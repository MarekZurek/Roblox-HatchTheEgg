--!strict
-- Farm Value (FV) and Soul Eggs (SE) pure arithmetic.
-- Spec: docs/02_eggs_and_farm_value.md §1-§2, docs/05_prestige_soul_eggs_and_boosts.md §2-§4, docs/27 §2.

local FvSe = {}

export type FarmValueParams = {
	eggIndex: number,
	population: number,
	habCapacity: number,
	shippingPerMinute: number,
	researchEggLayingRateMult: number?,
	researchEggValueMult: number?,
	eggValueBase: number,
	silosOwned: number?,
	siloCapacityLevel: number?,
	researchIHRBase: number?,
	researchIHRMult: number?,
	researchMaxRCBBase: number?,
	researchMaxRCBMult: number?,
	valuationMult: number?,
	localMysticalEarningsMultiplier: number?,
	isContract: boolean?,
}

export type EggInfo = {
	index: number,
	name: string,
	eggValueBase: number,
	discoveryFV: number,
	advanceFV: number,
}

local function fail(code: string): never
	error("FarmMath/fv_se/" .. code, 3)
end

local function finite(value: any, name: string): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		fail("INVALID_" .. name)
	end
	return value
end

local function nonnegative(value: any, name: string): number
	local v = finite(value, name)
	if v < 0 then
		fail("NEGATIVE_" .. name)
	end
	return v
end

local function positive(value: any, name: string): number
	local v = finite(value, name)
	if v <= 0 then
		fail("NON_POSITIVE_" .. name)
	end
	return v
end

-- 19 egg species definitions from docs/02 §1 & docs/reference_data/infrastructure.json
local EGGS: { [number]: EggInfo } = table.freeze({
	[0] = table.freeze({ index = 0, name = "KURZE", eggValueBase = 1.0, discoveryFV = 0, advanceFV = 0 }),
	[1] = table.freeze({ index = 1, name = "KACZE", eggValueBase = 3.0, discoveryFV = 5e7, advanceFV = 2.5e8 }),
	[2] = table.freeze({ index = 2, name = "GĘSIE", eggValueBase = 10.0, discoveryFV = 2e9, advanceFV = 1e10 }),
	[3] = table.freeze({ index = 3, name = "INDYCZE", eggValueBase = 40.0, discoveryFV = 1e11, advanceFV = 5e11 }),
	[4] = table.freeze({ index = 4, name = "STRUSIE", eggValueBase = 160.0, discoveryFV = 1e14, advanceFV = 5e14 }),
	[5] = table.freeze({ index = 5, name = "PAWIE", eggValueBase = 700.0, discoveryFV = 2e16, advanceFV = 1e17 }),
	[6] = table.freeze({ index = 6, name = "PINGWINIE", eggValueBase = 3000.0, discoveryFV = 1e19, advanceFV = 5e19 }),
	[7] = table.freeze({ index = 7, name = "KRUCZE", eggValueBase = 15000.0, discoveryFV = 5e22, advanceFV = 2.5e23 }),
	[8] = table.freeze({ index = 8, name = "ORLE", eggValueBase = 60000.0, discoveryFV = 1e26, advanceFV = 5e26 }),
	[9] = table.freeze({ index = 9, name = "KAZUARA", eggValueBase = 250000.0, discoveryFV = 5e29, advanceFV = 2.5e30 }),
	[10] = table.freeze({ index = 10, name = "PTERODAKTYLA", eggValueBase = 1000000.0, discoveryFV = 2e33, advanceFV = 1e34 }),
	[11] = table.freeze({ index = 11, name = "RAPTORA", eggValueBase = 5000000.0, discoveryFV = 1e37, advanceFV = 5e37 }),
	[12] = table.freeze({ index = 12, name = "TYRANOZAURA", eggValueBase = 25000000.0, discoveryFV = 1e41, advanceFV = 5e41 }),
	[13] = table.freeze({ index = 13, name = "GRYFA", eggValueBase = 2500000000.0, discoveryFV = 5e44, advanceFV = 2.5e45 }),
	[14] = table.freeze({ index = 14, name = "HYDRY", eggValueBase = 100000000000.0, discoveryFV = 5e48, advanceFV = 2.5e49 }),
	[15] = table.freeze({ index = 15, name = "BAZYLISZKA", eggValueBase = 1e12, discoveryFV = 2e52, advanceFV = 1e53 }),
	[16] = table.freeze({ index = 16, name = "FENIKSA", eggValueBase = 15e12, discoveryFV = 5e56, advanceFV = 2.5e57 }),
	[17] = table.freeze({ index = 17, name = "SMOCZE", eggValueBase = 150e12, discoveryFV = 1e61, advanceFV = 5e61 }),
	[18] = table.freeze({ index = 18, name = "ASTRALNEGO LEWIATANA", eggValueBase = 1e-7, discoveryFV = 1e65, advanceFV = 5e65 }),
})

-- Pure Farm Value calculation according to docs/02 §2.
local function calculateFarmValue(params: FarmValueParams): number
	if type(params) ~= "table" then
		fail("INVALID_PARAMS")
	end

	local eggIndex = params.eggIndex
	if type(eggIndex) ~= "number" or eggIndex % 1 ~= 0 or eggIndex < 0 or eggIndex > 18 then
		fail("INVALID_EGG_INDEX")
	end

	local population = nonnegative(params.population, "POPULATION")
	local habCapacity = nonnegative(params.habCapacity, "HAB_CAPACITY")
	local shippingPerMinute = nonnegative(params.shippingPerMinute, "SHIPPING_PER_MINUTE")
	local eggValueBase = positive(params.eggValueBase, "EGG_VALUE_BASE")

	local researchEggLayingRateMult = if params.researchEggLayingRateMult ~= nil
		then positive(params.researchEggLayingRateMult, "RESEARCH_EGG_LAYING_RATE_MULT")
		else 1.0
	local researchEggValueMult = if params.researchEggValueMult ~= nil
		then nonnegative(params.researchEggValueMult, "RESEARCH_EGG_VALUE_MULT")
		else 1.0
	local silosOwned = if params.silosOwned ~= nil
		then nonnegative(params.silosOwned, "SILOS_OWNED")
		else 1
	local siloCapacityLevel = if params.siloCapacityLevel ~= nil
		then nonnegative(params.siloCapacityLevel, "SILO_CAPACITY_LEVEL")
		else 0
	local researchIHRBase = if params.researchIHRBase ~= nil
		then nonnegative(params.researchIHRBase, "RESEARCH_IHR_BASE")
		else 0
	local researchIHRMult = if params.researchIHRMult ~= nil
		then nonnegative(params.researchIHRMult, "RESEARCH_IHR_MULT")
		else 1.0
	local researchMaxRCBBase = if params.researchMaxRCBBase ~= nil
		then nonnegative(params.researchMaxRCBBase, "RESEARCH_MAX_RCB_BASE")
		else 0
	local researchMaxRCBMult = if params.researchMaxRCBMult ~= nil
		then nonnegative(params.researchMaxRCBMult, "RESEARCH_MAX_RCB_MULT")
		else 1.0
	local valuationMult = if params.valuationMult ~= nil
		then nonnegative(params.valuationMult, "VALUATION_MULT")
		else 1.0
	local localMysticalEarningsMultiplier = if params.localMysticalEarningsMultiplier ~= nil
		then nonnegative(params.localMysticalEarningsMultiplier, "LOCAL_MYSTICAL_EARNINGS_MULTIPLIER")
		else 1.0
	local isContract = params.isContract == true

	local L = researchEggLayingRateMult / 30
	local C = math.floor((shippingPerMinute / 60) / L)
	local P = if population <= C then population else math.floor(C + 0.2 * (population - C))
	local F = math.max(0, habCapacity - population) ^ 0.6
	local I = 4 * researchIHRBase * researchIHRMult / 60
	local T = silosOwned * (3600 + 360 * siloCapacityLevel)
	local R = math.max(1, (5 + researchMaxRCBBase) * researchMaxRCBMult - 4) ^ 0.25
	local K: number
	if isContract then
		K = if eggIndex == 18 then 3600 else 6000
	else
		K = if eggIndex < 18 then 1200 + 600 * eggIndex else 3600
	end

	local FV = 50 * K * valuationMult * localMysticalEarningsMultiplier * L * eggValueBase * researchEggValueMult * (P + F + 0.25 * I * T) * R
	return FV
end

-- Pure Soul Eggs piecewise calculation according to docs/05 §2 & Contract 27.
-- Returns exact Real64 without math.floor.
local function calculateSoulEggs(
	earnings: number,
	epicPrestigeBonusLevel: number?,
	prestigeEventMult: number?
): number
	if type(earnings) ~= "number" or earnings ~= earnings or earnings < 1 then
		return 0
	end

	local p: number
	if earnings >= 1e60 then
		p = 0.21
	elseif earnings >= 1e48 then
		p = 0.20
	elseif earnings >= 1e39 then
		p = 0.19
	elseif earnings >= 1e30 then
		p = 0.18
	elseif earnings >= 1e21 then
		p = 0.17
	elseif earnings >= 1e12 then
		p = 0.16
	else
		p = 0.15
	end

	local baseSE = earnings ^ p
	local epLevel = if epicPrestigeBonusLevel ~= nil then epicPrestigeBonusLevel else 0
	local eventMult = if prestigeEventMult ~= nil then prestigeEventMult else 1.0
	local collectionMult = (1 + 0.10 * epLevel) * eventMult
	return baseSE * collectionMult
end

-- Earning Bonus (EB) and Mystical Multiplier calculation according to docs/05 §4.
-- Returns (EB, mysticalMultiplier) where mysticalMultiplier = 1.0 + EB.
local function calculateEarningBonus(
	soulEggs: number?,
	prophecyEggs: number?,
	soulFoodLvl: number?,
	prophecyBonusLvl: number?
): (number, number)
	local se = if soulEggs ~= nil then soulEggs else 0
	local pe = if prophecyEggs ~= nil then prophecyEggs else 0
	local sf = if soulFoodLvl ~= nil then soulFoodLvl else 0
	local pb = if prophecyBonusLvl ~= nil then prophecyBonusLvl else 0

	local ebPerSoulEgg = 0.10 + 0.01 * sf
	local peMultPerEgg = 1.05 + 0.01 * pb
	local peFactor = peMultPerEgg ^ pe
	local EB = se * ebPerSoulEgg * peFactor
	local mysticalMultiplier = 1.0 + EB
	return EB, mysticalMultiplier
end

-- Discovery threshold check (docs/02 §1).
local function canDiscoverEgg(fv: number, targetEggIndex: number): boolean
	if type(fv) ~= "number" or fv ~= fv or type(targetEggIndex) ~= "number" then
		return false
	end
	local egg = EGGS[targetEggIndex]
	if egg == nil then
		return false
	end
	return fv >= egg.discoveryFV
end

-- Advance threshold check (docs/02 §1).
local function canAdvanceEgg(fv: number, targetEggIndex: number): boolean
	if type(fv) ~= "number" or fv ~= fv or type(targetEggIndex) ~= "number" then
		return false
	end
	local egg = EGGS[targetEggIndex]
	if egg == nil then
		return false
	end
	return fv >= egg.advanceFV
end

FvSe.calculateFarmValue = calculateFarmValue
FvSe.calculateSoulEggs = calculateSoulEggs
FvSe.calculateEarningBonus = calculateEarningBonus
FvSe.EGGS = EGGS
FvSe.canDiscoverEgg = canDiscoverEgg
FvSe.canAdvanceEgg = canAdvanceEgg

return table.freeze(FvSe)
