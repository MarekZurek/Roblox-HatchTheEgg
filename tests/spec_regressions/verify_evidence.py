"""Recheck all captured FAIL/PASS logs with the final classifier and current test hashes."""
from pathlib import Path
import importlib.util,hashlib,json,sys
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from mutation_support import classify

def load(relative):
 spec=importlib.util.spec_from_file_location(relative.replace('/','_'),ROOT/relative)
 module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module

def input_tree(root,suite):
 # Reconstruct the inputs from the actual isolated copy, not from the current
 # tree alone. Include shared support and reference fixtures as well as src.
 paths=set((root/'src').rglob('*.luau')) | set((root/'tests/support').glob('*.luau'))
 for pattern in ('*.luau','*.json'):paths.update((root/'tests'/suite).rglob(pattern))
 paths.update((root/'docs/reference_data').rglob('*.json'))
 entries=[(str(p.relative_to(root)).replace('\\','/'),hashlib.sha256(p.read_bytes()).hexdigest()) for p in paths]
 return hashlib.sha256(json.dumps(sorted(entries),separators=(',',':')).encode()).hexdigest()

def main():
 game=load('tests/game_behavior/mutation_check.py')
 fresh=load('tests/fresh_cash_purchases/mutation_check.py')
 spec=load('tests/spec_regressions/mutation_check.py')
 groups=[('game-behavior-mutations',set(game.EXPECTED_FAILURES),game.EXPECTED_CASE_LINES),('fresh_cash_mutations-results',set(fresh.MUTATIONS),fresh.EXPECTED_CASE_LINES),('spec-regression-mutations',{r['name'] for r in spec.CASES},{})]
 rows=[]
 for report_name,names,lines in groups:
  report=json.loads((ROOT/'build'/(report_name+'.json')).read_text(encoding='utf8'))
  assert report['complete'],report_name
  assert {r['name'] for r in report['mutants']}==names,report_name+' incomplete selection'
  for row in report['mutants']:
   assert row['testSha256']==hashlib.sha256((ROOT/f"tests/{row['suite']}/run.luau").read_bytes()).hexdigest(),row['name']+' stale test'
   for path,digest in row['sourceSha256'].items():assert digest==hashlib.sha256((ROOT/path).read_bytes()).hexdigest(),path+' stale source'
   archive=(ROOT/row['mutant']['log']).parent.parent
   digest=input_tree(archive,row['suite'])
   assert digest==input_tree(ROOT,row['suite']),row['name']+' stale dependency graph'
   expected=lines.get(row['name'],row.get('expectedCaseLine'))
   output=(ROOT/row['mutant']['log']).read_text(encoding='utf8')
   state=classify(row['mutant']['exitCode'],output,row['suite'],row['expectedFailure'],row['baseline']['exitCode'],expected)
   assert state=='KILLED' and row['corrected']['exitCode']==0,(row['name'],state,expected)
   row={**row,'state':state,'expectedCaseLine':expected,'inputTreeSha256':digest}
   rows.append(row)
 proof=json.loads((ROOT/'build/runner-fault-mutations.json').read_text(encoding='utf8'))
 assert proof['status']=='PASS' and len(proof['mutants'])==5
 assert proof['testSha256']==hashlib.sha256((ROOT/'tests/spec_regressions/test_mutation_support.py').read_bytes()).hexdigest()
 assert proof['sourceSha256']==hashlib.sha256((ROOT/'tools/mutation_support.py').read_bytes()).hexdigest()
 result={'status':'PASS','localOnly':True,'semanticMutations':len(rows),'runnerMutations':len(proof['mutants']),'finalClassifierSha256':hashlib.sha256((ROOT/'tools/mutation_support.py').read_bytes()).hexdigest(),'semanticEvidence':rows,'runnerEvidence':proof['mutants']}
 (ROOT/'build/verified-mutation-evidence.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8')
 print(f'Final evidence verification PASS: {len(rows)} semantic + 5 runner faults; exact assertions/call sites and current hashes')
if __name__=='__main__':main()
