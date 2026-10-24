--!nocheck
local C=require("../../src/shared/NumericCodec")
local Data=require("../../src/server/PersistenceData")
local Schema=require("../../src/server/ProfileSchema").new(C)
local Repo=require("../../src/server/SessionRepository")
local Actor=require("../../src/server/PlayerCoordinator")
local serde=require("@lune/serde")
local fs=require("@lune/fs")
local count=0
local function eq(a,b,label) count+=1;assert(a==b,(label or "").." expected "..tostring(b).." got "..tostring(a)) end
local function op(id,revision,args)
	return {operationId=id,kind="TestGrant",args=args or {value="1"},expectedRevision=revision or "0"}
end
local function harness(limit)
	local t={records={},now=1000000,elapsed=0,serial=0,domainCalls=0,simulationCalls=0,updates=0,reads=0}
	local store={}
	function store.read(key)
		t.reads+=1
		if t.readFail then return false,"read timeout" end
		return true,if t.records[key] then Data.copy(t.records[key]) else nil
	end
	function store.update(key,callback)
		t.updates+=1
		if t.pause then t.pause=false;coroutine.yield("STORAGE_WAIT") end
		if t.defer then t.defer=false;t.late=function()local p=callback(Data.copy(t.records[key]));if p then t.records[key]=Data.copy(p) end end;return false,"timeout" end
		local nextProfile=callback(if t.records[key] then Data.copy(t.records[key]) else nil)
		if nextProfile then t.records[key]=Data.copy(nextProfile) end
		if t.afterError then t.afterError=false;return false,"response lost" end
		return true,if nextProfile then Data.copy(nextProfile) else nil
	end
	t.repo=Repo.new({mode="INTERNAL_TEST_ONLY",codec=C,data=Data,schema=Schema,store=store,
		clock={utcNowMs=function()return t.now end,elapsedNowSeconds=function()return t.elapsed end},
		encodeJson=function(v)return serde.encode("json",v)end,tokenFactory=function()t.serial+=1;return "token-"..t.serial end})
	t.handle=t.repo.acquire("1").handle
	local simulation={advance=function(profile,request)
		t.simulationCalls+=1
		profile.farm.cash=C.BigAmount.encode(C.BigAmount.decode(profile.farm.cash)+(request.income or 0))
		profile.timeline.settledWallThrough+=request.elapsedMs or 0
		if request.yieldNow then coroutine.yield() end
		if request.corrupt then profile.meta.revision="999" end
		return {profile=profile,complete=request.complete~=false}
	end}
	local domain={apply=function(profile,operation)
		t.domainCalls+=1
		if operation.args.yieldNow then coroutine.yield() end
		local rejected=operation.args.reject==true
		if not rejected then profile.inventory.boosts.test=operation.args.value end
		return {profile=profile,result=if rejected then {errorCode="INSUFFICIENT_CASH"} else {granted=operation.args.value},
			terminalStatus=if rejected then "REJECTED" else "APPLIED",
			validate=function(fresh)return operation.args.freshReject~=true,"QUOTE_CHANGED" end}
	end}
	t.actor=Actor.new({mode="INTERNAL_TEST_ONLY",codec=C,data=Data,repository=t.repo,handle=t.handle,clock={utcNowMs=function()return t.now end,elapsedNowSeconds=function()return t.elapsed end},simulation=simulation,domain=domain,maxQueue=limit or 8})
	function t.advance(ms) t.now+=ms;t.elapsed+=ms/1000 end
	function t.ready() eq(t.actor.setReady(true).status,"READY_SET") end
	function t.flush()return t.actor.drain() end
	return t
end
do
	local h=harness();local a=h.actor
	eq(a.submit(op("A")).status,"NOT_ACCEPTED");eq(a.submit(op("A")).errorCode,"SESSION_NOT_READY")
	eq(a.resultOf("A").status,"UNKNOWN");eq(a.query("A").status,"UNKNOWN");eq(h.domainCalls,0)
	h.ready();eq(a.submit(op("A")).status,"PENDING");eq(a.resultOf("A").status,"PENDING")
	eq(a.submit(op("A","999")).status,"PENDING");eq(a.snapshots().queued,1)
	eq(a.submit(op("A","0",{value="2"})).errorCode,"OPERATION_ID_CONFLICT")
	eq(h.domainCalls,0);eq(h.records["player:1"].inventory.boosts.test,nil)
	eq(h.flush().results[1].status,"APPLIED");eq(a.resultOf("A").status,"APPLIED")
	eq(h.domainCalls,1);eq(h.records["player:1"].inventory.boosts.test,"1")
	eq(a.setReady(false).status,"READY_SET")
	local retry=op("A","999");retry.validUntilMs=0
	eq(a.submit(retry).status,"REPLAYED");eq(a.submit(retry).resultRevision,"1")
	eq(a.submit(op("A","0",{value="2"})).errorCode,"OPERATION_ID_CONFLICT");eq(h.domainCalls,1)
	eq(a.query("A").status,"REPLAYED");eq(a.snapshots().durable.meta.revision,"1")
end
do
	local h=harness();h.ready();local a=h.actor
	eq(a.tick({income=5,elapsedMs=300}).status,"PENDING");eq(h.flush().results[1].status,"ADVANCED")
	eq(a.snapshots().working.farm.cash,"5");eq(a.snapshots().durable.farm.cash,"0");eq(a.snapshots().durable.meta.revision,"0")
	eq(a.submit(op("afterTick","0"),{income=2,elapsedMs=100}).status,"PENDING")
	eq(h.flush().results[1].status,"APPLIED");eq(h.records["player:1"].farm.cash,"7")
	eq(h.records["player:1"].timeline.settledWallThrough,1000400);eq(h.domainCalls,1)
	eq(a.submit(op("stale","0"),{income=100}).status,"PENDING")
	eq(h.flush().results[1].errorCode,"STALE_REVISION");eq(h.domainCalls,1);eq(h.simulationCalls,2)
	eq(h.records["player:1"].farm.cash,"7");eq(a.snapshots().working.meta.revision,"2")
end
for _,rejectedByValidator in {false,true} do
	local h=harness();h.ready();local a=h.actor
	a.tick({income=3});h.flush()
	local args={value="4",reject=not rejectedByValidator,freshReject=rejectedByValidator}
	a.submit(op("reject","0",args),{income=2,elapsedMs=300})
	eq(h.flush().results[1].status,"REJECTED");eq(a.snapshots().working.farm.cash,"5")
	eq(a.snapshots().durable.farm.cash,"0");eq(a.snapshots().working.meta.revision,"1")
	eq(a.checkpoint(op("save","1")).status,"PENDING");eq(h.flush().results[1].status,"APPLIED")
	eq(h.records["player:1"].farm.cash,"5");eq(h.records["player:1"].timeline.settledWallThrough,1000300)
	eq(a.submit(op("reject","999",args)).status,"REPLAYED");eq(h.domainCalls,1)
	eq(h.records["player:1"].farm.cash,"5")
end
do
	local h=harness();h.ready();local a=h.actor
	a.submit(op("serial"));h.pause=true
	local worker=coroutine.create(function()return a.drain()end)
	local ok,reason=coroutine.resume(worker);eq(ok,true);eq(reason,"STORAGE_WAIT")
	eq(a.snapshots().busy,true);eq(a.drain().errorCode,"WRITER_BUSY")
	eq(a.setReady(false).errorCode,"WRITER_BUSY");eq(a.recover("serial").errorCode,"WRITER_BUSY")
	eq(a.resultOf("serial").status,"PENDING");eq(a.query("serial").status,"PENDING")
	eq(a.tick({income=2}).status,"PENDING");eq(a.submit(op("next","1",{value="2"})).status,"PENDING")
	eq(h.domainCalls,1);eq(h.records["player:1"].inventory.boosts.test,nil)
	local resumed,result=coroutine.resume(worker);eq(resumed,true);eq(result.results[1].status,"APPLIED")
	eq(coroutine.status(worker),"dead");eq(a.snapshots().queued,2)
	h.flush();eq(h.records["player:1"].farm.cash,"2");eq(h.records["player:1"].inventory.boosts.test,"2")
	eq(h.domainCalls,2);eq(a.snapshots().busy,false)
end
do
	local h=harness();h.ready();local a=h.actor
	a.submit(op("uncertain"));a.submit(op("waiting","1"));h.afterError=true
	eq(h.flush().results[1].status,"UNKNOWN");eq(a.snapshots().working,nil);eq(a.snapshots().ready,false)
	eq(a.resultOf("waiting").status,"UNKNOWN");eq(a.query("waiting").status,"UNKNOWN")
	eq(a.submit(op("new")).status,"NOT_ACCEPTED");eq(h.domainCalls,1)
	eq(a.query("uncertain").status,"REPLAYED");eq(a.submit(op("uncertain")).status,"REPLAYED")
	eq(a.recover("uncertain").status,"UNKNOWN");h.advance(120000)
	eq(a.recover("uncertain").status,"ACQUIRED");eq(a.resultOf("waiting").status,"NOT_APPLIED")
	eq(a.snapshots().ready,false);eq(a.snapshots().durable.ownership.generation,"2")
	h.ready();eq(a.submit(op("waiting","1")).status,"PENDING");h.flush();eq(h.domainCalls,2)
	eq(a.resultOf("waiting").status,"APPLIED")
end
do
	local h=harness();h.ready();local a=h.actor
	a.submit(op("late"));h.defer=true;eq(h.flush().results[1].status,"UNKNOWN")
	eq(a.query("late").status,"UNKNOWN");h.advance(120000)
	eq(a.recover("late").status,"ACQUIRED");eq(a.resultOf("late").status,"NOT_APPLIED")
	h.late();eq(h.records["player:1"].operations.late,nil);eq(h.records["player:1"].inventory.boosts.test,nil)
	h.ready();a.submit(op("late"));h.flush();eq(h.records["player:1"].inventory.boosts.test,"1");eq(h.domainCalls,2)
	eq(a.recover("forgotten").status,"UNKNOWN");h.advance(120000)
	eq(a.recover("forgotten").status,"ACQUIRED");eq(a.query("forgotten").status,"NOT_APPLIED")
	h.ready();eq(a.submit(op("forgotten","1")).status,"PENDING");h.flush();eq(a.resultOf("forgotten").status,"APPLIED")
end
do
	local h=harness();local a=h.actor
	eq(a.tick({income=1,complete=false}).status,"PENDING");eq(h.flush().results[1].status,"SETTLING")
	eq(a.submit(op("blocked")).errorCode,"SESSION_NOT_READY")
	eq(a.checkpoint(op("partial")).status,"PENDING");eq(h.flush().results[1].status,"APPLIED")
	eq(a.snapshots().ready,false);eq(h.records["player:1"].farm.cash,"1")
	eq(a.tick({income=1,complete=true}).status,"PENDING");eq(h.flush().results[1].status,"ADVANCED")
	eq(a.snapshots().ready,true);a.checkpoint(op("complete","1"));h.flush();eq(h.records["player:1"].farm.cash,"2")
end
do
	local h=harness(1);h.ready();local a=h.actor
	eq(a.tick({income=1}).status,"PENDING");eq(a.submit(op("full")).errorCode,"QUEUE_FULL")
	eq(a.renew().errorCode,"QUEUE_FULL");h.flush()
	eq(a.renew().status,"PENDING");eq(h.flush().results[1].status,"RENEWED")
	eq(a.release().status,"PENDING");eq(h.flush().results[1].status,"RELEASED")
	eq(a.submit(op("afterRelease")).errorCode,"OPERATION_BLOCKED")
end
for _,request in {{yieldNow=true},{corrupt=true}} do
	local h=harness();h.ready();h.actor.tick(request)
	eq(h.flush().results[1].status,"UNKNOWN");eq(h.actor.snapshots().working,nil)
	eq(h.records["player:1"].farm.cash,"0")
end
do
	local h=harness();h.ready();h.actor.submit(op("yield","0",{yieldNow=true,value="1"}))
	eq(h.flush().results[1].status,"UNKNOWN");eq(h.records["player:1"].operations.yield,nil)
	local t=harness();t.ready();t.advance(120000);t.actor.submit(op("expired"))
	eq(t.actor.submit(op("expired")).errorCode,"OPERATION_BLOCKED");eq(t.actor.snapshots().working,nil)
	eq(t.records["player:1"].inventory.boosts.test,nil)
end
do
	local h=harness();h.ready();h.advance(100000)
	eq(h.actor.tick({income=10}).errorCode,"SESSION_LOST");eq(h.simulationCalls,0)
	eq(h.actor.snapshots().working,nil);eq(h.records["player:1"].farm.cash,"0")
	local t=harness();t.ready();t.now-=1
	eq(t.actor.tick({income=10}).errorCode,"CLOCK_UNCERTAIN");eq(t.simulationCalls,0)
	local u=harness();u.ready();u.elapsed=20
	eq(u.actor.submit(op("skew")).errorCode,"CLOCK_UNCERTAIN");eq(u.domainCalls,0)
end
for _,bad in {op("", "0"),op("x","01"),{operationId="x",kind="Test",args={}}} do
	local h=harness();h.ready();eq(h.actor.submit(bad).errorCode,"INVALID_OPERATION");eq(h.actor.snapshots().queued,0)
end
for _,kind in {"checkpoint","command"} do
	local h=harness();h.ready();local a=h.actor
	a.tick({income=7,elapsedMs=300});h.flush();h.advance(30000)
	eq(a.renew().status,"PENDING");eq(h.flush().results[1].status,"RENEWED")
	eq(a.snapshots().working.farm.cash,"7");eq(a.snapshots().durable.farm.cash,"0")
	eq(a.snapshots().working.ownership.endsAtMs,1150000)
	if kind=="checkpoint" then a.checkpoint(op("afterRenew")) else a.submit(op("afterRenew")) end
	eq(h.flush().results[1].status,"APPLIED");eq(h.records["player:1"].farm.cash,"7")
	eq(h.records["player:1"].timeline.settledWallThrough,1000300)
	eq(a.snapshots().ready,true)
end
do
	local h=harness();h.ready();local a=h.actor
	a.checkpoint(op("base"));h.flush()
	eq(a.snapshots().durable.meta.revision,"1")
	a.tick({income=3,elapsedMs=300});h.flush()
	local simulations,domains=h.simulationCalls,h.domainCalls
	eq(a.submit(op("staleWithWorking","0"),{income=99,elapsedMs=300}).status,"PENDING")
	eq(h.flush().results[1].errorCode,"STALE_REVISION")
	eq(a.snapshots().durable.farm.cash,"0");eq(a.snapshots().working.farm.cash,"3")
	eq(a.snapshots().working.timeline.settledWallThrough,1000300)
	eq(h.simulationCalls,simulations);eq(h.domainCalls,domains)
	eq(a.snapshots().durable.operations.staleWithWorking.terminalStatus,"REJECTED")
	a.checkpoint(op("saveAfterStale","2"));eq(h.flush().results[1].status,"APPLIED")
	eq(a.snapshots().durable.farm.cash,"3");eq(a.snapshots().durable.timeline.settledWallThrough,1000300)
	eq(a.submit(op("saveAfterStale","999")).status,"REPLAYED")
	eq(a.snapshots().durable.farm.cash,"3")
end
do
	local h=harness();h.ready();local a=h.actor
	eq(a.submit(op("queuedReadFailure")).status,"PENDING")
	local updates=h.updates
	eq(a.query("queuedReadFailure").status,"PENDING","NOT_FOUND read retains tracked queue")
	h.readFail=true
	eq(a.query("queuedReadFailure").status,"PENDING","uncertain read retains tracked queue")
	eq(a.resultOf("queuedReadFailure").status,"PENDING")
	eq(h.domainCalls,0);eq(h.updates,updates);eq(a.snapshots().queued,1)
	h.readFail=false
	eq(h.flush().results[1].status,"APPLIED");eq(h.domainCalls,1)
end
fs.writeFile("build/coordinator-results.json",serde.encode("json",{status="PASS",assertions=count,level="L",studioTested=false,dataStoreTested=false}))
print("coordinator: "..count.." assertions PASS")
