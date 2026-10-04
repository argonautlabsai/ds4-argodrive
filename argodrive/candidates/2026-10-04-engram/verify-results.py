"""Validate the published records of the 2026-10-04 package; no inference is run."""
import csv, hashlib, json, statistics
from pathlib import Path
root = Path(__file__).resolve().parent
data = json.loads((root / 'results.json').read_text())
expected = {200: '8182ab832dcc07c11d4d36028b9b3f4f5cc672538011495e60fcb4f40b91044f',
            512: 'f14f5a1dcb74375d8d3e98fba56cc1cdea2d410117fd41decb82d0d273fd1ec4'}
prompt = root.parents[2] / 'speed-bench/promessi_sposi.txt'
prompt_sha = hashlib.sha256(prompt.read_bytes()).hexdigest()
for key in ('hotlist', 'conditional_prior'):
    f = root.parents[2] / data[key]['path']
    assert hashlib.sha256(f.read_bytes()).hexdigest() == data[key]['sha256'], key
assert len({a['id'] for a in data['arms']}) == len(data['arms'])
groups = {g['id']: g for g in data['groups']}
SWITCHES = {'DS4_ARGODRIVE_PREFILL_READER': '1', 'DS4_ARGODRIVE_ENGRAM_PREFETCH_MIN': '1', 'DS4_ARGODRIVE_ENGRAM_BATCH_READERS': '128'}
for arm in data['arms']:
    path = root / arm['csv']; assert hashlib.sha256(path.read_bytes()).hexdigest() == arm['csv_sha256'], arm['id']
    with path.open() as f: rows = list(csv.DictReader(f))
    assert len(rows) == 1; row = rows[0]
    for field, key in [('gen_tps', 'generation_tok_s'), ('gen_steady_tps', 'steady_tok_s'), ('prefill_tps', 'prefill_tok_s'), ('gen_first_ms', 'first_decode_step_ms')]:
        assert float(row[field]) == arm[key], (arm['id'], field)
    assert int(row['prefill_tokens']) == arm['prompt_tokens'] == 512 and int(row['gen_tokens']) == arm['generated_tokens']
    assert arm['prompt_sha256'] == prompt_sha and arm['output_sha256'] == expected[arm['generated_tokens']], arm['id']
    assert arm['requested_cache_experts'] == 3600 and arm['runtime_cache']['matches_requested'] and not arm['runtime_cache']['allocation_reduced'], arm['id']
    assert arm['swap_growth_mb'] == 0 and arm['gpu_active_mhz'] >= 1600, arm['id']
    d = arm['environment_delta']
    if arm['group'] in ('qual512', 'qual200') and arm['label'] == 'B':
        assert all(d.get(k) == v for k, v in SWITCHES.items()) and d.get('DS4_ARGODRIVE_COOC') == data['conditional_prior']['path'], arm['id']
    if arm['group'] in ('qual512', 'qual200', 'screen-reader-engram') and arm['label'] == 'A':
        assert d == {} and arm['binary_tree'] == 'published tag', arm['id']
for gid in ('screen-reader-engram', 'screen-cooc', 'qual512', 'qual200'):
    g = groups[gid]; arms = [a for a in data['arms'] if a['group'] == gid]
    a = [x for x in arms if x['label'] == 'A']; b = [x for x in arms if x['label'] == 'B']
    assert len(a) == len(b) >= 2 and g['complete'], gid
    for k in ('prefill_tok_s', 'steady_tok_s', 'generation_tok_s'):
        assert g['medians']['A'][k] == statistics.median(x[k] for x in a) and g['medians']['B'][k] == statistics.median(x[k] for x in b)
    assert all(y['prefill_tok_s'] > x['prefill_tok_s'] for x, y in zip(a, b)), gid
    assert abs(g['prefill_gain_pct'] - 100 * (g['medians']['B']['prefill_tok_s'] / g['medians']['A']['prefill_tok_s'] - 1)) < 1e-9
for d in data['one_drive_diagnostics']:
    path = root / d['csv']; assert hashlib.sha256(path.read_bytes()).hexdigest() == d['csv_sha256'], d['id']
    assert d['output_sha256'] == 'be5708786e61' or len(d['output_sha256']) == 64, d['id']
q5, q2 = groups['qual512'], groups['qual200']; assert len(q5['arms']) == len(q2['arms']) == 4
print(f"verified {len(data['arms'])} arms in {len(data['groups'])} groups and {len(data['one_drive_diagnostics'])} one-drive diagnostics; qualification prefill "
      f"{q5['medians']['A']['prefill_tok_s']:.2f} -> {q5['medians']['B']['prefill_tok_s']:.2f} tok/s at 512/512 ({q5['prefill_gain_pct']:+.1f}%) and "
      f"{q2['medians']['A']['prefill_tok_s']:.2f} -> {q2['medians']['B']['prefill_tok_s']:.2f} at 512/200 ({q2['prefill_gain_pct']:+.1f}%), "
      f"decode {q5['steady_gain_pct']:+.2f}% / {q2['steady_gain_pct']:+.2f}%; every arm's output matches the published reference hash")
