--!strict
-- equipment.luau: authoritative server domain logic for pet inventory, equipment, and effect composition.
-- Spec: docs/09 §1, §2; docs/16 §1, §2; docs/22; docs/23; NEXT-04 (#29).

local Equipment = {
	VERSION = 1,
}

export type PetVariant = "normal" | "golden" | "rainbow"

export type PetItem = {
	uid: string,
	speciesId: string,
	tier: number, -- 1..5
	variant: PetVariant,
	locked: boolean,
	customBonus: ({ [string]: number } | number)?,
}

export type PetInventory = {
	pets: { [string]: PetItem },
	equipped: { string },
	guarantees: { [string]: number }?,
}

export type PetMultipliers = {
	eggValueMult: number,
	layingRateMult: number,
	ihrMult: number,
	habCapacityMult: number,
	eliteChanceMult: number,
	prestigeEarningsMult: number,
	boostBoostMult: number,
}

export type PetSpeciesDef = {
	id: string,
	stat: string?,
	baseBonus: number?,
	tierBonuses: { [number]: number }?,
	bonuses: { [string]: number }?,
}

-- Embedded test-only catalog of archetypes (docs/09 §2, docs/16 §1, NEXT-04)
local TEST_ONLY_CATALOG: { [string]: PetSpeciesDef } = table.freeze({
	farmer_dog = table.freeze({
		id = "farmer_dog",
		stat = "eggValueMult",
		baseBonus = 0.5,
	}),
	farm_pup = table.freeze({
		id = "farm_pup",
		stat = "eggValueMult",
		baseBonus = 0.5,
	}),
	robo_cock = table.freeze({
		id = "robo_cock",
		stat = "layingRateMult",
		baseBonus = 0.5,
	}),
	rooster_king = table.freeze({
		id = "rooster_king",
		stat = "layingRateMult",
		baseBonus = 0.5,
	}),
	golden_pecker = table.freeze({
		id = "golden_pecker",
		stat = "ihrMult",
		baseBonus = 0.5,
	}),
	speedy_chick = table.freeze({
		id = "speedy_chick",
		stat = "ihrMult",
		baseBonus = 0.5,
	}),
	mega_rooster = table.freeze({
		id = "mega_rooster",
		stat = "habCapacityMult",
		baseBonus = 0.5,
	}),
	heavy_cow = table.freeze({
		id = "heavy_cow",
		stat = "habCapacityMult",
		baseBonus = 0.5,
	}),
	drone_hawk = table.freeze({
		id = "drone_hawk",
		stat = "eliteChanceMult",
		baseBonus = 4.0, -- 5x elite chance corresponds to b = 4 (doc 16 §1)
	}),
	cosmic_phoenix = table.freeze({
		id = "cosmic_phoenix",
		stat = "prestigeEarningsMult",
		baseBonus = 0.5,
	}),
	alien_clucker = table.freeze({
		id = "alien_clucker",
		stat = "boostBoostMult",
		baseBonus = 0.5,
	}),
})

-- Validates pet item fields according to specification.
local function validatePet(pet: any): (boolean, string?)
	if type(pet) ~= "table" then
		return false, "INVALID_PET_NOT_A_TABLE"
	end
	if type(pet.uid) ~= "string" or #pet.uid == 0 then
		return false, "INVALID_PET_UID"
	end
	if type(pet.speciesId) ~= "string" or #pet.speciesId == 0 then
		return false, "INVALID_PET_SPECIES_ID"
	end
	if type(pet.tier) ~= "number" or pet.tier < 1 or pet.tier > 5 or pet.tier % 1 ~= 0 then
		return false, "INVALID_PET_TIER"
	end
	if pet.variant ~= "normal" and pet.variant ~= "golden" and pet.variant ~= "rainbow" then
		return false, "INVALID_PET_VARIANT"
	end
	if type(pet.locked) ~= "boolean" then
		return false, "INVALID_PET_LOCKED"
	end
	if pet.customBonus ~= nil then
		if type(pet.customBonus) ~= "table" and type(pet.customBonus) ~= "number" then
			return false, "INVALID_PET_CUSTOM_BONUS"
		end
		if type(pet.customBonus) == "table" then
			for k, v in pet.customBonus do
				if type(k) ~= "string" or type(v) ~= "number" then
					return false, "INVALID_PET_CUSTOM_BONUS_ENTRY"
				end
			end
		end
	end
	return true, nil
end

-- Creates an empty pet inventory.
local function createInventory(): PetInventory
	return {
		pets = {},
		equipped = {},
		guarantees = {},
	}
end

-- Returns maximum equipment slots: standard 3, Pro 5 (docs/09 §3, docs/16 §1).
local function getMaxSlots(isPro: any?): number
	if isPro == true then
		return 5
	elseif type(isPro) == "number" and isPro >= 1 then
		return 5
	end
	return 3
end

-- Adds a pet to inventory. Rejects duplicate UID or invalid data.
local function addPet(inventory: any, pet: any): (boolean, string?)
	if type(inventory) ~= "table" or type(inventory.pets) ~= "table" then
		return false, "INVALID_INVENTORY"
	end
	local valid, err = validatePet(pet)
	if not valid then
		return false, err or "INVALID_PET_DATA"
	end
	if inventory.pets[pet.uid] ~= nil then
		return false, "DUPLICATE_UID"
	end
	inventory.pets[pet.uid] = pet
	return true, pet.uid
end

-- Removes a pet from inventory. Protected against removing locked or equipped pets.
local function removePet(inventory: any, uid: string): (boolean, string?)
	if type(inventory) ~= "table" or type(inventory.pets) ~= "table" or type(uid) ~= "string" then
		return false, "INVALID_ARGUMENTS"
	end
	local pet = inventory.pets[uid]
	if not pet then
		return false, "PET_NOT_FOUND"
	end
	if pet.locked == true then
		return false, "PET_LOCKED"
	end
	if inventory.equipped and type(inventory.equipped) == "table" then
		for _, eqUid in inventory.equipped do
			if eqUid == uid then
				return false, "PET_EQUIPPED"
			end
		end
	end
	inventory.pets[uid] = nil
	return true, nil
end

-- Sets lock status for a pet.
local function setPetLock(inventory: any, uid: string, locked: boolean): (boolean, string?)
	if type(inventory) ~= "table" or type(inventory.pets) ~= "table" or type(uid) ~= "string" or type(locked) ~= "boolean" then
		return false, "INVALID_ARGUMENTS"
	end
	local pet = inventory.pets[uid]
	if not pet then
		return false, "PET_NOT_FOUND"
	end
	pet.locked = locked
	return true, nil
end

-- Equips a pet. Checks presence, duplicate prevention, and slot limits.
local function equipPet(inventory: any, uid: string, maxSlotsOrIsPro: any?): (boolean, string?)
	if type(inventory) ~= "table" or type(inventory.pets) ~= "table" or type(inventory.equipped) ~= "table" or type(uid) ~= "string" then
		return false, "INVALID_ARGUMENTS"
	end
	local pet = inventory.pets[uid]
	if not pet then
		return false, "PET_NOT_FOUND"
	end
	local maxSlots = if type(maxSlotsOrIsPro) == "number" then maxSlotsOrIsPro else getMaxSlots(maxSlotsOrIsPro)

	for _, eqUid in inventory.equipped do
		if eqUid == uid then
			return false, "ALREADY_EQUIPPED"
		end
	end

	if #inventory.equipped >= maxSlots then
		return false, "MAX_SLOTS_REACHED"
	end

	table.insert(inventory.equipped, uid)
	return true, nil
end

-- Unequips a pet.
local function unequipPet(inventory: any, uid: string): (boolean, string?)
	if type(inventory) ~= "table" or type(inventory.equipped) ~= "table" or type(uid) ~= "string" then
		return false, "INVALID_ARGUMENTS"
	end
	for i, eqUid in inventory.equipped do
		if eqUid == uid then
			table.remove(inventory.equipped, i)
			return true, nil
		end
	end
	return false, "NOT_EQUIPPED"
end

-- Incubation is disabled in v1 until balance is formally approved (docs/09 §3, docs/18).
local function incubatePet(...: any): (boolean, string)
	return false, "INCUBATOR_DISABLED"
end

-- Calculates pet multipliers across all 7 confirmed dimensions.
-- Formula: P[d] = 1.0 + sum(b_i[d])
-- Golden variant: b_base * 2.0; Rainbow variant: b_base * 3.5.
-- Enlightenment: all multipliers neutralized to 1.0x, pets remain equipped.
local function calculatePetMultipliers(inventory: any, farm: any?, catalog: any?): PetMultipliers
	local multipliers: PetMultipliers = {
		eggValueMult = 1.0,
		layingRateMult = 1.0,
		ihrMult = 1.0,
		habCapacityMult = 1.0,
		eliteChanceMult = 1.0,
		prestigeEarningsMult = 1.0,
		boostBoostMult = 1.0,
	}

	-- Enlightenment check (docs/11 §4, docs/16 §1)
	local eggIndex = if farm then (farm.eggIndex or 0) else 0
	local isEnlightenment = (eggIndex == 18) or (farm ~= nil and farm.isEnlightenment == true)
	if isEnlightenment then
		return multipliers
	end

	if not inventory or not inventory.equipped or not inventory.pets then
		return multipliers
	end

	local bonusSum: { [string]: number } = {
		eggValueMult = 0.0,
		layingRateMult = 0.0,
		ihrMult = 0.0,
		habCapacityMult = 0.0,
		eliteChanceMult = 0.0,
		prestigeEarningsMult = 0.0,
		boostBoostMult = 0.0,
	}

	for _, uid in inventory.equipped do
		local pet = inventory.pets[uid]
		if pet and type(pet) == "table" then
			local variantMult = 1.0
			if pet.variant == "rainbow" then
				variantMult = 3.5
			elseif pet.variant == "golden" then
				variantMult = 2.0
			end

			if pet.customBonus ~= nil then
				if type(pet.customBonus) == "table" then
					for stat, baseVal in pet.customBonus do
						if type(stat) == "string" and type(baseVal) == "number" then
							bonusSum[stat] = (bonusSum[stat] or 0.0) + baseVal * variantMult
						end
					end
				elseif type(pet.customBonus) == "number" then
					local def = (catalog and catalog[pet.speciesId]) or TEST_ONLY_CATALOG[pet.speciesId]
					local stat = if def then def.stat else nil
					if stat then
						bonusSum[stat] = (bonusSum[stat] or 0.0) + pet.customBonus * variantMult
					end
				end
			else
				local def = (catalog and catalog[pet.speciesId]) or TEST_ONLY_CATALOG[pet.speciesId]
				if def then
					if def.bonuses then
						for stat, baseVal in def.bonuses do
							bonusSum[stat] = (bonusSum[stat] or 0.0) + baseVal * variantMult
						end
					elseif def.stat then
						local baseVal = (def.tierBonuses and def.tierBonuses[pet.tier]) or def.baseBonus or 0.5
						bonusSum[def.stat] = (bonusSum[def.stat] or 0.0) + baseVal * variantMult
					end
				end
			end
		end
	end

	multipliers.eggValueMult = 1.0 + (bonusSum.eggValueMult or 0.0)
	multipliers.layingRateMult = 1.0 + (bonusSum.layingRateMult or 0.0)
	multipliers.ihrMult = 1.0 + (bonusSum.ihrMult or 0.0)
	multipliers.habCapacityMult = 1.0 + (bonusSum.habCapacityMult or 0.0)
	multipliers.eliteChanceMult = 1.0 + (bonusSum.eliteChanceMult or 0.0)
	multipliers.prestigeEarningsMult = 1.0 + (bonusSum.prestigeEarningsMult or 0.0)
	multipliers.boostBoostMult = 1.0 + (bonusSum.boostBoostMult or 0.0)

	return multipliers
end

-- Calculates drone elite chance with Drone Hawk bonus (docs/09 §1, docs/16 §1).
-- Formula: min(1.0, baseChance * P), 0 when baseChance <= 0.
local function calculateDroneEliteChance(baseChance: number, petEliteMult: number): number
	if baseChance <= 0.0 or petEliteMult <= 0.0 then
		return 0.0
	end
	local raw = baseChance * petEliteMult
	return math.min(1.0, math.max(0.0, raw))
end

-- Applies habitat capacity multiplier with confirmed ceil rounding (docs/09 §2, docs/16 §1).
local function applyHabCapacityMultiplier(baseCapacity: number, petHabCapMult: number): number
	if baseCapacity <= 0 then
		return 0
	end
	return math.ceil(baseCapacity * petHabCapMult)
end

-- Composes boost categories with Alien Clucker (docs/16 §2).
-- If categorySum > 1.0 returns categorySum * B * Q, otherwise 1.0.
-- Q does not activate empty categories and does not multiply Video Doubler or Money Printer.
local function composeBoostWithAlien(categorySum: number, beaconSum: number?, petBoostBoostMult: number?): number
	if categorySum <= 1.0 then
		return 1.0
	end
	local B = if beaconSum and beaconSum > 0 then beaconSum else 1.0
	local Q = petBoostBoostMult or 1.0
	return categorySum * B * Q
end

Equipment.TEST_ONLY_CATALOG = TEST_ONLY_CATALOG
Equipment.validatePet = validatePet
Equipment.createInventory = createInventory
Equipment.getMaxSlots = getMaxSlots
Equipment.addPet = addPet
Equipment.removePet = removePet
Equipment.setPetLock = setPetLock
Equipment.equipPet = equipPet
Equipment.unequipPet = unequipPet
Equipment.incubatePet = incubatePet
Equipment.calculatePetMultipliers = calculatePetMultipliers
Equipment.calculateDroneEliteChance = calculateDroneEliteChance
Equipment.applyHabCapacityMultiplier = applyHabCapacityMultiplier
Equipment.composeBoostWithAlien = composeBoostWithAlien

return table.freeze(Equipment)
