import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPRODUCE=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(REPRODUCE/'lib'))
from model_support import ds41_fork_profile

class LatestChampionTests(unittest.TestCase):
    def test_exact_tested_stack_and_previous_profile_preserved(self):
        old=ds41_fork_profile('/primary',['/one','/two'],'champion-20260919')
        new=ds41_fork_profile('/primary',['/one','/two'],'champion-20260921')
        self.assertFalse(new['errors'])
        self.assertEqual(new['cache_experts'],4200)
        self.assertEqual(new['environment']['DS4_ARGODRIVE_DECODE_WEIGHTS'],'10,6,6')
        self.assertEqual(new['environment']['DS4_ARGODRIVE_GAP_KEEPALIVE'],'2')
        self.assertEqual(new['environment']['DS4_TP_KEEPALIVE_TGS'],'1')
        self.assertEqual(new['environment']['DS4_ARGODRIVE_DECAY_TOKENS'],'32')
        for key in ['RESIDENT_DOWN','Q8_ROUND_EPILOGUE','FLAT_READS','SHARED_BF16','NORM_BF16','HC_NORM','LIVE_SCAN']:
            self.assertEqual(new['environment']['DS4_ARGODRIVE_'+key],'1')
        self.assertEqual(old['environment']['DS4_ARGODRIVE_GAP_KEEPALIVE'],'1')
        self.assertNotIn('DS4_ARGODRIVE_RESIDENT_DOWN',old['environment'])

    def test_requires_three_real_source_paths(self):
        for replicas in [[],['/one'],['/one','/two','/three'],['/one*2','/two']]:
            self.assertTrue(ds41_fork_profile('/primary',replicas,'champion-20260921')['errors'])

    def test_cli_plan_preserves_measurement_and_cache_settings(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);engine=root/'engine';engine.write_text('#!/bin/sh\nexit 99\n');engine.chmod(0o700)
            prompt=root/'prompt';prompt.write_text('Public test fixture')
            result=subprocess.run([sys.executable,str(REPRODUCE/'run.py'),'plan','--variant','fork',
                '--profile','champion-20260921','--engine',str(engine),'--model',str(root/'primary'),
                '--replica',str(root/'one'),'--replica',str(root/'two'),'--prompt',str(prompt),
                '--out',str(root/'arm'),'--tokens','200','--accounting','--timeline'],capture_output=True,text=True,check=True)
            plan=json.loads(result.stdout)
            self.assertFalse(plan['launches_engine'])
            self.assertEqual(plan['requested_environment']['DS4_ARGODRIVE_ACCOUNTING'],'1')
            self.assertEqual(plan['requested_environment']['DS4_ARGODRIVE_TIMELINE'],str((root/'arm/timeline.csv').resolve()))
            self.assertEqual(plan['requested_primary_weight'],10)
            self.assertEqual(plan['requested_replica_weights'],[5,5])
            self.assertEqual(plan['cache'],{'experts':4200})
            self.assertFalse((root/'arm').exists())

    def test_legacy_does_not_enable_new_stack(self):
        profile=ds41_fork_profile('/primary',['/one','/two'])
        self.assertNotIn('DS4_ARGODRIVE_RESIDENT_DOWN',profile['environment'])
        self.assertNotIn('DS4_ARGODRIVE_DECAY_TOKENS',profile['environment'])

if __name__=='__main__':unittest.main()
