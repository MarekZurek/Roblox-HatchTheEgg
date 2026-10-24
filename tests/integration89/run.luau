--!nocheck
-- Test-only wire/memory bridge; not the production IMP-15 integration adapter.
local C=require("../../src/shared/NumericCodec")
local Data=require("../../src/server/PersistenceData")
local Schema=require("../../src/server/ProfileSchema").new(C)
local Repo=require("../../src/server/SessionRepository")
local Coordinator=require("../../src/server/PlayerCoordinator")
local Timeline=require("../../src/server/TimelineSimulation")
local Catalog=require("../../src/server/CatalogRegistry").new(C,require("../../src/server/CatalogRegistry/Data"),{mode="INTERNAL_TEST_ONLY"})
local Production=require("../../src/server/FarmMath/production_research").new(C,Catalog,{mode="INTERNAL_TEST_ONLY"})
local Population=require("../../src/server/FarmMath/PopulationMath").new(C)
local Hatching=require("../../src/server/FarmMath/hatching_rcb").new(C,Population,Data,{mode="INTERNAL_TEST_ONLY"})
local IHR=require("../../src/server/FarmMath/ihr").new(C,Population)
local T=Timeline.new(C,Production,Hatching,IHR,Data,{mode="INTERNAL_TEST_ONLY"})
local fs,serde=require("@lune/fs"),require("@lune/serde")
local assertions=0
local function eq(a,b,label) assertions+=1;assert(a==b,(label or "").." expected "..tostring(b).." got "..tostring(a)) end
local function equalData(a,b,label)eq(Data.fingerprint(a),Data.fingerprint(b),label)end
local function harness()
	local h={records={},now=1000000,elapsed=0,serial=0,updates=0,reads=0}
	function h.advance(ms)h.now+=ms;h.elapsed+=ms/1000 end
	h.clock={utcNowMs=function()return h.now end,elapsedNowSeconds=function()return h.elapsed end}
	h.store={read=function(key)h.reads+=1;return true,Data.copy(h.records[key])end,
		update=function(key,callback)
			h.updates+=1
			local candidate=callback(if h.records[key] then Data.copy(h.records[key]) else nil)
			if candidate then h.records[key]=Data.copy(candidate)end
			if h.loseResponse then h.loseResponse=false;return false,"saved response lost"end
			return true,if candidate then Data.copy(candidate) else nil
		end}
	h.repo=Repo.new({mode="INTERNAL_TEST_ONLY",codec=C,data=Data,schema=Schema,store=h.store,clock=h.clock,
		encodeJson=function(v)return serde.encode("json",v)end,tokenFactory=function()h.serial+=1;return "integration-"..h.serial end})
	local opened=h.repo.acquire("1");eq(opened.status,"ACQUIRED");h.handle=opened.handle
	return h
end
local numericAccounting={"prestigeSessionArchivedCash","prestigeExtraEarnings","lastBaseEarnings","currentFarmCash","lastCashEarned"}
local function neutralProfile(profile)
	-- The narrow test adapter must not hide active profile effects from a neutral
	-- timeline by dropping their sections during wire -> memory conversion.
	for key,value in profile.effects do
		assert(key=="boosts" and type(value)=="table" and next(value)==nil,"TEST_ADAPTER_UNSUPPORTED_EFFECT")
	end
	assert(next(profile.inventory.equipped)==nil,"TEST_ADAPTER_UNSUPPORTED_EFFECT")
end
local function memory(profile)
	neutralProfile(profile)
	local f=Data.copy(profile.farm)
	f.cash=C.BigAmount.decode(f.cash);f.hatcheryStock=C.Real64.decode(f.hatcheryStock)
	f.commonLevels=Data.copy(f.common);f.vehicleTypes={}
	for _,vehicle in f.vehicles do table.insert(f.vehicleTypes,vehicle.typeIndex)end
	local types={};for i,hab in f.habitats do types[i]=if hab.typeIndex==-1 then false else hab.typeIndex end
	local capacities=Production.capacities(f.commonLevels,types)
	for i,hab in f.habitats do hab.capacity=tostring(capacities[i]);hab.fractionalIHR=C.Real64.decode(hab.fractionalIHR)end
	local a=Data.copy(profile.accounting);for _,key in numericAccounting do a[key]=C.BigAmount.decode(a[key])end
	return {farm=f,accounting=a,settledWallThrough=profile.timeline.settledWallThrough}
end
local function wire(profile,state,checkpoint)
	local p=Data.copy(profile)
	p.farm=Data.copy(state.farm);p.farm.cash=C.BigAmount.encode(p.farm.cash);p.farm.hatcheryStock=C.Real64.encode(p.farm.hatcheryStock)
	for _,hab in p.farm.habitats do hab.fractionalIHR=C.Real64.encode(hab.fractionalIHR)end
	p.accounting=Data.copy(state.accounting);for _,key in numericAccounting do p.accounting[key]=C.BigAmount.encode(p.accounting[key])end
	p.timeline.settledWallThrough=state.settledWallThrough
	p.timeline.integrationCheckpoint=checkpoint
	return p
end
local config={revision="integration-neutral:1",siloCapacityLevel=0,pro=false}
local function seed(h)
	local p=h.handle.snapshot
	p.farm.cash="10";p.farm.habitats[1].population="30"
	p.farm.common={internal_hatchery1=1}
	p.accounting.currentFarmCash="100";p.accounting.prestigeSessionArchivedCash="200"
	p.accounting.prestigeExtraEarnings="7";p.accounting.lastBaseEarnings="300"
	h.records[h.handle.key]=Data.copy(p)
end
local function simulation(profile,request)
	neutralProfile(profile)
	local cp=if profile.timeline.integrationCheckpoint then T.decodeCheckpoint(profile.timeline.integrationCheckpoint)
		else T.begin(memory(profile),request.targetMs,config)
	cp=T.advance(cp,request.budget)
	return {profile=wire(profile,cp.state,T.encodeCheckpoint(cp)),complete=cp.done}
end
local function actor(h,apply)
	return Coordinator.new({mode="INTERNAL_TEST_ONLY",codec=C,data=Data,repository=h.repo,handle=h.handle,clock=h.clock,maxQueue=8,
		simulation={advance=simulation},domain={apply=apply or function(p)return {profile=p,result={accepted=true},validate=function()return true end}end}})
end
local function operation(id,revision)
	return {kind="IntegrationCheckpoint",operationId=id,args={},expectedRevision=revision or "0"}
end
-- A one-second offline/online-independent oracle with 30 settled hens:
-- 1 egg/sec * 0.25 cash/egg. Wallet and cumulative earnings start differently.
do
	local h=harness();seed(h)
	local s=memory(h.handle.snapshot)
	local a=T.advance(T.begin(s,h.now+1000,config),100)
	eq(a.done,true);eq(a.state.farm.cash,10.249999999999998)
	eq(a.state.accounting.currentFarmCash,100.25000000000001)
	eq(a.state.accounting.prestigeSessionArchivedCash,200)
	eq(a.state.accounting.prestigeExtraEarnings,7)
	eq(a.state.accounting.lastBaseEarnings,300.225,"manager runs before final 0.1sec production")
	local sliced=T.advance(T.begin(s,h.now+1000,config),1)
	eq(sliced.done,false);eq(sliced.phase,"AFTER_PRODUCTION")
	local halfway=serde.decode("json",serde.encode("json",T.encodeCheckpoint(sliced)))
	sliced=T.advance(T.decodeCheckpoint(halfway),100)
	equalData(sliced,a,"mid-phase restart preserves whole computation")
	eq(s.farm.cash,10,"input unchanged")
end
-- Actual single-writer -> Timeline -> SessionRepository. No fake simulation math.
do
	local h=harness();seed(h);local c=actor(h)
	eq(c.setReady(true).status,"READY_SET")
	eq(c.submit(operation("timeline"),{targetMs=h.now+1000,budget=100}).status,"PENDING")
	eq(c.drain().results[1].status,"APPLIED")
	local p=h.records[h.handle.key]
	eq(p.farm.cash,C.BigAmount.encode(10.249999999999998));eq(p.accounting.currentFarmCash,C.BigAmount.encode(100.25000000000001))
	eq(p.timeline.settledWallThrough,h.now+1000);eq(p.meta.revision,"1")
	eq(p.operations.timeline.result.accepted,true)
	local writes=h.updates
	eq(c.submit(operation("timeline","999")).status,"REPLAYED")
	eq(c.query("timeline").status,"REPLAYED");eq(h.updates,writes)
	eq(c.snapshots().queued,0)
end
-- A lost acknowledgement freezes further commands, while the durable economic
-- effect, cursor and operation result remain one atomic record.
do
	local h=harness();seed(h);local calls=0
	local c=actor(h,function(p)calls+=1;return {profile=p,result={calls=calls},validate=function()return true end}end)
	c.setReady(true);c.submit(operation("lost"),{targetMs=h.now+1000,budget=100})
	h.loseResponse=true
	eq(c.drain().results[1].status,"UNKNOWN");eq(calls,1)
	eq(c.snapshots().working,nil);eq(c.snapshots().ready,false)
	eq(h.records[h.handle.key].farm.cash,C.BigAmount.encode(10.249999999999998))
	eq(h.records[h.handle.key].timeline.settledWallThrough,h.now+1000)
	eq(c.submit(operation("other","1")).status,"NOT_ACCEPTED")
	local writes=h.updates
	eq(c.query("lost").status,"REPLAYED");eq(calls,1);eq(h.updates,writes)
	h.advance(120000)
	eq(c.recover("lost").status,"ACQUIRED")
	eq(c.submit(operation("lost","999")).status,"REPLAYED");eq(calls,1)
	eq(h.records[h.handle.key].farm.cash,C.BigAmount.encode(10.249999999999998))
	eq(c.snapshots().queued,0)
end
-- A real saved AFTER_PRODUCTION checkpoint resumes under a new lease owner.
-- Settling permits technical ticks/checkpoints, not ordinary player commands.
do
	local h=harness();seed(h)
	local source=memory(h.handle.snapshot)
	local target=h.now+61000
	local uninterrupted=T.advance(T.begin(source,target,config),10000)
	local c=actor(h)
	eq(c.tick({targetMs=target,budget=1}).status,"PENDING")
	eq(c.drain().results[1].status,"SETTLING")
	eq(c.snapshots().ready,false)
	eq(c.submit(operation("too-early")).status,"NOT_ACCEPTED")
	eq(c.checkpoint(operation("partial")).status,"PENDING")
	eq(c.drain().results[1].status,"APPLIED")
	local saved=h.records[h.handle.key]
	eq(saved.timeline.settledWallThrough,h.now,"partial state does not advance wall cursor")
	local cp=T.decodeCheckpoint(saved.timeline.integrationCheckpoint)
	eq(cp.phase,"AFTER_PRODUCTION");eq(cp.mode,"AWAY");eq(cp.done,false)
	eq(saved.farm.cash,C.BigAmount.encode(10.0375),"exactly one half-rate 0.3sec production phase")
	eq(c.release().status,"PENDING");eq(c.drain().results[1].status,"RELEASED")
	local reopened=h.repo.acquire("1");eq(reopened.status,"ACQUIRED");h.handle=reopened.handle
	local nextActor=actor(h)
	eq(nextActor.tick({targetMs=target,budget=10000}).status,"PENDING")
	eq(nextActor.drain().results[1].status,"ADVANCED")
	eq(nextActor.snapshots().ready,true)
	eq(nextActor.checkpoint(operation("finished","1")).status,"PENDING")
	eq(nextActor.drain().results[1].status,"APPLIED")
	local finished=h.records[h.handle.key]
	equalData(T.decodeCheckpoint(finished.timeline.integrationCheckpoint),uninterrupted,"restart matches uninterrupted phases bit for bit")
	eq(finished.timeline.settledWallThrough,target)
	eq(finished.meta.revision,"2");eq(finished.ownership.generation,"2")
	eq(finished.accounting.prestigeExtraEarnings,"7")
	eq(finished.accounting.prestigeSessionArchivedCash,"200")
end
do
	local h=harness();seed(h)
	local p=Data.copy(h.handle.snapshot);p.effects.boosts={{kind="income",remainingSeconds="1"}}
	local ok,err=pcall(memory,p)
	eq(ok,false);eq(string.find(tostring(err),"TEST_ADAPTER_UNSUPPORTED_EFFECT",1,true)~=nil,true)
	p=Data.copy(h.handle.snapshot);p.inventory.equipped={"pet-1"}
	eq(pcall(memory,p),false)
end
fs.writeFile("build/integration89-results.json",serde.encode("json",{status="PASS",assertions=assertions,level="L",studioTested=false,dataStoreTested=false}))
print("integration89: "..assertions.." assertions PASS")
