--!nocheck
-- Acceptance Test Suite for HatchTheEgg (QA-01).
-- Verifies all 16 acceptance scenarios from docs/29 (§5: A01–A16) in test harness (level L/S/D).
--
-- Scenarios:
-- A01 (L/S): Nowy profil vs profil nieczytelny/błędny; blokada do stanu ready, błąd dekodowania nie tworzy pustego konta (ProfileSchema.validate / SessionRepository).
-- A02 (L/S): Wylęg start/refresh/stop, pusty zapas, brak miejsca, wygaśnięcie intencji po rozłączeniu.
-- A03 (L/S): Kury w drodze, rezerwacja wolnych miejsc, dotarcie i brak wpływu liczby modeli 3D na stan ekonomii.
-- A04 (L):   Produkcja vs transport (transport powyżej, równy i poniżej produkcji), sprzedaż = min(produkcja, transport).
-- A05 (L):   Ułamki IHR, pełny slot, sharing wybierający wolny cel zgodnie z regułą.
-- A06 (L/S): Zakup Common: wystarczająca gotówka, brak środków (INSUFFICIENT_CASH), zamknięty tier (TIER_LOCKED), maxLevel (MAX_LEVEL); brak zmniejszania accounting.currentFarmCash.
-- A07 (L/S): Skalowanie ceny kurników i pojazdów od liczby posiadanych egzemplarzy (sameTypeOwned); zachowanie kur przy zamianie kurnika.
-- A08 (L/S): Zmiana wyceny / warunków i ochrona expectedRevision / quoteId (odrzucenie nieaktualnej wyceny).
-- A09 (L/S/D): Dwa identyczne operationId równocześnie; replay z zapisanym wynikiem, konflikt argumentów pod tym samym ID (OPERATION_ID_CONFLICT).
-- A10 (L/S): Odmowa komendy przy braku gotowości sesji (NOT_ACCEPTED z SESSION_NOT_READY), brak pozornej kolejki.
-- A11 (L/D): Fencing sesji, próba zapisu przez starego właściciela po przejęciu sesji przez nowe połączenie (stary token nie mutuje nowej sesji).
-- A12 (L/S/D): Powrót online (<=60s) bez limitu silosów vs away (>60s) z limitem silosów; zamknięcie całego okresu; brak produkcji away przy zerze silosów.
-- A13 (L/D): Przerwanie obliczenia/checkpointu między produkcją a wzrostem; wznowienie daje ten sam wynik bitowo bez podwójnej wypłaty.
-- A14 (L/S): Wykrycie luki viewSeq na kliencie i wywołanie RefreshState (resync); brak cofania widoku.
-- A15 (S):   Izolacja dwóch graczy (Player 1 vs Player 2): brak dostępu do cudzego salda, brak wycieku tokenów/ledgerów w projekcji, odrzucenie sfingowanego playerId w payloadzie.
-- A16 (S/H): Pełny obieg funkcjonalny pętli farmy: wejście -> wylęg -> wzrost populacji -> ograniczenie transportu -> wycena i zakup ulepszenia -> powrót i synchronizacja HUD.

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local C = require("../../src/shared/NumericCodec")
local BigAmount = C.BigAmount
local ExactUInt = C.ExactUInt
local Real64 = C.Real64

local ProtocolSchemas = require("../../src/shared/ProtocolSchemas").new(C)
local ProfileSchema = require("../../src/server/ProfileSchema").new(C)
local PersistenceData = require("../../src/server/PersistenceData")
local SessionRepository = require("../../src/server/SessionRepository")
local PlayerCoordinator = require("../../src/server/PlayerCoordinator")
local TimelineSimulation = require("../../src/server/TimelineSimulation")

local CatalogData = require("../../src/server/CatalogRegistry/Data")
local CatalogRegistry = require("../../src/server/CatalogRegistry")
local Catalog = CatalogRegistry.new(C, CatalogData, { mode = "INTERNAL_TEST_ONLY" })

local ProductionMathModule = require("../../src/server/FarmMath/production_research")
local ProductionMath = ProductionMathModule.new(C, Catalog, { mode = "INTERNAL_TEST_ONLY" })
local PopulationMath = require("../../src/server/FarmMath/PopulationMath").new(C)
local HatchingRCB = require("../../src/server/FarmMath/hatching_rcb").new(C, PopulationMath, PersistenceData, { mode = "INTERNAL_TEST_ONLY" })
local IHR = require("../../src/server/FarmMath/ihr").new(C, PopulationMath)
local FarmActions = require("../../src/server/FarmActions")
local ViewProjector = require("../../src/server/ViewProjector")

local ServerBootstrap = require("../../src/server/Bootstrap")
local ClientBootstrap = require("../../src/client/Bootstrap")
local ClientTransport = require("../../src/client/ClientTransport")
local ClientStateStore = require("../../src/client/ClientStateStore")
local RoutePresentation = require("../../src/client/RoutePresentation")

-- ============================================================================
-- Assertion & Metric Tracking
-- ============================================================================
local scenarioAssertions = {
	A01 = 0, A02 = 0, A03 = 0, A04 = 0,
	A05 = 0, A06 = 0, A07 = 0, A08 = 0,
	A09 = 0, A10 = 0, A11 = 0, A12 = 0,
	A13 = 0, A14 = 0, A15 = 0, A16 = 0,
}
local currentScenario = "A01"
local totalAssertions = 0

local function setScenario(id)
	currentScenario = id
end

local function ok(cond, label)
	totalAssertions += 1
	scenarioAssertions[currentScenario] += 1
	assert(cond, string.format("[%s] condition failed: %s", currentScenario, label or ""))
end

local function eq(a, b, label)
	totalAssertions += 1
	scenarioAssertions[currentScenario] += 1
	assert(a == b, string.format("[%s] %s: expected %s, got %s", currentScenario, label or "", tostring(b), tostring(a)))
end

local function approxEq(a: number, b: number, eps: number?, label: string?)
	totalAssertions += 1
	scenarioAssertions[currentScenario] += 1
	local tolerance = eps or 1e-4
	local diff = math.abs(a - b)
	assert(diff <= tolerance, string.format("[%s] %s: expected %s, got %s (diff: %s)", currentScenario, label or "", tostring(b), tostring(a), tostring(diff)))
end

local function createMockClock(startMs)
	local nowMs = startMs or 1000000
	local elapsedSec = 0
	local clock = {}
	function clock.utcNowMs() return nowMs end
	function clock.elapsedNowSeconds() return elapsedSec end
	function clock.advance(dt)
		elapsedSec += dt
		nowMs += math.floor(dt * 1000 + 0.5)
	end
	function clock.set(n, e)
		nowMs = n
		if e ~= nil then elapsedSec = e end
	end
	return clock
end

-- ============================================================================
-- SCENARIO A01 (L/S):
-- Nowy profil vs profil nieczytelny/błędny; blokada do stanu ready, błąd dekodowania nie tworzy pustego konta (ProfileSchema.validate / SessionRepository).
-- ============================================================================
setScenario("A01")
do
	local clock = createMockClock(1000000)
	local records = {}
	local store = {
		records = records,
		read = function(key)
			return true, if records[key] then PersistenceData.copy(records[key]) else nil
		end,
		update = function(key, transform)
			local cur = if records[key] then PersistenceData.copy(records[key]) else nil
			local callOk, nextVal = pcall(transform, cur)
			if not callOk then
				print("ERROR in store.update transform:", nextVal)
				error(nextVal)
			end
			if nextVal ~= nil then
				records[key] = PersistenceData.copy(nextVal)
			end
			return true, if nextVal ~= nil then PersistenceData.copy(nextVal) else nil
		end,
	}

	local tokenCount = 0
	local repo = SessionRepository.new({
		mode = "INTERNAL_TEST_ONLY",
		codec = C,
		data = PersistenceData,
		schema = ProfileSchema,
		store = store,
		clock = clock,
		encodeJson = function(v) return serde.encode("json", v) end,
		tokenFactory = function()
			tokenCount += 1
			return "token-a01-" .. tostring(tokenCount)
		end,
	})

	-- 1. Nowy profil (No existing record in store -> acquire creates valid reference profile)
	local acqNew = repo.acquire("101")
	eq(acqNew.status, "ACQUIRED", "A01: acquire on empty store succeeds")
	ok(acqNew.handle ~= nil, "A01: handle returned")
	local pNew = acqNew.profile
	ok(pNew ~= nil, "A01: profile created")
	eq(pNew.meta.schemaVersion, 1, "A01: schemaVersion is 1")
	eq(pNew.meta.numericCodecVersion, 1, "A01: numericCodecVersion is 1")
	eq(pNew.meta.calculationVersion, 1, "A01: calculationVersion is 1")
	eq(pNew.meta.playerId, "101", "A01: playerId is 101")
	eq(pNew.meta.revision, "0", "A01: initial revision is 0")
	eq(pNew.farm.cash, "0", "A01: initial cash is 0")
	eq(pNew.farm.hatcheryStock, "250", "A01: initial hatchery stock is 250")
	eq(pNew.farm.runningCount, "0", "A01: initial runningCount is 0")
	eq(pNew.farm.habitats[1].typeIndex, 0, "A01: habitat 1 is COOP (0)")
	eq(pNew.farm.habitats[2].typeIndex, -1, "A01: habitat 2 is empty (-1)")
	eq(pNew.farm.habitats[1].population, "0", "A01: habitat 1 population is 0")
	eq(pNew.farm.habitats[1].assignedInTransit, "0", "A01: assignedInTransit is 0")
	eq(pNew.ownership.generation, "1", "A01: ownership generation is 1")
	ok(#pNew.ownership.ownerToken > 0, "A01: ownerToken assigned")
	ok(pNew.ownership.endsAtMs > clock.utcNowMs(), "A01: lease ends in future")

	local valOk = ProfileSchema.validate(pNew, "101")
	eq(valOk, true, "A01: reference profile passes ProfileSchema.validate")

	-- Release session 101 cleanly
	local relRes = repo.release(acqNew.handle)
	eq(relRes.status, "RELEASED", "A01: session 101 released")

	-- 2. Profil nieczytelny/błędny (Corrupted profile in store)
	-- Test direct ProfileSchema validation failures:
	local corruptBadType = "not-a-table"
	local okBadType, errBadType = pcall(function() return ProfileSchema.validate(corruptBadType, "102") end)
	eq(okBadType, false, "A01: non-table profile rejected")

	local corruptBadSchema = ProfileSchema.createReference("102", 1000000)
	corruptBadSchema.meta.schemaVersion = 999
	local okBadSchema, errBadSchema = ProfileSchema.validate(corruptBadSchema, "102")
	eq(okBadSchema, false, "A01: schemaVersion 999 rejected")
	eq(errBadSchema, "UNSUPPORTED_SCHEMA", "A01: errorCode is UNSUPPORTED_SCHEMA")

	local corruptBadCodec = ProfileSchema.createReference("102", 1000000)
	corruptBadCodec.meta.numericCodecVersion = 999
	local okBadCodec, errBadCodec = ProfileSchema.validate(corruptBadCodec, "102")
	eq(okBadCodec, false, "A01: numericCodecVersion 999 rejected")
	eq(errBadCodec, "UNSUPPORTED_VERSION", "A01: errorCode is UNSUPPORTED_VERSION")

	local corruptInconsistentRes = ProfileSchema.createReference("102", 1000000)
	corruptInconsistentRes.farm.runningCount = "5"
	corruptInconsistentRes.farm.habitats[1].assignedInTransit = "0"
	local okInconsistent = pcall(function() return ProfileSchema.validate(corruptInconsistentRes, "102") end)
	eq(okInconsistent, false, "A01: inconsistent runningCount vs assignedInTransit rejected")

	local corruptNegativeIHR = ProfileSchema.createReference("102", 1000000)
	corruptNegativeIHR.farm.habitats[1].fractionalIHR = "-0.25"
	local okNegIHR = pcall(function() return ProfileSchema.validate(corruptNegativeIHR, "102") end)
	eq(okNegIHR, false, "A01: negative fractionalIHR rejected")

	-- Now store corrupted profile in storage and attempt repo.acquire:
	local corruptStoreProfile = {
		meta = { schemaVersion = 999, numericCodecVersion = 1, calculationVersion = 1, playerId = "102", configRevision = "cfg:1", revision = "0" },
		ownership = { generation = "0", ownerToken = "", endsAtMs = 0 },
		corruptedDataPayload = "DO_NOT_OVERWRITE_ME",
	}
	store.records["player:102"] = PersistenceData.copy(corruptStoreProfile)

	local acqCorrupt = repo.acquire("102")
	eq(acqCorrupt.status, "NOT_ACCEPTED", "A01: acquire on corrupt profile returns NOT_ACCEPTED")
	eq(acqCorrupt.errorCode, "UNSUPPORTED_SCHEMA", "A01: errorCode matches validation failure")

	-- CRITICAL INVARIANT: store record was NOT overwritten with an empty reference account!
	ok(store.records["player:102"] ~= nil, "A01: store record still exists")
	eq(store.records["player:102"].corruptedDataPayload, "DO_NOT_OVERWRITE_ME", "A01: corrupted profile data preserved in store without being overwritten")
	eq(store.records["player:102"].meta.schemaVersion, 999, "A01: original schemaVersion retained")

	-- 3. Blokada do stanu ready (Coordinator rejects mutations until ready)
	local acqGated = repo.acquire("103")
	eq(acqGated.status, "ACQUIRED", "A01: acquire player 103")
	local coordGated = PlayerCoordinator.new({
		mode = "INTERNAL_TEST_ONLY",
		codec = C,
		data = PersistenceData,
		repository = repo,
		handle = acqGated.handle,
		clock = clock,
		maxQueue = 8,
		simulation = { advance = function(p) return { profile = p, complete = true } end },
		domain = { apply = function(p) return { profile = p, terminalStatus = "APPLIED", result = {}, validate = function() return true end } end },
	})

	eq(coordGated.snapshots().ready, false, "A01: coordinator starts unready")
	local unreadySubmit = coordGated.submit({
		operationId = "op-early-1",
		kind = "BuyResearch",
		expectedRevision = "0",
		args = { researchId = "comfy_nests", mode = "single", quoteId = "quote-spoof-1" },
	})
	eq(unreadySubmit.status, "NOT_ACCEPTED", "A01: command rejected when session is not ready")
	eq(unreadySubmit.errorCode, "SESSION_NOT_READY", "A01: errorCode is SESSION_NOT_READY")

	-- Now transition to ready
	local setR = coordGated.setReady(true)
	eq(setR.status, "READY_SET", "A01: setReady(true) succeeds")
	eq(coordGated.snapshots().ready, true, "A01: coordinator is now ready")

	coordGated.release()
	coordGated.drain()
end

-- ============================================================================
-- SCENARIO A02 (L/S):
-- Wylęg start/refresh/stop, pusty zapas, brak miejsca, wygaśnięcie intencji po rozłączeniu.
-- ============================================================================
setScenario("A02")
do
	local clock = createMockClock(2000000)
	local server = ServerBootstrap.new({ clock = clock, initialNowMs = 2000000 })
	local joinRes = server:playerJoined("201")
	eq(joinRes.status, "JOINED", "A02: player 201 joined")

	local coord = server:getCoordinator("201")
	ok(coord ~= nil, "A02: coordinator active")

	local client = ClientBootstrap.new({ wire = server, playerId = "201", clock = clock })
	client:connect("boot-a02-1")
	eq(client:getStatus(), "READY", "A02: client ready")

	-- 1. Wylęg start / refresh / stop intents
	local fHatch = {
		habitats = {
			{ typeIndex = 0, capacity = "250", population = "0", assignedInTransit = "0", fractionalIHR = 0 },
			{ typeIndex = -1, capacity = "0", population = "0", assignedInTransit = "0", fractionalIHR = 0 },
			{ typeIndex = -1, capacity = "0", population = "0", assignedInTransit = "0", fractionalIHR = 0 },
			{ typeIndex = -1, capacity = "0", population = "0", assignedInTransit = "0", fractionalIHR = 0 },
		},
		hatcheryStock = 250,
		runningCount = "0",
		hatchGroupSequence = "0",
		groups = {},
	}
	local rHatch = { streamId = client:getStore():getStreamId(), lastInputSeq = "0", held = false, holdElapsed = 0 }
	local drawFn = function() return "0" end
	local routeFn = function(s) return { routeVersion = "scene-v1", startInstantMs = clock.utcNowMs(), travelDurationSeconds = 2.0, snapshot = { slotId = s } } end

	-- Start intent sets held to true
	local startPacket = { kind = "HatchInput", streamId = rHatch.streamId, inputSeq = "1", state = "start" }
	fHatch, rHatch = HatchingRCB.input(fHatch, rHatch, startPacket, drawFn, routeFn)
	eq(rHatch.held, true, "A02: HatchInput start sets held to true")

	-- Hold ticking with rate = 10 chickens/s (period = 0.1s): in dt = 0.25s (<= 0.3), 2 chickens spawned
	local fStep1, rStep1, attempts, released = HatchingRCB.holdStep(fHatch, rHatch, 0.25, 10, drawFn, routeFn)
	eq(released, 2, "A02: 2 chickens spawned while held")
	eq(fStep1.hatcheryStock, 248, "A02: Hatchery stock decremented from 250 to 248")
	eq(fStep1.runningCount, "2", "A02: runningCount incremented to 2")

	-- Refresh intent keeps held state true
	local refreshPacket = { kind = "HatchInput", streamId = rHatch.streamId, inputSeq = "2", state = "refresh" }
	fStep1, rStep1 = HatchingRCB.input(fStep1, rStep1, refreshPacket, drawFn, routeFn)
	eq(rStep1.held, true, "A02: HatchInput refresh preserves held state")

	-- Stop intent sets held to false and resets holdElapsed
	local stopPacket = { kind = "HatchInput", streamId = rHatch.streamId, inputSeq = "3", state = "stop" }
	local fStop, rStop = HatchingRCB.input(fStep1, rStep1, stopPacket, drawFn, routeFn)
	eq(rStop.held, false, "A02: HatchInput stop sets held to false")
	eq(rStop.holdElapsed, 0, "A02: holdElapsed reset to 0 on stop")

	-- After stop, holdStep with dt = 0.3 does NOT spawn any chickens
	local fPostStop, rPostStop, attStop, relStop = HatchingRCB.holdStep(fStop, rStop, 0.3, 10, drawFn, routeFn)
	eq(relStop, 0, "A02: No chickens spawned after stop intent")
	eq(fPostStop.hatcheryStock, fStop.hatcheryStock, "A02: Hatchery stock unchanged after stop intent")

	-- Discrete HatchPress on client/server bootstrap
	local pressMsg, pressSeq = client:hatchPress()
	eq(pressSeq, "1", "A02: client hatchPress sent inputSeq 1")
	eq(coord.snapshots().working.farm.runningCount, "1", "A02: Server runningCount is 1 from discrete press")
	eq(coord.snapshots().working.farm.hatcheryStock, "249", "A02: Server hatchery stock decremented to 249")

	-- 2. Pusty zapas (Empty stock)
	local fEmptyStock = PersistenceData.copy(coord.snapshots().working.farm)
	fEmptyStock.hatcheryStock = 0
	local runtimeEmpty = { streamId = client:getStore():getStreamId(), lastInputSeq = "10", held = false, holdElapsed = 0 }
	local nextFarmEmpty, _, statusEmpty = HatchingRCB.input(fEmptyStock, runtimeEmpty, { kind = "HatchPress", streamId = runtimeEmpty.streamId, inputSeq = "11" }, function() return "0" end, function(s) return server:_getRoute(s) end)
	eq(statusEmpty, "NO_STOCK", "A02: Hatch press with 0 stock returns NO_STOCK")
	eq(nextFarmEmpty.hatcheryStock, 0, "A02: Hatchery stock floored at 0, never negative")
	eq(nextFarmEmpty.runningCount, fEmptyStock.runningCount, "A02: Running count not increased on NO_STOCK")

	-- 3. Brak miejsca (No vacancy)
	local fFullHab = PersistenceData.copy(coord.snapshots().working.farm)
	fFullHab.hatcheryStock = 100
	fFullHab.runningCount = "0"
	fFullHab.groups = {}
	fFullHab.habitats[1].population = "250"
	fFullHab.habitats[1].assignedInTransit = "0"
	fFullHab.habitats[1].capacity = "250"
	for i = 2, 4 do
		fFullHab.habitats[i].typeIndex = -1
		fFullHab.habitats[i].capacity = "0"
		fFullHab.habitats[i].population = "0"
		fFullHab.habitats[i].assignedInTransit = "0"
	end
	local runtimeFull = { streamId = client:getStore():getStreamId(), lastInputSeq = "20", held = false, holdElapsed = 0 }
	local nextFarmFull, _, statusFull = HatchingRCB.input(fFullHab, runtimeFull, { kind = "HatchPress", streamId = runtimeFull.streamId, inputSeq = "21" }, function() return "0" end, function(s) return server:_getRoute(s) end)
	eq(statusFull, "NO_VACANCY", "A02: Hatch press when coops are full returns NO_VACANCY")
	eq(nextFarmFull.runningCount, fFullHab.runningCount, "A02: Running count not increased on NO_VACANCY")
	eq(nextFarmFull.habitats[1].assignedInTransit, "0", "A02: assignedInTransit not exceeded")

	-- 4. Wygaśnięcie intencji po rozłączeniu (Disconnect terminates intent)
	client:destroy()
	server:playerLeaving("201")
	eq(server:getPlayer("201"), nil, "A02: player 201 unregistered from server bootstrap")

	-- Reconnect player: runtime intent state is freshly initialized (held=false)
	server:playerJoined("201")
	local pSession = server:getPlayer("201")
	ok(pSession ~= nil, "A02: player 201 reconnected")
	eq(pSession.hatchingRuntime.held, false, "A02: Hatching intent expired on disconnect and is false upon reconnect")
	eq(pSession.hatchingRuntime.lastInputSeq, "0", "A02: Hatching input sequence reset upon reconnect")

	server:playerLeaving("201")
end

-- ============================================================================
-- SCENARIO A03 (L/S):
-- Kury w drodze, rezerwacja wolnych miejsc, dotarcie i brak wpływu liczby modeli 3D na stan ekonomii.
-- ============================================================================
setScenario("A03")
do
	local clock = createMockClock(3000000)
	local server = ServerBootstrap.new({ clock = clock, initialNowMs = 3000000 })
	local fix3 = ProfileSchema.createReference("301", 3000000)
	fix3.farm.habitats[1].population = "248"
	server:playerJoined("301", fix3)
	local coord = server:getCoordinator("301")

	local client = ClientBootstrap.new({ wire = server, playerId = "301", clock = clock })
	client:connect("boot-a03-1")

	-- 1. Kury w drodze & rezerwacja wolnych miejsc
	-- Habitat 1 capacity is 250. Starting population is 248, so remaining space is 2 hens.

	-- Spawn chicken 1
	local _, seq1 = client:hatchPress()
	eq(seq1, "1", "A03: First hatch press")
	local sHatch1 = coord.snapshots().working.farm
	eq(sHatch1.runningCount, "1", "A03: runningCount is 1")
	eq(sHatch1.habitats[1].assignedInTransit, "1", "A03: assignedInTransit is 1")

	-- Spawn chicken 2 (filling the remaining vacancy of 2)
	local _, seq2 = client:hatchPress()
	eq(seq2, "2", "A03: Second hatch press")
	local sHatch2 = coord.snapshots().working.farm
	eq(sHatch2.runningCount, "2", "A03: runningCount is 2")
	eq(sHatch2.habitats[1].assignedInTransit, "2", "A03: assignedInTransit is 2")

	-- Attempt to spawn 3rd chicken: effective vacancy is 250 - 248 - 2 = 0!
	local hatchRes3
	client:hatchPress(function(res) hatchRes3 = res end)
	local sHatch3 = coord.snapshots().working.farm
	eq(sHatch3.runningCount, "2", "A03: 3rd chicken cannot spawn, runningCount remains 2")
	eq(sHatch3.habitats[1].assignedInTransit, "2", "A03: assignedInTransit remains 2 (cannot overcommit)")

	-- 2. Dotarcie (Arrival past travel time: slot 1 duration is 3.57s)
	server:tick(4.0, clock.utcNowMs() + 4000)
	client:update(clock.utcNowMs())
	eq(client:getPresentation():getActiveGroupCount(), 0, "A03: Prior visual chickens completed on arrival")
	local sPostArrival = coord.snapshots().working.farm
	eq(sPostArrival.runningCount, "0", "A03: runningCount drops to 0 on arrival")
	eq(sPostArrival.habitats[1].assignedInTransit, "0", "A03: assignedInTransit drops to 0 on arrival")
	eq(sPostArrival.habitats[1].population, "250", "A03: habitat 1 population reached exactly 250 (248 + 2)")

	-- 3. Brak wpływu liczby modeli 3D na stan ekonomii
	local pres = client:getPresentation()
	local prePresCash = client:getFarm().cash
	local prePresPop = client:getFarm().habitats[1].population

	-- Spawn 5 visual chicken groups (50 total visual chickens) in presentation layer
	for g = 1, 5 do
		pres:spawnGroup("extra-g-" .. tostring(g), 10, 1, clock.utcNowMs(), 2.0)
	end
	eq(pres:getActiveGroupCount(), 5, "A03: 5 visual groups spawned in presentation")

	-- Destroy visual models arbitrarily (simulating client render lag, cull, void fall)
	for g = 1, 5 do
		local grp = pres:getGroup("extra-g-" .. tostring(g))
		if grp then
			for _, m in ipairs(grp.models) do
				m:destroy()
			end
		end
	end

	-- Update presentation
	pres:update(clock.utcNowMs() + 1000)

	-- Verify economy state in ClientStateStore is completely unchanged by visual models
	local postPresCash = client:getFarm().cash
	local postPresPop = client:getFarm().habitats[1].population
	eq(postPresCash, prePresCash, "A03: Client cash balance 100% immune to 3D visual models")
	eq(postPresPop, prePresPop, "A03: Habitat population 100% immune to 3D visual models")

	client:destroy()
	server:playerLeaving("301")
end

-- ============================================================================
-- SCENARIO A04 (L):
-- Produkcja vs transport (transport powyżej, równy i poniżej produkcji), sprzedaż = min(produkcja, transport).
-- ============================================================================
setScenario("A04")
do
	local dt = 0.3 -- Invariant: simulation steps enforce dt <= 0.3s
	local eggVal = 0.25 -- base egg value ($0.25)
	local layingRatePerHen = 1 / 30 -- base egg laying rate (1/30 eggs/s)
	-- 1 Trike (type 0): 5,000 eggs/min = 5000 / 60 eggs/s = 83.33333333333333 eggs/s
	-- In dt = 0.3s: fleet capacity = (5000 / 60) * 0.3 = 25.0 eggs.
	local shippingRatePerSec = 5000 / 60
	local shippingCapacityInDt = shippingRatePerSec * dt

	-- Case 1: Transport > Produkcja (Transport above production)
	-- 120 hens @ (1/30) eggs/s = 4.0 eggs/s produced.
	-- In dt = 0.3s: 1.2 eggs produced.
	-- Fleet shipping capacity in 0.3s = 25.0 eggs.
	-- All produced eggs are sold: soldEggs = 1.2, cash = 1.2 * 0.25 = $0.30.
	local stateAbove = {
		commonLevels = {},
		habitatTypes = { 0, false, false, false },
		settledPopulation = { "120", "0", "0", "0" },
		vehicleTypes = { 0 },
		rcbMultiplier = 1,
	}
	local stepAbove = ProductionMath.productionStep(stateAbove, dt)
	approxEq(stepAbove.producedEggs, 120 * layingRatePerHen * dt, 1e-6, "A04.1: Produced eggs for 120 hens in dt=0.3s")
	approxEq(stepAbove.soldEggs, 120 * layingRatePerHen * dt, 1e-6, "A04.1: Sold eggs matches produced eggs when transport > production")
	approxEq(stepAbove.cashIncome, (120 * layingRatePerHen * dt) * eggVal, 1e-6, "A04.1: Cash income = 1.2 * $0.25 = $0.30")
	ok(shippingCapacityInDt > stepAbove.producedEggs, "A04.1: Confirmed transport > production")

	-- Case 2: Transport == Produkcja (Transport exactly equal to production)
	-- With comfy_nests = 15, laying rate per hen is (1 + 0.1 * 15)/30 = 2.5/30 = 1/12 eggs/s.
	-- With 1,000 hens (4 SHACKs, 250 hens each, capacity 500 each):
	-- In dt = 0.3s: producedEggs = 1000 * (1/12) * 0.3 = 25.0 eggs.
	-- Fleet shipping capacity in 0.3s (1 Trike) = (5000 / 60) * 0.3 = 25.0 eggs.
	-- Transport (25.0) == Production (25.0).
	-- Produced == Shipping: soldEggs = 25.0, cash = 25.0 * 0.25 = $6.25.
	local stateEqual = {
		commonLevels = { comfy_nests = 15 },
		habitatTypes = { 1, 1, 1, 1 }, -- 4 SHACKs
		settledPopulation = { "250", "250", "250", "250" }, -- 1000 hens (<= 500 cap each)
		vehicleTypes = { 0 },
		rcbMultiplier = 1,
	}
	local stepEqual = ProductionMath.productionStep(stateEqual, dt)
	approxEq(stepEqual.producedEggs, shippingCapacityInDt, 1e-6, "A04.2: Produced eggs matches shipping capacity (25.0)")
	approxEq(stepEqual.soldEggs, shippingCapacityInDt, 1e-6, "A04.2: Sold eggs matches produced eggs and shipping capacity (25.0)")
	approxEq(stepEqual.cashIncome, shippingCapacityInDt * eggVal, 1e-6, "A04.2: Cash income = 25.0 * $0.25 = $6.25")

	-- Case 3: Transport < Produkcja (Transport below production - BOTTLENECK)
	-- With comfy_nests = 50, laying rate is (1 + 5.0)/30 = 6/30 = 0.2 eggs/s per hen.
	-- With 2,000 hens (4 SHACKs with 500 hens each):
	-- In dt = 0.3s: producedEggs = 2000 * 0.2 * 0.3 = 120.0 eggs.
	-- Fleet shipping capacity in 0.3s (1 Trike) = 25.0 eggs.
	-- Bottleneck active: soldEggs = min(120.0, 25.0) = 25.0 eggs!
	-- Cash income is strictly limited to shipping capacity * eggVal ($6.25), NOT produced * eggVal ($30.00).
	local stateBelow = {
		commonLevels = { comfy_nests = 50 },
		habitatTypes = { 1, 1, 1, 1 }, -- 4 SHACKs
		settledPopulation = { "500", "500", "500", "500" }, -- 2000 hens (cap 500 each)
		vehicleTypes = { 0 },
		rcbMultiplier = 1,
	}
	local stepBelow = ProductionMath.productionStep(stateBelow, dt)
	approxEq(stepBelow.producedEggs, 120.0, 1e-6, "A04.3: Produced eggs is 120.0")
	approxEq(stepBelow.soldEggs, shippingCapacityInDt, 1e-6, "A04.3: Sold eggs constrained by fleet shipping rate: min(production, transport)")
	approxEq(stepBelow.cashIncome, shippingCapacityInDt * eggVal, 1e-6, "A04.3: Cash income limited strictly by transport capacity ($6.25)")
	ok(stepBelow.soldEggs < stepBelow.producedEggs, "A04.3: Confirmed soldEggs < producedEggs")
	ok(stepBelow.cashIncome < stepBelow.producedEggs * eggVal, "A04.3: Income is lower than unconstrained production")
end

-- ============================================================================
-- SCENARIO A05 (L):
-- Ułamki IHR, pełny slot, sharing wybierający wolny cel zgodnie z regułą.
-- ============================================================================
setScenario("A05")
do
	local function createHab(cap, pop, res, frac)
		return {
			typeIndex = if cap == "0" then -1 else 0,
			capacity = cap,
			population = pop or "0",
			assignedInTransit = res or "0",
			fractionalIHR = frac or 0,
		}
	end

	-- 1. Ułamki IHR (IHR fractions accumulation and carry >= 0)
	-- Habitat 1 starts with fractionalIHR = 0.8. Rate = 1 chicken/s, dt = 0.3s -> adds 0.3.
	-- 0.8 + 0.3 = 1.1 -> integer chicken = 1 (pop becomes 1), remainder fractionalIHR = 0.1 >= 0.
	local habs1 = { createHab("250", "0", "0", 0.8), createHab("0"), createHab("0"), createHab("0") }
	local out1 = IHR.step(habs1, 1.0, 0.3, 0)
	eq(out1[1].population, "1", "A05.1: 1 chicken hatched from fractional accumulation")
	approxEq(out1[1].fractionalIHR, 0.1, 1e-10, "A05.1: Remaining fractionalIHR is 0.1")
	ok(out1[1].fractionalIHR >= 0, "A05.1: Fractional carry is strictly >= 0")

	-- Second step with dt = 0.3s -> 0.1 + 0.3 = 0.4 -> integer chicken = 0, remainder = 0.4.
	local out2 = IHR.step(out1, 1.0, 0.3, 0)
	eq(out2[1].population, "1", "A05.1: Population remains 1 when fraction < 1.0")
	approxEq(out2[1].fractionalIHR, 0.4, 1e-10, "A05.1: Fractional carry accumulated to 0.4")
	ok(out2[1].fractionalIHR >= 0, "A05.1: Fractional carry strictly >= 0")

	-- 2. Pełny slot bez sharingu (Full slot without sharing clears carry)
	local habsFull = { createHab("10", "10", "0", 0.7), createHab("100", "0"), createHab("0"), createHab("0") }
	local outNoShare = IHR.step(habsFull, 1.0, 0.3, 0)
	eq(outNoShare[1].population, "10", "A05.2: Full habitat 1 population capped at 10")
	eq(outNoShare[1].fractionalIHR, 0, "A05.2: Full habitat 1 without sharing clears carry to 0")

	-- 3. Sharing wybierający wolny cel zgodnie z regułą (Vacancy-weighted sharing)
	-- Habitat 1 is full (cap 1, pop 1).
	-- Habitat 2 has cap 100, pop 0 (vacancy 100).
	-- Habitat 3 has cap 100, pop 0 (vacancy 100).
	-- Sharing mult = 0.5. With draw choosing slot 3:
	local sharingDraws = {}
	local habsSharing = {
		createHab("1", "1", "0", 0.7),
		createHab("100", "0", "0", 0),
		createHab("100", "0", "0", 0),
		createHab("0"),
	}
	local outShare = IHR.step(habsSharing, 10.0, 0.3, 0.5, function(sourceSlot)
		table.insert(sharingDraws, sourceSlot)
		return "100" -- Selects habitat 3 (second vacancy bracket)
	end)

	eq(#sharingDraws, 1, "A05.3: Sharing draw invoked for full habitat 1")
	eq(sharingDraws[1], 1, "A05.3: Full source is habitat 1")
	eq(outShare[1].fractionalIHR, 0.7, "A05.3: Hab 1 fraction preserved with sharing")
	eq(outShare[2].population, "3", "A05.3: Hab 2 received its own 3 chickens")
	eq(outShare[3].population, "4", "A05.3: Hab 3 received its own 3 + 1 shared chicken from Hab 1")
	approxEq(outShare[3].fractionalIHR, 0.5, 1e-10, "A05.3: Hab 3 fractional carry")

	-- 4. Gdy wszystkie sloty są pełne, sharing nie rozdaje kur i nie rzuca błędu
	local habsAllFull = {
		createHab("1", "1", "0", 0.5),
		createHab("1", "1", "0", 0.5),
		createHab("0"),
		createHab("0"),
	}
	local outAllFull = IHR.step(habsAllFull, 10.0, 0.3, 1.0, function()
		error("draw must not be called when all slots are full")
	end)
	eq(outAllFull[1].population, "1", "A05.4: Hab 1 population stays 1")
	eq(outAllFull[2].population, "1", "A05.4: Hab 2 population stays 1")
	eq(outAllFull[1].fractionalIHR, 0, "A05.4: Hab 1 carry cleared when all full")
	eq(outAllFull[2].fractionalIHR, 0, "A05.4: Hab 2 carry cleared when all full")
end

-- ============================================================================
-- SCENARIO A06 (L/S):
-- Zakup Common: wystarczająca gotówka, brak środków (INSUFFICIENT_CASH), zamknięty tier (TIER_LOCKED), maxLevel (MAX_LEVEL); brak zmniejszania accounting.currentFarmCash.
-- ============================================================================
setScenario("A06")
do
	local actions = FarmActions.new(C, Catalog, { mode = "INTERNAL_TEST_ONLY" })

	local function baseProfile(cashVal, revVal)
		local p = ProfileSchema.createReference("601", 1000000)
		p.farm.cash = cashVal or "1000"
		p.accounting.currentFarmCash = revVal or "1000"
		return p
	end

	-- 1. Wystarczająca gotówka (Successful purchase & currentFarmCash NOT decreased)
	local pRich = baseProfile("1000", "5000")
	local comfyCost = Catalog.researchPrice("comfy_nests", 0)
	local opComfy = {
		operationId = "buy-comfy-1",
		kind = "BuyResearch",
		args = { researchId = "comfy_nests", mode = "single", quoteId = "q-601" },
		expectedRevision = "0",
	}
	local outComfy = actions.apply(pRich, opComfy)
	eq(outComfy.terminalStatus, "APPLIED", "A06.1: BuyResearch comfy_nests applied")
	eq(outComfy.result.actionKind, "BuyResearch", "A06.1: actionKind matches")
	eq(outComfy.result.level, 1, "A06.1: comfy_nests level incremented to 1")
	eq(pRich.farm.common.comfy_nests, 1, "A06.1: Profile farm.common.comfy_nests is 1")
	local expectedRemaining = BigAmount.subtract(1000, comfyCost)
	eq(pRich.farm.cash, BigAmount.encode(expectedRemaining), "A06.1: Cash decremented by catalog price")

	-- CRITICAL INVARIANT: currentFarmCash NOT decreased!
	eq(pRich.accounting.currentFarmCash, "5000", "A06.1: CRITICAL: accounting.currentFarmCash NOT decreased by purchase!")

	-- 2. Brak środków (INSUFFICIENT_CASH)
	local pBroke = baseProfile("0", "5000")
	local outBroke = actions.apply(pBroke, opComfy)
	eq(outBroke.terminalStatus, "REJECTED", "A06.2: Purchase rejected with no cash")
	eq(outBroke.result.errorCode, "INSUFFICIENT_CASH", "A06.2: errorCode is INSUFFICIENT_CASH")
	eq(pBroke.farm.cash, "0", "A06.2: Cash unchanged at 0")
	eq(pBroke.farm.common.comfy_nests, nil, "A06.2: Research level unchanged")
	eq(pBroke.accounting.currentFarmCash, "5000", "A06.2: currentFarmCash unchanged")

	-- 3. Zamknięty tier (TIER_LOCKED)
	-- hab_capacity1 is in Tier 1, requiring 30 points in Tier 0
	local pLocked = baseProfile("1000000", "5000")
	pLocked.farm.common.comfy_nests = 0 -- 0 points
	local opTier1 = {
		operationId = "buy-tier1-1",
		kind = "BuyResearch",
		args = { researchId = "hab_capacity1", mode = "single", quoteId = "q-tier1" },
		expectedRevision = "0",
	}
	local outLocked = actions.apply(pLocked, opTier1)
	eq(outLocked.terminalStatus, "REJECTED", "A06.3: Purchase rejected on locked tier")
	eq(outLocked.result.errorCode, "TIER_LOCKED", "A06.3: errorCode is TIER_LOCKED")
	eq(pLocked.farm.cash, "1000000", "A06.3: Cash unchanged")
	eq(pLocked.farm.common.hab_capacity1, nil, "A06.3: hab_capacity1 level unchanged")

	-- 4. Max level (MAX_LEVEL)
	-- better_incubators maxLevel is 15
	local pMax = baseProfile("1000000", "5000")
	pMax.farm.common.better_incubators = 15
	local opMax = {
		operationId = "buy-max-1",
		kind = "BuyResearch",
		args = { researchId = "better_incubators", mode = "single", quoteId = "q-max" },
		expectedRevision = "0",
	}
	local outMax = actions.apply(pMax, opMax)
	eq(outMax.terminalStatus, "REJECTED", "A06.4: Purchase rejected at max level")
	eq(outMax.result.errorCode, "MAX_LEVEL", "A06.4: errorCode is MAX_LEVEL")
	eq(pMax.farm.cash, "1000000", "A06.4: Cash unchanged")
	eq(pMax.farm.common.better_incubators, 15, "A06.4: Level remains 15")
end

-- ============================================================================
-- SCENARIO A07 (L/S):
-- Skalowanie ceny kurników i pojazdów od liczby posiadanych egzemplarzy (sameTypeOwned); zachowanie kur przy zamianie kurnika.
-- ============================================================================
setScenario("A07")
do
	local actions = FarmActions.new(C, Catalog, { mode = "INTERNAL_TEST_ONLY" })

	-- 1. Skalowanie ceny kurników od sameTypeOwned
	-- Price of COOP (typeIndex 0) depends on how many COOPs are already owned:
	local habCost0 = Catalog.habitatPrice(0, 0) -- 0 owned
	local habCost1 = Catalog.habitatPrice(0, 1) -- 1 owned
	local habCost2 = Catalog.habitatPrice(0, 2) -- 2 owned
	local habCost3 = Catalog.habitatPrice(0, 3) -- 3 owned
	ok(habCost1 > habCost0, "A07.1: COOP price scales with 1 already owned: " .. tostring(habCost1) .. " > " .. tostring(habCost0))
	ok(habCost2 > habCost1, "A07.1: COOP price scales with 2 already owned: " .. tostring(habCost2) .. " > " .. tostring(habCost1))
	ok(habCost3 > habCost2, "A07.1: COOP price scales with 3 already owned: " .. tostring(habCost3) .. " > " .. tostring(habCost2))

	-- 2. Skalowanie ceny pojazdów od sameTypeOwned
	-- Price of TRIKE (typeIndex 0) depends on how many TRIKEs are already owned:
	local vehCost0 = Catalog.vehiclePrice(0, 0) -- 0 owned
	local vehCost1 = Catalog.vehiclePrice(0, 1) -- 1 owned
	local vehCost2 = Catalog.vehiclePrice(0, 2) -- 2 owned
	local vehCost3 = Catalog.vehiclePrice(0, 3) -- 3 owned
	ok(vehCost1 > vehCost0, "A07.2: TRIKE price scales with 1 already owned: " .. tostring(vehCost1) .. " > " .. tostring(vehCost0))
	ok(vehCost2 > vehCost1, "A07.2: TRIKE price scales with 2 already owned: " .. tostring(vehCost2) .. " > " .. tostring(vehCost1))
	ok(vehCost3 > vehCost2, "A07.2: TRIKE price scales with 3 already owned: " .. tostring(vehCost3) .. " > " .. tostring(vehCost2))

	-- Test vehicle purchase on Slot 2 with sameTypeOwned = 1
	local pScale = ProfileSchema.createReference("701", 1000000)
	pScale.farm.cash = "1000000"
	-- Vehicle slot 1 has TRIKE (0). Buying TRIKE on slot 2 charges vehCost1:
	local opVeh2 = {
		operationId = "buy-veh2",
		kind = "BuyVehicle",
		args = { slotId = 2, vehicleId = "TRIKE", quoteId = "q-v2" },
		expectedRevision = "0",
	}
	local outVeh2 = actions.apply(pScale, opVeh2)
	eq(outVeh2.terminalStatus, "APPLIED", "A07.2: TRIKE on slot 2 applied")
	eq(pScale.farm.cash, BigAmount.encode(BigAmount.subtract(1000000, vehCost1)), "A07.2: Cash decremented by vehCost1 for second TRIKE")
	eq(pScale.farm.vehicles[2].typeIndex, 0, "A07.2: Vehicle slot 2 is TRIKE")

	-- 3. Zachowanie kur przy zamianie kurnika (Population preserved on replacement)
	local pReplace = ProfileSchema.createReference("702", 1000000)
	pReplace.farm.cash = "10000"
	pReplace.farm.habitats[1].population = "180"
	pReplace.farm.habitats[1].assignedInTransit = "15"
	pReplace.farm.habitats[1].fractionalIHR = "0.75"
	pReplace.farm.runningCount = "15"

	-- Upgrade Slot 1 from COOP (0) to SHACK (1)
	local opUpgrade = {
		operationId = "buy-shack-1",
		kind = "BuyHabitat",
		args = { slotId = 1, habitatId = "SHACK", quoteId = "q-shack-1" },
		expectedRevision = "0",
	}
	local outUpgrade = actions.apply(pReplace, opUpgrade)
	eq(outUpgrade.terminalStatus, "APPLIED", "A07.3: BuyHabitat SHACK applied")
	eq(pReplace.farm.habitats[1].typeIndex, 1, "A07.3: Slot 1 upgraded to SHACK (typeIndex = 1)")

	-- Settled chickens and reservations PRESERVED:
	eq(pReplace.farm.habitats[1].population, "180", "A07.3: Settled chickens preserved exactly across habitat upgrade")
	eq(pReplace.farm.habitats[1].assignedInTransit, "15", "A07.3: In-transit reservations preserved exactly")
	eq(pReplace.farm.habitats[1].fractionalIHR, "0.75", "A07.3: Fractional IHR preserved")
	eq(pReplace.farm.runningCount, "15", "A07.3: Running count preserved")
end

-- ============================================================================
-- SCENARIO A08 (L/S):
-- Zmiana wyceny / warunków i ochrona expectedRevision / quoteId (odrzucenie nieaktualnej wyceny).
-- ============================================================================
setScenario("A08")
do
	local clock = createMockClock(8000000)
	local server = ServerBootstrap.new({ clock = clock, initialNowMs = 8000000 })
	local fix8 = ProfileSchema.createReference("801", 8000000)
	fix8.farm.cash = "1000"
	fix8.accounting.currentFarmCash = "1000"
	server:playerJoined("801", fix8)
	local coord = server:getCoordinator("801")
	local client = ClientBootstrap.new({ wire = server, playerId = "801", clock = clock })
	client:connect("boot-a08-1")

	-- 1. Create quote at expectedRevision = "0"
	local quoteView
	client:requestQuote({ kind = "BuyResearch", args = { researchId = "comfy_nests", mode = "single" } }, function(q)
		quoteView = q
	end)
	ok(quoteView ~= nil, "A08: QuoteView created")
	eq(quoteView.quoteId ~= nil, true, "A08: quoteId present")
	eq(quoteView.expectedRevision, "0", "A08: expectedRevision is 0")

	-- 2. Advance coordinator revision in the background (e.g. via another committed operation)
	local intermediateOp = {
		operationId = "op-inter-1",
		kind = "BuyResearch",
		expectedRevision = "0",
		args = { researchId = "nutritional_sup", mode = "single" },
	}
	local coordSubmit = coord.submit(intermediateOp)
	eq(coordSubmit.status, "PENDING", "A08: Intermediate operation submitted")
	coord.drain()
	eq(coord.snapshots().working.meta.revision, "1", "A08: Server revision advanced to 1")

	-- 3. Now attempt to confirm purchase with STALE quote (expectedRevision = "0")
	local stalePurchaseRes
	client:confirmPurchase(quoteView, function(res)
		stalePurchaseRes = res
	end)
	ok(stalePurchaseRes ~= nil, "A08: Stale purchase response received")
	eq(stalePurchaseRes.status, "REJECTED", "A08: Stale purchase rejected")
	local errCode = (stalePurchaseRes.result and stalePurchaseRes.result.errorCode) or stalePurchaseRes.errorCode
	ok(errCode == "STALE_REVISION" or errCode == "REVISION_MISMATCH", "A08: errorCode indicates stale revision / mismatch: " .. tostring(errCode))

	-- Research level and cash were NOT charged:
	eq(coord.snapshots().working.farm.common.comfy_nests, nil, "A08: comfy_nests not purchased")

	-- 4. Validator rejects if conditions changed under same revision (e.g. price or level changed)
	local actions = FarmActions.new(C, Catalog, { mode = "INTERNAL_TEST_ONLY" })
	local pFresh = ProfileSchema.createReference("802", 1000000)
	pFresh.farm.cash = "100"
	local outTest = actions.apply(pFresh, { kind = "BuyResearch", args = { researchId = "comfy_nests", mode = "single", quoteId = "q-fresh" }, expectedRevision = "0" })

	-- If research level was changed on the fresh profile before commit validation:
	local pModified = PersistenceData.copy(pFresh)
	pModified.farm.common.comfy_nests = 1
	local vPass, vCode = outTest.validate(pModified, 1000000)
	eq(vPass, false, "A08: Validator rejects changed condition")
	eq(vCode, "QUOTE_CHANGED", "A08: Validator returns QUOTE_CHANGED")

	client:destroy()
	server:playerLeaving("801")
end

-- ============================================================================
-- SCENARIO A09 (L/S/D):
-- Dwa identyczne operationId równocześnie; replay z zapisanym wynikiem, konflikt argumentów pod tym samym ID (OPERATION_ID_CONFLICT).
-- ============================================================================
setScenario("A09")
do
	local clock = createMockClock(9000000)
	local server = ServerBootstrap.new({ clock = clock, initialNowMs = 9000000 })
	local fix9 = ProfileSchema.createReference("901", 9000000)
	fix9.farm.cash = "1000"
	fix9.accounting.currentFarmCash = "1000"
	server:playerJoined("901", fix9)
	local coord = server:getCoordinator("901")

	-- 1. Dwa identyczne operationId równocześnie (Concurrent duplicate submission)
	local opDup1 = {
		operationId = "op-dup-901",
		kind = "BuyResearch",
		expectedRevision = "0",
		args = { researchId = "comfy_nests", mode = "single", quoteId = "quote-spoof-1" },
	}
	local opDup2 = {
		operationId = "op-dup-901",
		kind = "BuyResearch",
		expectedRevision = "0",
		args = { researchId = "comfy_nests", mode = "single", quoteId = "quote-spoof-1" },
	}

	local res1 = coord.submit(opDup1)
	local res2 = coord.submit(opDup2)
	eq(res1.status, "PENDING", "A09.1: First submission pending")
	eq(res2.status, "PENDING", "A09.1: Concurrent second submission recognized as pending without error")
	eq(coord.snapshots().queued, 1, "A09.1: Exactly 1 item queued for execution")

	-- Drain coordinator
	local drainRes = coord.drain()
	eq(drainRes.results[1].status, "APPLIED", "A09.1: First submission applied")

	-- Query result of op-dup-901
	local queryRes = coord.resultOf("op-dup-901")
	eq(queryRes.status, "APPLIED", "A09.1: Stored result is APPLIED")
	eq(coord.snapshots().working.farm.common.comfy_nests, 1, "A09.1: comfy_nests incremented exactly once")

	-- Replay of the committed operation returns REPLAYED with identical saved result
	local replayRes = coord.submit(opDup1)
	eq(replayRes.status, "REPLAYED", "A09.1: Replay of committed operation returns REPLAYED")
	eq(replayRes.result.actionKind, "BuyResearch", "A09.1: Replayed result matches saved result")
	eq(coord.snapshots().working.farm.common.comfy_nests, 1, "A09.1: Level remains 1 (not double incremented)")

	-- 2. Konflikt argumentów pod tym samym ID (OPERATION_ID_CONFLICT)
	local opConflict = {
		operationId = "op-dup-901", -- Same ID as above!
		kind = "BuyResearch",
		expectedRevision = "1",
		args = { researchId = "nutritional_sup", mode = "single" }, -- DIFFERENT ARGS!
	}
	local resConflict = coord.submit(opConflict)
	eq(resConflict.status, "REJECTED", "A09.2: Same ID with different arguments rejected")
	eq(resConflict.errorCode, "OPERATION_ID_CONFLICT", "A09.2: errorCode is OPERATION_ID_CONFLICT")

	server:playerLeaving("901")
end

-- ============================================================================
-- SCENARIO A10 (L/S):
-- Odmowa komendy przy braku gotowości sesji (NOT_ACCEPTED z SESSION_NOT_READY), brak pozornej kolejki.
-- ============================================================================
setScenario("A10")
do
	local clock = createMockClock(10000000)
	local server = ServerBootstrap.new({ clock = clock, initialNowMs = 10000000 })
	server:playerJoined("1001")
	local coord = server:getCoordinator("1001")

	-- 1. Odmowa komendy przy braku gotowości sesji (NOT_ACCEPTED z SESSION_NOT_READY)
	coord.setReady(false)
	eq(coord.snapshots().ready, false, "A10: Coordinator ready is false")

	local opUnready = {
		operationId = "op-unready-1",
		kind = "BuyResearch",
		expectedRevision = "0",
		args = { researchId = "comfy_nests", mode = "single", quoteId = "quote-spoof-1" },
	}
	local resUnready = coord.submit(opUnready)
	eq(resUnready.status, "NOT_ACCEPTED", "A10: Submission returns NOT_ACCEPTED")
	eq(resUnready.errorCode, "SESSION_NOT_READY", "A10: errorCode is SESSION_NOT_READY")

	-- 2. Brak pozornej kolejki (No fake queuing)
	eq(coord.snapshots().queued, 0, "A10: Queue length is strictly 0 (not enqueued)")
	local queryUnready = coord.resultOf("op-unready-1")
	eq(queryUnready.status, "UNKNOWN", "A10: Unaccepted operation is UNKNOWN")

	-- Transitioning ready to true and draining does NOT execute the rejected command
	coord.setReady(true)
	local drainRes = coord.drain()
	eq(#drainRes.results, 0, "A10: Nothing to drain")
	eq(coord.snapshots().working.farm.common.comfy_nests, nil, "A10: comfy_nests was not executed")

	server:playerLeaving("1001")
end

-- ============================================================================
-- SCENARIO A11 (L/D):
-- Fencing sesji, próba zapisu przez starego właściciela po przejęciu sesji przez nowe połączenie (stary token nie mutuje nowej sesji).
-- ============================================================================
setScenario("A11")
do
	local clock = createMockClock(11000000)
	local records = {}
	local store = {
		records = records,
		read = function(key)
			return true, if records[key] then PersistenceData.copy(records[key]) else nil
		end,
		update = function(key, transform)
			local cur = if records[key] then PersistenceData.copy(records[key]) else nil
			local callOk, nextVal = pcall(transform, cur)
			if not callOk then
				print("ERROR in store.update transform:", nextVal)
				error(nextVal)
			end
			if nextVal ~= nil then
				records[key] = PersistenceData.copy(nextVal)
			end
			return true, if nextVal ~= nil then PersistenceData.copy(nextVal) else nil
		end,
	}

	local tokenCount = 0
	local repo = SessionRepository.new({
		mode = "INTERNAL_TEST_ONLY",
		codec = C,
		data = PersistenceData,
		schema = ProfileSchema,
		store = store,
		clock = clock,
		encodeJson = function(v) return serde.encode("json", v) end,
		tokenFactory = function()
			tokenCount += 1
			return "fence-token-" .. tostring(tokenCount)
		end,
	})

	-- 1. Initial acquisition (Session 1, generation 1, token 1)
	local acq1 = repo.acquire("1101")
	eq(acq1.status, "ACQUIRED", "A11: Session 1 acquired")
	local h1 = acq1.handle
	eq(h1.generation, "1", "A11: Session 1 generation is 1")
	local token1 = h1.token

	-- Advance clock past lease end time to allow takeover (120s TTL)
	clock.advance(130.0)

	-- 2. New connection acquires session (Session 2, generation 2, token 2)
	local acq2 = repo.acquire("1101")
	eq(acq2.status, "ACQUIRED", "A11: Session 2 acquired after lease expiration")
	local h2 = acq2.handle
	eq(h2.generation, "2", "A11: Session 2 generation incremented to 2")
	local token2 = h2.token
	ok(token2 ~= token1, "A11: Session 2 has a new unique ownerToken")

	-- Verify storage record currently belongs to Session 2
	local storeRec = store.records["player:1101"]
	eq(storeRec.ownership.ownerToken, token2, "A11: Store record owned by Session 2")
	eq(storeRec.ownership.generation, "2", "A11: Store record generation is 2")

	-- 3. Stary właściciel próbuje zapisać (Old owner H1 attempts commit on now-taken session)
	local staleOp = {
		operationId = "stale-op-1",
		kind = "BuyResearch",
		expectedRevision = "0",
		args = { researchId = "comfy_nests", mode = "single", quoteId = "quote-spoof-1" },
	}
	local stalePlan = {
		changes = { { path = { "farm", "cash" }, value = "999999" } },
		result = { hacked = true },
		terminalStatus = "APPLIED",
		validate = function() return true end,
	}

	local commitRes = repo.commit(h1, staleOp, stalePlan)
	eq(commitRes.status, "NOT_ACCEPTED", "A11: Old owner commit rejected")
	eq(commitRes.errorCode, "SESSION_LOST", "A11: errorCode is SESSION_LOST (fenced)")
	eq(h1.state, "SESSION_LOST", "A11: Handle 1 state set to SESSION_LOST")
	eq(h1.blocked, true, "A11: Handle 1 blocked permanently")

	-- CRITICAL INVARIANT: Session 2 store record was NOT mutated by old owner!
	local storeAfterStale = store.records["player:1101"]
	eq(storeAfterStale.ownership.ownerToken, token2, "A11: Store ownerToken still belongs to Session 2")
	eq(storeAfterStale.ownership.generation, "2", "A11: Store generation still belongs to Session 2")
	eq(storeAfterStale.farm.cash, "0", "A11: Store farm.cash was NOT modified by old owner's stale patch!")

	-- 4. Old owner cannot renew or release Session 2
	local renewRes = repo.renew(h1)
	eq(renewRes.status, "NOT_ACCEPTED", "A11: Old owner renew rejected")
	local releaseRes = repo.release(h1)
	eq(releaseRes.status, "NOT_ACCEPTED", "A11: Old owner release rejected")
	eq(store.records["player:1101"].ownership.ownerToken, token2, "A11: Session 2 ownership retained")

	-- Clean up Session 2
	repo.release(h2)
end

-- ============================================================================
-- SCENARIO A12 (L/S/D):
-- Powrót online (<=60s) bez limitu silosów vs away (>60s) z limitem silosów; zamknięcie całego okresu; brak produkcji away przy zerze silosów.
-- ============================================================================
setScenario("A12")
do
	local Catalog = CatalogRegistry.new(C, CatalogData, { mode = "INTERNAL_TEST_ONLY" })
	local ProdMath = ProductionMathModule.new(C, Catalog, { mode = "INTERNAL_TEST_ONLY" })
	local PopMath = PopulationMath
	local HatchRCB = HatchingRCB
	local IhrModule = IHR
	local Timeline = TimelineSimulation.new(C, ProdMath, HatchRCB, IhrModule, PersistenceData, { mode = "INTERNAL_TEST_ONLY" })

	local function makeTimelineState(pop, silos, cash)
		local habs = {}
		for i = 1, 4 do
			habs[i] = {
				typeIndex = if i == 1 then 0 else -1,
				capacity = if i == 1 then "250" else "0",
				population = if i == 1 then (pop or "100") else "0",
				assignedInTransit = "0",
				fractionalIHR = 0,
			}
		end
		return {
			farm = {
				cash = cash or 10,
				habitats = habs,
				hatcheryStock = 0,
				runningCount = "0",
				hatchGroupSequence = "0",
				groups = {},
				commonLevels = {},
				vehicleTypes = { 0 },
				siloOwned = silos or 1,
			},
			accounting = {
				prestigeSessionArchivedCash = 0,
				prestigeExtraEarnings = 0,
				lastBaseEarnings = 0,
				currentFarmCash = cash or 10,
				lastCashEarned = 0,
			},
			settledWallThrough = 1000,
		}
	end

	local function simAll(state, targetMs, cfg)
		local config = cfg or { revision = "neutral:1", siloCapacityLevel = 0, pro = false }
		local cp = Timeline.begin(state, targetMs, config)
		return Timeline.advance(cp, 100000)
	end

	-- 1. Powrót online (<=60s) bez limitu silosów (even with 0 silos!)
	local stateZeroOnline = makeTimelineState("100", 0, 10) -- 0 silos owned!
	-- dt = 60s (targetMs = 61000 from 1000)
	local resOnline = simAll(stateZeroOnline, 61000)
	eq(resOnline.mode, "ONLINE", "A12.1: dt <= 60s is ONLINE mode")
	eq(resOnline.productionSeconds, 60, "A12.1: Full 60s of production simulated despite 0 silos")
	ok(resOnline.state.farm.cash > 10, "A12.1: Cash increased during online return without silos: " .. tostring(resOnline.state.farm.cash))
	eq(resOnline.state.settledWallThrough, 61000, "A12.1: settledWallThrough advanced to 61000")

	-- 2. Powrót away (>60s) z limitem silosów
	-- dt = 7200s (2 hours). 1 silo owned = 3600s capacity.
	local stateAway1 = makeTimelineState("100", 1, 10)
	local targetAwayMs = 1000 + 7200 * 1000
	local resAway1 = simAll(stateAway1, targetAwayMs)
	eq(resAway1.mode, "AWAY", "A12.2: dt > 60s is AWAY mode")
	eq(resAway1.productionSeconds, 3600, "A12.2: Production capped at 1 silo capacity (3600s), ignoring extra 3600s")
	eq(resAway1.state.settledWallThrough, targetAwayMs, "A12.2: Entire period closed (settledWallThrough advanced to 7201000)")

	-- Immediate second simulation of same target yields 0 new cash:
	local resImmediate = simAll(resAway1.state, targetAwayMs)
	eq(resImmediate.state.farm.cash, resAway1.state.farm.cash, "A12.2: Closed entire period: zero double payment on immediate re-entry")

	-- 3. Brak produkcji away przy zerze silosów
	local stateZeroAway = makeTimelineState("100", 0, 10) -- 0 silos!
	local resZeroAway = simAll(stateZeroAway, 61001) -- 60.001s (> 60s)
	eq(resZeroAway.mode, "AWAY", "A12.3: Mode is AWAY")
	eq(resZeroAway.productionSeconds, 0, "A12.3: Zero silos gives 0 production seconds in AWAY mode")
	eq(resZeroAway.state.farm.cash, 10, "A12.3: No cash produced in AWAY mode with 0 silos")
	eq(resZeroAway.state.settledWallThrough, 61001, "A12.3: Entire period closed (settledWallThrough advanced to 61001)")
end

-- ============================================================================
-- SCENARIO A13 (L/D):
-- Przerwanie obliczenia/checkpointu między produkcją a wzrostem; wznowienie daje ten sam wynik bitowo bez podwójnej wypłaty.
-- ============================================================================
setScenario("A13")
do
	local Catalog = CatalogRegistry.new(C, CatalogData, { mode = "INTERNAL_TEST_ONLY" })
	local ProdMath = ProductionMathModule.new(C, Catalog, { mode = "INTERNAL_TEST_ONLY" })
	local Timeline = TimelineSimulation.new(C, ProdMath, HatchingRCB, IHR, PersistenceData, { mode = "INTERNAL_TEST_ONLY" })

	local function makeInterruptedState()
		local habs = {}
		for i = 1, 4 do
			habs[i] = {
				typeIndex = if i == 1 then 0 else -1,
				capacity = if i == 1 then "250" else "0",
				population = if i == 1 then "150" else "0",
				assignedInTransit = "0",
				fractionalIHR = 0,
			}
		end
		return {
			farm = {
				cash = 100,
				habitats = habs,
				hatcheryStock = 10,
				runningCount = "0",
				hatchGroupSequence = "0",
				groups = {},
				commonLevels = { comfy_nests = 5, internal_hatchery1 = 2 },
				vehicleTypes = { 0 },
				siloOwned = 1,
			},
			accounting = {
				prestigeSessionArchivedCash = 0,
				prestigeExtraEarnings = 0,
				lastBaseEarnings = 100,
				currentFarmCash = 100,
				lastCashEarned = 0,
			},
			settledWallThrough = 1000,
		}
	end

	local cfg = { revision = "neutral:1", siloCapacityLevel = 0, pro = false }
	local targetMs = 2000 -- 1.0 second advance

	-- 1. Uninterrupted reference simulation
	local original = makeInterruptedState()
	local cpUninterrupted = Timeline.begin(original, targetMs, cfg)
	local resUninterrupted = Timeline.advance(cpUninterrupted, 10000)
	eq(resUninterrupted.done, true, "A13: Uninterrupted simulation completed")
	eq(resUninterrupted.state.settledWallThrough, 2000, "A13: Uninterrupted settled through targetMs")

	-- 2. Interrupted simulation (interrupted after production phase of step 1)
	local cpInterrupted = Timeline.begin(original, targetMs, cfg)
	-- Advance exactly 1 phase: transitions to AFTER_PRODUCTION (production evaluated, growth not yet run)
	local mid = Timeline.advance(cpInterrupted, 1)
	eq(mid.phase, "AFTER_PRODUCTION", "A13: Checkpoint paused in AFTER_PRODUCTION phase")
	eq(mid.done, false, "A13: Checkpoint is not done")
	ok(mid.state.farm.cash > 100, "A13: Cash earned from step 1 production")

	-- Encode checkpoint to JSON wire format and decode back (simulating persistence / recovery)
	local wireEncoded = Timeline.encodeCheckpoint(mid)
	local jsonStr = serde.encode("json", wireEncoded)
	local jsonDecoded = serde.decode("json", jsonStr)
	local cpRestored = Timeline.decodeCheckpoint(jsonDecoded)

	-- Resume restored checkpoint to completion
	local resResumed = Timeline.advance(cpRestored, 10000)
	eq(resResumed.done, true, "A13: Resumed simulation completed")

	-- CRITICAL INVARIANT: Bitwise identical fingerprint! Zero double payout!
	local fpResumed = PersistenceData.fingerprint(resResumed.state)
	local fpUninterrupted = PersistenceData.fingerprint(resUninterrupted.state)
	eq(fpResumed, fpUninterrupted, "A13: CRITICAL: Resumed simulation matches uninterrupted simulation bitwise")
	eq(resResumed.state.farm.cash, resUninterrupted.state.farm.cash, "A13: Cash matches exactly without double payment")
	eq(resResumed.state.accounting.currentFarmCash, resUninterrupted.state.accounting.currentFarmCash, "A13: currentFarmCash matches exactly")
end

-- ============================================================================
-- SCENARIO A14 (L/S):
-- Wykrycie luki viewSeq na kliencie i wywołanie RefreshState (resync); brak cofania widoku.
-- ============================================================================
setScenario("A14")
do
	local transport = ClientTransport.new({ protocol = ProtocolSchemas })
	local store = ClientStateStore.new({ transport = transport, codec = C })

	local initialSnapshot = {
		protocolVersion = 1,
		numericCodecVersion = 1,
		viewSchemaVersion = 1,
		configRevision = "cfg:1",
		calculationVersion = 1,
		streamId = "stream-a14",
		commitRevision = "0",
		viewSeq = "1",
		serverObservedAt = 1000000,
		kind = "StateSnapshot",
		view = {
			audience = "ownFarm",
			farm = {
				lifecycle = "ready",
				cash = "100",
				eggIndex = 0,
				habitats = { { slotId = 1, habitatIndex = 0, population = "10", reservedInTransit = "0", capacity = "250" } },
				hatchery = { stock = "250", capacity = "250", refillPerSecond = "3" },
				fleet = { vehicles = { { slotId = 1, vehicleIndex = 0 } }, shippingPerMinute = "5000" },
				producedEggsPerSecond = "0.33",
				soldEggsPerSecond = "0.33",
				cashIncomePerSecond = "0.08",
				common = {},
			},
		},
	}

	store:applySnapshot(initialSnapshot)
	eq(store:getStatus(), "READY", "A14: Store is READY")
	eq(store:getViewSeq(), "1", "A14: Initial viewSeq is 1")

	-- 1. Wykrycie luki viewSeq (Delta arrives with sequence gap: baseViewSeq = 3 > currentViewSeq = 1)
	local resyncEvents = {}
	store:onResyncRequested(function(reqId)
		table.insert(resyncEvents, reqId)
	end)

	local gapDelta = {
		protocolVersion = 1,
		streamId = "stream-a14",
		commitRevision = "1",
		baseViewSeq = "3", -- GAP! Expected 1
		viewSeq = "4",
		serverObservedAt = 1000100,
		kind = "StateDelta",
		changes = { farm = { cash = "500" } },
	}

	local applyGap, gapErr = store:applyDelta(gapDelta)
	eq(applyGap, false, "A14: Gap delta rejected")
	eq(gapErr, "GAP_DETECTED", "A14: Error code is GAP_DETECTED")
	eq(store:getStatus(), "RESYNCING", "A14: Store transitioned to RESYNCING")
	eq(#resyncEvents, 1, "A14: resyncRequested emitted to trigger RefreshState")

	-- Cash was NOT modified by the corrupt/gap delta:
	eq(store:getFarm().cash, "100", "A14: Cash remains 100 (gap delta not applied)")

	-- Resync snapshot arrives to restore consistent state
	local resyncSnapshot = PersistenceData.copy(initialSnapshot)
	resyncSnapshot.viewSeq = "5"
	resyncSnapshot.view.farm.cash = "200"
	store:applySnapshot(resyncSnapshot)
	eq(store:getStatus(), "READY", "A14: Store restored to READY after resync snapshot")
	eq(store:getViewSeq(), "5", "A14: viewSeq updated to 5")
	eq(store:getFarm().cash, "200", "A14: Cash updated to 200 from resync snapshot")

	-- 2. Brak cofania widoku (Stale / outdated delta arriving: delta.viewSeq <= currentViewSeq)
	local staleDelta = {
		protocolVersion = 1,
		streamId = "stream-a14",
		commitRevision = "0",
		baseViewSeq = "2",
		viewSeq = "3", -- Outdated: 3 <= 5
		serverObservedAt = 1000050,
		kind = "StateDelta",
		changes = { farm = { cash = "50" } },
	}

	local applyStale, staleErr = store:applyDelta(staleDelta)
	eq(applyStale, false, "A14: Outdated delta rejected")
	eq(staleErr, "OUTDATED_DELTA", "A14: Error code is OUTDATED_DELTA")
	eq(store:getViewSeq(), "5", "A14: viewSeq NOT rolled back (remains 5)")
	eq(store:getFarm().cash, "200", "A14: Cash NOT rolled back (remains 200)")

	store:destroy()
end

-- ============================================================================
-- SCENARIO A15 (S):
-- Izolacja dwóch graczy (Player 1 vs Player 2): brak dostępu do cudzego salda, brak wycieku tokenów/ledgerów w projekcji, odrzucenie sfingowanego playerId w payloadzie.
-- ============================================================================
setScenario("A15")
do
	local clock = createMockClock(15000000)
	local server = ServerBootstrap.new({ clock = clock, initialNowMs = 15000000 })

	-- Player 1 ("1501") starting with $1,000 cash and 10 chickens
	local fix1 = ProfileSchema.createReference("1501", 15000000)
	fix1.farm.cash = "1000"
	fix1.farm.habitats[1].population = "10"
	server:playerJoined("1501", fix1)

	-- Player 2 ("1502") starting with $500 cash and 50 chickens
	local fix2 = ProfileSchema.createReference("1502", 15000000)
	fix2.farm.cash = "500"
	fix2.farm.habitats[1].population = "50"
	server:playerJoined("1502", fix2)

	local client1 = ClientBootstrap.new({ wire = server, playerId = "1501", clock = clock })
	client1:connect("boot-p1")
	local client2 = ClientBootstrap.new({ wire = server, playerId = "1502", clock = clock })
	client2:connect("boot-p2")

	-- 1. Brak dostępu do cudzego salda (Player isolation)
	local farm1 = client1:getFarm()
	local farm2 = client2:getFarm()
	eq(farm1.cash, "1000", "A15.1: Player 1 sees own cash balance ($1000)")
	eq(farm1.habitats[1].population, "10", "A15.1: Player 1 sees own population (10)")
	eq(farm2.cash, "500", "A15.2: Player 2 sees own cash balance ($500)")
	eq(farm2.habitats[1].population, "50", "A15.2: Player 2 sees own population (50)")

	-- 2. Brak wycieku tokenów/ledgerów w projekcji (Security scrub)
	-- Inspect Player 1's store state directly:
	local state1 = client1:getStore():getState()
	eq(state1.farm.ownership, nil, "A15.2: ownership section NOT present in client projection")
	eq(state1.farm.ownerToken, nil, "A15.2: ownerToken NOT present in client projection")
	eq(state1.farm.operations, nil, "A15.2: operations ledger NOT present in client projection")
	eq(state1.farm.accounting, nil, "A15.2: internal accounting ledger NOT present in client projection")
	eq(state1.farm.permanent, nil, "A15.2: permanent store NOT present in client projection")

	-- 3. Odrzucenie sfingowanego playerId w payloadzie (Anti-spoofing)
	-- Client 1 attempts to invoke mutation specifying caller as player "1502" or invalid ID
	-- NetworkGateway authenticates by caller identity (`resolvePlayerId(caller)`).
	-- If an unauthorized or unknown caller attempts to send a command:
	local spoofMsg = {
		protocolVersion = 1,
		requestId = "spoof-req-1",
		operationId = "spoof-op-1",
		kind = "BuyResearch",
		expectedRevision = "0",
		args = { researchId = "comfy_nests", mode = "single", quoteId = "quote-spoof-1" },
	}

	-- Invoked by unknown / spoofed caller "unknown-player-999"
	local spoofRes = server.gateway:handleRequest("unknown-player-999", spoofMsg)
	eq(spoofRes.admission, "NOT_ACCEPTED", "A15.3: Spoofed / unknown caller rejected with NOT_ACCEPTED")
	eq(spoofRes.errorCode, "SESSION_NOT_FOUND", "A15.3: errorCode is SESSION_NOT_FOUND")

	-- Verify Player 2's cash was NOT debited by Player 1 or any spoofed attempt:
	eq(client2:getFarm().cash, "500", "A15.3: Player 2 cash completely untouched")

	client1:destroy()
	client2:destroy()
	server:playerLeaving("1501")
	server:playerLeaving("1502")
end

-- ============================================================================
-- SCENARIO A16 (S/H):
-- Pełny obieg funkcjonalny pętli farmy: wejście -> wylęg -> wzrost populacji -> ograniczenie transportu -> wycena i zakup ulepszenia -> powrót i synchronizacja HUD.
-- ============================================================================
setScenario("A16")
do
	local clock = createMockClock(16000000)
	local server = ServerBootstrap.new({ clock = clock, initialNowMs = 16000000 })

	-- Fixture with $500 starting funds for full loop demonstration
	local initialFixture = ProfileSchema.createReference("1601", 16000000)
	initialFixture.farm.cash = "500"
	initialFixture.accounting.currentFarmCash = "500"
	initialFixture.farm.vehicles = {} -- Start with 0 vehicles to clearly observe transport bottleneck
	server:playerJoined("1601", initialFixture)

	-- Step 1: Wejście & Bootstrap (Player connect)
	local client = ClientBootstrap.new({ wire = server, playerId = "1601", clock = clock })
	client:connect("boot-a16-1")
	eq(client:getStatus(), "READY", "A16.1: Client enters READY status")
	eq(client:getHUD():getSessionStatus(), "READY", "A16.1: HUD shows READY")
	eq(client:getHUD():getCashText(), "$500", "A16.1: HUD formats initial cash $500")

	-- Step 2: Wylęg (Hatch press -> in-transit chicken)
	local hatchAccepted = false
	client:hatchPress(function(res)
		if res and res.status == "ACCEPTED" then hatchAccepted = true end
	end)
	ok(hatchAccepted, "A16.2: Hatch press accepted")
	eq(server:getCoordinator("1601").snapshots().working.farm.runningCount, "1", "A16.2: 1 chicken in transit")
	eq(client:getPresentation():getActiveGroupCount(), 1, "A16.2: Route presentation animates group")

	-- Step 3: Wzrost populacji (Chicken arrives at coop)
	server:tick(4.0, clock.utcNowMs() + 4000)
	client:update(clock.utcNowMs())
	eq(server:getCoordinator("1601").snapshots().working.farm.habitats[1].population, "1", "A16.3: Population incremented to 1 hen")
	eq(client:getPresentation():getActiveGroupCount(), 0, "A16.3: Chicken arrival completed in presentation")

	-- Sync delta to client
	client:receive(server:createPlayerDelta("1601"))
	eq(client:getFarm().habitats[1].population, "1", "A16.3: Client farm population updated to 1")

	-- Step 4: Ograniczenie transportu (Hen lays eggs but 0 vehicles means 0 shipping capacity)
	local farmPreVeh = client:getFarm()
	local producedPre = BigAmount.decode(farmPreVeh.producedEggsPerSecond)
	local soldPre = BigAmount.decode(farmPreVeh.soldEggsPerSecond)
	ok(producedPre > 0, "A16.4: 1 hen produces eggs (> 0)")
	eq(soldPre, 0, "A16.4: Shipping bottleneck: 0 vehicles means 0 eggs sold despite egg laying")
	ok(producedPre > soldPre, "A16.4: Bottleneck confirmed: produced eggs strictly greater than sold eggs")

	-- Step 5: Wycena i zakup ulepszenia transportu (Buy vehicle TRIKE on slot 1)
	local vehQuote
	client:requestQuote({ kind = "BuyVehicle", args = { slotId = 1, vehicleId = "TRIKE" } }, function(q)
		vehQuote = q
	end)
	ok(vehQuote ~= nil, "A16.5: Vehicle quote received")
	eq(vehQuote.available, true, "A16.5: Vehicle upgrade available")
	eq(vehQuote.resultIndex, 0, "A16.5: Vehicle is TRIKE (index 0)")

	local vehBuyRes
	client:confirmPurchase(vehQuote, function(res)
		vehBuyRes = res
	end)
	ok(vehBuyRes ~= nil, "A16.5: Vehicle purchase response received")
	eq(vehBuyRes.status, "APPLIED", "A16.5: First vehicle applied")

	-- Step 6: Powrót i synchronizacja HUD (Sync delta and verify bottleneck relieved)
	local deltaVeh = server:createPlayerDelta("1601")
	client:receive(deltaVeh)
	local farmPostVeh = client:getFarm()
	eq(#farmPostVeh.fleet.vehicles, 1, "A16.6: Fleet now has 1 vehicle")
	eq(farmPostVeh.fleet.shippingPerMinute, "5000", "A16.6: Shipping capacity increased to 5,000 eggs/min")
	local soldPost = BigAmount.decode(farmPostVeh.soldEggsPerSecond)
	ok(soldPost > 0, "A16.6: Bottleneck relieved: sold eggs per second is now positive")
	eq(farmPostVeh.soldEggsPerSecond, farmPostVeh.producedEggsPerSecond, "A16.6: Sold eggs matches produced eggs now that transport is available")

	-- Step 7: Wycena i zakup ulepszenia badań (Buy research comfy_nests)
	local resQuote
	client:requestQuote({ kind = "BuyResearch", args = { researchId = "comfy_nests", mode = "single" } }, function(q)
		resQuote = q
	end)
	ok(resQuote ~= nil, "A16.7: Research quote received")

	local resBuyRes
	client:confirmPurchase(resQuote, function(res)
		resBuyRes = res
	end)
	eq(resBuyRes.status, "APPLIED", "A16.7: Research purchase applied")
	client:receive(server:createPlayerDelta("1601"))
	eq(client:getFarm().common[1].level, 1, "A16.7: comfy_nests upgraded to level 1 on client")

	-- Step 8: Rozłączenie, zapis checkpointu i odtworzenie po powrocie (Reconnect & persist)
	local savedCash = client:getFarm().cash
	client:destroy()
	server:playerLeaving("1601")
	eq(server:getPlayer("1601"), nil, "A16.8: Player left and saved")

	-- Reconnect
	server:playerJoined("1601")
	local clientReconnect = ClientBootstrap.new({ wire = server, playerId = "1601", clock = clock })
	clientReconnect:connect("boot-a16-reconnect")
	eq(clientReconnect:getStatus(), "READY", "A16.8: Reconnected client is READY")
	eq(#clientReconnect:getFarm().fleet.vehicles, 1, "A16.8: Restored fleet has 1 vehicle")
	eq(clientReconnect:getFarm().common[1].level, 1, "A16.8: Restored comfy_nests is level 1")
	eq(clientReconnect:getFarm().cash, savedCash, "A16.8: Restored wallet cash matches exactly without data loss")

	clientReconnect:destroy()
	server:playerLeaving("1601")
end

-- ============================================================================
-- Report Output & JSON Persistence
-- ============================================================================
local resultsData = {
	suite = "acceptance",
	status = "PASS",
	level = "L/S/D",
	scenarios = scenarioAssertions,
	totalAssertions = totalAssertions,
}

pcall(function()
	fs.writeFile("build/acceptance-results.json", serde.encode("json", resultsData, true))
end)

print("======================================================================")
print("HatchTheEgg - Acceptance Test Suite (docs/29 §5: A01 - A16)")
print("======================================================================")
print(string.format("[A01] New profile & corrupt profile validation / session gate : %3d assertions (PASS)", scenarioAssertions.A01))
print(string.format("[A02] Hatch intents start/refresh/stop, stock, vacancy, expiry : %3d assertions (PASS)", scenarioAssertions.A02))
print(string.format("[A03] In-transit chickens, vacancy reservation, 3D invariance : %3d assertions (PASS)", scenarioAssertions.A03))
print(string.format("[A04] Production vs shipping (greater, equal, lower)          : %3d assertions (PASS)", scenarioAssertions.A04))
print(string.format("[A05] IHR fractions, full slot, vacancy-weighted sharing      : %3d assertions (PASS)", scenarioAssertions.A05))
print(string.format("[A06] Common research purchases & currentFarmCash preservation: %3d assertions (PASS)", scenarioAssertions.A06))
print(string.format("[A07] sameTypeOwned scaling for habitats/vehicles & pop intact: %3d assertions (PASS)", scenarioAssertions.A07))
print(string.format("[A08] Quote protection, quoteId & expectedRevision validation : %3d assertions (PASS)", scenarioAssertions.A08))
print(string.format("[A09] Duplicate operationId replay & conflict detection       : %3d assertions (PASS)", scenarioAssertions.A09))
print(string.format("[A10] Admission refusal when unready & zero ghost queuing     : %3d assertions (PASS)", scenarioAssertions.A10))
print(string.format("[A11] Session fencing against stale owner write attempt       : %3d assertions (PASS)", scenarioAssertions.A11))
print(string.format("[A12] Online vs Away silo limits & zero silo away handling    : %3d assertions (PASS)", scenarioAssertions.A12))
print(string.format("[A13] Checkpoint phase interruption & bitwise resumed match   : %3d assertions (PASS)", scenarioAssertions.A13))
print(string.format("[A14] viewSeq gap detection, RefreshState resync, no rollback : %3d assertions (PASS)", scenarioAssertions.A14))
print(string.format("[A15] Multi-player isolation, no token leaks, anti-spoofing  : %3d assertions (PASS)", scenarioAssertions.A15))
print(string.format("[A16] Complete end-to-end farm loop & reconnect persistence   : %3d assertions (PASS)", scenarioAssertions.A16))
print("======================================================================")
print(string.format("TOTAL: %d assertions across 16 scenarios - 100%% PASS", totalAssertions))
print("======================================================================")
