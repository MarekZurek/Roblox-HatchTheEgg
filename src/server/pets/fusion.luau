--!strict
-- fusion.luau: authoritative server domain logic for pet fusion/evolution and permanent guarantee counters.
-- Spec: docs/22 §1; docs/23; docs/27 §4; NEXT-05 (#30).

local Fusion = {
	VERSION = 1,
}

export type PetVariant = "normal" | "golden" | "rainbow"

export type PetItem = {
	uid: string,
	speciesId: string,
	tier: number,
	variant: PetVariant,
	locked: boolean,
	customBonus: any?,
}

export type PetInventory = {
	pets: { [string]: PetItem },
	equipped: { string }?,
	guarantees: { [string]: number }?,
}

export type FusionRecipe = {
	requiredMaterials: number,
	baseChance: number,
	guaranteeThreshold: number,
}

export type FusionPreview = {
	basePet: PetItem,
	targetVariant: PetVariant,
	requiredMaterials: number,
	baseChance: number,
	proBonus: number,
	finalChance: number,
	isGuaranteed: boolean,
	guaranteeKey: string,
	currentFailCount: number,
	guaranteeThreshold: number,
}

export type FusionResult = {
	success: boolean,
	status: "SUCCESS" | "FAILURE",
	pet: PetItem,
	consumedMaterials: { string },
	guaranteeCount: number,
	isGuaranteed: boolean,
	targetVariant: PetVariant,
}

-- Embedded test-only recipes for Normal -> Golden and Golden -> Rainbow (docs/22 §1, NEXT-05)
local TEST_ONLY_RECIPES: { [string]: FusionRecipe } = table.freeze({
	golden = table.freeze({
		requiredMaterials = 2,
		baseChance = 0.40,
		guaranteeThreshold = 5,
	}),
	rainbow = table.freeze({
		requiredMaterials = 3,
		baseChance = 0.25,
		guaranteeThreshold = 8,
	}),
})

-- Helper to look up recipe from supplied table or default TEST_ONLY_RECIPES
local function lookupRecipe(recipes: any?, tier: number, targetVariant: string, speciesId: string?): FusionRecipe?
	local rTable = recipes or TEST_ONLY_RECIPES
	if type(rTable) ~= "table" then
		return nil
	end

	if type(rTable.getRecipe) == "function" then
		local r = rTable.getRecipe(tier, targetVariant, speciesId)
		if r then
			return r
		end
	end

	if speciesId then
		local specKey = string.format("%s:%d:%s", speciesId, tier, targetVariant)
		if rTable[specKey] then
			return rTable[specKey]
		end
	end

	local tierKey = string.format("%d:%s", tier, targetVariant)
	if rTable[tierKey] then
		return rTable[tierKey]
	end

	if rTable[targetVariant] then
		return rTable[targetVariant]
	end

	return nil
end

-- Checks if a pet UID is currently equipped
local function isPetEquipped(inventory: any, uid: string): boolean
	if inventory and inventory.equipped and type(inventory.equipped) == "table" then
		for _, eqUid in inventory.equipped do
			if eqUid == uid then
				return true
			end
		end
	end
	return false
end

-- Generates guarantee counter key formatted as speciesId:tier:targetVariant
local function getGuaranteeKey(speciesId: string, tier: number, targetVariant: string): string
	return string.format("%s:%d:%s", speciesId, tier, targetVariant)
end

-- Validates fusion eligibility and returns preview data
local function getFusionPreview(
	inventory: any,
	baseUid: string,
	materialUids: { string },
	isPro: any?,
	recipes: any?
): (boolean, any)
	if type(inventory) ~= "table" or type(inventory.pets) ~= "table" then
		return false, "INVALID_INVENTORY"
	end
	if type(baseUid) ~= "string" or #baseUid == 0 then
		return false, "INVALID_BASE_UID"
	end
	if type(materialUids) ~= "table" then
		return false, "INVALID_MATERIALS_TABLE"
	end

	local basePet = inventory.pets[baseUid]
	if not basePet then
		return false, "BASE_PET_NOT_FOUND"
	end

	-- Equipped protection
	if isPetEquipped(inventory, baseUid) then
		return false, "EQUIPPED_PET_CANNOT_BE_FUSED"
	end

	-- Lock protection
	if basePet.locked == true then
		return false, "LOCKED_PET_CANNOT_BE_FUSED"
	end

	-- Target variant determination
	local targetVariant: PetVariant
	if basePet.variant == "normal" then
		targetVariant = "golden"
	elseif basePet.variant == "golden" then
		targetVariant = "rainbow"
	elseif basePet.variant == "rainbow" then
		return false, "MAX_VARIANT_REACHED"
	else
		return false, "INVALID_VARIANT"
	end

	-- Recipe lookup
	local recipe = lookupRecipe(recipes, basePet.tier, targetVariant, basePet.speciesId)
	if not recipe then
		return false, "RECIPE_NOT_FOUND"
	end

	-- Material count requirement
	if #materialUids < recipe.requiredMaterials then
		return false, "INSUFFICIENT_MATERIALS"
	end
	if #materialUids > recipe.requiredMaterials then
		return false, "EXCESS_MATERIALS"
	end

	-- Material validation
	local seenUids: { [string]: boolean } = {}
	for _, mUid in materialUids do
		if type(mUid) ~= "string" or #mUid == 0 then
			return false, "INVALID_MATERIAL_UID"
		end
		if mUid == baseUid then
			return false, "BASE_PET_IN_MATERIALS"
		end
		if seenUids[mUid] then
			return false, "DUPLICATE_MATERIAL_UID"
		end
		seenUids[mUid] = true

		local matPet = inventory.pets[mUid]
		if not matPet then
			return false, "MATERIAL_PET_NOT_FOUND"
		end
		if matPet.locked == true then
			return false, "LOCKED_PET_CANNOT_BE_FUSED"
		end
		if isPetEquipped(inventory, mUid) then
			return false, "EQUIPPED_PET_CANNOT_BE_FUSED"
		end

		-- Strict copy consistency: same species, same tier, same input variant
		if matPet.speciesId ~= basePet.speciesId then
			return false, "SPECIES_MISMATCH"
		end
		if matPet.tier ~= basePet.tier then
			return false, "TIER_MISMATCH"
		end
		if matPet.variant ~= basePet.variant then
			return false, "VARIANT_MISMATCH"
		end
	end

	-- Guarantee counter lookup
	local guaranteeKey = getGuaranteeKey(basePet.speciesId, basePet.tier, targetVariant)
	local guarantees = inventory.guarantees or {}
	local currentFails = guarantees[guaranteeKey] or 0
	local isGuaranteed = (currentFails >= recipe.guaranteeThreshold)

	-- Pro pass bonus: +10 percentage points (+0.10)
	local isProBool = (isPro == true) or (type(isPro) == "number" and isPro >= 1)
	local proBonus = if (isProBool and not isGuaranteed) then 0.10 else 0.0

	local finalChance = if isGuaranteed
		then 1.0
		else math.min(1.0, math.max(0.0, recipe.baseChance + proBonus))

	local preview: FusionPreview = {
		basePet = basePet,
		targetVariant = targetVariant,
		requiredMaterials = recipe.requiredMaterials,
		baseChance = recipe.baseChance,
		proBonus = proBonus,
		finalChance = finalChance,
		isGuaranteed = isGuaranteed,
		guaranteeKey = guaranteeKey,
		currentFailCount = currentFails,
		guaranteeThreshold = recipe.guaranteeThreshold,
	}

	return true, preview
end

-- Executes authoritative fusion transaction
local function executeFusion(
	inventory: any,
	baseUid: string,
	materialUids: { string },
	isPro: any?,
	recipes: any?,
	roll: number?
): (boolean, any)
	local okPreview, previewOrErr = getFusionPreview(inventory, baseUid, materialUids, isPro, recipes)
	if not okPreview then
		return false, previewOrErr
	end

	local preview: FusionPreview = previewOrErr
	inventory.guarantees = inventory.guarantees or {}

	-- Roll evaluation
	local actualRoll = roll or math.random()
	local isSuccess = preview.isGuaranteed or (actualRoll < preview.finalChance)

	-- Consume materials
	for _, mUid in materialUids do
		inventory.pets[mUid] = nil
	end

	local basePet = inventory.pets[baseUid]

	if isSuccess then
		-- Success: mutate base pet variant, reset guarantee counter to 0
		basePet.variant = preview.targetVariant
		inventory.guarantees[preview.guaranteeKey] = 0

		local result: FusionResult = {
			success = true,
			status = "SUCCESS",
			pet = basePet,
			consumedMaterials = materialUids,
			guaranteeCount = 0,
			isGuaranteed = preview.isGuaranteed,
			targetVariant = preview.targetVariant,
		}
		return true, result
	else
		-- Failure: base pet preserved intact, guarantee counter incremented by 1
		local newCount = preview.currentFailCount + 1
		inventory.guarantees[preview.guaranteeKey] = newCount

		local result: FusionResult = {
			success = false,
			status = "FAILURE",
			pet = basePet,
			consumedMaterials = materialUids,
			guaranteeCount = newCount,
			isGuaranteed = false,
			targetVariant = preview.targetVariant,
		}
		return true, result
	end
end

Fusion.TEST_ONLY_RECIPES = TEST_ONLY_RECIPES
Fusion.getGuaranteeKey = getGuaranteeKey
Fusion.getFusionPreview = getFusionPreview
Fusion.executeFusion = executeFusion

return table.freeze(Fusion)
