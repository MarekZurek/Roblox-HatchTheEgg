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
local expectedIds = {"comfy_nests", "nutritional_sup", "better_incubators", "hab_capacity1", "internal_hatchery1", "hatchery_expansion", "leafsprings"}
same(C.commonIds, expectedIds, "ids")
local byId = {}
for _, row in research.common do byId[row.id] = row end
local prices = 0
local effects = 0
for _, id in expectedIds do
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
equal(prices, 163); equal(effects, 170)
for tier, threshold in research.tierThresholds do same(C.tierThreshold(tier - 1), threshold, "thresholds." .. tostring(tier)) end
for _, key in {"index", "name", "value"} do same(C.getEgg(0)[key], infrastructure.eggs[1][key], "egg." .. key) end
local habitatPrices, vehiclePrices = 0, 0
for typeIndex = 0, 1 do
	local h, v = infrastructure.habitats[typeIndex + 1], infrastructure.vehicles[typeIndex + 1]
	for _, key in {"index", "name", "capacity", "prices"} do
		same(C.getHabitat(typeIndex)[key], h[key], "habitats." .. tostring(typeIndex) .. "." .. key)
		same(C.getVehicle(typeIndex)[key], v[key], "vehicles." .. tostring(typeIndex) .. "." .. key)
	end
	for slot = 0, 3 do
		same(C.habitatPrice(typeIndex, slot), h.prices[slot + 1], "habitats." .. tostring(typeIndex) .. ".prices." .. tostring(slot + 1))
		habitatPrices += 1
	end
	for owned = 0, #v.prices - 1 do
		same(C.vehiclePrice(typeIndex, owned), v.prices[owned + 1], "vehicles." .. tostring(typeIndex) .. ".prices." .. tostring(owned + 1))
		vehiclePrices += 1
	end
	rejects("INVALID_INDEX", function() C.vehiclePrice(typeIndex, #v.prices) end)
end
equal(habitatPrices, 8); equal(vehiclePrices, 34)
-- These APIs are zero-based, unlike Luau arrays and visible UI slot numbers.
equal(C.habitatPrice(0, 1), infrastructure.habitats[1].prices[2])
equal(C.vehiclePrice(0, 1), infrastructure.vehicles[1].prices[2])
for _, bad in {-1, 0.5, math.huge, -math.huge, 0/0, "0", {}, false} do
	rejects("INVALID_INDEX", function() C.getHabitat(bad) end)
	rejects("INVALID_INDEX", function() C.researchPrice(expectedIds[1], bad) end)
end
rejects("INVALID_INDEX", function() C.getEgg(1) end)
rejects("INVALID_INDEX", function() C.getVehicle(2) end)
rejects("INVALID_INDEX", function() C.habitatPrice(0, 4) end)
rejects("INVALID_INDEX", function() C.tierThreshold(13) end)
rejects("UNSUPPORTED_RESEARCH", function() C.getCommon("excitable_chickens") end)
rejects("UNSUPPORTED_RESEARCH", function() C.getCommon({}) end)
rejects("TEST_MODE_REQUIRED", function() Registry.new(Codec, Data) end)
rejects("TEST_MODE_REQUIRED", function() Registry.new(Codec, Data, {mode="production"}) end)
rejects("UNSUPPORTED_CODEC", function() Registry.new({}, Data, {mode="INTERNAL_TEST_ONLY"}) end)
local wrongStatus = table.clone(Data)
wrongStatus.productionConfigurationApproved = true
rejects("INVALID_DATA_STATUS", function() Registry.new(Codec, wrongStatus, {mode="INTERNAL_TEST_ONLY"}) end)
equal(pcall(function() C.getCommon(expectedIds[1]).prices[1] = 0 end), false, "deep immutable")
equal(pcall(function() C.STATUS = "production" end), false, "immutable API")
-- Input mutation after construction cannot change a registry snapshot.
local mutable = table.clone(Data)
mutable.egg = table.clone(Data.egg)
local isolated = Registry.new(Codec, mutable, {mode="INTERNAL_TEST_ONLY"})
mutable.egg.value = 999
equal(isolated.getEgg(0).value, 0.25)
fs.writeFile("build/catalog-results.json",serde.encode("json",{status="PASS",level="L",assertions=count,researchPrices=163,effectRecords=170,habitatPrices=8,vehiclePrices=34,studioTested=false,dataStoreTested=false},true))
print(string.format("CatalogRegistry PASS: %d assertions; 163 research prices, 170 effects, 8 habitat prices, 34 vehicle prices", count))
