--!nocheck
-- Pure first-farm arithmetic. No purchases, mutation, services or persistence.
local Module = {}
local function fail(code) error("FarmMath/" .. code, 3) end
function Module.new(codec, catalog, options)
	if type(options) ~= "table" or options.mode ~= "INTERNAL_TEST_ONLY" then fail("TEST_MODE_REQUIRED") end
	if type(codec) ~= "table" or codec.VERSION ~= 1 then fail("UNSUPPORTED_CODEC") end
	if type(catalog) ~= "table" or catalog.STATUS ~= "INTERNAL_TEST_ONLY" then fail("UNSUPPORTED_CATALOG") end
	local amount = codec.BigAmount
	local api = { VERSION = 1, STATUS = "INTERNAL_TEST_ONLY", productionConfigurationApproved = false }
	local allowed = {}
	for _, id in catalog.commonIds do allowed[id] = true end
	local function levels(input)
		if type(input) ~= "table" or getmetatable(input) ~= nil then fail("INVALID_LEVELS") end
		local total, effects = 0, {}
		for id in input do if not allowed[id] then fail("UNSUPPORTED_RESEARCH") end end
		for _, id in catalog.commonIds do
			local level = input[id]
			if level == nil then level = 0 end
			-- Registry validates finite integer levels and their individual maxima.
			effects[id] = catalog.researchEffects(id, level)
			total += level
		end
		return total, effects
	end
	function api.research(input)
		local points, e = levels(input)
		local eggLayingRateMult = 1
		local eggValueMult = 1
		local hatcheryRefillRateMult = 1
		local hatcheryCapacityAdd = 0
		local internalHatcheryRateAdd = 0
		local habCapacityMult = 1
		local vehicleCapacityMult = 1
		local maxFleetSizeAdd = 0

		for _, id in catalog.commonIds do
			local eff = e[id]
			if eff then
				if eff.eggLayingRateMult ~= nil then
					eggLayingRateMult = amount.multiply(eggLayingRateMult, eff.eggLayingRateMult)
				end
				if eff.eggValueMult ~= nil then
					eggValueMult = amount.multiply(eggValueMult, eff.eggValueMult)
				end
				if eff.hatcheryRefillRateMult ~= nil then
					hatcheryRefillRateMult = amount.multiply(hatcheryRefillRateMult, eff.hatcheryRefillRateMult)
				end
				if eff.hatcheryCapacity ~= nil then
					hatcheryCapacityAdd = amount.add(hatcheryCapacityAdd, eff.hatcheryCapacity)
				end
				if eff.internalHatcheryRate ~= nil then
					internalHatcheryRateAdd = amount.add(internalHatcheryRateAdd, eff.internalHatcheryRate)
				end
				if eff.habCapacityMult ~= nil then
					habCapacityMult = amount.multiply(habCapacityMult, eff.habCapacityMult)
				end
				if eff.vehicleCapacityMult ~= nil then
					vehicleCapacityMult = amount.multiply(vehicleCapacityMult, eff.vehicleCapacityMult)
				end
				if eff.maxFleetSize ~= nil then
					maxFleetSizeAdd = maxFleetSizeAdd + eff.maxFleetSize
				end
			end
		end

		return table.freeze({
			commonPoints = points,
			layingPerChickenPerSecond = amount.divide(eggLayingRateMult, 30),
			eggValue = amount.multiply(catalog.getEgg(0).value, eggValueMult),
			refillPerSecond = amount.multiply(3, hatcheryRefillRateMult),
			hatcheryCapacity = amount.add(250, hatcheryCapacityAdd),
			internalHatcheryPerHabPerMinute = internalHatcheryRateAdd,
			habCapacityMult = habCapacityMult,
			vehicleCapacityMult = vehicleCapacityMult,
			maxFleetSize = 4 + maxFleetSizeAdd,
		})
	end
	function api.tierUnlocked(input, tier)
		local points = levels(input)
		return points >= catalog.tierThreshold(tier)
	end
	function api.canResearch(input, id)
		local row = catalog.getCommon(id)
		local points = levels(input)
		local current = input[id] or 0
		if current >= row.maxLevel then return false, "MAX_LEVEL" end
		if points < catalog.tierThreshold(row.tier_raw) then return false, "TIER_LOCKED" end
		return true, nil
	end
	local function dense(list, maximum, required)
		if type(list) ~= "table" or getmetatable(list) ~= nil then fail("INVALID_ARRAY") end
		local n = #list
		if n > maximum or (required and n ~= required) then fail("INVALID_ARRAY") end
		for k in list do if type(k) ~= "number" or k % 1 ~= 0 or k < 1 or k > n then fail("INVALID_ARRAY") end end
		for i = 1, n do if list[i] == nil then fail("INVALID_ARRAY") end end
		return n
	end
	function api.capacities(input, habitatTypes)
		dense(habitatTypes, 4, 4)
		local mult, caps, total = api.research(input).habCapacityMult, {}, 0
		for i = 1, 4 do
			local kind = habitatTypes[i]
			local cap = if kind == false then 0 else math.ceil(amount.multiply(catalog.getHabitat(kind).capacity, mult))
			caps[i], total = cap, total + cap
		end
		return table.freeze(caps), total
	end
	function api.shippingPerSecond(input, vehicleTypes)
		local r = api.research(input)
		local n = dense(vehicleTypes, r.maxFleetSize)
		local mult, perMinute = r.vehicleCapacityMult, 0
		for i = 1, n do perMinute = amount.add(perMinute, amount.multiply(catalog.getVehicle(vehicleTypes[i]).capacity, mult)) end
		return amount.divide(perMinute, 60)
	end
	function api.productionStep(state, dt)
		if type(state) ~= "table" then fail("INVALID_STATE") end
		dt = amount.validate(dt)
		if dt > 0.3 then fail("STEP_TOO_LONG") end
		local r = api.research(state.commonLevels)
		local caps = api.capacities(state.commonLevels, state.habitatTypes)
		dense(state.settledPopulation, 4, 4)
		local population = 0
		for i = 1, 4 do
			-- This first fragment accepts only safe exact populations fitting its selected habitats.
			local p = codec.ExactUInt.toSafeNumber(codec.ExactUInt.decode(state.settledPopulation[i]))
			if p > caps[i] then fail("UNSUPPORTED_POPULATION") end
			population += p
		end
		local rcb = if state.rcbMultiplier == nil then 1 else amount.validate(state.rcbMultiplier)
		if rcb < 1 then fail("INVALID_RCB") end
		local producedRate = amount.multiply(population, r.layingPerChickenPerSecond)
		local shippingRate = api.shippingPerSecond(state.commonLevels, state.vehicleTypes)
		local soldRate = math.min(producedRate, shippingRate)
		local cashRate = amount.multiply(amount.multiply(soldRate, r.eggValue), rcb)
		local produced = amount.multiply(producedRate, dt)
		local sold = math.min(produced, amount.multiply(shippingRate, dt))
		local cash = amount.multiply(amount.multiply(sold, r.eggValue), rcb)
		return table.freeze({ producedEggsPerSecond = producedRate, soldEggsPerSecond = soldRate,
			cashIncomePerSecond = cashRate, producedEggs = produced,
			soldEggs = sold, cashIncome = cash,
			populationConversion = "EXACT_SAFE_INTEGER", usedSettledPopulation = population })
	end
	return table.freeze(api)
end
return table.freeze(Module)
