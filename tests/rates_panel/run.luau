--!nocheck
-- Regression suite for the top rates HUD panel (HatchTheEgg).
-- Scope:
-- * One named top panel replaces the three bare top numbers: Produkcja, Sprzedaż and
--   Limit transportu, every value a rate in Polish "jaj/s".
-- * Production and sales come straight from farm.producedEggsPerSecond / farm.soldEggsPerSecond.
-- * Transport is the fleet CAPACITY converted with
--   codec.BigAmount.divide(codec.BigAmount.decode(farm.fleet.shippingPerMinute), 60) before
--   formatCompact: 5000/min => "83.33 jaj/s" (never "5000/s"), never the current sold amount or cash.
--   The authoritative view is only read; the presentation view stays frozen and byte-identical.
-- * Responsive geometry for 320x640, 360x640, 640x360 and 1200x700 stays on screen and clear of the
--   48px sound toggle, the right dock and the GoldenEgg counter.
-- * Home navigation and the sound toggle keep their behavior and hit targets.
local C = require("../../src/shared/NumericCodec")
local Schemas = require("../../src/shared/ProtocolSchemas")
local Protocol = Schemas.new(C)

local ClientTransport = require("../../src/client/ClientTransport")
local ClientStateStore = require("../../src/client/ClientStateStore")
local IntentControllers = require("../../src/client/IntentControllers")
local HUD = require("../../src/client/HUD")

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
local function near(a, b, label)
	assertions += 1
	assert(type(a) == "number" and math.abs(a - b) < 1e-9,
		(label or "") .. " expected " .. tostring(b) .. " got " .. tostring(a))
end

-- Client harness: real transport/store/controllers, presentation-only HUD, toggling audio stub.
local function newHarness(extraDeps)
	local outgoing = {}
	local transport = ClientTransport.new({ protocol = Protocol, wire = function(msg) table.insert(outgoing, msg) end })
	local store = ClientStateStore.new({ transport = transport, codec = C })
	local controllers = IntentControllers.new({ transport = transport, stateStore = store, codec = C })
	local muted = false
	local audio = {
		playSFX = function() end,
		isMuted = function() return muted end,
		toggleMute = function() muted = not muted; return muted end,
	}
	local deps = {
		stateStore = store,
		intentControllers = controllers,
		codec = C,
		audioController = audio,
	}
	for key, value in (extraDeps or {}) do deps[key] = value end
	local hud = HUD.new(deps)
	return { hud = hud, store = store, outgoing = outgoing }
end

-- Own-farm snapshot shaped like the real ViewProjector output.
local function makeSnapshot(spec)
	local habitats = {}
	for slot = 1, 4 do
		local source = (spec.habitats and spec.habitats[slot]) or {}
		table.insert(habitats, {
			slotId = slot,
			habitatIndex = source.habitatIndex or 0,
			population = source.population or "0",
			reservedInTransit = source.reservedInTransit or "0",
			capacity = source.capacity or "500",
		})
	end
	return {
		protocolVersion = 1, numericCodecVersion = 1, viewSchemaVersion = 1,
		configRevision = "cfg:1", calculationVersion = 1,
		streamId = spec.streamId or "stream-rates",
		commitRevision = spec.commitRevision or "1",
		viewSeq = spec.viewSeq or "1",
		serverObservedAt = spec.serverObservedAt or 1000000,
		kind = "StateSnapshot",
		requestId = spec.requestId or "boot-rates",
		view = {
			audience = "own",
			farm = {
				lifecycle = spec.lifecycle or "ready",
				eggIndex = 0,
				cash = spec.cash or "1000",
				habitats = habitats,
				hatchery = { stock = "250", capacity = "500", refillPerSecond = "3" },
				fleet = spec.fleet or {
					vehicles = { { slotId = 1, vehicleIndex = 0 } },
					shippingPerMinute = "60000",
					slotLimit = 4,
					upgrades = {},
				},
				producedEggsPerSecond = spec.producedEggsPerSecond or "1500",
				soldEggsPerSecond = spec.soldEggsPerSecond or "1200",
				cashIncomePerSecond = "500",
				common = {},
			},
		},
	}
end


-- ============================================================================
-- Section 1: jaj/s formatting (production, sales and the jaj/min -> jaj/s capacity)
-- ============================================================================
do
	eq(HUD.formatEggRate("0"), "0 jaj/s", "zero production keeps the jaj/s unit")
	eq(HUD.formatEggRate(0), "0 jaj/s", "numeric zero production keeps the jaj/s unit")
	eq(HUD.formatEggRate("24500"), "24.5K jaj/s", "production 24500/s renders as 24.5K jaj/s")
	eq(HUD.formatEggRate("20000"), "20K jaj/s", "sales 20000/s renders as 20K jaj/s")
	eq(HUD.formatEggRate(nil), nil, "a missing production field yields no text")

	eq(HUD.formatTransportRate(C, nil), nil, "a missing transport field yields no text")
	eq(HUD.formatTransportRate(nil, "5000"), nil, "a missing codec yields no text")
	eq(HUD.formatTransportRate(C, "not-a-decimal"), nil, "a rejected decimal yields no text")

	near(HUD.transportRatePerSecond(C, "5000"), 5000 / 60, "5000/min converts to 83.33/s")
	eq(HUD.formatTransportRate(C, "5000"), "83.33 jaj/s", "5000/min renders as 83.33 jaj/s")
	ok(HUD.formatTransportRate(C, "5000") ~= "5000 jaj/s", "transport is never the raw per-minute number")
	ok(HUD.formatTransportRate(C, "5000") ~= "83.33 jaj/min", "transport is a per-second rate")
	eq(HUD.formatTransportRate(C, "60000"), "1K jaj/s", "60000/min renders as 1K jaj/s")
	eq(HUD.formatTransportRate(C, "1200000"), "20K jaj/s", "1200000/min renders as 20K jaj/s")
	eq(HUD.formatTransportRate(C, "0"), "0 jaj/s", "no vehicle capacity is a real zero, not a missing value")
end

-- ============================================================================
-- Section 2: one named panel with three cells (headings, legacy labels, no bare leftovers)
-- ============================================================================
do
	local h = newHarness()
	local hud = h.hud

	ok(hud:getRatesPanel() ~= nil, "one rates panel exists")
	eq(hud:getRatesHeadingText(1), "Produkcja", "cell 1 heading is Produkcja")
	eq(hud:getRatesHeadingText(2), "Sprzedaż", "cell 2 heading is Sprzedaż")
	eq(hud:getRatesHeadingText(3), "Limit transportu", "cell 3 heading is Limit transportu")
	eq(hud:getRatesCaptionText(), "Transport określa maksymalną sprzedaż", "explanatory caption text")

	ok(hud.producedEggsLabel ~= nil and hud.soldEggsLabel ~= nil and hud.shippingLabel ~= nil,
		"legacy value labels are preserved")
	ok(hud.producedEggsLabel.Parent == hud:getRatesCell(1)
		and hud.soldEggsLabel.Parent == hud:getRatesCell(2)
		and hud.shippingLabel.Parent == hud:getRatesCell(3),
		"each value label sits in its own panel cell")
	ok(hud:getRatesCell(1):FindFirstChild("RatesHeading") ~= nil, "the heading is a separate visible label")

	eq(hud:getProducedEggsText(), "0 jaj/s", "initial production placeholder is a jaj/s rate")
	eq(hud:getSoldEggsText(), "0 jaj/s", "initial sales placeholder is a jaj/s rate")
	eq(hud:getShippingText(), "0 jaj/s", "initial transport placeholder is a jaj/s rate")

	local bare = 0
	for _, node in hud:getTopBar():GetDescendants() do
		if type(node.Text) == "string"
			and (string.find(node.Text, "/min", 1, true) or string.find(node.Text, "0/s", 1, true)) then
			bare += 1
		end
	end
	eq(bare, 0, "no obsolete bare top numbers remain in the header")

	hud:destroy()
end

-- ============================================================================
-- Section 3: live values from the authoritative view, changed rates and immutability
-- ============================================================================
do
	local h = newHarness()
	local hud, store = h.hud, h.store

	store:applySnapshot(makeSnapshot({
		streamId = "stream-rates-live",
		cash = "5420000",
		producedEggsPerSecond = "24500",
		soldEggsPerSecond = "20000",
		fleet = { vehicles = { { slotId = 1, vehicleIndex = 0 } }, shippingPerMinute = "5000", slotLimit = 4, upgrades = {} },
	}))
	eq(hud:getProducedEggsText(), "24.5K jaj/s", "production rate shown in jaj/s")
	eq(hud:getSoldEggsText(), "20K jaj/s", "sales rate shown in jaj/s")
	eq(hud:getShippingText(), "83.33 jaj/s", "5000/min transport capacity is 83.33 jaj/s")
	ok(hud:getShippingText() ~= hud:getSoldEggsText(), "transport capacity is not the current sales rate")

	-- Changed rates flow through the same panel.
	store:applySnapshot(makeSnapshot({
		streamId = "stream-rates-live", commitRevision = "2", viewSeq = "2",
		producedEggsPerSecond = "120", soldEggsPerSecond = "60",
		fleet = { vehicles = {}, shippingPerMinute = "600", slotLimit = 4, upgrades = {} },
	}))
	eq(hud:getProducedEggsText(), "120 jaj/s", "changed production rate is repainted")
	eq(hud:getSoldEggsText(), "60 jaj/s", "changed sales rate is repainted")
	eq(hud:getShippingText(), "10 jaj/s", "changed transport capacity is repainted")

	-- Real zeroes stay zeroes in every cell.
	store:applySnapshot(makeSnapshot({
		streamId = "stream-rates-live", commitRevision = "3", viewSeq = "3",
		producedEggsPerSecond = "0", soldEggsPerSecond = "0",
		fleet = { vehicles = {}, shippingPerMinute = "0", slotLimit = 4, upgrades = {} },
	}))
	eq(hud:getProducedEggsText(), "0 jaj/s", "zero production renders as 0 jaj/s")
	eq(hud:getSoldEggsText(), "0 jaj/s", "zero sales render as 0 jaj/s")
	eq(hud:getShippingText(), "0 jaj/s", "zero transport capacity renders as 0 jaj/s")

	-- Exact input immutability: the authoritative view the HUD reads is frozen and byte-identical
	-- after a repaint, and writing the transport field through it is rejected.
	local view = store:getPresentationFarm()
	local encodedView = serde.encode("json", view)
	hud:update()
	eq(serde.encode("json", view), encodedView, "the authoritative view is byte-identical after the repaint")
	eq(table.isfrozen(view), true, "the presentation view stays frozen")
	eq(pcall(function() view.fleet.shippingPerMinute = "999" end), false,
		"the authoritative transport value cannot be written through the view")

	hud:destroy()
end

-- ============================================================================
-- Section 4: a view without the rate fields never invents a rate
-- ============================================================================
do
	local h = newHarness()
	local hud, store = h.hud, h.store

	eq(hud:getSessionStatus(), "CONNECTING", "status behavior unchanged before any view")
	hud:update()
	eq(hud:getProducedEggsText(), "0 jaj/s", "repaint without a view keeps the placeholder")
	eq(hud:getSoldEggsText(), "0 jaj/s", "repaint without a view keeps the sales placeholder")
	eq(hud:getShippingText(), "0 jaj/s", "repaint without a view keeps the transport placeholder")

	local partial = makeSnapshot({ streamId = "stream-rates-partial" })
	partial.view.farm.producedEggsPerSecond = nil
	partial.view.farm.soldEggsPerSecond = nil
	partial.view.farm.fleet.shippingPerMinute = nil
	store:applySnapshot(partial)
	eq(hud:getSessionStatus(), "READY", "a ready view still reaches the HUD")
	eq(hud:getProducedEggsText(), "0 jaj/s", "a view without production shows no invented rate")
	eq(hud:getSoldEggsText(), "0 jaj/s", "a view without sales shows no invented rate")
	eq(hud:getShippingText(), "0 jaj/s", "a view without transport shows no invented rate")

	hud:destroy()
end


-- ============================================================================
-- Section 5: responsive geometry (desktop and mobile, portrait and landscape)
-- ============================================================================
do
	for _, viewport in ipairs({ { 320, 640 }, { 360, 640 }, { 640, 360 }, { 1200, 700 } }) do
		local width, height = viewport[1], viewport[2]
		local layout = HUD.ratesPanelGeometry(width)
		local where = string.format("%dx%d: ", width, height)
		ok(layout.left >= 0, where .. "the header starts on screen")
		ok(layout.left + layout.width <= width - 92, where .. "the header clears the sound toggle and the right dock")
		ok(6 + layout.height <= 104, where .. "the header stays above the GoldenEgg counter")
		ok(layout.cellWidth > 0 and layout.cellWidth * 3 <= layout.panelWidth + 1e-9, where .. "three equal cells fit the panel")
	end

	eq(HUD.ratesPanelGeometry(320).captionVisible, false, "narrow cells drop the caption")
	eq(HUD.ratesPanelGeometry(640).captionVisible, true, "wide cells keep the caption")
	eq(HUD.ratesPanelGeometry(640).left + HUD.ratesPanelGeometry(640).width, 548, "640px keeps a 92px right gutter")
	eq(HUD.ratesPanelGeometry(1200).left, 360, "1200px centres the 480px header")
	eq(HUD.ratesPanelGeometry(1200).width, 480, "wide viewports use the full 480px header")
	eq(HUD.ratesPanelGeometry(4000).width, 480, "the header never grows past 480px")
	eq(HUD.ratesPanelGeometry(120).width, 168, "tiny viewports clamp to the minimum header width")
	eq(HUD.ratesPanelGeometry(nil).width, 480, "a missing viewport falls back to the desktop layout")
	eq(HUD.ratesPanelGeometry(320).panelHeight, 44, "narrow cells reserve two heading lines")
	eq(HUD.ratesPanelGeometry(1200).panelHeight, 36, "wide cells use the compact single-line heading")
	ok(HUD.ratesPanelGeometry(320).headingMax >= 10 and HUD.ratesPanelGeometry(320).headingMax <= 15,
		"heading font cap stays readable on a 320px viewport")
	ok(HUD.ratesPanelGeometry(1200).valueMax >= 15 and HUD.ratesPanelGeometry(1200).valueMax <= 24,
		"value font cap stays readable on a 1200px viewport")
end

-- ============================================================================
-- Section 6: existing navigation and sound toggle are unchanged
-- ============================================================================
do
	local homeClicks = 0
	local h = newHarness({ onHomeClicked = function() homeClicks += 1 end })
	local hud = h.hud

	ok(hud.homeButton ~= nil, "home button exists")
	ok(hud.homeButton.Parent == hud:getTopBar(), "home button stays in the top header")
	hud.homeButton.Activated:Fire()
	eq(homeClicks, 1, "home navigation callback still fires")

	local audioBtn = hud:getAudioToggleButton()
	ok(audioBtn ~= nil, "sound toggle exists")
	audioBtn.Activated:Fire()
	eq(audioBtn.Text, "🔇", "sound toggle still mutes")
	audioBtn.Activated:Fire()
	eq(audioBtn.Text, "🔊", "sound toggle still unmutes")

	-- Lune has no viewport, so the touch targets are asserted from the source, like the other
	-- geometry-independent UI checks in this repository.
	local source = fs.readFile("src/client/HUD.luau")
	ok(string.find(source, "UDim2.new(0, 44, 0, 44)", 1, true) ~= nil, "the Dom button keeps its 44px hit target")
	ok(string.find(source, "UDim2.new(0, 48, 0, 48)", 1, true) ~= nil, "the sound toggle keeps its 48px hit target")
	ok(string.find(source, "IgnoreGuiInset = false", 1, true) ~= nil, "the existing IgnoreGuiInset treatment is preserved")

	hud:destroy()
end

fs.writeFile("build/rates-panel-results.json", serde.encode("json", {
	status = "PASS", level = "L", assertions = assertions,
	studioTested = false, dataStoreTested = false, humanAcceptanceTested = false,
	scope = "one named top rates panel (Produkcja / Sprzedaz / Limit transportu) in jaj/s: production and sales from the authoritative per-second view, transport as fleet capacity (jaj/min / 60, 5000/min => 83.33 jaj/s), responsive header geometry for 320x640/360x640/640x360/1200x700 clear of the sound toggle, right dock and GoldenEgg counter, preserved home navigation and 44px hit targets, no invented rates and no authoritative writes",
}, true))
print(string.format("Rates panel (top jaj/s metrics): %d assertions PASS", assertions))
