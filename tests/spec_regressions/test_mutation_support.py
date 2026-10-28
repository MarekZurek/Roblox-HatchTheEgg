"""Regression tests for mutation evidence classification and source isolation."""
from pathlib import Path
import hashlib,json,sys,tempfile,unittest
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'tools'))
from mutation_support import classify,run_mutations

class ClassificationTests(unittest.TestCase):
 def test_intended_assertion(self):
  self.assertEqual(classify(1,'C:/copy/tests/sample/run:7: SPEC/cash expected 1 got 2','sample','SPEC/cash'),'KILLED')
 def test_survivor(self):
  self.assertEqual(classify(0,'PASS','sample','SPEC/cash'),'SURVIVED')
 def test_runtime_crash_even_with_marker(self):
  self.assertEqual(classify(1,'C:/copy/tests/sample/run:7: attempt to call a nil value SPEC/cash','sample','SPEC/cash'),'INVALID')
 def test_foreign_assertion(self):
  self.assertEqual(classify(1,'C:/copy/tests/other/run:7: SPEC/cash','sample','SPEC/cash'),'INVALID')
 def test_wrong_assertion(self):
  self.assertEqual(classify(1,'C:/copy/tests/sample/run:7: SPEC/unrelated','sample','SPEC/cash'),'INVALID')
 def test_marker_in_later_output_does_not_hide_crash(self):
  self.assertEqual(classify(1,'C:/copy/src/Cash:4: attempt to index nil\nC:/copy/tests/sample/run:7: SPEC/cash','sample','SPEC/cash'),'INVALID')
 def test_syntax_or_import_errors(self):
  for text in ['SyntaxError: SPEC/cash','Failed to resolve require SPEC/cash']:
   self.assertEqual(classify(1,'C:/copy/tests/sample/run:7: '+text,'sample','SPEC/cash'),'INVALID')
 def test_timeout_and_failed_baseline(self):
  self.assertEqual(classify(None,'TIMEOUT','sample','SPEC/cash'),'INVALID')
  self.assertEqual(classify(1,'C:/copy/tests/sample/run:7: SPEC/cash','sample','SPEC/cash',1),'INVALID')
 def test_same_message_from_wrong_case_is_invalid(self):
  output="C:/copy/tests/sample/run:7: SPEC/cash\n    Script 'C:/copy/tests/sample/run', Line 99"
  self.assertEqual(classify(1,output,'sample','SPEC/cash',expected_case_line=42),'INVALID')
  self.assertEqual(classify(1,output,'sample','SPEC/cash',expected_case_line=99),'KILLED')
 def test_no_test_assertion(self):
  self.assertEqual(classify(1,'arbitrary failure expected SPEC/cash','sample','SPEC/cash'),'INVALID')

class IsolationTests(unittest.TestCase):
 def test_fault_only_exists_in_copy_and_corrected_test_runs(self):
  workspace_build=Path(__file__).resolve().parents[2]/'build'
  workspace_build.mkdir(exist_ok=True)
  with tempfile.TemporaryDirectory(dir=workspace_build) as temp:
   assert Path(temp).resolve().is_relative_to(workspace_build.resolve())
   root=Path(temp)
   for name in ['src','tests/sample','docs/reference_data','tools','.tools/lune-test']:(root/name).mkdir(parents=True,exist_ok=True)
   source=root/'src/Cash.luau';source.write_bytes(b'return 1')
   (root/'tests/sample/run.luau').write_text('test fixture',encoding='utf8')
   exe=root/'.tools/lune-test/lune.exe';exe.write_bytes(b'fake tool for unit test')
   (root/'tools/toolchain.json').write_text(json.dumps({'lune':{'version':'test','executableSha256':hashlib.sha256(exe.read_bytes()).hexdigest()}}))
   calls=[]
   def execute(_tool,workspace,_suite,_timeout):
    self.assertNotEqual(root,workspace);self.assertEqual(source.read_bytes(),b'return 1')
    value=(workspace/'src/Cash.luau').read_text();calls.append(value)
    return {'command':['fake','run','tests/sample/run.luau'],'exitCode':1 if value=='return 2' else 0,'output':'C:/copy/tests/sample/run:7: SPEC/cash' if value=='return 2' else 'PASS'}
   with patch('mutation_support.execute',side_effect=execute):
    report=run_mutations(root,[{'name':'cash','suite':'sample','faults':[('src/Cash.luau','return 1','return 2')],'expectedFailure':'SPEC/cash'}],'unit-mutation')
   self.assertEqual(calls,['return 1','return 2','return 1'])
   self.assertEqual(report['status'],'PASS');self.assertEqual(source.read_bytes(),b'return 1')

if __name__=='__main__':unittest.main()
