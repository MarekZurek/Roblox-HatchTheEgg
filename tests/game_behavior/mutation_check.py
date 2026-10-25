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
 ('calendar_cash_percent_omitted','src/server/rewards/calendar.luau',
  'BigAmount.divide(reward.amountNumber,100)','reward.amountNumber'),
 ('calendar_shell_precision_lost','src/server/rewards/calendar.luau',
  'ExactUInt.decode(profile.permanent.shellScripts or "0")','ExactUInt.fromSafeNumber(tonumber(profile.permanent.shellScripts or "0"))'),
 ('calendar_prestige_base_lost','src/server/rewards/calendar.luau',
  'profile.accounting.currentFarmCash = BigAmount.encode(BigAmount.add(BigAmount.decode(profile.accounting.currentFarmCash or "0"),addCash))',
  'profile.accounting.currentFarmCash = profile.accounting.currentFarmCash'),
 ('startup_receipt_handler_missing','src/server/Main.server.luau',
  'MarketplaceService.ProcessReceipt = function(receipt) return receiptHandler(receipt) end',
  '-- Startup receipt handler missing'),
 ('local_payments_enabled','src/server/Bootstrap.luau',
  'purchasesEnabled = storageMode ~= "STUDIO_MEMORY",','purchasesEnabled = true,'),
 ('rejected_receipt_acknowledged','src/server/Bootstrap.luau',
  'if res and (res.status == "APPLIED" or (res.status == "REPLAYED" and res.terminalStatus == "APPLIED")) then\n\t\tself:checkpointPlayer(pId)\n\t\treturn true, res\n\tend\n\n\treturn false, (res and res.errorCode) or "PURCHASE_FAILED"',
  'if res and (res.status == "APPLIED" or res.status == "REPLAYED") then\n\t\tself:checkpointPlayer(pId)\n\t\treturn true, res\n\tend\n\n\treturn false, (res and res.errorCode) or "PURCHASE_FAILED"'),
 ('durable_receipt_replay_ignored','src/server/Bootstrap.luau',
  'res = admission -- a durable replay may not have an in-process entry after restart',
  'res = coordinator.resultOf(op.operationId) -- ignores the saved record'),
 ('confirmed_retry_snapshot_stale','src/server/PlayerCoordinator.luau',
  'working=data.copy(h.snapshot) -- confirmed retry may have refreshed the durable snapshot',
  'working=data.copy(candidate) -- stale state after a confirmed grant'),
 ('unknown_policy_allowed','src/server/platform/products.luau',
  'return paidRandomAllowed == true and profile.entitlements',
  'return paidRandomAllowed ~= false and profile.entitlements'),
 ('fusion_trusts_saved_pro_flag','src/server/Bootstrap.luau',
  'local bonus=Products.isProBonusAvailable(draft,Products.readPaidRandomPolicy(self.paidRandomAllowed,playerId))',
  'local bonus=draft.entitlements.pro_plus10_enabled==true'),
 ('fulfillment_trusts_prepared_policy','src/server/platform/products.luau',
  'profile.entitlements.pro_plus10_enabled = playerContext ~= nil and playerContext.paidRandomAllowed == true',
  'profile.entitlements.pro_plus10_enabled = op ~= nil and op.paidRandomAllowed == true'),
 ('late_policy_response_overwrites_current','src/server/Main.server.luau',
  'if policyByPlayer[pId]~=row or player.Parent~=Players or activePlayerObjects[pId]~=player then return nil end',
  'if player.Parent~=Players or activePlayerObjects[pId]~=player then return nil end\n    policyByPlayer[pId]=row'),
 ('sensitive_action_skips_policy_refresh','src/server/Main.server.luau',
  'refreshPolicy(player) -- outside the coordinator/UpdateAsync; concurrent requests coalesce',
  '-- Sensitive action uses a stale cache'),
]
def main():
 base=ROOT/'build'/('behavior-mutations-'+uuid.uuid4().hex[:8]);base.mkdir(parents=True)
 results=[]
 for name,relative,old,new in MUTANTS:
  target=base/name;target.mkdir()
  shutil.copytree(ROOT/'src',target/'src')
  shutil.copytree(ROOT/'tests/game_behavior',target/'tests/game_behavior')
  shutil.copytree(ROOT/'tests/calendar_cycle',target/'tests/calendar_cycle')
  shutil.copytree(ROOT/'tests/persistence_startup',target/'tests/persistence_startup')
  shutil.copytree(ROOT/'tests/support',target/'tests/support')
  shutil.copytree(ROOT/'tests/pro_policy',target/'tests/pro_policy')
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
  suite='pro_policy' if name in {'unknown_policy_allowed','fusion_trusts_saved_pro_flag','fulfillment_trusts_prepared_policy','late_policy_response_overwrites_current','sensitive_action_skips_policy_refresh'} else 'persistence_startup' if name in {'startup_receipt_handler_missing','local_payments_enabled','rejected_receipt_acknowledged','durable_receipt_replay_ignored','confirmed_retry_snapshot_stale'} else 'calendar_cycle' if name in {'calendar_cash_percent_omitted','calendar_shell_precision_lost','calendar_prestige_base_lost'} else 'game_behavior'
  run=subprocess.run([str(ROOT/'.tools/lune-0.11.1/lune.exe'),'run',f'tests/{suite}/run.luau'],cwd=target,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=120)
  output=run.stdout+run.stderr
  invalid=any(word in output for word in ['SyntaxError','Failed to resolve require','could not resolve','error parsing'])
  state='INVALID' if invalid else 'KILLED' if run.returncode else 'SURVIVED'
  (target/'build/output.txt').write_text(output,encoding='utf-8')
  print(f'{name}: {state}',flush=True)
  results.append({'mutant':name,'state':state,'exitCode':run.returncode,'output':str((target/'build/output.txt').relative_to(ROOT))})
 report={'status':'PASS' if all(r['state']=='KILLED' for r in results) else 'FAIL','mutants':results,'scope':'Twenty selected semantic mutations; not exhaustive mutation coverage'}
 (ROOT/'build/game-behavior-mutations.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
 assert report['status']=='PASS',report
if __name__=='__main__':main()
