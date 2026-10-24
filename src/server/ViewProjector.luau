--!nocheck
-- Authoritative state projection for HatchTheEgg.
-- Pure Luau projection module; converts internal profiles to ProtocolSchemas-compliant views.
-- Never exposes internal session tokens, owner tokens, or ledgers.

local ALL_COMMON_RESEARCH_IDS = table.freeze({
	"comfy_nests",
	"nutritional_sup",
	"better_incubators",
	"excitable_chickens",
	"hab_capacity1",
	"internal_hatchery1",
	"padded_packaging",
	"hatchery_expansion",
	"bigger_eggs",
	"internal_hatchery2",
	"leafsprings",
	"vehicle_reliablity",
	"rooster_booster",
	"coordinated_clucking",
	"hatchery_rebuild1",
	"usde_prime",
	"hen_house_ac",
	"superfeed",
	"microlux",
	"compact_incubators",
	"lightweight_boxes",
	"excoskeletons",
	"internal_hatchery3",
	"improved_genetics",
	"traffic_management",
	"motivational_clucking",
	"driver_training",
	"shell_fortification",
	"egg_loading_bots",
	"super_alloy",
	"even_bigger_eggs",
	"internal_hatchery4",
	"quantum_storage",
	"genetic_purification",
	"internal_hatchery5",
	"time_compress",
	"hover_upgrades",
	"graviton_coating",
	"grav_plating",
	"chrystal_shells",
	"autonomous_vehicles",
	"neural_linking",
	"telepathic_will",
	"enlightened_chickens",
	"dark_containment",
	"atomic_purification",
	"multi_layering",
	"timeline_diversion",
	"wormhole_dampening",
	"eggsistor",
	"micro_coupling",
	"neural_net_refine",
	"matter_reconfig",
	"timeline_splicing",
	"hyper_portalling",
	"relativity_optimization",
})

local function deepCopy(value)
	if type(value) ~= "table" then return value end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

local function deepEqual(a, b)
	if a == b then return true end
	if type(a) ~= "table" or type(b) ~= "table" then return false end
	for k, v in a do
		if not deepEqual(v, b[k]) then return false end
	end
	for k, _ in b do
		if a[k] == nil then return false end
	end
	return true
end

local ViewProjector = {}
ViewProjector.__index = ViewProjector
ViewProjector.ALL_COMMON_RESEARCH_IDS = ALL_COMMON_RESEARCH_IDS

function ViewProjector.new(deps)
	assert(type(deps) == "table", "INVALID_DEPS")
	assert(deps.codec and deps.codec.VERSION == 1, "CODEC_REQUIRED")
	assert(deps.catalog and type(deps.catalog.getCommon) == "function", "CATALOG_REQUIRED")
	assert(deps.productionMath ~= nil, "PRODUCTION_MATH_REQUIRED")

	local productionMath = deps.productionMath
	if type(productionMath) == "table" and type(productionMath.new) == "function" then
		productionMath = productionMath.new(deps.codec, deps.catalog, { mode = "INTERNAL_TEST_ONLY" })
	end
	assert(type(productionMath) == "table" and type(productionMath.research) == "function", "INVALID_PRODUCTION_MATH")

	local supportedIds = {}
	if deps.catalog.commonIds then
		for _, id in deps.catalog.commonIds do
			supportedIds[id] = true
		end
	end

	local self = setmetatable({
		codec = deps.codec,
		catalog = deps.catalog,
		productionMath = productionMath,
		configRevision = deps.configRevision or "CANONICAL_V1",
		supportedIds = table.freeze(supportedIds),
	}, ViewProjector)

	return self
end

function ViewProjector:projectPrivateView(profile, streamId, viewSeq, serverObservedAt, requestId)
	assert(type(profile) == "table" and type(profile.farm) == "table", "INVALID_PROFILE")
	assert(type(streamId) == "string", "INVALID_STREAM_ID")
	assert(type(viewSeq) == "string", "INVALID_VIEW_SEQ")
	assert(type(serverObservedAt) == "number", "INVALID_SERVER_OBSERVED_AT")
	assert(type(requestId) == "string", "INVALID_REQUEST_ID")

	local codec = self.codec
	local catalog = self.catalog
	local productionMath = self.productionMath
	local farm = profile.farm
	local commonLevels = farm.common or {}

	-- Compute derived research metrics
	local r = productionMath.research(commonLevels)

	-- Habitats: 4 slots
	local habTypes = {}
	for i = 1, 4 do
		local h = farm.habitats and farm.habitats[i]
		habTypes[i] = if h and h.typeIndex ~= nil and h.typeIndex >= 0 then h.typeIndex else false
	end
	local caps = productionMath.capacities(commonLevels, habTypes)

	local habitatsList = {}
	local totalPopExact = codec.ExactUInt.fromSafeNumber(0)
	for slotId = 1, 4 do
		local h = farm.habitats and farm.habitats[slotId]
		local pop = (h and h.population) or "0"
		local inTransit = (h and h.assignedInTransit) or "0"
		local cap = caps[slotId] or 0
		local capacity = codec.ExactUInt.encode(codec.ExactUInt.fromSafeNumber(cap))

		totalPopExact = codec.ExactUInt.add(totalPopExact, codec.ExactUInt.decode(pop))

		local habObj = {
			slotId = slotId,
			population = pop,
			reservedInTransit = inTransit,
			capacity = capacity,
		}
		if h and h.typeIndex ~= nil and h.typeIndex >= 0 then
			habObj.habitatIndex = h.typeIndex
		end
		table.insert(habitatsList, habObj)
	end
	local totalPopNum = codec.ExactUInt.toSafeNumber(totalPopExact)

	-- Fleet: up to 4 vehicles
	local fleetVehicles = {}
	local shippingPerMinute = 0
	local fleetLimit = farm.fleetLimit or 4
	for slotId = 1, fleetLimit do
		local v = farm.vehicles and farm.vehicles[slotId]
		if type(v) == "table" and type(v.typeIndex) == "number" and v.typeIndex >= 0 then
			table.insert(fleetVehicles, { slotId = slotId, vehicleIndex = v.typeIndex })
			local baseCap = catalog.getVehicle(v.typeIndex).capacity
			shippingPerMinute = codec.BigAmount.add(shippingPerMinute, codec.BigAmount.multiply(baseCap, r.vehicleCapacityMult))
		end
	end

	-- Derived production metrics
	local producedEggsPerSecondNum = codec.BigAmount.multiply(totalPopNum, r.layingPerChickenPerSecond)
	local shippingPerSecondNum = codec.BigAmount.divide(shippingPerMinute, 60)
	local soldEggsPerSecondNum = math.min(producedEggsPerSecondNum, shippingPerSecondNum)
	local cashIncomePerSecondNum = codec.BigAmount.multiply(soldEggsPerSecondNum, r.eggValue)

	-- Hatchery
	local hatcheryStock = farm.hatcheryStock or "250"
	local hatchery = {
		stock = codec.BigAmount.encode(codec.BigAmount.decode(hatcheryStock)),
		capacity = codec.BigAmount.encode(r.hatcheryCapacity),
		refillPerSecond = codec.BigAmount.encode(r.refillPerSecond),
	}

	-- Common research list (exactly 56 items)
	local commonList = {}
	for _, id in ALL_COMMON_RESEARCH_IDS do
		if self.supportedIds[id] then
			local currentLevel = commonLevels[id] or 0
			local can, reason = productionMath.canResearch(commonLevels, id)
			local entry = {
				researchId = id,
				level = currentLevel,
				available = can,
			}
			if not can and reason ~= nil then
				entry.blockedReason = reason
			end
			table.insert(commonList, entry)
		else
			table.insert(commonList, {
				researchId = id,
				level = 0,
				available = false,
				blockedReason = "UNSUPPORTED",
			})
		end
	end

	local lifecycle = profile.lifecycle or "ready"
	local ownFarm = {
		lifecycle = lifecycle,
		eggIndex = farm.eggIndex or 0,
		cash = codec.BigAmount.encode(codec.BigAmount.decode(farm.cash or "0")),
		habitats = habitatsList,
		hatchery = hatchery,
		fleet = {
			vehicles = fleetVehicles,
			shippingPerMinute = codec.BigAmount.encode(shippingPerMinute),
		},
		producedEggsPerSecond = codec.BigAmount.encode(producedEggsPerSecondNum),
		soldEggsPerSecond = codec.BigAmount.encode(soldEggsPerSecondNum),
		cashIncomePerSecond = codec.BigAmount.encode(cashIncomePerSecondNum),
		common = commonList,
	}

	local commitRevision = (profile.meta and profile.meta.revision) or "0"
	local configRev = (profile.meta and profile.meta.configRevision) or self.configRevision

	local snapshot = {
		protocolVersion = 1,
		numericCodecVersion = 1,
		viewSchemaVersion = 1,
		configRevision = configRev,
		calculationVersion = 1,
		streamId = streamId,
		commitRevision = commitRevision,
		viewSeq = viewSeq,
		serverObservedAt = serverObservedAt,
		kind = "StateSnapshot",
		requestId = requestId,
		view = {
			audience = "own",
			farm = ownFarm,
		},
	}

	return snapshot
end

function ViewProjector:projectPublicView(profile, streamId, viewSeq, serverObservedAt, requestId)
	assert(type(profile) == "table" and type(profile.farm) == "table", "INVALID_PROFILE")
	assert(type(streamId) == "string", "INVALID_STREAM_ID")
	assert(type(viewSeq) == "string", "INVALID_VIEW_SEQ")
	assert(type(serverObservedAt) == "number", "INVALID_SERVER_OBSERVED_AT")
	assert(type(requestId) == "string", "INVALID_REQUEST_ID")

	local codec = self.codec
	local farm = profile.farm

	-- Total settled population
	local totalPopExact = codec.ExactUInt.fromSafeNumber(0)
	for slotId = 1, 4 do
		local h = farm.habitats and farm.habitats[slotId]
		if h and h.population then
			totalPopExact = codec.ExactUInt.add(totalPopExact, codec.ExactUInt.decode(h.population))
		end
	end

	-- Visible habitats (1..4 slots, only visible index if present)
	local publicHabitats = {}
	for slotId = 1, 4 do
		local h = farm.habitats and farm.habitats[slotId]
		local habEntry = { slotId = slotId }
		if h and h.typeIndex ~= nil and h.typeIndex >= 0 then
			habEntry.habitatIndex = h.typeIndex
		end
		table.insert(publicHabitats, habEntry)
	end

	-- Vehicles
	local publicVehicles = {}
	local fleetLimit = farm.fleetLimit or 4
	for slotId = 1, fleetLimit do
		local v = farm.vehicles and farm.vehicles[slotId]
		if type(v) == "table" and type(v.typeIndex) == "number" and v.typeIndex >= 0 then
			table.insert(publicVehicles, { slotId = slotId, vehicleIndex = v.typeIndex })
		end
	end

	local publicFarm = {
		eggIndex = farm.eggIndex or 0,
		population = codec.ExactUInt.encode(totalPopExact),
		habitats = publicHabitats,
		vehicles = publicVehicles,
	}

	local commitRevision = (profile.meta and profile.meta.revision) or "0"
	local configRev = (profile.meta and profile.meta.configRevision) or self.configRevision

	local snapshot = {
		protocolVersion = 1,
		numericCodecVersion = 1,
		viewSchemaVersion = 1,
		configRevision = configRev,
		calculationVersion = 1,
		streamId = streamId,
		commitRevision = commitRevision,
		viewSeq = viewSeq,
		serverObservedAt = serverObservedAt,
		kind = "StateSnapshot",
		requestId = requestId,
		view = {
			audience = "public",
			farm = publicFarm,
		},
	}

	return snapshot
end

function ViewProjector:createDelta(previousOwnView, currentOwnView, streamId, commitRevision, baseViewSeq, viewSeq, serverObservedAt)
	assert(type(currentOwnView) == "table", "INVALID_CURRENT_VIEW")
	assert(type(streamId) == "string", "INVALID_STREAM_ID")
	assert(type(commitRevision) == "string", "INVALID_COMMIT_REVISION")
	assert(type(baseViewSeq) == "string", "INVALID_BASE_VIEW_SEQ")
	assert(type(viewSeq) == "string", "INVALID_VIEW_SEQ")
	assert(type(serverObservedAt) == "number", "INVALID_SERVER_OBSERVED_AT")

	local currView = if currentOwnView.view then currentOwnView.view else currentOwnView
	local prevView = if previousOwnView and previousOwnView.view then previousOwnView.view else previousOwnView

	local audience = currView.audience or "own"
	local currFarm = currView.farm or {}
	local prevFarm = if prevView then prevView.farm else nil

	local farmChanges = {}
	if prevFarm == nil then
		for k, v in currFarm do
			farmChanges[k] = deepCopy(v)
		end
	else
		for k, v in currFarm do
			if not deepEqual(prevFarm[k], v) then
				farmChanges[k] = deepCopy(v)
			end
		end
	end

	local configRev = currentOwnView.configRevision or self.configRevision

	local delta = {
		protocolVersion = 1,
		numericCodecVersion = 1,
		viewSchemaVersion = 1,
		configRevision = configRev,
		calculationVersion = 1,
		streamId = streamId,
		commitRevision = commitRevision,
		baseViewSeq = baseViewSeq,
		viewSeq = viewSeq,
		serverObservedAt = serverObservedAt,
		kind = "StateDelta",
		changes = {
			audience = audience,
			farm = farmChanges,
		},
	}

	return delta
end

return table.freeze(ViewProjector)
