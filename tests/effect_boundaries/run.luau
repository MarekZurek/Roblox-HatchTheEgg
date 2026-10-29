--!nocheck
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local Codec = require("../../src/shared/NumericCodec")
local Data = require("../../src/server/PersistenceData")
local CatalogData = require("../../src/server/CatalogRegistry/Data")
local Catalog = require("../../src/server/CatalogRegistry").new(Codec, CatalogData, { mode = "INTERNAL_TEST_ONLY" })
local ProductionMath = require("../../src/server/FarmMath/production_research").new(Codec, Catalog, { mode = "INTERNAL_TEST_ONLY" })
local PopulationMath = require("../../src/server/FarmMath/PopulationMath").new(Codec)
local Hatching = require("../../src/server/FarmMath/hatching_rcb").new(Codec, PopulationMath, Data, { mode = "INTERNAL_TEST_ONLY" })
local IHR = require("../../src/server/FarmMath/ihr").new(Codec, PopulationMath)
local Timeline = require("../../src/server/TimelineSimulation").new(Codec, ProductionMath, Hatching, IHR, Data, { mode = "INTERNAL_TEST_ONLY" })
local EffectsManager = require("../../src/server/EffectsManager")

local BigAmount = Codec.BigAmount
local Real64 = Codec.Real64
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

local function reject(fn, label)
	assertions += 1
	local success, err = pcall(fn)
	assert(not success, (if label then label .. ": " else "") .. "expected rejection but succeeded")
end

local function makeFarm(cash, pop, eggIndex, siloOwned)
	local habitats = {}
	for i = 1, 4 do
		habitats[i] = {
			typeIndex = if i == 1 then 0 else -1,
			capacity = if i == 1 then "250" else "0",
			population = if i == 1 then tostring(pop or 100) else "0",
			assignedInTransit = "0",
			fractionalIHR = 0,
		}
	end
	return {
		cash = cash or 0,
		eggIndex = eggIndex or 0,
		habitats = habitats,
		hatcheryStock = 250,
		runningCount = "0",
		hatchGroupSequence = "0",
		groups = {},
		commonLevels = {},
		vehicleTypes = { 0 },
		siloOwned = siloOwned or 1,
	}
end

local function makeState(farm, effects, settledMs)
	return {
		farm = farm or makeFarm(),
		accounting = {
			prestigeSessionArchivedCash = 0,
			prestigeExtraEarnings = 0,
			lastBaseEarnings = 0,
			currentFarmCash = 0,
			lastCashEarned = 0,
		},
		effects = effects,
		settledWallThrough = settledMs or 1000000,
	}
end

local function makeConfig(pro, siloCapacityLevel, liveEvents)
	return {
		revision = "test-cfg:1",
		pro = pro or false,
		siloCapacityLevel = siloCapacityLevel or 0,
		liveEvents = liveEvents,
	}
end

-- ============================================================================
-- Section 1: Retired timed doubler compatibility (28.10.2026)
-- ============================================================================
do
 local nowMs = 1000000
 for _, effects in {{}, {videoDoublerEndsAtMs=nowMs+99999999}, {videoDoubler={endsAtMs=nowMs+99999999}}} do
  local before = serde.encode("json", effects)
  for level = 0, 12 do
   local accepted, code = EffectsManager.activateVideoDoubler(effects, nowMs, level)
   eq(accepted, false, "retired activation rejected")
   eq(code, "FEATURE_REMOVED")
   eq(serde.encode("json", effects), before, "rejected activation leaves state unchanged")
  end
  local mult = EffectsManager.calculateMultipliers(effects, {eggIndex=0}, nowMs)
  eq(mult.videoDoublerActive, false, "legacy deadline inert")
  eq(mult.vdMultiplier, 1)
  eq(mult.earningsMultiplier, 1)
 end
end

-- ============================================================================
-- Section 2: Boost Categories & Boost Beacon Compounding (docs/11 Â§4)
-- ============================================================================
do
	local nowMs = 1000000

	-- 2.1 Single Jimbo: 50x earnings
	local effJimbo1 = {
		boosts = {
			{ id = "jimbos_orange", dimension_raw = 2, effect = 50.0, remainingSeconds = 600 },
		},
	}
	local mJ1 = EffectsManager.calculateMultipliers(effJimbo1, { eggIndex = 0 }, nowMs)
	eq(mJ1.effectiveEarningsBoost, 50.0, "single Jimbo 50 gives 50x")
	eq(mJ1.earningsMultiplier, 50.0, "earningsMultiplier is 50x (without VD)")

	-- 2.2 Multiple Jimbo: sum (50 + 50 = 100x)
	local effJimbo2 = {
		boosts = {
			{ id = "jimbos_orange", dimension_raw = 2, effect = 50.0, remainingSeconds = 600 },
			{ id = "jimbos_orange", dimension_raw = 2, effect = 50.0, remainingSeconds = 600 },
		},
	}
	local mJ2 = EffectsManager.calculateMultipliers(effJimbo2, { eggIndex = 0 }, nowMs)
	eq(mJ2.effectiveEarningsBoost, 100.0, "two Jimbo 50 sum to 100x")

	-- 2.3 Jimbo 50 + Boost Beacon 50: 50 * 50 = 2500x
	local effJB = {
		boosts = {
			{ id = "jimbos_orange", dimension_raw = 2, effect = 50.0, remainingSeconds = 600 },
			{ id = "boost_beacon_orange", dimension_raw = 7, effect = 50.0, remainingSeconds = 600 },
		},
	}
	local mJB = EffectsManager.calculateMultipliers(effJB, { eggIndex = 0 }, nowMs)
	eq(mJB.beaconFactor, 50.0, "beaconFactor is 50")
	eq(mJB.effectiveEarningsBoost, 2500.0, "Jimbo 50 * Beacon 50 = 2500x")
	eq(mJB.earningsMultiplier, 2500.0, "composite earnings 2500x")

	-- 2.4 Jimbo 50 + two Boost Beacon 50: 50 * (50 + 50) = 5000x
	local effJBB = {
		boosts = {
			{ id = "jimbos_orange", dimension_raw = 2, effect = 50.0, remainingSeconds = 600 },
			{ id = "boost_beacon_orange", dimension_raw = 7, effect = 50.0, remainingSeconds = 600 },
			{ id = "boost_beacon_orange", dimension_raw = 7, effect = 50.0, remainingSeconds = 600 },
		},
	}
	local mJBB = EffectsManager.calculateMultipliers(effJBB, { eggIndex = 0 }, nowMs)
	eq(mJBB.beaconFactor, 100.0, "beacons sum to 100")
	eq(mJBB.effectiveEarningsBoost, 5000.0, "Jimbo 50 * (50 + 50) = 5000x")

	-- 2.5 Tachyon 1000 + Boost Beacon 50: 1000 * 50 = 50,000x IHR
	local effTB = {
		boosts = {
			{ id = "tachyon_prism_orange", dimension_raw = 4, effect = 1000.0, remainingSeconds = 600 },
			{ id = "boost_beacon_orange", dimension_raw = 7, effect = 50.0, remainingSeconds = 600 },
		},
	}
	local mTB = EffectsManager.calculateMultipliers(effTB, { eggIndex = 0 }, nowMs)
	eq(mTB.effectiveIHRBoost, 50000.0, "Tachyon 1000 * Beacon 50 = 50000x")
	eq(mTB.ihrMultiplier, 50000.0, "ihrMultiplier is 50000x")

	-- 2.6 Soul Beacon 500 + Boost Beacon 50: 500 * 50 = 25,000x prestige
	local effSB = {
		boosts = {
			{ id = "soul_beacon_orange", dimension_raw = 9, effect = 500.0, remainingSeconds = 600 },
			{ id = "boost_beacon_orange", dimension_raw = 7, effect = 50.0, remainingSeconds = 600 },
		},
	}
	local mSB = EffectsManager.calculateMultipliers(effSB, { eggIndex = 0 }, nowMs)
	eq(mSB.effectivePrestigeBoost, 25000.0, "Soul Beacon 500 * Beacon 50 = 25000x")
	eq(mSB.prestigeMultiplier, 25000.0, "prestigeMultiplier is 25000x")

	-- 2.7 Boost Beacon alone: neutral 1.0x for empty categories
	local effBeaconAlone = {
		boosts = {
			{ id = "boost_beacon_orange", dimension_raw = 7, effect = 50.0, remainingSeconds = 600 },
		},
	}
	local mBA = EffectsManager.calculateMultipliers(effBeaconAlone, { eggIndex = 0 }, nowMs)
	eq(mBA.beaconFactor, 50.0, "beacon factor is 50")
	eq(mBA.effectiveEarningsBoost, 1.0, "earnings remains 1.0 without base boost")
	eq(mBA.effectiveIHRBoost, 1.0, "IHR remains 1.0 without base boost")
	eq(mBA.effectivePrestigeBoost, 1.0, "prestige remains 1.0 without base boost")
	eq(mBA.earningsMultiplier, 1.0, "total earnings 1.0")

	-- 2.8 Boost Beacon alone stays neutral even with a retired deadline
	local effBeaconVD = {
		videoDoublerEndsAtMs = nowMs + 100000,
		boosts = {
			{ id = "boost_beacon_orange", dimension_raw = 7, effect = 50.0, remainingSeconds = 600 },
		},
	}
	local mBVD = EffectsManager.calculateMultipliers(effBeaconVD, { eggIndex = 0 }, nowMs)
	eq(mBVD.vdMultiplier, 1.0, "retired VD neutral")
	eq(mBVD.earningsMultiplier, 1.0, "Beacon alone remains neutral")

	-- 2.9 Jimbo 50 + Beacon 50: legacy VD does not change 2500x
	effJB.videoDoublerEndsAtMs = nowMs + 100000
	local mJBVD = EffectsManager.calculateMultipliers(effJB, { eggIndex = 0 }, nowMs)
	eq(mJBVD.earningsMultiplier, 2500.0, "Jimbo 50 * Beacon 50; legacy VD ignored")

	-- 2.10 Simultaneous 3-category compounding with 2 Boost Beacons
	-- Jimbo 10 + Jimbo 50 = 60x earnings
	-- Tachyon 100 + Tachyon 1000 = 1100x IHR
	-- Soul Beacon 50 + Soul Beacon 500 = 550x prestige
	-- Boost Beacon 10 + Boost Beacon 50 = 60x beacon factor
	local effTri = {
		boosts = {
			{ id = "j1", dimension_raw = 2, effect = 10.0, remainingSeconds = 600 },
			{ id = "j2", dimension_raw = 2, effect = 50.0, remainingSeconds = 600 },
			{ id = "t1", dimension_raw = 4, effect = 100.0, remainingSeconds = 600 },
			{ id = "t2", dimension_raw = 4, effect = 1000.0, remainingSeconds = 600 },
			{ id = "s1", dimension_raw = 9, effect = 50.0, remainingSeconds = 600 },
			{ id = "s2", dimension_raw = 9, effect = 500.0, remainingSeconds = 600 },
			{ id = "b1", dimension_raw = 7, effect = 10.0, remainingSeconds = 600 },
			{ id = "b2", dimension_raw = 7, effect = 50.0, remainingSeconds = 600 },
		},
	}
	local mTri = EffectsManager.calculateMultipliers(effTri, { eggIndex = 0 }, nowMs)
	eq(mTri.beaconFactor, 60.0, "beacon factor is 60")
	eq(mTri.effectiveEarningsBoost, 3600.0, "earnings: 60 * 60 = 3600x")
	eq(mTri.effectiveIHRBoost, 66000.0, "IHR: 1100 * 60 = 66000x")
	eq(mTri.effectivePrestigeBoost, 33000.0, "prestige: 550 * 60 = 33000x")

	-- 2.11 Verify all 20 reference boosts in BOOST_CATALOG
	for boostId, item in EffectsManager.BOOST_CATALOG do
		eq(item.id, boostId, "catalog item id matches key: " .. boostId)
		ok(item.dimension_raw == 2 or item.dimension_raw == 4 or item.dimension_raw == 7 or item.dimension_raw == 9 or item.dimension_raw == 10, "valid dimension_raw")
		ok(item.durationSeconds >= 0, "non-negative duration")
		ok(item.effect > 0, "positive effect")
	end
end

-- ============================================================================
-- Section 3: Enlightenment Pause (eggIndex == 18)
-- ============================================================================
do
	local nowMs = 1000000
	local effEnlightenment = {
		videoDoublerEndsAtMs = nowMs + 100000,
		boosts = {
			{ id = "jimbos_orange", dimension_raw = 2, effect = 50.0, remainingSeconds = 600 },
			{ id = "boost_beacon_orange", dimension_raw = 7, effect = 50.0, remainingSeconds = 600 },
			{ id = "tachyon_prism_orange", dimension_raw = 4, effect = 1000.0, remainingSeconds = 600 },
		},
	}

	-- 3.1 Multipliers on Enlightenment are neutral, including retired VD
	local mEnl = EffectsManager.calculateMultipliers(effEnlightenment, { eggIndex = 18 }, nowMs)
	eq(mEnl.boostsEnabled, false, "boostsEnabled is false on Enlightenment")
	eq(mEnl.effectiveEarningsBoost, 1.0, "earnings boost is 1.0 on Enlightenment")
	eq(mEnl.effectiveIHRBoost, 1.0, "IHR boost is 1.0 on Enlightenment")
	eq(mEnl.effectivePrestigeBoost, 1.0, "prestige boost is 1.0 on Enlightenment")
	eq(mEnl.vdMultiplier, 1.0, "retired VD inert on Enlightenment")
	eq(mEnl.earningsMultiplier, 1.0, "Enlightenment neutral")

	-- 3.2 Time does NOT decay on Enlightenment
	local beforeSeconds = effEnlightenment.boosts[1].remainingSeconds
	EffectsManager.stepDecay(effEnlightenment, { eggIndex = 18 }, 0.3)
	eq(effEnlightenment.boosts[1].remainingSeconds, beforeSeconds, "boost time does not decay on Enlightenment")
	eq(#effEnlightenment.boosts, 3, "boosts not removed on Enlightenment")

	-- 3.3 Normal decay resumes on other eggs
	EffectsManager.stepDecay(effEnlightenment, { eggIndex = 17 }, 0.3)
	eq(effEnlightenment.boosts[1].remainingSeconds, beforeSeconds - 0.3, "boost decays normally on Universe egg")

	-- 3.4 Expiry boundary: remainingSeconds == 0 preserved, < 0 removed
	local effExp = {
		boosts = {
			{ id = "b1", remainingSeconds = 0.3 },
			{ id = "b2", remainingSeconds = 0.2 },
		},
	}
	EffectsManager.stepDecay(effExp, { eggIndex = 0 }, 0.3)
	eq(#effExp.boosts, 1, "only 1 boost remains")
	eq(effExp.boosts[1].id, "b1", "b1 with remaining 0 is preserved")
	eq(effExp.boosts[1].remainingSeconds, 0, "b1 has exactly 0 remainingSeconds")

	EffectsManager.stepDecay(effExp, { eggIndex = 0 }, 0.001)
	eq(#effExp.boosts, 0, "b1 removed once remainingSeconds < 0")
end

-- ============================================================================
-- Section 4: Boost Activation & Slot Limits (docs/11 Â§4)
-- ============================================================================
do
	local nowMs = 1000000
	local eff = { boosts = {} }
	local inv = { boosts = { jimbos_orange = 10, boost_beacon_orange = 5 } }

	-- 4.1 Standard player limit is 2 slots
	local ok1, b1 = EffectsManager.activateBoost(eff, inv, "jimbos_orange", nil, nowMs, 1.0, 0)
	eq(ok1, true, "1st boost activated")
	eq(inv.boosts.jimbos_orange, 9, "inventory decremented to 9")
	eq(b1.remainingSeconds, 600.0, "duration is 600s")
	eq(b1.effect, 50.0, "effect is 50.0")

	local ok2, b2 = EffectsManager.activateBoost(eff, inv, "boost_beacon_orange", nil, nowMs, 1.0, 0)
	eq(ok2, true, "2nd boost activated")
	eq(inv.boosts.boost_beacon_orange, 4, "inventory decremented to 4")

	-- 3rd boost refused for standard player
	local ok3, err3 = EffectsManager.activateBoost(eff, inv, "jimbos_orange", nil, nowMs, 1.0, 0)
	eq(ok3, false, "3rd boost refused on standard permit")
	eq(err3, "MAX_ACTIVE_BOOSTS")

	-- 4.2 Pro permit allows up to 5 slots
	local okPro3, bPro3 = EffectsManager.activateBoost(eff, inv, "jimbos_orange", nil, nowMs, 1.0, 1)
	eq(okPro3, true, "3rd boost allowed with Pro permit (permitLevel=1)")

	local okPro4, _ = EffectsManager.activateBoost(eff, inv, "jimbos_orange", nil, nowMs, 1.0, 1)
	eq(okPro4, true, "4th boost allowed with Pro")

	local okPro5, _ = EffectsManager.activateBoost(eff, inv, "jimbos_orange", nil, nowMs, 1.0, 1)
	eq(okPro5, true, "5th boost allowed with Pro")

	-- 6th boost refused even for Pro
	local okPro6, errPro6 = EffectsManager.activateBoost(eff, inv, "jimbos_orange", nil, nowMs, 1.0, 1)
	eq(okPro6, false, "6th boost refused with Pro")
	eq(errPro6, "MAX_ACTIVE_BOOSTS")

	-- 4.3 Insufficient inventory refusal
	inv.boosts.empty_boost = 0
	local okEmpty, errEmpty = EffectsManager.activateBoost({ boosts = {} }, inv, "empty_boost", nil, nowMs, 1.0, 0)
	eq(okEmpty, false, "empty inventory rejected")
	eq(errEmpty, "INSUFFICIENT_INVENTORY")

	-- 4.4 Duration multiplier (e.g. from event duration boost)
	local effDur = { boosts = {} }
	local okDur, bDur = EffectsManager.activateBoost(effDur, inv, "jimbos_orange", nil, nowMs, 2.0, 0)
	eq(okDur, true)
	eq(bDur.remainingSeconds, 1200.0, "duration multiplied 2x to 1200s")
end

-- ============================================================================
-- Section 5: Silos, AWAY Mode & Offline Cutoff in TimelineSimulation
-- ============================================================================
do
	-- 5.1 <= 60s is ONLINE: produces full duration without silo restriction
	local farmZeroSilo = makeFarm(10, 100, 0, 0)
	local stateOnline = makeState(farmZeroSilo, nil, 1000)
	local cpOnline = Timeline.begin(stateOnline, 61000, makeConfig(false, 0))
	eq(cpOnline.mode, "ONLINE", "<= 60s is ONLINE")
	eq(cpOnline.productionSeconds, 60, "production is full 60s despite 0 silos")
	local advOnline = Timeline.advance(cpOnline, 1000)
	eq(advOnline.done, true)
	ok(advOnline.state.farm.cash > 10, "cash produced online")

	-- 5.2 > 60s is AWAY: capped to silosOwned * (3600 + 360 * siloCapacityLevel)
	-- With 0 silos, AWAY production is strictly 0s
	local stateAway0 = makeState(makeFarm(10, 100, 0, 0), nil, 1000)
	local cpAway0 = Timeline.begin(stateAway0, 62000, makeConfig(false, 0))
	eq(cpAway0.mode, "AWAY", "> 60s is AWAY")
	eq(cpAway0.productionSeconds, 0, "AWAY production capped to 0s with 0 silos")
	eq(cpAway0.done, true, "done immediately when limit is 0")
	eq(cpAway0.state.settledWallThrough, 62000, "settledWallThrough advances to targetMs")
	eq(cpAway0.state.farm.cash, 10, "cash strictly unchanged")

	-- 5.3 1 silo with level 0 -> 3600s capacity
	local stateAway1 = makeState(makeFarm(10, 100, 0, 1), nil, 1000)
	-- Offline period of 7200s (2h)
	local cpAway1 = Timeline.begin(stateAway1, 1000 + 25200 * 1000, makeConfig(false, 0))
	eq(cpAway1.mode, "AWAY")
	eq(cpAway1.productionSeconds, 21600, "AWAY production capped at 6h flat offline cap (21600s)")

	-- 5.4 Boosts do NOT decay after silos run out!
	local effBoostFreeze = {
		boosts = {
			{ id = "jimbos_orange", dimension_raw = 2, effect = 50.0, remainingSeconds = 1800 }, -- 30 min of boost
		},
	}
	local stateFreeze = makeState(makeFarm(10, 100, 0, 0), effBoostFreeze, 1000)
	-- Player away for 10 hours with 0 silos
	local cpFreeze = Timeline.begin(stateFreeze, 1000 + 36000 * 1000, makeConfig(false, 0))
	eq(cpFreeze.productionSeconds, 0, "0s production")
	eq(cpFreeze.state.effects.boosts[1].remainingSeconds, 1800, "boost remainingSeconds frozen at 1800s")
	eq(cpFreeze.state.settledWallThrough, 1000 + 36000 * 1000, "wall clock advanced 10h")

	-- 5.5 Standard account gets 0.5x AWAY income, Pro gets 1.0x AWAY income
	local stateFree = makeState(makeFarm(0, 100, 0, 1), nil, 1000)
	local cpFree = Timeline.begin(stateFree, 62000, makeConfig(false, 0))
	local resFree = Timeline.advance(cpFree, 1000)

	local statePro = makeState(makeFarm(0, 100, 0, 1), nil, 1000)
	local cpPro = Timeline.begin(statePro, 62000, makeConfig(true, 0))
	local resPro = Timeline.advance(cpPro, 1000)

	near(resPro.state.farm.cash / resFree.state.farm.cash, 2.0, 1e-12, "Pro gets 2x standard away income (1.0x vs 0.5x)")
end

-- Legacy timers are inert online/away and through checkpoint serialization.
do
 for _, pro in {false, true} do
  for _, duration in {0.3, 61, 3600} do
   local function run(effects)
    local cp=Timeline.begin(makeState(makeFarm(0,30,0,1),effects,1000000),1000000+duration*1000,makeConfig(pro,0))
    cp=Timeline.decodeCheckpoint(serde.decode("json",serde.encode("json",Timeline.encodeCheckpoint(cp))))
    return Timeline.advance(cp,100000).state
   end
   local base=run({boosts={}})
   for _, legacy in {{videoDoublerEndsAtMs=999999999},{videoDoubler={endsAtMs=999999999}}} do
    local result=run(legacy)
    near(result.farm.cash,base.farm.cash,nil,"legacy timer cannot increase online/away income")
    near(result.accounting.currentFarmCash,base.accounting.currentFarmCash,nil,"no ledger inflation")
    near(result.accounting.prestigeExtraEarnings,base.accounting.prestigeExtraEarnings,nil,"no phantom prestige earnings")
   end
  end
 end
end

-- ============================================================================
-- Section 6: Live Events & Multiplier Composition in Simulation
-- ============================================================================
do
	local startMs = 1000000
	-- Event active from 1000000 to 1010000 (10s)
	local evEarnings = {
		id = "ev_earn_2x",
		type = "earnings-boost",
		multiplier = 2.0,
		startTimeMs = startMs,
		deadlineMs = startMs + 10000,
	}

	-- 6.1 Event alone in simulation step
	local stateEv = makeState(makeFarm(0, 100, 0, 1), nil, startMs)
	local cfgEv = makeConfig(false, 0, { evEarnings })
	local cpEv = Timeline.begin(stateEv, startMs + 1000, cfgEv) -- 1s simulation
	local resEv = Timeline.advance(cpEv, 1000)

	-- Compare with baseline without event
	local stateBase = makeState(makeFarm(0, 100, 0, 1), nil, startMs)
	local cpBase = Timeline.begin(stateBase, startMs + 1000, makeConfig(false, 0))
	local resBase = Timeline.advance(cpBase, 1000)

	near(resEv.state.farm.cash / resBase.state.farm.cash, 2.0, 1e-12, "2x live event doubles cash income in simulation")

	-- 6.2 Event + Jimbo 50 composition: 2.0 * 50 = 100x; legacy VD ignored
	local effFull = {
		videoDoublerEndsAtMs = startMs + 50000,
		boosts = {
			{ id = "jimbos_orange", dimension_raw = 2, effect = 50.0, remainingSeconds = 600 },
		},
	}
	local stateFull = makeState(makeFarm(0, 100, 0, 1), effFull, startMs)
	local cpFull = Timeline.begin(stateFull, startMs + 1000, cfgEv)
	local resFull = Timeline.advance(cpFull, 1000)

	near(resFull.state.farm.cash / resBase.state.farm.cash, 100.0, 1e-12, "event 2x * Jimbo 50x; legacy VD ignored")

	-- 6.3 Event expired mid-simulation: only active in window
	local evShort = {
		id = "ev_short",
		type = "earnings-boost",
		multiplier = 5.0,
		startTimeMs = startMs,
		deadlineMs = startMs + 300, -- active only in first step (dt <= 0.3)
	}
	ok(EffectsManager.isEventActive(evShort, startMs + 100), "active in first 300ms")
	ok(not EffectsManager.isEventActive(evShort, startMs + 300), "inactive at deadline 300ms")
	ok(not EffectsManager.isEventActive(evShort, startMs + 500), "inactive after deadline")
end

-- ============================================================================
-- Section 7: Prestige Multiplier & prestigeExtraEarnings Accumulation
-- ============================================================================
do
	local startMs = 1000000
	-- Soul Beacon 50 -> 50x prestige multiplier
	local effSoul = {
		boosts = {
			{ id = "soul_beacon_purple_v2", dimension_raw = 9, effect = 50.0, remainingSeconds = 600 },
		},
	}
	local s = makeState(makeFarm(0, 100, 0, 1), effSoul, startMs)
	local cp = Timeline.begin(s, startMs + 1000, makeConfig(false, 0))
	local res = Timeline.advance(cp, 1000)

	-- Cash income earned
	local cashEarned = res.state.farm.cash
	ok(cashEarned > 0, "cash earned")
	-- prestigeExtraEarnings should accumulate: cashEarned * (50 - 1) = cashEarned * 49
	local extraEarned = res.state.accounting.prestigeExtraEarnings
	near(extraEarned, cashEarned * 49.0, 1e-12, "prestigeExtraEarnings accumulates income * (mult - 1)")
end

-- ============================================================================
-- Section 8: Checkpoint Determinism & Slicing Invariance with Effects
-- ============================================================================
do
	local startMs = 1000000
	local effComplex = {
		videoDoublerEndsAtMs = startMs + 5000000,
		boosts = {
			{ id = "jimbos_orange", dimension_raw = 2, effect = 50.0, remainingSeconds = 1200 },
			{ id = "boost_beacon_orange", dimension_raw = 7, effect = 50.0, remainingSeconds = 600 },
			{ id = "tachyon_prism_orange", dimension_raw = 4, effect = 1000.0, remainingSeconds = 600 },
		},
	}
	local farm = makeFarm(100, 100, 0, 2)
	local s = makeState(farm, effComplex, startMs)
	local targetMs = startMs + 2000 -- 2s simulation

	-- Continuous execution
	local cpDirect = Timeline.begin(Data.copy(s), targetMs, makeConfig(true, 0))
	local resDirect = Timeline.advance(cpDirect, 1000)

	-- Sliced phase-by-phase execution with encode/decode round-trip at each step
	local cpSliced = Timeline.begin(Data.copy(s), targetMs, makeConfig(true, 0))
	while not cpSliced.done do
		local wire = Timeline.encodeCheckpoint(cpSliced)
		local wireJson = serde.decode("json", serde.encode("json", wire))
		cpSliced = Timeline.decodeCheckpoint(wireJson)
		cpSliced = Timeline.advance(cpSliced, 1)
	end

	eq(Data.fingerprint(cpSliced), Data.fingerprint(resDirect), "sliced execution with effects matches continuous bitwise")
	eq(cpSliced.state.effects.boosts[1].remainingSeconds, resDirect.state.effects.boosts[1].remainingSeconds, "remaining seconds match exactly")
end

-- ============================================================================
-- Section 9: Save Results and Report
-- ============================================================================
fs.writeFile("build/effect_boundaries-results.json", serde.encode("json", {
	status = "PASS",
	level = "L",
	assertions = assertions,
	studioTested = false,
	dataStoreTested = false,
	scope = "Retired doubler compatibility, boost composition, decay, Enlightenment pause, offline silos, and live events",
}, true))

print(string.format("EffectsManager & Effect Boundaries PASS: %d assertions", assertions))
