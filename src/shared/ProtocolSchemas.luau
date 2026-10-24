--!nocheck
-- Wire v1, first neutral farm only. Validation does not authorize or execute actions.
local ProtocolSchemas = { VERSION = 1 }
local LIMITS = table.freeze({ maxDepth = 10, maxNodes = 4096, maxBytes = 65536, maxString = 256 })
ProtocolSchemas.LIMITS = LIMITS

local function fail() error("INVALID_REQUEST", 0) end
local function literal(expected)
	return function(value) if value ~= expected then fail() end end
end
local function enum(values)
	return function(value) if not values[value] then fail() end end
end
local function integer(minimum, maximum)
	return function(value)
		if type(value) ~= "number" or value ~= value or value % 1 ~= 0 or value < minimum or value > maximum then fail() end
	end
end
local index = integer(0, 65535)
local slot = integer(1, 4)
local instant = integer(0, 9007199254740991)
local function id(value)
	if type(value) ~= "string" or #value < 1 or #value > 96 or not string.match(value, "^[A-Za-z0-9_:.%- ]+$") then fail() end
end
local function record(required, optional)
	optional = optional or {}
	return function(value)
		if type(value) ~= "table" then fail() end
		for key, check in required do if value[key] == nil then fail() end; check(value[key]) end
		for key, child in value do
			local check = required[key] or optional[key]
			if not check then fail() end
			check(child)
		end
	end
end
local function array(check, maximum, uniqueKey)
	return function(value)
		if type(value) ~= "table" then fail() end
		local n, seen = 0, {}
		for key, child in value do
			if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > maximum then fail() end
			n += 1
			check(child)
			if uniqueKey then
				local keyValue = child[uniqueKey]
				if seen[keyValue] then fail() end
				seen[keyValue] = true
			end
		end
		if n ~= #value then fail() end
		for i = 1, n do if value[i] == nil then fail() end end
	end
end

-- Bounded structural walk precedes schemas: never invoke attacker metamethods.
local function preflight(value)
	local nodes, bytes, seen = 0, 0, {}
	local function walk(child, depth)
		nodes += 1
		if nodes > LIMITS.maxNodes or depth > LIMITS.maxDepth then fail() end
		local kind = type(child)
		if kind == "table" then
			if getmetatable(child) ~= nil or seen[child] then fail() end
			seen[child] = true
			bytes += 2
			for key, item in child do
				if type(key) ~= "string" and type(key) ~= "number" then fail() end
				walk(key, depth + 1); walk(item, depth + 1)
			end
		elseif kind == "string" then
			if #child > LIMITS.maxString or utf8.len(child) == nil then fail() end
			-- Conservative JSON escaped size, including delimiters; UTF-8 bytes count directly.
			bytes += 2
			for i = 1, #child do
				local b = string.byte(child, i)
				bytes += if b < 32 then 6 elseif b == 34 or b == 92 then 2 else 1
			end
		elseif kind == "number" then
			if child ~= child or child == math.huge or child == -math.huge then fail() end
			bytes += 32
		elseif kind == "boolean" then bytes += 5
		else fail() end
		bytes += 2 -- separators / array overhead, conservatively
		if bytes > LIMITS.maxBytes then fail() end
	end
	walk(value, 0)
end

function ProtocolSchemas.new(codec)
	assert(codec.VERSION == 1, "ProtocolSchemas requires NumericCodec v1")
	local function numeric(coder)
		return function(value)
			if type(value) ~= "string" or coder.encode(coder.decode(value)) ~= value then fail() end
		end
	end
	local exact, amount = numeric(codec.ExactUInt), numeric(codec.BigAmount)
	local lifecycle = enum({ loading = true, offlineSettling = true, ready = true, sessionLost = true })
	local action = enum({ BuyResearch = true, BuyHabitat = true, BuyVehicle = true })
	local targetSchemas = {
		BuyResearch = record({ researchId = id, mode = literal("single") }),
		BuyHabitat = record({ slotId = slot, habitatId = id }),
		BuyVehicle = record({ slotId = slot, vehicleId = id }),
	}
	local mutationSchemas = {
		BuyResearch = record({ researchId = id, mode = literal("single"), quoteId = id }),
		BuyHabitat = record({ slotId = slot, habitatId = id, quoteId = id }),
		BuyVehicle = record({ slotId = slot, vehicleId = id, quoteId = id }),
	}
	local function target(value)
		record({ kind = action, args = function(args) if type(value.kind) ~= "string" then fail() end; local check = targetSchemas[value.kind]; if not check then fail() end; check(args) end })(value)
	end
	local client = {}
	for _, name in { "Bootstrap", "RefreshState" } do
		client[name] = record({ protocolVersion = literal(1), requestId = id, kind = literal(name) })
	end
	client.QuoteRequest = record({ protocolVersion = literal(1), requestId = id, kind = literal("QuoteRequest"), target = target })
	client.OperationStatus = record({ protocolVersion = literal(1), requestId = id, kind = literal("OperationStatus"), operationId = id })
	for name, args in mutationSchemas do
		client[name] = record({ protocolVersion = literal(1), requestId = id, kind = literal(name), operationId = id, expectedRevision = exact, args = args })
	end
	client.HatchPress = record({ protocolVersion = literal(1), requestId = id, kind = literal("HatchPress"), streamId = id, inputSeq = exact })
	client.HatchInput = record({ protocolVersion = literal(1), requestId = id, kind = literal("HatchInput"), streamId = id, inputSeq = exact, state = enum({ start = true, refresh = true, stop = true }) })

	local habitat = record({ slotId = slot, population = exact, reservedInTransit = exact, capacity = exact }, { habitatIndex = index })
	local visibleHabitat = record({ slotId = slot }, { habitatIndex = index })
	local vehicle = record({ slotId = slot, vehicleIndex = index })
	local boolean = function(v) if type(v) ~= "boolean" then fail() end end
	local research = record({ researchId = id, level = index, available = boolean }, { blockedReason = id })
	local habitats = array(habitat, 4, "slotId")
	local fourHabitats = function(value) habitats(value); if #value ~= 4 then fail() end end
	local ownFields = {
		lifecycle = lifecycle, eggIndex = index, cash = amount,
		habitats = fourHabitats,
		hatchery = record({ stock = amount, capacity = amount, refillPerSecond = amount }),
		fleet = record({ vehicles = array(vehicle, 4, "slotId"), shippingPerMinute = amount }),
		producedEggsPerSecond = amount, soldEggsPerSecond = amount, cashIncomePerSecond = amount,
		common = array(research, 56, "researchId"),
	}
	local publicFields = { eggIndex = index, population = exact, habitats = array(visibleHabitat, 4, "slotId"), vehicles = array(vehicle, 4, "slotId") }
	local ownView, publicView = record(ownFields), record(publicFields)
	local function view(value)
		if value.audience == "own" then record({ audience = literal("own"), farm = ownView })(value)
		elseif value.audience == "public" then record({ audience = literal("public"), farm = publicView })(value)
		else fail() end
	end
	-- Delta replaces named whole sections. Empty arrays explicitly remove all entries;
	-- an absent section leaves it unchanged. Arbitrary paths and patches are forbidden.
	local function changes(value)
		if value.audience == "own" then record({ audience = literal("own"), farm = record({}, ownFields) })(value)
		elseif value.audience == "public" then record({ audience = literal("public"), farm = record({}, publicFields) })(value)
		else fail() end
	end
	local versionFields = {
		protocolVersion = literal(1), numericCodecVersion = literal(1), viewSchemaVersion = literal(1),
		configRevision = id, calculationVersion = literal(1), streamId = id, commitRevision = exact, viewSeq = exact, serverObservedAt = instant,
	}
	local function extend(base, extra)
		local copy = table.clone(base)
		for key, check in extra do copy[key] = check end
		return copy
	end
	local server = {}
	server.StateSnapshot = record(extend(versionFields, { kind = literal("StateSnapshot"), requestId = id, view = view }))
	local deltaShape = record(extend(versionFields, { kind = literal("StateDelta"), baseViewSeq = exact, changes = changes }))
	server.StateDelta = function(value)
		deltaShape(value)
		if codec.ExactUInt.compare(codec.ExactUInt.decode(value.viewSeq), codec.ExactUInt.decode(value.baseViewSeq)) <= 0 then fail() end
	end
	server.QuoteView = function(value)
		local fields = { protocolVersion = literal(1), numericCodecVersion = literal(1), kind = literal("QuoteView"), requestId = id, quoteId = id,
			expectedRevision = exact, target = target, cashCost = amount, currency = literal("cash"), configRevision = id, calculationVersion = literal(1),
			expiresAt = instant, available = boolean }
		if type(value.target) ~= "table" then fail() end
		if value.target.kind == "BuyResearch" then fields.nextLevel = index else fields.resultIndex = index end
		record(fields, { blockedReason = id })(value)
	end
	local terminal = enum({ APPLIED = true, REJECTED = true })
	local terminalResult = function(value)
		if value.terminalStatus == "REJECTED" then record({ terminalStatus = literal("REJECTED"), errorCode = id })(value)
		elseif value.terminalStatus == "APPLIED" then
			local resultSchemas = {
				BuyResearch = record({ terminalStatus = literal("APPLIED"), actionKind = literal("BuyResearch"), researchId = id, level = index }),
				BuyHabitat = record({ terminalStatus = literal("APPLIED"), actionKind = literal("BuyHabitat"), slotId = slot, habitatId = id }),
				BuyVehicle = record({ terminalStatus = literal("APPLIED"), actionKind = literal("BuyVehicle"), slotId = slot, vehicleId = id }),
			}
			local check = resultSchemas[value.actionKind]; if not check then fail() end; check(value)
		else fail() end
	end
	server.CommandResult = function(value)
		local common = { protocolVersion = literal(1), kind = literal("CommandResult"), requestId = id, operationId = id,
			status = enum({ APPLIED = true, REPLAYED = true, REJECTED = true, NOT_APPLIED = true, PENDING = true, UNKNOWN = true }),
			currentCommitRevision = exact, streamId = id, serverObservedAt = instant }
		if value.status == "APPLIED" or value.status == "REPLAYED" or value.status == "REJECTED" then
			record(extend(common, { resultRevision = exact, result = terminalResult }))(value)
			terminal(value.result.terminalStatus)
			if value.status ~= "REPLAYED" and value.status ~= value.result.terminalStatus then fail() end
			if codec.ExactUInt.compare(codec.ExactUInt.decode(value.resultRevision), codec.ExactUInt.decode(value.currentCommitRevision)) > 0 then fail() end
		else record(common, { errorCode = id })(value) end
	end
	server.Admission = record({ protocolVersion = literal(1), kind = literal("Admission"), requestId = id, admission = literal("NOT_ACCEPTED"), errorCode = id }, { operationId = id })
	local function validate(schemas, value)
		local ok = pcall(function()
			preflight(value)
			if type(value) ~= "table" or type(value.kind) ~= "string" then fail() end
			local check = schemas[value.kind]; if not check then fail() end; check(value)
		end)
		return ok, if ok then nil else "INVALID_REQUEST"
	end
	return table.freeze({
		validateClient = function(value) return validate(client, value) end,
		validateServer = function(value) return validate(server, value) end,
	})
end

return table.freeze(ProtocolSchemas)
