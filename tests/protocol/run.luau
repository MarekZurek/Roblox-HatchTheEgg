--!nocheck
local Codec = require("../../src/shared/NumericCodec")
local Schemas = require("../../src/shared/ProtocolSchemas")
local P = Schemas.new(Codec)
local fs, serde = require("@lune/fs"), require("@lune/serde")
local assertions = 0
local function check(value, expected, direction)
	local valid, code = (if direction == "server" then P.validateServer else P.validateClient)(value)
	assertions += 1; assert(valid == expected, "Unexpected validity for " .. tostring(if type(value) == "table" then value.kind else type(value)))
	assertions += 1; assert(code == (if expected then nil else "INVALID_REQUEST"), "Error contract")
end
local function copy(value)
	if type(value) ~= "table" then return value end
	local result = {}; for k, v in value do result[k] = copy(v) end; return result
end
local messages = {
	{ protocolVersion = 1, requestId = "request-1", kind = "Bootstrap" },
	{ protocolVersion = 1, requestId = "request-1", kind = "RefreshState" },
	{ protocolVersion = 1, requestId = "request-1", kind = "OperationStatus", operationId = "op-stable" },
	{ protocolVersion = 1, requestId = "request-1", kind = "HatchPress", streamId = "stream-a", inputSeq = "9007199254740993" },
	{ protocolVersion = 1, requestId = "request-1", kind = "HatchInput", streamId = "stream-a", inputSeq = "2", state = "start" },
}
local args = {
	BuyResearch = { researchId = "comfort_nests", mode = "single", quoteId = "quote-1" },
	BuyHabitat = { habitatId = "COOP", slotId = 1, quoteId = "quote-1" },
	BuyVehicle = { vehicleId = "TRIKE", slotId = 4, quoteId = "quote-1" },
}
for kind, target in args do
	table.insert(messages, { protocolVersion = 1, requestId = "req-a", kind = kind, operationId = "op-stable", expectedRevision = "18446744073709551615", args = target })
	local quoteArgs = copy(target); quoteArgs.quoteId = nil
	table.insert(messages, { protocolVersion = 1, requestId = "req-q", kind = "QuoteRequest", target = { kind = kind, args = quoteArgs } })
end
for _, message in messages do
	check(message, true)
	for _, forbidden in { "playerId", "price", "cash", "clock", "sessionToken", "ledger", "viewSeq", "count" } do
		local bad = copy(message); bad[forbidden] = "1"; check(bad, false)
	end
	for key in message do local bad = copy(message); bad[key] = nil; check(bad, false) end
	local bad = copy(message); bad.protocolVersion = 2; check(bad, false)
	bad = copy(message); bad.requestId = ""; check(bad, false)
	bad = copy(message); bad.requestId = string.rep("a", 97); check(bad, false)
	bad = copy(message); bad.requestId = "bad\nrequest"; check(bad, false)
	check(message, false, "server")
end
for kind, target in args do
	local message = { protocolVersion = 1, requestId = "r", kind = kind, operationId = "op", expectedRevision = "0", args = copy(target) }
	for _, number in { 0, "00", "01", "-1", "1.0", "1e0", "18446744073709551616", " 1", "" } do
		local bad = copy(message); bad.expectedRevision = number; check(bad, false)
	end
	local bad = copy(message); bad.args.quoteId = nil; check(bad, false)
	bad = copy(message); bad.args.price = "0"; check(bad, false)
	bad = copy(message); bad.args.count = 99; check(bad, false)
	-- Transport metadata does not silently rewrite stable operation identity.
	local repeatMessage = copy(message); repeatMessage.requestId = "r-new"; repeatMessage.expectedRevision = "9007199254740993"
	check(repeatMessage, true); assert(repeatMessage.operationId == message.operationId); assertions += 1
end
local press = messages[4]
for _, field in { "operationId", "expectedRevision", "quoteId", "heldSeconds", "count", "serverObservedAt" } do
	local bad = copy(press); bad[field] = "1"; check(bad, false)
end
for _, state in { "start", "refresh", "stop" } do local message = copy(messages[5]); message.state = state; check(message, true) end
local badHold = copy(messages[5]); badHold.state = "click"; check(badHold, false)
local badSlot = { protocolVersion = 1, requestId = "r", kind = "BuyHabitat", operationId = "o", expectedRevision = "0", args = copy(args.BuyHabitat) }
for _, value in { 0, 5, -1, 1.5, "1", math.huge, 0/0 } do local bad = copy(badSlot); bad.args.slotId = value; check(bad, false) end
local max = copy(badSlot); max.kind = "BuyResearch"; max.args = copy(args.BuyResearch); max.args.mode = "max"; check(max, false)
for _, kind in { "GrantCash", "PreparePurchase", "ClaimOffer", "FusePets", "Prestige", "BuySilo" } do local bad = copy(badSlot); bad.kind = kind; check(bad, false) end

local own = {
	lifecycle = "ready", eggIndex = 0, cash = "1.25", habitats = {},
	hatchery = { stock = "250", capacity = "250", refillPerSecond = "3" },
	fleet = { vehicles = { { slotId = 1, vehicleIndex = 0 } }, shippingPerMinute = "5000" },
	producedEggsPerSecond = "1", soldEggsPerSecond = "1", cashIncomePerSecond = "0.25",
	common = { { researchId = "comfort_nests", level = 0, available = true } },
}
for i = 1, 4 do table.insert(own.habitats, { slotId = i, population = "0", reservedInTransit = "0", capacity = "250", habitatIndex = 0 }) end
local snapshot = { protocolVersion = 1, numericCodecVersion = 1, viewSchemaVersion = 1, configRevision = "test-only-v1", calculationVersion = 1,
	kind = "StateSnapshot", requestId = "r", streamId = "stream-a", commitRevision = "9007199254740993", viewSeq = "4", serverObservedAt = 1792800000000,
	view = { audience = "own", farm = own } }
check(snapshot, true, "server"); check(snapshot, false)
local unsupportedCalculation = copy(snapshot); unsupportedCalculation.calculationVersion = "1"; check(unsupportedCalculation, false, "server")
unsupportedCalculation.calculationVersion = 2; check(unsupportedCalculation, false, "server")
local public = copy(snapshot); public.view = { audience = "public", farm = { eggIndex = 0, population = "0", habitats = { { slotId = 1, habitatIndex = 0 } }, vehicles = {} } }
check(public, true, "server")
for _, key in { "cash", "GE", "pets", "sessionToken", "receiptId", "ledger", "schemaVersion" } do
	local bad = copy(public); bad.view.farm[key] = "0"; check(bad, false, "server")
	bad = copy(snapshot); bad.view.farm[key] = if key == "cash" then "-1" else "0"; check(bad, false, "server")
end
for _, number in { 1.25, "NaN", "inf", "1e999", "1e-999", "01", "1.250", "-0", "-1" } do
	local bad = copy(snapshot); bad.view.farm.cash = number; check(bad, false, "server")
end
for _, invalid in { "0", -1, 1.5, 9007199254740992, math.huge } do local bad = copy(snapshot); bad.serverObservedAt = invalid; check(bad, false, "server") end
for _, life in { "loading", "offlineSettling", "ready", "sessionLost" } do local candidate = copy(snapshot); candidate.view.farm.lifecycle = life; check(candidate, true, "server") end
local delta = copy(snapshot); delta.kind = "StateDelta"; delta.requestId = nil; delta.view = nil; delta.baseViewSeq = "3"; delta.changes = { audience = "own", farm = { fleet = { vehicles = {}, shippingPerMinute = "0" } } }
check(delta, true, "server")
for _, base in { "4", "5", "18446744073709551615" } do local bad = copy(delta); bad.baseViewSeq = base; check(bad, false, "server") end
local bad = copy(delta); bad.changes.farm["cash.amount"] = "2"; check(bad, false, "server")
bad = copy(delta); bad.changes.farm.sessionToken = "secret"; check(bad, false, "server")
local duplicate = copy(snapshot); table.insert(duplicate.view.farm.common, copy(duplicate.view.farm.common[1])); check(duplicate, false, "server")
local sparse = copy(snapshot); sparse.view.farm.habitats = { [2] = copy(own.habitats[1]) }; check(sparse, false, "server")
local mixed = copy(snapshot); mixed.view.farm.habitats.extra = copy(own.habitats[1]); check(mixed, false, "server")
local incomplete = copy(snapshot); table.remove(incomplete.view.farm.habitats); check(incomplete, false, "server")
local smallIndex = copy(snapshot); smallIndex.view.farm.common[1].level = "0"; check(smallIndex, false, "server")

local quote = { protocolVersion = 1, kind = "QuoteView", requestId = "r", quoteId = "q", expectedRevision = "0", target = { kind = "BuyResearch", args = { researchId = "comfort_nests", mode = "single" } }, cashCost = "2", currency = "cash", numericCodecVersion = 1, calculationVersion = 1, nextLevel = 1, available = true, configRevision = "test-only-v1", expiresAt = 1000 }
check(quote, true, "server")
for key in quote do local bad = copy(quote); bad[key] = nil; check(bad, false, "server") end
for _, kind in { "BuyHabitat", "BuyVehicle" } do
	local candidate = copy(quote); candidate.target.kind = kind; candidate.target.args = copy(args[kind]); candidate.target.args.quoteId = nil
	candidate.nextLevel = nil; candidate.resultIndex = 0; check(candidate, true, "server")
end
local result = { protocolVersion = 1, kind = "CommandResult", requestId = "r", operationId = "o", status = "APPLIED", resultRevision = "1", currentCommitRevision = "2", streamId = "s", serverObservedAt = 1000,
	result = { terminalStatus = "APPLIED", actionKind = "BuyResearch", researchId = "comfort_nests", level = 1 } }
check(result, true, "server")
for _, status in { "APPLIED", "REPLAYED" } do local candidate = copy(result); candidate.status = status; check(candidate, true, "server") end
local rejected = copy(result); rejected.status = "REJECTED"; rejected.result = { terminalStatus = "REJECTED", errorCode = "INSUFFICIENT_CASH" }; check(rejected, true, "server")
rejected.status = "REPLAYED"; check(rejected, true, "server")
for _, status in { "PENDING", "UNKNOWN", "NOT_APPLIED" } do
	local candidate = copy(result); candidate.status = status; candidate.result = nil; candidate.resultRevision = nil; check(candidate, true, "server")
	candidate.resultRevision = "1"; check(candidate, false, "server")
end
bad = copy(result); bad.status = "REJECTED"; check(bad, false, "server")
bad = copy(result); bad.result.sessionToken = "secret"; check(bad, false, "server")
bad = copy(result); bad.resultRevision = "3"; check(bad, false, "server")
local admission = { protocolVersion = 1, kind = "Admission", requestId = "r", operationId = "o", admission = "NOT_ACCEPTED", errorCode = "SESSION_NOT_READY" }
check(admission, true, "server"); admission.terminalStatus = "NOT_APPLIED"; check(admission, false, "server")

for _, value in { 1, true, "Bootstrap", function() end, buffer.create(1) } do check(value, false); check(value, false, "server") end
local cycle = copy(messages[1]); cycle.loop = cycle; check(cycle, false)
local meta = setmetatable(copy(messages[1]), { __index = function() error("Metamethod must not execute") end }); check(meta, false)
local alias = copy(messages[1]); alias.a = {}; alias.b = alias.a; check(alias, false)
local deep = copy(messages[1]); local cursor = deep; for _ = 1, 12 do cursor.extra = {}; cursor = cursor.extra end; check(deep, false)
local huge = copy(messages[1]); huge.extra = {}; for i = 1, 2100 do huge.extra[i] = "x" end; check(huge, false)
local bytes = copy(messages[1]); bytes.extra = {}; for i = 1, 300 do bytes.extra[i] = string.rep("x", 256) end; check(bytes, false)
local long = copy(messages[1]); long.requestId = string.rep("a", 257); check(long, false)
local hostileKey = copy(messages[1]); hostileKey[{}] = "x"; check(hostileKey, false)
local invalidUTF8 = copy(messages[1]); invalidUTF8.requestId = string.char(255); check(invalidUTF8, false)
local invalidUTF8Key = copy(messages[1]); invalidUTF8Key[string.char(255)] = "x"; check(invalidUTF8Key, false)
-- Lune's Roblox instance representation is not a Studio runtime test.
local Instance = require("@lune/roblox").Instance
check(Instance.new("Folder"), false)
local instancePayload = copy(messages[1]); instancePayload.extra = Instance.new("Folder"); check(instancePayload, false)

fs.writeFile("build/protocol-results.json", serde.encode("json", { status = "PASS", assertions = assertions, protocolVersion = 1, runtime = "Lune", studioTested = false, datastoreTested = false }, true))
print("Protocol schemas: " .. assertions .. " assertions PASS")
