import sys
import unittest
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'lib'))
from model_support import ds41_fork_profile
import ds41_benchmark as b


class ChampionProfileTests(unittest.TestCase):
    def test_runtime_cache_fallback_invalidates_comparison(self):
        full = b'streaming expert cache budget=4200 experts entries=4200'
        self.assertTrue(b.observe_cache(full, 4200)['matches_requested'])
        self.assertFalse(b.observe_cache(b'', 4200)['matches_requested'])
        self.assertFalse(b.observe_cache(b'streaming expert cache budget=3685 experts', 4200)['matches_requested'])
        self.assertFalse(b.observe_cache(full+b'\nusing locked cache cap: 3991 experts', 4200)['matches_requested'])
        self.assertFalse(b.observe_cache(full+b'\nruntime cache cap now 3685 experts', 4200)['matches_requested'])

    def test_champion_complete_and_requires_three_sources(self):
        p = ds41_fork_profile('/model', ['/green', '/white'], 'champion-20260919')
        self.assertFalse(p['errors'])
        self.assertEqual(p['cache_experts'], 4200)
        self.assertEqual(p['replica_weights'], [5, 5])
        self.assertEqual(p['environment']['DS4_ARGODRIVE_PRIMARY_WEIGHT'], '10')
        self.assertEqual(p['environment']['DS4_ARGODRIVE_DECODE_WEIGHTS'], '10,6,6')
        self.assertEqual(p['environment']['DS4_ARGODRIVE_CPU_KEEPALIVE'], '1')
        self.assertEqual(p['environment']['DS4_TP_KEEPALIVE_ITERS'], '300000')
        self.assertNotIn('DS4_ARGODRIVE_PREFILL_PIPE', p['environment'])
        self.assertNotIn('DS4_ARGODRIVE_RESIDENT_DOWN', p['environment'])
        self.assertTrue(ds41_fork_profile('/model', [], 'champion-20260919')['errors'])
        self.assertTrue(ds41_fork_profile('/model', ['/green'], 'champion-20260919')['errors'])

    def test_invalid_replica_weights_never_launch(self):
        with patch.object(b.subprocess, 'Popen') as child:
            for weights in ([], [0], [101], [True], ['5'], [5, 5]):
                with self.assertRaisesRegex(ValueError, 'integer weight'):
                    b.run({'model_path': '/model'}, replicas=['/green'], replica_weights=weights)
            child.assert_not_called()


if __name__ == '__main__': unittest.main()
