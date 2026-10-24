--!nocheck
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local Fusion = require("../../src/server/pets/fusion")

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

local function makeInventory()
	return {
		pets = {},
		equipped = {},
		guarantees = {},
	}
end

local function addPet(inv, uid, speciesId, tier, variant, locked)
	inv.pets[uid] = {
		uid = uid,
		speciesId = speciesId or "farmer_dog",
		tier = tier or 1,
		variant = variant or "normal",
		locked = if locked ~= nil then locked else false,
	}
end

-- ============================================================================
-- Section 1: Copy Compatibility and Mismatch Rejection
-- ============================================================================
do
	local inv = makeInventory()
	addPet(inv, "base_1", "farmer_dog", 1, "normal", false)
	addPet(inv, "mat_diff_species", "robo_cock", 1, "normal", false)
	addPet(inv, "mat_diff_tier", "farmer_dog", 2, "normal", false)
	addPet(inv, "mat_diff_variant", "farmer_dog", 1, "golden", false)
	addPet(inv, "mat_ok_1", "farmer_dog", 1, "normal", false)
	addPet(inv, "mat_ok_2", "farmer_dog", 1, "normal", false)

	-- Species mismatch
	local ok1, err1 = Fusion.getFusionPreview(inv, "base_1", { "mat_ok_1", "mat_diff_species" })
	ok(not ok1, "species mismatch rejected")
	eq(err1, "SPECIES_MISMATCH", "species mismatch error matches")

	-- Tier mismatch
	local ok2, err2 = Fusion.getFusionPreview(inv, "base_1", { "mat_ok_1", "mat_diff_tier" })
	ok(not ok2, "tier mismatch rejected")
	eq(err2, "TIER_MISMATCH", "tier mismatch error matches")

	-- Variant mismatch
	local ok3, err3 = Fusion.getFusionPreview(inv, "base_1", { "mat_ok_1", "mat_diff_variant" })
	ok(not ok3, "variant mismatch rejected")
	eq(err3, "VARIANT_MISMATCH", "variant mismatch error matches")

	-- Valid matching copies
	local okVal, prev = Fusion.getFusionPreview(inv, "base_1", { "mat_ok_1", "mat_ok_2" })
	ok(okVal, "matching copies preview accepted")
	eq(prev.targetVariant, "golden", "normal base targets golden")
	eq(prev.requiredMaterials, 2, "golden requires 2 materials")
end

-- ============================================================================
-- Section 2: Equipped and Locked Protections
-- ============================================================================
do
	local inv = makeInventory()
	addPet(inv, "b_locked", "farmer_dog", 1, "normal", true)
	addPet(inv, "b_equipped", "farmer_dog", 1, "normal", false)
	addPet(inv, "m_locked", "farmer_dog", 1, "normal", true)
	addPet(inv, "m_equipped", "farmer_dog", 1, "normal", false)
	addPet(inv, "m_free_1", "farmer_dog", 1, "normal", false)
	addPet(inv, "m_free_2", "farmer_dog", 1, "normal", false)
	addPet(inv, "b_free", "farmer_dog", 1, "normal", false)

	table.insert(inv.equipped, "b_equipped")
	table.insert(inv.equipped, "m_equipped")

	-- Base locked
	local okBL, errBL = Fusion.getFusionPreview(inv, "b_locked", { "m_free_1", "m_free_2" })
	ok(not okBL, "locked base rejected")
	eq(errBL, "LOCKED_PET_CANNOT_BE_FUSED", "base locked error")

	-- Base equipped
	local okBE, errBE = Fusion.getFusionPreview(inv, "b_equipped", { "m_free_1", "m_free_2" })
	ok(not okBE, "equipped base rejected")
	eq(errBE, "EQUIPPED_PET_CANNOT_BE_FUSED", "base equipped error")

	-- Material locked
	local okML, errML = Fusion.getFusionPreview(inv, "b_free", { "m_free_1", "m_locked" })
	ok(not okML, "locked material rejected")
	eq(errML, "LOCKED_PET_CANNOT_BE_FUSED", "material locked error")

	-- Material equipped
	local okME, errME = Fusion.getFusionPreview(inv, "b_free", { "m_free_1", "m_equipped" })
	ok(not okME, "equipped material rejected")
	eq(errME, "EQUIPPED_PET_CANNOT_BE_FUSED", "material equipped error")

	-- Ghost base pet
	local okGB, errGB = Fusion.getFusionPreview(inv, "ghost_base", { "m_free_1", "m_free_2" })
	ok(not okGB, "ghost base rejected")
	eq(errGB, "BASE_PET_NOT_FOUND", "ghost base error")

	-- Ghost material pet
	local okGM, errGM = Fusion.getFusionPreview(inv, "b_free", { "m_free_1", "ghost_mat" })
	ok(not okGM, "ghost material rejected")
	eq(errGM, "MATERIAL_PET_NOT_FOUND", "ghost material error")
end

-- ============================================================================
-- Section 3: Self-Reference, Duplicate Materials, and Count Requirements
-- ============================================================================
do
	local inv = makeInventory()
	addPet(inv, "b1", "farmer_dog", 1, "normal", false)
	addPet(inv, "m1", "farmer_dog", 1, "normal", false)
	addPet(inv, "m2", "farmer_dog", 1, "normal", false)
	addPet(inv, "m3", "farmer_dog", 1, "normal", false)

	-- Base pet inside materials
	local okSelf, errSelf = Fusion.getFusionPreview(inv, "b1", { "b1", "m1" })
	ok(not okSelf, "base pet in materials rejected")
	eq(errSelf, "BASE_PET_IN_MATERIALS", "base pet in materials error")

	-- Duplicate material UID
	local okDup, errDup = Fusion.getFusionPreview(inv, "b1", { "m1", "m1" })
	ok(not okDup, "duplicate material UID rejected")
	eq(errDup, "DUPLICATE_MATERIAL_UID", "duplicate material error")

	-- Insufficient materials (1 instead of 2)
	local okLess, errLess = Fusion.getFusionPreview(inv, "b1", { "m1" })
	ok(not okLess, "insufficient materials rejected")
	eq(errLess, "INSUFFICIENT_MATERIALS", "insufficient materials error")

	-- Excess materials (3 instead of 2)
	local okMore, errMore = Fusion.getFusionPreview(inv, "b1", { "m1", "m2", "m3" })
	ok(not okMore, "excess materials rejected")
	eq(errMore, "EXCESS_MATERIALS", "excess materials error")
end

-- ============================================================================
-- Section 4: Rainbow Terminal Variant Protection
-- ============================================================================
do
	local inv = makeInventory()
	addPet(inv, "r_base", "farmer_dog", 1, "rainbow", false)
	addPet(inv, "r_mat1", "farmer_dog", 1, "rainbow", false)
	addPet(inv, "r_mat2", "farmer_dog", 1, "rainbow", false)

	local okR, errR = Fusion.getFusionPreview(inv, "r_base", { "r_mat1", "r_mat2" })
	ok(not okR, "rainbow base rejected from further evolution")
	eq(errR, "MAX_VARIANT_REACHED", "max variant reached error matches")

	local execR, resR = Fusion.executeFusion(inv, "r_base", { "r_mat1", "r_mat2" })
	ok(not execR, "executeFusion on rainbow rejected")
	eq(resR, "MAX_VARIANT_REACHED", "execute error matches")
end

-- ============================================================================
-- Section 5: Successful Fusion Execution (Normal -> Golden and Golden -> Rainbow)
-- ============================================================================
do
	-- Test Normal -> Golden
	local inv = makeInventory()
	addPet(inv, "base_dog", "farmer_dog", 1, "normal", false)
	addPet(inv, "mat_1", "farmer_dog", 1, "normal", false)
	addPet(inv, "mat_2", "farmer_dog", 1, "normal", false)
	inv.guarantees["farmer_dog:1:golden"] = 2

	-- Execute with roll = 0.0 (guaranteed success)
	local okExec, res = Fusion.executeFusion(inv, "base_dog", { "mat_1", "mat_2" }, false, nil, 0.0)
	ok(okExec, "executeFusion executed")
	ok(res.success, "fusion succeeded")
	eq(res.status, "SUCCESS", "status is SUCCESS")

	-- Base pet mutation check
	eq(res.pet.uid, "base_dog", "base UID preserved")
	eq(res.pet.speciesId, "farmer_dog", "species preserved")
	eq(res.pet.tier, 1, "tier preserved")
	eq(res.pet.variant, "golden", "variant updated to golden")
	eq(inv.pets["base_dog"].variant, "golden", "inventory base pet variant is golden")

	-- Consumed materials check
	eq(inv.pets["mat_1"], nil, "mat_1 removed from inventory")
	eq(inv.pets["mat_2"], nil, "mat_2 removed from inventory")

	-- Guarantee counter reset to 0
	eq(inv.guarantees["farmer_dog:1:golden"], 0, "guarantee counter reset to 0 after success")

	-- Now test Golden -> Rainbow (requires 3 materials in TEST_ONLY_RECIPES)
	addPet(inv, "gold_m1", "farmer_dog", 1, "golden", false)
	addPet(inv, "gold_m2", "farmer_dog", 1, "golden", false)
	addPet(inv, "gold_m3", "farmer_dog", 1, "golden", false)

	local okRain, resRain = Fusion.executeFusion(inv, "base_dog", { "gold_m1", "gold_m2", "gold_m3" }, false, nil, 0.0)
	ok(okRain, "golden->rainbow execution executed")
	ok(resRain.success, "golden->rainbow succeeded")
	eq(resRain.pet.variant, "rainbow", "variant updated to rainbow")
	eq(inv.pets["base_dog"].variant, "rainbow", "inventory base pet is now rainbow")
	eq(inv.pets["gold_m1"], nil, "gold_m1 consumed")
	eq(inv.pets["gold_m2"], nil, "gold_m2 consumed")
	eq(inv.pets["gold_m3"], nil, "gold_m3 consumed")
end

-- ============================================================================
-- Section 6: Failure Fusion Execution (Base Pet Preserved, Counter Incremented)
-- ============================================================================
do
	local inv = makeInventory()
	addPet(inv, "base_survivor", "farmer_dog", 1, "normal", false)
	addPet(inv, "sacrifice_1", "farmer_dog", 1, "normal", false)
	addPet(inv, "sacrifice_2", "farmer_dog", 1, "normal", false)
	inv.guarantees["farmer_dog:1:golden"] = 1

	-- Roll = 0.99 (guaranteed failure for base chance 0.40)
	local okExec, res = Fusion.executeFusion(inv, "base_survivor", { "sacrifice_1", "sacrifice_2" }, false, nil, 0.99)
	ok(okExec, "fusion execution succeeded technically")
	ok(not res.success, "roll outcome is failure")
	eq(res.status, "FAILURE", "status is FAILURE")

	-- Crucial invariant: Base pet preserved intact!
	ok(inv.pets["base_survivor"] ~= nil, "base pet still exists in inventory")
	eq(inv.pets["base_survivor"].variant, "normal", "base pet variant unchanged")
	eq(res.pet.variant, "normal", "result pet variant is normal")

	-- Materials consumed
	eq(inv.pets["sacrifice_1"], nil, "sacrifice_1 consumed")
	eq(inv.pets["sacrifice_2"], nil, "sacrifice_2 consumed")

	-- Guarantee counter incremented
	eq(inv.guarantees["farmer_dog:1:golden"], 2, "guarantee counter incremented from 1 to 2")
	eq(res.guaranteeCount, 2, "result guaranteeCount is 2")
end

-- ============================================================================
-- Section 7: Permanent Guarantee Threshold (N failures -> 100% chance)
-- ============================================================================
do
	local customRecipes = {
		golden = {
			requiredMaterials = 2,
			baseChance = 0.20,
			guaranteeThreshold = 3, -- 3 failures gives guarantee
		},
	}

	local inv = makeInventory()
	addPet(inv, "hero_pet", "farmer_dog", 1, "normal", false)

	-- Initially at 0 failures: chance 0.20, not guaranteed
	addPet(inv, "m_a1", "farmer_dog", 1, "normal", false)
	addPet(inv, "m_a2", "farmer_dog", 1, "normal", false)
	local okP0, prev0 = Fusion.getFusionPreview(inv, "hero_pet", { "m_a1", "m_a2" }, false, customRecipes)
	ok(okP0, "preview 0")
	eq(prev0.isGuaranteed, false, "initially not guaranteed")
	near(prev0.finalChance, 0.20, 1e-12, "initial chance 0.20")

	-- Fail 1
	Fusion.executeFusion(inv, "hero_pet", { "m_a1", "m_a2" }, false, customRecipes, 0.99)
	eq(inv.guarantees["farmer_dog:1:golden"], 1, "counter is 1")

	-- Fail 2
	addPet(inv, "m_b1", "farmer_dog", 1, "normal", false)
	addPet(inv, "m_b2", "farmer_dog", 1, "normal", false)
	Fusion.executeFusion(inv, "hero_pet", { "m_b1", "m_b2" }, false, customRecipes, 0.99)
	eq(inv.guarantees["farmer_dog:1:golden"], 2, "counter is 2")

	-- Fail 3
	addPet(inv, "m_c1", "farmer_dog", 1, "normal", false)
	addPet(inv, "m_c2", "farmer_dog", 1, "normal", false)
	Fusion.executeFusion(inv, "hero_pet", { "m_c1", "m_c2" }, false, customRecipes, 0.99)
	eq(inv.guarantees["farmer_dog:1:golden"], 3, "counter reached threshold 3")

	-- Now counter >= threshold: 100% guarantee active!
	addPet(inv, "m_g1", "farmer_dog", 1, "normal", false)
	addPet(inv, "m_g2", "farmer_dog", 1, "normal", false)
	local okPG, prevG = Fusion.getFusionPreview(inv, "hero_pet", { "m_g1", "m_g2" }, false, customRecipes)
	ok(okPG, "preview with guarantee")
	eq(prevG.isGuaranteed, true, "isGuaranteed is true")
	eq(prevG.finalChance, 1.0, "finalChance is 1.0 (100%)")

	-- Even with roll = 0.99, execution MUST succeed!
	local okGuarExec, resGuar = Fusion.executeFusion(inv, "hero_pet", { "m_g1", "m_g2" }, false, customRecipes, 0.99)
	ok(okGuarExec, "guaranteed execution executed")
	ok(resGuar.success, "guaranteed execution succeeded despite high roll")
	eq(resGuar.isGuaranteed, true, "resGuar.isGuaranteed is true")
	eq(resGuar.pet.variant, "golden", "hero_pet evolved to golden")
	eq(inv.guarantees["farmer_dog:1:golden"], 0, "guarantee counter reset to 0")

	-- Guarantee does NOT bypass material validation:
	inv.guarantees["farmer_dog:1:golden"] = 5 -- high counter
	addPet(inv, "hero2", "farmer_dog", 1, "normal", false)
	local okNoMat, errNoMat = Fusion.getFusionPreview(inv, "hero2", {}, false, customRecipes)
	ok(not okNoMat, "empty materials still rejected even with guarantee")
	eq(errNoMat, "INSUFFICIENT_MATERIALS", "insufficient materials error")
end

-- ============================================================================
-- Section 8: Pro Pass (+10 Percentage Points) Bonus
-- ============================================================================
do
	local customRecipes = {
		golden = {
			requiredMaterials = 2,
			baseChance = 0.40,
			guaranteeThreshold = 5,
		},
		high_chance = {
			requiredMaterials = 2,
			baseChance = 0.95,
			guaranteeThreshold = 5,
		},
	}

	local inv = makeInventory()
	addPet(inv, "b_pro", "farmer_dog", 1, "normal", false)
	addPet(inv, "m_p1", "farmer_dog", 1, "normal", false)
	addPet(inv, "m_p2", "farmer_dog", 1, "normal", false)

	-- Without Pro
	local okStd, pStd = Fusion.getFusionPreview(inv, "b_pro", { "m_p1", "m_p2" }, false, customRecipes)
	ok(okStd, "standard preview")
	eq(pStd.proBonus, 0.0, "proBonus is 0.0 without Pro")
	near(pStd.finalChance, 0.40, 1e-12, "finalChance is 0.40 without Pro")

	-- With Pro (isPro = true)
	local okPro, pPro = Fusion.getFusionPreview(inv, "b_pro", { "m_p1", "m_p2" }, true, customRecipes)
	ok(okPro, "pro preview")
	near(pPro.proBonus, 0.10, 1e-12, "proBonus is 0.10 with Pro")
	near(pPro.finalChance, 0.50, 1e-12, "finalChance is 0.40 + 0.10 = 0.50 with Pro")

	-- With Pro as number 1
	local okProNum, pProNum = Fusion.getFusionPreview(inv, "b_pro", { "m_p1", "m_p2" }, 1, customRecipes)
	near(pProNum.finalChance, 0.50, 1e-12, "finalChance with permit 1 is 0.50")

	-- Cap at 1.0 (100%): base 0.95 + 0.10 = 1.05 -> capped at 1.00
	local capRecipe = {
		golden = {
			requiredMaterials = 2,
			baseChance = 0.95,
			guaranteeThreshold = 5,
		},
	}
	local okCap, pCap = Fusion.getFusionPreview(inv, "b_pro", { "m_p1", "m_p2" }, true, capRecipe)
	ok(okCap, "cap preview")
	eq(pCap.finalChance, 1.0, "finalChance capped at 1.00")
end

-- ============================================================================
-- Section 9: Guarantee Key Independence
-- ============================================================================
do
	local keyDogT1 = Fusion.getGuaranteeKey("farmer_dog", 1, "golden")
	local keyDogT2 = Fusion.getGuaranteeKey("farmer_dog", 2, "golden")
	local keyCockT1 = Fusion.getGuaranteeKey("robo_cock", 1, "golden")
	local keyDogRain = Fusion.getGuaranteeKey("farmer_dog", 1, "rainbow")

	eq(keyDogT1, "farmer_dog:1:golden", "dog t1 golden key matches")
	eq(keyDogT2, "farmer_dog:2:golden", "dog t2 golden key matches")
	eq(keyCockT1, "robo_cock:1:golden", "cock t1 golden key matches")
	eq(keyDogRain, "farmer_dog:1:rainbow", "dog t1 rainbow key matches")

	ok(keyDogT1 ~= keyDogT2, "tier keys are distinct")
	ok(keyDogT1 ~= keyCockT1, "species keys are distinct")
	ok(keyDogT1 ~= keyDogRain, "target variant keys are distinct")

	local inv = makeInventory()
	addPet(inv, "dog_base", "farmer_dog", 1, "normal", false)
	addPet(inv, "dog_m1", "farmer_dog", 1, "normal", false)
	addPet(inv, "dog_m2", "farmer_dog", 1, "normal", false)

	-- Fail on dog T1 golden
	Fusion.executeFusion(inv, "dog_base", { "dog_m1", "dog_m2" }, false, nil, 0.99)
	eq(inv.guarantees[keyDogT1], 1, "dog t1 golden incremented to 1")
	eq(inv.guarantees[keyDogT2], nil, "dog t2 golden remains nil")
	eq(inv.guarantees[keyCockT1], nil, "cock t1 golden remains nil")
	eq(inv.guarantees[keyDogRain], nil, "dog t1 rainbow remains nil")
end

-- ============================================================================
-- Section 10: Specific Tier / Species Recipe Lookup
-- ============================================================================
do
	local multiTierRecipes = {
		["1:golden"] = { requiredMaterials = 2, baseChance = 0.50, guaranteeThreshold = 3 },
		["2:golden"] = { requiredMaterials = 3, baseChance = 0.35, guaranteeThreshold = 6 },
	}

	local inv = makeInventory()
	addPet(inv, "d1", "farmer_dog", 1, "normal", false)
	addPet(inv, "d1_m1", "farmer_dog", 1, "normal", false)
	addPet(inv, "d1_m2", "farmer_dog", 1, "normal", false)

	addPet(inv, "d2", "farmer_dog", 2, "normal", false)
	addPet(inv, "d2_m1", "farmer_dog", 2, "normal", false)
	addPet(inv, "d2_m2", "farmer_dog", 2, "normal", false)
	addPet(inv, "d2_m3", "farmer_dog", 2, "normal", false)

	local okT1, pT1 = Fusion.getFusionPreview(inv, "d1", { "d1_m1", "d1_m2" }, false, multiTierRecipes)
	ok(okT1, "tier 1 recipe lookup")
	eq(pT1.requiredMaterials, 2, "tier 1 requires 2")
	near(pT1.baseChance, 0.50, 1e-12, "tier 1 chance is 0.50")

	local okT2, pT2 = Fusion.getFusionPreview(inv, "d2", { "d2_m1", "d2_m2", "d2_m3" }, false, multiTierRecipes)
	ok(okT2, "tier 2 recipe lookup")
	eq(pT2.requiredMaterials, 3, "tier 2 requires 3")
	near(pT2.baseChance, 0.35, 1e-12, "tier 2 chance is 0.35")
end

-- ============================================================================
-- Section 11: Save Results and Report
-- ============================================================================
fs.writeFile("build/fusion-results.json", serde.encode("json", {
	status = "PASS",
	level = "L",
	assertions = assertions,
	studioTested = false,
	dataStoreTested = false,
	scope = "NEXT-05 Pet fusion, copy validation, slot/lock protections, Pro pass bonus, and guarantee counters",
}, true))

print(string.format("Pet Fusion PASS: %d assertions", assertions))
