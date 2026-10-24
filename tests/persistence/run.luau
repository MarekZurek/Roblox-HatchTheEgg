--!nocheck
local C=require("../../src/shared/NumericCodec")
local Data=require("../../src/server/PersistenceData")
local Schema=require("../../src/server/ProfileSchema").new(C)
local Repo=require("../../src/server/SessionRepository")
local Port=require("../../src/server/RobloxDataStorePort")
local serde=require("@lune/serde")
local fs=require("@lune/fs")
local count=0
local function eq(a,b,label) count+=1;assert(a==b,(label or "").." expected "..tostring(b).." got "..tostring(a)) end
local function harness()
	local h={records={},now=1000000,elapsed=0,serial=0,updates=0,reads=0}
	function h.advance(ms) h.now+=ms;h.elapsed+=ms/1000 end
	h.clock={utcNowMs=function()return h.now end,elapsedNowSeconds=function()return h.elapsed end}
	h.store={
		read=function(key) h.reads+=1;if h.readFail then return false,"read timeout" end;return true,if h.records[key] then Data.copy(h.records[key]) else nil end,
		update=function(key,cb)
			h.updates+=1
			local current=if h.records[key] then Data.copy(h.records[key]) else nil
			if h.beforeError then h.beforeError=false;return false,"before callback" end
			if h.defer then h.defer=false;h.late=function()local candidate=cb(if h.records[key] then Data.copy(h.records[key]) else nil);if candidate then h.records[key]=Data.copy(candidate) end end;return false,"still in flight" end
			if h.retry then h.retry=false;cb(Data.copy(current)) end
			if h.during then local hook=h.during;h.during=nil;hook() end
			local candidate=cb(if h.records[key] then Data.copy(h.records[key]) else nil)
			if h.returnNil then h.returnNil=false;return true,nil end
			if candidate~=nil then h.records[key]=Data.copy(candidate) end
			if h.afterError then h.afterError=false;return false,"after commit response lost" end
			return true,if candidate then Data.copy(candidate) else nil
		end,
	}
	function h.repository(extra)
		local deps={mode="INTERNAL_TEST_ONLY",codec=C,data=Data,schema=Schema,store=h.store,clock=h.clock,encodeJson=function(v)return serde.encode("json",v)end,tokenFactory=function()h.serial+=1;return "token-"..h.serial end}
		for k,v in extra or {} do deps[k]=v end
		return Repo.new(deps)
	end
	h.repo=h.repository()
	function h.open(player)
		local r=h.repo.acquire(player or "1");eq(r.status,"ACQUIRED");return r.handle
	end
	return h
end
local function op(id,revision,args)
	return {operationId=id,kind="TestDebitAndGrant",args=args or {item="test"},quoteId="quote",expectedRevision=revision or "0",validUntilMs=9000000000}
end
local function plan(cash,result)
	return {changes={{path={"farm","cash"},value=cash},{path={"inventory","boosts","test"},value="1"},{path={"timeline","settledWallThrough"},value=1000001}},result=result or {granted="1"},validate=function(p)return C.BigAmount.decode(p.farm.cash)>=0 end}
end
do
	local h=harness();local a=h.open();local p=h.records[a.key]
	eq(p.farm.cash,"0");eq(p.farm.siloOwned,1);eq(p.farm.fleetLimit,4);eq(p.farm.hatcheryStock,"250");eq(p.permanent.GE,"10")
	eq(p.ownership.generation,"1");eq(p.meta.revision,"0")
	eq(h.repo.acquire("1").errorCode,"SESSION_BUSY")
	h.retry=true
	local r=h.repo.commit(a,op("A"),plan("1"));eq(r.status,"APPLIED");eq(r.resultRevision,"1")
	p=h.records[a.key];eq(p.farm.cash,"1");eq(p.inventory.boosts.test,"1");eq(p.timeline.settledWallThrough,1000001);eq(p.operations.A.result.granted,"1")
	local replayOp=op("A","999");replayOp.validUntilMs=0
	eq(h.repo.commit(a,replayOp,plan("999")).status,"REPLAYED");eq(h.records[a.key].farm.cash,"1")
	eq(h.repo.commit(a,op("A","1",{item="changed"}),plan("999")).errorCode,"OPERATION_ID_CONFLICT")
	eq(h.repo.commit(a,op("B","0"),plan("999")).errorCode,"STALE_REVISION")
	eq(h.records[a.key].operations.B.terminalStatus,"REJECTED")
	eq(h.repo.commit(a,op("B","2"),plan("999")).terminalStatus,"REJECTED")
	eq(h.records[a.key].farm.cash,"1")
	eq(h.repo.query(a,"missing").status,"NOT_FOUND")
	local before=h.updates;eq(h.repo.query(a,"A").status,"REPLAYED");eq(h.updates,before,"query does not write")
	local b=h.open("2");eq(h.repo.query(b,"A").status,"NOT_FOUND")
end
do
	local h=harness();local a=h.open();h.afterError=true
	eq(h.repo.commit(a,op("lost"),plan("9")).status,"UNKNOWN")
	eq(h.records[a.key].farm.cash,"9");eq(h.repo.query(a,"lost").status,"REPLAYED")
	eq(h.repo.commit(a,op("blocked"),plan("88")).status,"NOT_ACCEPTED")
	eq(h.repo.recover(a,"lost").status,"UNKNOWN")
	h.advance(120000)
	local r=h.repo.recover(a,"lost");eq(r.status,"ACQUIRED");eq(r.operation.status,"REPLAYED");eq(r.handle.generation,"2")
	eq(h.repo.commit(r.handle,op("lost","999"),plan("999")).status,"REPLAYED");eq(h.records[a.key].farm.cash,"9")
end
do
	local h=harness();local a=h.open();h.defer=true
	eq(h.repo.commit(a,op("late"),plan("7")).status,"UNKNOWN")
	eq(h.repo.query(a,"late").status,"UNKNOWN","missing is not proof")
	h.advance(120000);local r=h.repo.recover(a,"late");eq(r.operation.status,"NOT_APPLIED")
	h.late();eq(h.records[a.key].farm.cash,"0");eq(h.records[a.key].ownership.ownerToken,r.handle.token)
	eq(h.repo.commit(r.handle,op("late"),plan("7")).status,"APPLIED")
	eq(h.records[a.key].farm.cash,"7")
end
do
	local h=harness();local a=h.open();h.advance(100000)
	eq(h.repo.commit(a,op("stop"),plan("1")).errorCode,"RENEW_REQUIRED")
	eq(h.repo.renew(a).status,"RENEWED");eq(h.records[a.key].meta.revision,"0")
	h.advance(120000);local b=h.open()
	eq(h.repo.commit(a,op("old"),plan("8")).errorCode,"SESSION_LOST")
	eq(h.repo.release(a).status,"NOT_ACCEPTED");eq(h.records[a.key].ownership.ownerToken,b.token)
	eq(h.repo.release(b).status,"RELEASED");local c=h.open();eq(c.generation,"3")
end
do
	local h=harness();local a=h.open();h.afterError=true
	eq(h.repo.renew(a).status,"UNKNOWN");eq(h.repo.commit(a,op("x"),plan("1")).status,"NOT_ACCEPTED")
	h.readFail=true;eq(h.repo.query(a,"x").status,"UNKNOWN")
end
do
	local h=harness();h.beforeError=true
	local r=h.repo.acquire("1");eq(r.status,"UNKNOWN");eq(h.records["player:1"],nil)
	eq(h.repo.recover(r.handle,"never").operation.status,"NOT_APPLIED")
	local p=Schema.createReference("2",h.now);p.meta.schemaVersion=99;p.privateFuture={kept="yes"};h.records["player:2"]=Data.copy(p)
	eq(h.repo.acquire("2").errorCode,"UNSUPPORTED_SCHEMA");eq(h.records["player:2"].privateFuture.kept,"yes");eq(h.records["player:2"].meta.schemaVersion,99)
	p=Schema.createReference("3",h.now);p.farm.cash="nan";h.records["player:3"]=p
	eq(h.repo.acquire("3").errorCode,"CORRUPT_PROFILE");eq(h.records["player:3"].farm.cash,"nan")
end
do
	local h=harness();local p=Schema.createReference("1",h.now);p.meta.schemaVersion=0;p.future={secret="keep"};p.rewards={existing="preserve"};p.ownership.futureField="kept";h.records["player:1"]=p
	h.repo=h.repository({migrations={[0]=function(v)v.meta.schemaVersion=1;return v end}})
	local a=h.open();eq(h.records[a.key].future.secret,"keep");eq(h.records[a.key].rewards.existing,"preserve")
	eq(h.records[a.key].ownership.futureField,"kept")
	eq(h.repo.commit(a,op("preserve"),plan("1")).status,"APPLIED");eq(h.records[a.key].rewards.existing,"preserve")
end
do
	local h=harness();local a=h.open();h.now-=1
	eq(h.repo.commit(a,op("clock"),plan("1")).errorCode,"CLOCK_UNCERTAIN");eq(h.records[a.key].farm.cash,"0")
	h=harness();a=h.open();h.now+=10000
	eq(h.repo.renew(a).errorCode,"CLOCK_UNCERTAIN")
end
do
	local h=harness();local a=h.open();h.returnNil=true
	eq(h.repo.commit(a,op("nil"),plan("1")).status,"UNKNOWN","pcall true is not commit")
	eq(h.records[a.key].farm.cash,"0")
end
do
	local h=harness();local a=h.open();local p=plan("1")
	p.changes={{path={"meta","revision"},value="9"}}
	eq(h.repo.commit(a,op("meta"),p).status,"NOT_ACCEPTED")
	p=plan("1");table.insert(p.changes,{path={"farm","cash"},value="2"})
	eq(h.repo.commit(a,op("overlap"),p).status,"NOT_ACCEPTED")
	p=plan("1");p.validate=function()coroutine.yield();return true end
	eq(h.repo.commit(a,op("yield"),p).status,"NOT_ACCEPTED")
	p=plan("1");p.validate=function()return false,"NO_FUNDS" end
	eq(h.repo.commit(a,op("reject"),p).errorCode,"NO_FUNDS");eq(h.records[a.key].operations.reject.terminalStatus,"REJECTED")
	local expired=op("expiry","1");expired.validUntilMs=h.now
	eq(h.repo.commit(a,expired,plan("2")).errorCode,"QUOTE_CHANGED")
	eq(h.records[a.key].farm.cash,"0")
end
do
	local h=harness();local a=h.open();local big=string.rep("x",2097152)
	eq(h.repo.commit(a,op("full"),plan("1",{payload=big})).errorCode,"STORAGE_CAPACITY")
	eq(h.records[a.key].farm.cash,"0");eq(h.records[a.key].operations.full,nil)
	local state=h.records[a.key];state.futurePadding=string.rep("x",3145728);a.snapshot=Data.copy(state)
	eq(h.repo.commit(a,op("profilefull"),plan("1")).errorCode,"STORAGE_CAPACITY")
	eq(h.repo.query(a,"full").status,"NOT_FOUND")
	state.futurePadding=nil;a.snapshot=Data.copy(state)
	eq(h.repo.commit(a,op("unicode"),plan("1",{payload="żółć 🐔"})).status,"APPLIED")
end
do
	local h=harness();local a=h.open();local incoming=op("original")
	h.during=function()incoming.operationId="mutated";eq(h.repo.commit(a,op("racing"),plan("9")).status,"NOT_ACCEPTED") end
	eq(h.repo.commit(a,incoming,plan("1")).status,"APPLIED");eq(h.records[a.key].operations.original.kind,"TestDebitAndGrant");eq(h.records[a.key].operations.mutated,nil)
end
do
	local seen={}
	local native={UpdateAsync=function(_,key,callback)seen.key=key;return callback({value=1}) end,GetAsync=function(_,key,options)seen.cache=options.UseCache;return {value=2} end}
	local port=Port.new(native,function()return {} end)
	local ok,p=port.update("private-key",function(v)v.value+=1;return v end);eq(ok,true);eq(p.value,2)
	ok,p=port.read("private-key");eq(ok,true);eq(p.value,2);eq(seen.cache,false)
end
do
	local h=harness();local a=h.open();local b
	h.during=function()h.advance(120000);b=h.open() end
	eq(h.repo.commit(a,op("late-owner"),plan("4")).errorCode,"SESSION_LOST")
	eq(h.records[a.key].farm.cash,"0");eq(h.records[a.key].ownership.ownerToken,b.token)
	h=harness();a=h.open();h.defer=true;eq(h.repo.renew(a).status,"UNKNOWN")
	local expiry=h.records[a.key].ownership.endsAtMs;h.advance(2000);h.late()
	eq(h.records[a.key].ownership.endsAtMs,expiry,"late renew does not extend uncertain lease")
end
do
	local h=harness();local p=Schema.createReference("1",h.now);p.ownership.generation="9007199254740992";h.records["player:1"]=p
	local a=h.open();eq(a.generation,"9007199254740993");eq(h.records[a.key].meta.revision,"0")
	eq(Data.fingerprint({a=1,b="2"}),Data.fingerprint({b="2",a=1}))
	eq(Data.fingerprint({a=-1/math.huge}),Data.fingerprint({a=0}))
	eq(Data.fingerprint({a=1})==Data.fingerprint({a="1"}),false)
end
do
	-- Independent encoded candidate sizes, exactly on both limits and one byte either side.
	for _, limit in {2097152,3145728} do
		for _, delta in {-1,0,1} do
			local h=harness();local a=h.open();local request=op("boundary")
			local future=Data.copy(a.snapshot)
			future.farm.cash="1";future.inventory.boosts.test="1";future.timeline.settledWallThrough=1000001;future.meta.revision="1"
			future.operations.boundary={kind=request.kind,argsKey=Data.fingerprint({kind=request.kind,args=request.args,quoteId=request.quoteId}),terminalStatus="APPLIED",result={payload=""},resultRevision="1"}
			local proposed=plan("1",{payload=""})
			local overhead
			if limit==2097152 then overhead=#serde.encode("json",future.operations)
			else
				future.padding="";h.records[a.key].padding="";a.snapshot.padding=""
				overhead=#serde.encode("json",future)
			end
			local filler=string.rep("x",limit+delta-overhead)
			if limit==2097152 then proposed.result.payload=filler
			else h.records[a.key].padding=filler;a.snapshot.padding=filler end
			local result=h.repo.commit(a,request,proposed)
			eq(result.status,if delta<=0 then "APPLIED" else "NOT_ACCEPTED","exact byte boundary")
			if delta<=0 then
				eq(#serde.encode("json",if limit==2097152 then h.records[a.key].operations else h.records[a.key]),limit+delta)
				eq(h.repo.readOperation("1","boundary").status,"REPLAYED")
				if limit==2097152 and delta==0 then
					eq(h.repo.commit(a,op("extra","1"),plan("2")).errorCode,"STORAGE_CAPACITY")
					eq(h.repo.commit(a,op("boundary","999"),plan("99")).status,"REPLAYED")
				end
			else eq(h.records[a.key].operations.boundary,nil);eq(h.records[a.key].farm.cash,"0") end
		end
	end
end
do
	local info={GetUserIds=function()return {7} end,GetMetadata=function()return {private="kept"} end}
	local native={UpdateAsync=function(_,_,fn)local record,users,metadata=fn({existing=1},info);eq(users[1],7);eq(metadata.private,"kept");return record end}
	local p=Port.new(native,function()return{}end);local ok=p.update("k",function(v)return v end);eq(ok,true)
end
do
	local p=Schema.createReference("1",1000000)
	p.farm.habitats[1].fractionalIHR="1.5"
	eq(Schema.validate(p,"1"),true,"clipped IHR carry may exceed one")
	eq(p.farm.hatchGroupSequence,"0")
	p.farm.habitats[1].fractionalIHR="-0.01"
	eq(pcall(Schema.validate,p,"1"),false)
	p.farm.habitats[1].fractionalIHR="0";p.farm.hatchGroupSequence="01"
	eq(pcall(Schema.validate,p,"1"),false)
end

-- Test Suite for SessionRepository.LIMITS
do
	eq(Repo.LIMITS ~= nil, true, "Repo.LIMITS exported")
	eq(Repo.LIMITS.PROFILE_MAX_BYTES, 3145728, "PROFILE_MAX_BYTES is 3 MiB")
	eq(Repo.LIMITS.LEDGER_MAX_BYTES, 2097152, "LEDGER_MAX_BYTES is 2 MiB")
	eq(Repo.LIMITS.LEASE_DURATION_MS, 120000, "LEASE_DURATION_MS is 120s")
end

-- Test Suite for RobloxDataStorePort Retries and Backoff
do
	local delays = {}
	local mockWait = function(s)
		table.insert(delays, s)
	end

	-- 1. Success on first attempt: no retries, no delay
	local attempts = 0
	local dsMock = {
		UpdateAsync = function(_, key, transform)
			attempts += 1
			return transform({ count = 10 })
		end,
		GetAsync = function(_, key, options)
			attempts += 1
			return { count = 20 }
		end,
	}
	local port = Port.new(dsMock, function() return { UseCache = false } end, {
		maxAttempts = 3,
		baseBackoff = 1,
		waitFn = mockWait,
	})
	delays = {}
	attempts = 0
	local ok, val = port.update("k1", function(v) return { count = v.count + 1 } end)
	eq(ok, true)
	eq(val.count, 11)
	eq(attempts, 1)
	eq(#delays, 0)

	-- 2. Network errors with successful retry on 3rd attempt
	delays = {}
	attempts = 0
	dsMock.UpdateAsync = function(_, key, transform)
		attempts += 1
		if attempts < 3 then
			error("502 Server Throttled (attempt " .. tostring(attempts) .. ")")
		end
		return transform({ count = 30 })
	end
	ok, val = port.update("k2", function(v) return { count = v.count + 1 } end)
	eq(ok, true)
	eq(val.count, 31)
	eq(attempts, 3)
	eq(#delays, 2)
	eq(delays[1], 1, "first backoff is 1s")
	eq(delays[2], 2, "second backoff is 2s")

	-- 3. Exhausting all 3 attempts returns false, lastErr
	delays = {}
	attempts = 0
	dsMock.UpdateAsync = function(_, key, transform)
		attempts += 1
		error("Connection Timeout")
	end
	ok, val = port.update("k3", function(v) return v end)
	eq(ok, false)
	eq(type(val), "string")
	eq(string.find(val, "Connection Timeout") ~= nil, true)
	eq(attempts, 3)
	eq(#delays, 2)

	-- 4. Transform returning nil (repository logic cancellation) aborts immediately without retry
	delays = {}
	attempts = 0
	dsMock.UpdateAsync = function(_, key, transform)
		attempts += 1
		local res = transform({ count = 100 })
		if res == nil then
			return nil
		end
		return res
	end
	ok, val = port.update("k4", function(v)
		return nil -- cancel
	end)
	eq(ok, true)
	eq(val, nil)
	eq(attempts, 1, "does not retry when transform cancelled")
	eq(#delays, 0, "no backoff delays on transform cancelled")

	-- 5. Read retries with exponential backoff
	delays = {}
	attempts = 0
	dsMock.GetAsync = function(_, key, options)
		attempts += 1
		if attempts < 3 then
			error("GetAsync Throttled")
		end
		return { fetched = true }
	end
	ok, val = port.read("k5")
	eq(ok, true)
	eq(val.fetched, true)
	eq(attempts, 3)
	eq(#delays, 2)
	eq(delays[1], 1)
	eq(delays[2], 2)

	-- 6. Read fails all attempts
	delays = {}
	attempts = 0
	dsMock.GetAsync = function(_, key, options)
		attempts += 1
		error("Fatal DataStore Error")
	end
	ok, val = port.read("k6")
	eq(ok, false)
	eq(type(val), "string")
	eq(attempts, 3)
	eq(#delays, 2)
end

-- Test Suite for Session Fencing, SESSION_BUSY, and Stale Token Rejection
do
	local h = harness()
	-- Player 1 acquired by Server A
	local handleA = h.open("1")
	eq(handleA.state, "READY")

	-- Server B attempts to acquire Player 1 while lease is active (< 120s) -> SESSION_BUSY
	local busyRes = h.repo.acquire("1")
	eq(busyRes.status, "NOT_ACCEPTED")
	eq(busyRes.errorCode, "SESSION_BUSY")

	-- Advance clock past lease duration (120,000ms)
	h.advance(120001)

	-- Server B acquires expired session
	local acquireB = h.repo.acquire("1")
	eq(acquireB.status, "ACQUIRED")
	local handleB = acquireB.handle
	eq(handleB.generation > handleA.generation, true, "generation incremented")

	-- Stale Server A attempts mutation -> fenced out with SESSION_LOST
	local staleRes = h.repo.commit(handleA, op("stale-1", "0"), plan("100"))
	eq(staleRes.status, "NOT_ACCEPTED")
	eq(staleRes.errorCode, "SESSION_LOST")

	-- Fresh Server B commits successfully
	local freshRes = h.repo.commit(handleB, op("fresh-1", "0"), plan("200"))
	eq(freshRes.status, "APPLIED")
	eq(h.records[handleB.key].farm.cash, "200")
end

-- Test Suite for ServerBootstrap:checkpointPlayer, checkpointAll, and close()
do
	local ServerBootstrap = require("../../src/server/Bootstrap")
	local nowVal = 5000000
	local elapsedVal = 0
	local clock = {
		utcNowMs = function() return nowVal end,
		elapsedNowSeconds = function() return elapsedVal end,
		advance = function(dt)
			elapsedVal += dt
			nowVal += math.floor(dt * 1000 + 0.5)
		end,
	}

	local server = ServerBootstrap.new({
		clock = clock,
		initialNowMs = 5000000,
	})

	-- Join two players
	local j1 = server:playerJoined("901")
	local j2 = server:playerJoined("902")
	eq(j1 ~= nil, true, "Player 901 joined")
	eq(j2 ~= nil, true, "Player 902 joined")

	-- Advance time on server
	server:tick(10.0)

	-- Checkpoint single player
	local okCp1, cp1Res = server:checkpointPlayer("901")
	eq(okCp1, true, "checkpointPlayer 901 succeeds")
	eq(cp1Res ~= nil, true)

	-- Checkpoint non-existent player
	local okCpX, cpXErr = server:checkpointPlayer("999999")
	eq(okCpX, false)
	eq(cpXErr, "PLAYER_NOT_FOUND")

	-- Checkpoint all players
	local allRes = server:checkpointAll()
	eq(allRes["901"] ~= nil and allRes["901"].ok == true, true, "checkpointAll 901 ok")
	eq(allRes["902"] ~= nil and allRes["902"].ok == true, true, "checkpointAll 902 ok")

	-- Safe flush on server shutdown
	local closeRes = server:close()
	eq(closeRes["901"] ~= nil and closeRes["901"].ok == true, true, "close flushed 901")
	eq(closeRes["902"] ~= nil and closeRes["902"].ok == true, true, "close flushed 902")
	eq(server:getPlayer("901"), nil, "Player 901 removed from active sessions")
	eq(server:getPlayer("902"), nil, "Player 902 removed from active sessions")

	-- Verify that player 901 can now be immediately acquired by another server instance (lease was released)
	local j1Rejoin = server:playerJoined("901")
	eq(j1Rejoin ~= nil, true, "Player 901 cleanly rejoins without waiting for 120s lease")
	server:playerLeaving("901")
end
local result={status="PASS",level="L",assertions=count,studioTested=false,dataStoreTested=false,realDataStoreApiTested=false}
fs.writeFile("build/persistence-results.json",serde.encode("json",result,true))
print(serde.encode("json",result))
