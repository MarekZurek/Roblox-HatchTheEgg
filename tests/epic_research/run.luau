--!strict
-- Comprehensive Epic Research Test Suite (Protocol, Server, ViewProjector, Economy Impact, Replay, ClientBootstrap & HUD)
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local C = require("../../src/shared/NumericCodec")
local ProtocolSchemas = require("../../src/shared/ProtocolSchemas").new(C)
local CatalogData = require("../../src/server/CatalogRegistry/Data")
local CatalogRegistry = require("../../src/server/CatalogRegistry")
local Catalog = CatalogRegistry.new(C, CatalogData, { mode = "INTERNAL_TEST_ONLY" })
local FarmActions = require("../../src/server/FarmActions")
local ServerBootstrap = require("../../src/server/Bootstrap")
local ClientBootstrap = require("../../src/client/Bootstrap")
local ProfileSchema = require("../../src/server/ProfileSchema").new(C)
local ProductionMath = require("../../src/server/FarmMath/production_research").new(C, Catalog, { mode = "INTERNAL_TEST_ONLY" })
local ViewProjectorMod = require("../../src/server/ViewProjector")

local Availability = require("../../src/shared/FeatureAvailability")
local assertions = 0
local function eq(a: any, b: any, label: string?)
	assertions += 1
	assert(a == b, (label or "") .. " expected " .. tostring(b) .. " got " .. tostring(a))
end

local function ok(cond: any, label: string?)
	assertions += 1
	assert(cond, label or "condition failed")
end

local function deepCopy(t: any): any
	if type(t) ~= "table" then return t end
	local copy = {}
	for k, v in t do copy[k] = deepCopy(v) end
	return copy
end

print("======================================================================")
print("HatchTheEgg - Epic Research Integration Suite")
print("======================================================================")

-- ============================================================================
-- Section A: ProtocolSchemas Validation for BuyEpicResearch
-- ============================================================================
print("--- [A] ProtocolSchemas Validation for BuyEpicResearch ---")
do
	-- Valid client BuyEpicResearch command
	local validClientCmd = {
		protocolVersion = 1,
		requestId = "req-epic-1",
		kind = "BuyEpicResearch",
		operationId = "op-epic-1",
		expectedRevision = "1",
		args = {
			researchId = "hold_to_hatch",
		},
	}
	local okClient, errClient = ProtocolSchemas.validateClient(validClientCmd)
	ok(okClient, "Valid BuyEpicResearch client packet passes validation: " .. tostring(errClient))

	-- Invalid: missing researchId
	local missingResearchId = {
		protocolVersion = 1,
		requestId = "req-epic-2",
		kind = "BuyEpicResearch",
		operationId = "op-epic-2",
		expectedRevision = "1",
		args = {},
	}
	local okBad1 = ProtocolSchemas.validateClient(missingResearchId)
	eq(okBad1, false, "Missing researchId rejected by client schema")

	-- Invalid: non-string researchId
	local nonStringResearchId = {
		protocolVersion = 1,
		requestId = "req-epic-3",
		kind = "BuyEpicResearch",
		operationId = "op-epic-3",
		expectedRevision = "1",
		args = { researchId = 123 },
	}
	local okBad2 = ProtocolSchemas.validateClient(nonStringResearchId)
	eq(okBad2, false, "Non-string researchId rejected by client schema")

	-- Invalid: researchId with illegal characters
	local illegalCharId = {
		protocolVersion = 1,
		requestId = "req-epic-4",
		kind = "BuyEpicResearch",
		operationId = "op-epic-4",
		expectedRevision = "1",
		args = { researchId = "bad/id!@" },
	}
	local okBad3 = ProtocolSchemas.validateClient(illegalCharId)
	eq(okBad3, false, "Illegal characters in researchId rejected by client schema")

	-- Valid server CommandResult with BuyEpicResearch APPLIED
	local validServerApplied = {
		protocolVersion = 1,
		kind = "CommandResult",
		requestId = "req-epic-1",
		operationId = "op-epic-1",
		status = "APPLIED",
		currentCommitRevision = "2",
		resultRevision = "2",
		streamId = "stream-1",
		serverObservedAt = 1000000,
		result = {
			terminalStatus = "APPLIED",
			actionKind = "BuyEpicResearch",
			success = true,
			researchId = "hold_to_hatch",
			level = 1,
			costGE = "10",
		},
	}
	local okServer, errServer = ProtocolSchemas.validateServer(validServerApplied)
	ok(okServer, "Server APPLIED CommandResult passes validation: " .. tostring(errServer))

	-- Valid server CommandResult with BuyEpicResearch REJECTED
	local validServerRejected = {
		protocolVersion = 1,
		kind = "CommandResult",
		requestId = "req-epic-1",
		operationId = "op-epic-1",
		status = "REJECTED",
		currentCommitRevision = "2",
		resultRevision = "2",
		streamId = "stream-1",
		serverObservedAt = 1000000,
		result = {
			terminalStatus = "REJECTED",
			errorCode = "INSUFFICIENT_GE",
		},
	}
	local okServerRej, errServerRej = ProtocolSchemas.validateServer(validServerRejected)
	ok(okServerRej, "Server REJECTED CommandResult passes validation: " .. tostring(errServerRej))
end

-- ============================================================================
-- Section B: Successful Epic Research Purchase & Balance Update
-- ============================================================================
print("--- [B] Successful Epic Research Purchase & Balance Update ---")
do
	local nowMs = 1000000
	local mockClock = {
		utcNowMs = function() return nowMs end,
		elapsedNowSeconds = function() return 0 end,
	}

	local server = ServerBootstrap.new({
		clock = mockClock,
		initialNowMs = nowMs,
	})

	local initialFixture = ProfileSchema.createReference("101", nowMs)
	initialFixture.permanent.GE = "1000"
	initialFixture.permanent.totalGESpent = "0"
	initialFixture.permanent.epic = {}

	local joinRes, joinErr = server:playerJoined("101", initialFixture)
	ok(joinRes ~= nil, "playerJoined succeeded: " .. tostring(joinErr))

	-- Buy hold_to_hatch (Lvl 1 cost is 10 GE)
	local buyPacket = {
		protocolVersion = 1,
		requestId = "req-b-1",
		kind = "BuyEpicResearch",
		operationId = "op-b-1",
		expectedRevision = "0",
		args = { researchId = "hold_to_hatch" },
	}
	local res = server:dispatch("101", buyPacket)
	ok(res ~= nil, "dispatch returned response")
	eq(res.status, "APPLIED", "status is APPLIED")
	ok(res.result ~= nil, "result exists")
	eq(res.result.success, true, "success is true")
	eq(res.result.researchId, "hold_to_hatch", "researchId is hold_to_hatch")
	eq(res.result.level, 1, "level is 1")
	eq(res.result.costGE, "10", "costGE is 10")

	local coord = server:getCoordinator("101")
	local durable = coord.snapshots().durable
	eq(durable.permanent.GE, "990", "GE correctly deducted (1000 - 10 = 990)")
	eq(durable.permanent.totalGESpent, "10", "totalGESpent correctly incremented to 10")
	eq(durable.permanent.epic.hold_to_hatch, 1, "epic level for hold_to_hatch is 1")

	server:playerLeaving("101")
end

-- ============================================================================
-- Section C: Price Scaling on Subsequent Levels (1 -> 2 -> 3)
-- ============================================================================
print("--- [C] Price Scaling on Subsequent Levels (1 -> 2 -> 3) ---")
do
	local nowMs = 1000000
	local mockClock = {
		utcNowMs = function() return nowMs end,
		elapsedNowSeconds = function() return 0 end,
	}
	local server = ServerBootstrap.new({ clock = mockClock, initialNowMs = nowMs })
	local fixture = ProfileSchema.createReference("102", nowMs)
	fixture.permanent.GE = "5000"
	fixture.permanent.totalGESpent = "0"
	fixture.permanent.epic = {}
	server:playerJoined("102", fixture)

	local row = Catalog.getEpic("hold_to_hatch")
	local p1 = row.prices[1] -- 10
	local p2 = row.prices[2] -- 45
	local p3 = row.prices[3] -- 80
	eq(p1, 10, "Lvl 1 price is 10")
	eq(p2, 45, "Lvl 2 price is 45")
	eq(p3, 80, "Lvl 3 price is 80")

	-- Purchase 1
	local res1 = server:dispatch("102", {
		protocolVersion = 1, requestId = "req-c-1", kind = "BuyEpicResearch",
		operationId = "op-c-1", expectedRevision = "0", args = { researchId = "hold_to_hatch" },
	})
	eq(res1.status, "APPLIED")
	eq(res1.result.level, 1)
	eq(res1.result.costGE, "10")

	-- Purchase 2
	local coord = server:getCoordinator("102")
	local rev1 = coord.snapshots().durable.meta.revision
	local res2 = server:dispatch("102", {
		protocolVersion = 1, requestId = "req-c-2", kind = "BuyEpicResearch",
		operationId = "op-c-2", expectedRevision = rev1, args = { researchId = "hold_to_hatch" },
	})
	eq(res2.status, "APPLIED")
	eq(res2.result.level, 2)
	eq(res2.result.costGE, "45")

	-- Purchase 3
	local rev2 = coord.snapshots().durable.meta.revision
	local res3 = server:dispatch("102", {
		protocolVersion = 1, requestId = "req-c-3", kind = "BuyEpicResearch",
		operationId = "op-c-3", expectedRevision = rev2, args = { researchId = "hold_to_hatch" },
	})
	eq(res3.status, "APPLIED")
	eq(res3.result.level, 3)
	eq(res3.result.costGE, "80")

	local profile = coord.snapshots().durable
	eq(profile.permanent.epic.hold_to_hatch, 3, "Final level is 3")
	eq(profile.permanent.GE, tostring(5000 - 10 - 45 - 80), "Balance after 3 upgrades: 4865")
	eq(profile.permanent.totalGESpent, tostring(10 + 45 + 80), "Total spent: 135")

	server:playerLeaving("102")
end

-- ============================================================================
-- Section D: Rejection on Insufficient GE (INSUFFICIENT_GE)
-- ============================================================================
print("--- [D] Rejection on Insufficient GE (INSUFFICIENT_GE) ---")
do
	local nowMs = 1000000
	local mockClock = { utcNowMs = function() return nowMs end, elapsedNowSeconds = function() return 0 end }
	local server = ServerBootstrap.new({ clock = mockClock, initialNowMs = nowMs })
	local fixture = ProfileSchema.createReference("103", nowMs)
	fixture.permanent.GE = "5" -- hold_to_hatch costs 10
	fixture.permanent.totalGESpent = "0"
	fixture.permanent.epic = {}
	server:playerJoined("103", fixture)

	local res = server:dispatch("103", {
		protocolVersion = 1, requestId = "req-d-1", kind = "BuyEpicResearch",
		operationId = "op-d-1", expectedRevision = "0", args = { researchId = "hold_to_hatch" },
	})
	eq(res.status, "REJECTED", "Purchase rejected due to insufficient GE")
	eq(res.result.errorCode, "INSUFFICIENT_GE", "errorCode is INSUFFICIENT_GE")

	local coord = server:getCoordinator("103")
	local durable = coord.snapshots().durable
	eq(durable.permanent.GE, "5", "GE balance unchanged after rejection")
	eq(durable.permanent.totalGESpent, "0", "totalGESpent unchanged after rejection")
	eq(durable.permanent.epic.hold_to_hatch, nil, "epic research level not set")

	server:playerLeaving("103")
end

-- ============================================================================
-- Section E: Rejection on Max Level (MAX_LEVEL)
-- ============================================================================
print("--- [E] Rejection on Max Level (MAX_LEVEL) ---")
do
	local nowMs = 1000000
	local mockClock = { utcNowMs = function() return nowMs end, elapsedNowSeconds = function() return 0 end }
	local server = ServerBootstrap.new({ clock = mockClock, initialNowMs = nowMs })
	local fixture = ProfileSchema.createReference("104", nowMs)
	fixture.permanent.GE = "10000000"
	fixture.permanent.epic = { prophecy_bonus = 5 } -- prophecy_bonus maxLevel is 5
	server:playerJoined("104", fixture)

	local res = server:dispatch("104", {
		protocolVersion = 1, requestId = "req-e-1", kind = "BuyEpicResearch",
		operationId = "op-e-1", expectedRevision = "0", args = { researchId = "prophecy_bonus" },
	})
	eq(res.status, "REJECTED", "Purchase at maxLevel rejected")
	eq(res.result.errorCode, "MAX_LEVEL", "errorCode is MAX_LEVEL")

	local coord = server:getCoordinator("104")
	local durable = coord.snapshots().durable
	eq(durable.permanent.epic.prophecy_bonus, 5, "Level stays at 5")
	eq(durable.permanent.GE, "10000000", "GE balance unchanged")

	server:playerLeaving("104")
end

-- ============================================================================
-- Section F: Rejection on Unsupported Research ID (UNSUPPORTED_RESEARCH)
-- ============================================================================
print("--- [F] Rejection on Unsupported Research ID (UNSUPPORTED_RESEARCH) ---")
do
	local nowMs = 1000000
	local mockClock = { utcNowMs = function() return nowMs end, elapsedNowSeconds = function() return 0 end }
	local server = ServerBootstrap.new({ clock = mockClock, initialNowMs = nowMs })
	local fixture = ProfileSchema.createReference("105", nowMs)
	fixture.permanent.GE = "1000"
	server:playerJoined("105", fixture)

	local res = server:dispatch("105", {
		protocolVersion = 1, requestId = "req-f-1", kind = "BuyEpicResearch",
		operationId = "op-f-1", expectedRevision = "0", args = { researchId = "non_existent_epic_id" },
	})
	eq(res.status, "REJECTED", "Purchase with invalid id rejected")
	eq(res.result.errorCode, "UNSUPPORTED_RESEARCH", "errorCode is UNSUPPORTED_RESEARCH")

	local coord = server:getCoordinator("105")
	local durable = coord.snapshots().durable
	eq(durable.permanent.GE, "1000", "GE balance unchanged")

	server:playerLeaving("105")
end

-- ============================================================================
-- Section G: Idempotency & Replay Protection
-- ============================================================================
print("--- [G] Idempotency & Replay Protection ---")
do
	local nowMs = 1000000
	local mockClock = { utcNowMs = function() return nowMs end, elapsedNowSeconds = function() return 0 end }
	local server = ServerBootstrap.new({ clock = mockClock, initialNowMs = nowMs })
	local fixture = ProfileSchema.createReference("106", nowMs)
	fixture.permanent.GE = "1000"
	fixture.permanent.totalGESpent = "0"
	fixture.permanent.epic = {}
	server:playerJoined("106", fixture)

	local packet = {
		protocolVersion = 1,
		requestId = "req-g-1",
		kind = "BuyEpicResearch",
		operationId = "op-idempotent-repeat",
		expectedRevision = "0",
		args = { researchId = "hold_to_hatch" },
	}

	-- First dispatch
	local res1 = server:dispatch("106", packet)
	eq(res1.status, "APPLIED", "First dispatch applied")
	eq(res1.result.level, 1)

	local coord = server:getCoordinator("106")
	local geAfterFirst = coord.snapshots().durable.permanent.GE
	eq(geAfterFirst, "990", "GE is 990 after first purchase")

	-- Replay: exactly the same operationId submitted again
	local replayRes = server:dispatch("106", packet)
	eq(replayRes.status, "REPLAYED", "Duplicate operationId returns REPLAYED")
	eq(replayRes.result.terminalStatus, "APPLIED", "terminalStatus in result is APPLIED")
	eq(replayRes.result.actionKind, "BuyEpicResearch", "actionKind in result is BuyEpicResearch")
	eq(replayRes.result.level, 1, "level in replayed result is 1")
	eq(replayRes.result.costGE, "10", "costGE in replayed result is 10")

	local geAfterReplay = coord.snapshots().durable.permanent.GE
	eq(geAfterReplay, "990", "GE balance NOT deducted again on replay")
	eq(coord.snapshots().durable.permanent.epic.hold_to_hatch, 1, "Level NOT incremented again on replay")
	eq(coord.snapshots().durable.permanent.totalGESpent, "10", "totalGESpent NOT doubled on replay")

	server:playerLeaving("106")
end

-- ============================================================================
-- Section H: ViewProjector Epic Progress & Delta Generation
-- ============================================================================
print("--- [H] ViewProjector Epic Progress & Delta Generation ---")
do
	local projector = ViewProjectorMod.new({
		codec = C,
		catalog = Catalog,
		productionMath = ProductionMath,
		configRevision = "cfg:1",
	})

	local profile = ProfileSchema.createReference("107", 1000000)
	profile.permanent.GE = "500"
	profile.permanent.epic = {
		hold_to_hatch = 3,
		cheaper_contractors = 2,
		lab_upgrade = 1,
	}

	local snap = projector:projectPrivateView(profile, "stream-107", "1", 1000000, "req-snap-1")
	ok(snap ~= nil, "Snapshot created")
	eq(snap.kind, "StateSnapshot")
	local progress = snap.view.farm.progress
	ok(progress ~= nil, "farm.progress exists in snapshot")
	ok(progress.epic ~= nil, "farm.progress.epic exists in snapshot")
	eq(progress.epic.hold_to_hatch, 3, "snapshot has hold_to_hatch = 3")
	eq(progress.epic.cheaper_contractors, 2, "snapshot has cheaper_contractors = 2")
	eq(progress.epic.lab_upgrade, 1, "snapshot has lab_upgrade = 1")

	local okSnapVal, errSnapVal = ProtocolSchemas.validateServer(snap)
	ok(okSnapVal, "Snapshot with progress.epic passes ProtocolSchemas validation: " .. tostring(errSnapVal))

	-- Mutate epic progress and generate Delta
	local profile2 = deepCopy(profile)
	profile2.permanent.epic.hold_to_hatch = 4
	profile2.meta.revision = "1"
	local snap2 = projector:projectPrivateView(profile2, "stream-107", "2", 1001000, "req-snap-2")

	local delta = projector:createDelta(snap, snap2, "stream-107", "1", "1", "2", 1001000)
	ok(delta ~= nil, "Delta created")
	eq(delta.kind, "StateDelta")
	local deltaChanges = delta.changes.farm
	ok(deltaChanges.progress ~= nil, "progress section present in changes")
	eq(deltaChanges.progress.epic.hold_to_hatch, 4, "delta reflects updated hold_to_hatch = 4")

	local okDeltaVal, errDeltaVal = ProtocolSchemas.validateServer(delta)
	ok(okDeltaVal, "Delta with progress.epic passes ProtocolSchemas validation: " .. tostring(errDeltaVal))
end

-- ============================================================================
-- Section I: Real Economic Impact on Quotes (FarmActions.createQuote)
-- ============================================================================
print("--- [I] Real Economic Impact on Quotes (FarmActions.createQuote) ---")
do
	local profileBase = ProfileSchema.createReference("108", 1000000)
	profileBase.permanent.epic = {}
	profileBase.farm.cash = "10000000000"

	-- 1. Habitat Quote with cheaper_contractors
	local habTarget = { kind = "BuyHabitat", args = { slotId = 1, habitatId = "SHACK" } }
	local quoteHabBase = FarmActions.createQuote(profileBase, Catalog, habTarget, "req-q1", "0", "q-hab-base", 1000000, "cfg:1")
	ok(quoteHabBase.available, "Base habitat quote available")
	local baseHabCost = C.BigAmount.decode(quoteHabBase.cashCost)

	-- Profile with cheaper_contractors = 5 (each level reduces hab cost by 5%)
	local profileWithDiscount = deepCopy(profileBase)
	profileWithDiscount.permanent.epic = { cheaper_contractors = 5 }
	local quoteHabDiscounted = FarmActions.createQuote(profileWithDiscount, Catalog, habTarget, "req-q2", "0", "q-hab-disc", 1000000, "cfg:1")
	ok(quoteHabDiscounted.available, "Discounted habitat quote available")
	local discountedHabCost = C.BigAmount.decode(quoteHabDiscounted.cashCost)

	ok(discountedHabCost < baseHabCost, "Habitat cost strictly lower with cheaper_contractors (" .. tostring(discountedHabCost) .. " < " .. tostring(baseHabCost) .. ")")
	local expectedMult = Catalog.epicEffects("cheaper_contractors", 5).habCostMult
	local actualRatio = discountedHabCost / baseHabCost
	ok(math.abs(actualRatio - expectedMult) < 1e-6, "Habitat discount matches exact habCostMult (" .. tostring(actualRatio) .. " == " .. tostring(expectedMult) .. ")")

	-- 2. Common Research Quote with lab_upgrade / cheaper_research
	local resTarget = { kind = "BuyResearch", args = { researchId = "comfy_nests", mode = "single" } }
	local quoteResBase = FarmActions.createQuote(profileBase, Catalog, resTarget, "req-q3", "0", "q-res-base", 1000000, "cfg:1")
	ok(quoteResBase.available, "Base research quote available")
	local baseResCost = C.BigAmount.decode(quoteResBase.cashCost)

	-- With lab_upgrade alias (level 4)
	local profileWithLabUpgrade = deepCopy(profileBase)
	profileWithLabUpgrade.permanent.epic = { lab_upgrade = 4 }
	local quoteResLab = FarmActions.createQuote(profileWithLabUpgrade, Catalog, resTarget, "req-q4", "0", "q-res-lab", 1000000, "cfg:1")
	local labResCost = C.BigAmount.decode(quoteResLab.cashCost)
	ok(labResCost < baseResCost, "Research cost strictly lower with lab_upgrade (" .. tostring(labResCost) .. " < " .. tostring(baseResCost) .. ")")

	-- With canonical cheaper_research (level 4)
	local profileWithCheaperResearch = deepCopy(profileBase)
	profileWithCheaperResearch.permanent.epic = { cheaper_research = 4 }
	local quoteResCheaper = FarmActions.createQuote(profileWithCheaperResearch, Catalog, resTarget, "req-q5", "0", "q-res-cheaper", 1000000, "cfg:1")
	local cheaperResCost = C.BigAmount.decode(quoteResCheaper.cashCost)

	eq(labResCost, cheaperResCost, "lab_upgrade and cheaper_research produce identical discount")
	local expectedResMult = Catalog.epicEffects("cheaper_research", 4).researchCostMult
	local actualResRatio = labResCost / baseResCost
	ok(math.abs(actualResRatio - expectedResMult) < 1e-6, "Research discount matches exact researchCostMult (" .. tostring(actualResRatio) .. " == " .. tostring(expectedResMult) .. ")")
end

-- ============================================================================
-- Section J: ClientBootstrap & ClientStateStore End-to-End Flow
-- ============================================================================
print("--- [J] ClientBootstrap & ClientStateStore End-to-End Flow ---")
do
	local nowMs = 1000000
	local mockClock = {
		utcNowMs = function() return nowMs end,
		elapsedNowSeconds = function() return 0 end,
	}

	local server = ServerBootstrap.new({
		clock = mockClock,
		initialNowMs = nowMs,
	})

	local initialFixture = ProfileSchema.createReference("109", nowMs)
	initialFixture.permanent.GE = "1000"
	initialFixture.permanent.totalGESpent = "0"
	initialFixture.permanent.epic = {}
	server:playerJoined("109", initialFixture)

	local client = ClientBootstrap.new({
		wire = server,
		playerId = "109",
	})

	local bootRes = client:connect("boot-epic-client")
	ok(bootRes ~= nil, "client connected")
	eq(client:getStatus(), "READY", "Client is READY")

	local storeFarm = client:getFarm()
	ok(storeFarm ~= nil, "Store farm view exists")
	ok(storeFarm.progress ~= nil, "Farm progress exists")
	ok(storeFarm.progress.epic ~= nil, "Farm progress epic table exists in client store")

	-- Buy epic research through ClientBootstrap method
	local commandCallbackFired = false
	local commandResultData = nil
	client:buyEpicResearch("epic_hatchery", function(res)
		commandCallbackFired = true
		commandResultData = res
	end)

	ok(commandCallbackFired, "buyEpicResearch callback fired")
	ok(commandResultData ~= nil, "commandResultData received")
	eq(commandResultData.status, "APPLIED", "Purchase applied over client transport")
	eq(commandResultData.result.researchId, "epic_hatchery")
	eq(commandResultData.result.level, 1)

	-- Verify client state store updated through RefreshState
	local updatedFarm = client:getFarm()
	ok(updatedFarm.progress.epic.epic_hatchery == 1, "ClientStateStore progress.epic has epic_hatchery = 1")
	eq(updatedFarm.progress.GE, "998", "ClientStateStore reflects deducted GE (1000 - 2 = 998)")

	-- Check HUD modal opens and shows updated cards
	local hud = client:getHUD()
	ok(hud ~= nil, "HUD exists")
	hud:toggleEpicResearchModal(true)
	local epicModal = hud:getEpicResearchModal()
	ok(epicModal ~= nil, "EpicResearchModal exists")
	eq(epicModal.Visible, true, "EpicResearchModal is Visible")

	-- Trigger HUD update pass to verify formatting
	hud:update()
	local cardData = hud.epicResearchCards["epic_hatchery"]
	ok(cardData ~= nil, "cardData exists for epic_hatchery")
	ok(string.find(cardData.lvlLabel.Text, "1 / 20", 1, true) ~= nil, "Level label shows 1 / 20: " .. cardData.lvlLabel.Text)
	-- Next price for Lvl 2 epic_hatchery is 54 GE
	ok(string.find(cardData.buyBtn.Text, "54 💎", 1, true) ~= nil, "Buy button shows next price (54 💎): " .. cardData.buyBtn.Text)

	hud:destroy()
	client:destroy()
	server:playerLeaving("109")
end

-- ============================================================================
-- Section K: All 23 Active Epic Research Items Integrity & Purchasing Coverage
-- ============================================================================
print("--- [K] All 23 Active Epic Research Items Integrity & Purchasing Coverage ---")
do
	local nowMs = 1000000
	local mockClock = { utcNowMs = function() return nowMs end, elapsedNowSeconds = function() return 0 end }
	local server = ServerBootstrap.new({ clock = mockClock, initialNowMs = nowMs })
	local fixture = ProfileSchema.createReference("110", nowMs)
	fixture.permanent.GE = "100000000" -- large GE pool
	fixture.permanent.totalGESpent = "0"
	fixture.permanent.epic = {}
	server:playerJoined("110", fixture)

	local coord = server:getCoordinator("110")

	for i, epicId in ipairs(Catalog.epicIds) do
		local row = Catalog.getEpic(epicId)
		ok(row ~= nil, "Catalog entry exists for " .. epicId)
		ok(row.maxLevel > 0, "maxLevel > 0 for " .. epicId)
		ok(#row.prices == row.maxLevel, "prices table matches maxLevel for " .. epicId)

		local rev = coord.snapshots().durable.meta.revision
		local res = server:dispatch("110", {
			protocolVersion = 1,
			requestId = "req-k-" .. tostring(i),
			kind = "BuyEpicResearch",
			operationId = "op-k-" .. tostring(i),
			expectedRevision = rev,
			args = { researchId = epicId },
		})

		if not Availability.isEpicAvailable(epicId) then
			eq(res.status,"REJECTED","Unsupported Epic cannot be bought")
			eq(res.result.errorCode,"FEATURE_UNAVAILABLE","Unavailable effect reason")
		else
		eq(res.status, "APPLIED", "Purchase succeeded for epic research: " .. epicId)
		eq(res.result.researchId, epicId, "Returned researchId matches: " .. epicId)
		eq(res.result.level, 1, "Level 1 granted for: " .. epicId)
		eq(res.result.costGE, tostring(row.prices[1]), "Price matches catalog row for: " .. epicId)
		end
	end

	local durable = coord.snapshots().durable
	eq(#Catalog.epicIds, 23, "Catalog contains exactly 23 active epic research items")
	for _, epicId in ipairs(Catalog.epicIds) do
		eq(durable.permanent.epic[epicId], if Availability.isEpicAvailable(epicId) then 1 else nil, "Only supported level recorded for " .. epicId)
	end

	server:playerLeaving("110")
end

print(string.format("======================================================================"))
print(string.format("Epic Research test suite PASS: %d assertions", assertions))
print(string.format("======================================================================"))
