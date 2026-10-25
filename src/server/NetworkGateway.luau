--!nocheck
-- NetworkGateway for HatchTheEgg.
-- Validates client intents with ProtocolSchemas.validateClient,
-- enforces session admission gates, maintains player data isolation,
-- and routes commands to PlayerCoordinator and ViewProjector.

local function resolvePlayerId(player)
	if type(player) == "string" then return player end
	if type(player) == "number" then return tostring(player) end
	if type(player) == "table" or typeof(player) == "Instance" then
		return tostring(player.UserId or player.Name or player.playerId or player)
	end
	return tostring(player)
end

local function formatCommandResult(requestId, operationId, rawResult, currentRevision, streamId, nowMs)
	local status = rawResult.status
	local cmdResult = {
		protocolVersion = 1,
		kind = "CommandResult",
		requestId = requestId,
		operationId = operationId,
		status = status,
		currentCommitRevision = currentRevision,
		streamId = streamId,
		serverObservedAt = nowMs,
	}

	if status == "APPLIED" or status == "REPLAYED" or status == "REJECTED" then
		cmdResult.resultRevision = rawResult.resultRevision or currentRevision
		if status == "REJECTED" then
			local err = (rawResult.result and (rawResult.result.errorCode or rawResult.result.error)) or rawResult.errorCode or "OPERATION_REJECTED"
			cmdResult.result = {
				terminalStatus = "REJECTED",
				errorCode = err,
			}
		elseif status == "APPLIED" then
			cmdResult.result = rawResult.result
		elseif status == "REPLAYED" then
			local term = rawResult.terminalStatus or (rawResult.result and rawResult.result.terminalStatus) or "APPLIED"
			if term == "REJECTED" then
				local err = (rawResult.result and (rawResult.result.errorCode or rawResult.result.error)) or rawResult.errorCode or "OPERATION_REJECTED"
				cmdResult.result = {
					terminalStatus = "REJECTED",
					errorCode = err,
				}
			else
				cmdResult.result = rawResult.result
			end
		end
	else
		if rawResult.errorCode then
			cmdResult.errorCode = rawResult.errorCode
		end
	end

	return cmdResult
end

-- A ledger read can prove a lost write, but does not refresh the fenced actor.
-- The host must recover ownership/state before exposing that revision to the UI.
local function reconcileKnownResult(pData,operationId,result)
    local snapshots=pData.coordinator.snapshots()
    if result.status=="REPLAYED" and not snapshots.ready then
        return {status="UNKNOWN",errorCode="RECOVERY_REQUIRED"}
    end
    return result
end

local NetworkGateway = {}
NetworkGateway.__index = NetworkGateway

function NetworkGateway.new(deps)
	assert(type(deps) == "table", "INVALID_DEPS")
	assert(deps.viewProjector ~= nil, "VIEW_PROJECTOR_REQUIRED")
	assert(deps.farmActions ~= nil, "FARM_ACTIONS_REQUIRED")
	assert(deps.protocol ~= nil and type(deps.protocol.validateClient) == "function", "PROTOCOL_REQUIRED")
	assert(deps.clock ~= nil and type(deps.clock.utcNowMs) == "function", "CLOCK_REQUIRED")

	local codec = deps.codec or deps.viewProjector.codec
	local catalog = deps.catalog or deps.viewProjector.catalog
	local configRevision = deps.configRevision or deps.viewProjector.configRevision or "CANONICAL_V1"
	local autoDrain = if deps.autoDrain ~= nil then deps.autoDrain else true

	local self = setmetatable({
		viewProjector = deps.viewProjector,
		farmActions = deps.farmActions,
		protocol = deps.protocol,
		clock = deps.clock,
		codec = codec,
		catalog = catalog,
		configRevision = configRevision,
		autoDrain = autoDrain,
		players = {},
		quoteSerial = 0,
		streamSerial = 0,
		defaultPlayerId = nil,
	}, NetworkGateway)

	-- If a default coordinator is provided, register it
	if deps.coordinator then
		local snapshots = deps.coordinator.snapshots()
		local playerId = (snapshots.durable and snapshots.durable.meta and snapshots.durable.meta.playerId) or "player-1"
		self:registerPlayer(playerId, deps.coordinator)
		self.defaultPlayerId = playerId
	end

	self:_initHandlers()
	return self
end

function NetworkGateway:registerPlayer(playerId, coordinator, streamId)
	assert(type(playerId) == "string" and #playerId > 0, "INVALID_PLAYER_ID")
	assert(coordinator ~= nil and type(coordinator.snapshots) == "function", "INVALID_COORDINATOR")

	self.streamSerial += 1
	local stream = streamId or ("stream-" .. playerId .. "-" .. tostring(self.streamSerial))

	self.players[playerId] = {
		playerId = playerId,
		coordinator = coordinator,
		streamId = stream,
		streamSerial = self.streamSerial,
		viewSeq = "1",
		lastInputSeq = "0",
		previousOwnView = nil,
	}
	if not self.defaultPlayerId then
		self.defaultPlayerId = playerId
	end
end

function NetworkGateway:unregisterPlayer(playerId)
	assert(type(playerId) == "string", "INVALID_PLAYER_ID")
	self.players[playerId] = nil
	if self.defaultPlayerId == playerId then
		self.defaultPlayerId = next(self.players)
	end
end

function NetworkGateway:getCoordinator(playerId)
	local pData = self.players[playerId]
	return if pData then pData.coordinator else nil
end

function NetworkGateway:getPlayerState(playerId)
	return self.players[playerId]
end

function NetworkGateway:_nextQuoteSerial()
	self.quoteSerial += 1
	return self.quoteSerial
end

function NetworkGateway:_nextStreamSerial()
	self.streamSerial += 1
	return self.streamSerial
end

function NetworkGateway:_initHandlers()
	local handlers = {}

	handlers.Bootstrap = function(selfRef, playerId, message, pData)
		pData.streamSerial += 1
		pData.streamId = "stream-" .. playerId .. "-" .. tostring(pData.streamSerial)
		pData.viewSeq = "1"
		pData.lastInputSeq = "0"

		local nowMs = selfRef.clock.utcNowMs()
		local snapshots = pData.coordinator.snapshots()
		local profile = snapshots.working or snapshots.durable

		local snapshot = selfRef.viewProjector:projectPrivateView(
			profile,
			pData.streamId,
			pData.viewSeq,
			nowMs,
			message.requestId
		)
		pData.previousOwnView = snapshot.view
		return snapshot
	end

	handlers.RefreshState = function(selfRef, playerId, message, pData)
		if not pData.streamId then
			pData.streamSerial += 1
			pData.streamId = "stream-" .. playerId .. "-" .. tostring(pData.streamSerial)
			pData.viewSeq = "1"
		else
			pData.viewSeq = selfRef.codec.ExactUInt.encode(
				selfRef.codec.ExactUInt.add(
					selfRef.codec.ExactUInt.decode(pData.viewSeq),
					selfRef.codec.ExactUInt.fromSafeNumber(1)
				)
			)
		end

		local nowMs = selfRef.clock.utcNowMs()
		local snapshots = pData.coordinator.snapshots()
		local profile = snapshots.working or snapshots.durable

		local snapshot = selfRef.viewProjector:projectPrivateView(
			profile,
			pData.streamId,
			pData.viewSeq,
			nowMs,
			message.requestId
		)
		pData.previousOwnView = snapshot.view
		return snapshot
	end

	handlers.QuoteRequest = function(selfRef, playerId, message, pData)
		local nowMs = selfRef.clock.utcNowMs()
		local snapshots = pData.coordinator.snapshots()
		local profile = snapshots.working or snapshots.durable

		local quoteId = "quote-" .. tostring(selfRef:_nextQuoteSerial())
		local expectedRev = profile.meta.revision

		local quoteView = selfRef.farmActions.createQuote(
			profile,
			selfRef.catalog,
			message.target,
			message.requestId,
			expectedRev,
			quoteId,
			nowMs,
			selfRef.configRevision
		)
		return quoteView
	end

	handlers.OperationStatus = function(selfRef, playerId, message, pData)
		local nowMs = selfRef.clock.utcNowMs()
		local snapshots = pData.coordinator.snapshots()
		local profile = snapshots.working or snapshots.durable
		local streamId = pData.streamId or ("stream-" .. playerId)

		local queryResult = reconcileKnownResult(pData,message.operationId,pData.coordinator.query(message.operationId))
		local current=pData.coordinator.snapshots()
		profile=current.working or current.durable
		return formatCommandResult(
			message.requestId,
			message.operationId,
			queryResult,
			profile.meta.revision,
			streamId,
			nowMs
		)
	end

	local function handleMutation(selfRef, playerId, message, pData)
		local nowMs = selfRef.clock.utcNowMs()
		local snapshots = pData.coordinator.snapshots()
		local profile = snapshots.working or snapshots.durable
		local streamId = pData.streamId or ("stream-" .. playerId)

		local op = {
			operationId = message.operationId,
			kind = message.kind,
			expectedRevision = message.expectedRevision,
			args = message.args,
			quoteId = message.args.quoteId,
		}

		local submitResult = pData.coordinator.submit(op,{kind="TimeAdvance",targetMs=nowMs,budget=100})
		if submitResult.status == "NOT_ACCEPTED" then
			return {
				protocolVersion = 1,
				kind = "Admission",
				requestId = message.requestId,
				operationId = message.operationId,
				admission = "NOT_ACCEPTED",
				errorCode = submitResult.errorCode or "NOT_ACCEPTED",
			}
		end

		if submitResult.status == "REPLAYED" then
			return formatCommandResult(
				message.requestId,
				message.operationId,
				submitResult,
				profile.meta.revision,
				streamId,
				nowMs
			)
		end

		if selfRef.autoDrain then
			pData.coordinator.drain()
			local finalResult = pData.coordinator.resultOf(message.operationId)
			if finalResult.status == "UNKNOWN" then
				finalResult = reconcileKnownResult(pData,message.operationId,pData.coordinator.query(message.operationId))
			end
			local freshSnapshots = pData.coordinator.snapshots()
			local freshProfile = freshSnapshots.working or freshSnapshots.durable
			return formatCommandResult(
				message.requestId,
				message.operationId,
				finalResult,
				freshProfile.meta.revision,
				streamId,
				nowMs
			)
		else
			return formatCommandResult(
				message.requestId,
				message.operationId,
				submitResult,
				profile.meta.revision,
				streamId,
				nowMs
			)
		end
	end

	handlers.BuyResearch = handleMutation
	handlers.BuyHabitat = handleMutation
	handlers.BuyVehicle = handleMutation
	handlers.UpgradeEgg = handleMutation
    for _, kind in {"ClaimDailyGift","ClaimTrophy","FusePets","EquipPet","UnequipPet","TogglePetLock","BuyBoost","PurchaseProduct","Prestige"} do
        handlers[kind] = handleMutation
    end

	handlers.HatchPress = function(selfRef, playerId, message, pData)
		if pData.streamId ~= nil and message.streamId ~= pData.streamId then
			return {
				protocolVersion = 1,
				kind = "Admission",
				requestId = message.requestId,
				admission = "NOT_ACCEPTED",
				errorCode = "WRONG_STREAM",
			}
		end

		if pData.lastInputSeq ~= nil and selfRef.codec.ExactUInt.compare(
			selfRef.codec.ExactUInt.decode(message.inputSeq),
			selfRef.codec.ExactUInt.decode(pData.lastInputSeq)
		) <= 0 then
			return {
				protocolVersion = 1,
				kind = "Admission",
				requestId = message.requestId,
				admission = "NOT_ACCEPTED",
				errorCode = "STALE_INPUT",
			}
		end

		pData.lastInputSeq = message.inputSeq
		pData.coordinator.tick({
			kind = "HatchPress",
			packet = message,
			streamId = message.streamId,
			inputSeq = message.inputSeq,
		})

		if selfRef.autoDrain then
			pData.coordinator.drain()
		end

		return {
			status = "ACCEPTED",
			kind = "HatchPress",
			requestId = message.requestId,
			streamId = message.streamId,
			inputSeq = message.inputSeq,
		}
	end

	handlers.HatchInput = function(selfRef, playerId, message, pData)
		if pData.streamId ~= nil and message.streamId ~= pData.streamId then
			return {
				protocolVersion = 1,
				kind = "Admission",
				requestId = message.requestId,
				admission = "NOT_ACCEPTED",
				errorCode = "WRONG_STREAM",
			}
		end

		if pData.lastInputSeq ~= nil and selfRef.codec.ExactUInt.compare(
			selfRef.codec.ExactUInt.decode(message.inputSeq),
			selfRef.codec.ExactUInt.decode(pData.lastInputSeq)
		) <= 0 then
			return {
				protocolVersion = 1,
				kind = "Admission",
				requestId = message.requestId,
				admission = "NOT_ACCEPTED",
				errorCode = "STALE_INPUT",
			}
		end

		pData.lastInputSeq = message.inputSeq
		pData.coordinator.tick({
			kind = "HatchInput",
			packet = message,
			streamId = message.streamId,
			inputSeq = message.inputSeq,
			state = message.state,
		})

		if selfRef.autoDrain then
			pData.coordinator.drain()
		end

		return {
			status = "ACCEPTED",
			kind = "HatchInput",
			requestId = message.requestId,
			streamId = message.streamId,
			inputSeq = message.inputSeq,
			state = message.state,
		}
	end

	self.handlers = handlers
end

function NetworkGateway:handleRequest(playerOrId, message)
	local playerId = resolvePlayerId(playerOrId)
	if not playerId or playerId == "" then
		playerId = self.defaultPlayerId
	end

	-- 1. Client schema validation
	local valid, _ = self.protocol.validateClient(message)
	if not valid then
		local reqId = if type(message) == "table" and type(message.requestId) == "string"
			and #message.requestId > 0 and #message.requestId <= 96
			and string.match(message.requestId, "^[A-Za-z0-9_:.%- ]+$")
			then message.requestId
			else "invalid-request"

		local opId = if type(message) == "table" and type(message.operationId) == "string"
			and #message.operationId > 0 and #message.operationId <= 96
			and string.match(message.operationId, "^[A-Za-z0-9_:.%- ]+$")
			then message.operationId
			else nil

		local admission = {
			protocolVersion = 1,
			kind = "Admission",
			requestId = reqId,
			admission = "NOT_ACCEPTED",
			errorCode = "INVALID_REQUEST",
		}
		if opId then
			admission.operationId = opId
		end
		return admission
	end

	-- 2. Player isolation lookup
	local pData = self.players[playerId]
	if not pData or not pData.coordinator then
		local admission = {
			protocolVersion = 1,
			kind = "Admission",
			requestId = message.requestId,
			admission = "NOT_ACCEPTED",
			errorCode = "SESSION_NOT_FOUND",
		}
		if message.operationId then
			admission.operationId = message.operationId
		end
		return admission
	end

	-- 3. Admission readiness gate
	local snapshots = pData.coordinator.snapshots()
	if not snapshots.ready then
		local admission = {
			protocolVersion = 1,
			kind = "Admission",
			requestId = message.requestId,
			admission = "NOT_ACCEPTED",
			errorCode = "SESSION_NOT_READY",
		}
		if message.operationId then
			admission.operationId = message.operationId
		end
		return admission
	end

	-- 4. Dispatch to handler
	local handler = self.handlers[message.kind]
	if not handler then
		local admission = {
			protocolVersion = 1,
			kind = "Admission",
			requestId = message.requestId,
			admission = "NOT_ACCEPTED",
			errorCode = "INVALID_REQUEST",
		}
		if message.operationId then
			admission.operationId = message.operationId
		end
		return admission
	end

	local result = handler(self, playerId, message, pData)
	return result
end

-- Convenient aliases
NetworkGateway.dispatch = NetworkGateway.handleRequest
NetworkGateway.handle = NetworkGateway.handleRequest

function NetworkGateway:createPlayerDelta(playerOrId)
	local playerId = resolvePlayerId(playerOrId)
	local pData = self.players[playerId]
	if not pData or not pData.coordinator then return nil, "PLAYER_NOT_FOUND" end
	if not pData.streamId or not pData.previousOwnView then return nil, "NO_ACTIVE_STREAM" end

	local snapshots = pData.coordinator.snapshots()
	local profile = snapshots.working or snapshots.durable
	local baseViewSeq = pData.viewSeq

	pData.viewSeq = self.codec.ExactUInt.encode(
		self.codec.ExactUInt.add(
			self.codec.ExactUInt.decode(pData.viewSeq),
			self.codec.ExactUInt.fromSafeNumber(1)
		)
	)
	local nowMs = self.clock.utcNowMs()

	local currentSnapshot = self.viewProjector:projectPrivateView(
		profile,
		pData.streamId,
		pData.viewSeq,
		nowMs,
		"delta-req"
	)
	local delta = self.viewProjector:createDelta(
		pData.previousOwnView,
		currentSnapshot.view,
		pData.streamId,
		profile.meta.revision,
		baseViewSeq,
		pData.viewSeq,
		nowMs
	)
	pData.previousOwnView = currentSnapshot.view
	return delta
end

return table.freeze(NetworkGateway)
