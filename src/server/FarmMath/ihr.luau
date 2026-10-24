--!strict
-- One IHR phase of a simulation step. Caller owns production-before-IHR ordering.
local IHR = {}

local function fail(code: string): never
	error("IHR/" .. code, 3)
end

local function nonnegative(value: any): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge or value < 0 then
		fail("INVALID_NUMBER")
	end
	return value
end

function IHR.new(codec: any, populationMath: any): any
	if type(codec) ~= "table" or codec.VERSION ~= 1 then fail("UNSUPPORTED_CODEC") end
	if type(populationMath) ~= "table" or type(populationMath.vacancy) ~= "function"
		or type(populationMath.vacancies) ~= "function" or type(populationMath.select) ~= "function" then fail("INVALID_POPULATION_MATH") end
	local U = codec.ExactUInt
	local zero = U.decode("0")
	local function addTo(hab: any, increment: number)
		local accumulator = nonnegative(hab.fractionalIHR + increment)
		local integral = math.floor(accumulator)
		if integral >= 18446744073709551616 then fail("ACCUMULATOR_UINT64_OVERFLOW") end
		-- %.0f serializes this integral binary64 exactly, without an unsafe integer cast.
		local requested = U.decode(string.format("%.0f", integral))
		local vacancy = populationMath.vacancy(hab)
		local added = if U.compare(requested, vacancy) <= 0 then requested else vacancy
		hab.population = U.encode(U.add(U.decode(hab.population), added))
		-- The reference subtracts actual additions, not the unclipped integral part.
		local addedReal = U.toReal64Rounded(added)
		hab.fractionalIHR = accumulator - addedReal
	end

	local function step(habitats: any, ratePerHabSecond: number, dt: number, sharing: number, drawSource: any): any
		ratePerHabSecond = nonnegative(ratePerHabSecond)
		dt = nonnegative(dt)
		sharing = nonnegative(sharing)
		if dt > 0.3 then fail("STEP_TOO_LONG") end
		if sharing > 1 then fail("INVALID_SHARING") end
		if type(habitats) ~= "table" or getmetatable(habitats) ~= nil then fail("INVALID_HABITATS") end
		for k in habitats do
			if type(k) ~= "number" or k % 1 ~= 0 or k < 1 or k > 4 then fail("INVALID_HABITATS") end
		end
		local result = {}
		for i = 1, 4 do
			local hab = habitats[i]
			if type(hab) ~= "table" or getmetatable(hab) ~= nil then fail("INVALID_HABITATS") end
			nonnegative(hab.fractionalIHR)
			local capacity = U.decode(hab.capacity)
			populationMath.vacancy(hab) -- Validates exact counters; over-capacity yields no vacancy.
			if hab.typeIndex ~= nil and (type(hab.typeIndex) ~= "number" or hab.typeIndex % 1 ~= 0 or hab.typeIndex < -1) then fail("INVALID_HABITAT_TYPE") end
			if hab.typeIndex == -1 and U.compare(capacity, zero) ~= 0 then fail("INVALID_EMPTY_HABITAT") end
			result[i] = table.clone(hab)
		end
		if dt == 0 then return result end
		local increment = nonnegative(codec.Real64.multiply(ratePerHabSecond, dt))
		for i = 1, 4 do
			local source = result[i]
			if U.compare(U.decode(source.capacity), zero) == 0 then
				-- Unbuilt slots never produce or donate IHR.
				source.fractionalIHR = 0
			elseif U.compare(populationMath.vacancy(source), zero) > 0 then
				addTo(source, increment)
			elseif sharing > 0 and increment > 0 then
				local _, total = populationMath.vacancies(result)
				if U.compare(total, zero) == 0 then
					source.fractionalIHR = 0
				else
					if type(drawSource) ~= "function" then fail("MISSING_DRAW_SOURCE") end
					local target = populationMath.select(result, drawSource(i))
					if target == nil then fail("INVALID_SELECTION") end
					local sharedRate = codec.Real64.multiply(ratePerHabSecond, sharing)
					addTo(result[target], nonnegative(codec.Real64.multiply(sharedRate, dt)))
				end
			else
				source.fractionalIHR = 0
			end
		end
		return result
	end
	return table.freeze({ step = step })
end

return table.freeze(IHR)
