--!nocheck
-- Test suite for issue #82 UI asset integration (UiAssets manifest + StudUi binding + HUD wiring).
-- Verifies:
-- 1. UiAssets is an honest manifest: 15 bound keys carry the real uploaded rbxassetid://... from
--    theZuraz (11647593962) and 4 optional unuploaded keys keep id == "" (never an invented id).
-- 2. StudUi resolves a pending key to nil (no fake image) and a supplied id to "rbxassetid://...".
-- 3. StudUi:iconSlot / inlineIcon / closeButton draw nothing while a key is pending, keep the text
--    fallback, and draw the genuine image only once an id is bound.
-- 4. HUD wires UiAssets.images into its single StudUi instance; HUD:getAssetStatus() reports
--    manifestVersion = 1, mapped = 15, pending = 4, uploadPending = false, iconsCreated = 24.
-- 5. Migrated window headings/menu keep meaningful, emoji-free text, draw genuine IconSlot /
--    IconImage / CloseIcon instances for bound keys, and the menu still opens the matching window.

local UiAssets = require("../../src/client/ui/UiAssets")
local StudUi = require("../../src/client/ui/StudUi")

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

-- All 19 keys declared in UiAssets.images.
local EXPECTED_KEYS = {
	"texture.stud", "texture.stripes",
	"window.research", "window.habitats", "window.fleet", "window.pets",
	"window.shop", "window.calendar", "window.egg", "window.hatch",
	"tab.trophies", "tab.boosts", "tab.passes", "tab.ge",
	"control.close", "control.lock", "control.warning", "control.upgrade", "control.target",
}

local EXPECTED_BOUND_IDS = {
	["texture.stud"] = "rbxassetid://131341485666607",
	["window.research"] = "rbxassetid://105864065338181",
	["window.habitats"] = "rbxassetid://134178063134703",
	["window.fleet"] = "rbxassetid://70778451286598",
	["window.pets"] = "rbxassetid://103320313492528",
	["window.shop"] = "rbxassetid://117587068465023",
	["window.calendar"] = "rbxassetid://104025891237053",
	["window.egg"] = "rbxassetid://131144454901847",
	["window.hatch"] = "rbxassetid://133508181437045",
	["tab.trophies"] = "rbxassetid://95628265314432",
	["tab.boosts"] = "rbxassetid://72308823693688",
	["tab.passes"] = "rbxassetid://125059444460019",
	["tab.ge"] = "rbxassetid://123463156806216",
	["control.close"] = "rbxassetid://113170557670552",
	["control.upgrade"] = "rbxassetid://125059444460019",
}

local EXPECTED_PENDING_KEYS = {
	["texture.stripes"] = true,
	["control.lock"] = true,
	["control.warning"] = true,
	["control.target"] = true,
}

-- Any 4-byte UTF-8 lead byte means an emoji glyph; migrated headings/menu must not use them.
local function hasEmoji(text)
	if type(text) ~= "string" then return false end
	for i = 1, #text do
		if string.byte(text, i) >= 0xF0 then return true end
	end
	return false
end

-- A minimal element factory + Roblox-or-mock constructors for the direct StudUi tests.
local function mockCreate(className, properties, parent)
	local inst = { ClassName = className, Name = (properties and properties.Name) or className, Children = {} }
	for k, v in pairs(properties or {}) do inst[k] = v end
	function inst:FindFirstChild(name)
		for _, c in ipairs(self.Children) do if c.Name == name then return c end end
		return nil
	end
	function inst:FindFirstChildOfClass(cls)
		for _, c in ipairs(self.Children) do if c.ClassName == cls then return c end end
		return nil
	end
	if parent ~= nil then
		inst.Parent = parent
		table.insert(parent.Children, inst)
	end
	return inst
end

local function studUiWith(assets, manifestVersion)
	return StudUi.new({
		create = mockCreate,
		isRoblox = false,
		Color3 = {
			fromRGB = function(r, g, b) return { R = r, G = g, B = b } end,
			new = function(r, g, b) return { R = r, G = g, B = b } end,
		},
		UDim2 = {
			new = function(sx, ox, sy, oy) return { X = { Scale = sx, Offset = ox }, Y = { Scale = sy, Offset = oy } } end,
			fromOffset = function(x, y) return { X = { Offset = x }, Y = { Offset = y } } end,
		},
		UDim = { new = function(s, o) return { Scale = s, Offset = o } end },
		Vector2 = { new = function(x, y) return { X = x, Y = y } end },
		Enum = {
			Font = { FredokaOne = "FredokaOne" },
			TextXAlignment = { Left = "Left", Right = "Right", Center = "Center" },
			TextYAlignment = { Top = "Top", Center = "Center", Bottom = "Bottom" },
		},
		assets = assets,
		manifestVersion = manifestVersion,
	})
end

-- ============================================================================
-- Section 1: UiAssets is an honest, licence-backed manifest with bound uploaded ids
-- ============================================================================
do
	ok(type(UiAssets) == "table", "UiAssets module loads as a table")
	eq(UiAssets.manifestVersion, 1, "manifest version bumped to 1 after uploading 14 PNGs")
	eq(UiAssets.uploadPending, true, "uploadPending stays true while 4 optional keys remain unuploaded")
	ok(type(UiAssets.images) == "table", "images map exists")
	ok(type(UiAssets.license) == "table" and type(UiAssets.license.studui) == "string" and #UiAssets.license.studui > 0,
		"StudUI licence recorded")
	ok(type(UiAssets.license) == "table" and type(UiAssets.license.gvesster) == "string" and #UiAssets.license.gvesster > 0,
		"gvesster licence recorded")

	local count = 0
	for _ in pairs(UiAssets.images) do count += 1 end
	eq(count, #EXPECTED_KEYS, "exactly the expected number of image keys is declared")

	for _, key in ipairs(EXPECTED_KEYS) do
		local entry = UiAssets.images[key]
		ok(type(entry) == "table", "entry for " .. key .. " is a table")
		ok(type(entry.source) == "string" and #entry.source > 0, key .. " has a real local source")
		ok(string.sub(entry.source, -4) == ".png", key .. " source is a PNG")
		if EXPECTED_BOUND_IDS[key] ~= nil then
			eq(entry.id, EXPECTED_BOUND_IDS[key], key .. " id matches uploaded rbxassetid")
		else
			ok(EXPECTED_PENDING_KEYS[key] == true, key .. " is an expected unuploaded optional key")
			eq(entry.id, "", key .. " unuploaded optional key stays empty")
		end
	end
end

-- ============================================================================
-- Section 2: StudUi never invents an id while a key is pending
-- ============================================================================
do
	local emptyAssets = {}
	for _, key in ipairs(EXPECTED_KEYS) do
		emptyAssets[key] = { source = UiAssets.images[key].source, id = "" }
	end
	local ui = studUiWith(emptyAssets, 0)
	eq(ui:assetId("window.shop"), nil, "pending window key resolves to nil (never a guessed id)")
	eq(ui:assetId("texture.stud"), nil, "pending texture key resolves to nil")
	eq(ui:assetId("control.close"), nil, "pending control key resolves to nil")
	eq(ui:assetId("no.such.key"), nil, "unknown key resolves to nil")
	eq(ui:assetId(""), nil, "empty key resolves to nil")
	eq(ui:hasAsset("window.shop"), false, "hasAsset is false while pending")

	local status = ui:assetStatus()
	eq(status.manifestVersion, 0, "asset status carries the manifest version")
	eq(status.mapped, 0, "nothing is mapped while all ids are empty")
	eq(status.pending, #EXPECTED_KEYS, "every key is reported pending")
	eq(#status.pendingKeys, #EXPECTED_KEYS, "pendingKeys lists every key")
	eq(#status.mappedKeys, 0, "mappedKeys is empty")
	eq(status.iconsCreated, 0, "no image instance is created for a pending key")

	-- iconSlot / inlineIcon must draw nothing while pending so the text label alone carries meaning.
	local parent = mockCreate("Frame", { Name = "Parent" }, nil)
	local slot, image = ui:iconSlot(parent, { key = "window.shop" })
	eq(slot, nil, "iconSlot returns no slot while the image is pending")
	eq(image, nil, "iconSlot returns no image while the image is pending")
	eq(ui:inlineIcon(parent, { key = "tab.ge" }), nil, "inlineIcon returns nil while pending")
	eq(#parent.Children, 0, "no placeholder child is added for a pending icon")
end

-- ============================================================================
-- Section 3: A bound id resolves and draws the genuine image (text stays as fallback until then)
-- ============================================================================
do
	local ui = studUiWith({
		["window.shop"] = { source = "gvesster/.../Golden Shopping Cart.png", id = "12345" },
		["texture.stud"] = { source = "studui/StudUI_stud.png", id = "rbxassetid://999" },
		["tab.ge"] = { source = "gvesster/.../Golden Diamond.png", id = 42 },
		["control.close"] = { source = "gvesster/.../X.png", id = "" },
	}, 1)

	eq(ui:assetId("window.shop"), "rbxassetid://12345", "a numeric string id is normalised once")
	eq(ui:assetId("texture.stud"), "rbxassetid://999", "a full rbxassetid:// id is passed through")
	eq(ui:assetId("tab.ge"), "rbxassetid://42", "a numeric id is formatted")
	eq(ui:assetId("control.close"), nil, "an empty id stays unmapped")
	eq(ui:hasAsset("window.shop"), true, "hasAsset is true once an id is bound")

	local status = ui:assetStatus()
	eq(status.manifestVersion, 1, "bound manifest version is reported")
	eq(status.mapped, 3, "three keys are mapped")
	eq(status.pending, 1, "one key remains pending")

	local parent = mockCreate("Frame", { Name = "Parent" }, nil)
	local slot, image = ui:iconSlot(parent, { key = "window.shop" })
	ok(slot ~= nil and image ~= nil, "iconSlot draws once the id is bound")
	eq(image.Image, "rbxassetid://12345", "icon uses the genuine uploaded id")
	eq(#parent.Children, 1, "exactly one slot is created for a bound icon")

	local inline = ui:inlineIcon(parent, { key = "tab.ge", size = { 0, 22, 0, 22 }, position = { 0, 0, 0, 0 } })
	ok(inline ~= nil, "inlineIcon draws once the id is bound")
	eq(inline.Image, "rbxassetid://42", "inline icon uses the genuine uploaded id")

	local closeBtn = ui:closeButton(parent, function() end)
	ok(closeBtn ~= nil, "close button still exists")
	eq(closeBtn:FindFirstChild("CloseIcon"), nil, "close icon is not drawn while control.close has no id")
	eq(closeBtn.Text, "X", "close button keeps its text fallback while the icon is pending")
end

-- ============================================================================
-- Section 4: HUD wiring — bound uploaded assets drawn, headings/menu stay meaningful
-- ============================================================================
do
	local transport = ClientTransport.new({ protocol = Protocol, wire = function() end })
	local store = ClientStateStore.new({ transport = transport, codec = C })
	local controllers = IntentControllers.new({ transport = transport, stateStore = store, codec = C })
	local hud = HUD.new({ stateStore = store, intentControllers = controllers, codec = C })

	local status = hud:getAssetStatus()
	eq(status.manifestVersion, 1, "HUD reports manifestVersion 1")
	eq(status.mapped, 15, "HUD reports 15 mapped asset keys")
	eq(status.pending, 4, "HUD reports 4 optional pending asset keys")
	eq(status.uploadPending, true, "HUD reports uploadPending == true while 4 optional keys are unuploaded")
	eq(status.iconsCreated, 24, "HUD creates 24 icon instances across headers, tabs, close buttons and hatch card")

	-- Migrated headings stay meaningful, carry no emoji, and draw their bound header icon + close icon.
	local windows = {
		{ label = "Research", win = hud:getResearchModal(), title = "BADANIA I TECHNOLOGIA", key = "window.research" },
		{ label = "Habitats", win = hud:getHabitatsModal(), title = "TWOJE KURNIKI (PARCELE 1-4)", key = "window.habitats" },
		{ label = "Fleet", win = hud:getVehiclesModal(), title = "FLOTA TRANSPORTOWA (DO 17 POJAZDÓW)", key = "window.fleet" },
		{ label = "Pets", win = hud:getPetsModal(), title = "MOJE PETY I EWOLUCJA FUZYJNA", key = "window.pets" },
		{ label = "Shop", win = hud:getShopModal(), title = "SKLEP DIAMENTÓW I PRZEPUSTEK", key = "window.shop" },
		{ label = "Daily/Trophies", win = hud:getCalendarModal(), title = "KALENDARZ NAGRÓD", key = "window.calendar" },
		{ label = "EggUpgrade", win = hud:getEggUpgradeModal(), title = "STACJA BADAWCZA JAJ", key = "window.egg" },
		{ label = "PetHatch", win = hud:getPetHatchModal(), title = "INKUBACJA & WYKLUWANIE JAJ", key = "window.hatch" },
		{ label = "EpicResearch", win = hud:getEpicResearchModal(), title = "BADANIA EPICKIE", key = "window.shop" },
	}
	for _, w in ipairs(windows) do
		ok(w.win ~= nil, w.label .. " window exists")
		local header = w.win:FindFirstChild("WindowHeader")
		ok(header ~= nil, w.label .. " window header exists")
		local title = header and header:FindFirstChild("WindowTitle")
		ok(title ~= nil, w.label .. " window has a text title")
		eq(title.Text, w.title, w.label .. " heading text is unchanged")
		ok(not hasEmoji(title.Text), w.label .. " heading has no emoji")
		local iconSlot = header:FindFirstChild("IconSlot")
		ok(iconSlot ~= nil, w.label .. " header draws IconSlot once asset is bound")
		local iconImg = iconSlot and iconSlot:FindFirstChild("IconImage")
		ok(iconImg ~= nil, w.label .. " header draws IconImage")
		eq(iconImg.Image, EXPECTED_BOUND_IDS[w.key], w.label .. " header icon uses uploaded rbxassetid")
		local closeBtn = w.win:FindFirstChild("CloseBtn")
		ok(closeBtn ~= nil, w.label .. " close button exists")
		local closeIcon = closeBtn and closeBtn:FindFirstChild("CloseIcon")
		ok(closeIcon ~= nil, w.label .. " close button draws CloseIcon")
		eq(closeIcon.Image, EXPECTED_BOUND_IDS["control.close"], w.label .. " close icon uses uploaded rbxassetid")
		eq(closeBtn.Text, "", w.label .. " close button clears fallback X text when CloseIcon is drawn")
	end

	-- Menu dock buttons carry genuine icons, clear fallback text, and still open their matching windows.
	local dockButtons = {
		{ label = "Research", btn = hud.researchToggleBtn, key = "window.research", title = "Badania" },
		{ label = "EpicResearch", btn = hud.epicResearchToggleBtn, key = "tab.ge", title = "Epickie" },
		{ label = "Habitats", btn = hud.habitatsToggleBtn, key = "window.habitats", title = "Kurniki" },
		{ label = "Fleet", btn = hud.vehiclesToggleBtn, key = "window.fleet", title = "Flota" },
		{ label = "Pets", btn = hud.petsToggleBtn, key = "window.pets", title = "Pety" },
		{ label = "Shop", btn = hud.shopToggleBtn, key = "window.shop", title = "Sklep" },
		{ label = "Daily/Trophies", btn = hud.calendarToggleBtn, key = "window.calendar", title = "Nagrody" },
	}

	for _, d in ipairs(dockButtons) do
		ok(d.btn ~= nil, d.label .. " dock button exists")
		eq(d.btn.Text, "", d.label .. " button text is empty (icon only)")
		if d.btn.GetAttribute then
			eq(d.btn:GetAttribute("MenuTitle"), d.title, d.label .. " button has MenuTitle attribute")
		end
		local icon = d.btn:FindFirstChild("ButtonIcon")
		ok(icon ~= nil, d.label .. " dock button has ButtonIcon child")
		if icon then
			eq(icon.Image, EXPECTED_BOUND_IDS[d.key], d.label .. " button icon uses uploaded rbxassetid")
		end
	end

	eq(hud:getShopModal().Visible, false, "shop window starts hidden")
	hud.shopToggleBtn.Activated:Fire()
	eq(hud:getShopModal().Visible, true, "shop menu button still opens the shop window")

	hud:destroy()
end

print("UI assets (#82): " .. tostring(assertions) .. " assertions PASS")
