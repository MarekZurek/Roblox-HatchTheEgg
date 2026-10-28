--!nocheck
-- Independent expectations: decode original JSON, not a generator-produced fixture.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local Codec = require("../../src/shared/NumericCodec")
local Registry = require("../../src/server/CatalogRegistry")
local Data = require("../../src/server/CatalogRegistry/Data")
local C = Registry.new(Codec, Data, { mode = "INTERNAL_TEST_ONLY" })
local research = serde.decode("json", fs.readFile("docs/reference_data/research.json"))
local infrastructure = serde.decode("json", fs.readFile("docs/reference_data/infrastructure.json"))
local oracle = serde.decode("json", fs.readFile("tests/catalog/numeric_bits.json"))
local count = 0
local function equal(a, b, message)
	count += 1
	assert(a == b, (message or "") .. ": " .. tostring(a) .. " != " .. tostring(b))
end
local function bits(value)
	local b = buffer.create(8)
	buffer.writef64(b, 0, value)
	local out = {}
	for i = 0, 7 do table.insert(out, string.format("%02x", buffer.readu8(b, i))) end
	return table.concat(out)
end
local function same(a, b, path)
	if type(b) == "number" then
		equal(type(a), "number", path)
		equal(bits(a), assert(oracle.bits[path], "Missing independent oracle: " .. path), path .. " binary64")
	elseif type(b) == "table" then
		equal(type(a), "table", path)
		for k, v in b do same(a[k], v, path .. "." .. tostring(k)) end
		for k in a do equal(b[k] ~= nil, true, path .. " unexpected key") end
	else equal(a, b, path) end
end
local function rejects(code, callback)
	local ok, err = pcall(callback)
	equal(ok, false, code)
	count += 1
	assert(string.find(tostring(err), "CatalogRegistry/" .. code, 1, true), tostring(err))
end

equal(C.STATUS, "INTERNAL_TEST_ONLY")
equal(C.productionConfigurationApproved, false)
same(C.sourceSha256, oracle.sourceSha256, "sourceSha256")

local expectedCommonIds = {}
for _, row in research.common do table.insert(expectedCommonIds, row.id) end
same(C.commonIds, expectedCommonIds, "commonIds")

local expectedEpicIds = {}
for _, row in research.epic do
 if row.id ~= "video_doubler_time" then table.insert(expectedEpicIds, row.id) end
end
rejects("RESEARCH_REMOVED", function() C.getEpic("video_doubler_time") end)
same(C.epicIds, expectedEpicIds, "epicIds")

local byId = {}
for _, row in research.common do byId[row.id] = row end
local prices = 0
local effects = 0
for _, id in expectedCommonIds do
	local row, imported = byId[id], C.getCommon(id)
	for _, key in {"id", "tier_raw", "maxLevel", "prices", "effectsByLevel"} do
		same(imported[key], row[key], id .. "." .. key)
	end
	for level = 0, row.maxLevel - 1 do
		same(C.researchPrice(id, level), row.prices[level + 1], id .. ".prices." .. tostring(level + 1))
		prices += 1
	end
	for level = 0, row.maxLevel do
		same(C.researchEffects(id, level), row.effectsByLevel[level + 1], id .. ".effectsByLevel." .. tostring(level + 1))
		effects += 1
	end
	rejects("MAX_LEVEL", function() C.researchPrice(id, row.maxLevel) end)
	rejects("INVALID_INDEX", function() C.researchEffects(id, row.maxLevel + 1) end)
end
equal(prices, 2330); equal(effects, 2386)

local byEpicId = {}
for _, row in research.epic do byEpicId[row.id] = row end
local epicPrices = 0
local epicEffects = 0
for _, id in expectedEpicIds do
	local row, imported = byEpicId[id], C.getEpic(id)
	for _, key in {"id", "tier_raw", "maxLevel", "prices", "effectsByLevel"} do
		same(imported[key], row[key], "epic." .. id .. "." .. key)
	end
	for level = 0, row.maxLevel - 1 do
		same(C.epicPrice(id, level), row.prices[level + 1], "epic." .. id .. ".prices." .. tostring(level + 1))
		epicPrices += 1
	end
	for level = 0, row.maxLevel do
		same(C.epicEffects(id, level), row.effectsByLevel[level + 1], "epic." .. id .. ".effectsByLevel." .. tostring(level + 1))
		epicEffects += 1
	end
	rejects("MAX_LEVEL", function() C.epicPrice(id, row.maxLevel) end)
	rejects("INVALID_INDEX", function() C.epicEffects(id, row.maxLevel + 1) end)
end
equal(epicPrices, 656); equal(epicEffects, 679)

for tier, threshold in research.tierThresholds do
	same(C.tierThreshold(tier - 1), threshold, "thresholds." .. tostring(tier))
end

for eggIndex = 0, #infrastructure.eggs - 1 do
	local e = infrastructure.eggs[eggIndex + 1]
	for _, key in {"index", "name", "value"} do
		same(C.getEgg(eggIndex)[key], e[key], "eggs." .. tostring(eggIndex) .. "." .. key)
	end
end

local habitatPrices, vehiclePrices = 0, 0
for typeIndex = 0, #infrastructure.habitats - 1 do
	local h = infrastructure.habitats[typeIndex + 1]
	for _, key in {"index", "name", "capacity", "prices"} do
		same(C.getHabitat(typeIndex)[key], h[key], "habitats." .. tostring(typeIndex) .. "." .. key)
	end
	for slot = 0, 3 do
		same(C.habitatPrice(typeIndex, slot), h.prices[slot + 1], "habitats." .. tostring(typeIndex) .. ".prices." .. tostring(slot + 1))
		habitatPrices += 1
	end
end
equal(habitatPrices, 76)

for typeIndex = 0, #infrastructure.vehicles - 1 do
	local v = infrastructure.vehicles[typeIndex + 1]
	for _, key in {"index", "name", "capacity", "prices"} do
		same(C.getVehicle(typeIndex)[key], v[key], "vehicles." .. tostring(typeIndex) .. "." .. key)
	end
	for owned = 0, #v.prices - 1 do
		same(C.vehiclePrice(typeIndex, owned), v.prices[owned + 1], "vehicles." .. tostring(typeIndex) .. ".prices." .. tostring(owned + 1))
		vehiclePrices += 1
	end
	rejects("INVALID_INDEX", function() C.vehiclePrice(typeIndex, #v.prices) end)
end
equal(vehiclePrices, 204)

-- These APIs are zero-based, unlike Luau arrays and visible UI slot numbers.
equal(C.habitatPrice(0, 1), infrastructure.habitats[1].prices[2])
equal(C.vehiclePrice(0, 1), infrastructure.vehicles[1].prices[2])

for _, bad in {-1, 0.5, math.huge, -math.huge, 0/0, "0", {}, false} do
	rejects("INVALID_INDEX", function() C.getHabitat(bad) end)
	rejects("INVALID_INDEX", function() C.getVehicle(bad) end)
	rejects("INVALID_INDEX", function() C.getEgg(bad) end)
	rejects("INVALID_INDEX", function() C.researchPrice(expectedCommonIds[1], bad) end)
	rejects("INVALID_INDEX", function() C.epicPrice(expectedEpicIds[1], bad) end)
end

rejects("INVALID_INDEX", function() C.getEgg(19) end)
rejects("INVALID_INDEX", function() C.getHabitat(19) end)
rejects("INVALID_INDEX", function() C.getVehicle(12) end)
rejects("INVALID_INDEX", function() C.habitatPrice(0, 4) end)
rejects("INVALID_INDEX", function() C.vehiclePrice(0, 17) end)
rejects("INVALID_INDEX", function() C.tierThreshold(13) end)
rejects("UNSUPPORTED_RESEARCH", function() C.getCommon("nonexistent_research") end)
rejects("UNSUPPORTED_RESEARCH", function() C.getCommon({}) end)
rejects("UNSUPPORTED_RESEARCH", function() C.getEpic("nonexistent_epic") end)
rejects("UNSUPPORTED_RESEARCH", function() C.getEpic({}) end)
rejects("TEST_MODE_REQUIRED", function() Registry.new(Codec, Data) end)
rejects("TEST_MODE_REQUIRED", function() Registry.new(Codec, Data, {mode="production"}) end)
rejects("UNSUPPORTED_CODEC", function() Registry.new({}, Data, {mode="INTERNAL_TEST_ONLY"}) end)

local wrongStatus = table.clone(Data)
wrongStatus.productionConfigurationApproved = true
rejects("INVALID_DATA_STATUS", function() Registry.new(Codec, wrongStatus, {mode="INTERNAL_TEST_ONLY"}) end)
equal(pcall(function() C.getCommon(expectedCommonIds[1]).prices[1] = 0 end), false, "deep immutable")
equal(pcall(function() C.STATUS = "production" end), false, "immutable API")

-- Input mutation after construction cannot change a registry snapshot.
local mutable = table.clone(Data)
mutable.eggs = table.clone(Data.eggs)
mutable.eggs[1] = table.clone(Data.eggs[1])
local isolated = Registry.new(Codec, mutable, {mode="INTERNAL_TEST_ONLY"})
mutable.eggs[1].value = 999
equal(isolated.getEgg(0).value, 0.25)

fs.writeFile("build/catalog-results.json", serde.encode("json", {
	status = "PASS",
	level = "L",
	assertions = count,
	commonPrices = prices,
	commonEffects = effects,
	epicPrices = epicPrices,
	epicEffects = epicEffects,
	habitatPrices = habitatPrices,
	vehiclePrices = vehiclePrices,
	studioTested = false,
	dataStoreTested = false,
}, true))
print(string.format("CatalogRegistry PASS: %d assertions; %d common prices, %d common effects, %d epic prices, %d epic effects, %d habitat prices, %d vehicle prices", count, prices, effects, epicPrices, epicEffects, habitatPrices, vehiclePrices))
