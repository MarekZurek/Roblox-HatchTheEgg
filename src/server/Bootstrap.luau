--!nocheck
-- Server bootstrap and orchestration module for HatchTheEgg.
-- Pure factory object ServerBootstrap.new(deps) compatible with Lune and Roblox Studio.
-- Wires all authoritative server components:
-- NumericCodec, CatalogRegistry, SessionRepository, ProfileSchema, PersistenceData,
-- PlayerCoordinator, TimelineSimulation, FarmMath, FarmActions, ViewProjector, NetworkGateway, Clock.

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

local NumericCodec = resolve(function()
	return game:GetService("ReplicatedStorage").HatchTheEgg.Shared.NumericCodec
end, "../shared/NumericCodec")

local ProtocolSchemas = resolve(function()
	return game:GetService("ReplicatedStorage").HatchTheEgg.Shared.ProtocolSchemas
end, "../shared/ProtocolSchemas")

local CatalogData = resolve(function()
	return script.Parent.CatalogRegistry.Data
end, "./CatalogRegistry/Data")

local CatalogRegistry = resolve(function()
	return script.Parent.CatalogRegistry
end, "./CatalogRegistry")

local SessionRepository = resolve(function()
	return script.Parent.SessionRepository
end, "./SessionRepository")

local ProfileSchema = resolve(function()
	return script.Parent.ProfileSchema
end, "./ProfileSchema")

local PersistenceData = resolve(function()
	return script.Parent.PersistenceData
end, "./PersistenceData")

local PlayerCoordinator = resolve(function()
	return script.Parent.PlayerCoordinator
end, "./PlayerCoordinator")

local TimelineSimulation = resolve(function()
	return script.Parent.TimelineSimulation
end, "./TimelineSimulation")

local ProductionMath = resolve(function()
	return script.Parent.FarmMath.production_research
end, "./FarmMath/production_research")

local PopulationMath = resolve(function()
	return script.Parent.FarmMath.PopulationMath
end, "./FarmMath/PopulationMath")

local HatchingRCB = resolve(function()
	return script.Parent.FarmMath.hatching_rcb
end, "./FarmMath/hatching_rcb")

local IHR = resolve(function()
	return script.Parent.FarmMath.ihr
end, "./FarmMath/ihr")

local FarmActions = resolve(function()
	return script.Parent.FarmActions
end, "./FarmActions")

local ProgressActions = resolve(function()
	return script.Parent.ProgressActions
end, "./ProgressActions")

local ViewProjector = resolve(function()
	return script.Parent.ViewProjector
end, "./ViewProjector")

local NetworkGateway = resolve(function()
	return script.Parent.NetworkGateway
end, "./NetworkGateway")

-- Numeric accounting fields that decode/encode to BigAmount
local NUMERIC_ACCOUNTING = table.freeze({
	"prestigeSessionArchivedCash",
	"prestigeExtraEarnings",
	"lastBaseEarnings",
	"currentFarmCash",
	"lastCashEarned",
})

local function neutralProfile(p)
	p.effects = p.effects or {}
	p.effects.boosts = p.effects.boosts or {}
	p.inventory = p.inventory or {}
	p.inventory.equipped = p.inventory.equipped or {}
end

local function profileToMemory(p, codec, productionMath, data)
	neutralProfile(p)
	local f = data.copy(p.farm)
	f.cash = codec.BigAmount.decode(f.cash)
	f.hatcheryStock = codec.Real64.decode(f.hatcheryStock)
	f.commonLevels = data.copy(f.common or {})
	f.vehicleTypes = {}
	for _, v in f.vehicles or {} do
		if type(v) == "table" and type(v.typeIndex) == "number" and v.typeIndex >= 0 then
			table.insert(f.vehicleTypes, v.typeIndex)
		end
	end

	local types = {}
	for i = 1, 4 do
		local hab = f.habitats and f.habitats[i]
		types[i] = if not hab or hab.typeIndex == -1 then false else hab.typeIndex
	end

	local capacities = productionMath.capacities(f.commonLevels, types)
	for i = 1, 4 do
		local hab = f.habitats[i]
		hab.capacity = tostring(capacities[i])
		hab.fractionalIHR = codec.Real64.decode(hab.fractionalIHR or "0")
	end

	local a = data.copy(p.accounting)
	for _, key in NUMERIC_ACCOUNTING do
		a[key] = codec.BigAmount.decode(a[key] or "0")
	end

	return {
		farm = f,
		accounting = a,
		settledWallThrough = p.timeline.settledWallThrough,
	}
end

local function memoryToWire(p, state, checkpoint, codec, data)
	local out = data.copy(p)
	out.farm = data.copy(state.farm)
	out.farm.cash = codec.BigAmount.encode(state.farm.cash)
	out.farm.hatcheryStock = codec.BigAmount.encode(state.farm.hatcheryStock)
	for i = 1, 4 do
		local hab = out.farm.habitats[i]
		hab.fractionalIHR = codec.Real64.encode(hab.fractionalIHR)
	end
	out.accounting = data.copy(state.accounting)
	for _, key in NUMERIC_ACCOUNTING do
		out.accounting[key] = codec.BigAmount.encode(state.accounting[key])
	end
	out.timeline.settledWallThrough = state.settledWallThrough
	out.timeline.integrationCheckpoint = checkpoint
	return out
end

local function createDefaultClock(initialNowMs)
	local nowMs = initialNowMs or 1000000
	local elapsedSec = 0
	local clock = {}
	function clock.utcNowMs()
		return nowMs
	end
	function clock.elapsedNowSeconds()
		return elapsedSec
	end
	function clock.advance(dtSeconds)
		elapsedSec += dtSeconds
		nowMs += math.floor(dtSeconds * 1000 + 0.5)
	end
	function clock.set(newNowMs, newElapsedSec)
		nowMs = newNowMs
		if newElapsedSec ~= nil then
			elapsedSec = newElapsedSec
		end
	end
	return clock
end

local function createMemoryStore(data)
	local records = {}
	return {
		records = records,
		read = function(key)
			return true, if records[key] then data.copy(records[key]) else nil
		end,
		update = function(key, transform)
			local current = if records[key] then data.copy(records[key]) else nil
			local nextVal = transform(current)
			if nextVal ~= nil then
				records[key] = data.copy(nextVal)
			end
			return true, if nextVal ~= nil then data.copy(nextVal) else nil
		end,
	}
end

local ServerBootstrap = {}
ServerBootstrap.__index = ServerBootstrap

function ServerBootstrap.new(deps)
	deps = deps or {}

	local codec = deps.codec or NumericCodec
	local data = deps.data or PersistenceData
	local schema = deps.schema or ProfileSchema.new(codec)
	local catalogData = deps.catalogData or CatalogData
	local catalog = deps.catalog or CatalogRegistry.new(codec, catalogData, { mode = "INTERNAL_TEST_ONLY" })
	local productionMath = deps.productionMath or ProductionMath.new(codec, catalog, { mode = "INTERNAL_TEST_ONLY" })
	local populationMath = deps.populationMath or PopulationMath.new(codec)
	local hatching = deps.hatching or HatchingRCB.new(codec, populationMath, data, { mode = "INTERNAL_TEST_ONLY" })
	local ihr = deps.ihr or IHR.new(codec, populationMath)
	local timeline = deps.timeline or TimelineSimulation.new(codec, productionMath, hatching, ihr, data, { mode = "INTERNAL_TEST_ONLY" })
	local farmActions = deps.farmActions or FarmActions.new(codec, catalog, { mode = "INTERNAL_TEST_ONLY" })
	local protocol = deps.protocol or ProtocolSchemas.new(codec)
	local configRevision = deps.configRevision or "first-farm-neutral:1"

	local viewProjector = deps.viewProjector or ViewProjector.new({
		codec = codec,
		catalog = catalog,
		productionMath = productionMath,
		configRevision = configRevision,
	})

	local clock = deps.clock or createDefaultClock(deps.initialNowMs or 1000000)
	local store = deps.store or createMemoryStore(data)

	local encodeJson = deps.encodeJson
	if not encodeJson then
		local okSerde, serde = pcall(function() return require("@lune/serde") end)
		if okSerde and serde and serde.encode then
			encodeJson = function(v) return serde.encode("json", v) end
		else
			local okHttp, HttpService = pcall(function() return game:GetService("HttpService") end)
			if okHttp and HttpService then
				encodeJson = function(v) return HttpService:JSONEncode(v) end
			else
				error("JSON encoder required in deps.encodeJson")
			end
		end
	end

	local tokenSerial = 0
	local tokenFactory = deps.tokenFactory or function()
		tokenSerial += 1
		return "session-token-" .. tostring(tokenSerial)
	end

	local repository = deps.repository or SessionRepository.new({
		mode = "INTERNAL_TEST_ONLY",
		codec = codec,
		data = data,
		schema = schema,
		store = store,
		clock = clock,
		encodeJson = encodeJson,
		tokenFactory = tokenFactory,
	})

	local gateway = deps.gateway or NetworkGateway.new({
		viewProjector = viewProjector,
		farmActions = farmActions,
		protocol = protocol,
		clock = clock,
		codec = codec,
		catalog = catalog,
		configRevision = configRevision,
		autoDrain = true,
	})

	local self = setmetatable({
		codec = codec,
		data = data,
		schema = schema,
		catalog = catalog,
		productionMath = productionMath,
		populationMath = populationMath,
		hatching = hatching,
		ihr = ihr,
		timeline = timeline,
		farmActions = farmActions,
		viewProjector = viewProjector,
		protocol = protocol,
		configRevision = configRevision,
		config = {
			revision = configRevision,
			siloCapacityLevel = 0,
			pro = false,
		},
		clock = clock,
		store = store,
		repository = repository,
		gateway = gateway,
		players = {},
		depsRouteProvider = deps.routeProvider,
	}, ServerBootstrap)

	return self
end

function ServerBootstrap:_getRoute(slot)
	if self.depsRouteProvider then
		return self.depsRouteProvider(slot)
	end
	local durations = {
		[1] = 3.57,
		[2] = 3.57,
		[3] = 2.45,
		[4] = 2.45,
	}
	return {
		routeVersion = "scene-v1",
		startInstantMs = self.clock.utcNowMs(),
		travelDurationSeconds = durations[slot] or 2.0,
		snapshot = { slotId = slot },
	}
end

function ServerBootstrap:_simulationAdvance(playerSession, profile, request)
	if request == nil then
		return { profile = profile, complete = true }
	end

	if request.kind == "HatchPress" or request.kind == "HatchInput" then
		local pData = self.gateway:getPlayerState(playerSession.playerId)
		local streamId = (pData and pData.streamId) or request.streamId or playerSession.hatchingRuntime.streamId
		if playerSession.hatchingRuntime.streamId ~= streamId then
			playerSession.hatchingRuntime.streamId = streamId
			playerSession.hatchingRuntime.lastInputSeq = "0"
		end

		local drawSource = function() return "0" end
		local routeProvider = function(slot)
			return self:_getRoute(slot)
		end

		-- Prepare farm for hatching
		local farm = self.data.copy(profile.farm)
		local common = farm.common or {}
		local types = {}
		for i = 1, 4 do
			local hab = farm.habitats[i]
			types[i] = if not hab or hab.typeIndex == -1 then false else hab.typeIndex
		end
		local capacities = self.productionMath.capacities(common, types)
		for i = 1, 4 do
			local hab = farm.habitats[i]
			hab.capacity = if hab.typeIndex == -1 then "0" else tostring(capacities[i])
		end
		if type(farm.hatcheryStock) == "string" then
			farm.hatcheryStock = self.codec.BigAmount.decode(farm.hatcheryStock)
		end

		local nextFarm, nextRuntime, status, groupId = self.hatching.input(
			farm,
			playerSession.hatchingRuntime,
			request.packet or request,
			drawSource,
			routeProvider
		)
		playerSession.hatchingRuntime = nextRuntime
		nextFarm.hatcheryStock = self.codec.BigAmount.encode(nextFarm.hatcheryStock)
		profile.farm = nextFarm
		return { profile = profile, complete = true }
	end

	-- Time advance simulation
	local targetMs = request.targetMs
		or (if request.dtSeconds then profile.timeline.settledWallThrough + math.floor(request.dtSeconds * 1000 + 0.5) else profile.timeline.settledWallThrough)
	local budget = request.budget or 100

	local mem = profileToMemory(profile, self.codec, self.productionMath, self.data)
	local cp
	if profile.timeline.integrationCheckpoint then
		cp = self.timeline.decodeCheckpoint(profile.timeline.integrationCheckpoint)
	else
		cp = self.timeline.begin(mem, targetMs, self.config)
	end

	cp = self.timeline.advance(cp, budget)

	local checkpointWire = if cp.done then nil else self.timeline.encodeCheckpoint(cp)
	local nextProfile = memoryToWire(profile, cp.state, checkpointWire, self.codec, self.data)

	return {
		profile = nextProfile,
		complete = cp.done,
	}
end

function ServerBootstrap:playerJoined(playerId, initialProfileFixture)
	local pId = tostring(playerId)
	assert(string.match(pId, "^[0-9]+$"), "INVALID_PLAYER_ID: must be numeric digits")

	-- If fixture provided and store supports it, initialize profile in store
	if initialProfileFixture ~= nil then
		local fixture = self.data.copy(initialProfileFixture)
		fixture.ownership = fixture.ownership or {}
		fixture.ownership.ownerToken = ""
		fixture.ownership.endsAtMs = 0
		self.store.update("player:" .. pId, function()
			return fixture
		end)
	end

	-- 1. Acquire session in repository
	local opened = self.repository.acquire(pId)
	if opened.status ~= "ACQUIRED" then
		return nil, opened.errorCode or "ACQUIRE_FAILED"
	end
	local handle = opened.handle

	-- 2. Create PlayerCoordinator with simulation & domain ports
	local playerSession = {
		playerId = pId,
		handle = handle,
		hatchingRuntime = {
			streamId = "stream-" .. pId .. "-1",
			lastInputSeq = "0",
			held = false,
			holdElapsed = 0,
		},
	}

	local function simulationAdvance(profile, request)
		return self:_simulationAdvance(playerSession, profile, request)
	end

	local function domainApply(candidateProfile, op)
		if op.kind == "UpgradeEgg" or op.kind == "Prestige" then
			return ProgressActions.apply(candidateProfile, op, { catalog = self.catalog, productionMath = self.productionMath })
		end
		return self.farmActions.apply(candidateProfile, op)
	end

	local coordinator = PlayerCoordinator.new({
		mode = "INTERNAL_TEST_ONLY",
		codec = self.codec,
		data = self.data,
		repository = self.repository,
		handle = handle,
		clock = self.clock,
		maxQueue = 32,
		simulation = { advance = simulationAdvance },
		domain = { apply = domainApply },
	})

	-- Set coordinator ready so requests can be admitted
	local readyRes = coordinator.setReady(true)
	assert(readyRes.status == "READY_SET", "COORDINATOR_READY_FAILED")

	playerSession.coordinator = coordinator

	-- 3. Register player in NetworkGateway
	self.gateway:registerPlayer(pId, coordinator)
	local pData = self.gateway:getPlayerState(pId)
	if pData and pData.streamId then
		playerSession.hatchingRuntime.streamId = pData.streamId
	end

	self.players[pId] = playerSession

	return {
		status = "JOINED",
		playerId = pId,
		coordinator = coordinator,
		handle = handle,
		streamId = (pData and pData.streamId) or ("stream-" .. pId .. "-1"),
	}
end

function ServerBootstrap:playerLeaving(playerId)
	local pId = tostring(playerId)
	local playerSession = self.players[pId]
	if not playerSession then
		return false, "PLAYER_NOT_FOUND"
	end

	local coordinator = playerSession.coordinator

	-- 1. Execute checkpoint
	local nowMs = self.clock.utcNowMs()

	-- Proactively renew lease if near expiration so checkpoint is guaranteed to commit
	if playerSession.handle and playerSession.handle.endsAtMs and (nowMs >= playerSession.handle.endsAtMs - 45000) then
		coordinator.renew()
		coordinator.drain()
	end

	local snapshots = coordinator.snapshots()
	local currentRev = (snapshots.durable and snapshots.durable.meta and snapshots.durable.meta.revision) or "0"

	local cpOp = {
		operationId = "checkpoint-" .. pId .. "-" .. tostring(nowMs),
		kind = "Checkpoint",
		expectedRevision = currentRev,
		args = {},
	}
	coordinator.checkpoint(cpOp)
	coordinator.drain()

	-- 2. Release session in repository
	coordinator.release()
	coordinator.drain()

	-- 3. Unregister from gateway
	self.gateway:unregisterPlayer(pId)

	-- 4. Clean up local session
	self.players[pId] = nil

	return true
end

function ServerBootstrap:checkpointPlayer(playerId)
	local pId = tostring(playerId)
	local playerSession = self.players[pId]
	if not playerSession then
		return false, "PLAYER_NOT_FOUND"
	end

	local coordinator = playerSession.coordinator
	local nowMs = self.clock.utcNowMs()

	if playerSession.handle and playerSession.handle.endsAtMs and (nowMs >= playerSession.handle.endsAtMs - 45000) then
		coordinator.renew()
		coordinator.drain()
	end

	local snapshots = coordinator.snapshots()
	local currentRev = (snapshots.durable and snapshots.durable.meta and snapshots.durable.meta.revision) or "0"

	local cpOp = {
		operationId = "checkpoint-" .. pId .. "-" .. tostring(nowMs),
		kind = "Checkpoint",
		expectedRevision = currentRev,
		args = {},
	}
	coordinator.checkpoint(cpOp)
	coordinator.drain()

	local res = coordinator.resultOf(cpOp.operationId)
	return true, res
end

function ServerBootstrap:checkpointAll()
	local results = {}
	for pId, _ in pairs(self.players) do
		local ok, res = self:checkpointPlayer(pId)
		results[pId] = { ok = ok, result = res }
	end
	return results
end

function ServerBootstrap:close()
	local pIds = {}
	for pId, _ in pairs(self.players) do
		table.insert(pIds, pId)
	end
	local results = {}
	for _, pId in ipairs(pIds) do
		local ok, res = self:playerLeaving(pId)
		results[pId] = { ok = ok, result = res }
	end
	return results
end

function ServerBootstrap:tick(dtSeconds, nowMs)
	if dtSeconds ~= nil and type(self.clock.advance) == "function" then
		self.clock.advance(dtSeconds)
	elseif nowMs ~= nil and type(self.clock.set) == "function" then
		self.clock.set(nowMs)
	end

	local currentNowMs = nowMs or self.clock.utcNowMs()

	for playerId, playerSession in pairs(self.players) do
		local coordinator = playerSession.coordinator
		if coordinator then
			if playerSession.handle and playerSession.handle.endsAtMs and (currentNowMs >= playerSession.handle.endsAtMs - 45000) then
				coordinator.renew()
			end
			coordinator.tick({
				kind = "TimeAdvance",
				dtSeconds = dtSeconds,
				targetMs = currentNowMs,
				budget = 100,
			})
			coordinator.drain()
		end
	end
end

function ServerBootstrap:getCoordinator(playerId)
	local pId = tostring(playerId)
	local s = self.players[pId]
	return if s then s.coordinator else nil
end

function ServerBootstrap:getPlayer(playerId)
	local pId = tostring(playerId)
	return self.players[pId]
end

function ServerBootstrap:getGateway()
	return self.gateway
end

function ServerBootstrap:getRepository()
	return self.repository
end

function ServerBootstrap:dispatch(playerId, message)
	return self.gateway:handleRequest(playerId, message)
end
ServerBootstrap.handleRequest = ServerBootstrap.dispatch

function ServerBootstrap:createPlayerDelta(playerId)
	local pId = tostring(playerId)
	return self.gateway:createPlayerDelta(pId)
end

return table.freeze(ServerBootstrap)
