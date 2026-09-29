"""Check the recorded arms of the 2026-09-29 screens; no inference is run and no champion is claimed."""
import csv, hashlib, json
from pathlib import Path
root = Path(__file__).resolve().parent
data = json.loads((root / 'results.json').read_text())
ref = {200: '8182ab832dcc07c11d4d36028b9b3f4f5cc672538011495e60fcb4f40b91044f'}
for a in data['arms']:
    p = root / a['csv']; assert hashlib.sha256(p.read_bytes()).hexdigest() == a['csv_sha256'], a['id']
    with p.open() as f: row = list(csv.DictReader(f))[0]
    assert float(row['gen_steady_tps']) == a['steady_tok_s'] and int(row['gen_tokens']) == a['generated_tokens'] == 200
    assert a['output_sha256'] == ref[200] and a['swap_growth_mb'] == 0 and a['gpu_active_mhz'] >= 1600, a['id']
print(f"PASS: {len(data['arms'])} CSVs, reference output hash and gates on every recorded arm; screens only, no new champion.")
