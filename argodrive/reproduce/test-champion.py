#!/usr/bin/env python3
"""Bounded champion kernel, reader and cache fixtures; no model required."""
import argparse
import fcntl
import os
from pathlib import Path
import subprocess
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).parent/'lib'))
from ds41_benchmark import process_guard

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine-source', type=Path, default=Path(__file__).resolve().parents[2])
    args=parser.parse_args(); root=args.engine_source.resolve()
    tests=Path(__file__).resolve().parent/'tests'
    compiler=subprocess.check_output(['xcrun','--find','clang'],text=True).strip()
    sdk=subprocess.check_output(['xcrun','--sdk','macosx','--show-sdk-path'],text=True).strip()
    env={k:v for k,v in os.environ.items() if not k.startswith(('DS4_','GLM_','K3_'))}
    env['MTL_DEBUG_LAYER']='1'
    fixtures=['flat_pool','q4_resident_down','q8_round_epilogue','shared_bf16',
              'norm_bf16','hc_norm','live_scan','decay','keepalive_scope']
    with Path('/tmp/argodrive-glm-campaign.lock').open('a+') as lock, tempfile.TemporaryDirectory(prefix='argodrive-champion-tests-') as tmp:
        fcntl.flock(lock, fcntl.LOCK_EX|fcntl.LOCK_NB);process_guard()
        for name in fixtures:
            binary=Path(tmp)/name
            subprocess.run([compiler,'-O2','-g','-fobjc-arc','-Wl,-dead_strip',
                            '-I',str(root),'-isysroot',sdk,str(tests/('test_'+name+'.m')),
                            '-framework','Foundation','-framework','Metal','-lm','-pthread',
                            '-o',str(binary)],check=True,cwd=root,timeout=120)
            cases=[[]]
            if name=='keepalive_scope': cases=[['1'],['2']]
            if name=='decay': cases=[[v,v if v.isdigit() and v!='0' else '16'] for v in ('4','8','16','32','64','128','0','invalid')]
            for case in cases:
                subprocess.run([str(binary),*case],check=True,cwd=root,env=env,timeout=90)
            print('PASS',name,flush=True)
    print('PASS: nine focused fixtures; no full-model, CUDA or distributed inference claim.')

if __name__=='__main__': main()
