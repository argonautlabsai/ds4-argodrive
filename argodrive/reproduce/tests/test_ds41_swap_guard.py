import hashlib,json,subprocess,sys,tempfile,unittest
from pathlib import Path
from unittest.mock import MagicMock,patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'lib'))
import ds41_benchmark as b
class SwapGuardTests(unittest.TestCase):
 def test_cache_reduction_stops_engine_even_without_swap_growth(self):
  with tempfile.TemporaryDirectory() as d:
   root=Path(d);model=root/'model';model.write_bytes(b'GGUFtest')
   engine=root/'ds4-bench';engine.write_text('fixture');engine.chmod(0o700)
   prompt=root/'prompt';prompt.write_text('fixture');out=root/'arm'
   child=MagicMock(pid=4321);child.wait.side_effect=[subprocess.TimeoutExpired(['fixture'],2),0];child.poll.return_value=None
   def launch(*args,**kw):
    kw['stdout'].write('ds4:   using locked cache cap: 3991 experts\n');kw['stdout'].flush();return child
   with patch.object(b,'DS41_Q4_BYTES',8),patch.object(b,'DS41_Q4_SHA256',hashlib.sha256(model.read_bytes()).hexdigest()),patch.object(b,'process_guard'),patch.object(b.fcntl,'flock'),patch.object(b.subprocess,'Popen',side_effect=launch),patch.object(b,'swap_used_mb',return_value=100),patch.object(b.os,'killpg') as stop:
    p=b.plan(engine,model,prompt,out);p['cache']={'experts':4200}
    with self.assertRaisesRegex(RuntimeError,'reduced the requested expert cache'):b.run(p,max_swap_growth_mb=256)
   stop.assert_called_once_with(4321,b.signal.SIGTERM)
   state=json.loads((out/'run.json').read_text());self.assertEqual(state['status'],'stopped');self.assertIsNone(state['active_pid'])
   self.assertIn('locked cache cap',(out/'baseline.engine.txt').read_text())
 def test_units_and_unavailable_measurement(self):
  with patch.object(b.subprocess,'check_output',return_value='total = 2.00G used = 1.25G free = 0.75G'):
   self.assertEqual(b.swap_used_mb(),1280)
  with patch.object(b.subprocess,'check_output',return_value='unavailable'):
   with self.assertRaises(RuntimeError):b.swap_used_mb()
 def test_growth_stops_owned_engine_and_preserves_failure_evidence(self):
  with tempfile.TemporaryDirectory() as d:
   root=Path(d);model=root/'model';model.write_bytes(b'GGUFtest')
   engine=root/'ds4-bench';engine.write_text('fixture');engine.chmod(0o700)
   prompt=root/'prompt';prompt.write_text('fixture');out=root/'arm'
   child=MagicMock(pid=4321);child.wait.side_effect=[subprocess.TimeoutExpired(['fixture'],2),0];child.poll.return_value=None
   with patch.object(b,'DS41_Q4_BYTES',8),patch.object(b,'DS41_Q4_SHA256',hashlib.sha256(model.read_bytes()).hexdigest()),patch.object(b,'process_guard'),patch.object(b.fcntl,'flock'),patch.object(b.subprocess,'Popen',return_value=child),patch.object(b,'swap_used_mb',side_effect=[100,400]),patch.object(b.os,'killpg') as stop:
    p=b.plan(engine,model,prompt,out)
    with self.assertRaisesRegex(RuntimeError,'Swap growth'):b.run(p,max_swap_growth_mb=256)
   stop.assert_called_once_with(4321,b.signal.SIGTERM)
   state=json.loads((out/'run.json').read_text());self.assertEqual(state['status'],'stopped');self.assertIsNone(state['active_pid'])
   self.assertEqual(len(json.loads((out/'swap-samples.json').read_text())),2)
if __name__=='__main__':unittest.main()
