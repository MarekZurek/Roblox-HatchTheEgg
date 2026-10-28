-- Independent behavioral regressions for #63-65 through real clients/server state.
local B=require('../../src/server/Bootstrap')
local Client=require('../../src/client/Bootstrap')
local C=require('../../src/shared/NumericCodec')
local D=require('../../src/server/PersistenceData')
local S=require('../../src/server/ProfileSchema').new(C)
local fs,serde=require('@lune/fs'),require('@lune/serde')
local assertions=0
local function eq(a,b,label)assertions+=1;assert(a==b,(label or '')..' expected '..tostring(b)..' got '..tostring(a))end
local function near(a,b,label)assertions+=1;assert(math.abs(a-b)<=math.max(1,math.abs(b))*2e-12,(label or '')..' expected '..tostring(b)..' got '..tostring(a))end
local ORIGIN=1000000
local function harness(mutate,events)
 local h={now=ORIGIN,records={},sent={}}
 h.store={read=function(key)return true,h.records[key] and D.copy(h.records[key])end,update=function(key,fn)
  if h.onWrite then local hook=h.onWrite;h.onWrite=nil;hook()end
  local next=fn(h.records[key] and D.copy(h.records[key]));if next then h.records[key]=D.copy(next)end
  if h.loseAck then h.loseAck=false;return false,'lost acknowledgement' end
  return true,next and D.copy(next)
 end}
 function h.restart()
  h.server=B.new({storageMode='INTERNAL_TEST_ONLY',store=h.store,clock={utcNowMs=function()return h.now end,elapsedNowSeconds=function()return (h.now-ORIGIN)/1000 end},liveEvents=events or {}})
 end
 h.restart()
 local p=S.createReference('1',h.now);p.farm.cash='1000000'
 if mutate then mutate(p) end
 eq(h.server:playerJoined('1',p).status,'JOINED')
 function h.state()local s=h.server:getCoordinator('1').snapshots();return s.working or s.durable end
 function h.client()
  local c
  c=Client.new({playerId='1',wire=function(packet)
   table.insert(h.sent,D.copy(packet));local response=h.server:dispatch('1',packet)
   if response then local ok,err=c:receive(response);eq(ok,true,tostring(err))end
  end})
  c:connect('fresh-client');return c
 end
 function h.command(kind,id,args)
  return h.server:dispatch('1',{protocolVersion=1,kind=kind,requestId=id,operationId=id,expectedRevision=h.state().meta.revision,args=args or {}})
 end
 function h.step(seconds)
  h.now+=seconds*1000;h.server:tick(seconds)
  local n=0
  while not h.server:getCoordinator("1").snapshots().ready do h.server:tick(0);n+=1;assert(n<1000,"settling stalled") end
 end
 return h
end
-- New intent after reconnect/process restart must not replay an old successful purchase.
do
 local h=harness();local c=h.client();local first,second,third
 c:buyResearch('comfy_nests',function(r)first=r end)
 eq(first.status,'APPLIED');eq(h.state().farm.common.comfy_nests,1)
 local oldPacket
 for _,p in h.sent do if p.kind=='BuyResearch' then oldPacket=D.copy(p) end end
 local firstCash=h.state().farm.cash
 c:destroy();h.server:playerLeaving('1');eq(h.server:playerJoined('1').status,'JOINED')
 c=h.client();c:buyResearch('comfy_nests',function(r)second=r end)
 eq(second.status,'APPLIED','new purchase after reconnect')
 eq(h.state().farm.common.comfy_nests,2)
 eq(first.operationId~=second.operationId,true,'new intent gets different ID')
 local secondCash=h.state().farm.cash
 eq(C.BigAmount.decode(secondCash)<C.BigAmount.decode(firstCash),true,'second price actually deducted')
 local oldReply=h.server:dispatch('1',oldPacket)
 eq(oldReply.status,'REPLAYED');eq(h.state().farm.cash,secondCash);eq(h.state().farm.common.comfy_nests,2)
 c:destroy();h.server:playerLeaving('1');h.restart();eq(h.server:playerJoined('1').status,'JOINED')
 c=h.client();c:buyResearch('comfy_nests',function(r)third=r end)
 eq(third.status,'APPLIED','new process keeps operation namespace unique')
 eq(h.state().farm.common.comfy_nests,3)
 eq(third.operationId~=first.operationId and third.operationId~=second.operationId,true)
 local current=h.state().farm.cash
 eq(h.server:dispatch('1',oldPacket).status,'REPLAYED');eq(h.state().farm.cash,current)
end
-- Generic commands also need unique IDs when a server process and client counters restart.
do
 local h=harness(function(p)p.accounting.currentFarmCash='1000000' end)
 local c=h.client();local first,second
 c:prestige(function(r)first=r end);eq(first.status,'APPLIED')
 c:destroy();h.server:playerLeaving('1');h.restart();eq(h.server:playerJoined('1').status,'JOINED')
 c=h.client();c:prestige(function(r)second=r end)
 eq(second.status,'APPLIED');eq(h.state().permanent.prestigeCount,'2')
 eq(first.operationId~=second.operationId,true,'generic command session namespace')
end
-- Prestige event is a collection multiplier at the action instant, not an earnings boost.
for _,case in {{offset=999,m=1},{offset=1000,m=4},{offset=1999,m=4},{offset=2000,m=1}} do
 local h=harness(function(p)p.accounting.currentFarmCash='1000000';p.farm.habitats[1].population='0' end,
  {{type='prestige-boost',multiplier=4,startTimeMs=ORIGIN+1000,deadlineMs=ORIGIN+2000}})
 h.now=ORIGIN+case.offset
 local r=h.command('Prestige','event-prestige')
 eq(r.status,'APPLIED')
 near(C.Real64.decode(h.state().permanent.SE),(1000000^.15)*case.m,'collection boundary [start,end)')
 eq(h.state().accounting.currentFarmCash,'0');eq(h.state().permanent.prestigeCount,'1')
 local after=h.state().permanent.SE;h.now=ORIGIN+3000
 eq(h.command('Prestige','event-prestige').status,'REPLAYED')
 eq(h.state().permanent.SE,after,'old result not repriced by later event state')
 eq(h.state().permanent.prestigeCount,'1')
end
do
 local h=harness(function(p)
  p.accounting.currentFarmCash='1000000';p.permanent.epic.prestige_bonus=10
  p.effects.boosts={{id='soul_beacon_blue_v2',dimension_raw=9,effect=5,remainingSeconds='10'}}
 end,{{type='prestige',multiplier=4,startTimeMs=ORIGIN,deadlineMs=ORIGIN+1000}})
 eq(h.command('Prestige','event-with-soul').status,'APPLIED')
 near(C.Real64.decode(h.state().permanent.SE),(1000000^.15)*2*4,'no second Soul Beacon multiplier')
 local bad=h.command('Prestige','forged-multiplier',{prestigeEventMult=999})
 eq(bad.admission,'NOT_ACCEPTED');eq(h.state().permanent.prestigeCount,'1')
end
-- Event changes at the storage callback: no reset under a now-invalid collection factor.
do
 local h=harness(function(p)p.accounting.currentFarmCash='1000000' end,
  {{type='prestige',multiplier=4,startTimeMs=ORIGIN,deadlineMs=ORIGIN+1000}})
 h.onWrite=function()h.now=ORIGIN+1000 end
 local r=h.command('Prestige','cross-deadline')
 eq(r.status,'REJECTED');eq(r.result.errorCode,'PRESTIGE_EVENT_CHANGED')
 eq(h.state().permanent.SE,'0');eq(h.state().accounting.currentFarmCash,'1000000')
 eq(h.state().permanent.prestigeCount,'0')
 eq(h.command('Prestige','new-decision').status,'APPLIED')
 near(C.Real64.decode(h.state().permanent.SE),1000000^.15)
end
-- An acknowledgement lost after commit must not reprice or repeat a successful reset.
do
 local h=harness(function(p)p.accounting.currentFarmCash='1000000' end,
  {{type='prestige',multiplier=4,startTimeMs=ORIGIN,deadlineMs=ORIGIN+1000}})
 h.loseAck=true
 h.command('Prestige','lost-prestige-ack')
 near(C.Real64.decode(h.records['player:1'].permanent.SE),(1000000^.15)*4)
 h.now=ORIGIN+120001
 eq(h.server:getCoordinator('1').recover('lost-prestige-ack').status,'ACQUIRED')
 eq(h.server:getCoordinator('1').setReady(true).status,'READY_SET')
 local replay=h.command('Prestige','lost-prestige-ack')
 eq(replay.status,'REPLAYED');near(C.Real64.decode(h.state().permanent.SE),(1000000^.15)*4)
 eq(h.state().permanent.prestigeCount,'1');eq(h.state().accounting.currentFarmCash,'0')
end
do
 local Progress=require('../../src/server/ProgressActions')
 local p=S.createReference('1',ORIGIN);p.accounting.currentFarmCash='1000000'
 local result=Progress.applyPrestige(p,{kind='Prestige',prestigeEventMult=999,args={prestigeEventMult=999}})
 near(C.Real64.decode(result.profile.permanent.SE),1000000^.15,'operation payload is not a collection authority')
end
-- Actual running chickens at the start of a step, with independent c/K expectations.
local function rcbProfile(p,n,common,epic)
 p.farm.cash='0';p.farm.habitats[1].population='100';p.farm.common=common or {excitable_chickens=25};p.permanent.epic=epic or {}
 p.farm.runningCount=tostring(n);p.farm.hatchGroupSequence=tostring(n);p.farm.habitats[1].assignedInTransit=tostring(n)
 if n>0 then p.farm.groups['hatch:'..n]={groupId='hatch:'..n,count=tostring(n),targetSlot=1,routeVersion='regression',startInstantMs=ORIGIN,travelDurationSeconds=.3,status='IN_TRANSIT'} end
end
for _,case in {
 {n=0,common={excitable_chickens=25},epic={},c=1.025,k=5},
 {n=10,common={excitable_chickens=25},epic={},c=1.025,k=5},
 {n=100,common={excitable_chickens=25},epic={},c=1.025,k=5},
 {n=100,common={excitable_chickens=25,coordinated_clucking=50},epic={},c=1.025,k=15},
 {n=10,common={},epic={epic_clucking=20},c=1.02,k=5},
 {n=10,common={excitable_chickens=25},epic={epic_clucking=20},c=1.025*1.02,k=5},
 {n=100,common={excitable_chickens=25},epic={epic_multiplier=1},c=1.025,k=7},
 {n=100,common={},epic={epic_multiplier=100},c=1,k=205},
} do
 local h=harness(function(p)rcbProfile(p,case.n,case.common,case.epic)end)
 local view=h.server:dispatch('1',{protocolVersion=1,kind='Bootstrap',requestId='rcb-view'})
 local multiplier=case.k
 near(C.BigAmount.decode(view.view.farm.cashIncomePerSecond),(5/3)*multiplier,'HUD uses actual RCB')
 h.step(.3)
 near(C.BigAmount.decode(h.state().farm.cash),.50*multiplier,'step begins with running population')
 eq(h.state().farm.runningCount,'0','arrival closes running group after production')
 local before=C.BigAmount.decode(h.state().farm.cash)
 h.step(.3)
 local sold=math.min((100+case.n)/30,5000/60)
 near(C.BigAmount.decode(h.state().farm.cash)-before,sold*.50*.3*multiplier,'passive multiplier retained after arrival')
end
-- RCB composes once with existing pets/boosts (legacy VD inert) and the historical earnings event.
do
 local h=harness(function(p)
  rcbProfile(p,10)
  p.inventory.pets.dog={uid='dog',speciesId='farmer_dog',tier=1,variant='normal',locked=false}
  p.inventory.equipped={'dog'}
  p.effects={videoDoublerEndsAtMs=ORIGIN+1000,boosts={{id='jimbos_blue_v2',remainingSeconds='10'},{id='soul_beacon_blue_v2',remainingSeconds='10'}}}
 end,{{type='earnings',multiplier=3,startTimeMs=ORIGIN,deadlineMs=ORIGIN+100}})
 h.step(.3)
 local income=.50*5*1.5*3*(5/3) -- retired VD has no factor
 near(C.BigAmount.decode(h.state().farm.cash),income,'RCB composed exactly once')
 near(C.BigAmount.decode(h.state().accounting.prestigeExtraEarnings),income*4,'actual earnings feed Soul Beacon accumulator')
end
-- Checkpoint at every phase: in-flight RCB is preserved until arrival and never repaid.
do
 local Catalog=require('../../src/server/CatalogRegistry').new(C,require('../../src/server/CatalogRegistry/Data'),{mode='INTERNAL_TEST_ONLY'})
 local M=require('../../src/server/FarmMath/production_research').new(C,Catalog,{mode='INTERNAL_TEST_ONLY'})
 local P=require('../../src/server/FarmMath/PopulationMath').new(C)
 local H=require('../../src/server/FarmMath/hatching_rcb').new(C,P,D,{mode='INTERNAL_TEST_ONLY'})
 local I=require('../../src/server/FarmMath/ihr').new(C,P)
 local T=require('../../src/server/TimelineSimulation').new(C,M,H,I,D,{mode='INTERNAL_TEST_ONLY'})
 local p=S.createReference('1',ORIGIN);rcbProfile(p,10)
 local farm=D.copy(p.farm);farm.cash=0;farm.hatcheryStock=250;farm.commonLevels=farm.common;farm.vehicleTypes={0}
 for i,hab in farm.habitats do hab.capacity=if i==1 then '250' else '0';hab.fractionalIHR=0 end
 local cp=T.begin({settledWallThrough=ORIGIN,farm=farm,permanent=p.permanent,accounting={prestigeSessionArchivedCash=0,currentFarmCash=0,prestigeExtraEarnings=0,lastBaseEarnings=0,lastCashEarned=0}},ORIGIN+600,{revision='rcb-checkpoint:1',pro=false,siloCapacityLevel=0})
 local whole=T.advance(cp,100);local sliced=cp
 while not sliced.done do sliced=T.decodeCheckpoint(serde.decode('json',serde.encode('json',T.encodeCheckpoint(T.advance(sliced,1))))) end
 eq(D.fingerprint(sliced),D.fingerprint(whole),'checkpoint round trips match uninterrupted RCB')
 near(whole.state.farm.cash,.50*5+(110/30)*.50*.3*5)
 eq(whole.state.farm.runningCount,'0')
 eq(D.fingerprint(T.advance(sliced,10)),D.fingerprint(sliced),'completed checkpoint does not repeat income')
end
-- Away closes running groups before production, and does not preserve active RCB.
do
 local h=harness(function(p)rcbProfile(p,10)end);h.step(61)
 near(C.BigAmount.decode(h.state().farm.cash),(110/30)*.50*61*.5*5,'away mode retains passive multiplier')
 eq(h.state().farm.runningCount,'0')
end
fs.writeFile('build/session-prestige-rcb-results.json',serde.encode('json',{status='PASS',level='L',assertions=assertions,studioTested=false,dataStoreTested=false},true))
print(string.format('Session IDs, prestige collection and active RCB: %d assertions PASS',assertions))
