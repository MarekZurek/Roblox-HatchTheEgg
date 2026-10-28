-- Independent interval-income oracles for #61, with the actual simulation and Bootstrap.
local C=require('../../src/shared/NumericCodec')
local D=require('../../src/server/PersistenceData')
local Catalog=require('../../src/server/CatalogRegistry').new(C,require('../../src/server/CatalogRegistry/Data'),{mode='INTERNAL_TEST_ONLY'})
local M=require('../../src/server/FarmMath/production_research').new(C,Catalog,{mode='INTERNAL_TEST_ONLY'})
local P=require('../../src/server/FarmMath/PopulationMath').new(C)
local H=require('../../src/server/FarmMath/hatching_rcb').new(C,P,D,{mode='INTERNAL_TEST_ONLY'})
local I=require('../../src/server/FarmMath/ihr').new(C,P)
local T=require('../../src/server/TimelineSimulation').new(C,M,H,I,D,{mode='INTERNAL_TEST_ONLY'})
local B=require('../../src/server/Bootstrap')
local S=require('../../src/server/ProfileSchema').new(C)
local fs,serde=require('@lune/fs'),require('@lune/serde')
local assertions=0
local function eq(a,b,label)assertions+=1;assert(a==b,(label or '')..' expected '..tostring(b)..' got '..tostring(a))end
local function near(a,b,label)assertions+=1;assert(math.abs(a-b)<=math.max(1e-12,math.abs(b)*2e-12),(label or '')..' expected '..tostring(b)..' got '..tostring(a))end
local ORIGIN=1000000
local function state()
 local habs={}
 for n=1,4 do habs[n]={typeIndex=if n==1 then 0 else -1,capacity=if n==1 then '250' else '0',population=if n==1 then '100' else '0',assignedInTransit='0',fractionalIHR=0}end
 return {settledWallThrough=ORIGIN,farm={cash=0,eggIndex=0,habitats=habs,hatcheryStock=0,runningCount='0',hatchGroupSequence='0',groups={},commonLevels={},vehicleTypes={0},siloOwned=1},
  accounting={prestigeSessionArchivedCash=0,prestigeExtraEarnings=0,lastBaseEarnings=0,currentFarmCash=0,lastCashEarned=0}}
end
local function event(a,b,m,kind)return {type=kind or 'earnings',startTimeMs=ORIGIN+a,deadlineMs=ORIGIN+b,multiplier=m}end
local function config(events,pro)return {revision='event-regression:1',siloCapacityLevel=0,pro=pro==true,liveEvents=events or {}}end
local function run(s,events,duration,pro)return T.advance(T.begin(s,ORIGIN+duration,config(events,pro)),100000)end
-- Base 100 chickens * (1 egg/30s) * $0.25 = $5/6 per second. No output-derived oracle.
local RATE=5/6
for _,case in {
 {events={event(0,100,3)},area=.5}, -- exact issue reproduction: 0.1*3+0.2
 {events={event(100,300,3)},area=.7},
 {events={event(100,200,3)},area=.5},
 {events={event(-100,0,3)},area=.3}, -- [start,end): already ended
 {events={event(300,500,3)},area=.3}, -- starts at step end
 {events={event(0,300,3)},area=.9},
 {events={event(100,100,99)},area=.3},
 {events={event(200,100,99)},area=.3}, -- empty window
 {events={event(0,100,0)},area=.2},
 {events={event(0,100,0),event(100,200,0),event(200,300,0)},area=0},
 {events={event(0,100,3),event(100,300,2,'earnings-boost')},area=.7},
 -- Product of simultaneously active events, not product of independent averages.
 {events={event(0,200,2),event(100,300,3)},area=1.1},
 {events={{type='earnings',startTimeMs=ORIGIN,durationSeconds=.1,multiplier=3}},area=.5},
 {events={event(0,100,7,'prestige'),event(0,100,9,'ihr'),event(0,100,99,'sale')},area=.3},
} do
 local s=state();local before=D.fingerprint(s)
 local result=run(s,case.events,300)
 near(result.state.farm.cash,RATE*case.area,'weighted earnings')
 near(result.state.accounting.currentFarmCash,RATE*case.area,'prestige income base')
 near(result.state.accounting.lastCashEarned,RATE*case.area,'earned accumulator')
 eq(result.stepIndex,1,'event boundaries do not add simulation steps')
 eq(D.fingerprint(s),before,'input immutable')
end
do
 local result=run(state(),{event(350,450,3)},450)
 near(result.state.farm.cash,RATE*.65,'short final step weighted by its actual duration')
 eq(result.stepIndex,2,'short final step adds no event substeps')
 local reversed=run(state(),{event(100,300,3),event(0,200,2)},300)
 near(reversed.state.farm.cash,RATE*1.1,'event ordering does not change interval semantics')
end
-- Absolute epochs, including sub-ms event windows; use relative event offsets internally.
do
 local s=state();local origin=1790000000000;s.settledWallThrough=origin
 local result=T.advance(T.begin(s,origin+300,config({{type='earnings',startTimeMs=origin,deadlineMs=origin+100,multiplier=3}})),10)
 near(result.state.farm.cash,5/12,'realistic epoch interval')
 local fractional=run(state(),{event(0,100.5,3)},300)
 near(fractional.state.farm.cash,RATE*(.1005*3+.1995),'fractional milliseconds not floored')
end
-- Legacy VD is inert across deadline boundaries. Boost decays once per 0.3s.
for _,vdEnd in {100,300,301} do
 local s=state();s.effects={videoDoublerEndsAtMs=ORIGIN+vdEnd,boosts={{id='fixture',dimension_raw=2,effect=10,remainingSeconds=.1},{id='fixture-soul',dimension_raw=9,effect=5,remainingSeconds=.1}}}
 local result=run(s,{event(0,100,3)},300)
 local vd=1 -- retired deadline inert
 near(result.state.farm.cash,(5/12)*10*vd,'VD point rule distinct from weighted event')
 near(result.state.accounting.prestigeExtraEarnings,(5/12)*10*vd*4,'prestige extra uses actual earned income')
 eq(#result.state.effects.boosts,0,'expired boost removed once after full step')
 eq(result.stepIndex,1)
end
-- Boundaries must not insert extra IHR phases, which would produce new chickens too early.
do
 local s=state();s.farm.habitats[1].population='0';s.farm.habitats[1].fractionalIHR=.995;s.farm.commonLevels.internal_hatchery1=1
 local result=run(s,{event(0,100,3)},300)
 eq(result.state.farm.cash,0,'new IHR chicken cannot produce in the same step')
 eq(result.state.farm.habitats[1].population,'1','IHR advances once')
 eq(result.stepIndex,1)
end
-- Frozen checkpoint context, phase restart and bitwise agreement, not reapplying paid production.
do
 local sourceConfig=config({event(0,100,3),event(400,650,2)})
 local cp=T.begin(state(),ORIGIN+1000,sourceConfig)
 sourceConfig.liveEvents[1].multiplier=999
 local whole=T.advance(cp,100)
 local sliced=cp
 while not sliced.done do
  sliced=T.decodeCheckpoint(serde.decode('json',serde.encode('json',T.encodeCheckpoint(T.advance(sliced,1)))))
 end
 eq(D.fingerprint(sliced),D.fingerprint(whole),'all phase checkpoint round trips match')
 near(whole.state.farm.cash,RATE*(1+.2+.25),'independent full interval oracle')
 eq(D.fingerprint(T.advance(sliced,10)),D.fingerprint(sliced),'done checkpoint cannot pay twice')
 local afterProduction=T.advance(cp,1);local snapshot=afterProduction.state.farm.cash
 local afterGrowth=T.advance(T.decodeCheckpoint(T.encodeCheckpoint(afterProduction)),1)
 eq(afterGrowth.state.farm.cash,snapshot,'resume AFTER_PRODUCTION does not repay event income')
 eq(afterGrowth.stepIndex,1)
end
-- Away caps: 3600 seconds of production only. Event has already ended at return.
for _,pro in {false,true} do
 local s=state();local result=run(s,{event(0,100,3),event(3599900,3600100,3),event(3600100,4000000,50)},4000000,pro)
 local factor=if pro then 1 else .5
 near(result.state.farm.cash,RATE*(3600+.2+.2)*factor,'event integration clipped by silo limit')
 eq(result.productionSeconds,3600);eq(result.state.settledWallThrough,ORIGIN+4000000)
 local again=T.advance(T.begin(result.state,ORIGIN+4000000,config({},pro)),2)
 eq(again.state.farm.cash,result.state.farm.cash,'settled away period not paid twice')
end
do
 local s=state();s.farm.siloOwned=0
 local result=run(s,{event(0,100,3)},61001)
 eq(result.state.farm.cash,0);eq(result.stepIndex,0);eq(result.state.settledWallThrough,ORIGIN+61001)
end
-- Actual Bootstrap simulation bridge: no direct leaf-method test bypassing event config.
do
 local now=ORIGIN
 local b=B.new({storageMode='INTERNAL_TEST_ONLY',clock={utcNowMs=function()return now end,elapsedNowSeconds=function()return (now-ORIGIN)/1000 end},liveEvents={event(0,100,3)}})
 local p=S.createReference('1',ORIGIN);p.farm.habitats[1].population='100'
 eq(b:playerJoined('1',p).status,'JOINED')
 now+=300;b:tick(.3)
 local working=b:getCoordinator('1').snapshots().working
 near(C.BigAmount.decode(working.farm.cash),5/12,'Bootstrap uses weighted event calculation')
 near(C.BigAmount.decode(working.accounting.currentFarmCash),5/12)
end
fs.writeFile('build/event-time-results.json',serde.encode('json',{status='PASS',level='L',assertions=assertions,studioTested=false,dataStoreTested=false},true))
print(string.format('Historical earnings event time: %d assertions PASS',assertions))
