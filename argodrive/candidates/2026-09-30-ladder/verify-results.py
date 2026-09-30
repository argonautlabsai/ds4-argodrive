"""Validate the ladder records; no inference is run."""
import csv, hashlib, json, statistics
from pathlib import Path
root = Path(__file__).resolve().parent
data = json.loads((root / 'results.json').read_text())
prompt = root.parents[2] / 'speed-bench/promessi_sposi.txt'
assert hashlib.sha256(prompt.read_bytes()).hexdigest() == data['arms'][0]['prompt_sha256']
assert len({a['id'] for a in data['arms']}) == len(data['arms']) == len(data['sequence'])
hashes = set()
for a in data['arms']:
    path = root / a['csv']; assert hashlib.sha256(path.read_bytes()).hexdigest() == a['csv_sha256'], a['id']
    with path.open() as f: rows = list(csv.DictReader(f))
    assert len(rows) == 1; row = rows[0]
    for field, key in [('gen_tps', 'generation_tok_s'), ('gen_steady_tps', 'steady_tok_s'), ('prefill_tps', 'prefill_tok_s'), ('gen_first_ms', 'first_decode_step_ms')]:
        assert float(row[field]) == a[key], (a['id'], field)
    assert int(row['prefill_tokens']) == a['prompt_tokens'] == 512 and int(row['gen_tokens']) == a['generated_tokens'] == 200
    assert 0 <= a['swap_growth_mb'] <= data['max_swap_growth_mb'] <= 64 and a['prompt_sha256'] == data['arms'][0]['prompt_sha256']
    if a['rung'] != 'upstream-internal':
        assert a['gpu_active_mhz'] >= 1600 and a['requested_cache_experts'] == 3600 and a['runtime_cache']['matches_requested'] and not a['runtime_cache']['allocation_reduced'], a['id']
    hashes.add(a['output_sha256'])
assert (len(hashes) == 1) == data['output_identical_on_all_arms']
up = next(r for r in data['rungs'] if r['id'] == 'upstream-internal')
for r in data['rungs']:
    sel = [a for a in data['arms'] if a['rung'] == r['id']]; assert len(sel) == r['runs'] and sorted(a['id'] for a in sel) == sorted(r['arms'])
    for k in ('steady_tok_s', 'generation_tok_s', 'prefill_tok_s', 'first_decode_step_ms'):
        assert r['medians'][k] == statistics.median(a[k] for a in sel), (r['id'], k)
    for k in ('steady_tok_s', 'generation_tok_s', 'prefill_tok_s'):
        assert abs(r['vs_upstream'][k] - r['medians'][k] / up['medians'][k]) < 1e-12
print('PASS: %d CSVs, hashes, gates (swap growth at most %.1f MB, recorded per arm), medians and multipliers; output identical on all arms: %s.' % (len(data['arms']), data['max_swap_growth_mb'], data['output_identical_on_all_arms']))
print('This checks published evidence; it does not rerun inference or establish broad model quality.')
