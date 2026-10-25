--!nocheck
-- IntentControllers for HatchTheEgg.
-- Handles player input and intent translation to protocol messages:
-- 1. HatchController: generates monotonic inputSeq (ExactUInt), sends HatchPress and HatchInput (start/refresh/stop).
-- 2. ShopController: requests quotes, caches QuoteView, confirms purchases with expected revision and operationId generation.
--
-- CRITICAL ARCHITECTURAL INVARIANT:
-- Intent controllers NEVER modify authoritative state, grant resources, or perform local simulation.
-- All actions are strictly sent through ClientTransport and validated by the authoritative server.

local IntentControllers = {}
IntentControllers.__index = IntentControllers

-- ============================================================================
-- HatchController
-- ============================================================================

local HatchController = {}
HatchController.__index = HatchController

function HatchController.new(deps)
	assert(type(deps) == "table", "INVALID_DEPS")
	assert(deps.transport ~= nil, "TRANSPORT_REQUIRED")
	assert(deps.stateStore ~= nil, "STATE_STORE_REQUIRED")
	assert(deps.codec ~= nil and deps.codec.ExactUInt ~= nil, "CODEC_REQUIRED")

	local self = setmetatable({
		transport = deps.transport,
		stateStore = deps.stateStore,
		codec = deps.codec,
		_inputSeq = deps.codec.ExactUInt.fromSafeNumber(0),
	}, HatchController)

	return self
end

function HatchController:_nextInputSeq()
	self._inputSeq = self.codec.ExactUInt.add(self._inputSeq, self.codec.ExactUInt.fromSafeNumber(1))
	return self.codec.ExactUInt.encode(self._inputSeq)
end

function HatchController:getInputSeq()
	return self.codec.ExactUInt.encode(self._inputSeq)
end

function HatchController:press(callback)
	local streamId = self.stateStore:getStreamId()
	assert(streamId ~= nil, "NO_STREAM_ID")

	local inputSeq = self:_nextInputSeq()
	local msg = self.transport:sendHatchPress(nil, streamId, inputSeq, callback)
	return msg, inputSeq
end

function HatchController:holdStart(callback)
 self._holdingStream=self.stateStore:getStreamId();self._lastHoldRefresh=nil
	local streamId = self.stateStore:getStreamId()
	assert(streamId ~= nil, "NO_STREAM_ID")

	local inputSeq = self:_nextInputSeq()
	local msg = self.transport:sendHatchInput(nil, streamId, inputSeq, "start", callback)
	return msg, inputSeq
end

function HatchController:holdRefresh(callback)
	local streamId = self.stateStore:getStreamId()
	assert(streamId ~= nil, "NO_STREAM_ID")

	local inputSeq = self:_nextInputSeq()
	local msg = self.transport:sendHatchInput(nil, streamId, inputSeq, "refresh", callback)
	return msg, inputSeq
end

function HatchController:holdStop(callback)
 self._holdingStream=nil;self._lastHoldRefresh=nil
	local streamId = self.stateStore:getStreamId()
	assert(streamId ~= nil, "NO_STREAM_ID")

	local inputSeq = self:_nextInputSeq()
	local msg = self.transport:sendHatchInput(nil, streamId, inputSeq, "stop", callback)
	return msg, inputSeq
end

function HatchController:update(nowMs)
 if not self._holdingStream then return end
 if not self.stateStore:isReady() or self.stateStore:getStreamId()~=self._holdingStream then self._holdingStream=nil;return end
 if self._lastHoldRefresh==nil or nowMs-self._lastHoldRefresh>=500 then self._lastHoldRefresh=nowMs;self:holdRefresh() end
end

-- ============================================================================
-- ShopController
-- ============================================================================

local ShopController = {}
ShopController.__index = ShopController

function ShopController.new(deps)
	assert(type(deps) == "table", "INVALID_DEPS")
	assert(deps.transport ~= nil, "TRANSPORT_REQUIRED")
	assert(deps.stateStore ~= nil, "STATE_STORE_REQUIRED")
	assert(deps.codec ~= nil, "CODEC_REQUIRED")

	local self = setmetatable({
		transport = deps.transport,
		stateStore = deps.stateStore,
		codec = deps.codec,
		_quotes = {},
		_latestQuote = nil,
		_opSerial = 0,
		_unsubQuote = nil,
	}, ShopController)

	-- Automatically buffer any quote received on transport
	if self.transport ~= nil and type(self.transport.onQuote) == "function" then
		self._unsubQuote = self.transport:onQuote(function(quoteView)
			self:_cacheQuote(quoteView)
		end)
	end

	return self
end

function ShopController:_targetKey(target)
	if type(target) ~= "table" or type(target.kind) ~= "string" or type(target.args) ~= "table" then
		return nil
	end
	local kind = target.kind
	local args = target.args
	if kind == "BuyResearch" then
		return "BuyResearch:" .. tostring(args.researchId)
	elseif kind == "BuyHabitat" then
		return "BuyHabitat:" .. tostring(args.slotId) .. ":" .. tostring(args.habitatId)
	elseif kind == "BuyVehicle" then
		return "BuyVehicle:" .. tostring(args.slotId) .. ":" .. tostring(args.vehicleId)
	end
	return nil
end

function ShopController:_cacheQuote(quoteView)
	if type(quoteView) ~= "table" or quoteView.kind ~= "QuoteView" then
		return
	end
	self._latestQuote = quoteView
	local key = self:_targetKey(quoteView.target)
	if key ~= nil then
		self._quotes[key] = quoteView
	end
end

function ShopController:getLatestQuote()
	return self._latestQuote
end

function ShopController:getCachedQuote(targetOrKey)
	if type(targetOrKey) == "string" then
		return self._quotes[targetOrKey]
	elseif type(targetOrKey) == "table" then
		local key = self:_targetKey(targetOrKey)
		if key ~= nil then
			return self._quotes[key]
		end
		return nil
	end
	return self._latestQuote
end

function ShopController:getAllCachedQuotes()
	local copy = {}
	for k, v in pairs(self._quotes) do
		copy[k] = v
	end
	return copy
end

function ShopController:requestQuote(target, callback)
	assert(type(target) == "table", "TARGET_REQUIRED")
	assert(type(target.kind) == "string", "TARGET_KIND_REQUIRED")

	local wrappedCallback
	if callback ~= nil then
		wrappedCallback = function(response)
			if type(response) == "table" and response.kind == "QuoteView" then
				self:_cacheQuote(response)
			end
			callback(response)
		end
	end

	return self.transport:sendQuoteRequest(nil, target, wrappedCallback)
end

function ShopController:confirmPurchase(quoteView, callback)
	assert(type(quoteView) == "table", "QUOTE_VIEW_REQUIRED")
	assert(quoteView.kind == "QuoteView", "NOT_A_QUOTE_VIEW")
	assert(type(quoteView.quoteId) == "string", "QUOTE_ID_REQUIRED")
	assert(type(quoteView.target) == "table", "QUOTE_TARGET_REQUIRED")
	assert(type(quoteView.target.kind) == "string", "QUOTE_TARGET_KIND_REQUIRED")
	assert(type(quoteView.target.args) == "table", "QUOTE_TARGET_ARGS_REQUIRED")

	-- 1. Check quote availability
	if not quoteView.available then
		local reason = quoteView.blockedReason or "QUOTE_NOT_AVAILABLE"
		if callback ~= nil then
			callback({
				status = "REJECTED",
				errorCode = reason,
			})
		end
		return false, reason
	end

	-- 2. Expiration check (against serverObservedAt if known)
	if self.stateStore ~= nil then
		local serverObservedAt = self.stateStore:getServerObservedAt()
		if serverObservedAt ~= nil and quoteView.expiresAt ~= nil and quoteView.expiresAt <= serverObservedAt then
			local reason = "QUOTE_EXPIRED"
			if callback ~= nil then
				callback({
					status = "REJECTED",
					errorCode = reason,
				})
			end
			return false, reason
		end

		-- 3. Expected revision check
		local currentRevision = self.stateStore:getCommitRevision()
		if currentRevision ~= nil and quoteView.expectedRevision ~= nil and currentRevision ~= quoteView.expectedRevision then
			local reason = "REVISION_MISMATCH"
			if callback ~= nil then
				callback({
					status = "REJECTED",
					errorCode = reason,
				})
			end
			return false, reason
		end
	end

	-- 4. Generate operationId
	self._opSerial += 1
	local operationId = "op-shop-" .. tostring(self.stateStore:getStreamId()) .. "-" .. tostring(self._opSerial)

	-- 5. Prepare mutation args with quoteId
	local args = table.clone(quoteView.target.args)
	args.quoteId = quoteView.quoteId

	-- 6. Send purchase command via transport
	local expectedRevision = quoteView.expectedRevision
	local msg = self.transport:sendPurchase(
		quoteView.target.kind,
		nil,
		operationId,
		expectedRevision,
		args,
		callback
	)

	return true, operationId, msg
end

function ShopController:destroy()
	if self._unsubQuote ~= nil then
		self._unsubQuote()
		self._unsubQuote = nil
	end
	self._quotes = {}
	self._latestQuote = nil
end

-- ============================================================================
-- IntentControllers Constructor
-- ============================================================================

function IntentControllers.new(deps)
	assert(type(deps) == "table", "INVALID_DEPS")
	assert(deps.transport ~= nil, "TRANSPORT_REQUIRED")
	assert(deps.stateStore ~= nil, "STATE_STORE_REQUIRED")
	assert(deps.codec ~= nil, "CODEC_REQUIRED")

	local hatch = HatchController.new(deps)
	local shop = ShopController.new(deps)

	local self = setmetatable({
		transport = deps.transport,
		stateStore = deps.stateStore,
		codec = deps.codec,
		hatch = hatch,
		hatchController = hatch,
		shop = shop,
		shopController = shop,
	}, IntentControllers)

	return self
end

function IntentControllers:destroy()
	if self.shop ~= nil and type(self.shop.destroy) == "function" then
		self.shop:destroy()
	end
end

IntentControllers.HatchController = HatchController
IntentControllers.ShopController = ShopController

return table.freeze(IntentControllers)
