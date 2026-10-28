-- Regression oracles for #66-70. Fixture values are not launch balance.
local B=require('../../src/server/Bootstrap')
local Client=require('../../src/client/Bootstrap')
local C=require('../../src/shared/NumericCodec')
local D=require('../../src/server/PersistenceData')
local S=require('../../src/server/ProfileSchema').new(C)
local Progress=require('../../src/server/ProgressActions')
local FarmActions=require('../../src/server/FarmActions')
local fs,serde=require('@lune/fs'),require('@lune/serde')
local count=0
local function eq(a,b,label)count+=1;assert(a==b,(label or '')..' expected '..tostring(b)..' got '..tostring(a))end
local function near(a,b,label)count+=1;assert(math.abs(a-b)<=math.max(1,math.abs(b))*2e-12,(label or '')..' expected '..tostring(b)..' got '..tostring(a))end
local ORIGIN=1000000
local function harness(mutate)
 local h={now=ORIGIN,records={}}
 h.store={read=function(key)return true,h.records[key] and D.copy(h.records[key])end,update=function(key,fn)
  if h.beforeWrite then local hook=h.beforeWrite;h.beforeWrite=nil;hook()end
  local next=fn(h.records[key] and D.copy(h.records[key]));if next then h.records[key]=D.copy(next)end
  return true,next and D.copy(next)
 end}
 function h.restart()h.b=B.new({storageMode='INTERNAL_TEST_ONLY',store=h.store,clock={utcNowMs=function()return h.now end,elapsedNowSeconds=function()return (h.now-ORIGIN)/1000 end}})end
 h.restart();local p=S.createReference('1',ORIGIN);p.farm.cash='1e40';if mutate then mutate(p)end
 eq(h.b:playerJoined('1',p).status,'JOINED')
 function h.p()local ss=h.b:getCoordinator('1').snapshots();return ss.working or ss.durable end
 function h.step(dt)
  h.now+=dt*1000;h.b:tick(dt);local n=0
  while not h.b:getCoordinator('1').snapshots().ready do h.b:tick(0);n+=1;assert(n<1000,'settlement stalled')end
 end
 function h.input(state,seq,stream)
  return h.b:dispatch('1',{protocolVersion=1,kind='HatchInput',requestId='hold-'..seq,streamId=stream or h.b:getPlayer('1').hatchingRuntime.streamId,inputSeq=tostring(seq),state=state})
 end
 function h.cmd(kind,args,id)return h.b:dispatch('1',{protocolVersion=1,kind=kind,requestId=id,operationId=id,expectedRevision=h.p().meta.revision,args=args or {}})end
 function h.client()
  local client
  client=Client.new({playerId='1',wire=function(packet)local r=h.b:dispatch('1',packet);if r then client:receive(r)end end})
  client:connect('real-client');return client
 end
 return h
end
-- #67: independent closed-form empty-farm FV and real calendar claim/upgrade gate.
local emptyFV=50*1200*(1/30)*.50*(250^.6)
for _,level in {0,1,20} do
 local p=S.createReference('1',ORIGIN);p.permanent.epic.accounting_tricks=level
 near(Progress.calculateProfileFarmValue(p),emptyFV*(1+.05*level),'valuation from Epic')
 local h=harness(function(q)q.permanent.epic.accounting_tricks=level;q.rewards.numDailyGiftsCollected=3 end)
 local view=h.b:dispatch('1',{protocolVersion=1,kind='Bootstrap',requestId='calendar-view'})
 local before=h.p().farm.cash;local gift=h.cmd('ClaimDailyGift',{},'valuation-gift')
 eq(gift.status,'APPLIED')
 -- Day four is 50% FV in reference_data, not a value obtained from the resolver.
 near(C.BigAmount.decode(gift.result.amount),emptyFV*(1+.05*level)*.5,'calendar uses updated FV')
 near(C.BigAmount.decode(view.view.farm.progress.calendar[4].amount),emptyFV*(1+.05*level)*.5,'calendar preview uses same FV')
end
do
 local p=S.createReference('1',ORIGIN);p.permanent.SE='1000'
 eq(Progress.canUpgradeEgg(p,1),false,'below egg threshold without valuation')
 p.permanent.epic.accounting_tricks=20
 eq(Progress.canUpgradeEgg(p,1),true,'valuation reaches existing egg threshold')
end
-- #68: stock/vacancy checked by real hold kernel; stop, expiry and stream change.
for _,level in {0,1,15} do
 local h=harness(function(p)p.permanent.epic.hold_to_hatch=level end)
 eq(h.input('start',1).status,'ACCEPTED');h.step(.3)
 local n=C.ExactUInt.toSafeNumber(C.ExactUInt.decode(h.p().farm.runningCount))
 eq(n,if level==0 then 0 elseif level==1 then 0 else 9,'owned level determines hold rate')
 h.input('stop',2);local seq=h.p().farm.hatchGroupSequence;h.step(.3)
 eq(h.p().farm.hatchGroupSequence,seq,'stop prevents new groups')
end
do
 local h=harness(function(p)p.permanent.epic.hold_to_hatch=15 end)
 h.input('start',1);h.step(2.1)
 eq(h.b:getPlayer('1').hatchingRuntime.held,false,'unrefreshed intention expires')
 local attempts=C.ExactUInt.toSafeNumber(C.ExactUInt.decode(h.p().farm.hatchGroupSequence))
 eq(attempts>=59 and attempts<=60,true,'two-second technical lease cannot grant 2.1s of breeding')
 local seq=h.p().farm.hatchGroupSequence;h.input('refresh',2);h.step(.3)
 eq(h.p().farm.hatchGroupSequence,seq,'refresh cannot resurrect expired intention')
 h.input('start',3);h.step(.3);eq(h.p().farm.hatchGroupSequence~=seq,true)
 local old=h.b:getPlayer('1').hatchingRuntime.streamId
 h.b:dispatch('1',{protocolVersion=1,kind='Bootstrap',requestId='new-handshake'})
 local before=h.p().farm.hatchGroupSequence;h.step(.3)
 eq(h.p().farm.hatchGroupSequence,before,'new handshake ends old intention')
 eq(h.input('start',4,old).errorCode,'WRONG_STREAM')
end
for _,case in {{stock='0',pop='0'},{stock='250',pop='250'}} do
 local h=harness(function(p)p.permanent.epic.hold_to_hatch=15;p.farm.hatcheryStock=case.stock;p.farm.habitats[1].population=case.pop end)
 h.input('start',1);h.step(.3)
 eq(h.p().farm.hatchGroupSequence,'0','no stock or vacancy means no release')
end
do
 local h=harness(function(p)p.permanent.epic.hold_to_hatch=15 end)
 local c=h.client();c:hatchHoldStart()
 for _=1,6 do h.now+=500;c:update(h.now);h.b:tick(0)end
 eq(h.b:getPlayer('1').hatchingRuntime.held,true,'client renews while actively held')
 c:hatchHoldStop();local before=h.p().farm.hatchGroupSequence;h.step(.3)
 eq(h.p().farm.hatchGroupSequence,before)
 h.input('start',100);h.cmd('Prestige',{},'reset-hold');h.step(.3)
 eq(h.b:getPlayer('1').hatchingRuntime.held,false,'reset ends intention')
 h.input('start',101);local seq=h.p().farm.hatchGroupSequence;h.step(61)
 eq(h.p().farm.hatchGroupSequence,seq,'away cannot breed from held input')
 eq(h.b:getPlayer('1').hatchingRuntime.held,false,'away ends the input lease')
 c:destroy();h.b:playerLeaving('1');h.restart();eq(h.b:playerJoined('1').status,'JOINED')
 seq=h.p().farm.hatchGroupSequence;h.step(.3);eq(h.p().farm.hatchGroupSequence,seq,'new session never restores hold')
end
-- #69: a single free target makes the independent sharing oracle deterministic.
for _,level in {0,1,10} do
 local h=harness(function(p)
  p.farm.habitats[1].population='250';p.farm.habitats[2].typeIndex=0
  p.farm.common.internal_hatchery1=1;p.permanent.epic.int_hatch_sharing=level
 end)
 h.step(.3)
 near(C.Real64.decode(h.p().farm.habitats[2].fractionalIHR),.01*(1+.1*level),'own IHR plus shared IHR')
 eq(h.p().farm.habitats[2].population,'0','fraction does not create an extra chicken')
 if level>0 then
  eq(h.p().timeline.selectionState~=nil,true,'random cursor survives bridge')
  eq(S.validate(h.p(),'1'),true)
 end
end
do
 local h=harness(function(p)
  for i=1,4 do p.farm.habitats[i].typeIndex=0;p.farm.habitats[i].population='250' end
  p.farm.common.internal_hatchery1=1;p.permanent.epic.int_hatch_sharing=10
 end)
 h.step(.3)
 for _,hab in h.p().farm.habitats do eq(hab.population,'250');eq(hab.fractionalIHR,'0')end
end
-- #70: quote, apply, fresh callback guard and resets preserve the unlock distinction.
for _,unlock in {false,true,'missing'} do
 local h=harness(function(p)p.permanent.hyperloop=if unlock=='missing' then nil else unlock end)
 local target={kind='BuyVehicle',args={slotId=1,vehicleId='HYPERLOOP TRAIN'}}
 local q=h.b:dispatch('1',{protocolVersion=1,kind='QuoteRequest',requestId='train-quote',target=target})
 eq(q.available,unlock==true)
 local before=h.p().farm.cash
 local r=h.cmd('BuyVehicle',{slotId=1,vehicleId='HYPERLOOP TRAIN',quoteId=q.quoteId},'train')
 eq(r.status,if unlock==true then 'APPLIED' else 'REJECTED')
 eq(h.p().farm.vehicles[1].typeIndex,if unlock==true then 11 else 0)
 if unlock~=true then eq(C.BigAmount.decode(h.p().farm.cash),C.BigAmount.decode(before));eq(r.result.errorCode,'HYPERLOOP_LOCKED')end
end
do
 local h=harness(function(p)p.permanent.hyperloop=true end)
 local q=h.b:dispatch('1',{protocolVersion=1,kind='QuoteRequest',requestId='old-train-quote',target={kind='BuyVehicle',args={slotId=1,vehicleId='HYPERLOOP TRAIN'}}})
 h.beforeWrite=function()h.records['player:1'].permanent.hyperloop=false end
 local r=h.cmd('BuyVehicle',{slotId=1,vehicleId='HYPERLOOP TRAIN',quoteId=q.quoteId},'fresh-station-check')
 eq(r.status,'REJECTED');eq(r.result.errorCode,'HYPERLOOP_LOCKED');eq(h.p().farm.vehicles[1].typeIndex,0)
end
do
 local h=harness(function(p)p.permanent.hyperloop=true;p.permanent.SE='100000' end)
 eq(h.cmd('UpgradeEgg',{targetEggIndex=1},'station-after-egg').status,'APPLIED')
 eq(h.p().permanent.hyperloop,true)
 eq(h.cmd('Prestige',{},'station-after-prestige').status,'APPLIED');eq(h.p().permanent.hyperloop,true)
end
-- #66: only server-issued records become visible; spoofing stays rejected.
do
 local h=harness();local c=h.client()
 local world=require('../../src/server/world/FarmPlotBuilder').new();world:build()
 local prompt=world:getDeliveryPrompt();local billboard={Name='ParcelBillboard',Enabled=true}
 c:syncDeliveryWidgets({prompt,billboard});eq(prompt.Enabled,false);eq(billboard.Enabled,false)
 eq(#c:getOrdinaryOffers(),0);eq(c:getPresentation():getDrone('drone-1'),nil)
 local terms={farmValue=10000,curve0FarmValue=2000,config={droneGoldGuaranteed=true},rollElite=.99,rolls={u2=.8}}
 eq(h.b:issueDrone('1','trusted-drone',terms),true)
 eq(h.b:issueOffer('1','trusted-parcel','ordinary',{rewardType='GE',amount='3',amountNumber=3}),true)
 eq(h.b:playerJoined('2').status,'JOINED')
 eq(h.b:issueOffer('2','other-player-parcel','ordinary',{rewardType='GE',amount='3',amountNumber=3}),true)
 c.transport:sendRefreshState()
 eq(c:getPresentation():getDrone('trusted-drone')~=nil,true)
 eq(c:getOrdinaryOffers()[1].id,'trusted-parcel')
 eq(#c:getOrdinaryOffers(),1,'other players offers never appear in private view')
 c:syncDeliveryWidgets({prompt,billboard});eq(prompt.Enabled,true);eq(billboard.Enabled,true)
 local snapshot=h.b:dispatch('1',{protocolVersion=1,kind='RefreshState',requestId='privacy'})
 eq(snapshot.view.farm.progress.issuedDrones[1].terms,nil,'server terms never projected')
 local before=C.ExactUInt.toSafeNumber(C.ExactUInt.decode(h.p().permanent.GE))
 eq(h.b:hitDrone('1','trusted-drone'),true);eq(h.b:claimOffer('1','trusted-parcel'),true)
 eq(C.ExactUInt.toSafeNumber(C.ExactUInt.decode(h.p().permanent.GE)),before+3+3)
 eq(h.b:hitDrone('1','drone-1'),false);eq(h.b:claimOffer('1','offer_2plus1'),false)
 local paid=h.p().permanent.GE;h.b:hitDrone('1','trusted-drone');h.b:claimOffer('1','trusted-parcel');eq(h.p().permanent.GE,paid)
 c.transport:sendRefreshState();eq(c:getPresentation():getDrone('trusted-drone'),nil);eq(#c:getOrdinaryOffers(),0)
 c:syncDeliveryWidgets({prompt,billboard});eq(prompt.Enabled,false);eq(billboard.Enabled,false)
 eq(h.b:issueDrone('1','expiring-drone',terms),true);c.transport:sendRefreshState()
 eq(c:getPresentation():getDrone('expiring-drone')~=nil,true)
 h.now=h.p().rewards.droneSpawns['expiring-drone'].expiresAtMs
 c.transport:sendRefreshState();eq(c:getPresentation():getDrone('expiring-drone'),nil,'expired visual removed from authoritative view')
end
-- A non-expired offer's actual owner is the only player receiving its private record.
do
 local Main=require('../support/MainHarness')
 local h=Main.new();h.join()
 eq(h.server:issueDrone('1','main-drone',{farmValue=10000,curve0FarmValue=2000,config={droneGoldGuaranteed=true},rollElite=.99,rolls={u2=.8}}),true)
 eq(h.server:issueOffer('1','main-parcel','ordinary',{rewardType='GE',amount='3',amountNumber=3}),true)
 h.remote({protocolVersion=1,kind='Bootstrap',requestId='main-reward-view'})
 local view=h.messages[#h.messages].message.view.farm.progress
 eq(view.issuedDrones[1].id,'main-drone');eq(view.ordinaryOffers[1].id,'main-parcel')
 h.remote({protocolVersion=1,kind='HitDrone',droneId=view.issuedDrones[1].id})
 h.remote({protocolVersion=1,kind='ClaimOffer',offerId=view.ordinaryOffers[1].id})
 eq(h.profile().permanent.GE,'16','actual Main ingress pays issued records')
 h.remote({protocolVersion=1,kind='HitDrone',droneId='main-drone'})
 h.remote({protocolVersion=1,kind='ClaimOffer',offerId='main-parcel'})
 eq(h.profile().permanent.GE,'16','actual Main ingress cannot pay twice')
end
-- Weighted sharing chooses one free target, and the RNG/hold cursor survives every phase.
do
 local Catalog=require('../../src/server/CatalogRegistry').new(C,require('../../src/server/CatalogRegistry/Data'),{mode='INTERNAL_TEST_ONLY'})
 local M=require('../../src/server/FarmMath/production_research').new(C,Catalog,{mode='INTERNAL_TEST_ONLY'})
 local P=require('../../src/server/FarmMath/PopulationMath').new(C)
 local H=require('../../src/server/FarmMath/hatching_rcb').new(C,P,D,{mode='INTERNAL_TEST_ONLY'})
 local I=require('../../src/server/FarmMath/ihr').new(C,P)
 local T=require('../../src/server/TimelineSimulation').new(C,M,H,I,D,{mode='INTERNAL_TEST_ONLY'})
 local function memory()
  local p=S.createReference('1',ORIGIN)
  p.farm.hatcheryStock=250;p.farm.cash=0;p.farm.commonLevels={internal_hatchery1=1};p.farm.vehicleTypes={0}
  p.permanent.epic={int_hatch_sharing=10,hold_to_hatch=15}
  for i,hab in p.farm.habitats do hab.typeIndex=if i<3 then 0 else -1;hab.capacity=if i<3 then '250' else '0';hab.population=if i==1 then '250' else '0';hab.fractionalIHR=0 end
  return {settledWallThrough=ORIGIN,farm=p.farm,permanent=p.permanent,accounting={prestigeSessionArchivedCash=0,currentFarmCash=0,prestigeExtraEarnings=0,lastBaseEarnings=0,lastCashEarned=0}}
 end
 local routes={};for i=1,4 do routes[i]={routeVersion='checkpoint-fixture',travelDurationSeconds=1} end
 local cfg={revision='sharing-hold:1',pro=false,siloCapacityLevel=0,selectionSeed=123456,
  holdContext={sessionKey='fixture-session',expiresAtMs=ORIGIN+2000,routes=routes,runtime={streamId='fixture-stream',lastInputSeq='1',held=true,holdElapsed=0}}}
 local cp=T.begin(memory(),ORIGIN+1200,cfg);local whole=T.advance(cp,100);local sliced=cp
 while not sliced.done do sliced=T.decodeCheckpoint(serde.decode('json',serde.encode('json',T.encodeCheckpoint(T.advance(sliced,1))))) end
 eq(D.fingerprint(sliced),D.fingerprint(whole),'hold/sharing checkpoint bitwise agreement')
 eq(whole.state.farm.hatchGroupSequence,'36','float32 hold accumulator preserved through phase resumes')
 eq(whole.state.farm.runningCount,'27');eq(whole.state.farm.habitats[2].population,'9')
 near(whole.state.farm.hatcheryStock,250-36+3*1.2)
 near(whole.state.farm.habitats[2].fractionalIHR,.08,'shared and own IHR accumulated once')
 eq(whole.state.selectionState~=nil,true)
 eq(D.fingerprint(T.advance(sliced,10)),D.fingerprint(sliced),'completed checkpoint is idempotent')
 local s=memory();s.permanent.epic.hold_to_hatch=0
 s.farm.habitats[2].population='249';s.farm.habitats[3]={typeIndex=1,capacity='500',population='0',assignedInTransit='0',fractionalIHR=0}
 local result=T.advance(T.begin(s,ORIGIN+300,{revision='weighted:1',pro=false,siloCapacityLevel=0,selectionSeed=123456}),10)
 local fractions={result.state.farm.habitats[2].fractionalIHR,result.state.farm.habitats[3].fractionalIHR};table.sort(fractions)
 near(fractions[1],.01);near(fractions[2],.02,'donation goes to one weighted target, never equal split')
end
-- Checkpoint restored into a new owner must not resume the previous held intention.
do
 local h=harness(function(p)p.permanent.epic.hold_to_hatch=15 end)
 h.input('start',1);h.now+=1200
 local first=h.b:_simulationAdvance(h.b:getPlayer('1'),h.p(),{kind='TimeAdvance',targetMs=h.now,budget=1})
 eq(first.complete,false)
 local watermark=first.profile.farm.hatchGroupSequence
 h.restart();eq(h.b:playerJoined('1',first.profile).status,'JOINED');h.step(0)
 eq(h.p().farm.hatchGroupSequence,watermark,'old owner checkpoint cannot breed further chickens')
 eq(h.b:getPlayer('1').hatchingRuntime.held,false)
end
fs.writeFile('build/farm-gaps-results.json',serde.encode('json',{status='PASS',level='L',assertions=count,studioTested=false,dataStoreTested=false},true))
print(string.format('Farm integration gaps #66-70: %d assertions PASS',count))
