"""Validate current gift FAIL/PASS evidence, then export a portable delivery artifact."""
from pathlib import Path
import hashlib,importlib.util,json,sys,platform
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from mutation_support import classify

def module(name,path):
 spec=importlib.util.spec_from_file_location(name,ROOT/path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m

def main():
 cases={c['name']:c for c in module('gift_cases','tests/gift_drops/mutation_check.py').CASES}
 graph=module('input_graph','tests/spec_regressions/verify_evidence.py').input_tree
 report=json.loads((ROOT/'build/ground-gift-mutations.json').read_text(encoding='utf8'))
 assert report['complete'] and {r['name'] for r in report['mutants']}==set(cases),'Incomplete selection'
 rows=[]
 for row in report['mutants']:
  case=cases[row['name']]
  assert row['expectedFailure']==case['expectedFailure']
  assert row['faults']==[list(f) for f in case['faults']]
  assert row['testSha256']==hashlib.sha256((ROOT/f"tests/{row['suite']}/run.luau").read_bytes()).hexdigest(),'Stale test'
  for path,digest in row['sourceSha256'].items():assert digest==hashlib.sha256((ROOT/path).read_bytes()).hexdigest(),'Stale source'
  text=(ROOT/row['mutant']['log']).read_text(encoding='utf8')
  assert classify(row['mutant']['exitCode'],text,row['suite'],case['expectedFailure'],row['baseline']['exitCode'])=='KILLED'
  assert row['corrected']['exitCode']==0
  archive=(ROOT/row['mutant']['log']).parent.parent
  digest=graph(archive,row['suite']);assert digest==graph(ROOT,row['suite']),'Stale fixture graph'
  rows.append({'name':row['name'],'suite':row['suite'],'faults':row['faults'],'expectedFailure':row['expectedFailure'],
               'failure':row['failingAssertion'].replace(str(ROOT),'<repo>'),'exits':{k:row[k]['exitCode'] for k in ['baseline','mutant','corrected']},
               'testSha256':row['testSha256'],'sourceSha256':row['sourceSha256'],'inputTreeSha256':digest,'state':'KILLED'})
 result={'status':'PASS_LOCAL_ONLY','scope':f'{len(rows)} selected semantic faults; not exhaustive coverage',
         'python':platform.python_version(),'lune':report['toolchain'],'date':'2026-10-28','baseRevision':'34f77932ea115651e27a047c810e59fb4c8fd758',
         'commands':['<python> tests/gift_drops/mutation_check.py','<python> tests/gift_drops/verify_evidence.py'],
         'mutants':rows,'studioTested':False,'cloudTested':False}
 (ROOT/'build/ground_gifts-verified-evidence.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8')
 print(f'Ground gift evidence PASS: {len(rows)} intended FAIL -> PASS controls; current source/test/fixture hashes')
if __name__=='__main__':main()
