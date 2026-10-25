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

	local baseSpeed = d.baseSpeed or DEFAULT_SPEED
	local routes = d.routes or (if baseSpeed == DEFAULT_SPEED then CANONICAL_ROUTES else generateCanonicalRoutes(baseSpeed))

	local self = setmetatable({
		baseSpeed = baseSpeed,
		routes = routes,
		maxVisualsPerGroup = d.maxVisualsPerGroup or 5,
		modelFactory = d.modelFactory,
		chickenTemplate = d.chickenTemplate,
		container = d.container or d.modelsContainer,
		clientStateStore = d.clientStateStore,
		_activeGroups = {},
		_completedGroups = {},
		_activeDrones = {},
		_listeners = {},
	}, RoutePresentation)

	return self
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

	self._activeGroups[groupId] = group
	self:_emit("groupSpawned", groupId, group)
	return group
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
		group.isDestroyed = true
		self._completedGroups[group.groupId] = true
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
	local durSec = durationSeconds or 9.0

	-- 3D Bezier trajectory: customizable or calculated across the farm
	local p0, p1, p2, p3
	if trajectory and trajectory.p0 and trajectory.p3 then
		p0 = trajectory.p0
		p1 = trajectory.p1 or p0
		p2 = trajectory.p2 or trajectory.p3
		p3 = trajectory.p3
	else
		-- Deterministic pseudo-random Bezier curve across farm based on droneId
		local seedNum = 0
		for i = 1, #tostring(droneId) do
			seedNum = (seedNum * 31 + string.byte(tostring(droneId), i)) % 100000
		end
		local angle = (seedNum / 100000) * math.pi * 2
		local r = 80
		p0 = createPoint(math.cos(angle) * r, 24, math.sin(angle) * r)
		local endAngle = angle + math.pi + ((seedNum % 7) - 3) * 0.15
		p3 = createPoint(math.cos(endAngle) * r, 24, math.sin(endAngle) * r)
		p1 = createPoint(p0.x * 0.35 + ((seedNum % 13) - 6) * 3, 28, p0.z * 0.35 + ((seedNum % 17) - 8) * 3)
		p2 = createPoint(p3.x * 0.35 + ((seedNum % 11) - 5) * 3, 26, p3.z * 0.35 + ((seedNum % 19) - 9) * 3)
	end

	local startPos = p0
	local endPos = p3

	local model
	if isRoblox then
		model = Instance.new("Model")
		model.Name = "Drone_" .. tostring(droneId)

		local core = Instance.new("Part")
		core.Name = "DroneCore"
		core.Shape = Enum.PartType.Ball
		core.Size = if isElite then Vector3.new(5.2, 5.2, 5.2) else Vector3.new(3.8, 3.8, 3.8)
		core.Color = if isElite then Color3.fromRGB(255, 215, 35) else Color3.fromRGB(255, 95, 175)
		core.Material = Enum.Material.Neon
		core.Anchored = true
		core.CanCollide = false
		core.CanTouch = false
		core.CanQuery = true
		core.Position = Vector3.new(startPos.x, startPos.y, startPos.z)
		core.Parent = model
		model.PrimaryPart = core

		-- Gift Box Payload hanging underneath
		local box = Instance.new("Part")
		box.Name = "GiftCrate"
		box.Size = Vector3.new(2.8, 2.8, 2.8)
		box.Color = if isElite then Color3.fromRGB(255, 235, 85) else Color3.fromRGB(115, 235, 95)
		box.TopSurface = Enum.SurfaceType.Studs
		box.Anchored = false
		box.CanCollide = false
		box.CanTouch = false
		box.CanQuery = true
		box.Position = Vector3.new(startPos.x, startPos.y - 3.0, startPos.z)
		box.Parent = model

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = core
		weld.Part1 = box
		weld.Parent = box

		-- ClickDetector on core and box so clicking or tapping shoots the drone!
		local cd = Instance.new("ClickDetector")
		cd.MaxActivationDistance = 140
		cd.Parent = core
		cd.MouseClick:Connect(function()
			self:shootDrone(droneId)
		end)

		local cdBox = Instance.new("ClickDetector")
		cdBox.MaxActivationDistance = 140
		cdBox.Parent = box
		cdBox.MouseClick:Connect(function()
			self:shootDrone(droneId)
		end)

		local bb = Instance.new("BillboardGui")
		bb.Name = "DroneBillboard"
		bb.Adornee = core
		bb.Size = UDim2.new(0, 180, 0, 50)
		bb.StudsOffset = Vector3.new(0, 4.5, 0)
		bb.AlwaysOnTop = true
		bb.Parent = core

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, 0, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.FredokaOne
		lbl.TextScaled = true
		lbl.Text = if isElite then "👑 ELITARNY DRON! [KLIKNIJ]" else "📦 DRON Z PACZKĄ! [KLIKNIJ]"
		lbl.TextColor3 = Color3.fromRGB(255, 245, 95)
		lbl.Parent = bb

		local st = Instance.new("UIStroke")
		st.Thickness = 2.4
		st.Color = Color3.fromRGB(20, 10, 5)
		st.Parent = lbl

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
		durationSeconds = durSec,
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

function RoutePresentation:shootDrone(droneId: string)
	local d = self._activeDrones[droneId]
	if not d or d.claimed or d.falling then return false end
	d.falling = true
	d.fallVelocity = 8
	if isRoblox and typeof(d.model) == "Instance" then
		local bb = d.model:FindFirstChildWhichIsA("BillboardGui", true)
		if bb then bb:Destroy() end
		local core = d.model:FindFirstChild("DroneCore")
		if core then
			core.Color = Color3.fromRGB(120, 120, 120)
		end
	end
	self:_emit("droneShot", droneId)
	return true
end

function RoutePresentation:updateDrones(nowMs: number, dtSeconds: number?)
	local dt = dtSeconds or 0.033
	local finished = {}
	for droneId, d in pairs(self._activeDrones) do
		if d.falling then
			d.fallVelocity = (d.fallVelocity or 0) + 70 * dt
			local curY = d.currentPosition.y - d.fallVelocity * dt
			d.currentPosition = createPoint(d.currentPosition.x, curY, d.currentPosition.z)
			applyModelPosition(d.model, d.currentPosition)
			if curY <= 0.85 then
				d.currentPosition = createPoint(d.currentPosition.x, 0.85, d.currentPosition.z)
				applyModelPosition(d.model, d.currentPosition)
				table.insert(finished, { droneId = droneId, shot = true })
			end
		else
			local alpha = math.clamp((nowMs - d.startInstantMs) / (d.durationSeconds * 1000), 0, 1)
			local pos
			if d.p0 and d.p1 and d.p2 and d.p3 then
				pos = bezierCubic(d.p0, d.p1, d.p2, d.p3, alpha)
			else
				pos = lerpPoint(d.startPos, d.endPos, alpha)
			end
			local bobY = math.sin(alpha * math.pi * 8) * 1.8
			d.currentPosition = createPoint(pos.x, pos.y + bobY, pos.z)
			applyModelPosition(d.model, d.currentPosition)
			if alpha >= 1 then
				table.insert(finished, { droneId = droneId, shot = false })
			end
		end
	end

	for _, item in ipairs(finished) do
		local d = self._activeDrones[item.droneId]
		if d then
			if item.shot then
				if d.onClicked then
					d.onClicked(item.droneId)
				end
				self:claimDroneVisual(item.droneId)
			else
				destroyModel(d.model)
				self._activeDrones[item.droneId] = nil
			end
		end
	end
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
end

return table.freeze(RoutePresentation)
