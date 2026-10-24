--!nocheck
local C=require("../../src/shared/NumericCodec")
local Data=require("../../src/server/PersistenceData")
local P=require("../../src/server/FarmMath/PopulationMath").new(C)
local H=require("../../src/server/FarmMath/hatching_rcb").new(C,P,Data,{mode="INTERNAL_TEST_ONLY"})
local V=require("./population_vectors")
local fs,serde=require("@lune/fs"),require("@lune/serde")
local count=0
local function eq(a,b,label)count+=1;assert(a==b,(label or "").." expected "..tostring(b).." got "..tostring(a))end
local function near(a,b,tolerance)count+=1;assert(math.abs(a-b)<=tolerance,"RCB reference mismatch")end
local function bad(code,fn)local ok,err=pcall(fn);eq(ok,false,code);count+=1;assert(string.find(tostring(err),code,1,true),tostring(err))end
local function hab(cap,pop,res)return {typeIndex=0,capacity=cap or "10",population=pop or "0",assignedInTransit=res or "0",fractionalIHR=0}end
local function empty()return {typeIndex=-1,capacity="0",population="0",assignedInTransit="0",fractionalIHR=0}end
local function farm()return {habitats={hab(),empty(),empty(),empty()},hatcheryStock=3,runningCount="0",hatchGroupSequence="0",groups={}}end
local function runtime()return {streamId="connection-1",lastInputSeq="0",held=false,holdElapsed=0}end
local function press(seq)return {kind="HatchPress",streamId="connection-1",inputSeq=seq or "1"}end
local function route()return {routeVersion="scene-1",startInstantMs=1000,travelDurationSeconds=0.25,snapshot={pathVersion="path-1"}}end
local function draw()return "0"end

for _,v in V do eq(P.modulo(v[1],v[2]),v[3],"independent uint64 remainder") end
bad("ZERO_DIVISOR",function()P.modulo("1","0")end)
bad("INVALID_UINT64_TEXT",function()P.modulo("01","2")end)
eq(C.ExactUInt.encode(P.vacancy(hab("10","9","2"))),"0")
eq(C.ExactUInt.encode(P.vacancy(hab("18446744073709551615","18446744073709551614"))),"1")
local slots={hab("10","10"),hab("10"),hab("10"),empty()}
eq(P.select(slots,"0"),2);eq(P.select(slots,"9"),2);eq(P.select(slots,"10"),3)
eq(P.select(slots,"18446744073709551615"),3)
eq(P.select({empty(),empty(),empty(),empty()},nil),nil)
bad("OVERFLOW",function()P.vacancies({hab("18446744073709551615"),hab("1"),empty(),empty()})end)
bad("INVALID_EMPTY_SLOT",function()P.vacancy({typeIndex=-1,capacity="1",population="0",assignedInTransit="0"})end)
do
	local f,r=farm(),runtime();local original=Data.fingerprint(f)
	local a,b,status,id=H.input(f,r,press(),draw,route)
	eq(status,"RELEASED");eq(id,"hatch:1");eq(a.hatcheryStock,2);eq(a.habitats[1].population,"0")
	eq(a.habitats[1].assignedInTransit,"1");eq(a.runningCount,"1");eq(a.hatchGroupSequence,"1")
	eq(Data.fingerprint(f),original);eq(r.lastInputSeq,"0");eq(b.lastInputSeq,"1")
	local duplicate,_,s=H.input(a,b,press(),draw,route);eq(s,"STALE_INPUT");eq(duplicate.hatcheryStock,2)
	local wrong=press("2");wrong.streamId="old";eq(select(3,H.input(a,b,wrong,draw,route)),"WRONG_STREAM")
	local early,earlyStatus=H.arrive(a,id,1.249999999);eq(earlyStatus,"NOT_DUE");eq(early.habitats[1].population,"0")
	local arrived,arrivedStatus=H.arrive(a,id,1.25);eq(arrivedStatus,"ARRIVED");eq(arrived.habitats[1].population,"1")
	eq(arrived.runningCount,"0");eq(arrived.habitats[1].assignedInTransit,"0");eq(arrived.groups[id],nil)
	local twice,twiceStatus=H.arrive(arrived,id,2);eq(twiceStatus,"ALREADY_CLOSED_OR_UNKNOWN");eq(twice.habitats[1].population,"1")
	local newer,newRuntime,_,newId=H.input(arrived,b,press("2"),draw,route);eq(newId,"hatch:2")
	local replayOld=H.arrive(newer,id,100);eq(replayOld.habitats[1].population,"1");eq(replayOld.runningCount,"1")
	local away=H.closeInFlightForAway(newer);eq(away.habitats[1].population,"2");eq(away.runningCount,"0")
	eq(Data.fingerprint(H.closeInFlightForAway(away)),Data.fingerprint(away))
	-- Input stream and hold state remain runtime data, not stored in the returned farm.
	eq(newer.input,nil);eq(newer.held,nil);eq(newRuntime.lastInputSeq,"2")
end
do
	local f,r=farm(),runtime();local calls=0
	local noDraw=function()calls+=1;return "0"end
	f.hatcheryStock=0.999
	local a,_,status=H.input(f,r,press(),noDraw,route);eq(status,"NO_STOCK");eq(a.hatcheryStock,0.999);eq(calls,0)
	f.hatcheryStock=1;f.habitats[1].population="10"
	a,_,status=H.input(f,r,press(),noDraw,route);eq(status,"NO_VACANCY");eq(a.hatcheryStock,1);eq(calls,0)
	f=farm();a,_,status=H.input(f,r,press(),draw,function()return nil end)
	eq(status,"ROUTE_UNAVAILABLE");eq(a.hatcheryStock,3);eq(a.runningCount,"0");eq(a.hatchGroupSequence,"0")
	bad("INVALID_DURATION",function()H.input(f,r,press(),draw,function()return {routeVersion="a",startInstantMs=1,travelDurationSeconds=0}end)end)
	bad("CALLBACK_YIELDED",function()H.input(f,r,press(),function()coroutine.yield();return"0"end,route)end)
	eq(f.hatcheryStock,3)
end
do
	eq(H.refill(0,250,3,0.3),0.8999999999999999)
	eq(H.refill(249.5,250,3,0.3),250);eq(H.refill(10,250,3,0),10)
	eq(H.holdRate(0),0);eq(H.holdRate(15),30)
	local f,r=farm(),runtime()
	local start={kind="HatchInput",streamId=r.streamId,inputSeq="1",state="start"}
	f,r=H.input(f,r,start,draw,route)
	local a,b,attempts,released=H.holdStep(f,r,0.3,0,draw,route)
	eq(attempts,0);eq(released,0);eq(a.hatcheryStock,3);eq(b.holdElapsed,0)
	a,b,attempts=H.holdStep(f,r,0.25,2,draw,route);eq(attempts,0);eq(b.holdElapsed,0.25)
	a,b,attempts=H.holdStep(a,b,0.25,2,draw,route);eq(attempts,0);eq(b.holdElapsed,0.5,"strict equality")
	a,b,attempts,released=H.holdStep(a,b,0.25,2,draw,route);eq(attempts,1);eq(released,1);eq(b.holdElapsed,0.25)
	local stop={kind="HatchInput",streamId=r.streamId,inputSeq="2",state="stop"}
	a,b=H.input(a,b,stop,draw,route);eq(b.held,false);eq(b.holdElapsed,0)
	local refresh={kind="HatchInput",streamId=r.streamId,inputSeq="3",state="refresh"}
	a,b=H.input(a,b,refresh,draw,route);eq(b.held,false)
	local stopped=H.holdStep(a,b,0.3,30,draw,route);eq(stopped.hatcheryStock,a.hatcheryStock)
	r.held=true;r.holdElapsed=C.Real64.roundFloat32(0.1)
	local _,d=H.holdStep(f,r,0,10,draw,route);eq(d.holdElapsed,r.holdElapsed)
	local threshold,_,at=H.holdStep(f,r,0.3,0.1,draw,route);eq(at,0);eq(threshold.hatcheryStock,3)
	r.holdElapsed=C.Real64.roundFloat32(1e20)
	bad("HOLD_TIME_STALL",function()H.holdStep(f,r,0.3,30,draw,route)end)
	bad("UNSUPPORTED_REFILL_INPUT",function()H.refill(251,250,3,0.3)end)
end
do
	eq(H.rcb("0",1,5,2),1);eq(H.rcb("10",1,5,2),1)
	eq(H.rcb("3",2,5,2),10);eq(H.rcb("3",0.5,5,99),0.125)
	near(H.rcb("10",1.1,5,2),5.1874849202,5e-11)
	eq(H.rcb("1000",1e300,5,2),10,"finite cap selects before overflow check")
	bad("NON_FINITE",function()H.rcb("5",2,5,math.huge)end)
	bad("NON_FINITE",function()H.rcb("2000",2,1e308,2)end)
end
do
	-- Cross-module seam: production sees only settled, then IHR affects the next call.
	local Registry=require("../../src/server/CatalogRegistry")
	local CatalogData=require("../../src/server/CatalogRegistry/Data")
	local catalog=Registry.new(C,CatalogData,{mode="INTERNAL_TEST_ONLY"})
	local F=require("../../src/server/FarmMath/production_research").new(C,catalog,{mode="INTERNAL_TEST_ONLY"})
	local I=require("../../src/server/FarmMath/ihr").new(C,P)
	local f,r=farm(),runtime();f.habitats[1].capacity="250"
	f,r=H.input(f,r,press(),draw,route)
	local function state(v)return {commonLevels={},habitatTypes={0,false,false,false},settledPopulation={v.habitats[1].population,"0","0","0"},vehicleTypes={0},rcbMultiplier=1}end
	eq(F.productionStep(state(f),0.3).producedEggs,0)
	f=H.arrive(f,"hatch:1",1.25)
	eq(F.productionStep(state(f),0.3).producedEggs,0.01)
	f.habitats=I.step(f.habitats,10,0.3,0)
	eq(f.habitats[1].population,"4");eq(F.productionStep(state(f),0.3).producedEggs,0.04)
	local Schema=require("../../src/server/ProfileSchema").new(C)
	local saved=Schema.createReference("1",1000)
	local clipped={hab("250","249"),empty(),empty(),empty()}
	local grown=I.step(clipped,10,0.3,0)
	eq(grown[1].fractionalIHR,2)
	saved.farm.habitats[1].population=grown[1].population
	saved.farm.habitats[1].fractionalIHR=C.Real64.encode(grown[1].fractionalIHR)
	eq(Schema.validate(saved,"1"),true,"actual clipped carry accepted by persistence schema")
end
local result={status="PASS",level="L",assertions=count,moduloVectors=#V,studioTested=false,dataStoreTested=false,realRouteTested=false,crossModuleSeam=true}
fs.writeFile("build/hatching-results.json",serde.encode("json",result,true))
print(serde.encode("json",result))
