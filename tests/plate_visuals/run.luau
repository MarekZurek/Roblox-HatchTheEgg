--!nocheck
-- Representative client visual stream regressions (approved plate adaptation, cosmetics only).
-- Scope:
-- 1. While the server says chickens are in transit, the client keeps a smooth representative
--    stream, even when in-transit counts stay constant across updates.
-- 2. A global model cap and a global spawn-rate cap bound the stream; several coops are handled
--    fairly and no model is created per real chicken.
-- 3. The stream stops and clears when authoritative counts vanish or the view stream changes.
-- 4. The stream is cosmetic: it never sends arrivals, never grants population and never writes
--    authoritative state.
-- 5. Explicit RoutePresentation.spawnGroup stays compatible, and completed-group history and
--    cleanup stay bounded.
local ClientBootstrap = require("../../src/client/Bootstrap")
local RoutePresentation = require("../../src/client/RoutePresentation")
local fs, serde = require("@lune/fs"), require("@lune/serde")

local assertions = 0
local function eq(a, b, label)
	assertions += 1
	assert(a == b, (label or "") .. " expected " .. tostring(b) .. " got " .. tostring(a))
end
local function ok(cond, label)
	assertions += 1
	assert(cond, label or "condition failed")
end

local viewSeq = 0
-- Minimal but valid own-farm snapshot with exact per-slot in-transit counts.
local function makeSnapshot(reserved, streamId)
	viewSeq += 1
	local habitats = {}
	for slot = 1, 4 do
		habitats[slot] = {
			slotId = slot,
			habitatIndex = 0,
			population = "0",
			reservedInTransit = tostring(reserved[slot] or 0),
			capacity = "250",
		}
	end
	return {
		protocolVersion = 1, numericCodecVersion = 1, viewSchemaVersion = 1,
		configRevision = "cfg:1", calculationVersion = 1,
		streamId = streamId or "stream-visuals-1",
		commitRevision = "1", viewSeq = tostring(viewSeq), serverObservedAt = 1000000,
		kind = "StateSnapshot", requestId = "boot-visuals-1",
		view = {
			audience = "own",
			farm = {
				lifecycle = "ready", eggIndex = 0, cash = "1000", habitats = habitats,
				hatchery = { stock = "250", capacity = "500", refillPerSecond = "3" },
				fleet = { vehicles = { { slotId = 1, vehicleIndex = 0 } }, shippingPerMinute = "60000", slotLimit = 4, upgrades = {} },
				producedEggsPerSecond = "0", soldEggsPerSecond = "0", cashIncomePerSecond = "0", common = {},
			},
		},
	}
end

local function newClient(reserved, streamId)
	local sent = {}
	local client = ClientBootstrap.new({
		playerId = "1",
		wire = function(message) table.insert(sent, message) end,
	})
	client:connect("boot-visuals")
	client:receive(makeSnapshot(reserved, streamId))
	return client, sent
end

local function frames(client, seconds, stepMs, onFrame)
	local step = stepMs or (1000 / 60)
	local target = math.floor(seconds * 1000 + 0.5)
	local elapsed = 0
	local now = 1000000
	while elapsed < target do
		elapsed += step
		now += step
		client:update(now)
		if onFrame then onFrame(elapsed) end
	end
	return now
end

-- ============================================================================
-- 1. Constant authoritative in-transit counts still produce a smooth stream
-- ============================================================================
do
	local client = newClient({ 4, 0, 3, 0 })
	local presentation = client:getPresentation()
	eq(presentation:getActiveVisualCount(), 0, "no visuals before the first frame")
	eq(client:getTransitStreamState().total, 7, "stream reads the authoritative in-transit total")

	-- The same counts are re-sent while frames run: the stream must not stall.
	frames(client, 2.0, 50, function(elapsed)
		if math.floor(elapsed / 250) ~= math.floor((elapsed - 50) / 250) then
			client:receive(makeSnapshot({ 4, 0, 3, 0 }))
		end
	end)

	local state = client:getTransitStreamState()
	eq(state.total, 7, "in-transit counts stayed constant across updates")
	eq(state.counts[1], 4, "coop 1 count preserved")
	eq(state.counts[3], 3, "coop 3 count preserved")
	ok(presentation:getActiveVisualCount() > 0, "constant counts still produce visuals")
	ok(presentation:getStreamGroupCount() > 0, "stream groups exist while chickens are in transit")
end

-- ============================================================================
-- 2. Global spawn-rate cap (about 8 representative visuals per second)
-- ============================================================================
do
	local client = newClient({ 100, 0, 0, 0 })
	local presentation = client:getPresentation()
	frames(client, 1.0, 1000 / 60)
	local firstSecond = presentation:getActiveVisualCount()
	ok(firstSecond <= 8, "at most 8 visuals created in the first second, got " .. tostring(firstSecond))
	ok(firstSecond >= 6, "the stream is not starved in the first second, got " .. tostring(firstSecond))

	frames(client, 1.0, 1000 / 60)
	local secondWindow = presentation:getActiveVisualCount()
	ok(secondWindow <= 16, "at most 16 visuals after two seconds, got " .. tostring(secondWindow))
	ok(secondWindow > firstSecond, "the stream keeps flowing on later frames")
end

-- ============================================================================
-- 3. Global model cap, bounded group count and bounded completed history
-- ============================================================================
do
	local client = newClient({ 100, 100, 100, 100 })
	local presentation = client:getPresentation()
	frames(client, 30.0, 50)
	ok(presentation:getActiveVisualCount() <= 32, "global model cap holds, got " .. tostring(presentation:getActiveVisualCount()))
	ok(presentation:getActiveGroupCount() <= 32, "live stream groups stay bounded, got " .. tostring(presentation:getActiveGroupCount()))
	eq(presentation:getActiveVisualCount(), presentation:getStreamGroupCount(), "one representative model per stream group")
	ok(presentation:getCompletedHistoryCount() <= presentation.maxCompletedHistory, "completed id history is bounded")
	ok(presentation:getCompletedHistoryCount() > 0, "stream groups really completed and were cleaned up")
end

-- ============================================================================
-- 4. Several coops handled fairly, proportional to authoritative in-transit counts
-- ============================================================================
do
	local client = newClient({ 30, 0, 15, 0 })
	local presentation = client:getPresentation()
	local perSlot = { 0, 0, 0, 0 }
	local total = 0
	presentation:on("groupSpawned", function(_groupId, group)
		perSlot[group.targetSlotId] = perSlot[group.targetSlotId] + 1
		total += 1
	end)
	frames(client, 12.0, 50)
	ok(total >= 60, "the stream kept spawning visuals, got " .. tostring(total))
	ok(perSlot[1] > 0, "coop 1 with more chickens is represented")
	ok(perSlot[3] > 0, "coop 3 with fewer chickens is still represented")
	ok(perSlot[1] > perSlot[3], "the busier coop receives more representative visuals")
	eq(perSlot[2], 0, "a coop with no chickens in transit gets no visuals")
	eq(perSlot[4], 0, "an empty coop gets no visuals")
	ok(perSlot[1] <= perSlot[3] * 3, "the fair split does not starve the smaller coop")
end

-- ============================================================================
-- 5. Stop and clear when counts vanish or the view stream changes
-- ============================================================================
do
	local client = newClient({ 20, 0, 20, 0 })
	local presentation = client:getPresentation()
	frames(client, 3.0, 50)
	ok(presentation:getStreamGroupCount() > 0, "stream is running before the stop")

	client:receive(makeSnapshot({ 0, 0, 0, 0 }))
	eq(client:getTransitStreamState().total, 0, "authoritative counts vanished")
	eq(presentation:getStreamGroupCount(), 0, "stream groups cleared when counts vanish")
	eq(presentation:getActiveVisualCount(), 0, "no representative models remain")
	frames(client, 1.0, 50)
	eq(presentation:getActiveVisualCount(), 0, "no new visuals without authoritative chickens")
end
do
	local client = newClient({ 20, 0, 0, 0 })
	local presentation = client:getPresentation()
	frames(client, 2.0, 50)
	ok(presentation:getStreamGroupCount() > 0, "stream is running before the stream change")

	client:receive(makeSnapshot({ 20, 0, 0, 0 }, "stream-visuals-2"))
	eq(client:getTransitStreamState().streamId, "stream-visuals-2", "client followed the new view stream")
	eq(presentation:getStreamGroupCount(), 0, "old stream visuals cleared on a stream change")
	frames(client, 1.0, 50)
	ok(presentation:getStreamGroupCount() > 0, "the new stream starts from its own counters")
	ok(presentation:getActiveVisualCount() <= 8, "the new stream respects the spawn-rate cap")
end

-- ============================================================================
-- 6. Cosmetic only: no wire traffic, no arrival and no population change
-- ============================================================================
do
	local client, sent = newClient({ 40, 40, 0, 0 })
	local presentation = client:getPresentation()
	local arrivals = 0
	presentation:onChickensArrived(function() arrivals += 1 end)
	frames(client, 5.0, 50)
	eq(#sent, 1, "the stream sent no protocol message beyond the initial bootstrap")
	eq(arrivals > 0, true, "visual groups finish their own cosmetic route")
	eq(client:getFarm().habitats[1].population, "0", "no population was granted by visuals")
	eq(client:getFarm().habitats[2].population, "0", "second coop population untouched")
	eq(client:getFarm().cash, "1000", "cash untouched by the visual stream")
	eq(client:getFarm().habitats[1].reservedInTransit, "40", "reservations remain the server's own numbers")
end

-- ============================================================================
-- 7. Explicit spawnGroup compatibility, bounded history and cleanup
-- ============================================================================
do
	local presentation = RoutePresentation.new({})
	local group = presentation:spawnGroup("compat-1", 3, 1, 1000, 1.0)
	eq(#group.models, 3, "explicit spawnGroup still creates the requested models")
	eq(presentation:getActiveVisualCount(), 3, "global model counter tracks explicit groups")
	eq(presentation:getActiveGroupCount(), 1, "explicit group is active")
	presentation:update(2500)
	eq(presentation:isGroupCompleted("compat-1"), true, "explicit group completes on arrival")
	eq(presentation:getActiveVisualCount(), 0, "completed models release the global budget")

	-- Completed ids are retained only inside a bounded recent window.
	for index = 1, presentation.maxCompletedHistory + 10 do
		presentation:spawnGroup("hist-" .. tostring(index), 1, 1, 3000 + index * 100, 0.1)
		presentation:update(3000 + index * 100 + 200)
	end
	eq(presentation:getCompletedHistoryCount() <= presentation.maxCompletedHistory, true, "completed id history stays bounded")
	eq(presentation:isGroupCompleted("compat-1"), false, "oldest completed id was evicted")
	eq(presentation:isGroupCompleted("hist-" .. tostring(presentation.maxCompletedHistory + 10)), true, "newest completed id is retained")

	-- Stream cleanup drops its own completed ids instead of retaining them forever.
	local streamed = presentation:spawnStreamGroup("stream-clean-1", 1, 2, 20000, 0.1)
	presentation:update(20100)
	eq(presentation:isGroupCompleted("stream-clean-1"), true, "stream group completed")
	local before = presentation:getCompletedHistoryCount()
	eq(presentation:clearStreamGroups(), 0, "nothing active left to clear")
	eq(presentation:getCompletedHistoryCount(), before, "clearStreamGroups only removes retained stream ids")

	local active = presentation:spawnStreamGroup("stream-clean-2", 1, 2, 21000, 5.0)
	ok(active ~= nil, "active stream group exists")
	eq(presentation:getStreamGroupCount(), 1, "stream group counted")
	eq(presentation:clearStreamGroups(), 1, "clearStreamGroups removes active stream groups")
	eq(presentation:getStreamGroupCount(), 0, "no stream groups remain")
	eq(presentation:getActiveVisualCount(), 0, "cleared stream models released the budget")
end

fs.writeFile("build/plate-visuals-results.json", serde.encode("json", {
	status = "PASS", level = "L", assertions = assertions,
	studioTested = false, dataStoreTested = false, humanAcceptanceTested = false,
	scope = "constant-count representative stream, global model and spawn-rate caps, coop fairness, stop/clear, cosmetic-only, spawnGroup compatibility and bounded cleanup",
}, true))
print(string.format("Plate visuals (client representative stream): %d assertions PASS", assertions))
