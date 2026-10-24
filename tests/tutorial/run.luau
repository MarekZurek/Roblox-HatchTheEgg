--!nocheck
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local Codec = require("../../src/shared/NumericCodec")
local Onboarding = require("../../src/server/onboarding/manager")
local TutorialController = require("../../src/client/onboarding/TutorialController")
local Trophies = require("../../src/server/rewards/trophies")

local assertions = 0
local function eq(a, b, label)
	assertions += 1
	assert(a == b, (if label then label .. ": " else "") .. tostring(a) .. " != " .. tostring(b))
end

-- ============================================================================
-- Section 1: Initial Profile Baseline (docs/31 §4)
-- ============================================================================
do
	local nowMs = 123456789
	local p = Onboarding.createInitialProfile("player-test-onboard", nowMs)

	-- Farm & Infrastructure baseline
	eq(p.farm.eggIndex, 0, "starting egg is Edible (0)")
	eq(p.farm.maxEggReached, 0, "maxEggReached is 0")
	eq(p.farm.cash, "0", "starting cash is 0")
	eq(#p.farm.habitats, 4, "4 habitat slots")
	eq(p.farm.habitats[1].typeIndex, 0, "slot 1 is Coop (typeIndex 0)")
	eq(p.farm.habitats[1].population, "0", "slot 1 population 0")
	eq(p.farm.habitats[2].typeIndex, -1, "slot 2 is empty (-1)")
	eq(p.farm.habitats[3].typeIndex, -1, "slot 3 is empty (-1)")
	eq(p.farm.habitats[4].typeIndex, -1, "slot 4 is empty (-1)")

	-- Fleet & Silos baseline
	eq(#p.farm.vehicles, 1, "1 vehicle")
	eq(p.farm.vehicles[1].typeIndex, 0, "vehicle is Trike (0)")
	eq(p.farm.fleetLimit, 4, "baseline fleetLimit is 4")
	eq(p.farm.siloOwned, 1, "1 owned silo")

	-- Hatchery & Research baseline
	eq(p.farm.hatcheryStock, "250", "hatchery stock is full 250")
	eq(p.farm.runningCount, "0", "runningCount is 0")
	eq(next(p.farm.common), nil, "common research is empty")

	-- Permanent & Economics baseline
	eq(p.permanent.GE, "10", "starting GE is exactly 10 (earned=10, spent=0)")
	eq(p.permanent.totalGESpent, "0", "totalGESpent is 0")
	eq(p.permanent.SE, "0", "SE is 0")
	eq(p.permanent.PE, "0", "PE is 0")
	eq(next(p.permanent.epic), nil, "epic research is empty")

	-- Rewards baseline
	eq(p.rewards.tutorialStep, 1, "starts at tutorial step 1")
	eq(p.rewards.lastFreeBonusDayUtc, -1, "no free bonus claimed yet")
	eq(p.rewards.lastCalendarDayUtc, -1, "no calendar day claimed yet")
	eq(p.rewards.numDailyGiftsCollected, 0, "0 daily gifts collected")
	eq(next(p.rewards.trophies), nil, "trophies empty")

	-- Piggy baseline
	eq(p.piggy.rawAmount, 0, "piggy bank starts empty")
end

-- ============================================================================
-- Section 2: Sequential Step Advancement
-- ============================================================================
do
	local p = Onboarding.createInitialProfile("p1", 1000)
	eq(p.rewards.tutorialStep, 1, "starts at step 1")

	local ok1, s2 = Onboarding.advanceTutorialStep(p, 1)
	eq(ok1, true, "advance step 1 -> 2")
	eq(s2, 2, "now step 2")

	local ok2, s3 = Onboarding.advanceTutorialStep(p, 2)
	eq(ok2, true, "advance step 2 -> 3")
	eq(s3, 3, "now step 3")

	local ok3, s4 = Onboarding.advanceTutorialStep(p, 3)
	eq(ok3, true, "advance step 3 -> 4")
	eq(s4, 4, "now step 4")

	local ok4, s5 = Onboarding.advanceTutorialStep(p, 4)
	eq(ok4, true, "advance step 4 -> 5")
	eq(s5, 5, "now step 5 (COMPLETED)")

	-- Cannot advance past completed
	local ok5, sStay = Onboarding.advanceTutorialStep(p, 5)
	eq(ok5, false, "cannot advance past step 5")
	eq(sStay, 5, "stays at step 5")
end

-- ============================================================================
-- Section 3: Reconcile Tutorial Steps on Reconnect (Soft-lock prevention)
-- ============================================================================
do
	-- Fresh profile: step stays 1
	local pFresh = Onboarding.createInitialProfile("p_fresh", 1000)
	local recFresh = Onboarding.reconcileTutorialStep(pFresh)
	eq(recFresh, 1, "fresh profile stays at step 1")

	-- Profile that has hatched chickens (population > 0): reconciles to step 2
	local pHatched = Onboarding.createInitialProfile("p_hatched", 1000)
	pHatched.farm.habitats[1].population = "5"
	local recHatched = Onboarding.reconcileTutorialStep(pHatched)
	eq(recHatched, 2, "reconciles to step 2 when population > 0")

	-- Profile that has researched Common: reconciles to step 3
	local pResearched = Onboarding.createInitialProfile("p_res", 1000)
	pResearched.farm.habitats[1].population = "10"
	pResearched.farm.common.comfy_nests = 1
	local recRes = Onboarding.reconcileTutorialStep(pResearched)
	eq(recRes, 3, "reconciles to step 3 when research present")

	-- Profile that has upgraded habitat (typeIndex = 1 Shack): reconciles to step 4
	local pHabUpgraded = Onboarding.createInitialProfile("p_hab", 1000)
	pHabUpgraded.farm.habitats[1].typeIndex = 1
	pHabUpgraded.farm.habitats[1].population = "20"
	pHabUpgraded.farm.common.comfy_nests = 1
	local recHab = Onboarding.reconcileTutorialStep(pHabUpgraded)
	eq(recHab, 4, "reconciles to step 4 when habitat upgraded")

	-- Profile that has collected calendar gift: reconciles to step 5 (COMPLETED)
	local pGiftDone = Onboarding.createInitialProfile("p_gift", 1000)
	pGiftDone.farm.habitats[1].typeIndex = 1
	pGiftDone.farm.habitats[1].population = "50"
	pGiftDone.farm.common.comfy_nests = 1
	pGiftDone.rewards.numDailyGiftsCollected = 1
	local recGift = Onboarding.reconcileTutorialStep(pGiftDone)
	eq(recGift, 5, "reconciles to step 5 (COMPLETED) when gift collected")

	-- Reconnect with fully advanced profile never soft-locks
	local pAdvanced = Onboarding.createInitialProfile("p_adv", 1000)
	pAdvanced.farm.cash = "1000000000"
	pAdvanced.farm.common.super_clutch = 5
	pAdvanced.rewards.numDailyGiftsCollected = 3
	local recAdv = Onboarding.reconcileTutorialStep(pAdvanced)
	eq(recAdv, 5, "advanced profile immediately reconciles to COMPLETED without locking")
end

-- ============================================================================
-- Section 4: Retroactive Trophy Checks Without Double Claims
-- ============================================================================
do
	local p = Onboarding.createInitialProfile("p_troph", 1000)
	p.farm.eggIndex = 0 -- Edible

	-- Population below 10M: no trophies
	local rew0 = Onboarding.checkRetroactiveTrophies(p, 5_000_000)
	eq(next(rew0), nil, "no trophies below 10M population")

	-- Population reaches 10M: Bronze trophy (2M SE) awarded
	local rewBronze = Onboarding.checkRetroactiveTrophies(p, 10_000_000)
	eq(rewBronze["0:1"] ~= nil, true, "Bronze trophy 0:1 awarded")
	eq(rewBronze["0:1"].soulEggs, 2_000_000, "2M SE awarded")
	eq(p.permanent.SE, "2000000", "SE updated in profile")

	-- Second check at 10M: already claimed, no new awards!
	local rewBronzeDup = Onboarding.checkRetroactiveTrophies(p, 10_000_000)
	eq(next(rewBronzeDup), nil, "no duplicate awards on second check")
	eq(p.permanent.SE, "2000000", "SE balance not duplicated")

	-- Population jumps to 10B: Diamond trophy (5 PE) awarded, Bronze NOT re-awarded!
	local rewDiamond = Onboarding.checkRetroactiveTrophies(p, 10_000_000_000)
	eq(rewDiamond["0:1"], nil, "Bronze was already claimed")
	eq(rewDiamond["0:5"] ~= nil, true, "Diamond trophy 0:5 awarded")
	eq(rewDiamond["0:5"].prophecyEggs, 5, "5 PE awarded")
	eq(p.permanent.PE, "5", "PE updated to 5")
end

-- ============================================================================
-- Section 5: Client TutorialController
-- ============================================================================
do
	local ctrl = TutorialController.new(nil, nil)
	eq(ctrl.currentStep, 1, "client starts at step 1")
	eq(ctrl:getTargetWidget(), "HatchButton", "step 1 targets HatchButton")
	eq(ctrl:isCompleted(), false, "not completed at step 1")

	ctrl:setStep(2)
	eq(ctrl.currentStep, 2, "client step set to 2")
	eq(ctrl:getTargetWidget(), "ResearchMenuButton", "step 2 targets ResearchMenuButton")

	ctrl:setStep(5)
	eq(ctrl.currentStep, 5, "client step set to 5")
	eq(ctrl:isCompleted(), true, "completed at step 5")
	eq(ctrl.visible, false, "controller hidden on completion")
end

-- ============================================================================
-- Section 6: Save Results JSON
-- ============================================================================
fs.writeFile("build/tutorial-results.json", serde.encode("json", {
	status = "PASS",
	level = "L",
	assertions = assertions,
	studioTested = false,
	dataStoreTested = false,
	scope = "NEXT-10 Onboarding initial profile baseline, tutorial steps, reconnect reconciliation, and retroactive trophies",
}, true))

print(string.format("Onboarding & Tutorial PASS: %d assertions", assertions))
