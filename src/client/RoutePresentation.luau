--!nocheck
-- RoutePresentation for HatchTheEgg (IMP-13 & VIS-05).
-- Visual presentation of the 4 habitat plots, hatchery zone, cute 3D kawaii chicken models,
-- arrival particle puffs, and 3D flying drones based on PRE-03 (docs/35_pre03_routes_and_arrivals.md).
--
-- CRITICAL ARCHITECTURAL INVARIANT:
-- The presentation layer is strictly a one-way consumer of state.
-- Removing, destroying, slowing down, or colliding chicken/drone models in 3D
-- DOES NOT affect the server authoritative population, running chickens in transit,
-- egg laying rate, or player cash balances!

local SCENE_VERSION = "CANONICAL_V1"
local ROUTE_VERSION = 1
local DEFAULT_SPEED = 25.0 -- studs per second
-- Representative visuals are cosmetic and must stay bounded: at most this many live models
-- and at most this many model spawns per second across every group, plus a bounded window of
-- retained completed group ids.
local DEFAULT_MAX_ACTIVE_VISUALS = 32
local DEFAULT_MAX_VISUAL_SPAWNS_PER_SECOND = 8
local DEFAULT_MAX_COMPLETED_HISTORY = 64

local isRoblox = (typeof(Instance) == "table" and type(Instance.new) == "function")

-- ============================================================================
-- Geometry and Vector Helpers
-- Compatible with both Roblox Vector3 and pure Lune tables { x, y, z }
-- ============================================================================

local function createPoint(x: number, y: number, z: number)
	return { x = x, y = y, z = z, X = x, Y = y, Z = z }
end

local function getCoords(pt)
	if type(pt) == "table" or type(pt) == "userdata" then
		local x = pt.x or pt.X or 0
		local y = pt.y or pt.Y or 0
		local z = pt.z or pt.Z or 0
		return x, y, z
	end
	return 0, 0, 0
end

local function pointDistance(p1, p2)
	local x1, y1, z1 = getCoords(p1)
	local x2, y2, z2 = getCoords(p2)
	local dx = x2 - x1
	local dy = y2 - y1
	local dz = z2 - z1
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function lerpPoint(p1, p2, alpha: number)
	local x1, y1, z1 = getCoords(p1)
	local x2, y2, z2 = getCoords(p2)
	local x = x1 + (x2 - x1) * alpha
	local y = y1 + (y2 - y1) * alpha
	local z = z1 + (z2 - z1) * alpha
	return createPoint(x, y, z)
end

local function applyModelPosition(model, pt, lookAtPt, hopY, waddleAngle)
	if model == nil then return end
	if type(model) == "table" and model.destroyed then return end

	local x, y, z = getCoords(pt)

	-- If model has custom setPosition method (mock)
	if type(model) == "table" and type(model.setPosition) == "function" then
		model:setPosition(pt)
		return
	end

	-- Roblox Studio environment
	if isRoblox and typeof(model) == "Instance" then
		local vy = y + 0.85 + (hopY or 0)
		local v3 = Vector3.new(x, vy, z)
		local targetCF = CFrame.new(v3)
		if lookAtPt then
			local lx, _, lz = getCoords(lookAtPt)
			local lookV = Vector3.new(lx, vy, lz)
			if (lookV - v3).Magnitude > 0.05 then
				targetCF = CFrame.lookAt(v3, lookV)
			end
		end
		if waddleAngle then
			targetCF = targetCF * CFrame.Angles(0, 0, waddleAngle)
		end

		pcall(function()
			if model:IsA("Model") then
				model:PivotTo(targetCF)
			elseif model:IsA("BasePart") then
				model.CFrame = targetCF
			end
		end)
		return
	end

	-- Pure Lune environment / table mock
	local posObj = createPoint(x, y, z)
	model.position = posObj
	model.Position = posObj
end

local function destroyModel(model)
	if model == nil then return end
	if typeof(model) == "Instance" then
		pcall(function() model:Destroy() end)
		return
	end
	if type(model) == "table" then
		if type(model.Destroy) == "function" then
			pcall(function() model:Destroy() end)
		elseif type(model.destroy) == "function" then
			pcall(function() model:destroy() end)
		end
		model.destroyed = true
	end
end

-- ============================================================================
-- 3D Chicken Model & Arrival Particle Puff (Roblox Studio)
-- ============================================================================

local CHICKEN_PALETTE = table.freeze({
	{ 255, 248, 235 }, -- Cream White
	{ 255, 232, 95 },  -- Sunny Chick Yellow
	{ 255, 195, 225 }, -- Strawberry Milk Pink
	{ 195, 238, 255 }, -- Soft Sky Blue
})

local function makeChickenSubPart(parent, name, size, offsetCF, color, baseCF)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.CFrame = baseCF * offsetCF
	p.Parent = parent

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = parent.PrimaryPart
	weld.Part1 = p
	weld.Parent = p
	p.Anchored = false
	return p
end

local function createDefaultModel(groupId, index, startPos, container, chickenTemplate)
	if chickenTemplate ~= nil and typeof(chickenTemplate) == "Instance" then
		local clone = chickenTemplate:Clone()
		clone.Name = "Chicken_" .. tostring(groupId) .. "_" .. tostring(index)
		applyModelPosition(clone, startPos)
		if container ~= nil then
			clone.Parent = container
		end
		return clone
	end

	-- Roblox Studio: Build multi-part 3D Kawaii Cube Chicken!
	if isRoblox then
		local model = Instance.new("Model")
		model.Name = "Chicken_" .. tostring(groupId) .. "_" .. tostring(index)

		local sx, sy, sz = getCoords(startPos)
		local baseCF = CFrame.new(sx, sy + 0.85, sz)
		local pal = CHICKEN_PALETTE[((index - 1) % #CHICKEN_PALETTE) + 1]
		local bodyColor = Color3.fromRGB(pal[1], pal[2], pal[3])

		-- Chubby Cube Body (PrimaryPart)
		local body = Instance.new("Part")
		body.Name = "Body"
		body.Size = Vector3.new(1.45, 1.4, 1.65)
		body.Color = bodyColor
		body.Material = Enum.Material.SmoothPlastic
		body.TopSurface = Enum.SurfaceType.Studs
		body.BottomSurface = Enum.SurfaceType.Smooth
		body.Anchored = true
		body.CanCollide = false
		body.CanTouch = false
		body.CanQuery = false
		body.CFrame = baseCF
		body.Parent = model
		model.PrimaryPart = body

		-- Red Comb on Head (Grzebień)
		makeChickenSubPart(
			model,
			"Comb",
			Vector3.new(0.28, 0.45, 0.78),
			CFrame.new(0, 0.88, -0.15),
			Color3.fromRGB(255, 65, 85),
			baseCF
		)

		-- Orange Beak (Dziób)
		makeChickenSubPart(
			model,
			"Beak",
			Vector3.new(0.42, 0.28, 0.45),
			CFrame.new(0, 0.12, -0.95),
			Color3.fromRGB(255, 165, 35),
			baseCF
		)

		-- Red Wattle under Beak
		makeChickenSubPart(
			model,
			"Wattle",
			Vector3.new(0.24, 0.28, 0.24),
			CFrame.new(0, -0.14, -0.88),
			Color3.fromRGB(245, 55, 75),
			baseCF
		)

		-- Cute Left & Right Eyes
		makeChickenSubPart(
			model,
			"EyeLeft",
			Vector3.new(0.18, 0.24, 0.12),
			CFrame.new(-0.36, 0.32, -0.82),
			Color3.fromRGB(25, 20, 20),
			baseCF
		)
		makeChickenSubPart(
			model,
			"EyeRight",
			Vector3.new(0.18, 0.24, 0.12),
			CFrame.new(0.36, 0.32, -0.82),
			Color3.fromRGB(25, 20, 20),
			baseCF
		)

		-- Plump Side Wings
		makeChickenSubPart(
			model,
			"Wings",
			Vector3.new(1.82, 0.58, 0.92),
			CFrame.new(0, 0.0, 0.05),
			bodyColor,
			baseCF
		)

		-- Cute Tail Feathers
		makeChickenSubPart(
			model,
			"Tail",
			Vector3.new(0.55, 0.55, 0.42),
			CFrame.new(0, 0.35, 0.88),
			bodyColor,
			baseCF
		)

		if container ~= nil then
			model.Parent = container
		end
		return model
	end

	-- Pure Lune mock model
	local mock = {
		id = tostring(groupId) .. "_" .. tostring(index),
		position = startPos,
		Position = startPos,
		destroyed = false,
		destroy = function(self)
			self.destroyed = true
		end,
		Destroy = function(self)
			self.destroyed = true
		end,
	}
	return mock
end

local function spawnArrivalPuff(pos, container)
	if not isRoblox or container == nil then return end
	pcall(function()
		local x, y, z = getCoords(pos)
		local puffPart = Instance.new("Part")
		puffPart.Name = "ArrivalPuff"
		puffPart.Shape = Enum.PartType.Ball
		puffPart.Size = Vector3.new(2.2, 2.2, 2.2)
		puffPart.Position = Vector3.new(x, y + 1.5, z)
		puffPart.Color = Color3.fromRGB(255, 235, 145)
		puffPart.Material = Enum.Material.Neon
		puffPart.Transparency = 0.25
		puffPart.Anchored = true
		puffPart.CanCollide = false
		puffPart.CanTouch = false
		puffPart.CanQuery = false
		puffPart.Parent = container

		local pe = Instance.new("ParticleEmitter")
		pe.Color = ColorSequence.new(Color3.fromRGB(255, 145, 215), Color3.fromRGB(255, 245, 115))
		pe.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.8),
			NumberSequenceKeypoint.new(1, 0),
		})
		pe.Lifetime = NumberRange.new(0.25, 0.45)
		pe.Speed = NumberRange.new(6, 12)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.Rate = 0
		pe.Parent = puffPart
		pe:Emit(10)

		task.delay(0.45, function()
			if puffPart and puffPart.Parent then
				puffPart:Destroy()
			end
		end)
	end)
end

-- ============================================================================
-- Canonical Scene Layout and Routes Geometry
-- ============================================================================

local HATCHERY_ZONE = table.freeze({
	center = createPoint(0, 0, 55),
	size = createPoint(20, 8, 15),
	spawnPoint = createPoint(0, 0, 45),
})

local HABITAT_PLOTS = table.freeze({
	[1] = table.freeze({
		slotId = 1,
		name = "Habitat_Slot_1",
		description = "Back-Left Habitat Plot",
		center = createPoint(-35, 0, -35),
		size = createPoint(24, 12, 24),
		entrance = createPoint(-30, 0, -30),
	}),
	[2] = table.freeze({
		slotId = 2,
		name = "Habitat_Slot_2",
		description = "Back-Right Habitat Plot",
		center = createPoint(35, 0, -35),
		size = createPoint(24, 12, 24),
		entrance = createPoint(30, 0, -30),
	}),
	[3] = table.freeze({
		slotId = 3,
		name = "Habitat_Slot_3",
		description = "Front-Left Habitat Plot",
		center = createPoint(-35, 0, 15),
		size = createPoint(24, 12, 24),
		entrance = createPoint(-30, 0, 10),
	}),
	[4] = table.freeze({
		slotId = 4,
		name = "Habitat_Slot_4",
		description = "Front-Right Habitat Plot",
		center = createPoint(35, 0, 15),
		size = createPoint(24, 12, 24),
		entrance = createPoint(30, 0, 10),
	}),
})

local function buildRoute(slotId: number, waypoints: { any }, speedProfile: { number }?, baseSpeed: number?)
	local defaultSpd = baseSpeed or DEFAULT_SPEED
	local segments = {}
	local totalLength = 0
	local totalDuration = 0

	for i = 1, #waypoints - 1 do
		local fromPt = waypoints[i]
		local toPt = waypoints[i + 1]
		local segLen = pointDistance(fromPt, toPt)
		assert(segLen > 0, "SEGMENT_LENGTH_MUST_BE_POSITIVE")

		local segSpeed = if speedProfile and speedProfile[i] then speedProfile[i] else defaultSpd
		assert(segSpeed > 0, "SEGMENT_SPEED_MUST_BE_POSITIVE")

		local segDuration = segLen / segSpeed
		local startTime = totalDuration
		local endTime = totalDuration + segDuration

		table.insert(segments, table.freeze({
			index = i,
			from = fromPt,
			to = toPt,
			length = segLen,
			speed = segSpeed,
			duration = segDuration,
			startTime = startTime,
			endTime = endTime,
		}))

		totalLength += segLen
		totalDuration += segDuration
	end

	return table.freeze({
		slotId = slotId,
		routeVersion = ROUTE_VERSION,
		sceneVersion = SCENE_VERSION,
		waypoints = table.freeze(waypoints),
		segments = table.freeze(segments),
		totalLength = totalLength,
		travelDuration = totalDuration,
	})
end

local function generateCanonicalRoutes(baseSpeed: number?)
	local spd = baseSpeed or DEFAULT_SPEED
	local routes = {}

	-- Slot 1 (Back-Left): Hatchery -> South road -> Crossroads -> NW branch -> Coop 1
	routes[1] = buildRoute(1, {
		createPoint(0, 0, 45),
		createPoint(0, 0, 25),
		createPoint(0, 0, -5),
		createPoint(-15, 0, -20),
		createPoint(-30, 0, -30),
	}, nil, spd)

	-- Slot 2 (Back-Right): Hatchery -> South road -> Crossroads -> NE branch -> Coop 2
	routes[2] = buildRoute(2, {
		createPoint(0, 0, 45),
		createPoint(0, 0, 25),
		createPoint(0, 0, -5),
		createPoint(15, 0, -20),
		createPoint(30, 0, -30),
	}, nil, spd)

	-- Slot 3 (Front-Left): Hatchery -> South road -> SW branch -> Coop 3
	routes[3] = buildRoute(3, {
		createPoint(0, 0, 45),
		createPoint(0, 0, 25),
		createPoint(-15, 0, 20),
		createPoint(-30, 0, 10),
	}, nil, spd)

	-- Slot 4 (Front-Right): Hatchery -> South road -> SE branch -> Coop 4
	routes[4] = buildRoute(4, {
		createPoint(0, 0, 45),
		createPoint(0, 0, 25),
		createPoint(15, 0, 20),
		createPoint(30, 0, 10),
	}, nil, spd)

	return table.freeze(routes)
end

local CANONICAL_ROUTES = generateCanonicalRoutes()

-- ============================================================================
-- Interpolation Helper
-- ============================================================================

local function interpolateRoutePosition(route, progress: number)
	assert(route ~= nil, "ROUTE_REQUIRED")
	local waypoints = route.waypoints
	local n = #waypoints
	if n == 0 then
		return createPoint(0, 0, 0)
	end
	if n == 1 then
		return waypoints[1]
	end

	local p = math.clamp(progress, 0, 1)
	if p <= 0 then
		return waypoints[1]
	elseif p >= 1 then
		return waypoints[n]
	end

	local t = p * route.travelDuration
	local segments = route.segments
	for _, seg in segments do
		if t <= seg.endTime or seg.index == #segments then
			local segAlpha = if seg.duration > 0 then math.clamp((t - seg.startTime) / seg.duration, 0, 1) else 1
			return lerpPoint(seg.from, seg.to, segAlpha)
		end
	end

	return waypoints[n]
end

-- ============================================================================
-- RoutePresentation Class
-- ============================================================================

local RoutePresentation = {}
RoutePresentation.__index = RoutePresentation

RoutePresentation.SCENE_VERSION = SCENE_VERSION
RoutePresentation.ROUTE_VERSION = ROUTE_VERSION
RoutePresentation.DEFAULT_SPEED = DEFAULT_SPEED
RoutePresentation.HATCHERY_ZONE = HATCHERY_ZONE
RoutePresentation.HABITAT_PLOTS = HABITAT_PLOTS
RoutePresentation.CANONICAL_ROUTES = CANONICAL_ROUTES

-- Static helper methods
function RoutePresentation.getRoute(slotId: number)
	assert(type(slotId) == "number" and slotId >= 1 and slotId <= 4, "INVALID_SLOT_ID: " .. tostring(slotId))
	return CANONICAL_ROUTES[slotId]
end

function RoutePresentation.getAllRoutes()
	return CANONICAL_ROUTES
end

function RoutePresentation.getHatcheryZone()
	return HATCHERY_ZONE
end

function RoutePresentation.getHabitatPlot(slotId: number)
	assert(type(slotId) == "number" and slotId >= 1 and slotId <= 4, "INVALID_SLOT_ID: " .. tostring(slotId))
	return HABITAT_PLOTS[slotId]
end

function RoutePresentation.getAllHabitatPlots()
	return HABITAT_PLOTS
end

function RoutePresentation.getSceneVersion()
	return SCENE_VERSION
end

function RoutePresentation.getRouteVersion()
	return ROUTE_VERSION
end

function RoutePresentation.pointDistance(p1, p2)
	return pointDistance(p1, p2)
end

function RoutePresentation.lerpPoint(p1, p2, alpha: number)
	return lerpPoint(p1, p2, alpha)
end

function RoutePresentation.interpolatePosition(slotId: number, progress: number)
	local route = RoutePresentation.getRoute(slotId)
	return interpolateRoutePosition(route, progress)
end

-- Constructor
function RoutePresentation.new(deps)
	local d = deps or {}
	local container = if typeof(d) == "Instance" then d elseif type(d) == "table" then (d.container or d.modelsContainer) else nil
	local baseSpeed = if type(d) == "table" then (d.baseSpeed or DEFAULT_SPEED) else DEFAULT_SPEED
	local routes = if type(d) == "table" and d.routes then d.routes elseif baseSpeed == DEFAULT_SPEED then CANONICAL_ROUTES else generateCanonicalRoutes(baseSpeed)

	local self = setmetatable({
		baseSpeed = baseSpeed,
		routes = routes,
		maxVisualsPerGroup = d.maxVisualsPerGroup or 5,
		maxActiveVisuals = d.maxActiveVisuals or DEFAULT_MAX_ACTIVE_VISUALS,
		maxSpawnsPerSecond = d.maxSpawnsPerSecond or DEFAULT_MAX_VISUAL_SPAWNS_PER_SECOND,
		maxCompletedHistory = d.maxCompletedHistory or DEFAULT_MAX_COMPLETED_HISTORY,
		modelFactory = d.modelFactory,
		chickenTemplate = d.chickenTemplate,
		container = container,
		clientStateStore = d.clientStateStore,
		_activeGroups = {},
		_completedGroups = {},
		_completedOrder = {},
		_activeVisualCount = 0,
		_spawnBudget = nil,
		_spawnBudgetMs = nil,
		_activeDrones = {},
		_listeners = {},
	}, RoutePresentation)

	return self
end

-- ============================================================================
-- Representative Visual Budget (global model cap, spawn-rate cap, bounded history)
-- ============================================================================

-- Never keep more than maxActiveVisuals live models and never create more than
-- maxSpawnsPerSecond models per second, counted over every group. The budget only limits
-- cosmetic models: group lifecycle, reservations and authoritative state stay untouched.
function RoutePresentation:_consumeVisualBudget(wanted: number, nowMs: number)
	local modelBudget = math.max(0, self.maxActiveVisuals - self._activeVisualCount)
	if self._spawnBudgetMs == nil then
		self._spawnBudgetMs = nowMs
		self._spawnBudget = self.maxSpawnsPerSecond
	else
		local elapsedSeconds = math.max(0, (nowMs - self._spawnBudgetMs) / 1000)
		if elapsedSeconds > 0 then
			self._spawnBudget = math.min(
				self.maxSpawnsPerSecond,
				(self._spawnBudget or 0) + elapsedSeconds * self.maxSpawnsPerSecond
			)
			self._spawnBudgetMs = nowMs
		end
	end
	local granted = math.min(wanted, modelBudget, math.floor(self._spawnBudget or 0))
	self._spawnBudget = math.max(0, (self._spawnBudget or 0) - granted)
	return granted
end

-- Completed ids are retained only inside a bounded recent-history window.
function RoutePresentation:_markCompleted(groupId: any)
	if self._completedGroups[groupId] == true then return end
	self._completedGroups[groupId] = true
	table.insert(self._completedOrder, groupId)
	while #self._completedOrder > self.maxCompletedHistory do
		local oldest = table.remove(self._completedOrder, 1)
		if oldest ~= nil then
			self._completedGroups[oldest] = nil
		end
	end
end

function RoutePresentation:_forgetCompletion(groupId: any)
	self._completedGroups[groupId] = nil
	local index = table.find(self._completedOrder, groupId)
	if index ~= nil then
		table.remove(self._completedOrder, index)
	end
end

-- ============================================================================
-- Lifecycle and Route Methods
-- ============================================================================

function RoutePresentation:getRouteForSlot(slotId: number)
	assert(type(slotId) == "number" and slotId >= 1 and slotId <= 4, "INVALID_SLOT_ID: " .. tostring(slotId))
	return self.routes[slotId]
end

function RoutePresentation:interpolateRoutePosition(slotId: number, progress: number)
	local route = self:getRouteForSlot(slotId)
	return interpolateRoutePosition(route, progress)
end

-- ============================================================================
-- Chicken Group Spawning and Lifecycle
-- ============================================================================

function RoutePresentation:spawnGroup(groupId: any, count: any, targetSlotId: number, startInstantMs: number, travelDurationSeconds: number?)
	assert(groupId ~= nil, "GROUP_ID_REQUIRED")
	assert(type(targetSlotId) == "number" and targetSlotId >= 1 and targetSlotId <= 4, "INVALID_TARGET_SLOT: " .. tostring(targetSlotId))
	assert(type(startInstantMs) == "number", "START_INSTANT_MS_REQUIRED")

	local numCount = tonumber(count) or 1
	assert(numCount > 0, "COUNT_MUST_BE_POSITIVE")

	local route = self:getRouteForSlot(targetSlotId)
	local durationSec = if travelDurationSeconds ~= nil and travelDurationSeconds > 0
		then travelDurationSeconds
		else route.travelDuration

	-- Clean up existing group if same groupId is spawned again
	if self._activeGroups[groupId] ~= nil then
		self:removeGroup(groupId)
	end

	local startPos = route.waypoints[1]
	local nextPos = route.waypoints[2] or startPos
	local visualCount = math.clamp(numCount, 1, self.maxVisualsPerGroup)
	-- The global representative-visual budget may reduce (even to zero) the models of this
	-- group; the group itself still exists so lifecycle, tests and callers stay compatible.
	visualCount = self:_consumeVisualBudget(visualCount, startInstantMs)
	local models = {}

	for i = 1, visualCount do
		local model
		if type(self.modelFactory) == "function" then
			model = self.modelFactory(groupId, i, numCount, targetSlotId)
			applyModelPosition(model, startPos)
		else
			model = createDefaultModel(groupId, i, startPos, self.container, self.chickenTemplate)
			applyModelPosition(model, startPos, nextPos, 0, 0)
		end
		table.insert(models, model)
	end

	local group = {
		groupId = groupId,
		count = numCount,
		targetSlotId = targetSlotId,
		startInstantMs = startInstantMs,
		travelDurationSeconds = durationSec,
		models = models,
		currentProgress = 0,
		currentPosition = startPos,
		isCompleted = false,
		isDestroyed = false,
	}

	self._activeVisualCount += #models
	self._activeGroups[groupId] = group
	self:_emit("groupSpawned", groupId, group)
	return group
end

-- ============================================================================
-- Representative Cosmetic Stream
-- ============================================================================

-- A stream group visualises an authoritative in-transit count. It is cosmetic: it never
-- sends arrivals, never grants population and is cleared as a unit when the stream ends.
function RoutePresentation:spawnStreamGroup(groupId: any, count: any, targetSlotId: number, startInstantMs: number, travelDurationSeconds: number?)
	local group = self:spawnGroup(groupId, count, targetSlotId, startInstantMs, travelDurationSeconds)
	if group ~= nil then
		group.isStreamGroup = true
	end
	return group
end

function RoutePresentation:clearStreamGroups()
	local ids = {}
	for groupId, group in self._activeGroups do
		if group.isStreamGroup == true then
			table.insert(ids, groupId)
		end
	end
	local removed = 0
	for _, groupId in ipairs(ids) do
		if self:removeGroup(groupId) then removed += 1 end
		self:_forgetCompletion(groupId)
	end
	return removed
end

function RoutePresentation:getStreamGroupCount()
	local count = 0
	for _, group in self._activeGroups do
		if group.isStreamGroup == true then count += 1 end
	end
	return count
end

function RoutePresentation:getActiveVisualCount()
	return self._activeVisualCount
end

function RoutePresentation:getCompletedHistoryCount()
	return #self._completedOrder
end

function RoutePresentation:update(nowMs: number)
	assert(type(nowMs) == "number", "NOW_MS_REQUIRED")

	local arrivedGroups = {}

	for groupId, group in self._activeGroups do
		local elapsedMs = nowMs - group.startInstantMs
		local durationMs = group.travelDurationSeconds * 1000
		local progress = if durationMs > 0 then math.clamp(elapsedMs / durationMs, 0, 1) else 1

		group.currentProgress = progress
		local pos = self:interpolateRoutePosition(group.targetSlotId, progress)
		local lookAheadPos = self:interpolateRoutePosition(group.targetSlotId, math.min(1, progress + 0.05))
		group.currentPosition = pos

		-- Update visual model positions (if models are still alive and valid)
		local numModels = #group.models
		for idx, model in ipairs(group.models) do
			local isDestroyed = (type(model) == "table" and model.destroyed == true)
			if model ~= nil and not isDestroyed then
				local modelPos = pos
				if numModels > 1 then
					local spreadOffset = (idx - (numModels + 1) / 2) * 0.75
					modelPos = createPoint(pos.x + spreadOffset, pos.y, pos.z)
				end
				local hopY = math.abs(math.sin(progress * math.pi * 16 + idx)) * 0.48
				local waddleAngle = math.sin(progress * math.pi * 16 + idx) * 0.14
				applyModelPosition(model, modelPos, lookAheadPos, hopY, waddleAngle)
			end
		end

		-- Check for arrival at destination
		if progress >= 1 then
			group.isCompleted = true
			table.insert(arrivedGroups, group)
		end
	end

	-- Clean up arrived groups: chickens visually disappear in target coop with a particle puff
	for _, group in ipairs(arrivedGroups) do
		spawnArrivalPuff(group.currentPosition, self.container)
		for _, model in ipairs(group.models) do
			destroyModel(model)
		end
		self._activeVisualCount = math.max(0, self._activeVisualCount - #group.models)
		group.isDestroyed = true
		self:_markCompleted(group.groupId)
		self._activeGroups[group.groupId] = nil

		self:_emit("chickensArrived", group.groupId, group.targetSlotId, group.count)
		self:_emit("groupCompleted", group.groupId, group)
	end

	self:updateDrones(nowMs)

	return self:getActiveGroupCount()
end

-- ============================================================================
-- 3D Flying Drones Presentation (VIS-05, PROD-06)
-- ============================================================================

local function bezierCubic(p0, p1, p2, p3, t)
	local u = 1 - t
	local tt = t * t
	local uu = u * u
	local uuu = uu * u
	local ttt = tt * t
	local x = uuu * p0.x + 3 * uu * t * p1.x + 3 * u * tt * p2.x + ttt * p3.x
	local y = uuu * p0.y + 3 * uu * t * p1.y + 3 * u * tt * p2.y + ttt * p3.y
	local z = uuu * p0.z + 3 * uu * t * p1.z + 3 * u * tt * p2.z + ttt * p3.z
	return createPoint(x, y, z)
end

function RoutePresentation:spawnDrone(droneId: string, isElite: boolean?, startInstantMs: number, durationSeconds: number?, onClicked: ((string) -> ())?, trajectory: any?)
	local durSec = durationSeconds or 15.0
	local descentDuration = if trajectory and trajectory.landedAtMs then (trajectory.landedAtMs-startInstantMs)/1000 else 2.5
	local groundDuration = 15
 local expiresAtMs = if trajectory and trajectory.expiresAtMs then trajectory.expiresAtMs else startInstantMs+math.floor(descentDuration*1000)+15000

	-- 3D Bezier trajectory: parachute drop down to random farm ground point
	local p0, p1, p2, p3
	if trajectory and trajectory.p0 and trajectory.p3 then
		p0 = trajectory.p0
		p1 = trajectory.p1 or p0
		p2 = trajectory.p2 or trajectory.p3
		p3 = trajectory.p3
	else
		-- Deterministic pseudo-random Bezier curve dropping onto farm based on droneId
		local seedNum = 0
		for i = 1, #tostring(droneId) do
			seedNum = (seedNum * 31 + string.byte(tostring(droneId), i)) % 100000
		end
		-- Random landing position within [-30, 30] studs on X and Z
		local targetX = ((seedNum % 6000) / 100) - 30
		local targetZ = (((math.floor(seedNum / 7)) % 6000) / 100) - 30
		local driftX = (((seedNum % 2000) / 100) - 10) * 0.4
		local driftZ = ((((math.floor(seedNum / 13)) % 2000) / 100) - 10) * 0.4
		local startY = 48 + (seedNum % 6)
		p0 = createPoint(targetX + driftX, startY, targetZ + driftZ)
		p1 = createPoint(targetX + driftX * 0.7, startY + 2.5, targetZ + driftZ * 0.7)
		p2 = createPoint(targetX + driftX * 0.3, 20.0, targetZ + driftZ * 0.3)
		p3 = createPoint(targetX, 1.15, targetZ)
	end

	if trajectory and trajectory.position then
  local pos=trajectory.position;p3=createPoint(pos.x,pos.y,pos.z)
  p0=createPoint(pos.x,48,pos.z);p1=createPoint(pos.x,50,pos.z);p2=createPoint(pos.x,20,pos.z)
 end
	local startPos = p0
	local endPos = p3

	local model
	if isRoblox then
		model = Instance.new("Model")
		model.Name = "Drone_" .. tostring(droneId)

		-- Main Gift Box Part (~3.5x3.5x3.5 studs, red or gold for elite)
		local box = Instance.new("Part")
		box.Name = "GiftBoxPart"
		box.Shape = Enum.PartType.Block
		box.Size = Vector3.new(3.5, 3.5, 3.5)
		box.Color = if isElite then Color3.fromRGB(255, 215, 35) else Color3.fromRGB(235, 45, 65)
		box.Material = Enum.Material.SmoothPlastic
		box.TopSurface = Enum.SurfaceType.Smooth
		box.BottomSurface = Enum.SurfaceType.Smooth
		box.Anchored = true
		box.CanCollide = false
		box.CanTouch = true
		box.CanQuery = true
		box.Position = Vector3.new(startPos.x, startPos.y, startPos.z)
		box.Parent = model
		model.PrimaryPart = box

		-- Ribbon bands (Horizontal & Vertical)
		local ribbonColor = if isElite then Color3.fromRGB(50, 230, 255) else Color3.fromRGB(255, 215, 35)

		local ribbonH = Instance.new("Part")
		ribbonH.Name = "RibbonH"
		ribbonH.Size = Vector3.new(3.54, 3.54, 0.85)
		ribbonH.Color = ribbonColor
		ribbonH.Material = Enum.Material.Neon
		ribbonH.TopSurface = Enum.SurfaceType.Smooth
		ribbonH.BottomSurface = Enum.SurfaceType.Smooth
		ribbonH.Anchored = false
		ribbonH.CanCollide = false
		ribbonH.CanTouch = false
		ribbonH.CanQuery = false
		ribbonH.CFrame = box.CFrame
		ribbonH.Parent = model
		local weldH = Instance.new("WeldConstraint")
		weldH.Part0 = box; weldH.Part1 = ribbonH; weldH.Parent = ribbonH

		local ribbonV = Instance.new("Part")
		ribbonV.Name = "RibbonV"
		ribbonV.Size = Vector3.new(0.85, 3.54, 3.54)
		ribbonV.Color = ribbonColor
		ribbonV.Material = Enum.Material.Neon
		ribbonV.TopSurface = Enum.SurfaceType.Smooth
		ribbonV.BottomSurface = Enum.SurfaceType.Smooth
		ribbonV.Anchored = false
		ribbonV.CanCollide = false
		ribbonV.CanTouch = false
		ribbonV.CanQuery = false
		ribbonV.CFrame = box.CFrame
		ribbonV.Parent = model
		local weldV = Instance.new("WeldConstraint")
		weldV.Part0 = box; weldV.Part1 = ribbonV; weldV.Parent = ribbonV

		-- Ribbon Bow on top
		local bow = Instance.new("Part")
		bow.Name = "RibbonBow"
		bow.Shape = Enum.PartType.Ball
		bow.Size = Vector3.new(1.3, 0.7, 1.3)
		bow.Color = ribbonColor
		bow.Material = Enum.Material.Neon
		bow.Anchored = false
		bow.CanCollide = false
		bow.CanTouch = false
		bow.CanQuery = false
		bow.CFrame = box.CFrame * CFrame.new(0, 1.85, 0)
		bow.Parent = model
		local weldBow = Instance.new("WeldConstraint")
		weldBow.Part0 = box; weldBow.Part1 = bow; weldBow.Parent = bow

		-- Parachute Canopy above the box during gentle descent
		local parachute = Instance.new("Part")
		parachute.Name = "GiftParachute"
		parachute.Shape = Enum.PartType.Ball
		parachute.Size = Vector3.new(5.6, 2.6, 5.6)
		parachute.Color = if isElite then Color3.fromRGB(255, 235, 140) else Color3.fromRGB(250, 245, 235)
		parachute.Material = Enum.Material.SmoothPlastic
		parachute.Anchored = false
		parachute.CanCollide = false
		parachute.CanTouch = false
		parachute.CanQuery = false
		parachute.CFrame = box.CFrame * CFrame.new(0, 5.2, 0)
		parachute.Parent = model
		local weldP = Instance.new("WeldConstraint")
		weldP.Part0 = box; weldP.Part1 = parachute; weldP.Parent = parachute

		-- Soft Sparkle Light & Particles
		local light = Instance.new("PointLight")
		light.Name = "GiftLight"
		light.Range = 14
		light.Brightness = 1.5
		light.Color = if isElite then Color3.fromRGB(255, 220, 80) else Color3.fromRGB(255, 140, 140)
		light.Parent = box

		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Name = "GiftSparkles"
		sparkles.Rate = 5
		sparkles.Lifetime = NumberRange.new(0.5, 1.0)
		sparkles.Speed = NumberRange.new(1, 2.5)
		sparkles.Size = NumberSequence.new(0.35, 0)
		sparkles.LightEmission = 0.8
		sparkles.Color = ColorSequence.new(if isElite then Color3.fromRGB(255, 235, 100) else Color3.fromRGB(255, 240, 180))
		sparkles.Parent = box

		-- BillboardGui: Title & Subtitle with countdown
		local bb = Instance.new("BillboardGui")
		bb.Name = "GiftBillboard"
		bb.Adornee = box
		bb.Size = UDim2.new(0, 220, 0, 60)
		bb.StudsOffset = Vector3.new(0, 4.6, 0)
		bb.AlwaysOnTop = true
		bb.Parent = box

		local titleLbl = Instance.new("TextLabel")
		titleLbl.Name = "Title"
		titleLbl.Size = UDim2.new(1, 0, 0.55, 0)
		titleLbl.BackgroundTransparency = 1
		titleLbl.Font = Enum.Font.FredokaOne
		titleLbl.TextScaled = true
		titleLbl.Text = if isElite then "👑 ZŁOTY PREZENT!" else "🎁 PREZENT!"
		titleLbl.TextColor3 = if isElite then Color3.fromRGB(255, 225, 60) else Color3.fromRGB(255, 245, 110)
		titleLbl.Parent = bb
		local st1 = Instance.new("UIStroke")
		st1.Thickness = 2.4; st1.Color = Color3.fromRGB(20, 10, 5); st1.Parent = titleLbl

		local subLbl = Instance.new("TextLabel")
		subLbl.Name = "Subtitle"
		subLbl.Size = UDim2.new(1, 0, 0.45, 0)
		subLbl.Position = UDim2.new(0, 0, 0.55, 0)
		subLbl.BackgroundTransparency = 1
		subLbl.Font = Enum.Font.FredokaOne
		subLbl.TextScaled = true
		subLbl.Text = "[PODBIEGNIJ BY PODNIEŚĆ]"
		subLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
		subLbl.Parent = bb
		local st2 = Instance.new("UIStroke")
		st2.Thickness = 2.0; st2.Color = Color3.fromRGB(20, 10, 5); st2.Parent = subLbl

        -- Cosmetic only; no click, touch or prompt claim callback.

		if self.container then
			model.Parent = self.container
		end
	else
		model = {
			id = droneId,
			position = startPos,
			destroyed = false,
		}
	end

	local entry = {
		droneId = droneId,
		isElite = isElite == true,
		startInstantMs = startInstantMs,
		durationSeconds = durSec, expiresAtMs = expiresAtMs,
		descentDuration = descentDuration,
		groundDuration = groundDuration,
		landed = false,
		landedAtMs = 0,
		startPos = startPos,
		endPos = endPos,
		p0 = p0,
		p1 = p1,
		p2 = p2,
		p3 = p3,
		currentPosition = startPos,
		model = model,
		claimed = false,
		falling = false,
		fallVelocity = 0,
		onClicked = onClicked,
	}
	self._activeDrones[droneId] = entry
	return entry
end

-- Compatibility shim: stale click callers cannot collect a gift.
function RoutePresentation:shootDrone(_droneId: string, _instant: boolean?)
 return false
end

function RoutePresentation:updateDrones(nowMs: number, _dtSeconds: number?)
 local finished={}
 for id,d in self._activeDrones do
  if nowMs>=d.expiresAtMs then table.insert(finished,id)
  else
   local alpha=math.clamp((nowMs-d.startInstantMs)/(d.descentDuration*1000),0,1)
   d.currentPosition=bezierCubic(d.p0,d.p1,d.p2,d.p3,alpha)
   applyModelPosition(d.model,d.currentPosition)
   if alpha>=1 and not d.landed then
    d.landed=true;d.landedAtMs=d.startInstantMs+d.descentDuration*1000
    if isRoblox then
     local para=d.model:FindFirstChild('GiftParachute');if para then para:Destroy() end
     spawnArrivalPuff(d.currentPosition,self.container)
    end
   end
   if d.landed and isRoblox then
    local sub=d.model:FindFirstChild('Subtitle',true)
    if sub then sub.Text=string.format('[PODBIEGNIJ BY PODNIEŚĆ] (%ds...)',math.ceil((d.expiresAtMs-nowMs)/1000)) end
   end
  end
 end
 for _,id in finished do self:removeDroneVisual(id) end
end

function RoutePresentation:removeDroneVisual(droneId)
 local d=self._activeDrones[droneId]
 if not d then return false end
 destroyModel(d.model);self._activeDrones[droneId]=nil;return true
end

function RoutePresentation:claimDroneVisual(droneId: string)
	local d = self._activeDrones[droneId]
	if not d then return false end
	d.claimed = true
	spawnArrivalPuff(d.currentPosition, self.container)
	destroyModel(d.model)
	self._activeDrones[droneId] = nil
	self:_emit("droneClaimed", droneId)
	return true
end

function RoutePresentation:getDrone(droneId: string)
	return self._activeDrones[droneId]
end

function RoutePresentation:getGroup(groupId: any)
	return self._activeGroups[groupId]
end

function RoutePresentation:getGroupPosition(groupId: any)
	local g = self._activeGroups[groupId]
	return if g ~= nil then g.currentPosition else nil
end

function RoutePresentation:getGroupProgress(groupId: any)
	local g = self._activeGroups[groupId]
	return if g ~= nil then g.currentProgress else nil
end

function RoutePresentation:isGroupCompleted(groupId: any)
	return self._completedGroups[groupId] == true
end

function RoutePresentation:getActiveGroupCount()
	local count = 0
	for _ in self._activeGroups do
		count += 1
	end
	return count
end

function RoutePresentation:getActiveGroups()
	local list = {}
	for _, group in self._activeGroups do
		table.insert(list, group)
	end
	return list
end

function RoutePresentation:removeGroup(groupId: any)
	local group = self._activeGroups[groupId]
	if group ~= nil then
		for _, model in ipairs(group.models) do
			destroyModel(model)
		end
		self._activeVisualCount = math.max(0, self._activeVisualCount - #group.models)
		group.isDestroyed = true
		self._activeGroups[groupId] = nil
		return true
	end
	return false
end

function RoutePresentation:clearAllGroups()
	for groupId, group in self._activeGroups do
		for _, model in ipairs(group.models) do
			destroyModel(model)
		end
		group.isDestroyed = true
	end
	self._activeGroups = {}
	self._activeVisualCount = 0
	for _, d in pairs(self._activeDrones) do
		destroyModel(d.model)
	end
	self._activeDrones = {}
end

-- ============================================================================
-- Event System
-- ============================================================================

function RoutePresentation:on(eventName: string, callback: (...any) -> ())
	assert(type(eventName) == "string", "INVALID_EVENT_NAME")
	assert(type(callback) == "function", "INVALID_CALLBACK")

	if not self._listeners[eventName] then
		self._listeners[eventName] = {}
	end
	table.insert(self._listeners[eventName], callback)

	return function()
		local list = self._listeners[eventName]
		if not list then return end
		local idx = table.find(list, callback)
		if idx then
			table.remove(list, idx)
		end
		if #list == 0 then
			self._listeners[eventName] = nil
		end
	end
end

function RoutePresentation:_emit(eventName: string, ...)
	local list = self._listeners[eventName]
	if list ~= nil then
		local copy = table.clone(list)
		for _, cb in ipairs(copy) do
			cb(...)
		end
	end
end

function RoutePresentation:onChickensArrived(callback: (groupId: any, targetSlotId: number, count: number) -> ())
	return self:on("chickensArrived", callback)
end

function RoutePresentation:onGroupCompleted(callback: (groupId: any, group: any) -> ())
	return self:on("groupCompleted", callback)
end

function RoutePresentation:destroy()
	self:clearAllGroups()
	self._listeners = {}
	self._completedGroups = {}
	self._completedOrder = {}
	self._activeVisualCount = 0
	self._spawnBudget = nil
	self._spawnBudgetMs = nil
end

return table.freeze(RoutePresentation)
