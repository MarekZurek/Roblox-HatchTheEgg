--!nocheck
-- Test suite for RoutePresentation (IMP-13).
-- Verifies:
-- 1. Route geometry for all 4 slots (unique target waypoints, positive lengths, positive durations).
-- 2. Polyline position interpolation at progress 0.0 (hatchery), 0.5 (midpoint), 1.0 (coop entrance).
-- 3. Visual chicken models lifecycle, completion, and destruction on arrival.
-- 4. Architectural invariant: chicken model destruction NEVER modifies ClientStateStore or economy.
-- 5. Multiple concurrent chicken groups in flight to different habitat slots.
-- 6. Custom model factories, speed profiles, and edge-case handling.

local C = require("../../src/shared/NumericCodec")
local Schemas = require("../../src/shared/ProtocolSchemas")
local Protocol = Schemas.new(C)

local ClientTransport = require("../../src/client/ClientTransport")
local ClientStateStore = require("../../src/client/ClientStateStore")
local RoutePresentation = require("../../src/client/RoutePresentation")

local CatalogData = require("../../src/server/CatalogRegistry/Data")
local Catalog = require("../../src/server/CatalogRegistry").new(C, CatalogData, { mode = "INTERNAL_TEST_ONLY" })
local ProductionMath = require("../../src/server/FarmMath/production_research").new(C, Catalog, { mode = "INTERNAL_TEST_ONLY" })
local ProfileSchema = require("../../src/server/ProfileSchema").new(C)
local ViewProjector = require("../../src/server/ViewProjector")
local FarmPlotBuilder = require("../../src/server/world/FarmPlotBuilder")
local ClientBootstrap = require("../../src/client/Bootstrap")

local assertions = 0
local function eq(a, b, label)
	assertions += 1
	assert(a == b, (label or "") .. " expected " .. tostring(b) .. " got " .. tostring(a))
end

local function ok(cond, label)
	assertions += 1
	assert(cond, label or "condition failed")
end

local function approxEq(a: number, b: number, eps: number?, label: string?)
	assertions += 1
	local tolerance = eps or 1e-4
	local diff = math.abs(a - b)
	assert(diff <= tolerance, (label or "approxEq") .. " expected " .. tostring(b) .. " got " .. tostring(a) .. " (diff: " .. tostring(diff) .. ")")
end

local projector = ViewProjector.new({
	codec = C,
	catalog = Catalog,
	productionMath = ProductionMath,
	configRevision = "CANONICAL_V1",
})

-- ============================================================================
-- Section 1: Route and Scene Geometry Verification for 4 Slots
-- ============================================================================
do
	eq(RoutePresentation.getSceneVersion(), "CANONICAL_V1", "Scene version")
	eq(RoutePresentation.getRouteVersion(), 1, "Route version")
	eq(RoutePresentation.DEFAULT_SPEED, 25.0, "Default speed is 25 studs/s")

	-- 1.1 Hatchery Zone
	local hatchery = RoutePresentation.getHatcheryZone()
	ok(hatchery ~= nil, "Hatchery zone exists")
	eq(hatchery.spawnPoint.x, 0, "Hatchery spawn X")
	eq(hatchery.spawnPoint.y, 0, "Hatchery spawn Y")
	eq(hatchery.spawnPoint.z, 45, "Hatchery spawn Z")
	ok(hatchery.size.x > 0 and hatchery.size.y > 0 and hatchery.size.z > 0, "Hatchery has positive dimensions")

	-- 1.2 Habitat Plots (1..4)
	local plots = RoutePresentation.getAllHabitatPlots()
	local entrances = {}
	for slotId = 1, 4 do
		local plot = RoutePresentation.getHabitatPlot(slotId)
		ok(plot ~= nil, "Plot exists for slot " .. tostring(slotId))
		eq(plot.slotId, slotId, "Plot slotId matches")
		ok(#plot.name > 0, "Plot has a name")
		ok(plot.size.x > 0 and plot.size.y > 0 and plot.size.z > 0, "Plot has positive size")
		ok(plot.entrance ~= nil, "Plot has entrance")
		entrances[slotId] = plot.entrance
	end

	-- Verify all 4 habitat entrances are distinct (no overlapping coops)
	for i = 1, 4 do
		for j = i + 1, 4 do
			local d = RoutePresentation.pointDistance(entrances[i], entrances[j])
			ok(d > 15.0, string.format("Coop entrance %d and %d are distinct (distance %.2f studs)", i, j, d))
		end
	end

	-- 1.3 Canonical Routes for Slots 1..4
	local routes = RoutePresentation.getAllRoutes()
	ok(routes ~= nil, "Canonical routes exist")

	for slotId = 1, 4 do
		local route = RoutePresentation.getRoute(slotId)
		ok(route ~= nil, "Route exists for slot " .. tostring(slotId))
		eq(route.slotId, slotId, "Route slotId matches")
		eq(route.routeVersion, 1, "Route version matches")
		eq(route.sceneVersion, "CANONICAL_V1", "Scene version matches")

		-- Check waypoints
		local waypoints = route.waypoints
		ok(#waypoints >= 4, "Route has at least 4 waypoints for realistic walking path")

		-- Start point must match hatchery spawn point exactly
		local startPt = waypoints[1]
		approxEq(RoutePresentation.pointDistance(startPt, hatchery.spawnPoint), 0, 1e-5, "Route starts at hatchery spawn")

		-- End point must match habitat entrance exactly
		local endPt = waypoints[#waypoints]
		approxEq(RoutePresentation.pointDistance(endPt, entrances[slotId]), 0, 1e-5, "Route ends at coop entrance")

		-- Check segments
		local segments = route.segments
		eq(#segments, #waypoints - 1, "Number of segments is waypoints - 1")

		local runningLen = 0
		local runningDur = 0
		for i, seg in ipairs(segments) do
			eq(seg.index, i, "Segment index")
			ok(seg.length > 0, "Segment length must be positive")
			ok(seg.speed > 0, "Segment speed must be positive")
			ok(seg.duration > 0, "Segment duration must be positive")
			approxEq(seg.duration, seg.length / seg.speed, 1e-5, "Segment duration = length / speed")
			approxEq(seg.startTime, runningDur, 1e-5, "Segment startTime continuity")
			runningLen += seg.length
			runningDur += seg.duration
			approxEq(seg.endTime, runningDur, 1e-5, "Segment endTime continuity")
		end

		ok(route.totalLength > 0, "Route totalLength must be positive")
		ok(route.travelDuration > 0, "Route travelDuration must be positive")
		approxEq(route.totalLength, runningLen, 1e-5, "totalLength equals sum of segment lengths")
		approxEq(route.travelDuration, runningDur, 1e-5, "travelDuration equals sum of segment durations")
	end

	-- Symmetry check: Left and Right routes should be symmetrical in length and duration
	-- Slot 1 (Back-Left) and Slot 2 (Back-Right)
	local r1 = RoutePresentation.getRoute(1)
	local r2 = RoutePresentation.getRoute(2)
	approxEq(r1.totalLength, r2.totalLength, 1e-4, "Slots 1 and 2 symmetrical length")
	approxEq(r1.travelDuration, r2.travelDuration, 1e-4, "Slots 1 and 2 symmetrical duration")

	-- Slot 3 (Front-Left) and Slot 4 (Front-Right)
	local r3 = RoutePresentation.getRoute(3)
	local r4 = RoutePresentation.getRoute(4)
	approxEq(r3.totalLength, r4.totalLength, 1e-4, "Slots 3 and 4 symmetrical length")
	approxEq(r3.travelDuration, r4.travelDuration, 1e-4, "Slots 3 and 4 symmetrical duration")

	-- Front coops (3, 4) are closer to hatchery than back coops (1, 2)
	ok(r3.totalLength < r1.totalLength, "Front coops closer than back coops")
	ok(r3.travelDuration < r1.travelDuration, "Front coops duration shorter than back coops")
end

-- ============================================================================
-- Section 2: Position Interpolation along Polylines (Progress 0.0, 0.5, 1.0)
-- ============================================================================
do
	local hatchery = RoutePresentation.getHatcheryZone()

	for slotId = 1, 4 do
		local plot = RoutePresentation.getHabitatPlot(slotId)
		local route = RoutePresentation.getRoute(slotId)

		-- 2.1 Progress = 0.0 (Start at hatchery)
		local pos0 = RoutePresentation.interpolatePosition(slotId, 0.0)
		approxEq(pos0.x, hatchery.spawnPoint.x, 1e-4, "Progress 0.0 X matches hatchery")
		approxEq(pos0.y, hatchery.spawnPoint.y, 1e-4, "Progress 0.0 Y matches hatchery")
		approxEq(pos0.z, hatchery.spawnPoint.z, 1e-4, "Progress 0.0 Z matches hatchery")
		approxEq(RoutePresentation.pointDistance(pos0, hatchery.spawnPoint), 0, 1e-4, "Progress 0.0 dist to start")

		-- 2.2 Progress = 1.0 (Arrival at target coop entrance)
		local pos1 = RoutePresentation.interpolatePosition(slotId, 1.0)
		approxEq(pos1.x, plot.entrance.x, 1e-4, "Progress 1.0 X matches coop entrance")
		approxEq(pos1.y, plot.entrance.y, 1e-4, "Progress 1.0 Y matches coop entrance")
		approxEq(pos1.z, plot.entrance.z, 1e-4, "Progress 1.0 Z matches coop entrance")
		approxEq(RoutePresentation.pointDistance(pos1, plot.entrance), 0, 1e-4, "Progress 1.0 dist to entrance")

		-- 2.3 Progress = 0.5 (Midpoint along polyline)
		local posHalf = RoutePresentation.interpolatePosition(slotId, 0.5)
		local distFromStart = RoutePresentation.pointDistance(posHalf, hatchery.spawnPoint)
		local distFromEnd = RoutePresentation.pointDistance(posHalf, plot.entrance)

		ok(distFromStart > 5.0, "Progress 0.5 is well away from hatchery (> 5 studs)")
		ok(distFromEnd > 5.0, "Progress 0.5 is well away from coop entrance (> 5 studs)")

		-- 2.4 Clamping behavior (negative progress and > 1 progress)
		local posNeg = RoutePresentation.interpolatePosition(slotId, -0.25)
		approxEq(RoutePresentation.pointDistance(posNeg, pos0), 0, 1e-5, "Negative progress clamped to 0.0")

		local posOver = RoutePresentation.interpolatePosition(slotId, 1.75)
		approxEq(RoutePresentation.pointDistance(posOver, pos1), 0, 1e-5, "Progress > 1 clamped to 1.0")

		-- 2.5 Monotonic progression along the polyline
		-- As progress advances from 0 to 1, distance along the polyline path advances smoothly
		local prevPos = pos0
		for step = 1, 10 do
			local p = step / 10
			local currentPos = RoutePresentation.interpolatePosition(slotId, p)
			local stepDist = RoutePresentation.pointDistance(prevPos, currentPos)
			ok(stepDist > 0, string.format("Progress step %.1f moves forward (dist: %.2f)", p, stepDist))
			prevPos = currentPos
		end
	end
end

-- ============================================================================
-- Section 3: Visual Chicken Group Lifecycle and Model Destruction on Arrival
-- ============================================================================
do
	local pres = RoutePresentation.new()
	eq(pres:getActiveGroupCount(), 0, "Initially 0 active groups")

	local arrivalEvents = {}
	pres:onChickensArrived(function(groupId, targetSlotId, count)
		table.insert(arrivalEvents, { groupId = groupId, targetSlotId = targetSlotId, count = count })
	end)

	local completedEvents = {}
	pres:onGroupCompleted(function(groupId, group)
		table.insert(completedEvents, { groupId = groupId, isCompleted = group.isCompleted })
	end)

	-- 3.1 Spawn a group of 3 chickens to Slot 1, starting at t=10000ms with travelDuration=2.0s (2000ms)
	local startMs = 10000
	local durationSec = 2.0
	local group = pres:spawnGroup("grp-single-1", 3, 1, startMs, durationSec)

	ok(group ~= nil, "Group successfully created")
	eq(group.groupId, "grp-single-1")
	eq(group.count, 3)
	eq(group.targetSlotId, 1)
	eq(group.startInstantMs, startMs)
	eq(group.travelDurationSeconds, durationSec)
	eq(group.currentProgress, 0)
	eq(group.isCompleted, false)
	eq(group.isDestroyed, false)
	eq(#group.models, 3, "Spawns 3 visual models")
	eq(pres:getActiveGroupCount(), 1, "1 active group in presentation")

	local models = group.models
	for _, m in ipairs(models) do
		eq(m.destroyed, false, "Model is not destroyed initially")
		ok(m.position ~= nil, "Model has position")
	end

	-- 3.2 Update at t = startMs (progress = 0.0)
	pres:update(startMs)
	eq(group.currentProgress, 0.0, "Progress at start is 0")
	eq(group.isCompleted, false)
	eq(pres:getActiveGroupCount(), 1)
	for _, m in ipairs(models) do
		eq(m.destroyed, false)
	end

	-- 3.3 Update at t = startMs + 1000ms (progress = 0.5)
	pres:update(startMs + 1000)
	approxEq(group.currentProgress, 0.5, 1e-4, "Progress at midpoint is 0.5")
	eq(group.isCompleted, false)
	eq(pres:getActiveGroupCount(), 1)
	for _, m in ipairs(models) do
		eq(m.destroyed, false, "Models still alive at midpoint")
	end

	-- 3.4 Update at t = startMs + 2000ms (progress = 1.0 - arrival!)
	pres:update(startMs + 2000)
	eq(pres:getActiveGroupCount(), 0, "Active groups drops to 0 after arrival")
	eq(pres:getGroup("grp-single-1"), nil, "Group removed from active groups")
	ok(pres:isGroupCompleted("grp-single-1"), "Group marked completed in history")

	-- CRITICAL: Visual models must be destroyed upon arrival
	for _, m in ipairs(models) do
		eq(m.destroyed, true, "Visual chicken model destroyed on arrival into coop")
	end

	-- Verify arrival and completed events were emitted
	eq(#arrivalEvents, 1, "Arrival event fired once")
	eq(arrivalEvents[1].groupId, "grp-single-1")
	eq(arrivalEvents[1].targetSlotId, 1)
	eq(arrivalEvents[1].count, 3)

	eq(#completedEvents, 1, "Completed event fired once")
	eq(completedEvents[1].groupId, "grp-single-1")
	eq(completedEvents[1].isCompleted, true)

	-- 3.5 Subsequent updates past arrival time do not resurrect or fail
	pres:update(startMs + 5000)
	eq(pres:getActiveGroupCount(), 0)
	eq(#arrivalEvents, 1, "No duplicate arrival events")
end

-- ============================================================================
-- Section 4: CRITICAL ARCHITECTURAL INVARIANT
-- Destroying visual chicken models DOES NOT modify ClientStateStore or economy!
-- ============================================================================
do
	local mockTransport = ClientTransport.new({ protocol = Protocol })
	local store = ClientStateStore.new({
		transport = mockTransport,
		codec = C,
	})

	-- Set up initial authoritative client state via snapshot
	local profile = ProfileSchema.createReference("player-inv-1", 1000000)
	profile.farm.cash = "50000"
	profile.farm.habitats[1].population = "500"
	profile.farm.habitats[1].assignedInTransit = "10"
	profile.farm.habitats[2].population = "300"
	profile.farm.habitats[2].assignedInTransit = "0"

	local initialSnapshot = projector:projectPrivateView(profile, "stream-inv-1", "1", 1000000, "req-inv-1")
	store:applySnapshot(initialSnapshot)
	eq(store:getStatus(), "READY")
	eq(store:getFarm().cash, "50000")
	eq(store:getFarm().habitats[1].population, "500")
	eq(store:getFarm().habitats[1].reservedInTransit, "10")
	eq(store:getViewSeq(), "1")
	eq(store:getCommitRevision(), "0")

	-- Wire RoutePresentation with clientStateStore
	local pres = RoutePresentation.new({ clientStateStore = store })

	-- Spawn 3 groups of visual chickens heading to different habitats
	local g1 = pres:spawnGroup("inv-g1", 10, 1, 1000, 3.0)
	local g2 = pres:spawnGroup("inv-g2", 15, 2, 1000, 3.0)
	local g3 = pres:spawnGroup("inv-g3", 5, 3, 1000, 2.0)
	eq(pres:getActiveGroupCount(), 3)

	-- Save snapshots of state before touching visual models
	local preFarm = store:getFarm()
	local preCash = preFarm.cash
	local prePop1 = preFarm.habitats[1].population
	local preRes1 = preFarm.habitats[1].reservedInTransit
	local preSeq = store:getViewSeq()
	local preRev = store:getCommitRevision()

	-- Action 1: Prematurely destroy all models of group 1 (simulating physics glitch, void, exploit)
	for _, m in ipairs(g1.models) do
		m:destroy()
		eq(m.destroyed, true)
	end

	-- Action 2: Update presentation during movement
	pres:update(2000) -- midpoint

	-- Verify store state is completely intact
	local checkFarm1 = store:getFarm()
	eq(checkFarm1.cash, preCash, "Cash untouched by model destruction")
	eq(checkFarm1.habitats[1].population, prePop1, "Population untouched by model destruction")
	eq(checkFarm1.habitats[1].reservedInTransit, preRes1, "Reserved untouched by model destruction")
	eq(store:getViewSeq(), preSeq, "viewSeq untouched")
	eq(store:getCommitRevision(), preRev, "commitRevision untouched")

	-- Action 3: Advance to completion of group 3 (t=3000ms >= 1000+2000)
	pres:update(3000)
	eq(g3.isCompleted, true)
	eq(g3.isDestroyed, true)

	-- Verify store state remains untouched after natural arrival
	local checkFarm2 = store:getFarm()
	eq(checkFarm2.cash, preCash, "Cash untouched by arrival")
	eq(checkFarm2.habitats[1].population, prePop1, "Population untouched by arrival")
	eq(checkFarm2.habitats[1].reservedInTransit, preRes1, "Reserved untouched by arrival")
	eq(store:getViewSeq(), preSeq)

	-- Action 4: Forcefully clear all groups and destroy presentation
	pres:clearAllGroups()
	pres:destroy()

	-- Final verification of ClientStateStore
	local postFarm = store:getFarm()
	eq(postFarm.cash, "50000", "Final cash matches initial exactly")
	eq(postFarm.habitats[1].population, "500", "Final population matches initial exactly")
	eq(postFarm.habitats[1].reservedInTransit, "10", "Final reserved matches initial exactly")
	eq(store:getViewSeq(), "1", "Final viewSeq matches initial exactly")
	eq(store:getStatus(), "READY", "Store remains READY")

	store:destroy()
end

-- ============================================================================
-- Section 5: Multiple Concurrent Chicken Groups to Different Habitats
-- ============================================================================
do
	local pres = RoutePresentation.new()

	local arrivals = {}
	pres:onChickensArrived(function(groupId, slotId, count)
		table.insert(arrivals, { groupId = groupId, slotId = slotId, count = count })
	end)

	-- Spawn 4 groups heading to all 4 habitats with staggered start times and durations
	-- G1 -> Slot 1 (back-left):  start=10000, dur=4.0s (ends 14000)
	-- G2 -> Slot 2 (back-right): start=10000, dur=4.0s (ends 14000)
	-- G3 -> Slot 3 (front-left): start=10500, dur=2.0s (ends 12500)
	-- G4 -> Slot 4 (front-right): start=11000, dur=2.0s (ends 13000)
	local g1 = pres:spawnGroup("grp-A", 4, 1, 10000, 4.0)
	local g2 = pres:spawnGroup("grp-B", 4, 2, 10000, 4.0)
	local g3 = pres:spawnGroup("grp-C", 2, 3, 10500, 2.0)
	local g4 = pres:spawnGroup("grp-D", 2, 4, 11000, 2.0)

	eq(pres:getActiveGroupCount(), 4, "All 4 groups active")

	-- t = 11500:
	-- G1: (11500 - 10000) / 4000 = 0.375
	-- G2: (11500 - 10000) / 4000 = 0.375
	-- G3: (11500 - 10500) / 2000 = 0.500
	-- G4: (11500 - 11000) / 2000 = 0.250
	pres:update(11500)
	eq(pres:getActiveGroupCount(), 4)
	approxEq(g1.currentProgress, 0.375, 1e-4)
	approxEq(g2.currentProgress, 0.375, 1e-4)
	approxEq(g3.currentProgress, 0.500, 1e-4)
	approxEq(g4.currentProgress, 0.250, 1e-4)
	eq(#arrivals, 0, "No groups arrived yet")

	-- t = 12600: G3 has arrived (ends at 12500)
	pres:update(12600)
	eq(pres:getActiveGroupCount(), 3, "3 groups remain active after G3 arrives")
	eq(#arrivals, 1, "G3 arrived")
	eq(arrivals[1].groupId, "grp-C")
	eq(arrivals[1].slotId, 3)

	-- t = 13100: G4 has arrived (ends at 13000)
	pres:update(13100)
	eq(pres:getActiveGroupCount(), 2, "2 groups remain active after G4 arrives")
	eq(#arrivals, 2, "G4 arrived")
	eq(arrivals[2].groupId, "grp-D")
	eq(arrivals[2].slotId, 4)

	-- t = 14100: G1 and G2 have arrived (end at 14000)
	pres:update(14100)
	eq(pres:getActiveGroupCount(), 0, "All groups completed")
	eq(#arrivals, 4, "All 4 groups arrived")

	local arrivalSlots = {}
	for _, arr in ipairs(arrivals) do
		arrivalSlots[arr.groupId] = arr.slotId
	end
	eq(arrivalSlots["grp-A"], 1)
	eq(arrivalSlots["grp-B"], 2)
	eq(arrivalSlots["grp-C"], 3)
	eq(arrivalSlots["grp-D"], 4)

	pres:destroy()
end

-- ============================================================================
-- Section 6: Custom ModelFactory, Speed Profile, and Edge Cases
-- ============================================================================
do
	-- 6.1 Custom model factory
	local spawnedCount = 0
	local customPres = RoutePresentation.new({
		modelFactory = function(groupId, index, count, targetSlotId)
			spawnedCount += 1
			return {
				id = groupId .. "_" .. index,
				custom = true,
				position = nil,
				destroyed = false,
				setPosition = function(self, p)
					self.position = p
				end,
				destroy = function(self)
					self.destroyed = true
				end,
			}
		end,
	})

	local gCustom = customPres:spawnGroup("grp-custom", 2, 2, 5000, 1.0)
	eq(spawnedCount, 2, "Custom modelFactory invoked 2 times")
	eq(gCustom.models[1].custom, true)
	ok(gCustom.models[1].position ~= nil, "Initial position set on custom model")

	customPres:update(5500)
	approxEq(gCustom.currentProgress, 0.5, 1e-4)
	ok(gCustom.models[1].position ~= nil)

	customPres:update(6000)
	eq(gCustom.models[1].destroyed, true, "Custom destroy method called on arrival")
	customPres:destroy()

	-- 6.2 Custom baseSpeed
	local fastPres = RoutePresentation.new({ baseSpeed = 50.0 })
	local standardPres = RoutePresentation.new({ baseSpeed = 25.0 })

	local rFast = fastPres:getRouteForSlot(1)
	local rStd = standardPres:getRouteForSlot(1)
	approxEq(rFast.totalLength, rStd.totalLength, 1e-4, "Lengths are identical")
	approxEq(rFast.travelDuration * 2, rStd.travelDuration, 1e-4, "At 2x speed, duration is halved")

	-- 6.3 Default travelDurationSeconds when omitted
	local defPres = RoutePresentation.new()
	local r1 = defPres:getRouteForSlot(1)
	local gDef = defPres:spawnGroup("grp-def-dur", 1, 1, 1000)
	approxEq(gDef.travelDurationSeconds, r1.travelDuration, 1e-4, "Defaults to route travelDuration")

	-- 6.4 Input validation errors
	local okSlot0, err0 = pcall(function()
		defPres:spawnGroup("err-1", 1, 0, 1000)
	end)
	eq(okSlot0, false, "Slot 0 rejected")

	local okSlot5, err5 = pcall(function()
		defPres:spawnGroup("err-2", 1, 5, 1000)
	end)
	eq(okSlot5, false, "Slot 5 rejected")

	local okCount0, errC0 = pcall(function()
		defPres:spawnGroup("err-3", 0, 1, 1000)
	end)
	eq(okCount0, false, "Count 0 rejected")

	local okNoGroup, errNG = pcall(function()
		defPres:spawnGroup(nil, 1, 1, 1000)
	end)
	eq(okNoGroup, false, "Nil groupId rejected")

	-- 6.5 Manual removal via removeGroup and clearAllGroups
	local gManual = defPres:spawnGroup("grp-manual", 2, 3, 2000, 5.0)
	eq(defPres:getActiveGroupCount(), 2) -- grp-def-dur + grp-manual
	local removed = defPres:removeGroup("grp-manual")
	eq(removed, true, "Manual removal returns true")
	eq(gManual.models[1].destroyed, true, "Model destroyed on manual removal")
	eq(defPres:getActiveGroupCount(), 1)

	defPres:clearAllGroups()
	eq(defPres:getActiveGroupCount(), 0, "clearAllGroups clears all active groups")

	defPres:destroy()
end

-- ============================================================================
-- Section 7: 3D Diegetic Silos & Delivery Truck with Parcels (PROD-06)
-- ============================================================================
do
	local world = FarmPlotBuilder.new()
	world:build()

	-- 7.1 Verify 10 Physical Silos
	local silos = world:getSilos()
	ok(silos ~= nil, "Silos list exists")
	eq(#silos, 10, "Dedicated plot accommodates exactly 10 silos for Pro Permit")

	local siloLabels = world:getSiloLabels()
	ok(siloLabels ~= nil, "Silo SurfaceGui labels list exists")
	eq(#siloLabels, 10, "10 Silo SurfaceGui countdown timer labels exist")

	-- 7.2 Update Silos from FarmView with 2 owned silos (Free Permit baseline)
	world:updateFromFarmView({ eggIndex = 0, silosOwned = 2, habitats = {}, common = {} }, Catalog)
	ok(string.find(siloLabels[1].Text, "SILOS #1") ~= nil, "Silo 1 header")
	ok(string.find(siloLabels[1].Text, "AKTYWNY") ~= nil, "Silo 1 active")
	ok(string.find(siloLabels[1].Text, "02:00:00") ~= nil, "Silo 1 has 2 hours offline protection")
	ok(string.find(siloLabels[2].Text, "SILOS #2") ~= nil, "Silo 2 header")
	ok(string.find(siloLabels[2].Text, "AKTYWNY") ~= nil, "Silo 2 active")
	ok(string.find(siloLabels[3].Text, "ZABLOKOWANY") ~= nil, "Silo 3 locked")
	ok(string.find(siloLabels[3].Text, "Wymaga Pro Permit") ~= nil, "Silo 3 locked note")
	ok(string.find(siloLabels[10].Text, "ZABLOKOWANY") ~= nil, "Silo 10 locked")

	-- 7.3 Update Silos with 10 owned silos (Pro Permit Variant A)
	world:updateFromFarmView({ eggIndex = 0, silosOwned = 10, habitats = {}, common = {} }, Catalog)
	for i = 1, 10 do
		ok(string.find(siloLabels[i].Text, "AKTYWNY") ~= nil, string.format("Silo %d active with Pro Permit", i))
		ok(string.find(siloLabels[i].Text, "10:00:00") ~= nil, string.format("Silo %d shows 10h timer", i))
	end

	-- 7.4 Delivery Truck & 2+1 Parcel
	local truck = world:getDeliveryTruck()
	ok(truck ~= nil, "Delivery truck exists at Shipping Depot")
	eq(truck.Name, "DeliveryTruck_2Plus1", "Delivery truck name")

	local parcel = world:getDeliveryParcel()
	ok(parcel ~= nil, "Delivery parcel 2+1 exists on the ground")
	eq(parcel.Name, "DeliveryParcel_2Plus1", "Delivery parcel name")

	local prompt = world:getDeliveryPrompt()
	ok(prompt ~= nil, "Delivery parcel ProximityPrompt exists")
	eq(prompt.ObjectText, "Specjalna Oferta 2+1", "Prompt object text")
	eq(prompt.ActionText, "Otwórz Paczkę", "Prompt action text")
end

-- ============================================================================
-- Section 8: 3D Bezier Drone Trajectory & Shoot-Down Presentation (PROD-06)
-- ============================================================================
do
	local pres = RoutePresentation.new()

	-- 8.1 Spawn Drone along 3D Bezier curve
	local droneId = "drone_test_bezier_1"
	local entry = pres:spawnDrone(droneId, false, 10000, 10.0)
	ok(entry ~= nil, "Drone spawned")
	eq(entry.droneId, droneId, "Drone id")
	eq(entry.falling, false, "Initial drone is flying, not falling")
	ok(entry.p0 ~= nil and entry.p1 ~= nil and entry.p2 ~= nil and entry.p3 ~= nil, "Cubic Bezier control points exist")
	ok(entry.p1.y > entry.p0.y, "Cubic Bezier p1 altitude rises above ground")

	-- Update at t = 15000 (midpoint)
	pres:update(15000)
	local activeDrone = pres:getDrone(droneId)
	ok(activeDrone ~= nil, "Drone still active at midpoint")
	ok(activeDrone.currentPosition.y > 15.0, "Drone flying high overhead along curve")

	-- 8.2 Shoot Drone Down
	local shotFired = false
	pres:on("droneShot", function(id)
		if id == droneId then shotFired = true end
	end)

	local okShoot = pres:shootDrone(droneId)
	eq(okShoot, true, "shootDrone returns true")
	eq(shotFired, true, "droneShot event emitted")
	eq(activeDrone.falling, true, "Drone falling state active")

	-- Simulate falling physics over multiple frames
	local clickTriggered = false
	activeDrone.onClicked = function(id)
		if id == droneId then clickTriggered = true end
	end

	local simTime = 15000
	for _ = 1, 30 do
		simTime += 50
		pres:update(simTime, 0.05)
		if not pres:getDrone(droneId) then
			break
		end
	end

	eq(pres:getDrone(droneId), nil, "Drone removed from active presentation upon ground impact")
	eq(clickTriggered, true, "onClicked callback triggered on ground impact")

	-- 8.3 ClientBootstrap Intent Wiring
	local sentWire = nil
	local client = ClientBootstrap.new({
		playerId = "123",
		wire = function(msg)
			sentWire = msg
		end,
	})

	-- hitDrone triggers HitDrone wire packet
	client:hitDrone("drone_wire_1")
	ok(sentWire ~= nil, "HitDrone message sent via wire")
	eq(sentWire.kind, "HitDrone", "Message kind is HitDrone")
	eq(sentWire.droneId, "drone_wire_1", "Drone ID matches")

	-- claimOffer triggers ClaimOffer wire packet
	sentWire = nil
	client:claimOffer("offer_wire_1")
	ok(sentWire ~= nil, "ClaimOffer message sent via wire")
	eq(sentWire.kind, "ClaimOffer", "Message kind is ClaimOffer")
	eq(sentWire.offerId, "offer_wire_1", "Offer ID matches")

	pres:destroy()
end

print(string.format("RoutePresentation: %d assertions PASS", assertions))
