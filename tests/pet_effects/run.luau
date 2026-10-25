--!nocheck
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local Equipment = require("../../src/server/pets/equipment")

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

-- ============================================================================
-- Section 1: Pet Data Structure Validation & Creation
-- ============================================================================
do
	local inv = Equipment.createInventory()
	ok(type(inv) == "table", "inventory is table")
	ok(type(inv.pets) == "table", "inventory.pets is table")
	ok(type(inv.equipped) == "table", "inventory.equipped is table")
	ok(type(inv.guarantees) == "table", "inventory.guarantees is table")
	eq(#inv.equipped, 0, "initial equipped is empty")

	-- Valid pet item
	local validPet = {
		uid = "pet_001",
		speciesId = "farmer_dog",
		tier = 1,
		variant = "normal",
		locked = false,
	}
	local okVal, errVal = Equipment.validatePet(validPet)
	ok(okVal, "valid pet accepted")
	eq(errVal, nil, "no error for valid pet")

	-- Invalid validations
	ok(not Equipment.validatePet(nil), "nil pet rejected")
	ok(not Equipment.validatePet(123), "number pet rejected")
	ok(not Equipment.validatePet({ uid = "", speciesId = "dog", tier = 1, variant = "normal", locked = false }), "empty uid rejected")
	ok(not Equipment.validatePet({ uid = "p1", speciesId = "", tier = 1, variant = "normal", locked = false }), "empty speciesId rejected")
	ok(not Equipment.validatePet({ uid = "p1", speciesId = "dog", tier = 0, variant = "normal", locked = false }), "tier 0 rejected")
	ok(not Equipment.validatePet({ uid = "p1", speciesId = "dog", tier = 6, variant = "normal", locked = false }), "tier 6 rejected")
	ok(not Equipment.validatePet({ uid = "p1", speciesId = "dog", tier = 2.5, variant = "normal", locked = false }), "fractional tier rejected")
	ok(not Equipment.validatePet({ uid = "p1", speciesId = "dog", tier = 1, variant = "shiny", locked = false }), "invalid variant rejected")
	ok(not Equipment.validatePet({ uid = "p1", speciesId = "dog", tier = 1, variant = "normal", locked = "false" }), "string locked rejected")

	-- Variants accepted
	ok(Equipment.validatePet({ uid = "p1", speciesId = "dog", tier = 1, variant = "normal", locked = false }), "normal accepted")
	ok(Equipment.validatePet({ uid = "p2", speciesId = "dog", tier = 2, variant = "golden", locked = true }), "golden accepted")
	ok(Equipment.validatePet({ uid = "p3", speciesId = "dog", tier = 5, variant = "rainbow", locked = false }), "rainbow accepted")

	-- Custom bonus validation
	ok(Equipment.validatePet({ uid = "p4", speciesId = "dog", tier = 1, variant = "normal", locked = false, customBonus = { eggValueMult = 0.5 } }), "valid table customBonus accepted")
	ok(Equipment.validatePet({ uid = "p5", speciesId = "dog", tier = 1, variant = "normal", locked = false, customBonus = 0.5 }), "valid number customBonus accepted")
	ok(not Equipment.validatePet({ uid = "p6", speciesId = "dog", tier = 1, variant = "normal", locked = false, customBonus = "fast" }), "string customBonus rejected")
	ok(not Equipment.validatePet({ uid = "p7", speciesId = "dog", tier = 1, variant = "normal", locked = false, customBonus = { [1] = 0.5 } }), "non-string key customBonus rejected")
end

-- ============================================================================
-- Section 2: Inventory Operations & Protections (add, remove, lock, duplicates)
-- ============================================================================
do
	local inv = Equipment.createInventory()

	local pet1 = { uid = "pet_1", speciesId = "farmer_dog", tier = 1, variant = "normal", locked = false }
	local pet2 = { uid = "pet_2", speciesId = "robo_cock", tier = 2, variant = "golden", locked = true }

	local added1, id1 = Equipment.addPet(inv, pet1)
	ok(added1, "pet1 added")
	eq(id1, "pet_1", "added pet1 returns uid")
	eq(inv.pets["pet_1"].uid, "pet_1", "pet1 stored in inventory")

	-- Duplicate UID rejection
	local addedDup, errDup = Equipment.addPet(inv, pet1)
	ok(not addedDup, "duplicate UID rejected")
	eq(errDup, "DUPLICATE_UID", "duplicate error matches")

	local added2, id2 = Equipment.addPet(inv, pet2)
	ok(added2, "pet2 added")

	-- Locked pet removal protection
	local remLocked, errLocked = Equipment.removePet(inv, "pet_2")
	ok(not remLocked, "locked pet cannot be removed")
	eq(errLocked, "PET_LOCKED", "locked removal error matches")
	ok(inv.pets["pet_2"] ~= nil, "locked pet remains in inventory")

	-- Unlocking pet
	local lockRes = Equipment.setPetLock(inv, "pet_2", false)
	ok(lockRes, "setPetLock to false succeeded")
	eq(inv.pets["pet_2"].locked, false, "pet2 is now unlocked")

	-- Non-existent pet removal
	local remGhost, errGhost = Equipment.removePet(inv, "non_existent")
	ok(not remGhost, "ghost pet cannot be removed")
	eq(errGhost, "PET_NOT_FOUND", "ghost error matches")

	-- Unlocked pet removal succeeds
	local remSuccess, remErr = Equipment.removePet(inv, "pet_2")
	ok(remSuccess, "unlocked pet2 removed successfully")
	eq(remErr, nil, "no removal error")
	eq(inv.pets["pet_2"], nil, "pet2 no longer in inventory")

	-- Equipped pet removal protection
	local pet3 = { uid = "pet_3", speciesId = "golden_pecker", tier = 1, variant = "normal", locked = false }
	Equipment.addPet(inv, pet3)
	Equipment.equipPet(inv, "pet_3")
	eq(#inv.equipped, 1, "pet_3 equipped")

	local remEquipped, errEquipped = Equipment.removePet(inv, "pet_3")
	ok(not remEquipped, "equipped pet cannot be removed")
	eq(errEquipped, "PET_EQUIPPED", "equipped removal error matches")
	ok(inv.pets["pet_3"] ~= nil, "equipped pet remains in inventory")

	-- Unequip and then remove
	Equipment.unequipPet(inv, "pet_3")
	eq(#inv.equipped, 0, "pet_3 unequipped")
	local remAfterUnequip = Equipment.removePet(inv, "pet_3")
	ok(remAfterUnequip, "pet_3 removed after unequip")
	eq(inv.pets["pet_3"], nil, "pet_3 removed from inventory")
end

-- ============================================================================
-- Section 3: Slot Limits (Standard 3, Pro 5) & Duplicate Equip Prevention
-- ============================================================================
do
	eq(Equipment.getMaxSlots(false), 3, "standard slot limit is 3")
	eq(Equipment.getMaxSlots(nil), 3, "nil pro slot limit is 3")
	eq(Equipment.getMaxSlots(true), 5, "pro slot limit is 5")
	eq(Equipment.getMaxSlots(1), 5, "permit level 1 slot limit is 5")

	local inv = Equipment.createInventory()
	for i = 1, 6 do
		Equipment.addPet(inv, {
			uid = "slot_pet_" .. i,
			speciesId = "farmer_dog",
			tier = 1,
			variant = "normal",
			locked = false,
		})
	end

	-- Standard user (3 slots)
	local eq1 = Equipment.equipPet(inv, "slot_pet_1", false)
	local eq2 = Equipment.equipPet(inv, "slot_pet_2", false)
	local eq3 = Equipment.equipPet(inv, "slot_pet_3", false)
	ok(eq1 and eq2 and eq3, "equipped 3 pets on standard")
	eq(#inv.equipped, 3, "3 pets equipped")

	-- 4th pet on standard should fail
	local eq4, err4 = Equipment.equipPet(inv, "slot_pet_4", false)
	ok(not eq4, "4th pet rejected on standard")
	eq(err4, "MAX_SLOTS_REACHED", "max slots error on standard")
	eq(#inv.equipped, 3, "equipped count unchanged")

	-- Duplicate equip prevention
	local eqDup, errDup = Equipment.equipPet(inv, "slot_pet_1", false)
	ok(not eqDup, "duplicate equip rejected")
	eq(errDup, "ALREADY_EQUIPPED", "already equipped error matches")

	-- Pro user (5 slots)
	local eq4Pro, err4Pro = Equipment.equipPet(inv, "slot_pet_4", true)
	ok(eq4Pro, "4th pet accepted on Pro")
	eq(err4Pro, nil, "no error for 4th pet on Pro")

	local eq5Pro, err5Pro = Equipment.equipPet(inv, "slot_pet_5", true)
	ok(eq5Pro, "5th pet accepted on Pro")
	eq(#inv.equipped, 5, "5 pets equipped on Pro")

	-- 6th pet on Pro should fail
	local eq6Pro, err6Pro = Equipment.equipPet(inv, "slot_pet_6", true)
	ok(not eq6Pro, "6th pet rejected on Pro")
	eq(err6Pro, "MAX_SLOTS_REACHED", "max slots error on Pro")
	eq(#inv.equipped, 5, "equipped count unchanged at 5")

	-- Unequip non-equipped pet
	local unGhost, unGhostErr = Equipment.unequipPet(inv, "slot_pet_6")
	ok(not unGhost, "unequipping non-equipped pet fails")
	eq(unGhostErr, "NOT_EQUIPPED", "not equipped error matches")

	-- Unequip all
	for i = 1, 5 do
		local okU = Equipment.unequipPet(inv, "slot_pet_" .. i)
		ok(okU, "unequipped slot_pet_" .. i)
	end
	eq(#inv.equipped, 0, "all unequipped")
end

-- ============================================================================
-- Section 4: Additive Stacking of Same-Stat Bonuses (P[d] = 1 + sum(b_i))
-- ============================================================================
do
	-- Baseline empty inventory: neutral 1.0 across all dimensions
	local invEmpty = Equipment.createInventory()
	local mEmpty = Equipment.calculatePetMultipliers(invEmpty, { eggIndex = 0 })
	eq(mEmpty.eggValueMult, 1.0, "neutral eggValueMult is 1.0")
	eq(mEmpty.layingRateMult, 1.0, "neutral layingRateMult is 1.0")
	eq(mEmpty.ihrMult, 1.0, "neutral ihrMult is 1.0")
	eq(mEmpty.habCapacityMult, 1.0, "neutral habCapacityMult is 1.0")
	eq(mEmpty.eliteChanceMult, 1.0, "neutral eliteChanceMult is 1.0")
	eq(mEmpty.prestigeEarningsMult, 1.0, "neutral prestigeEarningsMult is 1.0")
	eq(mEmpty.boostBoostMult, 1.0, "neutral boostBoostMult is 1.0")

	-- Single pet with +50% (b=0.5): 1 + 0.5 = 1.5x
	local inv = Equipment.createInventory()
	Equipment.addPet(inv, {
		uid = "p1",
		speciesId = "farmer_dog",
		tier = 1,
		variant = "normal",
		locked = false,
		customBonus = { eggValueMult = 0.5 },
	})
	Equipment.equipPet(inv, "p1")
	local m1 = Equipment.calculatePetMultipliers(inv, { eggIndex = 0 })
	near(m1.eggValueMult, 1.5, 1e-12, "single +50% gives 1.5x")
	eq(m1.layingRateMult, 1.0, "unaffected dimension remains 1.0")

	-- Two pets with +50% (b1=0.5, b2=0.5): 1 + 0.5 + 0.5 = 2.0x (NOT 1.5^2 = 2.25x)
	Equipment.addPet(inv, {
		uid = "p2",
		speciesId = "farmer_dog",
		tier = 1,
		variant = "normal",
		locked = false,
		customBonus = { eggValueMult = 0.5 },
	})
	Equipment.equipPet(inv, "p2")
	local m2 = Equipment.calculatePetMultipliers(inv, { eggIndex = 0 })
	near(m2.eggValueMult, 2.0, 1e-12, "two +50% pets give exactly 2.0x (additive)")

	-- Five pets with +50% (b=0.5 each): 1 + 5*0.5 = 3.5x
	for i = 3, 5 do
		Equipment.addPet(inv, {
			uid = "p" .. i,
			speciesId = "farmer_dog",
			tier = 1,
			variant = "normal",
			locked = false,
			customBonus = { eggValueMult = 0.5 },
		})
		Equipment.equipPet(inv, "p" .. i, 5)
	end
	local m5 = Equipment.calculatePetMultipliers(inv, { eggIndex = 0 })
	near(m5.eggValueMult, 3.5, 1e-12, "five +50% pets give exactly 3.5x (additive)")
end

-- ============================================================================
-- Section 5: Evolution Variants Scaling (Golden 2.0x bonus, Rainbow 3.5x bonus)
-- ============================================================================
do
	-- Base bonus b_base = 0.5 (+50%)
	-- Normal: b = 0.5 -> P = 1 + 0.5 = 1.5
	-- Golden: b = 0.5 * 2.0 = 1.0 -> P = 1 + 1.0 = 2.0 (NOT (1 + 0.5) * 2 = 3.0)
	-- Rainbow: b = 0.5 * 3.5 = 1.75 -> P = 1 + 1.75 = 2.75 (NOT (1 + 0.5) * 3.5 = 5.25)
	local inv = Equipment.createInventory()

	Equipment.addPet(inv, {
		uid = "gold_dog",
		speciesId = "farmer_dog",
		tier = 1,
		variant = "golden",
		locked = false,
		customBonus = { eggValueMult = 0.5 },
	})
	Equipment.equipPet(inv, "gold_dog")
	local mGold = Equipment.calculatePetMultipliers(inv, { eggIndex = 0 })
	near(mGold.eggValueMult, 2.0, 1e-12, "golden +50% scales bonus to 1.0 -> multiplier 2.0x")

	Equipment.unequipPet(inv, "gold_dog")

	Equipment.addPet(inv, {
		uid = "rainbow_dog",
		speciesId = "farmer_dog",
		tier = 1,
		variant = "rainbow",
		locked = false,
		customBonus = { eggValueMult = 0.5 },
	})
	Equipment.equipPet(inv, "rainbow_dog")
	local mRain = Equipment.calculatePetMultipliers(inv, { eggIndex = 0 })
	near(mRain.eggValueMult, 2.75, 1e-12, "rainbow +50% scales bonus to 1.75 -> multiplier 2.75x")

	-- Combining 1 Golden (b=1.0) and 1 Normal (b=0.5): 1 + 1.0 + 0.5 = 2.5x
	Equipment.equipPet(inv, "gold_dog")
	local mCombo = Equipment.calculatePetMultipliers(inv, { eggIndex = 0 })
	near(mCombo.eggValueMult, 3.75, 1e-12, "golden (1.0) + rainbow (1.75) gives 1 + 2.75 = 3.75x")
end

-- ============================================================================
-- Section 6: Drone Hawk & Elite Chance (min(1.0, pBase * P), zero handling)
-- ============================================================================
do
	-- Helper direct testing
	eq(Equipment.calculateDroneEliteChance(0.0, 5.0), 0.0, "zero pBase gives 0")
	eq(Equipment.calculateDroneEliteChance(-0.05, 5.0), 0.0, "negative pBase gives 0")
	eq(Equipment.calculateDroneEliteChance(0.08, 0.0), 0.0, "zero multiplier gives 0")
	eq(Equipment.calculateDroneEliteChance(0.08, -1.0), 0.0, "negative multiplier gives 0")

	-- Doc 16 §1 exact reference progression:
	-- Base chance pBase = 0.08 (8%)
	-- "5x" means b = 4.0.
	-- One Hawk 5x: P = 1 + 4 = 5 -> pElite = 0.08 * 5 = 0.40 (40%)
	-- Two Hawks 5x: P = 1 + 4 + 4 = 9 -> pElite = 0.08 * 9 = 0.72 (72%)
	-- Three Hawks 5x: P = 1 + 4 + 4 + 4 = 13 -> raw = 0.08 * 13 = 1.04 -> saturated min(1.0, 1.04) = 1.0 (100%)
	local pBase = 0.08
	local inv = Equipment.createInventory()
	for i = 1, 3 do
		Equipment.addPet(inv, {
			uid = "hawk_" .. i,
			speciesId = "drone_hawk",
			tier = 1,
			variant = "normal",
			locked = false,
			customBonus = { eliteChanceMult = 4.0 },
		})
	end

	-- 1 Hawk
	Equipment.equipPet(inv, "hawk_1")
	local m1 = Equipment.calculatePetMultipliers(inv, { eggIndex = 0 })
	near(m1.eliteChanceMult, 5.0, 1e-12, "one 5x hawk gives multiplier P=5")
	near(Equipment.calculateDroneEliteChance(pBase, m1.eliteChanceMult), 0.40, 1e-12, "one 5x hawk gives 40% elite chance")

	-- 2 Hawks
	Equipment.equipPet(inv, "hawk_2")
	local m2 = Equipment.calculatePetMultipliers(inv, { eggIndex = 0 })
	near(m2.eliteChanceMult, 9.0, 1e-12, "two 5x hawks give multiplier P=9")
	near(Equipment.calculateDroneEliteChance(pBase, m2.eliteChanceMult), 0.72, 1e-12, "two 5x hawks give 72% elite chance (doc 16 §1)")

	-- 3 Hawks (saturation at 100%)
	Equipment.equipPet(inv, "hawk_3")
	local m3 = Equipment.calculatePetMultipliers(inv, { eggIndex = 0 })
	near(m3.eliteChanceMult, 13.0, 1e-12, "three 5x hawks give multiplier P=13")
	near(Equipment.calculateDroneEliteChance(pBase, m3.eliteChanceMult), 1.0, 1e-12, "three 5x hawks saturate at exactly 100% (doc 16 §1)")
end

-- ============================================================================
-- Section 7: Enlightenment Egg Neutralization (eggIndex == 18)
-- ============================================================================
do
	local inv = Equipment.createInventory()
	Equipment.addPet(inv, {
		uid = "super_dog",
		speciesId = "farmer_dog",
		tier = 5,
		variant = "rainbow",
		locked = false,
		customBonus = {
			eggValueMult = 5.0,
			layingRateMult = 3.0,
			ihrMult = 4.0,
			habCapacityMult = 2.0,
			eliteChanceMult = 10.0,
			prestigeEarningsMult = 6.0,
			boostBoostMult = 2.5,
		},
	})
	Equipment.equipPet(inv, "super_dog")
	eq(#inv.equipped, 1, "super_dog is equipped")

	-- On standard egg (e.g. Edible egg 0), multipliers are active
	local mActive = Equipment.calculatePetMultipliers(inv, { eggIndex = 0 })
	ok(mActive.eggValueMult > 1.0, "eggValueMult active on Edible")
	ok(mActive.layingRateMult > 1.0, "layingRateMult active on Edible")
	ok(mActive.ihrMult > 1.0, "ihrMult active on Edible")
	ok(mActive.habCapacityMult > 1.0, "habCapacityMult active on Edible")
	ok(mActive.eliteChanceMult > 1.0, "eliteChanceMult active on Edible")
	ok(mActive.prestigeEarningsMult > 1.0, "prestigeEarningsMult active on Edible")
	ok(mActive.boostBoostMult > 1.0, "boostBoostMult active on Edible")

	-- On Enlightenment (eggIndex == 18), all multipliers are neutralized to 1.0x
	local mEnlightenment = Equipment.calculatePetMultipliers(inv, { eggIndex = 18 })
	eq(mEnlightenment.eggValueMult, 1.0, "Enlightenment neutralizes eggValueMult to 1.0")
	eq(mEnlightenment.layingRateMult, 1.0, "Enlightenment neutralizes layingRateMult to 1.0")
	eq(mEnlightenment.ihrMult, 1.0, "Enlightenment neutralizes ihrMult to 1.0")
	eq(mEnlightenment.habCapacityMult, 1.0, "Enlightenment neutralizes habCapacityMult to 1.0")
	eq(mEnlightenment.eliteChanceMult, 1.0, "Enlightenment neutralizes eliteChanceMult to 1.0")
	eq(mEnlightenment.prestigeEarningsMult, 1.0, "Enlightenment neutralizes prestigeEarningsMult to 1.0")
	eq(mEnlightenment.boostBoostMult, 1.0, "Enlightenment neutralizes boostBoostMult to 1.0")

	-- With isEnlightenment = true flag
	local mFlag = Equipment.calculatePetMultipliers(inv, { eggIndex = 0, isEnlightenment = true })
	eq(mFlag.eggValueMult, 1.0, "isEnlightenment flag neutralizes eggValueMult")

	-- Crucial invariant: pets remain equipped in inventory, not stripped or unequipped
	eq(#inv.equipped, 1, "pets remain equipped during Enlightenment")
	eq(inv.equipped[1], "super_dog", "equipped pet is still super_dog")
end

-- ============================================================================
-- Section 8: Alien Clucker & Boost Category Composition
-- ============================================================================
do
	-- Reference rule (docs/16 §2):
	-- B = sum(Beacon) if sum(Beacon) > 0 else 1.0
	-- Q = P[boostBoostMult]
	-- category = categorySum * B * Q if categorySum > 1.0 else 1.0

	-- Empty category (categorySum <= 1.0): Q does NOT activate empty categories!
	eq(Equipment.composeBoostWithAlien(1.0, 0, 1.5), 1.0, "empty category remains 1.0 with Alien")
	eq(Equipment.composeBoostWithAlien(0.0, 50, 1.5), 1.0, "zero category remains 1.0 with Beacon and Alien")
	eq(Equipment.composeBoostWithAlien(1.0, 50, 2.0), 1.0, "neutral category remains 1.0 with 50x Beacon and Alien")

	-- Active category without Beacon (categorySum = 50, beaconSum = 0, Q = 1.5)
	-- category = 50 * 1 * 1.5 = 75
	near(Equipment.composeBoostWithAlien(50.0, 0, 1.5), 75.0, 1e-12, "50x Jimbo + 1.5x Alien gives 75x")

	-- Active category with Beacon (docs/16 §2 line 66 exact reference):
	-- Jimbo 50, Beacon 50, Alien +50% (Q = 1.5):
	-- 50 * 50 * 1.5 = 3750x
	near(Equipment.composeBoostWithAlien(50.0, 50.0, 1.5), 3750.0, 1e-12, "Jimbo 50 + Beacon 50 + Alien 1.5 gives 3750x (doc 16 §2)")

	-- Tachyon 1000, Beacon 50, Alien 1.5:
	-- 1000 * 50 * 1.5 = 75000x
	near(Equipment.composeBoostWithAlien(1000.0, 50.0, 1.5), 75000.0, 1e-12, "Tachyon 1000 + Beacon 50 + Alien 1.5 gives 75000x")
end

-- ============================================================================
-- Section 9: Habitat Capacity Multiplier & Ceil Rounding
-- ============================================================================
do
	-- Docs/09 §2, Docs/16 §1: "Pojemność kurnika xP; zachować końcowe ceil potwierdzone w GDR"
	eq(Equipment.applyHabCapacityMultiplier(0, 1.5), 0, "zero capacity returns 0")
	eq(Equipment.applyHabCapacityMultiplier(-10, 1.5), 0, "negative capacity returns 0")

	-- Exact whole numbers
	eq(Equipment.applyHabCapacityMultiplier(100, 1.5), 150, "100 * 1.5 = 150")
	eq(Equipment.applyHabCapacityMultiplier(250, 2.0), 500, "250 * 2.0 = 500")

	-- Fractional ceil rounding
	eq(Equipment.applyHabCapacityMultiplier(250, 1.001), 251, "250 * 1.001 = 250.25 -> ceil 251")
	eq(Equipment.applyHabCapacityMultiplier(100, 1.000001), 101, "100 * 1.000001 = 100.0001 -> ceil 101")
	eq(Equipment.applyHabCapacityMultiplier(1000, 1.3333), 1334, "1000 * 1.3333 = 1333.3 -> ceil 1334")
end

-- ============================================================================
-- Section 10: Incubator Disabled Rejection
-- ============================================================================
do
	local okInc, errInc = Equipment.incubatePet("tier1", "cash", 100)
	ok(not okInc, "incubator call rejected")
	eq(errInc, "INCUBATOR_DISABLED", "rejection reason is INCUBATOR_DISABLED")

	local okInc2, errInc2 = Equipment.incubatePet()
	ok(not okInc2, "incubator call without args rejected")
	eq(errInc2, "INCUBATOR_DISABLED", "rejection reason is INCUBATOR_DISABLED")
end

-- ============================================================================
-- Section 11: Embedded Test Catalog & All 7 Archetypes Multiplier Verification
-- ============================================================================
do
	local cat = Equipment.TEST_ONLY_CATALOG
	ok(cat.farmer_dog ~= nil, "farmer_dog in catalog")
	ok(cat.robo_cock ~= nil, "robo_cock in catalog")
	ok(cat.golden_pecker ~= nil, "golden_pecker in catalog")
	ok(cat.mega_rooster ~= nil, "mega_rooster in catalog")
	ok(cat.drone_hawk ~= nil, "drone_hawk in catalog")
	ok(cat.cosmic_phoenix ~= nil, "cosmic_phoenix in catalog")
	ok(cat.alien_clucker ~= nil, "alien_clucker in catalog")

	-- Test equipping each archetype from default catalog
	local speciesTests = {
		{ species = "farmer_dog", stat = "eggValueMult", expected = 1.5 },
		{ species = "robo_cock", stat = "layingRateMult", expected = 1.5 },
		{ species = "golden_pecker", stat = "ihrMult", expected = 1.5 },
		{ species = "mega_rooster", stat = "habCapacityMult", expected = 1.5 },
		{ species = "drone_hawk", stat = "eliteChanceMult", expected = 5.0 }, -- baseBonus 4.0 -> 1 + 4 = 5.0
		{ species = "cosmic_phoenix", stat = "prestigeEarningsMult", expected = 1.5 },
		{ species = "alien_clucker", stat = "boostBoostMult", expected = 1.5 },
	}

	for _, t in speciesTests do
		local inv = Equipment.createInventory()
		Equipment.addPet(inv, {
			uid = "test_" .. t.species,
			speciesId = t.species,
			tier = 1,
			variant = "normal",
			locked = false,
		})
		Equipment.equipPet(inv, "test_" .. t.species)
		local m = Equipment.calculatePetMultipliers(inv, { eggIndex = 0 })
		near(m[t.stat], t.expected, 1e-12, "default catalog bonus for " .. t.species)
	end
end

-- ============================================================================
-- Section 12: Multi-Archetype Multiplicative Layering Across Distinct Dimensions
-- ============================================================================
do
	-- Equip 3 distinct archetypes: farmer_dog (+50% egg value), golden_pecker (+50% IHR), mega_rooster (+50% hab cap)
	local inv = Equipment.createInventory()
	Equipment.addPet(inv, { uid = "d1", speciesId = "farmer_dog", tier = 1, variant = "normal", locked = false })
	Equipment.addPet(inv, { uid = "p1", speciesId = "golden_pecker", tier = 1, variant = "normal", locked = false })
	Equipment.addPet(inv, { uid = "r1", speciesId = "mega_rooster", tier = 1, variant = "normal", locked = false })

	Equipment.equipPet(inv, "d1")
	Equipment.equipPet(inv, "p1")
	Equipment.equipPet(inv, "r1")

	local m = Equipment.calculatePetMultipliers(inv, { eggIndex = 0 })
	near(m.eggValueMult, 1.5, 1e-12, "eggValueMult is 1.5")
	near(m.ihrMult, 1.5, 1e-12, "ihrMult is 1.5")
	near(m.habCapacityMult, 1.5, 1e-12, "habCapacityMult is 1.5")
	eq(m.layingRateMult, 1.0, "layingRateMult remains 1.0")
	eq(m.eliteChanceMult, 1.0, "eliteChanceMult remains 1.0")
	eq(m.prestigeEarningsMult, 1.0, "prestigeEarningsMult remains 1.0")
	eq(m.boostBoostMult, 1.0, "boostBoostMult remains 1.0")
end

-- ============================================================================
-- Section 13: Authoritative Server Egg Hatching & Pet Management (PROD-07)
-- ============================================================================
do
	local ServerBootstrap = require("../../src/server/Bootstrap")
	local server = ServerBootstrap.new({ initialNowMs = 5000000, petHatchTestPolicy={mode="INTERNAL_TEST_ONLY",costGE=100,draw=function()return 0.9 end} })
	local joinRes, err = server:playerJoined("7001")
	ok(joinRes ~= nil, "Player joined server for hatching test")

	local coordinator = server:getCoordinator("7001")
	ok(coordinator ~= nil, "Coordinator exists")
	local snaps = coordinator.snapshots()
	local prof = snaps.working or snaps.durable
	ok(prof ~= nil, "Player profile exists")

	-- 1. Initial attempt with default 10 GE fails (10 < 100)
	local okHatch0, errHatch0 = server:hatchPet("7001")
	eq(okHatch0, false, "Hatching with default GE fails")
	eq(errHatch0, "INSUFFICIENT_GE", "Error is INSUFFICIENT_GE")

	-- 2. Grant 240 GE via authoritative ClaimOffer (10 + 240 = 250 GE)
	eq(server:issueOffer("7001", "ge_grant_1", "ordinary", {rewardType="GE",amount="240",amountNumber=240}), true, "explicit test reward issued before claim")
	local okClaim, resClaim = server:claimOffer("7001", "ge_grant_1")
	eq(okClaim, true, "claimOffer granted 240 GE")
	prof = coordinator.snapshots().working or coordinator.snapshots().durable
	eq(prof.permanent.GE, "250", "Player GE balance is now 250")

	-- 3. Attempt with 250 GE succeeds and deducts 100 GE
	local okHatch1, resHatch1 = server:hatchPet("7001")
	eq(okHatch1, true, "Hatching with 250 GE succeeds")
	ok(resHatch1 ~= nil, "Hatch result returned")
	eq(resHatch1.costGE, 100, "Cost is 100 GE")

	prof = coordinator.snapshots().working or coordinator.snapshots().durable
	eq(prof.permanent.GE, "150", "GE balance reduced from 250 to 150")
	eq(prof.permanent.totalGESpent, "100", "totalGESpent incremented by 100")

	local hatchedPet1 = resHatch1.pet
	ok(hatchedPet1 ~= nil, "Hatched pet item exists")
	ok(prof.inventory.pets[hatchedPet1.uid] ~= nil, "Pet item added to profile inventory")
	eq(hatchedPet1.tier, 1, "Hatched pet tier is 1")
	eq(hatchedPet1.locked, false, "Hatched pet is initially unlocked")
	ok(Equipment.TEST_ONLY_CATALOG[hatchedPet1.speciesId] ~= nil, "Hatched pet species is in catalog")
	ok(hatchedPet1.variant == "normal" or hatchedPet1.variant == "golden" or hatchedPet1.variant == "rainbow", "Variant is valid")

	-- 4. Equip the hatched pet
	local okEquip, resEquip = server:equipPet("7001", hatchedPet1.uid)
	eq(okEquip, true, "Equip hatched pet succeeds")
	prof = coordinator.snapshots().working or coordinator.snapshots().durable
	ok(table.find(prof.inventory.equipped, hatchedPet1.uid) ~= nil, "Hatched pet is equipped in inventory")

	-- 5. Lock the hatched pet
	local okLock = server:togglePetLock("7001", hatchedPet1.uid, true)
	eq(okLock, true, "Toggle lock succeeds")
	prof = coordinator.snapshots().working or coordinator.snapshots().durable
	eq(prof.inventory.pets[hatchedPet1.uid].locked, true, "Pet is locked in inventory")

	-- 6. Second hatch succeeds: 150 GE -> 50 GE, totalGESpent -> 200
	local okHatch2, resHatch2 = server:hatchPet("7001")
	eq(okHatch2, true, "Second hatch succeeds")
	prof = coordinator.snapshots().working or coordinator.snapshots().durable
	eq(prof.permanent.GE, "50", "GE balance reduced from 150 to 50")
	eq(prof.permanent.totalGESpent, "200", "totalGESpent incremented to 200")

	-- 7. Third hatch fails with 50 GE
	local okHatch3, errHatch3 = server:hatchPet("7001")
	eq(okHatch3, false, "Third hatch with 50 GE fails")
	eq(errHatch3, "INSUFFICIENT_GE", "Error is INSUFFICIENT_GE")
	prof = coordinator.snapshots().working or coordinator.snapshots().durable
	eq(prof.permanent.GE, "50", "GE balance unchanged")
	eq(prof.permanent.totalGESpent, "200", "totalGESpent unchanged")
end

-- ============================================================================
-- Section 14: Save Results and Report
-- ============================================================================
fs.writeFile("build/pet_effects-results.json", serde.encode("json", {
	status = "PASS",
	level = "L",
	assertions = assertions,
	studioTested = false,
	dataStoreTested = false,
	scope = "NEXT-04 Pet inventory, equipment, slots, protections, and effect composition",
}, true))

print(string.format("Pet Effects PASS: %d assertions", assertions))
