--!nocheck
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local Codec = require("../../src/shared/NumericCodec")
local IHR = require("../../src/server/FarmMath/ihr")
-- Test seam: exact small-domain vacancy/selection oracle, independent of IHR.
local U = Codec.ExactUInt
local P = {}
function P.vacancy(h)
	local cap, pop, reserved = U.decode(h.capacity), U.decode(h.population), U.decode(h.assignedInTransit)
	if U.compare(pop, cap) >= 0 then return U.decode("0") end
	local remaining = U.subtract(cap, pop)
	if U.compare(reserved, remaining) >= 0 then return U.decode("0") end
	return U.subtract(remaining, reserved)
end
function P.vacancies(habs)
	local values, total = {}, U.decode("0")
	for i = 1, 4 do values[i] = P.vacancy(habs[i]); total = U.add(total, values[i]) end
	return values, total
end
function P.select(habs, text)
	local values, total = P.vacancies(habs)
	if U.encode(total) == "0" then return nil, "0" end
	local draw = U.toSafeNumber(U.decode(text)) % U.toSafeNumber(total)
	for i = 1, 4 do
		local size = U.toSafeNumber(values[i])
		if draw < size then return i, U.encode(total) end
		draw -= size
	end
	error("oracle selection failed")
end
local ihr = IHR.new(Codec, P)
local count = 0
local function equal(a, b, label)
	count += 1
	assert(a == b, (label or "") .. " " .. tostring(a) .. " != " .. tostring(b))
end
local function rejects(fragment, callback)
	local ok, err = pcall(callback)
	equal(ok, false, fragment)
	count += 1
	assert(string.find(tostring(err), fragment, 1, true), tostring(err))
end
local function hab(capacity, population, assigned, fraction)
	return { typeIndex = if capacity == "0" then -1 else 0, capacity = capacity, population = population or "0", assignedInTransit = assigned or "0", fractionalIHR = fraction or 0, unchanged = "sentinel" }
end
local function farm(first, second, third, fourth)
	return {first or hab("0"), second or hab("0"), third or hab("0"), fourth or hab("0")}
end
rejects("UNSUPPORTED_CODEC", function() IHR.new({VERSION=2}, P) end)
rejects("INVALID_POPULATION_MATH", function() IHR.new(Codec, {}) end)
local input = farm(hab("250", "0", "0", 0.8))
local out = ihr.step(input, 1, 0.3, 0)
equal(out[1].population, "1", "integer portion")
equal(out[1].fractionalIHR, 0.8 + 0.3 - 1, "binary64 order")
equal(input[1].population, "0", "input preserved")
equal(input[1].fractionalIHR, 0.8, "input accumulator preserved")
equal(out[1].unchanged, "sentinel", "other fields preserved")
equal(out == input, false)
equal(out[1] == input[1], false)
for i = 2, 4 do equal(out[i].population, "0"); equal(out[i].fractionalIHR, 0) end

-- Reservations occupy slots before arrival; subtract only additions surviving clipping.
out = ihr.step(farm(hab("10", "8", "1", 2.5)), 0, 0.3, 0)
equal(out[1].population, "9")
equal(out[1].fractionalIHR, 1.5, "carry may exceed one")
equal(out[1].assignedInTransit, "1")
out = ihr.step(out, 0, 0.3, 0)
equal(out[1].fractionalIHR, 0, "full without sharing clears carry")

-- Empty slots cannot donate; full slots choose weighted vacancy, not equal split.
local draws = {}
out = ihr.step(farm(hab("1", "1", "0", 0.7), hab("100"), hab("100")), 10, 0.3, 0.5, function(source)
	table.insert(draws, source)
	return "100" -- second vacancy interval: slot 3
end)
equal(#draws, 1)
equal(draws[1], 1)
equal(out[1].fractionalIHR, 0.7)
equal(out[2].population, "3")
equal(out[3].population, "4")
equal(out[3].fractionalIHR, 0.5)
equal(out[4].population, "0")

-- Sequential visitation: sharing into an earlier processed target remains valid.
out = ihr.step(farm(hab("100"), hab("1", "1")), 10, 0.3, 0.5, function() return "0" end)
equal(out[1].population, "4")
equal(out[1].fractionalIHR, 0.5)
-- Independent Python binary64 witness: (rate*sharing)*dt differs by one ULP
-- from (rate*dt)*sharing. Slot 1's own step lands exactly at 2 before donation.
out = ihr.step(farm(hab("100", "0", "0", 0.8159190327745043), hab("1", "1")),
	4.447507940640296, 0.26623470559898016, 0.11253087017612728, function() return "0" end)
equal(out[1].population, "2")
equal(out[1].fractionalIHR, 0.1332456616008755, "sharing multiplies rate before dt")
equal(out[1].fractionalIHR == 0.13324566160087548, false, "reject reassociated FP order")
out = ihr.step(farm(hab("1", "1", "0", 5), hab("1", "1")), 10, 0.3, 1, function() error("must not draw") end)
equal(out[1].fractionalIHR, 0)
equal(out[2].fractionalIHR, 0)

-- Exact population increment above 2^53: never round the population through number.
out = ihr.step(farm(hab("9007199254740995", "9007199254740993", "0", 0.8)), 1, 0.3, 0)
equal(out[1].population, "9007199254740994")
equal(out[1].fractionalIHR, 0.8 + 0.3 - 1)

-- 0.3+0.3+0.3+0.1 intentionally retains the reference floating point residue.
out = farm(hab("250", "100"))
for _, dt in {0.3, 0.3, 0.3, 0.1} do out = ihr.step(out, 1, dt, 0) end
equal(out[1].population, "100")
equal(out[1].fractionalIHR, 0.9999999999999999)
out = farm(hab("250", "100"))
local remaining = 1
while remaining > 0 do
	local dt = math.min(remaining, 0.3)
	out = ihr.step(out, 3, dt, 0)
	remaining -= dt
end
equal(out[1].population, "102")
equal(out[1].fractionalIHR, 0.9999999999999997)
out = ihr.step(farm(hab("1", "1", "0", 0.8)), 10, 0, 0)
equal(out[1].fractionalIHR, 0.8, "zero dt no-op")

for _, bad in {-1, math.huge, -math.huge, 0/0} do
	rejects("INVALID_NUMBER", function() ihr.step(farm(hab("10")), bad, 0.3, 0) end)
	rejects("INVALID_NUMBER", function() ihr.step(farm(hab("10")), 1, bad, 0) end)
	rejects("INVALID_NUMBER", function() ihr.step(farm(hab("10", "0", "0", bad)), 1, 0.3, 0) end)
end
rejects("STEP_TOO_LONG", function() ihr.step(farm(hab("10")), 1, 0.30000000000000004, 0) end)
rejects("INVALID_SHARING", function() ihr.step(farm(hab("10")), 1, 0.3, 1.1) end)
rejects("MISSING_DRAW_SOURCE", function() ihr.step(farm(hab("1", "1"), hab("10")), 1, 0.3, 1) end)
rejects("INVALID_HABITATS", function() ihr.step({hab("10")}, 1, 0.3, 0) end)
out = ihr.step(farm(hab("10", "9", "2")), 1, 0.3, 0)
equal(out[1].population, "9", "overcapacity vacancy clamps to zero")
equal(out[1].assignedInTransit, "2", "overcapacity reservations preserved")
rejects("INVALID_EMPTY_HABITAT", function()
	local h = hab("10"); h.typeIndex = -1; ihr.step(farm(h), 1, 0.3, 0)
end)
rejects("ACCUMULATOR_UINT64_OVERFLOW", function() ihr.step(farm(hab("10")), 1e30, 0.3, 0) end)
rejects("ARITHMETIC_UNDERFLOW", function() ihr.step(farm(hab("10")), 5e-324, 0.3, 0) end)
rejects("ARITHMETIC_UNDERFLOW", function()
	ihr.step(farm(hab("1", "1"), hab("10")), 1e-300, 0.3, 1e-100, function() return "0" end)
end)
-- Integration with the real exact vacancy selector, including a full-width draw.
local PopulationMath = require("../../src/server/FarmMath/PopulationMath")
local integrated = IHR.new(Codec, PopulationMath.new(Codec))
out = integrated.step(farm(hab("1", "1"), hab("10"), hab("10")), 10, 0.3, 1, function() return "18446744073709551615" end)
-- uint64 max modulo 20 = 15, so sharing selects slot 3.
equal(out[2].population, "3")
equal(out[3].population, "6")
out = integrated.step(farm(hab("10", "9", "2", 5)), 10, 0.3, 0)
equal(out[1].population, "9", "overcapacity reservation preserved")
equal(out[1].fractionalIHR, 0)
out = integrated.step(farm(hab("9007199254740995", "9007199254740993", "0", 0.8)), 1, 0.3, 0)
equal(out[1].population, "9007199254740994")
rejects("INVALID_EMPTY_SLOT", function()
	local h = hab("0", "1"); integrated.step(farm(h), 1, 0.3, 0)
end)
fs.writeFile("build/ihr-results.json", serde.encode("json", {status="PASS", level="L", assertions=count, studioTested=false, dataStoreTested=false, independentPopulationTestSeam=true, realPopulationMathIntegration=true}, true))
print(string.format("IHR PASS: %d assertions", count))
