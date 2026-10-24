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

local FvSe = resolve(function()
	return script.Parent.FarmMath.fv_se
end, "./FarmMath/fv_se")

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

local function neutralProfile(p)
	p.effects = p.effects or {}
	p.effects.boosts = p.effects.boosts or {}
	p.inventory = p.inventory or {}
	p.inventory.equipped = p.inventory.equipped or {}
end

local function profileToMemory(p, codec, productionMath, data)
	neutralProfile(p)
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

	local capacities = productionMath.capacities(f.commonLevels, types)
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
	out.timeline.settledWallThrough = state.settledWallThrough
	out.timeline.integrationCheckpoint = checkpoint
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

local ServerBootstrap = {}
ServerBootstrap.__index = ServerBootstrap

function ServerBootstrap.new(deps)
	deps = deps or {}

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
		codec = codec,
		catalog = catalog,
		productionMath = productionMath,
		configRevision = configRevision,
	})

	local clock = deps.clock or createDefaultClock(deps.initialNowMs or 1000000)
	local store = deps.store or createMemoryStore(data)

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

function ServerBootstrap:_simulationAdvance(playerSession, profile, request)
	if request == nil then
		return { profile = profile, complete = true }
	end

	if request.kind == "HatchPress" or request.kind == "HatchInput" then
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
		local capacities = self.productionMath.capacities(common, types)
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
	else
		local simConfig = {
			revision = self.configRevision,
			siloCapacityLevel = (self.config and self.config.siloCapacityLevel) or 0,
			pro = if (profile.entitlements and profile.entitlements.pro_permit == true) then true else ((self.config and self.config.pro) or false),
		}
		cp = self.timeline.begin(mem, targetMs, simConfig)
	end

	cp = self.timeline.advance(cp, budget)

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
		hatchingRuntime = {
			streamId = "stream-" .. pId .. "-1",
			lastInputSeq = "0",
			held = false,
			holdElapsed = 0,
		},
		offersState = Offers.createOffersState(),
	}

	local function simulationAdvance(profile, request)
		return self:_simulationAdvance(playerSession, profile, request)
	end

	local function domainApply(candidateProfile, op)
		if op.kind == "UpgradeEgg" or op.kind == "Prestige" then
			return ProgressActions.apply(candidateProfile, op, { catalog = self.catalog, productionMath = self.productionMath })
		elseif op.kind == "PlatformPurchase" or op.kind == "ConfirmPurchase" then
			local pToken = (op.args and op.args.purchaseToken) or op.operationId
			local receiptInfo = op.args and op.args.receiptInfo
			local nowMs = self.clock.utcNowMs()
			local isPiggyEnabled = (self.config and self.config.isPiggyEnabled ~= false)
			local ok, res = Products.confirmPurchase(candidateProfile, pToken, receiptInfo, nowMs, isPiggyEnabled)
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
				candidateProfile.entitlements.pro_permit_effective_at = nowMs
				candidateProfile.entitlements.pro_plus10_enabled = (op.args and op.args.paidRandomAllowed ~= false)
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
		elseif op.kind == "HitDrone" then
			local droneId = (op.args and (op.args.droneId or op.args.spawnId)) or "drone_1"
			candidateProfile.rewards = candidateProfile.rewards or {}
			candidateProfile.rewards.claimedDrones = candidateProfile.rewards.claimedDrones or {}
			if candidateProfile.rewards.claimedDrones[droneId] then
				return {
					profile = candidateProfile,
					result = { error = "ALREADY_CLAIMED", droneId = droneId },
					terminalStatus = "REJECTED",
					validate = function() return false, "ALREADY_CLAIMED" end,
				}
			end

			local spawn = op.args and op.args.spawn
			local nowMs = self.clock.utcNowMs()
			if not spawn then
				local isElite = (op.args and op.args.isElite) or false
				local createdAtMs = (op.args and op.args.createdAtMs) or (nowMs - 2000)
				local expiresAtMs = (op.args and op.args.expiresAtMs) or (nowMs + 15000)
				spawn = {
					spawnId = droneId,
					createdAtMs = createdAtMs,
					expiresAtMs = expiresAtMs,
					isElite = isElite,
					claimed = false,
					reward = nil,
				}
			end

			local pop = 0
			if candidateProfile.farm and candidateProfile.farm.habitats then
				for _, h in candidateProfile.farm.habitats do
					if h.population then
						pop += self.codec.ExactUInt.toSafeNumber(self.codec.ExactUInt.decode(h.population))
					end
				end
			end
			local eggIdx = (candidateProfile.farm and candidateProfile.farm.eggIndex) or 0
			local egg = FvSe.EGGS[eggIdx] or FvSe.EGGS[0]
			local eggVal = egg.eggValueBase
			local currentCashNum = self.codec.BigAmount.decode(candidateProfile.farm and candidateProfile.farm.cash or "0")
			local farmVal = (op.args and op.args.farmValue) or math.max(100.0, pop * eggVal * 100.0 + currentCashNum)
			local curve0Val = (op.args and op.args.curve0FarmValue) or 10000.0

			local config = (op.args and op.args.config)
			local rolls = (op.args and op.args.rolls)
			local okClaim, reward = Drones.claimDrone(spawn, nowMs, candidateProfile, config, rolls, farmVal, curve0Val)

			if okClaim then
				candidateProfile.rewards.claimedDrones[droneId] = true
			end

			return {
				profile = candidateProfile,
				result = {
					droneId = droneId,
					reward = reward,
				},
				terminalStatus = if okClaim then "APPLIED" else "REJECTED",
				validate = function()
					return okClaim, if not okClaim then tostring(reward) else nil
				end,
			}
		elseif op.kind == "ClaimOffer" then
			local offerId = (op.args and op.args.offerId) or "offer_2plus1"
			local offersState = playerSession.offersState
			local offer = Offers.findOffer(offersState, offerId)
			local nowMs = self.clock.utcNowMs()
			if not offer then
				local defaultReward = (op.args and op.args.reward) or {
					rewardType = "Cash",
					amount = "50000",
					amountNumber = 50000,
				}
				local channel = (op.args and op.args.channel) or "bonus"
				Offers.createOffer(offersState, offerId, channel, defaultReward, nowMs)
			end

			local paidGE = op.args and op.args.paidGE
			local okOffer, resOffer = Offers.claimOffer(offersState, offerId, nowMs, candidateProfile, paidGE)
			return {
				profile = candidateProfile,
				result = resOffer,
				terminalStatus = if okOffer then "APPLIED" else "REJECTED",
				validate = function()
					return okOffer, if not okOffer then resOffer.error else nil
				end,
			}
		elseif op.kind == "HatchPetEgg" or op.kind == "HatchPet" then
			local costGE = (op.args and op.args.costGE) or 100
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
			local roll = if op.args and op.args.roll ~= nil then op.args.roll else math.random()
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
			local variantRoll = if op.args and op.args.variantRoll ~= nil then op.args.variantRoll else math.random()
			local variant = "normal"
			if variantRoll < 0.02 then
				variant = "rainbow"
			elseif variantRoll < 0.10 then
				variant = "golden"
			end

			local petSerial = (op.args and op.args.petSerial) or tostring(self.clock.utcNowMs()) .. "_" .. tostring(math.random(1000, 9999))
			local petUid = (op.args and op.args.petUid) or ("pet_" .. chosenSpeciesId .. "_" .. tostring(petSerial))

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
				result = { success = okEq, petUid = petUid, error = errEq },
				terminalStatus = if okEq then "APPLIED" else "REJECTED",
				validate = function() return okEq, errEq end,
			}
		elseif op.kind == "UnequipPet" then
			local petUid = op.args and (op.args.petUid or op.args.petId)
			candidateProfile.inventory = candidateProfile.inventory or {}
			candidateProfile.inventory.equipped = candidateProfile.inventory.equipped or {}
			local okUneq, errUneq = Equipment.unequipPet(candidateProfile.inventory, petUid)
			return {
				profile = candidateProfile,
				result = { success = okUneq, petUid = petUid, error = errUneq },
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
				result = { success = okLock, petUid = petUid, locked = newLock, error = errLock },
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

	coordinator.submit(op)
	coordinator.drain()

	local res = coordinator.resultOf(op.operationId)
	if res and (res.status == "APPLIED" or res.status == "REPLAYED") then
		self:checkpointPlayer(pId)
		return true, res
	end

	return false, (res and res.errorCode) or "PURCHASE_FAILED"
end

function ServerBootstrap:grantEntitlement(playerId, entitlementId, opts)
	local pId = tostring(playerId)
	local playerSession = self.players[pId]
	if not playerSession then
		return false, "PLAYER_NOT_CONNECTED"
	end

	local coordinator = playerSession.coordinator
	local snapshots = coordinator.snapshots()
	local currentRev = (snapshots.durable and snapshots.durable.meta and snapshots.durable.meta.revision) or "0"

	local op = {
		operationId = "entitlement-" .. pId .. "-" .. entitlementId .. "-" .. tostring(self.clock.utcNowMs()),
		kind = "GrantEntitlement",
		expectedRevision = currentRev,
		args = {
			entitlementId = entitlementId,
			paidRandomAllowed = if opts and opts.paidRandomAllowed ~= nil then opts.paidRandomAllowed else true,
		},
	}

	coordinator.submit(op)
	coordinator.drain()

	local res = coordinator.resultOf(op.operationId)
	if res and (res.status == "APPLIED" or res.status == "REPLAYED") then
		self:checkpointPlayer(pId)
		return true, res
	end

	return false, (res and res.errorCode) or "GRANT_FAILED"
end

function ServerBootstrap:hitDrone(playerId, droneId, opts)
	local pId = tostring(playerId)
	local playerSession = self.players[pId]
	if not playerSession then
		return false, "PLAYER_NOT_CONNECTED"
	end

	self._droneHitSerial = (self._droneHitSerial or 0) + 1
	local coordinator = playerSession.coordinator
	local snapshots = coordinator.snapshots()
	local currentRev = (snapshots.durable and snapshots.durable.meta and snapshots.durable.meta.revision) or "0"

	local op = {
		operationId = "hit-drone-" .. pId .. "-" .. tostring(droneId) .. "-" .. tostring(self.clock.utcNowMs()) .. "-" .. tostring(self._droneHitSerial),
		kind = "HitDrone",
		expectedRevision = currentRev,
		args = {
			droneId = droneId,
			isElite = if opts and opts.isElite ~= nil then opts.isElite else false,
			config = opts and opts.config,
			rolls = opts and opts.rolls,
			farmValue = opts and opts.farmValue,
			curve0FarmValue = opts and opts.curve0FarmValue,
		},
	}

	coordinator.submit(op)
	coordinator.drain()

	local res = coordinator.resultOf(op.operationId)
	if res and (res.status == "APPLIED" or (res.status == "REPLAYED" and res.terminalStatus == "APPLIED")) then
		self:checkpointPlayer(pId)
		return true, (res.result and res.result.reward) or res.result
	end

	return false, (res and (res.errorCode or (res.result and (res.result.error or res.result.errorCode)))) or "HIT_DRONE_FAILED"
end

function ServerBootstrap:claimOffer(playerId, offerId, opts)
	local pId = tostring(playerId)
	local playerSession = self.players[pId]
	if not playerSession then
		return false, "PLAYER_NOT_CONNECTED"
	end

	self._offerClaimSerial = (self._offerClaimSerial or 0) + 1
	local coordinator = playerSession.coordinator
	local snapshots = coordinator.snapshots()
	local currentRev = (snapshots.durable and snapshots.durable.meta and snapshots.durable.meta.revision) or "0"

	local op = {
		operationId = "claim-offer-" .. pId .. "-" .. tostring(offerId) .. "-" .. tostring(self.clock.utcNowMs()) .. "-" .. tostring(self._offerClaimSerial),
		kind = "ClaimOffer",
		expectedRevision = currentRev,
		args = {
			offerId = offerId,
			paidGE = opts and opts.paidGE,
			reward = opts and opts.reward,
			channel = opts and opts.channel,
		},
	}

	coordinator.submit(op)
	coordinator.drain()

	local res = coordinator.resultOf(op.operationId)
	if res and (res.status == "APPLIED" or (res.status == "REPLAYED" and res.terminalStatus == "APPLIED")) then
		self:checkpointPlayer(pId)
		return true, (res.result and res.result.reward) or res.result
	end

	return false, (res and (res.errorCode or (res.result and (res.result.error or res.result.errorCode)))) or "CLAIM_OFFER_FAILED"
end

function ServerBootstrap:getOffersState(playerId)
	local pId = tostring(playerId)
	local playerSession = self.players[pId]
	return if playerSession then playerSession.offersState else nil
end

function ServerBootstrap:hatchPet(playerId, opts)
	local pId = tostring(playerId)
	local playerSession = self.players[pId]
	if not playerSession then
		return false, "PLAYER_NOT_CONNECTED"
	end

	self._petHatchSerial = (self._petHatchSerial or 0) + 1
	local coordinator = playerSession.coordinator
	local snapshots = coordinator.snapshots()
	local currentRev = (snapshots.durable and snapshots.durable.meta and snapshots.durable.meta.revision) or "0"

	local op = {
		operationId = "hatch-pet-" .. pId .. "-" .. tostring(self.clock.utcNowMs()) .. "-" .. tostring(self._petHatchSerial),
		kind = "HatchPetEgg",
		expectedRevision = currentRev,
		args = {
			costGE = if opts and opts.costGE ~= nil then opts.costGE else 100,
			roll = opts and opts.roll,
			variantRoll = opts and opts.variantRoll,
			petUid = opts and opts.petUid,
			petSerial = opts and opts.petSerial,
		},
	}

	coordinator.submit(op)
	coordinator.drain()

	local res = coordinator.resultOf(op.operationId)
	if res and (res.status == "APPLIED" or (res.status == "REPLAYED" and res.terminalStatus == "APPLIED")) then
		self:checkpointPlayer(pId)
		return true, res.result
	end

	return false, (res and (res.errorCode or (res.result and (res.result.error or res.result.errorCode)))) or "HATCH_FAILED"
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

	coordinator.submit(op)
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

	coordinator.submit(op)
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
	return self.gateway:handleRequest(playerId, message)
end
ServerBootstrap.handleRequest = ServerBootstrap.dispatch

function ServerBootstrap:createPlayerDelta(playerId)
	local pId = tostring(playerId)
	return self.gateway:createPlayerDelta(pId)
end

return table.freeze(ServerBootstrap)
