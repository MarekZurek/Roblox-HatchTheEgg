--!nocheck
local C=require("../../src/shared/NumericCodec")
local D=require("../../src/server/PersistenceData")
local Catalog=require("../../src/server/CatalogRegistry").new(C,require("../../src/server/CatalogRegistry/Data"),{mode="INTERNAL_TEST_ONLY"})
local M=require("../../src/server/FarmMath/production_research").new(C,Catalog,{mode="INTERNAL_TEST_ONLY"})
local P=require("../../src/server/FarmMath/PopulationMath").new(C)
local H=require("../../src/server/FarmMath/hatching_rcb").new(C,P,D,{mode="INTERNAL_TEST_ONLY"})
local I=require("../../src/server/FarmMath/ihr").new(C,P)
local T=require("../../src/server/TimelineSimulation").new(C,M,H,I,D,{mode="INTERNAL_TEST_ONLY"})
local fs,serde=require("@lune/fs"),require("@lune/serde")
local assertions=0
local function eq(a,b)assertions+=1;assert(a==b,tostring(a).." != "..tostring(b))end
local function reject(fn)eq(pcall(fn),false)end
local function state(pop)
 local h={}
 for i=1,4 do h[i]={typeIndex=if i==1 then 0 else -1,capacity=if i==1 then "250" else "0",population=if i==1 then (pop or "100") else "0",assignedInTransit="0",fractionalIHR=0} end
 return {farm={cash=10,habitats=h,hatcheryStock=0,runningCount="0",hatchGroupSequence="0",groups={},commonLevels={},vehicleTypes={0},siloOwned=1},accounting={prestigeSessionArchivedCash=20,prestigeExtraEarnings=30,lastBaseEarnings=40,currentFarmCash=100,lastCashEarned=50},settledWallThrough=1000}
end
local function cfg(pro)return {revision="neutral:1",siloCapacityLevel=0,pro=pro or false}end
local function all(s,ms,c) local cp=T.begin(s,ms,c or cfg()); while not cp.done do cp=T.advance(cp,50000) end; return cp end
local original=state();local before=D.fingerprint(original)
local cp=T.begin(original,2000,cfg());eq(cp.mode,"ONLINE");eq(cp.productionSeconds,1);eq(cp.stepIndex,0)
local mid=T.advance(cp,1);eq(mid.phase,"AFTER_PRODUCTION");eq(mid.stepDt,.3);eq(mid.elapsedSeconds,0);eq(mid.state.farm.cash,10.5)
eq(mid.state.accounting.currentFarmCash,100.5);eq(mid.state.accounting.lastBaseEarnings,120);eq(mid.state.accounting.lastCashEarned,50.5)
eq(mid.state.accounting.prestigeSessionArchivedCash,20);eq(mid.state.accounting.prestigeExtraEarnings,30)
local saved=serde.decode("json",serde.encode("json",T.encodeCheckpoint(mid)))
local resumed=T.advance(T.decodeCheckpoint(saved),100)
local uninterrupted=T.advance(cp,100)
eq(D.fingerprint(resumed),D.fingerprint(uninterrupted));eq(uninterrupted.stepIndex,4);eq(uninterrupted.done,true);eq(uninterrupted.state.settledWallThrough,2000)
eq(D.fingerprint(original),before);eq(cp.stepIndex,0)
eq(uninterrupted.state.farm.hatcheryStock,2.9999999999999996)
local sliced=cp
while not sliced.done do sliced=T.decodeCheckpoint(serde.decode("json",serde.encode("json",T.encodeCheckpoint(T.advance(sliced,1))))) end
eq(D.fingerprint(sliced),D.fingerprint(uninterrupted))
eq(D.fingerprint(T.advance(sliced,10)),D.fingerprint(sliced))
-- Independent 0.3,0.3,0.3,remaining reference operations, not output-derived expectations.
local remaining=1;local cash=10;local stock=0
while remaining>0 do local dt=math.min(remaining,.3);cash+=math.min((100*(1/30))*dt,(500/60)*dt)*.50;stock=math.min(250,stock+3*dt);remaining-=dt end
eq(uninterrupted.state.farm.cash,cash);eq(uninterrupted.state.farm.hatcheryStock,stock)
-- Exact threshold: short reconnect produces without silos; away zero cap closes whole period and groups.
local zero=state();zero.farm.siloOwned=0
local sixty=all(zero,61000);eq(sixty.mode,"ONLINE");eq(sixty.productionSeconds,60);eq(sixty.state.farm.cash>10,true)
local away=all(zero,61001);eq(away.mode,"AWAY");eq(away.productionSeconds,0);eq(away.stepIndex,0);eq(away.state.farm.cash,10);eq(away.state.settledWallThrough,61001)
eq(all(away.state,61001).state.farm.cash,10)
local limited=all(state(),1000+25000*1000);eq(limited.mode,"AWAY");eq(limited.productionSeconds,21600);eq(limited.state.settledWallThrough,1000+25000*1000)
local pro=all(state(),62000,cfg(true));local free=all(state(),62000,cfg(false))
eq((pro.state.farm.cash-10)>(free.state.farm.cash-10),true)
-- Already-ready groups settle before first production; within-step arrivals occur only after production.
local function grouped(due)
 local s=state("0");s.farm.runningCount="1";s.farm.hatchGroupSequence="1";s.farm.habitats[1].assignedInTransit="1"
 s.farm.groups["hatch:1"]={groupId="hatch:1",count="1",targetSlot=1,routeVersion="test",startInstantMs=0,travelDurationSeconds=due,status="IN_TRANSIT"}
 return s
end
local arriving=T.advance(T.begin(grouped(1.3),1600,cfg()),1)
eq(arriving.state.farm.cash,10);eq(arriving.state.farm.habitats[1].population,"0")
arriving=T.advance(arriving,1);eq(arriving.state.farm.habitats[1].population,"1");eq(arriving.state.farm.runningCount,"0")
arriving=T.advance(arriving,1);eq(arriving.state.farm.cash,10+(1/30*.3*.50))
local ready=all(grouped(1),1300);eq(ready.state.farm.cash,10+(1/30*.3*.50))
local awayGroup=grouped(100);awayGroup.farm.siloOwned=0;local closed=all(awayGroup,61001)
eq(closed.state.farm.habitats[1].population,"1");eq(closed.state.farm.runningCount,"0");eq(closed.state.farm.cash,10)
-- Common IHR rate is 2/min at level1; growth affects following production only.
local growth=state("0");growth.farm.commonLevels.internal_hatchery1=1;growth.farm.habitats[1].fractionalIHR=.995
local growthMid=T.advance(T.begin(growth,1600,cfg()),1);eq(growthMid.state.farm.cash,10)
local growthDone=T.advance(growthMid,1);eq(growthDone.state.farm.habitats[1].population,"1")
eq(T.advance(growthDone,1).state.farm.cash>10,true)
local backward=all(state(),999);eq(backward.clockDiscrepancy,true);eq(backward.state.settledWallThrough,1000);eq(backward.state.farm.cash,10)
reject(function()T.begin(state(),2000,{revision="x",siloCapacityLevel=0,pro=false,sharing=1})end)
local active=state();active.effects={boosts={"x"}};reject(function()T.begin(active,2000,cfg())end)
local invalid=D.copy(mid);invalid.stepDt=.1;reject(function()T.advance(invalid,1)end)
invalid=D.copy(cp);invalid.elapsedSeconds=1;reject(function()T.advance(invalid,1)end)
reject(function()T.advance(cp,-1)end)
reject(function()T.begin(state(),math.huge,cfg())end)
local wire=T.encodeCheckpoint(cp);wire.payload.elapsedSeconds=0;reject(function()T.decodeCheckpoint(wire)end)
fs.writeFile("build/timeline-results.json",serde.encode("json",{suite="timeline",assertions=assertions,status="PASS"},true))
print("timeline: "..assertions.." assertions PASS")
