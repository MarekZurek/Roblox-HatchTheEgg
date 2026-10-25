-- Behavioral regressions #71-74. Prices and levels below are isolated fixtures,
-- not approved launch balance. Expected values come from reference rules.
local B=require('../../src/server/Bootstrap')
local C=require('../../src/shared/NumericCodec')
local D=require('../../src/server/PersistenceData')
local S=require('../../src/server/ProfileSchema').new(C)
local P=require('../../src/server/ProgressActions')
local F=require('../../src/server/FarmActions')
local Main=require('../support/MainHarness')
local fs,serde=require('@lune/fs'),require('@lune/serde')
local count=0
local function eq(a,b,label)count+=1;assert(a==b,(label or '')..' expected '..tostring(b)..' got '..tostring(a))end
local function near(a,b,label)count+=1;assert(math.abs(a-b)<=math.max(1,math.abs(b))*2e-12,(label or '')..' expected '..tostring(b)..' got '..tostring(a))end
local ORIGIN=10000000
local function harness(mutate,events)
 local h={now=ORIGIN,records={}}
 h.store={read=function(key)return true,h.records[key] and D.copy(h.records[key])end,update=function(key,fn)
  if h.beforeWrite then local hook=h.beforeWrite;h.beforeWrite=nil;hook()end
  if h.fail then return false,'simulated write outage' end
  local next=fn(h.records[key] and D.copy(h.records[key]));if next then h.records[key]=D.copy(next)end
  if h.loseAck then h.loseAck=false;h.fail=true;return false,'lost acknowledgement' end
  return true,next and D.copy(next)
 end}
 h.b=B.new({storageMode='INTERNAL_TEST_ONLY',store=h.store,clock={utcNowMs=function()return h.now end,elapsedNowSeconds=function()return (h.now-ORIGIN)/1000 end},liveEvents=events or {}})
 local p=S.createReference('1',ORIGIN);p.farm.cash='1000000';if mutate then mutate(p)end
 eq(h.b:playerJoined('1',p).status,'JOINED')
 function h.p()local ss=h.b:getCoordinator('1').snapshots();return ss.working or ss.durable end
 function h.cmd(kind,args,id)return h.b:dispatch('1',{protocolVersion=1,kind=kind,requestId=id,operationId=id,expectedRevision=h.p().meta.revision,args=args or {}})end
 function h.input(state,seq)return h.b:dispatch('1',{protocolVersion=1,kind='HatchInput',requestId='input-'..seq,streamId=h.b:getPlayer('1').hatchingRuntime.streamId,inputSeq=tostring(seq),state=state})end
 function h.step(ms)h.now+=ms;h.b:tick(0)end
 function h.quote(kind,args)return h.b:dispatch('1',{protocolVersion=1,kind='QuoteRequest',requestId='quote-request',target={kind=kind,args=args}})end
 return h
end
local function finish(h)
 for _=1,1000 do
  h.server:tick(0)
  if h.server:getCoordinator('1').snapshots().ready and next(h.server:getPlayer('1').pendingEntitlements)==nil then return end
 end
 error('owned entitlement did not finish')
end
-- #71: actual Main ownership jobs, in either policy/ownership order. Old income
-- must keep F2P rates even when ownership is learned before settlement finishes.
for _,away in {16,61,3700} do
 for _,reverse in {false,true} do
  local p=S.createReference('1',ORIGIN-away*1000);p.farm.habitats[1].population='100'
  local h=Main.new({nowMs=ORIGIN,records={['player:1']=p},attributes={pro_permit_PlatformId=987654322,buy_max_PlatformId=987654323},owns={[987654322]=true,[987654323]=true}})
  local jobs=h.join();if reverse then for i=#jobs,1,-1 do h.runJob(jobs[i])end else for _,i in jobs do h.runJob(i)end end
  finish(h)
  eq(h.profile().entitlements.pro_permit,true,'owned Pro survives incomplete settlement')
  eq(h.profile().entitlements.buy_max,true,'owned Buy MAX survives incomplete settlement')
  eq(h.profile().entitlements.pro_permit_effective_at,ORIGIN)
  if away==61 and not reverse then
   h.services.Players.PlayerRemoving:Fire(h.player);h.player.Parent=nil
   h.player=h.addPlayer(1);for _,i in h.join() do h.runJob(i) end;finish(h)
   eq(h.profile().entitlements.pro_permit,true,'owned pass survives reconnect/new generation')
  end
  local control=harness(function(q)
   q.timeline.settledWallThrough=ORIGIN-away*1000;q.farm.cash='0';q.farm.habitats[1].population='100'
  end)
  for _=1,1000 do control.b:tick(0);if control.b:getCoordinator('1').snapshots().ready then break end end
  near(C.BigAmount.decode(h.profile().accounting.currentFarmCash),C.BigAmount.decode(control.p().accounting.currentFarmCash),'new Pro is not retroactive across silos/away')
  local ledger=D.fingerprint(h.profile().operations);h.server:tick(0)
  eq(D.fingerprint(h.profile().operations),ledger,'no repeated grant after success')
 end
end
for _,policy in {{ArePaidRandomItemsRestricted=true},{}} do
 local p=S.createReference('1',ORIGIN-61000)
 local h=Main.new({nowMs=ORIGIN,records={['player:1']=p},policyResult=policy,attributes={pro_permit_PlatformId=987654322}})
 for _,i in h.join()do h.runJob(i)end;finish(h)
 eq(h.profile().entitlements.pro_permit,true,'base Pro independent of paid-random policy')
 eq(h.profile().entitlements.pro_plus10_enabled,false,'unknown/restricted remains gated')
end
-- Ownership result from an old player/session is not authority for its successor.
do
 local h=Main.new({nowMs=ORIGIN,attributes={pro_permit_PlatformId=987654322}})
 local jobs=h.join();h.runJob(jobs[1])
 h.onOwnership=function()coroutine.yield();return true end
 local co=coroutine.create(function()h.runJob(jobs[2])end);eq(coroutine.resume(co),true)
 h.services.Players.PlayerRemoving:Fire(h.player);h.player.Parent=nil
 h.player=h.addPlayer(1);h.join()
 eq(coroutine.resume(co),true)
 eq(h.profile().entitlements.pro_permit,nil,'old callback cannot grant successor')
end
-- UNKNOWN, both before and after storage committed. Same intent is reconciled;
-- no second benefit and no side write bypassing the coordinator.
for _,committed in {false,true} do
 local h=Main.new({nowMs=ORIGIN,attributes={pro_permit_PlatformId=987654322}})
 local jobs=h.join();h.runJob(jobs[1])
 if committed then h.loseWriteAck=true;h.disconnectAfterAckLoss=true else h.writeFailure=true end
 h.runJob(jobs[2]);eq(next(h.server:getPlayer('1').pendingEntitlements)~=nil,true)
 h.writeFailure=false;h.server:tick(0)
 eq(next(h.server:getPlayer('1').pendingEntitlements)~=nil,true,'ledger read alone cannot unfreeze a fenced owner')
 h.elapsed=121
 finish(h)
 eq(h.profile().entitlements.pro_permit,true,'trusted grant recovers unknown write')
 local grants=0;for _,op in h.profile().operations do if op.kind=='GrantEntitlement' and op.terminalStatus=='APPLIED' then grants+=1 end end
 eq(grants,1,'exactly one durable grant')
end
-- #72: independent closed-form FV. Only the maximum bonus dimension counts,
-- not current running chickens, clucking growth, pet equipment or active boosts.
local baseFV=50*1200*(1/30)*.25*(250^.6)
for _,case in {{common={},epic={},cap=0},{common={coordinated_clucking=50},epic={},cap=10},
 {common={coordinated_clucking=50,motivational_clucking=2},epic={},cap=11},
 {common={coordinated_clucking=50},epic={epic_multiplier=3,epic_clucking=10},cap=16}} do
 local p=S.createReference('1',ORIGIN);p.farm.common=case.common;p.permanent.epic=case.epic
 near(P.calculateProfileFarmValue(p),baseFV*(1+case.cap)^.25,'max RCB cap in FV')
 p.farm.runningCount='100';p.effects.boosts={{id='fixture',dimension_raw=2,effect=50,remainingSeconds='60'}}
 p.inventory.pets={fixture={uid='fixture',speciesId='rooster',tier=3,variant='Rainbow',power=100}};p.inventory.equipped={'fixture'}
 near(P.calculateProfileFarmValue(p),baseFV*(1+case.cap)^.25,'running, pet and boost excluded from FV')
end
do
 local h=harness(function(p)p.farm.common.coordinated_clucking=50;p.rewards.numDailyGiftsCollected=3 end)
 local gift=h.cmd('ClaimDailyGift',{},'rcb-calendar')
 eq(gift.status,'APPLIED');near(C.BigAmount.decode(gift.result.amount),baseFV*11^.25*.5,'28-day cash resolver uses corrected FV')
 local p=S.createReference('1',ORIGIN);p.permanent.SE='40000'
 eq(P.canUpgradeEgg(p,1),false);p.farm.common.coordinated_clucking=50
 eq(P.canUpgradeEgg(p,1),true,'existing egg threshold uses max RCB')
end
-- #73: raw first-price oracles from unchanged reference_data, never createQuote.
local purchases={
 {kind='BuyResearch',args={researchId='comfy_nests',mode='single'},epic='cheaper_research',base=.5026054676849723},
 {kind='BuyHabitat',args={slotId=1,habitatId='SHACK'},epic='cheaper_contractors',base=466.66887875775},
 {kind='BuyVehicle',args={slotId=1,vehicleId='TRANSIT VAN'},epic='bust_unions',base=544.5387296153486},
}
for _,spec in purchases do
 for _,level in {0,1,10} do
  local price=spec.base*(1-.05*level)
  local h=harness(function(p)p.permanent.epic[spec.epic]=level;p.farm.cash=C.BigAmount.encode(price);p.accounting.currentFarmCash='2000000'end)
  local q=h.quote(spec.kind,spec.args);near(C.BigAmount.decode(q.cashCost),price);eq(q.available,true,'exact discounted affordability')
  local args=table.clone(spec.args);args.quoteId=q.quoteId
  local r=h.cmd(spec.kind,args,'discount-purchase');eq(r.status,'APPLIED')
  near(C.BigAmount.decode(h.p().farm.cash),0,'discount is actually debited')
  eq(h.p().accounting.currentFarmCash,'2000000','spending preserves prestige earnings')
  eq(h.cmd(spec.kind,args,'discount-purchase').status,'REPLAYED');eq(h.p().farm.cash,'0')
 end
 -- The write callback sees a newer discount even at the same revision.
 local h=harness();local q=h.quote(spec.kind,spec.args);local args=table.clone(spec.args);args.quoteId=q.quoteId
 h.beforeWrite=function()h.records['player:1'].permanent.epic[spec.epic]=10 end
 local r=h.cmd(spec.kind,args,'changed-in-callback');eq(r.status,'REJECTED');eq(r.result.errorCode,'QUOTE_CHANGED')
 eq(h.p().farm.cash,'1000000','fresh discount mismatch cannot spend old price')
 -- Quote-to-command change with a settled state and unchanged revision.
 local direct=S.createReference('1',ORIGIN);direct.farm.cash='1000000'
 local actions=F.new(C,h.b.catalog,{mode='INTERNAL_TEST_ONLY'})
 local old=actions.createQuote(direct,{kind=spec.kind,args=spec.args},'r','0','old',ORIGIN)
 direct.permanent.epic[spec.epic]=10
 local out=actions.apply(direct,{kind=spec.kind,args=spec.args,quoteId=old.quoteId})
 eq(out.terminalStatus,'REJECTED');eq(out.result.errorCode,'QUOTE_CHANGED');eq(direct.farm.cash,'1000000')
end
-- #74: rejected reset preserves a live input, successful reset stops it. Replay
-- must not kill an input started after that confirmed reset.
do
 local h=harness(function(p)p.permanent.epic.hold_to_hatch=15;p.accounting.currentFarmCash='1000000'end,
  {{type='prestige',multiplier=4,startTimeMs=ORIGIN,deadlineMs=ORIGIN+100}})
 eq(h.input('start',1).status,'ACCEPTED')
 h.beforeWrite=function()h.now+=100 end
 local r=h.cmd('Prestige',{},'rejected-prestige');eq(r.status,'REJECTED');eq(r.result.errorCode,'PRESTIGE_EVENT_CHANGED')
 eq(h.p().permanent.prestigeCount,'0');eq(h.b:getPlayer('1').hatchingRuntime.held,true,'rejected plan is not a reset')
 h.input('refresh',2);h.step(300)
 eq(h.p().farm.hatchGroupSequence~='0',true,'continued input really hatches after rejection')
 eq(h.cmd('Prestige',{},'successful-prestige').status,'APPLIED');eq(h.b:getPlayer('1').hatchingRuntime.held,false)
 h.input('start',3);eq(h.cmd('Prestige',{},'successful-prestige').status,'REPLAYED')
 eq(h.b:getPlayer('1').hatchingRuntime.held,true,'old replay does not stop new input')
 h.step(2100);eq(h.b:getPlayer('1').hatchingRuntime.held,false,'unchanged lease expires')
end
do
 local h=harness(function(p)p.permanent.SE='40000';p.farm.common.coordinated_clucking=50;p.permanent.epic.hold_to_hatch=15 end)
 h.input('start',1)
 h.beforeWrite=function()h.records['player:1'].farm.common={} end
 eq(h.cmd('UpgradeEgg',{targetEggIndex=1},'rejected-upgrade').status,'REJECTED')
 eq(h.b:getPlayer('1').hatchingRuntime.held,true,'fresh-state rejection of egg reset preserves input')
 -- A new decision uses the settled authoritative state, not an old result.
 local good=harness(function(p)p.permanent.SE='100000';p.permanent.epic.hold_to_hatch=15 end)
 good.input('start',1);eq(good.cmd('UpgradeEgg',{targetEggIndex=1},'successful-upgrade').status,'APPLIED')
 eq(good.b:getPlayer('1').hatchingRuntime.held,false,'committed egg change stops input')
 good.input('start',2);eq(good.cmd('UpgradeEgg',{targetEggIndex=1},'successful-upgrade').status,'REPLAYED')
 eq(good.b:getPlayer('1').hatchingRuntime.held,true,'egg-change replay preserves later input')
end
for _,committed in {false,true} do
 local h=harness(function(p)p.permanent.epic.hold_to_hatch=15;p.accounting.currentFarmCash='1000000'end)
 h.input('start',1);if committed then h.loseAck=true else h.fail=true end
 eq(h.cmd('Prestige',{},'unknown-reset').status,'UNKNOWN')
 eq(h.b:getPlayer('1').hatchingRuntime.held,true,'unknown result is not a confirmed reset')
 local before=h.p().farm.hatchGroupSequence;h.step(300)
 eq(h.p().farm.hatchGroupSequence,before,'unknown session cannot breed')
 h.fail=false;h.now+=121000
 local c=h.b:getCoordinator('1');eq(c.recover('unknown-reset').status,'ACQUIRED');c.setReady(true);h.b:tick(0)
 eq(h.b:getPlayer('1').hatchingRuntime.held,false,'confirmed reset or elapsed technical lease stops old input')
 eq(h.p().permanent.prestigeCount,if committed then '1' else '0')
end
fs.writeFile('build/entitlement-farm-regressions-results.json',serde.encode('json',{status='PASS',level='L',assertions=count,studioTested=false,dataStoreTested=false},true))
print(string.format('Entitlement / farm regressions #71-74: %d assertions PASS',count))
