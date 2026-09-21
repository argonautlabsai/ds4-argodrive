"""Recompute the published medians and verify all eight timing CSVs."""
import csv
import hashlib
import json
import statistics
from pathlib import Path

root=Path(__file__).resolve().parent
data=json.loads((root/'results.json').read_text())
assert len(data['arms'])==8
for arm in data['arms']:
    path=root/arm['csv']
    assert hashlib.sha256(path.read_bytes()).hexdigest()==arm['csv_sha256']
    row=list(csv.DictReader(path.open()))
    assert len(row)==1
    row=row[0]
    for field,key in [('gen_tps','generation_tok_s'),('gen_steady_tps','steady_tok_s'),('prefill_tps','prefill_tok_s')]:
        assert float(row[field])==arm[key]
    assert int(row['gen_tokens'])==arm['generated_tokens']
    assert int(row['gen_steady_tokens'])==arm['generated_tokens']-1
    assert int(row['prefill_tokens'])==int(row['ctx_tokens'])==512
    assert arm['runtime_cache']['matches_requested'] and arm['swap_growth_mb']==0
for group in data['groups']:
    rows=[a for a in data['arms'] if a['generated_tokens']==group['generated_tokens']]
    assert ''.join(a['label'] for a in rows)==group['sequence']
    assert len({a['output_sha256'] for a in rows})==1
    for label in 'AB':
        runs=[a for a in rows if a['label']==label];assert len(runs)==2
        reference=group['configurations'][label]
        assert statistics.median(a['steady_tok_s'] for a in runs)==reference['steady_median']
        assert statistics.median(a['generation_tok_s'] for a in runs)==reference['inclusive_median']
print('PASS: eight CSV hashes, token counts, medians, output-hash agreement and recorded cache/swap gates.')
print('This validates the published record; it does not rerun inference or independently establish model quality.')
