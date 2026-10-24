--!nocheck
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local Codec = require("../../src/shared/NumericCodec")
local Schema = require("../../src/server/ProfileSchema").new(Codec)
local Data = require("../../src/server/PersistenceData")
local Repo = require("../../src/server/SessionRepository")
local Actor = require("../../src/server/PlayerCoordinator")
local CatalogData = require("../../src/server/CatalogRegistry/Data")
local Catalog = require("../../src/server/CatalogRegistry").new(Codec, CatalogData, { mode = "INTERNAL_TEST_ONLY" })
local ProductionMath = require("../../src/server/FarmMath/production_research").new(Codec, Catalog, { mode = "INTERNAL_TEST_ONLY" })
local FvSe = require("../../src/server/FarmMath/fv_se")
local ProgressActions = require("../../src/server/ProgressActions")

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

local function nearRel(a, b, maxRelErr, label)
	assertions += 1
	local relErr = math.abs(a - b) / math.abs(b)
	assert(relErr <= maxRelErr, (if label then label .. ": " else "") .. tostring(a) .. " !~= " .. tostring(b) .. " (relErr=" .. tostring(relErr) .. ", limit=" .. tostring(maxRelErr) .. ")")
end

local function ok(cond, label)
	assertions += 1
	assert(cond, label or "condition failed")
end

local function createTestProfile(playerId, nowMs)
	local p = Schema.createReference(playerId or "player-reset-test", nowMs or 1000000)
	return p
end

-- ============================================================================
-- Section 1: PrestigeEarnings and Pending Soul Eggs Calculations
-- ============================================================================
do
	local p = createTestProfile()
	p.accounting.prestigeSessionArchivedCash = BigAmount.encode(200000)
	p.accounting.currentFarmCash = BigAmount.encode(500000)
	p.accounting.prestigeExtraEarnings = BigAmount.encode(50000)

	-- 1.1 Total Prestige Earnings E = archived + current + extra
	local E = ProgressActions.calculatePrestigeEarnings(p)
	eq(E, 750000, "calculatePrestigeEarnings sum matches")

	-- 1.2 Pending Soul Eggs across 7 intervals (p = 0.15 .. 0.21)
	local thresholds = {
		{ E = 1e6, p = 0.15 },
		{ E = 1e15, p = 0.16 },
		{ E = 1e24, p = 0.17 },
		{ E = 1e33, p = 0.18 },
		{ E = 1e42, p = 0.19 },
		{ E = 1e51, p = 0.20 },
		{ E = 1e65, p = 0.21 },
	}

	for _, tc in thresholds do
		local prof = createTestProfile()
		prof.accounting.currentFarmCash = BigAmount.encode(tc.E)
		local se = ProgressActions.calculatePendingSoulEggs(prof)
		local expected = tc.E ^ tc.p
		nearRel(se, expected, 1e-12, "pending SE for E=" .. tostring(tc.E) .. " (exponent " .. tostring(tc.p) .. ")")
	end

	-- 1.3 Epic Prestige Bonus & Event Multiplier
	local profEpic = createTestProfile()
	profEpic.accounting.currentFarmCash = BigAmount.encode(1e15)
	profEpic.permanent.epic = { epic_prestige_bonus = 20 } -- +10% per level -> 3.0x
	local seEpic = ProgressActions.calculatePendingSoulEggs(profEpic)
	local baseSE = (1e15)^0.16
	nearRel(seEpic, baseSE * 3.0, 1e-12, "Epic Prestige Bonus lvl 20 is 3.0x")

	-- Event multiplier 2.0x -> 3.0 * 2.0 = 6.0x
	local seEpicEvent = ProgressActions.calculatePendingSoulEggs(profEpic, 2.0)
	nearRel(seEpicEvent, baseSE * 6.0, 1e-12, "Epic Prestige Bonus lvl 20 with 2x event is 6.0x")

	-- Alternative field name `prestige_bonus`
	local profAlt = createTestProfile()
	profAlt.accounting.currentFarmCash = BigAmount.encode(1e15)
	profAlt.permanent.epic = { prestige_bonus = 10 } -- 2.0x
	local seAlt = ProgressActions.calculatePendingSoulEggs(profAlt)
	nearRel(seAlt, baseSE * 2.0, 1e-12, "prestige_bonus alternative key works")

	-- 1.4 Real64 no-floor verification
	local profFrac = createTestProfile()
	profFrac.accounting.currentFarmCash = BigAmount.encode(10)
	local seFrac = ProgressActions.calculatePendingSoulEggs(profFrac)
	eq(seFrac, 10^0.15, "SE preserves binary64 precision")
	ok(seFrac % 1 ~= 0, "SE must not have math.floor applied")
end

-- ============================================================================
-- Section 2: applyPrestige Mechanics & Invariants
-- ============================================================================
do
	local p = createTestProfile()
	p.farm.eggIndex = 3
	p.farm.cash = BigAmount.encode(999999)
	p.farm.common = { comfy_nests = 10, nutritional_sup = 5 }
	p.farm.habitats[1] = { typeIndex = 1, population = "500", assignedInTransit = "10", fractionalIHR = "0.5" }
	p.farm.habitats[2] = { typeIndex = 0, population = "200", assignedInTransit = "0", fractionalIHR = "0" }
	p.farm.vehicles = { { typeIndex = 1 }, { typeIndex = 0 } }
	p.farm.hatcheryStock = "100"
	p.farm.runningCount = "10"
	p.farm.siloOwned = 4

	p.accounting.prestigeSessionArchivedCash = BigAmount.encode(100000)
	p.accounting.currentFarmCash = BigAmount.encode(500000)
	p.accounting.lastCashEarned = BigAmount.encode(500)
	p.accounting.prestigeExtraEarnings = BigAmount.encode(25000)
	p.accounting.lastBaseEarnings = BigAmount.encode(10000)

	p.permanent.SE = Real64.encode(100.5)
	p.permanent.prestigeCount = "3"
	p.permanent.epic = { epic_prestige_bonus = 10 } -- 2.0x

	local E = 100000 + 500000 + 25000 -- 625,000
	local expectedGainedSE = (625000^0.15) * 2.0
	local expectedNewSE = 100.5 + expectedGainedSE

	local op = { kind = "Prestige", operationId = "op-prestige-1", expectedRevision = "0" }
	local outcome = ProgressActions.applyPrestige(Data.copy(p), op)

	eq(outcome.terminalStatus, "APPLIED", "prestige terminalStatus")
	eq(outcome.result.actionKind, "Prestige", "prestige actionKind")
	eq(outcome.result.gainedSoulEggs, Real64.encode(expectedGainedSE), "gainedSoulEggs result string")
	eq(outcome.result.prestigeCount, "4", "prestigeCount result string")

	local nextProf = outcome.profile

	-- Permanent updates:
	eq(nextProf.permanent.SE, Real64.encode(expectedNewSE), "permanent.SE updated")
	eq(nextProf.permanent.prestigeCount, "4", "permanent.prestigeCount incremented")

	-- Full reset of all 5 session accounting accumulators:
	eq(nextProf.accounting.prestigeSessionArchivedCash, "0", "archived cash reset")
	eq(nextProf.accounting.currentFarmCash, "0", "current farm cash reset")
	eq(nextProf.accounting.lastCashEarned, "0", "last cash earned reset")
	eq(nextProf.accounting.prestigeExtraEarnings, "0", "extra earnings reset")
	eq(nextProf.accounting.lastBaseEarnings, "0", "last base earnings reset")

	-- Farm reset to Edible:
	eq(nextProf.farm.eggIndex, 0, "eggIndex reset to 0 (Edible)")
	eq(nextProf.farm.cash, "0", "farm cash reset to 0")
	eq(#nextProf.farm.habitats, 4, "4 habitats")
	eq(nextProf.farm.habitats[1].typeIndex, 0, "slot 1 reset to Coop (0)")
	eq(nextProf.farm.habitats[1].population, "0", "slot 1 pop 0")
	eq(nextProf.farm.habitats[1].assignedInTransit, "0", "slot 1 transit 0")
	eq(nextProf.farm.habitats[1].fractionalIHR, "0", "slot 1 ihr 0")
	for i = 2, 4 do
		eq(nextProf.farm.habitats[i].typeIndex, -1, "slot " .. i .. " empty (-1)")
		eq(nextProf.farm.habitats[i].population, "0", "slot " .. i .. " pop 0")
	end
	eq(#nextProf.farm.vehicles, 1, "1 vehicle")
	eq(nextProf.farm.vehicles[1].typeIndex, 0, "vehicle reset to Trike (0)")
	eq(nextProf.farm.fleetLimit, 4, "fleetLimit is 4")
	eq(next(nextProf.farm.common), nil, "common research reset to empty table")
	eq(nextProf.farm.hatcheryStock, "250", "hatchery stock reset to 250")
	eq(nextProf.farm.runningCount, "0", "running count reset to 0")
	eq(nextProf.farm.hatchGroupSequence, "0", "hatchGroupSequence reset to 0")
	eq(next(nextProf.farm.groups), nil, "groups reset to empty table")
	eq(nextProf.farm.siloOwned, 1, "siloOwned reset to 1")

	-- Validate against ProfileSchema
	local valid, err = Schema.validate(nextProf, "player-reset-test")
	ok(valid, "ProfileSchema.validate passes after Prestige: " .. tostring(err))

	-- Re-validator test
	ok(outcome.validate(nextProf, 1000000), "validate callback returns true")
end

-- ============================================================================
-- Section 3: UpgradeEgg Farm Value Checks & Rejections
-- ============================================================================
do
	local p = createTestProfile()
	-- Farm Value on fresh Edible profile: ~13 732
	local fv = ProgressActions.calculateProfileFarmValue(p)
	near(fv, 13732.00679132647, 1e-6, "profile FV on fresh farm matches empty edible reference")

	-- 3.1 Advance threshold for SUPERFOOD (index 1) is 68,000,000
	local canAdvance, reason, curFv = ProgressActions.canUpgradeEgg(p, 1)
	eq(canAdvance, false, "cannot advance to Superfood on fresh farm")
	eq(reason, "FV_TOO_LOW", "reason is FV_TOO_LOW")
	near(curFv, 13732.00679132647, 1e-6, "current FV returned")

	-- 3.2 applyUpgradeEgg rejection when FV is too low
	local opBadFv = { kind = "UpgradeEgg", operationId = "op-up-1", expectedRevision = "0", args = { targetEggIndex = 1 } }
	local origFingerprint = Data.fingerprint(p)
	local rejectOutcome = ProgressActions.applyUpgradeEgg(p, opBadFv)
	eq(rejectOutcome.terminalStatus, "REJECTED", "terminalStatus is REJECTED")
	eq(rejectOutcome.result.errorCode, "FV_TOO_LOW", "errorCode is FV_TOO_LOW")
	eq(Data.fingerprint(rejectOutcome.profile), origFingerprint, "candidateProfile completely unchanged on FV rejection")

	-- 3.3 Invalid target egg index rejections:
	-- Same egg
	local opSame = { kind = "UpgradeEgg", operationId = "op-up-same", args = { targetEggIndex = 0 } }
	local resSame = ProgressActions.applyUpgradeEgg(p, opSame)
	eq(resSame.terminalStatus, "REJECTED")
	eq(resSame.result.errorCode, "INVALID_TARGET_EGG")

	-- Downgrade attempt
	p.farm.eggIndex = 3
	local opDown = { kind = "UpgradeEgg", operationId = "op-up-down", args = { targetEggIndex = 2 } }
	local resDown = ProgressActions.applyUpgradeEgg(p, opDown)
	eq(resDown.terminalStatus, "REJECTED")
	eq(resDown.result.errorCode, "INVALID_TARGET_EGG")

	-- Out of bounds
	for _, badIndex in { -1, 19, 100, 1.5, "2" } do
		local opOOB = { kind = "UpgradeEgg", operationId = "op-up-oob", args = { targetEggIndex = badIndex } }
		local resOOB = ProgressActions.applyUpgradeEgg(p, opOOB)
		eq(resOOB.terminalStatus, "REJECTED", "OOB index " .. tostring(badIndex))
		eq(resOOB.result.errorCode, "INVALID_TARGET_EGG")
	end
end

-- ============================================================================
-- Section 4: Successful UpgradeEgg & Session Archiving
-- ============================================================================
do
	local p = createTestProfile()
	-- Boost farm value by giving Earning Bonus: 1,000,000 Soul Eggs with soulFood = 10 -> EB = 200,000 -> mult = 200,001
	p.permanent.SE = Real64.encode(1000000)
	p.permanent.epic = { soul_food = 10 }
	p.farm.cash = BigAmount.encode(500000)
	p.accounting.currentFarmCash = BigAmount.encode(500000)
	p.accounting.lastCashEarned = BigAmount.encode(250)
	p.accounting.prestigeSessionArchivedCash = BigAmount.encode(100000)
	p.accounting.prestigeExtraEarnings = BigAmount.encode(50000)
	p.accounting.lastBaseEarnings = BigAmount.encode(10000)

	local boostedFV = ProgressActions.calculateProfileFarmValue(p)
	ok(boostedFV >= 68000000, "boosted FV qualifies for Superfood (index 1)")

	local canAdv, blk, fv = ProgressActions.canUpgradeEgg(p, 1)
	eq(canAdv, true, "canUpgradeEgg to Superfood is true")
	eq(blk, nil, "no blocked reason")

	local opUpgrade = {
		kind = "UpgradeEgg",
		operationId = "op-up-success",
		expectedRevision = "0",
		args = { targetEggIndex = 1 },
	}

	local outcome = ProgressActions.applyUpgradeEgg(Data.copy(p), opUpgrade)
	eq(outcome.terminalStatus, "APPLIED", "upgrade applied")
	eq(outcome.result.actionKind, "UpgradeEgg", "actionKind UpgradeEgg")
	eq(outcome.result.newEggIndex, 1, "newEggIndex is 1")

	local nextProf = outcome.profile

	-- 4.1 Cash Archiving:
	-- archived = previous archived (100,000) + currentFarmCash (500,000) = 600,000
	eq(nextProf.accounting.prestigeSessionArchivedCash, BigAmount.encode(600000), "archived cash rolled over")
	eq(nextProf.accounting.currentFarmCash, "0", "current farm cash reset to 0")
	eq(nextProf.accounting.lastCashEarned, "0", "last cash earned reset to 0")
	eq(nextProf.farm.cash, "0", "wallet farm cash reset to 0")

	-- Invariants: prestigeExtraEarnings and lastBaseEarnings PRESERVED!
	eq(nextProf.accounting.prestigeExtraEarnings, BigAmount.encode(50000), "prestigeExtraEarnings preserved")
	eq(nextProf.accounting.lastBaseEarnings, BigAmount.encode(10000), "lastBaseEarnings preserved")

	-- 4.2 Egg Index & maxEggReached:
	eq(nextProf.farm.eggIndex, 1, "eggIndex updated to 1")
	eq(nextProf.farm.maxEggReached, 1, "maxEggReached updated to 1")

	-- 4.3 No SE or prestigeCount changes:
	eq(nextProf.permanent.SE, Real64.encode(1000000), "permanent.SE NOT changed by UpgradeEgg")
	eq(nextProf.permanent.prestigeCount, "0", "prestigeCount NOT incremented by UpgradeEgg")

	-- 4.4 Infrastructure Reset:
	eq(nextProf.farm.habitats[1].typeIndex, 0, "slot 1 is Coop")
	eq(nextProf.farm.habitats[1].population, "0", "slot 1 pop is 0")
	eq(nextProf.farm.habitats[2].typeIndex, -1, "slot 2 is empty")
	eq(#nextProf.farm.vehicles, 1, "1 vehicle")
	eq(nextProf.farm.vehicles[1].typeIndex, 0, "vehicle is Trike")
	eq(next(nextProf.farm.common), nil, "common research is empty")
	eq(nextProf.farm.hatcheryStock, "250", "hatchery stock is 250")
	eq(nextProf.farm.runningCount, "0", "running count is 0")
	eq(nextProf.farm.siloOwned, 1, "siloOwned is 1")

	-- Schema validation
	local valid, err = Schema.validate(nextProf, "player-reset-test")
	ok(valid, "ProfileSchema passes after UpgradeEgg: " .. tostring(err))

	-- Storage Re-validator callback checks
	ok(outcome.validate(p, 1000000), "validateFn passes on original pre-upgrade profile")
	local failValidation, valErr = outcome.validate(nextProf, 1000000)
	eq(failValidation, false, "validateFn fails if profile already upgraded")
	eq(valErr, "ALREADY_ADVANCED", "correct re-validation error")

	-- maxEggReached retention on higher historic reach
	local pHigh = createTestProfile()
	pHigh.farm.eggIndex = 1
	pHigh.farm.maxEggReached = 5
	pHigh.permanent.SE = Real64.encode(1000000)
	pHigh.permanent.epic = { soul_food = 10 }
	local outcome2 = ProgressActions.applyUpgradeEgg(pHigh, { kind = "UpgradeEgg", args = { targetEggIndex = 2 } })
	eq(outcome2.profile.farm.eggIndex, 2, "eggIndex is 2")
	eq(outcome2.profile.farm.maxEggReached, 5, "maxEggReached retained at 5")
end

-- ============================================================================
-- Section 5: Full Reset Matrix Field-By-Field Verification (docs/27 §4.2)
-- ============================================================================
do
	local function createRichProfile()
		local p = createTestProfile()
		p.farm.eggIndex = 2
		p.farm.maxEggReached = 3
		p.farm.cash = BigAmount.encode(888888)
		p.farm.habitats[1] = { typeIndex = 1, population = "300", assignedInTransit = "5", fractionalIHR = "0.2" }
		p.farm.habitats[2] = { typeIndex = 0, population = "100", assignedInTransit = "0", fractionalIHR = "0" }
		p.farm.vehicles = { { typeIndex = 1 }, { typeIndex = 0 } }
		p.farm.fleetLimit = 4
		p.farm.common = { comfy_nests = 15, nutritional_sup = 8 }
		p.farm.hatcheryStock = "75"
		p.farm.runningCount = "5"
		p.farm.hatchGroupSequence = "12"
		p.farm.groups = { ["hatch:12"] = { groupId = "hatch:12", count = "5", status = "IN_TRANSIT" } }
		p.farm.siloOwned = 6

		p.accounting.prestigeSessionArchivedCash = BigAmount.encode(300000)
		p.accounting.currentFarmCash = BigAmount.encode(400000)
		p.accounting.lastCashEarned = BigAmount.encode(120)
		p.accounting.prestigeExtraEarnings = BigAmount.encode(35000)
		p.accounting.lastBaseEarnings = BigAmount.encode(15000)

		p.permanent.GE = "7500"
		p.permanent.totalGESpent = "3000"
		p.permanent.SE = Real64.encode(10000000)
		p.permanent.PE = "8"
		p.permanent.epic = { soul_food = 10, epic_prestige_bonus = 5, silo_capacity = 4, prophecy_bonus = 3 }
		p.permanent.hyperloop = true
		p.permanent.prestigeCount = "5"

		p.inventory.boosts = { jimbo_1 = 3, tachyon_2 = 1 }
		p.inventory.pets = { ["pet_1"] = { uid = "pet_1", type = "feather", level = 2 } }
		p.inventory.equipped = { slot_1 = "pet_1" }
		p.inventory.guarantees = { t3_craft = "18" }

		p.effects.boosts = { { id = "active_1", remainingSeconds = 450.5 } }
		p.effects.videoDoubler = { endsAtMs = 5000000 }

		p.timeline.settledWallThrough = 2000000
		p.rewards = { daily_claimed = 5 }
		p.piggy = { storedGE = "1200" }
		p.entitlements = { pro_permit = true }
		p.operations = { ["prior-op-1"] = { kind = "BuyResearch", argsKey = "k", terminalStatus = "APPLIED", result = {}, resultRevision = "1" } }

		return p
	end

	-- 5.1 Field-by-field verification for UpgradeEgg
	local richBeforeUpgrade = createRichProfile()
	local upgradeOp = { kind = "UpgradeEgg", operationId = "op-up-matrix", args = { targetEggIndex = 3 } }
	local upOutcome = ProgressActions.applyUpgradeEgg(Data.copy(richBeforeUpgrade), upgradeOp)
	eq(upOutcome.terminalStatus, "APPLIED", "Upgrade: terminalStatus is APPLIED")
	local pUp = upOutcome.profile

	-- Mutable fields:
	eq(pUp.farm.eggIndex, 3, "Upgrade: eggIndex updated")
	eq(pUp.farm.maxEggReached, 3, "Upgrade: maxEggReached updated")
	eq(pUp.farm.cash, "0", "Upgrade: cash reset")
	eq(pUp.accounting.prestigeSessionArchivedCash, BigAmount.encode(300000 + 400000), "Upgrade: archived sum")
	eq(pUp.accounting.currentFarmCash, "0", "Upgrade: currentFarmCash reset")
	eq(pUp.accounting.lastCashEarned, "0", "Upgrade: lastCashEarned reset")
	eq(pUp.farm.habitats[1].typeIndex, 0, "Upgrade: hab slot 1 Coop")
	eq(pUp.farm.habitats[1].population, "0", "Upgrade: hab slot 1 pop 0")
	eq(pUp.farm.habitats[2].typeIndex, -1, "Upgrade: hab slot 2 empty")
	eq(#pUp.farm.vehicles, 1, "Upgrade: 1 vehicle")
	eq(next(pUp.farm.common), nil, "Upgrade: common empty")
	eq(pUp.farm.hatcheryStock, "250", "Upgrade: hatcheryStock 250")
	eq(pUp.farm.runningCount, "0", "Upgrade: runningCount 0")
	eq(pUp.farm.siloOwned, 1, "Upgrade: siloOwned 1")

	-- INVARIANT FIELDS (must be strictly identical):
	eq(pUp.accounting.prestigeExtraEarnings, richBeforeUpgrade.accounting.prestigeExtraEarnings, "Upgrade: extra earnings preserved")
	eq(pUp.accounting.lastBaseEarnings, richBeforeUpgrade.accounting.lastBaseEarnings, "Upgrade: last base earnings preserved")
	eq(pUp.permanent.GE, richBeforeUpgrade.permanent.GE, "Upgrade: GE preserved")
	eq(pUp.permanent.totalGESpent, richBeforeUpgrade.permanent.totalGESpent, "Upgrade: totalGESpent preserved")
	eq(pUp.permanent.SE, richBeforeUpgrade.permanent.SE, "Upgrade: SE preserved")
	eq(pUp.permanent.PE, richBeforeUpgrade.permanent.PE, "Upgrade: PE preserved")
	eq(pUp.permanent.prestigeCount, richBeforeUpgrade.permanent.prestigeCount, "Upgrade: prestigeCount preserved")
	eq(serde.encode("json", pUp.permanent.epic), serde.encode("json", richBeforeUpgrade.permanent.epic), "Upgrade: epic research preserved")
	eq(pUp.permanent.hyperloop, richBeforeUpgrade.permanent.hyperloop, "Upgrade: hyperloop preserved")
	eq(serde.encode("json", pUp.inventory), serde.encode("json", richBeforeUpgrade.inventory), "Upgrade: full inventory preserved")
	eq(serde.encode("json", pUp.effects), serde.encode("json", richBeforeUpgrade.effects), "Upgrade: full effects preserved")
	eq(pUp.timeline.settledWallThrough, richBeforeUpgrade.timeline.settledWallThrough, "Upgrade: timeline preserved")
	eq(serde.encode("json", pUp.rewards), serde.encode("json", richBeforeUpgrade.rewards), "Upgrade: rewards preserved")
	eq(serde.encode("json", pUp.piggy), serde.encode("json", richBeforeUpgrade.piggy), "Upgrade: piggy preserved")
	eq(serde.encode("json", pUp.entitlements), serde.encode("json", richBeforeUpgrade.entitlements), "Upgrade: entitlements preserved")
	eq(serde.encode("json", pUp.operations), serde.encode("json", richBeforeUpgrade.operations), "Upgrade: operations preserved")

	-- 5.2 Field-by-field verification for Prestige
	local richBeforePrestige = createRichProfile()
	local presOp = { kind = "Prestige", operationId = "op-pres-matrix" }
	local presOutcome = ProgressActions.applyPrestige(Data.copy(richBeforePrestige), presOp)
	local pPres = presOutcome.profile

	-- Mutable fields:
	eq(pPres.farm.eggIndex, 0, "Prestige: eggIndex reset to 0")
	eq(pPres.farm.cash, "0", "Prestige: farm cash reset")
	eq(pPres.accounting.prestigeSessionArchivedCash, "0", "Prestige: archived cash reset")
	eq(pPres.accounting.currentFarmCash, "0", "Prestige: currentFarmCash reset")
	eq(pPres.accounting.lastCashEarned, "0", "Prestige: lastCashEarned reset")
	eq(pPres.accounting.prestigeExtraEarnings, "0", "Prestige: extra earnings reset")
	eq(pPres.accounting.lastBaseEarnings, "0", "Prestige: lastBaseEarnings reset")
	eq(pPres.farm.habitats[1].typeIndex, 0, "Prestige: hab 1 Coop")
	eq(pPres.farm.habitats[1].population, "0", "Prestige: pop 0")
	eq(#pPres.farm.vehicles, 1, "Prestige: 1 vehicle")
	eq(next(pPres.farm.common), nil, "Prestige: common empty")
	eq(pPres.farm.hatcheryStock, "250", "Prestige: stock 250")
	eq(pPres.farm.runningCount, "0", "Prestige: running 0")
	eq(pPres.farm.siloOwned, 1, "Prestige: silos 1")

	-- Specific Prestige updates:
	ok(Real64.decode(pPres.permanent.SE) > Real64.decode(richBeforePrestige.permanent.SE), "Prestige: SE increased")
	eq(pPres.permanent.prestigeCount, "6", "Prestige: prestigeCount incremented from 5 to 6")
	eq(pPres.farm.maxEggReached, 3, "Prestige: maxEggReached NOT lowered (stays 3)")

	-- INVARIANT FIELDS (must be strictly identical):
	eq(pPres.permanent.GE, richBeforePrestige.permanent.GE, "Prestige: GE preserved")
	eq(pPres.permanent.totalGESpent, richBeforePrestige.permanent.totalGESpent, "Prestige: totalGESpent preserved")
	eq(pPres.permanent.PE, richBeforePrestige.permanent.PE, "Prestige: PE preserved")
	eq(serde.encode("json", pPres.permanent.epic), serde.encode("json", richBeforePrestige.permanent.epic), "Prestige: epic research preserved")
	eq(pPres.permanent.hyperloop, richBeforePrestige.permanent.hyperloop, "Prestige: hyperloop preserved")
	eq(serde.encode("json", pPres.inventory), serde.encode("json", richBeforePrestige.inventory), "Prestige: full inventory preserved")
	eq(serde.encode("json", pPres.effects), serde.encode("json", richBeforePrestige.effects), "Prestige: full effects preserved")
	eq(pPres.timeline.settledWallThrough, richBeforePrestige.timeline.settledWallThrough, "Prestige: timeline preserved")
	eq(serde.encode("json", pPres.rewards), serde.encode("json", richBeforePrestige.rewards), "Prestige: rewards preserved")
	eq(serde.encode("json", pPres.piggy), serde.encode("json", richBeforePrestige.piggy), "Prestige: piggy preserved")
	eq(serde.encode("json", pPres.entitlements), serde.encode("json", richBeforePrestige.entitlements), "Prestige: entitlements preserved")
	eq(serde.encode("json", pPres.operations), serde.encode("json", richBeforePrestige.operations), "Prestige: operations preserved")
end

-- ============================================================================
-- Section 6: Integration with PlayerCoordinator (Actor) & Idempotency
-- ============================================================================
do
	local function createCoordinatorHarness()
		local t = { records = {}, now = 1000000, elapsed = 0, serial = 0, updates = 0, reads = 0 }
		local store = {}
		function store.read(key)
			t.reads += 1
			return true, if t.records[key] then Data.copy(t.records[key]) else nil
		end
		function store.update(key, callback)
			t.updates += 1
			local nextProfile = callback(if t.records[key] then Data.copy(t.records[key]) else nil)
			if nextProfile then t.records[key] = Data.copy(nextProfile) end
			return true, if nextProfile then Data.copy(nextProfile) else nil
		end
		t.repo = Repo.new({
			mode = "INTERNAL_TEST_ONLY",
			codec = Codec,
			data = Data,
			schema = Schema,
			store = store,
			clock = {
				utcNowMs = function() return t.now end,
				elapsedNowSeconds = function() return t.elapsed end,
			},
			encodeJson = function(v) return serde.encode("json", v) end,
			tokenFactory = function() t.serial += 1; return "token-" .. t.serial end,
		})

		local acquired = t.repo.acquire("1")
		eq(acquired.status, "ACQUIRED")
		t.handle = acquired.handle

		-- Seed profile with high SE so FV is boosted and egg upgrade is allowed
		t.handle.snapshot.permanent.SE = Real64.encode(1000000)
		t.handle.snapshot.permanent.epic = { soul_food = 10 }
		t.handle.snapshot.farm.cash = BigAmount.encode(500000)
		t.handle.snapshot.accounting.currentFarmCash = BigAmount.encode(500000)
		t.records["player:1"] = Data.copy(t.handle.snapshot)

		local simulation = {
			advance = function(profile, request)
				return { profile = profile, complete = true }
			end,
		}

		t.domain = ProgressActions.new(Codec, Catalog, ProductionMath, { mode = "INTERNAL_TEST_ONLY" })
		t.actor = Actor.new({
			mode = "INTERNAL_TEST_ONLY",
			codec = Codec,
			data = Data,
			repository = t.repo,
			handle = t.handle,
			clock = {
				utcNowMs = function() return t.now end,
				elapsedNowSeconds = function() return t.elapsed end,
			},
			simulation = simulation,
			domain = t.domain,
			maxQueue = 8,
		})
		function t.ready() eq(t.actor.setReady(true).status, "READY_SET") end
		function t.drain() return t.actor.drain() end
		return t
	end

	local h = createCoordinatorHarness()
	h.ready()
	local actor = h.actor

	-- 6.1 Submit UpgradeEgg through PlayerCoordinator
	local opUpgrade = {
		protocolVersion = 1,
		requestId = "req-up-1",
		kind = "UpgradeEgg",
		operationId = "op-coord-upgrade-1",
		expectedRevision = "0",
		args = { targetEggIndex = 1 },
	}

	local submitRes = actor.submit(opUpgrade)
	eq(submitRes.status, "PENDING", "submit UpgradeEgg is PENDING")
	local drainRes = h.drain()
	eq(drainRes.status, "DRAINED")
	eq(#drainRes.results, 1)
	local r1 = drainRes.results[1]
	eq(r1.status, "APPLIED", "UpgradeEgg APPLIED in coordinator")
	eq(r1.result.terminalStatus, "APPLIED")
	eq(r1.result.actionKind, "UpgradeEgg")
	eq(r1.result.newEggIndex, 1)
	eq(r1.resultRevision, "1")

	local snap = h.records["player:1"]
	eq(snap.farm.eggIndex, 1, "durable store eggIndex is 1")
	eq(snap.meta.revision, "1", "revision bumped to 1")
	eq(snap.accounting.prestigeSessionArchivedCash, BigAmount.encode(500000), "archived cash stored")

	-- 6.2 Idempotency: Replay same operationId for UpgradeEgg
	local replayRes = actor.submit(opUpgrade)
	eq(replayRes.status, "REPLAYED", "duplicate operationId returns REPLAYED")
	eq(replayRes.resultRevision, "1", "replayed revision is 1")
	eq(replayRes.result.newEggIndex, 1, "replayed result preserved")
	-- Store must not be modified again
	eq(h.records["player:1"].farm.eggIndex, 1)
	eq(h.records["player:1"].meta.revision, "1")

	-- 6.3 Conflict detection: same operationId with different target
	local conflictOp = {
		protocolVersion = 1,
		requestId = "req-up-diff",
		kind = "UpgradeEgg",
		operationId = "op-coord-upgrade-1",
		expectedRevision = "1",
		args = { targetEggIndex = 2 },
	}
	local conflictRes = actor.submit(conflictOp)
	eq(conflictRes.status, "REJECTED", "conflict returns REJECTED")
	eq(conflictRes.errorCode, "OPERATION_ID_CONFLICT")

	-- 6.4 Submit Prestige through PlayerCoordinator
	local opPrestige = {
		protocolVersion = 1,
		requestId = "req-pres-1",
		kind = "Prestige",
		operationId = "op-coord-prestige-1",
		expectedRevision = "1",
		args = {},
	}

	local submitPres = actor.submit(opPrestige)
	eq(submitPres.status, "PENDING", "submit Prestige is PENDING")
	local drainPres = h.drain()
	eq(drainPres.status, "DRAINED")
	eq(#drainPres.results, 1)
	local rPres = drainPres.results[1]
	eq(rPres.status, "APPLIED", "Prestige APPLIED")
	eq(rPres.result.terminalStatus, "APPLIED")
	eq(rPres.result.actionKind, "Prestige")
	eq(rPres.resultRevision, "2")

	local snapPres = h.records["player:1"]
	eq(snapPres.farm.eggIndex, 0, "durable store eggIndex reset to 0")
	eq(snapPres.permanent.prestigeCount, "1", "prestigeCount is 1")
	ok(Real64.decode(snapPres.permanent.SE) > 1000000, "SE increased in durable store")
	eq(snapPres.meta.revision, "2", "revision bumped to 2")
	eq(snapPres.accounting.prestigeSessionArchivedCash, "0", "archived cash reset in durable store")

	-- 6.5 Idempotency: Replay same operationId for Prestige
	local curSEText = snapPres.permanent.SE
	local replayPres = actor.submit(opPrestige)
	eq(replayPres.status, "REPLAYED", "duplicate prestige operationId returns REPLAYED")
	eq(replayPres.resultRevision, "2")
	-- Verify SE was NOT added again and prestigeCount was NOT incremented again!
	eq(h.records["player:1"].permanent.SE, curSEText, "SE not doubled on replay")
	eq(h.records["player:1"].permanent.prestigeCount, "1", "prestigeCount not incremented on replay")
	eq(h.records["player:1"].meta.revision, "2", "revision unchanged on replay")

	-- 6.6 Unknown action handling in ProgressActions dispatcher
	local unknownOutcome = ProgressActions.apply(Data.copy(snapPres), { kind = "UnknownAction" })
	eq(unknownOutcome.terminalStatus, "REJECTED")
	eq(unknownOutcome.result.errorCode, "UNKNOWN_PROGRESS_ACTION")
end

-- ============================================================================
-- Section 7: Save Results and Report
-- ============================================================================
fs.writeFile("build/resets-results.json", serde.encode("json", {
	status = "PASS",
	level = "L",
	assertions = assertions,
	studioTested = false,
	dataStoreTested = false,
	scope = "NEXT-02 UpgradeEgg, Prestige, session accounting, and idempotency",
}, true))

print(string.format("ProgressActions & Resets PASS: %d assertions", assertions))
