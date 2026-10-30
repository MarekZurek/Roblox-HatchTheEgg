--!nocheck
-- Server-authoritative plate hatching regressions (approved plate adaptation).
-- Scope:
-- 1. Standing on the 3D hatch pressure plate hatches up to 30 chickens/second, counted from the
--    server-observed entry and limited by real stock and real vacancies.
-- 2. Only the server can observe presence: a client message, count, dt or claimed position can
--    never create plate intent, and no extra remote exists for it.
-- 3. Manual HatchPress and the Epic Hold-to-Hatch keep their existing meanings; plate intent and
--    hold intent stay distinct.
-- 4. Entry/exit, bounded lease/catch-up, reset, reconnect/ownership generation, arrivals,
--    30/s count integrity and group ids.
-- Fixtures below are isolated test profiles, not approved launch balance.
local B = require("../../src/server/Bootstrap")
local C = require("../../src/shared/NumericCodec")
local D = require("../../src/server/PersistenceData")
local S = require("../../src/server/ProfileSchema").new(C)
local Schemas = require("../../src/shared/ProtocolSchemas")
local Protocol = Schemas.new(C)
local fs, serde = require("@lune/fs"), require("@lune/serde")

local ORIGIN = 10000000
local assertions = 0
local function eq(a, b, label)
	assertions += 1
	assert(a == b, (label or "") .. " expected " .. tostring(b) .. " got " .. tostring(a))
end
local function ok(cond, label)
	assertions += 1
	assert(cond, label or "condition failed")
end

local function harness(mutate)
	local h = { now = ORIGIN, records = {} }
	h.store = {
		read = function(key) return true, h.records[key] and D.copy(h.records[key]) end,
		update = function(key, fn)
			local next = fn(h.records[key] and D.copy(h.records[key]))
			if next then h.records[key] = D.copy(next) end
			return true, next and D.copy(next)
		end,
	}
	h.b = B.new({
		storageMode = "INTERNAL_TEST_ONLY",
		store = h.store,
		clock = {
			utcNowMs = function() return h.now end,
			elapsedNowSeconds = function() return (h.now - ORIGIN) / 1000 end,
		},
	})
	local p = S.createReference("1", ORIGIN)
	p.farm.cash = "1000000"
	if mutate then mutate(p) end
	eq(h.b:playerJoined("1", p).status, "JOINED", "session joined")
	function h.farm()
		local ss = h.b:getCoordinator("1").snapshots()
		return (ss.working or ss.durable).farm
	end
	function h.presence() return h.b:getPlatePresence("1") end
	function h.stream() return h.b:getPlayer("1").hatchingRuntime.streamId end
	function h.input(state, seq)
		return h.b:dispatch("1", {
			protocolVersion = 1, kind = "HatchInput", requestId = "input-" .. seq,
			streamId = h.stream(), inputSeq = tostring(seq), state = state,
		})
	end
	function h.press(seq)
		return h.b:dispatch("1", {
			protocolVersion = 1, kind = "HatchPress", requestId = "press-" .. seq,
			streamId = h.stream(), inputSeq = tostring(seq),
		})
	end
	function h.cmd(kind, args, id)
		local ss = h.b:getCoordinator("1").snapshots()
		local revision = (ss.working or ss.durable).meta.revision
		return h.b:dispatch("1", {
			protocolVersion = 1, kind = kind, requestId = id, operationId = id,
			expectedRevision = revision, args = args or {},
		})
	end
	return h
end

-- Mimics the Main.server sampler cadence: observe the real plate, then let the tick settle.
local function sample(h, seconds, present, intervalMs)
	local interval = intervalMs or 250
	local target = math.floor(seconds * 1000 + 0.5)
	local elapsed = 0
	while elapsed < target do
		local dt = math.min(interval, target - elapsed)
		h.b:setPlatePresence("1", present)
		h.now += dt
		h.b:tick(0)
		elapsed += dt
	end
end

local function groupIds(farm)
	local ids = {}
	for id in farm.groups do table.insert(ids, id) end
	-- Numeric order of the sequence suffix, not lexicographic order of the text id.
	table.sort(ids, function(a, b)
		return tonumber(string.match(a, "(%d+)$")) < tonumber(string.match(b, "(%d+)$"))
	end)
	return ids
end

-- ============================================================================
-- 1. Observed entry rate: 30 chickens/second, no settled population before arrival
-- ============================================================================
do
	local h = harness(nil)
	sample(h, 1.0, true)
	local farm = h.farm()
	eq(farm.runningCount, "30", "one second of observed presence releases 30 chickens")
	eq(farm.hatcheryStock, "223", "stock charged per release, base 3/s refill unchanged (250 - 30 + 3)")
	eq(farm.hatchGroupSequence, "30", "group sequence advanced by exactly 30")
	eq(farm.habitats[1].assignedInTransit, "30", "reservations stay server-owned per slot")
	eq(farm.habitats[1].population, "0", "spawning never adds settled chickens immediately")

	-- Travel time for slot 1 is 3.57s: arrivals stay data-only until they are due.
	h.b:setPlatePresence("1", false)
	h.now += 2000
	h.b:tick(0)
	farm = h.farm()
	eq(farm.habitats[1].population, "0", "no arrival before the route travel time")
	eq(farm.runningCount, "30", "all 30 chickens still in transit")
	eq(h.presence().held, false, "stepping off stops the plate intent")

	h.now += 3000
	h.b:tick(0)
	farm = h.farm()
	eq(farm.runningCount, "0", "in-flight chickens settle on arrival")
	eq(farm.habitats[1].assignedInTransit, "0", "reservations released on arrival")
	eq(farm.habitats[1].population, "30", "settled population reaches exactly 30")
	eq(farm.hatchGroupSequence, "30", "no extra chickens after the plate was released")
end

-- ============================================================================
-- 2. Rate integrity: exact 30/s across windows, ids consecutive and unique
-- ============================================================================
do
	for _, case in { { 0.25, 7 }, { 0.5, 15 }, { 2.0, 60 }, { 3.0, 90 } } do
		local h = harness(nil)
		sample(h, case[1], true)
		eq(h.farm().runningCount, tostring(case[2]), "observed " .. tostring(case[1]) .. "s releases " .. tostring(case[2]))
	end

	local h = harness(nil)
	sample(h, 2.0, true)
	local farm = h.farm()
	local ids = groupIds(farm)
	eq(#ids, 60, "60 data-only groups created")
	local unique, distinct, total, travelOk = {}, 0, 0, true
	for index, id in ipairs(ids) do
		if not unique[id] then
			unique[id] = true
			distinct += 1
		end
		local group = farm.groups[id]
		eq(id, "hatch:" .. tostring(index), "group id follows the sequence exactly")
		total += tonumber(group.count)
		if not (group.targetSlot >= 1 and group.targetSlot <= 4 and group.travelDurationSeconds > 0 and group.status == "IN_TRANSIT") then travelOk = false end
	end
	eq(distinct, 60, "every group id is unique")
	eq(total, 60, "group counts sum to the running total")
	eq(travelOk, true, "every group keeps a valid route, target and duration")
end

-- ============================================================================
-- 3. Exit and bounded lease: no counting after exit, no unbounded catch-up
-- ============================================================================
do
	local h = harness(nil)
	sample(h, 0.5, true)
	eq(h.farm().runningCount, "15", "half a second releases 15")
	sample(h, 1.5, false)
	eq(h.farm().runningCount, "15", "no further releases while off the plate")
	eq(h.presence().held, false, "exit clears the observed presence")
end
do
	-- One observation may only ever buy one bounded lease of plate time, never a backlog.
	local h = harness(nil)
	h.b:setPlatePresence("1", true)
	h.now += 500
	h.b:tick(0)
	eq(h.farm().runningCount, "15", "first half second of the lease counts")
	h.now += 500
	h.b:tick(0)
	eq(h.farm().runningCount, "30", "the lease ends one second after the last observation")
	h.now += 5000
	h.b:tick(0)
	eq(h.farm().hatchGroupSequence, "30", "a stalled sampler cannot catch up an unbounded pause")
	eq(h.presence().held, true, "an expired lease keeps the raw observation until it is refreshed")
	ok(h.presence().expiresAtMs < h.now, "lease is bounded in server time")
end

-- ============================================================================
-- 4. Limited by real stock and real vacancies
-- ============================================================================
do
	local h = harness(function(p) p.farm.hatcheryStock = "2" end)
	sample(h, 0.25, true)
	local farm = h.farm()
	eq(farm.runningCount, "2", "only the two available chickens hatch")
	ok(tonumber(farm.hatcheryStock) < 1, "stock is exhausted, not over-spent")
end
do
	local h = harness(function(p) p.farm.habitats[1].population = "245" end)
	sample(h, 1.0, true)
	local farm = h.farm()
	eq(farm.runningCount, "5", "rate is capped by the five real vacancies")
	eq(farm.habitats[1].assignedInTransit, "5", "reservations match the vacancies")
	eq(farm.habitats[1].capacity, "250", "capacity is untouched by the plate path")
end
do
	-- No vacancy anywhere: the plate cannot overcommit a full farm.
	local h = harness(function(p)
		p.farm.habitats[1].population = "250"
		p.farm.hatcheryStock = "250"
	end)
	sample(h, 1.0, true)
	eq(h.farm().runningCount, "0", "no vacancy means no plate hatching")
end

-- ============================================================================
-- 5. Anti-spoof: presence is server-observed only, never client-claimed
-- ============================================================================
do
	local h = harness(nil)
	eq(h.b:setPlatePresence("999", true), false, "unknown player cannot be observed")
	eq(select(2, h.b:setPlatePresence("999", true)), "PLAYER_NOT_CONNECTED", "rejection reason")
	eq(pcall(h.b.setPlatePresence, h.b, "1", "yes"), false, "non-boolean presence is rejected")
	eq(pcall(h.b.setPlatePresence, h.b, "1", true, -5), false, "non-instant observation time is rejected")
	eq(h.b:setPlatePresence("1", true, ORIGIN + 1000), true, "a fresh observation is accepted")
	eq(select(2, h.b:setPlatePresence("1", true, ORIGIN + 500)), "STALE_OBSERVATION", "an older observation cannot rewind the window")

	-- No client message can create plate intent: unknown kinds are refused by the schema.
	for _, kind in { "PlatePresence", "SetPlatePresence", "PlateHold", "HatchPlate" } do
		local message = { protocolVersion = 1, requestId = "forged-1", operationId = "forged-1", kind = kind }
		eq(Protocol.validateClient(message), false, "client schema refuses " .. kind)
		local reply = h.b:dispatch("1", message)
		eq(reply.admission, "NOT_ACCEPTED", "gateway refuses forged " .. kind)
	end
	eq(h.presence().held, true, "forged messages did not change the observed presence")
end
do
	-- Client traffic cannot drive the plate rate: no presence means no plate hatching at all.
	local h = harness(nil)
	for seq = 1, 60 do h.press(seq) end
	local farm = h.farm()
	eq(farm.runningCount, "60", "manual presses stay one chicken each, never a plate burst")
	eq(farm.hatchGroupSequence, "60", "manual press count matches the presses exactly")

	local quiet = harness(nil)
	quiet.now += 1000
	quiet.b:tick(0)
	eq(quiet.farm().runningCount, "0", "no plate releases without a server observation")
end
do
	-- No free hold: a client hold without the Epic research cannot hatch at plate rate.
	local h = harness(nil)
	h.input("start", 1)
	sample(h, 1.0, false)
	eq(h.farm().runningCount, "0", "hold without hold_to_hatch research releases nothing")
	eq(h.presence().held, false, "a client hold never sets plate presence")
	eq(h.b:getPlayer("1").hatchingRuntime.held, true, "the hold intent itself stays separate")
end

-- ============================================================================
-- 6. Manual press and Epic hold keep their existing meanings
-- ============================================================================
do
	local h = harness(nil)
	h.press(1)
	local farm = h.farm()
	eq(farm.runningCount, "1", "a manual press still hatches exactly one chicken")
	eq(farm.hatcheryStock, "249", "manual press spends one stock unit")
	eq(h.presence().held, false, "a manual press is not plate intent")
end
do
	local h = harness(function(p) p.permanent.epic.hold_to_hatch = 5 end)
	h.input("start", 1)
	eq(h.b:getPlayer("1").hatchingRuntime.held, true, "Epic hold starts as before")
	sample(h, 1.0, false)
	local farm = h.farm()
	eq(farm.runningCount, "10", "Epic hold level 5 keeps its 10/s research rate")
	eq(h.presence().held, false, "Epic hold is not plate intent")
	h.now += 2100
	h.b:tick(0)
	eq(h.b:getPlayer("1").hatchingRuntime.held, false, "an unrefreshed hold lease still expires")
	eq(h.farm().hatchGroupSequence, "20", "the hold counts only inside its own 2s bounded lease")
	h.now += 1000
	h.b:tick(0)
	eq(h.farm().hatchGroupSequence, "20", "expired hold stops hatching")
end

-- ============================================================================
-- 7. Reset (egg change) stops the plate intent and restarts a fresh entry
-- ============================================================================
do
	local h = harness(function(p)
		p.permanent.SE = "100000"
		p.farm.common.flock_motivation = 40
	end)
	sample(h, 0.5, true)
	eq(h.farm().runningCount, "15", "plate hatches before the reset")
	eq(h.cmd("UpgradeEgg", { targetEggIndex = 1 }, "plate-reset").status, "APPLIED", "egg change applied")
	eq(h.presence().held, false, "reset stops the plate intent")
	eq(h.presence().holdElapsed, 0, "reset clears the plate accumulator")
	h.now += 1000
	h.b:tick(0)
	eq(h.farm().runningCount, "0", "no plate hatching after the reset without a new entry")
	sample(h, 0.25, true)
	eq(h.farm().runningCount, "7", "a fresh observed entry counts from its own start")
end

-- ============================================================================
-- 8. Reconnect / ownership generation change never continues old plate input
-- ============================================================================
do
	local h = harness(nil)
	local firstStream = h.stream()
	sample(h, 0.5, true)
	eq(h.farm().runningCount, "15", "plate hatches during the first session")
	eq(h.b:playerLeaving("1"), true, "session released")
	eq(h.b:getPlatePresence("1"), nil, "a disconnected player has no plate presence")

	local profile = h.records["player:1"]
	ok(profile ~= nil, "profile was persisted by the first session")
	eq(h.b:playerJoined("1").status, "JOINED", "session re-established")
	eq(h.b:getPlatePresence("1").held, false, "reconnect starts without plate intent")
	ok(h.stream() ~= firstStream, "a new view stream was issued")
	eq(h.b:getPlatePresence("1").streamId, h.stream(), "presence follows the current stream only")
	eq(h.b:getPlatePresence("1").lastObservedMs, 0, "no observation carries over")

	h.now += 1000
	h.b:tick(0)
	eq(h.farm().hatchGroupSequence, "15", "old plate input does not continue after reconnect")
	sample(h, 0.25, true)
	eq(h.farm().hatchGroupSequence, "22", "a new observation counts from the new entry")
end

fs.writeFile("build/plate-hatching-results.json", serde.encode("json", {
	status = "PASS", level = "L", assertions = assertions,
	studioTested = false, dataStoreTested = false, humanAcceptanceTested = false,
	scope = "server-observed plate presence, 30/s rate, stock/vacancy limits, anti-spoof, reset, reconnect, unchanged manual/Epic hold",
}, true))
print(string.format("Plate hatching (server-authoritative): %d assertions PASS", assertions))
