--!nocheck
-- Full integration smoke test of the HatchTheEgg game loop (IMP-15).
-- Tests ServerBootstrap and ClientBootstrap wired together across 9 sequential game loop phases:
-- 1. Player connect (playerJoined + sendBootstrap -> StateSnapshot -> client in READY state).
-- 2. Hatch press (HatchPress -> Gateway -> Coordinator spawns running chickens -> RoutePresentation animates movement).
-- 3. Passage of time: chicken reaches coop (population increases) -> FarmMath computes egg production -> sale constrained by fleet -> cash deposited into farm.cash and accounting.currentFarmCash.
-- 4. Pricing common research (comfy_nests) via QuoteRequest -> receive QuoteView.
-- 5. Buy research (BuyResearch) -> server deducts cash, increases level to 1 -> next tick of simulation produces more eggs due to upgrade.
-- 6. Quote and buy habitat upgrade (BuyHabitat on "SHACK" in slot 1) -> capacity increases from 250 to 500, existing chickens and reservations preserved.
-- 7. Buy vehicle (BuyVehicle on "TRIKE" in slot 2) -> fleet capacity and shipping rate increase.
-- 8. Checkpoint save and disconnect (playerLeaving).
-- 9. Reconnect player (reconnect with new session generation) -> profile restored from repository with correct research, habitats, vehicles, wallet balance and accounting.currentFarmCash without double crediting and without data loss.

local C = require("../../src/shared/NumericCodec")
local BigAmount = C.BigAmount
local ExactUInt = C.ExactUInt
local Real64 = C.Real64

local ServerBootstrap = require("../../src/server/Bootstrap")
local ClientBootstrap = require("../../src/client/Bootstrap")
local ProfileSchema = require("../../src/server/ProfileSchema").new(C)

local assertions = 0
local function eq(a, b, label)
	assertions += 1
	assert(a == b, (label or "") .. " expected " .. tostring(b) .. " got " .. tostring(a))
end

local function ok(cond, label)
	assertions += 1
	assert(cond, label or "condition failed")
end

local function approxEq(a: number, b: number, eps: number?, label: string?)
	assertions += 1
	local tolerance = eps or 1e-4
	local diff = math.abs(a - b)
	assert(diff <= tolerance, (label or "approxEq") .. " expected " .. tostring(b) .. " got " .. tostring(a) .. " (diff: " .. tostring(diff) .. ")")
end

-- ============================================================================
-- Integration Test Setup
-- ============================================================================
local nowMs = 1000000
local elapsedSec = 0
local mockClock = {
	utcNowMs = function() return nowMs end,
	elapsedNowSeconds = function() return elapsedSec end,
	advance = function(dt)
		elapsedSec += dt
		nowMs += math.floor(dt * 1000 + 0.5)
	end,
	set = function(n, e)
		nowMs = n
		if e ~= nil then elapsedSec = e end
	end,
}

local server = ServerBootstrap.new({
	clock = mockClock,
	initialNowMs = nowMs,
})

-- Fixture with starting funds to enable all purchases in the scenario
local initialFixture = ProfileSchema.createReference("1", nowMs)
initialFixture.farm.cash = "1000"
initialFixture.accounting.currentFarmCash = "1000"
initialFixture.accounting.lastBaseEarnings = "1000"

-- ============================================================================
-- Phase 1: Player Connect & Client Bootstrap
-- ============================================================================
do
	local joinRes, joinErr = server:playerJoined("1", initialFixture)
	ok(joinRes ~= nil, "playerJoined succeeded: " .. tostring(joinErr))
	eq(joinRes.status, "JOINED", "playerJoined status")
	eq(joinRes.playerId, "1", "playerJoined playerId")

	local coord = server:getCoordinator("1")
	ok(coord ~= nil, "Coordinator created for player 1")
	ok(coord.snapshots().ready, "Coordinator is ready")

	local client = ClientBootstrap.new({
		wire = server,
		playerId = "1",
	})
	eq(client:getStatus(), "CONNECTING", "Client initial status is CONNECTING")

	local bootMsg = client:connect("boot-req-1")
	ok(bootMsg ~= nil, "connect returned message")
	eq(client:getStatus(), "READY", "Client status transitioned to READY")
	ok(client:getStore():isReady(), "Client store is ready")
	ok(client:getStore():getStreamId() ~= nil, "Stream ID established")
	eq(client:getStore():getCommitRevision(), "0", "Initial commit revision is 0")

	local farm = client:getFarm()
	ok(farm ~= nil, "Farm view received")
	eq(farm.cash, "1000", "Initial cash is 1000")
	eq(farm.habitats[1].population, "0", "Initial coop 1 population is 0")
	eq(farm.habitats[1].reservedInTransit, "0", "Initial coop 1 reserved in transit is 0")
	eq(farm.habitats[1].capacity, "250", "Initial coop 1 capacity is 250")

	eq(client:getHUD():getSessionStatus(), "READY", "HUD session status is READY")
	eq(client:getHUD():getCashText(), "$1K", "HUD cash formatted as $1K")

	-- Clean up phase 1 client instance
	client:destroy()
end

-- ============================================================================
-- Phase 2: Hatch Click & Chicken Movement
-- ============================================================================
local client = ClientBootstrap.new({
	wire = server,
	playerId = "1",
})
client:connect("boot-req-2")
eq(client:getStatus(), "READY", "Client 2 connected and READY")

do
	eq(client:getPresentation():getActiveGroupCount(), 0, "No visual chickens before hatch press")

	local hatchRes
	local msg, inputSeq = client:hatchPress(function(res)
		hatchRes = res
	end)
	ok(msg ~= nil, "hatchPress returned message")
	eq(inputSeq, "1", "inputSeq is 1")
	ok(hatchRes ~= nil, "hatch response received")
	eq(hatchRes.status, "ACCEPTED", "hatch intent accepted by gateway")

	-- Server state check: running = 1, inTransit = 1, hatcheryStock decremented by 1
	local snapshots = server:getCoordinator("1").snapshots()
	eq(snapshots.working.farm.runningCount, "1", "Server running count is 1")
	eq(snapshots.working.farm.habitats[1].assignedInTransit, "1", "Server assignedInTransit for slot 1 is 1")
	eq(snapshots.working.farm.hatcheryStock, "249", "Hatchery stock decreased by 1 from 250 to 249")

	-- Visual presentation check: RoutePresentation animates group
	eq(client:getPresentation():getActiveGroupCount(), 1, "RoutePresentation has 1 active group")
	local activeGroups = client:getPresentation():getActiveGroups()
	eq(activeGroups[1].targetSlotId, 1, "Active group targets slot 1")
	eq(activeGroups[1].count, 1, "Active group has 1 chicken")

	-- Animate at an intermediate point along the route
	client:update(nowMs + 1000)
	local pos = client:getPresentation():getGroupPosition(activeGroups[1].groupId)
	ok(pos ~= nil, "Group position is computed")
	ok(pos.z < 45, "Chicken moved forward away from hatchery spawn point")
end

-- ============================================================================
-- Phase 3: Passage of Time & Arrival at Coop
-- ============================================================================
do
	-- Advance server time by 4.0 seconds (travel duration for slot 1 is ~3.57s)
	-- Arrival trigger: nowMs >= due, so chicken lands in coop
	server:tick(4.0, nowMs + 4000)

	local sPostArrival = server:getCoordinator("1").snapshots()
	eq(sPostArrival.working.farm.runningCount, "0", "Running count returned to 0 after arrival")
	eq(sPostArrival.working.farm.habitats[1].assignedInTransit, "0", "assignedInTransit returned to 0 after arrival")
	eq(sPostArrival.working.farm.habitats[1].population, "1", "Hab 1 population increased to 1 chicken")

	-- Production simulation check:
	-- 1 hen produces eggs, fleet ships them, cash and accounting.currentFarmCash increased!
	local serverCash = BigAmount.decode(sPostArrival.working.farm.cash)
	local serverRev = BigAmount.decode(sPostArrival.working.accounting.currentFarmCash)
	ok(serverCash > 1000, "Server cash increased from production: " .. tostring(serverCash))
	ok(serverRev > 1000, "Server accounting.currentFarmCash increased: " .. tostring(serverRev))

	-- Client receives delta
	local delta = server:createPlayerDelta("1")
	ok(delta ~= nil, "Server created delta")
	local applyOk = client:receive(delta)
	ok(applyOk, "Client applied delta successfully")

	eq(client:getFarm().habitats[1].population, "1", "Client hab 1 population updated to 1")
	eq(client:getFarm().habitats[1].reservedInTransit, "0", "Client hab 1 reservedInTransit updated to 0")
	ok(BigAmount.decode(client:getFarm().cash) > 1000, "Client cash balance updated")

	-- Update presentation to arrival time: group completed and models cleaned up
	client:update(nowMs)
	eq(client:getPresentation():getActiveGroupCount(), 0, "Visual chicken group completed on arrival")
end

-- ============================================================================
-- Phase 4: Pricing Common Research (comfy_nests) via QuoteRequest
-- ============================================================================
local comfyQuote
do
	local reqTarget = { kind = "BuyResearch", args = { researchId = "comfy_nests", mode = "single" } }
	client:requestQuote(reqTarget, function(q)
		comfyQuote = q
	end)

	ok(comfyQuote ~= nil, "Received QuoteView for comfy_nests")
	eq(comfyQuote.kind, "QuoteView", "Quote kind is QuoteView")
	eq(comfyQuote.target.kind, "BuyResearch", "Quote target kind is BuyResearch")
	eq(comfyQuote.target.args.researchId, "comfy_nests", "Quote researchId is comfy_nests")
	eq(comfyQuote.nextLevel, 1, "Next level is 1")
	eq(comfyQuote.available, true, "comfy_nests is available for purchase")
	ok(comfyQuote.quoteId ~= nil, "Quote has unique quoteId")
	eq(comfyQuote.cashCost, BigAmount.encode(0.50260546768497227), "Cash cost matches catalog price for level 0->1")
end

-- ============================================================================
-- Phase 5: Buy Research (comfy_nests) & Production Step Increase
-- ============================================================================
do
	local buyRes
	client:confirmPurchase(comfyQuote, function(res)
		buyRes = res
	end)

	ok(buyRes ~= nil, "Purchase command result received")
	eq(buyRes.status, "APPLIED", "Purchase applied successfully")
	eq(buyRes.result.actionKind, "BuyResearch", "Action kind is BuyResearch")
	eq(buyRes.result.level, 1, "Level is 1")

	local sPostBuy = server:getCoordinator("1").snapshots()
	eq(sPostBuy.working.farm.common.comfy_nests, 1, "Server farm.common.comfy_nests is 1")
	eq(sPostBuy.working.meta.revision, "1", "Server meta.revision advanced to 1")

	-- Sync delta to client
	local delta = server:createPlayerDelta("1")
	ok(delta ~= nil, "Created delta after research purchase")
	client:receive(delta)
	eq(client:getStore():getCommitRevision(), "1", "Client commitRevision updated to 1")

	-- Measure production with comfy_nests level 1:
	-- Base egg laying rate is 1/30 eggs/s per hen.
	-- comfy_nests level 1 grants eggLayingRateMult = 1.1 (10% more eggs: 1.1 / 30 eggs/s).
	-- In 10 seconds with 1 hen: 10 * (1.1 / 30) eggs * $0.50/egg = ~$0.1833333 cash (vs $0.1666667 without upgrade)
	local cashBefore = BigAmount.decode(sPostBuy.working.farm.cash)
	local revBefore = BigAmount.decode(sPostBuy.working.accounting.currentFarmCash)

	server:tick(10.0, mockClock.utcNowMs() + 10000)

	local sPostTick = server:getCoordinator("1").snapshots()
	local cashAfter = BigAmount.decode(sPostTick.working.farm.cash)
	local revAfter = BigAmount.decode(sPostTick.working.accounting.currentFarmCash)

	local expectedIncome = 10 * (1.1 / 30) * 0.50
	local baseIncome = 10 * (1.0 / 30) * 0.50
	approxEq(revAfter - revBefore, expectedIncome, 1e-4, "Earned production with comfy_nests level 1")
	approxEq(cashAfter - cashBefore, expectedIncome, 1e-4, "Wallet increased by comfy_nests level 1 production")
	ok(revAfter - revBefore > baseIncome, "Production rate is strictly greater than base level 0 rate")

	-- Sync delta to client
	client:receive(server:createPlayerDelta("1"))
end

-- ============================================================================
-- Phase 6: Quote & Buy Habitat Upgrade (BuyHabitat to "SHACK" in slot 1)
-- ============================================================================
do
	local habQuote
	client:requestQuote({ kind = "BuyHabitat", args = { slotId = 1, habitatId = "SHACK" } }, function(q)
		habQuote = q
	end)

	ok(habQuote ~= nil, "Received QuoteView for habitat SHACK")
	eq(habQuote.available, true, "SHACK is available")
	eq(habQuote.resultIndex, 1, "SHACK resultIndex is 1")
	eq(habQuote.cashCost, BigAmount.encode(466.66887875775001), "SHACK price matches catalog (466.67)")

	local habBuyRes
	client:confirmPurchase(habQuote, function(res)
		habBuyRes = res
	end)

	ok(habBuyRes ~= nil, "BuyHabitat response received")
	eq(habBuyRes.status, "APPLIED", "BuyHabitat applied")
	eq(habBuyRes.result.actionKind, "BuyHabitat", "Action kind is BuyHabitat")
	eq(habBuyRes.result.slotId, 1, "SlotId is 1")
	eq(habBuyRes.result.habitatId, "SHACK", "HabitatId is SHACK")

	local sPostHab = server:getCoordinator("1").snapshots()
	eq(sPostHab.working.farm.habitats[1].typeIndex, 1, "Hab 1 typeIndex is now 1 (SHACK)")
	eq(sPostHab.working.farm.habitats[1].population, "1", "Settled chickens preserved across habitat upgrade")
	eq(sPostHab.working.farm.habitats[1].assignedInTransit, "0", "Reservations preserved")
	eq(sPostHab.working.meta.revision, "2", "Server meta.revision advanced to 2")

	-- Sync delta to client
	local delta = server:createPlayerDelta("1")
	client:receive(delta)

	local farm = client:getFarm()
	eq(farm.habitats[1].habitatIndex, 1, "Client hab 1 is SHACK (index 1)")
	eq(farm.habitats[1].capacity, "500", "Capacity rose from 250 to 500")
	eq(farm.habitats[1].population, "1", "Client chickens preserved (population = 1)")
	eq(client:getHUD():getHabitatText(1), "1 / 500", "HUD habitat text updated to 1 / 500")
end

-- ============================================================================
-- Phase 7: Quote & Buy Vehicle (BuyVehicle to "TRIKE" in slot 2)
-- ============================================================================
do
	local vehQuote
	client:requestQuote({ kind = "BuyVehicle", args = { slotId = 2, vehicleId = "TRIKE" } }, function(q)
		vehQuote = q
	end)

	ok(vehQuote ~= nil, "Received QuoteView for vehicle TRIKE")
	eq(vehQuote.available, true, "TRIKE is available for slot 2")
	eq(vehQuote.resultIndex, 0, "TRIKE resultIndex is 0")
	eq(vehQuote.cashCost, BigAmount.encode(22.414486035289428), "Second TRIKE price matches catalog (22.41)")

	local vehBuyRes
	client:confirmPurchase(vehQuote, function(res)
		vehBuyRes = res
	end)

	ok(vehBuyRes ~= nil, "BuyVehicle response received")
	eq(vehBuyRes.status, "APPLIED", "BuyVehicle applied")
	eq(vehBuyRes.result.actionKind, "BuyVehicle", "Action kind is BuyVehicle")
	eq(vehBuyRes.result.slotId, 2, "SlotId is 2")

	local sPostVeh = server:getCoordinator("1").snapshots()
	eq(sPostVeh.working.farm.vehicles[2].typeIndex, 0, "Vehicle slot 2 is TRIKE (typeIndex = 0)")
	eq(sPostVeh.working.meta.revision, "3", "Server meta.revision advanced to 3")

	-- Sync delta to client
	local delta = server:createPlayerDelta("1")
	client:receive(delta)

	local farm = client:getFarm()
	eq(#farm.fleet.vehicles, 2, "Client fleet now has 2 vehicles")
	eq(farm.fleet.vehicles[1].vehicleIndex, 0, "Vehicle 1 is TRIKE")
	eq(farm.fleet.vehicles[2].vehicleIndex, 0, "Vehicle 2 is TRIKE")
	eq(farm.fleet.shippingPerMinute, "10000", "Shipping capacity doubled to 10,000 eggs/min")
end

-- ============================================================================
-- Phase 8: Checkpoint Save & Disconnect (playerLeaving)
-- ============================================================================
local preLeaveCash = server:getCoordinator("1").snapshots().working.farm.cash
local preLeaveRev = server:getCoordinator("1").snapshots().working.accounting.currentFarmCash

do
	local leaveOk, leaveErr = server:playerLeaving("1")
	ok(leaveOk, "playerLeaving succeeded: " .. tostring(leaveErr))
	eq(server:getPlayer("1"), nil, "Player unregistered from server bootstrap")
	eq(server:getCoordinator("1"), nil, "Coordinator cleared from server bootstrap")

	-- Inspect storage record directly
	local storeRec = server.store.records["player:1"]
	ok(storeRec ~= nil, "Storage record exists")
	eq(storeRec.ownership.ownerToken, "", "Owner token cleared on release")
	eq(storeRec.ownership.endsAtMs, 0, "endsAtMs reset to 0 on release")
	eq(storeRec.meta.revision, "4", "meta.revision is 4 after checkpoint commit")
	eq(storeRec.farm.common.comfy_nests, 1, "Persisted comfy_nests is level 1")
	eq(storeRec.farm.habitats[1].typeIndex, 1, "Persisted hab 1 is SHACK (typeIndex = 1)")
	eq(storeRec.farm.habitats[1].population, "1", "Persisted population is 1")
	eq(storeRec.farm.vehicles[2].typeIndex, 0, "Persisted vehicle 2 is TRIKE")
	eq(storeRec.farm.cash, preLeaveCash, "Persisted cash matches pre-leave balance")
	eq(storeRec.accounting.currentFarmCash, preLeaveRev, "Persisted revenue matches pre-leave accumulator")

	client:destroy()
end

-- ============================================================================
-- Phase 9: Reconnect with New Session Generation & State Verification
-- ============================================================================
do
	-- Rejoin player without fixture -> restored from persistence store
	local joinRes, joinErr = server:playerJoined("1")
	ok(joinRes ~= nil, "playerJoined on reconnect succeeded: " .. tostring(joinErr))
	eq(joinRes.status, "JOINED", "playerJoined status is JOINED")

	local storeRec = server.store.records["player:1"]
	ok(storeRec.ownership.ownerToken ~= "", "Owner token claimed by new session")
	eq(storeRec.ownership.generation, "2", "Ownership generation incremented to 2")

	-- New client connects
	local client2 = ClientBootstrap.new({
		wire = server,
		playerId = "1",
	})
	client2:connect("boot-reconnect-1")
	eq(client2:getStatus(), "READY", "Reconnected client is READY")
	eq(client2:getStore():getCommitRevision(), "4", "Client commitRevision restored to 4")

	local f = client2:getFarm()
	eq(f.common[1].researchId, "comfy_nests", "First research is comfy_nests")
	eq(f.common[1].level, 1, "Restored comfy_nests level is 1")
	eq(f.habitats[1].habitatIndex, 1, "Restored hab 1 is SHACK (index 1)")
	eq(f.habitats[1].capacity, "500", "Restored hab 1 capacity is 500")
	eq(f.habitats[1].population, "1", "Restored hab 1 population is 1")
	eq(#f.fleet.vehicles, 2, "Restored fleet has 2 vehicles")
	eq(f.fleet.shippingPerMinute, "10000", "Restored shipping rate is 10,000")
	eq(f.cash, preLeaveCash, "Restored wallet cash matches exactly without data loss")

	local coord2 = server:getCoordinator("1")
	local sRestored = coord2.snapshots()
	eq(sRestored.working.accounting.currentFarmCash, preLeaveRev, "Restored currentFarmCash has zero double counting")

	client2:destroy()
end

print(string.format("Integration game loop smoke test PASS: %d assertions", assertions))
