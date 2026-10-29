--!nocheck
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local FvSe = require("../../src/server/FarmMath/fv_se")

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

local function reject(fn, label)
	assertions += 1
	local ok, err = pcall(fn)
	assert(not ok, (if label then label .. ": " else "") .. "expected rejection, but call succeeded")
end

-- =====================================================================
-- 1. Reference Empty Edible Farm Test (docs/02 §2)
-- Expected FV: ~13 732.00679132647, relErr < 1e-6
-- =====================================================================
do
	local fv = FvSe.calculateFarmValue({
		eggIndex = 0,
		population = 0,
		habCapacity = 250,
		shippingPerMinute = 0,
		eggValueBase = 0.25,
	})
	local refVal = 13732.00679132647
	nearRel(fv, refVal, 1e-6, "empty Edible farm FV reference")
	near(fv, refVal, 1e-10, "empty Edible farm FV high precision")

	-- Same reference should hold regardless of vehicle capacity when population = 0
	local fvWithTrike = FvSe.calculateFarmValue({
		eggIndex = 0,
		population = 0,
		habCapacity = 250,
		shippingPerMinute = 5000, -- 1 Trike
		eggValueBase = 0.25,
	})
	near(fvWithTrike, refVal, 1e-10, "empty Edible farm with shipping")
end

-- =====================================================================
-- 2. Fleet Shipping Limit & 0.2 Penalty on Excess Population
-- L = 1/30 (laying rate 1.0)
-- shippingPerMinute = 6000 -> 100/s -> C = floor(100 / (1/30)) = 3000
-- =====================================================================
do
	local baseParams = {
		eggIndex = 0,
		eggValueBase = 0.25,
		shippingPerMinute = 6000,
		habCapacity = 10000,
		researchEggLayingRateMult = 1.0,
		researchIHRBase = 0,
		researchMaxRCBBase = 0,
	}

	-- For population <= C (3000), P = population
	local params2000 = table.clone(baseParams)
	params2000.population = 2000
	params2000.habCapacity = 2000 -- F = 0
	local fv2000 = FvSe.calculateFarmValue(params2000)

	local params3000 = table.clone(baseParams)
	params3000.population = 3000
	params3000.habCapacity = 3000 -- F = 0
	local fv3000 = FvSe.calculateFarmValue(params3000)

	-- Ratio fv3000 / fv2000 should be 3000 / 2000 = 1.5 exactly
	near(fv3000 / fv2000, 1.5, 1e-12, "population below shipping limit ratio")

	-- For population > C (3000), e.g. 4000:
	-- P = floor(3000 + 0.2 * 1000) = 3200
	local params4000 = table.clone(baseParams)
	params4000.population = 4000
	params4000.habCapacity = 4000 -- F = 0
	local fv4000 = FvSe.calculateFarmValue(params4000)

	-- Ratio fv4000 / fv3000 should be 3200 / 3000
	near(fv4000 / fv3000, 3200 / 3000, 1e-12, "0.2 penalty on excess population ratio")

	-- Excess population small step rounding:
	-- population = 3004 -> 3000 + 0.2 * 4 = 3000.8 -> floor = 3000
	local params3004 = table.clone(baseParams)
	params3004.population = 3004
	params3004.habCapacity = 3004
	local fv3004 = FvSe.calculateFarmValue(params3004)
	eq(fv3004, fv3000, "excess population fraction floored")

	-- population = 3005 -> 3000 + 0.2 * 5 = 3001 -> floor = 3001
	local params3005 = table.clone(baseParams)
	params3005.population = 3005
	params3005.habCapacity = 3005
	local fv3005 = FvSe.calculateFarmValue(params3005)
	near(fv3005 / fv3000, 3001 / 3000, 1e-12, "excess population exact step")
end

-- =====================================================================
-- 3. Free Capacity Term F = max(0, habCapacity - population)^0.6
-- =====================================================================
do
	local params = {
		eggIndex = 0,
		eggValueBase = 1.0,
		shippingPerMinute = 0,
		population = 0,
		habCapacity = 1000,
		researchEggLayingRateMult = 1.0,
		researchIHRBase = 0,
	}
	-- F = 1000^0.6, P = 0, 0.25*I*T = 0
	local fvEmpty = FvSe.calculateFarmValue(params)

	-- When population fills half hab: population = 500, habCapacity = 1000
	-- P = 0 (since shipping = 0, C = 0, P = floor(0 + 0.2 * 500) = 100)
	-- F = 500^0.6
	params.population = 500
	local fvHalf = FvSe.calculateFarmValue(params)

	-- When population equals habCapacity: F = 0
	params.population = 1000
	local fvFull = FvSe.calculateFarmValue(params)

	-- When population exceeds habCapacity (overcrowded/downgraded): F = max(0, negative)^0.6 = 0
	params.population = 1500
	local fvOver = FvSe.calculateFarmValue(params)

	-- P for 1000 is floor(0.2 * 1000) = 200, P for 1500 is floor(0.2 * 1500) = 300
	-- Both have F = 0 and I = 0, so fvOver / fvFull == 300 / 200 = 1.5
	near(fvOver / fvFull, 1.5, 1e-12, "F clamped to 0 when population > capacity")
	assert(fvEmpty > 0, "fvEmpty positive")
	assert(fvHalf > 0, "fvHalf positive")
end

-- =====================================================================
-- 4. IHR and Silo Capacity Term: 0.25 * I * T
-- I = 4 * researchIHRBase * researchIHRMult / 60
-- T = silosOwned * (3600 + 360 * siloCapacityLevel)
-- =====================================================================
do
	local baseParams = {
		eggIndex = 0,
		eggValueBase = 1.0,
		population = 0,
		habCapacity = 0, -- F = 0, P = 0
		shippingPerMinute = 0,
		researchEggLayingRateMult = 30.0, -- L = 1.0
		valuationMult = 1.0,
		localMysticalEarningsMultiplier = 1.0,
		researchEggValueMult = 1.0,
		researchMaxRCBBase = 0,
		researchMaxRCBMult = 1.0, -- R = 1.0
	}
	-- 50 * K * 1 * 1 * 1 * 1 * 1 * (0 + 0 + 0.25 * I * T) * 1
	-- K = 1200, 50 * K = 60000
	-- FV = 60000 * 0.25 * I * T = 15000 * I * T

	-- Base: silosOwned = 1, siloCapacityLevel = 0 -> T = 3600
	-- researchIHRBase = 15, researchIHRMult = 1.0 -> I = 4 * 15 / 60 = 1.0
	local p1 = table.clone(baseParams)
	p1.silosOwned = 1
	p1.siloCapacityLevel = 0
	p1.researchIHRBase = 15
	p1.researchIHRMult = 1.0
	local fv1 = FvSe.calculateFarmValue(p1)
	-- FV = 15000 * 1.0 * 3600 = 54,000,000
	near(fv1, 54000000, 1e-6, "IHR and silo base calculation")

	-- Upgrade siloCapacityLevel to 10: T = 1 * (3600 + 3600) = 7200 -> exactly 2x
	local p2 = table.clone(p1)
	p2.siloCapacityLevel = 10
	local fv2 = FvSe.calculateFarmValue(p2)
	near(fv2, 108000000, 1e-6, "silo capacity level 10 gives 2x T")

	-- 10 silos owned: T = 10 * 7200 = 72000 -> 10x
	local p3 = table.clone(p2)
	p3.silosOwned = 10
	local fv3 = FvSe.calculateFarmValue(p3)
	near(fv3, 1080000000, 1e-6, "10 silos owned gives 10x T")

	-- researchIHRMult = 3.5 -> I = 3.5x
	local p4 = table.clone(p3)
	p4.researchIHRMult = 3.5
	local fv4 = FvSe.calculateFarmValue(p4)
	near(fv4 / fv3, 3.5, 1e-12, "research IHR multiplier")
end

-- =====================================================================
-- 5. K Constant for Standard & Contract Farms
-- Standard: eggIndex 0..17 -> 1200 + 600 * eggIndex; eggIndex 18 -> 3600
-- Contract: eggIndex 0..17 -> 6000; eggIndex 18 -> 3600
-- =====================================================================
do
	local function getK(eggIndex, isContract)
		local p = {
			eggIndex = eggIndex,
			eggValueBase = 1.0,
			population = 1,
			habCapacity = 1, -- F = 0, P = 1, I = 0 -> bracket = 1
			shippingPerMinute = 6000,
			researchEggLayingRateMult = 30.0, -- L = 1.0
			valuationMult = 1.0,
			localMysticalEarningsMultiplier = 1.0,
			researchEggValueMult = 1.0,
			researchMaxRCBBase = 0,
			researchMaxRCBMult = 1.0,
			researchIHRBase = 0,
			isContract = isContract,
		}
		-- FV = 50 * K * 1 * 1 * 1 * 1 * 1 * 1 * 1 = 50 * K
		return FvSe.calculateFarmValue(p) / 50
	end

	-- Standard farm
	for i = 0, 17 do
		local expectedK = 1200 + 600 * i
		near(getK(i, false), expectedK, 1e-12, "standard farm K for egg " .. i)
		near(getK(i, nil), expectedK, 1e-12, "standard farm K default isContract")
	end
	near(getK(18, false), 3600, 1e-12, "standard Enlightenment K is 3600")

	-- Contract farm
	for i = 0, 17 do
		near(getK(i, true), 6000, 1e-12, "contract farm K for egg " .. i .. " is 6000")
	end
	near(getK(18, true), 3600, 1e-12, "contract Enlightenment K is 3600")
end

-- =====================================================================
-- 6. Soul Eggs 7 Intervals (p = 0.15, 0.16, 0.17, 0.18, 0.19, 0.20, 0.21)
-- & earnings < 1 returns 0
-- =====================================================================
do
	-- Below 1 returns 0
	eq(FvSe.calculateSoulEggs(0), 0, "earnings 0 returns 0")
	eq(FvSe.calculateSoulEggs(0.5), 0, "earnings 0.5 returns 0")
	eq(FvSe.calculateSoulEggs(0.999999), 0, "earnings < 1 returns 0")
	eq(FvSe.calculateSoulEggs(-10), 0, "negative earnings returns 0")
	eq(FvSe.calculateSoulEggs(0/0), 0, "NaN earnings returns 0")

	-- Interval 1: [1, 1e12) -> p = 0.15
	near(FvSe.calculateSoulEggs(1), 1.0, 1e-12, "earnings 1 -> 1^0.15 = 1")
	near(FvSe.calculateSoulEggs(1e6), (1e6)^0.15, 1e-12, "earnings 1e6 -> p=0.15")
	near(FvSe.calculateSoulEggs(1e12 - 1), (1e12 - 1)^0.15, 1e-12, "just below 1e12 -> p=0.15")

	-- Interval 2: [1e12, 1e21) -> p = 0.16
	near(FvSe.calculateSoulEggs(1e12), (1e12)^0.16, 1e-12, "exact threshold 1e12 -> p=0.16")
	near(FvSe.calculateSoulEggs(1e15), (1e15)^0.16, 1e-12, "earnings 1e15 -> p=0.16")
	near(FvSe.calculateSoulEggs(1e21 * 0.999), (1e21 * 0.999)^0.16, 1e-12, "just below 1e21 -> p=0.16")

	-- Interval 3: [1e21, 1e30) -> p = 0.17
	near(FvSe.calculateSoulEggs(1e21), (1e21)^0.17, 1e-12, "exact threshold 1e21 -> p=0.17")
	near(FvSe.calculateSoulEggs(1e25), (1e25)^0.17, 1e-12, "earnings 1e25 -> p=0.17")

	-- Interval 4: [1e30, 1e39) -> p = 0.18
	near(FvSe.calculateSoulEggs(1e30), (1e30)^0.18, 1e-12, "exact threshold 1e30 -> p=0.18")
	near(FvSe.calculateSoulEggs(1e35), (1e35)^0.18, 1e-12, "earnings 1e35 -> p=0.18")

	-- Interval 5: [1e39, 1e48) -> p = 0.19
	near(FvSe.calculateSoulEggs(1e39), (1e39)^0.19, 1e-12, "exact threshold 1e39 -> p=0.19")
	near(FvSe.calculateSoulEggs(1e45), (1e45)^0.19, 1e-12, "earnings 1e45 -> p=0.19")

	-- Interval 6: [1e48, 1e60) -> p = 0.20
	near(FvSe.calculateSoulEggs(1e48), (1e48)^0.20, 1e-12, "exact threshold 1e48 -> p=0.20")
	near(FvSe.calculateSoulEggs(1e55), (1e55)^0.20, 1e-12, "earnings 1e55 -> p=0.20")

	-- Interval 7: [1e60, inf) -> p = 0.21
	near(FvSe.calculateSoulEggs(1e60), (1e60)^0.21, 1e-12, "exact threshold 1e60 -> p=0.21")
	near(FvSe.calculateSoulEggs(1e75), (1e75)^0.21, 1e-12, "earnings 1e75 -> p=0.21")
	near(FvSe.calculateSoulEggs(1e100), (1e100)^0.21, 1e-12, "earnings 1e100 -> p=0.21")
end

-- =====================================================================
-- 7. Epic Prestige Bonus & Prestige Event Multiplier
-- =====================================================================
do
	local earnings = 1e15
	local baseSE = (1e15)^0.16

	-- Level 0, no event
	near(FvSe.calculateSoulEggs(earnings, 0, 1.0), baseSE, 1e-12, "level 0 collectionMult is 1.0")
	near(FvSe.calculateSoulEggs(earnings), baseSE, 1e-12, "defaults give 1.0x collectionMult")

	-- Level 20 -> 1 + 0.10 * 20 = 3.0x
	near(FvSe.calculateSoulEggs(earnings, 20, 1.0), baseSE * 3.0, 1e-12, "epic prestige level 20 is 3.0x")

	-- Level 10 -> 2.0x
	near(FvSe.calculateSoulEggs(earnings, 10, 1.0), baseSE * 2.0, 1e-12, "epic prestige level 10 is 2.0x")

	-- Prestige Event 2x with level 20 -> 3.0 * 2.0 = 6.0x
	near(FvSe.calculateSoulEggs(earnings, 20, 2.0), baseSE * 6.0, 1e-12, "epic prestige lvl 20 + 2x event is 6.0x")

	-- Prestige Event 3x with level 0 -> 3.0x
	near(FvSe.calculateSoulEggs(earnings, 0, 3.0), baseSE * 3.0, 1e-12, "3x event alone is 3.0x")
end

-- =====================================================================
-- 8. Absence of Floor for Soul Eggs (Contract 27 Real64 preservation)
-- =====================================================================
do
	local se = FvSe.calculateSoulEggs(10, 0, 1.0)
	local expected = 10^0.15 -- ~1.4125375446227544
	near(se, expected, 1e-14, "SE binary64 exactness")
	assert(se % 1 ~= 0, "SE must NOT be floored to integer: " .. tostring(se))
	assert(se > 1.41 and se < 1.42, "fractional SE within expected range")

	local seHigh = FvSe.calculateSoulEggs(123456789.987, 3, 1.5)
	assert(seHigh % 1 ~= 0, "scaled SE retains fractional binary64")
end

-- =====================================================================
-- 9. Earning Bonus (EB) & Mystical Earnings Multiplier (1 + EB)
-- EB = SE * (0.10 + 0.01 * SoulFoodLvl) * ((1.05 + 0.01 * ProphecyBonusLvl) ^ ProphecyEggs)
-- mysticalMultiplier = 1.0 + EB
-- =====================================================================
do
	-- When SE = 0: EB = 0, mysticalMultiplier = 1.0
	local eb0, mult0 = FvSe.calculateEarningBonus(0, 0, 0, 0)
	eq(eb0, 0, "SE=0 gives EB=0")
	eq(mult0, 1.0, "SE=0 gives mysticalMultiplier=1.0")

	-- nil inputs default safely
	local ebNil, multNil = FvSe.calculateEarningBonus()
	eq(ebNil, 0, "nil inputs give EB=0")
	eq(multNil, 1.0, "nil inputs give mysticalMultiplier=1.0")

	-- Baseline: 100 SE, no PE, no research
	-- EB = 100 * 0.10 * (1.05^0) = 10.0
	-- mysticalMultiplier = 11.0
	local eb100, mult100 = FvSe.calculateEarningBonus(100, 0, 0, 0)
	near(eb100, 10.0, 1e-12, "100 SE base EB")
	near(mult100, 11.0, 1e-12, "100 SE base multiplier")

	-- Soul Food Level 10:
	-- (0.10 + 0.01 * 10) = 0.20 per SE -> EB = 20.0
	local ebSF, multSF = FvSe.calculateEarningBonus(100, 0, 10, 0)
	near(ebSF, 20.0, 1e-12, "Soul Food lvl 10 doubles per-SE bonus")
	near(multSF, 21.0, 1e-12, "Soul Food lvl 10 multiplier")

	-- Soul Food max level 140:
	-- (0.10 + 0.01 * 140) = 1.50 per SE -> EB = 150.0
	local ebSFMax, multSFMax = FvSe.calculateEarningBonus(100, 0, 140, 0)
	near(ebSFMax, 150.0, 1e-12, "Soul Food max lvl 140")
	near(multSFMax, 151.0, 1e-12, "Soul Food max lvl 140 multiplier")

	-- Prophecy Eggs compounding:
	-- 10 PE, ProphecyBonusLvl = 5 (+1% each -> 1.10 per egg):
	-- 1.10^10 = 2.5937424601000023
	-- EB = 100 * 0.10 * 2.5937424601000023 = 25.937424601000023
	local ebPE, multPE = FvSe.calculateEarningBonus(100, 10, 0, 5)
	local expectedPEFactor = 1.10^10
	near(ebPE, 10 * expectedPEFactor, 1e-12, "10 PE with Prophecy Bonus 5")
	near(multPE, 1.0 + 10 * expectedPEFactor, 1e-12, "multiplier with PE compounding")

	-- Verify documented powers from docs/05 §3:
	-- 50 PE with 10% bonus: 1.10^50 ~ 117.39085
	local eb50, _ = FvSe.calculateEarningBonus(1, 50, 0, 5)
	nearRel(eb50 / 0.10, 117.3908528, 1e-6, "50 PE 10% bonus factor")
end

-- =====================================================================
-- 10. 19 Eggs Table & Discovery / Advance Predicates (docs/02 §1)
-- =====================================================================
do
	local expectedEggs = {
		{ index = 0, name = "KURZE", eggValueBase = 1.0, discoveryFV = 0, advanceFV = 0 },
		{ index = 1, name = "KACZE", eggValueBase = 3.0, discoveryFV = 5e7, advanceFV = 2.5e8 },
		{ index = 2, name = "GĘSIE", eggValueBase = 10.0, discoveryFV = 2e9, advanceFV = 1e10 },
		{ index = 3, name = "INDYCZE", eggValueBase = 40.0, discoveryFV = 1e11, advanceFV = 5e11 },
		{ index = 4, name = "STRUSIE", eggValueBase = 160.0, discoveryFV = 1e14, advanceFV = 5e14 },
		{ index = 5, name = "PAWIE", eggValueBase = 700.0, discoveryFV = 2e16, advanceFV = 1e17 },
		{ index = 6, name = "PINGWINIE", eggValueBase = 3000.0, discoveryFV = 1e19, advanceFV = 5e19 },
		{ index = 7, name = "KRUCZE", eggValueBase = 15000.0, discoveryFV = 5e22, advanceFV = 2.5e23 },
		{ index = 8, name = "ORLE", eggValueBase = 60000.0, discoveryFV = 1e26, advanceFV = 5e26 },
		{ index = 9, name = "KAZUARA", eggValueBase = 250000.0, discoveryFV = 5e29, advanceFV = 2.5e30 },
		{ index = 10, name = "PTERODAKTYLA", eggValueBase = 1000000.0, discoveryFV = 2e33, advanceFV = 1e34 },
		{ index = 11, name = "RAPTORA", eggValueBase = 5000000.0, discoveryFV = 1e37, advanceFV = 5e37 },
		{ index = 12, name = "TYRANOZAURA", eggValueBase = 25000000.0, discoveryFV = 1e41, advanceFV = 5e41 },
		{ index = 13, name = "GRYFA", eggValueBase = 2500000000.0, discoveryFV = 5e44, advanceFV = 2.5e45 },
		{ index = 14, name = "HYDRY", eggValueBase = 100000000000.0, discoveryFV = 5e48, advanceFV = 2.5e49 },
		{ index = 15, name = "BAZYLISZKA", eggValueBase = 1e12, discoveryFV = 2e52, advanceFV = 1e53 },
		{ index = 16, name = "FENIKSA", eggValueBase = 15e12, discoveryFV = 5e56, advanceFV = 2.5e57 },
		{ index = 17, name = "SMOCZE", eggValueBase = 150e12, discoveryFV = 1e61, advanceFV = 5e61 },
		{ index = 18, name = "ASTRALNEGO LEWIATANA", eggValueBase = 1e-7, discoveryFV = 1e65, advanceFV = 5e65 },
	}

	for i = 0, 18 do
		local row = FvSe.EGGS[i]
		local exp = expectedEggs[i + 1]
		assert(row ~= nil, "missing egg " .. i)
		eq(row.index, exp.index, "egg index " .. i)
		eq(row.name, exp.name, "egg name " .. i)
		eq(row.eggValueBase, exp.eggValueBase, "egg base value " .. i)
		eq(row.discoveryFV, exp.discoveryFV, "egg discoveryFV " .. i)
		eq(row.advanceFV, exp.advanceFV, "egg advanceFV " .. i)

		-- canDiscoverEgg tests
		if exp.discoveryFV > 0 then
			eq(FvSe.canDiscoverEgg(exp.discoveryFV * 0.99, i), false, "cannot discover below threshold " .. i)
			eq(FvSe.canDiscoverEgg(exp.discoveryFV, i), true, "can discover at threshold " .. i)
			eq(FvSe.canDiscoverEgg(exp.discoveryFV * 1.01, i), true, "can discover above threshold " .. i)
			if exp.discoveryFV < 9e15 then
				eq(FvSe.canDiscoverEgg(exp.discoveryFV - 1, i), false, "cannot discover 1 below threshold " .. i)
			end
		else
			eq(FvSe.canDiscoverEgg(0, i), true, "Edible discoverable at 0")
		end

		-- canAdvanceEgg tests
		if exp.advanceFV > 0 then
			eq(FvSe.canAdvanceEgg(exp.advanceFV * 0.99, i), false, "cannot advance below threshold " .. i)
			eq(FvSe.canAdvanceEgg(exp.advanceFV, i), true, "can advance at threshold " .. i)
			eq(FvSe.canAdvanceEgg(exp.advanceFV * 1.01, i), true, "can advance above threshold " .. i)
			if exp.advanceFV < 9e15 then
				eq(FvSe.canAdvanceEgg(exp.advanceFV - 1, i), false, "cannot advance 1 below threshold " .. i)
			end
		else
			eq(FvSe.canAdvanceEgg(0, i), true, "Edible advanceable at 0")
		end
	end

	-- Out of bounds and invalid inputs for predicates
	eq(FvSe.canDiscoverEgg(1e70, -1), false, "negative egg index")
	eq(FvSe.canDiscoverEgg(1e70, 19), false, "out of bounds egg index 19")
	eq(FvSe.canDiscoverEgg(1e70, "0"), false, "string egg index")
	eq(FvSe.canDiscoverEgg(0/0, 1), false, "NaN fv")
	eq(FvSe.canAdvanceEgg(1e70, -1), false, "negative egg advance index")
	eq(FvSe.canAdvanceEgg(1e70, 19), false, "out of bounds egg advance index 19")
	eq(FvSe.canAdvanceEgg(1e70, nil), false, "nil egg advance index")
	eq(FvSe.canAdvanceEgg(0/0, 1), false, "NaN fv advance")
end

-- =====================================================================
-- 11. Validation and Rejection Tests for calculateFarmValue
-- =====================================================================
do
	local validParams = {
		eggIndex = 0,
		population = 100,
		habCapacity = 250,
		shippingPerMinute = 5000,
		eggValueBase = 0.25,
	}

	-- Not a table
	reject(function() FvSe.calculateFarmValue("bad") end, "non-table params")
	reject(function() FvSe.calculateFarmValue(nil) end, "nil params")

	-- eggIndex
	for _, badIndex in {-1, 19, 1.5, 0/0, math.huge, "0"} do
		local p = table.clone(validParams)
		p.eggIndex = badIndex
		reject(function() FvSe.calculateFarmValue(p) end, "bad eggIndex: " .. tostring(badIndex))
	end

	-- Negative / non-finite population
	for _, badPop in {-1, 0/0, math.huge, "100"} do
		local p = table.clone(validParams)
		p.population = badPop
		reject(function() FvSe.calculateFarmValue(p) end, "bad population: " .. tostring(badPop))
	end

	-- Negative / non-finite habCapacity
	for _, badCap in {-1, 0/0, math.huge, "250"} do
		local p = table.clone(validParams)
		p.habCapacity = badCap
		reject(function() FvSe.calculateFarmValue(p) end, "bad habCapacity: " .. tostring(badCap))
	end

	-- Negative / non-finite shippingPerMinute
	for _, badShip in {-1, 0/0, math.huge} do
		local p = table.clone(validParams)
		p.shippingPerMinute = badShip
		reject(function() FvSe.calculateFarmValue(p) end, "bad shippingPerMinute: " .. tostring(badShip))
	end

	-- Non-positive eggValueBase
	for _, badVal in {0, -1, 0/0, math.huge} do
		local p = table.clone(validParams)
		p.eggValueBase = badVal
		reject(function() FvSe.calculateFarmValue(p) end, "bad eggValueBase: " .. tostring(badVal))
	end

	-- Negative multipliers
	local pNegMult = table.clone(validParams)
	pNegMult.valuationMult = -0.5
	reject(function() FvSe.calculateFarmValue(pNegMult) end, "negative valuationMult")

	local pNegLaying = table.clone(validParams)
	pNegLaying.researchEggLayingRateMult = 0
	reject(function() FvSe.calculateFarmValue(pNegLaying) end, "zero layingRateMult")

	local pNegSilos = table.clone(validParams)
	pNegSilos.silosOwned = -1
	reject(function() FvSe.calculateFarmValue(pNegSilos) end, "negative silosOwned")
end

-- =====================================================================
-- 12. Save Results and Report
-- =====================================================================
fs.writeFile("build/fv_se-results.json", serde.encode("json", {
	status = "PASS",
	level = "L",
	assertions = assertions,
	studioTested = false,
	dataStoreTested = false,
	scope = "NEXT-01 Pure Farm Value and Soul Eggs arithmetic",
}, true))

print(string.format("FarmMath fv_se PASS: %d assertions", assertions))
