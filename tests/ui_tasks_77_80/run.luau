--!nocheck
-- Regression suite for GitHub #77-#80 (HatchTheEgg UI/world task batch).
-- Scope:
-- #77 Persistent compact hatch status beside the hatchery/stock HUD, derived from the authoritative
--     farm view: capacity is full when NO built coop has vacancy after population + reservedInTransit
--     (one full coop plus one vacant coop is not blocked). A separate low-stock message exists (the
--     stock is a BigAmount binary64 decimal, so anything below one whole egg blocks, including 0.5)
--     and capacity keeps priority when both are true. Counts stay exact uint64 (also above 2^53), the
--     status is idempotent, sends no packet and plays no sound.
-- #78 Every user-visible habitat type name is "Tier 1".."Tier 19" (index 0 => Tier 1) in the parcel
--     cards (current/next) and in the world labels/pad offers; empty slots stay empty, never Tier 0.
-- #79 The same for all 12 vehicle types in the fleet panel; the tier is the type, never the slot, and
--     empty slots keep their slotId identity and gaps.
-- #80 No vehicle step-on buy pads remain in the world generator; habitat pads still work, the depot,
--     parking and 2+1 offer delivery stay, and the fleet panel buy path stays available.
local C = require("../../src/shared/NumericCodec")
local Schemas = require("../../src/shared/ProtocolSchemas")
local Protocol = Schemas.new(C)

local ClientTransport = require("../../src/client/ClientTransport")
local ClientStateStore = require("../../src/client/ClientStateStore")
local IntentControllers = require("../../src/client/IntentControllers")
local HUD = require("../../src/client/HUD")

local CatalogData = require("../../src/server/CatalogRegistry/Data")
local Catalog = require("../../src/server/CatalogRegistry").new(C, CatalogData, { mode = "INTERNAL_TEST_ONLY" })
local FarmPlotBuilder = require("../../src/server/world/FarmPlotBuilder")

local fs, serde = require("@lune/fs"), require("@lune/serde")

local assertions = 0
local function eq(a, b, label)
	assertions += 1
	assert(a == b, (label or "") .. " expected " .. tostring(b) .. " got " .. tostring(a))
end
local function ok(cond, label)
	assertions += 1
	assert(cond, label or "condition failed")
end
local function contains(text, needle, label)
	assertions += 1
	assert(type(text) == "string" and string.find(text, needle, 1, true) ~= nil,
		(label or "") .. " expected to contain '" .. needle .. "' in '" .. tostring(text) .. "'")
end
local function missing(text, needle, label)
	assertions += 1
	assert(type(text) == "string" and string.find(text, needle, 1, true) == nil,
		(label or "") .. " must not contain '" .. needle .. "'")
end

-- Client harness: real transport/store/controllers, presentation-only HUD, counting audio stub.
local function newHarness(extraDeps)
	local outgoing = {}
	local transport = ClientTransport.new({ protocol = Protocol, wire = function(msg) table.insert(outgoing, msg) end })
	local store = ClientStateStore.new({ transport = transport, codec = C })
	local controllers = IntentControllers.new({ transport = transport, stateStore = store, codec = C })
	local sounds = 0
	local audio = {
		playSFX = function() sounds += 1 end,
		isMuted = function() return false end,
		toggleMute = function() return false end,
	}
	local deps = {
		stateStore = store,
		intentControllers = controllers,
		codec = C,
		audioController = audio,
	}
	for key, value in (extraDeps or {}) do deps[key] = value end
	local hud = HUD.new(deps)
	return { hud = hud, store = store, outgoing = outgoing, sounds = function() return sounds end }
end

-- Own-farm snapshot shaped like the real ViewProjector output. A slot without habitatIndex is an
-- empty parcel (exactly like the server view, which omits habitatIndex for unbuilt slots).
local function makeSnapshot(spec)
	local habitats = {}
	for slot = 1, 4 do
		local source = (spec.habitats and spec.habitats[slot]) or {}
		local entry = {
			slotId = slot,
			population = source.population or "0",
			reservedInTransit = source.reservedInTransit or "0",
			capacity = source.capacity or "250",
		}
		if source.habitatIndex ~= nil then entry.habitatIndex = source.habitatIndex end
		if source.nextHabitatId ~= nil then entry.nextHabitatId = source.nextHabitatId end
		if source.upgradePrice ~= nil then entry.upgradePrice = source.upgradePrice end
		habitats[slot] = entry
	end
	return {
		protocolVersion = 1, numericCodecVersion = 1, viewSchemaVersion = 1,
		configRevision = "cfg:1", calculationVersion = 1,
		streamId = spec.streamId or "stream-77-80",
		commitRevision = spec.commitRevision or "1",
		viewSeq = spec.viewSeq or "1",
		serverObservedAt = spec.serverObservedAt or 1000000,
		kind = "StateSnapshot",
		requestId = spec.requestId or "boot-77-80",
		view = {
			audience = "own",
			farm = {
				lifecycle = spec.lifecycle or "ready",
				eggIndex = 0,
				cash = spec.cash or "1000",
				habitats = habitats,
				hatchery = {
					stock = (spec.hatchery and spec.hatchery.stock) or "250",
					capacity = (spec.hatchery and spec.hatchery.capacity) or "500",
					refillPerSecond = (spec.hatchery and spec.hatchery.refillPerSecond) or "3",
				},
				fleet = spec.fleet or {
					vehicles = { { slotId = 1, vehicleIndex = 0 } },
					shippingPerMinute = "6000",
					slotLimit = 4,
					upgrades = {},
				},
				producedEggsPerSecond = "0",
				soldEggsPerSecond = "0",
				cashIncomePerSecond = "0",
				common = spec.common or {},
			},
		},
	}
end

-- ============================================================================
-- Section 1: #77 persistent hatch status (blocked capacity, reservations, empty stock)
-- ============================================================================
do
	local h = newHarness()
	local hud = h.hud

	-- 1.1 No view yet: nothing is claimed.
	eq(hud:getHatchStatusVisible(), false, "no view: status hidden")
	eq(hud:getHatchStatusReason(), nil, "no view: no blocked reason")

	-- 1.2 A built coop with vacancy: normal, message hidden.
	local snapVacancy = makeSnapshot({
		streamId = "stream-77-vacancy",
		hatchery = { stock = "250" },
		habitats = {
			{ habitatIndex = 0, population = "10", reservedInTransit = "0", capacity = "250" },
			{}, {}, {},
		},
	})
	ok(Protocol.validateServer(snapVacancy), "vacancy snapshot is valid under ProtocolSchemas")
	h.store:applySnapshot(snapVacancy)
	eq(hud:getHatchStatusReason(), nil, "vacancy: no blocked reason")
	eq(hud:getHatchStatusVisible(), false, "vacancy: status hidden")
	eq(hud:getHatchStatusText(), "", "vacancy: no message text")

	-- 1.3 Every built coop full after population + reservedInTransit: capacity is the blocker.
	local snapFull = makeSnapshot({
		streamId = "stream-77-full",
		commitRevision = "2",
		hatchery = { stock = "120" },
		habitats = {
			{ habitatIndex = 0, population = "250", reservedInTransit = "0", capacity = "250", nextHabitatId = "SHACK", upgradePrice = "500" },
			{ habitatIndex = 1, population = "400", reservedInTransit = "100", capacity = "500" },
			{ habitatIndex = 2, population = "0", reservedInTransit = "1000", capacity = "1000" },
			{},
		},
	})
	ok(Protocol.validateServer(snapFull), "full snapshot is valid under ProtocolSchemas")
	h.store:applySnapshot(snapFull)
	eq(hud:getHatchStatusReason(), "CAPACITY_FULL", "full: reason is CAPACITY_FULL")
	eq(hud:getHatchStatusVisible(), true, "full: status visible")
	eq(hud:getHatchStatusText(), "Brak miejsca w kurnikach", "full: main message only, no appended hint")
	eq(hud:getHatchStatusActionVisible(), true, "full: Kurniki action available")

	-- The action opens the existing habitat panel; it is not a new remote or a new purchase path.
	local action = hud:getHatchStatusActionButton()
	ok(action ~= nil, "full: action button instance exists")
	eq(action.Text, "Kurniki", "full: action label is Kurniki")
	action.Activated:Fire()
	eq(hud:getHabitatsModal().Visible, true, "full: action opens the existing habitats panel")
	hud:toggleHabitatsModal(false)
	eq(hud:getHabitatsModal().Visible, false, "full: habitats panel closes again")


	-- 1.4 One full coop with another coop still vacant is NOT blocked.
	local snapMixed = makeSnapshot({
		streamId = "stream-77-mixed",
		hatchery = { stock = "120" },
		habitats = {
			{ habitatIndex = 0, population = "250", reservedInTransit = "0", capacity = "250" },
			{ habitatIndex = 1, population = "100", reservedInTransit = "0", capacity = "500" },
			{ habitatIndex = 2, population = "1000", reservedInTransit = "0", capacity = "1000" },
			{},
		},
	})
	h.store:applySnapshot(snapMixed)
	eq(hud:getHatchStatusReason(), nil, "mixed: one vacant coop clears the block")
	eq(hud:getHatchStatusVisible(), false, "mixed: status hidden")

	-- 1.5 A vacancy can come from reservations alone (population 0, chickens still in transit).
	local snapReservedVacant = makeSnapshot({
		streamId = "stream-77-reserved-vacant",
		hatchery = { stock = "120" },
		habitats = {
			{ habitatIndex = 0, population = "250", reservedInTransit = "0", capacity = "250" },
			{ habitatIndex = 1, population = "0", reservedInTransit = "499", capacity = "500" },
			{ habitatIndex = 2, population = "10", reservedInTransit = "0", capacity = "10" },
			{},
		},
	})
	h.store:applySnapshot(snapReservedVacant)
	eq(hud:getHatchStatusReason(), nil, "reservations below capacity leave one vacancy")

	local snapReservedFull = makeSnapshot({
		streamId = "stream-77-reserved-full",
		hatchery = { stock = "120" },
		habitats = {
			{ habitatIndex = 0, population = "250", reservedInTransit = "0", capacity = "250" },
			{ habitatIndex = 1, population = "0", reservedInTransit = "500", capacity = "500" },
			{ habitatIndex = 2, population = "10", reservedInTransit = "0", capacity = "10" },
			{},
		},
	})
	h.store:applySnapshot(snapReservedFull)
	eq(hud:getHatchStatusReason(), "CAPACITY_FULL", "reservations filling capacity block hatching")
	eq(hud:getHatchStatusVisible(), true, "reservations: status visible")

	-- 1.6 Stock below one whole egg with free capacity: a separate message, no Kurniki action.
	-- The stock is a BigAmount binary64 decimal, so 0.5 is already blocked; the old ExactUInt == 0
	-- helper wrongly reported it as non-empty.
	for _, case in ipairs({ { stock = "0" }, { stock = "0.5" } }) do
		local snapStock = makeSnapshot({
			streamId = "stream-77-stock-" .. case.stock,
			hatchery = { stock = case.stock },
			habitats = {
				{ habitatIndex = 0, population = "0", reservedInTransit = "0", capacity = "250" },
				{}, {}, {},
			},
		})
		h.store:applySnapshot(snapStock)
		eq(hud:getHatchStatusReason(), "NO_STOCK", "stock " .. case.stock .. ": reason is NO_STOCK")
		eq(hud:getHatchStatusVisible(), true, "stock " .. case.stock .. ": status visible")
		contains(hud:getHatchStatusText(), "Brak jaj do wylęgu", "stock " .. case.stock .. ": base message")
		contains(hud:getHatchStatusText(), "zapas się odnawia", "stock " .. case.stock .. ": refill note")
		eq(hud:getHatchStatusActionVisible(), false, "stock " .. case.stock .. ": no Kurniki action")
	end

	-- 1.6b Exactly one whole egg is enough to hatch: the boundary is stock >= 1, not stock > 0.
	local snapOneEgg = makeSnapshot({
		streamId = "stream-77-stock-one",
		hatchery = { stock = "1" },
		habitats = {
			{ habitatIndex = 0, population = "0", reservedInTransit = "0", capacity = "250" },
			{}, {}, {},
		},
	})
	h.store:applySnapshot(snapOneEgg)
	eq(hud:getHatchStatusReason(), nil, "exactly one egg: hatching is not blocked")
	eq(hud:getHatchStatusVisible(), false, "exactly one egg: status hidden")

	-- 1.7 Capacity full has priority when both conditions are true.
	local snapBoth = makeSnapshot({
		streamId = "stream-77-both",
		hatchery = { stock = "0" },
		habitats = {
			{ habitatIndex = 0, population = "250", reservedInTransit = "0", capacity = "250" },
			{ habitatIndex = 1, population = "500", reservedInTransit = "0", capacity = "500" },
			{}, {},
		},
	})
	h.store:applySnapshot(snapBoth)
	eq(hud:getHatchStatusReason(), "CAPACITY_FULL", "both blocked: capacity wins")
	contains(hud:getHatchStatusText(), "Brak miejsca w kurnikach", "both blocked: capacity message")
	missing(hud:getHatchStatusText(), "Brak jaj do wylęgu", "both blocked: stock message suppressed")


	-- 1.8 Restoring capacity through a delta clears the message (whole-section replacement).
	local delta = {
		protocolVersion = 1, numericCodecVersion = 1, viewSchemaVersion = 1,
		configRevision = "cfg:1", calculationVersion = 1,
		streamId = "stream-77-both", commitRevision = "3",
		viewSeq = "2", baseViewSeq = "1", serverObservedAt = 1000100,
		kind = "StateDelta",
		changes = {
			audience = "own",
			farm = {
				hatchery = { stock = "40", capacity = "500", refillPerSecond = "3" },
				habitats = {
					{ slotId = 1, habitatIndex = 0, population = "0", reservedInTransit = "0", capacity = "250" },
					{ slotId = 2, habitatIndex = 1, population = "500", reservedInTransit = "0", capacity = "500" },
					{ slotId = 3, population = "0", reservedInTransit = "0", capacity = "250" },
					{ slotId = 4, population = "0", reservedInTransit = "0", capacity = "250" },
				},
			},
		},
	}
	ok(Protocol.validateServer(delta), "capacity-restoring delta is valid under ProtocolSchemas")
	h.store:applyDelta(delta)
	eq(hud:getHatchStatusReason(), nil, "restored capacity clears the blocked reason")
	eq(hud:getHatchStatusVisible(), false, "restored capacity hides the status")

	-- 1.9 A reset/refreshed view (new stream) and an unready session never claim a block.
	local snapReset = makeSnapshot({
		streamId = "stream-77-reset",
		commitRevision = "9",
		hatchery = { stock = "250" },
		habitats = {
			{ habitatIndex = 0, population = "0", reservedInTransit = "0", capacity = "250" },
			{ habitatIndex = 0, population = "0", reservedInTransit = "0", capacity = "250" },
			{}, {},
		},
	})
	h.store:applySnapshot(snapReset)
	eq(hud:getHatchStatusReason(), nil, "state reset with vacancy stays clear")
	eq(hud:getHatchStatusVisible(), false, "state reset hides the status")

	local snapUnready = makeSnapshot({
		streamId = "stream-77-unready",
		lifecycle = "loading",
		hatchery = { stock = "0" },
		habitats = {
			{ habitatIndex = 0, population = "250", reservedInTransit = "0", capacity = "250" },
			{}, {}, {},
		},
	})
	h.store:applySnapshot(snapUnready)
	eq(hud:getHatchStatusVisible(), false, "unready farm view hides the status")
	eq(hud:getHatchStatusReason(), nil, "unready farm view claims nothing")

	local snapLost = makeSnapshot({
		streamId = "stream-77-lost",
		lifecycle = "sessionLost",
		hatchery = { stock = "0" },
		habitats = {
			{ habitatIndex = 0, population = "250", reservedInTransit = "0", capacity = "250" },
			{}, {}, {},
		},
	})
	h.store:applySnapshot(snapLost)
	eq(hud:getSessionStatus(), "SESSION_LOST", "session lost status mirrored")
	eq(hud:getHatchStatusVisible(), false, "session lost hides the status")


	-- 1.10 Counts above 2^53 stay exact: population 2^53 + reservation 1 fills capacity 2^53 + 1,
	-- while a lossy tonumber comparison would still see a vacancy.
	local exactCapacity = "9007199254740993"
	local exactPopulation = "9007199254740992"
	local snapExactFull = makeSnapshot({
		streamId = "stream-77-exact-full",
		hatchery = { stock = "5" },
		habitats = {
			{ habitatIndex = 18, population = exactPopulation, reservedInTransit = "1", capacity = exactCapacity },
			{}, {}, {},
		},
	})
	h.store:applySnapshot(snapExactFull)
	eq(hud:getHatchStatusReason(), "CAPACITY_FULL", "exact >2^53 counts block hatching")
	eq(hud:getHatchStatusVisible(), true, "exact >2^53 counts keep the status visible")
	eq(hud:getHatchStatusText(), "Brak miejsca w kurnikach", "no upgrade is promised when none exists")
	ok(string.find(hud:getHabitatText(1), " / ", 1, true) ~= nil, "exact counts still render in the parcel card")

	local snapExactVacant = makeSnapshot({
		streamId = "stream-77-exact-vacant",
		hatchery = { stock = "5" },
		habitats = {
			{ habitatIndex = 18, population = exactPopulation, reservedInTransit = "0", capacity = exactCapacity },
			{}, {}, {},
		},
	})
	h.store:applySnapshot(snapExactVacant)
	eq(hud:getHatchStatusReason(), nil, "exact >2^53 counts still see the remaining vacancy")
	eq(hud:getHatchStatusVisible(), false, "exact vacancy hides the status")

	-- 1.11 No packets, no sounds, no repeated announcement, and both paths stay informed.
	local soundsBefore = h.sounds()
	h.store:applySnapshot(snapExactFull)
	eq(hud:getHatchStatusVisible(), true, "blocked view keeps the status visible")
	eq(#h.outgoing, 0, "the status itself sends no packet")
	eq(h.sounds(), soundsBefore, "the status itself plays no sound")
	local announced = hud:getHatchStatusText()
	for _ = 1, 3 do hud:update() end
	eq(hud:getHatchStatusText(), announced, "repeated view updates do not re-announce the status")
	eq(hud:getHatchStatusVisible(), true, "repeated view updates keep the status visible")
	eq(#h.outgoing, 0, "repeated view updates still send no packet")
	eq(h.sounds(), soundsBefore, "repeated view updates still play no sound")

	-- The plate path is observed by the server and sends no client input; the status is a pure
	-- function of the view, so a player standing on the plate sees the same message.
	h.store:applySnapshot(snapExactFull)
	eq(hud:getHatchStatusVisible(), true, "the same authoritative view keeps the plate path informed")
	eq(#h.outgoing, 0, "re-applying the view sends no packet")

	-- The manual hatch button path still sends the existing authoritative intent and keeps the status.
	hud:pressHatch()
	ok(#h.outgoing >= 1, "manual hatch path still sends the authoritative intent")
	eq(hud:getHatchStatusVisible(), true, "manual hatch path keeps the blocked status visible")

	-- 1.12 Responsive strip geometry (#77): a narrow root reserves the 84px right dock; a wide root
	-- centres the strip with a 400px cap. Pure function so it is testable without a live viewport.
	local narrow = HUD.hatchStatusGeometry(320)
	eq(narrow.centered, false, "320px root keeps the strip left-anchored")
	eq(narrow.left, 16, "320px root insets the strip 16px from the left")
	eq(narrow.width, 208, "320px root reserves the right dock (width 208)")
	ok(narrow.left + narrow.width <= 320 - 96, "320px strip right edge stays left of the right dock")
	local portrait = HUD.hatchStatusGeometry(375)
	ok(portrait.left + portrait.width <= 375 - 96, "375px strip right edge stays left of the right dock")
	local edge = HUD.hatchStatusGeometry(600)
	eq(edge.centered, true, "600px root switches to the centred layout")
	eq(edge.width, 400, "600px root uses the 400px cap")
	local wide = HUD.hatchStatusGeometry(1280)
	eq(wide.centered, true, "wide root centres the strip")
	eq(wide.width, 400, "wide root caps the strip at 400px")

	hud:destroy()
end


-- ============================================================================
-- Section 2: #78 all 19 habitat types are shown as Tier 1..Tier 19
-- ============================================================================
do
	local h = newHarness()
	local hud = h.hud

	for index = 0, 18 do
		local snap = makeSnapshot({
			streamId = "stream-78-" .. tostring(index),
			hatchery = { stock = "250" },
			habitats = {
				{ habitatIndex = index, population = "0", reservedInTransit = "0", capacity = "250" },
				{}, {}, {},
			},
		})
		if index == 0 then
			ok(Protocol.validateServer(snap), "habitat tier snapshot is valid under ProtocolSchemas")
		end
		h.store:applySnapshot(snap)
		local card = hud.habitatCards[1]
		ok(card ~= nil, "habitat card 1 exists for index " .. tostring(index))
		eq(card:FindFirstChild("TitleLabel").Text, "Parcela #1: Tier " .. tostring(index + 1),
			"habitat index " .. tostring(index) .. " shows Tier " .. tostring(index + 1))
		local nextText = card:FindFirstChild("NextUpgradeLabel").Text
		if index < 18 then
			eq(nextText, "Następny: Tier " .. tostring(index + 2),
				"habitat index " .. tostring(index) .. " next is Tier " .. tostring(index + 2))
		else
			contains(nextText, "Maksymalny", "habitat index 18 is the maximum tier")
		end
	end

	-- Empty slots stay empty: no habitatIndex is never shown as "Tier 0".
	local snapEmpty = makeSnapshot({
		streamId = "stream-78-empty",
		hatchery = { stock = "250" },
		habitats = {
			{ habitatIndex = 0, population = "0", reservedInTransit = "0", capacity = "250" },
			{}, {}, {},
		},
	})
	h.store:applySnapshot(snapEmpty)
	local emptyTitle = hud.habitatCards[2]:FindFirstChild("TitleLabel").Text
	eq(emptyTitle, "Parcela #2: Niezbudowany", "empty parcel stays empty")
	missing(emptyTitle, "Tier 0", "empty parcel is not Tier 0")

	hud:destroy()
end


-- ============================================================================
-- Section 3: #79 all 12 vehicle types are shown as Tier 1..Tier 12 in the fleet panel
-- ============================================================================
do
	local clickedSlot = nil
	local h = newHarness({ onQuickBuyVehicle = function(slotId) clickedSlot = slotId end })
	local hud = h.hud

	local vehicles = {}
	for index = 0, 11 do
		table.insert(vehicles, { slotId = index + 1, vehicleIndex = index })
	end
	local snap = makeSnapshot({
		streamId = "stream-79-tiers",
		fleet = { vehicles = vehicles, shippingPerMinute = "6000", slotLimit = 12, upgrades = {} },
	})
	ok(Protocol.validateServer(snap), "vehicle tier snapshot is valid under ProtocolSchemas")
	h.store:applySnapshot(snap)

	for index = 0, 11 do
		local card = hud.vehicleCards[index + 1]
		ok(card ~= nil, "vehicle card " .. tostring(index + 1) .. " exists")
		eq(card.titleLabel.Text, "Slot #" .. tostring(index + 1) .. ": Tier " .. tostring(index + 1),
			"vehicle index " .. tostring(index) .. " shows Tier " .. tostring(index + 1))
	end
	-- Capacity labels still come from the unchanged reference table.
	eq(hud.vehicleCards[1].capLabel.Text, "Wydajność: 5K jaj/min", "Tier 1 capacity label unchanged")
	eq(hud.vehicleCards[12].capLabel.Text, "Wydajność: 50M jaj/min", "Tier 12 capacity label unchanged")

	-- The tier belongs to the type, never to the fleet slot: gaps keep their slot identity.
	local snapGap = makeSnapshot({
		streamId = "stream-79-gaps",
		fleet = {
			vehicles = { { slotId = 1, vehicleIndex = 0 }, { slotId = 4, vehicleIndex = 1 } },
			shippingPerMinute = "6000",
			slotLimit = 4,
			upgrades = { { slotId = 1, nextVehicleId = "TRANSIT VAN", price = "100", available = true } },
		},
	})
	ok(Protocol.validateServer(snapGap), "gap snapshot is valid under ProtocolSchemas")
	h.store:applySnapshot(snapGap)
	eq(hud.vehicleCards[1].titleLabel.Text, "Slot #1: Tier 1", "slot 1 keeps Tier 1")
	eq(hud.vehicleCards[2].titleLabel.Text, "Slot #2: Puste miejsce", "gap slot 2 stays empty")
	eq(hud.vehicleCards[3].titleLabel.Text, "Slot #3: Puste miejsce", "gap slot 3 stays empty")
	eq(hud.vehicleCards[4].titleLabel.Text, "Slot #4: Tier 2", "slot identity is the slotId, not the list index")

	-- The existing fleet panel purchase path and prices stay available.
	eq(hud.vehicleCards[1].upgBtn.Active, true, "fleet panel buy path stays available")
	eq(hud.vehicleCards[1].upgBtn.Text, "$100", "fleet panel price unchanged")
	eq(hud.vehicleCards[1].priceLabel.Text, "Następny pojazd", "fleet panel offer label unchanged")
	hud.vehicleCards[1].upgBtn.Activated:Fire()
	eq(clickedSlot, 1, "fleet panel buy path still targets the clicked slot")

	hud:destroy()
end


-- ============================================================================
-- Section 4: #80 world generator (no vehicle pads, habitat pads and depot untouched)
-- ============================================================================
do
	local world = FarmPlotBuilder.new()
	world:build()

	local pads = world:getBuyPads()
	eq(#pads, 4, "only the four habitat buy pads remain in the world")
	for _, pad in ipairs(pads) do
		eq(pad.padType, "BuyHabitat", "pad for slot " .. tostring(pad.slotId) .. " is a habitat pad")
		eq(pad.touchPart:GetAttribute("PadKind"), "BuyHabitat", "pad attribute stays BuyHabitat")
		eq(pad.touchPart:GetAttribute("SlotId"), pad.slotId, "pad slot attribute unchanged")
	end
	eq(pads[1].slotId, 1, "habitat pad slot 1 retained")
	eq(pads[4].slotId, 4, "habitat pad slot 4 retained")

	-- Depot, parking and the 2+1 offer delivery stay exactly as before.
	ok(world:getDeliveryTruck() ~= nil, "delivery truck still exists")
	ok(world:getDeliveryParcel() ~= nil, "2+1 offer parcel still exists")
	eq(world:getDeliveryPrompt().ObjectText, "Specjalna Oferta 2+1", "offer prompt object text unchanged")
	eq(world:getDeliveryPrompt().ActionText, "Otwórz Paczkę", "offer delivery prompt unchanged")
	ok(world.vehiclesModels[1] ~= nil, "parked vehicle presentation still exists")
	eq(world.vehiclesModels[1].Name, "Vehicle_Slot1_Body", "parked vehicle part name unchanged")

	-- Habitat pads still track the current/next tier. The pad price is the authoritative per-slot
	-- upgradePrice supplied by the farm view (same value as the purchase quote), never the catalog
	-- sameTypeOwned=0 price and never a fabricated $100/$500 fallback.
	-- Roblox billboards are not created in Lune, so seed label stubs and observe the same
	-- update code path that writes the world labels.
	for slot = 1, 4 do
		world.habitats[slot].titleLabel = { Text = "" }
	end
	world:updateFromFarmView({
		eggIndex = 0,
		habitats = {
			-- Another SHACK is owned in the real fixture, so the authoritative COOP->SHACK price is
			-- 803.9, not the catalog sameTypeOwned=0 price of 467.
			{ slotId = 1, habitatIndex = 0, population = "0", reservedInTransit = "0", capacity = "250", nextHabitatId = "SHACK", upgradePrice = "803.8970067798514" },
			{ slotId = 2, population = "0", reservedInTransit = "0", capacity = "250", nextHabitatId = "COOP", upgradePrice = "11.266786860373685" },
			{ slotId = 3, habitatIndex = 18, population = "0", reservedInTransit = "0", capacity = "250" },
			{ slotId = 4, habitatIndex = 5, population = "0", reservedInTransit = "0", capacity = "250", nextHabitatId = "DOUBLE DECKER" },
		},
	}, Catalog)

	eq(world.habitats[1].buyPad.line1Label.Text, "[Kurnik #1 -> Tier 2]", "slot 1 pad offers Tier 2")
	eq(world.habitats[2].buyPad.line1Label.Text, "[Kurnik #2 -> Tier 1]", "unbuilt slot 2 pad offers Tier 1")
	eq(world.habitats[3].buyPad.line1Label.Text, "[Kurnik #3 • MAX]", "max tier pad shows MAX")
	eq(world.habitats[4].buyPad.line1Label.Text, "[Kurnik #4 -> Tier 7]", "slot 4 (Tier 6) pad offers Tier 7")
	eq(world.habitats[2].buyPad.line2Label.Text, "Pojemność bazowa: 250", "unbuilt pad describes the Tier 1 base capacity")
	eq(world.habitats[1].buyPad.line2Label.Text, "Pojemność bazowa: 500", "pad line 2 describes the target base capacity without a delta")
	missing(world.habitats[1].buyPad.line2Label.Text, "+", "pad line 2 never implies a delta")
	eq(world.habitats[1].buyPad.line3Label.Text, "$804", "pad price is the authoritative upgradePrice, not the catalog zero-owned price")
	missing(world.habitats[1].buyPad.line3Label.Text, "467", "pad never shows the catalog sameTypeOwned=0 price")
	eq(world.habitats[2].buyPad.line3Label.Text, "$11", "unbuilt pad shows the authoritative build price")
	eq(world.habitats[3].buyPad.line3Label.Text, "MAX", "max tier pad has no price")
	eq(world.habitats[4].buyPad.line3Label.Text, "…", "absent upgradePrice shows an ellipsis, not a fabricated $500")

	-- A buildable slot whose view omits nextHabitatId has no offer: show MAX, never a price.
	world:updateFromFarmView({
		eggIndex = 0,
		habitats = {
			{ slotId = 1, habitatIndex = 0, population = "0", reservedInTransit = "0", capacity = "250" },
		},
	}, Catalog)
	eq(world.habitats[1].buyPad.line1Label.Text, "[Kurnik #1 • MAX]", "absent nextHabitatId shows MAX")
	eq(world.habitats[1].buyPad.line3Label.Text, "MAX", "absent nextHabitatId never fabricates a price")
	missing(world.habitats[1].buyPad.line3Label.Text, "$", "absent nextHabitatId has no dollar price")

	-- World titles use the tier names; empty slots stay empty.
	eq(world.habitats[1].titleLabel.Text, "🏠 Kurnik #1 • Tier 1", "world slot 1 title")
	eq(world.habitats[2].titleLabel.Text, "🏠 Kurnik #2 • Wolna Parcela", "world slot 2 stays empty")
	eq(world.habitats[3].titleLabel.Text, "🏠 Kurnik #3 • Tier 19", "world slot 3 title")
	eq(world.habitats[4].titleLabel.Text, "🏠 Kurnik #4 • Tier 6", "world slot 4 title")


	-- Internal IDs, model names and the reference catalog are untouched.
	eq(Catalog.getHabitat(0).name, "COOP", "catalog habitat 0 name unchanged")
	eq(Catalog.getHabitat(1).name, "SHACK", "catalog habitat 1 name unchanged")
	eq(Catalog.getHabitat(0).capacity, 250, "catalog habitat 0 capacity unchanged")
	eq(Catalog.getHabitat(1).capacity, 500, "catalog habitat 1 capacity unchanged")
	eq(Catalog.getHabitat(0).prices[1], 11.266786860373685, "catalog habitat 0 price unchanged")
	eq(Catalog.getHabitat(1).prices[1], 466.66887875775001, "catalog habitat 1 price unchanged")
	eq(Catalog.getVehicle(0).name, "TRIKE", "catalog vehicle 0 name unchanged")
	eq(Catalog.getVehicle(0).capacity, 5000, "catalog vehicle 0 capacity unchanged")
	eq(Catalog.getVehicle(11).name, "HYPERLOOP TRAIN", "catalog vehicle 11 name unchanged")
	eq(FarmPlotBuilder.HABITAT_PLOTS[1].slotId, 1, "habitat slot 1 id unchanged")
	eq(FarmPlotBuilder.HABITAT_PLOTS[4].slotId, 4, "habitat slot 4 id unchanged")
	eq(world.habitats[1].slotModel.Name, "HabitatSlot_1", "internal slot model name unchanged")
	eq(world.habitats[1].buildingModel.Name, "BuildingGeometry", "internal building model name unchanged")
	eq(pads[1].model.Name, "BuyPad_Habitat_1", "internal habitat pad model name unchanged")
end

-- ============================================================================
-- Section 5: scope guards (no client-side BuyVehicle pad path, no dead vehicle pads)
-- ============================================================================
do
	local mainClient = fs.readFile("src/client/Main.client.luau")
	eq(string.find(mainClient, "padKind == \"BuyVehicle\"", 1, true), nil,
		"client never triggers BuyVehicle from a world pad")
	ok(string.find(mainClient, "onQuickBuyVehicle = function(slotId)", 1, true) ~= nil,
		"fleet panel still routes vehicle purchases through the HUD callback")

	local worldSource = fs.readFile("src/server/world/FarmPlotBuilder.luau")
	eq(string.find(worldSource, "BuyPad_Vehicle", 1, true), nil, "world generator has no vehicle buy pads")
	eq(string.find(worldSource, "padType = \"BuyVehicle\"", 1, true), nil, "world generator has no BuyVehicle pad type")
	ok(string.find(worldSource, "createBuyPad(slotModel", 1, true) ~= nil,
		"shared pad infrastructure stays for habitat pads")
	eq(string.find(worldSource, "\"Szopa (Shack)\"", 1, true), nil, "old habitat display name removed from the world")
	eq(string.find(worldSource, "Kurniczek", 1, true), nil, "old pad offer name removed from the world")
	ok(string.find(worldSource, "ActionText = \"Flota pojazdów\"", 1, true) ~= nil,
		"depot still routes to the fleet panel")

	local hudSource = fs.readFile("src/client/HUD.luau")
	eq(string.find(hudSource, "\"Kurnik (Coop)\"", 1, true), nil, "old habitat display name removed from the HUD")
	eq(string.find(hudSource, "\"Trójkołowiec (Trike)\"", 1, true), nil, "old vehicle display name removed from the HUD")
end

fs.writeFile("build/ui-tasks-77-80-results.json", serde.encode("json", {
	status = "PASS", level = "L", assertions = assertions,
	studioTested = false, dataStoreTested = false, humanAcceptanceTested = false,
	scope = "#77 hatch status from the authoritative view (capacity/reservations, BigAmount stock < 1 including 0.5, exact uint64 counts, no packets or sounds, responsive strip geometry), #78 habitat tiers 1..19, #79 vehicle tiers 1..12, #80 no world vehicle buy pads while habitat pads (authoritative upgradePrice) and the fleet panel stay",
}, true))
print(string.format("UI tasks #77-#80 (hatch status, tier names, world vehicle pads): %d assertions PASS", assertions))
