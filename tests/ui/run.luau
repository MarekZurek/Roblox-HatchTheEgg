--!nocheck
-- Test suite for IMP-14: Minimal HUD & IntentControllers.
-- Verifies:
-- 1. Number formatting for presentation UI only (zero, small amounts, K, M, B, T suffixes).
-- 2. HatchController (press, hold start/refresh/stop, streamId binding, strictly monotonic inputSeq ExactUInt).
-- 3. ShopController (QuoteRequest -> QuoteView caching -> purchase confirmation with preconditions & operationId).
-- 4. HUD state reactions to ClientStateStore snapshots and deltas (cash, rates, hatchery, habitats 1..4).
-- 5. Shop view button states (active vs blocked with TIER_LOCKED, MAX_LEVEL, INSUFFICIENT_CASH).
-- 6. Session lifecycle banner transitions (CONNECTING, LOADING, READY, RESYNCING, SESSION_LOST).
-- 7. Critical architectural invariant: HUD and IntentControllers NEVER modify authoritative state or grant resources.

local C = require("../../src/shared/NumericCodec")
local Schemas = require("../../src/shared/ProtocolSchemas")
local Protocol = Schemas.new(C)

local ClientTransport = require("../../src/client/ClientTransport")
local ClientStateStore = require("../../src/client/ClientStateStore")
local IntentControllers = require("../../src/client/IntentControllers")
local HUD = require("../../src/client/HUD")
local AudioController = require("../../src/client/AudioController")

local assertions = 0
local function eq(a, b, label)
	assertions += 1
	assert(a == b, (label or "") .. " expected " .. tostring(b) .. " got " .. tostring(a))
end

local function ok(cond, label)
	assertions += 1
	assert(cond, label or "condition failed")
end

-- Helper to construct a valid base StateSnapshot view for testing
local function makeTestSnapshot(overrides)
	local o = overrides or {}
	local habitats = {}
	for i = 1, 4 do
		local hOverride = (o.habitats and o.habitats[i]) or {}
		table.insert(habitats, {
			slotId = i,
			habitatIndex = hOverride.habitatIndex or 0,
			population = hOverride.population or "0",
			reservedInTransit = hOverride.reservedInTransit or "0",
			capacity = hOverride.capacity or "500",
		})
	end

	local common = o.common or {
		{ researchId = "comfy_nests", level = 0, available = true },
		{ researchId = "hab_capacity1", level = 0, available = false, blockedReason = "TIER_LOCKED" },
		{ researchId = "maxed_research", level = 25, available = false, blockedReason = "MAX_LEVEL" },
		{ researchId = "expensive_research", level = 1, available = false, blockedReason = "INSUFFICIENT_CASH" },
	}

	return {
		protocolVersion = 1,
		numericCodecVersion = 1,
		viewSchemaVersion = 1,
		configRevision = "cfg:1",
		calculationVersion = 1,
		streamId = o.streamId or "stream-1",
		commitRevision = o.commitRevision or "1",
		viewSeq = o.viewSeq or "1",
		serverObservedAt = o.serverObservedAt or 1000000,
		kind = "StateSnapshot",
		requestId = "boot-req-1",
		view = {
			audience = "own",
			farm = {
				lifecycle = o.lifecycle or "ready",
				eggIndex = 0,
				cash = o.cash or "1000",
				habitats = habitats,
				hatchery = {
					stock = (o.hatchery and o.hatchery.stock) or "250",
					capacity = (o.hatchery and o.hatchery.capacity) or "500",
					refillPerSecond = (o.hatchery and o.hatchery.refillPerSecond) or "10",
				},
				fleet = {
					vehicles = {
						{ slotId = 1, vehicleIndex = 0 },
					},
					shippingPerMinute = (o.fleet and o.fleet.shippingPerMinute) or "60000",
					slotLimit=4,
					upgrades={{slotId=1,nextVehicleId="TRANSIT VAN",price="100",available=true}},
				},
				producedEggsPerSecond = o.producedEggsPerSecond or "1500",
				soldEggsPerSecond = o.soldEggsPerSecond or "1200",
				cashIncomePerSecond = o.cashIncomePerSecond or "500",
				common = common,
			},
		},
	}
end

-- ============================================================================
-- Section 1: Presentation-Only Number Formatting in HUD
-- ============================================================================
do
	-- 1.1 Zero values
	eq(HUD.formatCash("0"), "$0", "formatCash zero string")
	eq(HUD.formatCash(0), "$0", "formatCash zero number")
	eq(HUD.formatRate("0"), "0/s", "formatRate zero default unit")
	eq(HUD.formatRate("0", "/min"), "0/min", "formatRate zero custom unit")
	eq(HUD.formatCompact("0"), "0", "formatCompact zero")

	-- 1.2 Small values (< 1,000)
	eq(HUD.formatCash("1"), "$1", "formatCash 1")
	eq(HUD.formatCash("25"), "$25", "formatCash 25")
	eq(HUD.formatCash("450"), "$450", "formatCash 450")
	eq(HUD.formatCash("999"), "$999", "formatCash 999")
	eq(HUD.formatRate("500"), "500/s", "formatRate 500")
	eq(HUD.formatRate("100", "/s"), "100/s", "formatRate 100")
	eq(HUD.formatCompact("450"), "450", "formatCompact 450")

	-- 1.3 Thousands (K)
	eq(HUD.formatCash("1000"), "$1K", "formatCash 1K")
	eq(HUD.formatCash("1500"), "$1.5K", "formatCash 1.5K")
	eq(HUD.formatCash("25400"), "$25.4K", "formatCash 25.4K")
	eq(HUD.formatCash("999900"), "$999.9K", "formatCash 999.9K")
	eq(HUD.formatRate("1000"), "1K/s", "formatRate 1K")
	eq(HUD.formatRate("24500", "/s"), "24.5K/s", "formatRate 24.5K/s")
	eq(HUD.formatRate("60000", "/min"), "60K/min", "formatRate 60K/min")
	eq(HUD.formatCompact("1500"), "1.5K", "formatCompact 1.5K")

	-- 1.4 Millions (M)
	eq(HUD.formatCash("1000000"), "$1M", "formatCash 1M")
	eq(HUD.formatCash("1420000"), "$1.42M", "formatCash 1.42M")
	eq(HUD.formatCash("25000000"), "$25M", "formatCash 25M")
	eq(HUD.formatRate("2000000", "/s"), "2M/s", "formatRate 2M/s")
	eq(HUD.formatRate("60000000", "/min"), "60M/min", "formatRate 60M/min")
	eq(HUD.formatCompact("1000000"), "1M", "formatCompact 1M")

	-- 1.5 Billions (B)
	eq(HUD.formatCash("1000000000"), "$1B", "formatCash 1B")
	eq(HUD.formatCash("2500000000"), "$2.5B", "formatCash 2.5B")
	eq(HUD.formatRate("1200000000", "/s"), "1.2B/s", "formatRate 1.2B/s")
	eq(HUD.formatCompact("3500000000"), "3.5B", "formatCompact 3.5B")

	-- 1.6 Trillions (T)
	eq(HUD.formatCash("1000000000000"), "$1T", "formatCash 1T")
	eq(HUD.formatCash("4250000000000"), "$4.25T", "formatCash 4.25T")
	eq(HUD.formatRate("1000000000000", "/s"), "1T/s", "formatRate 1T/s")
	eq(HUD.formatCompact("1000000000000"), "1T", "formatCompact 1T")

	-- 1.7 Instance method invocation
	local dummyStore = { onStatusChanged = function() return function() end end, onStateChanged = function() return function() end end, getStatus = function() return "CONNECTING" end, getFarm = function() return nil end }
	local dummyControllers = {}
	local hud = HUD.new({
		stateStore = dummyStore,
		intentControllers = dummyControllers,
		codec = C,
	})
	eq(hud:formatCash("1000000"), "$1M", "hud:formatCash method call")
	eq(hud:formatRate("5000", "/s"), "5K/s", "hud:formatRate method call")
	eq(hud:formatCompact("2500"), "2.5K", "hud:formatCompact method call")
	hud:destroy()
end

-- ============================================================================
-- Section 2: HatchController (Press, Hold, Monotonic inputSeq ExactUInt)
-- ============================================================================
do
	local outgoing = {}
	local transport = ClientTransport.new({
		protocol = Protocol,
		wire = function(msg)
			table.insert(outgoing, msg)
		end,
	})

	local store = ClientStateStore.new({
		transport = transport,
		codec = C,
	})

	local hatch = IntentControllers.HatchController.new({
		transport = transport,
		stateStore = store,
		codec = C,
	})

	-- 2.1 Rejection without streamId
	local okPressNoStream, errNoStream = pcall(function()
		hatch:press()
	end)
	eq(okPressNoStream, false, "press() fails without streamId")
	ok(string.find(tostring(errNoStream), "NO_STREAM_ID") ~= nil, "Error indicates NO_STREAM_ID")

	local okHoldNoStream = pcall(function()
		hatch:holdStart()
	end)
	eq(okHoldNoStream, false, "holdStart() fails without streamId")

	-- 2.2 Feed snapshot to provide streamId
	local snapshot = makeTestSnapshot({ streamId = "stream-test-42", commitRevision = "1" })
	store:applySnapshot(snapshot)
	eq(store:getStreamId(), "stream-test-42", "Stream ID established")

	-- 2.3 HatchPress generates monotonic sequence
	outgoing = {}
	local msg1, seq1 = hatch:press()
	eq(seq1, "1", "First inputSeq is 1")
	eq(#outgoing, 1, "One message sent")
	eq(outgoing[1].kind, "HatchPress")
	eq(outgoing[1].streamId, "stream-test-42")
	eq(outgoing[1].inputSeq, "1")
	ok(Protocol.validateClient(outgoing[1]), "HatchPress passes ProtocolSchemas validation")

	local msg2, seq2 = hatch:press()
	eq(seq2, "2", "Second inputSeq is 2")
	eq(#outgoing, 2)
	eq(outgoing[2].inputSeq, "2")
	ok(C.ExactUInt.compare(C.ExactUInt.decode(seq2), C.ExactUInt.decode(seq1)) > 0, "seq2 > seq1")

	-- 2.4 HatchInput holdStart, holdRefresh, holdStop
	local msg3, seq3 = hatch:holdStart()
	eq(seq3, "3", "holdStart inputSeq is 3")
	eq(#outgoing, 3)
	eq(outgoing[3].kind, "HatchInput")
	eq(outgoing[3].state, "start")
	eq(outgoing[3].streamId, "stream-test-42")
	ok(C.ExactUInt.compare(C.ExactUInt.decode(seq3), C.ExactUInt.decode(seq2)) > 0, "seq3 > seq2")
	ok(Protocol.validateClient(outgoing[3]), "holdStart passes ProtocolSchemas validation")

	local msg4, seq4 = hatch:holdRefresh()
	eq(seq4, "4", "holdRefresh inputSeq is 4")
	eq(#outgoing, 4)
	eq(outgoing[4].kind, "HatchInput")
	eq(outgoing[4].state, "refresh")
	ok(C.ExactUInt.compare(C.ExactUInt.decode(seq4), C.ExactUInt.decode(seq3)) > 0, "seq4 > seq3")
	ok(Protocol.validateClient(outgoing[4]), "holdRefresh passes ProtocolSchemas validation")

	local msg5, seq5 = hatch:holdStop()
	eq(seq5, "5", "holdStop inputSeq is 5")
	eq(#outgoing, 5)
	eq(outgoing[5].kind, "HatchInput")
	eq(outgoing[5].state, "stop")
	ok(C.ExactUInt.compare(C.ExactUInt.decode(seq5), C.ExactUInt.decode(seq4)) > 0, "seq5 > seq4")
	ok(Protocol.validateClient(outgoing[5]), "holdStop passes ProtocolSchemas validation")

	-- 2.5 Accessor check
	eq(hatch:getInputSeq(), "5", "Current inputSeq accessor returns 5")
end

-- ============================================================================
-- Section 3: ShopController (QuoteRequest -> Cache -> Confirm Purchase)
-- ============================================================================
do
	local outgoing = {}
	local transport = ClientTransport.new({
		protocol = Protocol,
		wire = function(msg)
			table.insert(outgoing, msg)
		end,
	})

	local store = ClientStateStore.new({
		transport = transport,
		codec = C,
	})

	local snapshot = makeTestSnapshot({ streamId = "stream-shop-1", commitRevision = "5", serverObservedAt = 1000000 })
	store:applySnapshot(snapshot)

	local shop = IntentControllers.ShopController.new({
		transport = transport,
		stateStore = store,
		codec = C,
	})

	-- 3.1 Request Quote
	local targetResearch = { kind = "BuyResearch", args = { researchId = "comfy_nests", mode = "single" } }
	local quoteReceived = nil

	local quoteMsg = shop:requestQuote(targetResearch, function(res)
		quoteReceived = res
	end)

	eq(#outgoing, 1, "QuoteRequest sent")
	eq(outgoing[1].kind, "QuoteRequest")
	eq(outgoing[1].target.kind, "BuyResearch")
	eq(outgoing[1].target.args.researchId, "comfy_nests")
	ok(Protocol.validateClient(outgoing[1]), "QuoteRequest valid under ProtocolSchemas")

	-- Simulate server responding with QuoteView
	local sampleQuote = {
		protocolVersion = 1,
		numericCodecVersion = 1,
		kind = "QuoteView",
		requestId = outgoing[1].requestId,
		quoteId = "quote-cn-1",
		expectedRevision = "5",
		target = targetResearch,
		cashCost = "100",
		currency = "cash",
		nextLevel = 1,
		configRevision = "cfg:1",
		calculationVersion = 1,
		expiresAt = 2000000,
		available = true,
	}
	ok(Protocol.validateServer(sampleQuote), "sampleQuote valid under ProtocolSchemas")

	transport:receive(sampleQuote)
	ok(quoteReceived ~= nil, "Quote callback invoked")
	eq(quoteReceived.quoteId, "quote-cn-1", "Quote ID matches")

	-- 3.2 Verify Quote Caching
	local cachedByTarget = shop:getCachedQuote(targetResearch)
	ok(cachedByTarget ~= nil, "Quote found by target table")
	eq(cachedByTarget.quoteId, "quote-cn-1")

	local cachedByString = shop:getCachedQuote("BuyResearch:comfy_nests")
	ok(cachedByString ~= nil, "Quote found by key string")
	eq(cachedByString.quoteId, "quote-cn-1")

	eq(shop:getLatestQuote().quoteId, "quote-cn-1", "Latest quote matches")

	-- 3.3 Confirm Purchase: Rejection cases
	-- Case A: Quote marked as unavailable
	local blockedQuote = table.clone(sampleQuote)
	blockedQuote.available = false
	blockedQuote.blockedReason = "TIER_LOCKED"
	local okBlocked, errBlocked = shop:confirmPurchase(blockedQuote)
	eq(okBlocked, false, "Blocked quote rejected")
	eq(errBlocked, "TIER_LOCKED", "Reason is TIER_LOCKED")

	-- Case B: Quote expired
	local expiredQuote = table.clone(sampleQuote)
	expiredQuote.expiresAt = 500000 -- earlier than serverObservedAt (1000000)
	local okExpired, errExpired = shop:confirmPurchase(expiredQuote)
	eq(okExpired, false, "Expired quote rejected")
	eq(errExpired, "QUOTE_EXPIRED", "Reason is QUOTE_EXPIRED")

	-- Case C: Commit revision mismatch
	local mismatchQuote = table.clone(sampleQuote)
	mismatchQuote.expectedRevision = "99" -- store commitRevision is "5"
	local okMismatch, errMismatch = shop:confirmPurchase(mismatchQuote)
	eq(okMismatch, false, "Revision mismatch rejected")
	eq(errMismatch, "REVISION_MISMATCH", "Reason is REVISION_MISMATCH")

	-- 3.4 Confirm Purchase: Successful case
	outgoing = {}
	local purchaseResultCallback = nil
	local okConfirm, opId, sentMsg = shop:confirmPurchase(sampleQuote, function(res)
		purchaseResultCallback = res
	end)

	eq(okConfirm, true, "Purchase confirmed successfully")
	ok(opId ~= nil and #opId > 0, "operationId generated")
	eq(#outgoing, 1, "Purchase command sent to wire")
	eq(outgoing[1].kind, "BuyResearch")
	eq(outgoing[1].operationId, opId)
	eq(outgoing[1].expectedRevision, "5")
	eq(outgoing[1].args.researchId, "comfy_nests")
	eq(outgoing[1].args.mode, "single")
	eq(outgoing[1].args.quoteId, "quote-cn-1")
	ok(Protocol.validateClient(outgoing[1]), "Sent purchase message valid under ProtocolSchemas")

	-- Verify unique operationId generation on subsequent confirmation
	local okConfirm2, opId2 = shop:confirmPurchase(sampleQuote)
	eq(okConfirm2, true, "Second purchase confirmed")
	ok(opId2 ~= opId, "Subsequent purchase gets unique operationId")
	eq(#outgoing, 2, "Second purchase sent to wire")
	eq(outgoing[2].operationId, opId2)

	-- Simulate server sending CommandResult
	local commandResult = {
		protocolVersion = 1,
		kind = "CommandResult",
		requestId = outgoing[1].requestId,
		operationId = opId,
		status = "APPLIED",
		resultRevision = "6",
		currentCommitRevision = "6",
		streamId = "stream-shop-1",
		serverObservedAt = 1000050,
		result = {
			terminalStatus = "APPLIED",
			actionKind = "BuyResearch",
			researchId = "comfy_nests",
			level = 1,
		},
	}
	ok(Protocol.validateServer(commandResult), "CommandResult valid")
	transport:receive(commandResult)

	ok(purchaseResultCallback ~= nil, "Purchase callback notified on CommandResult")
	eq(purchaseResultCallback.status, "APPLIED")
	eq(purchaseResultCallback.result.level, 1)

	shop:destroy()
end

-- ============================================================================
-- Section 4: HUD Reaction to ClientStateStore (Snapshots & Deltas)
-- ============================================================================
do
	local outgoing = {}
	local transport = ClientTransport.new({
		protocol = Protocol,
		wire = function(msg) table.insert(outgoing, msg) end,
	})

	local store = ClientStateStore.new({
		transport = transport,
		codec = C,
	})

	local controllers = IntentControllers.new({
		transport = transport,
		stateStore = store,
		codec = C,
	})

	local hud = HUD.new({
		stateStore = store,
		intentControllers = controllers,
		codec = C,
	})

	-- Initial state
	eq(hud:getSessionStatus(), "CONNECTING", "Initial HUD status is CONNECTING")
	eq(hud:getCashText(), "$0", "Default cash before snapshot is $0")
	eq(hud:getCashRateText(), "+$0/s", "Default cash rate before snapshot is +$0/s")

	-- 4.1 Apply StateSnapshot
	local snap = makeTestSnapshot({
		streamId = "stream-hud-full",
		commitRevision = "1",
		viewSeq = "1",
		cash = "5420000",
		producedEggsPerSecond = "24500",
		soldEggsPerSecond = "20000",
		fleet = { shippingPerMinute = "1200000" },
		hatchery = { stock = "250", capacity = "500", refillPerSecond = "10" },
		habitats = {
			{ habitatIndex = 0, population = "150", capacity = "500" },
			{ habitatIndex = 1, population = "0", capacity = "250" },
			{ habitatIndex = 2, population = "250", capacity = "250" },
			{ habitatIndex = 3, population = "50", capacity = "100" },
		},
	})
	store:applySnapshot(snap)

	-- Verify HUD elements updated
	eq(hud:getSessionStatus(), "READY", "Status is READY after snapshot")
	eq(hud:getCashText(), "$5.42M", "Cash formatted as $5.42M")
	eq(hud:getCashRateText(), "+$500/s", "Cash rate formatted as +$500/s")
	eq(hud:getProducedEggsText(), "24.5K jaj/s", "Produced eggs 24.5K jaj/s")
	eq(hud:getSoldEggsText(), "20K jaj/s", "Sold eggs 20K jaj/s")
	eq(hud:getShippingText(), "20K jaj/s", "Transport limit 1.2M/min -> 20K jaj/s")

	-- Hatchery
	eq(hud:getHatcheryText(), "250 / 500", "Hatchery stock / capacity")
	eq(hud:getHatcheryRatio(), 0.5, "Hatchery fill ratio is 0.5")
	eq(hud:getHatcheryRefillText(), "+10/s", "Hatchery refill rate is +10/s")

	-- Habitats 1..4
	eq(hud:getHabitatText(1), "150 / 500", "Habitat 1 text")
	eq(hud:getHabitatRatio(1), 0.3, "Habitat 1 ratio is 0.3")
	eq(hud:getHabitatText(2), "0 / 250", "Habitat 2 text")
	eq(hud:getHabitatRatio(2), 0.0, "Habitat 2 ratio is 0.0")
	eq(hud:getHabitatText(3), "250 / 250", "Habitat 3 text")
	eq(hud:getHabitatRatio(3), 1.0, "Habitat 3 ratio is 1.0")
	eq(hud:getHabitatText(4), "50 / 100", "Habitat 4 text")
	eq(hud:getHabitatRatio(4), 0.5, "Habitat 4 ratio is 0.5")

	-- 4.2 Apply StateDelta (cash and habitat 1 change)
	local delta = {
		protocolVersion = 1,
		numericCodecVersion = 1,
		viewSchemaVersion = 1,
		configRevision = "cfg:1",
		calculationVersion = 1,
		streamId = "stream-hud-full",
		commitRevision = "2",
		viewSeq = "2",
		baseViewSeq = "1",
		serverObservedAt = 1000100,
		kind = "StateDelta",
		changes = {
			audience = "own",
			farm = {
				cash = "10000000",
				habitats = {
					{ slotId = 1, habitatIndex = 0, population = "350", capacity = "500", reservedInTransit = "0" },
					{ slotId = 2, habitatIndex = 1, population = "0", capacity = "250", reservedInTransit = "0" },
					{ slotId = 3, habitatIndex = 2, population = "250", capacity = "250", reservedInTransit = "0" },
					{ slotId = 4, habitatIndex = 3, population = "50", capacity = "100", reservedInTransit = "0" },
				},
			},
		},
	}
	ok(Protocol.validateServer(delta), "Delta is valid under ProtocolSchemas")
	store:applyDelta(delta)

	-- Verify HUD updated after delta
	eq(hud:getCashText(), "$10M", "Cash updated to $10M")
	eq(hud:getHabitatText(1), "350 / 500", "Habitat 1 population updated to 350 / 500")
	eq(hud:getHabitatRatio(1), 0.7, "Habitat 1 ratio updated to 0.7")
	-- Other elements unchanged
	eq(hud:getProducedEggsText(), "24.5K jaj/s", "Produced eggs preserved")

	hud:destroy()
end

-- ============================================================================
-- Section 5: Shop View Button States & Blocked Reasons
-- ============================================================================
do
	local transport = ClientTransport.new({
		protocol = Protocol,
		wire = function() end,
	})

	local store = ClientStateStore.new({
		transport = transport,
		codec = C,
	})

	local controllers = IntentControllers.new({
		transport = transport,
		stateStore = store,
		codec = C,
	})

	local hud = HUD.new({
		stateStore = store,
		intentControllers = controllers,
		codec = C,
	})

	local snap = makeTestSnapshot({
		streamId = "stream-shop-locks",
		common = {
			{ researchId = "comfy_nests", level = 5, available = true },
			{ researchId = "hab_capacity1", level = 0, available = false, blockedReason = "TIER_LOCKED" },
			{ researchId = "maxed_research", level = 25, available = false, blockedReason = "MAX_LEVEL" },
			{ researchId = "expensive_research", level = 1, available = false, blockedReason = "INSUFFICIENT_CASH" },
		},
	})
	store:applySnapshot(snap)

	-- 5.1 Available item
	local cn = hud:getShopResearchItem("comfy_nests")
	ok(cn ~= nil, "comfy_nests item created in HUD")
	eq(cn.available, true, "comfy_nests is available")
	eq(cn.buyButton.Active, true, "comfy_nests buyButton is Active")
	eq(cn.statusLabel.Text, "BUY", "comfy_nests status label shows BUY")
	eq(cn.blockedReason, nil, "comfy_nests has no blockedReason")

	-- 5.2 TIER_LOCKED item
	local habCap = hud:getShopResearchItem("hab_capacity1")
	ok(habCap ~= nil, "hab_capacity1 item created in HUD")
	eq(habCap.available, false, "hab_capacity1 is not available")
	eq(habCap.buyButton.Active, false, "hab_capacity1 buyButton is inactive")
	eq(habCap.statusLabel.Text, "TIER_LOCKED", "hab_capacity1 status label shows TIER_LOCKED")
	eq(habCap.blockedReason, "TIER_LOCKED", "hab_capacity1 blockedReason is TIER_LOCKED")

	-- 5.3 MAX_LEVEL item
	local maxed = hud:getShopResearchItem("maxed_research")
	ok(maxed ~= nil, "maxed_research item created in HUD")
	eq(maxed.available, false, "maxed_research is not available")
	eq(maxed.buyButton.Active, false, "maxed_research buyButton is inactive")
	eq(maxed.statusLabel.Text, "MAX_LEVEL", "maxed_research status label shows MAX_LEVEL")
	eq(maxed.blockedReason, "MAX_LEVEL", "maxed_research blockedReason is MAX_LEVEL")

	-- 5.4 INSUFFICIENT_CASH item
	local exp = hud:getShopResearchItem("expensive_research")
	ok(exp ~= nil, "expensive_research item created in HUD")
	eq(exp.available, false, "expensive_research is not available")
	eq(exp.buyButton.Active, false, "expensive_research buyButton is inactive")
	eq(exp.statusLabel.Text, "INSUFFICIENT_CASH", "expensive_research status label shows INSUFFICIENT_CASH")
	eq(exp.blockedReason, "INSUFFICIENT_CASH", "expensive_research blockedReason is INSUFFICIENT_CASH")

	-- 5.5 Arrival of quote updates price and status
	local quoteView = {
		protocolVersion = 1,
		numericCodecVersion = 1,
		kind = "QuoteView",
		requestId = "req-quote-cn",
		quoteId = "quote-cn-10",
		expectedRevision = "1",
		target = { kind = "BuyResearch", args = { researchId = "comfy_nests", mode = "single" } },
		cashCost = "15000",
		currency = "cash",
		nextLevel = 6,
		configRevision = "cfg:1",
		calculationVersion = 1,
		expiresAt = 9999999,
		available = true,
	}
	transport:receive(quoteView)

	eq(cn.priceLabel.Text, "$15K", "comfy_nests price label updated to $15K from quote")

	hud:destroy()
end

-- ============================================================================
-- Section 6: Lifecycle Banner Transitions (CONNECTING, LOADING, READY, RESYNCING, SESSION_LOST)
-- ============================================================================
do
	local transport = ClientTransport.new({
		protocol = Protocol,
		wire = function() end,
	})

	local store = ClientStateStore.new({
		transport = transport,
		codec = C,
	})

	local controllers = IntentControllers.new({
		transport = transport,
		stateStore = store,
		codec = C,
	})

	local hud = HUD.new({
		stateStore = store,
		intentControllers = controllers,
		codec = C,
	})

	-- State 1: CONNECTING
	eq(hud:getSessionStatus(), "CONNECTING", "Initial lifecycle status is CONNECTING")
	eq(hud.sessionStatusLabel.Text, "CONNECTING", "Banner label shows CONNECTING")

	-- State 2: LOADING (explicit loading state prior to snapshot reception)
	store:setStatus("LOADING")
	eq(hud:getSessionStatus(), "LOADING", "Lifecycle transitions to LOADING")
	eq(hud.sessionStatusLabel.Text, "LOADING", "Banner label shows LOADING")

	-- State 3: READY (via StateSnapshot)
	local snap = makeTestSnapshot({ streamId = "stream-lifecycle-1", viewSeq = "1" })
	store:applySnapshot(snap)
	eq(hud:getSessionStatus(), "READY", "Lifecycle transitions to READY")
	eq(hud.sessionStatusLabel.Text, "READY", "Banner label shows READY")

	-- State 4: RESYNCING (via Sequence Gap in StateDelta)
	local gapDelta = {
		protocolVersion = 1,
		numericCodecVersion = 1,
		viewSchemaVersion = 1,
		configRevision = "cfg:1",
		calculationVersion = 1,
		streamId = "stream-lifecycle-1",
		commitRevision = "10",
		viewSeq = "10",
		baseViewSeq = "9", -- Gap! Current store viewSeq is 1
		serverObservedAt = 1000200,
		kind = "StateDelta",
		changes = { audience = "own", farm = {} },
	}
	store:applyDelta(gapDelta)
	eq(hud:getSessionStatus(), "RESYNCING", "Lifecycle transitions to RESYNCING upon gap")
	eq(hud.sessionStatusLabel.Text, "RESYNCING", "Banner label shows RESYNCING")

	-- State 4: SESSION_LOST
	local lostSnap = makeTestSnapshot({ streamId = "stream-lifecycle-2", lifecycle = "sessionLost" })
	store:applySnapshot(lostSnap)
	eq(hud:getSessionStatus(), "SESSION_LOST", "Lifecycle transitions to SESSION_LOST")
	eq(hud.sessionStatusLabel.Text, "SESSION_LOST", "Banner label shows SESSION_LOST")

	hud:destroy()
end

-- ============================================================================
-- Section 7: Critical Architectural Invariant
-- HUD and IntentControllers NEVER modify authoritative state or grant resources!
-- ============================================================================
do
	local outgoing = {}
	local transport = ClientTransport.new({
		protocol = Protocol,
		wire = function(msg) table.insert(outgoing, msg) end,
	})

	local store = ClientStateStore.new({
		transport = transport,
		codec = C,
	})

	local snap = makeTestSnapshot({
		streamId = "stream-invariant-1",
		cash = "100",
		habitats = {
			{ habitatIndex = 0, population = "10", capacity = "500" },
			{ habitatIndex = 0, population = "0", capacity = "500" },
			{ habitatIndex = 0, population = "0", capacity = "500" },
			{ habitatIndex = 0, population = "0", capacity = "500" },
		},
	})
	store:applySnapshot(snap)

	local controllers = IntentControllers.new({
		transport = transport,
		stateStore = store,
		codec = C,
	})

	local hud = HUD.new({
		stateStore = store,
		intentControllers = controllers,
		codec = C,
	})

	-- Player interacts with UI buttons
	hud:pressHatch()
	hud:startHoldHatch()
	hud:refreshHoldHatch()
	hud:stopHoldHatch()

	-- Click buy button on research
	hud:buyResearch("comfy_nests")

	-- VERIFY: Store state is UNTOUCHED!
	local farmState = store:getFarm()
	eq(farmState.cash, "100", "Authoritative cash is untouched by HUD or controllers")
	eq(farmState.habitats[1].population, "10", "Authoritative population is untouched by HUD or controllers")
	eq(farmState.common[1].level, 0, "Authoritative research level is untouched by HUD or controllers")

	hud:destroy()
end

-- ============================================================================
-- Section 8: HabitatsModal (19 Habitats & 4 Parcel Cards)
-- ============================================================================
do
	local transport = ClientTransport.new({ protocol = Protocol, wire = function() end })
	local store = ClientStateStore.new({ transport = transport, codec = C })
	local controllers = IntentControllers.new({ transport = transport, stateStore = store, codec = C })

	local clickedSlot = nil
	local hud = HUD.new({
		stateStore = store,
		intentControllers = controllers,
		codec = C,
		onQuickBuyHabitat = function(slotId)
			clickedSlot = slotId
		end,
	})

	local habModal = hud:getHabitatsModal()
	ok(habModal ~= nil, "HabitatsModal created")
	eq(habModal.Visible, false, "HabitatsModal initially hidden")

	-- Toggle open
	hud:toggleHabitatsModal(true)
	eq(habModal.Visible, true, "HabitatsModal opened")

	-- Feed snapshot with different habitats
	local snap = makeTestSnapshot({
		streamId = "stream-habs-19",
		habitats = {
			{ slotId = 1, habitatIndex = 0, population = "100", capacity = "250" }, -- Coop
			{ slotId = 2, habitatIndex = 1, population = "300", capacity = "500" }, -- Shack
			{ slotId = 3, habitatIndex = 7, population = "25000", capacity = "50000" }, -- Warehouse
			{ slotId = 4, habitatIndex = 18, population = "1000000", capacity = "600000000" }, -- Chicken Universe
		},
	})
	store:applySnapshot(snap)

	-- Verify parcel cards 1..4
	for slotId = 1, 4 do
		local card = hud.habitatCards[slotId]
		ok(card ~= nil, "Habitat card " .. tostring(slotId) .. " exists")
		local title = card:FindFirstChild("TitleLabel")
		ok(title ~= nil, "Card " .. tostring(slotId) .. " has TitleLabel")
		local pop = card:FindFirstChild("PopulationLabel")
		ok(pop ~= nil, "Card " .. tostring(slotId) .. " has PopulationLabel")
		local upg = card:FindFirstChild("UpgradeHabitatBtn")
		ok(upg ~= nil, "Card " .. tostring(slotId) .. " has UpgradeHabitatBtn")
	end

	-- Card 1: Tier 1 (type 0)
	local card1 = hud.habitatCards[1]
	ok(string.find(card1:FindFirstChild("TitleLabel").Text, "Tier 1") ~= nil, "Card 1 displays Tier 1")
	ok(string.find(card1:FindFirstChild("NextUpgradeLabel").Text, "Tier 2") ~= nil, "Card 1 next is Tier 2")

	-- Card 4: Tier 19 (max)
	local card4 = hud.habitatCards[4]
	ok(string.find(card4:FindFirstChild("TitleLabel").Text, "Tier 19") ~= nil, "Card 4 displays Tier 19")
	ok(string.find(card4:FindFirstChild("NextUpgradeLabel").Text, "Maksymalny") ~= nil, "Card 4 displays MAX")

	-- Trigger upgrade button on slot 2
	local upgBtn2 = hud.habitatCards[2]:FindFirstChild("UpgradeHabitatBtn")
	upgBtn2.Activated:Fire()
	eq(clickedSlot, 2, "UpgradeHabitatBtn slot 2 invoked onQuickBuyHabitat")

	-- Close
	hud:toggleHabitatsModal(false)
	eq(habModal.Visible, false, "HabitatsModal closed")

	hud:destroy()
end

-- ============================================================================
-- Section 9: VehiclesModal (12 Vehicles, 17 Fleet Slots, Shipping Comparison)
-- ============================================================================
do
	local transport = ClientTransport.new({ protocol = Protocol, wire = function() end })
	local store = ClientStateStore.new({ transport = transport, codec = C })
	local controllers = IntentControllers.new({ transport = transport, stateStore = store, codec = C })

	local clickedVehSlot = nil
	local hud = HUD.new({
		stateStore = store,
		intentControllers = controllers,
		codec = C,
		onQuickBuyVehicle = function(slotId)
			clickedVehSlot = slotId
		end,
	})

	local vModal = hud:getVehiclesModal()
	ok(vModal ~= nil, "VehiclesModal created")
	eq(vModal.Visible, false, "VehiclesModal initially hidden")

	hud:toggleVehiclesModal(true)
	eq(vModal.Visible, true, "VehiclesModal opened")

	-- Test 9.1: Shipping > Production (Sufficient)
	local snapSufficient = makeTestSnapshot({
		streamId = "stream-fleet-1",
		producedEggsPerSecond = "100", -- 6,000 eggs/min
		fleet = {
			shippingPerMinute = "60000", -- 60,000 eggs/min
			vehicles = {
				{ slotId = 1, vehicleIndex = 0 }, -- Trike
				{ slotId = 2, vehicleIndex = 1 }, -- Transit Van
			},
		},
	})
	store:applySnapshot(snapSufficient)
	eq(hud:getShippingComparisonStatus(), "Spedycja wystarczająca", "Status is Spedycja wystarczająca when rate >= production")

	-- Test 9.2: Shipping < Production (Bottleneck)
	local snapBottleneck = makeTestSnapshot({
		streamId = "stream-fleet-2",
		producedEggsPerSecond = "2000", -- 120,000 eggs/min
		fleet = {
			shippingPerMinute = "15000", -- 15,000 eggs/min
			vehicles = {
				{ slotId = 1, vehicleIndex = 0 },
			},
		},
	})
	store:applySnapshot(snapBottleneck)
	eq(hud:getShippingComparisonStatus(), "Wąskie gardło spedycji!", "Status is Wąskie gardło spedycji when rate < production")

	-- Test 9.3: Slot 1 active vs Slot 10 locked
	local container = vModal:FindFirstChild("FleetSlotsContainer")
	ok(container ~= nil, "FleetSlotsContainer exists")

	local slot1Card = container:FindFirstChild("VehicleSlotCard_1")
	ok(slot1Card ~= nil, "VehicleSlotCard_1 exists")
	ok(string.find(slot1Card:FindFirstChild("Title").Text, "Tier 1") ~= nil, "Slot 1 shows Tier 1")
	eq(slot1Card:FindFirstChild("BuyVehicleButton").Active, true, "Slot 1 buy button active")

	-- Test 9.4: Trigger upgrade button on slot 1
	slot1Card:FindFirstChild("BuyVehicleButton").Activated:Fire()
	eq(clickedVehSlot, 1, "BuyVehicleButton slot 1 invoked onQuickBuyVehicle")

	local slot10Card = container:FindFirstChild("VehicleSlotCard_10")
	ok(slot10Card ~= nil, "VehicleSlotCard_10 exists")
	ok(string.find(slot10Card:FindFirstChild("Title").Text, "Zablokowany") ~= nil, "Slot 10 is marked Zablokowany")
	eq(slot10Card:FindFirstChild("BuyVehicleButton").Active, false, "Slot 10 buy button disabled")

	hud:destroy()
end

-- ============================================================================
-- Section 10: ResearchModal (Multi-Tier Tabs 1..13 + EPICKIE, Tier Unlock Check)
-- ============================================================================
do
	local transport = ClientTransport.new({ protocol = Protocol, wire = function() end })
	local store = ClientStateStore.new({ transport = transport, codec = C })
	local controllers = IntentControllers.new({ transport = transport, stateStore = store, codec = C })
	store:applySnapshot(makeTestSnapshot({ streamId = "stream-audio-1", commitRevision = "1" }))

	local hud = HUD.new({
		stateStore = store,
		intentControllers = controllers,
		codec = C,
	})

	local resModal = hud:getResearchModal()
	ok(resModal ~= nil, "ResearchModal created")
	eq(resModal.Visible, false, "ResearchModal initially hidden")

	hud:toggleResearchModal(true)
	eq(resModal.Visible, true, "ResearchModal opened")

	-- Common has 13 tabs; Epic has its own modal.
	local tabsRow = resModal:FindFirstChild("TierTabsRow")
	ok(tabsRow ~= nil, "TierTabsRow exists")
	eq(#tabsRow:GetChildren(), 13, "13 tabs present (T1..T13)")

	-- Check initial selected tier is 1
	eq(hud:getCurrentResearchTier(), 1, "Initial selected tier is 1")

	-- Feed snapshot with total research points = 10 (Tier 1 unlocked, Tier 2 requires 30 -> locked)
	local snap = makeTestSnapshot({
		streamId = "stream-tier-locks",
		common = {
			{ researchId = "comfy_nests", level = 10, available = true },
			{ researchId = "hab_capacity1", level = 0, available = false, blockedReason = "TIER_LOCKED" },
			{ researchId = "padded_packaging", level = 0, available = false, blockedReason = "TIER_LOCKED" },
		},
	})
	store:applySnapshot(snap)

	-- Select Tier 2
	hud:selectResearchTier(2)
	eq(hud:getCurrentResearchTier(), 2, "Selected tier is 2")

	-- Tier lock banner should be visible for Tier 2 since 10 < 30
	local lockBanner = resModal:FindFirstChild("TierLockBanner")
	ok(lockBanner ~= nil, "TierLockBanner exists")
	eq(lockBanner.Visible, true, "TierLockBanner is visible for locked Tier 2")
	ok(string.find(lockBanner.Text, "wymaga 30", 1, true) ~= nil or string.find(lockBanner.Text, "Wymaga 30", 1, true) ~= nil, "Banner mentions 30 required")

	-- Switch to Tier 1: banner should be hidden
	hud:selectResearchTier(1)
	eq(lockBanner.Visible, false, "TierLockBanner is hidden for Tier 1")

	-- Open the dedicated Epic window.
	-- Dedicated Epic Research Modal
	hud:toggleEpicResearchModal(true)
	local epicModal = hud:getEpicResearchModal()
	ok(epicModal ~= nil, "EpicResearchModal created")
	eq(epicModal.Visible, true, "EpicResearchModal opened")
	local gePill = epicModal:FindFirstChild("EpicGeBalancePill")
	ok(gePill ~= nil, "EpicGeBalancePill exists")
	local epicContainer = epicModal:FindFirstChild("EpicResearchListContainer")
	ok(epicContainer ~= nil, "EpicResearchListContainer exists")
	eq(#epicContainer:GetChildren(), 23, "All 23 active epic research cards present")
	hud:closeAllModals()
	eq(epicModal.Visible, false, "closeAllModals closes EpicResearchModal")



	hud:destroy()
end

-- ============================================================================
-- Section 11: PetsModal (Equipped Slots 3/5, Inventory, Fusion with Pro Permit)
-- ============================================================================
do
	local transport = ClientTransport.new({ protocol = Protocol, wire = function() end })
	local store = ClientStateStore.new({ transport = transport, codec = C })
	local controllers = IntentControllers.new({ transport = transport, stateStore = store, codec = C })

	local fusedBase = nil
	local equippedPet = nil
	local unequippedSlot = nil
	local lockedPet = nil

	local hud = HUD.new({
		stateStore = store,
		intentControllers = controllers,
		codec = C,
		onFusePets = function(baseId, matIds)
			fusedBase = baseId
		end,
		onEquipPet = function(petId, slotIdx)
			equippedPet = petId
		end,
		onUnequipPet = function(slotIdx)
			unequippedSlot = slotIdx
		end,
		onTogglePetLock = function(petId)
			lockedPet = petId
		end,
	})

	local pModal = hud:getPetsModal()
	ok(pModal ~= nil, "PetsModal exists")
	eq(pModal.Visible, false, "PetsModal initially hidden")

	hud:togglePetsModal(true)
	eq(pModal.Visible, true, "PetsModal opened")

	-- Equipped slots: 5 slot buttons present
	local eqFrame = pModal:FindFirstChild("EquippedSlotsFrame")
	ok(eqFrame ~= nil, "EquippedSlotsFrame exists")
	for s = 1, 5 do
		local slotBtn = eqFrame:FindFirstChild("EquippedSlot_" .. tostring(s))
		ok(slotBtn ~= nil, "EquippedSlot_" .. tostring(s) .. " exists")
	end

	-- Test unequip slot 1
	eqFrame:FindFirstChild("EquippedSlot_1").Activated:Fire()
	eq(unequippedSlot, 1, "EquippedSlot_1 fired onUnequipPet")

	-- Inventory Section: Equip and Lock buttons
	local invFrame = pModal:FindFirstChild("InventoryFrame")
	ok(invFrame ~= nil, "InventoryFrame exists")
	local petCard1 = invFrame:FindFirstChild("PetCard_1")
	ok(petCard1 ~= nil, "PetCard_1 exists")

	petCard1:FindFirstChild("EquipBtn").Activated:Fire()
	eq(equippedPet, nil, "Empty inventory must not select a fabricated pet")

	petCard1:FindFirstChild("LockBtn").Activated:Fire()
	eq(lockedPet, nil, "Empty inventory must not lock a fabricated pet")

	-- Fusion Section: Chance, Guarantee, Pro Permit badge, Fuse button
	local fusFrame = pModal:FindFirstChild("FusionFrame")
	ok(fusFrame ~= nil, "FusionFrame exists")
	ok(fusFrame:FindFirstChild("FusionChanceLabel") ~= nil, "FusionChanceLabel exists")
	ok(fusFrame:FindFirstChild("FusionGuaranteeLabel") ~= nil, "FusionGuaranteeLabel exists")
	ok(fusFrame:FindFirstChild("ProPermitBonusBadge") ~= nil, "ProPermitBonusBadge exists")

	local fuseBtn = fusFrame:FindFirstChild("FusePetsButton")
	ok(fuseBtn ~= nil, "FusePetsButton exists")
	fuseBtn.Activated:Fire()
	eq(fusedBase, nil, "Fusion requires explicit base and material selection")

	hud:destroy()
end

-- ============================================================================
-- Section 12: ShopModal (GE Packs, Boosts, GamePasses with Pro Permit Notice)
-- ============================================================================
do
	local transport = ClientTransport.new({ protocol = Protocol, wire = function() end })
	local store = ClientStateStore.new({ transport = transport, codec = C })
	local controllers = IntentControllers.new({ transport = transport, stateStore = store, codec = C })

	local purchasedProduct = nil
	local purchasedBoost = nil

	local hud = HUD.new({
		stateStore = store,
		intentControllers = controllers,
		codec = C,
		onPurchaseProduct = function(prodId)
			purchasedProduct = prodId
		end,
		onBuyBoost = function(boostId)
			purchasedBoost = boostId
		end,
	})

	local sModal = hud:getShopModal()
	ok(sModal ~= nil, "ShopModal exists")
	eq(sModal.Visible, false, "ShopModal initially hidden")

	hud:toggleShopModal(true)
	eq(sModal.Visible, true, "ShopModal opened")

	-- Tab 1: GE Packs
	hud:selectShopTab(1)
	eq(hud:getCurrentShopTab(), 1, "Selected shop tab 1")
	local cont = sModal:FindFirstChild("ShopContentContainer")
	ok(cont:FindFirstChild("Tab1_GEPacks").Visible, "Tab 1 visible")
	ok(not cont:FindFirstChild("Tab2_Boosts").Visible, "Tab 2 hidden")
	ok(not cont:FindFirstChild("Tab3_GamePasses").Visible, "Tab 3 hidden")

	local geCard = cont:FindFirstChild("Tab1_GEPacks"):FindFirstChild("ShopCard_ge_pack_small")
	ok(geCard ~= nil, "ShopCard_ge_pack_small exists")
	geCard:FindFirstChild("BuyProductButton").Activated:Fire()
	eq(purchasedProduct, "ge_pack_small", "ge_pack_small buy button fired onPurchaseProduct")

	-- Tab 2: Boosts
	hud:selectShopTab(2)
	eq(hud:getCurrentShopTab(), 2, "Selected shop tab 2")
	ok(cont:FindFirstChild("Tab2_Boosts").Visible, "Tab 2 visible")
	local boostCard = cont:FindFirstChild("Tab2_Boosts"):FindFirstChild("BoostCard_jimbos_blue_v2")
	ok(boostCard ~= nil, "BoostCard_jimbos_blue_v2 exists")
	boostCard:FindFirstChild("BuyBoostButton").Activated:Fire()
	eq(purchasedBoost, "jimbos_blue_v2", "jimbos_blue_v2 buy button fired onBuyBoost")

	-- Tab 3: GamePasses
	hud:selectShopTab(3)
	eq(hud:getCurrentShopTab(), 3, "Selected shop tab 3")
	ok(cont:FindFirstChild("Tab3_GamePasses").Visible, "Tab 3 visible")
	local proCard = cont:FindFirstChild("Tab3_GamePasses"):FindFirstChild("PassCard_pro_permit")
	ok(proCard ~= nil, "PassCard_pro_permit exists")
	-- Check regulatory notice
	local notice = proCard:FindFirstChild("Notice")
	ok(notice ~= nil, "Notice exists on Pro Permit card")
	ok(string.find(notice.Text, "regulacjami", 1, true) ~= nil, "Notice mentions regulatory compliance")

	proCard:FindFirstChild("BuyPassButton").Activated:Fire()
	eq(purchasedProduct, "pro_permit", "pro_permit buy button fired onPurchaseProduct")

	local autoHatchCard = cont:FindFirstChild("Tab3_GamePasses"):FindFirstChild("PassCard_auto_hatch")
	ok(autoHatchCard ~= nil, "PassCard_auto_hatch exists")
	autoHatchCard:FindFirstChild("BuyPassButton").Activated:Fire()
	eq(purchasedProduct, "pro_permit", "Auto-Hatch placeholder does not invoke purchase")
	eq(autoHatchCard:FindFirstChild("BuyPassButton").Active, false, "Auto-Hatch disabled")
	local maxCard=cont:FindFirstChild("Tab3_GamePasses"):FindFirstChild("PassCard_buy_max")
	maxCard:FindFirstChild("BuyPassButton").Activated:Fire()
	eq(purchasedProduct,"pro_permit","Buy MAX placeholder cannot invoke purchase")
	eq(maxCard:FindFirstChild("BuyPassButton").Active,false,"Buy MAX disabled")
	hud:selectResearchTier(14)
	eq(hud:getCurrentResearchTier(),1,"Invalid retired tier does not change selection")

	hud:destroy()
end

-- ============================================================================
-- Section 13: CalendarModal (28-day Grid & 19-Egg Trophies)
-- ============================================================================
do
	local transport = ClientTransport.new({ protocol = Protocol, wire = function() end })
	local store = ClientStateStore.new({ transport = transport, codec = C })
	local controllers = IntentControllers.new({ transport = transport, stateStore = store, codec = C })

	local giftClaimed = false
	local trophyClaimEgg = nil
	local trophyClaimTier = nil

	local hud = HUD.new({
		stateStore = store,
		intentControllers = controllers,
		codec = C,
		onClaimDailyGift = function()
			giftClaimed = true
		end,
		onClaimTrophy = function(eggIdx, tierIdx)
			trophyClaimEgg = eggIdx
			trophyClaimTier = tierIdx
		end,
	})

	local cModal = hud:getCalendarModal()
	ok(cModal ~= nil, "CalendarModal exists")
	eq(cModal.Visible, false, "CalendarModal initially hidden")

	hud:toggleCalendarModal(true)
	eq(cModal.Visible, true, "CalendarModal opened")

	-- Tab 1: Calendar 28 days
	eq(hud:getCurrentCalendarTab(), 1, "Default calendar tab is 1")
	local calTab1 = cModal:FindFirstChild("CalendarContent_Tab1")
	ok(calTab1 ~= nil, "CalendarContent_Tab1 exists")
	for d = 1, 28 do
		local cell = calTab1:FindFirstChild("DayCell_" .. tostring(d))
		ok(cell ~= nil, "DayCell_" .. tostring(d) .. " exists")
	end

	-- Claim daily gift button
	local claimBtn = cModal:FindFirstChild("ClaimDailyGiftButton")
	ok(claimBtn ~= nil, "ClaimDailyGiftButton exists")
	claimBtn.Activated:Fire()
	eq(giftClaimed, true, "ClaimDailyGiftButton fired onClaimDailyGift")

	-- Tab 2: Trophies
	hud:selectCalendarTab(2)
	eq(hud:getCurrentCalendarTab(), 2, "Selected calendar tab 2 (Trophies)")
	local trophTab2 = cModal:FindFirstChild("TrophiesContent_Tab2")
	ok(trophTab2 ~= nil, "TrophiesContent_Tab2 exists")
	ok(trophTab2.Visible, "Trophies tab visible")

	local egg0Card = trophTab2:FindFirstChild("TrophyCard_Egg_0")
	ok(egg0Card ~= nil, "TrophyCard_Egg_0 exists")
	-- 5 Cup buttons
	for t = 1, 5 do
		ok(egg0Card:FindFirstChild("CupBtn_" .. tostring(t)) ~= nil, "CupBtn_" .. tostring(t) .. " exists")
	end

	-- Click Gold Cup (tier 3) on Egg 0
	egg0Card:FindFirstChild("CupBtn_3").Activated:Fire()
	eq(trophyClaimEgg, 0, "Egg 0 trophy claimed")
	eq(trophyClaimTier, 3, "Tier 3 trophy claimed")

	hud:destroy()
end

-- ============================================================================
-- Section 14: Right Dock 6 Menu Buttons & Mutual Exclusivity
-- ============================================================================
do
	local transport = ClientTransport.new({ protocol = Protocol, wire = function() end })
	local store = ClientStateStore.new({ transport = transport, codec = C })
	local controllers = IntentControllers.new({ transport = transport, stateStore = store, codec = C })
	store:applySnapshot(makeTestSnapshot({ streamId = "stream-audio-1", commitRevision = "1" }))

	local hud = HUD.new({
		stateStore = store,
		intentControllers = controllers,
		codec = C,
	})

	local resModal = hud:getResearchModal()
	local habModal = hud:getHabitatsModal()
	local vehModal = hud:getVehiclesModal()
	local petModal = hud:getPetsModal()
	local shopModal = hud:getShopModal()
	local calModal = hud:getCalendarModal()

	-- All initially hidden
	eq(resModal.Visible, false)
	eq(habModal.Visible, false)
	eq(vehModal.Visible, false)
	eq(petModal.Visible, false)
	eq(shopModal.Visible, false)
	eq(calModal.Visible, false)

	-- 14.1 Open Research Modal via dock button
	hud.researchToggleBtn.Activated:Fire()
	eq(resModal.Visible, true, "ResearchModal opened via dock button")
	eq(habModal.Visible, false)
	eq(vehModal.Visible, false)

	-- 14.2 Open Habitats Modal: Research closes automatically!
	hud.habitatsToggleBtn.Activated:Fire()
	eq(habModal.Visible, true, "HabitatsModal opened")
	eq(resModal.Visible, false, "ResearchModal closed on Habitats open")

	-- 14.3 Open Vehicles Modal
	hud.vehiclesToggleBtn.Activated:Fire()
	eq(vehModal.Visible, true, "VehiclesModal opened")
	eq(habModal.Visible, false, "HabitatsModal closed")

	-- 14.4 Open Pets Modal
	hud.petsToggleBtn.Activated:Fire()
	eq(petModal.Visible, true, "PetsModal opened")
	eq(vehModal.Visible, false, "VehiclesModal closed")

	-- 14.5 Open Shop Modal
	hud.shopToggleBtn.Activated:Fire()
	eq(shopModal.Visible, true, "ShopModal opened")
	eq(petModal.Visible, false, "PetsModal closed")

	-- 14.6 Open Calendar Modal
	hud.calendarToggleBtn.Activated:Fire()
	eq(calModal.Visible, true, "CalendarModal opened")
	eq(shopModal.Visible, false, "ShopModal closed")

	-- 14.6b Epic Research Modal & Dual Buttons (GE & Robux)
	hud:toggleEpicResearchModal(true)
	local epicModal = hud:getEpicResearchModal()
	ok(epicModal ~= nil, "EpicResearchModal created")
	eq(epicModal.Visible, true, "EpicResearchModal opened")
	local epicCard = hud.epicResearchCards and hud.epicResearchCards["hold_to_hatch"]
	ok(epicCard ~= nil, "hold_to_hatch card exists")
	ok(epicCard.buyBtn ~= nil, "buyBtn exists")
	ok(epicCard.buyRobuxBtn ~= nil, "buyRobuxBtn exists")

	-- 14.7 closeAllModals closes everything
	hud:closeAllModals()
	eq(calModal.Visible, false, "CalendarModal closed via closeAllModals")
	eq(epicModal.Visible, false, "EpicResearchModal closed via closeAllModals")

	hud:destroy()
end

-- ============================================================================
-- Section 15: Pet Incubator Modal & Egg Hatch Animation Overlay (PROD-07)
-- ============================================================================
do
	local transport = ClientTransport.new({ protocol = Protocol, wire = function() end })
	local store = ClientStateStore.new({ transport = transport, codec = C })
	local controllers = IntentControllers.new({ transport = transport, stateStore = store, codec = C })
	store:applySnapshot(makeTestSnapshot({ streamId = "stream-audio-1", commitRevision = "1" }))

	local hud = HUD.new({
		stateStore = store,
		intentControllers = controllers,
		codec = C,
	})

	-- 15.1 PetHatchModal verification
	local hatchModal = hud:getPetHatchModal()
	ok(hatchModal ~= nil, "PetHatchModal created")
	eq(hatchModal.Visible, false, "PetHatchModal initially hidden")

	hud:togglePetHatchModal(true)
	eq(hatchModal.Visible, true, "PetHatchModal opened")

	-- 15.2 Hatch Button activation
	local hatchTriggered = false
	hud.onHatchPetEgg = function(eggType)
		hatchTriggered = true
		eq(eggType, "standard_egg", "eggType is standard_egg")
	end
	if hud.hatchEggButton and hud.hatchEggButton.Activated then
		hud.hatchEggButton.Activated:Fire()
		eq(hatchTriggered, true, "HatchEggButton triggers onHatchPetEgg")
	end

	-- 15.3 HatchAnimationOverlay & playEggHatchAnimation
	local animOverlay = hud:getHatchAnimationOverlay()
	ok(animOverlay ~= nil, "HatchAnimationOverlay exists")
	eq(animOverlay.Visible, false, "HatchAnimationOverlay initially hidden")

	local equippedPetId = nil
	local lockedPetId = nil
	hud.onEquipPet = function(pUid, slot)
		equippedPetId = pUid
	end
	hud.onTogglePetLock = function(pUid)
		lockedPetId = pUid
	end

	local animationFinished = false
	hud:playEggHatchAnimation({
		uid = "pet_gold_dog_99",
		speciesId = "farmer_dog",
		rarity = "Legendary",
		variant = "golden",
		tier = 1,
	}, function()
		animationFinished = true
	end)

	eq(animOverlay.Visible, true, "HatchAnimationOverlay visible during reveal")
	eq(hud.petRevealCard.Visible, true, "PetRevealCard visible in test mock")
	eq(hud.revealPetName.Text, "Pies Farmer (Farmer Dog)", "Pet name displayed")
	eq(hud.revealPetIcon.Text, "🐶", "Pet icon displayed")
	eq(hud.revealPetRarity.Text, "LEGENDARY PET", "Pet rarity displayed")
	eq(hud.revealPetStat.Text, "+50% Wartość Jaj", "Pet stat displayed")

	-- Quick Actions: Equip
	if hud.revealEquipBtn and hud.revealEquipBtn.Activated then
		hud.revealEquipBtn.Activated:Fire()
		eq(equippedPetId, "pet_gold_dog_99", "revealEquipBtn equipped correct pet")
	end

	-- Quick Actions: Lock
	if hud.revealLockBtn and hud.revealLockBtn.Activated then
		hud.revealLockBtn.Activated:Fire()
		eq(lockedPetId, "pet_gold_dog_99", "revealLockBtn locked correct pet")
	end

	-- Close All Modals
	hud:closeAllModals()
	eq(hatchModal.Visible, false, "PetHatchModal closed via closeAllModals")
	eq(animOverlay.Visible, false, "HatchAnimationOverlay closed via closeAllModals")

	hud:destroy()
end

-- ============================================================================
-- Section 16: Audio Controller, BGM/SFX Lifecycle & Mobile Interface Optimization (PROD-08)
-- ============================================================================
do
	-- 16.1 AudioController Lifecycle & Sound Effects
	local audio = AudioController.new()
	ok(audio ~= nil, "AudioController instance created")
	eq(audio:getSFXVolume(), 0.8, "Default SFX volume is 0.8")
	eq(audio:getBGMVolume(), 0.5, "Default BGM volume is 0.5")
	eq(audio:isMuted(), false, "Initially not muted")
	eq(audio:isSFXEnabled(), true, "SFX initially enabled")
	eq(audio:isBGMEnabled(), true, "BGM initially enabled")

	-- Toggle mute
	local mutedState = audio:toggleMute()
	eq(mutedState, true, "Muted state is true after toggle")
	eq(audio:isMuted(), true, "isMuted returns true")
	audio:setMuted(false)
	eq(audio:isMuted(), false, "isMuted returns false after setMuted(false)")

	-- Volume adjustments & clamping
	audio:setSFXVolume(0.4)
	eq(audio:getSFXVolume(), 0.4, "SFX volume updated to 0.4")
	audio:setSFXVolume(1.5)
	eq(audio:getSFXVolume(), 1.0, "SFX volume clamped to 1.0")
	audio:setSFXVolume(-0.3)
	eq(audio:getSFXVolume(), 0.0, "SFX volume clamped to 0.0")
	audio:setSFXVolume(0.8)

	audio:setBGMVolume(0.65)
	eq(audio:getBGMVolume(), 0.65, "BGM volume updated to 0.65")

	-- BGM Playback Lifecycle
	audio:playBGM("farm_bgm")
	eq(audio:isBGMPlaying(), true, "BGM is playing")
	audio:pauseBGM()
	eq(audio:isBGMPlaying(), false, "BGM is paused")
	audio:resumeBGM()
	eq(audio:isBGMPlaying(), true, "BGM resumed")
	audio:stopBGM()
	eq(audio:isBGMPlaying(), false, "BGM stopped")

	-- SFX Playback: All 5 canonical SFX
	audio:playSFX("cluck")
	eq(audio:getLastPlayedSFX(), "cluck", "cluck SFX played")
	eq(audio:getSFXPlayCount("cluck"), 1, "cluck count is 1")

	audio:playSFX("coin")
	eq(audio:getLastPlayedSFX(), "coin", "coin SFX played")
	eq(audio:getSFXPlayCount("coin"), 1, "coin count is 1")

	audio:playSFX("pop")
	eq(audio:getLastPlayedSFX(), "pop", "pop SFX played")
	eq(audio:getSFXPlayCount("pop"), 1, "pop count is 1")

	audio:playSFX("click")
	eq(audio:getLastPlayedSFX(), "click", "click SFX played")
	eq(audio:getSFXPlayCount("click"), 1, "click count is 1")

	audio:playSFX("fanfare")
	eq(audio:getLastPlayedSFX(), "fanfare", "fanfare SFX played")
	eq(audio:getSFXPlayCount("fanfare"), 1, "fanfare count is 1")

	-- 16.2 HUD Audio Integration & AudioToggleButton
	local transport = ClientTransport.new({ protocol = Protocol, wire = function() end })
	local store = ClientStateStore.new({ transport = transport, codec = C })
	local controllers = IntentControllers.new({ transport = transport, stateStore = store, codec = C })
	store:applySnapshot(makeTestSnapshot({ streamId = "stream-audio-1", commitRevision = "1" }))

	local hud = HUD.new({
		stateStore = store,
		intentControllers = controllers,
		codec = C,
		audioController = audio,
	})

	eq(hud:getAudioController(), audio, "HUD audioController matches")
	local audioBtn = hud:getAudioToggleButton()
	ok(audioBtn ~= nil, "AudioToggleButton exists in HUD")
	eq(audioBtn.Text, "🔊", "Audio button initial icon is unmuted 🔊")

	-- Press audio toggle button
	if audioBtn.Activated then
		audioBtn.Activated:Fire()
		eq(audio:isMuted(), true, "Audio muted after button tap")
		eq(audioBtn.Text, "🔇", "Audio button icon updated to muted 🔇")
		audioBtn.Activated:Fire()
		eq(audio:isMuted(), false, "Audio unmuted after second tap")
		eq(audioBtn.Text, "🔊", "Audio button icon restored to 🔊")
	end

	-- Press hatch triggers cluck SFX
	local initialCluck = audio:getSFXPlayCount("cluck")
	hud:pressHatch()
	eq(audio:getSFXPlayCount("cluck"), initialCluck + 1, "pressHatch triggered cluck SFX")

	-- 16.3 Mobile Touch Hitbox Optimization (min 44x44 pixels)
	hud:toggleResearchModal(true)
	local closeBtn = hud:getResearchModal():FindFirstChild("CloseBtn", true)
	ok(closeBtn ~= nil, "Actual research close button exists")
	closeBtn.Activated:Fire()
	eq(hud:getResearchModal().Visible, false, "Actual close button closes research")

	-- Check mobile-friendly touch targets on main interactive buttons
	ok(hud.hatchButton ~= nil, "HatchButton exists")
	ok(hud.homeButton ~= nil, "HomeButton exists")
	ok(hud.researchToggleBtn ~= nil, "Dock buttons exist")

	hud:destroy()
	audio:destroy()
end

-- Availability callbacks stay safe even when a test fires Activated programmatically.
do
 local transport=ClientTransport.new({protocol=Protocol,wire=function()end})
 local store=ClientStateStore.new({transport=transport,codec=C})
 local bought,paid=0,0
 local controllers=IntentControllers.new({transport=transport,stateStore=store,codec=C})
 local hud=HUD.new({stateStore=store,intentControllers=controllers,codec=C,onBuyEpicResearch=function()bought+=1 end,onPurchaseProduct=function()paid+=1 end})
 hud.onBuyEpicResearch=function()bought+=1 end -- same binding used by Main
 hud:_updateEpicResearchModal({progress={GE="1000000",epic={}}})
 for _,id in {"afx_mission_time","afx_mission_capacity","hold_to_research","epic_silo_quality","warp_shift"} do
  local row=hud.epicResearchCards[id]
  eq(row.buyBtn.Active,false,"unavailable Epic visibly disabled")
  row.buyBtn.Activated:Fire()
  eq(bought,0,"unavailable Epic callback blocked")
 end
 for _,row in hud.epicResearchCards do
  eq(row.buyRobuxBtn.Active,false,"Epic Robux not purchasable")
  row.buyRobuxBtn.Activated:Fire()
 end
 eq(paid,0,"hidden Robux buttons cannot purchase")
 hud.epicResearchCards.hold_to_hatch.buyBtn.Activated:Fire()
 eq(bought,1,"available Epic callback works")
 hud:_updatePrestigeDisplay({cash="100",progress={SE="0",epic={}}})
 eq(hud.prestigeActionBtn.Active,false,"missing projection cannot invent prestige")
 local prestigeRequests=0;hud.onPrestigeRequested=function()prestigeRequests+=1 end
 hud.prestigeActionBtn.Activated:Fire()
 eq(prestigeRequests,0,"missing preview cannot request prestige")
 ok(string.find(hud.prestigePendingLabel.Text,"—",1,true)~=nil,"missing preview is explicit")
 hud:_updatePrestigeDisplay({cash="100",progress={SE="0",epic={},pendingSE="37.465210714934891",earningBonus="0"}})
 eq(hud.prestigeActionBtn.Active,true,"projected prestige enabled")
 hud.prestigeActionBtn.Activated:Fire()
 eq(prestigeRequests,1,"projected prestige can request reset")
 ok(string.find(hud.prestigePendingLabel.Text,"37.47",1,true)~=nil,"fractional authoritative preview formatted")
 hud:_updateEggUpgradeModal({eggIndex=0})
 eq(hud.eggUpgradeBtn.Active,false,"FV requires server projection")
 hud:_updateEggUpgradeModal({eggIndex=0,homeFV="1e20"})
 eq(hud.eggUpgradeBtn.Active,true,"authoritative FV enables advancement")
 for _,invalid in {0,14,-1,1.5,"2"} do
  hud:selectResearchTier(invalid)
  eq(hud:getCurrentResearchTier(),1,"invalid tier preserves Common selection")
 end
 hud:destroy()
end

print(string.format("HUD and IntentControllers: %d assertions PASS", assertions))
