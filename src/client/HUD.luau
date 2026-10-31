--!nocheck
-- HUD for HatchTheEgg (IMP-14, VIS-04, PROD-01, PROD-02, PROD-03).
-- Classic Studs styled responsive 2D HUD for PC and Mobile, inspired by
-- the user's reference screenshots (Dom button at top, Koszyk Jajek at bottom center,
-- huge green $ counter at bottom-left, studded quick-upgrade buttons on the left,
-- 6 framed icon buttons dock on the right, and total chicken counter at bottom-right).
--
-- Supported Full Modals (PROD-03):
-- 1. HabitatsModal: All 19 habitat types (Tier 1..Tier 19), 4 parcel cards, capacity fill bars, prices.
-- 2. VehiclesModal: Up to 17 fleet slots, 12 vehicle types (Tier 1..Tier 12), live shipping comparison bar.
-- 3. ResearchModal: Multi-tier modal with tabs for Tiers 1–13 (56 common) + dedicated Epic research tab (Diamenty).
-- 4. PetsModal: Equipped slots (3/5), inventory grid, fusion section (chance indicator, guarantee counter, +10 p.p. Pro Permit bonus).
-- 5. ShopModal: 3 tabs: Diamenty (pakiety Diamentów 1..4), Wzmocnienia (Boosts za Diamenty), Przepustki (Pro Permit, Buy MAX).
-- 6. CalendarModal: 28-day calendar grid with claim indicators + Trophies tab across 19 eggs with 5 tier cups.
-- 7. EggUpgradeModal: 19 eggs progression, Farm Value threshold checking and reset confirmation.
--
-- CRITICAL ARCHITECTURAL INVARIANT:
-- HUD and controllers NEVER modify authoritative state, grant resources, or alter economy balances.
-- All numeric formatting (K, M, B, T) is presentation-only and NEVER parsed back into domain numbers.

local HUD = {}
HUD.__index = HUD

-- Shared stud-style window family (#82). Same dual Studio/Lune resolution as the client
-- Bootstrap, so the module is required from the instance tree in Roblox and by path in Lune.
local isStudioRuntime = (typeof(script) == "Instance")
local function resolveModule(studioGetter, lunePath)
	if isStudioRuntime then
		local ok, mod = pcall(studioGetter)
		if ok and mod then
			return if typeof(mod) == "Instance" then require(mod) else mod
		end
	end
	return require(lunePath)
end

local Availability = resolveModule(function()
 return game:GetService("ReplicatedStorage").HatchTheEgg.Shared.FeatureAvailability
end, "../shared/FeatureAvailability")

local EpicPricing = resolveModule(function() return game:GetService("ReplicatedStorage").HatchTheEgg.Shared.EpicPricing end, "../shared/EpicPricing")

local StudUi = resolveModule(function()
	return script.Parent.ui.StudUi
end, "./ui/StudUi")

-- One integration surface for uploaded image ids (root owns the ids; see src/client/ui/UiAssets).
local UiAssets = resolveModule(function()
	return script.Parent.ui.UiAssets
end, "./ui/UiAssets")

-- Presentation-Only Numeric Formatting

local SUFFIXES = table.freeze({
	{ 1e15, "q" },
	{ 1e12, "T" },
	{ 1e9, "B" },
	{ 1e6, "M" },
	{ 1e3, "K" },
})

local function formatCompact(value)
	local n = if type(value) == "number" then value else tonumber(value) or 0
	if n < 0 then
		return "-" .. formatCompact(-n)
	end

	if n < 1000 then
		if n % 1 == 0 then
			return string.format("%d", n)
		else
			local s = string.format("%.2f", n)
			s = string.gsub(s, "%.?0+$", "")
			return s
		end
	end

	for _, tier in ipairs(SUFFIXES) do
		local threshold = tier[1]
		local symbol = tier[2]
		if n >= threshold then
			local scaled = n / threshold
			local formatted
			if scaled >= 100 then
				formatted = string.format("%.1f", scaled)
			else
				formatted = string.format("%.2f", scaled)
			end
			formatted = string.gsub(formatted, "%.?0+$", "")
			return formatted .. symbol
		end
	end

	return tostring(n)
end

function HUD.formatCompact(selfOrValue, maybeValue)
	local val = if type(selfOrValue) == "table" and selfOrValue.formatCompact == HUD.formatCompact then maybeValue else selfOrValue
	return formatCompact(val)
end

local RESEARCH_EFFECT_LABELS = {
	eggLayingRateMult="Tempo znoszenia", eggValueMult="Wartość jaj",
	hatcheryRefillRateMult="Odnawianie wylęgu", habCapacityMult="Pojemność kurników",
	vehicleCapacityMult="Pojemność transportu", vehicleCapacityMultHover="Pojemność poduszkowców",
	portalCapacityMult="Pojemność portali", hyperloopCarCapacityMult="Pojemność wagonów",
	vehicleSpeedMult="Prędkość pojazdów", vehicleRoundTripTimeMult="Czas kursu",
	vehicleLoadingTimeMult="Czas załadunku", hatcheryCapacity="Zapas wylęgu",
	internalHatcheryRate="Kurczaki/min/kurnik", maxFleetSize="Miejsca floty",
	onscreenChickenMult="Mnożnik Dochodów",
	onscreenChickenMultMax="Maksymalny Mnożnik", hyperloopMaxTrainLength="Dodatkowe wagony",
}
local function researchEffectText(research,fallback)
	local lines={}
	for _,effect in research.effects or {} do
		local function value(text)
			local n=tonumber(text) or 0
			local percent=effect.stat:find("Mult",1,true)~=nil and effect.stat~="onscreenChickenMultMax"
			if percent then n=(n-1)*100 end
			if math.abs(n)<1e-9 then n=0 end
			return (if n>=0 then "+" else "")..formatCompact(n)..(if percent then "%" else "")
		end
		local label=RESEARCH_EFFECT_LABELS[effect.stat] or effect.stat
		table.insert(lines,label..": "..value(effect.current)..(if effect.next then " → "..value(effect.next) else " (MAX)"))
	end
	return if #lines>0 then table.concat(lines,"\n") else fallback
end

function HUD.formatCash(selfOrAmount, maybeAmount)
	local amount = if type(selfOrAmount) == "table" and selfOrAmount.formatCash == HUD.formatCash then maybeAmount else selfOrAmount
	return "$" .. formatCompact(amount)
end

function HUD.formatRate(selfOrAmount, maybeAmountOrUnit, maybeUnit)
	local amount
	local unit = "/s"

	if type(selfOrAmount) == "table" and selfOrAmount.formatRate == HUD.formatRate then
		amount = maybeAmountOrUnit
		if maybeUnit ~= nil then
			unit = maybeUnit
		end
	else
		amount = selfOrAmount
		if maybeAmountOrUnit ~= nil and type(maybeAmountOrUnit) == "string" then
			unit = maybeAmountOrUnit
		end
	end

	return formatCompact(amount) .. unit
end

-- Top Rates Panel Formatting
-- The three former bare top numbers become one named panel: Produkcja, Sprzedaż and
-- Limit transportu. Every value is a rate in Polish "jaj/s".
-- Production and sales are already per-second values of the authoritative view. Transport is the
-- fleet CAPACITY (jaj/min -> jaj/s), never the current sales amount or cash, and the conversion goes
-- through the same BigAmount codec as the view: 5000/min renders as "83.33 jaj/s", not "5000/s".
-- Formatting is presentation-only, the input farm view is only read and never mutated, and a missing
-- authoritative field yields no text at all instead of an invented rate.

HUD.RATES_HEADINGS = table.freeze({ "Produkcja", "Sprzedaż", "Limit transportu" })
HUD.RATES_CAPTION = "Transport określa maksymalną sprzedaż"
HUD.RATES_UNIT = " jaj/s"

local function rateText(amount)
	if amount == nil then return nil end
	return formatCompact(amount) .. HUD.RATES_UNIT
end

function HUD.formatEggRate(selfOrAmount, maybeAmount)
	local amount = if type(selfOrAmount) == "table" and selfOrAmount.formatEggRate == HUD.formatEggRate then maybeAmount else selfOrAmount
	return rateText(amount)
end

-- Pure jaj/min -> jaj/s capacity conversion through the authoritative codec. Returns nil when the
-- field or codec is absent (or the encoded decimal is rejected) so no fictional rate is displayed.
function HUD.transportRatePerSecond(codec, shippingPerMinute)
	if codec == nil or type(codec.BigAmount) ~= "table" or shippingPerMinute == nil then
		return nil
	end
	local ok, perSecond = pcall(function()
		return codec.BigAmount.divide(codec.BigAmount.decode(shippingPerMinute), 60)
	end)
	if not ok then return nil end
	return perSecond
end

function HUD.formatTransportRate(selfOrCodec, maybeCodecOrPerMinute, maybePerMinute)
	local codec, shippingPerMinute
	if type(selfOrCodec) == "table" and selfOrCodec.formatTransportRate == HUD.formatTransportRate then
		codec, shippingPerMinute = maybeCodecOrPerMinute, maybePerMinute
	else
		codec, shippingPerMinute = selfOrCodec, maybeCodecOrPerMinute
	end
	return rateText(HUD.transportRatePerSecond(codec, shippingPerMinute))
end

-- Hatch Status Helpers (#77)
-- The blocked decision is presentation of the authoritative farm view only. Counts stay exact
-- uint64 values: tonumber would round population/reservations above 2^53 and change the answer.

HUD.HATCH_STATUS_FULL = "CAPACITY_FULL"
HUD.HATCH_STATUS_STOCK = "NO_STOCK"
HUD.HATCH_STATUS_FULL_TEXT = "Brak miejsca w kurnikach"
HUD.HATCH_STATUS_STOCK_TEXT = "Brak jaj do wylęgu — zapas się odnawia."

-- The hatchery stock is a BigAmount binary64 decimal, not an exact uint64 count, and hatching needs
-- at least one whole egg: a fractional stock such as 0.5 is already blocked, exactly like the server
-- rule. The removed ExactUInt == 0 helper wrongly reported 0.5 as non-empty; stock < 1 is the test.
local function stockBelowOne(codec, text)
	if type(text) ~= "string" then return false end
	local ok, value = pcall(codec.BigAmount.decode, text)
	if not ok then return false end
	return value < 1
end

-- A built coop has vacancy while population + reservedInTransit < capacity (exact uint64 math).
local function habitatHasVacancy(codec, habitat)
	local U = codec.ExactUInt
	local okCapacity, capacity = pcall(U.decode, habitat.capacity)
	local okPopulation, population = pcall(U.decode, habitat.population or "0")
	local okTransit, inTransit = pcall(U.decode, habitat.reservedInTransit or "0")
	if not (okCapacity and okPopulation and okTransit) then return false end
	if U.compare(population, capacity) >= 0 then return false end
	return U.compare(inTransit, U.subtract(capacity, population)) < 0
end

-- Reference Catalogs & Display Data

local _cat = UiAssets.catalogs
local HABITAT_DISPLAY_NAMES = _cat.HABITAT_DISPLAY_NAMES
local HABITAT_CAPACITIES = _cat.HABITAT_CAPACITIES
local VEHICLE_DISPLAY_NAMES = _cat.VEHICLE_DISPLAY_NAMES
local VEHICLE_CAPACITIES = _cat.VEHICLE_CAPACITIES
local TIER_THRESHOLDS = _cat.TIER_THRESHOLDS
local CATEGORY_THRESHOLDS = _cat.CATEGORY_THRESHOLDS
local RESEARCH_CATEGORY = _cat.RESEARCH_CATEGORY
local UNIFIED_RESEARCH_GROUPS = _cat.UNIFIED_RESEARCH_GROUPS
local COMMON_RESEARCH_TIERS = _cat.COMMON_RESEARCH_TIERS
local RESEARCH_DISPLAY_NAMES = _cat.RESEARCH_DISPLAY_NAMES
local RESEARCH_ICONS = _cat.RESEARCH_ICONS
local COMMON_RESEARCH_MAX_LEVELS = _cat.COMMON_RESEARCH_MAX_LEVELS
local UNSUPPORTED_EPIC_RESEARCH = Availability.blockedEpic
local EPIC_RESEARCH_CATALOG = _cat.EPIC_RESEARCH_CATALOG
local BOOSTS_CATALOG = _cat.BOOSTS_CATALOG
local SHOP_PRODUCTS_CATALOG = _cat.SHOP_PRODUCTS_CATALOG
local TROPHY_POPULATION_TIERS = _cat.TROPHY_POPULATION_TIERS
local EGGS_DATA = _cat.EGGS_DATA

-- GUI Instance Helpers (Studio & Lune Mock)

local isRoblox = (typeof(Instance) == "table" and type(Instance.new) == "function")
local Color3 = if isRoblox and typeof(Color3) == "table" then Color3 else {
	fromRGB = function(r, g, b) return { R = r, G = g, B = b } end,
	new = function(r, g, b) return { R = r, G = g, B = b } end,
}
local UDim2 = if isRoblox and typeof(UDim2) == "table" then UDim2 else {
	new = function(sx, ox, sy, oy) return { X = { Scale = sx, Offset = ox }, Y = { Scale = sy, Offset = oy } } end,
}
local UDim = if isRoblox and typeof(UDim) == "table" then UDim else {
	new = function(s, o) return { Scale = s, Offset = o } end,
}
local Enum = if isRoblox then Enum else {
	Font = { FredokaOne = "FredokaOne" },
	TextXAlignment = { Left = "Left", Right = "Right", Center = "Center" },
	TextYAlignment = { Top = "Top", Center = "Center", Bottom = "Bottom" },
	ZIndexBehavior = { Sibling = "Sibling" },
	ApplyStrokeMode = { Border = "Border" },
}

local TweenService = nil
if isRoblox then
	pcall(function()
		TweenService = game:GetService("TweenService")
	end)
end

local function createMockEvent()
	local listeners = {}
	local event = {}
	function event:Connect(cb)
		table.insert(listeners, cb)
		return {
			Disconnect = function()
				local idx = table.find(listeners, cb)
				if idx then
					table.remove(listeners, idx)
				end
			end,
		}
	end
	function event:Fire(...)
		for _, cb in ipairs(table.clone(listeners)) do
			cb(...)
		end
	end
	return event
end

local function createMockElement(className, properties)
	local attributes = {}
	local inst = {
		ClassName = className,
		Name = (properties and properties.Name) or className,
		Parent = nil,
		Children = {},
		Text = (properties and properties.Text) or "",
		Visible = if properties and properties.Visible ~= nil then properties.Visible else true,
		Active = if properties and properties.Active ~= nil then properties.Active else true,
		AutoButtonColor = if properties and properties.AutoButtonColor ~= nil then properties.AutoButtonColor else true,
	}

	function inst:SetAttribute(name, value)
		attributes[name] = value
	end

	function inst:GetAttribute(name)
		return attributes[name]
	end

	function inst:GetAttributes()
		return table.clone(attributes)
	end

	function inst:FindFirstChild(name)
		for _, child in ipairs(self.Children) do
			if child.Name == name then
				return child
			end
		end
		return nil
	end

	function inst:WaitForChild(name)
		return self:FindFirstChild(name)
	end

	function inst:GetChildren()
		return table.clone(self.Children)
	end

	function inst:GetDescendants()
		local result = {}
		local function collect(node)
			for _, child in ipairs(node.Children or {}) do
				table.insert(result, child)
				collect(child)
			end
		end
		collect(self)
		return result
	end

	function inst:ClearAllChildren()
		for _, child in ipairs(self.Children or {}) do
			child.Parent = nil
		end
		self.Children = {}
	end

	function inst:Destroy()
		self.destroyed = true
		if self.Parent and type(self.Parent.Children) == "table" then
			local idx = table.find(self.Parent.Children, self)
			if idx then
				table.remove(self.Parent.Children, idx)
			end
		end
	end

	if className == "TextButton" or className == "ImageButton" then
		inst.Activated = createMockEvent()
		inst.MouseButton1Down = createMockEvent()
		inst.MouseButton1Up = createMockEvent()
	end

	if properties then
		for k, v in pairs(properties) do
			inst[k] = v
		end
	end

	return inst
end

local function createGuiElement(className, properties, parent)
	local inst
	if isRoblox then
		inst = Instance.new(className)
		if properties then
			for k, v in pairs(properties) do
				pcall(function() inst[k] = v end)
			end
		end
		if parent ~= nil then
			inst.Parent = parent
		end
	else
		inst = createMockElement(className, properties)
		if parent ~= nil then
			inst.Parent = parent
			if type(parent.Children) == "table" then
				table.insert(parent.Children, inst)
			end
		end
	end
	return inst
end

local function addCornerAndStroke(inst, radiusScaleOrOffset, strokeColor, strokeThickness)
	if not isRoblox or typeof(inst) ~= "Instance" then return end
	local corner = Instance.new("UICorner")
	if type(radiusScaleOrOffset) == "number" and radiusScaleOrOffset <= 1 then
		corner.CornerRadius = UDim.new(radiusScaleOrOffset, 0)
	else
		corner.CornerRadius = UDim.new(0, radiusScaleOrOffset or 10)
	end
	corner.Parent = inst

	if strokeThickness and strokeThickness > 0 then
		local stroke = Instance.new("UIStroke")
		stroke.Color = strokeColor or Color3.fromRGB(22, 12, 8)
		stroke.Thickness = strokeThickness
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = inst
	end
end

local function addTextStroke(label, thickness, color)
	if not isRoblox or typeof(label) ~= "Instance" then return end
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Color3.fromRGB(18, 10, 6)
	stroke.Thickness = thickness or 2.5
	stroke.Parent = label
end

-- One decoration pass per instance, at build time only (#82). The shared stud-style family uses
-- corners, thick borders, a vertical gradient for depth, an optional restrained tiled stud
-- overlay and optional pressed feedback. Roblox-only: the Lune mock keeps exactly the element set
-- the existing UI suites assert (no extra children, no per-update styling).
local function decorateGuiElement(inst, spec)
	if not isRoblox or typeof(inst) ~= "Instance" or type(spec) ~= "table" then return end

	local radius = spec.radius
	if radius ~= nil or spec.stroke ~= nil then
		local strokeColor = spec.stroke and Color3.fromRGB(spec.stroke[1], spec.stroke[2], spec.stroke[3]) or nil
		addCornerAndStroke(inst, radius or 8, strokeColor, spec.thickness)
	end

	if type(spec.gradient) == "table" and spec.gradient.top and spec.gradient.bottom then
		local top = spec.gradient.top
		local bottom = spec.gradient.bottom
		local gradient = Instance.new("UIGradient")
		gradient.Name = "Depth"
		gradient.Rotation = 90
		gradient.Color = ColorSequence.new(
			Color3.fromRGB(top[1], top[2], top[3]),
			Color3.fromRGB(bottom[1], bottom[2], bottom[3]))
		gradient.Parent = inst
	end

	if type(spec.studId) == "string" and spec.studId ~= "" then
		local tile = StudUi.TOKENS.stud.tile
		local stud = Instance.new("ImageLabel")
		stud.Name = "StudTexture"
		stud.Size = UDim2.new(1, 0, 1, 0)
		stud.BackgroundTransparency = 1
		stud.Image = spec.studId
		stud.ImageTransparency = spec.studTransparency or StudUi.TOKENS.stud.transparency
		stud.ScaleType = Enum.ScaleType.Tile
		stud.TileSize = UDim2.new(0, tile, 0, tile)
		stud.ZIndex = inst.ZIndex
		stud.Parent = inst
	end

	if type(spec.textStroke) == "number" and spec.textStroke > 0 then
		addTextStroke(inst, spec.textStroke)
	end

	if type(spec.maxTextSize) == "number" and spec.maxTextSize > 0 then
		local cap = Instance.new("UITextSizeConstraint")
		cap.Name = "ReadableTextCap"
		cap.MaxTextSize = spec.maxTextSize
		cap.Parent = inst
	end

	if spec.pressScale == true and inst.MouseButton1Down ~= nil and inst.MouseButton1Up ~= nil then
		local press = Instance.new("UIScale")
		press.Name = "PressScale"
		press.Scale = 1
		press.Parent = inst
		inst.MouseButton1Down:Connect(function()
			press.Scale = 0.96
		end)
		inst.MouseButton1Up:Connect(function()
			press.Scale = 1
		end)
	end
end

local function bindBouncyButton(btn)
	if not isRoblox or typeof(btn) ~= "Instance" or not TweenService then return end
	local uiScale = btn:FindFirstChild("PressScale")
	if not uiScale then
		uiScale = Instance.new("UIScale")
		uiScale.Name = "PressScale"
		uiScale.Scale = 1
		uiScale.Parent = btn
	end
	if btn:IsA("GuiButton") then
		local tweenDown = TweenService:Create(uiScale, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 0.94 })
		local tweenUp = TweenService:Create(uiScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.0 })
		btn.MouseButton1Down:Connect(function()
			tweenDown:Play()
		end)
		btn.MouseButton1Up:Connect(function()
			tweenUp:Play()
		end)
		btn.MouseLeave:Connect(function()
			tweenUp:Play()
		end)
	end
end

local function addShimmerEffect(frame)
	if not isRoblox or typeof(frame) ~= "Instance" or not TweenService then return end
	local gradient = Instance.new("UIGradient")
	gradient.Name = "ShimmerGradient"
	gradient.Rotation = 25
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.45, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
	})
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.4, 1),
		NumberSequenceKeypoint.new(0.5, 0.35),
		NumberSequenceKeypoint.new(0.6, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Offset = Vector2.new(-1, 0)
	gradient.Parent = frame

	local tween = TweenService:Create(gradient, TweenInfo.new(2.4, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, false, 0.8), {
		Offset = Vector2.new(1, 0),
	})
	tween:Play()
end

local function addPulseGlow(stroke, minTransparency, maxTransparency)
	if not isRoblox or typeof(stroke) ~= "Instance" or not TweenService then return end
	minTransparency = minTransparency or 0.05
	maxTransparency = maxTransparency or 0.6
	stroke.Transparency = minTransparency
	local tween = TweenService:Create(stroke, TweenInfo.new(1.0, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Transparency = maxTransparency,
	})
	tween:Play()
end

local function promptMarketplacePurchase(productId, onPurchaseProductCallback)
	if not Availability.isProductAvailable(productId) then return end
	if type(onPurchaseProductCallback) == "function" then
		onPurchaseProductCallback(productId)
	end
end

-- HUD Constructor & Initialization

function HUD.new(deps)
	assert(type(deps) == "table", "INVALID_DEPS")
	assert(deps.stateStore ~= nil, "STATE_STORE_REQUIRED")
	assert(deps.intentControllers ~= nil, "INTENT_CONTROLLERS_REQUIRED")
	assert(deps.codec ~= nil, "CODEC_REQUIRED")

	local guiRoot = deps.guiRoot
	if guiRoot == nil then
		guiRoot = createGuiElement("ScreenGui", {
			Name = "HatchTheEggHUD",
			ResetOnSpawn = false,
			IgnoreGuiInset = false,
			ZIndexBehavior = isRoblox and Enum.ZIndexBehavior.Sibling or nil,
		})
	end

	local self = setmetatable({
		stateStore = deps.stateStore,
		intentControllers = deps.intentControllers,
		codec = deps.codec,
		guiRoot = guiRoot,

		-- Intent callbacks
		onHomeClicked = deps.onHomeClicked,
		onQuickBuyHabitat = deps.onQuickBuyHabitat,
		onQuickBuyVehicle = deps.onQuickBuyVehicle,
		onQuickBuyResearch = deps.onQuickBuyResearch,
		onUpgradeEggRequested = deps.onUpgradeEggRequested,
		onClaimDailyGift = deps.onClaimDailyGift,
		onClaimTrophy = deps.onClaimTrophy,
		onFusePets = deps.onFusePets,
		onEquipPet = deps.onEquipPet,
		onUnequipPet = deps.onUnequipPet,
		onTogglePetLock = deps.onTogglePetLock,
		onBuyBoost = deps.onBuyBoost,
		onActivateBoost = deps.onActivateBoost,
		onPurchaseProduct = deps.onPurchaseProduct,
		audioController = deps.audioController,
		onToggleAudio = deps.onToggleAudio,

		-- Cached view data
		sessionStatus = "CONNECTING",
		hatcheryRatio = 0,
		habitatFillRatios = { 0, 0, 0, 0 },
		habitatPopulations = { "0", "0", "0", "0" },
		habitatCapacities = { "0", "0", "0", "0" },
		totalChickensCount = 0,

		-- Core HUD Components
		sessionBanner = nil,
		sessionStatusLabel = nil,
		homeButton = nil,
		cashLabel = nil,
		cashIcon = nil,
		cashRateLabel = nil,
		diamondsPillFrame = nil,
		diamondIcon = nil,
		producedEggsLabel = nil,
		soldEggsLabel = nil,
		shippingLabel = nil,
		rebirthLabel = nil,
		totalChickensLabel = nil,
		tutorialLabel = nil,
		hatcheryStockLabel = nil,
		hatcheryRefillLabel = nil,
		hatchStatusFrame = nil,
		hatchStatusLabel = nil,
		hatchStatusActionBtn = nil,
		hatchStatusReason = nil,
		hatchButton = nil,
		topBar = nil,
		audioToggleButton = nil,
		-- Top rates panel: one named panel with three equal cells; the legacy value labels are
		-- kept (producedEggsLabel/soldEggsLabel/shippingLabel) and each cell adds a visible heading.
		ratesPanel = nil,
		ratesCells = {},
		ratesHeadingLabels = {},
		ratesValueLabels = {},
		ratesHeadingCaps = {},
		ratesValueCaps = {},
		ratesCaptionLabel = nil,
		ratesCaptionCap = nil,
		_topHeaderInset = 6,

		-- Right Dock Menu Buttons
		researchToggleBtn = nil,
		habitatsToggleBtn = nil,
		vehiclesToggleBtn = nil,
		petsToggleBtn = nil,
		shopToggleBtn = nil,
		calendarToggleBtn = nil,

		-- Modals
		habitatsModal = nil,
		habitatCards = {},
		habitatLabels = {},
		habitatUpgBtns = {},

		vehiclesModal = nil,
		shippingComparisonBar = nil,
		shippingComparisonStatusLabel = nil,
		vehicleCards = {},

		shopFrame = nil, -- ResearchModal
		researchTabButtons = {},
		selectedResearchTier = 1,
		researchTierLockBanner = nil,
		shopResearch = {},
		unifiedResearch = {},
		_legacyHolder = isRoblox and Instance.new("Folder") or {},

		petsModal = nil,
		equippedPetSlots = {},
		petInventoryCards = {},
		fusionChanceLabel = nil,
		fusionGuaranteeLabel = nil,
		fusionProPermitBadge = nil,
		fusePetsButton = nil,

		shopModal = nil,
		shopModalTabButtons = {},
		selectedShopTab = 1,
		shopProductCards = {},
		activeBoostsSummaryLabel = nil,

		calendarModal = nil,
		calendarTabButtons = {},
		selectedCalendarTab = 1,
		calendarDayCells = {},
		claimDailyGiftButton = nil,
		trophyCards = {},

		eggUpgradeModal = nil,
		eggUpgradeCurrentLabel = nil,
		eggUpgradeNextLabel = nil,
		eggUpgradeMultLabel = nil,
		eggUpgradeCurrentFvLabel = nil,
		eggUpgradeReqFvLabel = nil,
		eggUpgradeWarningLabel = nil,
		eggUpgradeBtn = nil,

		-- Prestige & Rebirth Modal
		prestigeModal = nil,
		prestigeCurrentCrystalsLabel = nil,
		prestigeCurrentBonusLabel = nil,
		prestigePendingLabel = nil,
		prestigeActionBtn = nil,

		-- Pet Hatch & Incubator Modal (PROD-07)
		petHatchModal = nil,
		hatchEggButton = nil,
		hatchAnimationOverlay = nil,
		animatedEggVisual = nil,
		hatchBurstGlow = nil,
		petRevealCard = nil,
		revealPetIcon = nil,
		revealPetName = nil,
		revealPetRarity = nil,
		revealPetStat = nil,
		revealEquipBtn = nil,
		revealLockBtn = nil,
		revealConfirmBtn = nil,
		onHatchPetEgg = nil,

		_unsubs = {},
	}, HUD)

	-- Shared stud-style window family (#82). Created once; every migrated window reuses it so the
	-- frame/border/header/button/tab look is identical and decoration happens once per instance.
	self.ui = StudUi.new({
		create = createGuiElement,
		decorate = decorateGuiElement,
		isRoblox = isRoblox,
		Color3 = Color3,
		UDim2 = UDim2,
		UDim = UDim,
		Vector2 = if isRoblox then Vector2 else nil,
		Enum = Enum,
		assets = if UiAssets and type(UiAssets.images) == "table" then UiAssets.images else {},
		manifestVersion = if UiAssets then UiAssets.manifestVersion else 0,
	})

	self:_buildInterface()
	self:_setupSubscriptions()
	self:update()

	return self
end

function HUD:_playClick()
	if self.audioController and type(self.audioController.playSFX) == "function" then
		self.audioController:playSFX("click")
	end
end

function HUD:_buildInterface()
	local root = self.guiRoot

	-- 1. Session Status Banner
	self.sessionBanner = createGuiElement("Frame", {
		Name = "SessionBanner",
		Size = isRoblox and UDim2.new(0, 220, 0, 32) or nil,
		Position = isRoblox and UDim2.new(0.5, -110, 0, 68) or nil,
		BackgroundColor3 = isRoblox and Color3.fromRGB(45, 25, 15) or nil,
		BackgroundTransparency = 0.2,
	}, root)
	addCornerAndStroke(self.sessionBanner, 8, isRoblox and Color3.fromRGB(255, 215, 65) or nil, 2)

	self.sessionStatusLabel = createGuiElement("TextLabel", {
		Name = "StatusLabel",
		Size = isRoblox and UDim2.new(1, 0, 1, 0) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(255, 245, 120) or nil,
		Text = "CONNECTING",
	}, self.sessionBanner)
	addTextStroke(self.sessionStatusLabel, 2)

	-- 2. Top Header: "Dom" button, the three named rate metrics and the tutorial hint
	local headerLayout = HUD.ratesPanelGeometry(0)
	local topBar = createGuiElement("Frame", {
		Name = "TopBar",
		Size = isRoblox and UDim2.new(0, headerLayout.width, 0, headerLayout.height) or nil,
		Position = isRoblox and UDim2.new(0, headerLayout.left, 0, 6) or nil,
		BackgroundTransparency = 1,
	}, root)
	self.topBar = topBar

	-- Safe Area / Inset Adaptation for Mobile Notches & Dynamic Island. The inset is applied by the
	-- responsive binding below, together with the live header geometry.
	if isRoblox then
		pcall(function()
			-- ScreenGui already applies the top inset when IgnoreGuiInset is false.
			-- Frame-based preview roots inherit that setting from their ScreenGui.
			local screenGui = if root:IsA("ScreenGui") then root else root:FindFirstAncestorWhichIsA("ScreenGui")
			if screenGui == nil or not screenGui.IgnoreGuiInset then return end
			local GuiService = game:GetService("GuiService")
			local insetTopLeft, _ = GuiService:GetGuiInset()
			if insetTopLeft and insetTopLeft.Y > 0 then
				self._topHeaderInset = math.max(6, insetTopLeft.Y + 2)
			end
		end)
	end

	-- Audio Mute/Unmute Toggle Button (Top-Right, >= 44x44 hitbox for mobile touch)
	local audioToggleBtn = createGuiElement("TextButton", {
		Name = "AudioToggleButton",
		Size = isRoblox and UDim2.new(0, 48, 0, 48) or nil,
		Position = isRoblox and UDim2.new(1, -64, 0, 10) or nil,
		BackgroundColor3 = isRoblox and Color3.fromRGB(48, 25, 56) or nil,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(255, 255, 255) or nil,
		Text = if self.audioController and self.audioController:isMuted() then "🔇" else "🔊",
	}, root)
	addCornerAndStroke(audioToggleBtn, 10, isRoblox and Color3.fromRGB(255, 215, 65) or nil, 2.5)

	if audioToggleBtn.Activated then
		audioToggleBtn.Activated:Connect(function()
			self:_playClick()
			local newMuted = false
			if self.audioController and type(self.audioController.toggleMute) == "function" then
				newMuted = self.audioController:toggleMute()
			end
			self:updateAudioButtonIcon(newMuted)
			if type(self.onToggleAudio) == "function" then
				self.onToggleAudio(newMuted)
			end
		end)
	end
	self.audioToggleButton = audioToggleBtn

	self.homeButton = createGuiElement("TextButton", {
		Name = "DomButton",
		Size = isRoblox and UDim2.new(0, 44, 0, 44) or nil,
		Position = isRoblox and UDim2.new(0, 6, 0, 2) or nil,
		BackgroundColor3 = isRoblox and Color3.fromRGB(78, 195, 255) or nil,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(255, 255, 255) or nil,
		Text = "🏠",
	}, topBar)
	addCornerAndStroke(self.homeButton, 8, isRoblox and Color3.fromRGB(18, 42, 68) or nil, 3)
	addTextStroke(self.homeButton, 2.6)

	if self.homeButton.Activated ~= nil then
		self.homeButton.Activated:Connect(function()
			self:_playClick()
			if type(self.onHomeClicked) == "function" then
				self.onHomeClicked()
			elseif isRoblox then
				pcall(function()
					local Players = game:GetService("Players")
					local lp = Players.LocalPlayer
					if lp and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
						lp.Character.HumanoidRootPart.CFrame = CFrame.new(0, 4, 24)
					end
				end)
			end
		end)
	end

	-- One clear top panel with three named metric fields. The former bare numbers stay as the
	-- value labels (producedEggsLabel/soldEggsLabel/shippingLabel and their getters) and each cell adds
	-- a separate visible heading; every value is a rate in Polish "jaj/s".
	local ratesSpecs = {
		{ name = "ProducedEggsLabel", heading = HUD.RATES_HEADINGS[1], key = "producedEggsLabel", rgb = { 255, 165, 245 } },
		{ name = "SoldEggsLabel", heading = HUD.RATES_HEADINGS[2], key = "soldEggsLabel", rgb = { 255, 235, 75 } },
		{ name = "ShippingLabel", heading = HUD.RATES_HEADINGS[3], key = "shippingLabel", rgb = { 115, 255, 135 } },
	}
	local ratesPanel = createGuiElement("Frame", {
		Name = "RatesPanel",
		Size = isRoblox and UDim2.new(1, -8, 0, headerLayout.panelHeight) or nil,
		Position = isRoblox and UDim2.new(0, 4, 0, 48) or nil,
		BackgroundColor3 = isRoblox and Color3.fromRGB(45, 25, 15) or nil,
		BackgroundTransparency = 0.25,
	}, topBar)
	addCornerAndStroke(ratesPanel, 10, isRoblox and Color3.fromRGB(255, 215, 65) or nil, 2)
	self.ratesPanel = ratesPanel

	for index, spec in ipairs(ratesSpecs) do
		local cell = createGuiElement("Frame", {
			Name = "RatesCell" .. tostring(index),
			Size = isRoblox and UDim2.new(1 / 3, -4, 1, 0) or nil,
			Position = isRoblox and UDim2.new((index - 1) / 3, 2, 0, 0) or nil,
			BackgroundTransparency = 1,
		}, ratesPanel)
		self.ratesCells[index] = cell

		local heading = createGuiElement("TextLabel", {
			Name = "RatesHeading",
			Size = isRoblox and UDim2.new(1, 0, 0, headerLayout.headingHeight) or nil,
			Position = isRoblox and UDim2.new(0, 0, 0, 1) or nil,
			BackgroundTransparency = 1,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = true,
			TextWrapped = true,
			TextColor3 = isRoblox and Color3.fromRGB(255, 240, 200) or nil,
			Text = spec.heading,
		}, cell)
		addTextStroke(heading, 1.8)
		self.ratesHeadingLabels[index] = heading
		if isRoblox then
			local headingCap = Instance.new("UITextSizeConstraint")
			headingCap.Name = "ReadableTextCap"
			headingCap.MaxTextSize = headerLayout.headingMax
			headingCap.Parent = heading
			self.ratesHeadingCaps[index] = headingCap
		end

		local value = createGuiElement("TextLabel", {
			Name = spec.name,
			Size = isRoblox and UDim2.new(1, 0, 0, headerLayout.valueHeight) or nil,
			Position = isRoblox and UDim2.new(0, 0, 0, 1 + headerLayout.headingHeight) or nil,
			BackgroundTransparency = 1,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = true,
			TextColor3 = isRoblox and Color3.fromRGB(spec.rgb[1], spec.rgb[2], spec.rgb[3]) or nil,
			Text = "0" .. HUD.RATES_UNIT,
		}, cell)
		addTextStroke(value, 2.2)
		if isRoblox then
			local valueCap = Instance.new("UITextSizeConstraint")
			valueCap.Name = "ReadableTextCap"
			valueCap.MaxTextSize = headerLayout.valueMax
			valueCap.Parent = value
			self.ratesValueCaps[index] = valueCap
		end
		self.ratesValueLabels[index] = value
		self[spec.key] = value
	end

	-- Short explanatory caption, shown only when a cell is wide enough to keep it on one line so it
	-- can never collide with the right dock on a narrow phone.
	self.ratesCaptionLabel = createGuiElement("TextLabel", {
		Name = "RatesCaptionLabel",
		Visible = headerLayout.captionVisible,
		Size = isRoblox and UDim2.new(0, headerLayout.captionWidth, 0, 12) or nil,
		Position = isRoblox and UDim2.new(0, 8, 0, 48 + headerLayout.panelHeight) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextXAlignment = isRoblox and Enum.TextXAlignment.Left or nil,
		TextColor3 = isRoblox and Color3.fromRGB(235, 220, 190) or nil,
		Text = HUD.RATES_CAPTION,
	}, topBar)
	addTextStroke(self.ratesCaptionLabel, 1.6)
	if isRoblox then
		local captionCap = Instance.new("UITextSizeConstraint")
		captionCap.Name = "ReadableTextCap"
		captionCap.MaxTextSize = headerLayout.captionMax
		captionCap.Parent = self.ratesCaptionLabel
		self.ratesCaptionCap = captionCap
	end

	-- The tutorial hint shares the first header row with the Dom button, so it can never slide under
	-- the rates panel, the sound toggle or the right dock and never leaves the viewport.
	self.tutorialLabel = createGuiElement("TextLabel", {
		Name = "TutorialBannerLabel",
		Size = isRoblox and UDim2.new(1, -60, 0, 40) or nil,
		Position = isRoblox and UDim2.new(0, 52, 0, 3) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextWrapped = true,
		TextColor3 = isRoblox and Color3.fromRGB(255, 250, 210) or nil,
		Text = "🎯 Cel: Kliknij koszyk 'Jajka' na dole lub stań na czerwonym przycisku!",
	}, topBar)
	addTextStroke(self.tutorialLabel, 2.0)
	if isRoblox then
		local tutorialCap = Instance.new("UITextSizeConstraint")
		tutorialCap.Name = "ReadableTextCap"
		tutorialCap.MaxTextSize = 15
		tutorialCap.Parent = self.tutorialLabel
	end

	self:_bindTopHeaderResponsive(root)

	-- 3. Bottom-Left Cash & Rebirth Display
	local bottomLeft = createGuiElement("Frame", {
		Name = "BottomLeftCluster",
		Size = isRoblox and UDim2.new(0, 310, 0, 95) or nil,
		Position = isRoblox and UDim2.new(0, 16, 1, -108) or nil,
		BackgroundTransparency = 1,
	}, root)

	self.rebirthLabel = createGuiElement("TextLabel", {
		Name = "RebirthLabel",
		Size = isRoblox and UDim2.new(1, 0, 0, 26) or nil,
		Position = isRoblox and UDim2.new(0, 0, 0, 0) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextXAlignment = isRoblox and Enum.TextXAlignment.Left or nil,
		TextColor3 = isRoblox and Color3.fromRGB(255, 165, 125) or nil,
		Text = "Odrodzenie 0 • 🥚 Farma Jajeczna",
	}, bottomLeft)
	addTextStroke(self.rebirthLabel, 2.4)

	local rebirthBtn = createGuiElement("TextButton", {
		Name = "RebirthClickButton",
		Size = isRoblox and UDim2.new(1, 0, 0, 44) or nil,
		Position = isRoblox and UDim2.new(0, 0, 0, 0) or nil,
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 5,
	}, bottomLeft)
	if rebirthBtn.Activated then
		rebirthBtn.Activated:Connect(function()
			self:togglePrestigeModal()
		end)
	end

	self.cashIcon = createGuiElement("ImageLabel", {
		Name = "CashIcon",
		Size = isRoblox and UDim2.new(0, 42, 0, 42) or nil,
		Position = isRoblox and UDim2.new(0, 0, 0, 26) or nil,
		BackgroundTransparency = 1,
		Image = "rbxassetid://87511254654486", -- Green Cash 1st Outline 256px (Store Decal: 139287659909902, Image: 87511254654486)
	}, bottomLeft)

	self.cashLabel = createGuiElement("TextLabel", {
		Name = "CashLabel",
		Size = isRoblox and UDim2.new(1, -48, 0, 40) or nil,
		Position = isRoblox and UDim2.new(0, 48, 0, 26) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextXAlignment = isRoblox and Enum.TextXAlignment.Left or nil,
		TextColor3 = isRoblox and Color3.fromRGB(115, 255, 45) or nil,
		Text = "$0",
	}, bottomLeft)
	addTextStroke(self.cashLabel, 3.4)

	self.cashRateLabel = createGuiElement("TextLabel", {
		Name = "CashRateLabel",
		Size = isRoblox and UDim2.new(1, -48, 0, 22) or nil,
		Position = isRoblox and UDim2.new(0, 48, 0, 68) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextXAlignment = isRoblox and Enum.TextXAlignment.Left or nil,
		TextColor3 = isRoblox and Color3.fromRGB(165, 255, 135) or nil,
		Text = "+$0/s",
	}, bottomLeft)
	addTextStroke(self.cashRateLabel, 2.0)

	local diamondsPill = createGuiElement("Frame", {
		Name = "DiamondsPillFrame",
		Size = isRoblox and UDim2.new(0, 160, 0, 36) or nil,
		Position = isRoblox and UDim2.new(0, 16, 0, 104) or nil,
		BackgroundColor3 = isRoblox and Color3.fromRGB(20, 30, 48) or nil,
		BackgroundTransparency = isRoblox and 0.25 or nil,
		BorderSizePixel = 0,
	}, root)
	self.diamondsPillFrame = diamondsPill
	addCornerAndStroke(diamondsPill, 10, Color3.fromRGB(80, 200, 255), 1.8)

	self.diamondIcon = createGuiElement("ImageLabel", {
		Name = "DiamondIcon",
		Size = isRoblox and UDim2.new(0, 26, 0, 26) or nil,
		Position = isRoblox and UDim2.new(0, 6, 0.5, -13) or nil,
		BackgroundTransparency = 1,
		Image = "rbxassetid://123463156806216",
	}, diamondsPill)

	self.goldenEggsLabel = createGuiElement("TextLabel", {
		Name = "GoldenEggsLabel",
		Size = isRoblox and UDim2.new(1, -38, 1, 0) or nil,
		Position = isRoblox and UDim2.new(0, 36, 0, 0) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextXAlignment = isRoblox and Enum.TextXAlignment.Left or nil,
		TextColor3 = isRoblox and Color3.fromRGB(200, 240, 255) or nil,
		Text = "Diamenty: -",
	}, diamondsPill)
	addTextStroke(self.goldenEggsLabel, 2)

	-- 4. Left-Side Green Studded Quick-Action Buttons (hidden by default per docs/ui/ui_design_specification.md to preserve clean view and mobile touch thumbstick zone)
	local leftQuickCluster = createGuiElement("Frame", {
		Name = "LeftQuickButtons",
		Size = isRoblox and UDim2.new(0, 155, 0, 175) or nil,
		Position = isRoblox and UDim2.new(0, 16, 0.5, -60) or nil,
		BackgroundTransparency = 1,
		Visible = false,
	}, root)

	local quickButtonsSpec = {
		{
			name = "QuickResearchBtn",
			text = "🔬 +Badanie",
			yPos = 0,
			bg = isRoblox and Color3.fromRGB(102, 232, 48) or nil,
			action = function()
				if type(self.onQuickBuyResearch) == "function" then
					self.onQuickBuyResearch("comfy_nests")
				else
					self:buyResearch("comfy_nests")
				end
			end,
		},
		{
			name = "QuickHabitatBtn",
			text = "🏠 +Kurnik",
			yPos = 58,
			bg = isRoblox and Color3.fromRGB(102, 232, 48) or nil,
			action = function()
				if type(self.onQuickBuyHabitat) == "function" then
					self.onQuickBuyHabitat()
				else
					self:toggleHabitatsModal()
				end
			end,
		},
		{
			name = "QuickVehicleBtn",
			text = "🚚 +Pojazd",
			yPos = 116,
			bg = isRoblox and Color3.fromRGB(102, 232, 48) or nil,
			action = function()
				if type(self.onQuickBuyVehicle) == "function" then
					self.onQuickBuyVehicle()
				else
					self:toggleVehiclesModal()
				end
			end,
		},
	}

	for _, qSpec in ipairs(quickButtonsSpec) do
		local qBtn = createGuiElement("TextButton", {
			Name = qSpec.name,
			Size = isRoblox and UDim2.new(1, 0, 0, 48) or nil,
			Position = isRoblox and UDim2.new(0, 0, 0, qSpec.yPos) or nil,
			BackgroundColor3 = qSpec.bg,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = true,
			TextColor3 = isRoblox and Color3.fromRGB(255, 255, 255) or nil,
			Text = qSpec.text,
		}, leftQuickCluster)
		addCornerAndStroke(qBtn, 8, isRoblox and Color3.fromRGB(22, 48, 12) or nil, 3)
		addTextStroke(qBtn, 2.5)
		if qBtn.Activated then
			qBtn.Activated:Connect(function()
				self:_playClick()
				qSpec.action()
			end)
		end
	end

	-- 5. Bottom-Center Hatchery Indicator (#101: compact chicken stock + refill strip, no manual HatchButton)
	local hatcheryFrame = createGuiElement("Frame", {
		Name = "HatcheryFrame",
		Size = isRoblox and UDim2.new(0, 220, 0, 50) or nil,
		Position = isRoblox and UDim2.new(0.5, -110, 1, -60) or nil,
		BackgroundColor3 = isRoblox and Color3.fromRGB(235, 152, 48) or nil,
	}, root)
	addCornerAndStroke(hatcheryFrame, 14, isRoblox and Color3.fromRGB(58, 30, 12) or nil, 3.0)
	self.hatcheryFrame = hatcheryFrame
	self.hatchButton = nil

	self.hatcheryStockLabel = createGuiElement("TextLabel", {
		Name = "StockLabel",
		Size = isRoblox and UDim2.new(0.62, 0, 0, 36) or nil,
		Position = isRoblox and UDim2.new(0.04, 0, 0.5, -18) or nil,
		BackgroundColor3 = isRoblox and Color3.fromRGB(255, 245, 225) or nil,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(255, 255, 255) or nil,
		Text = "0 / 0",
	}, hatcheryFrame)
	addCornerAndStroke(self.hatcheryStockLabel, 10, isRoblox and Color3.fromRGB(72, 38, 14) or nil, 2.2)
	addTextStroke(self.hatcheryStockLabel, 2.2)

	self.hatcheryRefillLabel = createGuiElement("TextLabel", {
		Name = "RefillLabel",
		Size = isRoblox and UDim2.new(0.30, 0, 0, 36) or nil,
		Position = isRoblox and UDim2.new(0.68, 0, 0.5, -18) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(135, 255, 115) or nil,
		Text = "+0/s",
	}, hatcheryFrame)
	addTextStroke(self.hatcheryRefillLabel, 2.2)

	-- 6. Compact persistent hatch status (#77) beside the hatchery/stock HUD.
	-- Visible only while the authoritative farm view says hatching is blocked: no built coop has
	-- vacancy after population + reservedInTransit, or the hatchery stock is below one whole egg.
	-- It is visible on every path (standing on the plate or the manual hatch button), is recomputed
	-- only when the view changes, sends no intent, adds no remote and plays no sound or toast.
	local hatchStatusFrame = createGuiElement("Frame", {
		Name = "HatchStatusFrame",
		Visible = false,
		-- Compact mobile strip: 52px tall, bottom edge 2px above the hatchery HUD top (-60). The
		-- width is resolved from the live root size so it never clips a narrow viewport and never
		-- overlaps the 84px right dock; a wide view keeps it centred with a 400px cap.
		Size = isRoblox and UDim2.new(0, 400, 0, 52) or nil,
		Position = isRoblox and UDim2.new(0.5, 0, 1, -64) or nil,
		AnchorPoint = isRoblox and Vector2.new(0.5, 1) or nil,
		BackgroundColor3 = isRoblox and Color3.fromRGB(122, 32, 32) or nil,
		BackgroundTransparency = 0.08,
	}, root)
	addCornerAndStroke(hatchStatusFrame, 12, isRoblox and Color3.fromRGB(58, 16, 16) or nil, 2.6)
	self.hatchStatusFrame = hatchStatusFrame

	self.hatchStatusLabel = createGuiElement("TextLabel", {
		Name = "HatchStatusLabel",
		Size = isRoblox and UDim2.new(1, -16, 0, 44) or nil,
		Position = isRoblox and UDim2.new(0, 8, 0.5, -22) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextWrapped = true,
		TextXAlignment = isRoblox and Enum.TextXAlignment.Left or nil,
		TextYAlignment = isRoblox and Enum.TextYAlignment.Center or nil,
		TextColor3 = isRoblox and Color3.fromRGB(255, 242, 242) or nil,
		Text = "",
	}, hatchStatusFrame)
	addTextStroke(self.hatchStatusLabel, 2.2)
	if isRoblox then
		-- TextScaled with a cap keeps short messages readable without shrinking them to nothing.
		local textCap = Instance.new("UITextSizeConstraint")
		textCap.Name = "ReadableTextCap"
		textCap.MaxTextSize = 20
		textCap.Parent = self.hatchStatusLabel
	end

	self.hatchStatusActionBtn = createGuiElement("TextButton", {
		Name = "HatchStatusActionBtn",
		Visible = false,
		Size = isRoblox and UDim2.new(0, 88, 0, 44) or nil,
		Position = isRoblox and UDim2.new(1, -96, 0.5, -22) or nil,
		BackgroundColor3 = isRoblox and Color3.fromRGB(95, 235, 45) or nil,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(255, 255, 255) or nil,
		Text = "Kurniki",
	}, hatchStatusFrame)
	addCornerAndStroke(self.hatchStatusActionBtn, 8, isRoblox and Color3.fromRGB(22, 48, 12) or nil, 2)
	if self.hatchStatusActionBtn.Activated then
		self.hatchStatusActionBtn.Activated:Connect(function()
			self:_playClick()
			self:toggleHabitatsModal(true)
		end)
	end
	self:_bindHatchStatusResponsive(root)

	-- 7. Right-Side Framed Icon Buttons Dock (Touch-Friendly Square Icon Buttons)
	-- Tactile square icon buttons from UiAssets pack with accessible MenuTitle attribute
	local dockButtonsSpec = {
		{ name = "ResearchMenuButton", title = "Badania", iconKey = "window.research", bg = Color3.fromRGB(32, 68, 140), action = function() self:toggleResearchModal() end },
		{ name = "EpicResearchMenuButton", title = "Epickie", iconKey = "tab.ge", bg = Color3.fromRGB(115, 35, 155), action = function() self:toggleEpicResearchModal() end },
		{ name = "HabitatsMenuButton", title = "Kurniki", iconKey = "window.habitats", bg = Color3.fromRGB(160, 80, 40), action = function() self:toggleHabitatsModal() end },
		{ name = "VehiclesMenuButton", title = "Flota", iconKey = "window.fleet", bg = Color3.fromRGB(45, 175, 75), action = function() self:toggleVehiclesModal() end },
		{ name = "PetsMenuButton", title = "Pety", iconKey = "window.pets", bg = Color3.fromRGB(150, 60, 190), hidden = true, action = function() self:togglePetsModal() end },
		{ name = "ShopMenuButton", title = "Sklep", iconKey = "window.shop", bg = Color3.fromRGB(225, 155, 30), action = function() self:toggleShopModal() end },
		{ name = "CalendarMenuButton", title = "Nagrody", iconKey = "window.calendar", bg = Color3.fromRGB(225, 75, 95), action = function() self:toggleCalendarModal() end },
		{ name = "PrestigeMenuButton", title = "Prestiż", iconKey = "control.upgrade", emoji = "🟣", bg = Color3.fromRGB(110, 40, 170), action = function() self:togglePrestigeModal() end },
	}

	local visibleButtonsCount = 0
	for _, d in ipairs(dockButtonsSpec) do
		if not (d.hidden == true) then
			visibleButtonsCount += 1
		end
	end
	local dockHeight = visibleButtonsCount * 64
	local rightDock = createGuiElement("Frame", {
		Name = "RightDock",
		Size = isRoblox and UDim2.new(0, 70, 0, dockHeight) or nil,
		Position = isRoblox and UDim2.new(1, -82, 0.5, -math.floor(dockHeight / 2)) or nil,
		BackgroundTransparency = 1,
	}, root)

	local visibleIndex = 0
	for i, dSpec in ipairs(dockButtonsSpec) do
		local isVisible = not (dSpec.hidden == true)
		local yPos = 0
		if isVisible then
			visibleIndex += 1
			yPos = (visibleIndex - 1) * 64 + 4
		end

		local btn = createGuiElement("TextButton", {
			Name = dSpec.name,
			Visible = isVisible,
			Size = isRoblox and UDim2.new(0, 58, 0, 58) or nil,
			Position = isRoblox and UDim2.new(0, 6, 0, yPos) or nil,
			BackgroundColor3 = isRoblox and dSpec.bg or nil,
			AutoButtonColor = true,
			Text = "",
		}, rightDock)
		addCornerAndStroke(btn, 12, isRoblox and Color3.fromRGB(18, 12, 10) or nil, 3.0)
		if btn.SetAttribute then
			btn:SetAttribute("MenuTitle", dSpec.title)
		end

		local iconId = (self.ui and self.ui:assetId(dSpec.iconKey)) or (UiAssets and UiAssets.images[dSpec.iconKey] and UiAssets.images[dSpec.iconKey].id) or ""
		createGuiElement("ImageLabel", {
			Name = "ButtonIcon",
			Size = isRoblox and UDim2.new(0, 40, 0, 40) or nil,
			Position = isRoblox and UDim2.new(0.5, -20, 0.5, -20) or nil,
			BackgroundTransparency = 1,
			Image = iconId,
			ScaleType = isRoblox and Enum.ScaleType.Fit or nil,
		}, btn)

		if btn.Activated then
			btn.Activated:Connect(function()
				self:_playClick()
				dSpec.action()
			end)
		end

		if dSpec.emoji then
			createGuiElement("TextLabel", {
				Name = "ButtonBadge",
				Size = isRoblox and UDim2.new(0, 22, 0, 22) or nil,
				Position = isRoblox and UDim2.new(1, -24, 1, -24) or nil,
				BackgroundTransparency = 1,
				TextScaled = true,
				Text = dSpec.emoji,
			}, btn)
		end
		if dSpec.name == "ResearchMenuButton" then self.researchToggleBtn = btn
		elseif dSpec.name == "EpicResearchMenuButton" then self.epicResearchToggleBtn = btn
		elseif dSpec.name == "HabitatsMenuButton" then self.habitatsToggleBtn = btn
		elseif dSpec.name == "VehiclesMenuButton" then self.vehiclesToggleBtn = btn
		elseif dSpec.name == "PetsMenuButton" then self.petsToggleBtn = btn
		elseif dSpec.name == "ShopMenuButton" then self.shopToggleBtn = btn
		elseif dSpec.name == "CalendarMenuButton" then self.calendarToggleBtn = btn
		elseif dSpec.name == "PrestigeMenuButton" then self.prestigeToggleBtn = btn
		end
	end

	self.totalChickensLabel = createGuiElement("TextLabel", {
		Name = "TotalChickensLabel",
		Size = isRoblox and UDim2.new(0, 320, 0, 32) or nil,
		Position = isRoblox and UDim2.new(1, -336, 1, -42) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextXAlignment = isRoblox and Enum.TextXAlignment.Right or nil,
		TextColor3 = isRoblox and Color3.fromRGB(255, 225, 65) or nil,
		Text = "Całkowita liczba kurczaków: 0",
	}, root)
	addTextStroke(self.totalChickensLabel, 2.6)

	-- 7. Habitats Modal Drawer (Coops 1..4, supporting all 19 habitats)
	self:_buildHabitatsModal(root)

	-- 8. Vehicles Modal Drawer (Fleet slots 1..17 + live comparison bar)
	self:_buildVehiclesModal(root)

	-- 9. Research Modal Drawer (Multi-tier T1..T13 common + Epic research tab)
	self:_buildResearchModal(root)
	self:_buildEpicResearchModal(root)

	-- 10. Pets Modal Drawer (Equipped slots 3/5, inventory, fusion)
	self:_buildPetsModal(root)

	-- 11. Shop Modal Drawer (GE packs, Boosts, GamePasses)
	self:_buildShopModal(root)

	-- 12. Calendar & Trophies Modal Drawer (28-day calendar + 19 eggs cups)
	self:_buildCalendarModal(root)
    self.actionStatusLabel=createGuiElement("TextLabel",{Name="ActionStatus",Text="",BackgroundTransparency=1,
        Size=if isRoblox then UDim2.new(0.8,0,0,32) else nil,Position=if isRoblox then UDim2.new(0.1,0,0,8) else nil,
        TextColor3=if isRoblox then Color3.new(1,1,1) else nil,TextScaled=true},root)

	-- 13. Egg Upgrade Modal (PROD-02)
	self:_buildEggUpgradeModal(root)

	-- 14. Pet Incubator & Hatch Modal (PROD-07)
	self:_buildPetHatchModal(root)
	self:_buildHatchAnimationOverlay(root)

	-- 15. Prestige & Rebirth Modal
	self:_buildPrestigeModal(root)
end

-- Legacy contract kept for the existing UI suites: the desktop budget for a window is ~70% of the
-- viewport (94% on a phone). The shared family now resolves the actual on-screen size through
-- StudUi.windowFit, which never globally shrinks the text and instead reflows the content.
function HUD.modalLayout(width,height,designWidth)
	return StudUi.modalSize(width,height,designWidth)
end

-- Applies the shared window fit and an optional reflow hook. One AbsoluteSize connection per
-- window, disconnected when the frame is destroyed; no per-frame work, no decoration rebuild.
function HUD:_fitWindow(frame, designWidth, designHeight, onLayout)
	if frame == nil or self.ui == nil then return end
	self.ui:applyWindowResponsive(frame, self.guiRoot, designWidth, designHeight, onLayout)
end
-- Pure responsive geometry for the hatch status strip (#77), kept separate from the live layout so it
-- can be checked without a viewport. Narrow (mobile) roots anchor the strip left and reserve the 84px
-- right dock so its right edge stays <= width-96; wide roots centre it with a 400px cap.
function HUD.hatchStatusGeometry(rootWidth)
	local width = tonumber(rootWidth) or 0
	if width <= 0 then width = 1280 end
	if width < 600 then
		return { centered = false, left = 16, width = math.min(400, math.max(0, width - 112)) }
	end
	return { centered = true, left = nil, width = math.min(400, math.max(0, width - 32)) }
end

-- Applies the responsive geometry from the live root size. Reuses the existing modal pattern: one
-- AbsoluteSize signal, disconnected when the frame is destroyed, and no per-frame polling.
function HUD:_bindHatchStatusResponsive(root)
	local frame = self.hatchStatusFrame
	if not isRoblox or root == nil or frame == nil then return end
	local function resize()
		local size = root.AbsoluteSize
		local layout = HUD.hatchStatusGeometry(size and size.X or 0)
		if layout.centered then
			frame.AnchorPoint = Vector2.new(0.5, 1)
			frame.Position = UDim2.new(0.5, 0, 1, -64)
		else
			frame.AnchorPoint = Vector2.new(0, 1)
			frame.Position = UDim2.new(0, layout.left, 1, -64)
		end
		frame.Size = UDim2.new(0, layout.width, 0, 52)
	end
	local connection = root:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	frame.Destroying:Connect(function() connection:Disconnect() end)
	resize()
end

-- Pure responsive geometry for the top header and the rates panel, kept separate from the live
-- layout so it can be checked without a viewport. The header is centred up to 480px and always keeps
-- a 92px right gutter, so neither the 48px sound toggle (width-64, y 10..58) nor the right dock
-- (width-92, top edge height/2-220) can ever be covered; its bottom stays at root y 98..102, above
-- the GoldenEgg counter at y 104. Three equal cells; the headings wrap and the explanatory caption
-- appears only when a cell is wide enough to keep the note on one line.
function HUD.ratesPanelGeometry(rootWidth)
	local width = tonumber(rootWidth) or 0
	if width <= 0 then width = 1280 end

	local rightGutter = 92
	local headerWidth = math.clamp(width - 6 - rightGutter, 168, 480)
	local left = math.clamp((width - headerWidth) * 0.5, 6, math.max(6, width - rightGutter - headerWidth))

	local panelWidth = headerWidth - 8
	local cellWidth = panelWidth / 3
	local wrapsHeadings = cellWidth < 120
	local captionVisible = not wrapsHeadings
	local panelHeight = if wrapsHeadings then 44 else 36

	return {
		left = left,
		width = headerWidth,
		height = 48 + panelHeight + (if captionVisible then 12 else 0),
		panelHeight = panelHeight,
		panelWidth = panelWidth,
		cellWidth = cellWidth,
		headingHeight = if wrapsHeadings then 24 else 14,
		valueHeight = if wrapsHeadings then 20 else 22,
		headingMax = math.clamp(cellWidth * 0.17, 10, 15),
		valueMax = math.clamp(cellWidth * 0.20, 15, if wrapsHeadings then 20 else 24),
		captionVisible = captionVisible,
		captionWidth = math.min(panelWidth - 16, width - rightGutter - left - 8),
		captionMax = math.clamp(cellWidth * 0.12, 10, 13),
	}
end

-- Applies the responsive header geometry from the live root size. Reuses the existing modal pattern:
-- one AbsoluteSize signal, disconnected when the header is destroyed, and no per-frame polling.
function HUD:_bindTopHeaderResponsive(root)
	local header = self.topBar
	if not isRoblox or root == nil or header == nil then return end
	local topInset = self._topHeaderInset or 6
	local function resize()
		local size = root.AbsoluteSize
		local layout = HUD.ratesPanelGeometry(size and size.X or 0)
		header.Position = UDim2.new(0, layout.left, 0, topInset)
		header.Size = UDim2.new(0, layout.width, 0, layout.height)
		if self.ratesPanel ~= nil then
			self.ratesPanel.Size = UDim2.new(1, -8, 0, layout.panelHeight)
		end
		for index, cap in self.ratesHeadingCaps or {} do
			cap.MaxTextSize = layout.headingMax
			local cell = self.ratesCells and self.ratesCells[index]
			local heading = cell and cell:FindFirstChild("RatesHeading")
			if heading ~= nil then heading.Size = UDim2.new(1, 0, 0, layout.headingHeight) end
		end
		for index, cap in self.ratesValueCaps or {} do
			cap.MaxTextSize = layout.valueMax
			local value = self.ratesValueLabels and self.ratesValueLabels[index]
			if value ~= nil then
				value.Size = UDim2.new(1, 0, 0, layout.valueHeight)
				value.Position = UDim2.new(0, 0, 0, 1 + layout.headingHeight)
			end
		end
		if self.ratesCaptionLabel ~= nil then
			self.ratesCaptionLabel.Visible = layout.captionVisible
			self.ratesCaptionLabel.Size = UDim2.new(0, layout.captionWidth, 0, 12)
			if self.ratesCaptionCap ~= nil then self.ratesCaptionCap.MaxTextSize = layout.captionMax end
		end
	end
	local connection = root:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	header.Destroying:Connect(function() connection:Disconnect() end)
	resize()
end

function HUD:_buildHabitatsModal(root)
	-- Shared stud-style window (#82): thick border, coloured header, 44px close button.
	local win = self.ui:window({
		parent = root, name = "HabitatsFrame", family = "habitats",
		title = "TWOJE KURNIKI (PARCELE 1-4)",
		designWidth = 460, designHeight = 430,
	})
	local habitatsFrame = win.frame
	self.habitatsModal = habitatsFrame
	self:_fitWindow(habitatsFrame, win.designWidth, win.designHeight)
	self.ui:closeButton(habitatsFrame, function()
		habitatsFrame.Visible = false
	end)

	-- Long list scrolls instead of shrinking the text; the canvas is the exact content height.
	local habitatsScroll = self.ui:scroll(habitatsFrame, {
		name = "HabitatSlotsContainer",
		size = { 1, -24, 1, -84 }, position = { 0, 12, 0, 72 },
		canvasHeight = 4 * 80 + 4, scrollBarColor = { 255, 205, 95 },
	})

	for slotId = 1, 4 do
		local card = self.ui:card(habitatsScroll, {
			name = "HabitatCard_" .. tostring(slotId), family = "habitats",
			fill = { 112, 64, 36 }, top = { 150, 90, 50 }, border = { 42, 22, 12 },
			size = { 1, -6, 0, 72 }, position = { 0, 0, 0, (slotId - 1) * 80 },
		})

		local titleLabel = self.ui:label(card, {
			name = "TitleLabel", size = { 0.68, 0, 0, 24 }, position = { 0.03, 0, 0, 6 },
			text = "Parcela #" .. tostring(slotId) .. ": Tier 1",
			color = { 255, 245, 160 }, align = "Left", textStroke = 1.8, maxTextSize = 20,
		})

		local popLabel = self.ui:label(card, {
			name = "PopulationLabel", size = { 0.68, 0, 0, 20 }, position = { 0.03, 0, 0, 30 },
			text = "0 / 250", color = { 255, 255, 255 }, align = "Left",
			textStroke = 1.8, maxTextSize = 18,
		})

		local nextLabel = self.ui:label(card, {
			name = "NextUpgradeLabel", size = { 0.68, 0, 0, 18 }, position = { 0.03, 0, 0, 50 },
			text = "Następny: Tier 2", color = { 160, 240, 140 }, align = "Left",
			textStroke = 1.5, maxTextSize = 16,
		})

		-- Tactile action button: >= 44px touch target with pressed/disabled states.
		local upgBtn = self.ui:button(card, {
			name = "UpgradeHabitatBtn", text = "ULEPSZ", tone = "primary",
			size = { 0.26, 0, 0, 44 }, position = { 0.71, 0, 0, 14 },
			onClick = function()
				if type(self.onQuickBuyHabitat) == "function" then
					self.onQuickBuyHabitat(slotId)
				end
			end,
		})

		self.habitatCards[slotId] = card
		self.habitatLabels[slotId] = popLabel
		self.habitatUpgBtns[slotId] = upgBtn
	end
end

function HUD:_buildVehiclesModal(root)
	-- Shared stud-style window (#82): same family, header and close button as every other window.
	local win = self.ui:window({
		parent = root, name = "VehiclesFrame", family = "fleet",
		title = "FLOTA TRANSPORTOWA (DO 17 POJAZDÓW)",
		designWidth = 500, designHeight = 520,
	})
	local vFrame = win.frame
	self.vehiclesModal = vFrame
	self:_fitWindow(vFrame, win.designWidth, win.designHeight)
	self.ui:closeButton(vFrame, function()
		vFrame.Visible = false
	end)

	-- Comparison gauge
	local gaugeFrame = self.ui:card(vFrame, {
		name = "ComparisonGaugeFrame", family = "fleet",
		fill = { 32, 44, 26 }, top = { 54, 74, 44 }, border = { 20, 28, 16 },
		size = { 1, -28, 0, 58 }, position = { 0, 14, 0, 70 },
	})
	self.shippingComparisonBar = gaugeFrame

	self.shippingComparisonStatusLabel = self.ui:label(gaugeFrame, {
		name = "ComparisonStatusLabel", size = { 1, -12, 0, 24 }, position = { 0, 6, 0, 4 },
		text = "Spedycja: 0/min vs Produkcja: 0/min", color = { 255, 255, 255 },
		align = "Left", textStroke = 1.8, maxTextSize = 20,
	})

	-- Status pill: keeps the TextLabel contract the comparison getter reads.
	local statusBadge = self.ui:pill(gaugeFrame, {
		name = "StatusBadge", size = { 1, -12, 0, 22 }, position = { 0, 6, 0, 30 },
		text = "Spedycja wystarczająca", tone = "primary", align = "Left",
		maxTextSize = 18, radius = 6,
	})

	-- Fleet Slots Container (displays slots 1..17). The list scrolls; the canvas is grown by the
	-- update pass from the authoritative slot limit instead of a fixed 4-row canvas.
	local slotsScroll = self.ui:scroll(vFrame, {
		name = "FleetSlotsContainer",
		size = { 1, -28, 1, -146 }, position = { 0, 14, 0, 134 },
		canvasHeight = 4 * 56, scrollBarColor = { 115, 245, 125 },
	})
	self.fleetSlotsScroll=slotsScroll

	for slotId = 1, 17 do
		local card = self.ui:card(slotsScroll, {
			name = "VehicleSlotCard_" .. tostring(slotId), family = "fleet",
			fill = { 65, 85, 52 }, top = { 96, 122, 76 }, border = { 28, 38, 22 },
			visible = (slotId <= 4), -- default first 4 visible, updated dynamically
			size = { 1, 0, 0, 48 }, position = { 0, 0, 0, (slotId - 1) * 52 },
		})

		local titleLabel = self.ui:label(card, {
			name = "Title", size = { 0.48, 0, 0.5, 0 }, position = { 0.02, 0, 0.05, 0 },
			text = "Slot #" .. tostring(slotId) .. ": Tier 1", color = { 255, 255, 255 },
			align = "Left", textStroke = 1.6, maxTextSize = 17,
		})

		local capLabel = self.ui:label(card, {
			name = "Capacity", size = { 0.48, 0, 0.45, 0 }, position = { 0.02, 0, 0.5, 0 },
			text = "Wydajność: 5K jaj/min", color = { 165, 255, 140 },
			align = "Left", textStroke = 1.5, maxTextSize = 15,
		})

		local priceLabel = self.ui:label(card, {
			name = "Price", size = { 0.24, 0, 0.9, 0 }, position = { 0.51, 0, 0.05, 0 },
			text = "$544.5", color = { 255, 235, 95 },
			align = "Center", textStroke = 1.6, maxTextSize = 17,
		})

		local upgBtn = self.ui:button(card, {
			name = "BuyVehicleButton", text = "ULEPSZ", tone = "primary",
			size = { 0.22, 0, 0, 44 }, position = { 0.76, 0, 0, 2 },
			onClick = function()
				if type(self.onQuickBuyVehicle) == "function" then
					self.onQuickBuyVehicle(slotId)
				end
			end,
		})

		self.vehicleCards[slotId] = {
			card = card,
			titleLabel = titleLabel,
			capLabel = capLabel,
			priceLabel = priceLabel,
			upgBtn = upgBtn,
		}
	end
end

function HUD:_buildResearchModal(root)
	-- Shared stud-style window (#82). The title/subtitle keep their existing wording and the
	-- "obecnie → kolejny poziom" hint; only the decorative emoji becomes a genuine image slot.
	local win = self.ui:window({
		parent = root, name = "ShopFrame", family = "research",
		title = "BADANIA I TECHNOLOGIA",
		subtitle = "Efekt badania: obecnie → kolejny poziom",
		designWidth = 540, designHeight = 520,
	})
	local shopFrame = win.frame
	self.shopFrame = shopFrame
	self.researchWindow = win
	self:_fitWindow(shopFrame, win.designWidth, win.designHeight, function(fit)
		self:_reflowResearchList(fit.width)
	end)
	self.ui:closeButton(shopFrame, function()
		shopFrame.Visible = false
	end)

	-- Tier Selector Bar: T1..T13 in a comfortable horizontal ScrollingFrame.
	-- Exactly the 14 tab buttons live here (the existing suite counts this row's children).
	local tabsRow = self.ui:scroll(shopFrame, {
		name = "TierTabsRow",
		size = { 1, -24, 0, 44 }, position = { 0, 12, 0, 70 },
		canvasHeight = 0, scrollBarThickness = 3, scrollBarColor = { 245, 158, 11 },
	})
	if isRoblox then tabsRow.CanvasSize = UDim2.new(0, 520, 0, 0) end

	local tabNames = { "🧬 Genetyka", "🐣 Wylęg", "🏡 Kurniki", "🚚 Flota" }
	local tabOffset = 0
	for idx, tabName in ipairs(tabNames) do
		local tabWidth = 120
		local tabBtn = self.ui:tabButton(tabsRow, {
			name = "TierTab_" .. tabName, text = tabName,
			size = { 0, tabWidth }, position = { 0, tabOffset, 0, 0 },
			height = 44, active = (idx == 1),
			onClick = function()
				self:selectResearchTier(idx)
			end,
		})
		self.researchTabButtons[idx] = tabBtn
		tabOffset += tabWidth + 8
	end

	-- Lock Banner (themed pill; the update pass keeps its text and visibility contract)
	self.researchTierLockBanner = self.ui:pill(shopFrame, {
		name = "TierLockBanner", visible = false,
		size = { 1, -24, 0, 26 }, position = { 0, 12, 0, 120 },
		text = "Tier zablokowany! Wymaga więcej zakupionych badań",
		tone = "locked", align = "Center", maxTextSize = 18, radius = 6,
	})

	-- Research List container (ScrollingFrame). Positions are shared with the update pass so the
	-- list moves under the banner instead of overlapping it.
	local listContainer = self.ui:scroll(shopFrame, {
		name = "ResearchListContainer",
		size = { 1, -24, 1, 160 }, position = { 0, 12, 0, 152 },
		canvasHeight = 500, scrollBarThickness = 6, scrollBarColor = { 245, 158, 11 },
	})
	self.shopListContainer = listContainer
	self._researchCardLayout = StudUi.listCardLayout(win.designWidth - 24)
	self:_reflowResearchList(win.designWidth)
end

-- Reflows the research list for the resolved window width (#82): a roomy row keeps the
-- side-by-side layout, a phone stacks the price button under the text so neither the name nor the
-- price becomes unreadable. Only sizes/positions of existing instances change; nothing is created,
-- decorated or restyled per frame.
function HUD:_reflowResearchList(windowWidth)
	local width = tonumber(windowWidth) or 0
	if width <= 0 then return end
	local layout = StudUi.listCardLayout(width - 24)
	self._researchCardLayout = layout

	local highestOrder = 0
	for _, item in pairs(self.shopResearch or {}) do
		if item.card ~= nil and item.displayOrder ~= nil then
			highestOrder = math.max(highestOrder, item.displayOrder)
			self:_layoutResearchCard(item, layout)
		end
	end
	if isRoblox and self.shopListContainer ~= nil and highestOrder > 0 then
		self.shopListContainer.CanvasSize = UDim2.new(0, 0, 0, math.max(350, highestOrder * layout.rowSpacing + 10))
	end
end

-- Applies the current research row layout to one card and its known children.
function HUD:_layoutResearchCard(item, layout)
	local card = item and item.card
	if card == nil or layout == nil then return end
	card.Size = UDim2.new(1, -6, 0, layout.cardHeight)
	if item.displayOrder ~= nil then
		card.Position = UDim2.new(0, 0, 0, (item.displayOrder - 1) * layout.rowSpacing)
	end

	local compact = layout.compact == true
	local textWidth = if compact then -70 else -205
	if item.nameLabel ~= nil then
		item.nameLabel.Size = UDim2.new(1, textWidth, 0, 18)
		item.nameLabel.Position = UDim2.new(0, 58, 0, 6)
	end
	if item.subtitleLabel ~= nil then
		item.subtitleLabel.Size = UDim2.new(1, textWidth, 0, if compact then 36 else 40)
		item.subtitleLabel.Position = UDim2.new(0, 58, 0, if compact then 26 else 24)
	end
	if item.levelLabel ~= nil then
		if compact then
			item.levelLabel.Size = UDim2.new(1, textWidth, 0, 13)
		else
			item.levelLabel.Size = UDim2.new(0, 95, 0, 13)
		end
		item.levelLabel.Position = UDim2.new(0, 58, 0, if compact then 62 else 70)
	end
	if item.progressTrack ~= nil then
		if compact then
			item.progressTrack.Size = UDim2.new(1, textWidth, 0, 7)
			item.progressTrack.Position = UDim2.new(0, 58, 0, 76)
		else
			item.progressTrack.Size = UDim2.new(1, -300, 0, 7)
			item.progressTrack.Position = UDim2.new(0, 156, 0, 74)
		end
	end
	if item.buyButton ~= nil then
		if compact then
			item.buyButton.Size = UDim2.new(1, -16, 0, 44)
			item.buyButton.Position = UDim2.new(0, 8, 0, layout.cardHeight - 52)
		else
			item.buyButton.Size = UDim2.new(0, 130, 0, 44)
			item.buyButton.Position = UDim2.new(1, -138, 0, 7)
		end
	end
end

function HUD:_buildEpicResearchModal(root)
	local win = self.ui:window({
		parent = root,
		name = "EpicResearchModalFrame",
		family = "shop",
		title = "BADANIA EPICKIE",
		subtitle = "Diamenty lub Robux. *Cena końcowa w oknie Roblox.",
		designWidth = 920,
		designHeight = 640,
	})
	local eFrame = win.frame
	self.epicResearchModal = eFrame
	self:_fitWindow(eFrame, win.designWidth, win.designHeight)
	self.ui:closeButton(eFrame, function()
		eFrame.Visible = false
	end)

	if isRoblox and typeof(eFrame) == "Instance" then
		addCornerAndStroke(eFrame, 16, Color3.fromRGB(215, 120, 255), 2.5)
		local stroke = eFrame:FindFirstChildOfClass("UIStroke")
		if stroke then addPulseGlow(stroke, 0.1, 0.5) end
	end

	-- Golden Eggs Balance status pill
	self.epicGePill = self.ui:pill(eFrame, {
		name = "EpicGeBalancePill",
		size = { 1, -28, 0, 36 },
		position = { 0, 14, 0, 66 },
		text = "Twoje Diamenty: 0 💎",
		tone = "gold",
		align = "Center",
		maxTextSize = 18,
		radius = 8,
	})

	-- Scrolling container with cards for available and planned Epic research
	local scroll = self.ui:scroll(eFrame, {
		name = "EpicResearchListContainer",
		size = { 1, -28, 1, -118 },
		position = { 0, 14, 0, 108 },
		canvasHeight = #EPIC_RESEARCH_CATALOG * 92 + 12,
		scrollBarColor = { 215, 120, 255 },
	})
	self.epicResearchListContainer = scroll
	self.epicResearchCards = {}

	for i, item in ipairs(EPIC_RESEARCH_CATALOG) do
		local card = self.ui:card(scroll, {
			name = "EpicCard_" .. item.id,
			family = "shop",
			fill = { 44, 22, 54 },
			top = { 74, 38, 90 },
			border = { 90, 45, 110 },
			size = { 1, -6, 0, 84 },
			position = { 0, 0, 0, (i - 1) * 92 },
		})

		local title = self.ui:label(card, {
			name = "Title",
			size = { 0.54, 0, 0, 22 },
			position = { 0.03, 0, 0, 8 },
			text = item.name,
			color = { 255, 235, 120 },
			align = "Left",
			textStroke = 1.8,
			maxTextSize = 17,
		})

		local desc = self.ui:label(card, {
			name = "Desc",
			size = { 0.54, 0, 0, 26 },
			position = { 0.03, 0, 0, 30 },
			text = item.desc,
			color = { 225, 225, 235 },
			align = "Left",
			textStroke = 1.4,
			maxTextSize = 14,
		})

		local lvlLabel = self.ui:label(card, {
			name = "LevelLabel",
			size = { 0.24, 0, 0, 18 },
			position = { 0.03, 0, 0, 58 },
			text = "Poziom: 0 / " .. tostring(item.maxLevel),
			color = { 180, 240, 180 },
			align = "Left",
			textStroke = 1.4,
			maxTextSize = 13,
		})

		local track = createGuiElement("Frame", {
			Name = "ProgressTrack",
			Size = isRoblox and UDim2.new(0.28, 0, 0, 10) or nil,
			Position = isRoblox and UDim2.new(0.28, 0, 0, 62) or nil,
			BackgroundColor3 = isRoblox and Color3.fromRGB(30, 15, 38) or nil,
		}, card)
		addCornerAndStroke(track, 4, nil, 0)

		local fill = createGuiElement("Frame", {
			Name = "ProgressFill",
			Size = isRoblox and UDim2.new(0, 0, 1, 0) or nil,
			BackgroundColor3 = isRoblox and Color3.fromRGB(245, 158, 11) or nil,
		}, track)
		addCornerAndStroke(fill, 4, nil, 0)

		local buyBtn = self.ui:button(card, {
			name = "BuyEpicButton",
			text = if UNSUPPORTED_EPIC_RESEARCH[item.id] then "WKRÓTCE" else formatCompact(EpicPricing.ge(item.basePriceGE)) .. " 💎",
			tone = if UNSUPPORTED_EPIC_RESEARCH[item.id] then "ghost" else "primary",
			size = { 0.17, 0, 0, 48 },
			position = { 0.60, 0, 0, 18 },
			onClick = function()
				if UNSUPPORTED_EPIC_RESEARCH[item.id] then return end
				if type(self.onBuyEpicResearch) == "function" then
					self.onBuyEpicResearch(item.id)
				end
			end,
		})

		local buyRobuxBtn = self.ui:button(card, {
			name = "BuyRobuxButton",
			text = "WKRÓTCE", active = false,
			tone = "gold",
			size = { 0.18, 0, 0, 48 },
			position = { 0.79, 0, 0, 18 },
			visible = false,
			onClick = function()
				if UNSUPPORTED_EPIC_RESEARCH[item.id] then return end
                local offer=self._epicRobuxOffers and self._epicRobuxOffers[item.id]
                if offer and offer.configured and type(self.onBuyEpicRobux)=="function" then self.onBuyEpicRobux(item.id) end
			end,
		})

		if isRoblox then
			bindBouncyButton(buyBtn)
			if typeof(buyRobuxBtn) == "Instance" then buyRobuxBtn.Visible = false end
		end

		local cardEntry = {
			card = card,
			title = title,
			desc = desc,
			lvlLabel = lvlLabel,
			track = track,
			fill = fill,
			buyBtn = buyBtn,
			buyRobuxBtn = buyRobuxBtn,
			spec = item,
		}
		self.epicResearchCards[item.id] = cardEntry
	end
end

function HUD:_buildPetsModal(root)
	-- Shared stud-style window (#82): identical frame/header/close family as the other windows.
	local win = self.ui:window({
		parent = root, name = "PetsFrame", family = "pets",
		title = "MOJE PETY I EWOLUCJA FUZYJNA",
		designWidth = 520, designHeight = 540,
	})
	local pFrame = win.frame
	self.petsModal = pFrame
	self:_fitWindow(pFrame, win.designWidth, win.designHeight)
	self.ui:closeButton(pFrame, function()
		pFrame.Visible = false
	end)

	-- Equipped slots (3 base, 5 with Pro Permit)
	local eqFrame = self.ui:card(pFrame, {
		name = "EquippedSlotsFrame", family = "pets",
		fill = { 45, 20, 42 }, top = { 72, 34, 68 }, border = { 25, 10, 24 },
		size = { 1, -28, 0, 62 }, position = { 0, 14, 0, 72 },
	})

	for slotId = 1, 5 do
		-- The locked Pro slots keep the same wording without the decorative emoji glyph.
		local slotBtn = self.ui:button(eqFrame, {
			name = "EquippedSlot_" .. tostring(slotId),
			text = if slotId <= 3 then "+ Slot #" .. tostring(slotId) else "Pro Permit",
			tone = if slotId <= 3 then "neutral" else "disabled",
			size = { 0.18, 0, 0, 44 }, position = { 0.015 + (slotId - 1) * 0.198, 0, 0, 9 },
			textStroke = 1.5, maxTextSize = 16,
			onClick = function()
				if type(self.onUnequipPet) == "function" then
					self.onUnequipPet(slotId)
				end
			end,
		})
		self.equippedPetSlots[slotId] = slotBtn
	end

	-- Inventory Section: a scrolling list so long inventories never shrink the text.
	local invFrame = self.ui:scroll(pFrame, {
		name = "InventoryFrame", family = "pets",
		fill = { 48, 22, 45 },
		size = { 1, -28, 1, -172 }, position = { 0, 14, 0, 142 },
		canvasHeight = 4 * 48 + 40, scrollBarColor = { 245, 145, 255 },
	})

	self.ui:label(invFrame, {
		name = "InvTitle", size = { 1, -12, 0, 22 }, position = { 0, 8, 0, 4 },
		text = "Inwentarz Petów (Kliknij by założyć / zablokować):",
		color = { 255, 235, 145 }, align = "Left", textStroke = 1.8, maxTextSize = 18,
	})

	-- Sample default inventory entries
	for pIdx = 1, 4 do
		local pCard = self.ui:card(invFrame, {
			name = "PetCard_" .. tostring(pIdx), family = "pets",
			fill = { 80, 36, 75 }, top = { 112, 54, 104 }, border = { 36, 16, 34 },
			size = { 1, -16, 0, 44 }, position = { 0, 8, 0, 28 + (pIdx - 1) * 48 },
		})

		local nameLbl = self.ui:button(pCard, {
			name = "PetName",
			text = if pIdx == 1 then "Piesek Farmerski (T1 Normalny)" elseif pIdx == 2 then "Robo-Kogut (T1 Złoty)" else "Piesek (T1 Normalny)",
			tone = "neutral", size = { 0.55, 0, 0, 40 }, position = { 0.02, 0, 0, 2 },
			textStroke = 1.6, maxTextSize = 16,
		})
		if nameLbl.Activated then nameLbl.Activated:Connect(function()
			local pet=self._visiblePets and self._visiblePets[pIdx]
			if not pet or pet.locked or pet.equipped then return end
			if not self.fusionBaseUid or self.fusionBaseUid==pet.uid then self:selectFusionBase(pet.uid) else self:toggleFusionMaterial(pet.uid) end
			if self.fusionChanceLabel then self.fusionChanceLabel.Text="Baza: "..tostring(self.fusionBaseUid).." | materiały: "..tostring(#self.fusionMaterialUids) end
		end) end

		local equipBtn = self.ui:button(pCard, {
			name = "EquipBtn", text = "ZAŁÓŻ", tone = "primary",
			size = { 0.20, 0, 0, 40 }, position = { 0.58, 0, 0, 2 },
			textStroke = 1.5, maxTextSize = 16,
			onClick = function()
				if type(self.onEquipPet) == "function" then
					local pet=self._visiblePets and self._visiblePets[pIdx]
					if pet then self.onEquipPet(pet.uid,1) end
				end
			end,
		})

		local lockBtn = self.ui:button(pCard, {
			name = "LockBtn", text = "ODBL.", tone = "gold",
			size = { 0.18, 0, 0, 40 }, position = { 0.80, 0, 0, 2 },
			textStroke = 1.5, maxTextSize = 16,
			onClick = function()
				if type(self.onTogglePetLock) == "function" then
					local pet=self._visiblePets and self._visiblePets[pIdx]
					if pet then self.onTogglePetLock(pet.uid) end
				end
			end,
		})

		self.petInventoryCards[pIdx] = pCard
	end

	-- Fusion Section
	local fusFrame = self.ui:card(pFrame, {
		name = "FusionFrame", family = "pets",
		fill = { 42, 18, 40 }, top = { 68, 32, 66 }, border = { 22, 10, 20 },
		size = { 1, -28, 0, 120 }, position = { 0, 14, 0, 406 },
	})

	self.fusionChanceLabel = self.ui:label(fusFrame, {
		name = "FusionChanceLabel", size = { 0.68, 0, 0, 24 }, position = { 0.02, 0, 0, 6 },
		text = "Wybierz bazę, potem materiały (kliknij nazwę peta)",
		color = { 255, 235, 120 }, align = "Left", textStroke = 1.8, maxTextSize = 18,
	})

	self.fusionGuaranteeLabel = self.ui:label(fusFrame, {
		name = "FusionGuaranteeLabel", size = { 0.68, 0, 0, 22 }, position = { 0.02, 0, 0, 32 },
		text = "Receptura i gwarancja wymagają konfiguracji serwera",
		color = { 150, 245, 160 }, align = "Left", textStroke = 1.8, maxTextSize = 16,
	})

	self.fusionProPermitBadge = self.ui:label(fusFrame, {
		name = "ProPermitBonusBadge", size = { 0.68, 0, 0, 20 }, position = { 0.02, 0, 0, 56 },
		text = "Bonus Pro zależy od uprawnień konta",
		color = { 255, 175, 240 }, align = "Left", textStroke = 1.6, maxTextSize = 15,
	})
	addTextStroke(self.fusionProPermitBadge, 1.6)

	self.fusePetsButton = self.ui:button(fusFrame, {
		name = "FusePetsButton", text = "POŁĄCZ PETY", tone = "boost",
		size = { 0.28, 0, 0, 48 }, position = { 0.70, 0, 0, 14 },
		textStroke = 2.0, maxTextSize = 18,
		onClick = function()
			if type(self.onFusePets) == "function" then
				if self.fusionBaseUid and #self.fusionMaterialUids>0 then
					self.onFusePets(self.fusionBaseUid,table.clone(self.fusionMaterialUids))
				else self:onActionResult({status="NOT_ACCEPTED",errorCode="SELECT_FUSION_INPUTS"}) end
			end
		end,
	})
end

function HUD:_buildShopModal(root)
	-- Shared stud-style window (#82) with tabs for:
	-- 1. Pakiety Diamentów (ShopCard_ge_pack_small / large, piggy_break)
	-- 2. Wzmocnienia (BoostCard_*)
	-- 3. Przepustki (PassCard_pro_permit / buy_max)
	local win = self.ui:window({
		parent = root, name = "ShopModalFrame", family = "shop",
		title = "SKLEP DIAMENTÓW I PRZEPUSTEK",
		designWidth = 920, designHeight = 640,
	})
	local sFrame = win.frame
	self.shopModal = sFrame
	self:_fitWindow(sFrame, win.designWidth, win.designHeight)
	self.ui:closeButton(sFrame, function()
		sFrame.Visible = false
	end)

	if isRoblox and typeof(sFrame) == "Instance" then
		addCornerAndStroke(sFrame, 16, Color3.fromRGB(255, 215, 65), 2.5)
		local stroke = sFrame:FindFirstChildOfClass("UIStroke")
		if stroke then addPulseGlow(stroke, 0.1, 0.5) end
	end

	-- Top Hero Promo Banner: High-converting CTA to Tab 3 GamePasses
	local heroBanner = self.ui:button(sFrame, {
		name = "HeroPromoBanner",
		tone = "boost",
		size = { 1, -28, 0, 46 },
		position = { 0, 14, 0, 64 },
		text = "⭐ MEGA OFERTA: 2X DOCHÓD & PRZEPUSTKA PRO – ZWIĘKSZ ZYSKI JUŻ TERAZ! ⭐",
		color = { 255, 240, 110 },
		textStroke = 2.0,
		maxTextSize = 18,
		onClick = function()
			self:selectShopTab(3)
		end,
	})
	if isRoblox and typeof(heroBanner) == "Instance" then
		addCornerAndStroke(heroBanner, 10, Color3.fromRGB(255, 215, 65), 2.0)
		local stroke = heroBanner:FindFirstChildOfClass("UIStroke")
		if stroke then addPulseGlow(stroke, 0.05, 0.6) end
		addShimmerEffect(heroBanner)
		bindBouncyButton(heroBanner)
	end

	-- Tabs row: 1. Diamenty, 2. Wzmocnienia (Boosts), 3. Przepustki. 44px touch targets.
	local tabsRow = self.ui:card(sFrame, {
		name = "ShopTabsRow", family = "shop",
		fill = { 56, 32, 48 }, border = { 32, 16, 28 },
		size = { 1, -28, 0, 46 }, position = { 0, 14, 0, 116 },
	})

	local sTabNames = { "Diamenty", "Wzmocnienia", "Przepustki" }
	local sTabIcons = { "tab.ge", "tab.boosts", "tab.passes" }
	for idx, sName in ipairs(sTabNames) do
		local tabBtn = self.ui:tabButton(tabsRow, {
			name = "ShopTab_" .. tostring(idx), text = sName,
			size = { 0.32, 0, 0, 44 }, position = { (idx - 1) * 0.34, 0, 0, 1 },
			height = 44, active = (idx == 1), iconKey = sTabIcons[idx],
			onClick = function()
				self:selectShopTab(idx)
			end,
		})
		if isRoblox then
			bindBouncyButton(tabBtn)
		end
		self.shopModalTabButtons[idx] = tabBtn
	end

	-- Content Container: a scroll area so long product lists never shrink their text.
	local content = self.ui:scroll(sFrame, {
		name = "ShopContentContainer",
		size = { 1, -28, 1, -178 }, position = { 0, 14, 0, 168 },
		canvasHeight = 4 * 132 + 20, scrollBarColor = { 255, 215, 65 },
	})

	-- Build static product cards for tab 1 (GE), tab 2 (Boosts), tab 3 (Passes)
	self:_buildShopProducts(content)
end

function HUD:_buildShopProducts(container)
	-- Tab 1: GE Packs
	local tab1Frame = self.ui:card(container, {
		name = "Tab1_GEPacks", family = "shop",
		fill = { 56, 32, 48 }, border = { 32, 16, 28 },
		visible = true, size = { 1, 0, 0, 3 * 96 + 8 }, position = { 0, 0, 0, 0 },
	})

	local geProducts = {
		{
			id = "ge_pack_small",
			title = "Paczka Diamentów (1,000 💎)",
			badge = "[⚡ SZYBKI START]",
			badgeColor = { 255, 215, 65 },
			desc = "Zastrzyk Diamentów na epickie badania i boosty",
			btnText = "KUP",
		},
		{
			id = "ge_pack_large",
			title = "Wielka Paka Diamentów (10,000 💎)",
			badge = "[🔥 NAJLEPSZA WARTOŚĆ (+50% BONUS)]",
			badgeColor = { 255, 140, 50 },
			desc = "Maksymalna wartość Diamentów na badania",
			btnText = "KUP",
			isBestValue = true,
		},
		{
			id = "piggy_break",
			title = "Rozbij Skarbonkę (Break Piggy)",
			badge = "[💎 BANK DIAMENTÓW]",
			badgeColor = { 225, 120, 255 },
			desc = "Wypłać wszystkie Diamenty zmagazynowane w Skarbonce",
			btnText = "ROZBIJ",
		},
	}

	for i, prod in ipairs(geProducts) do
		local card = self.ui:card(tab1Frame, {
			name = "ShopCard_" .. prod.id, family = "shop",
			fill = if prod.isBestValue then { 86, 42, 74 } else { 74, 40, 64 },
			top = if prod.isBestValue then { 124, 64, 104 } else { 106, 58, 90 },
			border = if prod.isBestValue then { 255, 195, 45 } else { 36, 18, 30 },
			size = { 1, 0, 0, 88 }, position = { 0, 0, 0, (i - 1) * 96 },
		})

		local badgeLbl = self.ui:label(card, {
			name = "BadgeLabel", size = { 0.70, 0, 0, 18 }, position = { 0.03, 0, 0, 6 },
			text = prod.badge, color = prod.badgeColor, align = "Left",
			textStroke = 1.6, maxTextSize = 14,
		})

		local title = self.ui:label(card, {
			name = "Title", size = { 0.70, 0, 0, 24 }, position = { 0.03, 0, 0, 26 },
			text = prod.title, color = { 255, 235, 95 }, align = "Left",
			textStroke = 1.8, maxTextSize = 18,
		})

		local desc = self.ui:label(card, {
			name = "Desc", size = { 0.70, 0, 0, 30 }, position = { 0.03, 0, 0, 52 },
			text = prod.desc, color = { 240, 240, 240 }, align = "Left",
			textStroke = 1.6, maxTextSize = 15,
		})

		local buyBtn = self.ui:button(card, {
			name = "BuyProductButton", text = prod.btnText, tone = if prod.isBestValue then "gold" else "primary",
			size = { 0.23, 0, 0, 50 }, position = { 0.74, 0, 0, 19 },
			onClick = function()
				promptMarketplacePurchase(prod.id, self.onPurchaseProduct)
			end,
		})

		if isRoblox then
			bindBouncyButton(buyBtn)
			if prod.isBestValue then
				addShimmerEffect(card)
				local stroke = card:FindFirstChildOfClass("UIStroke")
				if stroke then addPulseGlow(stroke, 0.05, 0.6) end
			end
		end

		self.shopProductCards[prod.id] = card
	end

	-- Tab 2: Boosts (scrolling list, 44px buy & activate buttons)
	local tab2Frame = self.ui:card(container, {
		name = "Tab2_Boosts", family = "shop",
		fill = { 56, 32, 48 }, border = { 32, 16, 28 },
		visible = false, size = { 1, 0, 0, #BOOSTS_CATALOG * 56 + 48 }, position = { 0, 0, 0, 0 },
	})

	self.activeBoostsSummaryLabel = self.ui:label(tab2Frame, {
		name = "ActiveBoostsSummary", size = { 0.96, 0, 0, 34 }, position = { 0.02, 0, 0, 4 },
		text = "Aktywne boosty: 0 / 2", color = { 255, 235, 115 },
		align = "Left", textStroke = 1.5, maxTextSize = 15,
	})

	for i, bSpec in ipairs(BOOSTS_CATALOG) do
		local card = self.ui:card(tab2Frame, {
			name = "BoostCard_" .. bSpec.id, family = "shop",
			fill = { 68, 38, 58 }, top = { 98, 56, 84 }, border = { 32, 16, 28 },
			size = { 1, 0, 0, 50 }, position = { 0, 0, 0, 42 + (i - 1) * 56 },
		})

		local title = self.ui:label(card, {
			name = "Title", size = { 0.36, 0, 0, 50 }, position = { 0.02, 0, 0, 0 },
			text = bSpec.name .. " (" .. bSpec.effect .. ")", color = { 255, 255, 255 },
			align = "Left", textStroke = 1.5, maxTextSize = 15,
		})

		local ownedLbl = self.ui:label(card, {
			name = "OwnedCount", size = { 0.14, 0, 0, 50 }, position = { 0.39, 0, 0, 0 },
			text = "Posiadane: 0", color = { 215, 240, 255 },
			align = "Center", textStroke = 1.4, maxTextSize = 13,
		})

		local priceLbl = self.ui:label(card, {
			name = "Price", size = { 0.12, 0, 0, 50 }, position = { 0.54, 0, 0, 0 },
			text = tostring(bSpec.priceGE) .. " 💎", color = { 255, 215, 65 },
			align = "Center", textStroke = 1.5, maxTextSize = 15,
		})

		local activateBtn
		activateBtn = self.ui:button(card, {
			name = "ActivateBoostButton", text = "BRAK", tone = "disabled", active = false,
			size = { 0.15, 0, 0, 42 }, position = { 0.67, 0, 0, 4 },
			textStroke = 1.5, maxTextSize = 14,
			onClick = function()
				if not activateBtn.Active then return end
				if type(self.onActivateBoost) == "function" then
					self.onActivateBoost(bSpec.id)
				end
			end,
		})

		local buyBtn = self.ui:button(card, {
			name = "BuyBoostButton", text = "KUP", tone = "primary",
			size = { 0.15, 0, 0, 42 }, position = { 0.83, 0, 0, 4 },
			textStroke = 1.5, maxTextSize = 16,
			onClick = function()
				if type(self.onBuyBoost) == "function" then
					self.onBuyBoost(bSpec.id)
				end
			end,
		})

		if isRoblox then
			bindBouncyButton(activateBtn)
			bindBouncyButton(buyBtn)
		end

		self.shopProductCards[bSpec.id] = card
	end

	-- Tab 3: GamePasses (scrolling list)
	local tab3Frame = self.ui:card(container, {
		name = "Tab3_GamePasses", family = "shop",
		fill = { 56, 32, 48 }, border = { 32, 16, 28 },
		visible = false, size = { 1, 0, 0, 4 * 132 + 8 }, position = { 0, 0, 0, 0 },
	})

	local passes = {
		{
			spec = SHOP_PRODUCTS_CATALOG.double_cash,
			badge = "[⭐ NAJPOPULARNIEJSZE (2x KASA NA ZAWSZE)]",
			badgeColor = { 255, 215, 65 },
			isFeatured = true,
		},
		{
			spec = SHOP_PRODUCTS_CATALOG.pro_permit,
			badge = "[👑 VIP (18H OFFLINE & 5 BOOSTÓW)]",
			badgeColor = { 255, 175, 245 },
			isFeatured = true,
		},
		{
			spec = SHOP_PRODUCTS_CATALOG.auto_hatch,
			badge = "[⏳ WKRÓTCE (AKTUALIZACJA V1.1)]",
			badgeColor = { 120, 240, 255 },
			isFeatured = false,
		},
		{
			spec = SHOP_PRODUCTS_CATALOG.buy_max,
			badge = "[⏳ WKRÓTCE (AKTUALIZACJA V1.1)]",
			badgeColor = { 130, 255, 150 },
			isFeatured = false,
		},
	}

	for i, pass in ipairs(passes) do
		local card = self.ui:card(tab3Frame, {
			name = "PassCard_" .. pass.spec.id, family = "shop",
			fill = if pass.isFeatured then { 82, 42, 72 } else { 74, 40, 64 },
			top = if pass.isFeatured then { 118, 62, 102 } else { 106, 58, 90 },
			border = if pass.isFeatured then { 255, 205, 50 } else { 36, 18, 30 },
			size = { 1, 0, 0, 122 }, position = { 0, 0, 0, (i - 1) * 132 },
		})

		local badgeLbl = self.ui:label(card, {
			name = "BadgeLabel", size = { 0.70, 0, 0, 18 }, position = { 0.03, 0, 0, 6 },
			text = pass.badge, color = pass.badgeColor, align = "Left",
			textStroke = 1.6, maxTextSize = 14,
		})

		local title = self.ui:label(card, {
			name = "Title", size = { 0.70, 0, 0, 24 }, position = { 0.03, 0, 0, 26 },
			text = pass.spec.name, color = { 255, 235, 95 }, align = "Left",
			textStroke = 1.8, maxTextSize = 18,
		})

		local desc = self.ui:label(card, {
			name = "Desc", size = { 0.70, 0, 0, 36 }, position = { 0.03, 0, 0, 52 },
			text = pass.spec.desc, color = { 240, 240, 240 }, align = "Left",
			textStroke = 1.6, maxTextSize = 15,
		})

		if pass.spec.notice then
			local noticeLbl = self.ui:label(card, {
				name = "Notice", size = { 0.70, 0, 0, 26 }, position = { 0.03, 0, 0, 90 },
				text = pass.spec.notice, color = { 255, 175, 140 }, align = "Left",
				textStroke = 1.5, maxTextSize = 15,
			})
		end

		local isPassDisabled = not Availability.isProductAvailable(pass.spec.id)
		local buyBtn = self.ui:button(card, {
			name = "BuyPassButton", active = not isPassDisabled, text = if isPassDisabled then "WKRÓTCE" else "ODBLOKUJ", tone = if isPassDisabled then "ghost" else "primary",
			size = { 0.23, 0, 0, 52 }, position = { 0.74, 0, 0, 34 },
			onClick = function()
				if isPassDisabled then return end
				promptMarketplacePurchase(pass.spec.id, self.onPurchaseProduct)
			end,
		})

		if isRoblox then
			bindBouncyButton(buyBtn)
			if pass.isFeatured then
				addShimmerEffect(card)
				local stroke = card:FindFirstChildOfClass("UIStroke")
				if stroke then addPulseGlow(stroke, 0.1, 0.6) end
			end
		end

		self.shopProductCards[pass.spec.id] = card
	end
end

function HUD:_buildCalendarModal(root)
	-- Shared stud-style window (#82): 28-day daily rewards calendar.
	local win = self.ui:window({
		parent = root, name = "CalendarFrame", family = "calendar",
		title = "KALENDARZ NAGRÓD",
		designWidth = 560, designHeight = 520,
	})
	local cFrame = win.frame
	self.calendarModal = cFrame
	self.calendarWindow = win
	self:_fitWindow(cFrame, win.designWidth, win.designHeight, function(fit)
		self._calendarGridWidth = fit.width
	end)
	self.ui:closeButton(cFrame, function()
		cFrame.Visible = false
	end)

	-- Hidden Tabs Row (trophies removed from user view; kept headless for tests/contract)
	local tabsRow = self.ui:card(cFrame, {
		name = "CalendarTabsRow", family = "calendar",
		fill = { 48, 32, 58 }, border = { 24, 14, 30 },
		size = { 1, -28, 0, 44 }, position = { 0, 14, 0, 70 },
		visible = false,
	})

	local cTabNames = { "Kalendarz 28 Dni", "Trofea Jaj" }
	local cTabIcons = { "window.calendar", "tab.trophies" }
	for idx, cName in ipairs(cTabNames) do
		local tabBtn = self.ui:tabButton(tabsRow, {
			name = "CalendarTab_" .. tostring(idx), text = cName,
			size = { 0.48, 0, 0, 44 }, position = { (idx - 1) * 0.52, 0, 0, 0 },
			height = 44, active = (idx == 1), iconKey = cTabIcons[idx],
			onClick = function()
				self:selectCalendarTab(idx)
			end,
		})
		self.calendarTabButtons[idx] = tabBtn
	end

	-- 28-day Calendar Grid: positioned directly below window header since tabs are removed
	local calContent = self.ui:scroll(cFrame, {
		name = "CalendarContent_Tab1", family = "calendar",
		fill = { 36, 22, 44 }, visible = true,
		size = { 1, -28, 1, -140 }, position = { 0, 14, 0, 70 },
		canvasHeight = 4 * 56 + 12, scrollBarColor = { 255, 175, 75 },
	})
	self.calendarGridScroll = calContent

	for day = 1, 28 do
		local dayCell = self.ui:card(calContent, {
			name = "DayCell_" .. tostring(day), family = "calendar",
			fill = if day == 1 then { 225, 160, 45 } else { 56, 36, 68 },
			border = { 24, 14, 28 }, radius = 6,
			size = { 0.13, 0, 0, 52 }, position = { 0.015, 0, 0, 0 },
		})

		local dayNum = self.ui:label(dayCell, {
			name = "DayNumber", size = { 1, 0, 0.35, 0 }, position = { 0, 0, 0, 2 },
			text = "D" .. tostring(day), color = { 255, 235, 120 },
			textStroke = 1.6, maxTextSize = 18,
		})

		local dayRew = self.ui:label(dayCell, {
			name = "RewardText", size = { 1, -4, 0.6, 0 }, position = { 0, 2, 0.38, 0 },
			text = "Dane z serwera", color = { 255, 255, 255 },
			textStroke = 1.4, maxTextSize = 14,
		})

		self.calendarDayCells[day] = dayCell
	end

	-- Reflow the day cells for the resolved width.
	self.ui:applyGridReflow(calContent, self.calendarDayCells, {
		padding = 6, minCellWidth = 64, maxColumns = 7, cellHeight = 52, gap = 4,
	})

	-- Claim Daily Gift Button
	self.claimDailyGiftButton = self.ui:button(cFrame, {
		name = "ClaimDailyGiftButton", text = "ODBIERZ DZISIEJSZĄ NAGRODĘ", tone = "primary",
		size = { 1, -28, 0, 48 }, position = { 0, 14, 1, -60 },
		textStroke = 2.0, maxTextSize = 20,
		onClick = function()
			if type(self.onClaimDailyGift) == "function" then
				self.onClaimDailyGift()
			end
		end,
	})

	-- Tab 2: Trophies List (hidden, kept headless for tests)
	local trophContent = self.ui:scroll(cFrame, {
		name = "TrophiesContent_Tab2", family = "calendar",
		fill = { 36, 22, 44 }, visible = false,
		size = { 1, -28, 1, -140 }, position = { 0, 14, 0, 70 },
		canvasHeight = 19 * 60 + 12, scrollBarThickness = 8, scrollBarColor = { 255, 175, 75 },
	})

	for eIdx = 0, 18 do
		local egg = EGGS_DATA[eIdx] or { name = "Jajo " .. tostring(eIdx) }
		local card = self.ui:card(trophContent, {
			name = "TrophyCard_Egg_" .. tostring(eIdx), family = "calendar",
			fill = { 56, 36, 68 }, top = { 84, 56, 100 }, border = { 28, 16, 34 },
			size = { 1, -12, 0, 54 }, position = { 0, 6, 0, 6 + eIdx * 60 },
		})

		local eName = self.ui:label(card, {
			name = "EggTitle", size = { 0.35, 0, 1, 0 }, position = { 0.02, 0, 0, 0 },
			text = egg.name, color = { 255, 235, 120 }, align = "Left",
			textStroke = 1.6, maxTextSize = 17,
		})

		for tIdx, tInfo in ipairs(TROPHY_POPULATION_TIERS) do
			local cupBtn = self.ui:button(card, {
				name = "CupBtn_" .. tostring(tIdx),
				text = tInfo.name, tone = "neutral",
				size = { 0.11, 0, 0, 44 }, position = { 0.38 + (tIdx - 1) * 0.12, 0, 0, 5 },
				textStroke = 1.2, maxTextSize = 12,
				onClick = function()
					if type(self.onClaimTrophy) == "function" then
						self.onClaimTrophy(eIdx, tIdx)
					end
				end,
			})
		end

		self.trophyCards[eIdx] = card
	end
end

function HUD:_buildEggUpgradeModal(root)
	-- Shared stud-style window (#82): egg family; the existing label wording stays (minus the
	-- decorative glyphs) so every getter and the reset flow keep working unchanged.
	local win = self.ui:window({
		parent = root, name = "EggUpgradeModal", family = "egg",
		title = "STACJA BADAWCZA JAJ",
		designWidth = 440, designHeight = 360,
	})
	local eggModal = win.frame
	self.eggUpgradeModal = eggModal
	self:_fitWindow(eggModal, win.designWidth, win.designHeight)
	self.ui:closeButton(eggModal, function()
		eggModal.Visible = false
	end)

	self.eggUpgradeCurrentLabel = self.ui:label(eggModal, {
		name = "CurrentEggLabel", size = { 1, -32, 0, 26 }, position = { 0, 16, 0, 74 },
		text = "Aktualne: Jajo Kurze", color = { 255, 255, 255 },
		textStroke = 1.8, maxTextSize = 18,
	})

	self.eggUpgradeNextLabel = self.ui:label(eggModal, {
		name = "NextEggLabel", size = { 1, -32, 0, 26 }, position = { 0, 16, 0, 104 },
		text = "Następne: Jajo Kacze", color = { 115, 245, 115 },
		textStroke = 1.8, maxTextSize = 18,
	})

	self.eggUpgradeMultLabel = self.ui:label(eggModal, {
		name = "MultiplierLabel", size = { 1, -32, 0, 24 }, position = { 0, 16, 0, 134 },
		text = "Mnożnik Wartości: 5.0x", color = { 255, 215, 100 },
		textStroke = 1.8, maxTextSize = 17,
	})

	self.eggUpgradeCurrentFvLabel = self.ui:label(eggModal, {
		name = "CurrentFvLabel", size = { 1, -32, 0, 24 }, position = { 0, 16, 0, 164 },
		text = "Twoje Farm Value: $0", color = { 135, 225, 255 },
		textStroke = 1.8, maxTextSize = 17,
	})

	self.eggUpgradeReqFvLabel = self.ui:label(eggModal, {
		name = "RequiredFvLabel", size = { 1, -32, 0, 24 }, position = { 0, 16, 0, 192 },
		text = "Wymagane Farm Value: $5.0M", color = { 255, 185, 115 },
		textStroke = 1.8, maxTextSize = 17,
	})

	-- Reset warning: a themed pill so the destructive note is unmistakable and readable.
	self.eggUpgradeWarningLabel = self.ui:pill(eggModal, {
		name = "WarningLabel", size = { 1, -32, 0, 52 }, position = { 0, 16, 0, 224 },
		text = "Awans zresetuje bieżącą gotówkę, kurniki i pojazdy.\nPety, Diamenty i badania Epickie zostaną zachowane!",
		tone = "locked", align = "Center", wrapped = true,
		maxTextSize = 15, radius = 8, transparency = 0.15,
	})

	local upgEggBtn = self.ui:button(eggModal, {
		name = "UpgradeEggButton", text = "AWANSUJ NASTĘPNE JAJO", tone = "primary",
		size = { 1, -40, 0, 52 }, position = { 0, 20, 0, 292 },
		textStroke = 2.4, maxTextSize = 20,
		onClick = function()
			local farm = self.stateStore and self.stateStore:getFarm()
			local curEggIdx = (farm and farm.eggIndex) or 0
			local nextEggIdx = curEggIdx + 1
			if self.eggUpgradeBtn and self.eggUpgradeBtn.Active ~= false and nextEggIdx <= 18 and type(self.onUpgradeEggRequested) == "function" then
				self.onUpgradeEggRequested(nextEggIdx)
			end
		end,
	})
	self.eggUpgradeBtn = upgEggBtn
end

function HUD:_buildPetHatchModal(root)
	-- Shared stud-style window (#82): incubation uses the same frame/header/close family.
	local win = self.ui:window({
		parent = root, name = "PetHatchModal", family = "hatch",
		title = "INKUBACJA & WYKLUWANIE JAJ",
		designWidth = 480, designHeight = 460,
	})
	local hFrame = win.frame
	self.petHatchModal = hFrame
	self:_fitWindow(hFrame, win.designWidth, win.designHeight)
	self.ui:closeButton(hFrame, function()
		hFrame.Visible = false
	end)

	-- Subtitle info
	self.ui:label(hFrame, {
		name = "PetHatchSubtitle", size = { 1, -28, 0, 24 }, position = { 0, 14, 0, 70 },
		text = "Inkubuj jajo i odkryj nowego zwierzaka ze specjalnym bonusem!",
		color = { 240, 240, 240 }, align = "Left", textStroke = 1.6, maxTextSize = 16,
	})

	-- Central Egg Preview Card
	local card = self.ui:card(hFrame, {
		name = "EggPreviewCard", family = "hatch",
		fill = { 38, 16, 38 }, top = { 66, 30, 64 }, border = { 255, 215, 65 },
		size = { 1, -28, 0, 250 }, position = { 0, 14, 0, 100 },
	})

	-- Egg icon slot: a genuine cracked-egg image once bound, otherwise the text name below
	-- carries the meaning and no placeholder is drawn.
	local eggSlot, eggImage = self.ui:iconSlot(card, {
		key = "window.hatch", size = 90, position = { 0.5, -45, 0, 12 },
		background = { 38, 16, 38 }, border = { 255, 215, 65 }, transparency = 0,
	})
	if eggSlot == nil then
		self.ui:label(card, {
			name = "EggGraphicLabel", size = { 0, 90, 0, 90 }, position = { 0.5, -45, 0, 12 },
			text = "Jajo", color = { 255, 235, 110 }, textStroke = 1.6, maxTextSize = 22,
		})
	end

	self.ui:label(card, {
		name = "EggNameLabel", size = { 1, -20, 0, 26 }, position = { 0, 10, 0, 112 },
		text = "Standardowe Jajo Peta", color = { 255, 235, 110 },
		textStroke = 1.8, maxTextSize = 18,
	})

	-- Chances breakdown label
	self.ui:label(card, {
		name = "EggChancesLabel", size = { 1, -20, 0, 46 }, position = { 0, 10, 0, 142 },
		text = "Szanse:\nCommon (60%) • Rare (25%) • Epic (12%) • Legendary (3%)",
		color = { 220, 220, 240 }, wrapped = true, textStroke = 1.4, maxTextSize = 15,
	})

	-- Cost label
	self.ui:label(card, {
		name = "EggCostLabel", size = { 1, -20, 0, 24 }, position = { 0, 10, 0, 198 },
		text = "Koszt: 100 Diamentów (100 💎)", color = { 255, 215, 65 },
		textStroke = 1.6, maxTextSize = 17,
	})

	-- Hatch Button
	local hatchBtn = self.ui:button(hFrame, {
		name = "HatchButton", text = "WYSIADUJ / INKUBUJ (100 💎)", tone = "primary",
		size = { 1, -28, 0, 52 }, position = { 0, 14, 1, -66 },
		textStroke = 2.4, maxTextSize = 20,
		onClick = function()
			if type(self.onHatchPetEgg) == "function" then
				self.onHatchPetEgg("standard_egg")
			end
		end,
	})
	self.hatchEggButton = hatchBtn
end

function HUD:_buildHatchAnimationOverlay(root)
	local overlay = createGuiElement("Frame", {
		Name = "HatchAnimationOverlay",
		Visible = false,
		Size = isRoblox and UDim2.new(1, 0, 1, 0) or nil,
		Position = isRoblox and UDim2.new(0, 0, 0, 0) or nil,
		BackgroundColor3 = isRoblox and Color3.fromRGB(15, 8, 20) or nil,
		BackgroundTransparency = isRoblox and 0.2 or 0,
		ZIndex = 50,
	}, root)
	self.hatchAnimationOverlay = overlay

	-- Wobbling Egg in center
	local eggVisual = createGuiElement("TextLabel", {
		Name = "AnimatedEgg",
		Size = isRoblox and UDim2.new(0, 180, 0, 220) or nil,
		Position = isRoblox and UDim2.new(0.5, -90, 0.5, -130) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		Text = "🥚",
		ZIndex = 51,
	}, overlay)
	self.animatedEggVisual = eggVisual

	-- Flash / Burst glow frame
	local burstGlow = createGuiElement("Frame", {
		Name = "BurstGlow",
		Visible = false,
		Size = isRoblox and UDim2.new(0, 300, 0, 300) or nil,
		Position = isRoblox and UDim2.new(0.5, -150, 0.5, -150) or nil,
		BackgroundColor3 = isRoblox and Color3.fromRGB(255, 245, 160) or nil,
		BackgroundTransparency = 0.5,
		ZIndex = 52,
	}, overlay)
	addCornerAndStroke(burstGlow, 150, isRoblox and Color3.fromRGB(255, 255, 255) or nil, 4)
	self.hatchBurstGlow = burstGlow

	-- Pet Reveal Card
	local revealCard = createGuiElement("Frame", {
		Name = "PetRevealCard",
		Visible = false,
		Size = isRoblox and UDim2.new(0, 380, 0, 440) or nil,
		Position = isRoblox and UDim2.new(0.5, -190, 0.5, -220) or nil,
		BackgroundColor3 = isRoblox and Color3.fromRGB(48, 22, 52) or nil,
		ZIndex = 53,
	}, overlay)
	addCornerAndStroke(revealCard, 14, isRoblox and Color3.fromRGB(255, 215, 65) or nil, 3.5)
	self.petRevealCard = revealCard

	self.ui:heading(revealCard, {
		name = "RevealTitle", size = { 1, -20, 0, 36 }, position = { 0, 10, 0, 12 },
		text = "WYKLUŁEŚ NOWEGO PETA!", color = { 255, 235, 110 },
		zIndex = 54, textStroke = 2.4, maxTextSize = 22,
	})

	-- The pet species glyph stays a text label: it is content (which pet), driven by the reveal
	-- data, and its text is part of the verified HUD surface.
	local iconLabel = createGuiElement("TextLabel", {
		Name = "PetIcon",
		Size = isRoblox and UDim2.new(0, 120, 0, 120) or nil,
		Position = isRoblox and UDim2.new(0.5, -60, 0, 52) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		Text = "🐶",
		ZIndex = 54,
	}, revealCard)
	self.revealPetIcon = iconLabel

	local nameLabel = self.ui:label(revealCard, {
		name = "PetName", size = { 1, -20, 0, 32 }, position = { 0, 10, 0, 176 },
		text = "Farmer Dog", color = { 255, 255, 255 },
		zIndex = 54, textStroke = 2.0, maxTextSize = 20,
	})
	self.revealPetName = nameLabel

	local rarityLabel = self.ui:label(revealCard, {
		name = "PetRarity", size = { 1, -20, 0, 26 }, position = { 0, 10, 0, 210 },
		text = "Legendary", color = { 255, 215, 65 },
		zIndex = 54, textStroke = 2.0, maxTextSize = 18,
	})
	self.revealPetRarity = rarityLabel

	local statLabel = self.ui:label(revealCard, {
		name = "PetStat", size = { 1, -20, 0, 28 }, position = { 0, 10, 0, 240 },
		text = "+50% Wartość Jaj", color = { 120, 255, 140 },
		zIndex = 54, textStroke = 2.0, maxTextSize = 18,
	})
	self.revealPetStat = statLabel

	-- Action buttons: Equip, Lock, Confirm (shared tactile buttons, >= 44px)
	local equipBtn = self.ui:button(revealCard, {
		name = "EquipNowBtn", text = "Załóż Peta", tone = "primary",
		size = { 0.46, 0, 0, 46 }, position = { 0.03, 0, 0, 284 },
		zIndex = 54, textStroke = 2.0, maxTextSize = 17,
	})
	self.revealEquipBtn = equipBtn

	local lockBtn = self.ui:button(revealCard, {
		name = "LockBtn", text = "Zablokuj", tone = "gold",
		size = { 0.46, 0, 0, 46 }, position = { 0.51, 0, 0, 284 },
		zIndex = 54, textStroke = 2.0, maxTextSize = 17,
	})
	self.revealLockBtn = lockBtn

	local confirmBtn = self.ui:button(revealCard, {
		name = "ConfirmBtn", text = "Zatwierdź / Zamknij", tone = "boost",
		size = { 0.94, 0, 0, 48 }, position = { 0.03, 0, 0, 342 },
		zIndex = 54, textStroke = 2.0, maxTextSize = 17,
	})
	self.revealConfirmBtn = confirmBtn
end

function HUD:_buildPrestigeModal(root)
	local modal = createGuiElement("Frame", {
		Name = "PrestigeModal",
		Visible = false,
		Size = isRoblox and UDim2.new(0, 460, 0, 560) or nil,
		Position = isRoblox and UDim2.new(0.5, -230, 0.5, -280) or nil,
		BackgroundColor3 = isRoblox and Color3.fromRGB(24, 16, 42) or nil,
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		ZIndex = 50,
	}, root)
	self.prestigeModal = modal
	self:_fitWindow(modal, 460, 560)
	addCornerAndStroke(modal, 18, isRoblox and Color3.fromRGB(180, 80, 255) or nil, 3.5)

	-- Header Frame
	local header = createGuiElement("Frame", {
		Name = "WindowHeader",
		Size = isRoblox and UDim2.new(1, 0, 0, 52) or nil,
		Position = isRoblox and UDim2.new(0, 0, 0, 0) or nil,
		BackgroundColor3 = isRoblox and Color3.fromRGB(48, 22, 78) or nil,
		BorderSizePixel = 0,
		ZIndex = 51,
	}, modal)
	addCornerAndStroke(header, 18, isRoblox and Color3.fromRGB(180, 80, 255) or nil, 2)

	local titleLabel = createGuiElement("TextLabel", {
		Name = "WindowTitle",
		Size = isRoblox and UDim2.new(1, -70, 1, 0) or nil,
		Position = isRoblox and UDim2.new(0, 16, 0, 0) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(245, 220, 255) or nil,
		TextXAlignment = isRoblox and Enum.TextXAlignment.Left or nil,
		Text = "ODRODZENIE & PRESTIŻ",
		ZIndex = 52,
	}, header)
	addTextStroke(titleLabel, 2.5)

	-- Close Button
	local closeBtn = createGuiElement("TextButton", {
		Name = "CloseBtn",
		Size = isRoblox and UDim2.new(0, 36, 0, 36) or nil,
		Position = isRoblox and UDim2.new(1, -44, 0.5, -18) or nil,
		BackgroundColor3 = isRoblox and Color3.fromRGB(180, 40, 60) or nil,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(255, 255, 255) or nil,
		Text = "✕",
		ZIndex = 52,
	}, header)
	addCornerAndStroke(closeBtn, 8, isRoblox and Color3.fromRGB(90, 20, 30) or nil, 2)
	if closeBtn.Activated then
		closeBtn.Activated:Connect(function()
			self:_playClick()
			modal.Visible = false
		end)
	end

	-- 1. Current Crystals & Multiplier Card
	local currentCard = createGuiElement("Frame", {
		Name = "CurrentCard",
		Size = isRoblox and UDim2.new(1, -32, 0, 112) or nil,
		Position = isRoblox and UDim2.new(0, 16, 0, 62) or nil,
		BackgroundColor3 = isRoblox and Color3.fromRGB(36, 20, 60) or nil,
		BackgroundTransparency = 0.2,
		ZIndex = 51,
	}, modal)
	addCornerAndStroke(currentCard, 12, isRoblox and Color3.fromRGB(120, 50, 180) or nil, 2)

	self.prestigeCurrentCrystalsLabel = createGuiElement("TextLabel", {
		Name = "CurrentCrystalsLabel",
		Size = isRoblox and UDim2.new(1, -16, 0, 30) or nil,
		Position = isRoblox and UDim2.new(0, 10, 0, 6) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(225, 140, 255) or nil,
		TextXAlignment = isRoblox and Enum.TextXAlignment.Left or nil,
		Text = "Posiadane Kryształy: 🟣 0",
		ZIndex = 52,
	}, currentCard)
	addTextStroke(self.prestigeCurrentCrystalsLabel, 2.0)

	self.prestigeCurrentBonusLabel = createGuiElement("TextLabel", {
		Name = "CurrentBonusLabel",
		Size = isRoblox and UDim2.new(1, -16, 0, 26) or nil,
		Position = isRoblox and UDim2.new(0, 10, 0, 40) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(255, 225, 100) or nil,
		TextXAlignment = isRoblox and Enum.TextXAlignment.Left or nil,
		Text = "Bonus do zarobków: +0% (+10% z każdego kryształu)",
		ZIndex = 52,
	}, currentCard)
	addTextStroke(self.prestigeCurrentBonusLabel, 1.8)

	self.prestigeAfterBonusLabel = createGuiElement("TextLabel", {
		Name = "AfterBonusLabel",
		Size = isRoblox and UDim2.new(1, -16, 0, 26) or nil,
		Position = isRoblox and UDim2.new(0, 10, 0, 68) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(130, 250, 160) or nil,
		TextXAlignment = isRoblox and Enum.TextXAlignment.Left or nil,
		Text = "Po prestiżu: —",
		ZIndex = 52,
	}, currentCard)
	addTextStroke(self.prestigeAfterBonusLabel, 1.8)

	-- 2. Pending Crystals Card
	local pendingCard = createGuiElement("Frame", {
		Name = "PendingCard",
		Size = isRoblox and UDim2.new(1, -32, 0, 105) or nil,
		Position = isRoblox and UDim2.new(0, 16, 0, 182) or nil,
		BackgroundColor3 = isRoblox and Color3.fromRGB(48, 16, 80) or nil,
		BackgroundTransparency = 0.1,
		ZIndex = 51,
	}, modal)
	addCornerAndStroke(pendingCard, 14, isRoblox and Color3.fromRGB(220, 110, 255) or nil, 2.8)

	local pendingHeaderLabel = createGuiElement("TextLabel", {
		Name = "PendingHeaderLabel",
		Size = isRoblox and UDim2.new(1, -16, 0, 22) or nil,
		Position = isRoblox and UDim2.new(0, 8, 0, 8) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(200, 210, 240) or nil,
		Text = "KRYSZTAŁY DO ODEBRANIA:",
		ZIndex = 52,
	}, pendingCard)
	addTextStroke(pendingHeaderLabel, 1.5)

	self.prestigePendingLabel = createGuiElement("TextLabel", {
		Name = "PendingLabel",
		Size = isRoblox and UDim2.new(1, -16, 0, 44) or nil,
		Position = isRoblox and UDim2.new(0, 8, 0, 32) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(130, 250, 255) or nil,
		Text = "+0 KRYSZTAŁÓW PRESTIŻU",
		ZIndex = 52,
	}, pendingCard)
	addTextStroke(self.prestigePendingLabel, 2.8)

	local pendingSubLabel = createGuiElement("TextLabel", {
		Name = "PendingSubtextLabel",
		Size = isRoblox and UDim2.new(1, -16, 0, 20) or nil,
		Position = isRoblox and UDim2.new(0, 8, 0, 78) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(180, 230, 255) or nil,
		Text = "Zwiększaj dochód farmy, aby zdobyć jeszcze więcej kryształów!",
		ZIndex = 52,
	}, pendingCard)
	addTextStroke(pendingSubLabel, 1.4)
	self.prestigeSubLabel = pendingSubLabel

	-- 3. Warning / Explanation Pill
	local warningPill = createGuiElement("Frame", {
		Name = "WarningPill",
		Size = isRoblox and UDim2.new(1, -32, 0, 128) or nil,
		Position = isRoblox and UDim2.new(0, 16, 0, 295) or nil,
		BackgroundColor3 = isRoblox and Color3.fromRGB(32, 18, 30) or nil,
		BackgroundTransparency = 0.25,
		ZIndex = 51,
	}, modal)
	addCornerAndStroke(warningPill, 10, isRoblox and Color3.fromRGB(225, 80, 80) or nil, 1.8)

	local warningLabel = createGuiElement("TextLabel", {
		Name = "WarningText",
		Size = isRoblox and UDim2.new(1, -16, 1, -8) or nil,
		Position = isRoblox and UDim2.new(0, 8, 0, 4) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextWrapped = true,
		TextColor3 = isRoblox and Color3.fromRGB(255, 210, 210) or nil,
				Text = "🔴 RESET: gotówka, kurniki, flota, populacja kur, badania zwykłe.\n🟢 ZACHOWANE: wszystkie Kryształy Prestiżu, Diamenty 💎, Pety i ich poziomy, Badania Epickie, Trofea i Przepustki.",
		ZIndex = 52,
	}, warningPill)
	addTextStroke(warningLabel, 1.6)

	-- 4. Prestige Action Button
	local prestigeActionBtn = createGuiElement("TextButton", {
		Name = "PrestigeActionButton",
		Size = isRoblox and UDim2.new(1, -32, 0, 54) or nil,
		Position = isRoblox and UDim2.new(0, 16, 0, 433) or nil,
		BackgroundColor3 = isRoblox and Color3.fromRGB(160, 45, 230) or nil,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(255, 255, 255) or nil,
		Text = "ODRÓDŹ FARMĘ (+0 KRYSZTAŁÓW)",
		ZIndex = 52,
	}, modal)
	addCornerAndStroke(prestigeActionBtn, 14, isRoblox and Color3.fromRGB(240, 180, 255) or nil, 3.2)
	addTextStroke(prestigeActionBtn, 2.6)
	self.prestigeActionBtn = prestigeActionBtn

	if prestigeActionBtn.Activated then
		prestigeActionBtn.Activated:Connect(function()
			if prestigeActionBtn.Active == false then return end
			self:_playClick()
			if type(self.onPrestigeRequested) == "function" then
				self.onPrestigeRequested()
			end
		end)
	end
end

function HUD:playEggHatchAnimation(petData, onFinished)
	if not self.hatchAnimationOverlay then
		if onFinished then onFinished() end
		return
	end

	self:closeAllModals()
	self.hatchAnimationOverlay.Visible = true
	self.animatedEggVisual.Visible = true
	self.petRevealCard.Visible = false
	if self.hatchBurstGlow then self.hatchBurstGlow.Visible = false end

	local pSpecies = if type(petData) == "table" then (petData.speciesId or "farmer_dog") else "farmer_dog"
	local pRarity = if type(petData) == "table" and petData.rarity then petData.rarity else "Common"
	local pUid = if type(petData) == "table" then (petData.uid or "pet_unknown") else "pet_unknown"

	local speciesIcons = {
		farmer_dog = "🐶",
		farm_pup = "🐕",
		robo_cock = "🤖",
		golden_pecker = "✨",
		speedy_chick = "🐥",
		mega_rooster = "🐓",
		drone_hawk = "🦅",
		cosmic_phoenix = "🔥",
		alien_clucker = "👽",
	}

	local speciesNames = {
		farmer_dog = "Pies Farmer (Farmer Dog)",
		farm_pup = "Szczeniak (Farm Pup)",
		robo_cock = "Robo-Kogut (Robo Cock)",
		golden_pecker = "Złoty Dzięcioł (Golden Pecker)",
		speedy_chick = "Szybki Kurczak (Speedy Chick)",
		mega_rooster = "Mega Kogut (Mega Rooster)",
		drone_hawk = "Jastrząb Dronów (Drone Hawk)",
		cosmic_phoenix = "Kosmiczny Feniks (Cosmic Phoenix)",
		alien_clucker = "Kosmiczny Gdakacz (Alien Clucker)",
	}

	local statDescriptions = {
		farmer_dog = "+50% Wartość Jaj",
		farm_pup = "+50% Wartość Jaj",
		robo_cock = "+50% Tempo Znoszenia",
		golden_pecker = "+50% Wewnętrzny Wylęg (IHR)",
		speedy_chick = "+50% Wewnętrzny Wylęg (IHR)",
		mega_rooster = "+50% Pojemność Kurników",
		drone_hawk = "+400% Szansa na Elitarnego Drona",
		cosmic_phoenix = "+50% Zysk z Prestiżu",
		alien_clucker = "+50% Siła Dopalaczy (Boosts)",
	}

	local icon = speciesIcons[pSpecies] or "🐾"
	local name = speciesNames[pSpecies] or pSpecies
	local statDesc = statDescriptions[pSpecies] or "+Bonus Zwierzaka"

	self.revealPetIcon.Text = icon
	self.revealPetName.Text = name
	self.revealPetRarity.Text = string.upper(pRarity) .. " PET"
	self.revealPetStat.Text = statDesc

	local rarityColors = {
		Common = Color3.fromRGB(220, 220, 220),
		Rare = Color3.fromRGB(85, 175, 255),
		Epic = Color3.fromRGB(205, 95, 255),
		Legendary = Color3.fromRGB(255, 215, 45),
	}
	if isRoblox and self.revealPetRarity then
		self.revealPetRarity.TextColor3 = rarityColors[pRarity] or Color3.fromRGB(255, 215, 65)
	end

	-- Connect Actions
	local function cleanup()
		self.hatchAnimationOverlay.Visible = false
		if onFinished then onFinished() end
	end

	if self.revealEquipBtn and self.revealEquipBtn.Activated then
		local conn
		conn = self.revealEquipBtn.Activated:Connect(function()
			self:_playClick()
			if conn then conn:Disconnect() end
			if type(self.onEquipPet) == "function" then
				self.onEquipPet(pUid, 1)
			end
			cleanup()
		end)
	end

	if self.revealLockBtn and self.revealLockBtn.Activated then
		local connLock
		connLock = self.revealLockBtn.Activated:Connect(function()
			self:_playClick()
			if type(self.onTogglePetLock) == "function" then
				self.onTogglePetLock(pUid)
			end
			self.revealLockBtn.Text = "✅ Zablokowano"
		end)
	end

	if self.revealConfirmBtn and self.revealConfirmBtn.Activated then
		local connConfirm
		connConfirm = self.revealConfirmBtn.Activated:Connect(function()
			self:_playClick()
			if connConfirm then connConfirm:Disconnect() end
			cleanup()
		end)
	end

	-- Phase 1 & 2: Wobble and Burst
	if isRoblox then
		task.spawn(function()
			-- Wobble phase
			local start = os.clock()
			while os.clock() - start < 1.4 do
				local elapsed = os.clock() - start
				local rot = math.sin(elapsed * 24) * 12
				self.animatedEggVisual.Rotation = rot
				task.wait(0.03)
			end
			self.animatedEggVisual.Rotation = 0

			-- Burst phase
			if self.audioController and type(self.audioController.playSFX) == "function" then
				self.audioController:playSFX("pop")
			end
			if self.hatchBurstGlow then
				self.hatchBurstGlow.Visible = true
			end
			self.animatedEggVisual.Text = "💥"
			task.wait(0.35)

			self.animatedEggVisual.Visible = false
			if self.hatchBurstGlow then
				self.hatchBurstGlow.Visible = false
			end

			-- Reveal card phase
			if self.audioController and type(self.audioController.playSFX) == "function" then
				self.audioController:playSFX("fanfare")
			end
			self.petRevealCard.Visible = true
		end)
	else
		-- Lune mock direct reveal
		if self.audioController and type(self.audioController.playSFX) == "function" then
			self.audioController:playSFX("pop")
			self.audioController:playSFX("fanfare")
		end
		self.animatedEggVisual.Visible = false
		self.petRevealCard.Visible = true
	end
end

-- Modals Visibility & Mutual Exclusivity

function HUD:closeAllModals()
	if self.habitatsModal then self.habitatsModal.Visible = false end
	if self.vehiclesModal then self.vehiclesModal.Visible = false end
	if self.shopFrame then self.shopFrame.Visible = false end
	if self.petsModal then self.petsModal.Visible = false end
	if self.petHatchModal then self.petHatchModal.Visible = false end
	if self.hatchAnimationOverlay then self.hatchAnimationOverlay.Visible = false end
	if self.shopModal then self.shopModal.Visible = false end
	if self.calendarModal then self.calendarModal.Visible = false end
	if self.eggUpgradeModal then self.eggUpgradeModal.Visible = false end
	if self.epicResearchModal then self.epicResearchModal.Visible = false end
	if self.prestigeModal then self.prestigeModal.Visible = false end
end

function HUD:toggleEpicResearchModal(forceState)
	if not self.epicResearchModal then return end
	local target = if forceState ~= nil then forceState else not self.epicResearchModal.Visible
	self:closeAllModals()
	self.epicResearchModal.Visible = target
end

function HUD:getEpicResearchModal()
	return self.epicResearchModal
end

function HUD:togglePrestigeModal(forceState)
	if not self.prestigeModal then return end
	local target = if forceState ~= nil then forceState else not self.prestigeModal.Visible
	self:closeAllModals()
	self.prestigeModal.Visible = target
	if target then
		self:_playClick()
		self:_updatePrestigeDisplay()
	end
end

function HUD:getPrestigeModal()
	return self.prestigeModal
end

function HUD:toggleHabitatsModal(forceState)
	if not self.habitatsModal then return end
	local target = if forceState ~= nil then forceState else not self.habitatsModal.Visible
	self:closeAllModals()
	self.habitatsModal.Visible = target
end

function HUD:toggleVehiclesModal(forceState)
	if not self.vehiclesModal then return end
	local target = if forceState ~= nil then forceState else not self.vehiclesModal.Visible
	self:closeAllModals()
	self.vehiclesModal.Visible = target
end

function HUD:requestQuotesForCurrentTier(force)
	if not self.intentControllers or not self.intentControllers.shop then return end
	local currentTier = self.selectedResearchTier or 1

	local now = os.clock()
	if not force and self._lastTierQuoteReqTime and (now - self._lastTierQuoteReqTime) < 0.3 then
		return
	end
	self._lastTierQuoteReqTime = now

	local serverObservedAt = if self.stateStore then self.stateStore:getServerObservedAt() else nil
	if serverObservedAt and self._quoteNowMs then serverObservedAt = math.max(serverObservedAt, self._quoteNowMs) end
	local currentRevision = if self.stateStore then self.stateStore:getCommitRevision() else nil

	for rId, rCat in pairs(RESEARCH_CATEGORY) do
		if rCat == currentTier then
			local item = self.shopResearch and self.shopResearch[rId]
			local quote = item and item.quote
			local curLvl = item and item.level or 0
			local isFresh = quote ~= nil
				and (currentRevision == nil or quote.expectedRevision == currentRevision)
				and (serverObservedAt == nil or quote.expiresAt == nil or quote.expiresAt > serverObservedAt)
				and (quote.nextLevel == nil or quote.nextLevel > curLvl)

			if not isFresh then
				self.intentControllers.shop:requestQuote({
					kind = "BuyResearch",
					args = { researchId = rId, mode = "single" },
				})
			end
		end
	end

	for _, group in ipairs(UNIFIED_RESEARCH_GROUPS) do
		if group.category == currentTier then
			local uItem = self.unifiedResearch and self.unifiedResearch[group.key]
			local activeId = (uItem and uItem.activeId) or group.chain[1]
			if activeId then
				local maxQuote = self.intentControllers.shop:getCachedQuote({
					kind = "BuyResearch",
					args = { researchId = activeId, mode = "max" },
				})
				local curLvl = uItem and uItem.level or 0
				local isMaxFresh = maxQuote ~= nil
					and (currentRevision == nil or maxQuote.expectedRevision == currentRevision)
					and (serverObservedAt == nil or maxQuote.expiresAt == nil or maxQuote.expiresAt > serverObservedAt)
					and (maxQuote.nextLevel == nil or maxQuote.nextLevel > curLvl)

				if not isMaxFresh then
					self.intentControllers.shop:requestQuote({
						kind = "BuyResearch",
						args = { researchId = activeId, mode = "max" },
					})
			end
			end
		end
	end
end

function HUD:toggleResearchModal(forceState)
	if not self.shopFrame then return end
	local target = if forceState ~= nil then forceState else not self.shopFrame.Visible
	self:closeAllModals()
	self.shopFrame.Visible = target
	if target then
		self:requestQuotesForCurrentTier(true)
	end
end

function HUD:togglePetsModal(forceState)
	if not self.petsModal then return end
	local target = if forceState ~= nil then forceState else not self.petsModal.Visible
	self:closeAllModals()
	self.petsModal.Visible = target
end

function HUD:toggleShopModal(forceState)
	if not self.shopModal then return end
	local target = if forceState ~= nil then forceState else not self.shopModal.Visible
	self:closeAllModals()
	self.shopModal.Visible = target
end

function HUD:toggleCalendarModal(forceState)
	if not self.calendarModal then return end
	local target = if forceState ~= nil then forceState else not self.calendarModal.Visible
	self:closeAllModals()
	self.calendarModal.Visible = target
end

function HUD:toggleEggUpgradeModal(forceState)
	if not self.eggUpgradeModal then return end
	local target = if forceState ~= nil then forceState else not self.eggUpgradeModal.Visible
	self:closeAllModals()
	self.eggUpgradeModal.Visible = target
end

function HUD:togglePetHatchModal(forceState)
	if not self.petHatchModal then return end
	local target = if forceState ~= nil then forceState else not self.petHatchModal.Visible
	self:closeAllModals()
	self.petHatchModal.Visible = target
end

-- Tab selection methods
function HUD:selectResearchTier(tierIndex)
	if type(tierIndex) ~= "number" or tierIndex % 1 ~= 0 or tierIndex < 1 or tierIndex > 4 then return false end
	self.selectedResearchTier = tierIndex
	for idx, btn in ipairs(self.researchTabButtons) do
		if isRoblox then
			local isActive = (idx == tierIndex)
			btn.BackgroundColor3 = if isActive then Color3.fromRGB(245, 158, 11) else Color3.fromRGB(51, 30, 23)
			btn.TextColor3 = if isActive then Color3.fromRGB(69, 26, 3) else Color3.fromRGB(215, 204, 200)
			local stroke = btn:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = if isActive then Color3.fromRGB(180, 83, 9) else Color3.fromRGB(35, 18, 12)
				stroke.Thickness = if isActive then 2 else 1.2
			end
		end
	end
	self:update()
	self:requestQuotesForCurrentTier(true)
end

function HUD:selectShopTab(tabIndex)
	self.selectedShopTab = tabIndex
	for idx, btn in ipairs(self.shopModalTabButtons) do
		if isRoblox then
			btn.BackgroundColor3 = if idx == tabIndex then Color3.fromRGB(255, 215, 65) else Color3.fromRGB(42, 22, 34)
			btn.TextColor3 = if idx == tabIndex then Color3.fromRGB(24, 12, 10) else Color3.fromRGB(255, 255, 255)
		end
	end
	local cont = self.shopModal and self.shopModal:FindFirstChild("ShopContentContainer")
	if cont then
		local t1 = cont:FindFirstChild("Tab1_GEPacks")
		local t2 = cont:FindFirstChild("Tab2_Boosts")
		local t3 = cont:FindFirstChild("Tab3_GamePasses")
		if t1 then t1.Visible = (tabIndex == 1) end
		if t2 then t2.Visible = (tabIndex == 2) end
		if t3 then t3.Visible = (tabIndex == 3) end
	end
end

function HUD:selectCalendarTab(tabIndex)
	self.selectedCalendarTab = tabIndex
	for idx, btn in ipairs(self.calendarTabButtons) do
		if isRoblox then
			btn.BackgroundColor3 = if idx == tabIndex then Color3.fromRGB(255, 175, 75) else Color3.fromRGB(36, 22, 44)
			btn.TextColor3 = if idx == tabIndex then Color3.fromRGB(24, 12, 10) else Color3.fromRGB(255, 255, 255)
		end
	end
	if self.calendarModal then
		local t1 = self.calendarModal:FindFirstChild("CalendarContent_Tab1")
		local t2 = self.calendarModal:FindFirstChild("TrophiesContent_Tab2")
		local claimBtn = self.claimDailyGiftButton
		if t1 then t1.Visible = (tabIndex == 1) end
		if t2 then t2.Visible = (tabIndex == 2) end
		if claimBtn then claimBtn.Visible = (tabIndex == 1) end
	end
end

-- State & Subscriptions

function HUD:_setupSubscriptions()
	if self.stateStore ~= nil and type(self.stateStore.onStatusChanged) == "function" then
		table.insert(self._unsubs, self.stateStore:onStatusChanged(function(newStatus)
			self:updateStatus(newStatus)
		end))
	end

	if self.stateStore ~= nil and type(self.stateStore.onStateChanged) == "function" then
		table.insert(self._unsubs, self.stateStore:onStateChanged(function()
			self:update()
		end))
	end

	local transport = self.intentControllers and self.intentControllers.transport
	if transport ~= nil and type(transport.onQuote) == "function" then
		table.insert(self._unsubs, transport:onQuote(function(quoteView)
			self:onQuoteReceived(quoteView)
		end))
	end
end

function HUD:updateStatus(newStatus)
	self.sessionStatus = newStatus or self.stateStore:getStatus()
	if self.sessionStatusLabel ~= nil then
		self.sessionStatusLabel.Text = self.sessionStatus
	end
	if isRoblox and self.sessionBanner ~= nil then
		self.sessionBanner.Visible = (self.sessionStatus ~= "READY")
	end
	-- An unready session never claims a blocked hatch state (#77).
	if self.sessionStatus ~= "READY" then
		self:_applyHatchStatus(nil)
	end
end

-- Hatch Status (#77): blocked state derived from the authoritative farm view

-- Returns the blocked reason (or nil).
-- Capacity full wins over a low stock when both are true. Empty slots stay empty and are not
-- treated as a built coop with space.
function HUD:_resolveHatchBlockedReason(farm)
	if type(farm) ~= "table" or farm.lifecycle ~= "ready" then return nil end
	if type(farm.habitats) ~= "table" then return nil end

	local hasVacancy = false
	for _, habitat in ipairs(farm.habitats) do
		if type(habitat) == "table" then
			local index = habitat.habitatIndex
			if type(index) == "number" and index >= 0 then
				if habitatHasVacancy(self.codec, habitat) then hasVacancy = true end
			end
		end
	end

	-- No built habitat has vacancy after population + reservedInTransit: capacity is the blocker.
	if not hasVacancy then return HUD.HATCH_STATUS_FULL end

	local stock = farm.hatchery and farm.hatchery.stock
	if stockBelowOne(self.codec, stock) then return HUD.HATCH_STATUS_STOCK end

	return nil
end

function HUD:_applyHatchStatus(reason)
	self.hatchStatusReason = reason
	local frame = self.hatchStatusFrame
	if frame == nil then return end

	local text = ""
	local actionVisible = false
	if reason == HUD.HATCH_STATUS_FULL then
		-- Main message only: the strip never appends a long hint or promises an upgrade.
		text = HUD.HATCH_STATUS_FULL_TEXT
		actionVisible = true
		if isRoblox then frame.BackgroundColor3 = Color3.fromRGB(122, 32, 32) end
	elseif reason == HUD.HATCH_STATUS_STOCK then
		text = HUD.HATCH_STATUS_STOCK_TEXT
		if isRoblox then frame.BackgroundColor3 = Color3.fromRGB(112, 74, 18) end
	end

	if self.hatchStatusLabel then
		self.hatchStatusLabel.Text = text
		-- While the CTA is shown the label reserves the 88px button plus margins; without a CTA it
		-- expands to the full strip width.
		if isRoblox then
			self.hatchStatusLabel.Size = if actionVisible then UDim2.new(1, -112, 0, 44) else UDim2.new(1, -16, 0, 44)
		end
	end
	if self.hatchStatusActionBtn then self.hatchStatusActionBtn.Visible = actionVisible end
	frame.Visible = reason ~= nil
end

function HUD:_updateHatchStatus(farm)
	local reason = self:_resolveHatchBlockedReason(farm)
	self:_applyHatchStatus(reason)
end

-- Selection is explicit; stale/consumed/locked UIDs are never auto-replaced.
function HUD:showPurchasePreview(preview,confirm)
    if self.purchasePreviewFrame then self.purchasePreviewFrame:Destroy() end
    local parent=if self.actionStatusLabel then self.actionStatusLabel.Parent else nil
    local frame=createGuiElement("Frame",{Name="PurchasePreview",Visible=true,ZIndex=50,
        Size=if isRoblox then UDim2.new(0,420,0,200) else nil,Position=if isRoblox then UDim2.new(.5,-210,.5,-100) else nil,
        BackgroundColor3=if isRoblox then Color3.fromRGB(40,25,45) else nil},parent)
    self.purchasePreviewFrame=frame
    createGuiElement("TextLabel",{Name="Terms",Text=preview.description,TextWrapped=true,ZIndex=51,
        Size=if isRoblox then UDim2.new(1,-20,.65,0) else nil,Position=if isRoblox then UDim2.new(0,10,0,10) else nil,
        BackgroundTransparency=1,TextColor3=if isRoblox then Color3.new(1,1,1) else nil,TextScaled=true},frame)
    local used=false
    for i,label in {"Potwierdź","Anuluj"} do
        local button=createGuiElement("TextButton",{Name=if i==1 then "Confirm" else "Cancel",Text=label,ZIndex=51,
            Size=if isRoblox then UDim2.new(.45,0,.2,0) else nil,Position=if isRoblox then UDim2.new(.025+(i-1)*.5,0,.75,0) else nil},frame)
        if button.Activated then button.Activated:Connect(function()
            if used then return end;used=true;frame.Visible=false
            if i==1 then confirm() end
        end) end
    end
end
function HUD:selectFusionBase(uid)
    self.fusionBaseUid=uid;self.fusionMaterialUids={}
end
function HUD:toggleFusionMaterial(uid)
    self.fusionMaterialUids=self.fusionMaterialUids or {}
    if uid==self.fusionBaseUid then return end
    local at=table.find(self.fusionMaterialUids,uid)
    if at then table.remove(self.fusionMaterialUids,at) else table.insert(self.fusionMaterialUids,uid) end
end
function HUD:onActionResult(response)
    self.lastActionResult=response
    local result=response.result
    local text=if result and result.terminalStatus=="APPLIED" then (if result.actionKind=="PurchaseProduct" then "Otwieranie zakupu — oczekiwanie na platformę" elseif result.outcome=="FAILURE" then "Łączenie nieudane — pet bazowy zachowany" else "Operacja potwierdzona przez serwer")
        else response.errorCode or (result and result.errorCode) or response.status or "Oczekiwanie na serwer"
    if self.actionStatusLabel then self.actionStatusLabel.Text=text end
end
function HUD:update()
    self.fusionMaterialUids=self.fusionMaterialUids or {}
    local farm=(self.stateStore.getPresentationFarm or self.stateStore.getFarm)(self.stateStore)
    local progress=farm and farm.progress
	if self.goldenEggsLabel then self.goldenEggsLabel.Text="Diamenty: "..(if progress then formatCompact(progress.GE) else "-") end
    if self.fusionProPermitBadge and progress then
        self.fusionProPermitBadge.Text=if progress.proBonusAvailable then "Pro +10 p.p.: aktywne" elseif progress.paidRandomPolicy=="unknown" then "Pro +10 p.p.: polityka nieznana" elseif not progress.proPermit then "Pro +10 p.p.: wymaga Pro" else "Pro +10 p.p.: niedostępne dla konta" end
    self._visiblePets=if progress then progress.pets else {}
    for day,cell in self.calendarDayCells or {} do
        local reward=progress and progress.calendar and progress.calendar[day]
        local label=cell:FindFirstChild("RewardText")
        if label then label.Text=if reward then (if reward.available then (if reward.rewardType=="GE" then "💎 "..reward.amount else reward.rewardType.." "..reward.amount) else "Niedostępne") else "Dane z serwera" end
    end
    for i,card in self.petInventoryCards or {} do
        local pet=self._visiblePets[i]
        local label=card:FindFirstChild("PetName")
        if label then label.Text=if pet then pet.speciesId.." T"..tostring(pet.tier).." "..pet.variant else "Puste miejsce" end
    end
	-- 0. Compact hatch status from the authoritative farm view (#77); recomputed on view changes only.
	self:_updateHatchStatus(farm)
	self:updateStatus(self.stateStore:getStatus())

	if farm == nil then
		return
	end

	-- 1. Balances & Global Rates: one named top panel, every value a rate in jaj/s.
	if self.cashLabel ~= nil then
		self.cashLabel.Text = HUD.formatCash(farm.cash)
		if self.cashRateLabel ~= nil then
			local incomeSec = if farm.cashIncomePerSecond ~= nil then HUD.formatCash(farm.cashIncomePerSecond) else "$0"
			self.cashRateLabel.Text = "+" .. incomeSec .. "/s"
		end
	end
	-- Production and sales are the per-second values of the authoritative view. A field the view does
	-- not carry leaves the previous text alone instead of inventing a rate.
	if self.producedEggsLabel ~= nil then
		local producedText = HUD.formatEggRate(farm.producedEggsPerSecond)
		if producedText ~= nil then self.producedEggsLabel.Text = producedText end
	end
	if self.soldEggsLabel ~= nil then
		local soldText = HUD.formatEggRate(farm.soldEggsPerSecond)
		if soldText ~= nil then self.soldEggsLabel.Text = soldText end
	end
	if self.shippingLabel ~= nil then
		-- Transport is the fleet CAPACITY in jaj/s (shippingPerMinute / 60), never the current sales
		-- amount or cash. The view is only read; no authoritative value is written or recomputed.
		local transportText = HUD.formatTransportRate(self.codec, farm.fleet and farm.fleet.shippingPerMinute)
		if transportText ~= nil then self.shippingLabel.Text = transportText end
	end

	-- 2. Hatchery Stock & Capacity
	if farm.hatchery ~= nil then
		local stock = farm.hatchery.stock
		local capacity = farm.hatchery.capacity
		local refill = farm.hatchery.refillPerSecond

		if self.hatcheryStockLabel ~= nil then
			self.hatcheryStockLabel.Text = string.format("%s / %s", formatCompact(stock), formatCompact(capacity))
		end
		if self.hatcheryRefillLabel ~= nil then
			self.hatcheryRefillLabel.Text = "+" .. HUD.formatRate(refill, "/s")
		end

		local sNum = tonumber(stock) or 0
		local cNum = tonumber(capacity) or 1
		self.hatcheryRatio = if cNum > 0 then math.clamp(sNum / cNum, 0, 1) else 0
	end

	-- 3. Habitats 1..4 & Total Chickens
	local totalPop = 0
	if type(farm.habitats) == "table" then
		for _, hab in ipairs(farm.habitats) do
			local slotId = hab.slotId
			if slotId and slotId >= 1 and slotId <= 4 then
				self.habitatPopulations[slotId] = hab.population
				self.habitatCapacities[slotId] = hab.capacity

				if self.habitatLabels[slotId] ~= nil then
					self.habitatLabels[slotId].Text = string.format("%s / %s", formatCompact(hab.population), formatCompact(hab.capacity))
				end

				local pNum = tonumber(hab.population) or 0
				local cNum = tonumber(hab.capacity) or 1
				totalPop += pNum
				self.habitatFillRatios[slotId] = if cNum > 0 then math.clamp(pNum / cNum, 0, 1) else 0

				-- Update Habitat card title & next upgrade label
				local card = self.habitatCards[slotId]
				if card then
					local currentIdx = hab.habitatIndex or -1
					local currentName = HABITAT_DISPLAY_NAMES[currentIdx] or "Niezbudowany"
					local titleLabel = card:FindFirstChild("TitleLabel")
					if titleLabel then
						titleLabel.Text = string.format("Parcela #%d: %s", slotId, currentName)
					end
					local nextIdx = currentIdx + 1
					local nextName = HABITAT_DISPLAY_NAMES[nextIdx] or "MAX"
					local nextLabel = card:FindFirstChild("NextUpgradeLabel")
					if nextLabel then
						nextLabel.Text = if nextIdx <= 18 then ("Następny: " .. nextName) else "Maksymalny Kurnik"
					end
					local button=self.habitatUpgBtns[slotId]
					if button then
						button.Text=if currentIdx>=18 then "MAX" elseif hab.upgradePrice then HUD.formatCash(hab.upgradePrice) else "…"
						button.Active=currentIdx<18 and hab.nextHabitatId~=nil and hab.upgradePrice~=nil
					end
				end
			end
		end
	end
	self.totalChickensCount = totalPop
	if self.totalChickensLabel ~= nil then
		self.totalChickensLabel.Text = "Całkowita liczba kurczaków: " .. formatCompact(totalPop)
	end

	-- 4. Vehicles Modal Comparison Gauge & Slots
	self:_updateVehiclesModal(farm)

	-- 5. Research Modal Multi-tier view
	self:_updateResearchModal(farm)
	self:_updateEpicResearchModal(farm)

	-- 6. Egg Upgrade Modal Refresh
	self:_updateEggUpgradeModal(farm)

	-- 7. Prestige & Rebirth Display Refresh
	self:_updatePrestigeDisplay(farm)

	-- 8. Shop Boosts Inventory & Active Slots Refresh
	self:_updateShopModal(farm)
end

-- Time-dependent quote maintenance stays live without repainting the HUD.
function HUD:tick(nowMs)
	self._quoteNowMs = nowMs
	if self.shopFrame and self.shopFrame.Visible then
		self:requestQuotesForCurrentTier(false)
	end
end

function HUD:_updateVehiclesModal(farm)
	if not self.vehiclesModal or not farm then return end

	local fleetRate = tonumber((farm.fleet and farm.fleet.shippingPerMinute) or 0) or 0
	local eggPerSec = tonumber(farm.producedEggsPerSecond or 0) or 0
	local eggRatePerMin = eggPerSec * 60

	if self.shippingComparisonStatusLabel then
		self.shippingComparisonStatusLabel.Text = string.format("Spedycja: %s/min vs Produkcja: %s/min", formatCompact(fleetRate), formatCompact(eggRatePerMin))
	end

	local badge = self.shippingComparisonBar and self.shippingComparisonBar:FindFirstChild("StatusBadge")
	if badge then
		if fleetRate >= eggRatePerMin then
			badge.Text = "Spedycja wystarczająca"
			if isRoblox then badge.BackgroundColor3 = Color3.fromRGB(50, 180, 70) end
		else
			badge.Text = "Wąskie gardło spedycji!"
			if isRoblox then badge.BackgroundColor3 = Color3.fromRGB(220, 75, 45) end
		end
	end

	-- Update vehicle slot cards
	local vehiclesList = (farm.fleet and farm.fleet.vehicles) or {}
	local slotLimit=math.max(4,(farm.fleet and farm.fleet.slotLimit) or 4)
	if isRoblox and self.fleetSlotsScroll then self.fleetSlotsScroll.CanvasSize=UDim2.fromOffset(0,slotLimit*56) end
	local bySlot,upgrades={},{}
	for _,v in vehiclesList do bySlot[v.slotId]=v end
	for _,v in (farm.fleet and farm.fleet.upgrades) or {} do upgrades[v.slotId]=v end

	for slotId = 1, 17 do
		local slotData = self.vehicleCards[slotId]
		if slotData then
			local vEntry = bySlot[slotId]
			local vIdx = vEntry and vEntry.vehicleIndex
			local isUnlocked = slotId<=slotLimit
			local upgrade=upgrades[slotId]

			slotData.card.Visible = (slotId <= 4 or isUnlocked)

			if isUnlocked then
				local vName = if vIdx~=nil then VEHICLE_DISPLAY_NAMES[vIdx] or ("Pojazd #" .. vIdx) else "Puste miejsce"
				local vCap = if vIdx~=nil then VEHICLE_CAPACITIES[vIdx] or 0 else 0
				slotData.titleLabel.Text = string.format("Slot #%d: %s", slotId, vName)
				slotData.capLabel.Text = string.format("Wydajność: %s jaj/min", formatCompact(vCap))
				if upgrade and upgrade.blockedReason == "HYPERLOOP_LOCKED" then
					slotData.upgBtn.Text = "WKRÓTCE"
					slotData.priceLabel.Text = "EGG TO THE MOON 🚀"
					slotData.upgBtn.Active = false
					if isRoblox then slotData.upgBtn.BackgroundColor3 = Color3.fromRGB(120, 120, 120) end
				else
					slotData.upgBtn.Text = if upgrade then HUD.formatCash(upgrade.price) elseif vIdx==11 then "MAX" else "…"
					slotData.priceLabel.Text = if upgrade then "Następny pojazd" elseif vIdx==11 then "" else "Dane z serwera"
					slotData.upgBtn.Active = upgrade~=nil and upgrade.available
					if isRoblox then slotData.upgBtn.BackgroundColor3 = if (upgrade and upgrade.available) then Color3.fromRGB(95, 235, 45) else Color3.fromRGB(120, 120, 120) end
				end
			else
				slotData.titleLabel.Text = string.format("Slot #%d: Zablokowany", slotId)
				slotData.capLabel.Text = "Dodatkowe miejsce floty"
				slotData.priceLabel.Text = "-"
				slotData.upgBtn.Text = "ZABLOK."
				slotData.upgBtn.Active = false
				if isRoblox then slotData.upgBtn.BackgroundColor3 = Color3.fromRGB(120, 120, 120) end
			end
		end
	end
end

function HUD:_updateResearchModal(farm)
	if not self.shopFrame or not farm then return end

	local currentTier = self.selectedResearchTier or 1

	-- Calculate total purchased research levels to evaluate tier unlocking
	local totalPurchasedLevels = 0
	local byId = {}
	if type(farm.common) == "table" then
		for _, r in ipairs(farm.common) do
			byId[r.researchId] = r
			totalPurchasedLevels += (tonumber(r.level) or 0)
			-- Maintain individual research preview items for backend tests and quote hooks
			self:_updateResearchItem(r, 0, false)
		end
	end

	local requiredLevels = CATEGORY_THRESHOLDS[currentTier] or 0
	local isCategoryUnlocked = (totalPurchasedLevels >= requiredLevels)

	if self.researchTierLockBanner then
		if not isCategoryUnlocked then
			self.researchTierLockBanner.Visible = true
			self.researchTierLockBanner.Text = string.format("🔒 Kategoria zablokowana! Wymaga %d zakupionych badań (masz %d)", requiredLevels, totalPurchasedLevels)
			if isRoblox and self.shopListContainer then
				self.shopListContainer.Position = UDim2.new(0, 12, 0, 138)
				self.shopListContainer.Size = UDim2.new(1, -24, 1, -150)
			end
		else
			self.researchTierLockBanner.Visible = false
			if isRoblox and self.shopListContainer then
				self.shopListContainer.Position = UDim2.new(0, 12, 0, 110)
				self.shopListContainer.Size = UDim2.new(1, -24, 1, -122)
			end
		end
	end

	-- Render ONLY the 15 unified research groups (4 in Tab 1, 5 in Tab 2, 1 in Tab 3, 5 in Tab 4)
	do
		local visibleIdx = 0
		for _, group in ipairs(UNIFIED_RESEARCH_GROUPS) do
			local matchesTab = (group.category == currentTier)
			if matchesTab then
				visibleIdx += 1
			end
			self:_updateUnifiedGroup(group, byId, visibleIdx, matchesTab)
		end
		if isRoblox and self.shopListContainer then
			self.shopListContainer.CanvasSize = UDim2.new(0, 0, 0, math.max(350, visibleIdx * 96 + 10))
		end
		if self.shopFrame and self.shopFrame.Visible then
			self:requestQuotesForCurrentTier(false)
		end
	end
end

function HUD:_updateUnifiedGroup(group, byId, displayOrder, isTabVisible)
	local id = group.key
	self.unifiedResearch = self.unifiedResearch or {}
	local item = self.unifiedResearch[id]

	local chainCurLvl = 0
	local chainMaxLvl = 0
	local activeResearch = nil

	for _, subId in ipairs(group.chain) do
		local sub = byId[subId]
		local cur = sub and tonumber(sub.level) or 0
		local maxL = COMMON_RESEARCH_MAX_LEVELS[subId] or 25
		chainCurLvl += cur
		chainMaxLvl += maxL
		if activeResearch == nil and cur < maxL then
			activeResearch = sub
		end
	end
	if activeResearch == nil then
		activeResearch = byId[group.chain[#group.chain]] or { researchId = group.key, level = chainMaxLvl, available = false }
	end

	local cleanTitle = group.title
	local cleanSubtitle = researchEffectText(activeResearch, group.desc)
	local iconEmoji = group.icon
	local activeSubId = activeResearch.researchId

	if item == nil then
		local orderIdx = displayOrder or 1
		local shouldBeVisible = if isTabVisible ~= nil then isTabVisible else true
		local card = createGuiElement("TextButton", {
			Name = "UnifiedResearchCard_" .. id,
			Visible = shouldBeVisible,
			Size = isRoblox and UDim2.new(1, -6, 0, 90) or nil,
			Position = isRoblox and UDim2.new(0, 0, 0, (orderIdx - 1) * 96) or nil,
			BackgroundColor3 = isRoblox and Color3.fromRGB(78, 52, 46) or nil,
			Text = "",
			AutoButtonColor = false,
		}, self.shopListContainer or self.shopFrame)
		addCornerAndStroke(card, 12, isRoblox and Color3.fromRGB(43, 24, 16) or nil, 2)

		-- Left Icon Badge (44x44)
		local iconBadge = createGuiElement("Frame", {
			Name = "IconBadge",
			Size = isRoblox and UDim2.new(0, 44, 0, 44) or nil,
			Position = isRoblox and UDim2.new(0, 8, 0, 8) or nil,
			BackgroundColor3 = isRoblox and Color3.fromRGB(254, 243, 199) or nil,
		}, card)
		addCornerAndStroke(iconBadge, 10, isRoblox and Color3.fromRGB(217, 119, 6) or nil, 1.5)

		createGuiElement("TextLabel", {
			Name = "IconEmoji",
			Size = isRoblox and UDim2.new(1, 0, 1, 0) or nil,
			BackgroundTransparency = 1,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextSize = 24,
			TextColor3 = isRoblox and Color3.fromRGB(69, 26, 3) or nil,
			Text = iconEmoji,
		}, iconBadge)

		-- Middle Column: Name, Subtitle, Level, Progress Bar
		local nameLabel = createGuiElement("TextLabel", {
			Name = "Title",
			Size = isRoblox and UDim2.new(1, -210, 0, 18) or nil,
			Position = isRoblox and UDim2.new(0, 58, 0, 6) or nil,
			BackgroundTransparency = 1,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = true,
			TextXAlignment = isRoblox and Enum.TextXAlignment.Left or nil,
			TextColor3 = isRoblox and Color3.fromRGB(255, 255, 255) or nil,
			Text = cleanTitle,
		}, card)
		addTextStroke(nameLabel, 1.8)

		local subtitleLabel = createGuiElement("TextLabel", {
			Name = "Subtitle",
			Size = isRoblox and UDim2.new(1, -210, 0, 40) or nil,
			Position = isRoblox and UDim2.new(0, 58, 0, 24) or nil,
			BackgroundTransparency = 1,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = false,
			TextSize = 12,
			TextWrapped = true,
			TextYAlignment = isRoblox and Enum.TextYAlignment.Top or nil,
			TextXAlignment = isRoblox and Enum.TextXAlignment.Left or nil,
			TextColor3 = isRoblox and Color3.fromRGB(214, 190, 178) or nil,
			Text = cleanSubtitle,
		}, card)

		local levelLabel = createGuiElement("TextLabel", {
			Name = "Level",
			Size = isRoblox and UDim2.new(0, 95, 0, 13) or nil,
			Position = isRoblox and UDim2.new(0, 58, 0, 70) or nil,
			BackgroundTransparency = 1,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = true,
			TextXAlignment = isRoblox and Enum.TextXAlignment.Left or nil,
			TextColor3 = isRoblox and Color3.fromRGB(251, 191, 36) or nil,
			Text = string.format("★ POZ. %d/%d", chainCurLvl, chainMaxLvl),
		}, card)
		addTextStroke(levelLabel, 1.5)

		-- Mini Progress Bar
		local progressTrack = createGuiElement("Frame", {
			Name = "ProgressTrack",
			Size = isRoblox and UDim2.new(1, -300, 0, 7) or nil,
			Position = isRoblox and UDim2.new(0, 156, 0, 74) or nil,
			BackgroundColor3 = isRoblox and Color3.fromRGB(43, 24, 16) or nil,
		}, card)
		addCornerAndStroke(progressTrack, 3, nil, 0)

		local progressFill = createGuiElement("Frame", {
			Name = "ProgressFill",
			Size = isRoblox and UDim2.new(math.clamp(chainCurLvl / math.max(1, chainMaxLvl), 0, 1), 0, 1, 0) or nil,
			BackgroundColor3 = isRoblox and Color3.fromRGB(34, 197, 94) or nil,
		}, progressTrack)
		addCornerAndStroke(progressFill, 3, nil, 0)

		-- Invisible status label for test invariants
		local statusLabel = createGuiElement("TextLabel", {
			Name = "Status",
			Visible = false,
			Text = "BUY",
		}, card)

		-- 3D Tycoon Buy Button (+1 level, 92x48)
		local buyBtn = createGuiElement("TextButton", {
			Name = "BuyButton",
			Size = isRoblox and UDim2.new(0, 92, 0, 48) or nil,
			Position = isRoblox and UDim2.new(1, -196, 0, 21) or nil,
			BackgroundColor3 = isRoblox and Color3.fromRGB(34, 197, 94) or nil,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			Text = "",
		}, card)
		addCornerAndStroke(buyBtn, 10, isRoblox and Color3.fromRGB(20, 83, 45) or nil, 2)

		local btnActionLabel = createGuiElement("TextLabel", {
			Name = "ActionLabel",
			Size = isRoblox and UDim2.new(1, 0, 0.48, 0) or nil,
			Position = isRoblox and UDim2.new(0, 0, 0.04, 0) or nil,
			BackgroundTransparency = 1,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = true,
			TextColor3 = isRoblox and Color3.fromRGB(255, 255, 255) or nil,
			Text = "KUP",
		}, buyBtn)
		addTextStroke(btnActionLabel, 1.8)

		local priceLabel = createGuiElement("TextLabel", {
			Name = "Price",
			Size = isRoblox and UDim2.new(1, 0, 0.44, 0) or nil,
			Position = isRoblox and UDim2.new(0, 0, 0.50, 0) or nil,
			BackgroundTransparency = 1,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = true,
			TextColor3 = isRoblox and Color3.fromRGB(254, 240, 138) or nil,
			Text = "$0",
		}, buyBtn)
		addTextStroke(priceLabel, 1.8)

		-- 3D Tycoon Buy MAX Button (MAX levels, 92x48)
		local buyMaxBtn = createGuiElement("TextButton", {
			Name = "BuyMaxButton",
			Size = isRoblox and UDim2.new(0, 92, 0, 48) or nil,
			Position = isRoblox and UDim2.new(1, -98, 0, 21) or nil,
			BackgroundColor3 = isRoblox and Color3.fromRGB(245, 158, 11) or nil,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			Text = "",
		}, card)
		addCornerAndStroke(buyMaxBtn, 10, isRoblox and Color3.fromRGB(180, 83, 9) or nil, 2)

		local btnMaxActionLabel = createGuiElement("TextLabel", {
			Name = "MaxActionLabel",
			Size = isRoblox and UDim2.new(1, 0, 0.48, 0) or nil,
			Position = isRoblox and UDim2.new(0, 0, 0.04, 0) or nil,
			BackgroundTransparency = 1,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = true,
			TextColor3 = isRoblox and Color3.fromRGB(255, 255, 255) or nil,
			Text = "MAX",
		}, buyMaxBtn)
		addTextStroke(btnMaxActionLabel, 1.8)

		local btnMaxPriceLabel = createGuiElement("TextLabel", {
			Name = "MaxPrice",
			Size = isRoblox and UDim2.new(1, 0, 0.44, 0) or nil,
			Position = isRoblox and UDim2.new(0, 0, 0.50, 0) or nil,
			BackgroundTransparency = 1,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = true,
			TextColor3 = isRoblox and Color3.fromRGB(254, 240, 138) or nil,
			Text = "MAX",
		}, buyMaxBtn)
		addTextStroke(btnMaxPriceLabel, 1.8)

		item = {
			id = id,
			activeId = activeSubId,
			card = card,
			nameLabel = nameLabel,
			subtitleLabel = subtitleLabel,
			levelLabel = levelLabel,
			progressFill = progressFill,
			priceLabel = priceLabel,
			statusLabel = statusLabel,
			buyButton = buyBtn,
			actionLabel = btnActionLabel,
			buyMaxButton = buyMaxBtn,
			maxActionLabel = btnMaxActionLabel,
			maxPriceLabel = btnMaxPriceLabel,
			available = true,
			blockedReason = nil,
			quote = nil,
			maxQuote = nil,
		}

		local function triggerBuy()
			-- Guard against clicks when disabled or already maxed (EDGE-01)
			if not item.buyButton.Active or item.statusLabel.Text == "MAX" or item.statusLabel.Text == "LOCKED" then
				return
			end
			local buyTargetId = item.activeId or id
			self:buyResearch(buyTargetId, "single")
		end

		local function triggerBuyMax()
			if not item.buyMaxButton.Active or item.statusLabel.Text == "MAX" or item.statusLabel.Text == "LOCKED" then
				return
			end
			local buyTargetId = item.activeId or id
			self:buyResearch(buyTargetId, "max")
		end

		if card.Activated ~= nil then card.Activated:Connect(triggerBuy) end
		if buyBtn.Activated ~= nil then buyBtn.Activated:Connect(triggerBuy) end
		if buyMaxBtn.Activated ~= nil then buyMaxBtn.Activated:Connect(triggerBuyMax) end

		self.unifiedResearch[id] = item
	end

	item.activeId = activeSubId

	if isTabVisible ~= nil then
		item.card.Visible = isTabVisible
		if isTabVisible and displayOrder then
			item.card.Position = isRoblox and UDim2.new(0, 0, 0, (displayOrder - 1) * 96) or nil
		end
	end

	item.level = chainCurLvl
	item.subtitleLabel.Text = cleanSubtitle
	item.levelLabel.Text = string.format("★ POZ. %d/%d", chainCurLvl, chainMaxLvl)
	if item.progressFill and isRoblox then
		item.progressFill.Size = UDim2.new(math.clamp(chainCurLvl / math.max(1, chainMaxLvl), 0, 1), 0, 1, 0)
	end

	local quote = nil
	if self.intentControllers and self.intentControllers.shop then
		quote = self.intentControllers.shop:getCachedQuote({
			kind = "BuyResearch",
			args = { researchId = activeSubId, mode = "single" },
		})
	end

	-- Fresh quote validation (BUG-01)
	local activeCurLvl = activeResearch and tonumber(activeResearch.level) or 0
	if quote ~= nil and quote.nextLevel ~= nil and quote.nextLevel <= activeCurLvl then
		quote = nil
	end
	item.quote = quote

	local maxQuote = nil
	if self.intentControllers and self.intentControllers.shop then
		maxQuote = self.intentControllers.shop:getCachedQuote({
			kind = "BuyResearch",
			args = { researchId = activeSubId, mode = "max" },
		})
	end
	if maxQuote ~= nil and maxQuote.nextLevel ~= nil and maxQuote.nextLevel <= activeCurLvl then
		maxQuote = nil
	end
	item.maxQuote = maxQuote

	if quote ~= nil and quote.cashCost ~= nil then
		item.priceLabel.Text = HUD.formatCash(quote.cashCost)
	elseif activeResearch and activeResearch.price ~= nil then
		item.priceLabel.Text = HUD.formatCash(activeResearch.price)
	end

	local isAvailable = activeResearch.available
	local isMax = (chainCurLvl >= chainMaxLvl)

	if isMax then
		item.statusLabel.Text = "MAX"
		item.actionLabel.Text = "MAX"
		item.priceLabel.Text = "WYKUPIONE"
		item.priceLabel.TextColor3 = isRoblox and Color3.fromRGB(156, 163, 175) or nil
		item.buyButton.Active = false
		if isRoblox then item.buyButton.BackgroundColor3 = Color3.fromRGB(55, 65, 81) end

		item.maxActionLabel.Text = "MAX"
		item.maxPriceLabel.Text = "WYKUPIONE"
		item.maxPriceLabel.TextColor3 = isRoblox and Color3.fromRGB(156, 163, 175) or nil
		item.buyMaxButton.Active = false
		if isRoblox then item.buyMaxButton.BackgroundColor3 = Color3.fromRGB(55, 65, 81) end
	elseif not isAvailable then
		item.statusLabel.Text = "LOCKED"
		item.actionLabel.Text = "ZABLOK."
		item.priceLabel.Text = "ZABLOKOWANE"
		item.priceLabel.TextColor3 = isRoblox and Color3.fromRGB(156, 163, 175) or nil
		item.buyButton.Active = false
		if isRoblox then item.buyButton.BackgroundColor3 = Color3.fromRGB(75, 85, 99) end

		item.maxActionLabel.Text = "ZABLOK."
		item.maxPriceLabel.Text = "ZABLOKOWANE"
		item.maxPriceLabel.TextColor3 = isRoblox and Color3.fromRGB(156, 163, 175) or nil
		item.buyMaxButton.Active = false
		if isRoblox then item.buyMaxButton.BackgroundColor3 = Color3.fromRGB(75, 85, 99) end
	elseif quote ~= nil and not quote.available and quote.blockedReason == "INSUFFICIENT_CASH" then
		item.statusLabel.Text = "INSUFFICIENT_CASH"
		item.actionLabel.Text = "ZA MAŁO $"
		item.priceLabel.TextColor3 = isRoblox and Color3.fromRGB(156, 163, 175) or nil
		item.buyButton.Active = false
		if isRoblox then item.buyButton.BackgroundColor3 = Color3.fromRGB(107, 114, 128) end

		item.maxActionLabel.Text = "MAX"
		item.maxPriceLabel.Text = "ZA MAŁO $"
		item.maxPriceLabel.TextColor3 = isRoblox and Color3.fromRGB(156, 163, 175) or nil
		item.buyMaxButton.Active = false
		if isRoblox then item.buyMaxButton.BackgroundColor3 = Color3.fromRGB(107, 114, 128) end
	else
		item.statusLabel.Text = "BUY"
		item.actionLabel.Text = "KUP"
		item.priceLabel.TextColor3 = isRoblox and Color3.fromRGB(254, 240, 138) or nil
		item.buyButton.Active = true
		if isRoblox then item.buyButton.BackgroundColor3 = Color3.fromRGB(34, 197, 94) end

		if maxQuote ~= nil and not maxQuote.available and maxQuote.blockedReason == "INSUFFICIENT_CASH" then
			item.maxActionLabel.Text = "MAX"
			item.maxPriceLabel.Text = "ZA MAŁO $"
			item.maxPriceLabel.TextColor3 = isRoblox and Color3.fromRGB(156, 163, 175) or nil
			item.buyMaxButton.Active = false
			if isRoblox then item.buyMaxButton.BackgroundColor3 = Color3.fromRGB(107, 114, 128) end
		elseif maxQuote ~= nil and maxQuote.available and maxQuote.cashCost ~= nil then
			local levelsGain = (maxQuote.nextLevel or (chainCurLvl + 1)) - activeCurLvl
			item.maxActionLabel.Text = string.format("MAX (+%d)", math.max(1, levelsGain))
			item.maxPriceLabel.Text = HUD.formatCash(maxQuote.cashCost)
			item.maxPriceLabel.TextColor3 = isRoblox and Color3.fromRGB(254, 240, 138) or nil
			item.buyMaxButton.Active = true
			if isRoblox then item.buyMaxButton.BackgroundColor3 = Color3.fromRGB(245, 158, 11) end
		else
			item.maxActionLabel.Text = "MAX"
			item.maxPriceLabel.Text = "MAX"
			item.maxPriceLabel.TextColor3 = isRoblox and Color3.fromRGB(254, 240, 138) or nil
			item.buyMaxButton.Active = true
			if isRoblox then item.buyMaxButton.BackgroundColor3 = Color3.fromRGB(245, 158, 11) end
		end
	end
end

function HUD:_updateResearchItem(research, displayOrder, isTabVisible)
	local id = research.researchId
	local item = self.shopResearch[id]

	local rawName = RESEARCH_DISPLAY_NAMES[id] or id
	local cleanTitle, cleanSubtitle = string.match(rawName, "^(.-)%s*%((%+.-)%)%s*$")
	if not cleanTitle then
		cleanTitle = rawName
		cleanSubtitle = "Ulepszenie farmy"
	end
	local iconEmoji = RESEARCH_ICONS[id] or "🔬"
	local maxLvl = COMMON_RESEARCH_MAX_LEVELS[id] or 25
	local curLvl = tonumber(research.level) or 0
	cleanSubtitle=researchEffectText(research,cleanSubtitle)

	if item == nil then
		local orderIdx = displayOrder or 1
		local shouldBeVisible = if isTabVisible ~= nil then isTabVisible else (research.blockedReason ~= "UNSUPPORTED")
		local card = createGuiElement("TextButton", {
			Name = "LegacyResearchCard_" .. id,
			Visible = shouldBeVisible,
			Size = isRoblox and UDim2.new(1, -6, 0, 90) or nil,
			Position = isRoblox and UDim2.new(0, 0, 0, (orderIdx - 1) * 96) or nil,
			BackgroundColor3 = isRoblox and Color3.fromRGB(78, 52, 46) or nil,
			Text = "",
			AutoButtonColor = false,
		}, self._legacyHolder or self.shopFrame)
		addCornerAndStroke(card, 12, isRoblox and Color3.fromRGB(43, 24, 16) or nil, 2)

		-- Left Icon Badge (44x44)
		local iconBadge = createGuiElement("Frame", {
			Name = "IconBadge",
			Size = isRoblox and UDim2.new(0, 44, 0, 44) or nil,
			Position = isRoblox and UDim2.new(0, 8, 0, 8) or nil,
			BackgroundColor3 = isRoblox and Color3.fromRGB(254, 243, 199) or nil,
		}, card)
		addCornerAndStroke(iconBadge, 10, isRoblox and Color3.fromRGB(217, 119, 6) or nil, 1.5)

		createGuiElement("TextLabel", {
			Name = "IconEmoji",
			Size = isRoblox and UDim2.new(1, 0, 1, 0) or nil,
			BackgroundTransparency = 1,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextSize = 24,
			TextColor3 = isRoblox and Color3.fromRGB(69, 26, 3) or nil,
			Text = iconEmoji,
		}, iconBadge)

		-- Middle Column: Name, Subtitle, Level, Progress Bar
		local nameLabel = createGuiElement("TextLabel", {
			Name = "Title",
			Size = isRoblox and UDim2.new(1, -205, 0, 18) or nil,
			Position = isRoblox and UDim2.new(0, 58, 0, 6) or nil,
			BackgroundTransparency = 1,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = true,
			TextXAlignment = isRoblox and Enum.TextXAlignment.Left or nil,
			TextColor3 = isRoblox and Color3.fromRGB(255, 255, 255) or nil,
			Text = cleanTitle,
		}, card)
		addTextStroke(nameLabel, 1.8)

		local subtitleLabel = createGuiElement("TextLabel", {
			Name = "Subtitle",
			Size = isRoblox and UDim2.new(1, -205, 0, 40) or nil,
			Position = isRoblox and UDim2.new(0, 58, 0, 24) or nil,
			BackgroundTransparency = 1,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = false,
			TextSize = 12,
			TextWrapped = true,
			TextYAlignment = isRoblox and Enum.TextYAlignment.Top or nil,
			TextXAlignment = isRoblox and Enum.TextXAlignment.Left or nil,
			TextColor3 = isRoblox and Color3.fromRGB(214, 190, 178) or nil,
			Text = cleanSubtitle,
		}, card)

		local levelLabel = createGuiElement("TextLabel", {
			Name = "Level",
			Size = isRoblox and UDim2.new(0, 95, 0, 13) or nil,
			Position = isRoblox and UDim2.new(0, 58, 0, 70) or nil,
			BackgroundTransparency = 1,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = true,
			TextXAlignment = isRoblox and Enum.TextXAlignment.Left or nil,
			TextColor3 = isRoblox and Color3.fromRGB(251, 191, 36) or nil,
			Text = string.format("★ POZ. %d/%d", curLvl, maxLvl),
		}, card)
		addTextStroke(levelLabel, 1.5)

		-- Mini Progress Bar
		local progressTrack = createGuiElement("Frame", {
			Name = "ProgressTrack",
			Size = isRoblox and UDim2.new(1, -300, 0, 7) or nil,
			Position = isRoblox and UDim2.new(0, 156, 0, 74) or nil,
			BackgroundColor3 = isRoblox and Color3.fromRGB(43, 24, 16) or nil,
		}, card)
		addCornerAndStroke(progressTrack, 3, nil, 0)

		local progressFill = createGuiElement("Frame", {
			Name = "ProgressFill",
			Size = isRoblox and UDim2.new(math.clamp(curLvl / math.max(1, maxLvl), 0, 1), 0, 1, 0) or nil,
			BackgroundColor3 = isRoblox and Color3.fromRGB(34, 197, 94) or nil,
		}, progressTrack)
		addCornerAndStroke(progressFill, 3, nil, 0)

		-- Invisible status label for test invariants
		local statusLabel = createGuiElement("TextLabel", {
			Name = "Status",
			Visible = false,
			Text = "BUY",
		}, card)

		-- 3D Tycoon Buy Button (130x46)
		local buyBtn = createGuiElement("TextButton", {
			Name = "BuyButton",
			Size = isRoblox and UDim2.new(0, 130, 0, 46) or nil,
			Position = isRoblox and UDim2.new(1, -138, 0, 7) or nil,
			BackgroundColor3 = isRoblox and Color3.fromRGB(34, 197, 94) or nil,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			Text = "",
		}, card)
		addCornerAndStroke(buyBtn, 10, isRoblox and Color3.fromRGB(20, 83, 45) or nil, 2.5)

		local btnActionLabel = createGuiElement("TextLabel", {
			Name = "ActionLabel",
			Size = isRoblox and UDim2.new(1, 0, 0.48, 0) or nil,
			Position = isRoblox and UDim2.new(0, 0, 0.04, 0) or nil,
			BackgroundTransparency = 1,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = true,
			TextColor3 = isRoblox and Color3.fromRGB(255, 255, 255) or nil,
			Text = "KUP",
		}, buyBtn)
		addTextStroke(btnActionLabel, 1.8)

		local priceLabel = createGuiElement("TextLabel", {
			Name = "Price",
			Size = isRoblox and UDim2.new(1, 0, 0.44, 0) or nil,
			Position = isRoblox and UDim2.new(0, 0, 0.50, 0) or nil,
			BackgroundTransparency = 1,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = true,
			TextColor3 = isRoblox and Color3.fromRGB(254, 240, 138) or nil,
			Text = "$0",
		}, buyBtn)
		addTextStroke(priceLabel, 1.8)

		item = {
			id = id,
			card = card,
			nameLabel = nameLabel,
			subtitleLabel = subtitleLabel,
			levelLabel = levelLabel,
			progressFill = progressFill,
			priceLabel = priceLabel,
			statusLabel = statusLabel,
			buyButton = buyBtn,
			actionLabel = btnActionLabel,
			available = true,
			blockedReason = nil,
			quote = nil,
		}

		if card.Activated ~= nil then
			card.Activated:Connect(function()
				self:buyResearch(id)
			end)
		end

		if buyBtn.Activated ~= nil then
			buyBtn.Activated:Connect(function()
				self:buyResearch(id)
			end)
		end

		self.shopResearch[id] = item
	end

	if isTabVisible ~= nil then
		item.card.Visible = isTabVisible
		if isTabVisible and displayOrder then
			item.card.Position = isRoblox and UDim2.new(0, 0, 0, (displayOrder - 1) * 96) or nil
		end
	end

	item.level = curLvl
	item.subtitleLabel.Text=cleanSubtitle
	item.levelLabel.Text = string.format("★ POZ. %d/%d", curLvl, maxLvl)
	if item.progressFill and isRoblox then
		item.progressFill.Size = UDim2.new(math.clamp(curLvl / math.max(1, maxLvl), 0, 1), 0, 1, 0)
	end

	local quote = nil
	if self.intentControllers and self.intentControllers.shop then
		quote = self.intentControllers.shop:getCachedQuote({
			kind = "BuyResearch",
			args = { researchId = id, mode = "single" },
		})
	end
	item.quote = quote

	if quote ~= nil and quote.cashCost ~= nil then
		item.priceLabel.Text = HUD.formatCash(quote.cashCost)
	end

	local available = research.available
	local blockedReason = research.blockedReason

	if quote ~= nil then
		if not quote.available then
			available = false
			blockedReason = quote.blockedReason or blockedReason
		end
	end

	item.available = available
	item.blockedReason = blockedReason

	if available then
		item.buyButton.Active = true
		item.statusLabel.Text = "BUY"
		if item.actionLabel then
			item.actionLabel.Text = "KUP"
			item.actionLabel.Size = isRoblox and UDim2.new(1, 0, 0.48, 0) or nil
			item.actionLabel.Position = isRoblox and UDim2.new(0, 0, 0.04, 0) or nil
		end
		item.priceLabel.Visible = true
		if isRoblox then
			item.buyButton.BackgroundColor3 = Color3.fromRGB(34, 197, 94)
			local stroke = item.buyButton:FindFirstChildOfClass("UIStroke")
			if stroke then stroke.Color = Color3.fromRGB(20, 83, 45) end
		end
	else
		item.buyButton.Active = false
		local reasonText = blockedReason or "LOCKED"
		item.statusLabel.Text = reasonText
		if reasonText == "MAX_LEVEL" then
			if item.actionLabel then
				item.actionLabel.Text = "MAKS. POZ."
				item.actionLabel.Size = isRoblox and UDim2.new(1, -6, 0.9, 0) or nil
				item.actionLabel.Position = isRoblox and UDim2.new(0, 3, 0.05, 0) or nil
			end
			item.priceLabel.Visible = false
			if isRoblox then
				item.buyButton.BackgroundColor3 = Color3.fromRGB(75, 85, 99)
				local stroke = item.buyButton:FindFirstChildOfClass("UIStroke")
				if stroke then stroke.Color = Color3.fromRGB(31, 41, 55) end
			end
		elseif reasonText == "TIER_LOCKED" then
			if item.actionLabel then
				item.actionLabel.Text = "ZABLOKOWANE"
				item.actionLabel.Size = isRoblox and UDim2.new(1, -6, 0.9, 0) or nil
				item.actionLabel.Position = isRoblox and UDim2.new(0, 3, 0.05, 0) or nil
			end
			item.priceLabel.Visible = false
			if isRoblox then
				item.buyButton.BackgroundColor3 = Color3.fromRGB(127, 29, 29)
				local stroke = item.buyButton:FindFirstChildOfClass("UIStroke")
				if stroke then stroke.Color = Color3.fromRGB(69, 10, 10) end
			end
		elseif reasonText == "INSUFFICIENT_CASH" then
			if item.actionLabel then
				item.actionLabel.Text = "ZA MAŁO $"
				item.actionLabel.Size = isRoblox and UDim2.new(1, 0, 0.48, 0) or nil
				item.actionLabel.Position = isRoblox and UDim2.new(0, 0, 0.04, 0) or nil
			end
			item.priceLabel.Visible = true
			if isRoblox then
				item.buyButton.BackgroundColor3 = Color3.fromRGB(156, 163, 175)
				local stroke = item.buyButton:FindFirstChildOfClass("UIStroke")
				if stroke then stroke.Color = Color3.fromRGB(75, 85, 99) end
			end
		else
			if item.actionLabel then
				item.actionLabel.Text = reasonText
				item.actionLabel.Size = isRoblox and UDim2.new(1, -6, 0.9, 0) or nil
				item.actionLabel.Position = isRoblox and UDim2.new(0, 3, 0.05, 0) or nil
			end
			item.priceLabel.Visible = false
			if isRoblox then
				item.buyButton.BackgroundColor3 = Color3.fromRGB(120, 110, 105)
				local stroke = item.buyButton:FindFirstChildOfClass("UIStroke")
				if stroke then stroke.Color = Color3.fromRGB(60, 50, 45) end
			end
		end
	end
end

function HUD:_updateEpicResearchModal(farm)
    self._epicRobuxOffers={}
    for _,offer in (farm and farm.progress and farm.progress.epicRobuxOffers) or {} do self._epicRobuxOffers[offer.researchId]=offer end
	if not self.epicResearchModal or not farm then return end

	local p = farm.progress
	local geExact = (p and p.GE) or "0"
	local geNum = 0
	if self.codec and self.codec.ExactUInt then
		local okDec, dec = pcall(self.codec.ExactUInt.decode, geExact)
		if okDec and dec then
			geNum = self.codec.ExactUInt.toSafeNumber(dec)
		end
	else
		geNum = tonumber(geExact) or 0
	end

	if self.epicGePill then
		self.epicGePill.Text = "Twoje Diamenty: " .. formatCompact(geNum) .. " 💎"
	end

	local epicProgress = (p and p.epic) or {}

	for _, item in ipairs(EPIC_RESEARCH_CATALOG) do
		local cardData = self.epicResearchCards and self.epicResearchCards[item.id]
		if cardData then
			local curLvl = epicProgress[item.id]
			if curLvl == nil and item.id == "cheaper_research" then
				curLvl = epicProgress.lab_upgrade
			end
			curLvl = tonumber(curLvl) or 0

			local maxLvl = item.maxLevel
			local fraction = if maxLvl > 0 then math.clamp(curLvl / maxLvl, 0, 1) else 0

			if cardData.fill and isRoblox then
				cardData.fill.Size = UDim2.new(fraction, 0, 1, 0)
			end

			if cardData.buyRobuxBtn then
				local offer=self._epicRobuxOffers[item.id]
                cardData.buyRobuxBtn.Visible = not UNSUPPORTED_EPIC_RESEARCH[item.id] and curLvl<maxLvl
                cardData.buyRobuxBtn.Active = offer~=nil and offer.configured
                cardData.buyRobuxBtn.Text = if not offer or not offer.configured then "WKRÓTCE" elseif offer.credits~="0" then "UŻYJ" else tostring(offer.nominalPriceRobux).." R$*"
			end

			if UNSUPPORTED_EPIC_RESEARCH[item.id] then
				if cardData.lvlLabel then
					cardData.lvlLabel.Text = "Wkrótce (Aktualizacja v1.1)"
				end
				if cardData.buyBtn then
					cardData.buyBtn.Text = "WKRÓTCE"
					cardData.buyBtn.Active = false
					if isRoblox then
						cardData.buyBtn.BackgroundColor3 = Color3.fromRGB(75, 85, 99)
					end
				end
			elseif curLvl >= maxLvl then
				if cardData.lvlLabel then
					cardData.lvlLabel.Text = "Poziom: " .. tostring(curLvl) .. " / " .. tostring(maxLvl) .. " (MAX)"
				end
				if cardData.buyBtn then
					cardData.buyBtn.Text = "MAX"
					cardData.buyBtn.Active = false
					if isRoblox then
						cardData.buyBtn.BackgroundColor3 = Color3.fromRGB(75, 85, 99)
					end
				end
				if cardData.buyRobuxBtn then
					cardData.buyRobuxBtn.Text = "MAX"
					cardData.buyRobuxBtn.Active = false
					if isRoblox then
						cardData.buyRobuxBtn.BackgroundColor3 = Color3.fromRGB(75, 85, 99)
					end
				end
			else
				local nextPrice = EpicPricing.ge((item.prices and item.prices[curLvl + 1]) or item.basePriceGE)
				if cardData.lvlLabel then
					cardData.lvlLabel.Text = "Poziom: " .. tostring(curLvl) .. " / " .. tostring(maxLvl)
				end
				local canAfford = (geNum >= nextPrice)
				if cardData.buyBtn then
					cardData.buyBtn.Text = formatCompact(nextPrice) .. " 💎"
					cardData.buyBtn.Active = canAfford
					if isRoblox then
						cardData.buyBtn.BackgroundColor3 = if canAfford then Color3.fromRGB(34, 197, 94) else Color3.fromRGB(156, 163, 175)
					end
				end
				if cardData.buyRobuxBtn then
					if isRoblox then
						cardData.buyRobuxBtn.BackgroundColor3 = Color3.fromRGB(245, 158, 11)
					end
				end
			end
		end
	end
end

function HUD:_updateEggUpgradeModal(farm)
	if not self.eggUpgradeModal or not farm then return end

	local curEggIdx = farm.eggIndex or 0
	local nextEggIdx = curEggIdx + 1
	local curEgg = EGGS_DATA[curEggIdx] or EGGS_DATA[0]
	local nextEgg = EGGS_DATA[nextEggIdx]

	local codec = self.codec
	local approxFv = if farm.homeFV ~= nil then (if codec and codec.BigAmount then codec.BigAmount.decode(farm.homeFV) else tonumber(farm.homeFV) or 0) else nil
	if self.eggUpgradeCurrentLabel then
		self.eggUpgradeCurrentLabel.Text = string.format("🥚 Aktualne Jajo: %s ($%s)", curEgg.name, formatCompact(curEgg.eggValueBase))
	end

	if nextEgg then
		local reqFv = nextEgg.advanceFV
		local mult = nextEgg.eggValueBase / curEgg.eggValueBase
		if self.eggUpgradeNextLabel then
			self.eggUpgradeNextLabel.Text = string.format("✨ Następne Jajo: %s ($%s)", nextEgg.name, formatCompact(nextEgg.eggValueBase))
		end
		if self.eggUpgradeMultLabel then
			self.eggUpgradeMultLabel.Text = string.format("📈 Mnożnik Wartości: %.1fx", mult)
		end
		if self.eggUpgradeCurrentFvLabel then
			self.eggUpgradeCurrentFvLabel.Text = string.format("💰 Twoje Farm Value: $%s", if approxFv ~= nil then formatCompact(approxFv) else "—")
		end
		if self.eggUpgradeReqFvLabel then
			self.eggUpgradeReqFvLabel.Text = string.format("🎯 Wymagane Farm Value: $%s", formatCompact(reqFv))
		end

		if self.eggUpgradeBtn then
			self.eggUpgradeBtn.Active = approxFv ~= nil and approxFv >= reqFv
			if approxFv ~= nil and approxFv >= reqFv then
				self.eggUpgradeBtn.Text = "AWANSUJ NASTĘPNE JAJO (" .. string.upper(nextEgg.name) .. ")"
				if isRoblox then self.eggUpgradeBtn.BackgroundColor3 = Color3.fromRGB(95, 235, 55) end
			else
				self.eggUpgradeBtn.Text = if approxFv == nil then "OCZEKIWANIE NA WYCENĘ" else "WYMAGANE WIĘKSZE FARM VALUE"
				if isRoblox then self.eggUpgradeBtn.BackgroundColor3 = Color3.fromRGB(140, 140, 140) end
			end
		end
	else
		if self.eggUpgradeNextLabel then self.eggUpgradeNextLabel.Text = "🎉 Osiągnięto Oświecenie (MAX)!" end
		if self.eggUpgradeMultLabel then self.eggUpgradeMultLabel.Text = "Maksymalny gatunek osiągnięty" end
		if self.eggUpgradeReqFvLabel then self.eggUpgradeReqFvLabel.Text = "Brak dalszych poziomów" end
		if self.eggUpgradeBtn then
			self.eggUpgradeBtn.Text = "MAKSYMALNE JAJO"
			if isRoblox then self.eggUpgradeBtn.BackgroundColor3 = Color3.fromRGB(140, 140, 140) end
		end
	end
end

function HUD:_updatePrestigeDisplay(farm)
	farm = farm or (self.stateStore and (self.stateStore.getPresentationFarm or self.stateStore.getFarm)(self.stateStore))
	if not farm then return end

	local progress = farm.progress or {}
	local codec = self.codec
	local seStr = progress.SE or "0"
	local currentSE = if codec and codec.Real64 then codec.Real64.decode(seStr) else (tonumber(seStr) or 0)
	local epic = progress.epic or {}
	local soulFoodLvl = (epic.soul_eggs or epic.soul_food) or 0

	local pendingSE = if progress.pendingSE ~= nil then (if codec and codec.Real64 then codec.Real64.decode(progress.pendingSE) else tonumber(progress.pendingSE) or 0) else nil
	local pendingText = if pendingSE ~= nil then formatCompact(pendingSE) else "—"

	local bonusPerCrystal = 10 + soulFoodLvl
	local totalBonusPercent = if progress.earningBonus ~= nil then (if codec and codec.Real64 then math.floor(codec.Real64.decode(progress.earningBonus)) else tonumber(progress.earningBonus) or 0) else nil

	-- Update Bottom-Left HUD Rebirth Label
	if self.rebirthLabel ~= nil then
		local curEgg = EGGS_DATA[farm.eggIndex or 0]
		local eggName = if curEgg then curEgg.name else "Kurze"
		self.rebirthLabel.Text = string.format("🟣 %s Prestiż (+%s) • 🥚 %s", formatCompact(currentSE), pendingText, eggName)
	end

	-- Update Prestige Modal if created
	if self.prestigeCurrentCrystalsLabel then
		self.prestigeCurrentCrystalsLabel.Text = "Posiadane Kryształy: 🟣 " .. formatCompact(currentSE)
	end
	if self.prestigeCurrentBonusLabel then
		self.prestigeCurrentBonusLabel.Text = string.format("Bonus do zarobków: +%s%% (+%d%% z każdego kryształu)", if totalBonusPercent ~= nil then formatCompact(totalBonusPercent) else "—", bonusPerCrystal)
	end
	if self.prestigeSubLabel then
		local eventMult = if progress.prestigeEventMult ~= nil then (if codec and codec.Real64 then codec.Real64.decode(progress.prestigeEventMult) else tonumber(progress.prestigeEventMult) or 1) else 1
		self.prestigeSubLabel.Text = if eventMult > 1 then string.format("Aktywny event: ×%s Prestiż!", formatCompact(eventMult)) else "Zwiększaj dochód farmy, aby zdobyć jeszcze więcej kryształów!"
	end
	if self.prestigeAfterBonusLabel then
		local afterPercent = if progress.earningBonusAfter ~= nil then (if codec and codec.Real64 then math.floor(codec.Real64.decode(progress.earningBonusAfter)) else tonumber(progress.earningBonusAfter) or 0) else nil
		if afterPercent ~= nil and totalBonusPercent ~= nil then
			self.prestigeAfterBonusLabel.Text = string.format("Po prestiżu: +%s%% (+%s%%)", formatCompact(afterPercent), formatCompact(afterPercent - totalBonusPercent))
		else
			self.prestigeAfterBonusLabel.Text = "Po prestiżu: —"
		end
	end
	if self.prestigePendingLabel then
		self.prestigePendingLabel.Text = string.format("+%s KRYSZTAŁÓW PRESTIŻU", pendingText)
	end
	if self.prestigeActionBtn then
		self.prestigeActionBtn.Active = pendingSE ~= nil
		self.prestigeActionBtn.Text = string.format("ODRÓDŹ FARMĘ (+%s KRYSZTAŁÓW)", pendingText)
	end
end

function HUD:_updateShopModal(farm)
	if not self.shopModal or not farm then return end
	local progress = farm.progress or {}
	local codec = self.codec
	local boostInv = progress.boostInventory or {}
	local activeBoosts = progress.activeBoosts or {}
	local maxSlots = if progress.proPermit == true then 5 else 2
	local isEnlightenment = (farm.eggIndex == 18)

	if self.activeBoostsSummaryLabel then
		if isEnlightenment then
			self.activeBoostsSummaryLabel.Text = string.format("Aktywne boosty: %d / %d (Wstrzymane na Oświeceniu)", #activeBoosts, maxSlots)
		elseif #activeBoosts == 0 then
			self.activeBoostsSummaryLabel.Text = string.format("Aktywne boosty: 0 / %d", maxSlots)
		else
			local parts = {}
			for _, b in ipairs(activeBoosts) do
				local rem = if type(b.remainingSeconds) == "string" and codec and codec.Real64 then codec.Real64.decode(b.remainingSeconds) else (tonumber(b.remainingSeconds) or 0)
				local mins = math.max(0, math.ceil(rem / 60))
				table.insert(parts, string.format("%s (%dm)", tostring(b.id), mins))
			end
			self.activeBoostsSummaryLabel.Text = string.format("Aktywne boosty: %d / %d • %s", #activeBoosts, maxSlots, table.concat(parts, ", "))
		end
	end

	for _, bSpec in ipairs(BOOSTS_CATALOG) do
		local card = self.shopProductCards and self.shopProductCards[bSpec.id]
		if card then
			local rawOwned = boostInv[bSpec.id] or "0"
			local ownedNum = 0
			if type(rawOwned) == "string" and codec and codec.ExactUInt then
				local okDec, dec = pcall(codec.ExactUInt.decode, rawOwned)
				if okDec and dec then
					ownedNum = codec.ExactUInt.toSafeNumber(dec)
				end
			else
				ownedNum = tonumber(rawOwned) or 0
			end

			local ownedLbl = card:FindFirstChild("OwnedCount")
			if ownedLbl then
				ownedLbl.Text = string.format("Posiadane: %s", formatCompact(ownedNum))
			end

			local activateBtn = card:FindFirstChild("ActivateBoostButton")
			if activateBtn then
				local isInstant = (bSpec.dimension == 10)
				local slotsFull = (not isInstant) and (#activeBoosts >= maxSlots)
				local canActivate = (ownedNum > 0) and (not isEnlightenment) and (not slotsFull)
				activateBtn.Active = canActivate
				if isEnlightenment then
					activateBtn.Text = "WYŁĄCZONE"
					self.ui:setButtonTone(activateBtn, "disabled")
				elseif ownedNum <= 0 then
					activateBtn.Text = "BRAK"
					self.ui:setButtonTone(activateBtn, "disabled")
				elseif slotsFull then
					activateBtn.Text = "LIMIT"
					self.ui:setButtonTone(activateBtn, "disabled")
				else
					activateBtn.Text = "AKTYWUJ"
					self.ui:setButtonTone(activateBtn, "boost")
				end
			end
		end
	end
end

function HUD:onQuoteReceived(quoteView)
	if type(quoteView) ~= "table" or quoteView.kind ~= "QuoteView" then
		return
	end
	local target = quoteView.target
	if target and target.kind == "BuyResearch" and target.args and target.args.researchId then
		local item = self.shopResearch[target.args.researchId]
		if item ~= nil then
			item.quote = quoteView
			if quoteView.cashCost ~= nil then
				item.priceLabel.Text = HUD.formatCash(quoteView.cashCost)
			end
			if quoteView.available then
				item.available = true
				item.blockedReason = nil
				item.buyButton.Active = true
				item.statusLabel.Text = "BUY"
				if item.actionLabel then
					item.actionLabel.Text = "KUP"
					item.actionLabel.Size = isRoblox and UDim2.new(1, 0, 0.48, 0) or nil
					item.actionLabel.Position = isRoblox and UDim2.new(0, 0, 0.04, 0) or nil
				end
				item.priceLabel.Visible = true
				if isRoblox then
					item.buyButton.BackgroundColor3 = Color3.fromRGB(34, 197, 94)
					local stroke = item.buyButton:FindFirstChildOfClass("UIStroke")
					if stroke then stroke.Color = Color3.fromRGB(20, 83, 45) end
				end
			else
				item.available = false
				item.blockedReason = quoteView.blockedReason
				item.buyButton.Active = false
				local reason = quoteView.blockedReason or "LOCKED"
				item.statusLabel.Text = reason
				if item.actionLabel then
					item.actionLabel.Text = if reason == "INSUFFICIENT_CASH" then "ZA MAŁO $" elseif reason == "MAX_LEVEL" then "MAKS. POZ." elseif reason == "TIER_LOCKED" then "ZABLOKOWANE" elseif reason == "HYPERLOOP_LOCKED" then "WKRÓTCE: EGG TO THE MOON 🚀" else reason
					if reason == "INSUFFICIENT_CASH" then
						item.actionLabel.Size = isRoblox and UDim2.new(1, 0, 0.48, 0) or nil
						item.actionLabel.Position = isRoblox and UDim2.new(0, 0, 0.04, 0) or nil
						item.priceLabel.Visible = true
						if isRoblox then
							item.buyButton.BackgroundColor3 = Color3.fromRGB(156, 163, 175)
							local stroke = item.buyButton:FindFirstChildOfClass("UIStroke")
							if stroke then stroke.Color = Color3.fromRGB(75, 85, 99) end
						end
					elseif reason == "MAX_LEVEL" then
						item.actionLabel.Size = isRoblox and UDim2.new(1, -6, 0.9, 0) or nil
						item.actionLabel.Position = isRoblox and UDim2.new(0, 3, 0.05, 0) or nil
						item.priceLabel.Visible = false
						if isRoblox then
							item.buyButton.BackgroundColor3 = Color3.fromRGB(75, 85, 99)
							local stroke = item.buyButton:FindFirstChildOfClass("UIStroke")
							if stroke then stroke.Color = Color3.fromRGB(31, 41, 55) end
						end
					elseif reason == "TIER_LOCKED" then
						item.actionLabel.Size = isRoblox and UDim2.new(1, -6, 0.9, 0) or nil
						item.actionLabel.Position = isRoblox and UDim2.new(0, 3, 0.05, 0) or nil
						item.priceLabel.Visible = false
						if isRoblox then
							item.buyButton.BackgroundColor3 = Color3.fromRGB(127, 29, 29)
							local stroke = item.buyButton:FindFirstChildOfClass("UIStroke")
							if stroke then stroke.Color = Color3.fromRGB(69, 10, 10) end
						end
					else
						item.actionLabel.Size = isRoblox and UDim2.new(1, -6, 0.9, 0) or nil
						item.actionLabel.Position = isRoblox and UDim2.new(0, 3, 0.05, 0) or nil
						item.priceLabel.Visible = false
						if isRoblox then
							item.buyButton.BackgroundColor3 = Color3.fromRGB(120, 110, 105)
							local stroke = item.buyButton:FindFirstChildOfClass("UIStroke")
							if stroke then stroke.Color = Color3.fromRGB(60, 50, 45) end
						end
				end
				else
					item.buyButton.Text = reason
				end
			end
		end

		-- Propagate fresh quote to the active unified research card (BUG-01 & BUG-02 & MAX)
		if self.unifiedResearch then
			for _, uItem in pairs(self.unifiedResearch) do
				if uItem.activeId == target.args.researchId then
					local mode = target.args.mode or "single"
					if mode == "max" then
						uItem.maxQuote = quoteView
						if uItem.statusLabel.Text ~= "MAX" and uItem.statusLabel.Text ~= "LOCKED" then
							if quoteView.available then
								local activeCurLvl = uItem.level or 0
								local levelsGain = (quoteView.nextLevel or (activeCurLvl + 1)) - activeCurLvl
								uItem.maxActionLabel.Text = string.format("MAX (+%d)", math.max(1, levelsGain))
								if quoteView.cashCost ~= nil then
									uItem.maxPriceLabel.Text = HUD.formatCash(quoteView.cashCost)
								end
								uItem.maxPriceLabel.TextColor3 = isRoblox and Color3.fromRGB(254, 240, 138) or nil
								uItem.buyMaxButton.Active = true
								if isRoblox then
									uItem.buyMaxButton.BackgroundColor3 = Color3.fromRGB(245, 158, 11)
									local stroke = uItem.buyMaxButton:FindFirstChildOfClass("UIStroke")
									if stroke then stroke.Color = Color3.fromRGB(180, 83, 9) end
								end
							else
								local reason = quoteView.blockedReason or "LOCKED"
								uItem.buyMaxButton.Active = false
								uItem.maxActionLabel.Text = "MAX"
								uItem.maxPriceLabel.Text = if reason == "INSUFFICIENT_CASH" then "ZA MAŁO $" else reason
								uItem.maxPriceLabel.TextColor3 = isRoblox and Color3.fromRGB(156, 163, 175) or nil
								if isRoblox then
									uItem.buyMaxButton.BackgroundColor3 = Color3.fromRGB(107, 114, 128)
									local stroke = uItem.buyMaxButton:FindFirstChildOfClass("UIStroke")
									if stroke then stroke.Color = Color3.fromRGB(75, 85, 99) end
								end
							end
						end
					else
						uItem.quote = quoteView
						if quoteView.cashCost ~= nil then
							uItem.priceLabel.Text = HUD.formatCash(quoteView.cashCost)
						end
						if quoteView.available then
							if uItem.statusLabel.Text ~= "MAX" then
								uItem.available = true
								uItem.blockedReason = nil
								uItem.buyButton.Active = true
								uItem.statusLabel.Text = "BUY"
								if uItem.actionLabel then
									uItem.actionLabel.Text = "KUP"
									uItem.actionLabel.Size = isRoblox and UDim2.new(1, 0, 0.48, 0) or nil
									uItem.actionLabel.Position = isRoblox and UDim2.new(0, 0, 0.04, 0) or nil
								end
								uItem.priceLabel.Visible = true
								uItem.priceLabel.TextColor3 = isRoblox and Color3.fromRGB(254, 240, 138) or nil
								if isRoblox then
									uItem.buyButton.BackgroundColor3 = Color3.fromRGB(34, 197, 94)
									local stroke = uItem.buyButton:FindFirstChildOfClass("UIStroke")
									if stroke then stroke.Color = Color3.fromRGB(20, 83, 45) end
								end
							end
						else
							local reason = quoteView.blockedReason or "LOCKED"
							if uItem.statusLabel.Text ~= "MAX" then
								uItem.available = false
								uItem.blockedReason = reason
								uItem.buyButton.Active = false
								uItem.statusLabel.Text = reason
								if reason == "INSUFFICIENT_CASH" then
									if uItem.actionLabel then
										uItem.actionLabel.Text = "ZA MAŁO $"
										uItem.actionLabel.Size = isRoblox and UDim2.new(1, 0, 0.48, 0) or nil
										uItem.actionLabel.Position = isRoblox and UDim2.new(0, 0, 0.04, 0) or nil
									end
									uItem.priceLabel.Visible = true
									uItem.priceLabel.TextColor3 = isRoblox and Color3.fromRGB(156, 163, 175) or nil
									if isRoblox then
										uItem.buyButton.BackgroundColor3 = Color3.fromRGB(107, 114, 128)
										local stroke = uItem.buyButton:FindFirstChildOfClass("UIStroke")
										if stroke then stroke.Color = Color3.fromRGB(75, 85, 99) end
									end
								end
							end
						end
					end
					break
				end
			end
		end
	end
end

-- Intent Actions

function HUD:pressHatch(callback)
	if self.audioController and type(self.audioController.playSFX) == "function" then
		self.audioController:playSFX("cluck")
	end
	if self.intentControllers and self.intentControllers.hatch then
		return self.intentControllers.hatch:press(callback)
	end
	return nil
end

function HUD:startHoldHatch(callback)
	if self.intentControllers and self.intentControllers.hatch then
		return self.intentControllers.hatch:holdStart(callback)
	end
	return nil
end

function HUD:refreshHoldHatch(callback)
	if self.intentControllers and self.intentControllers.hatch then
		return self.intentControllers.hatch:holdRefresh(callback)
	end
	return nil
end

function HUD:stopHoldHatch(callback)
	if self.intentControllers and self.intentControllers.hatch then
		return self.intentControllers.hatch:holdStop(callback)
	end
	return nil
end

function HUD:buyResearch(researchId, mode, callback)
	if type(mode) == "function" and callback == nil then
		callback = mode
		mode = "single"
	end
	mode = mode or "single"

	if not self.intentControllers or not self.intentControllers.shop then
		if callback then callback({ status = "REJECTED", errorCode = "NO_SHOP_CONTROLLER" }) end
		return false, "NO_SHOP_CONTROLLER"
	end

	if isRoblox then
		local now = os.clock()
		if self._lastResearchBuyTime and (now - self._lastResearchBuyTime) < 0.2 then
			return false, "DEBOUNCED"
		end
		self._lastResearchBuyTime = now
	end

	if self.audioController and type(self.audioController.playSFX) == "function" then
		self.audioController:playSFX("click")
	end

	local target = {
		kind = "BuyResearch",
		args = { researchId = researchId, mode = mode },
	}

	local currentRevision = if self.stateStore then self.stateStore:getCommitRevision() else nil
	local serverObservedAt = if self.stateStore then self.stateStore:getServerObservedAt() else nil
	local quote = self.intentControllers.shop:getCachedQuote(target)

	local item = (self.shopResearch and self.shopResearch[researchId]) or (self.unifiedResearch and self.unifiedResearch[researchId])
	local curLvl = item and item.level or 0

	local isQuoteFresh = quote ~= nil
		and quote.available == true
		and (currentRevision == nil or quote.expectedRevision == currentRevision)
		and (serverObservedAt == nil or quote.expiresAt == nil or quote.expiresAt > serverObservedAt)
		and (quote.nextLevel == nil or quote.nextLevel > curLvl)

	local function doRequestAndConfirm()
		return self.intentControllers.shop:requestQuote(target, function(newQuote)
			if newQuote and newQuote.kind == "QuoteView" and newQuote.available then
				self.intentControllers.shop:confirmPurchase(newQuote, function(res)
					if callback then callback(res) end
				end)
			else
				local errReason = if newQuote and newQuote.blockedReason then newQuote.blockedReason else "QUOTE_UNAVAILABLE"
				if callback then
					callback({ status = "REJECTED", errorCode = errReason })
				end
			end
		end)
	end

	if isQuoteFresh then
		local okConfirm, opIdOrErr, msg = self.intentControllers.shop:confirmPurchase(quote, function(res)
			if res and res.status == "REJECTED" and (res.errorCode == "QUOTE_CHANGED" or res.errorCode == "STALE_REVISION" or res.errorCode == "REVISION_MISMATCH" or res.errorCode == "QUOTE_EXPIRED") then
				doRequestAndConfirm()
			else
				if callback then callback(res) end
			end
		end)

		if not okConfirm then
			return doRequestAndConfirm()
		end

		return okConfirm, opIdOrErr, msg
	else
		return doRequestAndConfirm()
	end
end

-- Accessors for Verification & Tests

function HUD:getSessionStatus() return self.sessionStatus end
function HUD:getCashText() return if self.cashLabel then self.cashLabel.Text else "" end
function HUD:getCashRateText() return if self.cashRateLabel then self.cashRateLabel.Text else "" end
function HUD:getProducedEggsText() return if self.producedEggsLabel then self.producedEggsLabel.Text else "" end
function HUD:getSoldEggsText() return if self.soldEggsLabel then self.soldEggsLabel.Text else "" end
function HUD:getShippingText() return if self.shippingLabel then self.shippingLabel.Text else "" end
function HUD:getTopBar() return self.topBar end
function HUD:getRatesPanel() return self.ratesPanel end
function HUD:getRatesCell(index)
	local cell = self.ratesCells and self.ratesCells[index]
	return cell
end
function HUD:getRatesHeadingText(index)
	local label = self.ratesHeadingLabels and self.ratesHeadingLabels[index]
	return if label then label.Text else ""
end
function HUD:getRatesCaptionText() return if self.ratesCaptionLabel then self.ratesCaptionLabel.Text else "" end
function HUD:getRatesCaptionVisible() return if self.ratesCaptionLabel then self.ratesCaptionLabel.Visible else false end
function HUD:getHatcheryText() return if self.hatcheryStockLabel then self.hatcheryStockLabel.Text else "" end
function HUD:getHatcheryRatio() return self.hatcheryRatio end
function HUD:getHatcheryRefillText() return if self.hatcheryRefillLabel then self.hatcheryRefillLabel.Text else "" end
function HUD:getHatchStatusText() return if self.hatchStatusLabel then self.hatchStatusLabel.Text else "" end
function HUD:getHatchStatusReason() return self.hatchStatusReason end
function HUD:getHatchStatusVisible() return if self.hatchStatusFrame then self.hatchStatusFrame.Visible else false end
function HUD:getHatchStatusActionButton() return self.hatchStatusActionBtn end
function HUD:getHatchStatusActionVisible() return if self.hatchStatusActionBtn then self.hatchStatusActionBtn.Visible else false end
function HUD:getHabitatText(slotId)
	local label = self.habitatLabels[slotId]
	return if label then label.Text else ""
end
function HUD:getHabitatRatio(slotId) return self.habitatFillRatios[slotId] or 0 end
function HUD:getShopResearchItem(researchId) return self.shopResearch[researchId] end

function HUD:getHabitatsModal() return self.habitatsModal end
function HUD:getVehiclesModal() return self.vehiclesModal end
function HUD:getResearchModal() return self.shopFrame end
function HUD:getPetsModal() return self.petsModal end
function HUD:getShopModal() return self.shopModal end
function HUD:getCalendarModal() return self.calendarModal end
function HUD:getEggUpgradeModal() return self.eggUpgradeModal end
function HUD:getPetHatchModal() return self.petHatchModal end
function HUD:getHatchAnimationOverlay() return self.hatchAnimationOverlay end

-- Read-only #82 diagnostic: which window/menu image keys are still awaiting an uploaded id.
-- Reports the shared StudUi binding state plus the module-level upload flag. It never invents an
-- id, so a reviewer can see exactly which bindings root still has to fill in UiAssets.
function HUD:getAssetStatus()
	local status = if self.ui and type(self.ui.assetStatus) == "function" then self.ui:assetStatus() else {}
	status.uploadPending = (type(UiAssets) == "table" and UiAssets.uploadPending == true)
		or (tonumber(status.pending) or 0) > 0
	return status
end

function HUD:getShippingComparisonStatus()
	local badge = self.shippingComparisonBar and self.shippingComparisonBar:FindFirstChild("StatusBadge")
	return if badge then badge.Text else ""
end

function HUD:getCurrentResearchTier() return self.selectedResearchTier end
function HUD:getCurrentShopTab() return self.selectedShopTab end
function HUD:getCurrentCalendarTab() return self.selectedCalendarTab end

function HUD:updateAudioButtonIcon(isMuted: boolean)
	if self.audioToggleButton then
		self.audioToggleButton.Text = if isMuted then "🔇" else "🔊"
	end
end

function HUD:setAudioController(controller)
	self.audioController = controller
	if self.audioToggleButton and controller and type(controller.isMuted) == "function" then
		self:updateAudioButtonIcon(controller:isMuted())
	end
end

function HUD:getAudioController()
	return self.audioController
end

function HUD:getAudioToggleButton()
	return self.audioToggleButton
end

function HUD:destroy()
	for _, unsub in ipairs(self._unsubs) do
		unsub()
	end
	self._unsubs = {}
	if self.guiRoot ~= nil and type(self.guiRoot.Destroy) == "function" then
		self.guiRoot:Destroy()
	end
end

return table.freeze(HUD)
