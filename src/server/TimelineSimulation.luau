--!nocheck
-- Server timeline with frozen progression/effects context and resumable model phases.
local isStudio = (typeof(script) == "Instance")
local function resolve(studioGetter, lunePath)
	if isStudio then
		local ok, mod = pcall(studioGetter)
		if ok and mod then
			return if typeof(mod) == "Instance" then require(mod) else mod
		end
	end
	return require(lunePath)
end

local EffectsManager = resolve(function()
	return script.Parent.EffectsManager
end, "./EffectsManager")
local Equipment=resolve(function()return script.Parent.pets.equipment end,"./pets/equipment")
local Timeline = {}
-- Approved plate adaptation: the physical hatch pressure plate hatches at most this rate.
-- The plate lane is advanced from server-observed presence only; the Epic hold lane keeps
-- its research-driven rate and its client-owned start/refresh/stop lifecycle.
Timeline.PLATE_HATCH_RATE = 30
function Timeline.new(codec, production, hatching, ihr, data, options)
 assert(options and options.mode == "INTERNAL_TEST_ONLY", "Timeline/TEST_MODE_REQUIRED")
 local A,R,U=codec.BigAmount,codec.Real64,codec.ExactUInt
 local api={VERSION=1,STATUS="INTERNAL_TEST_ONLY"}
 local function instant(n) assert(type(n)=="number" and n>=0 and n<=9007199254740991 and n%1==0,"Timeline/INVALID_INSTANT"); return n end
 local function integer(n) assert(type(n)=="number" and n>=0 and n<=9007199254740991 and n%1==0,"Timeline/INVALID_INTEGER");return n end
 local function arrived(farm,ending)
  local ids={}
  for id,g in farm.groups do table.insert(ids,{id=id,due=R.add(g.startInstantMs/1000,g.travelDurationSeconds)}) end
  table.sort(ids,function(a,b) return if a.due==b.due then a.id<b.id else a.due<b.due end)
  for _,g in ids do if g.due<=ending then farm=hatching.arrive(farm,g.id,ending) end end
  return farm
 end
 local function validateState(s)
  instant(s.settledWallThrough)
  if s.selectionState~=nil then integer(s.selectionState);assert(s.selectionState>0 and s.selectionState<4294967296,"Timeline/INVALID_SEED") end
  for _,key in {"pets","boosts","events"} do assert(s[key]==nil,"Timeline/UNSUPPORTED_EFFECT") end
  if s.effects~=nil then
   assert(type(s.effects)=="table","Timeline/INVALID_EFFECTS")
   if s.effects.boosts~=nil then
    assert(type(s.effects.boosts)=="table","Timeline/INVALID_BOOSTS")
    for _,b in s.effects.boosts do
     assert(type(b)=="table" and type(b.remainingSeconds)=="number","Timeline/INVALID_BOOST")
    end
   end
   if s.effects.videoDoublerEndsAtMs~=nil then
    assert(type(s.effects.videoDoublerEndsAtMs)=="number","Timeline/INVALID_VD")
   end
  end
  local f=s.farm; assert(type(f)=="table" and type(s.accounting)=="table","Timeline/INVALID_STATE")
  for _,key in {"effects","pets","boosts","events","rcbMultiplier"} do assert(f[key]==nil,"Timeline/UNSUPPORTED_EFFECT") end
  A.validate(f.cash);A.validate(f.hatcheryStock);integer(f.siloOwned)
  for _,name in {"prestigeSessionArchivedCash","prestigeExtraEarnings","lastBaseEarnings","currentFarmCash","lastCashEarned"} do A.validate(s.accounting[name]) end
  local types,pops={},{}
  for i,h in f.habitats do types[i]=if h.typeIndex==-1 then false else h.typeIndex;pops[i]=h.population end
  local pets=Equipment.calculatePetMultipliers(s.inventory,f)
  local caps=production.capacities(f.commonLevels,types,pets.habCapacityMult)
  for i,h in f.habitats do assert(h.capacity==U.encode(U.fromSafeNumber(caps[i])),"Timeline/CAPACITY_MISMATCH") end
  production.productionStep({commonLevels=f.commonLevels,habitatTypes=types,settledPopulation=pops,vehicleTypes=f.vehicleTypes,eggIndex=f.eggIndex,permanent=s.permanent,petMultipliers=pets,permitExistingPopulation=true},0)
  hatching.closeInFlightForAway(f) -- Validate group/reservation consistency without modifying input.
 end
 local function validateConfig(c)
  assert(type(c)=="table" and type(c.revision)=="string" and #c.revision>0 and type(c.pro)=="boolean","Timeline/INVALID_CONFIG")
  for k in c do assert(k=="revision" or k=="pro" or k=="siloCapacityLevel" or k=="liveEvents" or k=="holdContext" or k=="selectionSeed","Timeline/UNSUPPORTED_EFFECT") end
  integer(c.siloCapacityLevel)
  if c.liveEvents~=nil then assert(type(c.liveEvents)=="table","Timeline/INVALID_EVENTS") end
  if c.selectionSeed~=nil then integer(c.selectionSeed);assert(c.selectionSeed>0 and c.selectionSeed<4294967296,"Timeline/INVALID_SEED") end
  if c.holdContext~=nil then
   local h=c.holdContext;assert(type(h)=="table" and type(h.sessionKey)=="string" and type(h.routes)=="table","Timeline/INVALID_HOLD_CONTEXT")
   instant(h.expiresAtMs);assert(type(h.runtime)=="table" and type(h.runtime.held)=="boolean","Timeline/INVALID_HOLD_RUNTIME")
  end
 end
 function api.begin(state,targetMs,config)
  state=data.copy(state);config=data.copy(config);validateState(state);validateConfig(config);instant(targetMs)
  local start=state.settledWallThrough
  local duration=if targetMs>start then (targetMs-start)/1000 else 0
  local mode=if duration>60 then "AWAY" else "ONLINE"
  local limit=duration
  if mode=="AWAY" then limit=math.min(duration,A.multiply(state.farm.siloOwned,A.add(3600,A.multiply(360,config.siloCapacityLevel)))) end
  local cp={version=1,config=config,state=state,startInstantMs=start,targetInstantMs=math.max(start,targetMs),mode=mode,
   productionSeconds=limit,remainingSeconds=limit,elapsedSeconds=0,stepIndex=0,phase="BETWEEN_STEPS",done=false,clockDiscrepancy=targetMs<start}
  if config.holdContext and mode=="ONLINE" then cp.hold=data.copy(config.holdContext) end
  if duration>0 then
   if mode=="AWAY" then state.farm=hatching.closeInFlightForAway(state.farm) else state.farm=arrived(state.farm,start/1000) end
  end
  if limit==0 then cp.done=true;state.settledWallThrough=cp.targetInstantMs end
  return cp
 end
 local function validateCheckpoint(cp)
  assert(cp.version==1 and (cp.phase=="BETWEEN_STEPS" or cp.phase=="AFTER_PRODUCTION") and type(cp.done)=="boolean","Timeline/INVALID_CHECKPOINT")
  validateConfig(cp.config);validateState(cp.state);instant(cp.startInstantMs);instant(cp.targetInstantMs)
  if cp.phase=="AFTER_PRODUCTION" then assert(not cp.done and cp.stepDt==math.min(cp.remainingSeconds,0.3),"Timeline/INVALID_PHASE_DT") else assert(cp.stepDt==nil,"Timeline/UNEXPECTED_PHASE_DT") end
  if cp.selectionState~=nil then integer(cp.selectionState);assert(cp.selectionState>0 and cp.selectionState<4294967296,"Timeline/INVALID_SEED") end
  integer(cp.stepIndex);A.validate(cp.productionSeconds);A.validate(cp.remainingSeconds);A.validate(cp.elapsedSeconds)
  assert((cp.stepIndex==0)==(cp.elapsedSeconds==0),"Timeline/INVALID_CURSOR")
  assert(cp.elapsedSeconds<=cp.productionSeconds+math.max(1,cp.productionSeconds)*cp.stepIndex*2^-51,"Timeline/INVALID_CURSOR")
  -- Validation-only roundoff bound for independently accumulated elapsed and remaining; never changes dt/state.
  assert(math.abs((cp.elapsedSeconds+cp.remainingSeconds)-cp.productionSeconds)<=math.max(1,cp.productionSeconds)*cp.stepIndex*2^-51,"Timeline/INVALID_CURSOR")
  assert(cp.targetInstantMs>=cp.startInstantMs and cp.remainingSeconds<=cp.productionSeconds,"Timeline/INVALID_CURSOR")
  assert(cp.mode=="ONLINE" or cp.mode=="AWAY","Timeline/INVALID_MODE")
  local d=(cp.targetInstantMs-cp.startInstantMs)/1000
  assert(cp.mode==(if d>60 then "AWAY" else "ONLINE"),"Timeline/MODE_MISMATCH")
  local limit=if cp.mode=="AWAY" then math.min(d,A.multiply(cp.state.farm.siloOwned,A.add(3600,A.multiply(360,cp.config.siloCapacityLevel)))) else d
  assert(cp.productionSeconds==limit,"Timeline/LIMIT_MISMATCH")
  assert(cp.done==(cp.remainingSeconds==0),"Timeline/DONE_MISMATCH")
  assert(cp.state.settledWallThrough==(if cp.done then cp.targetInstantMs else cp.startInstantMs),"Timeline/WALL_CURSOR_MISMATCH")
  if cp.plate~=nil then
   -- Server-observed plate lane: only a bounded presence window, never client-supplied state.
   local p=cp.plate
   assert(type(p)=="table" and type(p.sessionKey)=="string" and type(p.routes)=="table","Timeline/INVALID_PLATE_CONTEXT")
   instant(p.sinceMs);instant(p.expiresAtMs);assert(p.sinceMs<=p.expiresAtMs,"Timeline/INVALID_PLATE_WINDOW")
   assert(type(p.runtime)=="table" and type(p.runtime.held)=="boolean","Timeline/INVALID_PLATE_RUNTIME")
   assert(cp.mode=="ONLINE","Timeline/INVALID_PLATE_MODE")
  end
 end
 local function draw(cp)
  -- Frozen local PRNG cursor: two uint32 words cover the full ExactUInt selection domain.
  local x=cp.selectionState or cp.state.selectionState or cp.config.selectionSeed or (cp.startInstantMs%4294967295+1)
  local function nextWord()
   x=bit32.bxor(x,bit32.lshift(x,13));x=bit32.bxor(x,bit32.rshift(x,17));x=bit32.bxor(x,bit32.lshift(x,5));return x
  end
  local high,low=nextWord(),nextWord();cp.selectionState=x;cp.state.selectionState=x
  return U.encode(U.fromParts(high,low))
 end
 function api.advance(checkpoint,maxPhases)
  local cp=data.copy(checkpoint);validateCheckpoint(cp);integer(maxPhases)
  local f=cp.state.farm
  local pets=Equipment.calculatePetMultipliers(cp.state.inventory,f)
  local research=production.productionContext(f.commonLevels,f.eggIndex,cp.state.permanent,pets)
  for _=1,maxPhases do
   if cp.done then break end
   local dt=if cp.phase=="AFTER_PRODUCTION" then cp.stepDt else math.min(cp.remainingSeconds,0.3)
   if cp.phase=="BETWEEN_STEPS" and cp.mode=="ONLINE" and cp.plate then
    -- A presence transition splits production too: newly running chickens cannot
    -- boost income for the part of a step before their observed entry.
    local startMs=R.add(cp.startInstantMs,cp.elapsedSeconds*1000)
    for _,boundaryMs in {cp.plate.sinceMs,cp.plate.expiresAtMs} do
     if boundaryMs>startMs and boundaryMs<R.add(startMs,dt*1000) then
      dt=R.divide(R.subtract(boundaryMs,startMs),1000)
     end
    end
   end
   local elapsed=R.add(cp.elapsedSeconds,dt)
   assert(elapsed>cp.elapsedSeconds,"Timeline/TIME_STALL")
   local stepEndMs=R.add(cp.startInstantMs,elapsed*1000)
   if cp.phase=="BETWEEN_STEPS" then
   if cp.mode=="ONLINE" and cp.hold then
    local hold=cp.hold
    local holdDt=math.max(0,math.min(dt,(hold.expiresAtMs-cp.startInstantMs)/1000-cp.elapsedSeconds))
    if holdDt>0 then
     local nextRuntime
     f,nextRuntime=hatching.holdStep(f,hold.runtime,holdDt,research.holdRate,function()return draw(cp)end,function(slot)
      local route=data.copy(hold.routes[slot]);route.startInstantMs=math.floor(cp.startInstantMs+cp.elapsedSeconds*1000+0.5);return route
     end)
     hold.runtime=nextRuntime
    end
    if holdDt<dt or stepEndMs>=hold.expiresAtMs then hold.runtime.held=false;hold.runtime.holdElapsed=0 end
   end
   if cp.mode=="ONLINE" and cp.plate then
    local plate=cp.plate
    -- Count only inside the observed presence window: from the observed entry to the last
    -- observation plus its bounded lease. Gaps never backfill, so a stalled host cannot catch up.
    local windowStart=math.max(R.add(cp.startInstantMs,cp.elapsedSeconds*1000),plate.sinceMs)
    local windowEnd=math.min(stepEndMs,plate.expiresAtMs)
    local plateDt=math.max(0,math.min(dt,(windowEnd-windowStart)/1000))
    if plateDt>0 then
     local nextRuntime
     f,nextRuntime=hatching.holdStep(f,plate.runtime,plateDt,Timeline.PLATE_HATCH_RATE,function()return draw(cp)end,function(slot)
      local route=data.copy(plate.routes[slot]);route.startInstantMs=math.floor(windowStart+0.5);return route
     end)
     plate.runtime=nextRuntime
    end
    -- Clipping the left edge at a new entry must not cancel later steps in this interval.
    if stepEndMs>=plate.expiresAtMs then plate.runtime.held=false;plate.runtime.holdElapsed=0 end
   end
   cp.state.accounting.lastBaseEarnings=A.add(cp.state.accounting.prestigeSessionArchivedCash,cp.state.accounting.currentFarmCash)
   local mults=EffectsManager.calculateMultipliers(cp.state.effects,f,stepEndMs,cp.config.liveEvents,{boostBoostMult=pets.boostBoostMult})
   local types,pops={},{}
   for i,h in f.habitats do types[i]=if h.typeIndex==-1 then false else h.typeIndex;pops[i]=h.population end
   local result=production.productionStep({commonLevels=f.commonLevels,habitatTypes=types,settledPopulation=pops,vehicleTypes=f.vehicleTypes,runningCount=f.runningCount,eggIndex=f.eggIndex,permanent=cp.state.permanent,petMultipliers=pets,permitExistingPopulation=true},dt)
   local baseIncome=if cp.mode=="AWAY" then A.multiply(result.cashIncome,if cp.config.pro then 1 else 0.5) else result.cashIncome
   local eventAverage=EffectsManager.averageEarningsEventMultiplier(cp.config.liveEvents,cp.startInstantMs,cp.elapsedSeconds,dt)
   local earningsMultiplier=A.multiply(A.multiply(mults.effectiveEarningsBoost,mults.vdMultiplier),eventAverage)
   local income=A.multiply(baseIncome,earningsMultiplier)
   f.cash=A.add(f.cash,income)
   local accounting=cp.state.accounting
   accounting.currentFarmCash=A.add(accounting.currentFarmCash,income)
   accounting.lastCashEarned=A.add(accounting.lastCashEarned,income)
   local prestigeMultiplier=A.multiply(mults.effectivePrestigeBoost,pets.prestigeEarningsMult)
   if prestigeMultiplier>1.0 then
    local extraRate=prestigeMultiplier-1.0
    local extraIncome=A.multiply(income,extraRate)
    accounting.prestigeExtraEarnings=A.add(accounting.prestigeExtraEarnings,extraIncome)
   end
   cp.phase="AFTER_PRODUCTION";cp.stepDt=dt
   else
   f=arrived(f,R.add(cp.startInstantMs/1000,elapsed))
   f.hatcheryStock=hatching.refill(f.hatcheryStock,research.hatcheryCapacity,research.refillPerSecond,dt)
   local mults=EffectsManager.calculateMultipliers(cp.state.effects,f,stepEndMs,cp.config.liveEvents,{boostBoostMult=pets.boostBoostMult})
   local baseIHRRate=R.divide(research.internalHatcheryPerHabPerMinute,60)
   local effectiveIHRRate=R.multiply(R.multiply(baseIHRRate,pets.ihrMult),mults.ihrMultiplier)
   if cp.mode=="AWAY" then effectiveIHRRate=R.multiply(effectiveIHRRate,research.calmMult) end
   f.habitats=ihr.step(f.habitats,effectiveIHRRate,dt,research.sharing,function()return draw(cp)end)
   if cp.state.effects~=nil then
    EffectsManager.stepDecay(cp.state.effects,f,dt)
   end
   cp.phase="BETWEEN_STEPS";cp.stepDt=nil
   cp.elapsedSeconds=elapsed;cp.remainingSeconds=R.subtract(cp.remainingSeconds,dt);cp.stepIndex+=1
   if cp.remainingSeconds==0 then cp.done=true;cp.state.settledWallThrough=cp.targetInstantMs end
   end
  end
  cp.state.farm=f
  return cp
 end
 -- Tagged numeric nodes make all binary64 values round-trip, including route snapshots.
 -- Reserved marker is rejected in memory data, avoiding user-data/tag ambiguity.
 local marker="__hteTimelineReal64"
 function api.encodeCheckpoint(cp)
  validateCheckpoint(cp)
  local function encode(v)
   if type(v)=="number" then return {[marker]=R.encode(v)} end
   if type(v)~="table" then return v end
   assert(v[marker]==nil,"Timeline/RESERVED_WIRE_KEY")
   local out={};for k,x in v do out[k]=encode(x) end;return out
  end
  return {version=1,payload=encode(data.copy(cp))}
 end
 function api.decodeCheckpoint(wire)
  wire=data.copy(wire);assert(wire.version==1 and type(wire.payload)=="table","Timeline/UNSUPPORTED_WIRE")
  local function decode(v)
   if type(v)~="table" then assert(type(v)~="number","Timeline/UNTAGGED_WIRE_NUMBER");return v end
   if v[marker]~=nil then
    local count=0;for _ in v do count+=1 end;assert(count==1,"Timeline/INVALID_WIRE_TAG")
    return R.decode(v[marker])
   end
   local out={};for k,x in v do out[k]=decode(x) end;return out
  end
  local cp=decode(wire.payload);validateCheckpoint(cp);return cp
 end
 return table.freeze(api)
end
return table.freeze(Timeline)
