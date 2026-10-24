--!nocheck
-- RoutePresentation for HatchTheEgg.
-- Visual presentation of the 4 habitat plots, hatchery zone, and chicken movement routes
-- based on PRE-03 (docs/35_pre03_routes_and_arrivals.md).
--
-- CRITICAL ARCHITECTURAL INVARIANT:
-- The presentation layer is strictly a one-way consumer of state.
-- Removing, destroying, slowing down, or colliding chicken models in 3D
-- DOES NOT affect the server authoritative population, running chickens in transit,
-- egg laying rate, or player cash balances!

local SCENE_VERSION = "CANONICAL_V1"
local ROUTE_VERSION = 1
local DEFAULT_SPEED = 25.0 -- studs per second

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

local function applyModelPosition(model, pt)
	if model == nil then return end
	if model.destroyed then return end

	local x, y, z = getCoords(pt)

	-- If model has custom setPosition method (mock)
	if type(model.setPosition) == "function" then
		model:setPosition(pt)
		return
	end

	-- Roblox Studio environment
	if typeof(CFrame) == "table" and type(CFrame.new) == "function" and typeof(Vector3) == "table" and type(Vector3.new) == "function" then
		local v3 = Vector3.new(x, y, z)
		if typeof(model.PivotTo) == "function" then
			model:PivotTo(CFrame.new(v3))
			return
		elseif typeof(model.SetPrimaryPartCFrame) == "function" and model.PrimaryPart ~= nil then
			model:SetPrimaryPartCFrame(CFrame.new(v3))
			return
		elseif model.Position ~= nil then
			model.Position = v3
			return
		end
	end

	-- Pure Lune environment / table mock
	local posObj = createPoint(x, y, z)
	model.position = posObj
	model.Position = posObj
end

local function destroyModel(model)
	if model == nil then return end
	if typeof(model.Destroy) == "function" then
		pcall(function() model:Destroy() end)
	elseif typeof(model.destroy) == "function" then
		pcall(function() model:destroy() end)
	end
	if type(model) == "table" then
		model.destroyed = true
	end
end

local function createDefaultModel(groupId, index, startPos, container, chickenTemplate)
	if chickenTemplate ~= nil and typeof(chickenTemplate.Clone) == "function" then
		local clone = chickenTemplate:Clone()
		clone.Name = "Chicken_" .. tostring(groupId) .. "_" .. tostring(index)
		applyModelPosition(clone, startPos)
		if container ~= nil then
			clone.Parent = container
		end
		return clone
	end

	-- Check if running inside Roblox with Instance.new
	if typeof(Instance) == "table" and type(Instance.new) == "function" and typeof(Vector3) == "table" and type(Vector3.new) == "function" then
		local part = Instance.new("Part")
		part.Name = "Chicken_" .. tostring(groupId) .. "_" .. tostring(index)
		part.Size = Vector3.new(1.2, 1.2, 1.2)
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Anchored = true
		applyModelPosition(part, startPos)
		if container ~= nil then
			part.Parent = container
		end
		return part
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
		container = d.container,
		clientStateStore = d.clientStateStore,
		_activeGroups = {},
		_completedGroups = {},
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
	local visualCount = math.clamp(numCount, 1, self.maxVisualsPerGroup)
	local models = {}

	for i = 1, visualCount do
		local model
		if type(self.modelFactory) == "function" then
			model = self.modelFactory(groupId, i, numCount, targetSlotId)
			applyModelPosition(model, startPos)
		else
			model = createDefaultModel(groupId, i, startPos, self.container, self.chickenTemplate)
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
		group.currentPosition = pos

		-- Update visual model positions (if models are still alive and valid)
		local numModels = #group.models
		for idx, model in ipairs(group.models) do
			if model ~= nil and not model.destroyed then
				-- Optional slight lateral offset when multiple models are in the group
				local modelPos = pos
				if numModels > 1 then
					local spreadOffset = (idx - (numModels + 1) / 2) * 0.4
					modelPos = createPoint(pos.x + spreadOffset, pos.y, pos.z)
				end
				applyModelPosition(model, modelPos)
			end
		end

		-- Check for arrival at destination
		if progress >= 1 then
			group.isCompleted = true
			table.insert(arrivedGroups, group)
		end
	end

	-- Clean up arrived groups: chickens visually disappear in target coop
	for _, group in ipairs(arrivedGroups) do
		for _, model in ipairs(group.models) do
			destroyModel(model)
		end
		group.isDestroyed = true
		self._completedGroups[group.groupId] = true
		self._activeGroups[group.groupId] = nil

		self:_emit("chickensArrived", group.groupId, group.targetSlotId, group.count)
		self:_emit("groupCompleted", group.groupId, group)
	end

	return self:getActiveGroupCount()
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
