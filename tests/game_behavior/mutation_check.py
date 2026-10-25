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
 ('egg_reset_reuses_group_ids','src/server/ProgressActions.luau',
  '-- Preserve hatchGroupSequence: group IDs must remain unique across farm resets (docs/38). UpgradeEgg.',
  'candidateProfile.farm.hatchGroupSequence = "0"'),
 ('prestige_reuses_group_ids','src/server/ProgressActions.luau',
  '-- Preserve hatchGroupSequence: group IDs must remain unique across farm resets (docs/38). Prestige.',
  'candidateProfile.farm.hatchGroupSequence = "0"'),
 ('event_end_point_sampling','src/server/TimelineSimulation.luau',
  'local eventAverage=EffectsManager.averageEarningsEventMultiplier(cp.config.liveEvents,cp.startInstantMs,cp.elapsedSeconds,dt)',
  'local eventAverage=mults.eventEarningsMult'),
 ('event_ignores_deadline','src/server/EffectsManager.luau',
  'local right = math.min(dt, (deadline - originMs) / 1000 - elapsedSeconds)',
  'local right = dt'),
 ('event_overlap_applies_whole_step','src/server/EffectsManager.luau',
  'if window.left <= left and window.right >= right then multiplier *= window.multiplier end',
  'if true then multiplier *= window.multiplier end'),
 ('shop_operation_reuses_local_counter','src/client/IntentControllers.luau',
  'local operationId = "op-shop-" .. tostring(self.stateStore:getStreamId()) .. "-" .. tostring(self._opSerial)',
  'local operationId = "op-" .. tostring(quoteView.target.kind) .. "-" .. tostring(self._opSerial)'),
 ('stream_omits_session_generation','src/server/NetworkGateway.luau',
  'local streamPrefix="stream-" .. playerId .. "-g" .. generation .. "-"',
  'local streamPrefix="stream-" .. playerId .. "-"'),
 ('prestige_ignores_collection_event','src/server/Bootstrap.luau',
  'deps.prestigeEventMult=Effects.calculateMultipliers(nil,candidateProfile.farm,self.clock.utcNowMs(),self.liveEvents).eventPrestigeMult',
  'deps.prestigeEventMult=1'),
 ('running_chickens_ignored','src/server/TimelineSimulation.luau',
  'runningCount=f.runningCount,eggIndex=f.eggIndex',
  'rcbMultiplier=1,eggIndex=f.eggIndex'),
 ('issued_drone_not_projected_to_visual','src/client/Bootstrap.luau',
  'for _,spawn in (progress and progress.issuedDrones) or {} do',
  'for _,spawn in {} do'),
 ('valuation_epic_ignored','src/server/ProgressActions.luau',
  'valuationMult = catalog.epicEffects("accounting_tricks",epic.accounting_tricks or 0).valuationMult or 1.0,',
  'valuationMult = 1.0,'),
 ('hold_rate_ignored','src/server/TimelineSimulation.luau',
  'hatching.holdStep(f,hold.runtime,holdDt,research.holdRate,',
  'hatching.holdStep(f,hold.runtime,holdDt,0,'),
 ('hold_timeout_unbounded','src/server/TimelineSimulation.luau',
  'local holdDt=math.max(0,math.min(dt,(hold.expiresAtMs-cp.startInstantMs)/1000-cp.elapsedSeconds))',
  'local holdDt=dt'),
 ('sharing_ignored','src/server/TimelineSimulation.luau',
  'f.habitats=ihr.step(f.habitats,effectiveIHRRate,dt,research.sharing,function()return draw(cp)end)',
  'f.habitats=ihr.step(f.habitats,effectiveIHRRate,dt,0,nil)'),
 ('hyperloop_unlock_checks_omitted','src/server/FarmActions.luau',
  'if typeIndex==11 and profile.permanent.hyperloop~=true then available=false;blockedReason="HYPERLOOP_LOCKED" end',
  '-- Missing quote unlock guard'),
 ('owned_pass_retry_dropped','src/server/Bootstrap.luau',
  'then self:grantEntitlement(playerId, entitlementId) end',
  'then local ignored = entitlementId end'),
 ('fv_max_rcb_ignored','src/server/ProgressActions.luau',
  'researchMaxRCBBase = r.rcbCap - 5 + (catalog.epicEffects("epic_multiplier",epic.epic_multiplier or 0).onscreenChickenMultMax or 0),',
  'researchMaxRCBBase = 0,'),
 ('epic_discounts_ignored','src/server/FarmActions.luau',
  'return catalog.epicEffects(spec[1], epic[spec[1]] or 0)[spec[2]] or 1',
  'return 1'),
 ('reset_stops_hold_before_commit','src/server/Bootstrap.luau',
  'local outcome=ProgressActions.apply(candidateProfile,op,deps)',
  'local outcome=ProgressActions.apply(candidateProfile,op,deps);if outcome.terminalStatus=="APPLIED" then playerSession.hatchingRuntime.held=false;playerSession.hatchingRuntime.holdElapsed=0 end'),
 ('discount_quote_change_ignored','src/server/FarmActions.luau',
  'if playerQuotes and op.quoteId and (not quoted or quoted.kind ~= op.kind or quoted.generation ~= candidateProfile.ownership.generation or quoted.multiplier ~= costMultiplier(candidateProfile,catalog,op.kind)) then',
  'if false then'),
 ('stale_ownership_callback_allowed','src/server/Main.server.luau',
  'if ok and owns and player.Parent == Players and activePlayerObjects[pId] == player and server:getPlayer(pId) == grantSession then',
  'if ok and owns then'),
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
  shutil.copytree(ROOT/'tests/resets',target/'tests/resets')
  shutil.copytree(ROOT/'tests/event_time',target/'tests/event_time')
  shutil.copytree(ROOT/'tests/session_prestige_rcb',target/'tests/session_prestige_rcb')
  shutil.copytree(ROOT/'tests/farm_gaps',target/'tests/farm_gaps')
  shutil.copytree(ROOT/'tests/entitlement_farm_regressions',target/'tests/entitlement_farm_regressions')
  (target/'docs/reference_data').mkdir(parents=True);(target/'build').mkdir()
  for ref in ['infrastructure','research','rewards']:
   shutil.copy2(ROOT/f'docs/reference_data/{ref}.json',target/f'docs/reference_data/{ref}.json')
  file=target/relative;text=file.read_text(encoding='utf-8');assert text.count(old)==1,(name,text.count(old))
  file.write_text(text.replace(old,new),encoding='utf-8')
  if name=='hyperloop_unlock_checks_omitted':
   # Disable all three defenses to reproduce an actual unauthorized train purchase.
   text=file.read_text(encoding='utf-8')
   text=text.replace('if typeIndex==11 and candidateProfile.permanent.hyperloop~=true then','if false then')
   text=text.replace('if typeIndex==11 and freshProfile.permanent.hyperloop~=true then','if false then')
   file.write_text(text,encoding='utf-8')
  if name=='calendar_claim_twice':
   # There are two independent UTC fences. Disabling only the leaf check
   # preserves correct behavior through the ingress and is not a semantic defect.
   server=target/'src/server/Bootstrap.luau';text=server.read_text(encoding='utf-8')
   old='if not Calendar.canClaimCalendarDay(draft,self.clock.utcNowMs()) then'
   assert text.count(old)==1
   server.write_text(text.replace(old,'if false then'),encoding='utf-8')
  suite='entitlement_farm_regressions' if name in {'owned_pass_retry_dropped','fv_max_rcb_ignored','epic_discounts_ignored','reset_stops_hold_before_commit','discount_quote_change_ignored','stale_ownership_callback_allowed'} else 'farm_gaps' if name in {'issued_drone_not_projected_to_visual','valuation_epic_ignored','hold_rate_ignored','hold_timeout_unbounded','sharing_ignored','hyperloop_unlock_checks_omitted'} else 'session_prestige_rcb' if name in {'shop_operation_reuses_local_counter','stream_omits_session_generation','prestige_ignores_collection_event','running_chickens_ignored'} else 'event_time' if name in {'event_end_point_sampling','event_ignores_deadline','event_overlap_applies_whole_step'} else 'resets' if name in {'egg_reset_reuses_group_ids','prestige_reuses_group_ids'} else 'pro_policy' if name in {'unknown_policy_allowed','fusion_trusts_saved_pro_flag','fulfillment_trusts_prepared_policy','late_policy_response_overwrites_current','sensitive_action_skips_policy_refresh'} else 'persistence_startup' if name in {'startup_receipt_handler_missing','local_payments_enabled','rejected_receipt_acknowledged','durable_receipt_replay_ignored','confirmed_retry_snapshot_stale'} else 'calendar_cycle' if name in {'calendar_cash_percent_omitted','calendar_shell_precision_lost','calendar_prestige_base_lost'} else 'game_behavior'
  run=subprocess.run([str(ROOT/'.tools/lune-0.11.1/lune.exe'),'run',f'tests/{suite}/run.luau'],cwd=target,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=120)
  output=run.stdout+run.stderr
  invalid=any(word in output for word in ['SyntaxError','Failed to resolve require','could not resolve','error parsing'])
  state='INVALID' if invalid else 'KILLED' if run.returncode else 'SURVIVED'
  (target/'build/output.txt').write_text(output,encoding='utf-8')
  print(f'{name}: {state}',flush=True)
  results.append({'mutant':name,'state':state,'exitCode':run.returncode,'output':str((target/'build/output.txt').relative_to(ROOT))})
 report={'status':'PASS' if all(r['state']=='KILLED' for r in results) else 'FAIL','mutants':results,'scope':'Forty-one selected semantic mutations; not exhaustive mutation coverage'}
 (ROOT/'build/game-behavior-mutations.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
 assert report['status']=='PASS',report
if __name__=='__main__':main()
