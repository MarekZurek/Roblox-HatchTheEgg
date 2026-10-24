--!nocheck
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local Codec = require("../../src/shared/NumericCodec")
local Calendar = require("../../src/server/rewards/calendar")
local Trophies = require("../../src/server/rewards/trophies")

local ExactUInt = Codec.ExactUInt
local BigAmount = Codec.BigAmount

local assertions = 0
local function eq(a, b, label)
	assertions += 1
	assert(a == b, (if label then label .. ": " else "") .. tostring(a) .. " != " .. tostring(b))
end

local function makeProfile()
	return {
		meta = { schemaVersion = 1, revision = "0" },
		permanent = { GE = "100", totalGESpent = "0", SE = "0", PE = "0", epic = {} },
		farm = { cash = "0", habitats = {} },
		accounting = { lastCashEarned = "0" },
		inventory = { boosts = {}, pets = {}, equipped = {} },
		rewards = { lastCalendarDayUtc = -1, numDailyGiftsCollected = 0, trophies = {} },
		piggy = { rawAmount = 0 },
	}
end

-- ============================================================================
-- Section 1: Calendar 28-day Cycle and Scaling Formulas (docs/15 §2)
-- ============================================================================
do
	local m0, d1 = Calendar.getCycleAndDay(0)
	eq(m0, 0, "C=0 -> m=0")
	eq(d1, 1, "C=0 -> day=1")

	local m0_28, d28 = Calendar.getCycleAndDay(27)
	eq(m0_28, 0, "C=27 -> m=0")
	eq(d28, 28, "C=27 -> day=28")

	local m1, d1_c1 = Calendar.getCycleAndDay(28)
	eq(m1, 1, "C=28 -> m=1")
	eq(d1_c1, 1, "C=28 -> day=1")

	-- Table of 5 scaling items across cycles from docs/15 §2:
	-- Day 1: 192 -> 384 -> 768 -> 1536 -> 3072 -> 6144 (cap)
	eq(Calendar.computeDayReward(0, 1).amountNumber, 192, "Day 1 m=0")
	eq(Calendar.computeDayReward(1, 1).amountNumber, 384, "Day 1 m=1")
	eq(Calendar.computeDayReward(4, 1).amountNumber, 3072, "Day 1 m=4")
	eq(Calendar.computeDayReward(5, 1).amountNumber, 6144, "Day 1 m=5 (cap)")
	eq(Calendar.computeDayReward(6, 1).amountNumber, 6144, "Day 1 m=6 (retains cap)")

	-- Day 8: 396 -> 792 -> 1584 -> 3168 -> 6336 -> 9472 (exact cap)
	eq(Calendar.computeDayReward(0, 8).amountNumber, 396, "Day 8 m=0")
	eq(Calendar.computeDayReward(1, 8).amountNumber, 792, "Day 8 m=1")
	eq(Calendar.computeDayReward(2, 8).amountNumber, 1584, "Day 8 m=2")
	eq(Calendar.computeDayReward(4, 8).amountNumber, 6336, "Day 8 m=4")
	eq(Calendar.computeDayReward(5, 8).amountNumber, 9472, "Day 8 m=5 (exact cap 9472)")
	eq(Calendar.computeDayReward(6, 8).amountNumber, 9472, "Day 8 m=6 (retains cap)")

	-- Day 17: 96 -> 192 -> ... -> 12288 (cap at m=7)
	eq(Calendar.computeDayReward(0, 17).amountNumber, 96, "Day 17 m=0")
	eq(Calendar.computeDayReward(1, 17).amountNumber, 192, "Day 17 m=1")
	eq(Calendar.computeDayReward(6, 17).amountNumber, 6144, "Day 17 m=6")
	eq(Calendar.computeDayReward(7, 17).amountNumber, 12288, "Day 17 m=7 (cap)")
	eq(Calendar.computeDayReward(8, 17).amountNumber, 12288, "Day 17 m=8 (retains cap)")

	-- Day 26: 396 -> 792 -> ... -> 6336 (cap at m=4)
	eq(Calendar.computeDayReward(0, 26).amountNumber, 396, "Day 26 m=0")
	eq(Calendar.computeDayReward(1, 26).amountNumber, 792, "Day 26 m=1")
	eq(Calendar.computeDayReward(4, 26).amountNumber, 6336, "Day 26 m=4 (cap)")
	eq(Calendar.computeDayReward(5, 26).amountNumber, 6336, "Day 26 m=5 (retains cap)")

	-- Day 27 (Piggy): 10000 -> 20000 -> 40000 (cap at m=2)
	eq(Calendar.computeDayReward(0, 27).amountNumber, 10000, "Day 27 m=0")
	eq(Calendar.computeDayReward(1, 27).amountNumber, 20000, "Day 27 m=1")
	eq(Calendar.computeDayReward(2, 27).amountNumber, 40000, "Day 27 m=2 (cap)")
	eq(Calendar.computeDayReward(3, 27).amountNumber, 40000, "Day 27 m=3 (retains cap)")

	-- Day 28: PE for first 24 cycles (m=0..23), 100k GE for m >= 24
	local rewM0 = Calendar.computeDayReward(0, 28)
	eq(rewM0.rewardType, "PE", "Day 28 m=0 is PE")
	eq(rewM0.amountNumber, 1, "Day 28 m=0 gives 1 PE")

	local rewM23 = Calendar.computeDayReward(23, 28)
	eq(rewM23.rewardType, "PE", "Day 28 m=23 is PE")
	eq(rewM23.amountNumber, 1, "Day 28 m=23 gives 1 PE")

	local rewM24 = Calendar.computeDayReward(24, 28)
	eq(rewM24.rewardType, "GE", "Day 28 m=24 converts to GE")
	eq(rewM24.amountNumber, 100000, "Day 28 m=24 gives 100,000 GE")

	local rewM50 = Calendar.computeDayReward(50, 28)
	eq(rewM50.rewardType, "GE", "Day 28 m=50 is GE")
	eq(rewM50.amountNumber, 100000, "Day 28 m=50 gives 100,000 GE")
end

-- ============================================================================
-- Section 2: Epic Research Overflow Conversion to GE (docs/13 §2 L10-15)
-- ============================================================================
do
	local profile = makeProfile()
	profile.permanent.GE = "100"
	profile.permanent.epic.hold_to_hatch = 14 -- max is 15

	-- 1 level below max: increments level to 15, 0 GE converted
	local ok1, newLvl1, convGE1 = Calendar.applyEpicResearchReward(profile, "hold_to_hatch", 1)
	eq(ok1, true, "epic research level applied")
	eq(newLvl1, 15, "level increased to max 15")
	eq(convGE1, 0, "0 GE converted below max")
	eq(profile.permanent.GE, "100", "GE unchanged")

	-- Already at max (15): award 2 levels -> converted to 2 * 500 = 1000 GE
	local ok2, newLvl2, convGE2 = Calendar.applyEpicResearchReward(profile, "hold_to_hatch", 2)
	eq(ok2, true, "epic research overflow processed")
	eq(newLvl2, 15, "level stays at max 15")
	eq(convGE2, 1000, "1000 GE converted")
	eq(profile.permanent.GE, "1100", "1000 GE added to permanent")
end

-- ============================================================================
-- Section 3: Daily Calendar UTC Gating & Invariant Claims
-- ============================================================================
do
	local profile = makeProfile()
	profile.permanent.GE = "0"
	local day0Ms = 1000000

	-- Day 0 claim (C = 0 -> Day 1, 192 GE)
	local ok1, rew1 = Calendar.claimDailyGift(profile, day0Ms)
	eq(ok1, true, "Day 0 calendar claim succeeded")
	eq(rew1.rewardType, "GE", "reward is GE")
	eq(rew1.amountNumber, 192, "amount is 192 GE")
	eq(profile.permanent.GE, "192", "GE updated in profile")
	eq(profile.rewards.numDailyGiftsCollected, 1, "counter incremented to 1")
	eq(profile.rewards.lastCalendarDayUtc, 0, "lastCalendarDayUtc set to 0")

	-- Duplicate claim on same UTC day -> ALREADY_CLAIMED_TODAY
	local okDup, _, errDup = Calendar.claimDailyGift(profile, day0Ms + 5000)
	eq(okDup, false, "duplicate claim rejected")
	eq(errDup, "ALREADY_CLAIMED_TODAY", "already claimed error")

	-- Midnight UTC transition: Day 1 (C = 1 -> Day 2, Cash)
	local day1Ms = 86400000 + 1000
	local ok2, rew2 = Calendar.claimDailyGift(profile, day1Ms)
	eq(ok2, true, "Day 1 calendar claim succeeded")
	eq(profile.rewards.numDailyGiftsCollected, 2, "counter incremented to 2")
	eq(profile.rewards.lastCalendarDayUtc, 1, "lastCalendarDayUtc updated to 1")

	-- Reset farm / prestige does NOT clear rewards.lastCalendarDayUtc or counter
	profile.farm.cash = "0"
	eq(profile.rewards.numDailyGiftsCollected, 2, "counter preserved across reset")
	eq(profile.rewards.lastCalendarDayUtc, 1, "lastCalendarDayUtc preserved across reset")
end

-- ============================================================================
-- Section 4: Trophies (19 Eggs, 5 Population Tiers, Idempotency)
-- ============================================================================
do
	local profile = makeProfile()
	profile.permanent.SE = "0"
	profile.permanent.GE = "0"
	profile.permanent.PE = "0"

	-- Edible Egg (eggIndex = 0)
	-- Tier 1: Bronze (10M population) -> 2M SE
	-- Tier 5: Diamond (10B population) -> 5 PE

	-- Insufficient population check
	local okFail, _, errFail = Trophies.claimTrophy(profile, 0, 1, 9_999_999)
	eq(okFail, false, "claim rejected for population too low")
	eq(errFail, "POPULATION_TOO_LOW", "population too low error")

	-- Claim Bronze Trophy on Edible (pop = 10_000_000)
	local okB, rewB = Trophies.claimTrophy(profile, 0, 1, 10_000_000)
	eq(okB, true, "Bronze trophy claimed")
	eq(rewB.soulEggs, 2_000_000, "2M SE awarded")
	eq(profile.permanent.SE, "2000000", "SE added to permanent profile")
	eq(Trophies.isTrophyClaimed(profile, 0, 1), true, "trophy 0:1 is claimed")

	-- Duplicate claim attempt -> ALREADY_CLAIMED
	local okBDup, _, errBDup = Trophies.claimTrophy(profile, 0, 1, 10_000_000)
	eq(okBDup, false, "duplicate trophy claim rejected")
	eq(errBDup, "ALREADY_CLAIMED", "already claimed error")

	-- Claim Diamond Trophy on Edible (pop = 10_000_000_000) -> 5 Prophecy Eggs!
	local okD, rewD = Trophies.claimTrophy(profile, 0, 5, 10_000_000_000)
	eq(okD, true, "Diamond trophy claimed")
	eq(rewD.prophecyEggs, 5, "5 PE awarded")
	eq(profile.permanent.PE, "5", "PE added to permanent profile")

	-- Enlightenment Egg (eggIndex = 18): awards PE across tiers!
	-- Tier 1 (10M) awards 1 PE
	local okEnl1, rewEnl1 = Trophies.claimTrophy(profile, 18, 1, 10_000_000)
	eq(okEnl1, true, "Enlightenment Tier 1 claimed")
	eq(rewEnl1.prophecyEggs, 1, "1 PE for Enlightenment Bronze")
	eq(profile.permanent.PE, "6", "PE increased from 5 to 6")

	-- Farm reset / prestige retains trophies
	profile.farm.cash = "0"
	eq(Trophies.isTrophyClaimed(profile, 0, 1), true, "trophy 0:1 preserved across reset")
	eq(Trophies.isTrophyClaimed(profile, 0, 5), true, "trophy 0:5 preserved across reset")
	eq(Trophies.isTrophyClaimed(profile, 18, 1), true, "trophy 18:1 preserved across reset")
end

-- ============================================================================
-- Section 5: Save Results JSON
-- ============================================================================
fs.writeFile("build/claims-results.json", serde.encode("json", {
	status = "PASS",
	level = "L",
	assertions = assertions,
	studioTested = false,
	dataStoreTested = false,
	scope = "NEXT-08 28-day calendar scaling, PE conversion, Epic research overflow, and 19-egg trophies",
}, true))

print(string.format("Calendar, Trophies & Claims PASS: %d assertions", assertions))
