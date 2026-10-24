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
local result={status="PASS",level="L",assertions=count,studioTested=false,dataStoreTested=false,realDataStoreApiTested=false}
fs.writeFile("build/persistence-results.json",serde.encode("json",result,true))
print(serde.encode("json",result))
