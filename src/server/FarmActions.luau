--!nocheck
-- Authoritative pricing and coordinator domain port for HatchTheEgg farm purchases.
-- Pure Luau domain actions; no direct storage writes, networking, or UI side-effects.

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
local CatalogData = resolve(function()
	return script.Parent.CatalogRegistry.Data
end, "./CatalogRegistry/Data")
local CatalogRegistry = resolve(function()
	return script.Parent.CatalogRegistry
end, "./CatalogRegistry")

local defaultCatalog = CatalogRegistry.new(NumericCodec, CatalogData, { mode = "INTERNAL_TEST_ONLY" })

local costEffects = {
	BuyResearch = {"cheaper_research", "researchCostMult"},
	BuyHabitat = {"cheaper_contractors", "habCostMult"},
	BuyVehicle = {"bust_unions", "vehicleCostMult"},
}
local function costMultiplier(profile, catalog, kind)
	local spec = costEffects[kind]
	local epic = profile.permanent.epic or {}
	return catalog.epicEffects(spec[1], epic[spec[1]] or 0)[spec[2]] or 1
end

local FarmActions = {
	VERSION = 1,
	HABITAT_NAME_TO_INDEX = table.freeze({
		COOP = 0,
		SHACK = 1,
		["SUPER SHACK"] = 2,
		["SHORT HOUSE"] = 3,
		["THE STANDARD"] = 4,
		["LONG HOUSE"] = 5,
		["DOUBLE DECKER"] = 6,
		WAREHOUSE = 7,
		CENTER = 8,
		BUNKER = 9,
		EGGKEA = 10,
		["HAB 1000"] = 11,
		HANGAR = 12,
		TOWER = 13,
		["HAB 10,000"] = 14,
		EGGTOPIA = 15,
		MONOLITH = 16,
		["PLANET PORTAL"] = 17,
		["CHICKEN UNIVERSE"] = 18,
	}),
	HABITAT_INDEX_TO_NAME = table.freeze({
		[0] = "COOP",
		[1] = "SHACK",
		[2] = "SUPER SHACK",
		[3] = "SHORT HOUSE",
		[4] = "THE STANDARD",
		[5] = "LONG HOUSE",
		[6] = "DOUBLE DECKER",
		[7] = "WAREHOUSE",
		[8] = "CENTER",
		[9] = "BUNKER",
		[10] = "EGGKEA",
		[11] = "HAB 1000",
		[12] = "HANGAR",
		[13] = "TOWER",
		[14] = "HAB 10,000",
		[15] = "EGGTOPIA",
		[16] = "MONOLITH",
		[17] = "PLANET PORTAL",
		[18] = "CHICKEN UNIVERSE",
	}),
	VEHICLE_NAME_TO_INDEX = table.freeze({
		TRIKE = 0,
		["TRANSIT VAN"] = 1,
		PICKUP = 2,
		["10 FOOT"] = 3,
		["24 FOOT"] = 4,
		SEMI = 5,
		["DOUBLE SEMI"] = 6,
		["FUTURE SEMI"] = 7,
		["MEGA SEMI"] = 8,
		["HOVER SEMI"] = 9,
		["QUANTUM TRANSPORTER"] = 10,
		["HYPERLOOP TRAIN"] = 11,
	}),
	VEHICLE_INDEX_TO_NAME = table.freeze({
		[0] = "TRIKE",
		[1] = "TRANSIT VAN",
		[2] = "PICKUP",
		[3] = "10 FOOT",
		[4] = "24 FOOT",
		[5] = "SEMI",
		[6] = "DOUBLE SEMI",
		[7] = "FUTURE SEMI",
		[8] = "MEGA SEMI",
		[9] = "HOVER SEMI",
		[10] = "QUANTUM TRANSPORTER",
		[11] = "HYPERLOOP TRAIN",
	}),
}

function FarmActions.createQuote(profile, catalog, target, requestId, expectedRevision, quoteId, nowMs, configRevision)
	catalog = catalog or defaultCatalog
	local BigAmount = NumericCodec.BigAmount

	assert(type(profile) == "table" and type(profile.farm) == "table", "INVALID_PROFILE")
	assert(type(catalog) == "table", "INVALID_CATALOG")
	assert(type(target) == "table" and type(target.kind) == "string" and type(target.args) == "table", "INVALID_TARGET")
	assert(type(requestId) == "string", "INVALID_REQUEST_ID")
	assert(type(quoteId) == "string", "INVALID_QUOTE_ID")
	assert(type(nowMs) == "number", "INVALID_NOW_MS")

	local expectedRev = expectedRevision or profile.meta.revision
	local cfgRev = configRevision or profile.meta.configRevision

	local kind = target.kind
	local args = target.args
	local cleanTarget
	local available = true
	local blockedReason = nil
	local price = 0
	local nextLevel = nil
	local resultIndex = nil

	if kind == "BuyResearch" then
		local researchId = args.researchId
		assert(type(researchId) == "string", "INVALID_RESEARCH_ID")
		cleanTarget = { kind = "BuyResearch", args = { researchId = researchId, mode = "single" } }

		local okRow, row = pcall(function()
			return catalog.getCommon(researchId)
		end)
		if not okRow or not row then
			return {
				kind = "QuoteView",
				quoteId = quoteId or "quote-" .. tostring(nowMs),
				target = cleanTarget,
				cashCost = BigAmount.encode(0),
				available = false,
				blockedReason = "UNSUPPORTED_RESEARCH",
				nextLevel = 0,
				expectedRevision = expectedRevision,
			}
		end
		local currentLevel = profile.farm.common[researchId] or 0

		local points = 0
		for _, lvl in profile.farm.common do
			points += lvl
		end

		local threshold = catalog.tierThreshold(row.tier_raw)
		if points < threshold then
			available = false
			blockedReason = "TIER_LOCKED"
		end

		if currentLevel >= row.maxLevel then
			available = false
			if not blockedReason then
				blockedReason = "MAX_LEVEL"
			end
			nextLevel = row.maxLevel
			price = 0
		else
			nextLevel = currentLevel + 1
			price = catalog.researchPrice(researchId, currentLevel) * costMultiplier(profile, catalog, kind)
		end

		local currentCash = BigAmount.decode(profile.farm.cash)
		if currentCash < price then
			available = false
			if not blockedReason then
				blockedReason = "INSUFFICIENT_CASH"
			end
		end

	elseif kind == "BuyHabitat" then
		local slotId = args.slotId
		assert(type(slotId) == "number" and slotId >= 1 and slotId <= 4, "INVALID_SLOT")
		local habitatId = args.habitatId
		local typeIndex = FarmActions.HABITAT_NAME_TO_INDEX[habitatId]
		assert(typeIndex ~= nil, "UNSUPPORTED_HABITAT")
		cleanTarget = { kind = "BuyHabitat", args = { slotId = slotId, habitatId = habitatId } }
		resultIndex = typeIndex

		local sameTypeOwned = 0
		for _, hab in profile.farm.habitats do
			if hab.typeIndex == typeIndex then
				sameTypeOwned += 1
			end
		end

		local targetSlot = profile.farm.habitats[slotId]
		if sameTypeOwned >= 4 or (targetSlot and targetSlot.typeIndex >= typeIndex) then
			available = false
			blockedReason = "MAX_LEVEL"
			price = 0
		else
			price = catalog.habitatPrice(typeIndex, sameTypeOwned) * costMultiplier(profile, catalog, kind)
		end

		local currentCash = BigAmount.decode(profile.farm.cash)
		if currentCash < price then
			available = false
			if not blockedReason then
				blockedReason = "INSUFFICIENT_CASH"
			end
		end

	elseif kind == "BuyVehicle" then
		local slotId = args.slotId
		assert(type(slotId) == "number" and slotId >= 1 and slotId <= (profile.farm.fleetLimit or 4), "INVALID_SLOT")
		local vehicleId = args.vehicleId
		local typeIndex = FarmActions.VEHICLE_NAME_TO_INDEX[vehicleId]
		assert(typeIndex ~= nil, "UNSUPPORTED_VEHICLE")
		if typeIndex==11 and profile.permanent.hyperloop~=true then available=false;blockedReason="HYPERLOOP_LOCKED" end
		cleanTarget = { kind = "BuyVehicle", args = { slotId = slotId, vehicleId = vehicleId } }
		resultIndex = typeIndex

		local sameTypeOwned = 0
		for _, v in profile.farm.vehicles do
			if type(v) == "table" and v.typeIndex == typeIndex then
				sameTypeOwned += 1
			end
		end

		local row = catalog.getVehicle(typeIndex)
		local existing = profile.farm.vehicles[slotId]
		if sameTypeOwned >= #row.prices or (existing and existing.typeIndex >= typeIndex) then
			available = false
			blockedReason = "MAX_LEVEL"
			price = 0
		else
			price = catalog.vehiclePrice(typeIndex, sameTypeOwned) * costMultiplier(profile, catalog, kind)
		end

		local currentCash = BigAmount.decode(profile.farm.cash)
		if currentCash < price then
			available = false
			if not blockedReason then
				blockedReason = "INSUFFICIENT_CASH"
			end
		end

	else
		error("INVALID_TARGET_KIND")
	end

	local quoteView = {
		protocolVersion = 1,
		numericCodecVersion = 1,
		kind = "QuoteView",
		requestId = requestId,
		quoteId = quoteId,
		expectedRevision = expectedRev,
		target = cleanTarget,
		cashCost = BigAmount.encode(price),
		currency = "cash",
		configRevision = cfgRev,
		calculationVersion = 1,
		expiresAt = nowMs + 60000,
		available = available,
	}

	if kind == "BuyResearch" then
		quoteView.nextLevel = nextLevel
	else
		quoteView.resultIndex = resultIndex
	end

	if not available then
		quoteView.blockedReason = blockedReason
	end

	return quoteView
end

function FarmActions.apply(candidateProfile, op, options)
	local catalog = (options and options.catalog) or defaultCatalog
	local codec = (options and options.codec) or NumericCodec
	local BigAmount = codec.BigAmount

	assert(type(candidateProfile) == "table" and type(candidateProfile.farm) == "table", "INVALID_PROFILE")
	assert(type(op) == "table" and type(op.kind) == "string" and type(op.args) == "table", "INVALID_OPERATION")

	local kind = op.kind
	local args = op.args
	local preparedMultiplier = costEffects[kind] and costMultiplier(candidateProfile, catalog, kind)

	if kind == "BuyResearch" then
		local researchId = args.researchId
		local okRow, row = pcall(function()
			return catalog.getCommon(researchId)
		end)
		if not okRow or not row then
			return {
				profile = candidateProfile,
				terminalStatus = "REJECTED",
				result = { terminalStatus = "REJECTED", errorCode = "UNSUPPORTED_RESEARCH" },
				validate = function() return true end,
			}
		end
		local currentLevel = candidateProfile.farm.common[researchId] or 0

		local points = 0
		for _, lvl in candidateProfile.farm.common do
			points += lvl
		end

		if points < catalog.tierThreshold(row.tier_raw) then
			return {
				profile = candidateProfile,
				terminalStatus = "REJECTED",
				result = { terminalStatus = "REJECTED", errorCode = "TIER_LOCKED" },
				validate = function() return true end,
			}
		end

		if currentLevel >= row.maxLevel then
			return {
				profile = candidateProfile,
				terminalStatus = "REJECTED",
				result = { terminalStatus = "REJECTED", errorCode = "MAX_LEVEL" },
				validate = function() return true end,
			}
		end

		local price = catalog.researchPrice(researchId, currentLevel) * preparedMultiplier
		local currentCash = BigAmount.decode(candidateProfile.farm.cash)
		if currentCash < price then
			return {
				profile = candidateProfile,
				terminalStatus = "REJECTED",
				result = { terminalStatus = "REJECTED", errorCode = "INSUFFICIENT_CASH" },
				validate = function() return true end,
			}
		end

		local remaining = BigAmount.subtract(currentCash, price)
		candidateProfile.farm.cash = BigAmount.encode(remaining)
		-- CRITICAL INVARIANT: candidateProfile.accounting.currentFarmCash is NOT DECREASED!

		local newLevel = currentLevel + 1
		candidateProfile.farm.common[researchId] = newLevel

		local terminalResult = {
			terminalStatus = "APPLIED",
			actionKind = "BuyResearch",
			researchId = researchId,
			level = newLevel,
		}

		local function validateFn(freshProfile, now)
			if costMultiplier(freshProfile, catalog, kind) ~= preparedMultiplier then return false, "QUOTE_CHANGED" end
			local freshCash = BigAmount.decode(freshProfile.farm.cash)
			if freshCash < price then return false, "INSUFFICIENT_CASH" end
			local freshLevel = freshProfile.farm.common[researchId] or 0
			if freshLevel ~= currentLevel then return false, "QUOTE_CHANGED" end
			local freshPoints = 0
			for _, lvl in freshProfile.farm.common do freshPoints += lvl end
			if freshPoints < catalog.tierThreshold(row.tier_raw) then return false, "TIER_LOCKED" end
			return true
		end

		return {
			profile = candidateProfile,
			terminalStatus = "APPLIED",
			result = terminalResult,
			validate = validateFn,
		}

	elseif kind == "BuyHabitat" then
		local slotId = args.slotId
		assert(type(slotId) == "number" and slotId >= 1 and slotId <= 4, "INVALID_SLOT")
		local habitatId = args.habitatId
		local typeIndex = FarmActions.HABITAT_NAME_TO_INDEX[habitatId]
		assert(typeIndex ~= nil, "UNSUPPORTED_HABITAT")

		local sameTypeOwned = 0
		for _, hab in candidateProfile.farm.habitats do
			if hab.typeIndex == typeIndex then
				sameTypeOwned += 1
			end
		end

		local targetSlot = candidateProfile.farm.habitats[slotId]
		if sameTypeOwned >= 4 or (targetSlot and targetSlot.typeIndex >= typeIndex) then
			return {
				profile = candidateProfile,
				terminalStatus = "REJECTED",
				result = { terminalStatus = "REJECTED", errorCode = "MAX_LEVEL" },
				validate = function() return true end,
			}
		end

		local price = catalog.habitatPrice(typeIndex, sameTypeOwned) * preparedMultiplier
		local currentCash = BigAmount.decode(candidateProfile.farm.cash)
		if currentCash < price then
			return {
				profile = candidateProfile,
				terminalStatus = "REJECTED",
				result = { terminalStatus = "REJECTED", errorCode = "INSUFFICIENT_CASH" },
				validate = function() return true end,
			}
		end

		local remaining = BigAmount.subtract(currentCash, price)
		candidateProfile.farm.cash = BigAmount.encode(remaining)
		-- CRITICAL INVARIANT: candidateProfile.accounting.currentFarmCash is NOT DECREASED!

		-- Update building type while preserving population, assignedInTransit, fractionalIHR!
		targetSlot.typeIndex = typeIndex

		local terminalResult = {
			terminalStatus = "APPLIED",
			actionKind = "BuyHabitat",
			slotId = slotId,
			habitatId = habitatId,
		}

		local function validateFn(freshProfile, now)
			if costMultiplier(freshProfile, catalog, kind) ~= preparedMultiplier then return false, "QUOTE_CHANGED" end
			local freshCash = BigAmount.decode(freshProfile.farm.cash)
			if freshCash < price then return false, "INSUFFICIENT_CASH" end
			local freshSlot = freshProfile.farm.habitats[slotId]
			if not freshSlot or freshSlot.typeIndex >= typeIndex then return false, "QUOTE_CHANGED" end
			local freshSameTypeOwned = 0
			for _, hab in freshProfile.farm.habitats do
				if hab.typeIndex == typeIndex then freshSameTypeOwned += 1 end
			end
			if freshSameTypeOwned ~= sameTypeOwned then return false, "QUOTE_CHANGED" end
			return true
		end

		return {
			profile = candidateProfile,
			terminalStatus = "APPLIED",
			result = terminalResult,
			validate = validateFn,
		}

	elseif kind == "BuyVehicle" then
		local slotId = args.slotId
		assert(type(slotId) == "number" and slotId >= 1 and slotId <= (candidateProfile.farm.fleetLimit or 4), "INVALID_SLOT")
		local vehicleId = args.vehicleId
		local typeIndex = FarmActions.VEHICLE_NAME_TO_INDEX[vehicleId]
		assert(typeIndex ~= nil, "UNSUPPORTED_VEHICLE")
		if typeIndex==11 and candidateProfile.permanent.hyperloop~=true then
			return {profile=candidateProfile,terminalStatus="REJECTED",result={terminalStatus="REJECTED",errorCode="HYPERLOOP_LOCKED"},validate=function()return true end}
		end

		local sameTypeOwned = 0
		for _, v in candidateProfile.farm.vehicles do
			if type(v) == "table" and v.typeIndex == typeIndex then
				sameTypeOwned += 1
			end
		end

		local row = catalog.getVehicle(typeIndex)
		local existing = candidateProfile.farm.vehicles[slotId]
		if sameTypeOwned >= #row.prices or (existing and existing.typeIndex >= typeIndex) then
			return {
				profile = candidateProfile,
				terminalStatus = "REJECTED",
				result = { terminalStatus = "REJECTED", errorCode = "MAX_LEVEL" },
				validate = function() return true end,
			}
		end

		local price = catalog.vehiclePrice(typeIndex, sameTypeOwned) * preparedMultiplier
		local currentCash = BigAmount.decode(candidateProfile.farm.cash)
		if currentCash < price then
			return {
				profile = candidateProfile,
				terminalStatus = "REJECTED",
				result = { terminalStatus = "REJECTED", errorCode = "INSUFFICIENT_CASH" },
				validate = function() return true end,
			}
		end

		local remaining = BigAmount.subtract(currentCash, price)
		candidateProfile.farm.cash = BigAmount.encode(remaining)
		-- CRITICAL INVARIANT: candidateProfile.accounting.currentFarmCash is NOT DECREASED!

		-- Preserve empty slot identities in a dense, serializable profile array.
		for i=1,slotId-1 do
			if not candidateProfile.farm.vehicles[i] then candidateProfile.farm.vehicles[i]={typeIndex=-1} end
		end
		if not candidateProfile.farm.vehicles[slotId] then
			candidateProfile.farm.vehicles[slotId] = { typeIndex = typeIndex }
		else
			candidateProfile.farm.vehicles[slotId].typeIndex = typeIndex
		end

		local terminalResult = {
			terminalStatus = "APPLIED",
			actionKind = "BuyVehicle",
			slotId = slotId,
			vehicleId = vehicleId,
		}

		local function validateFn(freshProfile, now)
			if costMultiplier(freshProfile, catalog, kind) ~= preparedMultiplier then return false, "QUOTE_CHANGED" end
			if typeIndex==11 and freshProfile.permanent.hyperloop~=true then return false,"HYPERLOOP_LOCKED" end
			local freshCash = BigAmount.decode(freshProfile.farm.cash)
			if freshCash < price then return false, "INSUFFICIENT_CASH" end
			local freshVehicle = freshProfile.farm.vehicles[slotId]
			if freshVehicle and freshVehicle.typeIndex >= typeIndex then return false, "QUOTE_CHANGED" end
			local freshSameTypeOwned = 0
			for _, v in freshProfile.farm.vehicles do
				if type(v) == "table" and v.typeIndex == typeIndex then freshSameTypeOwned += 1 end
			end
			if freshSameTypeOwned ~= sameTypeOwned then return false, "QUOTE_CHANGED" end
			return true
		end

		return {
			profile = candidateProfile,
			terminalStatus = "APPLIED",
			result = terminalResult,
			validate = validateFn,
		}

	else
		return {
			profile = candidateProfile,
			terminalStatus = "REJECTED",
			result = { terminalStatus = "REJECTED", errorCode = "UNSUPPORTED_OPERATION" },
			validate = function() return true end,
		}
	end
end

function FarmActions.new(codec, catalog, options)
	if type(options) ~= "table" or options.mode ~= "INTERNAL_TEST_ONLY" then
		error("FarmActions/TEST_MODE_REQUIRED", 2)
	end
	if type(codec) ~= "table" or codec.VERSION ~= 1 then
		error("FarmActions/UNSUPPORTED_CODEC", 2)
	end
	if type(catalog) ~= "table" then
		error("FarmActions/UNSUPPORTED_CATALOG", 2)
	end

	local instance = {
		VERSION = 1,
		codec = codec,
		catalog = catalog,
		HABITAT_NAME_TO_INDEX = FarmActions.HABITAT_NAME_TO_INDEX,
		HABITAT_INDEX_TO_NAME = FarmActions.HABITAT_INDEX_TO_NAME,
		VEHICLE_NAME_TO_INDEX = FarmActions.VEHICLE_NAME_TO_INDEX,
		VEHICLE_INDEX_TO_NAME = FarmActions.VEHICLE_INDEX_TO_NAME,
	}

	local quotes, quoteOrder = {}, {}
	function instance.createQuote(profile, targetOrCatalog, ...)
		local quote
		if type(targetOrCatalog) == "table" and targetOrCatalog.STATUS ~= nil then
			quote = FarmActions.createQuote(profile, targetOrCatalog, ...)
		else
			quote = FarmActions.createQuote(profile, catalog, targetOrCatalog, ...)
		end
		local playerId = profile.meta.playerId
		quotes[playerId] = quotes[playerId] or {}
		quoteOrder[playerId] = quoteOrder[playerId] or {}
		local key = quote.quoteId
		quotes[playerId][key] = {generation=profile.ownership.generation, kind=quote.target.kind, multiplier=costMultiplier(profile,catalog,quote.target.kind)}
		table.insert(quoteOrder[playerId],key)
		if #quoteOrder[playerId] > 64 then quotes[playerId][table.remove(quoteOrder[playerId],1)] = nil end
		return quote
	end

	function instance.apply(candidateProfile, op, callOptions)
		local playerQuotes = quotes[candidateProfile.meta.playerId]
		local quoted = playerQuotes and playerQuotes[op.quoteId]
		if playerQuotes and op.quoteId and (not quoted or quoted.kind ~= op.kind or quoted.generation ~= candidateProfile.ownership.generation or quoted.multiplier ~= costMultiplier(candidateProfile,catalog,op.kind)) then
			return {profile=candidateProfile,terminalStatus="REJECTED",result={terminalStatus="REJECTED",errorCode="QUOTE_CHANGED"},validate=function()return true end}
		end
		local merged = { catalog = catalog, codec = codec }
		if callOptions then
			for k, v in callOptions do merged[k] = v end
		end
		return FarmActions.apply(candidateProfile, op, merged)
	end
	function instance.forgetPlayer(playerId)
		quotes[playerId] = nil
		quoteOrder[playerId] = nil
	end

	return table.freeze(instance)
end

return table.freeze(FarmActions)
