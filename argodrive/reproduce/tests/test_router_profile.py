import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

REPRODUCE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPRODUCE / 'lib'))
from model_support import ds41_fork_profile

EXTRA = {
    'DS4_ARGODRIVE_HC_EXPAND_BF16': '1',
    'DS4_ARGODRIVE_ROPE_INPUT': '1',
    'DS4_ARGODRIVE_QAKV_BF16': '1',
    'DS4_ARGODRIVE_Q8_ROWS_EPILOGUE': '1',
    'DS4_ARGODRIVE_VIEW_CACHE': '1',
    'DS4_ARGODRIVE_V41_ROUTER_FUSION': '4',
}


class RouterProfileTests(unittest.TestCase):
    def test_profile_extends_the_pinned_champion_only(self):
        old = ds41_fork_profile('/primary', ['/one', '/two'], 'champion-20260921')
        new = ds41_fork_profile('/primary', ['/one', '/two'], 'v41-router-20260921')
        self.assertFalse(new['errors'])
        self.assertEqual(new['environment'], {**old['environment'], **EXTRA})
        self.assertEqual(new['cache_experts'], 4200)
        self.assertNotIn('DS4_ARGODRIVE_V41_ROUTER_FUSION', old['environment'])
        for replicas in [[], ['/one'], ['/one*2', '/two']]:
            self.assertTrue(ds41_fork_profile('/primary', replicas, 'v41-router-20260921')['errors'])

    def test_public_cli_plan_exports_the_measured_combination(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            engine = root / 'engine'
            engine.write_text('#!/bin/sh\nexit 99\n')
            engine.chmod(0o700)
            prompt = root / 'prompt'
            prompt.write_text('Public fixture')
            completed = subprocess.run([
                sys.executable, str(REPRODUCE / 'run.py'), 'plan', '--variant', 'fork',
                '--profile', 'v41-router-20260921', '--engine', str(engine),
                '--model', str(root / 'primary'), '--replica', str(root / 'one'),
                '--replica', str(root / 'two'), '--prompt', str(prompt),
                '--out', str(root / 'arm'), '--tokens', '200', '--accounting', '--timeline',
            ], check=True, capture_output=True, text=True)
            plan = json.loads(completed.stdout)
            self.assertFalse(plan['launches_engine'])
            for key, value in EXTRA.items():
                self.assertEqual(plan['requested_environment'][key], value)
            self.assertEqual(plan['requested_environment']['DS4_ARGODRIVE_DECAY_TOKENS'], '32')
            self.assertEqual(plan['requested_environment']['DS4_ARGODRIVE_DECODE_WEIGHTS'], '10,6,6')


if __name__ == '__main__':
    unittest.main()
