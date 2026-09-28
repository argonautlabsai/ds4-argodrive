import sys
import unittest
from pathlib import Path

REPRODUCE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPRODUCE / 'lib'))
from model_support import ds41_fork_profile

EXTRA = {
    'DS4_ARGODRIVE_FLAG_READBACK': '1',
    'DS4_ARGODRIVE_BF16_EPILOGUES': '1',
    'DS4_ARGODRIVE_PSO_CACHE': '1',
}


class StackProfileTests(unittest.TestCase):
    def test_profile_extends_the_router_profile_only(self):
        old = ds41_fork_profile('/primary', ['/one', '/two'], 'v41-router-20260921')
        new = ds41_fork_profile('/primary', ['/one', '/two'], 'v41-stack-20260927')
        self.assertFalse(new['errors'])
        self.assertEqual(new['environment'], {**old['environment'], **EXTRA})
        self.assertEqual(new['cache_experts'], 4600)
        self.assertEqual(old['cache_experts'], 4200)
        for key in EXTRA:
            self.assertNotIn(key, old['environment'])
        for replicas in [[], ['/one'], ['/one*2', '/two']]:
            self.assertTrue(ds41_fork_profile('/primary', replicas, 'v41-stack-20260927')['errors'])


class Stack0928ProfileTests(unittest.TestCase):
    EXTRA = {'DS4_ARGODRIVE_POST_MOE_FLUSH': '1', 'DS4_ARGODRIVE_VICTIM_PRESCAN': '1'}

    def test_profile_extends_the_stack_profile_only(self):
        old = ds41_fork_profile('/primary', ['/one', '/two'], 'v41-stack-20260927')
        new = ds41_fork_profile('/primary', ['/one', '/two'], 'v41-stack-20260928')
        self.assertFalse(new['errors'])
        self.assertEqual(new['environment'], {**old['environment'], **self.EXTRA})
        self.assertEqual(new['cache_experts'], 4600)
        for key in self.EXTRA:
            self.assertNotIn(key, old['environment'])


if __name__ == '__main__':
    unittest.main()
