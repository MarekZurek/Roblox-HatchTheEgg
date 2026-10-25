--!nocheck
-- Pure first-farm transitions. Input/runtime are separate from durable farm state.
local Hatching={}
function Hatching.rcb(codec,runningText,c,cap,multiplier)
		local running=codec.ExactUInt.decode(runningText)
		c,cap,multiplier=codec.BigAmount.validate(c),codec.BigAmount.validate(cap),codec.BigAmount.validate(multiplier)
		local n,exact=codec.ExactUInt.toReal64Rounded(running)
		local powered=c^n
		assert(powered==powered,"Hatching/INVALID_RCB")
		-- Overflow of the unbounded power is harmless when the finite cap selects the result.
		local q=math.min(powered,cap)
		if q>1 then q=codec.BigAmount.multiply(q,multiplier) end
		return codec.BigAmount.validate(q),exact
end
function Hatching.new(codec,population,data,options)
	assert(options and options.mode=="INTERNAL_TEST_ONLY","Hatching/INTERNAL_MODE_REQUIRED")
	assert(codec.VERSION==1,"Hatching/UNSUPPORTED_CODEC")
	local U,R,A=codec.ExactUInt,codec.Real64,codec.BigAmount
	local zero,one=U.fromSafeNumber(0),U.fromSafeNumber(1)
	local function uint(text)return U.decode(text)end
	local function amount(n)return A.validate(n)end
	local function id(s) assert(type(s)=="string" and #s>0 and #s<=96 and string.match(s,"^[A-Za-z0-9_:.%-]+$"),"Hatching/INVALID_ID");return s end
	local function pure(fn,...)
		local thread=coroutine.create(fn);local output=table.pack(coroutine.resume(thread,...))
		if coroutine.status(thread)~="dead" then coroutine.close(thread);error("Hatching/CALLBACK_YIELDED") end
		assert(output[1],output[2]);return table.unpack(output,2,output.n)
	end
	local function validateFarm(farm)
		data.copy(farm)
		population.vacancies(farm.habitats)
		amount(farm.hatcheryStock);uint(farm.runningCount);uint(farm.hatchGroupSequence)
		assert(type(farm.groups)=="table","Hatching/INVALID_GROUPS")
		local targets={zero,zero,zero,zero};local running=zero
		for groupId,group in farm.groups do
			id(groupId);assert(group.groupId==groupId and group.status=="IN_TRANSIT","Hatching/INVALID_GROUP")
			assert(type(group.targetSlot)=="number" and group.targetSlot%1==0 and group.targetSlot>=1 and group.targetSlot<=4,"Hatching/INVALID_TARGET")
			local serial=string.match(groupId,"^hatch:([0-9]+)$")
			assert(serial and U.compare(uint(serial),uint(farm.hatchGroupSequence))<=0,"Hatching/INVALID_GROUP_SEQUENCE")
			local count=uint(group.count);assert(U.compare(count,zero)>0,"Hatching/INVALID_GROUP_COUNT")
			assert(type(group.startInstantMs)=="number" and group.startInstantMs>=0 and group.startInstantMs<=9007199254740991 and group.startInstantMs%1==0,"Hatching/INVALID_INSTANT")
			assert(amount(group.travelDurationSeconds)>0,"Hatching/INVALID_DURATION");id(group.routeVersion)
			running=U.add(running,count);targets[group.targetSlot]=U.add(targets[group.targetSlot],count)
		end
		assert(U.encode(running)==farm.runningCount,"Hatching/INCONSISTENT_RUNNING")
		for slot=1,4 do assert(U.encode(targets[slot])==farm.habitats[slot].assignedInTransit,"Hatching/INCONSISTENT_RESERVATION") end
	end
	local function runtimeCopy(runtime)
		local out=data.copy(runtime);id(out.streamId);uint(out.lastInputSeq)
		assert(type(out.held)=="boolean","Hatching/INVALID_INTENT")
		amount(out.holdElapsed)
		assert(R.roundFloat32(out.holdElapsed)==out.holdElapsed,"Hatching/INVALID_HOLD_ACCUMULATOR")
		return out
	end
	local api={VERSION=1,STATUS="INTERNAL_TEST_ONLY"}
	function api.refill(stock,capacity,perSecond,dt)
		stock,capacity,perSecond,dt=amount(stock),amount(capacity),amount(perSecond),amount(dt)
		assert(dt<=0.3 and stock<=capacity,"Hatching/UNSUPPORTED_REFILL_INPUT")
		return math.min(capacity,A.add(stock,A.multiply(perSecond,dt)))
	end
	function api.holdRate(epicLevel)
		assert(type(epicLevel)=="number" and epicLevel%1==0 and epicLevel>=0 and epicLevel<=15,"Hatching/INVALID_EPIC_LEVEL")
		return epicLevel*2
	end
	function api.rcb(...) return Hatching.rcb(codec,...) end

	local function release(farm,drawSource,routeProvider)
		if farm.hatcheryStock<1 then return "NO_STOCK" end
		local _,free=population.vacancies(farm.habitats)
		if U.compare(free,zero)==0 then return "NO_VACANCY" end
		assert(type(drawSource)=="function" and type(routeProvider)=="function","Hatching/PROVIDERS_REQUIRED")
		local draw=pure(drawSource,U.encode(free));uint(draw)
		local slot=population.select(farm.habitats,draw)
		local route=pure(routeProvider,slot)
		if route==nil then return "ROUTE_UNAVAILABLE" end
		route=data.copy(route);id(route.routeVersion)
		assert(type(route.startInstantMs)=="number" and route.startInstantMs>=0 and route.startInstantMs<=9007199254740991 and route.startInstantMs%1==0,"Hatching/INVALID_INSTANT")
		assert(amount(route.travelDurationSeconds)>0,"Hatching/INVALID_DURATION")
		local serial=U.encode(U.add(uint(farm.hatchGroupSequence),one))
		local groupId="hatch:"..serial
		assert(farm.groups[groupId]==nil,"Hatching/GROUP_ID_CONFLICT")
		local hab=farm.habitats[slot]
		hab.assignedInTransit=U.encode(U.add(uint(hab.assignedInTransit),one))
		farm.runningCount=U.encode(U.add(uint(farm.runningCount),one))
		farm.hatcheryStock=A.subtract(farm.hatcheryStock,1);farm.hatchGroupSequence=serial
		farm.groups[groupId]={groupId=groupId,targetSlot=slot,count="1",routeVersion=route.routeVersion,startInstantMs=route.startInstantMs,travelDurationSeconds=route.travelDurationSeconds,status="IN_TRANSIT"}
		if route.snapshot~=nil then farm.groups[groupId].routeSnapshot=data.copy(route.snapshot) end
		return "RELEASED",groupId
	end
	function api.input(farm,runtime,packet,drawSource,routeProvider)
		validateFarm(farm);local nextFarm=data.copy(farm);local nextRuntime=runtimeCopy(runtime)
		assert(type(packet)=="table" and (packet.kind=="HatchPress" or packet.kind=="HatchInput"),"Hatching/INVALID_INPUT")
		id(packet.streamId);uint(packet.inputSeq)
		if packet.kind=="HatchInput" then assert(packet.state=="start" or packet.state=="refresh" or packet.state=="stop","Hatching/INVALID_INPUT") end
		if packet.streamId~=runtime.streamId then return nextFarm,nextRuntime,"WRONG_STREAM" end
		if U.compare(uint(packet.inputSeq),uint(runtime.lastInputSeq))<=0 then return nextFarm,nextRuntime,"STALE_INPUT" end
		nextRuntime.lastInputSeq=packet.inputSeq
		if packet.kind=="HatchPress" then
			local status,group=release(nextFarm,drawSource,routeProvider)
			return nextFarm,nextRuntime,status,group
		end
		if packet.state=="stop" then nextRuntime.held=false;nextRuntime.holdElapsed=0
		elseif packet.state=="start" then
			if not nextRuntime.held then nextRuntime.holdElapsed=0 end
			nextRuntime.held=true
		end -- refresh confirms an existing intention; it never starts one or creates a chicken.
		return nextFarm,nextRuntime,"INTENT_UPDATED"
	end
	function api.holdStep(farm,runtime,dt,rate,drawSource,routeProvider)
		validateFarm(farm);local nextFarm=data.copy(farm);local nextRuntime=runtimeCopy(runtime)
		dt,rate=amount(dt),amount(rate);assert(dt<=0.3 and rate<=30,"Hatching/INVALID_HOLD_STEP")
		if dt==0 then return nextFarm,nextRuntime,0,0 end
		if not nextRuntime.held or rate<=0.1 then nextRuntime.holdElapsed=0;return nextFarm,nextRuntime,0,0 end
		local elapsed=R.roundFloat32(R.add(nextRuntime.holdElapsed,dt))
		local period=1/rate;local attempts,released=0,0
		while elapsed>period do
			attempts+=1;assert(attempts<=128,"Hatching/HOLD_WORK_BUDGET")
			local after=R.roundFloat32(R.subtract(elapsed,period))
			assert(after<elapsed,"Hatching/HOLD_TIME_STALL")
			elapsed=after
			if release(nextFarm,drawSource,routeProvider)=="RELEASED" then released+=1 end
		end
		nextRuntime.holdElapsed=elapsed
		return nextFarm,nextRuntime,attempts,released
	end
	local function arrive(nextFarm,groupId)
		local group=nextFarm.groups[groupId]
		if group==nil then return false end
		local hab=nextFarm.habitats[group.targetSlot];local count=uint(group.count)
		hab.assignedInTransit=U.encode(U.subtract(uint(hab.assignedInTransit),count))
		nextFarm.runningCount=U.encode(U.subtract(uint(nextFarm.runningCount),count))
		hab.population=U.encode(U.add(uint(hab.population),count));nextFarm.groups[groupId]=nil
		return true
	end
	function api.arrive(farm,groupId,stepEndSeconds)
		validateFarm(farm);id(groupId);amount(stepEndSeconds)
		local nextFarm=data.copy(farm);local group=nextFarm.groups[groupId]
		if group==nil then return nextFarm,"ALREADY_CLOSED_OR_UNKNOWN" end
		local due=R.add(group.startInstantMs/1000,group.travelDurationSeconds)
		if stepEndSeconds<due then return nextFarm,"NOT_DUE" end
		arrive(nextFarm,groupId);return nextFarm,"ARRIVED"
	end
	function api.closeInFlightForAway(farm)
		validateFarm(farm);local nextFarm=data.copy(farm);local ids={}
		for groupId in nextFarm.groups do table.insert(ids,groupId) end
		table.sort(ids)
		for _,groupId in ids do arrive(nextFarm,groupId) end
		return nextFarm
	end
	return table.freeze(api)
end
return table.freeze(Hatching)
