--!nocheck
-- One aggregate, native-port UpdateAsync, fenced sessions. No live services at import.
local Repository = {}
local DOMAIN = {farm=true,accounting=true,permanent=true,inventory=true,effects=true,timeline=true,rewards=true,piggy=true,entitlements=true}
local function answer(status, code, extra)
	local out = extra or {}; out.status=status;out.errorCode=code;return out
end
local function pure(fn, ...)
	local thread=coroutine.create(fn)
	local result=table.pack(coroutine.resume(thread,...))
	if coroutine.status(thread)~="dead" then coroutine.close(thread);error("CALLBACK_YIELDED") end
	if not result[1] then error(result[2]) end
	return table.unpack(result,2,result.n)
end
function Repository.new(deps)
	assert(deps.mode=="INTERNAL_TEST_ONLY", "INTERNAL_MODE_REQUIRED")
	assert(deps.codec.VERSION==1,"UNSUPPORTED_CODEC")
	local U=deps.codec.ExactUInt
	local data,schema,store,clock=deps.data,deps.schema,deps.store,deps.clock
	assert(type(deps.encodeJson)=="function" and type(deps.tokenFactory)=="function", "DEPENDENCIES_REQUIRED")
	local self={}
	local function nextUInt(text) return U.encode(U.add(U.decode(text),U.fromSafeNumber(1))) end
	local function valid(p, player)
		local ok,a,b=pcall(function() data.copy(p);return schema.validate(p,player) end)
		return ok and a==true, if ok then b else "CORRUPT_PROFILE"
	end
	local function fits(p)
		local ok,profile,ledger=pcall(function() return deps.encodeJson(p),deps.encodeJson(p.operations) end)
		return ok and type(profile)=="string" and type(ledger)=="string" and #profile<=3145728 and #ledger<=2097152
	end
	local function sample(h)
		local now,elapsed=clock.utcNowMs(),clock.elapsedNowSeconds()
		if not (type(now)=="number" and now>=0 and now<=9007199254620991 and now%1==0
			and type(elapsed)=="number" and elapsed==elapsed and math.abs(elapsed)<math.huge) then
			h.blocked=true;error("INVALID_CLOCK")
		end
		if h.lastUtc and (now<h.lastUtc or elapsed<h.lastElapsed or math.abs((now-h.lastUtc)-(elapsed-h.lastElapsed)*1000)>5000) then
			h.blocked=true;error("CLOCK_UNCERTAIN")
		end
		h.lastUtc,h.lastElapsed=now,elapsed
		return now
	end
	local function owned(p,h,now)
		return p.ownership.ownerToken==h.token and p.ownership.generation==h.generation and now<p.ownership.endsAtMs
	end
	local function update(h, transform)
		local decision, candidateReturned
		local ok,success,value=pcall(function()
			return store.update(h.key,function(current)
				decision=nil
				candidateReturned=false
				local callOk,candidate,result=pcall(transform,current)
				if not callOk then decision=answer(if h.blocked then "NOT_ACCEPTED" else "NOT_APPLIED",if h.blocked then "CLOCK_UNCERTAIN" else "INVALID_TRANSFORM");return nil end
				decision=result
				candidateReturned=candidate~=nil
				return candidate
			end)
		end)
		if not ok or not success then h.blocked=true;h.state="UNKNOWN";return nil,answer("UNKNOWN","STORAGE_UNCERTAIN") end
		if value==nil then
			if candidateReturned then
				h.blocked=true;h.state="UNKNOWN";return nil,answer("UNKNOWN","UNCONFIRMED_WRITE")
			end
			return nil,decision or answer("NOT_APPLIED","TRANSFORM_CANCELLED")
		end
		return value,decision
	end
	local function replay(record,key)
		if record.argsKey~=key then return answer("REJECTED","OPERATION_ID_CONFLICT") end
		return answer("REPLAYED",nil,{result=data.copy(record.result),terminalStatus=record.terminalStatus,resultRevision=record.resultRevision})
	end
	function self.acquire(playerId)
		if type(playerId)~="string" or not string.match(playerId,"^[0-9]+$") or #playerId>20 then return answer("NOT_ACCEPTED","INVALID_PLAYER") end
		local token=deps.tokenFactory()
		assert(type(token)=="string" and #token>0 and #token<=128,"INVALID_TOKEN")
		local h={playerId=playerId,key="player:"..playerId,token=token,state="OPENING",blocked=false}
		local record,result=update(h,function(current)
			if h.blocked then return nil,answer("UNKNOWN","OPERATION_BLOCKED") end
			local now=sample(h)
			local p
			if current==nil then p=pure(schema.createReference,playerId,now) else p=data.copy(current) end
			if p.meta and type(p.meta.schemaVersion)=="number" and p.meta.schemaVersion<1 then
				local migrate=deps.migrations and deps.migrations[p.meta.schemaVersion]
				if not migrate then return nil,answer("NOT_ACCEPTED","UNSUPPORTED_SCHEMA") end
				local prior=data.copy(p);p=pure(migrate,data.copy(p))
				-- Retain opaque top-level sections a migration did not replace.
				for k,v in prior do if p[k]==nil then p[k]=v end end
			end
			local allowed,code=valid(p,playerId)
			if not allowed then return nil,answer("NOT_ACCEPTED",code) end
			if p.ownership.ownerToken~="" and now<p.ownership.endsAtMs then
				return nil,answer("NOT_ACCEPTED","SESSION_BUSY")
			end
			p.ownership.generation=nextUInt(p.ownership.generation)
			p.ownership.ownerToken=token;p.ownership.endsAtMs=now+120000
			if not fits(p) then return nil,answer("NOT_ACCEPTED","STORAGE_CAPACITY") end
			return p,answer("ACQUIRED")
		end)
		if not record then
			if result.status=="UNKNOWN" then result.handle=h end
			return result
		end
		local allowed=valid(record,playerId)
		if not allowed or record.ownership.ownerToken~=token then h.blocked=true;return answer("UNKNOWN","UNCONFIRMED_CLAIM",{handle=h}) end
		h.generation=record.ownership.generation;h.endsAtMs=record.ownership.endsAtMs;h.state="READY";h.snapshot=data.copy(record)
		return answer("ACQUIRED",nil,{handle=h,profile=data.copy(record)})
	end
	local function prepare(op,plan)
		assert(type(op.operationId)=="string" and #op.operationId>0 and #op.operationId<=128,"INVALID_OPERATION")
		assert(type(op.kind)=="string" and #op.kind>0 and #op.kind<=64,"INVALID_KIND")
		U.decode(op.expectedRevision)
		assert(type(op.args)=="table","INVALID_ARGUMENTS")
		if op.quoteId~=nil then assert(type(op.quoteId)=="string" and #op.quoteId>0 and #op.quoteId<=128,"INVALID_QUOTE") end
		if op.validUntilMs~=nil then assert(type(op.validUntilMs)=="number" and op.validUntilMs>=0 and op.validUntilMs<=9007199254740991 and op.validUntilMs%1==0,"INVALID_DEADLINE") end
		local fingerprint=data.fingerprint({kind=op.kind,args=op.args,quoteId=op.quoteId or ""})
		assert(#fingerprint<=16384,"ARGUMENTS_TOO_LARGE")
		assert(type(plan.validate)=="function","VALIDATOR_REQUIRED")
		local fixed=data.copy({changes=plan.changes,result=plan.result,terminalStatus=plan.terminalStatus or "APPLIED"})
		assert(fixed.terminalStatus=="APPLIED" or fixed.terminalStatus=="REJECTED","INVALID_STATUS")
		assert(type(fixed.result)=="table" and type(fixed.changes)=="table","INVALID_PLAN")
		if fixed.terminalStatus=="REJECTED" then assert(#fixed.changes==0,"REJECTED_CHANGES") end
		local paths={}
		for _,change in fixed.changes do
			assert(type(change.path)=="table" and #change.path>=2 and #change.path<=12 and DOMAIN[change.path[1]],"INVALID_PATCH")
			assert(change.value~=nil and change.delete==nil,"INVALID_PATCH_VALUE")
			for _,key in change.path do assert(type(key)=="string" or (type(key)=="number" and key>=1 and key%1==0),"INVALID_PATH") end
			for _,prior in paths do
				local prefix=true
				for i=1,math.min(#prior,#change.path) do if prior[i]~=change.path[i] then prefix=false;break end end
				assert(not prefix,"OVERLAPPING_PATCH")
			end
			table.insert(paths,change.path)
		end
		return fingerprint,fixed
	end
	local function candidate(p,op,fixed,key,validator,now)
		local known=p.operations[op.operationId]
		if known then return nil,replay(known,key) end
		local rejected
		if p.meta.revision~=op.expectedRevision then rejected="STALE_REVISION"
		elseif op.validUntilMs~=nil and now>=op.validUntilMs then rejected="QUOTE_CHANGED"
		else
			local guard,code=pure(validator,data.copy(p),now)
			if guard~=true then rejected=code or "PRECONDITION_FAILED" end
		end
		local nextProfile=data.copy(p)
		for _,change in (if rejected then {} else fixed.changes) do
			local node=nextProfile
			for i=1,#change.path-1 do node=node[change.path[i]];assert(type(node)=="table","INVALID_PATCH_PARENT") end
			node[change.path[#change.path]]=data.copy(change.value)
		end
		nextProfile.meta.revision=nextUInt(p.meta.revision)
		local terminalStatus=if rejected then "REJECTED" else fixed.terminalStatus
		local result=if rejected then {errorCode=rejected} else data.copy(fixed.result)
		nextProfile.operations[op.operationId]={kind=op.kind,argsKey=key,terminalStatus=terminalStatus,result=result,resultRevision=nextProfile.meta.revision}
		local allowed,code2=valid(nextProfile,p.meta.playerId)
		if not allowed then return nil,answer("REJECTED",code2) end
		if not fits(nextProfile) then return nil,answer("NOT_ACCEPTED","STORAGE_CAPACITY") end
		return nextProfile,answer(terminalStatus,rejected,{result=data.copy(result),resultRevision=nextProfile.meta.revision})
	end
	function self.commit(h,op,plan)
		if h.blocked or h.state~="READY" or h.busy then return answer("NOT_ACCEPTED","OPERATION_BLOCKED") end
		local copiedOk,copied=pcall(data.copy,op)
		if not copiedOk then return answer("NOT_ACCEPTED","INVALID_OPERATION") end
		op=copied
		local validator=plan.validate
		local ok,key,fixed=pcall(prepare,op,plan)
		if not ok then return answer("NOT_ACCEPTED","INVALID_OPERATION") end
		-- Preflight bounds before declaring tracked work. Revalidated on latest state in callback.
		local preOk,preCandidate,preResult=pcall(candidate,h.snapshot,op,fixed,key,validator,h.lastUtc)
		if not preOk then return answer("NOT_ACCEPTED","INVALID_PLAN") end
		if not preCandidate then return preResult end
		h.busy=true;h.pending={id=op.operationId,argsKey=key}
		local saved,result=update(h,function(current)
			if h.blocked then return nil,answer("UNKNOWN","OPERATION_BLOCKED") end
			local now=sample(h)
			local allowed,code=valid(current,h.playerId)
			if not allowed then h.blocked=true;return nil,answer("UNKNOWN",code) end
			if not owned(current,h,now) then h.blocked=true;h.state="SESSION_LOST";return nil,answer("NOT_ACCEPTED","SESSION_LOST") end
			local known=current.operations[op.operationId]
			if known then return nil,replay(known,key) end
			if now>=current.ownership.endsAtMs-20000 then return nil,answer("NOT_APPLIED","RENEW_REQUIRED") end
			return candidate(current,op,fixed,key,validator,now)
		end)
		h.busy=false
		if saved then
			local record=saved.operations[op.operationId]
			if not record or record.argsKey~=key then h.blocked=true;return answer("UNKNOWN","UNCONFIRMED_COMMIT") end
			h.snapshot=data.copy(saved);h.pending=nil
			return result
		end
		if result.status~="UNKNOWN" then h.pending=nil end
		return result
	end
	function self.query(h,operationId)
		if type(operationId)~="string" or #operationId==0 or #operationId>128 then return answer("NOT_ACCEPTED","INVALID_OPERATION") end
		local ok,success,p=pcall(store.read,h.key)
		if not ok or not success or p==nil then return answer("UNKNOWN","READ_UNCERTAIN") end
		local allowed,code=valid(p,h.playerId)
		if not allowed then return answer("UNKNOWN",code) end
		local record=p.operations[operationId]
		if record then return answer("REPLAYED",nil,{terminalStatus=record.terminalStatus,result=data.copy(record.result),resultRevision=record.resultRevision}) end
		if h.blocked then return answer("UNKNOWN","RECOVERY_REQUIRED") end
		return answer(if h.busy and h.pending and h.pending.id==operationId then "PENDING" else "NOT_FOUND")
	end
	function self.readOperation(playerId,operationId)
		if type(playerId)~="string" or not string.match(playerId,"^[0-9]+$") or #playerId>20 then return answer("NOT_ACCEPTED","INVALID_PLAYER") end
		return self.query({key="player:"..playerId,playerId=playerId,blocked=true},operationId)
	end
	function self.renew(h)
		if h.blocked or h.busy or h.state~="READY" then return answer("NOT_ACCEPTED","OPERATION_BLOCKED") end
		h.busy=true
		local saved,result=update(h,function(p)
			if h.blocked then return nil,answer("UNKNOWN","OPERATION_BLOCKED") end
			local now=sample(h)
			local allowed,code=valid(p,h.playerId)
			if not allowed then return nil,answer("NOT_APPLIED",code) end
			if not owned(p,h,now) then h.blocked=true;return nil,answer("NOT_APPLIED","SESSION_LOST") end
			local candidate=data.copy(p);candidate.ownership.endsAtMs=now+120000
			if not fits(candidate) then return nil,answer("NOT_APPLIED","STORAGE_CAPACITY") end
			return candidate,answer("RENEWED")
		end)
		h.busy=false
		if saved then h.endsAtMs=saved.ownership.endsAtMs;h.snapshot=data.copy(saved) end
		return result
	end
	function self.release(h)
		if h.blocked or h.busy then return answer("NOT_ACCEPTED","OPERATION_BLOCKED") end
		h.busy=true
		local saved,result=update(h,function(p)
			if h.blocked then return nil,answer("UNKNOWN","OPERATION_BLOCKED") end
			local now=sample(h)
			local allowed,code=valid(p,h.playerId)
			if not allowed then return nil,answer("NOT_APPLIED",code) end
			if not owned(p,h,now) then return nil,answer("NOT_APPLIED","SESSION_LOST") end
			local candidate=data.copy(p);candidate.ownership.ownerToken="";candidate.ownership.endsAtMs=0
			return candidate,answer("RELEASED")
		end)
		h.busy=false
		if saved then h.blocked=true;h.state="RELEASED" end
		return result
	end
	function self.recover(oldHandle,operationId)
		if type(operationId)~="string" or #operationId==0 or #operationId>128 then return answer("NOT_ACCEPTED","INVALID_OPERATION") end
		if oldHandle.busy then return answer("UNKNOWN","WRITE_IN_PROGRESS") end
		oldHandle.blocked=true -- late callbacks in this process may no longer mutate
		local result=self.acquire(oldHandle.playerId)
		if result.status~="ACQUIRED" then return answer("UNKNOWN",result.errorCode or "RECOVERY_WAIT",{recovery=result}) end
		local record=result.profile.operations[operationId]
		result.operation=if record then answer("REPLAYED",nil,{terminalStatus=record.terminalStatus,result=data.copy(record.result),resultRevision=record.resultRevision}) else answer("NOT_APPLIED")
		return result
	end
	return table.freeze(self)
end
return table.freeze(Repository)
