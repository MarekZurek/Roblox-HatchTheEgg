--!nocheck
-- FarmPlotBuilder for HatchTheEgg (VIS-02 & VIS-03).
-- Generates the 3D Farm Island world in Workspace:
-- - Bright Turquoise Ocean Water, Central Rainbow Hub Island, and Player Farm Plot,
-- - Main Hatchery with physical floor Pressure Plate,
-- - 4 Habitat Plots at canonical coordinates with reactive BillboardGuis & ProximityPrompts,
-- - Step-On Studded Buy Pads (Płytki do kupowania),
-- - Red-and-White Silo Tower with SurfaceGui, Shipping Depot with vehicles, Research Lab Stall,
-- - Non-colliding low-poly farm trees & clouds (CanCollide=false, CanTouch=false, CanQuery=false).
--
-- CRITICAL ARCHITECTURAL INVARIANT:
-- Visual 3D world geometry and prompts are strictly presentation & intent triggers.
-- All economy mutations go through authoritative PlayerCoordinator / NetworkGateway.

local isRoblox = (typeof(Instance) == "table" and type(Instance.new) == "function")
local isStudio = (typeof(script) == "Instance")
local function resolve(studioGetter, lunePath)
	if isStudio then
		local ok, mod = pcall(studioGetter)
		if ok and mod then
			return if typeof(mod) == "Instance" then require(mod) else mod
		end
	end
	return require(lunePath)
end

local FvSe = resolve(function()
	return script.Parent.Parent.FarmMath.fv_se
end, "../FarmMath/fv_se")

local FarmPlotBuilder = {}
FarmPlotBuilder.__index = FarmPlotBuilder

-- Canonical coordinates matching RoutePresentation (PRE-03)
FarmPlotBuilder.HATCHERY_CENTER = { x = 0, y = 0, z = 55 }
FarmPlotBuilder.HATCHERY_SPAWN = { x = 0, y = 0, z = 45 }
FarmPlotBuilder.PRESSURE_PLATE_POS = { x = 0, y = 0.35, z = 37 }
FarmPlotBuilder.SPAWN_LOCATION_POS = { x = 0, y = 0.5, z = 24 }
FarmPlotBuilder.INCUBATOR_STATION_POS = { x = -30, y = 0, z = -5 }

FarmPlotBuilder.HABITAT_PLOTS = table.freeze({
	[1] = { slotId = 1, center = { x = -35, y = 0, z = -35 }, entrance = { x = -30, y = 0, z = -30 }, padPos = { x = -22, y = 0.35, z = -28 } },
	[2] = { slotId = 2, center = { x = 35, y = 0, z = -35 }, entrance = { x = 30, y = 0, z = -30 }, padPos = { x = 22, y = 0.35, z = -28 } },
	[3] = { slotId = 3, center = { x = -35, y = 0, z = 15 }, entrance = { x = -30, y = 0, z = 10 }, padPos = { x = -22, y = 0.35, z = 12 } },
	[4] = { slotId = 4, center = { x = 35, y = 0, z = 15 }, entrance = { x = 30, y = 0, z = 10 }, padPos = { x = 22, y = 0.35, z = 12 } },
})

FarmPlotBuilder.ROUTE_WAYPOINTS = table.freeze({
	[1] = {
		{ x = 0, y = 0, z = 45 },
		{ x = 0, y = 0, z = 25 },
		{ x = 0, y = 0, z = -5 },
		{ x = -15, y = 0, z = -20 },
		{ x = -30, y = 0, z = -30 },
	},
	[2] = {
		{ x = 0, y = 0, z = 45 },
		{ x = 0, y = 0, z = 25 },
		{ x = 0, y = 0, z = -5 },
		{ x = 15, y = 0, z = -20 },
		{ x = 30, y = 0, z = -30 },
	},
	[3] = {
		{ x = 0, y = 0, z = 45 },
		{ x = 0, y = 0, z = 25 },
		{ x = -15, y = 0, z = 20 },
		{ x = -30, y = 0, z = 10 },
	},
	[4] = {
		{ x = 0, y = 0, z = 45 },
		{ x = 0, y = 0, z = 25 },
		{ x = 15, y = 0, z = 20 },
		{ x = 30, y = 0, z = 10 },
	},
})

local HABITAT_DISPLAY_NAMES = table.freeze({
	[-1] = "Wolna Parcela",
	[0] = "Kurnik (Coop)",
	[1] = "Szopa (Shack)",
})

local VEHICLE_DISPLAY_NAMES = table.freeze({
	[0] = "Trójkołowiec (Trike)",
	[1] = "Furgonetka (Transit Van)",
})

local SUFFIXES = table.freeze({
	{ 1e12, "T" },
	{ 1e9, "B" },
	{ 1e6, "M" },
	{ 1e3, "K" },
})

local function formatCompact(value)
	local n = tonumber(value) or 0
	if n < 1000 then
		return tostring(math.floor(n + 0.5))
	end
	for _, tier in ipairs(SUFFIXES) do
		if n >= tier[1] then
			local s = string.format("%.1f", n / tier[1])
			s = string.gsub(s, "%.0$", "")
			return s .. tier[2]
		end
	end
	return tostring(n)
end

-- ============================================================================
-- Helper Constructors (Roblox & Lune Mock Compatible)
-- ============================================================================

local function rgb(r, g, b)
	if isRoblox then
		return Color3.fromRGB(r, g, b)
	end
	return { r = r, g = g, b = b }
end

local function v3(x, y, z)
	if isRoblox then
		return Vector3.new(x, y, z)
	end
	return { x = x, y = y, z = z, X = x, Y = y, Z = z }
end

local function cf(x, y, z)
	if isRoblox then
		return CFrame.new(x, y, z)
	end
	return { x = x, y = y, z = z }
end

local function makePart(props, parent, isDecorative)
	if not isRoblox then
		local mock = {
			ClassName = props.ClassName or "Part",
			Name = props.Name or "Part",
			Size = props.Size or v3(1, 1, 1),
			Position = props.Position or v3(0, 0, 0),
			CanCollide = if isDecorative then false else (if props.CanCollide ~= nil then props.CanCollide else true),
			CanTouch = if isDecorative then false else (if props.CanTouch ~= nil then props.CanTouch else true),
			CanQuery = if isDecorative then false else (if props.CanQuery ~= nil then props.CanQuery else true),
			Anchored = true,
			Parent = parent,
			Children = {},
			Attributes = {},
			SetAttribute = function(self, k, val) self.Attributes[k] = val end,
			GetAttribute = function(self, k) return self.Attributes[k] end,
		}
		if parent and type(parent.Children) == "table" then
			table.insert(parent.Children, mock)
		end
		return mock
	end

	local part = Instance.new(props.ClassName or "Part")
	part.Name = props.Name or "Part"
	part.Anchored = if props.Anchored ~= nil then props.Anchored else true
	part.Size = props.Size or Vector3.new(4, 1, 4)
	if props.CFrame then
		part.CFrame = props.CFrame
	elseif props.Position then
		part.Position = props.Position
	end
	part.Color = props.Color or Color3.fromRGB(255, 255, 255)
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Transparency = props.Transparency or 0
	if props.Shape and part:IsA("Part") then
		part.Shape = props.Shape
	end

	if props.StudsTop then
		part.TopSurface = Enum.SurfaceType.Studs
	else
		part.TopSurface = Enum.SurfaceType.Smooth
	end
	part.BottomSurface = Enum.SurfaceType.Smooth

	if isDecorative then
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = if props.CastShadow ~= nil then props.CastShadow else false
	else
		part.CanCollide = if props.CanCollide ~= nil then props.CanCollide else true
		part.CanTouch = if props.CanTouch ~= nil then props.CanTouch else false
		part.CanQuery = if props.CanQuery ~= nil then props.CanQuery else true
	end

	if parent then
		part.Parent = parent
	end
	return part
end

local function makeOutlinedText(parent, props)
	if not isRoblox then
		return { Name = props.Name or "TextLabel", Text = props.Text or "" }
	end
	local lbl = Instance.new("TextLabel")
	lbl.Name = props.Name or "Label"
	lbl.Size = props.Size or UDim2.new(1, 0, 0.33, 0)
	lbl.Position = props.Position or UDim2.new(0, 0, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Font = props.Font or Enum.Font.FredokaOne
	lbl.Text = props.Text or ""
	lbl.TextColor3 = props.TextColor3 or Color3.fromRGB(255, 255, 255)
	lbl.TextScaled = if props.TextScaled ~= nil then props.TextScaled else true
	lbl.RichText = true
	lbl.Parent = parent

	local stroke = Instance.new("UIStroke")
	stroke.Color = props.StrokeColor or Color3.fromRGB(20, 12, 8)
	stroke.Thickness = props.StrokeThickness or 2.8
	stroke.Parent = lbl

	return lbl
end

-- ============================================================================
-- Step-On Studded Buy Pad Builder (Screenshot 1 Style!)
-- ============================================================================

local function createBuyPad(parent, config)
	-- config: { name, padType, slotId, researchId, pos, padColor, line1, line2, line3, line1Color }
	local model
	if isRoblox then
		model = Instance.new("Model")
		model.Name = config.name
		model.Parent = parent
	else
		model = { Name = config.name, Children = {}, Attributes = {} }
		if parent and parent.Children then table.insert(parent.Children, model) end
	end

	local px, py, pz = config.pos.x, config.pos.y, config.pos.z

	-- 1. Wood Outer Border Frame
	makePart({
		Name = "WoodBorderFrame",
		Size = v3(7.4, 0.5, 7.4),
		Position = v3(px, py - 0.1, pz),
		Color = rgb(112, 72, 38),
		Material = isRoblox and Enum.Material.SmoothPlastic or nil,
		CanCollide = true,
		CanTouch = false,
		CanQuery = false,
	}, model, false)

	-- 2. Studded Inner Plate (Bright Lime Green or Golden Yellow with classic Studs!)
	local c = config.padColor or { 95, 235, 45 }
	local touchPart = makePart({
		Name = "TouchPlate",
		Size = v3(6.2, 0.65, 6.2),
		Position = v3(px, py + 0.1, pz),
		Color = rgb(c[1], c[2], c[3]),
		Material = isRoblox and Enum.Material.Plastic or nil,
		StudsTop = true,
		CanCollide = true,
		CanTouch = true,
		CanQuery = true,
	}, model, false)

	touchPart:SetAttribute("PadKind", config.padType)
	if config.slotId then
		touchPart:SetAttribute("SlotId", config.slotId)
	end
	if config.researchId then
		touchPart:SetAttribute("ResearchId", config.researchId)
	end

	-- 3. Floating 3-Line Outlined BillboardGui right above the pad (Screenshot 1 style)
	local line1Label, line2Label, line3Label
	if isRoblox then
		local bb = Instance.new("BillboardGui")
		bb.Name = "PadBillboard"
		bb.Adornee = touchPart
		bb.Size = UDim2.new(0, 210, 0, 95)
		bb.StudsOffset = Vector3.new(0, 3.6, 0)
		bb.AlwaysOnTop = false
		bb.MaxDistance = 25
		bb.Parent = touchPart

		line1Label = makeOutlinedText(bb, {
			Name = "Line1_Title",
			Size = UDim2.new(1, 0, 0.30, 0),
			Position = UDim2.new(0, 0, 0, 0),
			Text = config.line1 or "[Ulepszenie]",
			TextColor3 = config.line1Color or Color3.fromRGB(255, 130, 245),
			StrokeThickness = 2.5,
		})

		line2Label = makeOutlinedText(bb, {
			Name = "Line2_Effect",
			Size = UDim2.new(1, 0, 0.28, 0),
			Position = UDim2.new(0, 0, 0.30, 0),
			Text = config.line2 or "+Efekt",
			TextColor3 = Color3.fromRGB(255, 255, 255),
			StrokeThickness = 2.5,
		})

		line3Label = makeOutlinedText(bb, {
			Name = "Line3_Price",
			Size = UDim2.new(1, 0, 0.42, 0),
			Position = UDim2.new(0, 0, 0.58, 0),
			Text = config.line3 or "$100",
			TextColor3 = Color3.fromRGB(95, 255, 75),
			StrokeThickness = 3.2,
		})
	else
		line1Label = { Text = config.line1 or "" }
		line2Label = { Text = config.line2 or "" }
		line3Label = { Text = config.line3 or "" }
	end

	return {
		model = model,
		touchPart = touchPart,
		padType = config.padType,
		slotId = config.slotId,
		researchId = config.researchId,
		line1Label = line1Label,
		line2Label = line2Label,
		line3Label = line3Label,
	}
end

-- ============================================================================
-- Egg Upgrade Pedestal Builder (PROD-02)
-- ============================================================================

local function createEggUpgradePedestal(parent, pos, self)
	local pedestal = makePart({
		Name = "EggUpgradePedestal",
		Size = v3(7, 3.6, 7),
		Position = v3(pos.x, pos.y, pos.z),
		Color = rgb(255, 215, 65),
		StudsTop = true,
		CanCollide = true,
		CanTouch = true,
		CanQuery = true,
	}, parent, false)

	-- Floating glowing mini egg atop the pedestal
	makePart({
		Name = "PedestalMiniEgg",
		Shape = isRoblox and Enum.PartType.Ball or nil,
		Size = v3(2.6, 3.6, 2.6),
		Position = v3(pos.x, pos.y + 3.0, pos.z),
		Color = rgb(255, 245, 140),
		Material = isRoblox and Enum.Material.Neon or nil,
	}, parent, true)

	local prompt
	if isRoblox then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "EggUpgradeProximityPrompt"
		prompt.ObjectText = "Stacja Badawcza Jaj"
		prompt.ActionText = "Zbadaj Nowe Jajo / Awansuj"
		prompt.KeyboardKeyCode = Enum.KeyCode.G
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 15
		prompt.RequiresLineOfSight = false
		prompt.Parent = pedestal

		local bb = Instance.new("BillboardGui")
		bb.Name = "EggUpgradeBillboard"
		bb.Adornee = pedestal
		bb.Size = UDim2.new(0, 260, 0, 85)
		bb.StudsOffset = Vector3.new(0, 6.2, 0)
		bb.MaxDistance = 32
		bb.AlwaysOnTop = false
		bb.Parent = pedestal

		local curLabel = makeOutlinedText(bb, {
			Name = "CurrentEggLabel",
			Size = UDim2.new(1, 0, 0.33, 0),
			Position = UDim2.new(0, 0, 0, 0),
			Text = "🥚 Aktualne: Jajo Jadalne (Edible)",
			TextColor3 = Color3.fromRGB(255, 235, 100),
			StrokeThickness = 2.8,
		})

		local nextLabel = makeOutlinedText(bb, {
			Name = "NextEggLabel",
			Size = UDim2.new(1, 0, 0.33, 0),
			Position = UDim2.new(0, 0, 0.33, 0),
			Text = "✨ Następne: Jajo Superfood",
			TextColor3 = Color3.fromRGB(115, 245, 115),
			StrokeThickness = 2.8,
		})

		local reqLabel = makeOutlinedText(bb, {
			Name = "RequiredFvLabel",
			Size = UDim2.new(1, 0, 0.33, 0),
			Position = UDim2.new(0, 0, 0.66, 0),
			Text = "Wymagane FV: $68.0M",
			TextColor3 = Color3.fromRGB(255, 255, 255),
			StrokeThickness = 2.8,
		})

		if self and self.eggUpgradeBillboards then
			table.insert(self.eggUpgradeBillboards, {
				bb = bb,
				curLabel = curLabel,
				nextLabel = nextLabel,
				reqLabel = reqLabel,
			})
		end
	else
		prompt = {
			Name = "EggUpgradeProximityPrompt",
			ObjectText = "Stacja Badawcza Jaj",
			ActionText = "Zbadaj Nowe Jajo / Awansuj",
			KeyboardKeyCode = "G",
			MaxActivationDistance = 15,
			HoldDuration = 0,
			Parent = pedestal,
		}
		if pedestal.Children then
			table.insert(pedestal.Children, prompt)
		end
		local curLabel = { Text = "🥚 Aktualne: Jajo Jadalne (Edible)" }
		local nextLabel = { Text = "✨ Następne: Jajo Superfood" }
		local reqLabel = { Text = "Wymagane FV: $68.0M" }
		if self and self.eggUpgradeBillboards then
			table.insert(self.eggUpgradeBillboards, {
				bb = { Name = "EggUpgradeBillboard" },
				curLabel = curLabel,
				nextLabel = nextLabel,
				reqLabel = reqLabel,
			})
		end
	end

	if self then
		if not self.eggUpgradePedestal then
			self.eggUpgradePedestal = pedestal
		end
		if not self.eggUpgradePrompt then
			self.eggUpgradePrompt = prompt
		end
	end

	return pedestal
end

-- ============================================================================
-- Decorative Farm Prop Builders (CanCollide=false, CanTouch=false, CanQuery=false)
-- ============================================================================

local function buildPineTree(parent, x, y, z, scale, foliageColor)
	scale = scale or 1
	-- Wooden trunk
	makePart({
		Name = "TreeTrunk",
		Shape = isRoblox and Enum.PartType.Cylinder or nil,
		Size = v3(6 * scale, 1.8 * scale, 1.8 * scale),
		CFrame = isRoblox and (CFrame.new(x, y + 3.0 * scale, z) * CFrame.Angles(0, 0, math.rad(90))) or nil,
		Position = v3(x, y + 3.0 * scale, z),
		Color = rgb(125, 78, 42),
	}, parent, true)

	-- Stepped studded green canopy layers
	local leafColor = foliageColor or rgb(72, 198, 52)
	for tier = 1, 3 do
		local w = (8.0 - (tier - 1) * 2.2) * scale
		makePart({
			Name = "PineCanopy_" .. tier,
			Size = v3(w, 2.8 * scale, w),
			Position = v3(x, y + (5.2 + (tier - 1) * 2.3) * scale, z),
			Color = leafColor,
			StudsTop = true,
		}, parent, true)
	end
end

local function buildRoundTree(parent, x, y, z, foliageColor)
	-- Wooden trunk
	makePart({
		Name = "TreeTrunk",
		Size = v3(2.2, 6, 2.2),
		Position = v3(x, y + 3, z),
		Color = rgb(125, 78, 42),
		Material = isRoblox and Enum.Material.SmoothPlastic or nil,
	}, parent, true)

	-- Fluffy spherical leafy canopy
	makePart({
		Name = "TreeCanopyMain",
		Shape = isRoblox and Enum.PartType.Ball or nil,
		Size = v3(8.5, 7.5, 8.5),
		Position = v3(x, y + 8, z),
		Color = foliageColor or rgb(92, 212, 58),
		StudsTop = true,
	}, parent, true)

	makePart({
		Name = "TreeCanopyTop",
		Shape = isRoblox and Enum.PartType.Ball or nil,
		Size = v3(5.5, 5.0, 5.5),
		Position = v3(x, y + 11.2, z),
		Color = rgb(135, 238, 85),
	}, parent, true)
end

local function buildGiantRainbowAndHub(worldFolder, self)
	local hubFolder
	if isRoblox then
		hubFolder = Instance.new("Folder")
		hubFolder.Name = "CentralHubAndIslands"
		hubFolder.Parent = worldFolder
	else
		hubFolder = { Name = "CentralHubAndIslands", Children = {} }
	end

	-- 1. Wooden Bridge from Player Farm Island (z = -62) to Central Hub Island (z = -110)
	makePart({
		Name = "WoodenBridgeDeck",
		Size = v3(16, 1.5, 52),
		Position = v3(0, -0.2, -88),
		Color = rgb(185, 132, 78),
		StudsTop = true,
		CanCollide = true,
	}, hubFolder, false)

	makePart({
		Name = "WoodenBridgeRailLeft",
		Size = v3(1.2, 3.2, 52),
		Position = v3(-7.4, 1.4, -88),
		Color = rgb(125, 82, 44),
		CanCollide = true,
	}, hubFolder, false)

	makePart({
		Name = "WoodenBridgeRailRight",
		Size = v3(1.2, 3.2, 52),
		Position = v3(7.4, 1.4, -88),
		Color = rgb(125, 82, 44),
		CanCollide = true,
	}, hubFolder, false)

	-- 2. Central Hub Island (Screenshot 2 centerpiece with Giant Rainbow & Clouds!)
	makePart({
		Name = "HubSandyBeachBase",
		Size = v3(96, 10, 96),
		Position = v3(0, -5.5, -160),
		Color = rgb(238, 206, 138),
		CanCollide = true,
	}, hubFolder, false)

	makePart({
		Name = "HubStuddedGrass",
		Size = v3(92, 1.5, 92),
		Position = v3(0, 0, -160),
		Color = rgb(106, 222, 42),
		Material = isRoblox and Enum.Material.Plastic or nil,
		StudsTop = true,
		CanCollide = true,
	}, hubFolder, false)

	-- Central Golden Egg Monument on Hub Island
	makePart({
		Name = "HubMonumentPedestal",
		Size = v3(18, 6, 18),
		Position = v3(0, 3, -160),
		Color = rgb(225, 175, 105),
		StudsTop = true,
		CanCollide = true,
	}, hubFolder, false)

	makePart({
		Name = "HubGiantGoldenEgg",
		Shape = isRoblox and Enum.PartType.Ball or nil,
		Size = v3(14, 19, 14),
		Position = v3(0, 14, -160),
		Color = rgb(255, 215, 35),
		Material = isRoblox and Enum.Material.Neon or nil,
	}, hubFolder, true)

	-- Interactive Egg Upgrade Pedestal under the Rainbow Monument (PROD-02)
	createEggUpgradePedestal(hubFolder, { x = 0, y = 2.5, z = -148 }, self)

	-- Giant 7-Color Rainbow Arch over the Central Hub (Screenshot 2!)
	local rainbowColors = {
		rgb(255, 65, 65),
		rgb(255, 155, 45),
		rgb(255, 235, 55),
		rgb(75, 235, 85),
		rgb(65, 185, 255),
		rgb(115, 95, 255),
		rgb(225, 95, 255),
	}
	local numSegments = 18
	for bandIdx, bandColor in ipairs(rainbowColors) do
		local radius = 64 - (bandIdx - 1) * 2.2
		for s = 1, numSegments do
			local a1 = math.pi * (s - 1) / numSegments
			local a2 = math.pi * s / numSegments
			local midA = (a1 + a2) * 0.5
			local segLen = radius * (a2 - a1) * 1.08
			local rx = math.cos(midA) * radius
			local ry = math.sin(midA) * radius
			local rz = -160
			if isRoblox then
				local segPart = makePart({
					Name = "RainbowSeg_" .. bandIdx .. "_" .. s,
					Size = Vector3.new(2.2, segLen, 3.5),
					CFrame = CFrame.new(rx, ry, rz) * CFrame.Angles(0, 0, midA),
					Color = bandColor,
					Material = Enum.Material.Neon,
					Transparency = 0.08,
				}, hubFolder, true)
				local _ = segPart
			end
		end
	end

	-- Fluffy White Clouds at Rainbow bases (Screenshot 2!)
	for _, sideX in ipairs({ -60, 60 }) do
		for cIdx = 1, 5 do
			local ox = (cIdx - 3) * 4.5
			local oy = (cIdx % 2) * 2.5 + 3
			local oz = ((cIdx * 7) % 5 - 2) * 2.5
			makePart({
				Name = "RainbowCloud",
				Shape = isRoblox and Enum.PartType.Ball or nil,
				Size = v3(14, 11, 14),
				Position = v3(sideX + ox, oy, -160 + oz),
				Color = rgb(255, 252, 255),
			}, hubFolder, true)
		end
	end

	-- Decorative Neighbor Farm Islands (Left & Right of Hub, like Screenshot 2!)
	for _, neighbor in ipairs({
		{ name = "NeighborIsland_West", x = -145, z = -110, rampColor = rgb(235, 55, 55) },
		{ name = "NeighborIsland_East", x = 145, z = -110, rampColor = rgb(235, 55, 55) },
	}) do
		makePart({
			Name = neighbor.name .. "_BeachBase",
			Size = v3(74, 9, 74),
			Position = v3(neighbor.x, -5, neighbor.z),
			Color = rgb(238, 206, 138),
		}, hubFolder, true)

		makePart({
			Name = neighbor.name .. "_Grass",
			Size = v3(70, 1.5, 70),
			Position = v3(neighbor.x, 0, neighbor.z),
			Color = rgb(106, 222, 42),
			StudsTop = true,
		}, hubFolder, true)

		-- Red-carpet display ramp on the side of island (like Screenshot 2!)
		makePart({
			Name = neighbor.name .. "_Grandstand",
			Size = v3(22, 10, 56),
			Position = v3(neighbor.x + (neighbor.x < 0 and -22 or 22), 5, neighbor.z),
			Color = rgb(198, 152, 98),
			StudsTop = true,
		}, hubFolder, true)

		makePart({
			Name = neighbor.name .. "_RedCarpet",
			Size = v3(14, 0.4, 48),
			Position = v3(neighbor.x + (neighbor.x < 0 and -12 or 12), 1.0, neighbor.z),
			Color = neighbor.rampColor,
			StudsTop = true,
		}, hubFolder, true)

		buildPineTree(hubFolder, neighbor.x, 0.5, neighbor.z - 18, 1.1, rgb(76, 204, 52))
		buildRoundTree(hubFolder, neighbor.x, 0.5, neighbor.z + 18, rgb(102, 220, 64))
	end
end

-- ============================================================================
-- Habitat Building Visual Constructor (Tier -1, 0, 1)
-- ============================================================================

local function populateHabitatStructure(buildingModel, slotId, typeIndex)
	if isRoblox then
		for _, child in ipairs(buildingModel:GetChildren()) do
			child:Destroy()
		end
	else
		buildingModel.Children = {}
	end

	local plotInfo = FarmPlotBuilder.HABITAT_PLOTS[slotId]
	local cx, cy, cz = plotInfo.center.x, plotInfo.center.y, plotInfo.center.z

	-- Raised Parcel Base Frame
	makePart({
		Name = "ParcelBaseFrame",
		Size = v3(25, 0.8, 25),
		Position = v3(cx, cy + 0.2, cz),
		Color = rgb(110, 64, 34),
		CanCollide = true,
	}, buildingModel, false)

	makePart({
		Name = "ParcelStuddedFloor",
		Size = v3(23, 0.9, 23),
		Position = v3(cx, cy + 0.35, cz),
		Color = if typeIndex == -1 then rgb(215, 175, 120) elseif typeIndex == 0 then rgb(255, 235, 195) else rgb(215, 240, 255),
		StudsTop = true,
		CanCollide = true,
	}, buildingModel, false)

	if typeIndex == -1 then
		-- Unbuilt Parcel: construction sign & corner posts
		for _, dx in ipairs({ -9, 9 }) do
			for _, dz in ipairs({ -9, 9 }) do
				makePart({
					Name = "ParcelPost",
					Size = v3(1.5, 3.5, 1.5),
					Position = v3(cx + dx, cy + 2.2, cz + dz),
					Color = rgb(255, 125, 175),
				}, buildingModel, true)
			end
		end
		return
	end

	-- Built Habitat (typeIndex 0 = Starter Coop, typeIndex 1 = Wooden Shack)
	local wallColor = if typeIndex == 0 then rgb(255, 242, 215) else rgb(175, 225, 255)
	local roofColor = if typeIndex == 0 then rgb(255, 95, 145) else rgb(125, 85, 245)
	local trimColor = if typeIndex == 0 then rgb(125, 68, 36) else rgb(255, 215, 65)
	local height = if typeIndex == 0 then 9 else 13

	-- Main Coop Walls
	makePart({
		Name = "CoopBody",
		Size = v3(16, height, 16),
		Position = v3(cx, cy + 0.8 + height * 0.5, cz),
		Color = wallColor,
		StudsTop = true,
		CanCollide = true,
	}, buildingModel, false)

	-- Corner Trim Pillars
	for _, dx in ipairs({ -7.8, 7.8 }) do
		for _, dz in ipairs({ -7.8, 7.8 }) do
			makePart({
				Name = "CornerTrim",
				Size = v3(1.4, height + 0.4, 1.4),
				Position = v3(cx + dx, cy + 0.8 + height * 0.5, cz + dz),
				Color = trimColor,
			}, buildingModel, true)
		end
	end

	-- Stepped Studded Roof (Classic Roblox Tycoon / Simulator style!)
	for step = 1, 4 do
		local w = 19 - (step - 1) * 3.6
		makePart({
			Name = "CoopRoofStep_" .. step,
			Size = v3(w, 1.4, w),
			Position = v3(cx, cy + 0.8 + height + (step - 0.5) * 1.4, cz),
			Color = roofColor,
			StudsTop = true,
		}, buildingModel, true)
	end

	-- Golden Egg Finial on top of Tier 1 Shack
	if typeIndex >= 1 then
		makePart({
			Name = "RoofEggFinial",
			Shape = isRoblox and Enum.PartType.Ball or nil,
			Size = v3(3.2, 4.2, 3.2),
			Position = v3(cx, cy + 0.8 + height + 7.2, cz),
			Color = rgb(255, 220, 45),
			Material = isRoblox and Enum.Material.Neon or nil,
		}, buildingModel, true)
	end

	-- Cute Chicken Doorway at the canonical entrance direction
	local ex, ez = plotInfo.entrance.x, plotInfo.entrance.z
	makePart({
		Name = "CoopEntranceArch",
		Size = v3(4.6, 5.2, 2.2),
		Position = v3((cx + ex) * 0.5, cy + 3.2, (cz + ez) * 0.5),
		Color = rgb(90, 45, 22),
	}, buildingModel, true)
end

-- ============================================================================
-- Main World Constructor
-- ============================================================================

function FarmPlotBuilder.new(deps)
	deps = deps or {}
	local self = setmetatable({
		workspace = deps.workspace or (isRoblox and game:GetService("Workspace") or { Name = "Workspace", Children = {} }),
		worldFolder = nil,
		spawnLocation = nil,
		pressurePlate = nil,
		hatchPrompt = nil,
		researchPrompt = nil,
		depotPrompt = nil,
		eggUpgradePedestal = nil,
		eggUpgradePrompt = nil,
		eggUpgradeBillboards = {},
		siloSurfaceLabel = nil,
		siloModels = {},
		siloLabels = {},
		deliveryTruckModel = nil,
		deliveryParcelModel = nil,
		deliveryPrompt = nil,
		incubatorStationModel = nil,
		incubatorPrompt = nil,
		incubatorEgg = nil,
		habitats = {},
		buyPads = {},
		vehiclesModels = {},
	}, FarmPlotBuilder)

	return self
end

function FarmPlotBuilder:build()
	if isRoblox then
		local existing = self.workspace:FindFirstChild("HatchTheEggWorld")
		if existing then
			existing:Destroy()
		end
		-- Remove default Baseplate if present so our Farm Islands shine!
		local baseplate = self.workspace:FindFirstChild("Baseplate")
		if baseplate then
			baseplate:Destroy()
		end
	end

	local worldFolder
	if isRoblox then
		worldFolder = Instance.new("Folder")
		worldFolder.Name = "HatchTheEggWorld"
		worldFolder.Parent = self.workspace
	else
		worldFolder = { Name = "HatchTheEggWorld", Children = {} }
	end
	self.worldFolder = worldFolder

	-- 0. Configure Bright Sunny Sky & Lighting
	self:_configureSunnyLighting()

	-- 1. Bright Turquoise Ocean Water with Foam Ripples
	self:_buildOceanWater(worldFolder)

	-- 2. Main Player Farm Island (Golden sandy beach & lime-green studded grass!)
	self:_buildFarmIslandBase(worldFolder)

	-- 3. Central Rainbow Hub Island & Bridges (Screenshot 2 inspiration!)
	buildGiantRainbowAndHub(worldFolder, self)

	-- 4. Paved Cobblestone / Sandy Chicken Roads matching RoutePresentation
	self:_buildChickenPaths(worldFolder)

	-- 5. Main Hatchery & Physical Floor Pressure Plate
	self:_buildHatchery(worldFolder)

	-- 6. 4 Habitat Plots, BillboardGuis, ProximityPrompts & Step-On Buy Pads
	self:_buildHabitats(worldFolder)

	-- 7. Classic Red-and-White Silo Tower with SurfaceGui
	self:_buildSiloTower(worldFolder)

	-- 8. Shipping Depot, Fleet Parking & Step-On Vehicle Buy Pads
	self:_buildShippingDepot(worldFolder)

	-- 9. Research Lab Stall & Step-On Research Buy Pads
	self:_buildResearchStall(worldFolder)

	-- 10. Low-Poly Farm Trees & Decorations (CanCollide=false, CanTouch=false, CanQuery=false)
	self:_buildFarmDecorations(worldFolder)

	-- 11. Pet Incubator Station & 3D Egg (PROD-07)
	self:_buildPetIncubatorStation(worldFolder)

	return self
end

function FarmPlotBuilder:_configureSunnyLighting()
	if not isRoblox then return end
	pcall(function()
		local Lighting = game:GetService("Lighting")
		Lighting.ClockTime = 13.5
		Lighting.Brightness = 2.6
		Lighting.Ambient = Color3.fromRGB(135, 145, 160)
		Lighting.OutdoorAmbient = Color3.fromRGB(155, 165, 180)
		Lighting.ColorShift_Top = Color3.fromRGB(255, 248, 230)

		local sky = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky", Lighting)
		sky.SunAngularSize = 18
	end)
end

function FarmPlotBuilder:_buildOceanWater(worldFolder)
	local seaFolder
	if isRoblox then
		seaFolder = Instance.new("Folder")
		seaFolder.Name = "OceanWater"
		seaFolder.Parent = worldFolder
	else
		seaFolder = { Name = "OceanWater", Children = {} }
	end

	-- Main Bright Turquoise Water Surface (Screenshot 2 style!)
	makePart({
		Name = "TurquoiseOceanSurface",
		Size = v3(1600, 16, 1600),
		Position = v3(0, -14, 0),
		Color = rgb(38, 168, 245),
		Material = isRoblox and Enum.Material.Foil or nil,
		Transparency = 0.08,
	}, seaFolder, true)

	-- Deep Ocean Floor underneath
	makePart({
		Name = "DeepOceanBed",
		Size = v3(1600, 4, 1600),
		Position = v3(0, -24, 0),
		Color = rgb(18, 105, 185),
		Material = isRoblox and Enum.Material.SmoothPlastic or nil,
	}, seaFolder, true)

	-- White Foam Waves & Lighter Cyan Water Ripples around the islands
	local waveOffsets = {
		{ -95, 20, 28, 18 }, { 95, -10, 32, 20 }, { -80, -85, 26, 22 },
		{ 85, 75, 30, 18 }, { 0, 115, 45, 22 }, { -120, -35, 25, 35 },
	}
	for idx, w in ipairs(waveOffsets) do
		makePart({
			Name = "WaterWave_" .. idx,
			Size = v3(w[3], 0.5, w[4]),
			Position = v3(w[1], -5.85, w[2]),
			Color = if idx % 2 == 0 then rgb(115, 215, 255) else rgb(235, 250, 255),
			Transparency = 0.15,
		}, seaFolder, true)
	end
end

function FarmPlotBuilder:_buildFarmIslandBase(worldFolder)
	local islandFolder
	if isRoblox then
		islandFolder = Instance.new("Folder")
		islandFolder.Name = "FarmIsland"
		islandFolder.Parent = worldFolder
	else
		islandFolder = { Name = "FarmIsland", Children = {} }
	end

	-- Earthy Island Cliff Base
	makePart({
		Name = "IslandCliffBase",
		Size = v3(148, 12, 136),
		Position = v3(0, -6.6, 0),
		Color = rgb(138, 98, 64),
		CanCollide = true,
	}, islandFolder, false)

	-- Golden Beach Sand Rim
	makePart({
		Name = "IslandSandyBeachRim",
		Size = v3(144, 3, 132),
		Position = v3(0, -1.2, 0),
		Color = rgb(242, 212, 148),
		CanCollide = true,
	}, islandFolder, false)

	-- Bright Lime Green Studded Grass Top (Screenshot 1 & 2 exact look!)
	makePart({
		Name = "IslandStuddedGrass",
		Size = v3(140, 1.2, 128),
		Position = v3(0, -0.6, 0),
		Color = rgb(106, 222, 42),
		Material = isRoblox and Enum.Material.Plastic or nil,
		StudsTop = true,
		CanCollide = true,
	}, islandFolder, false)

	-- Red-Carpet Showcase Grandstand on the South Edge (inspired by Screenshot 2!)
	makePart({
		Name = "SouthShowcasePlatform",
		Size = v3(78, 3.2, 10),
		Position = v3(0, 1.2, 68),
		Color = rgb(198, 152, 98),
		StudsTop = true,
		CanCollide = true,
	}, islandFolder, false)

	makePart({
		Name = "SouthRedCarpet",
		Size = v3(68, 0.3, 6),
		Position = v3(0, 2.9, 68),
		Color = rgb(225, 48, 58),
		StudsTop = true,
	}, islandFolder, true)

	-- Wooden Farm Perimeter Fence around the plot (leaving North bridge open)
	local fenceSegments = {
		{ name = "FenceWest", pos = v3(-69, 1.8, 0), size = v3(2, 3.6, 126) },
		{ name = "FenceEast", pos = v3(69, 1.8, 0), size = v3(2, 3.6, 126) },
		{ name = "FenceNorthWest", pos = v3(-39, 1.8, -63), size = v3(60, 3.6, 2) },
		{ name = "FenceNorthEast", pos = v3(39, 1.8, -63), size = v3(60, 3.6, 2) },
	}
	for _, f in ipairs(fenceSegments) do
		makePart({
			Name = f.name,
			Size = f.size,
			Position = f.pos,
			Color = rgb(148, 96, 52),
			StudsTop = true,
			CanCollide = true,
		}, islandFolder, false)
	end

	-- SpawnLocation
	if isRoblox then
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "FarmSpawnLocation"
		spawn.Anchored = true
		spawn.CanCollide = true
		spawn.Size = Vector3.new(8, 0.6, 8)
		spawn.Position = Vector3.new(
			FarmPlotBuilder.SPAWN_LOCATION_POS.x,
			FarmPlotBuilder.SPAWN_LOCATION_POS.y,
			FarmPlotBuilder.SPAWN_LOCATION_POS.z
		)
		spawn.Color = Color3.fromRGB(255, 235, 110)
		spawn.TopSurface = Enum.SurfaceType.Studs
		spawn.Transparency = 0.15
		spawn.Parent = islandFolder
		self.spawnLocation = spawn
	else
		self.spawnLocation = makePart({
			ClassName = "SpawnLocation",
			Name = "FarmSpawnLocation",
			Size = v3(8, 0.6, 8),
			Position = v3(
				FarmPlotBuilder.SPAWN_LOCATION_POS.x,
				FarmPlotBuilder.SPAWN_LOCATION_POS.y,
				FarmPlotBuilder.SPAWN_LOCATION_POS.z
			),
		}, islandFolder, false)
	end
end

function FarmPlotBuilder:_buildChickenPaths(worldFolder)
	local pathsFolder
	if isRoblox then
		pathsFolder = Instance.new("Folder")
		pathsFolder.Name = "ChickenPaths"
		pathsFolder.Parent = worldFolder
	else
		pathsFolder = { Name = "ChickenPaths", Children = {} }
	end

	for slotId = 1, 4 do
		local waypoints = FarmPlotBuilder.ROUTE_WAYPOINTS[slotId]
		for i = 1, #waypoints - 1 do
			local p1 = waypoints[i]
			local p2 = waypoints[i + 1]
			local dx = p2.x - p1.x
			local dz = p2.z - p1.z
			local len = math.sqrt(dx * dx + dz * dz)
			local mx = (p1.x + p2.x) * 0.5
			local mz = (p1.z + p2.z) * 0.5
			local angle = math.atan2(-dx, -dz)

			makePart({
				Name = string.format("Path_Slot%d_Seg%d", slotId, i),
				Size = v3(5.6, 0.25, len + 2.2),
				CFrame = isRoblox and (CFrame.new(mx, 0.08, mz) * CFrame.Angles(0, angle, 0)) or nil,
				Position = v3(mx, 0.08, mz),
				Color = rgb(235, 192, 132),
				StudsTop = true,
			}, pathsFolder, true)
		end
	end
end

function FarmPlotBuilder:_buildHatchery(worldFolder)
	local hatcheryModel
	if isRoblox then
		hatcheryModel = Instance.new("Model")
		hatcheryModel.Name = "Hatchery"
		hatcheryModel.Parent = worldFolder
	else
		hatcheryModel = { Name = "Hatchery", Children = {} }
	end

	local hx, hy, hz = FarmPlotBuilder.HATCHERY_CENTER.x, FarmPlotBuilder.HATCHERY_CENTER.y, FarmPlotBuilder.HATCHERY_CENTER.z

	-- Gingerbread & Strawberry Cream Barn Body
	local mainBody = makePart({
		Name = "HatcheryMainBarn",
		Size = v3(22, 12, 15),
		Position = v3(hx, hy + 6, hz),
		Color = rgb(255, 232, 210),
		StudsTop = true,
		CanCollide = true,
	}, hatcheryModel, false)

	-- Strawberry Frosting Stepped Roof
	for step = 1, 4 do
		local w = 25 - (step - 1) * 4.5
		makePart({
			Name = "HatcheryRoof_" .. step,
			Size = v3(w, 1.6, 17 - (step - 1) * 2.2),
			Position = v3(hx, hy + 12 + (step - 0.5) * 1.6, hz),
			Color = rgb(255, 85, 135),
			StudsTop = true,
		}, hatcheryModel, true)
	end

	-- Glowing Giant Egg Sign on Hatchery Roof
	makePart({
		Name = "HatcheryRoofEgg",
		Shape = isRoblox and Enum.PartType.Ball or nil,
		Size = v3(5.5, 7.5, 5.5),
		Position = v3(hx, hy + 21, hz),
		Color = rgb(255, 248, 220),
		Material = isRoblox and Enum.Material.Neon or nil,
	}, hatcheryModel, true)

	-- Chicken Exit Archway at (0, 0, 45)
	local gateDoor = makePart({
		Name = "HatcherySpawnGate",
		Size = v3(7, 6.5, 2),
		Position = v3(0, 3.25, 47.2),
		Color = rgb(95, 48, 24),
		CanCollide = false,
		CanTouch = false,
		CanQuery = true,
	}, hatcheryModel, false)

	if isRoblox then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "HatchProximityPrompt"
		prompt.ObjectText = "Główna Wylęgarnia"
		prompt.ActionText = "Wylęgaj kurczaki"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 18
		prompt.RequiresLineOfSight = false
		prompt.Parent = gateDoor
		self.hatchPrompt = prompt

		local bb = Instance.new("BillboardGui")
		bb.Name = "HatcheryBillboard"
		bb.Adornee = mainBody
		bb.Size = UDim2.new(0, 260, 0, 70)
		bb.StudsOffset = Vector3.new(0, 12, 0)
		bb.MaxDistance = 32
		bb.Parent = mainBody

		makeOutlinedText(bb, {
			Name = "Title",
			Size = UDim2.new(1, 0, 0.6, 0),
			Text = "🐣 WYLĘGARNIA KURCZĄT",
			TextColor3 = Color3.fromRGB(255, 235, 85),
			StrokeThickness = 3,
		})
		makeOutlinedText(bb, {
			Name = "Subtitle",
			Size = UDim2.new(1, 0, 0.4, 0),
			Position = UDim2.new(0, 0, 0.6, 0),
			Text = "Wejdź na czerwony przycisk lub naciśnij [E]!",
			TextColor3 = Color3.fromRGB(255, 255, 255),
			StrokeThickness = 2.2,
		})
	end

	-- Physical Red Studded Floor Hatch Button (Pressure Plate)
	local px = FarmPlotBuilder.PRESSURE_PLATE_POS.x
	local py = FarmPlotBuilder.PRESSURE_PLATE_POS.y
	local pz = FarmPlotBuilder.PRESSURE_PLATE_POS.z

	makePart({
		Name = "HatchPadBorderFrame",
		Size = v3(9.4, 0.5, 9.4),
		Position = v3(px, py - 0.12, pz),
		Color = rgb(110, 68, 36),
		CanCollide = true,
	}, hatcheryModel, false)

	local plate = makePart({
		Name = "HatchPressurePlate",
		Size = v3(8.0, 0.75, 8.0),
		Position = v3(px, py + 0.15, pz),
		Color = rgb(255, 58, 75),
		Material = isRoblox and Enum.Material.Plastic or nil,
		StudsTop = true,
		CanCollide = true,
		CanTouch = true,
		CanQuery = true,
	}, hatcheryModel, false)
	plate:SetAttribute("PadKind", "HatchPressurePlate")
	self.pressurePlate = plate

	if isRoblox then
		local plateBb = Instance.new("BillboardGui")
		plateBb.Name = "PressurePlateBillboard"
		plateBb.Adornee = plate
		plateBb.Size = UDim2.new(0, 220, 0, 75)
		plateBb.StudsOffset = Vector3.new(0, 3.5, 0)
		plateBb.MaxDistance = 24
		plateBb.AlwaysOnTop = false
		plateBb.Parent = plate

		makeOutlinedText(plateBb, {
			Name = "ActionLabel",
			Size = UDim2.new(1, 0, 0.55, 0),
			Text = "🐣 WYLĘGAJ TERAZ!",
			TextColor3 = Color3.fromRGB(255, 110, 130),
			StrokeThickness = 3.0,
		})
		makeOutlinedText(plateBb, {
			Name = "HintLabel",
			Size = UDim2.new(1, 0, 0.45, 0),
			Position = UDim2.new(0, 0, 0.55, 0),
			Text = "[Stań tutaj]",
			TextColor3 = Color3.fromRGB(255, 255, 140),
			StrokeThickness = 2.4,
		})
	end

	-- Interactive Egg Upgrade Pedestal beside Hatchery walkway (PROD-02)
	createEggUpgradePedestal(hatcheryModel, { x = 14, y = 1.8, z = 34 }, self)
end

function FarmPlotBuilder:_buildHabitats(worldFolder)
	local habsFolder
	if isRoblox then
		habsFolder = Instance.new("Folder")
		habsFolder.Name = "Habitats"
		habsFolder.Parent = worldFolder
	else
		habsFolder = { Name = "Habitats", Children = {} }
	end

	for slotId = 1, 4 do
		local plotInfo = FarmPlotBuilder.HABITAT_PLOTS[slotId]
		local initialType = if slotId == 1 then 0 else -1

		local slotModel
		local buildingModel
		if isRoblox then
			slotModel = Instance.new("Model")
			slotModel.Name = "HabitatSlot_" .. tostring(slotId)
			slotModel.Parent = habsFolder

			buildingModel = Instance.new("Model")
			buildingModel.Name = "BuildingGeometry"
			buildingModel.Parent = slotModel
		else
			slotModel = { Name = "HabitatSlot_" .. tostring(slotId), Children = {} }
			buildingModel = { Name = "BuildingGeometry", Children = {} }
		end

		populateHabitatStructure(buildingModel, slotId, initialType)

		-- Anchor part for BillboardGui & ProximityPrompt
		local anchorPart = makePart({
			Name = "HabitatInteractionAnchor",
			Size = v3(4, 4, 4),
			Position = v3(plotInfo.entrance.x, 2.5, plotInfo.entrance.z),
			Transparency = 1,
			CanCollide = false,
			CanTouch = false,
			CanQuery = true,
		}, slotModel, false)

		local titleLabel, popLabel, fullLabel, fillBar, prompt
		if isRoblox then
			prompt = Instance.new("ProximityPrompt")
			prompt.Name = "HabitatProximityPrompt"
			prompt.ObjectText = "Kurnik #" .. tostring(slotId)
			prompt.ActionText = "Rozbuduj kurnik"
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 16
			prompt.RequiresLineOfSight = false
			prompt:SetAttribute("SlotId", slotId)
			prompt.Parent = anchorPart

			local bb = Instance.new("BillboardGui")
			bb.Name = "HabitatBillboard"
			bb.Adornee = anchorPart
			bb.Size = UDim2.new(0, 230, 0, 95)
			bb.StudsOffset = Vector3.new(0, 12.5, 0)
			bb.MaxDistance = 40
			bb.Parent = anchorPart

			titleLabel = makeOutlinedText(bb, {
				Name = "HabitatTitle",
				Size = UDim2.new(1, 0, 0.34, 0),
				Text = string.format("🏠 Kurnik #%d (%s)", slotId, HABITAT_DISPLAY_NAMES[initialType]),
				TextColor3 = Color3.fromRGB(255, 235, 115),
				StrokeThickness = 2.6,
			})

			-- Progress Bar Background
			local barBg = Instance.new("Frame")
			barBg.Name = "ProgressBarBg"
			barBg.Size = UDim2.new(0.88, 0, 0.24, 0)
			barBg.Position = UDim2.new(0.06, 0, 0.36, 0)
			barBg.BackgroundColor3 = Color3.fromRGB(52, 28, 16)
			barBg.Parent = bb

			local cornerBg = Instance.new("UICorner")
			cornerBg.CornerRadius = UDim.new(0.5, 0)
			cornerBg.Parent = barBg

			local strokeBg = Instance.new("UIStroke")
			strokeBg.Color = Color3.fromRGB(20, 10, 5)
			strokeBg.Thickness = 2.2
			strokeBg.Parent = barBg

			fillBar = Instance.new("Frame")
			fillBar.Name = "Fill"
			fillBar.Size = UDim2.new(0, 0, 1, 0)
			fillBar.BackgroundColor3 = Color3.fromRGB(95, 235, 55)
			fillBar.Parent = barBg

			local cornerFill = Instance.new("UICorner")
			cornerFill.CornerRadius = UDim.new(0.5, 0)
			cornerFill.Parent = fillBar

			popLabel = makeOutlinedText(barBg, {
				Name = "PopulationLabel",
				Size = UDim2.new(1, 0, 1, 0),
				Text = if initialType >= 0 then "0 / 250 🐔" else "Niezbudowany",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				StrokeThickness = 2.0,
			})

			fullLabel = makeOutlinedText(bb, {
				Name = "FullWarningLabel",
				Size = UDim2.new(1, 0, 0.32, 0),
				Position = UDim2.new(0, 0, 0.64, 0),
				Text = "",
				TextColor3 = Color3.fromRGB(255, 75, 75),
				StrokeThickness = 2.8,
			})
		end

		-- Step-On Studded Buy Pad next to the Habitat (Screenshot 1 exact look!)
		local buyPad = createBuyPad(slotModel, {
			name = "BuyPad_Habitat_" .. tostring(slotId),
			padType = "BuyHabitat",
			slotId = slotId,
			pos = plotInfo.padPos,
			padColor = { 95, 235, 45 },
			line1 = string.format("[Kurnik #%d]", slotId),
			line2 = if initialType == -1 then "+Zbuduj Kurnik (250 miejsc)" else "+Ulepsz do Szopy (500 miejsc)",
			line3 = if initialType == -1 then "$100" else "$500",
			line1Color = isRoblox and Color3.fromRGB(255, 130, 245) or nil,
		})
		table.insert(self.buyPads, buyPad)

		self.habitats[slotId] = {
			slotId = slotId,
			slotModel = slotModel,
			buildingModel = buildingModel,
			anchorPart = anchorPart,
			prompt = prompt,
			titleLabel = titleLabel,
			popLabel = popLabel,
			fullLabel = fullLabel,
			fillBar = fillBar,
			buyPad = buyPad,
			currentTypeIndex = initialType,
		}
	end
end

local SILO_POSITIONS = table.freeze({
	[1] = { x = -54, z = 54 },
	[2] = { x = -54, z = 42 },
	[3] = { x = -54, z = 30 },
	[4] = { x = -54, z = 18 },
	[5] = { x = -54, z = 6 },
	[6] = { x = -66, z = 54 },
	[7] = { x = -66, z = 42 },
	[8] = { x = -66, z = 30 },
	[9] = { x = -66, z = 18 },
	[10] = { x = -66, z = 6 },
})

function FarmPlotBuilder:_buildSiloTower(worldFolder)
	for i = 1, 10 do
		local siloPos = SILO_POSITIONS[i]
		local sx, sy, sz = siloPos.x, 0, siloPos.z

		local siloModel
		if isRoblox then
			siloModel = Instance.new("Model")
			siloModel.Name = "SiloTower_" .. tostring(i)
			siloModel.Parent = worldFolder
		else
			siloModel = { Name = "SiloTower_" .. tostring(i), Children = {} }
		end

		-- Red & White Silo Rings (exact style from Screenshot 2!)
		for ring = 1, 7 do
			local ringColor = if ring % 2 == 1 then rgb(235, 55, 65) else rgb(255, 250, 245)
			makePart({
				Name = "SiloStripe_" .. ring,
				Shape = isRoblox and Enum.PartType.Cylinder or nil,
				Size = v3(3.4, 9, 9),
				CFrame = isRoblox and (CFrame.new(sx, sy + (ring - 0.5) * 3.4, sz) * CFrame.Angles(0, 0, math.rad(90))) or nil,
				Position = v3(sx, sy + (ring - 0.5) * 3.4, sz),
				Color = ringColor,
				CanCollide = true,
			}, siloModel, false)
		end

		-- Silo Dome Cap
		makePart({
			Name = "SiloDome",
			Shape = isRoblox and Enum.PartType.Ball or nil,
			Size = v3(9.5, 7.5, 9.5),
			Position = v3(sx, sy + 24.5, sz),
			Color = rgb(105, 58, 30),
		}, siloModel, true)

		-- Digital SurfaceGui Display Board on the front of the Silo facing +X (farm center)
		local displayBoard = makePart({
			Name = "SiloDisplayBoard",
			Size = v3(7.5, 4.0, 0.8),
			Position = v3(sx + 4.8, sy + 7.5, sz),
			CFrame = isRoblox and (CFrame.new(sx + 4.8, sy + 7.5, sz) * CFrame.Angles(0, math.rad(90), 0)) or nil,
			Color = rgb(32, 20, 14),
			CanCollide = false,
		}, siloModel, true)

		local timerLabel
		if isRoblox then
			local sgui = Instance.new("SurfaceGui")
			sgui.Name = "SiloSurfaceGui"
			sgui.Face = Enum.NormalId.Front
			sgui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			sgui.PixelsPerStud = 40
			sgui.Parent = displayBoard

			timerLabel = makeOutlinedText(sgui, {
				Name = "TimerLabel",
				Size = UDim2.new(1, 0, 1, 0),
				Text = string.format("🌾 SILOS #%d\nOFFLINE: 01:00:00\nSTATUS: %s", i, if i == 1 then "AKTYWNY" else "ZABLOKOWANY"),
				TextColor3 = if i == 1 then Color3.fromRGB(95, 255, 110) else Color3.fromRGB(220, 160, 80),
				StrokeThickness = 2.5,
			})
		else
			timerLabel = {
				Name = "TimerLabel",
				Text = string.format("🌾 SILOS #%d\nOFFLINE: 01:00:00\nSTATUS: %s", i, if i == 1 then "AKTYWNY" else "ZABLOKOWANY"),
			}
		end

		self.siloModels[i] = siloModel
		self.siloLabels[i] = timerLabel
		if i == 1 then
			self.siloSurfaceLabel = timerLabel
		end
	end
end

function FarmPlotBuilder:_buildShippingDepot(worldFolder)
	local depotModel
	if isRoblox then
		depotModel = Instance.new("Model")
		depotModel.Name = "ShippingDepot"
		depotModel.Parent = worldFolder
	else
		depotModel = { Name = "ShippingDepot", Children = {} }
	end

	local dx, dy, dz = 50, 0, 44

	-- Wafer & Red-Carpet Loading Dock Platform
	local dockBase = makePart({
		Name = "DepotPlatform",
		Size = v3(24, 1.0, 28),
		Position = v3(dx, dy + 0.4, dz),
		Color = rgb(198, 152, 98),
		StudsTop = true,
		CanCollide = true,
	}, depotModel, false)

	-- Canopy over Depot
	makePart({
		Name = "DepotRoof",
		Size = v3(22, 1.5, 12),
		Position = v3(dx, dy + 10, dz + 7),
		Color = rgb(255, 115, 55),
		StudsTop = true,
	}, depotModel, true)

	-- Cute 3D Delivery Vehicle in Slot 1
	local trikeBody = makePart({
		Name = "Vehicle_Slot1_Body",
		Size = v3(5.5, 3.6, 8.5),
		Position = v3(dx - 5, dy + 2.8, dz - 2),
		Color = rgb(255, 215, 55),
		StudsTop = true,
		CanCollide = true,
	}, depotModel, false)
	self.vehiclesModels[1] = trikeBody

	makePart({
		Name = "Vehicle_Slot1_EggCrate",
		Size = v3(4.5, 2.5, 4.5),
		Position = v3(dx - 5, dy + 5.5, dz - 3.5),
		Color = rgb(255, 250, 240),
		StudsTop = true,
	}, depotModel, true)

	if isRoblox then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "DepotProximityPrompt"
		prompt.ObjectText = "Stacja Transportowa"
		prompt.ActionText = "Flota pojazdów"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 18
		prompt.RequiresLineOfSight = false
		prompt.Parent = dockBase
		self.depotPrompt = prompt

		local bb = Instance.new("BillboardGui")
		bb.Name = "DepotBillboard"
		bb.Adornee = dockBase
		bb.Size = UDim2.new(0, 230, 0, 65)
		bb.StudsOffset = Vector3.new(0, 12, 0)
		bb.MaxDistance = 35
		bb.Parent = dockBase

		makeOutlinedText(bb, {
			Name = "Title",
			Size = UDim2.new(1, 0, 1, 0),
			Text = "🚚 STACJA TRANSPORTU JAJ",
			TextColor3 = Color3.fromRGB(255, 215, 75),
			StrokeThickness = 2.8,
		})
	end

	-- 2+1 Delivery Truck & Animated Gift Parcel (PROD-06)
	local truckModel
	if isRoblox then
		truckModel = Instance.new("Model")
		truckModel.Name = "DeliveryTruck_2Plus1"
		truckModel.Parent = depotModel
	else
		truckModel = { Name = "DeliveryTruck_2Plus1", Children = {} }
	end

	-- Truck Cabin
	makePart({
		Name = "TruckCab",
		Size = v3(6.5, 4.2, 5.5),
		Position = v3(dx + 4, dy + 2.8, dz - 14),
		Color = rgb(255, 95, 45),
		StudsTop = true,
		CanCollide = true,
	}, truckModel, false)

	-- Truck Windshield
	makePart({
		Name = "TruckWindshield",
		Size = v3(5.5, 2.0, 0.4),
		Position = v3(dx + 4, dy + 3.5, dz - 11.2),
		Color = rgb(185, 235, 255),
		CanCollide = false,
	}, truckModel, true)

	-- Truck Cargo Bed
	makePart({
		Name = "TruckCargoBed",
		Size = v3(6.8, 5.0, 8.5),
		Position = v3(dx + 4, dy + 3.2, dz - 20.5),
		Color = rgb(245, 230, 215),
		StudsTop = true,
		CanCollide = true,
	}, truckModel, false)

	-- 2+1 Delivery Parcel on the platform with glowing particles & ProximityPrompt
	local parcelPart = makePart({
		Name = "DeliveryParcel_2Plus1",
		Size = v3(3.2, 3.2, 3.2),
		Position = v3(dx + 4, dy + 2.2, dz - 4),
		Color = rgb(255, 215, 45),
		StudsTop = true,
		CanCollide = true,
	}, depotModel, false)

	local parcelPrompt = nil
	if isRoblox then
		parcelPrompt = Instance.new("ProximityPrompt")
		parcelPrompt.Name = "ClaimOfferPrompt"
		parcelPrompt.ObjectText = "Specjalna Oferta 2+1"
		parcelPrompt.ActionText = "Otwórz Paczkę"
		parcelPrompt.KeyboardKeyCode = Enum.KeyCode.E
		parcelPrompt.HoldDuration = 0
		parcelPrompt.MaxActivationDistance = 18
		parcelPrompt.RequiresLineOfSight = false
		parcelPrompt.Parent = parcelPart

		local cd = Instance.new("ClickDetector")
		cd.MaxActivationDistance = 32
		cd.Parent = parcelPart

		local pbb = Instance.new("BillboardGui")
		pbb.Name = "ParcelBillboard"
		pbb.Adornee = parcelPart
		pbb.Size = UDim2.new(0, 180, 0, 48)
		pbb.StudsOffset = Vector3.new(0, 3.2, 0)
		pbb.AlwaysOnTop = false
		pbb.MaxDistance = 30
		pbb.Parent = parcelPart

		makeOutlinedText(pbb, {
			Name = "ParcelLabel",
			Size = UDim2.new(1, 0, 1, 0),
			Text = "🎁 PACZKA 2+1!\n[NACIŚNIJ E]",
			TextColor3 = Color3.fromRGB(255, 245, 95),
			StrokeThickness = 2.4,
		})
	else
		parcelPrompt = {
			Name = "ClaimOfferPrompt",
			ActionText = "Otwórz Paczkę",
			ObjectText = "Specjalna Oferta 2+1",
		}
	end

	self.deliveryTruckModel = truckModel
	self.deliveryParcelModel = parcelPart
	self.deliveryPrompt = parcelPrompt

	-- Step-On Studded Buy Pads for Vehicles 1 & 2
	local vPad1 = createBuyPad(depotModel, {
		name = "BuyPad_Vehicle_1",
		padType = "BuyVehicle",
		slotId = 1,
		pos = { x = 32, y = 0.35, z = 36 },
		padColor = { 95, 235, 45 },
		line1 = "[Pojazd #1 -> Van]",
		line2 = "+Większy eksport jaj/min",
		line3 = "$1.2K",
	})
	table.insert(self.buyPads, vPad1)

	local vPad2 = createBuyPad(depotModel, {
		name = "BuyPad_Vehicle_2",
		padType = "BuyVehicle",
		slotId = 2,
		pos = { x = 32, y = 0.35, z = 46 },
		padColor = { 95, 235, 45 },
		line1 = "[Pojazd #2 -> Trike]",
		line2 = "+Dodatkowy pojazd floty",
		line3 = "$250",
	})
	table.insert(self.buyPads, vPad2)
end

function FarmPlotBuilder:_buildResearchStall(worldFolder)
	local stallModel
	if isRoblox then
		stallModel = Instance.new("Model")
		stallModel.Name = "ResearchStall"
		stallModel.Parent = worldFolder
	else
		stallModel = { Name = "ResearchStall", Children = {} }
	end

	local rx, ry, rz = -28, 0, 48

	-- Market Stall Counter (like Screenshot 2 red/white stalls!)
	local counter = makePart({
		Name = "ResearchCounter",
		Size = v3(14, 4.2, 6),
		Position = v3(rx, ry + 2.1, rz),
		Color = rgb(135, 78, 42),
		StudsTop = true,
		CanCollide = true,
	}, stallModel, false)

	-- Striped Red-and-White Awning
	for i = 1, 5 do
		makePart({
			Name = "AwningStripe_" .. i,
			Size = v3(2.8, 1.2, 8),
			Position = v3(rx - 5.6 + (i - 1) * 2.8, ry + 8.5, rz),
			Color = if i % 2 == 1 then rgb(235, 55, 65) else rgb(255, 250, 245),
			StudsTop = true,
		}, stallModel, true)
	end

	if isRoblox then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "ResearchProximityPrompt"
		prompt.ObjectText = "Laboratorium Badawcze"
		prompt.ActionText = "Otwórz Badania"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 16
		prompt.RequiresLineOfSight = false
		prompt.Parent = counter
		self.researchPrompt = prompt

		local bb = Instance.new("BillboardGui")
		bb.Name = "ResearchBillboard"
		bb.Adornee = counter
		bb.Size = UDim2.new(0, 230, 0, 65)
		bb.StudsOffset = Vector3.new(0, 9, 0)
		bb.MaxDistance = 35
		bb.Parent = counter

		makeOutlinedText(bb, {
			Name = "Title",
			Size = UDim2.new(1, 0, 1, 0),
			Text = "🔬 BUDYNEK BADAŃ [E]",
			TextColor3 = Color3.fromRGB(115, 235, 255),
			StrokeThickness = 2.8,
		})
	end
end

function FarmPlotBuilder:_buildFarmDecorations(worldFolder)
	local decoFolder
	if isRoblox then
		decoFolder = Instance.new("Folder")
		decoFolder.Name = "Decorations"
		decoFolder.Parent = worldFolder
	else
		decoFolder = { Name = "Decorations", Children = {} }
	end

	-- Cheerful Low-Poly Farm Trees around the edges of the Farm Island
	buildPineTree(decoFolder, -58, 0, -52, 1.1, rgb(72, 198, 52))
	buildPineTree(decoFolder, 58, 0, -52, 1.1, rgb(85, 210, 58))
	buildPineTree(decoFolder, -58, 0, -5, 1.0, rgb(65, 185, 48))
	buildPineTree(decoFolder, 58, 0, -5, 1.0, rgb(92, 215, 65))

	buildRoundTree(decoFolder, -56, 0, -25, rgb(98, 222, 62))
	buildRoundTree(decoFolder, 56, 0, -25, rgb(115, 232, 72))
	buildRoundTree(decoFolder, -56, 0, 22, rgb(255, 165, 205)) -- blossom tree accent
	buildRoundTree(decoFolder, 56, 0, 22, rgb(105, 225, 68))
end

-- ============================================================================
-- Reactive State Update (Updates 3D Billboards, Coop Models & Buy Pads!)
-- ============================================================================

function FarmPlotBuilder:updateFromFarmView(farmView, catalog)
	if type(farmView) ~= "table" then return end

	-- 1. Update 4 Habitats (3D structure tier, Billboard population, progress bar & FULL badge)
	if type(farmView.habitats) == "table" then
		for _, hab in ipairs(farmView.habitats) do
			local slotId = hab.slotId
			local hEntry = self.habitats[slotId]
			if hEntry then
				local hIdx = if hab.habitatIndex ~= nil then hab.habitatIndex else -1
				if hEntry.currentTypeIndex ~= hIdx then
					hEntry.currentTypeIndex = hIdx
					populateHabitatStructure(hEntry.buildingModel, slotId, hIdx)
				end

				local popNum = tonumber(hab.population) or 0
				local capNum = tonumber(hab.capacity) or 0
				local ratio = if capNum > 0 then math.clamp(popNum / capNum, 0, 1) else 0

				if hEntry.titleLabel then
					hEntry.titleLabel.Text = string.format(
						"🏠 Kurnik #%d • %s",
						slotId,
						HABITAT_DISPLAY_NAMES[hIdx] or "Kurnik"
					)
				end
				if hEntry.popLabel then
					if hIdx == -1 then
						hEntry.popLabel.Text = "Kup na płytce obok!"
					else
						hEntry.popLabel.Text = string.format("%s / %s 🐔", formatCompact(popNum), formatCompact(capNum))
					end
				end
				if hEntry.fillBar and isRoblox then
					hEntry.fillBar.Size = UDim2.new(ratio, 0, 1, 0)
					hEntry.fillBar.BackgroundColor3 = if ratio >= 1
						then Color3.fromRGB(255, 85, 85)
						else Color3.fromRGB(95, 235, 55)
				end
				if hEntry.fullLabel then
					hEntry.fullLabel.Text = if (capNum > 0 and popNum >= capNum) then "⚠️ PEŁNY! (FULL)" else ""
				end

				-- Update Habitat Step-On Buy Pad text
				local bp = hEntry.buyPad
				if bp then
					if hIdx == -1 then
						bp.line1Label.Text = string.format("[Kurnik #%d -> Kurniczek]", slotId)
						bp.line2Label.Text = "+250 Miejsc dla kurcząt"
						local price = if catalog and catalog.habitatPrice then catalog.habitatPrice(0, 0) else 100
						bp.line3Label.Text = "$" .. formatCompact(price)
					elseif hIdx == 0 then
						bp.line1Label.Text = string.format("[Kurnik #%d -> Szopa]", slotId)
						bp.line2Label.Text = "+500 Miejsc dla kurcząt"
						local price = if catalog and catalog.habitatPrice then catalog.habitatPrice(1, 0) else 500
						bp.line3Label.Text = "$" .. formatCompact(price)
					else
						bp.line1Label.Text = string.format("[Kurnik #%d • MAX]", slotId)
						bp.line2Label.Text = "Maksymalny poziom!"
						bp.line3Label.Text = "MAX"
					end
				end
			end
		end
	end

	-- 3. Update Egg Upgrade Pedestals (Billboards)
	if type(self.eggUpgradeBillboards) == "table" and farmView.eggIndex ~= nil then
		local curEggIdx = farmView.eggIndex
		local nextEggIdx = curEggIdx + 1
		local curEgg = FvSe.EGGS[curEggIdx]
		local nextEgg = FvSe.EGGS[nextEggIdx]
		local curName = if curEgg then curEgg.name else ("Egg #" .. tostring(curEggIdx))

		for _, entry in ipairs(self.eggUpgradeBillboards) do
			if nextEgg then
				local nextName = nextEgg.name
				local reqFV = nextEgg.advanceFV
				if entry.curLabel then
					entry.curLabel.Text = string.format("🥚 Aktualne: %s", curName)
				end
				if entry.nextLabel then
					entry.nextLabel.Text = string.format("✨ Następne: %s", nextName)
				end
				if entry.reqLabel then
					entry.reqLabel.Text = string.format("Wymagane FV: $%s", formatCompact(reqFV))
				end
			else
				if entry.curLabel then
					entry.curLabel.Text = string.format("🥚 Aktualne: %s (MAX)", curName)
				end
				if entry.nextLabel then
					entry.nextLabel.Text = "🎉 Osiągnięto Oświecenie (MAX)!"
				end
				if entry.reqLabel then
					entry.reqLabel.Text = "Brak dalszych jaj"
				end
			end
		end
	end

	-- 4. Update Silos Display (PROD-06)
	local silosOwned = 1
	if farmView and (farmView.siloOwned or farmView.silosOwned) then
		silosOwned = farmView.siloOwned or farmView.silosOwned
	end

	local awaySecRemaining = 0
	if timelineView and timelineView.awayRemainingSeconds then
		awaySecRemaining = timelineView.awayRemainingSeconds
	elseif farmView and farmView.awayRemainingSeconds then
		awaySecRemaining = farmView.awayRemainingSeconds
	else
		awaySecRemaining = silosOwned * 3600
	end

	local hours = math.floor(awaySecRemaining / 3600)
	local mins = math.floor((awaySecRemaining % 3600) / 60)
	local secs = math.floor(awaySecRemaining % 60)
	local timeStr = string.format("%02d:%02d:%02d", hours, mins, secs)

	for i, lbl in ipairs(self.siloLabels or {}) do
		if i <= silosOwned then
			lbl.Text = string.format("🌾 SILOS #%d\nOFFLINE: %s\nSTATUS: AKTYWNY", i, timeStr)
			if isRoblox and typeof(lbl) == "Instance" then
				lbl.TextColor3 = Color3.fromRGB(95, 255, 110)
			end
		else
			local req = if i > 2 then "(Wymaga Pro Permit)" else "(Do kupienia)"
			lbl.Text = string.format("🔒 SILOS #%d\nZABLOKOWANY\n%s", i, req)
			if isRoblox and typeof(lbl) == "Instance" then
				lbl.TextColor3 = Color3.fromRGB(220, 160, 80)
			end
		end
	end
end

function FarmPlotBuilder:getPressurePlate()
	return self.pressurePlate
end

function FarmPlotBuilder:getEggUpgradePedestal()
	return self.eggUpgradePedestal
end

function FarmPlotBuilder:getEggUpgradePrompt()
	return self.eggUpgradePrompt
end

function FarmPlotBuilder:getBuyPads()
	return self.buyPads
end

function FarmPlotBuilder:getHabitats()
	return self.habitats
end

function FarmPlotBuilder:getSilos()
	return self.siloModels
end

function FarmPlotBuilder:getSiloLabels()
	return self.siloLabels
end

function FarmPlotBuilder:getDeliveryTruck()
	return self.deliveryTruckModel
end

function FarmPlotBuilder:getDeliveryParcel()
	return self.deliveryParcelModel
end

function FarmPlotBuilder:getDeliveryPrompt()
	return self.deliveryPrompt
end

function FarmPlotBuilder:_buildPetIncubatorStation(worldFolder)
	local stationModel
	if isRoblox then
		stationModel = Instance.new("Model")
		stationModel.Name = "PetIncubatorStation"
		stationModel.Parent = worldFolder
	else
		stationModel = { Name = "PetIncubatorStation", Children = {} }
		if worldFolder and worldFolder.Children then
			table.insert(worldFolder.Children, stationModel)
		end
	end

	local ix, iy, iz = FarmPlotBuilder.INCUBATOR_STATION_POS.x, FarmPlotBuilder.INCUBATOR_STATION_POS.y, FarmPlotBuilder.INCUBATOR_STATION_POS.z

	-- 1. Stepped pedestal
	local pedestal = makePart({
		Name = "IncubatorPedestal",
		Size = v3(8, 2.8, 8),
		Position = v3(ix, iy + 1.4, iz),
		Color = rgb(235, 140, 190),
		StudsTop = true,
		CanCollide = true,
	}, stationModel, false)

	local pedestalRim = makePart({
		Name = "IncubatorRim",
		Size = v3(7.2, 0.6, 7.2),
		Position = v3(ix, iy + 3.0, iz),
		Color = rgb(255, 215, 65),
		StudsTop = true,
		CanCollide = true,
	}, stationModel, false)

	-- 2. Four Corner Support Pillars
	local pillarOffsets = {
		{ x = -3.2, z = -3.2 },
		{ x = 3.2, z = -3.2 },
		{ x = 3.2, z = 3.2 },
		{ x = -3.2, z = 3.2 },
	}
	for i, off in ipairs(pillarOffsets) do
		makePart({
			Name = "Pillar_" .. tostring(i),
			Size = v3(0.8, 6.5, 0.8),
			Position = v3(ix + off.x, iy + 3.2 + 3.25, iz + off.z),
			Color = if i % 2 == 1 then rgb(255, 65, 85) else rgb(255, 255, 255),
			CanCollide = false,
		}, stationModel, false)
	end

	-- 3. Transparent Glass Chamber
	local glassChamber = makePart({
		Name = "GlassChamber",
		Size = v3(5.6, 6.2, 5.6),
		Position = v3(ix, iy + 3.2 + 3.1, iz),
		Color = rgb(220, 245, 255),
		Transparency = 0.65,
		CanCollide = false,
	}, stationModel, false)

	-- 4. Golden Roof Topper
	local roofTopper = makePart({
		Name = "RoofTopper",
		Size = v3(7.4, 1.2, 7.4),
		Position = v3(ix, iy + 3.2 + 6.6, iz),
		Color = rgb(255, 215, 65),
		StudsTop = true,
		CanCollide = true,
	}, stationModel, false)

	-- 5. Floating / Neon Incubator Egg inside
	local eggPart = makePart({
		Name = "IncubatorEgg",
		Size = v3(2.6, 3.6, 2.6),
		Position = v3(ix, iy + 3.2 + 3.2, iz),
		Color = rgb(255, 225, 75),
		CanCollide = false,
	}, stationModel, false)

	-- 6. Floating BillboardGui & ProximityPrompt
	local prompt
	if isRoblox then
		local bb = Instance.new("BillboardGui")
		bb.Name = "IncubatorBillboard"
		bb.Size = UDim2.new(0, 240, 0, 75)
		bb.StudsOffset = Vector3.new(0, 8.5, 0)
		bb.AlwaysOnTop = false
		bb.MaxDistance = 35
		bb.Adornee = pedestal
		bb.Parent = pedestal

		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, 0, 0.55, 0)
		title.Position = UDim2.new(0, 0, 0, 0)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.FredokaOne
		title.TextScaled = true
		title.Text = "🐣 STACJA INKUBACJI PETÓW"
		title.TextColor3 = Color3.fromRGB(255, 235, 110)
		title.Parent = bb

		local titleStroke = Instance.new("UIStroke")
		titleStroke.Thickness = 2.5
		titleStroke.Color = Color3.fromRGB(40, 20, 10)
		titleStroke.Parent = title

		local sub = Instance.new("TextLabel")
		sub.Size = UDim2.new(1, 0, 0.45, 0)
		sub.Position = UDim2.new(0, 0, 0.55, 0)
		sub.BackgroundTransparency = 1
		sub.Font = Enum.Font.FredokaOne
		sub.TextScaled = true
		sub.Text = "[E] Wykluj Nowego Peta (100 GE)"
		sub.TextColor3 = Color3.fromRGB(255, 255, 255)
		sub.Parent = bb

		local subStroke = Instance.new("UIStroke")
		subStroke.Thickness = 2
		subStroke.Color = Color3.fromRGB(40, 20, 10)
		subStroke.Parent = sub

		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "IncubatorProximityPrompt"
		prompt.ObjectText = "Stacja Inkubacji Petów"
		prompt.ActionText = "Inkubuj Jajo"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.MaxActivationDistance = 15
		prompt.HoldDuration = 0
		prompt.Parent = pedestal
	else
		prompt = {
			Name = "IncubatorProximityPrompt",
			ObjectText = "Stacja Inkubacji Petów",
			ActionText = "Inkubuj Jajo",
			KeyboardKeyCode = "E",
			MaxActivationDistance = 15,
			HoldDuration = 0,
			Parent = pedestal,
		}
		if pedestal.Children then
			table.insert(pedestal.Children, prompt)
		end
	end

	self.incubatorStationModel = stationModel
	self.incubatorPrompt = prompt
	self.incubatorEgg = eggPart

	return stationModel
end

function FarmPlotBuilder:getIncubatorStation()
	return self.incubatorStationModel
end

function FarmPlotBuilder:getIncubatorPrompt()
	return self.incubatorPrompt
end

function FarmPlotBuilder:getIncubatorEgg()
	return self.incubatorEgg
end

return table.freeze(FarmPlotBuilder)
