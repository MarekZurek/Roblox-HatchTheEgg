--!nocheck
-- Internal single-writer actor. No task scheduler, services or remote handlers at import.
local Coordinator = {}
local DOMAIN = {farm=true,accounting=true,permanent=true,inventory=true,effects=true,timeline=true,rewards=true,piggy=true,entitlements=true}
local function answer(status,code)
	return {status=status,errorCode=code}
end
local function pure(fn,...)
	local thread=coroutine.create(fn)
	local result=table.pack(coroutine.resume(thread,...))
	if coroutine.status(thread)~="dead" then coroutine.close(thread);error("PORT_YIELDED") end
	if not result[1] then error(result[2]) end
	return table.unpack(result,2,result.n)
end
function Coordinator.new(deps)
	assert(deps.mode=="INTERNAL_TEST_ONLY","INTERNAL_MODE_REQUIRED")
	local data,repo,h=deps.data,deps.repository,deps.handle
	assert(deps.codec.VERSION==1 and h.state=="READY" and not h.blocked,"ACQUIRED_HANDLE_REQUIRED")
	assert(type(deps.maxQueue)=="number" and deps.maxQueue>=1 and deps.maxQueue%1==0,"QUEUE_BOUND_REQUIRED")
	assert(type(deps.simulation.advance)=="function" and type(deps.domain.apply)=="function","PORTS_REQUIRED")
	assert(type(deps.clock.utcNowMs)=="function" and type(deps.clock.elapsedNowSeconds)=="function","CLOCK_REQUIRED")
	local working=data.copy(h.snapshot)
	local ready,busy,blocked=false,false,false
	local queue,entries={},{}
	local self={}
	local guard
	local function fingerprint(op)
		assert(type(op.operationId)=="string" and #op.operationId>0 and #op.operationId<=128,"INVALID_ID")
		assert(type(op.kind)=="string" and #op.kind>0 and #op.kind<=64,"INVALID_KIND")
		assert(type(op.args)=="table","INVALID_ARGS")
		deps.codec.ExactUInt.decode(op.expectedRevision)
		if op.quoteId~=nil then assert(type(op.quoteId)=="string" and #op.quoteId>0 and #op.quoteId<=128,"INVALID_QUOTE") end
		if op.validUntilMs~=nil then assert(type(op.validUntilMs)=="number" and op.validUntilMs>=0 and op.validUntilMs<=9007199254740991 and op.validUntilMs%1==0,"INVALID_DEADLINE") end
		local key=data.fingerprint({kind=op.kind,args=op.args,quoteId=op.quoteId or ""})
		assert(#key<=16384,"ARGS_TOO_LARGE")
		return key
	end
	local function replay(record,key)
		if key and record.argsKey~=key then return answer("REJECTED","OPERATION_ID_CONFLICT") end
		return {status="REPLAYED",terminalStatus=record.terminalStatus,result=data.copy(record.result),resultRevision=record.resultRevision}
	end
	local function unavailable()
		local clockError=guard();if clockError then return clockError end
		if blocked or h.blocked or h.state~="READY" then return "OPERATION_BLOCKED" end
		if not ready then return "SESSION_NOT_READY" end
		if #queue>=deps.maxQueue then return "QUEUE_FULL" end
		return nil
	end
	local function patches(base,candidate)
		-- Domain ports may alter domain fields, never ownership/meta/operation ledger.
		for key,value in base do
			assert(candidate[key]~=nil,"SECTION_REMOVED")
			if not DOMAIN[key] then assert(data.fingerprint(value)==data.fingerprint(candidate[key]),"RESERVED_SECTION_CHANGED") end
		end
		for key in candidate do assert(base[key]~=nil,"SECTION_ADDED") end
		local changes={}
		for section in DOMAIN do
			assert(type(candidate[section])=="table","INVALID_SECTION")
			for field in base[section] do assert(candidate[section][field]~=nil,"FIELD_REMOVED") end
			for field,value in candidate[section] do
				if base[section][field]==nil or data.fingerprint(base[section][field])~=data.fingerprint(value) then
					table.insert(changes,{path={section,field},value=data.copy(value)})
				end
			end
		end
		return changes
	end
	local function freezeWork(code)
		blocked=true;ready=false
		for _,job in queue do
			if job.entry then job.entry.result=answer("UNKNOWN",code or "RECOVERY_REQUIRED") end
		end
		queue={}
	end
	guard=function()
		if blocked or h.blocked or h.state~="READY" then return "OPERATION_BLOCKED" end
		local ok,now,elapsed=pcall(function()return deps.clock.utcNowMs(),deps.clock.elapsedNowSeconds() end)
		local code
		if not ok or type(now)~="number" or now<0 or now>9007199254620991 or now%1~=0 or type(elapsed)~="number" or elapsed~=elapsed or math.abs(elapsed)==math.huge then code="CLOCK_UNCERTAIN"
		elseif h.lastUtc and (now<h.lastUtc or elapsed<h.lastElapsed or math.abs((now-h.lastUtc)-(elapsed-h.lastElapsed)*1000)>5000) then code="CLOCK_UNCERTAIN"
		elseif now>=h.endsAtMs-20000 then code="SESSION_LOST" end
		if code then h.blocked=true;h.state=code;freezeWork(code);return code end
		-- Reuse repository's clock observation baseline for commits and renewals.
		h.lastUtc,h.lastElapsed=now,elapsed
		return nil
	end
	function self.setReady(value)
		assert(type(value)=="boolean","INVALID_READY")
		if busy then return answer("NOT_ACCEPTED","WRITER_BUSY") end
		local code=guard();if code then return answer("NOT_ACCEPTED",code) end
		if blocked or h.blocked or h.state~="READY" then return answer("NOT_ACCEPTED","OPERATION_BLOCKED") end
		ready=value;return answer("READY_SET")
	end
	local function enqueue(kind,op,request)
		local copiedOk,copied=pcall(data.copy,op)
		if not copiedOk then return answer("NOT_ACCEPTED","INVALID_OPERATION") end
		local ok,key=pcall(fingerprint,copied)
		if not ok then return answer("NOT_ACCEPTED","INVALID_OPERATION") end
		local saved=h.snapshot.operations[copied.operationId]
		if saved then return replay(saved,key) end -- before readiness/revision/quote
		local entry=entries[copied.operationId]
		if entry then
			if entry.key~=nil and entry.key~=key then return answer("REJECTED","OPERATION_ID_CONFLICT") end
			if entry.result.status~="NOT_APPLIED" then return data.copy(entry.result) end
		end
		local code=unavailable()
		if code and not (kind=="checkpoint" and code=="SESSION_NOT_READY" and #queue<deps.maxQueue) then return answer("NOT_ACCEPTED",code) end
		local requestOk,fixed=pcall(function()return if request~=nil then data.copy(request) else nil end)
		if not requestOk then return answer("NOT_ACCEPTED","INVALID_SIMULATION_REQUEST") end
		entry={key=key,result=answer("PENDING")};entries[copied.operationId]=entry
		table.insert(queue,{kind=kind,op=copied,request=fixed,entry=entry})
		return answer("PENDING")
	end
	function self.submit(op,request) return enqueue("command",op,request) end
	function self.checkpoint(op) return enqueue("checkpoint",op,nil) end
	function self.tick(request)
		local code=guard();if code then return answer("NOT_ACCEPTED",code) end
		if blocked or h.blocked or h.state~="READY" then return answer("NOT_ACCEPTED","OPERATION_BLOCKED") end
		if #queue>=deps.maxQueue then return answer("NOT_ACCEPTED","QUEUE_FULL") end
		local ok,fixed=pcall(data.copy,request);if not ok then return answer("NOT_ACCEPTED","INVALID_SIMULATION_REQUEST") end
		table.insert(queue,{kind="tick",request=fixed});return answer("PENDING")
	end
	local function simulate(profile,request)
		if request==nil then return data.copy(profile),true end
		local result=pure(deps.simulation.advance,data.copy(profile),data.copy(request))
		assert(type(result)=="table" and type(result.complete)=="boolean","INVALID_SIMULATION_RESULT")
		local candidate=data.copy(result.profile);patches(profile,candidate)
		return candidate,result.complete
	end
	local function execute(job)
		local clockError=guard();if clockError then return answer("UNKNOWN",clockError) end
		if blocked or h.blocked or h.state~="READY" then freezeWork("SESSION_LOST");return answer("UNKNOWN","SESSION_LOST") end
		if job.kind=="renew" or job.kind=="release" then
			local result=repo[job.kind](h)
			if result.status=="RENEWED" then
				-- Renew refreshes the durable lease, not provisional domain progress.
				for key,value in h.snapshot do if not DOMAIN[key] then working[key]=data.copy(value) end end
			end
			if result.status=="UNKNOWN" or h.blocked or result.errorCode=="SESSION_LOST" then freezeWork(result.errorCode) end
			return result
		end
		if job.kind=="tick" then
			local candidate,complete=simulate(working,job.request)
			working=candidate
			ready=complete
			return answer(if complete then "ADVANCED" else "SETTLING")
		end
		if not ready and job.kind~="checkpoint" then return answer("NOT_APPLIED","SESSION_NOT_READY") end
		local op=job.op
		local candidate,complete=working,true
		local outcome
		if op.expectedRevision~=h.snapshot.meta.revision then
			outcome={profile=working,result={},validate=function()return false,"STALE_REVISION" end}
		else
			candidate,complete=simulate(working,job.request)
			if not complete then
				-- No action applied. Keep resumable simulation in memory; this ID is not terminal.
				working=candidate;ready=false
				return answer("NOT_APPLIED","SIMULATION_INCOMPLETE")
			end
			if job.kind=="checkpoint" then outcome={profile=candidate,result={checkpoint=true},validate=function()return true end}
			else outcome=pure(deps.domain.apply,data.copy(candidate),data.copy(op)) end
		end
		assert(type(outcome)=="table" and type(outcome.validate)=="function","INVALID_DOMAIN_RESULT")
		local terminal=outcome.terminalStatus or "APPLIED"
		assert(terminal=="APPLIED" or terminal=="REJECTED","INVALID_TERMINAL")
		local final=data.copy(outcome.profile)
		local changes=patches(h.snapshot,final)
		-- Rejection records no grant. Already simulated time remains provisional,
		-- available to a later checkpoint rather than erased or applied twice.
		if terminal=="REJECTED" then
			assert(data.fingerprint(final)==data.fingerprint(candidate),"REJECTED_CHANGES")
			changes={}
		end
		local result=repo.commit(h,op,{changes=changes,result=data.copy(outcome.result),terminalStatus=terminal,validate=outcome.validate})
		if result.status=="APPLIED" then
			working=data.copy(h.snapshot)
		elseif result.status=="REJECTED" or result.status=="REPLAYED" then
			-- A rejected purchase must not erase earlier uncheckpointed online production.
			working=data.copy(candidate)
			for key,value in h.snapshot do if not DOMAIN[key] then working[key]=data.copy(value) end end
		elseif result.status=="UNKNOWN" or h.blocked or result.errorCode=="SESSION_LOST" then freezeWork(result.errorCode)
		elseif result.status=="NOT_ACCEPTED" then
			-- Admission to tracked preparation already happened. Repository preflight
			-- certainly refused this write; expose a resolved non-execution instead.
			result=answer("NOT_APPLIED",result.errorCode)
		end
		return result
	end
	function self.drain(maxJobs)
		if busy then return answer("NOT_ACCEPTED","WRITER_BUSY") end
		maxJobs=maxJobs or #queue
		assert(type(maxJobs)=="number" and maxJobs>=0 and maxJobs%1==0,"INVALID_WORK_BUDGET")
		busy=true
		local completed={}
		for _=1,maxJobs do
			local job=table.remove(queue,1);if not job then break end
			local ok,result=pcall(execute,job)
			if not ok then
				-- Ports are pure; before repository invocation no external effect was attempted.
				-- Unexpected failures are nevertheless unresolved, never guessed as success.
				result=answer("UNKNOWN","COORDINATOR_FAILURE");freezeWork(result.errorCode)
			end
			if job.entry then job.entry.result=data.copy(result) end
			table.insert(completed,result)
			if blocked then break end
		end
		busy=false
		return {status="DRAINED",results=completed}
	end
	function self.resultOf(id)
		local entry=entries[id]
		return if entry then data.copy(entry.result) else answer("UNKNOWN","STATUS_NOT_TRACKED")
	end
	function self.query(id)
		local result=repo.query(h,id)
		if result.status=="REPLAYED" then
			if entries[id] then entries[id].result=data.copy(result) end
			return result
		end
		local entry=entries[id]
		if entry then return data.copy(entry.result) end
		-- A missing read alone cannot resolve forgotten accepted work.
		return if result.status=="NOT_FOUND" then answer("UNKNOWN","RECOVERY_REQUIRED") else result
	end
	function self.recover(id)
		if busy then return answer("NOT_ACCEPTED","WRITER_BUSY") end
		busy=true;freezeWork("RECOVERY_REQUIRED")
		local ok,result=pcall(repo.recover,h,id)
		if not ok then result=answer("UNKNOWN","RECOVERY_FAILED") end
		if result.status=="ACQUIRED" then
			h=result.handle;working=data.copy(result.profile);queue={}
			for operationId,entry in entries do
				local saved=h.snapshot.operations[operationId]
				entry.result=if saved then replay(saved,entry.key) else answer("NOT_APPLIED")
			end
			local saved=h.snapshot.operations[id]
			if not entries[id] then entries[id]={result=if saved then replay(saved) else answer("NOT_APPLIED")} end
			blocked=false
		end
		busy=false
		return result
	end
	local function maintenance(kind)
		local code=guard();if code then return answer("NOT_ACCEPTED",code) end
		if blocked or h.blocked then return answer("NOT_ACCEPTED","OPERATION_BLOCKED") end
		if #queue>=deps.maxQueue then return answer("NOT_ACCEPTED","QUEUE_FULL") end
		table.insert(queue,{kind=kind});return answer("PENDING")
	end
	function self.renew() return maintenance("renew") end
	function self.release() return maintenance("release") end
	function self.snapshots()
		guard()
		return {durable=data.copy(h.snapshot),working=if blocked or h.blocked then nil else data.copy(working),ready=ready and not blocked and not h.blocked,busy=busy,queued=#queue}
	end
	return table.freeze(self)
end
return table.freeze(Coordinator)
