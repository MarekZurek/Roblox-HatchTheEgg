--!strict
-- Authoritative server logic for new player onboarding, tutorial lifecycle, and state reconciliation.
-- Spec: docs/31 §4; docs/27 §4; docs/28; Issue #35 (NEXT-10).

local Codec = require("../../shared/NumericCodec")
local ExactUInt = Codec.ExactUInt
local BigAmount = Codec.BigAmount
local Trophies = require("../rewards/trophies")

local Onboarding = {
	VERSION = 1,
	STEPS = table.freeze({
		HATCH_FIRST_CHICKEN = 1,
		BUY_FIRST_RESEARCH = 2,
		UPGRADE_HABITAT = 3,
		COLLECT_DAILY_GIFT = 4,
		COMPLETED = 5,
	}),
	STEP_NAMES = table.freeze({
		[1] = "HATCH_FIRST_CHICKEN",
		[2] = "BUY_FIRST_RESEARCH",
		[3] = "UPGRADE_HABITAT",
		[4] = "COLLECT_DAILY_GIFT",
		[5] = "COMPLETED",
	}),
}

-- Creates initial new player profile strictly adhering to docs/31 §4 (no arbitrary free grants).
local function createInitialProfile(playerId: string, nowMs: number): any
	assert(type(playerId) == "string" and #playerId > 0, "Onboarding/INVALID_PLAYER_ID")
	assert(type(nowMs) == "number" and nowMs >= 0, "Onboarding/INVALID_TIMESTAMP")

	local habitats = {}
	for i = 1, 4 do
		habitats[i] = {
			typeIndex = if i == 1 then 0 else -1, -- 1 Coop in slot 1 (typeIndex = 0), other 3 empty (-1)
			population = "0",
			assignedInTransit = "0",
			fractionalIHR = "0",
		}
	end

	return {
		meta = {
			schemaVersion = 1,
			numericCodecVersion = Codec.VERSION,
			calculationVersion = 1,
			configRevision = "first-farm-neutral:1",
			revision = "0",
			playerId = playerId,
			mode = "INTERNAL_TEST_ONLY",
		},
		ownership = {
			generation = "0",
			ownerToken = "",
			endsAtMs = 0,
		},
		farm = {
			eggIndex = 0, -- First egg: Edible
			maxEggReached = 0,
			cash = "0", -- $0 starting cash
			habitats = habitats,
			vehicles = { { typeIndex = 0 } }, -- 1 Trike in slot 1
			fleetLimit = 4, -- Base fleet limit 4
			siloOwned = 1, -- 1 owned silo (3600s baseline)
			common = {},
			hatcheryStock = "250", -- Full 250 hatchery stock
			runningCount = "0",
			hatchGroupSequence = "0",
			groups = {},
		},
		accounting = {
			prestigeSessionArchivedCash = "0",
			prestigeExtraEarnings = "0",
			lastBaseEarnings = "0",
			currentFarmCash = "0",
			lastCashEarned = "0",
		},
		permanent = {
			GE = "10", -- Reference starting earned GE = 10, spent = 0
			totalGESpent = "0",
			SE = "0",
			PE = "0",
			epic = {},
			hyperloop = false,
			prestigeCount = "0",
		},
		inventory = {
			boosts = {},
			pets = {},
			equipped = {},
			guarantees = {},
		},
		effects = {
			boosts = {},
		},
		timeline = {
			settledWallThrough = nowMs,
		},
		rewards = {
			lastFreeBonusDayUtc = -1,
			lastCalendarDayUtc = -1,
			numDailyGiftsCollected = 0,
			trophies = {},
			tutorialStep = 1, -- Starts at Step 1
		},
		piggy = {
			rawAmount = 0,
			breaksCount = 0,
		},
		entitlements = {},
		operations = {},
	}
end

-- Checks total settled and in-transit population on farm.
local function getTotalPopulation(farm: any): number
	if not farm or not farm.habitats then
		return 0
	end
	local total = 0
	for _, hab in farm.habitats do
		if hab.population then
			local dec = ExactUInt.decode(hab.population)
			total += ExactUInt.toSafeNumber(dec)
		end
		if hab.assignedInTransit then
			local decT = ExactUInt.decode(hab.assignedInTransit)
			total += ExactUInt.toSafeNumber(decT)
		end
	end
	return total
end

-- Checks if any common research has been purchased.
local function hasAnyResearch(farm: any): boolean
	if not farm or not farm.common then
		return false
	end
	for _, lvl in farm.common do
		if type(lvl) == "number" and lvl > 0 then
			return true
		end
	end
	return false
end

-- Checks if player has upgraded or purchased additional habitats or vehicles.
local function hasUpgradedInfrastructure(farm: any): boolean
	if not farm then
		return false
	end
	if farm.habitats then
		for i, hab in farm.habitats do
			if (i == 1 and hab.typeIndex > 0) or (i > 1 and hab.typeIndex >= 0) then
				return true
			end
		end
	end
	if farm.vehicles and #farm.vehicles > 1 then
		return true
	end
	if farm.siloOwned and farm.siloOwned > 1 then
		return true
	end
	return false
end

-- Reconciles tutorial step based on player's actual state.
-- Eliminates soft-locks upon reconnect or mid-progress returns.
local function reconcileTutorialStep(profile: any): number
	assert(profile ~= nil and profile.rewards ~= nil, "Onboarding/INVALID_PROFILE")
	local step = profile.rewards.tutorialStep or 1

	while step < Onboarding.STEPS.COMPLETED do
		if step == Onboarding.STEPS.HATCH_FIRST_CHICKEN then
			local pop = getTotalPopulation(profile.farm)
			local running = (profile.farm and profile.farm.runningCount and ExactUInt.toSafeNumber(ExactUInt.decode(profile.farm.runningCount))) or 0
			local cash = (profile.farm and profile.farm.cash and BigAmount.decode(profile.farm.cash)) or 0
			if pop > 0 or running > 0 or cash > 0 or hasAnyResearch(profile.farm) or hasUpgradedInfrastructure(profile.farm) then
				step = Onboarding.STEPS.BUY_FIRST_RESEARCH
			else
				break
			end
		elseif step == Onboarding.STEPS.BUY_FIRST_RESEARCH then
			if hasAnyResearch(profile.farm) or hasUpgradedInfrastructure(profile.farm) then
				step = Onboarding.STEPS.UPGRADE_HABITAT
			else
				break
			end
		elseif step == Onboarding.STEPS.UPGRADE_HABITAT then
			if hasUpgradedInfrastructure(profile.farm) or (profile.rewards.numDailyGiftsCollected and profile.rewards.numDailyGiftsCollected > 0) then
				step = Onboarding.STEPS.COLLECT_DAILY_GIFT
			else
				break
			end
		elseif step == Onboarding.STEPS.COLLECT_DAILY_GIFT then
			if profile.rewards.numDailyGiftsCollected and profile.rewards.numDailyGiftsCollected > 0 then
				step = Onboarding.STEPS.COMPLETED
			else
				break
			end
		end
	end

	profile.rewards.tutorialStep = step
	return step
end

-- Advances tutorial step explicitly.
local function advanceTutorialStep(profile: any, fromStep: number): (boolean, number)
	assert(profile ~= nil and profile.rewards ~= nil, "Onboarding/INVALID_PROFILE")
	local curStep = profile.rewards.tutorialStep or 1
	if curStep == fromStep and curStep < Onboarding.STEPS.COMPLETED then
		curStep += 1
		profile.rewards.tutorialStep = curStep
		return true, curStep
	end
	return false, curStep
end

-- Checks and awards any earned trophies retroactively without double claims.
local function checkRetroactiveTrophies(profile: any, currentPopulation: number): { [string]: any }
	assert(profile ~= nil and profile.permanent ~= nil, "Onboarding/INVALID_PROFILE")
	local eggIndex = (profile.farm and profile.farm.eggIndex) or 0
	local awarded = {}

	for tierIndex = 1, #Trophies.POPULATION_TIERS do
		local reqPop = Trophies.POPULATION_TIERS[tierIndex]
		if currentPopulation >= reqPop then
			local key = Trophies.getTrophyKey(eggIndex, tierIndex)
			if not Trophies.isTrophyClaimed(profile, eggIndex, tierIndex) then
				local ok, rew = Trophies.claimTrophy(profile, eggIndex, tierIndex, currentPopulation)
				if ok and rew then
					awarded[key] = rew
				end
			end
		end
	end

	return awarded
end

Onboarding.createInitialProfile = createInitialProfile
Onboarding.getTotalPopulation = getTotalPopulation
Onboarding.hasAnyResearch = hasAnyResearch
Onboarding.hasUpgradedInfrastructure = hasUpgradedInfrastructure
Onboarding.reconcileTutorialStep = reconcileTutorialStep
Onboarding.advanceTutorialStep = advanceTutorialStep
Onboarding.checkRetroactiveTrophies = checkRetroactiveTrophies

return table.freeze(Onboarding)
