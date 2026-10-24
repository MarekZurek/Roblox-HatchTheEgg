--!strict
-- Authoritative server logic for egg farm trophies (19 eggs, 5 population tiers, idempotent claims).
-- Spec: docs/02 §1; docs/13 §2; docs/27 §4; reference_data/infrastructure.json; Issue #33 (NEXT-08).

local Codec = require("../../shared/NumericCodec")
local ExactUInt = Codec.ExactUInt
local BigAmount = Codec.BigAmount

local Trophies = {
	VERSION = 1,
	POPULATION_TIERS = table.freeze({
		10_000_000, -- Tier 1: Bronze (10M)
		50_000_000, -- Tier 2: Silver (50M)
		250_000_000, -- Tier 3: Gold (250M)
		1_000_000_000, -- Tier 4: Platinum (1B)
		10_000_000_000, -- Tier 5: Diamond (10B)
	}),
}

export type TrophyReward = {
	eggIndex: number,
	tierIndex: number,
	populationRequired: number,
	soulEggs: number,
	goldenEggs: number,
	prophecyEggs: number,
}

-- Embedded reference table for 19 eggs (docs/reference_data/infrastructure.json)
-- Each egg has SE, GE, and PE rewards across 5 population tiers.
local EGG_TROPHIES: { [number]: { se: { number }, ge: { number }, pe: { number } } } = table.freeze({
	[0] = table.freeze({ -- Edible
		se = table.freeze({ 2_000_000, 10_000_000, 100_000_000, 10_000_000_000, 0 }),
		ge = table.freeze({ 0, 0, 0, 0, 0 }),
		pe = table.freeze({ 0, 0, 0, 0, 5 }),
	}),
	[1] = table.freeze({ -- Superfood
		se = table.freeze({ 1_000_000, 5_000_000, 50_000_000, 2_500_000_000, 0 }),
		ge = table.freeze({ 0, 0, 0, 0, 0 }),
		pe = table.freeze({ 0, 0, 0, 0, 4 }),
	}),
	[2] = table.freeze({ -- Medical
		se = table.freeze({ 500_000, 2_500_000, 25_000_000, 1_000_000_000, 0 }),
		ge = table.freeze({ 0, 0, 0, 0, 0 }),
		pe = table.freeze({ 0, 0, 0, 0, 3 }),
	}),
	[3] = table.freeze({ -- Rocket Fuel
		se = table.freeze({ 250_000, 1_000_000, 10_000_000, 500_000_000, 0 }),
		ge = table.freeze({ 0, 0, 0, 0, 0 }),
		pe = table.freeze({ 0, 0, 0, 0, 2 }),
	}),
	[4] = table.freeze({ -- Super Material
		se = table.freeze({ 100_000, 500_000, 5_000_000, 250_000_000, 0 }),
		ge = table.freeze({ 0, 0, 0, 0, 0 }),
		pe = table.freeze({ 0, 0, 0, 0, 1 }),
	}),
	[5] = table.freeze({ -- Fusion
		se = table.freeze({ 0, 0, 0, 0, 0 }),
		ge = table.freeze({ 250, 500, 1000, 2500, 5000 }),
		pe = table.freeze({ 0, 0, 0, 0, 0 }),
	}),
	[6] = table.freeze({ -- Quantum
		se = table.freeze({ 0, 0, 0, 0, 0 }),
		ge = table.freeze({ 500, 1000, 2000, 5000, 10000 }),
		pe = table.freeze({ 0, 0, 0, 0, 0 }),
	}),
	[7] = table.freeze({ -- CRISPR
		se = table.freeze({ 0, 0, 0, 0, 0 }),
		ge = table.freeze({ 750, 1500, 3000, 7500, 15000 }),
		pe = table.freeze({ 0, 0, 0, 0, 0 }),
	}),
	[8] = table.freeze({ -- Tachyon
		se = table.freeze({ 0, 0, 0, 0, 0 }),
		ge = table.freeze({ 1000, 2000, 4000, 10000, 20000 }),
		pe = table.freeze({ 0, 0, 0, 0, 0 }),
	}),
	[9] = table.freeze({ -- Graviton
		se = table.freeze({ 0, 0, 0, 0, 0 }),
		ge = table.freeze({ 1250, 2500, 5000, 12500, 25000 }),
		pe = table.freeze({ 0, 0, 0, 0, 0 }),
	}),
	[10] = table.freeze({ -- Dilithium
		se = table.freeze({ 0, 0, 0, 0, 0 }),
		ge = table.freeze({ 1500, 3000, 6000, 15000, 30000 }),
		pe = table.freeze({ 0, 0, 0, 0, 0 }),
	}),
	[11] = table.freeze({ -- Prodigy
		se = table.freeze({ 0, 0, 0, 0, 0 }),
		ge = table.freeze({ 1750, 3500, 7000, 17500, 35000 }),
		pe = table.freeze({ 0, 0, 0, 0, 0 }),
	}),
	[12] = table.freeze({ -- Terraform
		se = table.freeze({ 0, 0, 0, 0, 0 }),
		ge = table.freeze({ 2000, 4000, 8000, 20000, 40000 }),
		pe = table.freeze({ 0, 0, 0, 0, 0 }),
	}),
	[13] = table.freeze({ -- Antimatter
		se = table.freeze({ 0, 0, 0, 0, 0 }),
		ge = table.freeze({ 2250, 4500, 9000, 22500, 45000 }),
		pe = table.freeze({ 0, 0, 0, 0, 0 }),
	}),
	[14] = table.freeze({ -- Dark Matter
		se = table.freeze({ 0, 0, 0, 0, 0 }),
		ge = table.freeze({ 2500, 5000, 10000, 25000, 50000 }),
		pe = table.freeze({ 0, 0, 0, 0, 0 }),
	}),
	[15] = table.freeze({ -- AI
		se = table.freeze({ 0, 0, 0, 0, 0 }),
		ge = table.freeze({ 2750, 5500, 11000, 27500, 55000 }),
		pe = table.freeze({ 0, 0, 0, 0, 0 }),
	}),
	[16] = table.freeze({ -- Nebula
		se = table.freeze({ 0, 0, 0, 0, 0 }),
		ge = table.freeze({ 3000, 6000, 12000, 30000, 60000 }),
		pe = table.freeze({ 0, 0, 0, 0, 0 }),
	}),
	[17] = table.freeze({ -- Universe
		se = table.freeze({ 0, 0, 0, 0, 0 }),
		ge = table.freeze({ 3500, 7000, 14000, 35000, 70000 }),
		pe = table.freeze({ 0, 0, 0, 0, 0 }),
	}),
	[18] = table.freeze({ -- Enlightenment
		se = table.freeze({ 0, 0, 0, 0, 0 }),
		ge = table.freeze({ 0, 0, 0, 0, 0 }),
		pe = table.freeze({ 1, 2, 3, 5, 10 }), -- 5 tiers of PE for Enlightenment!
	}),
})

local function getTrophyKey(eggIndex: number, tierIndex: number): string
	return string.format("%d:%d", eggIndex, tierIndex)
end

local function getTrophySpec(eggIndex: number, tierIndex: number, customCatalog: any?): TrophyReward?
	if tierIndex < 1 or tierIndex > #Trophies.POPULATION_TIERS then
		return nil
	end
	local catalog = customCatalog or EGG_TROPHIES
	local eggData = catalog[eggIndex]
	if not eggData then
		return nil
	end

	local reqPop = Trophies.POPULATION_TIERS[tierIndex]
	local se = (eggData.se and eggData.se[tierIndex]) or 0
	local ge = (eggData.ge and eggData.ge[tierIndex]) or 0
	local pe = (eggData.pe and eggData.pe[tierIndex]) or 0

	return {
		eggIndex = eggIndex,
		tierIndex = tierIndex,
		populationRequired = reqPop,
		soulEggs = se,
		goldenEggs = ge,
		prophecyEggs = pe,
	}
end

local function isTrophyClaimed(profile: any, eggIndex: number, tierIndex: number): boolean
	if not profile or not profile.rewards or not profile.rewards.trophies then
		return false
	end
	local key = getTrophyKey(eggIndex, tierIndex)
	return profile.rewards.trophies[key] == true
end

-- Claims an egg trophy if eligible.
-- Validates population requirement, prevents duplicate claims, and mutates permanent profile assets.
local function claimTrophy(
	profile: any,
	eggIndex: number,
	tierIndex: number,
	currentPopulation: number,
	customCatalog: any?
): (boolean, TrophyReward?, string?)
	assert(profile ~= nil and profile.permanent ~= nil, "Trophies/INVALID_PROFILE")
	local spec = getTrophySpec(eggIndex, tierIndex, customCatalog)
	if not spec then
		return false, nil, "INVALID_TROPHY_TIER"
	end

	if currentPopulation < spec.populationRequired then
		return false, nil, "POPULATION_TOO_LOW"
	end

	profile.rewards = profile.rewards or {}
	profile.rewards.trophies = profile.rewards.trophies or {}

	local key = getTrophyKey(eggIndex, tierIndex)
	if profile.rewards.trophies[key] == true then
		return false, nil, "ALREADY_CLAIMED"
	end

	-- Mark trophy claimed
	profile.rewards.trophies[key] = true

	-- Distribute rewards
	if spec.soulEggs > 0 then
		local curSE = BigAmount.decode(profile.permanent.SE)
		profile.permanent.SE = BigAmount.encode(BigAmount.add(curSE, spec.soulEggs))
	end

	if spec.goldenEggs > 0 then
		local curGE = ExactUInt.decode(profile.permanent.GE)
		local addGE = ExactUInt.fromSafeNumber(spec.goldenEggs)
		profile.permanent.GE = ExactUInt.encode(ExactUInt.add(curGE, addGE))
	end

	if spec.prophecyEggs > 0 then
		local curPE = ExactUInt.decode(profile.permanent.PE or "0")
		local addPE = ExactUInt.fromSafeNumber(spec.prophecyEggs)
		profile.permanent.PE = ExactUInt.encode(ExactUInt.add(curPE, addPE))
	end

	return true, spec, nil
end

Trophies.EGG_TROPHIES = EGG_TROPHIES
Trophies.getTrophyKey = getTrophyKey
Trophies.getTrophySpec = getTrophySpec
Trophies.isTrophyClaimed = isTrophyClaimed
Trophies.claimTrophy = claimTrophy

return table.freeze(Trophies)
