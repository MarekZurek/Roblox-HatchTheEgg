--!nocheck
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local Codec = require("../../src/shared/NumericCodec")
local Drones = require("../../src/server/rewards/drones")

local BigAmount = Codec.BigAmount
local ExactUInt = Codec.ExactUInt

local assertions = 0
local function eq(a, b, label)
	assertions += 1
	assert(a == b, (if label then label .. ": " else "") .. tostring(a) .. " != " .. tostring(b))
end

local function near(a, b, maxAbsErr, label)
	assertions += 1
	local err = math.abs(a - b)
	local limit = maxAbsErr or math.max(math.abs(b) * 1e-12, 1e-12)
	assert(err <= limit, (if label then label .. ": " else "") .. tostring(a) .. " !~= " .. tostring(b) .. " (err=" .. tostring(err) .. ", limit=" .. tostring(limit) .. ")")
end

local function ok(cond, label)
	assertions += 1
	assert(cond, label or "condition failed")
end

local function makeProfile(totalGESpent, currentGE, currentCash, maxEggReached, prestigeCount, population)
	local habitats = {}
	for i = 1, 4 do
		habitats[i] = {
			typeIndex = if i == 1 then 0 else -1,
			population = if i == 1 then tostring(population or 250) else "0",
			assignedInTransit = "0",
			fractionalIHR = "0",
		}
	end
	return {
		meta = { revision = "0", playerId = "1" },
		ownership = { generation = "0", ownerToken = "tok", endsAtMs = 0 },
		farm = {
			eggIndex = 0,
			maxEggReached = maxEggReached or 0,
			cash = currentCash or "0",
			habitats = habitats,
		},
		accounting = {
			prestigeSessionArchivedCash = "0",
			prestigeExtraEarnings = "0",
			lastBaseEarnings = "0",
			currentFarmCash = "0",
			lastCashEarned = "0",
		},
		permanent = {
			GE = currentGE or "10",
			totalGESpent = totalGESpent or "0",
			SE = "0",
			PE = "0",
			epic = { drone_rewards = 0 },
			prestigeCount = prestigeCount or "0",
		},
	}
end

-- ============================================================================
-- Section 1: Drone Spawn Creation & Elite Probability Progression
-- ============================================================================
do
	-- Beginner curve: prestigeCount == "0" and maxEggReached <= 4 -> pBase = 0.005 * maxEggReached
	local profEgg0 = makeProfile("0", "10", "0", 0, "0")
	eq(Drones.calculateEliteChance(profEgg0, 1.0), 0.0, "egg 0 gives 0.0 elite chance")

	local profEgg1 = makeProfile("0", "10", "0", 1, "0")
	near(Drones.calculateEliteChance(profEgg1, 1.0), 0.005, 1e-12, "egg 1 beginner gives 0.5% elite chance")

	local profEgg4 = makeProfile("0", "10", "0", 4, "0")
	near(Drones.calculateEliteChance(profEgg4, 1.0), 0.020, 1e-12, "egg 4 beginner gives 2.0% elite chance")

	-- Beyond beginner: maxEggReached > 4 or prestigeCount > 0 -> standard pBase = 0.08 (8%)
	local profEgg5 = makeProfile("0", "10", "0", 5, "0")
	near(Drones.calculateEliteChance(profEgg5, 1.0), 0.080, 1e-12, "egg 5 beginner gives standard 8% elite chance")

	local profPrestige = makeProfile("0", "10", "0", 1, "1")
	near(Drones.calculateEliteChance(profPrestige, 1.0), 0.080, 1e-12, "prestigeCount > 0 gives standard 8% elite chance")

	-- Drone Hawk pet multiplier scaling
	-- 2 Hawks 5x: mult = 9 -> 0.08 * 9 = 0.72 (72%)
	near(Drones.calculateEliteChance(profPrestige, 9.0), 0.72, 1e-12, "2 Hawks 5x give 72% elite chance (doc 16 §1)")

	-- 3 Hawks 5x: mult = 13 -> 0.08 * 13 = 1.04 -> saturated 100%
	near(Drones.calculateEliteChance(profPrestige, 13.0), 1.0, 1e-12, "3 Hawks 5x saturate at 100% elite chance")

	-- pBase <= 0 gives 0
	near(Drones.calculateEliteChance(profEgg0, 13.0), 0.0, 1e-12, "pBase 0 with pet multiplier remains 0.0")

	-- createDroneSpawn lifecycle fields
	local nowMs = 100000
	local spawnElite = Drones.createDroneSpawn("drone_1", nowMs, { flightDurationMs = 15000 }, profPrestige, 1.0, 0.05)
	eq(spawnElite.spawnId, "drone_1", "spawnId matches")
	eq(spawnElite.createdAtMs, nowMs, "createdAtMs matches")
	eq(spawnElite.expiresAtMs, nowMs + 15000, "expiresAtMs matches")
	eq(spawnElite.isElite, true, "roll 0.05 < 0.08 is elite")
	eq(spawnElite.claimed, false, "spawn starts unclaimed")
	eq(spawnElite.reward, nil, "spawn starts with nil reward")

	local spawnReg = Drones.createDroneSpawn("drone_2", nowMs, { flightDurationMs = 12000 }, profPrestige, 1.0, 0.09)
	eq(spawnReg.expiresAtMs, nowMs + 12000, "expiresAtMs matches custom duration")
	eq(spawnReg.isElite, false, "roll 0.09 >= 0.08 is regular")
end

-- ============================================================================
-- Section 2: Hit Qualification, Expiry, and Single-Claim Protection
-- ============================================================================
do
	local prof = makeProfile("0", "10", "0", 5, "1", 200)
	local nowMs = 1000
	local spawn = Drones.createDroneSpawn("d_test", nowMs, { flightDurationMs = 15000, droneGoldGuaranteed = true }, prof, 1.0, 0.5)

	-- Hit within window (e.g. at nowMs + 5000): success
	local ok1, rew1 = Drones.claimDrone(spawn, nowMs + 5000, prof, { droneGoldGuaranteed = true }, { u2 = 0.5 }, 1000, 1000)
	ok(ok1, "hit within flight window accepted")
	eq(spawn.claimed, true, "spawn marked as claimed")
	ok(rew1 ~= nil, "reward returned")

	-- Second hit on same spawn: rejected with ALREADY_CLAIMED
	local geBefore = prof.permanent.GE
	local okDup, errDup = Drones.claimDrone(spawn, nowMs + 6000, prof, { droneGoldGuaranteed = true }, { u2 = 0.5 }, 1000, 1000)
	ok(not okDup, "duplicate hit rejected")
	eq(errDup, "ALREADY_CLAIMED", "duplicate hit error matches")
	eq(prof.permanent.GE, geBefore, "GE balance unchanged on duplicate claim rejection")

	-- Hit after expiry: rejected with SPAWN_EXPIRED
	local spawnLate = Drones.createDroneSpawn("d_late", nowMs, { flightDurationMs = 10000, droneGoldGuaranteed = true }, prof, 1.0, 0.5)
	local okExp, errExp = Drones.claimDrone(spawnLate, nowMs + 10001, prof, { droneGoldGuaranteed = true }, { u2 = 0.5 }, 1000, 1000)
	ok(not okExp, "hit after expiry rejected")
	eq(errExp, "SPAWN_EXPIRED", "expired error matches")
	eq(spawnLate.claimed, false, "unclaimed late spawn remains unclaimed")

	-- Hit at exact boundary (nowMs == expiresAtMs): accepted
	local spawnBoundary = Drones.createDroneSpawn("d_bound", nowMs, { flightDurationMs = 10000, droneGoldGuaranteed = true }, prof, 1.0, 0.5)
	local okBound, rewBound = Drones.claimDrone(spawnBoundary, nowMs + 10000, prof, { droneGoldGuaranteed = true }, { u2 = 0.5 }, 1000, 1000)
	ok(okBound, "hit at exact boundary accepted")
	eq(spawnBoundary.claimed, true, "boundary spawn claimed")
end

-- ============================================================================
-- Section 3: Golden Egg Reward Distributions & Scaling
-- ============================================================================
do
	-- Reference base GE distribution (docs/06 §3):
	-- q = 1 (lvl 0):
	-- u2 < 0.1 -> 12 GE
	-- u2 < 0.7 -> 6 GE
	-- else -> 3 GE
	local prof = makeProfile("0", "10", "0", 5, "1", 200)

	-- Regular drone, q = 1
	local s3 = Drones.createDroneSpawn("s3", 0, { droneGoldGuaranteed = true }, prof, 1.0, 0.99)
	local _, r3 = Drones.claimDrone(s3, 100, prof, { droneGoldGuaranteed = true }, { u2 = 0.8 }, 1000, 1000)
	eq(r3.type, "GE", "reward is GE")
	eq(r3.amount, 3, "regular base 3 GE")

	local s6 = Drones.createDroneSpawn("s6", 0, { droneGoldGuaranteed = true }, prof, 1.0, 0.99)
	local _, r6 = Drones.claimDrone(s6, 100, prof, { droneGoldGuaranteed = true }, { u2 = 0.5 }, 1000, 1000)
	eq(r6.amount, 6, "regular base 6 GE")

	local s12 = Drones.createDroneSpawn("s12", 0, { droneGoldGuaranteed = true }, prof, 1.0, 0.99)
	local _, r12 = Drones.claimDrone(s12, 100, prof, { droneGoldGuaranteed = true }, { u2 = 0.05 }, 1000, 1000)
	eq(r12.amount, 12, "regular base 12 GE")

	-- q > 1.5 and u2 < 0.01 -> 24 GE
	local s24 = Drones.createDroneSpawn("s24", 0, { droneGoldGuaranteed = true, epicDroneRewardsLvl = 10 }, prof, 1.0, 0.99)
	local _, r24 = Drones.claimDrone(s24, 100, prof, { droneGoldGuaranteed = true, epicDroneRewardsLvl = 10 }, { u2 = 0.005 }, 1000, 1000)
	eq(r24.amount, 24, "regular base 24 GE (q > 1.5, u2 < 0.01)")

	-- Elite drone: max(48, 8 * baseGE) -> 48, 48, 96, 192
	local se3 = Drones.createDroneSpawn("se3", 0, { droneGoldGuaranteed = true }, prof, 1.0, 0.01) -- elite
	local _, re3 = Drones.claimDrone(se3, 100, prof, { droneGoldGuaranteed = true }, { u2 = 0.8 }, 1000, 1000)
	eq(re3.amount, 48, "elite base 3 -> max(48, 24) = 48 GE")

	local se6 = Drones.createDroneSpawn("se6", 0, { droneGoldGuaranteed = true }, prof, 1.0, 0.01)
	local _, re6 = Drones.claimDrone(se6, 100, prof, { droneGoldGuaranteed = true }, { u2 = 0.5 }, 1000, 1000)
	eq(re6.amount, 48, "elite base 6 -> max(48, 48) = 48 GE")

	local se12 = Drones.createDroneSpawn("se12", 0, { droneGoldGuaranteed = true }, prof, 1.0, 0.01)
	local _, re12 = Drones.claimDrone(se12, 100, prof, { droneGoldGuaranteed = true }, { u2 = 0.05 }, 1000, 1000)
	eq(re12.amount, 96, "elite base 12 -> max(48, 96) = 96 GE")

	local se24 = Drones.createDroneSpawn("se24", 0, { droneGoldGuaranteed = true, epicDroneRewardsLvl = 10 }, prof, 1.0, 0.01)
	local _, re24 = Drones.claimDrone(se24, 100, prof, { droneGoldGuaranteed = true, epicDroneRewardsLvl = 10 }, { u2 = 0.005 }, 1000, 1000)
	eq(re24.amount, 192, "elite base 24 -> max(48, 192) = 192 GE")

	-- Total GE spent threshold >= 152,500
	-- Regular: max(24, 2 * baseGE)
	-- Elite: 2 * max(48, 8 * baseGE)
	local profWhale = makeProfile("152500", "10", "0", 5, "1", 200)

	local sw3 = Drones.createDroneSpawn("sw3", 0, { droneGoldGuaranteed = true }, profWhale, 1.0, 0.99)
	local _, rw3 = Drones.claimDrone(sw3, 100, profWhale, { droneGoldGuaranteed = true }, { u2 = 0.8 }, 1000, 1000)
	eq(rw3.amount, 24, "whale regular base 3 -> max(24, 6) = 24 GE (doc 06 §3)")

	local sw24 = Drones.createDroneSpawn("sw24", 0, { droneGoldGuaranteed = true, epicDroneRewardsLvl = 10 }, profWhale, 1.0, 0.99)
	local _, rw24 = Drones.claimDrone(sw24, 100, profWhale, { droneGoldGuaranteed = true, epicDroneRewardsLvl = 10 }, { u2 = 0.005 }, 1000, 1000)
	eq(rw24.amount, 48, "whale regular base 24 -> max(24, 48) = 48 GE")

	local swe12 = Drones.createDroneSpawn("swe12", 0, { droneGoldGuaranteed = true }, profWhale, 1.0, 0.01)
	local _, rwe12 = Drones.claimDrone(swe12, 100, profWhale, { droneGoldGuaranteed = true }, { u2 = 0.05 }, 1000, 1000)
	eq(rwe12.amount, 192, "whale elite base 12 -> 2 * 96 = 192 GE")

	local swe24 = Drones.createDroneSpawn("swe24", 0, { droneGoldGuaranteed = true, epicDroneRewardsLvl = 10 }, profWhale, 1.0, 0.01)
	local _, rwe24 = Drones.claimDrone(swe24, 100, profWhale, { droneGoldGuaranteed = true, epicDroneRewardsLvl = 10 }, { u2 = 0.005 }, 1000, 1000)
	eq(rwe24.amount, 384, "whale elite base 24 -> 2 * 192 = 384 GE")
end

-- ============================================================================
-- Section 4: Struggle Modifier Bands and Small Population Exception
-- ============================================================================
do
	-- Exact float32(0.1) in binary64: 0.10000000149011612
	local smallPopRef = 0.10000000149011612

	-- Population <= 100 gives strictly smallPopRef regardless of ratio
	eq(Drones.calculateStruggleModifier(1000, 0, 1000), smallPopRef, "pop 0 gives exact smallPopRef")
	eq(Drones.calculateStruggleModifier(1000, 50, 1000), smallPopRef, "pop 50 gives exact smallPopRef")
	eq(Drones.calculateStruggleModifier(1000, 100, 1000), smallPopRef, "pop 100 gives exact smallPopRef")
	eq(Drones.calculateStruggleModifier(1e9, 100, 1), smallPopRef, "huge ratio with pop 100 still gives exact smallPopRef")

	-- Population > 100: evaluated by ratio = 100 * farmValue / curve0FarmValue
	local pop = 101

	-- 1. ratio < 3 -> 30
	eq(Drones.calculateStruggleModifier(2.9, pop, 100), 30.0, "ratio 2.9 -> 30")
	eq(Drones.calculateStruggleModifier(0.0, pop, 100), 30.0, "ratio 0.0 -> 30")

	-- 2. [3, 15) -> 15
	eq(Drones.calculateStruggleModifier(3.0, pop, 100), 15.0, "ratio 3.0 -> 15")
	eq(Drones.calculateStruggleModifier(14.99, pop, 100), 15.0, "ratio 14.99 -> 15")

	-- 3. [15, 30) -> 8
	eq(Drones.calculateStruggleModifier(15.0, pop, 100), 8.0, "ratio 15.0 -> 8")
	eq(Drones.calculateStruggleModifier(29.99, pop, 100), 8.0, "ratio 29.99 -> 8")

	-- 4. [30, 100) -> 5
	eq(Drones.calculateStruggleModifier(30.0, pop, 100), 5.0, "ratio 30.0 -> 5")
	eq(Drones.calculateStruggleModifier(99.99, pop, 100), 5.0, "ratio 99.99 -> 5")

	-- 5. [100, 200) -> 2
	eq(Drones.calculateStruggleModifier(100.0, pop, 100), 2.0, "ratio 100.0 -> 2")
	eq(Drones.calculateStruggleModifier(199.99, pop, 100), 2.0, "ratio 199.99 -> 2")

	-- 6. [200, 1000) -> 1
	eq(Drones.calculateStruggleModifier(200.0, pop, 100), 1.0, "ratio 200.0 -> 1")
	eq(Drones.calculateStruggleModifier(999.99, pop, 100), 1.0, "ratio 999.99 -> 1")

	-- 7. [1000, 50000) -> 0.75
	eq(Drones.calculateStruggleModifier(1000.0, pop, 100), 0.75, "ratio 1000.0 -> 0.75")
	eq(Drones.calculateStruggleModifier(49999.99, pop, 100), 0.75, "ratio 49999.99 -> 0.75")

	-- 8. [50000, 1000000) -> 0.5
	eq(Drones.calculateStruggleModifier(50000.0, pop, 100), 0.5, "ratio 50000.0 -> 0.5")
	eq(Drones.calculateStruggleModifier(999999.99, pop, 100), 0.5, "ratio 999999.99 -> 0.5")

	-- 9. >= 1000000 -> 0.25
	eq(Drones.calculateStruggleModifier(1000000.0, pop, 100), 0.25, "ratio 1000000.0 -> 0.25")
	eq(Drones.calculateStruggleModifier(5000000.0, pop, 100), 0.25, "ratio 5000000.0 -> 0.25")
end

-- ============================================================================
-- Section 5: Cash Reward Calculation & Elite Cash Formula
-- ============================================================================
do
	local prof = makeProfile("0", "10", "100", 5, "1", 200)
	local fv = 50000.0
	local curve0Val = 10000.0 -- ratio = 100 * 50000 / 10000 = 500 -> struggleModifier = 1.0

	-- Regular cash with b = 0.5 (u2 < 0.03 * 1.0)
	-- regularCash = FV * (0.5 / 50) * 1.0 = 50000 * 0.01 * 1.0 = 500
	local sCashBig = Drones.createDroneSpawn("sc_big", 0, { droneCashGuaranteed = true }, prof, 1.0, 0.99)
	local _, rcBig = Drones.claimDrone(sCashBig, 100, prof, { droneCashGuaranteed = true }, { u2 = 0.01 }, fv, curve0Val)
	eq(rcBig.type, "Cash", "reward is Cash")
	near(rcBig.amount, 500.0, 1e-12, "regular cash b=0.5 matches 500")

	-- Regular cash with b = 0.1 (u2 < 0.10 * 1.0)
	-- regularCash = FV * (0.1 / 50) * 1.0 = 50000 * 0.002 = 100
	local sCashMed = Drones.createDroneSpawn("sc_med", 0, { droneCashGuaranteed = true }, prof, 1.0, 0.99)
	local _, rcMed = Drones.claimDrone(sCashMed, 100, prof, { droneCashGuaranteed = true }, { u2 = 0.05 }, fv, curve0Val)
	near(rcMed.amount, 100.0, 1e-12, "regular cash b=0.1 matches 100")

	-- Regular cash with b = 0.02 (u2 >= 0.10)
	-- regularCash = FV * (0.02 / 50) * 1.0 = 50000 * 0.0004 = 20
	local sCashSmall = Drones.createDroneSpawn("sc_small", 0, { droneCashGuaranteed = true }, prof, 1.0, 0.99)
	local _, rcSmall = Drones.claimDrone(sCashSmall, 100, prof, { droneCashGuaranteed = true }, { u2 = 0.50 }, fv, curve0Val)
	near(rcSmall.amount, 20.0, 1e-12, "regular cash b=0.02 matches 20")

	-- Elite cash formula: FV * (10 / 50) * min(struggle, 10) * droneRewardMult * sqrt(chickenMult)
	-- Overwrites b: independent of u2!
	-- Here struggle = 1.0 -> min(1.0, 10) = 1.0
	-- eliteCash = 50000 * (10 / 50) * 1.0 = 50000 * 0.2 = 10000
	local sEliteCash1 = Drones.createDroneSpawn("se_c1", 0, { droneCashGuaranteed = true }, prof, 1.0, 0.01)
	local _, rEc1 = Drones.claimDrone(sEliteCash1, 100, prof, { droneCashGuaranteed = true }, { u2 = 0.01 }, fv, curve0Val)
	near(rEc1.amount, 10000.0, 1e-12, "elite cash independent of u2 (u2=0.01) matches 10000")

	local sEliteCash2 = Drones.createDroneSpawn("se_c2", 0, { droneCashGuaranteed = true }, prof, 1.0, 0.01)
	local _, rEc2 = Drones.claimDrone(sEliteCash2, 100, prof, { droneCashGuaranteed = true }, { u2 = 0.99 }, fv, curve0Val)
	near(rEc2.amount, 10000.0, 1e-12, "elite cash independent of u2 (u2=0.99) matches 10000")

	-- Elite cash with struggle = 30 -> capped at min(30, 10) = 10!
	-- ratio < 3 (fv = 100, curve0 = 10000 -> ratio = 1 -> struggle = 30)
	-- eliteCash = 100 * (10 / 50) * 10 = 100 * 0.2 * 10 = 200
	local sEliteStruggle = Drones.createDroneSpawn("se_str", 0, { droneCashGuaranteed = true }, prof, 1.0, 0.01)
	local _, rEcStr = Drones.claimDrone(sEliteStruggle, 100, prof, { droneCashGuaranteed = true }, { u2 = 0.5 }, 100.0, 10000.0)
	near(rEcStr.amount, 200.0, 1e-12, "elite cash caps struggle at 10 (30 -> 10)")
end

-- ============================================================================
-- Section 6: Profile State Mutation & Accounting Integration
-- ============================================================================
do
	local prof = makeProfile("0", "50", "1000", 5, "1", 200)

	-- 1. GE claim updates profile.permanent.GE
	local sGE = Drones.createDroneSpawn("s_ge", 0, { droneGoldGuaranteed = true }, prof, 1.0, 0.99)
	Drones.claimDrone(sGE, 100, prof, { droneGoldGuaranteed = true }, { u2 = 0.8 }, 1000, 1000) -- awards 3 GE
	eq(prof.permanent.GE, "53", "profile.permanent.GE incremented from 50 to 53")

	-- 2. Cash claim updates profile.farm.cash and profile.accounting.lastCashEarned
	local sCash = Drones.createDroneSpawn("s_cash", 0, { droneCashGuaranteed = true }, prof, 1.0, 0.99)
	-- fv = 10000, curve0 = 2000 -> ratio = 500 -> struggle = 1.0; b = 0.1 -> 10000 * 0.002 * 1.0 = 20
	Drones.claimDrone(sCash, 100, prof, { droneCashGuaranteed = true }, { u2 = 0.05 }, 10000.0, 2000.0)
	eq(prof.farm.cash, "1020", "profile.farm.cash incremented from 1000 to 1020")
	eq(prof.accounting.lastCashEarned, "20", "profile.accounting.lastCashEarned incremented by 20")
end

-- ============================================================================
-- Section 7: Server Authoritative HitDrone & ClaimOffer Coordinator Integration (PROD-06)
-- ============================================================================
do
	local ServerBootstrap = require("../../src/server/Bootstrap")
	local server = ServerBootstrap.new({ initialNowMs = 2000000 })
	local joinRes, err = server:playerJoined("999")
	ok(joinRes ~= nil, "Player 999 joined server")

	-- 1. Server Authoritative HitDrone with Cash reward
	local okHit1, reward1 = server:hitDrone("999", "drone_srv_1", {
		config = { droneCashGuaranteed = true },
		rolls = { u2 = 0.5 },
		farmValue = 10000.0,
		curve0FarmValue = 2000.0,
	})
	eq(okHit1, true, "hitDrone succeeded")
	ok(reward1 ~= nil, "reward returned")
	eq(reward1.type, "Cash", "reward type is Cash")
	near(reward1.amount, 0.4000000059604645, 1e-12, "cash amount matches formula with small population exception")

	-- 2. Idempotency / Duplicate hit rejection on server
	local okHitDup, errDup = server:hitDrone("999", "drone_srv_1")
	eq(okHitDup, false, "Duplicate hit on same droneId rejected")
	eq(errDup, "ALREADY_CLAIMED", "Error code is ALREADY_CLAIMED")

	-- 3. HitDrone with Golden Egg reward
	local okHit2, reward2 = server:hitDrone("999", "drone_srv_2", {
		config = { droneGoldGuaranteed = true },
		rolls = { u2 = 0.8 },
	})
	eq(okHit2, true, "hitDrone with GE succeeded")
	eq(reward2.type, "GE", "reward type is GE")
	eq(reward2.amount, 3, "reward amount is 3 GE")

	-- 4. Server Authoritative ClaimOffer (2+1 delivery parcel)
	local okClaim1, resClaim1 = server:claimOffer("999", "offer_parcel_1", {
		reward = { rewardType = "Cash", amount = "50000", amountNumber = 50000 },
	})
	eq(okClaim1, true, "claimOffer succeeded")
	ok(resClaim1 ~= nil, "claimOffer result returned")
	eq(resClaim1.rewardType, "Cash", "reward type is Cash")
	eq(resClaim1.amount, "50000", "reward amount is 50000")

	-- 5. Duplicate ClaimOffer rejection
	local okClaimDup, resClaimDup = server:claimOffer("999", "offer_parcel_1")
	eq(okClaimDup, false, "Duplicate claim on same offerId rejected")

	-- 6. Verify profile balance persisted & checkpointer flushed
	local coordinator = server:getCoordinator("999")
	local snaps = coordinator.snapshots()
	local prof = snaps.working or snaps.durable
	eq(prof.permanent.GE, "13", "Profile GE updated to 13 (10 + 3)")
	near(BigAmount.decode(prof.farm.cash), 50000.4, 1e-4, "Profile Cash updated to ~50000.4")
end

-- ============================================================================
-- Section 8: Save Results and Report
-- ============================================================================
fs.writeFile("build/drones-results.json", serde.encode("json", {
	status = "PASS",
	level = "L",
	assertions = assertions,
	studioTested = false,
	dataStoreTested = false,
	scope = "NEXT-06 & PROD-06 Authoritative drone spawning, hit qualification, GE/Cash rewards, and server coordinator integration",
}, true))

print(string.format("Drones PASS: %d assertions", assertions))
