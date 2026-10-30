--!nocheck
-- Current contract: docs/31 section 3 and CURRENT_SPEC at 57cd5b9 (user decision 2026-10-28).
-- Active running-chicken passive multiplier is retired. Research supplies a CONSTANT income multiplier:
-- K when c>1 or K>5, otherwise 1, online and away. Runner count does not change it.
-- Settled population alone lays eggs; arrivals can increase future production.
-- Independent fixtures: Edible $0.50, one egg/30s/hen, TRIKE 5000 eggs/min,
-- hand-derived c/K examples, actual cash and accounting accumulator assertions.
-- Reference data parity does not approve launch balance. These are isolated local profiles.
local B = require("../../src/server/Bootstrap")
local Client = require("../../src/client/Bootstrap")
local C = require("../../src/shared/NumericCodec")
local D = require("../../src/server/PersistenceData")
local S = require("../../src/server/ProfileSchema").new(C)
local Schemas = require("../../src/shared/ProtocolSchemas")
local Protocol = Schemas.new(C)
local Catalog = require("../../src/server/CatalogRegistry").new(C,
	require("../../src/server/CatalogRegistry/Data"), { mode = "INTERNAL_TEST_ONLY" })
local fs, serde = require("@lune/fs"), require("@lune/serde")

local ORIGIN = 1000000
local assertions = 0
local function eq(a, b, label)
	assertions += 1
	assert(a == b, (label or "") .. " expected " .. tostring(b) .. " got " .. tostring(a))
end
local function ok(cond, label)
	assertions += 1
	assert(cond, label or "condition failed")
end
local function near(a, b, label)
	assertions += 1
	assert(type(a) == "number" and math.abs(a - b) <= math.max(1, math.abs(b)) * 2e-12,
		(label or "") .. " expected " .. tostring(b) .. " got " .. tostring(a))
end

-- ============================================================================
-- Independent domain inputs (reference data, not the tested income function)
-- ============================================================================
local EGG_VALUE = 1.00          -- EDIBLE, egg index 0
local LAY_PER_CHICKEN = 1 / 30  -- one egg per chicken per 30 s
local TRIKE_PER_MINUTE = 5000   -- slot-1 TRIKE shipping capacity (not binding below)
local POP = 100                 -- fixed settled population for every paired run

-- Catalog cross-checks: the fixture literals below must be the reference rows, so a silently
-- changed catalog cannot make this suite pass with invented rules.
do
	eq(Catalog.researchEffects("excitable_chickens", 25).onscreenChickenMult, 1.025, "reference excitable_chickens@25")
	eq(Catalog.researchEffects("coordinated_clucking", 50).onscreenChickenMultMax, 10, "reference coordinated_clucking@50")
	eq(Catalog.epicEffects("epic_clucking", 20).onscreenChickenMult, 1.02, "reference epic_clucking@20")
	eq(Catalog.epicEffects("epic_multiplier", 100).onscreenChickenMultMax, 200, "reference epic_multiplier@100")
	eq(Catalog.getEgg(0).value, EGG_VALUE, "reference EDIBLE egg value")
	eq(Catalog.getVehicle(0).capacity, TRIKE_PER_MINUTE, "reference TRIKE capacity")
end

-- Independent constant-multiplier rule (docs/31 section 3, 57cd5b9); n is irrelevant.
local function passiveMultiplier(c, _n, K)
	return if (c > 1 or K > 5) then K else 1
end

-- Independent income of one ONLINE production step with a constant running count:
--   sold = min(pop * 1/30, shipping) * dt   (shipping never binds below)
--   cash = sold * eggValue * rcb * 1
local function stepIncome(pop, c, n, K, dt)
	local sold = math.min(pop * LAY_PER_CHICKEN, TRIKE_PER_MINUTE / 60) * dt
	return sold * EGG_VALUE * passiveMultiplier(c, n, K)
end

-- ============================================================================
-- Harness: real ServerBootstrap over an in-memory store, like the existing
-- session_prestige_rcb / fresh_cash_purchases suites.
-- ============================================================================
local function harness(mutate)
	local h = { now = ORIGIN, records = {} }
	h.clock = {
		utcNowMs = function() return h.now end,
		elapsedNowSeconds = function() return (h.now - ORIGIN) / 1000 end,
	}
	h.store = {
		read = function(key) return true, h.records[key] and D.copy(h.records[key]) end,
		update = function(key, cb)
			local next = cb(h.records[key] and D.copy(h.records[key]))
			if next then h.records[key] = D.copy(next) end
			return true, next and D.copy(next)
		end,
	}
	function h.restart()
		h.b = B.new({ storageMode = "INTERNAL_TEST_ONLY", store = h.store, clock = h.clock })
	end
	h.restart()
	local p = S.createReference("1", ORIGIN)
	p.farm.cash = "0"
	if mutate then mutate(p) end
	eq(h.b:playerJoined("1", p).status, "JOINED", "fixture joined")
	function h.state()
		local s = h.b:getCoordinator("1").snapshots()
		return s.working or s.durable
	end
	function h.cash() return C.BigAmount.decode(h.state().farm.cash) end
	function h.acc() return C.BigAmount.decode(h.state().accounting.currentFarmCash) end
	function h.durableCash() return C.BigAmount.decode(h.records["player:1"].farm.cash) end
	function h.durableAcc() return C.BigAmount.decode(h.records["player:1"].accounting.currentFarmCash) end
	function h.step(seconds)
		h.now += seconds * 1000
		h.b:tick(seconds)
		local n = 0
		while not h.b:getCoordinator("1").snapshots().ready do
			h.b:tick(0); n += 1; assert(n < 5000, "settling stalled")
		end
	end
	function h.view()
		return h.b:dispatch("1", { protocolVersion = 1, kind = "Bootstrap", requestId = "rcb-view" })
	end
	function h.quote(kind, args)
		return h.b:dispatch("1", { protocolVersion = 1, kind = "QuoteRequest", requestId = "q", target = { kind = kind, args = args } })
	end
	function h.packet(q, id)
		local args = D.copy(q.target.args); args.quoteId = q.quoteId
		return { protocolVersion = 1, kind = q.target.kind, requestId = "request-" .. id, operationId = id,
			expectedRevision = q.expectedRevision, args = args }
	end
	return h
end

-- A fixed settled population with an optional in-transit group. travel is huge for the paired
-- runs so no runner ever arrives and joins production inside the measured window.
local function fixture(p, spec)
	p.farm.common = spec.common or {}
	p.permanent.epic = spec.epic or {}
	p.farm.habitats[1].population = tostring(spec.pop or POP)
	-- Keep every paired profile physically feasible, including 100 settled + 220 runners.
	-- The same 500-capacity habitat is used by the no-runner baseline; capacity does not
	-- change laying/sale rates or the passive research multiplier oracle.
	p.farm.habitats[1].typeIndex = 1
	local n = spec.n or 0
	assert((spec.pop or POP) + n <= Catalog.getHabitat(1).capacity, "fixture exceeds habitat capacity")
	p.farm.runningCount = tostring(n)
	p.farm.hatchGroupSequence = tostring(n)
	p.farm.habitats[1].assignedInTransit = tostring(n)
	if n > 0 then
		p.farm.groups["hatch:" .. n] = { groupId = "hatch:" .. n, count = tostring(n), targetSlot = 1,
			routeVersion = "rcb-fixture", startInstantMs = ORIGIN,
			travelDurationSeconds = spec.travel or 100000, status = "IN_TRANSIT" }
	end
end

-- One full paired measurement: projected per-second rate, real cash and the earned accumulator.
local function measure(spec, seconds)
	local h = harness(function(p) fixture(p, spec) end)
	local projected = C.BigAmount.decode(h.view().view.farm.cashIncomePerSecond)
	h.step(seconds)
	return { h = h, projected = projected, cash = h.cash(), acc = h.acc(), durable = h.durableCash() }
end


-- ============================================================================
-- A. Paired fixed-population runs: no runners vs runners
--    Population, elapsed time, egg, research, boosts, pets and transport are identical inside a
--    pair; only the running count differs. No runner arrives inside the window, so the measured
--    income must remain equal, with no hen joining production.
-- ============================================================================
local WINDOW = 3
local CASES = {
	{ label = "c=1 neutral, no runners", n = 0, c = 1, K = 5, common = {}, epic = {} },
	{ label = "c=1 neutral, 100 runners", n = 100, c = 1, K = 5, common = {}, epic = {} },
	{ label = "excitable25, no runners", n = 0, c = 1.025, K = 5, common = { excitable_chickens = 25 }, epic = {} },
	{ label = "excitable25, 1 runner", n = 1, c = 1.025, K = 5, common = { excitable_chickens = 25 }, epic = {} },
	{ label = "excitable25, 10 runners", n = 10, c = 1.025, K = 5, common = { excitable_chickens = 25 }, epic = {} },
	{ label = "excitable25, 65 runners (unchanged multiplier)", n = 65, c = 1.025, K = 5, common = { excitable_chickens = 25 }, epic = {} },
	{ label = "excitable25, 66 runners (unchanged multiplier)", n = 66, c = 1.025, K = 5, common = { excitable_chickens = 25 }, epic = {} },
	{ label = "excitable25, 100 runners (same K)", n = 100, c = 1.025, K = 5, common = { excitable_chickens = 25 }, epic = {} },
	{ label = "clucking K=15, 100 runners", n = 100, c = 1.025, K = 15,
		common = { excitable_chickens = 25, coordinated_clucking = 50 }, epic = {} },
	{ label = "epic clucking c=1.0455, 10 runners", n = 10, c = 1.025 * 1.02, K = 5,
		common = { excitable_chickens = 25 }, epic = { epic_clucking = 20 } },
	{ label = "epic multiplier K=205, 100 runners", n = 100, c = 1.025, K = 205,
		common = { excitable_chickens = 25 }, epic = { epic_multiplier = 100 } },
	{ label = "epic multiplier K=205, 220 runners (same K)", n = 220, c = 1.025, K = 205,
		common = { excitable_chickens = 25 }, epic = { epic_multiplier = 100 } },
}
for _, case in CASES do
	local m = measure(case, WINDOW)
	local q = passiveMultiplier(case.c, case.n, case.K)
	local expected = stepIncome(POP, case.c, case.n, case.K, WINDOW)
	-- The projected per-second server view must already carry the same passive research multiplier.
	near(m.projected, stepIncome(POP, case.c, case.n, case.K, 1), case.label .. ": projected rate")
	near(m.cash, expected, case.label .. ": actual cash")
	near(m.acc, expected, case.label .. ": earned accumulator")
	near(m.durable, 0, case.label .. ": income is not checkpointed before a save")
	eq(m.h.state().farm.runningCount, tostring(case.n), case.label .. ": running count preserved")
	eq(m.h.state().farm.habitats[1].population, tostring(POP), case.label .. ": no runner joined production")
	-- Paired contrast against the same-research, no-runner baseline.
	local base = measure({ n = 0, c = case.c, K = case.K, common = case.common, epic = case.epic }, WINDOW)
	near(m.cash, base.cash, case.label .. ": income is constant regardless of runner count")
	near(m.cash / (WINDOW * POP * LAY_PER_CHICKEN * EGG_VALUE), q, case.label .. ": ratio equals the passive multiplier")
end
-- Different running counts must leave the income multiplier unchanged.
do
	local c, K = 1.025, 5
	local q1, q10, q65, q66, q100 = passiveMultiplier(c, 1, K), passiveMultiplier(c, 10, K), passiveMultiplier(c, 65, K), passiveMultiplier(c, 66, K), passiveMultiplier(c, 100, K)
	ok(q1 == K and q10 == K and q65 == K, "running counts evaluate to passive multiplier K")
	ok(q66 == K and q100 == K, "higher running counts evaluate to passive multiplier K")
	local m1 = measure({ n = 1, c = c, K = K, common = { excitable_chickens = 25 } }, WINDOW)
	local m10 = measure({ n = 10, c = c, K = K, common = { excitable_chickens = 25 } }, WINDOW)
	local m66 = measure({ n = 66, c = c, K = K, common = { excitable_chickens = 25 } }, WINDOW)
	local m100 = measure({ n = 100, c = c, K = K, common = { excitable_chickens = 25 } }, WINDOW)
	ok(m1.cash == m10.cash and m10.cash == m66.cash, "actual cash is constant below old cap")
	near(m66.cash, m100.cash, "more runners do not add income")
	near(m66.cash, stepIncome(POP, c, 66, K, WINDOW), "income equals the passive multiplier model")
end
-- A2. Projection agreement and exact big counters
--     The projected server rate must carry the same passive research multiplier as the real income once pets,
--     boosts are composed; retired timed doubler is inert. A running count above 2^53 cannot be represented
--     as a double, so it is only ever handled as an exact decimal string by the compatibility API; it is irrelevant to the multiplier.
do
	local h = harness(function(p)
		fixture(p, { n = 10, common = { excitable_chickens = 25 } })
		p.inventory.pets.dog = { uid = "dog", speciesId = "farmer_dog", tier = 1, variant = "normal", locked = false }
		p.inventory.equipped = { "dog" }
		p.effects = { videoDoublerEndsAtMs = ORIGIN + 100000, boosts = { { id = "jimbos_blue_v2", remainingSeconds = "100" } } }
	end)
	local projected = C.BigAmount.decode(h.view().view.farm.cashIncomePerSecond)
	h.step(3)
	near(h.cash() / 3, projected, "projected rate equals the real income rate with pets/boosts (legacy VD inert)")
	ok(h.cash() > stepIncome(POP, 1.025, 10, 5, 3), "boosted income still contains the passive research multiplier")
end
do
	-- A2b. A running count above 2^53 is not representable as a double, so the exact decimal string is
	-- passed to the compatibility API and does not affect the multiplier. No impossible farm (>2^53 assigned in transit) is built;
	-- only production_math.activeRCB is exercised, with the exact string input preserved.
	local big = "9007199254740993" -- 2^53 + 1: rounds to 2^53 as a double
	local M = require("../../src/server/FarmMath/production_research").new(C, Catalog, { mode = "INTERNAL_TEST_ONLY" })
	local common = { excitable_chickens = 25 }
	local multiplier = M.activeRCB(common, {}, big)
	eq(multiplier, 5, "an arbitrary exact running count leaves the passive multiplier unchanged")
	eq(C.ExactUInt.encode(C.ExactUInt.decode(big)), big, "the exact running-count string is preserved through the codec")
	eq(common.excitable_chickens, 25, "passive research multiplier leaves the research input untouched")
end



-- ============================================================================
-- B. Arrivals must not be confounded with the bonus
--    A runner group with travel 0.3 s is still running during the step it arrives at the end of.
--    The step before arrival earns the passive multiplier on the OLD population; the step after earns the grown
--    population with the same passive multiplier. Both values are separated explicitly.
-- ============================================================================
do
	local c, K, n = 1.025, 5, 10
	local h = harness(function(p) fixture(p, { n = n, common = { excitable_chickens = 25 }, travel = 0.3 }) end)
	h.step(0.3)
	local step1 = h.cash()
	near(step1, stepIncome(POP, c, n, K, 0.3), "arrival step: passive multiplier on the pre-arrival population")
	eq(h.state().farm.runningCount, "0", "arrival closes the running group after production")
	eq(h.state().farm.habitats[1].population, tostring(POP + n), "arrived hens join the settled population")
	local settledThenRunning = POP + n
	ok(step1 ~= stepIncome(POP + n, c, 0, K, 0.3), "the bonus step is not just the grown population")
	local before = h.cash()
	h.step(0.3)
	local step2 = h.cash() - before
	near(step2, stepIncome(POP + n, c, 0, K, 0.3), "step after arrival: grown population, same passive multiplier")
	ok(step2 ~= stepIncome(POP, c, n, K, 0.3), "the arrival step is not repaid a second time")
	eq(h.state().farm.habitats[1].population, tostring(settledThenRunning), "no double population")
end

-- ============================================================================
-- D. Return after arrivals
--    Once the first runners have settled the bonus is gone; fresh running chickens bring it back,
--    counted from the real server running count (one manual press = one chicken).
-- ============================================================================
do
	local c, K = 1.025, 5
	local h = harness(function(p) fixture(p, { n = 10, common = { excitable_chickens = 25 }, travel = 0.3 }) end)
	h.step(0.3) -- runners arrive
	local before = h.cash()
	h.step(0.3)
	near(h.cash() - before, stepIncome(POP + 10, c, 0, K, 0.3), "after arrival the passive multiplier stays constant")
	local stream = h.b:getPlayer("1").hatchingRuntime.streamId
	for seq = 1, 9 do
		h.b:dispatch("1", { protocolVersion = 1, kind = "HatchPress", requestId = "press-" .. seq,
			streamId = stream, inputSeq = tostring(seq) })
	end
	eq(h.state().farm.runningCount, "9", "nine fresh runners are in transit")
	before = h.cash()
	h.step(0.3)
	near(h.cash() - before, stepIncome(POP + 10, c, 9, K, 0.3), "the passive multiplier returns with the new runners")
	near(h.cash() - before, stepIncome(POP + 10, c, 0, K, 0.3), "passive multiplier remains steady with new runners")
end


-- ============================================================================
-- E. The bounded cosmetic client population is irrelevant to income
--    No client message can claim chickens, and the bounded client visuals are never the source
--    of the passive multiplier. The server tracks the full authoritative running count for population only.
-- ============================================================================
do
	local h = harness(function(p) fixture(p, { n = 0, common = { excitable_chickens = 25 } }) end)
	h.step(1)
	local cash, run = h.cash(), h.state().farm.runningCount
	for _, extra in { { count = "100" }, { population = "999" }, { rcb = "50" } } do
		local msg = { protocolVersion = 1, requestId = "forged", kind = "HatchPress",
			streamId = "stream-1-1", inputSeq = "1" }
		for key, value in extra do msg[key] = value end
		eq(Protocol.validateClient(msg), false, "client schema rejects a forged " .. next(extra) .. " field")
		eq(h.b:dispatch("1", msg).admission, "NOT_ACCEPTED", "gateway refuses the forged " .. next(extra) .. " field")
	end
	eq(h.cash(), cash, "forged population claims cannot change cash")
	eq(h.state().farm.runningCount, run, "forged population claims cannot change the running count")
end
do
	-- Real client stream with 100 in-transit chickens: cosmetic models stay bounded and the client
	-- never writes authoritative state, while the server income uses all 100.
	local habitats = {}
	for slot = 1, 4 do
		habitats[slot] = { slotId = slot, habitatIndex = 0, population = "0",
			reservedInTransit = if slot == 1 then "100" else "0", capacity = "250" }
	end
	local snapshot = {
		protocolVersion = 1, numericCodecVersion = 1, viewSchemaVersion = 1, configRevision = "cfg:1",
		calculationVersion = 1, streamId = "stream-rcb-1", commitRevision = "1", viewSeq = "1",
		serverObservedAt = ORIGIN, kind = "StateSnapshot", requestId = "boot-rcb-1",
		view = { audience = "own", farm = { lifecycle = "ready", eggIndex = 0, cash = "0",
			habitats = habitats, hatchery = { stock = "250", capacity = "500", refillPerSecond = "3" },
			fleet = { vehicles = { { slotId = 1, vehicleIndex = 0 } }, shippingPerMinute = "5000",
				slotLimit = 4, upgrades = {} },
			producedEggsPerSecond = "0", soldEggsPerSecond = "0", cashIncomePerSecond = "0", common = {} } },
	}
	local sent = {}
	local client = Client.new({ playerId = "1", wire = function(message) table.insert(sent, message) end })
	client:connect("boot-rcb")
	client:receive(snapshot)
	local presentation = client:getPresentation()
	local now = ORIGIN
	for _ = 1, 300 do now += 50; client:update(now) end
	eq(presentation:getActiveVisualCount() <= 32, true, "cosmetic models stay within the bounded cap")
	eq(client:getTransitStreamState().total, 100, "the stream reads the authoritative in-transit count")
	eq(#sent, 1, "the cosmetic stream sends no protocol message beyond the bootstrap")
	eq(client:getFarm().cash, "0", "cosmetic visuals never credit cash")
	eq(client:getFarm().habitats[1].population, "0", "cosmetic visuals never grant population")
	client:destroy()

	-- If the bounded cosmetic count were used as the bonus source the income would differ.
	local c, K = 1.025, 205
	local model100 = stepIncome(POP, c, 100, K, 1)
	local model32 = stepIncome(POP, c, 32, K, 1)
	near(model100, model32, "passive income is constant regardless of visual count")
	local m = measure({ n = 100, c = c, K = K, common = { excitable_chickens = 25 },
		epic = { epic_multiplier = 100 } }, 1)
	near(m.cash, model100, "server income uses the passive multiplier")
end


-- ============================================================================
-- F. Approved hatch pressure plate at 30 chickens/second
--    The plate releases real chickens; the population uses that real server running count, arriving inside
--    the observed window and limited by real stock/vacancy. The nominal 30/s is never the bonus.
-- ============================================================================
-- Documented plate rules: 30 attempts/s, float accumulator strictly above one period per attempt,
-- one chicken per successful attempt, each attempt needs >=1 stock and a vacancy, base 3/s refill
-- applied after the step (docs/workflow/plate_hatching_2026_10_26.md, docs/31 §2).
local function plateReleases(stock, steps, dt, rate, refill, cap, vacancies)
	local carry, released, cumulative = 0, 0, {}
	for _ = 1, steps do
		carry += dt
		local attempts = math.floor(carry * rate + 1e-9)
		carry -= attempts / rate
		local made = 0
		for _ = 1, attempts do
			if stock >= 1 and made < vacancies then stock -= 1; made += 1 end
		end
		released += made
		stock = math.min(cap, stock + refill * dt)
		table.insert(cumulative, released)
	end
	return cumulative
end
local function plateWindows(stock, steps)
	local c, K = 1.025, 5
	local h = harness(function(p)
		p.farm.common = { excitable_chickens = 25 }
		p.farm.habitats[1].population = tostring(POP)
		p.farm.hatcheryStock = tostring(stock)
	end)
	h.b:setPlatePresence("1", true)
	local windows, expected = {}, 0
	for _ = 1, steps do
		h.now += 250
		h.b:tick(0)
		local running = tonumber(h.state().farm.runningCount)
		table.insert(windows, running)
		expected += stepIncome(POP, c, running, K, 0.25)
	end
	return h, windows, expected
end
do
	local h, windows, expected = plateWindows(250, 4)
	eq(table.concat(windows, ","), "7,15,22,30", "plate releases the approved 30/s in 250 ms windows")
	near(h.cash(), expected, "plate income uses settled population and constant research multiplier per window")
	eq(h.state().farm.hatcheryStock, "223", "plate stock is charged per release with the base refill")
	near(h.cash(), stepIncome(POP, 1.025, 0, 5, 1), "plate hatching earns the steady passive multiplier")
end
do
	local h, windows, expected = plateWindows(2, 4)
	local model = plateReleases(2, 4, 0.25, 30, 3, 250, 250)
	eq(table.concat(model, ","), "2,2,3,4", "independent stock-limited release model")
	eq(table.concat(windows, ","), table.concat(model, ","), "real releases match the stock-limited model")
	near(h.cash(), expected, "stock-limited plate income keeps the constant research multiplier")
	ok(tonumber(h.state().farm.runningCount) < 30, "the plate cannot use 30 as the bonus count under a stock limit")
end


-- ============================================================================
-- G. Fresh-earned passive multiplier cash, a purchase before any checkpoint, replay and reload
-- ============================================================================
do
	local c, K, n = 1.025, 5, 10
	local h = harness(function(p) fixture(p, { n = n, common = { excitable_chickens = 25 } }) end)
	h.step(20)
	local earned = stepIncome(POP, c, n, K, 20)
	near(h.cash(), earned, "fresh income includes the passive research multiplier")
	near(h.acc(), earned, "the earned accumulator includes the passive research multiplier")
	near(h.durableCash(), 0, "fresh income is not checkpointed yet")
	near(h.durableAcc(), 0, "the fresh accumulator is not checkpointed yet")

	local cost = Catalog.researchPrice("comfy_nests", 0)
	local q = h.quote("BuyResearch", { researchId = "comfy_nests", mode = "single" })
	eq(q.available, true, "the quote sees the freshly earned passive multiplier cash")
	eq(q.cashCost, C.BigAmount.encode(cost), "the quote charges the reference price")
	local packet = h.packet(q, "spend-fresh-rcb")
	eq(h.b:dispatch("1", packet).status, "APPLIED", "a purchase before any checkpoint is applied")
	near(h.cash(), earned - cost, "spending debits exactly once from the passive multiplier-inclusive balance")
	near(h.acc(), earned, "spending does not reduce the earned accumulator")
	near(h.durableCash(), earned - cost, "the committed balance keeps the passive multiplier income exactly once")
	eq(h.state().farm.common.comfy_nests, 1, "research granted once")

	h.b:checkpointPlayer("1")
	near(h.durableCash(), earned - cost, "checkpoint keeps the post-purchase balance")
	near(h.durableAcc(), earned, "checkpoint keeps the earned accumulator exactly once")

	h.now += 120000
	h.restart()
	eq(h.b:playerJoined("1").status, "JOINED", "restart/rejoin")
	eq(h.b:dispatch("1", packet).status, "REPLAYED", "the old purchase replays without re-applying")
	near(h.durableCash(), earned - cost, "replay does not debit or credit again")
	near(h.durableAcc(), earned, "replay does not double count the earned passive multiplier income")
	eq(h.records["player:1"].farm.common.comfy_nests, 1, "replay does not grant a second level")
end


-- ============================================================================
-- H. Checkpoint / reload keeps the passive multiplier income exactly once
-- ============================================================================
do
	-- Direct timeline checkpoint round trip over a window with constant running chickens.
	local M = require("../../src/server/FarmMath/production_research").new(C, Catalog, { mode = "INTERNAL_TEST_ONLY" })
	local P = require("../../src/server/FarmMath/PopulationMath").new(C)
	local Hatch = require("../../src/server/FarmMath/hatching_rcb").new(C, P, D, { mode = "INTERNAL_TEST_ONLY" })
	local IHR = require("../../src/server/FarmMath/ihr").new(C, P)
	local T = require("../../src/server/TimelineSimulation").new(C, M, Hatch, IHR, D, { mode = "INTERNAL_TEST_ONLY" })
	local ref = S.createReference("1", ORIGIN)
	fixture(ref, { n = 10, common = { excitable_chickens = 25 } })
	local farm = D.copy(ref.farm)
	farm.cash = 0
	farm.hatcheryStock = 250
	farm.commonLevels = farm.common
	farm.vehicleTypes = { 0 }
	for i, hab in farm.habitats do hab.capacity = if i == 1 then "500" else "0"; hab.fractionalIHR = 0 end
	local function initialState()
		return { settledWallThrough = ORIGIN, farm = D.copy(farm), permanent = D.copy(ref.permanent),
			accounting = { prestigeSessionArchivedCash = 0, currentFarmCash = 0, prestigeExtraEarnings = 0,
				lastBaseEarnings = 0, lastCashEarned = 0 } }
	end
	local cfg = { revision = "rcb-checkpoint:1", pro = false, siloCapacityLevel = 0 }
	local whole = T.advance(T.begin(initialState(), ORIGIN + 6000, cfg), 100)
	local sliced = T.begin(initialState(), ORIGIN + 6000, cfg)
	while not sliced.done do
		sliced = T.decodeCheckpoint(serde.decode("json", serde.encode("json", T.encodeCheckpoint(T.advance(sliced, 1)))))
	end
	eq(D.fingerprint(sliced), D.fingerprint(whole), "checkpoint round trip matches the uninterrupted passive multiplier run")
	local window = stepIncome(POP, 1.025, 10, 5, 6)
	near(whole.state.farm.cash, window, "uninterrupted passive multiplier income over the window")
	near(sliced.state.farm.cash, window, "reloaded passive multiplier income is neither lost nor doubled")
	eq(D.fingerprint(T.advance(sliced, 10)), D.fingerprint(sliced), "a completed checkpoint does not repeat income")
end
do
	-- Real session: save, long absence, reload. The pre-save passive multiplier income is kept once and the away
	-- catch-up keeps the passive multiplier; in-flight runners settle before away production.
	local c, K, n = 1.025, 5, 10
	local h = harness(function(p) fixture(p, { n = n, common = { excitable_chickens = 25 } }) end)
	h.step(3)
	local online = stepIncome(POP, c, n, K, 3)
	near(h.cash(), online, "online window earned the passive multiplier")
	h.b:checkpointPlayer("1")
	near(h.durableCash(), online, "checkpoint stores the passive multiplier income exactly once")
	h.now += 120000
	h.restart()
	eq(h.b:playerJoined("1").status, "JOINED", "rejoin after a long absence")
	h.step(3)
	local expected = online + stepIncome(POP + n, c, 0, K, 123) * 0.5
	near(h.cash(), expected, "reload adds the away income once and never replays the passive multiplier")
	near(h.acc(), expected, "the earned accumulator matches the reload total")
	eq(h.state().farm.runningCount, "0", "away closes the in-flight runners")
	eq(h.state().farm.habitats[1].population, tostring(POP + n), "runners arrive during the away settle")
end

fs.writeFile("build/rcb_income-results.json", serde.encode("json", {
	status = "PASS", level = "L", assertions = assertions,
	studioTested = false, dataStoreTested = false, humanAcceptanceTested = false,
	scope = "issue #81: constant research multiplier affects real farm.cash and accounting.currentFarmCash independently of runners; paired fixed-population/time/egg/research/boost/pet/transport runs; c=1 neutral; c>1 fixture; independence from running count; arrivals; return after arrivals; bounded cosmetic client population; plate 30/s; fresh-earned purchase, replay and checkpoint/reload without double counting or loss",
}, true))
print(string.format("Constant research multiplier real income (issue #81): %d assertions PASS", assertions))

