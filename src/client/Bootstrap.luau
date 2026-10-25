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

local AudioController = resolve(function()
	return script.Parent.AudioController
end, "./AudioController")

local ClientBootstrap = {}
ClientBootstrap.__index = ClientBootstrap

function ClientBootstrap.new(deps)
	deps = deps or {}

	local codec = deps.codec or NumericCodec
	local protocol = deps.protocol or ProtocolSchemas.new(codec)
	local playerId = deps.playerId or "1"

	local audioController = deps.audioController or AudioController.new({
		sfxVolume = deps.sfxVolume,
		bgmVolume = deps.bgmVolume,
		muted = deps.muted,
	})

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
		audioController = audioController,
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
		audioController = audioController,
		wire = deps.wire,
		onClaimDailyGift = deps.onClaimDailyGift,
		onClaimTrophy = deps.onClaimTrophy,
		onFusePets = deps.onFusePets,
		onEquipPet = deps.onEquipPet,
		onUnequipPet = deps.onUnequipPet,
		onTogglePetLock = deps.onTogglePetLock,
		onBuyBoost = deps.onBuyBoost,
		onPurchaseProduct = deps.onPurchaseProduct,
        promptPurchase = deps.promptPurchase,
		_localHatchSerial = 0,
		_lastInTransitCounts = { 0, 0, 0, 0 },
		_unsubs = {},
	}, ClientBootstrap)

	if hud then
		if hud.onQuickBuyResearch == nil then
			hud.onQuickBuyResearch = function(researchId) self:buyResearch(researchId) end
		end
		if hud.onQuickBuyHabitat == nil then
			hud.onQuickBuyHabitat = function(slotId) self:buyHabitat(slotId or 1, "SHACK") end
		end
		if hud.onQuickBuyVehicle == nil then
			hud.onQuickBuyVehicle = function(slotId) self:buyVehicle(slotId or 1, "TRANSIT VAN") end
		end
		if hud.onUpgradeEggRequested == nil then
			hud.onUpgradeEggRequested = function(targetEggIndex) self:upgradeEgg(targetEggIndex) end
		end
		if hud.onClaimDailyGift == nil then
			hud.onClaimDailyGift = function() self:claimDailyGift() end
		end
		if hud.onClaimTrophy == nil then
			hud.onClaimTrophy = function(eggIdx, tierIdx) self:claimTrophy(eggIdx, tierIdx) end
		end
		if hud.onFusePets == nil then
			hud.onFusePets = function(baseId, matIds) self:fusePets(baseId, matIds) end
		end
		if hud.onEquipPet == nil then
			hud.onEquipPet = function(petId, slotIdx) self:equipPet(petId, slotIdx) end
		end
		if hud.onUnequipPet == nil then
			hud.onUnequipPet = function(slotIdx) self:unequipPet(slotIdx) end
		end
		if hud.onTogglePetLock == nil then
			hud.onTogglePetLock = function(petId) self:togglePetLock(petId) end
		end
		if hud.onBuyBoost == nil then
			hud.onBuyBoost = function(boostId) self:buyBoost(boostId) end
		end
		if hud.onPurchaseProduct == nil then
			hud.onPurchaseProduct = function(prodId) self:purchaseProduct(prodId) end
		end
	end

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
	if self.audioController and type(self.audioController.playSFX) == "function" then
		self.audioController:playSFX("cluck")
	end
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
	if self.audioController and type(self.audioController.playSFX) == "function" then
		self.audioController:playSFX("fanfare")
	end
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

-- Every action is an intent. Only a durable server response can report APPLIED.
function ClientBootstrap:_command(kind,args,callback)
    if not self.stateStore:isReady() or self.transport:getWire()==nil then
        local code=if not self.stateStore:isReady() then "SESSION_NOT_READY" else "TRANSPORT_UNAVAILABLE"
        if callback then callback({status="NOT_ACCEPTED",errorCode=code}) end
        return nil,code
    end
    self._actionSerial=(self._actionSerial or 0)+1
    local token=tostring(self.stateStore:getStreamId()).."-"..tostring(self._actionSerial)
    return self.transport:sendPurchase(kind,"req-action-"..token,"op-action-"..token,self.stateStore:getCommitRevision(),args,function(response)
        if response.kind=="CommandResult" and (response.status=="APPLIED" or response.status=="REPLAYED" or response.status=="REJECTED") then
            self.transport:sendRefreshState()
            if response.result and response.result.terminalStatus=="APPLIED" and response.result.actionKind=="PurchaseProduct" then
                local prompt=self.promptPurchase
                self._purchasePreviews=self._purchasePreviews or {}
                if not self._purchasePreviews[response.operationId] and type(prompt)=="function" and self.hud then
                    self._purchasePreviews[response.operationId]=true
                    self.hud:showPurchasePreview(response.result,function()
                        local farm=self.stateStore:getFarm()
                        local p=farm and farm.progress
                        if response.result.productId=="pro_permit" and (not p or p.paidRandomPolicy=="unknown" or (p.paidRandomPolicy=="allowed")~=response.result.paidBonusAvailable) then
                            self.hud:onActionResult({status="NOT_ACCEPTED",errorCode="POLICY_CHANGED"});return
                        end
                        prompt(response.result)
                    end)
                end
            end
        end
        if self.hud and type(self.hud.onActionResult)=="function" then self.hud:onActionResult(response) end
        if callback then callback(response) end
    end)
end
function ClientBootstrap:claimDailyGift(callback) return self:_command("ClaimDailyGift",{},callback) end
function ClientBootstrap:claimTrophy(eggIndex,tierIndex,callback) return self:_command("ClaimTrophy",{eggIndex=eggIndex,tierIndex=tierIndex},callback) end
function ClientBootstrap:fusePets(basePetId,materialIds,callback) return self:_command("FusePets",{basePetId=basePetId,materialIds=materialIds},callback) end
function ClientBootstrap:equipPet(petId,_slotIndex,callback) return self:_command("EquipPet",{petUid=petId},callback) end
function ClientBootstrap:unequipPet(slotIndex,callback) return self:_command("UnequipPet",{slotIndex=slotIndex},callback) end
function ClientBootstrap:togglePetLock(petId,callback) return self:_command("TogglePetLock",{petUid=petId},callback) end
function ClientBootstrap:buyBoost(boostId,callback) return self:_command("BuyBoost",{boostId=boostId},callback) end
function ClientBootstrap:purchaseProduct(productId,callback) return self:_command("PurchaseProduct",{productId=productId},callback) end
function ClientBootstrap:prestige(callback) return self:_command("Prestige",{},callback) end

function ClientBootstrap:hitDrone(droneId, callback)
	if self.audioController and type(self.audioController.playSFX) == "function" then
		self.audioController:playSFX("pop")
		self.audioController:playSFX("coin")
	end
	if type(self.onHitDrone) == "function" then
		return self.onHitDrone(droneId, callback)
	end
	local wireFn = self.wire or (self.transport and self.transport.wire)
	if wireFn then
		wireFn({
			protocolVersion = 1,
			kind = "HitDrone",
			droneId = droneId,
			requestId = "drone-" .. tostring(droneId),
		})
	end
	local res = { status = "APPLIED", droneId = droneId }
	if callback then callback(res) end
	return res
end

function ClientBootstrap:claimOffer(offerId, callback)
	if self.audioController and type(self.audioController.playSFX) == "function" then
		self.audioController:playSFX("pop")
		self.audioController:playSFX("coin")
	end
	if type(self.onClaimOffer) == "function" then
		return self.onClaimOffer(offerId, callback)
	end
	local wireFn = self.wire or (self.transport and self.transport.wire)
	if wireFn then
		wireFn({
			protocolVersion = 1,
			kind = "ClaimOffer",
			offerId = offerId,
			requestId = "offer-" .. tostring(offerId),
		})
	end
	local res = { status = "APPLIED", offerId = offerId }
	if callback then callback(res) end
	return res
end

function ClientBootstrap:hatchPetEgg(eggType, callback)
	if type(self.onHatchPetEgg) == "function" then
		return self.onHatchPetEgg(eggType, callback)
	end
	local wireFn = self.wire or (self.transport and self.transport.wire)
	if wireFn then
		wireFn({
			protocolVersion = 1,
			kind = "HatchPetEgg",
			eggType = eggType or "standard_egg",
			requestId = "hatch-" .. tostring(os.clock()),
		})
	end
	local res = { status = "PENDING", eggType = eggType or "standard_egg" }
	if callback then callback(res) end
	return res
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

function ClientBootstrap:getAudioController()
	return self.audioController
end

function ClientBootstrap:destroy()
	for _, unsub in ipairs(self._unsubs) do
		unsub()
	end
	self._unsubs = {}
	if self.audioController and type(self.audioController.destroy) == "function" then
		self.audioController:destroy()
	end
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
