"""FAIL/PASS controls for the mutation evidence gate itself, in isolated copies."""
from pathlib import Path
import hashlib,json,shutil,subprocess,sys,uuid
ROOT=Path(__file__).resolve().parents[2]
FAULTS=[
 ('wrong_callsite_accepted','if expected_case_line is not None:','if False:','FAIL: test_same_message_from_wrong_case_is_invalid'),
 ('runtime_crash_counted_as_kill',"if any(s in first for s in ('SyntaxError', 'attempt to call', 'attempt to index', 'Failed to resolve', 'error parsing')):", 'if False:', 'FAIL: test_runtime_crash_even_with_marker'),
 ('foreign_assertion_counted_as_kill',"re.search(r'tests/' + re.escape(suite) + r'/run(?:\\.luau)?:\\d+: ', first)",'True','FAIL: test_foreign_assertion'),
 ('broken_baseline_accepted','if baseline_exit != 0 or exit_code is None:','if exit_code is None:','FAIL: test_timeout_and_failed_baseline'),
 ('working_source_modified','path = target / relative','path = root / relative','FAIL: test_fault_only_exists_in_copy_and_corrected_test_runs'),
]

def main():
 source=ROOT/'tools/mutation_support.py';original=source.read_bytes();rows=[]
 base=ROOT/'build'/('runner-faults-'+uuid.uuid4().hex[:8]);base.mkdir(parents=True)
 for name,old,new,expected in FAULTS:
  target=base/name;(target/'tools').mkdir(parents=True);(target/'tests/spec_regressions').mkdir(parents=True);(target/'build').mkdir()
  shutil.copy2(source,target/'tools/mutation_support.py')
  shutil.copy2(ROOT/'tests/spec_regressions/test_mutation_support.py',target/'tests/spec_regressions/test_mutation_support.py')
  command=[sys.executable,'-B','tests/spec_regressions/test_mutation_support.py']
  def run(label):
   r=subprocess.run(command,cwd=target,capture_output=True,text=True,encoding='utf8',errors='replace',timeout=60)
   output=r.stdout+r.stderr;(target/'build'/f'{label}.txt').write_text(output,encoding='utf8');return r.returncode,output
  positive,_=run('baseline')
  text=original.decode('utf-8-sig');assert text.count(old)==1,name
  (target/'tools/mutation_support.py').write_text(text.replace(old,new),encoding='utf8')
  negative,out=run('mutant')
  (target/'tools/mutation_support.py').write_bytes(original)
  corrected,_=run('corrected')
  state='KILLED' if positive==0 and negative!=0 and expected in out and corrected==0 else 'INVALID'
  rows.append({'name':name,'state':state,'fault':{'path':'tools/mutation_support.py','before':old,'after':new},'expectedFailure':expected,'baselineExit':positive,'mutantExit':negative,'correctedExit':corrected,'command':command,'logs':str((target/'build').relative_to(ROOT))})
  print(name+': '+state,flush=True)
 report={'status':'PASS' if all(r['state']=='KILLED' for r in rows) else 'FAIL','mutants':rows,'testSha256':hashlib.sha256((ROOT/'tests/spec_regressions/test_mutation_support.py').read_bytes()).hexdigest(),'sourceSha256':hashlib.sha256(original).hexdigest()}
 (ROOT/'build/runner-fault-mutations.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf8')
 assert source.read_bytes()==original,'Working helper changed'
 assert report['status']=='PASS',report
if __name__=='__main__':main()
