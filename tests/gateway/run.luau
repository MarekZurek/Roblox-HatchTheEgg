--!nocheck
-- Gateway and Authoritative State Projection test suite.
-- Verifies ViewProjector (own view, public view, delta creation)
-- and NetworkGateway (client validation, admission gating, all handlers, player isolation).

local C = require("../../src/shared/NumericCodec")
local Schemas = require("../../src/shared/ProtocolSchemas")
local Protocol = Schemas.new(C)
local Data = require("../../src/server/PersistenceData")
local ProfileSchema = require("../../src/server/ProfileSchema").new(C)
local Repo = require("../../src/server/SessionRepository")
local Coordinator = require("../../src/server/PlayerCoordinator")
local CatalogData = require("../../src/server/CatalogRegistry/Data")
local Catalog = require("../../src/server/CatalogRegistry").new(C, CatalogData, { mode = "INTERNAL_TEST_ONLY" })
local ProductionMath = require("../../src/server/FarmMath/production_research").new(C, Catalog, { mode = "INTERNAL_TEST_ONLY" })
local FarmActions = require("../../src/server/FarmActions")
local ViewProjector = require("../../src/server/ViewProjector")
local NetworkGateway = require("../../src/server/NetworkGateway")
local serde = require("@lune/serde")
local fs = require("@lune/fs")

local assertions = 0
local function eq(a, b, label)
	assertions += 1
	assert(a == b, (label or "") .. " expected " .. tostring(b) .. " got " .. tostring(a))
end

local function ok(cond, label)
	assertions += 1
	assert(cond, label or "condition failed")
end

local function validateServer(payload, label)
	assertions += 1
	local valid, err = Protocol.validateServer(payload)
	assert(valid, (label or "Payload") .. " failed server validation: " .. tostring(err))
	return valid
end

local function validateClient(payload, label)
	assertions += 1
	local valid, err = Protocol.validateClient(payload)
	assert(valid, (label or "Payload") .. " failed client validation: " .. tostring(err))
	return valid
end

-- ============================================================================
-- Section 1: ViewProjector tests (Private View, Public View, Delta)
-- ============================================================================
local projector = ViewProjector.new({
	codec = C,
	catalog = Catalog,
	productionMath = ProductionMath,
	configRevision = "CANONICAL_V1",
})

local function makeTestProfile(playerId, cash, pop1, typeIndex1)
	local p = ProfileSchema.createReference(playerId or "player-1", 1000000)
	p.farm.cash = cash or "1000"
	p.farm.habitats[1].population = pop1 or "100"
	p.farm.habitats[1].typeIndex = if typeIndex1 ~= nil then typeIndex1 else 0
	return p
end

-- 1.1 Private View (audience = "own")
do
	local p = makeTestProfile("player-1", "5000", "200", 0)
	p.farm.common.comfy_nests = 5
	p.farm.common.egg_diet = 2

	local snapshot = projector:projectPrivateView(p, "stream-1", "1", 1000000, "req-1")
	validateServer(snapshot, "projectPrivateView snapshot")

	eq(snapshot.kind, "StateSnapshot")
	eq(snapshot.protocolVersion, 1)
	eq(snapshot.numericCodecVersion, 1)
	eq(snapshot.viewSchemaVersion, 1)
	eq(snapshot.calculationVersion, 1)
	eq(snapshot.streamId, "stream-1")
	eq(snapshot.viewSeq, "1")
	eq(snapshot.serverObservedAt, 1000000)
	eq(snapshot.requestId, "req-1")
	eq(snapshot.view.audience, "own")

	local farm = snapshot.view.farm
	eq(farm.lifecycle, "ready")
	eq(farm.eggIndex, 0)
	eq(farm.cash, "5000")

	-- Habitats
	eq(#farm.habitats, 4, "Must have exactly 4 habitats")
	eq(farm.habitats[1].slotId, 1)
	eq(farm.habitats[1].population, "200")
	eq(farm.habitats[1].habitatIndex, 0)
	eq(farm.habitats[1].capacity, "250")
	eq(farm.habitats[2].slotId, 2)
	eq(farm.habitats[2].population, "0")
	eq(farm.habitats[2].habitatIndex, nil, "Empty slot must not have habitatIndex")
	eq(farm.habitats[2].capacity, "0")

	-- Hatchery
	eq(farm.hatchery.stock, "250")
	eq(farm.hatchery.capacity, "250")
	eq(farm.hatchery.refillPerSecond, "3")

	-- Fleet
	eq(#farm.fleet.vehicles, 1)
	eq(farm.fleet.vehicles[1].slotId, 1)
	eq(farm.fleet.vehicles[1].vehicleIndex, 0)
	eq(farm.fleet.shippingPerMinute, "5000")

	-- Production rates
	-- comfy_nests = 5 -> layingPerChickenPerSecond = (1 + 0.1*5)/30 = 1.5/30 = 0.05
	-- population = 200 -> producedEggsPerSecond = 200 * 0.05 = 10
	eq(farm.producedEggsPerSecond, "10")
	-- shippingPerMinute = 5000 -> shippingPerSecond = 5000/60 = 83.333333333333329
	-- soldEggsPerSecond = min(10, 83.333333333333329) = 10
	eq(farm.soldEggsPerSecond, "10")
	-- egg_diet = 2 -> eggValue = 1.00 * (1 + 0.25*2) = 1.00 * 1.5 = 1.5
	-- cashIncomePerSecond = 10 * 1.5 = 15
	eq(farm.cashIncomePerSecond, "15")

	-- Common research list: exactly 14 entries
	eq(#farm.common, 14, "Must contain all 14 research items")
	local researchById = {}
	for _, res in farm.common do
		ok(researchById[res.researchId] == nil, "Research IDs must be unique: " .. res.researchId)
		researchById[res.researchId] = res
	end

	-- Check supported ones
	eq(researchById["comfy_nests"].level, 5)
	eq(researchById["comfy_nests"].available, true)
	eq(researchById["comfy_nests"].blockedReason, nil)

	eq(researchById["egg_diet"].level, 2)
	eq(researchById["egg_diet"].available, true)

	eq(researchById["hab_expansion"].level, 0)
	eq(researchById["hab_expansion"].available, true)
	eq(researchById["hab_expansion"].blockedReason, nil)

	eq(researchById["fleet_capacity"].level, 0)
	eq(researchById["fleet_capacity"].available, true)
	eq(researchById["fleet_capacity"].blockedReason, nil)

	eq(researchById["fleet_hyperloop"].level, 0)
	eq(researchById["fleet_hyperloop"].available, true)
	eq(researchById["fleet_hyperloop"].blockedReason, nil)

	-- Security check: NEVER expose internal tokens, ledgers or receipts
	ok(farm["ownerToken"] == nil, "No ownerToken in view")
	ok(farm["sessionToken"] == nil, "No sessionToken in view")
	ok(farm["operations"] == nil, "No operations ledger in view")
	ok(farm["accounting"] == nil, "No raw accounting in view")
	ok(farm["timeline"] == nil, "No raw timeline in view")
end

-- 1.2 Public View (audience = "public")
do
	local p = makeTestProfile("player-1", "999999", "350", 1)
	local pubSnapshot = projector:projectPublicView(p, "stream-pub", "2", 1000000, "req-pub")
	validateServer(pubSnapshot, "projectPublicView snapshot")

	eq(pubSnapshot.view.audience, "public")
	local pubFarm = pubSnapshot.view.farm
	eq(pubFarm.eggIndex, 0)
	eq(pubFarm.population, "350")
	eq(#pubFarm.habitats, 4)
	eq(pubFarm.habitats[1].slotId, 1)
	eq(pubFarm.habitats[1].habitatIndex, 1)
	eq(pubFarm.habitats[2].slotId, 2)
	eq(pubFarm.habitats[2].habitatIndex, nil)
	eq(#pubFarm.vehicles, 1)
	eq(pubFarm.vehicles[1].slotId, 1)
	eq(pubFarm.vehicles[1].vehicleIndex, 0)

	-- Strictly no private fields in public view
	ok(pubFarm["cash"] == nil, "No cash in public view")
	ok(pubFarm["common"] == nil, "No common in public view")
	ok(pubFarm["hatchery"] == nil, "No hatchery in public view")
	ok(pubFarm["fleet"] == nil, "No fleet in public view")
	ok(pubFarm["producedEggsPerSecond"] == nil, "No production rate in public view")
end

-- 1.3 Delta generation and changes detection
do
	local p1 = makeTestProfile("player-1", "1000", "100", 0)
	local snap1 = projector:projectPrivateView(p1, "stream-d", "1", 1000000, "req-d1")

	-- No changes between same views
	local deltaNoChange = projector:createDelta(snap1.view, snap1.view, "stream-d", "0", "1", "2", 1000050)
	validateServer(deltaNoChange, "Delta with no change")
	eq(deltaNoChange.kind, "StateDelta")
	eq(deltaNoChange.baseViewSeq, "1")
	eq(deltaNoChange.viewSeq, "2")
	eq(next(deltaNoChange.changes.farm), nil, "Changes should be empty")

	-- Modify cash and vehicles
	local p2 = makeTestProfile("player-1", "2500", "100", 0)
	p2.farm.vehicles[2] = { typeIndex = 0 } -- bought second trike
	local snap2 = projector:projectPrivateView(p2, "stream-d", "2", 1000100, "req-d2")

	local delta = projector:createDelta(snap1.view, snap2.view, "stream-d", "1", "1", "2", 1000100)
	validateServer(delta, "Delta with cash and fleet changes")
	eq(delta.changes.audience, "own")
	eq(delta.changes.farm.cash, "2500", "Cash change included")
	ok(delta.changes.farm.fleet ~= nil, "Fleet change included")
	eq(#delta.changes.farm.fleet.vehicles, 2, "Updated fleet has 2 vehicles")
	ok(delta.changes.farm.habitats == nil, "Unchanged habitats omitted from delta")
	ok(delta.changes.farm.common == nil, "Unchanged common research omitted from delta")

	-- Delta with invalid sequence (viewSeq <= baseViewSeq) must fail server validation
	local badDelta = table.clone(delta)
	badDelta.baseViewSeq = "2"
	badDelta.viewSeq = "2"
	local okBad, _ = Protocol.validateServer(badDelta)
	eq(okBad, false, "Delta with baseViewSeq == viewSeq must be rejected")
end

-- ============================================================================
-- Section 2: NetworkGateway Harness & Handlers
-- ============================================================================
local function createGatewayHarness()
	local h = { records = {}, now = 1000000, elapsed = 0, serial = 0 }
	local store = {}
	function store.read(key)
		return true, if h.records[key] then Data.copy(h.records[key]) else nil
	end
	function store.update(key, callback)
		local nextP = callback(if h.records[key] then Data.copy(h.records[key]) else nil)
		if nextP then h.records[key] = Data.copy(nextP) end
		return true, if nextP then Data.copy(nextP) else nil
	end

	h.clock = {
		utcNowMs = function() return h.now end,
		elapsedNowSeconds = function() return h.elapsed end,
	}

	h.repo = Repo.new({
		mode = "INTERNAL_TEST_ONLY",
		codec = C,
		data = Data,
		schema = ProfileSchema,
		store = store,
		clock = h.clock,
		encodeJson = function(v) return serde.encode("json", v) end,
		tokenFactory = function() h.serial += 1; return "token-" .. h.serial end,
	})

	local actions = FarmActions.new(C, Catalog, { mode = "INTERNAL_TEST_ONLY" })

	local function createPlayer(id, initialCash)
		local opened = h.repo.acquire(id)
		eq(opened.status, "ACQUIRED")
		opened.handle.snapshot.farm.cash = C.BigAmount.encode(initialCash or 100000)
		opened.handle.snapshot.accounting.currentFarmCash = C.BigAmount.encode(initialCash or 100000)
		h.records[opened.handle.key] = Data.copy(opened.handle.snapshot)

		local simulation = {
			advance = function(profile, request)
				if request and request.kind == "HatchPress" then
					profile.farm.runningCount = C.ExactUInt.encode(
						C.ExactUInt.add(C.ExactUInt.decode(profile.farm.runningCount), C.ExactUInt.fromSafeNumber(1))
					)
				end
				return { profile = profile, complete = true }
			end,
		}

		local actor = Coordinator.new({
			mode = "INTERNAL_TEST_ONLY",
			codec = C,
			data = Data,
			repository = h.repo,
			handle = opened.handle,
			clock = h.clock,
			simulation = simulation,
			domain = actions,
			maxQueue = 16,
		})
		return actor
	end

	h.player1Coordinator = createPlayer("1001", 500000)
	h.player2Coordinator = createPlayer("1002", 100000)

	local proj = ViewProjector.new({
		codec = C,
		catalog = Catalog,
		productionMath = ProductionMath,
		configRevision = "CANONICAL_V1",
	})

	h.gateway = NetworkGateway.new({
		coordinator = h.player1Coordinator,
		viewProjector = proj,
		farmActions = actions,
		protocol = Protocol,
		clock = h.clock,
		catalog = Catalog,
		codec = C,
		configRevision = "CANONICAL_V1",
	})

	h.gateway:registerPlayer("1002", h.player2Coordinator)

	function h.advance(ms)
		h.now += ms
		h.elapsed += ms / 1000
	end

	return h
end

-- 2.1 Bootstrap Handler
do
	local h = createGatewayHarness()
	-- Session not ready initially
	local unreadyRes = h.gateway:handleRequest("1001", {
		protocolVersion = 1,
		requestId = "boot-req-0",
		kind = "Bootstrap",
	})
	validateServer(unreadyRes, "Unready Bootstrap Admission")
	eq(unreadyRes.kind, "Admission")
	eq(unreadyRes.admission, "NOT_ACCEPTED")
	eq(unreadyRes.errorCode, "SESSION_NOT_READY")

	-- Set ready
	h.player1Coordinator.setReady(true)
	local bootRes = h.gateway:handleRequest("1001", {
		protocolVersion = 1,
		requestId = "boot-req-1",
		kind = "Bootstrap",
	})
	validateServer(bootRes, "Bootstrap StateSnapshot")
	eq(bootRes.kind, "StateSnapshot")
	eq(bootRes.viewSeq, "1")
	eq(bootRes.view.audience, "own")
	eq(bootRes.requestId, "boot-req-1")
	ok(bootRes.streamId ~= nil, "StreamId assigned")
end

-- 2.2 RefreshState Handler
do
	local h = createGatewayHarness()
	h.player1Coordinator.setReady(true)

	-- Bootstrap first
	local boot = h.gateway:handleRequest("1001", {
		protocolVersion = 1,
		requestId = "r-boot",
		kind = "Bootstrap",
	})
	eq(boot.viewSeq, "1")

	-- RefreshState
	local ref1 = h.gateway:handleRequest("1001", {
		protocolVersion = 1,
		requestId = "r-ref-1",
		kind = "RefreshState",
	})
	validateServer(ref1, "RefreshState 1")
	eq(ref1.viewSeq, "2", "viewSeq incremented")
	eq(ref1.streamId, boot.streamId, "streamId maintained")

	local ref2 = h.gateway:handleRequest("1001", {
		protocolVersion = 1,
		requestId = "r-ref-2",
		kind = "RefreshState",
	})
	validateServer(ref2, "RefreshState 2")
	eq(ref2.viewSeq, "3", "viewSeq incremented again")
end

-- 2.3 QuoteRequest Handler
do
	local h = createGatewayHarness()
	h.player1Coordinator.setReady(true)

	-- Research quote
	local qReq1 = {
		protocolVersion = 1,
		requestId = "req-q1",
		kind = "QuoteRequest",
		target = {
			kind = "BuyResearch",
			args = { researchId = "comfy_nests", mode = "single" },
		},
	}
	validateClient(qReq1, "QuoteRequest client validation")
	local qRes1 = h.gateway:handleRequest("1001", qReq1)
	validateServer(qRes1, "BuyResearch QuoteView")
	eq(qRes1.kind, "QuoteView")
	eq(qRes1.available, true)
	eq(qRes1.nextLevel, 1)

	-- Habitat quote
	local qReq2 = {
		protocolVersion = 1,
		requestId = "req-q2",
		kind = "QuoteRequest",
		target = {
			kind = "BuyHabitat",
			args = { slotId = 2, habitatId = "COOP" },
		},
	}
	local qRes2 = h.gateway:handleRequest("1001", qReq2)
	validateServer(qRes2, "BuyHabitat QuoteView")
	eq(qRes2.kind, "QuoteView")
	eq(qRes2.resultIndex, 0)
	eq(qRes2.available, true)

	-- Vehicle quote
	local qReq3 = {
		protocolVersion = 1,
		requestId = "req-q3",
		kind = "QuoteRequest",
		target = {
			kind = "BuyVehicle",
			args = { slotId = 2, vehicleId = "TRIKE" },
		},
	}
	local qRes3 = h.gateway:handleRequest("1001", qReq3)
	validateServer(qRes3, "BuyVehicle QuoteView")
	eq(qRes3.kind, "QuoteView")
	eq(qRes3.resultIndex, 0)
	eq(qRes3.available, true)
end

-- 2.4 BuyResearch, BuyHabitat, BuyVehicle and OperationStatus
do
	local h = createGatewayHarness()
	h.player1Coordinator.setReady(true)

	-- Bootstrap to get initial stream
	local boot = h.gateway:handleRequest("1001", {
		protocolVersion = 1,
		requestId = "r-init",
		kind = "Bootstrap",
	})

	-- Get quote
	local q = h.gateway:handleRequest("1001", {
		protocolVersion = 1,
		requestId = "rq",
		kind = "QuoteRequest",
		target = { kind = "BuyResearch", args = { researchId = "comfy_nests", mode = "single" } },
	})

	-- Execute BuyResearch
	local buyRes = {
		protocolVersion = 1,
		requestId = "req-buy-1",
		kind = "BuyResearch",
		operationId = "op-res-1",
		expectedRevision = "0",
		args = {
			researchId = "comfy_nests",
			mode = "single",
			quoteId = q.quoteId,
		},
	}
	validateClient(buyRes, "BuyResearch client validation")
	local result = h.gateway:handleRequest("1001", buyRes)
	validateServer(result, "BuyResearch CommandResult")

	eq(result.kind, "CommandResult")
	eq(result.status, "APPLIED")
	eq(result.operationId, "op-res-1")
	eq(result.result.actionKind, "BuyResearch")
	eq(result.result.researchId, "comfy_nests")
	eq(result.result.level, 1)

	-- Query OperationStatus for that operation
	local statusReq = {
		protocolVersion = 1,
		requestId = "req-stat-1",
		kind = "OperationStatus",
		operationId = "op-res-1",
	}
	validateClient(statusReq, "OperationStatus client validation")
	local statusRes = h.gateway:handleRequest("1001", statusReq)
	validateServer(statusRes, "OperationStatus CommandResult")
	eq(statusRes.status, "REPLAYED")
	eq(statusRes.operationId, "op-res-1")
	eq(statusRes.result.level, 1)

	-- Replay: submitting same operationId again returns REPLAYED
	local replayRes = h.gateway:handleRequest("1001", buyRes)
	validateServer(replayRes, "BuyResearch Replay CommandResult")
	eq(replayRes.status, "REPLAYED")
	eq(replayRes.operationId, "op-res-1")

	-- BuyHabitat
	local qHab = h.gateway:handleRequest("1001", {
		protocolVersion = 1,
		requestId = "rq-h",
		kind = "QuoteRequest",
		target = { kind = "BuyHabitat", args = { slotId = 2, habitatId = "COOP" } },
	})
	local buyHab = {
		protocolVersion = 1,
		requestId = "req-hab-1",
		kind = "BuyHabitat",
		operationId = "op-hab-1",
		expectedRevision = "1",
		args = {
			slotId = 2,
			habitatId = "COOP",
			quoteId = qHab.quoteId,
		},
	}
	local habResult = h.gateway:handleRequest("1001", buyHab)
	validateServer(habResult, "BuyHabitat CommandResult")
	eq(habResult.status, "APPLIED")
	eq(habResult.result.actionKind, "BuyHabitat")
	eq(habResult.result.slotId, 2)

	-- BuyVehicle
	local qVeh = h.gateway:handleRequest("1001", {
		protocolVersion = 1,
		requestId = "rq-v",
		kind = "QuoteRequest",
		target = { kind = "BuyVehicle", args = { slotId = 2, vehicleId = "TRIKE" } },
	})
	local buyVeh = {
		protocolVersion = 1,
		requestId = "req-veh-1",
		kind = "BuyVehicle",
		operationId = "op-veh-1",
		expectedRevision = "2",
		args = {
			slotId = 2,
			vehicleId = "TRIKE",
			quoteId = qVeh.quoteId,
		},
	}
	local vehResult = h.gateway:handleRequest("1001", buyVeh)
	validateServer(vehResult, "BuyVehicle CommandResult")
	eq(vehResult.status, "APPLIED")
	eq(vehResult.result.actionKind, "BuyVehicle")
	eq(vehResult.result.slotId, 2)
end

-- 2.5 HatchPress and HatchInput
do
	local h = createGatewayHarness()
	h.player1Coordinator.setReady(true)

	local boot = h.gateway:handleRequest("1001", {
		protocolVersion = 1,
		requestId = "r-boot-h",
		kind = "Bootstrap",
	})
	local streamId = boot.streamId

	-- HatchPress valid
	local pressMsg = {
		protocolVersion = 1,
		requestId = "press-1",
		kind = "HatchPress",
		streamId = streamId,
		inputSeq = "1",
	}
	validateClient(pressMsg, "HatchPress client validation")
	local pressRes = h.gateway:handleRequest("1001", pressMsg)
	eq(pressRes.status, "ACCEPTED")
	eq(pressRes.inputSeq, "1")

	-- HatchPress stale inputSeq (equal to previous)
	local stalePress = {
		protocolVersion = 1,
		requestId = "press-2",
		kind = "HatchPress",
		streamId = streamId,
		inputSeq = "1",
	}
	local staleRes = h.gateway:handleRequest("1001", stalePress)
	validateServer(staleRes, "Stale HatchPress Admission")
	eq(staleRes.kind, "Admission")
	eq(staleRes.admission, "NOT_ACCEPTED")
	eq(staleRes.errorCode, "STALE_INPUT")

	-- HatchPress wrong streamId
	local wrongStreamPress = {
		protocolVersion = 1,
		requestId = "press-3",
		kind = "HatchPress",
		streamId = "wrong-stream",
		inputSeq = "2",
	}
	local wrongRes = h.gateway:handleRequest("1001", wrongStreamPress)
	validateServer(wrongRes, "Wrong stream HatchPress Admission")
	eq(wrongRes.errorCode, "WRONG_STREAM")

	-- HatchInput (start, refresh, stop)
	local inputStart = {
		protocolVersion = 1,
		requestId = "hold-1",
		kind = "HatchInput",
		streamId = streamId,
		inputSeq = "2",
		state = "start",
	}
	validateClient(inputStart, "HatchInput start client validation")
	local inStartRes = h.gateway:handleRequest("1001", inputStart)
	eq(inStartRes.status, "ACCEPTED")

	local inputRefresh = {
		protocolVersion = 1,
		requestId = "hold-2",
		kind = "HatchInput",
		streamId = streamId,
		inputSeq = "3",
		state = "refresh",
	}
	local inRefRes = h.gateway:handleRequest("1001", inputRefresh)
	eq(inRefRes.status, "ACCEPTED")

	local inputStop = {
		protocolVersion = 1,
		requestId = "hold-3",
		kind = "HatchInput",
		streamId = streamId,
		inputSeq = "4",
		state = "stop",
	}
	local inStopRes = h.gateway:handleRequest("1001", inputStop)
	eq(inStopRes.status, "ACCEPTED")
end

-- ============================================================================
-- Section 3: Admission control & unready session rejection
-- ============================================================================
do
	local h = createGatewayHarness()
	-- Player 1 coordinator is NOT ready
	h.player1Coordinator.setReady(false)

	local requests = {
		Bootstrap = { protocolVersion = 1, requestId = "req-u1", kind = "Bootstrap" },
		RefreshState = { protocolVersion = 1, requestId = "req-u2", kind = "RefreshState" },
		QuoteRequest = { protocolVersion = 1, requestId = "req-u3", kind = "QuoteRequest", target = { kind = "BuyResearch", args = { researchId = "comfy_nests", mode = "single" } } },
		OperationStatus = { protocolVersion = 1, requestId = "req-u4", kind = "OperationStatus", operationId = "op-u4" },
		BuyResearch = { protocolVersion = 1, requestId = "req-u5", kind = "BuyResearch", operationId = "op-u5", expectedRevision = "0", args = { researchId = "comfy_nests", mode = "single", quoteId = "q-u" } },
		BuyHabitat = { protocolVersion = 1, requestId = "req-u6", kind = "BuyHabitat", operationId = "op-u6", expectedRevision = "0", args = { slotId = 1, habitatId = "COOP", quoteId = "q-u" } },
		BuyVehicle = { protocolVersion = 1, requestId = "req-u7", kind = "BuyVehicle", operationId = "op-u7", expectedRevision = "0", args = { slotId = 1, vehicleId = "TRIKE", quoteId = "q-u" } },
		HatchPress = { protocolVersion = 1, requestId = "req-u8", kind = "HatchPress", streamId = "stream-test", inputSeq = "1" },
		HatchInput = { protocolVersion = 1, requestId = "req-u9", kind = "HatchInput", streamId = "stream-test", inputSeq = "1", state = "start" },
	}

	for kind, msg in requests do
		local res = h.gateway:handleRequest("1001", msg)
		validateServer(res, "Unready session rejection for " .. kind)
		eq(res.kind, "Admission", kind .. " must return Admission")
		eq(res.admission, "NOT_ACCEPTED", kind .. " must be NOT_ACCEPTED")
		eq(res.errorCode, "SESSION_NOT_READY", kind .. " errorCode must be SESSION_NOT_READY")
	end
end

-- ============================================================================
-- Section 4: Player isolation tests
-- ============================================================================
do
	local h = createGatewayHarness()
	h.player1Coordinator.setReady(true)
	h.player2Coordinator.setReady(true)

	-- Bootstrap both players
	local snapA = h.gateway:handleRequest("1001", { protocolVersion = 1, requestId = "b-1", kind = "Bootstrap" })
	local snapB = h.gateway:handleRequest("1002", { protocolVersion = 1, requestId = "b-2", kind = "Bootstrap" })
	validateServer(snapA, "Player 1 snapshot")
	validateServer(snapB, "Player 2 snapshot")
	ok(snapA.streamId ~= snapB.streamId, "Player streams must be unique")

	-- Player 1 performs a purchase
	local qA = h.gateway:handleRequest("1001", {
		protocolVersion = 1,
		requestId = "qa",
		kind = "QuoteRequest",
		target = { kind = "BuyResearch", args = { researchId = "comfy_nests", mode = "single" } },
	})
	local buyA = h.gateway:handleRequest("1001", {
		protocolVersion = 1,
		requestId = "buy-a",
		kind = "BuyResearch",
		operationId = "op-player1-secret",
		expectedRevision = "0",
		args = { researchId = "comfy_nests", mode = "single", quoteId = qA.quoteId },
	})
	eq(buyA.status, "APPLIED")
	eq(buyA.result.level, 1)

	-- Player 2 cannot see Player 1's operationId
	local spyQuery = h.gateway:handleRequest("1002", {
		protocolVersion = 1,
		requestId = "spy-1",
		kind = "OperationStatus",
		operationId = "op-player1-secret",
	})
	validateServer(spyQuery, "Player 2 querying Player 1's operation")
	eq(spyQuery.status, "UNKNOWN", "Player 2 must get UNKNOWN for Player 1 operation")
	eq(spyQuery.errorCode, "RECOVERY_REQUIRED")

	-- Player 2's farm remains unaffected
	local snapB2 = h.gateway:handleRequest("1002", { protocolVersion = 1, requestId = "b-2-chk", kind = "RefreshState" })
	eq(snapB2.view.farm.common[1].level, 0, "Player 2 comfy_nests must remain level 0")
	eq(snapB2.view.farm.cash, "100000", "Player 2 cash untouched")

	-- Unregistered player returns SESSION_NOT_FOUND
	local unregRes = h.gateway:handleRequest("9999", {
		protocolVersion = 1,
		requestId = "unreg-1",
		kind = "Bootstrap",
	})
	validateServer(unregRes, "Unregistered player Admission")
	eq(unregRes.kind, "Admission")
	eq(unregRes.admission, "NOT_ACCEPTED")
	eq(unregRes.errorCode, "SESSION_NOT_FOUND")

	-- Malformed message with injected playerId in payload is rejected by client validation
	local maliciousPayload = {
		protocolVersion = 1,
		requestId = "bad-inj",
		kind = "Bootstrap",
		playerId = "1001",
	}
	local injRes = h.gateway:handleRequest("1002", maliciousPayload)
	validateServer(injRes, "Injected playerId Admission")
	eq(injRes.kind, "Admission")
	eq(injRes.admission, "NOT_ACCEPTED")
	eq(injRes.errorCode, "INVALID_REQUEST")
end

-- ============================================================================
-- Section 5: Gateway delta generation helper
-- ============================================================================
do
	local h = createGatewayHarness()
	h.player1Coordinator.setReady(true)

	local boot = h.gateway:handleRequest("1001", { protocolVersion = 1, requestId = "b-delta", kind = "Bootstrap" })
	eq(boot.viewSeq, "1")

	-- Purchase research to create delta
	local q = h.gateway:handleRequest("1001", {
		protocolVersion = 1,
		requestId = "qd",
		kind = "QuoteRequest",
		target = { kind = "BuyResearch", args = { researchId = "comfy_nests", mode = "single" } },
	})
	h.gateway:handleRequest("1001", {
		protocolVersion = 1,
		requestId = "bd",
		kind = "BuyResearch",
		operationId = "op-delta-1",
		expectedRevision = "0",
		args = { researchId = "comfy_nests", mode = "single", quoteId = q.quoteId },
	})

	local delta = h.gateway:createPlayerDelta("1001")
	ok(delta ~= nil, "Player delta created")
	validateServer(delta, "Gateway created player delta")
	eq(delta.kind, "StateDelta")
	eq(delta.baseViewSeq, "1")
	eq(delta.viewSeq, "2")
	ok(delta.changes.farm.cash ~= nil, "Cash change detected in delta")
	ok(delta.changes.farm.common ~= nil, "Common change detected in delta")
end

-- Write test results artifact
fs.writeFile("build/gateway-results.json", serde.encode("json", {
	status = "PASS",
	assertions = assertions,
	runtime = "Lune",
	studioTested = false,
	datastoreTested = false,
}, true))

print("NetworkGateway & ViewProjector: " .. assertions .. " assertions PASS")
