"""Check that semantic defects are caught by acceptance tests in isolated copies.

Never mutates the working source. A syntax/import failure is INVALID, not a kill.
Run after tools/test.ps1; output is an ignored local verification artifact.
"""
from pathlib import Path
import json, shutil, subprocess, uuid
ROOT=Path(__file__).resolve().parents[2]
MUTANTS=[
 ('local_fake_success','src/client/Bootstrap.luau',
  'function ClientBootstrap:claimDailyGift(callback) return self:_command("ClaimDailyGift",{},callback) end',
  'function ClientBootstrap:claimDailyGift(callback) local r={status="APPLIED"};if callback then callback(r) end;return r end'),
 ('missing_trophy_route','src/server/NetworkGateway.luau',
  '{"ClaimDailyGift","ClaimTrophy","FusePets",','{"ClaimDailyGift","FusePets",'),
 ('calendar_claim_twice','src/server/rewards/calendar.luau',
  'if currentUtcDay <= lastDay then','if false then'),
 ('trophy_below_threshold','src/server/rewards/trophies.luau',
  'if currentPopulation < spec.populationRequired then','if false then'),
 ('fusion_free_materials','src/server/pets/fusion.luau',
  'inventory.pets[mUid] = nil','inventory.pets[mUid] = inventory.pets[mUid]'),
 ('shop_credit_instead_of_debit','src/server/Bootstrap.luau',
  'U.subtract(U.decode(draft.permanent.GE),cost)','U.add(U.decode(draft.permanent.GE),cost)'),
 ('trophy_wrong_GE','src/server/rewards/trophies.luau',
  'ExactUInt.fromSafeNumber(spec.goldenEggs)','ExactUInt.fromSafeNumber(spec.goldenEggs+1)'),
]
def main():
 base=ROOT/'build'/('behavior-mutations-'+uuid.uuid4().hex[:8]);base.mkdir(parents=True)
 results=[]
 for name,relative,old,new in MUTANTS:
  target=base/name;target.mkdir()
  shutil.copytree(ROOT/'src',target/'src')
  shutil.copytree(ROOT/'tests/game_behavior',target/'tests/game_behavior')
  (target/'docs/reference_data').mkdir(parents=True);(target/'build').mkdir()
  for ref in ['infrastructure','research','rewards']:
   shutil.copy2(ROOT/f'docs/reference_data/{ref}.json',target/f'docs/reference_data/{ref}.json')
  file=target/relative;text=file.read_text(encoding='utf-8');assert text.count(old)==1,(name,text.count(old))
  file.write_text(text.replace(old,new),encoding='utf-8')
  if name=='calendar_claim_twice':
   # There are two independent UTC fences. Disabling only the leaf check
   # preserves correct behavior through the ingress and is not a semantic defect.
   server=target/'src/server/Bootstrap.luau';text=server.read_text(encoding='utf-8')
   old='if not Calendar.canClaimCalendarDay(draft,self.clock.utcNowMs()) then'
   assert text.count(old)==1
   server.write_text(text.replace(old,'if false then'),encoding='utf-8')
  run=subprocess.run([str(ROOT/'.tools/lune-0.11.1/lune.exe'),'run','tests/game_behavior/run.luau'],cwd=target,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=90)
  output=run.stdout+run.stderr
  invalid=any(word in output for word in ['SyntaxError','Failed to resolve require','could not resolve','error parsing'])
  state='INVALID' if invalid else 'KILLED' if run.returncode else 'SURVIVED'
  (target/'build/output.txt').write_text(output,encoding='utf-8')
  print(f'{name}: {state}',flush=True)
  results.append({'mutant':name,'state':state,'exitCode':run.returncode,'output':str((target/'build/output.txt').relative_to(ROOT))})
 report={'status':'PASS' if all(r['state']=='KILLED' for r in results) else 'FAIL','mutants':results,'scope':'Seven selected semantic mutations; not exhaustive mutation coverage'}
 (ROOT/'build/game-behavior-mutations.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
 assert report['status']=='PASS',report
if __name__=='__main__':main()
