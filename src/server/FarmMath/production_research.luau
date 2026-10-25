--!nocheck
-- Pure production math with explicit server context. No purchases or persistence.
local isStudio=(typeof(script)=="Instance")
local FvSe=if isStudio then require(script.Parent.fv_se) else require("./fv_se")
local Hatching=if isStudio then require(script.Parent.hatching_rcb) else require("./hatching_rcb")
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
		local rcbGrowthBase,rcbCapAdd=1,0

		for _, id in catalog.commonIds do
			local eff = e[id]
			if eff then
				if eff.onscreenChickenMult ~= nil then rcbGrowthBase=amount.multiply(rcbGrowthBase,eff.onscreenChickenMult) end
				if eff.onscreenChickenMultMax ~= nil then rcbCapAdd=amount.add(rcbCapAdd,eff.onscreenChickenMultMax) end
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
			rcbGrowthBase=rcbGrowthBase,rcbCap=amount.add(5,rcbCapAdd),
			layingPerChickenPerSecond = amount.divide(eggLayingRateMult, 30),
			eggValue = amount.multiply(catalog.getEgg(0).value, eggValueMult),
            eggValueMult = eggValueMult,
			refillPerSecond = amount.multiply(3, hatcheryRefillRateMult),
			hatcheryCapacity = amount.add(250, hatcheryCapacityAdd),
			internalHatcheryPerHabPerMinute = internalHatcheryRateAdd,
			habCapacityMult = habCapacityMult,
			vehicleCapacityMult = vehicleCapacityMult,
			maxFleetSize = 4 + maxFleetSizeAdd,
		})
	end
 -- Read only confirmed catalog effects. Empty/special Epic entries are not guessed.
 function api.progression(permanent)
  permanent=permanent or {}
  local epic=permanent.epic or {}
  local function effects(id,alias)
   local level=epic[id] or (alias and epic[alias]) or 0
   return catalog.epicEffects(id,level),level
  end
  local _,sf=effects("soul_eggs","soul_food")
  local _,pb=effects("prophecy_bonus")
  local lay=effects("epic_egg_laying")
  local refill=effects("epic_hatchery")
  local shipping=effects("transportation_lobbyist")
  local calm=effects("int_hatch_calm")
  local _,silo=effects("silo_capacity")
  local clucking=effects("epic_clucking")
  local runningCap=effects("epic_multiplier")
  local sharing=effects("int_hatch_sharing")
  local hold=effects("hold_to_hatch")
  local se=codec.Real64.decode(permanent.SE or "0")
  amount.validate(se)
  -- The exact PE counter is retained in the profile; conversion for the exponent
  -- is explicit and never replaces that counter.
  local pe=codec.ExactUInt.toReal64Rounded(codec.ExactUInt.decode(permanent.PE or "0"))
  local mystical=1
  if se~=0 then local _,m=FvSe.calculateEarningBonus(se,pe,sf,pb);mystical=amount.validate(m) end
  return {sharing=sharing.internalHatcherySharing or 0,holdRate=hold.holdToHatchRate or 0,rcbGrowthMult=clucking.onscreenChickenMult or 1,rcbCapAdd=runningCap.onscreenChickenMultMax or 0,mysticalMultiplier=mystical,layingRateMult=lay.eggLayingRateMult or 1,
   refillMult=refill.hatcheryRefillRateMult or 1,shippingMult=shipping.vehicleCapacityMult or 1,
   calmMult=calm.internalHatcheryMultAway or 1,siloCapacityLevel=silo}
 end
 function api.productionContext(common,eggIndex,permanent,pet)
  local r=table.clone(api.research(common));local progression=api.progression(permanent)
  pet=pet or {}
  r.eggValue=amount.multiply(amount.multiply(catalog.getEgg(eggIndex or 0).value,r.eggValueMult),pet.eggValueMult or 1)
  r.layingPerChickenPerSecond=amount.multiply(amount.multiply(r.layingPerChickenPerSecond,progression.layingRateMult),pet.layingRateMult or 1)
  r.refillPerSecond=amount.multiply(r.refillPerSecond,progression.refillMult)
  r.vehicleCapacityMult=amount.multiply(r.vehicleCapacityMult,progression.shippingMult)
  r.mysticalMultiplier=progression.mysticalMultiplier
  r.calmMult=progression.calmMult
  r.siloCapacityLevel=progression.siloCapacityLevel
  r.sharing=progression.sharing;r.holdRate=progression.holdRate
  r.rcbGrowthBase=amount.multiply(r.rcbGrowthBase,progression.rcbGrowthMult)
  r.rcbCap=amount.add(r.rcbCap,progression.rcbCapAdd)
  return r
 end
 function api.activeRCB(common,permanent,runningText)
  local r=api.productionContext(common,0,permanent)
  return Hatching.rcb(codec,runningText or "0",r.rcbGrowthBase,r.rcbCap,1)
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
	function api.capacities(input, habitatTypes, petCapacityMult)
		dense(habitatTypes, 4, 4)
		local mult, caps, total = api.research(input).habCapacityMult, {}, 0
		for i = 1, 4 do
			local kind = habitatTypes[i]
			local cap = if kind == false then 0 else math.ceil(amount.multiply(amount.multiply(catalog.getHabitat(kind).capacity, mult),petCapacityMult or 1))
			caps[i], total = cap, total + cap
		end
		return table.freeze(caps), total
	end
	function api.shippingPerSecond(input, vehicleTypes, permanent)
		local r = api.research(input)
		local n = dense(vehicleTypes, r.maxFleetSize)
		local mult, perMinute = amount.multiply(r.vehicleCapacityMult,api.progression(permanent).shippingMult), 0
		for i = 1, n do perMinute = amount.add(perMinute, amount.multiply(catalog.getVehicle(vehicleTypes[i]).capacity, mult)) end
		return amount.divide(perMinute, 60)
	end
	function api.productionStep(state, dt)
		if type(state) ~= "table" then fail("INVALID_STATE") end
		dt = amount.validate(dt)
		if dt > 0.3 then fail("STEP_TOO_LONG") end
		local r = api.productionContext(state.commonLevels,state.eggIndex,state.permanent,state.petMultipliers)
		local caps = api.capacities(state.commonLevels, state.habitatTypes,state.petMultipliers and state.petMultipliers.habCapacityMult)
		dense(state.settledPopulation, 4, 4)
		local population = 0
		for i = 1, 4 do
			-- This first fragment accepts only safe exact populations fitting its selected habitats.
			local p = codec.ExactUInt.toSafeNumber(codec.ExactUInt.decode(state.settledPopulation[i]))
			if p > caps[i] and not state.permitExistingPopulation then fail("UNSUPPORTED_POPULATION") end
			population += p
			if population > 9007199254740991 then fail("UNSAFE_TOTAL_POPULATION") end
		end
		local rcb = if state.rcbMultiplier == nil then Hatching.rcb(codec,state.runningCount or "0",r.rcbGrowthBase,r.rcbCap,1) else amount.validate(state.rcbMultiplier)
		if rcb < 1 then fail("INVALID_RCB") end
		local producedRate = amount.multiply(population, r.layingPerChickenPerSecond)
		local shippingRate = api.shippingPerSecond(state.commonLevels, state.vehicleTypes,state.permanent)
		local soldRate = math.min(producedRate, shippingRate)
		local cashRate = amount.multiply(amount.multiply(amount.multiply(soldRate, r.eggValue), rcb),r.mysticalMultiplier)
		local produced = amount.multiply(producedRate, dt)
		local sold = math.min(produced, amount.multiply(shippingRate, dt))
		local cash = amount.multiply(amount.multiply(amount.multiply(sold, r.eggValue), rcb),r.mysticalMultiplier)
		return table.freeze({ producedEggsPerSecond = producedRate, soldEggsPerSecond = soldRate,
			cashIncomePerSecond = cashRate, producedEggs = produced,
			soldEggs = sold, cashIncome = cash,
			populationConversion = "EXACT_SAFE_INTEGER", usedSettledPopulation = population })
	end
	return table.freeze(api)
end
return table.freeze(Module)
