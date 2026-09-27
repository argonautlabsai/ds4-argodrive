"""Validate the published records; no inference or hardware measurement is run."""
import csv
import hashlib
import json
import statistics
from pathlib import Path

root = Path(__file__).resolve().parent
data = json.loads((root / 'results.json').read_text())
expected = {200: '8182ab832dcc07c11d4d36028b9b3f4f5cc672538011495e60fcb4f40b91044f',
            512: 'f14f5a1dcb74375d8d3e98fba56cc1cdea2d410117fd41decb82d0d273fd1ec4'}
prompt = root.parents[2] / 'speed-bench/promessi_sposi.txt'
prompt_sha = hashlib.sha256(prompt.read_bytes()).hexdigest()
assert len({a['id'] for a in data['arms']}) == len(data['arms'])
groups = {g['id']: g for g in data['groups']}
assert groups['stack512']['role'] == 'qualification' and groups['stack200']['role'] == 'qualification'
for arm in data['arms']:
    path = root / arm['csv']
    assert hashlib.sha256(path.read_bytes()).hexdigest() == arm['csv_sha256'], arm['id']
    with path.open() as f:
        rows = list(csv.DictReader(f))
    assert len(rows) == 1
    row = rows[0]
    for field, key in [('gen_tps', 'generation_tok_s'), ('gen_steady_tps', 'steady_tok_s'),
                       ('prefill_tps', 'prefill_tok_s'), ('gen_first_ms', 'first_decode_step_ms')]:
        assert float(row[field]) == arm[key], (arm['id'], field)
    assert int(row['ctx_tokens']) == int(row['prefill_tokens']) == arm['prompt_tokens'] == 512
    assert int(row['gen_tokens']) == arm['generated_tokens']
    assert int(row['gen_steady_tokens']) == arm['steady_tokens'] == arm['generated_tokens'] - 1
    assert arm['context_allocation'] == 4096 and arm['prompt_sha256'] == prompt_sha
    assert arm['output_sha256'] == expected[arm['generated_tokens']], arm['id']
    assert arm['runtime_cache']['matches_requested'] and not arm['runtime_cache']['allocation_reduced']
    assert arm['runtime_cache']['observed_budgets'] == [arm['requested_cache_experts']]
    if groups[arm['group']]['role'] != 'excluded: clock gate':
        assert arm['swap_growth_mb'] == 0 and arm['expert_counters_close'], arm['id']
        assert arm['gpu_active_mhz'] >= 1600, arm['id']
for gid in ('stack512', 'stack200'):
    g = groups[gid]; arms = [a for a in data['arms'] if a['group'] == gid]
    a = [x for x in arms if x['label'] == 'A']; b = [x for x in arms if x['label'] == 'B']
    assert len(a) == len(b) == 2 and g['complete']
    assert all(x['binary_tree'] == 'published tag' and x['requested_cache_experts'] == 4200 for x in a)
    assert all(x['binary_tree'] == 'candidate' and x['requested_cache_experts'] == 4600 for x in b)
    assert all(x['engine_sha256'] == a[0]['engine_sha256'] for x in a) and all(x['engine_sha256'] == b[0]['engine_sha256'] for x in b)
    for k in ('steady_tok_s', 'generation_tok_s'):
        assert g['medians']['A'][k] == statistics.median(x[k] for x in a)
        assert g['medians']['B'][k] == statistics.median(x[k] for x in b)
    assert all(y['steady_tok_s'] > x['steady_tok_s'] for x, y in zip(a, b))
    assert abs(g['steady_gain_pct'] - 100 * (g['medians']['B']['steady_tok_s'] / g['medians']['A']['steady_tok_s'] - 1)) < 1e-9
# source hashes: every recorded file must still hash the same in this checkout
recorded = json.loads((root / 'source-sha256.json').read_text())['source_sha256']
tree = root.parents[2]
changed = [f for f, h in recorded.items() if hashlib.sha256((tree / f).read_bytes()).hexdigest() != h]
assert not changed, changed
q = groups['stack512']['medians']
print(f"PASS: {len(data['arms'])} CSVs, prompt and reference output hashes, cache/swap/clock gates on retained arms, "
      f"two-repeat qualification at 512/512 ({q['A']['steady_tok_s']:.3f} -> {q['B']['steady_tok_s']:.3f} steady) and 512/200, "
      f"{len(recorded)} source hashes.")
print("This checks published evidence; it does not rerun inference or establish broad model quality.")
