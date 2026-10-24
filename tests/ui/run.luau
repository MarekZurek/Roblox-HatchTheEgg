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
	eq(hud:getProducedEggsText(), "24.5K/s", "Produced eggs 24.5K/s")
	eq(hud:getSoldEggsText(), "20K/s", "Sold eggs 20K/s")
	eq(hud:getShippingText(), "1.2M/min", "Shipping 1.2M/min")

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
	eq(hud:getProducedEggsText(), "24.5K/s", "Produced eggs preserved")

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

print(string.format("HUD and IntentControllers: %d assertions PASS", assertions))
