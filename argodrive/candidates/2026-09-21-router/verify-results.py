"""Validate the published records; no inference or hardware measurement is run."""
import csv
import hashlib
import json
import math
import statistics
from pathlib import Path

root = Path(__file__).resolve().parent
data = json.loads((root / 'results.json').read_text())
assert len(data['arms']) == 14
assert {g['id'] for g in data['groups']} == {'final200', 'final512', 'repeat512', 'alternate'}
expected = {200: '8182ab832dcc07c11d4d36028b9b3f4f5cc672538011495e60fcb4f40b91044f',
            512: 'f14f5a1dcb74375d8d3e98fba56cc1cdea2d410117fd41decb82d0d273fd1ec4'}
for arm in data['arms']:
    path = root / arm['csv']
    assert hashlib.sha256(path.read_bytes()).hexdigest() == arm['csv_sha256']
    with path.open() as f:
        rows = list(csv.DictReader(f))
    assert len(rows) == 1
    row = rows[0]
    for field, key in [('gen_tps', 'generation_tok_s'), ('gen_steady_tps', 'steady_tok_s'),
                       ('prefill_tps', 'prefill_tok_s'), ('gen_first_ms', 'first_decode_step_ms')]:
        assert float(row[field]) == arm[key]
    assert int(row['ctx_tokens']) == int(row['prefill_tokens']) == arm['prompt_tokens'] == 512
    assert int(row['gen_tokens']) == arm['generated_tokens']
    assert int(row['gen_steady_tokens']) == arm['steady_tokens'] == arm['generated_tokens'] - 1
    assert arm['context_allocation'] == 4096
    assert arm['runtime_cache']['matches_requested']
    assert arm['runtime_cache']['observed_budgets'] == [4200]
    assert arm['swap_growth_mb'] == 0 and arm['expert_counters_close']
    sha = expected[arm['generated_tokens']] if arm['group'] != 'alternate' else 'fa0ad7ca3e570c745d654f7400f4e36595ea99ce04b4e87053472836fd422909'
    assert arm['output_sha256'] == sha
    for phase in arm['phase_accounting'].values():
        assert len(phase['devices']) == 3
        assert all(v > 0 for v in phase['expert_application_bytes_by_source'])
        assert phase['instrumented_application_bytes'] == sum(phase['expert_application_bytes_by_source']) + phase['engram_application_bytes_internal']
for group in data['groups']:
    arms = [a for a in data['arms'] if a['group'] == group['id']]
    assert ''.join(a['label'] for a in arms) == group['sequence']
    assert len({a['prompt_sha256'] for a in arms}) == 1
    assert len({a['steady_misses_per_token'] for a in arms}) == 1
    clocks = [a['gpu_active_mhz'] for a in arms]
    clock_pass = min(clocks) >= 1600 and max(clocks) / min(clocks) <= 1.01
    assert group['performance_qualified'] == clock_pass
    if group['performance_qualified']:
        assert group['id'] == 'final200'
        for label in 'AB':
            subset = [a for a in arms if a['label'] == label]
            assert len(subset) == 2
            speeds = [a['steady_tok_s'] for a in subset]
            assert max(speeds) / min(speeds) <= 1.02
            for key, value in group['medians'][label].items():
                assert math.isclose(statistics.median(a[key] for a in subset), value, rel_tol=1e-12)
        gain = 100 * (group['medians']['B']['steady_tok_s'] / group['medians']['A']['steady_tok_s'] - 1)
        assert math.isclose(gain, group['steady_gain_pct'], abs_tol=1e-10)
    else:
        assert 'medians' not in group and 'steady_gain_pct' not in group
source = json.loads((root / 'source-sha256.json').read_text())
assert len(source['source_sha256']) == 75
for relative, digest in source['source_sha256'].items():
    assert hashlib.sha256((root.parents[2] / relative).read_bytes()).hexdigest() == digest, relative
print('PASS: 14 CSVs, token counts, reference hashes, recorded cache/swap/accounting gates,')
print('qualified 200-token medians, three excluded clock-affected groups and 75 source hashes.')
print('This checks published evidence; it does not rerun inference or establish broad model quality.')
