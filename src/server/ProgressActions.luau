--!strict
-- ProgressActions: authoritative domain port for egg transition (UpgradeEgg), prestige, and session accounting.
-- Spec: docs/02 §1, §3; docs/05 §1-§4; docs/13 §5; docs/27 §2, §4.1, §4.2; NEXT-02 (#27).

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
local FvSe = resolve(function()
	return script.Parent.FarmMath.fv_se
end, "./FarmMath/fv_se")
local CatalogData = resolve(function()
	return script.Parent.CatalogRegistry.Data
end, "./CatalogRegistry/Data")
local CatalogRegistry = resolve(function()
	return script.Parent.CatalogRegistry
end, "./CatalogRegistry")
local ProductionResearch = resolve(function()
	return script.Parent.FarmMath.production_research
end, "./FarmMath/production_research")

local defaultCatalog = CatalogRegistry.new(NumericCodec, CatalogData, { mode = "INTERNAL_TEST_ONLY" })
local defaultProductionMath = ProductionResearch.new(NumericCodec, defaultCatalog, { mode = "INTERNAL_TEST_ONLY" })

local BigAmount = NumericCodec.BigAmount
local Real64 = NumericCodec.Real64
local ExactUInt = NumericCodec.ExactUInt

local ProgressActions = {
	VERSION = 1,
}

-- Extracts Farm Value from a profile using FvSe.calculateFarmValue.
local function calculateProfileFarmValue(
	profile: any,
	catalog: any?,
	productionMath: any?,
	options: any?
): number
	assert(type(profile) == "table" and type(profile.farm) == "table", "ProgressActions/INVALID_PROFILE")
	catalog = catalog or defaultCatalog
	productionMath = productionMath or defaultProductionMath

	local farm = profile.farm
	local permanent = profile.permanent or {}
	local epic = permanent.epic or {}

	local eggIndex = farm.eggIndex or 0
	local eggRow = nil
	if catalog and type(catalog.getEgg) == "function" then
		local okEgg, resEgg = pcall(catalog.getEgg, eggIndex)
		if okEgg and resEgg then eggRow = resEgg end
	end
	local eggInfo = FvSe.EGGS[eggIndex]
	local eggValueBase = if eggRow and eggRow.value then eggRow.value elseif eggInfo then eggInfo.eggValueBase else 0.25

	-- Sum settled population across 4 habitats
	local population = 0
	local habitatTypes = { false, false, false, false }
	if farm.habitats then
		for i = 1, 4 do
			local hab = farm.habitats[i]
			if hab then
				if hab.population then
					population += ExactUInt.toSafeNumber(ExactUInt.decode(hab.population))
				end
				if hab.typeIndex ~= nil and hab.typeIndex >= 0 then
					habitatTypes[i] = hab.typeIndex
				end
			end
		end
	end

	-- Hab capacity from research & habitats
	local _, habCapacity = productionMath.capacities(farm.common or {}, habitatTypes)

	-- Vehicle shipping rate per minute
	local vehicleTypes = {}
	if farm.vehicles then
		for i, v in farm.vehicles do
			table.insert(vehicleTypes, v.typeIndex)
		end
	end
	local shippingPerSec = productionMath.shippingPerSecond(farm.common or {}, vehicleTypes)
	local shippingPerMinute = shippingPerSec * 60

	-- Research multipliers from Common
	local r = productionMath.research(farm.common or {})
	local researchEggLayingRateMult = r.layingPerChickenPerSecond * 30
	local researchEggValueMult = r.eggValue / 0.25
	local researchIHRBase = r.internalHatcheryPerHabPerMinute

	-- Epic research safe reading (docs/27 §4.2, docs/05 §4)
	local soulFoodLvl = (epic.soul_eggs or epic.soul_food) or 0
	local prophecyBonusLvl = epic.prophecy_bonus or 0
	local siloCapacityLevel = epic.silo_capacity or 0

	-- Mystical earnings multiplier (1 + EB)
	local se = Real64.decode(permanent.SE or "0")
	local pe = ExactUInt.toSafeNumber(ExactUInt.decode(permanent.PE or "0"))
	local _, mysticalMultiplier = FvSe.calculateEarningBonus(se, pe, soulFoodLvl, prophecyBonusLvl)

	local silosOwned = farm.siloOwned or 1
	local isContract = farm.isContract == true

	return FvSe.calculateFarmValue({
		eggIndex = eggIndex,
		population = population,
		habCapacity = habCapacity,
		shippingPerMinute = shippingPerMinute,
		researchEggLayingRateMult = researchEggLayingRateMult,
		researchEggValueMult = researchEggValueMult,
		eggValueBase = eggValueBase,
		silosOwned = silosOwned,
		siloCapacityLevel = siloCapacityLevel,
		researchIHRBase = researchIHRBase,
		researchIHRMult = 1.0,
		researchMaxRCBBase = 0,
		researchMaxRCBMult = 1.0,
		valuationMult = catalog.epicEffects("accounting_tricks",epic.accounting_tricks or 0).valuationMult or 1.0,
		localMysticalEarningsMultiplier = mysticalMultiplier,
		isContract = isContract,
	})
end

-- Calculates total prestige earnings: E = archived + current + extra (docs/05 §2, docs/13 §5).
local function calculatePrestigeEarnings(profile: any): number
	assert(type(profile) == "table" and type(profile.accounting) == "table", "ProgressActions/INVALID_PROFILE")
	local archived = BigAmount.decode(profile.accounting.prestigeSessionArchivedCash or "0")
	local current = BigAmount.decode(profile.accounting.currentFarmCash or "0")
	local extra = BigAmount.decode(profile.accounting.prestigeExtraEarnings or "0")
	return BigAmount.add(BigAmount.add(archived, current), extra)
end

-- Calculates pending Soul Eggs from current prestige earnings E as pure Real64 (docs/05 §2, Contract 27).
local function calculatePendingSoulEggs(profile: any, prestigeEventMult: number?): number
	local E = calculatePrestigeEarnings(profile)
	local epic = (profile.permanent and profile.permanent.epic) or {}
	local epicPrestigeBonusLvl = (epic.prestige_bonus or epic.epic_prestige_bonus) or 0
	return FvSe.calculateSoulEggs(E, epicPrestigeBonusLvl, prestigeEventMult or 1.0)
end

-- Checks if the farm qualifies to advance to targetEggIndex (docs/02 §1, §3).
local function canUpgradeEgg(
	profile: any,
	targetEggIndex: number,
	catalog: any?,
	productionMath: any?
): (boolean, string?, number?)
	assert(type(profile) == "table" and type(profile.farm) == "table", "ProgressActions/INVALID_PROFILE")
	local currentEgg = profile.farm.eggIndex or 0
	local fv = calculateProfileFarmValue(profile, catalog, productionMath)

	if type(targetEggIndex) ~= "number" or targetEggIndex % 1 ~= 0 or targetEggIndex < 0 or targetEggIndex > 18 or targetEggIndex <= currentEgg then
		return false, "INVALID_TARGET_EGG", fv
	end

	if not FvSe.canAdvanceEgg(fv, targetEggIndex) then
		return false, "FV_TOO_LOW", fv
	end

	return true, nil, fv
end

-- Applies egg advancement with full session cash archiving and farm infrastructure reset.
local function applyUpgradeEgg(candidateProfile: any, op: any, deps: any?): any
	assert(type(candidateProfile) == "table" and type(candidateProfile.farm) == "table", "ProgressActions/INVALID_PROFILE")
	assert(type(op) == "table", "ProgressActions/INVALID_OP")

	local catalog = (deps and deps.catalog) or defaultCatalog
	local productionMath = (deps and deps.productionMath) or defaultProductionMath

	local targetEggIndex = if op.args and op.args.targetEggIndex ~= nil then op.args.targetEggIndex else op.targetEggIndex
	local currentEgg = candidateProfile.farm.eggIndex or 0

	if type(targetEggIndex) ~= "number" or targetEggIndex % 1 ~= 0 or targetEggIndex < 0 or targetEggIndex > 18 or targetEggIndex <= currentEgg then
		return {
			profile = candidateProfile,
			terminalStatus = "REJECTED",
			result = {
				terminalStatus = "REJECTED",
				success = false,
				errorCode = "INVALID_TARGET_EGG",
			},
			validate = function() return true end,
		}
	end

	local fv = calculateProfileFarmValue(candidateProfile, catalog, productionMath)
	if not FvSe.canAdvanceEgg(fv, targetEggIndex) then
		return {
			profile = candidateProfile,
			terminalStatus = "REJECTED",
			result = {
				terminalStatus = "REJECTED",
				success = false,
				errorCode = "FV_TOO_LOW",
			},
			validate = function() return true end,
		}
	end

	-- Step 1: Session Cash Archiving (docs/02 §3.1, docs/13 §5)
	-- currentFarmCash rolls into prestigeSessionArchivedCash.
	-- prestigeExtraEarnings and lastBaseEarnings are PRESERVED!
	local curCash = BigAmount.decode(candidateProfile.accounting.currentFarmCash or "0")
	local prevArchived = BigAmount.decode(candidateProfile.accounting.prestigeSessionArchivedCash or "0")
	candidateProfile.accounting.prestigeSessionArchivedCash = BigAmount.encode(BigAmount.add(prevArchived, curCash))
	candidateProfile.accounting.currentFarmCash = "0"
	candidateProfile.accounting.lastCashEarned = "0"
	candidateProfile.farm.cash = "0"

	-- Step 2: Egg Index and Record update
	candidateProfile.farm.eggIndex = targetEggIndex
	candidateProfile.farm.maxEggReached = math.max(candidateProfile.farm.maxEggReached or 0, targetEggIndex)

	-- Step 3: Infrastructure Reset (docs/02 §3.2, docs/27 §4.2)
	-- Reset habitats to 1 Coop and 3 empty slots
	local habitats = {}
	for i = 1, 4 do
		habitats[i] = {
			typeIndex = if i == 1 then 0 else -1,
			population = "0",
			assignedInTransit = "0",
			fractionalIHR = "0",
		}
	end
	candidateProfile.farm.habitats = habitats
	candidateProfile.farm.vehicles = { { typeIndex = 0 } }
	candidateProfile.farm.fleetLimit = 4
	candidateProfile.farm.common = {}
	candidateProfile.farm.hatcheryStock = "250"
	candidateProfile.farm.runningCount = "0"
	candidateProfile.farm.groups = {}
	-- Preserve hatchGroupSequence: group IDs must remain unique across farm resets (docs/38). UpgradeEgg.
	candidateProfile.farm.siloOwned = 1

	-- Step 4: Storage Re-validation Callback
	local function validateFn(freshProfile: any, now: number): (boolean, string?)
		if not freshProfile or not freshProfile.farm then
			return false, "INVALID_PROFILE"
		end
		if (freshProfile.farm.eggIndex or 0) >= targetEggIndex then
			return false, "ALREADY_ADVANCED"
		end
		local freshFV = calculateProfileFarmValue(freshProfile, catalog, productionMath)
		if not FvSe.canAdvanceEgg(freshFV, targetEggIndex) then
			return false, "FV_TOO_LOW"
		end
		return true, nil
	end

	local targetEggRow = nil
	if catalog and type(catalog.getEgg) == "function" then
		local okEgg, resEgg = pcall(catalog.getEgg, targetEggIndex)
		if okEgg and resEgg then targetEggRow = resEgg end
	end
	local targetEggInfo = FvSe.EGGS[targetEggIndex]
	local targetEggValueBase = if targetEggRow and targetEggRow.value then targetEggRow.value elseif targetEggInfo then targetEggInfo.eggValueBase else 0.25

	return {
		profile = candidateProfile,
		terminalStatus = "APPLIED",
		result = {
			terminalStatus = "APPLIED",
			success = true,
			actionKind = "UpgradeEgg",
			newEggIndex = targetEggIndex,
			eggIndex = targetEggIndex,
			eggValueBase = targetEggValueBase,
		},
		validate = validateFn,
	}
end

-- Applies Prestige: calculates and grants Soul Eggs, increments prestigeCount,
-- resets all 5 session accounting accumulators, and resets farm to Edible (eggIndex = 0).
local function applyPrestige(candidateProfile: any, op: any, deps: any?): any
	assert(type(candidateProfile) == "table" and type(candidateProfile.farm) == "table", "ProgressActions/INVALID_PROFILE")
	assert(type(candidateProfile.permanent) == "table", "ProgressActions/INVALID_PROFILE")
	assert(type(candidateProfile.accounting) == "table", "ProgressActions/INVALID_PROFILE")

	-- Step 1: Calculate and grant Soul Eggs (BEFORE reset!)
	local E = calculatePrestigeEarnings(candidateProfile)
	local epic = candidateProfile.permanent.epic or {}
	local epicPrestigeBonusLvl = (epic.prestige_bonus or epic.epic_prestige_bonus) or 0
	local prestigeEventMult = (deps and deps.prestigeEventMult)
		or 1.0

	local gainedSE = FvSe.calculateSoulEggs(E, epicPrestigeBonusLvl, prestigeEventMult)
	local currentSE = Real64.decode(candidateProfile.permanent.SE or "0")
	local newSE = Real64.add(currentSE, gainedSE)
	candidateProfile.permanent.SE = Real64.encode(newSE)

	local curPrestigeCount = ExactUInt.decode(candidateProfile.permanent.prestigeCount or "0")
	local newPrestigeCount = ExactUInt.add(curPrestigeCount, ExactUInt.fromSafeNumber(1))
	candidateProfile.permanent.prestigeCount = ExactUInt.encode(newPrestigeCount)

	-- Step 2: Full reset of all 5 session accounting accumulators (docs/05 §2, docs/13 §5)
	candidateProfile.accounting.prestigeSessionArchivedCash = "0"
	candidateProfile.accounting.currentFarmCash = "0"
	candidateProfile.accounting.lastCashEarned = "0"
	candidateProfile.accounting.prestigeExtraEarnings = "0"
	candidateProfile.accounting.lastBaseEarnings = "0"

	-- Step 3: Reset farm to initial Edible Egg state (docs/05 §1, docs/27 §4.2)
	candidateProfile.farm.eggIndex = 0
	candidateProfile.farm.cash = "0"

	local habitats = {}
	for i = 1, 4 do
		habitats[i] = {
			typeIndex = if i == 1 then 0 else -1,
			population = "0",
			assignedInTransit = "0",
			fractionalIHR = "0",
		}
	end
	candidateProfile.farm.habitats = habitats
	candidateProfile.farm.vehicles = { { typeIndex = 0 } }
	candidateProfile.farm.fleetLimit = 4
	candidateProfile.farm.common = {}
	candidateProfile.farm.hatcheryStock = "250"
	candidateProfile.farm.runningCount = "0"
	candidateProfile.farm.groups = {}
	-- Preserve hatchGroupSequence: group IDs must remain unique across farm resets (docs/38). Prestige.
	candidateProfile.farm.siloOwned = 1

	-- All other fields (GE, PE, epic, hyperloop, inventory, effects, timeline, rewards, piggy, entitlements, operations) preserved!

	return {
		profile = candidateProfile,
		terminalStatus = "APPLIED",
		result = {
			terminalStatus = "APPLIED",
			actionKind = "Prestige",
			gainedSoulEggs = Real64.encode(gainedSE),
			newSoulEggs = candidateProfile.permanent.SE,
			prestigeCount = candidateProfile.permanent.prestigeCount,
		},
		validate = function() return true end,
	}
end

-- Domain dispatcher for PlayerCoordinator domain port.
local function apply(candidateProfile: any, op: any, deps: any?): any
	assert(type(candidateProfile) == "table", "ProgressActions/INVALID_PROFILE")
	assert(type(op) == "table" and type(op.kind) == "string", "ProgressActions/INVALID_OP")

	if op.kind == "UpgradeEgg" then
		return applyUpgradeEgg(candidateProfile, op, deps)
	elseif op.kind == "Prestige" then
		return applyPrestige(candidateProfile, op, deps)
	else
		return {
			profile = candidateProfile,
			terminalStatus = "REJECTED",
			result = {
				terminalStatus = "REJECTED",
				errorCode = "UNKNOWN_PROGRESS_ACTION",
			},
			validate = function() return true end,
		}
	end
end

-- Factory constructor for injection into test harnesses and custom dependency containers.
function ProgressActions.new(codec: any?, catalog: any?, productionMath: any?, options: any?): any
	codec = codec or NumericCodec
	catalog = catalog or defaultCatalog
	productionMath = productionMath or defaultProductionMath

	local instance = {
		VERSION = 1,
		codec = codec,
		catalog = catalog,
		productionMath = productionMath,
	}

	function instance.calculateProfileFarmValue(profile: any, optionsOverride: any?): number
		return calculateProfileFarmValue(profile, catalog, productionMath, optionsOverride)
	end

	function instance.calculatePrestigeEarnings(profile: any): number
		return calculatePrestigeEarnings(profile)
	end

	function instance.calculatePendingSoulEggs(profile: any, prestigeEventMult: number?): number
		return calculatePendingSoulEggs(profile, prestigeEventMult)
	end

	function instance.canUpgradeEgg(profile: any, targetEggIndex: number): (boolean, string?, number?)
		return canUpgradeEgg(profile, targetEggIndex, catalog, productionMath)
	end

	function instance.applyUpgradeEgg(candidateProfile: any, op: any, depsOverride: any?): any
		local merged = { catalog = catalog, productionMath = productionMath }
		if depsOverride then
			for k, v in depsOverride do merged[k] = v end
		end
		return applyUpgradeEgg(candidateProfile, op, merged)
	end
	instance.upgradeEgg = instance.applyUpgradeEgg

	function instance.applyPrestige(candidateProfile: any, op: any, depsOverride: any?): any
		local merged = { catalog = catalog, productionMath = productionMath }
		if depsOverride then
			for k, v in depsOverride do merged[k] = v end
		end
		return applyPrestige(candidateProfile, op, merged)
	end

	function instance.apply(candidateProfile: any, op: any, depsOverride: any?): any
		local merged = { catalog = catalog, productionMath = productionMath }
		if depsOverride then
			for k, v in depsOverride do merged[k] = v end
		end
		return apply(candidateProfile, op, merged)
	end

	return table.freeze(instance)
end

ProgressActions.calculateProfileFarmValue = calculateProfileFarmValue
ProgressActions.calculatePrestigeEarnings = calculatePrestigeEarnings
ProgressActions.calculatePendingSoulEggs = calculatePendingSoulEggs
ProgressActions.canUpgradeEgg = canUpgradeEgg
ProgressActions.applyUpgradeEgg = applyUpgradeEgg
ProgressActions.upgradeEgg = applyUpgradeEgg
ProgressActions.applyPrestige = applyPrestige
ProgressActions.apply = apply

return table.freeze(ProgressActions)
