--!nocheck
-- Client bootstrap and orchestration module for HatchTheEgg.
-- Pure factory object ClientBootstrap.new(deps) compatible with Lune and Roblox Studio.
-- Wires all client components:
-- NumericCodec, ProtocolSchemas, ClientTransport, ClientStateStore,
-- IntentControllers, HUD, RoutePresentation.

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

local ClientTransport = resolve(function()
	return script.Parent.ClientTransport
end, "./ClientTransport")

local ClientStateStore = resolve(function()
	return script.Parent.ClientStateStore
end, "./ClientStateStore")

local IntentControllers = resolve(function()
	return script.Parent.IntentControllers
end, "./IntentControllers")

local RoutePresentation = resolve(function()
	return script.Parent.RoutePresentation
end, "./RoutePresentation")

local HUD = resolve(function()
	return script.Parent.HUD
end, "./HUD")

local ClientBootstrap = {}
ClientBootstrap.__index = ClientBootstrap

function ClientBootstrap.new(deps)
	deps = deps or {}

	local codec = deps.codec or NumericCodec
	local protocol = deps.protocol or ProtocolSchemas.new(codec)
	local playerId = deps.playerId or "1"

	local transport = deps.transport or ClientTransport.new({
		protocol = protocol,
		wire = deps.wire,
		playerId = playerId,
	})

	local stateStore = deps.stateStore or ClientStateStore.new({
		transport = transport,
		codec = codec,
	})

	local intentControllers = deps.intentControllers or IntentControllers.new({
		transport = transport,
		stateStore = stateStore,
		codec = codec,
	})

	local routePresentation = deps.routePresentation or RoutePresentation.new({
		clientStateStore = stateStore,
		baseSpeed = deps.baseSpeed,
		chickenTemplate = deps.chickenTemplate,
		modelsContainer = deps.modelsContainer,
	})

	local hud = deps.hud or HUD.new({
		stateStore = stateStore,
		intentControllers = intentControllers,
		codec = codec,
		guiRoot = deps.guiRoot,
	})

	local self = setmetatable({
		codec = codec,
		protocol = protocol,
		playerId = playerId,
		transport = transport,
		stateStore = stateStore,
		intentControllers = intentControllers,
		routePresentation = routePresentation,
		hud = hud,
		_localHatchSerial = 0,
		_lastInTransitCounts = { 0, 0, 0, 0 },
		_unsubs = {},
	}, ClientBootstrap)

	self:_setupEventBindings()
	return self
end

function ClientBootstrap:_setupEventBindings()
	-- Synchronize HUD and presentation whenever state changes
	local unsubState = self.stateStore:on("stateChanged", function(changeType, payload)
		if self.hud then
			self.hud:update()
		end

		-- Sync in-transit chickens to RoutePresentation
		local farm = self.stateStore:getFarm()
		if farm and farm.habitats and self.routePresentation then
			local nowMs = self.stateStore:getServerObservedAt() or 1000000
			for slotId = 1, 4 do
				local hab = farm.habitats[slotId]
				local inTransit = 0
				if hab and hab.reservedInTransit then
					inTransit = self.codec.ExactUInt.toSafeNumber(self.codec.ExactUInt.decode(hab.reservedInTransit))
				end
				local lastCount = self._lastInTransitCounts[slotId] or 0
				if inTransit > lastCount then
					local diff = inTransit - lastCount
					self._localHatchSerial += 1
					local gId = "hatch-state-" .. tostring(slotId) .. "-" .. tostring(self._localHatchSerial)
					local route = self.routePresentation:getRouteForSlot(slotId)
					local dur = (route and route.travelDuration) or 2.0
					self.routePresentation:spawnGroup(gId, diff, slotId, nowMs, dur)
				end
				self._lastInTransitCounts[slotId] = inTransit
			end
		end
	end)
	table.insert(self._unsubs, unsubState)

	-- Sync HUD on status changed
	local unsubStatus = self.stateStore:on("statusChanged", function(newStatus)
		if self.hud then
			self.hud:updateStatus(newStatus)
		end
	end)
	table.insert(self._unsubs, unsubStatus)

	-- Forward received quotes to HUD
	local unsubQuote = self.transport:onQuote(function(quoteView)
		if self.hud and type(self.hud.onQuoteReceived) == "function" then
			self.hud:onQuoteReceived(quoteView)
		end
	end)
	table.insert(self._unsubs, unsubQuote)
end

function ClientBootstrap:connect(requestId, callback)
	return self.transport:sendBootstrap(requestId, callback)
end
ClientBootstrap.start = ClientBootstrap.connect

function ClientBootstrap:hatchPress(callback)
	self._localHatchSerial += 1
	local localId = "hatch-press-" .. tostring(self._localHatchSerial)
	local nowMs = self.stateStore:getServerObservedAt() or 1000000
	local route = self.routePresentation:getRouteForSlot(1)
	local dur = (route and route.travelDuration) or 2.0

	local msg, inputSeq = self.intentControllers.hatch:press(function(res)
		if res and res.status == "ACCEPTED" then
			if self.routePresentation and self.routePresentation:getActiveGroupCount() == 0 then
				self.routePresentation:spawnGroup(localId, 1, 1, nowMs, dur)
			end
		end
		if callback then
			callback(res)
		end
	end)

	if self.routePresentation and self.routePresentation:getActiveGroupCount() == 0 then
		self.routePresentation:spawnGroup(localId, 1, 1, nowMs, dur)
	end

	return msg, inputSeq
end

function ClientBootstrap:hatchHoldStart(callback)
	return self.intentControllers.hatch:holdStart(callback)
end

function ClientBootstrap:hatchHoldRefresh(callback)
	return self.intentControllers.hatch:holdRefresh(callback)
end

function ClientBootstrap:hatchHoldStop(callback)
	return self.intentControllers.hatch:holdStop(callback)
end

function ClientBootstrap:requestQuote(target, callback)
	return self.intentControllers.shop:requestQuote(target, callback)
end

function ClientBootstrap:confirmPurchase(quoteView, callback)
	return self.intentControllers.shop:confirmPurchase(quoteView, callback)
end

function ClientBootstrap:buyResearch(researchId, callback)
	local target = { kind = "BuyResearch", args = { researchId = researchId, mode = "single" } }
	return self.intentControllers.shop:requestQuote(target, function(quoteView)
		if quoteView and quoteView.kind == "QuoteView" and quoteView.available then
			self.intentControllers.shop:confirmPurchase(quoteView, callback)
		else
			if callback then
				callback(quoteView or { status = "REJECTED", errorCode = "QUOTE_UNAVAILABLE" })
			end
		end
	end)
end

function ClientBootstrap:buyHabitat(slotId, habitatId, callback)
	local target = { kind = "BuyHabitat", args = { slotId = slotId, habitatId = habitatId } }
	return self.intentControllers.shop:requestQuote(target, function(quoteView)
		if quoteView and quoteView.kind == "QuoteView" and quoteView.available then
			self.intentControllers.shop:confirmPurchase(quoteView, callback)
		else
			if callback then
				callback(quoteView or { status = "REJECTED", errorCode = "QUOTE_UNAVAILABLE" })
			end
		end
	end)
end

function ClientBootstrap:buyVehicle(slotId, vehicleId, callback)
	local target = { kind = "BuyVehicle", args = { slotId = slotId, vehicleId = vehicleId } }
	return self.intentControllers.shop:requestQuote(target, function(quoteView)
		if quoteView and quoteView.kind == "QuoteView" and quoteView.available then
			self.intentControllers.shop:confirmPurchase(quoteView, callback)
		else
			if callback then
				callback(quoteView or { status = "REJECTED", errorCode = "QUOTE_UNAVAILABLE" })
			end
		end
	end)
end

function ClientBootstrap:upgradeEgg(targetEggIndex, callback)
	if not self.stateStore:isReady() then
		if callback then callback({ status = "REJECTED", errorCode = "SESSION_NOT_READY" }) end
		return nil, "SESSION_NOT_READY"
	end
	local rev = self.stateStore:getCommitRevision()
	local nowMs = self.stateStore:getServerObservedAt() or 1000000
	self._localUpgradeSerial = (self._localUpgradeSerial or 0) + 1
	local opId = "op-upgrade-egg-" .. tostring(nowMs) .. "-" .. tostring(self._localUpgradeSerial)
	local reqId = "req-upgrade-" .. tostring(nowMs) .. "-" .. tostring(self._localUpgradeSerial)
	local args = { targetEggIndex = targetEggIndex }
	return self.transport:sendPurchase("UpgradeEgg", reqId, opId, rev, args, callback)
end

function ClientBootstrap:update(nowMs)
	if self.routePresentation then
		self.routePresentation:update(nowMs)
	end
	if self.hud then
		self.hud:update()
	end
end
ClientBootstrap.tick = ClientBootstrap.update

function ClientBootstrap:receive(message)
	return self.transport:receive(message)
end

function ClientBootstrap:getState()
	return self.stateStore:getState()
end

function ClientBootstrap:getStatus()
	return self.stateStore:getStatus()
end

function ClientBootstrap:getFarm()
	return self.stateStore:getFarm()
end

function ClientBootstrap:getHUD()
	return self.hud
end

function ClientBootstrap:getPresentation()
	return self.routePresentation
end

function ClientBootstrap:getStore()
	return self.stateStore
end

function ClientBootstrap:getTransport()
	return self.transport
end

function ClientBootstrap:getIntentControllers()
	return self.intentControllers
end

function ClientBootstrap:destroy()
	for _, unsub in ipairs(self._unsubs) do
		unsub()
	end
	self._unsubs = {}
	if self.hud and type(self.hud.destroy) == "function" then
		self.hud:destroy()
	end
	if self.routePresentation and type(self.routePresentation.destroy) == "function" then
		self.routePresentation:destroy()
	end
	if self.intentControllers and type(self.intentControllers.destroy) == "function" then
		self.intentControllers:destroy()
	end
end

return table.freeze(ClientBootstrap)
