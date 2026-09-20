import importlib.util,sys,tempfile,unittest
from pathlib import Path
R=Path(__file__).resolve().parents[1]/'lib';sys.path.insert(0,str(R));import ds41_benchmark as m
class Process:
 def __init__(self,rc=None):self.rc=rc
 def poll(self):return self.rc
class ReadyTests(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.d=Path(self.tmp.name);self.csv=self.d/'sample.csv';self.log=self.d/'sample.log';self.devices={'internal':'disk0','Green':'disk6','White':'disk4'}
  self.log.write_text('ARGODRIVE_SAMPLER_START_MONO 100.000\n');self.csv.write_text('t_s,dev,v1,v2,v3\n'+''.join('0.1,%s,100,1,0\n'%v for v in self.devices.values()))
 def tearDown(self):self.tmp.cleanup()
 def test_all_drives_ready(self):m.wait_sampler_ready(Process(),self.csv,self.log,self.devices,timeout=0)
 def test_partial_drive_set_refused(self):
  self.csv.write_text('0.1,disk0,100,1,0\n')
  with self.assertRaisesRegex(RuntimeError,'all drive baselines'):m.wait_sampler_ready(Process(),self.csv,self.log,self.devices,timeout=0)
 def test_missing_clock_anchor_refused(self):
  self.log.write_text('')
  with self.assertRaisesRegex(RuntimeError,'all drive baselines'):m.wait_sampler_ready(Process(),self.csv,self.log,self.devices,timeout=0)
 def test_exited_sampler_refused(self):
  with self.assertRaisesRegex(RuntimeError,'exited'):m.wait_sampler_ready(Process(0),self.csv,self.log,self.devices,timeout=0)
if __name__=='__main__':unittest.main()
