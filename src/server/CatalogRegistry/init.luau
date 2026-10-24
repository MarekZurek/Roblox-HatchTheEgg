--!nocheck
-- No services. Studio and Lune inject the same codec and generated data module.
local CatalogRegistry = {}

local function fail(code) error("CatalogRegistry/" .. code, 3) end
local function index(value, maximum)
	if type(value) ~= "number" or value ~= value or value % 1 ~= 0 or value < 0 or value > maximum then
		fail("INVALID_INDEX")
	end
	return value
end
local function freezeCopy(value)
	if type(value) ~= "table" then return value end
	local copy = {}
	for k, v in value do copy[k] = freezeCopy(v) end
	return table.freeze(copy)
end

function CatalogRegistry.new(codec, data, options)
	if type(options) ~= "table" or options.mode ~= "INTERNAL_TEST_ONLY" then fail("TEST_MODE_REQUIRED") end
	if type(codec) ~= "table" or codec.VERSION ~= 1 then fail("UNSUPPORTED_CODEC") end
	if type(data) ~= "table" or data.status ~= "INTERNAL_TEST_ONLY"
		or data.sourceStatus ~= "REFERENCE_ONLY" or data.productionConfigurationApproved ~= false then fail("INVALID_DATA_STATUS") end
	local d = freezeCopy(data)
	-- Validate all imported numbers through NumericCodec, never silently round prices.
	local function validateNumbers(value)
		if type(value) == "number" then codec.BigAmount.validate(value)
		elseif type(value) == "table" then for _, v in value do validateNumbers(v) end end
	end
	validateNumbers(d)
	local api = { VERSION = 1, STATUS = d.status, productionConfigurationApproved = false,
		sourceSha256 = d.sourceSha256, commonIds = d.commonIds, epicIds = d.epicIds }
	function api.getCommon(id)
		if type(id) ~= "string" or d.common[id] == nil then fail("UNSUPPORTED_RESEARCH") end
		return d.common[id]
	end
	function api.researchPrice(id, currentLevel)
		local row = api.getCommon(id)
		index(currentLevel, row.maxLevel)
		if currentLevel == row.maxLevel then fail("MAX_LEVEL") end
		return row.prices[currentLevel + 1]
	end
	function api.researchEffects(id, level)
		local row = api.getCommon(id)
		return row.effectsByLevel[index(level, row.maxLevel) + 1]
	end
	function api.getEpic(id)
		if type(id) ~= "string" or d.epic[id] == nil then fail("UNSUPPORTED_RESEARCH") end
		return d.epic[id]
	end
	function api.epicPrice(id, currentLevel)
		local row = api.getEpic(id)
		index(currentLevel, row.maxLevel)
		if currentLevel == row.maxLevel then fail("MAX_LEVEL") end
		return row.prices[currentLevel + 1]
	end
	function api.epicEffects(id, level)
		local row = api.getEpic(id)
		return row.effectsByLevel[index(level, row.maxLevel) + 1]
	end
	function api.tierThreshold(tierRaw) return d.tierThresholds[index(tierRaw, #d.tierThresholds - 1) + 1] end
	function api.getEgg(eggIndex)
		return d.eggs[index(eggIndex, #d.eggs - 1) + 1]
	end
	function api.getHabitat(typeIndex) return d.habitats[index(typeIndex, #d.habitats - 1) + 1] end
	function api.habitatPrice(typeIndex, slotIndex)
		return api.getHabitat(typeIndex).prices[index(slotIndex, 3) + 1]
	end
	function api.getVehicle(typeIndex) return d.vehicles[index(typeIndex, #d.vehicles - 1) + 1] end
	function api.vehiclePrice(typeIndex, sameTypeOwned)
		local row = api.getVehicle(typeIndex)
		return row.prices[index(sameTypeOwned, #row.prices - 1) + 1]
	end
	return table.freeze(api)
end

return table.freeze(CatalogRegistry)
