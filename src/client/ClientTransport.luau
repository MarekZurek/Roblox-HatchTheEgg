--!nocheck
-- ClientTransport for HatchTheEgg.
-- Network transport abstraction for the client, working with test wire in Lune
-- and in the future with RemoteEvents/RemoteFunctions in Roblox Studio.
-- Handles sending client messages compliant with ProtocolSchemas and
-- correlating incoming server responses by requestId and operationId.

local ClientTransport = {}
ClientTransport.__index = ClientTransport

function ClientTransport.new(deps)
	assert(type(deps) == "table", "INVALID_DEPS")
	assert(deps.protocol ~= nil and type(deps.protocol.validateClient) == "function", "PROTOCOL_REQUIRED")

	local self = setmetatable({
		protocol = deps.protocol,
		wire = deps.wire,
		playerId = deps.playerId or "player-1",
		_reqSerial = 0,
		_subscribers = {},
		_kindSubscribers = {},
		_pendingRequests = {},
		_pendingOperations = {},
		_operationRequests = {},
	}, ClientTransport)

	return self
end

function ClientTransport:setWire(wire)
	self.wire = wire
end

function ClientTransport:getWire()
	return self.wire
end

function ClientTransport:setPlayerId(playerId)
	self.playerId = playerId
end

function ClientTransport:_nextRequestId(prefix)
	self._reqSerial += 1
	return (prefix or "req") .. "-" .. tostring(self._reqSerial)
end

function ClientTransport:_send(msg)
	local valid, err = self.protocol.validateClient(msg)
	if not valid then
		error("INVALID_CLIENT_MESSAGE: " .. tostring(err), 2)
	end

	if self.wire ~= nil then
		if type(self.wire) == "function" then
			self.wire(msg)
		elseif type(self.wire) == "table" then
			if type(self.wire.send) == "function" then
				self.wire:send(msg)
			elseif type(self.wire.handleRequest) == "function" then
				local res = self.wire:handleRequest(self.playerId or "player-1", msg)
				if res then
					self:receive(res)
				end
			end
		end
	end
end

-- ============================================================================
-- Client Message Senders
-- ============================================================================

function ClientTransport:sendBootstrap(requestId, callback)
	local reqId = requestId or self:_nextRequestId("boot")
	local msg = {
		protocolVersion = 1,
		requestId = reqId,
		kind = "Bootstrap",
	}
	if callback then
		self:registerRequestCallback(reqId, callback)
	end
	self:_send(msg)
	return msg
end

function ClientTransport:sendRefreshState(requestId, callback)
	local reqId = requestId or self:_nextRequestId("refresh")
	local msg = {
		protocolVersion = 1,
		requestId = reqId,
		kind = "RefreshState",
	}
	if callback then
		self:registerRequestCallback(reqId, callback)
	end
	self:_send(msg)
	return msg
end

function ClientTransport:sendQuoteRequest(requestId, target, callback)
	local reqId = requestId or self:_nextRequestId("quote")
	local msg = {
		protocolVersion = 1,
		requestId = reqId,
		kind = "QuoteRequest",
		target = target,
	}
	if callback then
		self:registerRequestCallback(reqId, callback)
	end
	self:_send(msg)
	return msg
end

function ClientTransport:sendOperationStatus(requestId, operationId, callback)
	local reqId = requestId or self:_nextRequestId("status")
	local msg = {
		protocolVersion = 1,
		requestId = reqId,
		kind = "OperationStatus",
		operationId = operationId,
	}
	if callback then
		self:registerRequestCallback(reqId, callback)
	end
	self:_send(msg)
	return msg
end

function ClientTransport:sendPurchase(kind, requestId, operationId, expectedRevision, args, callback)
	local reqId = requestId or self:_nextRequestId("purchase")
	local msg = {
		protocolVersion = 1,
		requestId = reqId,
		kind = kind,
		operationId = operationId,
		expectedRevision = expectedRevision,
		args = args,
	}
	if callback then
		self:registerRequestCallback(reqId, callback)
		if operationId then
			self._operationRequests[operationId] = reqId
			self:registerOperationCallback(operationId, callback)
		end
	end
	self:_send(msg)
	return msg
end

function ClientTransport:sendHatchPress(requestId, streamId, inputSeq, callback)
	local reqId = requestId or self:_nextRequestId("press")
	local msg = {
		protocolVersion = 1,
		requestId = reqId,
		kind = "HatchPress",
		streamId = streamId,
		inputSeq = inputSeq,
	}
	if callback then
		self:registerRequestCallback(reqId, callback)
	end
	self:_send(msg)
	return msg
end

function ClientTransport:sendHatchInput(requestId, streamId, inputSeq, state, callback)
	local reqId = requestId or self:_nextRequestId("input")
	local msg = {
		protocolVersion = 1,
		requestId = reqId,
		kind = "HatchInput",
		streamId = streamId,
		inputSeq = inputSeq,
		state = state,
	}
	if callback then
		self:registerRequestCallback(reqId, callback)
	end
	self:_send(msg)
	return msg
end

-- ============================================================================
-- Server Message Reception & Correlation
-- ============================================================================

function ClientTransport:receive(message)
	if type(message) ~= "table" then
		return false, "MESSAGE_MUST_BE_TABLE"
	end

	local valid, err = self.protocol.validateServer(message)
	if not valid then
		if message.status == "ACCEPTED" and (message.kind == "HatchPress" or message.kind == "HatchInput") then
			valid = true
		else
			return false, "INVALID_SERVER_MESSAGE: " .. tostring(err)
		end
	end

	local notified = {}
	local function notify(cb, msg)
		if not notified[cb] then
			notified[cb] = true
			cb(msg)
		end
	end

	-- 1. Correlation by requestId
	if message.requestId ~= nil and self._pendingRequests[message.requestId] ~= nil then
		local callbacks = self._pendingRequests[message.requestId]
		self._pendingRequests[message.requestId] = nil
		for _, cb in ipairs(callbacks) do
			notify(cb, message)
		end
	end

	-- 2. Correlation by operationId (CommandResult or Admission)
	local unrelatedAdmission = message.kind == "Admission" and self._operationRequests[message.operationId] ~= nil
        and self._operationRequests[message.operationId] ~= message.requestId
	if not unrelatedAdmission and message.operationId ~= nil and self._pendingOperations[message.operationId] ~= nil then
		local callbacks = self._pendingOperations[message.operationId]
		local isTerminal = true
		if message.kind == "CommandResult" and (message.status == "PENDING" or message.status == "UNKNOWN") then
			isTerminal = false
		end

		if isTerminal then
			self._pendingOperations[message.operationId] = nil
			self._operationRequests[message.operationId] = nil
		end

		for _, cb in ipairs(callbacks) do
			notify(cb, message)
		end
	end

	-- 3. General message subscribers
	for _, cb in ipairs(self._subscribers) do
		notify(cb, message)
	end

	-- 4. Kind-specific subscribers
	local kindCbs = self._kindSubscribers[message.kind]
	if kindCbs ~= nil then
		for _, cb in ipairs(kindCbs) do
			notify(cb, message)
		end
	end

	return true, message
end

-- Aliases
ClientTransport.onServerMessage = ClientTransport.receive
ClientTransport.dispatch = ClientTransport.receive

-- ============================================================================
-- Subscription & Correlation Registration
-- ============================================================================

function ClientTransport:on(kind, callback)
	assert(type(kind) == "string", "INVALID_KIND")
	assert(type(callback) == "function", "INVALID_CALLBACK")

	if not self._kindSubscribers[kind] then
		self._kindSubscribers[kind] = {}
	end
	table.insert(self._kindSubscribers[kind], callback)

	return function()
		local list = self._kindSubscribers[kind]
		if not list then return end
		local idx = table.find(list, callback)
		if idx then
			table.remove(list, idx)
		end
		if #list == 0 then
			self._kindSubscribers[kind] = nil
		end
	end
end

function ClientTransport:onMessage(callback)
	assert(type(callback) == "function", "INVALID_CALLBACK")
	table.insert(self._subscribers, callback)

	return function()
		local idx = table.find(self._subscribers, callback)
		if idx then
			table.remove(self._subscribers, idx)
		end
	end
end

function ClientTransport:onSnapshot(callback)
	return self:on("StateSnapshot", callback)
end

function ClientTransport:onDelta(callback)
	return self:on("StateDelta", callback)
end

function ClientTransport:onQuote(callback)
	return self:on("QuoteView", callback)
end

function ClientTransport:onCommandResult(callback)
	return self:on("CommandResult", callback)
end

function ClientTransport:onAdmission(callback)
	return self:on("Admission", callback)
end

function ClientTransport:registerRequestCallback(requestId, callback)
	assert(type(requestId) == "string", "INVALID_REQUEST_ID")
	assert(type(callback) == "function", "INVALID_CALLBACK")

	if not self._pendingRequests[requestId] then
		self._pendingRequests[requestId] = {}
	end
	table.insert(self._pendingRequests[requestId], callback)

	return function()
		local list = self._pendingRequests[requestId]
		if not list then return end
		local idx = table.find(list, callback)
		if idx then table.remove(list, idx) end
		if #list == 0 then self._pendingRequests[requestId] = nil end
	end
end

function ClientTransport:registerOperationCallback(operationId, callback)
	assert(type(operationId) == "string", "INVALID_OPERATION_ID")
	assert(type(callback) == "function", "INVALID_CALLBACK")

	if not self._pendingOperations[operationId] then
		self._pendingOperations[operationId] = {}
	end
	table.insert(self._pendingOperations[operationId], callback)

	return function()
		local list = self._pendingOperations[operationId]
		if not list then return end
		local idx = table.find(list, callback)
		if idx then table.remove(list, idx) end
		if #list == 0 then self._pendingOperations[operationId] = nil end
	end
end

ClientTransport.expectRequest = ClientTransport.registerRequestCallback
ClientTransport.expectOperation = ClientTransport.registerOperationCallback

return table.freeze(ClientTransport)
