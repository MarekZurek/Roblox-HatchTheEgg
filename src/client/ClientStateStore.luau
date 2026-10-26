--!nocheck
-- ClientStateStore for HatchTheEgg.
-- Client-side store of the authoritative player state view.
--
-- CRITICAL INVARIANT: The client is strictly a mirror projection.
-- It NEVER independently computes cash accrual, spawns authoritative chickens,
-- or mutates authoritative quantities. State changes only occur via server
-- StateSnapshot and StateDelta messages.

local LIFECYCLE = table.freeze({
	CONNECTING = "CONNECTING",
	LOADING = "LOADING",
	READY = "READY",
	RESYNCING = "RESYNCING",
	SESSION_LOST = "SESSION_LOST",
})

local function deepCopy(t)
	if type(t) ~= "table" then return t end
	local copy = {}
	for k, v in t do
		copy[k] = if type(v) == "table" then deepCopy(v) else v
	end
	return copy
end

local function freezeTree(t)
	for _, value in t do
		if type(value) == "table" then freezeTree(value) end
	end
	return table.freeze(t)
end

local ClientStateStore = {}
ClientStateStore.__index = ClientStateStore
ClientStateStore.LIFECYCLE = LIFECYCLE

function ClientStateStore.new(deps)
	assert(type(deps) == "table", "INVALID_DEPS")
	assert(deps.transport ~= nil, "TRANSPORT_REQUIRED")
	assert(deps.codec ~= nil and deps.codec.ExactUInt ~= nil, "CODEC_REQUIRED")

	local self = setmetatable({
		transport = deps.transport,
		codec = deps.codec,
		status = LIFECYCLE.CONNECTING,
		streamId = nil,
		viewSeq = nil,
		commitRevision = nil,
		serverObservedAt = nil,
		audience = nil,
		farm = nil,
		resyncSerial = 0,
		_listeners = {},
		_unsubs = {},
	}, ClientStateStore)

	-- Automatically wire up to transport snapshot and delta events
	if self.transport ~= nil then
		if type(self.transport.onSnapshot) == "function" then
			table.insert(self._unsubs, self.transport:onSnapshot(function(snapshot)
				self:applySnapshot(snapshot)
			end))
		end
		if type(self.transport.onDelta) == "function" then
			table.insert(self._unsubs, self.transport:onDelta(function(delta)
				self:applyDelta(delta)
			end))
		end
	end

	return self
end

-- ============================================================================
-- Lifecycle and State Accessors
-- ============================================================================

function ClientStateStore:getStatus()
	return self.status
end

function ClientStateStore:isReady()
	return self.status == LIFECYCLE.READY
end

function ClientStateStore:setStatus(newStatus)
	assert(LIFECYCLE[newStatus] ~= nil, "INVALID_LIFECYCLE_STATUS: " .. tostring(newStatus))
	local prev = self.status
	if prev ~= newStatus then
		self.status = newStatus
		self:_emit("statusChanged", newStatus, prev)
	end
end

function ClientStateStore:getStreamId()
	return self.streamId
end

function ClientStateStore:getViewSeq()
	return self.viewSeq
end

function ClientStateStore:getCommitRevision()
	return self.commitRevision
end

function ClientStateStore:getServerObservedAt()
	return self.serverObservedAt
end

function ClientStateStore:getAudience()
	return self.audience
end

function ClientStateStore:getFarm()
	return if self.farm ~= nil then deepCopy(self.farm) else nil
end

-- Shared presentation snapshot: copy only once per accepted view change.
-- Keep getFarm() as the defensive, independently mutable public copy API.
function ClientStateStore:getPresentationFarm()
	if self.farm == nil then return nil end
	if self._presentationFarm == nil then
		self._presentationFarm = freezeTree(deepCopy(self.farm))
	end
	return self._presentationFarm
end

function ClientStateStore:getState()
	return {
		status = self.status,
		streamId = self.streamId,
		viewSeq = self.viewSeq,
		commitRevision = self.commitRevision,
		serverObservedAt = self.serverObservedAt,
		audience = self.audience,
		farm = self:getFarm(),
	}
end

-- ============================================================================
-- Snapshot & Delta Application
-- ============================================================================

function ClientStateStore:applySnapshot(snapshot)
	assert(type(snapshot) == "table", "INVALID_SNAPSHOT")
	assert(snapshot.kind == "StateSnapshot", "NOT_A_SNAPSHOT")
	assert(type(snapshot.view) == "table", "SNAPSHOT_VIEW_REQUIRED")
	assert(type(snapshot.view.farm) == "table", "SNAPSHOT_FARM_REQUIRED")

	self.streamId = snapshot.streamId
	self.viewSeq = snapshot.viewSeq
	self.commitRevision = snapshot.commitRevision
	self.serverObservedAt = snapshot.serverObservedAt
	self.audience = snapshot.view.audience
	self.farm = deepCopy(snapshot.view.farm)
	self._presentationFarm = nil

	local prevStatus = self.status
	if self.farm.lifecycle == "sessionLost" then
		self.status = LIFECYCLE.SESSION_LOST
	else
		self.status = LIFECYCLE.READY
	end

	if prevStatus ~= self.status then
		self:_emit("statusChanged", self.status, prevStatus)
	end

	self:_emit("snapshotApplied", snapshot)
	self:_emit("stateChanged", "snapshot", snapshot)
	return true
end

function ClientStateStore:applyDelta(delta)
	assert(type(delta) == "table", "INVALID_DELTA")
	assert(delta.kind == "StateDelta", "NOT_A_DELTA")

	-- 1. Stream consistency check
	if self.streamId == nil or delta.streamId ~= self.streamId then
		self:setStatus(LIFECYCLE.RESYNCING)
		self:_requestResync()
		return false, "STREAM_MISMATCH"
	end

	-- 2. Monotonicity and continuity check of viewSeq
	local ExactUInt = self.codec.ExactUInt
	local currentSeq = ExactUInt.decode(self.viewSeq)
	local baseSeq = ExactUInt.decode(delta.baseViewSeq)
	local deltaSeq = ExactUInt.decode(delta.viewSeq)

	local cmpBase = ExactUInt.compare(baseSeq, currentSeq)

	if cmpBase ~= 0 then
		if cmpBase > 0 then
			-- Sequence gap detected! (delta.baseViewSeq > currentViewSeq)
			self:setStatus(LIFECYCLE.RESYNCING)
			self:_requestResync()
			return false, "GAP_DETECTED"
		else
			-- delta.baseViewSeq < currentViewSeq
			local cmpDeltaView = ExactUInt.compare(deltaSeq, currentSeq)
			if cmpDeltaView <= 0 then
				-- Outdated / stale delta (delta.viewSeq <= currentViewSeq): safely ignored, no rollback
				return false, "OUTDATED_DELTA"
			else
				-- delta.baseViewSeq is in the past but delta.viewSeq jumps past currentViewSeq (inconsistent base)
				self:setStatus(LIFECYCLE.RESYNCING)
				self:_requestResync()
				return false, "INCONSISTENT_BASE"
			end
		end
	end

	-- 3. Exact continuity: delta.baseViewSeq == currentViewSeq
	-- ProtocolSchemas section replacement: replace whole indicated sections in farm
	local farmChanges = delta.changes and delta.changes.farm
	if farmChanges ~= nil and self.farm ~= nil then
		self._presentationFarm = nil
		for sectionKey, sectionValue in farmChanges do
			self.farm[sectionKey] = deepCopy(sectionValue)
		end
	end

	-- Update sequence and revisions
	self.viewSeq = delta.viewSeq
	self.commitRevision = delta.commitRevision
	if delta.serverObservedAt ~= nil then
		self.serverObservedAt = delta.serverObservedAt
	end

	if self.farm ~= nil and self.farm.lifecycle == "sessionLost" then
		self:setStatus(LIFECYCLE.SESSION_LOST)
	end

	self:_emit("deltaApplied", delta)
	self:_emit("stateChanged", "delta", delta)
	return true
end

-- ============================================================================
-- Resync Logic
-- ============================================================================

function ClientStateStore:_requestResync()
	self.resyncSerial += 1
	local reqId = "resync-" .. tostring(self.resyncSerial)
	if self.transport ~= nil and type(self.transport.sendRefreshState) == "function" then
		self.transport:sendRefreshState(reqId)
	end
	self:_emit("resyncRequested", reqId)
	return reqId
end

function ClientStateStore:requestResync()
	self:setStatus(LIFECYCLE.RESYNCING)
	return self:_requestResync()
end

-- ============================================================================
-- Event System
-- ============================================================================

function ClientStateStore:on(eventName, callback)
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

function ClientStateStore:_emit(eventName, ...)
	local list = self._listeners[eventName]
	if list ~= nil then
		-- Copy list to handle potential unsubscriptions during callback execution
		local copy = table.clone(list)
		for _, cb in ipairs(copy) do
			cb(...)
		end
	end
end

function ClientStateStore:onStateChanged(callback)
	return self:on("stateChanged", callback)
end

function ClientStateStore:onSnapshotApplied(callback)
	return self:on("snapshotApplied", callback)
end

function ClientStateStore:onDeltaApplied(callback)
	return self:on("deltaApplied", callback)
end

function ClientStateStore:onStatusChanged(callback)
	return self:on("statusChanged", callback)
end

function ClientStateStore:onResyncRequested(callback)
	return self:on("resyncRequested", callback)
end

function ClientStateStore:destroy()
	for _, unsub in ipairs(self._unsubs) do
		unsub()
	end
	self._unsubs = {}
	self._listeners = {}
end

return table.freeze(ClientStateStore)
