--!nocheck
-- Server bootstrap and orchestration module for HatchTheEgg.
-- Pure factory object ServerBootstrap.new(deps) compatible with Lune and Roblox Studio.
-- Wires all authoritative server components:
-- NumericCodec, CatalogRegistry, SessionRepository, ProfileSchema, PersistenceData,
-- PlayerCoordinator, TimelineSimulation, FarmMath, FarmActions, ViewProjector, NetworkGateway, Clock.

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

local NumericCodec = resolve(function()
	return game:GetService("ReplicatedStorage").HatchTheEgg.Shared.NumericCodec
end, "../shared/NumericCodec")

local ProtocolSchemas = resolve(function()
	return game:GetService("ReplicatedStorage").HatchTheEgg.Shared.ProtocolSchemas
end, "../shared/ProtocolSchemas")

local CatalogData = resolve(function()
	return script.Parent.CatalogRegistry.Data
end, "./CatalogRegistry/Data")

local CatalogRegistry = resolve(function()
	return script.Parent.CatalogRegistry
end, "./CatalogRegistry")

local SessionRepository = resolve(function()
	return script.Parent.SessionRepository
end, "./SessionRepository")

local ProfileSchema = resolve(function()
	return script.Parent.ProfileSchema
end, "./ProfileSchema")

local PersistenceData = resolve(function()
	return script.Parent.PersistenceData
end, "./PersistenceData")

local PlayerCoordinator = resolve(function()
	return script.Parent.PlayerCoordinator
end, "./PlayerCoordinator")

local TimelineSimulation = resolve(function()
	return script.Parent.TimelineSimulation
end, "./TimelineSimulation")

local ProductionMath = resolve(function()
	return script.Parent.FarmMath.production_research
end, "./FarmMath/production_research")

local PopulationMath = resolve(function()
	return script.Parent.FarmMath.PopulationMath
end, "./FarmMath/PopulationMath")

local HatchingRCB = resolve(function()
	return script.Parent.FarmMath.hatching_rcb
end, "./FarmMath/hatching_rcb")

local IHR = resolve(function()
	return script.Parent.FarmMath.ihr
end, "./FarmMath/ihr")

local FarmActions = resolve(function()
	return script.Parent.FarmActions
end, "./FarmActions")

local Calendar = resolve(function() return script.Parent.rewards.calendar end, "./rewards/calendar")
local Trophies = resolve(function() return script.Parent.rewards.trophies end, "./rewards/trophies")
local Fusion = resolve(function() return script.Parent.pets.fusion end, "./pets/fusion")
local ActionReference = resolve(function() return script.Parent.ActionReferenceData end, "./ActionReferenceData")
local Effects = resolve(function() return script.Parent.EffectsManager end, "./EffectsManager")
local ProgressActions = resolve(function()
	return script.Parent.ProgressActions
end, "./ProgressActions")

local ViewProjector = resolve(function()
	return script.Parent.ViewProjector
end, "./ViewProjector")

local NetworkGateway = resolve(function()
	return script.Parent.NetworkGateway
end, "./NetworkGateway")

local Products = resolve(function()
	return script.Parent.platform.products
end, "./platform/products")

local Drones = resolve(function()
	return script.Parent.rewards.drones
end, "./rewards/drones")

local Offers = resolve(function()
	return script.Parent.rewards.offers
end, "./rewards/offers")

local Equipment = resolve(function()
	return script.Parent.pets.equipment
end, "./pets/equipment")

-- Numeric accounting fields that decode/encode to BigAmount
local NUMERIC_ACCOUNTING = table.freeze({
	"prestigeSessionArchivedCash",
	"prestigeExtraEarnings",
	"lastBaseEarnings",
	"currentFarmCash",
	"lastCashEarned",
})

local function ensureSimulationSections(p)
	p.effects = p.effects or {}
	p.effects.boosts = p.effects.boosts or {}
	p.inventory = p.inventory or {}
	p.inventory.equipped = p.inventory.equipped or {}
end

local function decodeEffects(effects,codec,data)
 local result=data.copy(effects or {})
 for _,boost in result.boosts or {} do
  if type(boost.remainingSeconds)=="string" then boost.remainingSeconds=codec.Real64.decode(boost.remainingSeconds) end
  codec.Real64.validate(boost.remainingSeconds)
 end
 return result
end
local function encodeEffects(effects,codec,data)
 local result=data.copy(effects)
 for _,boost in result.boosts or {} do boost.remainingSeconds=codec.Real64.encode(boost.remainingSeconds) end
 return result
end
local function frozenInventory(profile,data)
 local equipped=data.copy(profile.inventory.equipped or {})
 local pets={}
 for _,uid in equipped do
  if profile.inventory.pets[uid] then pets[uid]=data.copy(profile.inventory.pets[uid]) end
 end
 return {equipped=equipped,pets=pets}
end
local function profileToMemory(p, codec, productionMath, data)
	ensureSimulationSections(p)
	local f = data.copy(p.farm)
	f.cash = codec.BigAmount.decode(f.cash)
	f.hatcheryStock = codec.Real64.decode(f.hatcheryStock)
	f.commonLevels = data.copy(f.common or {})
	f.vehicleTypes = {}
	for _, v in f.vehicles or {} do
		if type(v) == "table" and type(v.typeIndex) == "number" and v.typeIndex >= 0 then
			table.insert(f.vehicleTypes, v.typeIndex)
		end
	end

	local types = {}
	for i = 1, 4 do
		local hab = f.habitats and f.habitats[i]
		types[i] = if not hab or hab.typeIndex == -1 then false else hab.typeIndex
	end

	local pets=Equipment.calculatePetMultipliers(p.inventory,f)
 local capacities = productionMath.capacities(f.commonLevels, types,pets.habCapacityMult)
	for i = 1, 4 do
		local hab = f.habitats[i]
		hab.capacity = tostring(capacities[i])
		hab.fractionalIHR = codec.Real64.decode(hab.fractionalIHR or "0")
	end

	local a = data.copy(p.accounting)
	for _, key in NUMERIC_ACCOUNTING do
		a[key] = codec.BigAmount.decode(a[key] or "0")
	end

	return {
		farm = f,
		accounting = a,
		settledWallThrough = p.timeline.settledWallThrough,
  contextVersion = 1,
  selectionState=if p.timeline.selectionState then codec.ExactUInt.toSafeNumber(codec.ExactUInt.decode(p.timeline.selectionState)) else nil,
  effects = decodeEffects(p.effects,codec,data),
  permanent = {SE=p.permanent.SE,PE=p.permanent.PE,epic=data.copy(p.permanent.epic or {})},
  inventory = frozenInventory(p,data),
	}
end

local function memoryToWire(p, state, checkpoint, codec, data)
	local out = data.copy(p)
	out.farm = data.copy(state.farm)
	out.farm.cash = codec.BigAmount.encode(state.farm.cash)
	out.farm.hatcheryStock = codec.BigAmount.encode(state.farm.hatcheryStock)
	for i = 1, 4 do
		local hab = out.farm.habitats[i]
		hab.fractionalIHR = codec.Real64.encode(hab.fractionalIHR)
	end
	out.accounting = data.copy(state.accounting)
	for _, key in NUMERIC_ACCOUNTING do
		out.accounting[key] = codec.BigAmount.encode(state.accounting[key])
	end
	if state.effects~=nil then out.effects=encodeEffects(state.effects,codec,data) end
 if state.selectionState then out.timeline.selectionState=codec.ExactUInt.encode(codec.ExactUInt.fromSafeNumber(state.selectionState)) end
 out.timeline.settledWallThrough = state.settledWallThrough
	-- Explicit completion marker: Coordinator patches never silently delete fields.
	out.timeline.integrationCheckpoint = checkpoint or false
	return out
end

local function createDefaultClock(initialNowMs)
	local nowMs = initialNowMs or 1000000
	local elapsedSec = 0
	local clock = {}
	function clock.utcNowMs()
		return nowMs
	end
	function clock.elapsedNowSeconds()
		return elapsedSec
	end
	function clock.advance(dtSeconds)
		elapsedSec += dtSeconds
		nowMs += math.floor(dtSeconds * 1000 + 0.5)
	end
	function clock.set(newNowMs, newElapsedSec)
		nowMs = newNowMs
		if newElapsedSec ~= nil then
			elapsedSec = newElapsedSec
		end
	end
	return clock
end

local function createMemoryStore(data)
	local records = {}
	return {
		records = records,
		read = function(key)
			return true, if records[key] then data.copy(records[key]) else nil
		end,
		update = function(key, transform)
			local current = if records[key] then data.copy(records[key]) else nil
			local nextVal = transform(current)
			if nextVal ~= nil then
				records[key] = data.copy(nextVal)
			end
			return true, if nextVal ~= nil then data.copy(nextVal) else nil
		end,
	}
end

local function validId(value)
 return type(value)=="string" and #value>0 and #value<=64 and utf8.len(value)~=nil
end
local function validIntent(value, allowed)
 if value==nil then return true end
 if type(value)~="table" or getmetatable(value)~=nil then return false end
 for k,v in value do
  if not allowed[k] then return false end
  if k=="protocolVersion" then if v~=1 then return false end
  elseif not validId(v) then return false end
 end
 return true
end
local CLAIM_FIELDS={operationId=true,requestId=true}
local HATCH_FIELDS={operationId=true,requestId=true,eggType=true,kind=true,protocolVersion=true}
local ServerBootstrap = {}
ServerBootstrap.__index = ServerBootstrap

function ServerBootstrap.new(deps)
	deps = deps or {}
	local storageMode = deps.storageMode or (if isStudio then "PERSISTENT" else "INTERNAL_TEST_ONLY")
	assert(storageMode == "PERSISTENT" or storageMode == "STUDIO_MEMORY" or storageMode == "INTERNAL_TEST_ONLY", "INVALID_STORAGE_MODE")
	if storageMode == "PERSISTENT" then
		assert(type(deps.store) == "table" and type(deps.store.read) == "function" and type(deps.store.update) == "function", "PERSISTENT_STORE_REQUIRED")
	elseif storageMode == "STUDIO_MEMORY" then
		assert(deps.isStudio == true, "STUDIO_MEMORY_REQUIRES_STUDIO")
		if isStudio then assert(game:GetService("RunService"):IsStudio(), "STUDIO_MEMORY_REQUIRES_STUDIO") end
		assert(deps.store == nil, "STUDIO_MEMORY_REJECTS_EXTERNAL_STORE")
	else
		assert(not isStudio, "INTERNAL_STORAGE_NOT_ALLOWED_IN_ROBLOX")
	end

	local codec = deps.codec or NumericCodec
	local data = deps.data or PersistenceData
	local schema = deps.schema or ProfileSchema.new(codec)
	local catalogData = deps.catalogData or CatalogData
	local catalog = deps.catalog or CatalogRegistry.new(codec, catalogData, { mode = "INTERNAL_TEST_ONLY" })
	local productionMath = deps.productionMath or ProductionMath.new(codec, catalog, { mode = "INTERNAL_TEST_ONLY" })
	local populationMath = deps.populationMath or PopulationMath.new(codec)
	local hatching = deps.hatching or HatchingRCB.new(codec, populationMath, data, { mode = "INTERNAL_TEST_ONLY" })
	local ihr = deps.ihr or IHR.new(codec, populationMath)
	local timeline = deps.timeline or TimelineSimulation.new(codec, productionMath, hatching, ihr, data, { mode = "INTERNAL_TEST_ONLY" })
	local farmActions = deps.farmActions or FarmActions.new(codec, catalog, { mode = "INTERNAL_TEST_ONLY" })
	local protocol = deps.protocol or ProtocolSchemas.new(codec)
	local configRevision = deps.configRevision or "first-farm-neutral:1"

	local viewProjector = deps.viewProjector or ViewProjector.new({
  paidRandomAllowed = deps.paidRandomAllowed,
  liveEvents = deps.liveEvents or {},
		codec = codec,
		catalog = catalog,
		productionMath = productionMath,
		configRevision = configRevision,
	})

	local clock = deps.clock or createDefaultClock(deps.initialNowMs or 1000000)
	local store = if storageMode == "PERSISTENT" then deps.store else deps.store or createMemoryStore(data)

	local encodeJson = deps.encodeJson
	if not encodeJson then
		local okSerde, serde = pcall(function() return require("@lune/serde") end)
		if okSerde and serde and serde.encode then
			encodeJson = function(v) return serde.encode("json", v) end
		else
			local okHttp, HttpService = pcall(function() return game:GetService("HttpService") end)
			if okHttp and HttpService then
				encodeJson = function(v) return HttpService:JSONEncode(v) end
			else
				error("JSON encoder required in deps.encodeJson")
			end
		end
	end

	local tokenSerial = 0
	local tokenFactory = deps.tokenFactory or function()
		tokenSerial += 1
		return "session-token-" .. tostring(tokenSerial)
	end

	local repository = deps.repository or SessionRepository.new({
		mode = "INTERNAL_TEST_ONLY",
		codec = codec,
		data = data,
		schema = schema,
		store = store,
		clock = clock,
		encodeJson = encodeJson,
		tokenFactory = tokenFactory,
	})

	local gateway = deps.gateway or NetworkGateway.new({
		viewProjector = viewProjector,
		farmActions = farmActions,
		protocol = protocol,
		clock = clock,
		codec = codec,
		catalog = catalog,
		configRevision = configRevision,
		autoDrain = true,
	})

	local self = setmetatable({
		storageMode = storageMode,
		purchasesEnabled = storageMode ~= "STUDIO_MEMORY",
		codec = codec,
		data = data,
		schema = schema,
		catalog = catalog,
		productionMath = productionMath,
		populationMath = populationMath,
		hatching = hatching,
		ihr = ihr,
		timeline = timeline,
		farmActions = farmActions,
		viewProjector = viewProjector,
		protocol = protocol,
		configRevision = configRevision,
		config = {
			revision = configRevision,
			siloCapacityLevel = 0,
			pro = false,
		},
		clock = clock,
		store = store,
		repository = repository,
		gateway = gateway,
		players = {},
		depsRouteProvider = deps.routeProvider,
  liveEvents = data.copy(deps.liveEvents or {}),
  -- Test fixture only: no production hatch prices/chances have been approved.
  petHatchTestPolicy = deps.petHatchTestPolicy,
        fusionPolicy = deps.fusionPolicy,
        boostShop = deps.boostShop,
        platformProducts = deps.platformProducts or {},
        paidRandomAllowed = deps.paidRandomAllowed,
	}, ServerBootstrap)

	return self
end

function ServerBootstrap:_getRoute(slot)
	if self.depsRouteProvider then
		return self.depsRouteProvider(slot)
	end
	local durations = {
		[1] = 3.57,
		[2] = 3.57,
		[3] = 2.45,
		[4] = 2.45,
	}
	return {
		routeVersion = "scene-v1",
		startInstantMs = self.clock.utcNowMs(),
		travelDurationSeconds = durations[slot] or 2.0,
		snapshot = { slotId = slot },
	}
end

-- Compare committed farm identity, never a tentative domain plan. An old replay
-- has the same identity and must not stop a newly started hold.
function ServerBootstrap:_reconcileReset(playerSession)
    local durable = playerSession.coordinator and playerSession.coordinator.snapshots().durable
    if not durable then return end
    local identity = durable.permanent.prestigeCount .. ":" .. tostring(durable.farm.eggIndex)
    if playerSession.confirmedResetIdentity ~= identity then
        playerSession.hatchingRuntime.held = false
        playerSession.hatchingRuntime.holdElapsed = 0
        playerSession.confirmedResetIdentity = identity
    end
end

function ServerBootstrap:_simulationAdvance(playerSession, profile, request)
	self:_reconcileReset(playerSession)
	if request == nil then
		return { profile = profile, complete = true }
	end
    local active=self.gateway:getPlayerState(playerSession.playerId)
    if active and active.streamId~=playerSession.hatchingRuntime.streamId then
        playerSession.hatchingRuntime.streamId=active.streamId;playerSession.hatchingRuntime.lastInputSeq="0"
        playerSession.hatchingRuntime.held=false;playerSession.hatchingRuntime.holdElapsed=0;playerSession.hatchingRuntime.expiresAtMs=0
    end

	if request.kind == "HatchPress" or request.kind == "HatchInput" then
        -- Settle the preceding interval under the previous intention, never backfill a new hold.
        if profile.timeline.settledWallThrough<self.clock.utcNowMs() or profile.timeline.integrationCheckpoint then
            local settled=self:_simulationAdvance(playerSession,profile,{kind="TimeAdvance",targetMs=self.clock.utcNowMs(),budget=100})
            profile=settled.profile
            if not settled.complete then return settled end
        end
		local pData = self.gateway:getPlayerState(playerSession.playerId)
		local streamId = (pData and pData.streamId) or request.streamId or playerSession.hatchingRuntime.streamId
		if playerSession.hatchingRuntime.streamId ~= streamId then
			playerSession.hatchingRuntime.streamId = streamId
			playerSession.hatchingRuntime.lastInputSeq = "0"
		end

		local drawSource = function() return "0" end
		local routeProvider = function(slot)
			return self:_getRoute(slot)
		end

		-- Prepare farm for hatching
		local farm = self.data.copy(profile.farm)
		local common = farm.common or {}
		local types = {}
		for i = 1, 4 do
			local hab = farm.habitats[i]
			types[i] = if not hab or hab.typeIndex == -1 then false else hab.typeIndex
		end
		if (playerSession.hatchingRuntime.expiresAtMs or 0)<=self.clock.utcNowMs() then playerSession.hatchingRuntime.held=false;playerSession.hatchingRuntime.holdElapsed=0 end
		local pets=Equipment.calculatePetMultipliers(profile.inventory,farm)
  local capacities = self.productionMath.capacities(common, types,pets.habCapacityMult)
		for i = 1, 4 do
			local hab = farm.habitats[i]
			hab.capacity = if hab.typeIndex == -1 then "0" else tostring(capacities[i])
		end
		if type(farm.hatcheryStock) == "string" then
			farm.hatcheryStock = self.codec.BigAmount.decode(farm.hatcheryStock)
		end

		local nextFarm, nextRuntime, status, groupId = self.hatching.input(
			farm,
			playerSession.hatchingRuntime,
			request.packet or request,
			drawSource,
			routeProvider
		)
		playerSession.hatchingRuntime = nextRuntime
        if nextRuntime.held and request.kind=="HatchInput" then nextRuntime.expiresAtMs=self.clock.utcNowMs()+2000 end
		nextFarm.hatcheryStock = self.codec.BigAmount.encode(nextFarm.hatcheryStock)
		profile.farm = nextFarm
		return { profile = profile, complete = true }
	end

	-- Time advance simulation
	local targetMs = request.targetMs
		or (if request.dtSeconds then profile.timeline.settledWallThrough + math.floor(request.dtSeconds * 1000 + 0.5) else profile.timeline.settledWallThrough)
	local budget = request.budget or 100

	local mem = profileToMemory(profile, self.codec, self.productionMath, self.data)
	local cp
	if profile.timeline.integrationCheckpoint then
		cp = self.timeline.decodeCheckpoint(profile.timeline.integrationCheckpoint)
        if cp.hold and cp.hold.sessionKey~=profile.ownership.generation..":"..playerSession.hatchingRuntime.streamId then
            cp.hold.runtime.held=false;cp.hold.runtime.holdElapsed=0
        end
	else
		local simConfig = {
			revision = self.configRevision,
			siloCapacityLevel = self.productionMath.progression(profile.permanent).siloCapacityLevel,
   liveEvents = self.data.copy(self.liveEvents),
			pro = if (profile.entitlements and profile.entitlements.pro_permit == true) then true else ((self.config and self.config.pro) or false),
		}
		local runtime=playerSession.hatchingRuntime
        if runtime.held then
            local routes={};for slot=1,4 do routes[slot]=self:_getRoute(slot) end
            simConfig.holdContext={runtime=self.data.copy(runtime),expiresAtMs=runtime.expiresAtMs or 0,sessionKey=profile.ownership.generation..":"..runtime.streamId,routes=routes}
        end
        cp = self.timeline.begin(mem, targetMs, simConfig)
	end

	if cp.mode=="AWAY" then playerSession.hatchingRuntime.held=false;playerSession.hatchingRuntime.holdElapsed=0 end
	cp = self.timeline.advance(cp, budget)
    if cp.hold and cp.hold.sessionKey==profile.ownership.generation..":"..playerSession.hatchingRuntime.streamId then playerSession.hatchingRuntime=self.data.copy(cp.hold.runtime) end

	local checkpointWire = if cp.done then nil else self.timeline.encodeCheckpoint(cp)
	local nextProfile = memoryToWire(profile, cp.state, checkpointWire, self.codec, self.data)

	return {
		profile = nextProfile,
		complete = cp.done,
	}
end

function ServerBootstrap:playerJoined(playerId, initialProfileFixture)
	local pId = tostring(playerId)
	assert(string.match(pId, "^[0-9]+$"), "INVALID_PLAYER_ID: must be numeric digits")

	-- If fixture provided and store supports it, initialize profile in store
	if initialProfileFixture ~= nil then
		local fixture = self.data.copy(initialProfileFixture)
		fixture.ownership = fixture.ownership or {}
		fixture.ownership.ownerToken = ""
		fixture.ownership.endsAtMs = 0
		self.store.update("player:" .. pId, function()
			return fixture
		end)
	end

	-- 1. Acquire session in repository
	local opened = self.repository.acquire(pId)
	if opened.status ~= "ACQUIRED" then
		return nil, opened.errorCode or "ACQUIRE_FAILED"
	end
	local handle = opened.handle

	-- 2. Create PlayerCoordinator with simulation & domain ports
	local playerSession = {
		playerId = pId,
		handle = handle,
		confirmedResetIdentity = handle.snapshot.permanent.prestigeCount .. ":" .. tostring(handle.snapshot.farm.eggIndex),
		pendingEntitlements = {},
		hatchingRuntime = {
			streamId = "stream-" .. pId .. "-1",
			lastInputSeq = "0",
			held = false,
			holdElapsed = 0,
		},
	}

	local function simulationAdvance(profile, request)
		return self:_simulationAdvance(playerSession, profile, request)
	end

	local function domainApply(candidateProfile, op)
        if not self.purchasesEnabled and (op.kind=="PurchaseProduct" or op.kind=="PlatformPurchase" or op.kind=="ConfirmPurchase" or op.kind=="GrantEntitlement") then
            return {profile=candidateProfile,terminalStatus="REJECTED",result={errorCode="LOCAL_PAYMENTS_DISABLED"},validate=function()return false,"LOCAL_PAYMENTS_DISABLED" end}
        end
        local connected={ClaimDailyGift=true,ClaimTrophy=true,FusePets=true,BuyBoost=true,PurchaseProduct=true}
        if connected[op.kind] then
            local draft=self.data.copy(candidateProfile)
            local args=op.args or {}
            local ok,code=false,"FEATURE_UNAVAILABLE"
            local policySnapshot, bonusSnapshot
            local result={terminalStatus="APPLIED",actionKind=op.kind}
            if op.kind=="ClaimDailyGift" then
                local m,day=Calendar.getCycleAndDay(draft.rewards.numDailyGiftsCollected or 0)
                local count=draft.rewards.numDailyGiftsCollected or 0
                local def=Calendar.referenceReward(count,ActionReference.calendar)
                local prestigeMultiplier=1
                if def and def.rewardType=="CashPercent" and not draft.farm.isContract then
                    local homeFV=ProgressActions.calculateProfileFarmValue(draft,self.catalog,self.productionMath)
                    def=Calendar.resolveReward(count,ActionReference.calendar,homeFV)
                    local pets=Equipment.calculatePetMultipliers(draft.inventory,draft.farm)
                    local effects=Effects.calculateMultipliers(decodeEffects(draft.effects,self.codec,self.data),draft.farm,self.clock.utcNowMs(),self.liveEvents,{boostBoostMult=pets.boostBoostMult})
                    prestigeMultiplier=self.codec.BigAmount.multiply(effects.effectivePrestigeBoost,pets.prestigeEarningsMult)
                end
                if not Calendar.canClaimCalendarDay(draft,self.clock.utcNowMs()) then code="ALREADY_CLAIMED_TODAY"
                elseif def and def.rewardType=="CashPercent" then code="HOME_FARM_REQUIRED"
                elseif def then
                    local reward,err
                    ok,reward,err=Calendar.claimDailyGift(draft,self.clock.utcNowMs(),{[day]=def},ActionReference.epic,prestigeMultiplier)
                    code=err
                    if ok then result.rewardType=def.rewardType;result.amount=self.codec.BigAmount.encode(def.amountNumber);result.day=day;result.cycle=m end
                end
            elseif op.kind=="ClaimTrophy" then
                if args.eggIndex~=draft.farm.eggIndex then code="WRONG_EGG"
                else
                    local pop=self.codec.ExactUInt.decode("0")
                    for _,hab in draft.farm.habitats do pop=self.codec.ExactUInt.add(pop,self.codec.ExactUInt.decode(hab.population)) end
                    -- Clamp only after exact comparison: trophy thresholds are <= 10 billion.
                    local limit=self.codec.ExactUInt.decode("10000000000")
                    local population=if self.codec.ExactUInt.compare(pop,limit)>=0 then 10000000000 else self.codec.ExactUInt.toSafeNumber(pop)
                    local catalog={};for k,v in ActionReference.trophies do catalog[tonumber(k)]=v end
                    local reward;ok,reward,code=Trophies.claimTrophy(draft,args.eggIndex,args.tierIndex,population,catalog)
                end
            elseif op.kind=="FusePets" then
                local policy=self.fusionPolicy
                if policy and policy.mode=="INTERNAL_TEST_ONLY" and policy.recipes and type(policy.draw)=="function" then
                    local res
                    local bonus=Products.isProBonusAvailable(draft,Products.readPaidRandomPolicy(self.paidRandomAllowed,playerId))
                    bonusSnapshot=bonus
                    local eligible,preview=Fusion.getFusionPreview(draft.inventory,args.basePetId,args.materialIds,bonus,policy.recipes)
                    if eligible then
                        ok,res=Fusion.executeFusion(draft.inventory,args.basePetId,args.materialIds,bonus,policy.recipes,policy.draw())
                    else ok=false;res=preview end
                    if ok then result.success=res.success;result.outcome=res.status;result.petUid=args.basePetId else code=res end
                end
            elseif op.kind=="BuyBoost" then
                local offer=self.boostShop and self.boostShop.mode=="INTERNAL_TEST_ONLY" and self.boostShop[args.boostId]
                if offer then
                    local U=self.codec.ExactUInt
                    local cost=U.decode(offer.costGE)
                    if U.compare(U.decode(draft.permanent.GE),cost)<0 then code="INSUFFICIENT_GE"
                    else
                        draft.permanent.GE=U.encode(U.subtract(U.decode(draft.permanent.GE),cost))
                        draft.permanent.totalGESpent=U.encode(U.add(U.decode(draft.permanent.totalGESpent),cost))
                        draft.inventory.boosts[args.boostId]=U.encode(U.add(U.decode(draft.inventory.boosts[args.boostId] or "0"),U.decode("1")))
                        ok=true
                    end
                end
            elseif op.kind=="PurchaseProduct" then
                local spec=self.platformProducts[args.productId]
                if spec and type(spec.platformId)=="number" and spec.platformId>0 and spec.platformId%1==0 and spec.platformId<=9007199254740991 then
                    local allowed=Products.readPaidRandomPolicy(self.paidRandomAllowed,playerId)
                    policySnapshot=allowed
                    if args.productId~="pro_permit" or type(allowed)=="boolean" then
                        local preview=Products.previewPurchase(draft,args.productId,{paidRandomAllowed=allowed},false)
                        if preview.isAvailable then
                            ok=true;result.productId=preview.productId;result.platformId=spec.platformId;result.productType=preview.productType
                            result.description=preview.description;result.paidBonusAvailable=preview.paidBonusAvailable
                        else code=preview.error end
                    else code="POLICY_UNAVAILABLE" end
                end
            end
            if not ok then return {profile=candidateProfile,terminalStatus="REJECTED",result={errorCode=code or "OPERATION_REJECTED"},validate=function()return false,code end} end
            return {profile=draft,terminalStatus="APPLIED",result=result,validate=function(fresh)
                local current=Products.readPaidRandomPolicy(self.paidRandomAllowed,playerId)
                if op.kind=="PurchaseProduct" and args.productId=="pro_permit" and current~=policySnapshot then return false,"POLICY_CHANGED" end
                if op.kind=="FusePets" and Products.isProBonusAvailable(fresh,current)~=bonusSnapshot then return false,"POLICY_CHANGED" end
                return true
            end}
        end
		if op.kind == "UpgradeEgg" or op.kind == "Prestige" then
			local deps={catalog=self.catalog,productionMath=self.productionMath}
            if op.kind=="Prestige" then
                deps.prestigeEventMult=Effects.calculateMultipliers(nil,candidateProfile.farm,self.clock.utcNowMs(),self.liveEvents).eventPrestigeMult
            end
            local outcome=ProgressActions.apply(candidateProfile,op,deps)
            if op.kind=="Prestige" then
                local validate=outcome.validate
                outcome.validate=function(fresh,now)
                    local current=Effects.calculateMultipliers(nil,fresh.farm,now,self.liveEvents).eventPrestigeMult
                    if current~=deps.prestigeEventMult then return false,"PRESTIGE_EVENT_CHANGED" end
                    return validate(fresh,now)
                end
            end
            return outcome
		elseif op.kind == "PlatformPurchase" or op.kind == "ConfirmPurchase" then
			local pToken = (op.args and op.args.purchaseToken) or op.operationId
			local receiptInfo = op.args and op.args.receiptInfo
			local nowMs = self.clock.utcNowMs()
			local isPiggyEnabled = (self.config and self.config.isPiggyEnabled ~= false)
			local ok, res = Products.confirmPurchase(candidateProfile, pToken, receiptInfo, nowMs, isPiggyEnabled,{paidRandomAllowed=Products.readPaidRandomPolicy(self.paidRandomAllowed,playerId)})
			return {
				profile = candidateProfile,
				result = res,
				terminalStatus = if ok then "APPLIED" else "REJECTED",
				validate = function() return ok, if not ok then res.error else nil end,
			}
		elseif op.kind == "GrantEntitlement" then
			local entId = op.args and op.args.entitlementId
			local nowMs = self.clock.utcNowMs()
			candidateProfile.entitlements = candidateProfile.entitlements or {}
			if entId == "pro_permit" then
				candidateProfile.entitlements.pro_permit = true
				candidateProfile.entitlements.pro_permit_effective_at = candidateProfile.entitlements.pro_permit_effective_at or nowMs
				candidateProfile.entitlements.pro_plus10_enabled = Products.readPaidRandomPolicy(self.paidRandomAllowed,playerId) == true
			elseif entId == "buy_max" then
				candidateProfile.entitlements.buy_max = true
				candidateProfile.entitlements.buy_max_effective_at = nowMs
			end
			return {
				profile = candidateProfile,
				result = { granted = entId },
				terminalStatus = "APPLIED",
				validate = function() return true end,
			}
  elseif op.kind == "IssueDrone" or op.kind == "IssueOffer" then
   local draft=self.data.copy(candidateProfile)
   local id=op.args.id
   local now=self.clock.utcNowMs()
   local function reject(code)
    return {profile=candidateProfile,result={error=code},terminalStatus="REJECTED",validate=function()return false,code end}
   end
   if not validId(id) then return reject("INVALID_REQUEST") end
   if op.kind=="IssueDrone" then
    local records=draft.rewards.droneSpawns or {}
    if records[id] or (draft.rewards.claimedDrones and draft.rewards.claimedDrones[id]) then return reject("DUPLICATE_SPAWN_ID") end
    local terms=op.args.terms
    local spawn=Drones.createDroneSpawn(id,now,terms.config,draft,terms.petEliteMult,terms.rollElite)
    spawn.ownerId=pId;spawn.terms=self.data.copy(terms)
    records[id]=spawn;draft.rewards.droneSpawns=records
   else
    local state=draft.rewards.offers or Offers.createOffersState()
    local ok,offer,code=Offers.createOffer(state,id,op.args.channel,op.args.reward,now)
    if not ok then return reject(code) end
    offer.ownerId=pId;offer.costGE=op.args.costGE
    draft.rewards.offers=state
   end
   return {profile=draft,result={id=id},validate=function()return true end}
  elseif op.kind == "HitDrone" then
   local id=op.args.droneId
   local original=candidateProfile.rewards.droneSpawns and candidateProfile.rewards.droneSpawns[id]
   local function reject(code)
    return {profile=candidateProfile,result={error=code},terminalStatus="REJECTED",validate=function()return false,code end}
   end
   if not original then return reject("UNKNOWN_SPAWN") end
   if original.ownerId~=pId then return reject("SPAWN_NOT_OWNED") end
   local now=self.clock.utcNowMs()
   if now<original.createdAtMs then return reject("SPAWN_NOT_ACTIVE") end
   local draft=self.data.copy(candidateProfile)
   local spawn=draft.rewards.droneSpawns[id]
   local terms=spawn.terms
   local ok,reward=Drones.claimDrone(spawn,now,draft,terms.config,terms.rolls,terms.farmValue,terms.curve0FarmValue)
   if not ok then return reject(reward) end
   return {profile=draft,result={droneId=id,reward=reward},validate=function(fresh,at)
    local saved=fresh.rewards.droneSpawns and fresh.rewards.droneSpawns[id]
    return saved~=nil and saved.ownerId==pId and not saved.claimed and at>=saved.createdAtMs and at<=saved.expiresAtMs,"SPAWN_NOT_ACTIVE"
   end}
  elseif op.kind == "ClaimOffer" then
   local id=op.args.offerId
   local state=candidateProfile.rewards.offers
   local offer=state and Offers.findOffer(state,id)
   local function reject(code)
    return {profile=candidateProfile,result={error=code},terminalStatus="REJECTED",validate=function()return false,code end}
   end
   if not offer then return reject("OFFER_NOT_FOUND") end
   if offer.ownerId~=pId then return reject("OFFER_NOT_OWNED") end
   local now=self.clock.utcNowMs()
   if offer.channel=="bonus" and not Offers.isBonusClaimFree(candidateProfile,now) and offer.costGE==nil then return reject("FEATURE_UNAVAILABLE") end
   local draft=self.data.copy(candidateProfile)
   local ok,result=Offers.claimOffer(draft.rewards.offers,id,now,draft,offer.costGE)
   if not ok then return reject(result.error) end
   return {profile=draft,result=result,validate=function(fresh)
    local saved=fresh.rewards.offers and Offers.findOffer(fresh.rewards.offers,id)
    return saved~=nil and saved.ownerId==pId and saved.status=="PENDING","OFFER_NOT_AVAILABLE"
   end}
		elseif op.kind == "HatchPetEgg" or op.kind == "HatchPet" then
   local policy=self.petHatchTestPolicy
   if not policy or policy.mode~="INTERNAL_TEST_ONLY" then
    return {profile=candidateProfile,result={error="FEATURE_UNAVAILABLE"},terminalStatus="REJECTED",validate=function()return false,"FEATURE_UNAVAILABLE" end}
   end
   local costGE=policy.costGE
   assert(type(costGE)=="number" and costGE>0 and costGE%1==0 and costGE<=9007199254740991,"INVALID_TEST_HATCH_COST")
			candidateProfile.permanent = candidateProfile.permanent or {}
			local currentGE = self.codec.ExactUInt.decode(candidateProfile.permanent.GE or "0")
			local costExact = self.codec.ExactUInt.fromSafeNumber(costGE)
			if self.codec.ExactUInt.compare(currentGE, costExact) < 0 then
				return {
					profile = candidateProfile,
					result = { error = "INSUFFICIENT_GE", costGE = costGE },
					terminalStatus = "REJECTED",
					validate = function() return false, "INSUFFICIENT_GE" end,
				}
			end

			-- Deduct GE
			candidateProfile.permanent.GE = self.codec.ExactUInt.encode(self.codec.ExactUInt.subtract(currentGE, costExact))
			local curSpent = self.codec.ExactUInt.decode(candidateProfile.permanent.totalGESpent or "0")
			candidateProfile.permanent.totalGESpent = self.codec.ExactUInt.encode(self.codec.ExactUInt.add(curSpent, costExact))

			-- Determine species from TEST_ONLY_CATALOG
			local roll = if policy.draw then policy.draw() else math.random()
   assert(type(roll)=="number" and roll>=0 and roll<1,"INVALID_SERVER_ROLL")
			local chosenSpeciesId = "farmer_dog"
			local rarity = "Common"
			if roll < 0.05 then
				chosenSpeciesId = "drone_hawk"
				rarity = "Legendary"
			elseif roll < 0.17 then
				chosenSpeciesId = "mega_rooster"
				rarity = "Epic"
			elseif roll < 0.42 then
				chosenSpeciesId = "golden_pecker"
				rarity = "Rare"
			elseif roll < 0.70 then
				chosenSpeciesId = "robo_cock"
				rarity = "Rare"
			else
				chosenSpeciesId = "farmer_dog"
				rarity = "Common"
			end

			-- Determine variant
			local variantRoll = if policy.draw then policy.draw() else math.random()
   assert(type(variantRoll)=="number" and variantRoll>=0 and variantRoll<1,"INVALID_SERVER_ROLL")
			local variant = "normal"
			if variantRoll < 0.02 then
				variant = "rainbow"
			elseif variantRoll < 0.10 then
				variant = "golden"
			end

   local seq=self.codec.ExactUInt.decode(candidateProfile.inventory.petSequence or "0")
   local petUid
   repeat
    seq=self.codec.ExactUInt.add(seq,self.codec.ExactUInt.fromSafeNumber(1))
    petUid="pet-"..self.codec.ExactUInt.encode(seq)
   until not candidateProfile.inventory.pets[petUid]
   candidateProfile.inventory.petSequence=self.codec.ExactUInt.encode(seq)

			local newPet = {
				uid = petUid,
				speciesId = chosenSpeciesId,
				tier = 1,
				variant = variant,
				locked = false,
				rarity = rarity,
			}

			candidateProfile.inventory = candidateProfile.inventory or {}
			candidateProfile.inventory.pets = candidateProfile.inventory.pets or {}
			candidateProfile.inventory.equipped = candidateProfile.inventory.equipped or {}
			candidateProfile.inventory.guarantees = candidateProfile.inventory.guarantees or {}

			local okAdd, addErr = Equipment.addPet(candidateProfile.inventory, newPet)
			if not okAdd then
				return {
					profile = candidateProfile,
					result = { error = addErr or "ADD_PET_FAILED" },
					terminalStatus = "REJECTED",
					validate = function() return false, addErr or "ADD_PET_FAILED" end,
				}
			end

			return {
				profile = candidateProfile,
				result = {
					success = true,
					pet = newPet,
					costGE = costGE,
				},
				terminalStatus = "APPLIED",
				validate = function() return true end,
			}
		elseif op.kind == "EquipPet" then
			local petUid = op.args and (op.args.petUid or op.args.petId)
			local isPro = candidateProfile.entitlements and candidateProfile.entitlements.pro_permit == true
			candidateProfile.inventory = candidateProfile.inventory or {}
			candidateProfile.inventory.pets = candidateProfile.inventory.pets or {}
			candidateProfile.inventory.equipped = candidateProfile.inventory.equipped or {}
			local okEq, errEq = Equipment.equipPet(candidateProfile.inventory, petUid, isPro)
			return {
				profile = candidateProfile,
				result = if okEq then {terminalStatus="APPLIED",actionKind="EquipPet",success=true,petUid=petUid} else {errorCode=errEq},
				terminalStatus = if okEq then "APPLIED" else "REJECTED",
				validate = function() return okEq, errEq end,
			}
		elseif op.kind == "UnequipPet" then
			local petUid = op.args and (op.args.petUid or op.args.petId)
            if op.args and op.args.slotIndex then petUid=candidateProfile.inventory.equipped[op.args.slotIndex] end
			candidateProfile.inventory = candidateProfile.inventory or {}
			candidateProfile.inventory.equipped = candidateProfile.inventory.equipped or {}
			local okUneq, errUneq = Equipment.unequipPet(candidateProfile.inventory, petUid)
			return {
				profile = candidateProfile,
				result = if okUneq then {terminalStatus="APPLIED",actionKind="UnequipPet",success=true,petUid=petUid} else {errorCode=errUneq},
				terminalStatus = if okUneq then "APPLIED" else "REJECTED",
				validate = function() return okUneq, errUneq end,
			}
		elseif op.kind == "TogglePetLock" or op.kind == "SetPetLock" then
			local petUid = op.args and (op.args.petUid or op.args.petId)
			candidateProfile.inventory = candidateProfile.inventory or {}
			candidateProfile.inventory.pets = candidateProfile.inventory.pets or {}
			local curPet = candidateProfile.inventory.pets[petUid]
			local newLock = if op.args and op.args.locked ~= nil then op.args.locked else if curPet then not curPet.locked else true
			local okLock, errLock = Equipment.setPetLock(candidateProfile.inventory, petUid, newLock)
			return {
				profile = candidateProfile,
				result = if okLock then {terminalStatus="APPLIED",actionKind="TogglePetLock",success=true,petUid=petUid,locked=newLock} else {errorCode=errLock},
				terminalStatus = if okLock then "APPLIED" else "REJECTED",
				validate = function() return okLock, errLock end,
			}
		end
		return self.farmActions.apply(candidateProfile, op)
	end

	local coordinator = PlayerCoordinator.new({
		mode = "INTERNAL_TEST_ONLY",
		codec = self.codec,
		data = self.data,
		repository = self.repository,
		handle = handle,
		clock = self.clock,
		maxQueue = 32,
		simulation = { advance = simulationAdvance },
		domain = { apply = domainApply },
	})

	-- Set coordinator ready so requests can be admitted
	local readyRes = coordinator.setReady(true)
	assert(readyRes.status == "READY_SET", "COORDINATOR_READY_FAILED")

	playerSession.coordinator = coordinator

	-- 3. Register player in NetworkGateway
	self.gateway:registerPlayer(pId, coordinator)
	local pData = self.gateway:getPlayerState(pId)
	if pData and pData.streamId then
		playerSession.hatchingRuntime.streamId = pData.streamId
	end

	self.players[pId] = playerSession

	return {
		status = "JOINED",
		playerId = pId,
		coordinator = coordinator,
		handle = handle,
		streamId = (pData and pData.streamId) or ("stream-" .. pId .. "-1"),
	}
end

function ServerBootstrap:playerLeaving(playerId)
	local pId = tostring(playerId)
	local playerSession = self.players[pId]
	if not playerSession then
		return false, "PLAYER_NOT_FOUND"
	end

	local coordinator = playerSession.coordinator

	-- 1. Execute checkpoint
	local nowMs = self.clock.utcNowMs()

	-- Proactively renew lease if near expiration so checkpoint is guaranteed to commit
	if playerSession.handle and playerSession.handle.endsAtMs and (nowMs >= playerSession.handle.endsAtMs - 45000) then
		coordinator.renew()
		coordinator.drain()
	end

	local snapshots = coordinator.snapshots()
	local currentRev = (snapshots.durable and snapshots.durable.meta and snapshots.durable.meta.revision) or "0"

	local cpOp = {
		operationId = "checkpoint-" .. pId .. "-" .. tostring(nowMs),
		kind = "Checkpoint",
		expectedRevision = currentRev,
		args = {},
	}
	coordinator.checkpoint(cpOp)
	coordinator.drain()

	-- 2. Release session in repository
	coordinator.release()
	coordinator.drain()

	-- 3. Unregister from gateway
	self.gateway:unregisterPlayer(pId)
	if self.farmActions.forgetPlayer then self.farmActions.forgetPlayer(pId) end

	-- 4. Clean up local session
	self.players[pId] = nil

	return true
end

function ServerBootstrap:checkpointPlayer(playerId)
	local pId = tostring(playerId)
	local playerSession = self.players[pId]
	if not playerSession then
		return false, "PLAYER_NOT_FOUND"
	end

	local coordinator = playerSession.coordinator
	local nowMs = self.clock.utcNowMs()

	if playerSession.handle and playerSession.handle.endsAtMs and (nowMs >= playerSession.handle.endsAtMs - 45000) then
		coordinator.renew()
		coordinator.drain()
	end

	local snapshots = coordinator.snapshots()
	local currentRev = (snapshots.durable and snapshots.durable.meta and snapshots.durable.meta.revision) or "0"

	local cpOp = {
		operationId = "checkpoint-" .. pId .. "-" .. tostring(nowMs),
		kind = "Checkpoint",
		expectedRevision = currentRev,
		args = {},
	}
	coordinator.checkpoint(cpOp)
	coordinator.drain()

	local res = coordinator.resultOf(cpOp.operationId)
	return true, res
end

function ServerBootstrap:checkpointAll()
	local results = {}
	for pId, _ in pairs(self.players) do
		local ok, res = self:checkpointPlayer(pId)
		results[pId] = { ok = ok, result = res }
	end
	return results
end

function ServerBootstrap:close()
	local pIds = {}
	for pId, _ in pairs(self.players) do
		table.insert(pIds, pId)
	end
	local results = {}
	for _, pId in ipairs(pIds) do
		local ok, res = self:playerLeaving(pId)
		results[pId] = { ok = ok, result = res }
	end
	return results
end

function ServerBootstrap:applyPurchase(playerId, receiptInfo)
	if not self.purchasesEnabled then return false, "LOCAL_PAYMENTS_DISABLED" end
	local pId = tostring(playerId)
	local playerSession = self.players[pId]
	if not playerSession then
		return false, "PLAYER_NOT_CONNECTED"
	end

	if type(receiptInfo) ~= "table" then
		return false, "INVALID_RECEIPT_INFO"
	end

	local purchaseId = receiptInfo.PurchaseId or receiptInfo.purchaseToken or receiptInfo.purchaseId
	if not purchaseId then
		return false, "MISSING_PURCHASE_ID"
	end
	local purchaseToken = tostring(purchaseId)

	local coordinator = playerSession.coordinator
	local snapshots = coordinator.snapshots()
	local currentRev = (snapshots.durable and snapshots.durable.meta and snapshots.durable.meta.revision) or "0"

	local op = {
		operationId = "receipt-" .. purchaseToken,
		kind = "PlatformPurchase",
		expectedRevision = currentRev,
		args = {
			purchaseToken = purchaseToken,
			receiptInfo = receiptInfo,
		},
	}

	local admission = coordinator.submit(op)
	local res
	if admission.status == "REPLAYED" or admission.status == "REJECTED" or admission.status == "NOT_ACCEPTED" then
		res = admission -- a durable replay may not have an in-process entry after restart
	else
		coordinator.drain()
		res = coordinator.resultOf(op.operationId)
	end
	if res and (res.status == "APPLIED" or (res.status == "REPLAYED" and res.terminalStatus == "APPLIED")) then
		self:checkpointPlayer(pId)
		return true, res
	end

	return false, (res and res.errorCode) or "PURCHASE_FAILED"
end

function ServerBootstrap:grantEntitlement(playerId, entitlementId, _legacyOpts)
	if not self.purchasesEnabled then return false, "LOCAL_PAYMENTS_DISABLED" end
	if entitlementId ~= "pro_permit" and entitlementId ~= "buy_max" then return false, "UNKNOWN_ENTITLEMENT" end
	local pId = tostring(playerId)
	local playerSession = self.players[pId]
	if not playerSession then
		return false, "PLAYER_NOT_CONNECTED"
	end

	local coordinator = playerSession.coordinator
	local snapshots = coordinator.snapshots()
	local currentRev = (snapshots.durable and snapshots.durable.meta and snapshots.durable.meta.revision) or "0"
	local op = playerSession.pendingEntitlements[entitlementId]
	if not op then
	self._entitlementSerial=(self._entitlementSerial or 0)+1
	op = {
		operationId = "entitlement-" .. pId .. "-" .. entitlementId .. "-" .. snapshots.durable.ownership.generation .. "-" .. tostring(self.clock.utcNowMs()) .. "-" .. tostring(self._entitlementSerial),
		kind = "GrantEntitlement",
		expectedRevision = currentRev,
		args = {
			entitlementId = entitlementId,
		},
	}
	playerSession.pendingEntitlements[entitlementId] = op
	end
	-- Preserve the operation ID while the write result is unknown. Only retry a
	-- known non-execution after settlement, under the current committed revision.
	local previous = coordinator.resultOf(op.operationId)
	if previous and ((previous.status == "UNKNOWN" and previous.errorCode ~= "STATUS_NOT_TRACKED") or (previous.status == "REPLAYED" and not snapshots.ready)) then
		previous = coordinator.query(op.operationId)
		if not coordinator.snapshots().ready then
			local recovered = coordinator.recover(op.operationId)
			if recovered.status ~= "ACQUIRED" then return false, "UNKNOWN" end
			coordinator.setReady(true)
			previous = coordinator.resultOf(op.operationId)
			currentRev = coordinator.snapshots().durable.meta.revision
		end
		if previous.status == "UNKNOWN" then return false, "UNKNOWN" end
	end
	if previous and (previous.status == "APPLIED" or (previous.status == "REPLAYED" and previous.terminalStatus == "APPLIED")) then
		playerSession.pendingEntitlements[entitlementId] = nil
		return true, previous
	end
	op.expectedRevision = currentRev

	coordinator.submit(op,{kind="TimeAdvance",targetMs=self.clock.utcNowMs(),budget=100})
	coordinator.drain()

	local res = coordinator.resultOf(op.operationId)
	if res and (res.status == "APPLIED" or (res.status == "REPLAYED" and res.terminalStatus == "APPLIED")) then
		playerSession.pendingEntitlements[entitlementId] = nil
		self:checkpointPlayer(pId)
		return true, res
	end

	if res and (res.status == "REJECTED" or (res.status == "REPLAYED" and res.terminalStatus == "REJECTED")) then
		self._entitlementSerial += 1
		op.operationId = "entitlement-" .. pId .. "-" .. entitlementId .. "-" .. snapshots.durable.ownership.generation .. "-" .. tostring(self.clock.utcNowMs()) .. "-" .. tostring(self._entitlementSerial)
	end
	return false, (res and res.errorCode) or "GRANT_FAILED"
end

-- All callers below enter the same durable single-writer path. No extra checkpoint
-- after APPLIED: the claim, reward and terminal result already share one commit.
function ServerBootstrap:_rewardOperation(playerId,kind,args,operationId)
 local session=self.players[tostring(playerId)]
 if not session then return false,"PLAYER_NOT_CONNECTED" end
 local c=session.coordinator
 local snapshots=c.snapshots()
 local op={operationId=operationId,kind=kind,expectedRevision=snapshots.durable.meta.revision,args=args}
 local admission=c.submit(op)
 if admission.status=="PENDING" then c.drain() end
 local res=if admission.status=="PENDING" then c.resultOf(operationId) else admission
 if res.status=="APPLIED" or (res.status=="REPLAYED" and res.terminalStatus=="APPLIED") then return true,res.result end
 return false,res.errorCode or (res.result and (res.result.error or res.result.errorCode)) or res.status
end

function ServerBootstrap:_issueOperation(playerId,kind,args)
 local session=self.players[tostring(playerId)]
 if not session then return false,"PLAYER_NOT_CONNECTED" end
 self._issueSerial=(self._issueSerial or 0)+1
 local generation=session.coordinator.snapshots().durable.ownership.generation
 return self:_rewardOperation(playerId,kind,args,"issue-"..generation.."-"..tostring(self._issueSerial).."-"..kind)
end

-- Trusted host APIs, deliberately absent from Remote/Gateway handlers. They do
-- not schedule spawns/offers or invent reward amounts on missing configuration.
function ServerBootstrap:issueDrone(playerId,id,terms)
 if not validId(id) or type(terms)~="table" then return false,"INVALID_REQUEST" end
 local ok,fixed=pcall(self.data.copy,terms)
 if not ok or type(fixed.farmValue)~="number" or fixed.farmValue<0 or type(fixed.curve0FarmValue)~="number" or fixed.curve0FarmValue<=0 then return false,"INVALID_REWARD_TERMS" end
 return self:_issueOperation(playerId,"IssueDrone",{id=id,terms=fixed})
end

function ServerBootstrap:issueOffer(playerId,id,channel,reward,costGE)
 if not validId(id) or (channel~="ordinary" and channel~="bonus") then return false,"INVALID_REQUEST" end
 local ok,fixed=pcall(self.data.copy,reward)
 if not ok or type(fixed)~="table" then return false,"INVALID_REWARD" end
 if costGE~=nil and (type(costGE)~="number" or costGE<=0 or costGE%1~=0 or costGE>9007199254740991) then return false,"INVALID_COST" end
 return self:_issueOperation(playerId,"IssueOffer",{id=id,channel=channel,reward=fixed,costGE=costGE})
end

function ServerBootstrap:hitDrone(playerId,id,options)
 if not validId(id) or not validIntent(options,CLAIM_FIELDS) then return false,"INVALID_REQUEST" end
 local session=self.players[tostring(playerId)]
 if not session then return false,"PLAYER_NOT_CONNECTED" end
 local p=session.coordinator.snapshots().durable
 if not (p.rewards.droneSpawns and p.rewards.droneSpawns[id]) then return false,"UNKNOWN_SPAWN" end
 local ok,result=self:_rewardOperation(playerId,"HitDrone",{droneId=id},(options and options.operationId) or ("drone-"..id))
 return ok,if ok then result.reward else result
end

function ServerBootstrap:claimOffer(playerId,id,options)
 if not validId(id) or not validIntent(options,CLAIM_FIELDS) then return false,"INVALID_REQUEST" end
 local session=self.players[tostring(playerId)]
 if not session then return false,"PLAYER_NOT_CONNECTED" end
 local p=session.coordinator.snapshots().durable
 if not (p.rewards.offers and Offers.findOffer(p.rewards.offers,id)) then return false,"OFFER_NOT_FOUND" end
 local ok,result=self:_rewardOperation(playerId,"ClaimOffer",{offerId=id},(options and options.operationId) or ("offer-"..id))
 return ok,if ok then result.reward else result
end

function ServerBootstrap:getOffersState(playerId)
 local session=self.players[tostring(playerId)]
 if not session then return nil end
 local p=session.coordinator.snapshots().durable
 return self.data.copy(p.rewards.offers or Offers.createOffersState())
end

function ServerBootstrap:hatchPet(playerId,intent)
 if not validIntent(intent,HATCH_FIELDS) then return false,"INVALID_REQUEST" end
 if intent and intent.kind and intent.kind~="HatchPetEgg" and intent.kind~="HatchPet" then return false,"INVALID_REQUEST" end
 if intent and intent.eggType and intent.eggType~="standard_egg" then return false,"FEATURE_UNAVAILABLE" end
 self._petHatchSerial=(self._petHatchSerial or 0)+1
 local session=self.players[tostring(playerId)]
 if not session then return false,"PLAYER_NOT_CONNECTED" end
 local durable=session.coordinator.snapshots().durable
 local generation=durable.ownership.generation
 local operationId=(intent and intent.operationId) or (intent and intent.requestId and ("pet-"..intent.requestId)) or ("hatch-"..generation.."-"..tostring(self._petHatchSerial))
 if (not self.petHatchTestPolicy or self.petHatchTestPolicy.mode~="INTERNAL_TEST_ONLY") and not durable.operations[operationId] then return false,"FEATURE_UNAVAILABLE" end
 return self:_rewardOperation(playerId,"HatchPetEgg",{eggType="standard_egg"},operationId)
end

function ServerBootstrap:handleRewardRequest(playerId,message)
 local fields={kind=true,protocolVersion=true,requestId=true,operationId=true}
 if type(message)~="table" or getmetatable(message)~=nil then return false,"INVALID_REQUEST" end
 local kind=message.kind
 if kind=="HitDrone" then fields.droneId=true
 elseif kind=="ClaimOffer" then fields.offerId=true
 elseif kind=="HatchPetEgg" or kind=="HatchPet" then fields.eggType=true
 else return false,"INVALID_REQUEST" end
 if not validIntent(message,fields) or message.protocolVersion~=1 then return false,"INVALID_REQUEST" end
 if kind=="HatchPetEgg" or kind=="HatchPet" then return self:hatchPet(playerId,message) end
 local options={operationId=message.operationId,requestId=message.requestId}
 if kind=="HitDrone" then return self:hitDrone(playerId,message.droneId,options) end
 return self:claimOffer(playerId,message.offerId,options)
end

function ServerBootstrap:equipPet(playerId, petUid)
	local pId = tostring(playerId)
	local playerSession = self.players[pId]
	if not playerSession then
		return false, "PLAYER_NOT_CONNECTED"
	end

	self._petEquipSerial = (self._petEquipSerial or 0) + 1
	local coordinator = playerSession.coordinator
	local snapshots = coordinator.snapshots()
	local currentRev = (snapshots.durable and snapshots.durable.meta and snapshots.durable.meta.revision) or "0"

	local op = {
		operationId = "equip-pet-" .. pId .. "-" .. tostring(petUid) .. "-" .. tostring(self.clock.utcNowMs()) .. "-" .. tostring(self._petEquipSerial),
		kind = "EquipPet",
		expectedRevision = currentRev,
		args = {
			petUid = petUid,
		},
	}

	coordinator.submit(op,{kind="TimeAdvance",targetMs=self.clock.utcNowMs(),budget=100})
	coordinator.drain()

	local res = coordinator.resultOf(op.operationId)
	if res and (res.status == "APPLIED" or (res.status == "REPLAYED" and res.terminalStatus == "APPLIED")) then
		self:checkpointPlayer(pId)
		return true, res.result
	end

	return false, (res and (res.errorCode or (res.result and (res.result.error or res.result.errorCode)))) or "EQUIP_FAILED"
end

function ServerBootstrap:unequipPet(playerId, petUid)
	local pId = tostring(playerId)
	local playerSession = self.players[pId]
	if not playerSession then
		return false, "PLAYER_NOT_CONNECTED"
	end

	self._petUnequipSerial = (self._petUnequipSerial or 0) + 1
	local coordinator = playerSession.coordinator
	local snapshots = coordinator.snapshots()
	local currentRev = (snapshots.durable and snapshots.durable.meta and snapshots.durable.meta.revision) or "0"

	local op = {
		operationId = "unequip-pet-" .. pId .. "-" .. tostring(petUid) .. "-" .. tostring(self.clock.utcNowMs()) .. "-" .. tostring(self._petUnequipSerial),
		kind = "UnequipPet",
		expectedRevision = currentRev,
		args = {
			petUid = petUid,
		},
	}

	coordinator.submit(op,{kind="TimeAdvance",targetMs=self.clock.utcNowMs(),budget=100})
	coordinator.drain()

	local res = coordinator.resultOf(op.operationId)
	if res and (res.status == "APPLIED" or (res.status == "REPLAYED" and res.terminalStatus == "APPLIED")) then
		self:checkpointPlayer(pId)
		return true, res.result
	end

	return false, (res and (res.errorCode or (res.result and (res.result.error or res.result.errorCode)))) or "UNEQUIP_FAILED"
end

function ServerBootstrap:togglePetLock(playerId, petUid, locked)
	local pId = tostring(playerId)
	local playerSession = self.players[pId]
	if not playerSession then
		return false, "PLAYER_NOT_CONNECTED"
	end

	self._petLockSerial = (self._petLockSerial or 0) + 1
	local coordinator = playerSession.coordinator
	local snapshots = coordinator.snapshots()
	local currentRev = (snapshots.durable and snapshots.durable.meta and snapshots.durable.meta.revision) or "0"

	local op = {
		operationId = "lock-pet-" .. pId .. "-" .. tostring(petUid) .. "-" .. tostring(self.clock.utcNowMs()) .. "-" .. tostring(self._petLockSerial),
		kind = "TogglePetLock",
		expectedRevision = currentRev,
		args = {
			petUid = petUid,
			locked = locked,
		},
	}

	coordinator.submit(op)
	coordinator.drain()

	local res = coordinator.resultOf(op.operationId)
	if res and (res.status == "APPLIED" or (res.status == "REPLAYED" and res.terminalStatus == "APPLIED")) then
		self:checkpointPlayer(pId)
		return true, res.result
	end

	return false, (res and (res.errorCode or (res.result and (res.result.error or res.result.errorCode)))) or "LOCK_FAILED"
end

function ServerBootstrap:tick(dtSeconds, nowMs)
	if dtSeconds ~= nil and type(self.clock.advance) == "function" then
		self.clock.advance(dtSeconds)
	elseif nowMs ~= nil and type(self.clock.set) == "function" then
		self.clock.set(nowMs)
	end

	local currentNowMs = nowMs or self.clock.utcNowMs()

	for playerId, playerSession in pairs(self.players) do
		local coordinator = playerSession.coordinator
		if coordinator then
			if playerSession.handle and playerSession.handle.endsAtMs and (currentNowMs >= playerSession.handle.endsAtMs - 45000) then
				coordinator.renew()
			end
			coordinator.tick({
				kind = "TimeAdvance",
				dtSeconds = dtSeconds,
				targetMs = currentNowMs,
				budget = 100,
			})
			coordinator.drain()
			self:_reconcileReset(playerSession)
			for entitlementId, pending in pairs(playerSession.pendingEntitlements) do
				local result = coordinator.resultOf(pending.operationId)
				if coordinator.snapshots().ready or result.status == "UNKNOWN" or result.status == "REPLAYED" then self:grantEntitlement(playerId, entitlementId) end
			end
		end
	end
end

function ServerBootstrap:getCoordinator(playerId)
	local pId = tostring(playerId)
	local s = self.players[pId]
	return if s then s.coordinator else nil
end

function ServerBootstrap:getPlayer(playerId)
	local pId = tostring(playerId)
	return self.players[pId]
end

function ServerBootstrap:getGateway()
	return self.gateway
end

function ServerBootstrap:getRepository()
	return self.repository
end

function ServerBootstrap:dispatch(playerId, message)
	local result = self.gateway:handleRequest(playerId, message)
	local session = self.players[tostring(playerId)]
	if session then self:_reconcileReset(session) end
	return result
end
ServerBootstrap.handleRequest = ServerBootstrap.dispatch

function ServerBootstrap:createPlayerDelta(playerId)
	local pId = tostring(playerId)
	return self.gateway:createPlayerDelta(pId)
end

return table.freeze(ServerBootstrap)
