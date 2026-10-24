--!nocheck
-- Test suite for ClientTransport and ClientStateStore (IMP-12).
-- Verifies client network abstraction, request/operation correlation,
-- authoritative view projection mirroring, monotonic viewSeq checks,
-- sequence gap detection, stale delta ignoring, and end-to-end integration.

local C = require("../../src/shared/NumericCodec")
local Schemas = require("../../src/shared/ProtocolSchemas")
local Protocol = Schemas.new(C)

local ClientTransport = require("../../src/client/ClientTransport")
local ClientStateStore = require("../../src/client/ClientStateStore")

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

-- ============================================================================
-- Section 1: ClientTransport Message Construction and Validation
-- ============================================================================
do
	local sent = {}
	local mockWire = {
		send = function(self, msg)
			table.insert(sent, msg)
		end,
	}

	local transport = ClientTransport.new({
		protocol = Protocol,
		wire = mockWire,
	})

	-- 1.1 sendBootstrap
	local bMsg = transport:sendBootstrap("req-b-1")
	eq(#sent, 1)
	eq(sent[1].kind, "Bootstrap")
	eq(sent[1].requestId, "req-b-1")
	validateClient(bMsg, "sendBootstrap message")

	-- 1.2 sendRefreshState
	local rMsg = transport:sendRefreshState("req-r-1")
	eq(#sent, 2)
	eq(sent[2].kind, "RefreshState")
	eq(sent[2].requestId, "req-r-1")
	validateClient(rMsg, "sendRefreshState message")

	-- 1.3 sendQuoteRequest
	local qMsg = transport:sendQuoteRequest("req-q-1", {
		kind = "BuyResearch",
		args = { researchId = "comfy_nests", mode = "single" },
	})
	eq(#sent, 3)
	eq(sent[3].kind, "QuoteRequest")
	eq(sent[3].target.kind, "BuyResearch")
	validateClient(qMsg, "sendQuoteRequest message")

	-- 1.4 sendOperationStatus
	local sMsg = transport:sendOperationStatus("req-s-1", "op-101")
	eq(#sent, 4)
	eq(sent[4].kind, "OperationStatus")
	eq(sent[4].operationId, "op-101")
	validateClient(sMsg, "sendOperationStatus message")

	-- 1.5 sendPurchase (BuyResearch, BuyHabitat, BuyVehicle)
	local p1 = transport:sendPurchase("BuyResearch", "req-p-1", "op-102", "0", {
		researchId = "comfy_nests",
		mode = "single",
		quoteId = "quote-1",
	})
	eq(#sent, 5)
	eq(sent[5].kind, "BuyResearch")
	validateClient(p1, "sendPurchase BuyResearch")

	local p2 = transport:sendPurchase("BuyHabitat", "req-p-2", "op-103", "1", {
		slotId = 2,
		habitatId = "COOP",
		quoteId = "quote-2",
	})
	eq(#sent, 6)
	eq(sent[6].kind, "BuyHabitat")
	validateClient(p2, "sendPurchase BuyHabitat")

	local p3 = transport:sendPurchase("BuyVehicle", "req-p-3", "op-104", "2", {
		slotId = 2,
		vehicleId = "TRIKE",
		quoteId = "quote-3",
	})
	eq(#sent, 7)
	eq(sent[7].kind, "BuyVehicle")
	validateClient(p3, "sendPurchase BuyVehicle")

	-- 1.6 sendHatchPress
	local hp = transport:sendHatchPress("req-hp-1", "stream-1", "1")
	eq(#sent, 8)
	eq(sent[8].kind, "HatchPress")
	eq(sent[8].streamId, "stream-1")
	eq(sent[8].inputSeq, "1")
	validateClient(hp, "sendHatchPress")

	-- 1.7 sendHatchInput (start, refresh, stop)
	local hi1 = transport:sendHatchInput("req-hi-1", "stream-1", "2", "start")
	local hi2 = transport:sendHatchInput("req-hi-2", "stream-1", "3", "refresh")
	local hi3 = transport:sendHatchInput("req-hi-3", "stream-1", "4", "stop")
	eq(#sent, 11)
	validateClient(hi1, "sendHatchInput start")
	validateClient(hi2, "sendHatchInput refresh")
	validateClient(hi3, "sendHatchInput stop")

	-- 1.8 Default requestId generation when omitted
	local autoMsg = transport:sendBootstrap(nil)
	ok(type(autoMsg.requestId) == "string" and #autoMsg.requestId > 0, "Auto-generated requestId")
	validateClient(autoMsg, "Auto-generated requestId bootstrap")
end

-- ============================================================================
-- Section 2: ClientTransport Correlation and Event Subscription
-- ============================================================================
do
	local transport = ClientTransport.new({
		protocol = Protocol,
	})

	-- 2.1 Request correlation for QuoteView
	local receivedQuote = nil
	transport:sendQuoteRequest("req-quote-corr", {
		kind = "BuyResearch",
		args = { researchId = "comfy_nests", mode = "single" },
	}, function(msg)
		receivedQuote = msg
	end)

	local quotePayload = {
		protocolVersion = 1,
		numericCodecVersion = 1,
		kind = "QuoteView",
		requestId = "req-quote-corr",
		quoteId = "quote-corr-1",
		expectedRevision = "0",
		target = {
			kind = "BuyResearch",
			args = { researchId = "comfy_nests", mode = "single" },
		},
		cashCost = "100",
		currency = "cash",
		configRevision = "CANONICAL_V1",
		calculationVersion = 1,
		expiresAt = 2000000,
		available = true,
		nextLevel = 1,
	}
	validateServer(quotePayload, "quotePayload")

	local okRec, _ = transport:receive(quotePayload)
	eq(okRec, true)
	ok(receivedQuote ~= nil, "Quote callback must be invoked")
	eq(receivedQuote.quoteId, "quote-corr-1")

	-- Subsequent receive with same requestId should not call callback again (cleared)
	local callCount = 0
	receivedQuote = nil
	transport:receive(quotePayload)
	ok(receivedQuote == nil, "Callback must not be called twice")

	-- 2.2 CommandResult correlation by operationId with PENDING -> APPLIED progression
	local opResults = {}
	transport:registerOperationCallback("op-multi-step", function(msg)
		table.insert(opResults, msg)
	end)

	local pendingResult = {
		protocolVersion = 1,
		kind = "CommandResult",
		requestId = "req-pending",
		operationId = "op-multi-step",
		status = "PENDING",
		currentCommitRevision = "0",
		streamId = "stream-1",
		serverObservedAt = 1000100,
	}
	validateServer(pendingResult, "pendingResult")
	transport:receive(pendingResult)
	eq(#opResults, 1, "PENDING notification received")
	eq(opResults[1].status, "PENDING")

	local appliedResult = {
		protocolVersion = 1,
		kind = "CommandResult",
		requestId = "req-applied",
		operationId = "op-multi-step",
		status = "APPLIED",
		resultRevision = "1",
		currentCommitRevision = "1",
		streamId = "stream-1",
		serverObservedAt = 1000200,
		result = {
			terminalStatus = "APPLIED",
			actionKind = "BuyResearch",
			researchId = "comfy_nests",
			level = 1,
		},
	}
	validateServer(appliedResult, "appliedResult")
	transport:receive(appliedResult)
	eq(#opResults, 2, "APPLIED notification received")
	eq(opResults[2].status, "APPLIED")

	-- After terminal APPLIED, callback is cleared: third message will not trigger it
	transport:receive(appliedResult)
	eq(#opResults, 2, "Callback cleared after terminal status")

	-- 2.3 Admission correlation by operationId and requestId
	local admissionReceived = nil
	transport:registerRequestCallback("req-rejected-1", function(msg)
		admissionReceived = msg
	end)

	local admissionPayload = {
		protocolVersion = 1,
		kind = "Admission",
		requestId = "req-rejected-1",
		operationId = "op-rejected-1",
		admission = "NOT_ACCEPTED",
		errorCode = "SESSION_NOT_READY",
	}
	validateServer(admissionPayload, "admissionPayload")
	transport:receive(admissionPayload)
	ok(admissionReceived ~= nil, "Admission received by requestId")
	eq(admissionReceived.errorCode, "SESSION_NOT_READY")

	-- 2.4 Unsubscribe mechanism
	local unsubCalled = 0
	local unsub = transport:onCommandResult(function(_)
		unsubCalled += 1
	end)
	transport:receive(appliedResult)
	eq(unsubCalled, 1)
	unsub()
	transport:receive(appliedResult)
	eq(unsubCalled, 1, "Unsubscribed callback must not be called")

	-- 2.5 Invalid server message returns false and error
	local badMsg = { kind = "UnknownKind", protocolVersion = 999 }
	local okBad, errBad = transport:receive(badMsg)
	eq(okBad, false)
	ok(errBad ~= nil, "Expected validation error on bad server message")
end

-- ============================================================================
-- Section 3: ClientStateStore Initialization (applySnapshot)
-- ============================================================================
do
	local transport = ClientTransport.new({ protocol = Protocol })
	local store = ClientStateStore.new({
		transport = transport,
		codec = C,
	})

	eq(store:getStatus(), "CONNECTING", "Initial status is CONNECTING")
	eq(store:isReady(), false)
	eq(store:getFarm(), nil)

	local p = makeTestProfile("player-1", "5000", "200", 0)
	p.farm.common.comfy_nests = 3
	local snapshot = projector:projectPrivateView(p, "stream-init", "1", 1000000, "req-snap-1")
	validateServer(snapshot, "Initial snapshot")

	local stateChangedFired = false
	local snapshotAppliedFired = false
	store:onStateChanged(function(kind, s)
		stateChangedFired = true
		eq(kind, "snapshot")
	end)
	store:onSnapshotApplied(function(s)
		snapshotAppliedFired = true
		eq(s.streamId, "stream-init")
	end)

	local okSnap = store:applySnapshot(snapshot)
	eq(okSnap, true)
	eq(store:getStatus(), "READY", "Status transitions to READY")
	eq(store:isReady(), true)
	eq(store:getStreamId(), "stream-init")
	eq(store:getViewSeq(), "1")
	eq(store:getCommitRevision(), "0")
	eq(store:getServerObservedAt(), 1000000)
	eq(store:getAudience(), "own")
	ok(stateChangedFired, "stateChanged event fired")
	ok(snapshotAppliedFired, "snapshotApplied event fired")

	local farm = store:getFarm()
	ok(farm ~= nil)
	eq(farm.cash, "5000")
	eq(#farm.habitats, 4)
	eq(farm.habitats[1].population, "200")

	-- CRITICAL INVARIANT: Client projection immutability
	-- Mutating the table returned by getFarm() must NOT mutate store's internal state
	farm.cash = "999999"
	farm.habitats[1].population = "99999"
	local freshFarm = store:getFarm()
	eq(freshFarm.cash, "5000", "Internal cash must NOT be modified by external mutation")
	eq(freshFarm.habitats[1].population, "200", "Internal population must NOT be modified")
end

-- ============================================================================
-- Section 4: Sequential Delta Application (applyDelta)
-- ============================================================================
do
	local transport = ClientTransport.new({ protocol = Protocol })
	local store = ClientStateStore.new({
		transport = transport,
		codec = C,
	})

	local p1 = makeTestProfile("player-1", "1000", "100", 0)
	local snap1 = projector:projectPrivateView(p1, "stream-seq", "1", 1000000, "req-1")
	store:applySnapshot(snap1)
	eq(store:getViewSeq(), "1")
	eq(store:getFarm().cash, "1000")

	-- 4.1 First Delta: cash increases to 1500 (baseViewSeq = "1", viewSeq = "2")
	local p2 = makeTestProfile("player-1", "1500", "100", 0)
	local snap2 = projector:projectPrivateView(p2, "stream-seq", "2", 1000100, "req-2")
	local delta1 = projector:createDelta(snap1.view, snap2.view, "stream-seq", "1", "1", "2", 1000100)
	validateServer(delta1, "delta1")

	local appliedDeltas = {}
	store:onDeltaApplied(function(d)
		table.insert(appliedDeltas, d)
	end)

	local okD1 = store:applyDelta(delta1)
	eq(okD1, true)
	eq(#appliedDeltas, 1, "deltaApplied event fired for delta1")
	eq(appliedDeltas[1].viewSeq, "2")
	eq(store:getViewSeq(), "2")
	eq(store:getCommitRevision(), "1")
	eq(store:getServerObservedAt(), 1000100)
	eq(store:getFarm().cash, "1500", "Cash updated by delta")
	eq(store:getFarm().habitats[1].population, "100", "Unchanged habitat population preserved")

	-- 4.2 Second Delta: population increases to 250 (baseViewSeq = "2", viewSeq = "3")
	local p3 = makeTestProfile("player-1", "1500", "250", 0)
	local snap3 = projector:projectPrivateView(p3, "stream-seq", "3", 1000200, "req-3")
	local delta2 = projector:createDelta(snap2.view, snap3.view, "stream-seq", "2", "2", "3", 1000200)
	validateServer(delta2, "delta2")

	local okD2 = store:applyDelta(delta2)
	eq(okD2, true)
	eq(#appliedDeltas, 2, "deltaApplied event fired for delta2")
	eq(appliedDeltas[2].viewSeq, "3")
	eq(store:getViewSeq(), "3")
	eq(store:getCommitRevision(), "2")
	eq(store:getFarm().cash, "1500", "Unchanged cash preserved")
	eq(store:getFarm().habitats[1].population, "250", "Habitat updated by delta2")
end

-- ============================================================================
-- Section 5: Outdated Delta Ignored (viewSeq <= currentViewSeq) Without Rollback
-- ============================================================================
do
	local transport = ClientTransport.new({ protocol = Protocol })
	local store = ClientStateStore.new({
		transport = transport,
		codec = C,
	})

	local p1 = makeTestProfile("player-1", "1000", "100", 0)
	local snap1 = projector:projectPrivateView(p1, "stream-stale", "1", 1000000, "req-1")
	local p2 = makeTestProfile("player-1", "1500", "100", 0)
	local snap2 = projector:projectPrivateView(p2, "stream-stale", "2", 1000100, "req-2")
	local p3 = makeTestProfile("player-1", "2000", "100", 0)
	local snap3 = projector:projectPrivateView(p3, "stream-stale", "3", 1000200, "req-3")

	local delta1 = projector:createDelta(snap1.view, snap2.view, "stream-stale", "1", "1", "2", 1000100)
	local delta2 = projector:createDelta(snap2.view, snap3.view, "stream-stale", "2", "2", "3", 1000200)

	store:applySnapshot(snap1)
	store:applyDelta(delta1)
	store:applyDelta(delta2)
	eq(store:getViewSeq(), "3")
	eq(store:getFarm().cash, "2000")

	-- Now a stale delta1 arrives again (baseViewSeq = "1", viewSeq = "2" <= "3")
	local okStale, reason = store:applyDelta(delta1)
	eq(okStale, false)
	eq(reason, "OUTDATED_DELTA")
	-- CRITICAL: Store state must NOT be rolled back
	eq(store:getViewSeq(), "3", "viewSeq must NOT roll back")
	eq(store:getCommitRevision(), "2", "commitRevision must NOT roll back")
	eq(store:getFarm().cash, "2000", "Cash must NOT roll back to 1500")
	eq(store:getStatus(), "READY", "Status remains READY")

	-- A duplicate delta2 arrives again (baseViewSeq = "2", viewSeq = "3" <= "3")
	local okDup, reasonDup = store:applyDelta(delta2)
	eq(okDup, false)
	eq(reasonDup, "OUTDATED_DELTA")
	eq(store:getViewSeq(), "3")
	eq(store:getFarm().cash, "2000")
end

-- ============================================================================
-- Section 6: Sequence Gap Detection (baseViewSeq > currentViewSeq) -> RESYNCING
-- ============================================================================
do
	local refreshSent = {}
	local mockWire = {
		send = function(self, msg)
			if msg.kind == "RefreshState" then
				table.insert(refreshSent, msg)
			end
		end,
	}

	local transport = ClientTransport.new({
		protocol = Protocol,
		wire = mockWire,
	})
	local store = ClientStateStore.new({
		transport = transport,
		codec = C,
	})

	local p1 = makeTestProfile("player-1", "1000", "100", 0)
	local snap1 = projector:projectPrivateView(p1, "stream-gap", "1", 1000000, "req-1")
	store:applySnapshot(snap1)
	eq(store:getViewSeq(), "1")
	eq(store:getStatus(), "READY")

	-- A delta arrives with baseViewSeq = "4" (gap: missing 2 and 3!)
	local p4 = makeTestProfile("player-1", "3000", "100", 0)
	local snap4 = projector:projectPrivateView(p4, "stream-gap", "4", 1000400, "req-4")
	local p5 = makeTestProfile("player-1", "4000", "100", 0)
	local snap5 = projector:projectPrivateView(p5, "stream-gap", "5", 1000500, "req-5")

	local gapDelta = projector:createDelta(snap4.view, snap5.view, "stream-gap", "4", "4", "5", 1000500)
	validateServer(gapDelta, "gapDelta")

	local resyncFired = false
	store:onResyncRequested(function(reqId)
		resyncFired = true
		ok(#reqId > 0)
	end)

	local okGap, reasonGap = store:applyDelta(gapDelta)
	eq(okGap, false)
	eq(reasonGap, "GAP_DETECTED")
	eq(store:getStatus(), "RESYNCING", "Status must become RESYNCING upon gap detection")
	ok(resyncFired, "resyncRequested event fired")
	eq(#refreshSent, 1, "RefreshState message sent to wire")
	eq(refreshSent[1].kind, "RefreshState")
	validateClient(refreshSent[1], "RefreshState message")

	-- Farm state must NOT be modified by the gapped delta
	eq(store:getViewSeq(), "1", "viewSeq unchanged")
	eq(store:getFarm().cash, "1000", "Cash unchanged")

	-- Server responds to RefreshState with a full StateSnapshot (viewSeq = "5")
	local resyncSnapshot = projector:projectPrivateView(p5, "stream-gap", "5", 1000500, refreshSent[1].requestId)
	store:applySnapshot(resyncSnapshot)

	eq(store:getStatus(), "READY", "Store returns to READY after snapshot applied")
	eq(store:getViewSeq(), "5")
	eq(store:getFarm().cash, "4000", "State synchronized to latest snapshot")
end

-- ============================================================================
-- Section 7: StreamId Mismatch -> Resync
-- ============================================================================
do
	local refreshSent = {}
	local mockWire = {
		send = function(self, msg)
			if msg.kind == "RefreshState" then
				table.insert(refreshSent, msg)
			end
		end,
	}

	local transport = ClientTransport.new({
		protocol = Protocol,
		wire = mockWire,
	})
	local store = ClientStateStore.new({
		transport = transport,
		codec = C,
	})

	local p1 = makeTestProfile("player-1", "1000", "100", 0)
	local snap1 = projector:projectPrivateView(p1, "stream-A", "1", 1000000, "req-1")
	store:applySnapshot(snap1)
	eq(store:getStreamId(), "stream-A")
	eq(store:getStatus(), "READY")

	-- Delta arrives with streamId = "stream-B"
	local p2 = makeTestProfile("player-1", "2000", "100", 0)
	local snap2 = projector:projectPrivateView(p2, "stream-B", "2", 1000100, "req-2")
	local deltaOtherStream = projector:createDelta(snap1.view, snap2.view, "stream-B", "1", "1", "2", 1000100)

	local okMismatch, reasonMismatch = store:applyDelta(deltaOtherStream)
	eq(okMismatch, false)
	eq(reasonMismatch, "STREAM_MISMATCH")
	eq(store:getStatus(), "RESYNCING")
	eq(#refreshSent, 1, "RefreshState sent on stream mismatch")

	-- Applying new snapshot with stream-B recovers the store
	local snapB = projector:projectPrivateView(p2, "stream-B", "2", 1000100, refreshSent[1].requestId)
	store:applySnapshot(snapB)
	eq(store:getStatus(), "READY")
	eq(store:getStreamId(), "stream-B")
	eq(store:getViewSeq(), "2")
	eq(store:getFarm().cash, "2000")
end

-- ============================================================================
-- Section 8: Inconsistent Base Detection (baseViewSeq < currentViewSeq and viewSeq > currentViewSeq)
-- ============================================================================
do
	local refreshSent = {}
	local mockWire = {
		send = function(self, msg)
			if msg.kind == "RefreshState" then
				table.insert(refreshSent, msg)
			end
		end,
	}

	local transport = ClientTransport.new({
		protocol = Protocol,
		wire = mockWire,
	})
	local store = ClientStateStore.new({
		transport = transport,
		codec = C,
	})

	local p1 = makeTestProfile("player-1", "1000", "100", 0)
	local snap1 = projector:projectPrivateView(p1, "stream-branch", "2", 1000000, "req-1")
	store:applySnapshot(snap1)
	eq(store:getViewSeq(), "2")

	-- An inconsistent delta with baseViewSeq = "1" but viewSeq = "3" arrives
	local p2 = makeTestProfile("player-1", "3000", "100", 0)
	local snap2 = projector:projectPrivateView(p2, "stream-branch", "3", 1000100, "req-2")
	local inconsistentDelta = projector:createDelta(snap1.view, snap2.view, "stream-branch", "1", "1", "3", 1000100)

	local okInc, reasonInc = store:applyDelta(inconsistentDelta)
	eq(okInc, false)
	eq(reasonInc, "INCONSISTENT_BASE")
	eq(store:getStatus(), "RESYNCING")
	eq(#refreshSent, 1)
end

-- ============================================================================
-- Section 9: End-to-End Integration with NetworkGateway
-- ============================================================================
do
	local h = { records = {}, now = 1000000, elapsed = 0, serial = 0 }
	local rawStore = {}
	function rawStore.read(key)
		return true, if h.records[key] then Data.copy(h.records[key]) else nil
	end
	function rawStore.update(key, callback)
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
		store = rawStore,
		clock = h.clock,
		encodeJson = function(v) return serde.encode("json", v) end,
		tokenFactory = function() h.serial += 1; return "token-" .. h.serial end,
	})

	local opened = h.repo.acquire("1001")
	eq(opened.status, "ACQUIRED")
	opened.handle.snapshot.farm.cash = C.BigAmount.encode(100000)
	opened.handle.snapshot.accounting.currentFarmCash = C.BigAmount.encode(100000)
	h.records[opened.handle.key] = Data.copy(opened.handle.snapshot)

	local actions = FarmActions.new(C, Catalog, { mode = "INTERNAL_TEST_ONLY" })
	local simulation = {
		advance = function(profile, request)
			return { profile = profile, complete = true }
		end,
	}

	local coordinator = Coordinator.new({
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

	local gateway = NetworkGateway.new({
		viewProjector = projector,
		farmActions = actions,
		protocol = Protocol,
		clock = h.clock,
		coordinator = coordinator,
		autoDrain = true,
	})

	coordinator.setReady(true)

	-- Create ClientTransport with gateway wire bridge
	local clientTransport
	local clientWire = {
		send = function(self, msg)
			local res = gateway:handleRequest("1001", msg)
			if res then
				clientTransport:receive(res)
			end
		end,
	}

	clientTransport = ClientTransport.new({
		protocol = Protocol,
		wire = clientWire,
		playerId = "1001",
	})

	local clientStore = ClientStateStore.new({
		transport = clientTransport,
		codec = C,
	})

	-- 9.1 Bootstrap -> Initial StateSnapshot
	eq(clientStore:getStatus(), "CONNECTING")
	local bootMsg = clientTransport:sendBootstrap("req-boot-e2e")
	validateClient(bootMsg, "Bootstrap request")

	-- After bootstrap, store automatically applied the server snapshot!
	eq(clientStore:getStatus(), "READY")
	eq(clientStore:getViewSeq(), "1")
	eq(clientStore:getFarm().cash, "100000")
	local activeStream = clientStore:getStreamId()
	ok(activeStream ~= nil and #activeStream > 0)

	-- 9.2 QuoteRequest
	local receivedQuote = nil
	clientTransport:sendQuoteRequest("req-quote-e2e", {
		kind = "BuyResearch",
		args = { researchId = "comfy_nests", mode = "single" },
	}, function(q)
		receivedQuote = q
	end)
	ok(receivedQuote ~= nil, "Quote received and correlated")
	eq(receivedQuote.target.kind, "BuyResearch")
	eq(receivedQuote.nextLevel, 1)

	-- 9.3 BuyResearch purchase
	local buyResult = nil
	clientTransport:sendPurchase("BuyResearch", "req-buy-e2e", "op-buy-e2e-1", "0", {
		researchId = "comfy_nests",
		mode = "single",
		quoteId = receivedQuote.quoteId,
	}, function(r)
		buyResult = r
	end)

	ok(buyResult ~= nil, "CommandResult received and correlated")
	eq(buyResult.status, "APPLIED")
	eq(buyResult.result.actionKind, "BuyResearch")
	eq(buyResult.result.level, 1)

	-- 9.4 Server emits delta -> store automatically updates!
	local delta = gateway:createPlayerDelta("1001")
	validateServer(delta, "gateway delta")
	clientTransport:receive(delta)

	eq(clientStore:getViewSeq(), "2", "Store viewSeq advanced via server delta")
	local researchMap = {}
	for _, r in clientStore:getFarm().common do
		researchMap[r.researchId] = r
	end
	eq(researchMap["comfy_nests"].level, 1, "Store shows comfy_nests level 1 from server delta")

	clientStore:destroy()
end

-- ============================================================================
-- Section 10: Lifecycle SESSION_LOST Handling
-- ============================================================================
do
	local transport = ClientTransport.new({ protocol = Protocol })
	local store = ClientStateStore.new({
		transport = transport,
		codec = C,
	})

	local p = makeTestProfile("player-1", "1000", "100", 0)
	local snap = projector:projectPrivateView(p, "stream-lost", "1", 1000000, "req-1")
	-- Simulate server signaling sessionLost in snapshot
	snap.view.farm.lifecycle = "sessionLost"
	store:applySnapshot(snap)

	eq(store:getStatus(), "SESSION_LOST", "Snapshot with sessionLost transitions to SESSION_LOST")
	eq(store:isReady(), false)

	-- Recovering with a fresh snapshot with lifecycle == "ready"
	snap.view.farm.lifecycle = "ready"
	store:applySnapshot(snap)
	eq(store:getStatus(), "READY", "Subsequent ready snapshot restores READY status")
	eq(store:isReady(), true)
end

print(string.format("ClientTransport and ClientStateStore: %d assertions PASS", assertions))
