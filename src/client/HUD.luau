--!nocheck
-- HUD for HatchTheEgg (IMP-14 & VIS-04).
-- Candy & Classic Studs styled responsive 2D HUD for PC and Mobile, inspired by
-- the user's reference screenshots (Dom button at top, Koszyk Jajek at bottom center,
-- huge green $ counter at bottom-left, studded quick-upgrade buttons on the left,
-- framed icon dock on the right, and total chicken counter at bottom-right).
--
-- CRITICAL ARCHITECTURAL INVARIANT:
-- HUD and controllers NEVER modify authoritative state, grant resources, or alter economy balances.
-- All numeric formatting (K, M, B, T) is presentation-only and NEVER parsed back into domain numbers.

local HUD = {}
HUD.__index = HUD

-- ============================================================================
-- Presentation-Only Numeric Formatting
-- ============================================================================

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

local RESEARCH_DISPLAY_NAMES = table.freeze({
	comfy_nests = "Wygodne Gniazda (+Tempo znoszenia)",
	nutritional_sup = "Cukrowe Suplementy (+Wartość jaj)",
	better_incubators = "Słodkie Inkubatory (+Wylęgarnia)",
	hab_capacity1 = "Rozbudowa Kurników (+Pojemność)",
	internal_hatchery1 = "Wewnętrzny Wylęg (+Kurczaki/min)",
	hatchery_expansion = "Pojemniejsza Wylęgarnia (+Zapas jaj)",
	leafsprings = "Resory Pojazdów (+Pojemność floty)",
})

-- ============================================================================
-- GUI Instance Helpers (Studio & Lune Mock)
-- ============================================================================

local isRoblox = (typeof(Instance) == "table" and type(Instance.new) == "function")

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

-- ============================================================================
-- HUD Constructor & Initialization
-- ============================================================================

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
		onHomeClicked = deps.onHomeClicked,
		onQuickBuyHabitat = deps.onQuickBuyHabitat,
		onQuickBuyVehicle = deps.onQuickBuyVehicle,

		-- Cached view data
		sessionStatus = "CONNECTING",
		hatcheryRatio = 0,
		habitatFillRatios = { 0, 0, 0, 0 },
		habitatPopulations = { "0", "0", "0", "0" },
		habitatCapacities = { "0", "0", "0", "0" },
		totalChickensCount = 0,

		-- UI Component hierarchy
		sessionBanner = nil,
		sessionStatusLabel = nil,
		homeButton = nil,
		cashLabel = nil,
		producedEggsLabel = nil,
		soldEggsLabel = nil,
		shippingLabel = nil,
		rebirthLabel = nil,
		totalChickensLabel = nil,
		tutorialLabel = nil,
		hatcheryStockLabel = nil,
		hatcheryRefillLabel = nil,
		hatcheryFillBar = nil,
		hatchButton = nil,
		habitatsModal = nil,
		habitatCards = {},
		habitatLabels = {},
		shopFrame = nil,
		shopListContainer = nil,
		shopResearch = {},
		shopHabitats = {},
		shopVehicles = {},

		_unsubs = {},
	}, HUD)

	self:_buildInterface()
	self:_setupSubscriptions()
	self:update()

	return self
end

function HUD:_buildInterface()
	local root = self.guiRoot

	-- 1. Session Status Banner (Top notification pill; auto-hides when READY in Studio)
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

	-- 2. Top-Center "Dom" Button & Boost/Rate Status Cluster (Screenshot 2 exact style!)
	local topBar = createGuiElement("Frame", {
		Name = "TopBar",
		Size = isRoblox and UDim2.new(0, 480, 0, 96) or nil,
		Position = isRoblox and UDim2.new(0.5, -240, 0, 6) or nil,
		BackgroundTransparency = 1,
	}, root)

	self.homeButton = createGuiElement("TextButton", {
		Name = "DomButton",
		Size = isRoblox and UDim2.new(0, 165, 0, 44) or nil,
		Position = isRoblox and UDim2.new(0.5, -82, 0, 0) or nil,
		BackgroundColor3 = isRoblox and Color3.fromRGB(78, 195, 255) or nil,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(255, 255, 255) or nil,
		Text = "Dom",
	}, topBar)
	addCornerAndStroke(self.homeButton, 8, isRoblox and Color3.fromRGB(18, 42, 68) or nil, 3)
	addTextStroke(self.homeButton, 2.6)

	if self.homeButton.Activated ~= nil then
		self.homeButton.Activated:Connect(function()
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

	-- Colorful Outlined Rate Counters under "Dom" button (Screenshot 2 style!)
	self.producedEggsLabel = createGuiElement("TextLabel", {
		Name = "ProducedEggsLabel",
		Size = isRoblox and UDim2.new(0.33, -4, 0, 26) or nil,
		Position = isRoblox and UDim2.new(0, 0, 0, 48) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(255, 165, 245) or nil,
		Text = "0/s",
	}, topBar)
	addTextStroke(self.producedEggsLabel, 2.2)

	self.soldEggsLabel = createGuiElement("TextLabel", {
		Name = "SoldEggsLabel",
		Size = isRoblox and UDim2.new(0.34, -4, 0, 26) or nil,
		Position = isRoblox and UDim2.new(0.33, 0, 0, 48) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(255, 235, 75) or nil,
		Text = "0/s",
	}, topBar)
	addTextStroke(self.soldEggsLabel, 2.2)

	self.shippingLabel = createGuiElement("TextLabel", {
		Name = "ShippingLabel",
		Size = isRoblox and UDim2.new(0.33, -4, 0, 26) or nil,
		Position = isRoblox and UDim2.new(0.67, 0, 0, 48) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(115, 255, 135) or nil,
		Text = "0/min",
	}, topBar)
	addTextStroke(self.shippingLabel, 2.2)

	self.tutorialLabel = createGuiElement("TextLabel", {
		Name = "TutorialBannerLabel",
		Size = isRoblox and UDim2.new(1, 0, 0, 22) or nil,
		Position = isRoblox and UDim2.new(0, 0, 0, 74) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(255, 250, 210) or nil,
		Text = "🎯 Cel: Kliknij koszyk 'Jajka' na dole lub stań na czerwonym przycisku!",
	}, topBar)
	addTextStroke(self.tutorialLabel, 2.0)

	-- 3. Bottom-Left Cash & Rebirth Display (Screenshot 2 exact style!)
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
		Text = "Odrodzenie 0 • 🍫 Cukierkowa Farma",
	}, bottomLeft)
	addTextStroke(self.rebirthLabel, 2.4)

	-- Note: tests/ui/run.luau creates cashLabel under TopBar or accesses self.cashLabel directly.
	-- We parent cashLabel to bottomLeft (and keep self.cashLabel reference intact).
	self.cashLabel = createGuiElement("TextLabel", {
		Name = "CashLabel",
		Size = isRoblox and UDim2.new(1, 0, 0, 58) or nil,
		Position = isRoblox and UDim2.new(0, 0, 0, 28) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextXAlignment = isRoblox and Enum.TextXAlignment.Left or nil,
		TextColor3 = isRoblox and Color3.fromRGB(115, 255, 45) or nil,
		Text = "$0",
	}, bottomLeft)
	addTextStroke(self.cashLabel, 3.4)

	-- 4. Left-Side Green Studded Quick-Action Buttons (Screenshot 2 left side!)
	local leftQuickCluster = createGuiElement("Frame", {
		Name = "LeftQuickButtons",
		Size = isRoblox and UDim2.new(0, 155, 0, 175) or nil,
		Position = isRoblox and UDim2.new(0, 16, 0.5, -60) or nil,
		BackgroundTransparency = 1,
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
				elseif self.habitatsModal then
					self.habitatsModal.Visible = not self.habitatsModal.Visible
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
			qBtn.Activated:Connect(qSpec.action)
		end
	end

	-- 5. Bottom-Center Egg Basket ("Jajka" / Hatchery Control Frame from Screenshot 2!)
	local hatcheryFrame = createGuiElement("Frame", {
		Name = "HatcheryFrame",
		Size = isRoblox and UDim2.new(0, 210, 0, 118) or nil,
		Position = isRoblox and UDim2.new(0.5, -105, 1, -128) or nil,
		BackgroundColor3 = isRoblox and Color3.fromRGB(235, 152, 48) or nil,
	}, root)
	addCornerAndStroke(hatcheryFrame, 18, isRoblox and Color3.fromRGB(58, 30, 12) or nil, 3.5)

	self.hatchButton = createGuiElement("TextButton", {
		Name = "HatchButton",
		Size = isRoblox and UDim2.new(1, -12, 0, 56) or nil,
		Position = isRoblox and UDim2.new(0, 6, 0, 6) or nil,
		BackgroundColor3 = isRoblox and Color3.fromRGB(255, 232, 135) or nil,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(255, 255, 255) or nil,
		Text = "🥚 Jajka (WYLĘG)",
	}, hatcheryFrame)
	addCornerAndStroke(self.hatchButton, 14, isRoblox and Color3.fromRGB(72, 38, 14) or nil, 2.8)
	addTextStroke(self.hatchButton, 2.8)

	if self.hatchButton.Activated ~= nil then
		self.hatchButton.Activated:Connect(function()
			self:pressHatch()
		end)
	end
	if self.hatchButton.MouseButton1Down ~= nil then
		self.hatchButton.MouseButton1Down:Connect(function()
			self:startHoldHatch()
		end)
	end
	if self.hatchButton.MouseButton1Up ~= nil then
		self.hatchButton.MouseButton1Up:Connect(function()
			self:stopHoldHatch()
		end)
	end

	self.hatcheryStockLabel = createGuiElement("TextLabel", {
		Name = "StockLabel",
		Size = isRoblox and UDim2.new(0.62, 0, 0, 36) or nil,
		Position = isRoblox and UDim2.new(0.04, 0, 0, 68) or nil,
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
		Position = isRoblox and UDim2.new(0.68, 0, 0, 68) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(135, 255, 115) or nil,
		Text = "+0/s",
	}, hatcheryFrame)
	addTextStroke(self.hatcheryRefillLabel, 2.2)

	-- 6. Right-Side Framed Icon Buttons ("Indeks / Badania", "Kurniki") & Bottom-Right Chicken Counter
	local rightDock = createGuiElement("Frame", {
		Name = "RightDock",
		Size = isRoblox and UDim2.new(0, 86, 0, 190) or nil,
		Position = isRoblox and UDim2.new(1, -100, 0.5, -80) or nil,
		BackgroundTransparency = 1,
	}, root)

	local researchToggleBtn = createGuiElement("TextButton", {
		Name = "ResearchMenuButton",
		Size = isRoblox and UDim2.new(0, 82, 0, 82) or nil,
		Position = isRoblox and UDim2.new(0, 0, 0, 0) or nil,
		BackgroundColor3 = isRoblox and Color3.fromRGB(32, 68, 128) or nil,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(255, 255, 255) or nil,
		Text = "📕\nBadania",
	}, rightDock)
	addCornerAndStroke(researchToggleBtn, 10, isRoblox and Color3.fromRGB(14, 28, 58) or nil, 3.2)
	addTextStroke(researchToggleBtn, 2.2)

	local habitatsToggleBtn = createGuiElement("TextButton", {
		Name = "HabitatsMenuButton",
		Size = isRoblox and UDim2.new(0, 82, 0, 82) or nil,
		Position = isRoblox and UDim2.new(0, 0, 0, 96) or nil,
		BackgroundColor3 = isRoblox and Color3.fromRGB(32, 68, 128) or nil,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(255, 255, 255) or nil,
		Text = "🏠\nKurniki",
	}, rightDock)
	addCornerAndStroke(habitatsToggleBtn, 10, isRoblox and Color3.fromRGB(14, 28, 58) or nil, 3.2)
	addTextStroke(habitatsToggleBtn, 2.2)

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

	-- 7. Habitats Modal Drawer (Coops 1..4)
	local habitatsFrame = createGuiElement("Frame", {
		Name = "HabitatsFrame",
		Visible = false,
		Size = isRoblox and UDim2.new(0, 360, 0, 310) or nil,
		Position = isRoblox and UDim2.new(0.5, -180, 0.5, -155) or nil,
		BackgroundColor3 = isRoblox and Color3.fromRGB(78, 42, 24) or nil,
	}, root)
	addCornerAndStroke(habitatsFrame, 14, isRoblox and Color3.fromRGB(255, 205, 95) or nil, 3.2)
	self.habitatsModal = habitatsFrame

	createGuiElement("TextLabel", {
		Name = "ModalHeader",
		Size = isRoblox and UDim2.new(1, -20, 0, 36) or nil,
		Position = isRoblox and UDim2.new(0, 10, 0, 8) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(255, 235, 115) or nil,
		Text = "🏠 TWOJE KURNIKI (1-4)",
	}, habitatsFrame)

	for slotId = 1, 4 do
		local card = createGuiElement("Frame", {
			Name = "HabitatCard_" .. tostring(slotId),
			Size = isRoblox and UDim2.new(1, -24, 0, 54) or nil,
			Position = isRoblox and UDim2.new(0, 12, 0, 50 + (slotId - 1) * 62) or nil,
			BackgroundColor3 = isRoblox and Color3.fromRGB(112, 64, 36) or nil,
		}, habitatsFrame)
		addCornerAndStroke(card, 8, isRoblox and Color3.fromRGB(42, 22, 12) or nil, 2)

		local popLabel = createGuiElement("TextLabel", {
			Name = "PopulationLabel",
			Size = isRoblox and UDim2.new(0.65, 0, 1, 0) or nil,
			Position = isRoblox and UDim2.new(0.04, 0, 0, 0) or nil,
			BackgroundTransparency = 1,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = true,
			TextColor3 = isRoblox and Color3.fromRGB(255, 255, 255) or nil,
			Text = "0 / 0",
		}, card)
		addTextStroke(popLabel, 2)

		local upgBtn = createGuiElement("TextButton", {
			Name = "UpgradeHabitatBtn",
			Size = isRoblox and UDim2.new(0.28, 0, 0.76, 0) or nil,
			Position = isRoblox and UDim2.new(0.69, 0, 0.12, 0) or nil,
			BackgroundColor3 = isRoblox and Color3.fromRGB(95, 235, 45) or nil,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = true,
			TextColor3 = isRoblox and Color3.fromRGB(255, 255, 255) or nil,
			Text = "ULEPSZ",
		}, card)
		addCornerAndStroke(upgBtn, 6, isRoblox and Color3.fromRGB(22, 48, 12) or nil, 2)
		if upgBtn.Activated then
			upgBtn.Activated:Connect(function()
				if type(self.onQuickBuyHabitat) == "function" then
					self.onQuickBuyHabitat(slotId)
				end
			end)
		end

		self.habitatCards[slotId] = card
		self.habitatLabels[slotId] = popLabel
	end

	-- 8. Shop Frame (Common Research Drawer)
	self.shopFrame = createGuiElement("Frame", {
		Name = "ShopFrame",
		Visible = false,
		Size = isRoblox and UDim2.new(0, 420, 0, 380) or nil,
		Position = isRoblox and UDim2.new(0.5, -210, 0.5, -190) or nil,
		BackgroundColor3 = isRoblox and Color3.fromRGB(68, 36, 22) or nil,
	}, root)
	addCornerAndStroke(self.shopFrame, 14, isRoblox and Color3.fromRGB(115, 225, 255) or nil, 3.2)

	createGuiElement("TextLabel", {
		Name = "ShopTitle",
		Size = isRoblox and UDim2.new(1, -20, 0, 36) or nil,
		Position = isRoblox and UDim2.new(0, 10, 0, 8) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(135, 235, 255) or nil,
		Text = "🔬 SŁODKIE BADANIA (ULEPSZENIA)",
	}, self.shopFrame)

	if researchToggleBtn.Activated then
		researchToggleBtn.Activated:Connect(function()
			self.shopFrame.Visible = not self.shopFrame.Visible
			if self.habitatsModal and self.shopFrame.Visible then
				self.habitatsModal.Visible = false
			end
		end)
	end

	if habitatsToggleBtn.Activated then
		habitatsToggleBtn.Activated:Connect(function()
			self.habitatsModal.Visible = not self.habitatsModal.Visible
			if self.shopFrame and self.habitatsModal.Visible then
				self.shopFrame.Visible = false
			end
		end)
	end
end

function HUD:toggleResearchModal(forceState)
	if not self.shopFrame then return end
	if forceState ~= nil then
		self.shopFrame.Visible = forceState
	else
		self.shopFrame.Visible = not self.shopFrame.Visible
	end
	if self.shopFrame.Visible and self.habitatsModal then
		self.habitatsModal.Visible = false
	end
end

function HUD:toggleHabitatsModal(forceState)
	if not self.habitatsModal then return end
	if forceState ~= nil then
		self.habitatsModal.Visible = forceState
	else
		self.habitatsModal.Visible = not self.habitatsModal.Visible
	end
	if self.habitatsModal.Visible and self.shopFrame then
		self.shopFrame.Visible = false
	end
end

function HUD:_setupSubscriptions()
	-- Subscribe to ClientStateStore status changes
	if self.stateStore ~= nil and type(self.stateStore.onStatusChanged) == "function" then
		table.insert(self._unsubs, self.stateStore:onStatusChanged(function(newStatus)
			self:updateStatus(newStatus)
		end))
	end

	-- Subscribe to ClientStateStore state changes (snapshots & deltas)
	if self.stateStore ~= nil and type(self.stateStore.onStateChanged) == "function" then
		table.insert(self._unsubs, self.stateStore:onStateChanged(function()
			self:update()
		end))
	end

	-- Subscribe to transport QuoteView messages to keep shop quotes fresh
	local transport = self.intentControllers and self.intentControllers.transport
	if transport ~= nil and type(transport.onQuote) == "function" then
		table.insert(self._unsubs, transport:onQuote(function(quoteView)
			self:onQuoteReceived(quoteView)
		end))
	end
end

-- ============================================================================
-- State & View Synchronization
-- ============================================================================

function HUD:updateStatus(newStatus)
	self.sessionStatus = newStatus or self.stateStore:getStatus()
	if self.sessionStatusLabel ~= nil then
		self.sessionStatusLabel.Text = self.sessionStatus
	end
	if isRoblox and self.sessionBanner ~= nil then
		self.sessionBanner.Visible = (self.sessionStatus ~= "READY")
	end
end

function HUD:update()
	self:updateStatus(self.stateStore:getStatus())

	local farm = self.stateStore:getFarm()
	if farm == nil then
		return
	end

	-- 1. Balances & Global Rates
	if self.cashLabel ~= nil then
		self.cashLabel.Text = HUD.formatCash(farm.cash)
	end
	if self.producedEggsLabel ~= nil then
		self.producedEggsLabel.Text = HUD.formatRate(farm.producedEggsPerSecond, "/s")
	end
	if self.soldEggsLabel ~= nil then
		self.soldEggsLabel.Text = HUD.formatRate(farm.soldEggsPerSecond, "/s")
	end
	if self.shippingLabel ~= nil then
		local fleetRate = (farm.fleet and farm.fleet.shippingPerMinute) or "0"
		self.shippingLabel.Text = HUD.formatRate(fleetRate, "/min")
	end

	-- 2. Hatchery Stock, Capacity & Refill
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

	-- 3. Habitats 1..4 (Population / Capacity) & Total Chickens Counter
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
			end
		end
	end
	self.totalChickensCount = totalPop
	if self.totalChickensLabel ~= nil then
		self.totalChickensLabel.Text = "Całkowita liczba kurczaków: " .. formatCompact(totalPop)
	end

	-- 4. Shop View (Common Research)
	local visibleIdx = 0
	if type(farm.common) == "table" then
		for _, research in ipairs(farm.common) do
			if research.blockedReason ~= "UNSUPPORTED" then
				visibleIdx += 1
			end
			self:_updateResearchItem(research, visibleIdx)
		end
	end
end

function HUD:_updateResearchItem(research, displayOrder)
	local id = research.researchId
	local item = self.shopResearch[id]

	if item == nil then
		local orderIdx = displayOrder or 1
		local isSupported = (research.blockedReason ~= "UNSUPPORTED")
		local card = createGuiElement("Frame", {
			Name = "ResearchCard_" .. id,
			Visible = isSupported,
			Size = isRoblox and UDim2.new(1, -24, 0, 42) or nil,
			Position = isRoblox and UDim2.new(0, 12, 0, 48 + (orderIdx - 1) * 46) or nil,
			BackgroundColor3 = isRoblox and Color3.fromRGB(102, 56, 32) or nil,
		}, self.shopFrame)
		addCornerAndStroke(card, 6, isRoblox and Color3.fromRGB(38, 18, 10) or nil, 1.8)

		local friendlyName = RESEARCH_DISPLAY_NAMES[id] or id
		local nameLabel = createGuiElement("TextLabel", {
			Name = "Title",
			Size = isRoblox and UDim2.new(0.46, 0, 1, 0) or nil,
			Position = isRoblox and UDim2.new(0.02, 0, 0, 0) or nil,
			BackgroundTransparency = 1,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = true,
			TextXAlignment = isRoblox and Enum.TextXAlignment.Left or nil,
			TextColor3 = isRoblox and Color3.fromRGB(255, 255, 255) or nil,
			Text = friendlyName,
		}, card)
		addTextStroke(nameLabel, 1.8)

		local levelLabel = createGuiElement("TextLabel", {
			Name = "Level",
			Size = isRoblox and UDim2.new(0.14, 0, 1, 0) or nil,
			Position = isRoblox and UDim2.new(0.49, 0, 0, 0) or nil,
			BackgroundTransparency = 1,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = true,
			TextColor3 = isRoblox and Color3.fromRGB(255, 235, 95) or nil,
			Text = "Lv 0",
		}, card)
		addTextStroke(levelLabel, 1.8)

		local priceLabel = createGuiElement("TextLabel", {
			Name = "Price",
			Size = isRoblox and UDim2.new(0.16, 0, 1, 0) or nil,
			Position = isRoblox and UDim2.new(0.64, 0, 0, 0) or nil,
			BackgroundTransparency = 1,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = true,
			TextColor3 = isRoblox and Color3.fromRGB(115, 255, 85) or nil,
			Text = "$0",
		}, card)
		addTextStroke(priceLabel, 1.8)

		local statusLabel = createGuiElement("TextLabel", {
			Name = "Status",
			Visible = false,
			Text = "BUY",
		}, card)

		local buyBtn = createGuiElement("TextButton", {
			Name = "BuyButton",
			Size = isRoblox and UDim2.new(0.17, 0, 0.78, 0) or nil,
			Position = isRoblox and UDim2.new(0.81, 0, 0.11, 0) or nil,
			BackgroundColor3 = isRoblox and Color3.fromRGB(95, 235, 45) or nil,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = true,
			TextColor3 = isRoblox and Color3.fromRGB(255, 255, 255) or nil,
			Text = "KUP",
		}, card)
		addCornerAndStroke(buyBtn, 6, isRoblox and Color3.fromRGB(22, 48, 12) or nil, 2)
		addTextStroke(buyBtn, 1.8)

		item = {
			id = id,
			card = card,
			nameLabel = nameLabel,
			levelLabel = levelLabel,
			priceLabel = priceLabel,
			statusLabel = statusLabel,
			buyButton = buyBtn,
			available = true,
			blockedReason = nil,
			quote = nil,
		}

		if buyBtn.Activated ~= nil then
			buyBtn.Activated:Connect(function()
				self:buyResearch(id)
			end)
		end

		self.shopResearch[id] = item
	end

	item.level = research.level
	item.levelLabel.Text = "Lv " .. tostring(research.level)

	-- Look up cached quote from ShopController
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

	-- Determine availability & blockedReason
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
		if isRoblox then
			item.buyButton.BackgroundColor3 = Color3.fromRGB(95, 235, 45)
			item.buyButton.Text = "KUP"
		end
	else
		item.buyButton.Active = false
		local reasonText = blockedReason or "LOCKED"
		item.statusLabel.Text = reasonText
		if isRoblox then
			item.buyButton.BackgroundColor3 = Color3.fromRGB(130, 115, 105)
			item.buyButton.Text = reasonText
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
			if not quoteView.available then
				item.available = false
				item.blockedReason = quoteView.blockedReason
				item.buyButton.Active = false
				item.statusLabel.Text = quoteView.blockedReason or "LOCKED"
			end
		end
	end
end

-- ============================================================================
-- Intent Actions (Triggered by Player UI Interactions)
-- ============================================================================

function HUD:pressHatch(callback)
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

function HUD:buyResearch(researchId, callback)
	if not self.intentControllers or not self.intentControllers.shop then
		return false, "NO_SHOP_CONTROLLER"
	end

	local target = {
		kind = "BuyResearch",
		args = { researchId = researchId, mode = "single" },
	}

	local currentRevision = if self.stateStore then self.stateStore:getCommitRevision() else nil
	local quote = self.intentControllers.shop:getCachedQuote(target)
	if quote ~= nil and quote.available and (currentRevision == nil or quote.expectedRevision == currentRevision) then
		return self.intentControllers.shop:confirmPurchase(quote, callback)
	else
		return self.intentControllers.shop:requestQuote(target, function(newQuote)
			if newQuote and newQuote.kind == "QuoteView" and newQuote.available then
				self.intentControllers.shop:confirmPurchase(newQuote, callback)
			elseif callback then
				callback({ status = "REJECTED", errorCode = "NO_QUOTE" })
			end
		end)
	end
end

-- ============================================================================
-- Accessors for UI Verification
-- ============================================================================

function HUD:getSessionStatus()
	return self.sessionStatus
end

function HUD:getCashText()
	return if self.cashLabel then self.cashLabel.Text else ""
end

function HUD:getProducedEggsText()
	return if self.producedEggsLabel then self.producedEggsLabel.Text else ""
end

function HUD:getSoldEggsText()
	return if self.soldEggsLabel then self.soldEggsLabel.Text else ""
end

function HUD:getShippingText()
	return if self.shippingLabel then self.shippingLabel.Text else ""
end

function HUD:getHatcheryText()
	return if self.hatcheryStockLabel then self.hatcheryStockLabel.Text else ""
end

function HUD:getHatcheryRatio()
	return self.hatcheryRatio
end

function HUD:getHatcheryRefillText()
	return if self.hatcheryRefillLabel then self.hatcheryRefillLabel.Text else ""
end

function HUD:getHabitatText(slotId)
	local label = self.habitatLabels[slotId]
	return if label then label.Text else ""
end

function HUD:getHabitatRatio(slotId)
	return self.habitatFillRatios[slotId] or 0
end

function HUD:getShopResearchItem(researchId)
	return self.shopResearch[researchId]
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
