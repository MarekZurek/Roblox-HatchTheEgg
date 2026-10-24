--!nocheck
local C = require("../../src/shared/NumericCodec")
local ProtocolSchemas = require("../../src/shared/ProtocolSchemas").new(C)
local Data = require("../../src/server/PersistenceData")
local Schema = require("../../src/server/ProfileSchema").new(C)
local Repo = require("../../src/server/SessionRepository")
local Actor = require("../../src/server/PlayerCoordinator")
local CatalogData = require("../../src/server/CatalogRegistry/Data")
local Catalog = require("../../src/server/CatalogRegistry").new(C, CatalogData, { mode = "INTERNAL_TEST_ONLY" })
local FarmActions = require("../../src/server/FarmActions")
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

local function freshProfile(cashStr, currentFarmCashStr)
	local p = Schema.createReference("player-test", 1000000)
	p.farm.cash = cashStr or "1000000"
	p.accounting.currentFarmCash = currentFarmCashStr or "500000"
	return p
end

-- ============================================================================
-- Section 1: createQuote & ProtocolSchemas validation
-- ============================================================================
do
	local p = freshProfile("1000", "50000")

	-- 1.1 BuyResearch quote (comfy_nests at lvl 0 -> 1)
	local targetResearch = { kind = "BuyResearch", args = { researchId = "comfy_nests", mode = "single" } }
	local quote = FarmActions.createQuote(p, Catalog, targetResearch, "req-1", "0", "q-1", 1000000, "cfg:1")
	ok(quote ~= nil, "Quote created")
	eq(quote.kind, "QuoteView")
	eq(quote.available, true)
	eq(quote.blockedReason, nil)
	eq(quote.nextLevel, 1)
	eq(quote.currency, "cash")
	local pPrice = Catalog.researchPrice("comfy_nests", 0)
	eq(quote.cashCost, C.BigAmount.encode(pPrice))
	local valid, err = ProtocolSchemas.validateServer(quote)
	ok(valid, "QuoteView passes ProtocolSchemas validation: " .. tostring(err))

	-- 1.2 TIER_LOCKED block (hab_capacity1 is tier 1, requires 30 points)
	local targetTier1 = { kind = "BuyResearch", args = { researchId = "hab_capacity1", mode = "single" } }
	local quoteLocked = FarmActions.createQuote(p, Catalog, targetTier1, "req-2", "0", "q-2", 1000000, "cfg:1")
	eq(quoteLocked.available, false)
	eq(quoteLocked.blockedReason, "TIER_LOCKED")
	local validLocked, errLocked = ProtocolSchemas.validateServer(quoteLocked)
	ok(validLocked, "TIER_LOCKED QuoteView valid: " .. tostring(errLocked))

	-- Unlock tier by giving 30 points in comfy_nests
	p.farm.common.comfy_nests = 30
	local quoteUnlocked = FarmActions.createQuote(p, Catalog, targetTier1, "req-3", "0", "q-3", 1000000, "cfg:1")
	eq(quoteUnlocked.available, true)
	eq(quoteUnlocked.blockedReason, nil)
	eq(quoteUnlocked.nextLevel, 1)

	-- 1.3 MAX_LEVEL block
	p.farm.common.better_incubators = 15 -- maxLevel is 15
	local targetMax = { kind = "BuyResearch", args = { researchId = "better_incubators", mode = "single" } }
	local quoteMax = FarmActions.createQuote(p, Catalog, targetMax, "req-4", "0", "q-4", 1000000, "cfg:1")
	eq(quoteMax.available, false)
	eq(quoteMax.blockedReason, "MAX_LEVEL")
	eq(quoteMax.nextLevel, 15)
	eq(quoteMax.cashCost, "0")
	local validMax, errMax = ProtocolSchemas.validateServer(quoteMax)
	ok(validMax, "MAX_LEVEL QuoteView valid: " .. tostring(errMax))

	-- 1.4 INSUFFICIENT_CASH block for research
	local pPoor = freshProfile("0", "0")
	pPoor.farm.common.comfy_nests = 30
	local quotePoor = FarmActions.createQuote(pPoor, Catalog, targetTier1, "req-5", "0", "q-5", 1000000, "cfg:1")
	eq(quotePoor.available, false)
	eq(quotePoor.blockedReason, "INSUFFICIENT_CASH")
	local validPoor, errPoor = ProtocolSchemas.validateServer(quotePoor)
	ok(validPoor, "INSUFFICIENT_CASH QuoteView valid: " .. tostring(errPoor))
end

-- ============================================================================
-- Section 2: Habitat and Vehicle Quotes & Scaling
-- ============================================================================
do
	local p = freshProfile("100000", "50000")

	-- 2.1 Habitat Quote: Slot 1 already has COOP (0). Buying COOP on Slot 1 should be MAX_LEVEL
	local targetHabSame = { kind = "BuyHabitat", args = { slotId = 1, habitatId = "COOP" } }
	local qHabSame = FarmActions.createQuote(p, Catalog, targetHabSame, "req-h1", "0", "qh-1", 1000000, "cfg:1")
	eq(qHabSame.available, false)
	eq(qHabSame.blockedReason, "MAX_LEVEL")
	eq(qHabSame.resultIndex, 0)
	local validH1, errH1 = ProtocolSchemas.validateServer(qHabSame)
	ok(validH1, "Hab MAX_LEVEL QuoteView valid: " .. tostring(errH1))

	-- 2.2 Habitat Quote: Slot 2 is empty (-1). Buying COOP on Slot 2.
	-- Slot 1 has COOP, so sameTypeOwned = 1.
	local targetHabSlot2 = { kind = "BuyHabitat", args = { slotId = 2, habitatId = "COOP" } }
	local qHabSlot2 = FarmActions.createQuote(p, Catalog, targetHabSlot2, "req-h2", "0", "qh-2", 1000000, "cfg:1")
	eq(qHabSlot2.available, true)
	eq(qHabSlot2.resultIndex, 0)
	local expectedPrice = Catalog.habitatPrice(0, 1) -- price for 2nd COOP
	eq(qHabSlot2.cashCost, C.BigAmount.encode(expectedPrice))
	local validH2, errH2 = ProtocolSchemas.validateServer(qHabSlot2)
	ok(validH2, "Hab QuoteView valid: " .. tostring(errH2))

	-- 2.3 Habitat Quote: Slot 1 upgrade from COOP (0) to SHACK (1).
	-- No SHACKs on farm, so sameTypeOwned = 0.
	local targetHabShack = { kind = "BuyHabitat", args = { slotId = 1, habitatId = "SHACK" } }
	local qHabShack = FarmActions.createQuote(p, Catalog, targetHabShack, "req-h3", "0", "qh-3", 1000000, "cfg:1")
	eq(qHabShack.available, true)
	eq(qHabShack.resultIndex, 1)
	local expectedShackPrice = Catalog.habitatPrice(1, 0)
	eq(qHabShack.cashCost, C.BigAmount.encode(expectedShackPrice))
	local validH3, errH3 = ProtocolSchemas.validateServer(qHabShack)
	ok(validH3, "Shack QuoteView valid: " .. tostring(errH3))

	-- 2.4 Habitat INSUFFICIENT_CASH
	local pBroke = freshProfile("0", "0")
	local qHabBroke = FarmActions.createQuote(pBroke, Catalog, targetHabShack, "req-h4", "0", "qh-4", 1000000, "cfg:1")
	eq(qHabBroke.available, false)
	eq(qHabBroke.blockedReason, "INSUFFICIENT_CASH")
	local validH4, errH4 = ProtocolSchemas.validateServer(qHabBroke)
	ok(validH4, "Hab INSUFFICIENT_CASH QuoteView valid: " .. tostring(errH4))

	-- 2.5 Vehicle Quote: Slot 1 already has TRIKE (0). Buying TRIKE on Slot 1 is MAX_LEVEL
	local targetVehSame = { kind = "BuyVehicle", args = { slotId = 1, vehicleId = "TRIKE" } }
	local qVehSame = FarmActions.createQuote(p, Catalog, targetVehSame, "req-v1", "0", "qv-1", 1000000, "cfg:1")
	eq(qVehSame.available, false)
	eq(qVehSame.blockedReason, "MAX_LEVEL")
	eq(qVehSame.resultIndex, 0)
	local validV1, errV1 = ProtocolSchemas.validateServer(qVehSame)
	ok(validV1, "Veh MAX_LEVEL QuoteView valid: " .. tostring(errV1))

	-- 2.6 Vehicle Quote: Slot 2 is empty. Buying TRIKE on Slot 2.
	-- Slot 1 has TRIKE, so sameTypeOwned = 1.
	local targetVehSlot2 = { kind = "BuyVehicle", args = { slotId = 2, vehicleId = "TRIKE" } }
	local qVehSlot2 = FarmActions.createQuote(p, Catalog, targetVehSlot2, "req-v2", "0", "qv-2", 1000000, "cfg:1")
	eq(qVehSlot2.available, true)
	eq(qVehSlot2.resultIndex, 0)
	local expectedTrike2 = Catalog.vehiclePrice(0, 1)
	eq(qVehSlot2.cashCost, C.BigAmount.encode(expectedTrike2))
	local validV2, errV2 = ProtocolSchemas.validateServer(qVehSlot2)
	ok(validV2, "Veh QuoteView valid: " .. tostring(errV2))

	-- 2.7 Vehicle Quote: Slot 1 upgrade to TRANSIT VAN (1).
	-- No TRANSIT VAN owned yet, so sameTypeOwned = 0.
	local targetTransit = { kind = "BuyVehicle", args = { slotId = 1, vehicleId = "TRANSIT VAN" } }
	local qTransit = FarmActions.createQuote(p, Catalog, targetTransit, "req-v3", "0", "qv-3", 1000000, "cfg:1")
	eq(qTransit.available, true)
	eq(qTransit.resultIndex, 1)
	local expectedVanPrice = Catalog.vehiclePrice(1, 0)
	eq(qTransit.cashCost, C.BigAmount.encode(expectedVanPrice))
	local validV3, errV3 = ProtocolSchemas.validateServer(qTransit)
	ok(validV3, "Transit QuoteView valid: " .. tostring(errV3))

	-- 2.8 Vehicle INSUFFICIENT_CASH
	local qVehBroke = FarmActions.createQuote(pBroke, Catalog, targetTransit, "req-v4", "0", "qv-4", 1000000, "cfg:1")
	eq(qVehBroke.available, false)
	eq(qVehBroke.blockedReason, "INSUFFICIENT_CASH")
	local validV4, errV4 = ProtocolSchemas.validateServer(qVehBroke)
	ok(validV4, "Veh INSUFFICIENT_CASH QuoteView valid: " .. tostring(errV4))
end

-- ============================================================================
-- Section 3: Domain Port `apply` (rejections, deductions, invariants)
-- ============================================================================
do
	local actions = FarmActions.new(C, Catalog, { mode = "INTERNAL_TEST_ONLY" })

	-- 3.1 Unsupported kind rejection
	local p = freshProfile("1000", "50000")
	local badOp = { kind = "BuySpaceship", args = {} }
	local badOutcome = actions.apply(p, badOp)
	eq(badOutcome.terminalStatus, "REJECTED")
	eq(badOutcome.result.errorCode, "UNSUPPORTED_OPERATION")

	-- 3.2 TIER_LOCKED rejection
	local opTierLocked = { kind = "BuyResearch", args = { researchId = "hab_capacity1", mode = "single", quoteId = "q" } }
	local outLocked = actions.apply(p, opTierLocked)
	eq(outLocked.terminalStatus, "REJECTED")
	eq(outLocked.result.errorCode, "TIER_LOCKED")
	eq(p.farm.cash, "1000") -- unchanged

	-- 3.3 MAX_LEVEL rejection
	p.farm.common.better_incubators = 15
	local opMax = { kind = "BuyResearch", args = { researchId = "better_incubators", mode = "single", quoteId = "q" } }
	local outMax = actions.apply(p, opMax)
	eq(outMax.terminalStatus, "REJECTED")
	eq(outMax.result.errorCode, "MAX_LEVEL")
	eq(p.farm.cash, "1000")

	-- 3.4 INSUFFICIENT_CASH rejection
	local pZero = freshProfile("0", "50000")
	local opComfy = { kind = "BuyResearch", args = { researchId = "comfy_nests", mode = "single", quoteId = "q" } }
	local outBroke = actions.apply(pZero, opComfy)
	eq(outBroke.terminalStatus, "REJECTED")
	eq(outBroke.result.errorCode, "INSUFFICIENT_CASH")
	eq(pZero.farm.cash, "0")
	eq(pZero.accounting.currentFarmCash, "50000")

	-- 3.5 Successful BuyResearch purchase
	local pRich = freshProfile("1000", "50000")
	local priceComfy = Catalog.researchPrice("comfy_nests", 0)
	local outBuyRes = actions.apply(pRich, opComfy)
	eq(outBuyRes.terminalStatus, "APPLIED")
	eq(outBuyRes.result.terminalStatus, "APPLIED")
	eq(outBuyRes.result.actionKind, "BuyResearch")
	eq(outBuyRes.result.researchId, "comfy_nests")
	eq(outBuyRes.result.level, 1)
	eq(pRich.farm.common.comfy_nests, 1)
	local expectedRemaining = C.BigAmount.subtract(1000, priceComfy)
	eq(pRich.farm.cash, C.BigAmount.encode(expectedRemaining))
	-- CRITICAL INVARIANT: currentFarmCash NOT decreased!
	eq(pRich.accounting.currentFarmCash, "50000")

	-- Validator passes on fresh profile before mutation with sufficient funds
	local pPre = freshProfile("1000", "50000")
	ok(outBuyRes.validate(pPre, 1000000) == true, "Validator passes on valid state")
	-- Validator fails with QUOTE_CHANGED if research level changed on fresh profile
	local pChanged = freshProfile("1000", "50000")
	pChanged.farm.common.comfy_nests = 1
	local vPass2, vCode2 = outBuyRes.validate(pChanged, 1000000)
	eq(vPass2, false)
	eq(vCode2, "QUOTE_CHANGED")
	-- Validator fails with INSUFFICIENT_CASH if fresh profile cash is too low
	local pEmpty = freshProfile("0", "50000")
	local vPass, vCode = outBuyRes.validate(pEmpty, 1000000)
	eq(vPass, false)
	eq(vCode, "INSUFFICIENT_CASH")

	-- 3.6 Successful BuyHabitat purchase with POPULATION PRESERVATION
	local pHab = freshProfile("10000", "75000")
	-- Seed Slot 1 with 150 hens, 25 in transit, fractionalIHR 0.5
	pHab.farm.habitats[1].population = "150"
	pHab.farm.habitats[1].assignedInTransit = "25"
	pHab.farm.habitats[1].fractionalIHR = "0.5"
	pHab.farm.runningCount = "25"

	local shackPrice0 = Catalog.habitatPrice(1, 0)
	local opShack = { kind = "BuyHabitat", args = { slotId = 1, habitatId = "SHACK", quoteId = "q-shack" } }
	local outShack = actions.apply(pHab, opShack)
	eq(outShack.terminalStatus, "APPLIED")
	eq(outShack.result.actionKind, "BuyHabitat")
	eq(outShack.result.slotId, 1)
	eq(outShack.result.habitatId, "SHACK")
	eq(pHab.farm.habitats[1].typeIndex, 1) -- upgraded to SHACK
	-- POPULATION PRESERVED:
	eq(pHab.farm.habitats[1].population, "150", "Population preserved on replacement")
	eq(pHab.farm.habitats[1].assignedInTransit, "25", "In-transit preserved on replacement")
	eq(pHab.farm.habitats[1].fractionalIHR, "0.5", "Fractional IHR preserved on replacement")
	-- Cash deducted correctly
	local habRemaining = C.BigAmount.subtract(10000, shackPrice0)
	eq(pHab.farm.cash, C.BigAmount.encode(habRemaining))
	-- CRITICAL INVARIANT: currentFarmCash NOT decreased!
	eq(pHab.accounting.currentFarmCash, "75000")

	-- 3.7 Habitat price scaling across slots (sameTypeOwned)
	local pScale = freshProfile("1000000", "50000")
	-- Initially: Slot 1 has COOP (0), slots 2, 3, 4 are -1.
	-- Buy COOP on Slot 2: sameTypeOwned is 1
	local coopPrice1 = Catalog.habitatPrice(0, 1)
	local cashBefore = C.BigAmount.decode(pScale.farm.cash)
	local outH2 = actions.apply(pScale, { kind = "BuyHabitat", args = { slotId = 2, habitatId = "COOP", quoteId = "q-c2" } })
	eq(outH2.terminalStatus, "APPLIED")
	eq(pScale.farm.habitats[2].typeIndex, 0)
	eq(pScale.farm.cash, C.BigAmount.encode(C.BigAmount.subtract(cashBefore, coopPrice1)))

	-- Buy COOP on Slot 3: sameTypeOwned is now 2
	local coopPrice2 = Catalog.habitatPrice(0, 2)
	cashBefore = C.BigAmount.decode(pScale.farm.cash)
	local outH3 = actions.apply(pScale, { kind = "BuyHabitat", args = { slotId = 3, habitatId = "COOP", quoteId = "q-c3" } })
	eq(outH3.terminalStatus, "APPLIED")
	eq(pScale.farm.habitats[3].typeIndex, 0)
	eq(pScale.farm.cash, C.BigAmount.encode(C.BigAmount.subtract(cashBefore, coopPrice2)))

	-- Buy COOP on Slot 4: sameTypeOwned is now 3
	local coopPrice3 = Catalog.habitatPrice(0, 3)
	cashBefore = C.BigAmount.decode(pScale.farm.cash)
	local outH4 = actions.apply(pScale, { kind = "BuyHabitat", args = { slotId = 4, habitatId = "COOP", quoteId = "q-c4" } })
	eq(outH4.terminalStatus, "APPLIED")
	eq(pScale.farm.habitats[4].typeIndex, 0)
	eq(pScale.farm.cash, C.BigAmount.encode(C.BigAmount.subtract(cashBefore, coopPrice3)))

	-- All 4 slots now have COOP. Trying to buy another COOP must fail with MAX_LEVEL
	local outH5 = actions.apply(pScale, { kind = "BuyHabitat", args = { slotId = 1, habitatId = "COOP", quoteId = "q-c5" } })
	eq(outH5.terminalStatus, "REJECTED")
	eq(outH5.result.errorCode, "MAX_LEVEL")

	-- 3.8 Successful BuyVehicle purchase and scaling
	local pVeh = freshProfile("1000000", "50000")
	-- Initially: 1 TRIKE at slot 1. sameTypeOwned = 1.
	-- Buy TRIKE on slot 2: price is catalog.vehiclePrice(0, 1)
	local trikePrice1 = Catalog.vehiclePrice(0, 1)
	cashBefore = C.BigAmount.decode(pVeh.farm.cash)
	local outV2 = actions.apply(pVeh, { kind = "BuyVehicle", args = { slotId = 2, vehicleId = "TRIKE", quoteId = "qv-2" } })
	eq(outV2.terminalStatus, "APPLIED")
	eq(outV2.result.actionKind, "BuyVehicle")
	eq(outV2.result.slotId, 2)
	eq(outV2.result.vehicleId, "TRIKE")
	eq(pVeh.farm.vehicles[2].typeIndex, 0)
	eq(pVeh.farm.cash, C.BigAmount.encode(C.BigAmount.subtract(cashBefore, trikePrice1)))
	eq(pVeh.accounting.currentFarmCash, "50000")

	-- Buy TRANSIT VAN on slot 1: upgrade from TRIKE to TRANSIT VAN. sameTypeOwned for TRANSIT VAN = 0.
	local vanPrice0 = Catalog.vehiclePrice(1, 0)
	cashBefore = C.BigAmount.decode(pVeh.farm.cash)
	local outV1 = actions.apply(pVeh, { kind = "BuyVehicle", args = { slotId = 1, vehicleId = "TRANSIT VAN", quoteId = "qv-1" } })
	eq(outV1.terminalStatus, "APPLIED")
	eq(pVeh.farm.vehicles[1].typeIndex, 1)
	eq(pVeh.farm.cash, C.BigAmount.encode(C.BigAmount.subtract(cashBefore, vanPrice0)))
	eq(pVeh.accounting.currentFarmCash, "50000")
end

-- ============================================================================
-- Section 4: Integration with PlayerCoordinator (atomic commit, replay, error)
-- ============================================================================
local function createCoordinatorHarness()
	local t = { records = {}, now = 1000000, elapsed = 0, serial = 0, updates = 0, reads = 0 }
	local store = {}
	function store.read(key)
		t.reads += 1
		return true, if t.records[key] then Data.copy(t.records[key]) else nil
	end
	function store.update(key, callback)
		t.updates += 1
		local nextProfile = callback(if t.records[key] then Data.copy(t.records[key]) else nil)
		if nextProfile then t.records[key] = Data.copy(nextProfile) end
		return true, if nextProfile then Data.copy(nextProfile) else nil
	end
	t.repo = Repo.new({
		mode = "INTERNAL_TEST_ONLY",
		codec = C,
		data = Data,
		schema = Schema,
		store = store,
		clock = {
			utcNowMs = function() return t.now end,
			elapsedNowSeconds = function() return t.elapsed end,
		},
		encodeJson = function(v) return serde.encode("json", v) end,
		tokenFactory = function() t.serial += 1; return "token-" .. t.serial end,
	})
	local acquired = t.repo.acquire("1")
	eq(acquired.status, "ACQUIRED")
	t.handle = acquired.handle

	-- Seed initial funds & population on player:1
	t.handle.snapshot.farm.cash = C.BigAmount.encode(500000)
	t.handle.snapshot.accounting.currentFarmCash = C.BigAmount.encode(123456)
	t.handle.snapshot.farm.habitats[1].population = "100"
	t.records["player:1"] = Data.copy(t.handle.snapshot)

	local simulation = {
		advance = function(profile, request)
			return { profile = profile, complete = true }
		end,
	}

	t.actions = FarmActions.new(C, Catalog, { mode = "INTERNAL_TEST_ONLY" })
	t.actor = Actor.new({
		mode = "INTERNAL_TEST_ONLY",
		codec = C,
		data = Data,
		repository = t.repo,
		handle = t.handle,
		clock = {
			utcNowMs = function() return t.now end,
			elapsedNowSeconds = function() return t.elapsed end,
		},
		simulation = simulation,
		domain = t.actions,
		maxQueue = 8,
	})
	function t.ready() eq(t.actor.setReady(true).status, "READY_SET") end
	function t.drain() return t.actor.drain() end
	return t
end

do
	local h = createCoordinatorHarness()
	h.ready()
	local actor = h.actor

	-- 4.1 Submit BuyResearch command
	local opResearch = {
		protocolVersion = 1,
		requestId = "req-c1",
		kind = "BuyResearch",
		operationId = "op-research-1",
		expectedRevision = "0",
		args = { researchId = "comfy_nests", mode = "single", quoteId = "q-res-1" },
	}

	local submitRes = actor.submit(opResearch)
	eq(submitRes.status, "PENDING")
	local drainRes = h.drain()
	eq(drainRes.status, "DRAINED")
	eq(#drainRes.results, 1)
	local r1 = drainRes.results[1]
	eq(r1.status, "APPLIED")
	eq(r1.result.terminalStatus, "APPLIED")
	eq(r1.result.actionKind, "BuyResearch")
	eq(r1.result.researchId, "comfy_nests")
	eq(r1.result.level, 1)
	eq(r1.resultRevision, "1")

	-- Check durable store in repository
	local record = h.records["player:1"]
	eq(record.farm.common.comfy_nests, 1)
	eq(record.meta.revision, "1")
	local priceComfy = Catalog.researchPrice("comfy_nests", 0)
	local expectedCash = C.BigAmount.subtract(500000, priceComfy)
	eq(record.farm.cash, C.BigAmount.encode(expectedCash))
	-- CRITICAL INVARIANT: currentFarmCash NOT decreased!
	eq(record.accounting.currentFarmCash, C.BigAmount.encode(123456))

	-- 4.2 Replay of same operationId
	local replayRes = actor.submit(opResearch)
	eq(replayRes.status, "REPLAYED")
	eq(replayRes.resultRevision, "1")
	eq(replayRes.result.actionKind, "BuyResearch")
	-- Cash did not get deducted again
	eq(h.records["player:1"].farm.cash, C.BigAmount.encode(expectedCash))

	-- 4.3 Conflict detection: same operationId with different arguments
	local conflictOp = {
		protocolVersion = 1,
		requestId = "req-c1-diff",
		kind = "BuyResearch",
		operationId = "op-research-1",
		expectedRevision = "1",
		args = { researchId = "nutritional_sup", mode = "single", quoteId = "q-diff" },
	}
	local conflictRes = actor.submit(conflictOp)
	eq(conflictRes.status, "REJECTED")
	eq(conflictRes.errorCode, "OPERATION_ID_CONFLICT")

	-- 4.4 Stale revision rejection
	local staleOp = {
		protocolVersion = 1,
		requestId = "req-c2",
		kind = "BuyHabitat",
		operationId = "op-hab-stale",
		expectedRevision = "0", -- current is "1"
		args = { slotId = 1, habitatId = "SHACK", quoteId = "q-hab-1" },
	}
	eq(actor.submit(staleOp).status, "PENDING")
	local drainStale = h.drain()
	eq(drainStale.results[1].errorCode, "STALE_REVISION")
	eq(h.records["player:1"].meta.revision, "2") -- SessionRepository records stale revision attempt with revision bump

	-- 4.5 BuyHabitat with current revision "2": replaces COOP with SHACK, preserving population 100
	local opHab = {
		protocolVersion = 1,
		requestId = "req-c3",
		kind = "BuyHabitat",
		operationId = "op-hab-ok",
		expectedRevision = "2",
		args = { slotId = 1, habitatId = "SHACK", quoteId = "q-hab-2" },
	}
	eq(actor.submit(opHab).status, "PENDING")
	local drainHab = h.drain()
	eq(drainHab.results[1].status, "APPLIED")
	eq(drainHab.results[1].result.actionKind, "BuyHabitat")
	eq(drainHab.results[1].resultRevision, "3")

	local durableHab = h.records["player:1"]
	eq(durableHab.farm.habitats[1].typeIndex, 1)
	eq(durableHab.farm.habitats[1].population, "100", "Population 100 preserved in durable commit")
	eq(durableHab.accounting.currentFarmCash, C.BigAmount.encode(123456), "currentFarmCash invariant preserved")

	-- 4.6 Insufficient cash rejection inside coordinator
	-- Drain the player's cash to 0
	h.records["player:1"].farm.cash = "0"
	h.handle.snapshot.farm.cash = "0"
	local actorSnapshots = actor.snapshots()
	if actorSnapshots.working then
		actorSnapshots.working.farm.cash = "0"
	end

	local opBroke = {
		protocolVersion = 1,
		requestId = "req-c4",
		kind = "BuyVehicle",
		operationId = "op-veh-broke",
		expectedRevision = "3",
		args = { slotId = 2, vehicleId = "TRIKE", quoteId = "q-v-broke" },
	}
	eq(actor.submit(opBroke).status, "PENDING")
	local drainBroke = h.drain()
	eq(drainBroke.results[1].status, "REJECTED")
	eq(drainBroke.results[1].errorCode, "INSUFFICIENT_CASH")
	eq(drainBroke.results[1].result.errorCode, "INSUFFICIENT_CASH")
	eq(drainBroke.results[1].resultRevision, "4")

	-- Replaying the rejected operation returns REPLAYED with terminalStatus REJECTED
	local replayBroke = actor.submit(opBroke)
	eq(replayBroke.status, "REPLAYED")
	eq(replayBroke.terminalStatus, "REJECTED")
	eq(replayBroke.result.errorCode, "INSUFFICIENT_CASH")

	-- 4.7 Full schema validation on final durable state
	local validDurable, durableErr = Schema.validate(h.records["player:1"], "1")
	ok(validDurable, "Final durable state passes ProfileSchema: " .. tostring(durableErr))
end

-- Save test report
fs.writeFile("build/purchases-results.json", serde.encode("json", {
	status = "PASS",
	assertions = assertions,
	suite = "purchases",
	module = "FarmActions",
	runtime = "Lune",
	studioTested = false,
	datastoreTested = false,
}, true))

print("purchases: " .. assertions .. " assertions PASS")
