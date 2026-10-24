--!nocheck
-- HUD for HatchTheEgg (IMP-14, VIS-04, PROD-01, PROD-02, PROD-03).
-- Candy & Classic Studs styled responsive 2D HUD for PC and Mobile, inspired by
-- the user's reference screenshots (Dom button at top, Koszyk Jajek at bottom center,
-- huge green $ counter at bottom-left, studded quick-upgrade buttons on the left,
-- 6 framed icon buttons dock on the right, and total chicken counter at bottom-right).
--
-- Supported Full Modals (PROD-03):
-- 1. HabitatsModal: All 19 habitats (Coop to Chicken Universe), 4 parcel cards, capacity fill bars, prices.
-- 2. VehiclesModal: Up to 17 fleet slots, 12 vehicles (Trike to Hyperloop), live shipping comparison bar.
-- 3. ResearchModal: Multi-tier modal with tabs for Tiers 1–13 (56 common) + dedicated Epic research tab (Złote Jaja).
-- 4. PetsModal: Equipped slots (3/5), inventory grid, fusion section (chance indicator, guarantee counter, +10 p.p. Pro Permit bonus).
-- 5. ShopModal: 3 tabs: Złote Jaja (GE packs 1..4), Wzmocnienia (Boosts for GE), Przepustki (Pro Permit, Buy MAX).
-- 6. CalendarModal: 28-day calendar grid with claim indicators + Trophies tab across 19 eggs with 5 tier cups.
-- 7. EggUpgradeModal: 19 eggs progression, Farm Value threshold checking and reset confirmation.
--
-- CRITICAL ARCHITECTURAL INVARIANT:
-- HUD and controllers NEVER modify authoritative state, grant resources, or alter economy balances.
-- All numeric formatting (K, M, B, T) is presentation-only and NEVER parsed back into domain numbers.

local HUD = {}
HUD.__index = HUD

-- ============================================================================
-- Presentation-Only Numeric Formatting
-- ============================================================================

local SUFFIXES = table.freeze({
	{ 1e15, "q" },
	{ 1e12, "T" },
	{ 1e9, "B" },
	{ 1e6, "M" },
	{ 1e3, "K" },
})

local function formatCompact(value)
	local n = if type(value) == "number" then value else tonumber(value) or 0
	if n < 0 then
		return "-" .. formatCompact(-n)
	end

	if n < 1000 then
		if n % 1 == 0 then
			return string.format("%d", n)
		else
			local s = string.format("%.2f", n)
			s = string.gsub(s, "%.?0+$", "")
			return s
		end
	end

	for _, tier in ipairs(SUFFIXES) do
		local threshold = tier[1]
		local symbol = tier[2]
		if n >= threshold then
			local scaled = n / threshold
			local formatted
			if scaled >= 100 then
				formatted = string.format("%.1f", scaled)
			else
				formatted = string.format("%.2f", scaled)
			end
			formatted = string.gsub(formatted, "%.?0+$", "")
			return formatted .. symbol
		end
	end

	return tostring(n)
end

function HUD.formatCompact(selfOrValue, maybeValue)
	local val = if type(selfOrValue) == "table" and selfOrValue.formatCompact == HUD.formatCompact then maybeValue else selfOrValue
	return formatCompact(val)
end

function HUD.formatCash(selfOrAmount, maybeAmount)
	local amount = if type(selfOrAmount) == "table" and selfOrAmount.formatCash == HUD.formatCash then maybeAmount else selfOrAmount
	return "$" .. formatCompact(amount)
end

function HUD.formatRate(selfOrAmount, maybeAmountOrUnit, maybeUnit)
	local amount
	local unit = "/s"

	if type(selfOrAmount) == "table" and selfOrAmount.formatRate == HUD.formatRate then
		amount = maybeAmountOrUnit
		if maybeUnit ~= nil then
			unit = maybeUnit
		end
	else
		amount = selfOrAmount
		if maybeAmountOrUnit ~= nil and type(maybeAmountOrUnit) == "string" then
			unit = maybeAmountOrUnit
		end
	end

	return formatCompact(amount) .. unit
end

-- ============================================================================
-- Reference Catalogs & Display Data
-- ============================================================================

local HABITAT_DISPLAY_NAMES = table.freeze({
	[0] = "Kurnik (Coop)",
	[1] = "Chatka (Shack)",
	[2] = "Super Chatka (Super Shack)",
	[3] = "Niski Dom (Short House)",
	[4] = "Standardowy (The Standard)",
	[5] = "Długi Dom (Long House)",
	[6] = "Piętrowy (Double Decker)",
	[7] = "Magazyn (Warehouse)",
	[8] = "Centrum Drobiu (Center)",
	[9] = "Bunkier (Bunker)",
	[10] = "Eggkea (Eggkea)",
	[11] = "Kurnik 1000 (Hab 1000)",
	[12] = "Hangar (Hangar)",
	[13] = "Wieża (Tower)",
	[14] = "Kurnik 10,000 (Hab 10,000)",
	[15] = "Eggtopia (Eggtopia)",
	[16] = "Monolit (Monolith)",
	[17] = "Portal Planetarny (Planet Portal)",
	[18] = "Uniwersum Kurczaków (Chicken Universe)",
})

local HABITAT_CAPACITIES = table.freeze({
	[0] = 250, [1] = 500, [2] = 1000, [3] = 2000, [4] = 5000,
	[5] = 10000, [6] = 20000, [7] = 50000, [8] = 100000, [9] = 200000,
	[10] = 500000, [11] = 1000000, [12] = 2000000, [13] = 5000000, [14] = 10000000,
	[15] = 25000000, [16] = 50000000, [17] = 100000000, [18] = 600000000,
})

local VEHICLE_DISPLAY_NAMES = table.freeze({
	[0] = "Trójkołowiec (Trike)",
	[1] = "Furgonetka (Transit Van)",
	[2] = "Pickup (Pickup)",
	[3] = "Ciężarówka 10ft (10 Foot)",
	[4] = "Ciężarówka 24ft (24 Foot)",
	[5] = "Ciągnik Siodłowy (Semi)",
	[6] = "Podwójny Ciągnik (Double Semi)",
	[7] = "Futurystyczny Ciągnik (Future Semi)",
	[8] = "Mega Ciężarówka (Mega Semi)",
	[9] = "Antygrawitacyjna (Hover Semi)",
	[10] = "Transporter Kwantowy (Quantum)",
	[11] = "Pociąg Hyperloop (Hyperloop Train)",
})

local VEHICLE_CAPACITIES = table.freeze({
	[0] = 5000, [1] = 15000, [2] = 50000, [3] = 100000, [4] = 250000,
	[5] = 500000, [6] = 1000000, [7] = 5000000, [8] = 15000000, [9] = 30000000,
	[10] = 50000000, [11] = 50000000,
})

local TIER_THRESHOLDS = table.freeze({
	0, 30, 80, 160, 280, 400, 520, 650, 800, 980, 1185, 1390, 1655
})

local COMMON_RESEARCH_TIERS = table.freeze({
	comfy_nests = 1, nutritional_sup = 1, better_incubators = 1, excitable_chickens = 1,
	hab_capacity1 = 2, internal_hatchery1 = 2, padded_packaging = 2, hatchery_expansion = 2, bigger_eggs = 2,
	internal_hatchery2 = 3, leafsprings = 3, vehicle_reliablity = 3, rooster_booster = 3, coordinated_clucking = 3,
	hatchery_rebuild1 = 4, usde_prime = 4, hen_house_ac = 4, superfeed = 4, microlux = 4,
	compact_incubators = 5, lightweight_boxes = 5, excoskeletons = 5, internal_hatchery3 = 5, improved_genetics = 5,
	traffic_management = 6, motivational_clucking = 6, driver_training = 6, shell_fortification = 6,
	egg_loading_bots = 7, super_alloy = 7, even_bigger_eggs = 7, internal_hatchery4 = 7,
	quantum_storage = 8, genetic_purification = 8, internal_hatchery5 = 8, time_compress = 8,
	hover_upgrades = 9, graviton_coating = 9, grav_plating = 9, chrystal_shells = 9,
	autonomous_vehicles = 10, neural_linking = 10, telepathic_will = 10, enlightened_chickens = 10,
	dark_containment = 11, atomic_purification = 11, multi_layering = 11, timeline_diversion = 11,
	wormhole_dampening = 12, eggsistor = 12, micro_coupling = 12, neural_net_refine = 12,
	matter_reconfig = 13, timeline_splicing = 13, hyper_portalling = 13, relativity_optimization = 13,
})

local RESEARCH_DISPLAY_NAMES = table.freeze({
	comfy_nests = "Wygodne Gniazda (+Tempo znoszenia)",
	nutritional_sup = "Cukrowe Suplementy (+Wartość jaj)",
	better_incubators = "Słodkie Inkubatory (+Wylęgarnia)",
	excitable_chickens = "Podekscytowane Kury (+Mnożnik biegu)",
	hab_capacity1 = "Rozbudowa Kurników (+Pojemność)",
	internal_hatchery1 = "Wewnętrzny Wylęg I (+Kurczaki/min)",
	padded_packaging = "Miękkie Pudełka (+Wartość jaj)",
	hatchery_expansion = "Pojemniejsza Wylęgarnia (+Zapas jaj)",
	bigger_eggs = "Większe Jaja (+Wartość x2)",
	internal_hatchery2 = "Wewnętrzny Wylęg II (+Kurczaki/min)",
	leafsprings = "Resory Pojazdów (+Pojemność floty)",
	vehicle_reliablity = "Niezawodność Floty (+Slot pojazdu)",
	rooster_booster = "Kogut Motywator (+Tempo wylęgu)",
	coordinated_clucking = "Skoordynowane Gdakanie (+Mnożnik)",
	hatchery_rebuild1 = "Modernizacja Wylęgarni (+Zapas)",
	usde_prime = "Certyfikat USDE (+Wartość x3)",
	hen_house_ac = "Klimatyzacja Kurników (+Znoszenie)",
	superfeed = "Super Pasza (+Wartość jaj)",
	microlux = "Żarówki Microlux (+Pojemność)",
	compact_incubators = "Kompaktowe Inkubatory (+Zapas)",
	lightweight_boxes = "Lekkie Kartony (+Pojemność floty)",
	excoskeletons = "Egzoszkielety (+Slot pojazdu)",
	internal_hatchery3 = "Wewnętrzny Wylęg III (+Kurczaki/min)",
	improved_genetics = "Ulepszona Genetyka (+Wartość i tempo)",
	traffic_management = "Zarządzanie Ruchem (+Slot pojazdu)",
	motivational_clucking = "Motywacyjny Śpiew (+Mnożnik)",
	driver_training = "Trening Kierowców (+Pojemność floty)",
	shell_fortification = "Wzmocnienie Skorupek (+Wartość)",
	egg_loading_bots = "Boty Załadunkowe (+Slot pojazdu)",
	super_alloy = "Super Stopy (+Pojemność floty)",
	even_bigger_eggs = "Gigantyczne Jaja (+Wartość)",
	internal_hatchery4 = "Wewnętrzny Wylęg IV (+Kurczaki/min)",
	quantum_storage = "Kwantowe Magazyny (+Pojemność)",
	genetic_purification = "Oczyszczanie Genetyczne (+Wartość)",
	internal_hatchery5 = "Wewnętrzny Wylęg V (+Kurczaki/min)",
	time_compress = "Kompresja Czasu (+Tempo wylęgu)",
	hover_upgrades = "Poduszkowce (+Pojemność floty)",
	graviton_coating = "Powłoka Grawitonowa (+Wartość)",
	grav_plating = "Płyty Antygrawitacyjne (+Pojemność)",
	chrystal_shells = "Krystaliczne Skorupki (+Wartość)",
	autonomous_vehicles = "Autonomiczna Flota (+Slot pojazdu)",
	neural_linking = "Łącze Neuronowe (+Tempo znoszenia)",
	telepathic_will = "Telepatyczna Wola (+Tempo wylęgu)",
	enlightened_chickens = "Oświecone Kury (+Wartość)",
	dark_containment = "Izolacja Ciemnej Materii (+Pojemność)",
	atomic_purification = "Atomowe Oczyszczenie (+Wartość)",
	multi_layering = "Wielowarstwowość (+Pojemność)",
	timeline_diversion = "Dywergencja Czasowa (+Tempo wylęgu)",
	wormhole_dampening = "Wygłuszanie Tuneli (+Slot pojazdu)",
	eggsistor = "Eggzystory Kwantowe (+Wartość)",
	micro_coupling = "Mikrosprzęgła (+Pojemność floty)",
	neural_net_refine = "Sieci Neuronowe (+Tempo)",
	matter_reconfig = "Rekonfiguracja Materii (+Wartość)",
	timeline_splicing = "Splatanie Osi Czasu (+Wylęg)",
	hyper_portalling = "Hiperportale (+Pojemność)",
	relativity_optimization = "Optymalizacja Relatywistyczna (+Wartość)",
})

local EPIC_RESEARCH_CATALOG = table.freeze({
	{ id = "hold_to_hatch", name = "Przytrzymaj by Wylęgać", maxLevel = 15, basePriceGE = 10, desc = "+Szybkość ciągłego wylęgu" },
	{ id = "epic_hatchery", name = "Epicka Wylęgarnia", maxLevel = 20, basePriceGE = 15, desc = "+Zapas wylęgarni" },
	{ id = "epic_int_hatchery", name = "Epicki Wewnętrzny Wylęg", maxLevel = 20, basePriceGE = 25, desc = "+Wewnętrzny wylęg kurcząt" },
	{ id = "video_doubler_time", name = "Wydłużony Mnożnik", maxLevel = 12, basePriceGE = 50, desc = "+Czas trwania wzmocnień" },
	{ id = "epic_clucking", name = "Epickie Gdakanie", maxLevel = 20, basePriceGE = 20, desc = "+Mnożnik biegających kurcząt" },
	{ id = "epic_multiplier", name = "Epicki Mnożnik", maxLevel = 100, basePriceGE = 30, desc = "+Maksymalny bonus biegających kurcząt" },
	{ id = "cheaper_contractors", name = "Tańsi Wykonawcy", maxLevel = 10, basePriceGE = 100, desc = "-Koszt budowy kurników" },
	{ id = "bust_unions", name = "Związki Zawodowe", maxLevel = 10, basePriceGE = 100, desc = "-Koszt zakupu pojazdów" },
	{ id = "lab_upgrade", name = "Modernizacja Laboratorium", maxLevel = 10, basePriceGE = 250, desc = "-Koszt zwykłych badań" },
	{ id = "silo_capacity", name = "Pojemność Silosów", maxLevel = 60, basePriceGE = 20, desc = "+Czas działania silosów offline" },
	{ id = "silo_quality", name = "Jakość Silosów", maxLevel = 20, basePriceGE = 100, desc = "+Efektywność produkcji offline" },
	{ id = "internal_hatchery_calm", name = "Spokój w Kurnikach", maxLevel = 20, basePriceGE = 50, desc = "+Tempo wylęgu gdy jesteś offline" },
	{ id = "soul_food", name = "Pokarm Dusz", maxLevel = 140, basePriceGE = 10, desc = "+Bonus do zarobków za każde Soul Egg" },
	{ id = "prestige_bonus", name = "Bonus Prestiżu", maxLevel = 20, basePriceGE = 100, desc = "+Liczba Soul Eggs zdobywana przy resecie" },
	{ id = "epic_comfy_nests", name = "Epickie Wygodne Gniazda", maxLevel = 20, basePriceGE = 150, desc = "+Globalne tempo znoszenia jaj" },
	{ id = "transportation_fleet", name = "Epicka Flota", maxLevel = 20, basePriceGE = 200, desc = "+Pojemność całej floty transportowej" },
	{ id = "prophecy_bonus", name = "Bonus Przepowiedni", maxLevel = 5, basePriceGE = 1000, desc = "+Mnożnik dla każdego Jaja Przepowiedni (PE)" },
	{ id = "drone_rewards", name = "Nagrody z Dronów", maxLevel = 20, basePriceGE = 50, desc = "+Szansa na rzadkie nagrody z dronów" },
	{ id = "epic_warm_eggs", name = "Ciepłe Inkubatory", maxLevel = 20, basePriceGE = 200, desc = "-Czas inkubacji petów" },
	{ id = "int_hatch_sharing", name = "Współdzielenie Wylęgu", maxLevel = 10, basePriceGE = 300, desc = "+Przekazywanie wylęgu z pełnych kurników" },
	{ id = "int_hatch_constant", name = "Stały Wewnętrzny Wylęg", maxLevel = 10, basePriceGE = 400, desc = "+Stały wylęg niezależnie od populacji" },
	{ id = "afx_mission_time", name = "Szybkie Misje Kosmiczne", maxLevel = 10, basePriceGE = 500, desc = "-Czas trwania ekspedycji" },
	{ id = "afx_ship_capacity", name = "Pojemność Statków", maxLevel = 10, basePriceGE = 600, desc = "+Miejsca na artefakty w statkach" },
	{ id = "relic_finder", name = "Poszukiwacz Reliktów", maxLevel = 10, basePriceGE = 750, desc = "+Szansa na legendarne artefakty" },
})

local BOOSTS_CATALOG = table.freeze({
	{ id = "jimbos_blue_v2", name = "Pasza Jimbosa (3x)", priceGE = 50, duration = "20 min", effect = "3x Dochód" },
	{ id = "jimbos_purple_v2", name = "Pasza Premium (10x)", priceGE = 150, duration = "15 min", effect = "10x Dochód" },
	{ id = "jimbos_orange", name = "Najlepsza Pasza (50x)", priceGE = 2500, duration = "10 min", effect = "50x Dochód" },
	{ id = "tachyon_prism_blue_v2", name = "Pryzmat Tachionowy", priceGE = 50, duration = "10 min", effect = "10x Wylęg" },
	{ id = "tachyon_prism_blue_big", name = "Wielki Pryzmat", priceGE = 500, duration = "4 godz", effect = "10x Wylęg" },
	{ id = "soul_beacon", name = "Latarnia Dusz", priceGE = 1000, duration = "30 min", effect = "5x Soul Eggs" },
	{ id = "blank_check", name = "Czysty Czek", priceGE = 750, duration = "Natychmiast", effect = "Zastrzyk Gotówki" },
	{ id = "money_printer", name = "Drukarka Pieniędzy", priceGE = 2500, duration = "Natychmiast", effect = "Ogromna Gotówka" },
})

local SHOP_PRODUCTS_CATALOG = table.freeze({
	ge_pack_small = { id = "ge_pack_small", name = "Pakiet Złotych Jaj (1,000 GE)", kind = "developer_product", geAmount = 1000 },
	ge_pack_large = { id = "ge_pack_large", name = "Wielki Pakiet Złotych Jaj (10,000 GE)", kind = "developer_product", geAmount = 10000 },
	piggy_break = { id = "piggy_break", name = "Rozbij Skarbonkę (Break Piggy)", kind = "developer_product", desc = "Odbierz wszystkie Złote Jaja zebrane w Skarbonce!" },
	pro_permit = {
		id = "pro_permit",
		name = "Pro Permit",
		kind = "gamepass",
		desc = "+2 Dodatkowe Sloty na Pety (łącznie 5), rozbudowa silosów do 10, bonus +10 p.p. do szansy fuzji petów*.",
		notice = "*Uwaga: Zgodnie z regulacjami dotyczącymi płatnych losowych mechanik, bonus +10 p.p. do fuzji jest dostępny tylko w uprawnionych regionach.",
	},
	buy_max = {
		id = "buy_max",
		name = "Kupuj MAX (Buy MAX)",
		kind = "gamepass",
		desc = "Kupuj maksymalną możliwą liczbę ulepszeń i badań jednym kliknięciem!",
	},
})

local CALENDAR_REWARDS_CATALOG = table.freeze({
	[1] = { day = 1, type = "GE", label = "192 GE", icon = "💎" },
	[2] = { day = 2, type = "Cash", label = "$5K Gotówka", icon = "💵" },
	[3] = { day = 3, type = "Boost", label = "Pasza Jimbosa", icon = "⚡" },
	[4] = { day = 4, type = "SE", label = "50K Soul Eggs", icon = "🌌" },
	[5] = { day = 5, type = "Epic", label = "Badanie: Wylęg", icon = "🔬" },
	[6] = { day = 6, type = "Cash", label = "$5K Gotówka", icon = "💵" },
	[7] = { day = 7, type = "Boost", label = "Pryzmat Tachion", icon = "⚡" },
	[8] = { day = 8, type = "GE", label = "396 GE", icon = "💎" },
	[9] = { day = 9, type = "Cash", label = "$5K Gotówka", icon = "💵" },
	[10] = { day = 10, type = "Boost", label = "Pasza Jimbosa", icon = "⚡" },
	[11] = { day = 11, type = "SE", label = "50K Soul Eggs", icon = "🌌" },
	[12] = { day = 12, type = "Epic", label = "Badanie: Drony", icon = "🔬" },
	[13] = { day = 13, type = "Cash", label = "$5K Gotówka", icon = "💵" },
	[14] = { day = 14, type = "Boost", label = "Pryzmat Tachion", icon = "⚡" },
	[15] = { day = 15, type = "Cash", label = "$5K Gotówka", icon = "💵" },
	[16] = { day = 16, type = "Boost", label = "Pasza Jimbosa", icon = "⚡" },
	[17] = { day = 17, type = "GE", label = "96 GE", icon = "💎" },
	[18] = { day = 18, type = "SE", label = "50K Soul Eggs", icon = "🌌" },
	[19] = { day = 19, type = "Cash", label = "$5K Gotówka", icon = "💵" },
	[20] = { day = 20, type = "Boost", label = "Pryzmat Tachion", icon = "⚡" },
	[21] = { day = 21, type = "Epic", label = "Badanie: Prestiż", icon = "🔬" },
	[22] = { day = 22, type = "Cash", label = "$5K Gotówka", icon = "💵" },
	[23] = { day = 23, type = "Boost", label = "Pasza Jimbosa", icon = "⚡" },
	[24] = { day = 24, type = "SE", label = "50K Soul Eggs", icon = "🌌" },
	[25] = { day = 25, type = "Cash", label = "$5K Gotówka", icon = "💵" },
	[26] = { day = 26, type = "GE", label = "396 GE", icon = "💎" },
	[27] = { day = 27, type = "Piggy", label = "Skarbonka +10K", icon = "🐷" },
	[28] = { day = 28, type = "PE", label = "1 Jajo Przepowiedni", icon = "✨" },
})

local TROPHY_POPULATION_TIERS = table.freeze({
	{ tier = 1, name = "Brąz", pop = 10000000, icon = "🥉" },
	{ tier = 2, name = "Srebro", pop = 50000000, icon = "🥈" },
	{ tier = 3, name = "Złoto", pop = 250000000, icon = "🥇" },
	{ tier = 4, name = "Platyna", pop = 1000000000, icon = "💠" },
	{ tier = 5, name = "Diament", pop = 10000000000, icon = "💎" },
})

local EGGS_DATA = table.freeze({
	[0] = { index = 0, name = "Edible", eggValueBase = 0.25, advanceFV = 0 },
	[1] = { index = 1, name = "Superfood", eggValueBase = 1.25, advanceFV = 68000000 },
	[2] = { index = 2, name = "Medical", eggValueBase = 6.25, advanceFV = 5300000000 },
	[3] = { index = 3, name = "Rocket Fuel", eggValueBase = 30, advanceFV = 240000000000 },
	[4] = { index = 4, name = "Super Material", eggValueBase = 150, advanceFV = 1.7e14 },
	[5] = { index = 5, name = "Fusion", eggValueBase = 700, advanceFV = 5e16 },
	[6] = { index = 6, name = "Quantum", eggValueBase = 3000, advanceFV = 2.3e19 },
	[7] = { index = 7, name = "CRISPR", eggValueBase = 12500, advanceFV = 9.4e22 },
	[8] = { index = 8, name = "Tachyon", eggValueBase = 50000, advanceFV = 1.7e26 },
	[9] = { index = 9, name = "Graviton", eggValueBase = 175000, advanceFV = 9.8e29 },
	[10] = { index = 10, name = "Dilithium", eggValueBase = 525000, advanceFV = 4.8e33 },
	[11] = { index = 11, name = "Prodigy", eggValueBase = 1500000, advanceFV = 1.6e37 },
	[12] = { index = 12, name = "Terraform", eggValueBase = 10000000, advanceFV = 2e40 },
	[13] = { index = 13, name = "Antimatter", eggValueBase = 1000000000, advanceFV = 1.3e44 },
	[14] = { index = 14, name = "Dark Matter", eggValueBase = 100000000000, advanceFV = 1.2e48 },
	[15] = { index = 15, name = "A.I.", eggValueBase = 1e12, advanceFV = 3.2e52 },
	[16] = { index = 16, name = "Nebula", eggValueBase = 1.5e13, advanceFV = 2e56 },
	[17] = { index = 17, name = "Universe", eggValueBase = 1e14, advanceFV = 4e60 },
	[18] = { index = 18, name = "Enlightenment", eggValueBase = 1e-7, advanceFV = 3.6e65 },
})

local function calculateClientFarmValue(farm)
	if not farm then return 0 end
	local eggIndex = farm.eggIndex or 0
	local egg = EGGS_DATA[eggIndex] or EGGS_DATA[0]
	local eggValueBase = egg.eggValueBase

	local population = 0
	local habCapacity = 0
	if type(farm.habitats) == "table" then
		for _, hab in ipairs(farm.habitats) do
			population += tonumber(hab.population) or 0
			habCapacity += tonumber(hab.capacity) or 0
		end
	end

	local shippingPerMinute = 0
	if farm.fleet and farm.fleet.shippingPerMinute then
		shippingPerMinute = tonumber(farm.fleet.shippingPerMinute) or 0
	end

	local L = 1.0 / 30
	local C = math.floor((shippingPerMinute / 60) / L)
	local P = if population <= C then population else math.floor(C + 0.2 * (population - C))
	local F = math.max(0, habCapacity - population) ^ 0.6
	local K = if eggIndex < 18 then 1200 + 600 * eggIndex else 3600

	return 50 * K * L * eggValueBase * (P + F)
end

-- ============================================================================
-- GUI Instance Helpers (Studio & Lune Mock)
-- ============================================================================

local isRoblox = (typeof(Instance) == "table" and type(Instance.new) == "function")
local Color3 = if isRoblox and typeof(Color3) == "table" then Color3 else {
	fromRGB = function(r, g, b) return { R = r, G = g, B = b } end,
	new = function(r, g, b) return { R = r, G = g, B = b } end,
}
local UDim2 = if isRoblox and typeof(UDim2) == "table" then UDim2 else {
	new = function(sx, ox, sy, oy) return { X = { Scale = sx, Offset = ox }, Y = { Scale = sy, Offset = oy } } end,
}
local UDim = if isRoblox and typeof(UDim) == "table" then UDim else {
	new = function(s, o) return { Scale = s, Offset = o } end,
}
local Enum = if isRoblox and typeof(Enum) == "table" then Enum else {
	Font = { FredokaOne = "FredokaOne" },
	TextXAlignment = { Left = "Left", Right = "Right", Center = "Center" },
	ZIndexBehavior = { Sibling = "Sibling" },
	ApplyStrokeMode = { Border = "Border" },
}

local function createMockEvent()
	local listeners = {}
	local event = {}
	function event:Connect(cb)
		table.insert(listeners, cb)
		return {
			Disconnect = function()
				local idx = table.find(listeners, cb)
				if idx then
					table.remove(listeners, idx)
				end
			end,
		}
	end
	function event:Fire(...)
		for _, cb in ipairs(table.clone(listeners)) do
			cb(...)
		end
	end
	return event
end

local function createMockElement(className, properties)
	local inst = {
		ClassName = className,
		Name = (properties and properties.Name) or className,
		Parent = nil,
		Children = {},
		Text = (properties and properties.Text) or "",
		Visible = if properties and properties.Visible ~= nil then properties.Visible else true,
		Active = if properties and properties.Active ~= nil then properties.Active else true,
		AutoButtonColor = if properties and properties.AutoButtonColor ~= nil then properties.AutoButtonColor else true,
	}

	function inst:FindFirstChild(name)
		for _, child in ipairs(self.Children) do
			if child.Name == name then
				return child
			end
		end
		return nil
	end

	function inst:WaitForChild(name)
		return self:FindFirstChild(name)
	end

	function inst:GetChildren()
		return table.clone(self.Children)
	end

	function inst:GetDescendants()
		local result = {}
		local function collect(node)
			for _, child in ipairs(node.Children or {}) do
				table.insert(result, child)
				collect(child)
			end
		end
		collect(self)
		return result
	end

	function inst:ClearAllChildren()
		for _, child in ipairs(self.Children or {}) do
			child.Parent = nil
		end
		self.Children = {}
	end

	function inst:Destroy()
		self.destroyed = true
		if self.Parent and type(self.Parent.Children) == "table" then
			local idx = table.find(self.Parent.Children, self)
			if idx then
				table.remove(self.Parent.Children, idx)
			end
		end
	end

	if className == "TextButton" or className == "ImageButton" then
		inst.Activated = createMockEvent()
		inst.MouseButton1Down = createMockEvent()
		inst.MouseButton1Up = createMockEvent()
	end

	if properties then
		for k, v in pairs(properties) do
			inst[k] = v
		end
	end

	return inst
end

local function createGuiElement(className, properties, parent)
	local inst
	if isRoblox then
		inst = Instance.new(className)
		if properties then
			for k, v in pairs(properties) do
				pcall(function() inst[k] = v end)
			end
		end
		if parent ~= nil then
			inst.Parent = parent
		end
	else
		inst = createMockElement(className, properties)
		if parent ~= nil then
			inst.Parent = parent
			if type(parent.Children) == "table" then
				table.insert(parent.Children, inst)
			end
		end
	end
	return inst
end

local function addCornerAndStroke(inst, radiusScaleOrOffset, strokeColor, strokeThickness)
	if not isRoblox or typeof(inst) ~= "Instance" then return end
	local corner = Instance.new("UICorner")
	if type(radiusScaleOrOffset) == "number" and radiusScaleOrOffset <= 1 then
		corner.CornerRadius = UDim.new(radiusScaleOrOffset, 0)
	else
		corner.CornerRadius = UDim.new(0, radiusScaleOrOffset or 10)
	end
	corner.Parent = inst

	if strokeThickness and strokeThickness > 0 then
		local stroke = Instance.new("UIStroke")
		stroke.Color = strokeColor or Color3.fromRGB(22, 12, 8)
		stroke.Thickness = strokeThickness
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = inst
	end
end

local function addTextStroke(label, thickness, color)
	if not isRoblox or typeof(label) ~= "Instance" then return end
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Color3.fromRGB(18, 10, 6)
	stroke.Thickness = thickness or 2.5
	stroke.Parent = label
end

-- ============================================================================
-- HUD Constructor & Initialization
-- ============================================================================

function HUD.new(deps)
	assert(type(deps) == "table", "INVALID_DEPS")
	assert(deps.stateStore ~= nil, "STATE_STORE_REQUIRED")
	assert(deps.intentControllers ~= nil, "INTENT_CONTROLLERS_REQUIRED")
	assert(deps.codec ~= nil, "CODEC_REQUIRED")

	local guiRoot = deps.guiRoot
	if guiRoot == nil then
		guiRoot = createGuiElement("ScreenGui", {
			Name = "HatchTheEggHUD",
			ResetOnSpawn = false,
			IgnoreGuiInset = false,
			ZIndexBehavior = isRoblox and Enum.ZIndexBehavior.Sibling or nil,
		})
	end

	local self = setmetatable({
		stateStore = deps.stateStore,
		intentControllers = deps.intentControllers,
		codec = deps.codec,
		guiRoot = guiRoot,

		-- Intent callbacks
		onHomeClicked = deps.onHomeClicked,
		onQuickBuyHabitat = deps.onQuickBuyHabitat,
		onQuickBuyVehicle = deps.onQuickBuyVehicle,
		onQuickBuyResearch = deps.onQuickBuyResearch,
		onUpgradeEggRequested = deps.onUpgradeEggRequested,
		onClaimDailyGift = deps.onClaimDailyGift,
		onClaimTrophy = deps.onClaimTrophy,
		onFusePets = deps.onFusePets,
		onEquipPet = deps.onEquipPet,
		onUnequipPet = deps.onUnequipPet,
		onTogglePetLock = deps.onTogglePetLock,
		onBuyBoost = deps.onBuyBoost,
		onPurchaseProduct = deps.onPurchaseProduct,

		-- Cached view data
		sessionStatus = "CONNECTING",
		hatcheryRatio = 0,
		habitatFillRatios = { 0, 0, 0, 0 },
		habitatPopulations = { "0", "0", "0", "0" },
		habitatCapacities = { "0", "0", "0", "0" },
		totalChickensCount = 0,

		-- Core HUD Components
		sessionBanner = nil,
		sessionStatusLabel = nil,
		homeButton = nil,
		cashLabel = nil,
		producedEggsLabel = nil,
		soldEggsLabel = nil,
		shippingLabel = nil,
		rebirthLabel = nil,
		totalChickensLabel = nil,
		tutorialLabel = nil,
		hatcheryStockLabel = nil,
		hatcheryRefillLabel = nil,
		hatchButton = nil,

		-- Right Dock Menu Buttons
		researchToggleBtn = nil,
		habitatsToggleBtn = nil,
		vehiclesToggleBtn = nil,
		petsToggleBtn = nil,
		shopToggleBtn = nil,
		calendarToggleBtn = nil,

		-- Modals
		habitatsModal = nil,
		habitatCards = {},
		habitatLabels = {},
		habitatUpgBtns = {},

		vehiclesModal = nil,
		shippingComparisonBar = nil,
		shippingComparisonStatusLabel = nil,
		vehicleCards = {},

		shopFrame = nil, -- ResearchModal
		researchTabButtons = {},
		selectedResearchTier = 1,
		researchTierLockBanner = nil,
		shopResearch = {},

		petsModal = nil,
		equippedPetSlots = {},
		petInventoryCards = {},
		fusionChanceLabel = nil,
		fusionGuaranteeLabel = nil,
		fusionProPermitBadge = nil,
		fusePetsButton = nil,

		shopModal = nil,
		shopModalTabButtons = {},
		selectedShopTab = 1,
		shopProductCards = {},

		calendarModal = nil,
		calendarTabButtons = {},
		selectedCalendarTab = 1,
		calendarDayCells = {},
		claimDailyGiftButton = nil,
		trophyCards = {},

		eggUpgradeModal = nil,
		eggUpgradeCurrentLabel = nil,
		eggUpgradeNextLabel = nil,
		eggUpgradeMultLabel = nil,
		eggUpgradeCurrentFvLabel = nil,
		eggUpgradeReqFvLabel = nil,
		eggUpgradeWarningLabel = nil,
		eggUpgradeBtn = nil,

		_unsubs = {},
	}, HUD)

	self:_buildInterface()
	self:_setupSubscriptions()
	self:update()

	return self
end

function HUD:_buildInterface()
	local root = self.guiRoot

	-- 1. Session Status Banner
	self.sessionBanner = createGuiElement("Frame", {
		Name = "SessionBanner",
		Size = isRoblox and UDim2.new(0, 220, 0, 32) or nil,
		Position = isRoblox and UDim2.new(0.5, -110, 0, 68) or nil,
		BackgroundColor3 = isRoblox and Color3.fromRGB(45, 25, 15) or nil,
		BackgroundTransparency = 0.2,
	}, root)
	addCornerAndStroke(self.sessionBanner, 8, isRoblox and Color3.fromRGB(255, 215, 65) or nil, 2)

	self.sessionStatusLabel = createGuiElement("TextLabel", {
		Name = "StatusLabel",
		Size = isRoblox and UDim2.new(1, 0, 1, 0) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(255, 245, 120) or nil,
		Text = "CONNECTING",
	}, self.sessionBanner)
	addTextStroke(self.sessionStatusLabel, 2)

	-- 2. Top-Center "Dom" Button & Rate Status Cluster
	local topBar = createGuiElement("Frame", {
		Name = "TopBar",
		Size = isRoblox and UDim2.new(0, 480, 0, 96) or nil,
		Position = isRoblox and UDim2.new(0.5, -240, 0, 6) or nil,
		BackgroundTransparency = 1,
	}, root)

	self.homeButton = createGuiElement("TextButton", {
		Name = "DomButton",
		Size = isRoblox and UDim2.new(0, 165, 0, 44) or nil,
		Position = isRoblox and UDim2.new(0.5, -82, 0, 0) or nil,
		BackgroundColor3 = isRoblox and Color3.fromRGB(78, 195, 255) or nil,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(255, 255, 255) or nil,
		Text = "Dom",
	}, topBar)
	addCornerAndStroke(self.homeButton, 8, isRoblox and Color3.fromRGB(18, 42, 68) or nil, 3)
	addTextStroke(self.homeButton, 2.6)

	if self.homeButton.Activated ~= nil then
		self.homeButton.Activated:Connect(function()
			if type(self.onHomeClicked) == "function" then
				self.onHomeClicked()
			elseif isRoblox then
				pcall(function()
					local Players = game:GetService("Players")
					local lp = Players.LocalPlayer
					if lp and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
						lp.Character.HumanoidRootPart.CFrame = CFrame.new(0, 4, 24)
					end
				end)
			end
		end)
	end

	self.producedEggsLabel = createGuiElement("TextLabel", {
		Name = "ProducedEggsLabel",
		Size = isRoblox and UDim2.new(0.33, -4, 0, 26) or nil,
		Position = isRoblox and UDim2.new(0, 0, 0, 48) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(255, 165, 245) or nil,
		Text = "0/s",
	}, topBar)
	addTextStroke(self.producedEggsLabel, 2.2)

	self.soldEggsLabel = createGuiElement("TextLabel", {
		Name = "SoldEggsLabel",
		Size = isRoblox and UDim2.new(0.34, -4, 0, 26) or nil,
		Position = isRoblox and UDim2.new(0.33, 0, 0, 48) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(255, 235, 75) or nil,
		Text = "0/s",
	}, topBar)
	addTextStroke(self.soldEggsLabel, 2.2)

	self.shippingLabel = createGuiElement("TextLabel", {
		Name = "ShippingLabel",
		Size = isRoblox and UDim2.new(0.33, -4, 0, 26) or nil,
		Position = isRoblox and UDim2.new(0.67, 0, 0, 48) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(115, 255, 135) or nil,
		Text = "0/min",
	}, topBar)
	addTextStroke(self.shippingLabel, 2.2)

	self.tutorialLabel = createGuiElement("TextLabel", {
		Name = "TutorialBannerLabel",
		Size = isRoblox and UDim2.new(1, 0, 0, 22) or nil,
		Position = isRoblox and UDim2.new(0, 0, 0, 74) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(255, 250, 210) or nil,
		Text = "🎯 Cel: Kliknij koszyk 'Jajka' na dole lub stań na czerwonym przycisku!",
	}, topBar)
	addTextStroke(self.tutorialLabel, 2.0)

	-- 3. Bottom-Left Cash & Rebirth Display
	local bottomLeft = createGuiElement("Frame", {
		Name = "BottomLeftCluster",
		Size = isRoblox and UDim2.new(0, 310, 0, 95) or nil,
		Position = isRoblox and UDim2.new(0, 16, 1, -108) or nil,
		BackgroundTransparency = 1,
	}, root)

	self.rebirthLabel = createGuiElement("TextLabel", {
		Name = "RebirthLabel",
		Size = isRoblox and UDim2.new(1, 0, 0, 26) or nil,
		Position = isRoblox and UDim2.new(0, 0, 0, 0) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextXAlignment = isRoblox and Enum.TextXAlignment.Left or nil,
		TextColor3 = isRoblox and Color3.fromRGB(255, 165, 125) or nil,
		Text = "Odrodzenie 0 • 🍫 Cukierkowa Farma",
	}, bottomLeft)
	addTextStroke(self.rebirthLabel, 2.4)

	self.cashLabel = createGuiElement("TextLabel", {
		Name = "CashLabel",
		Size = isRoblox and UDim2.new(1, 0, 0, 58) or nil,
		Position = isRoblox and UDim2.new(0, 0, 0, 28) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextXAlignment = isRoblox and Enum.TextXAlignment.Left or nil,
		TextColor3 = isRoblox and Color3.fromRGB(115, 255, 45) or nil,
		Text = "$0",
	}, bottomLeft)
	addTextStroke(self.cashLabel, 3.4)

	-- 4. Left-Side Green Studded Quick-Action Buttons
	local leftQuickCluster = createGuiElement("Frame", {
		Name = "LeftQuickButtons",
		Size = isRoblox and UDim2.new(0, 155, 0, 175) or nil,
		Position = isRoblox and UDim2.new(0, 16, 0.5, -60) or nil,
		BackgroundTransparency = 1,
	}, root)

	local quickButtonsSpec = {
		{
			name = "QuickResearchBtn",
			text = "🔬 +Badanie",
			yPos = 0,
			bg = isRoblox and Color3.fromRGB(102, 232, 48) or nil,
			action = function()
				if type(self.onQuickBuyResearch) == "function" then
					self.onQuickBuyResearch("comfy_nests")
				else
					self:buyResearch("comfy_nests")
				end
			end,
		},
		{
			name = "QuickHabitatBtn",
			text = "🏠 +Kurnik",
			yPos = 58,
			bg = isRoblox and Color3.fromRGB(102, 232, 48) or nil,
			action = function()
				if type(self.onQuickBuyHabitat) == "function" then
					self.onQuickBuyHabitat()
				else
					self:toggleHabitatsModal()
				end
			end,
		},
		{
			name = "QuickVehicleBtn",
			text = "🚚 +Pojazd",
			yPos = 116,
			bg = isRoblox and Color3.fromRGB(102, 232, 48) or nil,
			action = function()
				if type(self.onQuickBuyVehicle) == "function" then
					self.onQuickBuyVehicle()
				else
					self:toggleVehiclesModal()
				end
			end,
		},
	}

	for _, qSpec in ipairs(quickButtonsSpec) do
		local qBtn = createGuiElement("TextButton", {
			Name = qSpec.name,
			Size = isRoblox and UDim2.new(1, 0, 0, 48) or nil,
			Position = isRoblox and UDim2.new(0, 0, 0, qSpec.yPos) or nil,
			BackgroundColor3 = qSpec.bg,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = true,
			TextColor3 = isRoblox and Color3.fromRGB(255, 255, 255) or nil,
			Text = qSpec.text,
		}, leftQuickCluster)
		addCornerAndStroke(qBtn, 8, isRoblox and Color3.fromRGB(22, 48, 12) or nil, 3)
		addTextStroke(qBtn, 2.5)
		if qBtn.Activated then
			qBtn.Activated:Connect(qSpec.action)
		end
	end

	-- 5. Bottom-Center Egg Basket
	local hatcheryFrame = createGuiElement("Frame", {
		Name = "HatcheryFrame",
		Size = isRoblox and UDim2.new(0, 210, 0, 118) or nil,
		Position = isRoblox and UDim2.new(0.5, -105, 1, -128) or nil,
		BackgroundColor3 = isRoblox and Color3.fromRGB(235, 152, 48) or nil,
	}, root)
	addCornerAndStroke(hatcheryFrame, 18, isRoblox and Color3.fromRGB(58, 30, 12) or nil, 3.5)

	self.hatchButton = createGuiElement("TextButton", {
		Name = "HatchButton",
		Size = isRoblox and UDim2.new(1, -12, 0, 56) or nil,
		Position = isRoblox and UDim2.new(0, 6, 0, 6) or nil,
		BackgroundColor3 = isRoblox and Color3.fromRGB(255, 232, 135) or nil,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(255, 255, 255) or nil,
		Text = "🥚 Jajka (WYLĘG)",
	}, hatcheryFrame)
	addCornerAndStroke(self.hatchButton, 14, isRoblox and Color3.fromRGB(72, 38, 14) or nil, 2.8)
	addTextStroke(self.hatchButton, 2.8)

	if self.hatchButton.Activated ~= nil then
		self.hatchButton.Activated:Connect(function()
			self:pressHatch()
		end)
	end
	if self.hatchButton.MouseButton1Down ~= nil then
		self.hatchButton.MouseButton1Down:Connect(function()
			self:startHoldHatch()
		end)
	end
	if self.hatchButton.MouseButton1Up ~= nil then
		self.hatchButton.MouseButton1Up:Connect(function()
			self:stopHoldHatch()
		end)
	end

	self.hatcheryStockLabel = createGuiElement("TextLabel", {
		Name = "StockLabel",
		Size = isRoblox and UDim2.new(0.62, 0, 0, 36) or nil,
		Position = isRoblox and UDim2.new(0.04, 0, 0, 68) or nil,
		BackgroundColor3 = isRoblox and Color3.fromRGB(255, 245, 225) or nil,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(255, 255, 255) or nil,
		Text = "0 / 0",
	}, hatcheryFrame)
	addCornerAndStroke(self.hatcheryStockLabel, 10, isRoblox and Color3.fromRGB(72, 38, 14) or nil, 2.2)
	addTextStroke(self.hatcheryStockLabel, 2.2)

	self.hatcheryRefillLabel = createGuiElement("TextLabel", {
		Name = "RefillLabel",
		Size = isRoblox and UDim2.new(0.30, 0, 0, 36) or nil,
		Position = isRoblox and UDim2.new(0.68, 0, 0, 68) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(135, 255, 115) or nil,
		Text = "+0/s",
	}, hatcheryFrame)
	addTextStroke(self.hatcheryRefillLabel, 2.2)

	-- 6. Right-Side Framed Icon Buttons Dock (6 Buttons in PROD-03)
	local rightDock = createGuiElement("Frame", {
		Name = "RightDock",
		Size = isRoblox and UDim2.new(0, 80, 0, 440) or nil,
		Position = isRoblox and UDim2.new(1, -92, 0.5, -220) or nil,
		BackgroundTransparency = 1,
	}, root)

	local dockButtonsSpec = {
		{ name = "ResearchMenuButton", text = "🔬\nBadania", bg = Color3.fromRGB(32, 68, 140), action = function() self:toggleResearchModal() end },
		{ name = "HabitatsMenuButton", text = "🏠\nKurniki", bg = Color3.fromRGB(160, 80, 40), action = function() self:toggleHabitatsModal() end },
		{ name = "VehiclesMenuButton", text = "🚚\nFlota", bg = Color3.fromRGB(45, 175, 75), action = function() self:toggleVehiclesModal() end },
		{ name = "PetsMenuButton", text = "🐾\nPety", bg = Color3.fromRGB(150, 60, 190), action = function() self:togglePetsModal() end },
		{ name = "ShopMenuButton", text = "💎\nSklep", bg = Color3.fromRGB(225, 155, 30), action = function() self:toggleShopModal() end },
		{ name = "CalendarMenuButton", text = "📅\nNagrody", bg = Color3.fromRGB(225, 75, 95), action = function() self:toggleCalendarModal() end },
	}

	for i, dSpec in ipairs(dockButtonsSpec) do
		local btn = createGuiElement("TextButton", {
			Name = dSpec.name,
			Size = isRoblox and UDim2.new(0, 72, 0, 64) or nil,
			Position = isRoblox and UDim2.new(0, 4, 0, (i - 1) * 72) or nil,
			BackgroundColor3 = isRoblox and dSpec.bg or nil,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = true,
			TextColor3 = isRoblox and Color3.fromRGB(255, 255, 255) or nil,
			Text = dSpec.text,
		}, rightDock)
		addCornerAndStroke(btn, 10, isRoblox and Color3.fromRGB(18, 12, 10) or nil, 3.0)
		addTextStroke(btn, 2.0)
		if btn.Activated then
			btn.Activated:Connect(dSpec.action)
		end

		if dSpec.name == "ResearchMenuButton" then self.researchToggleBtn = btn
		elseif dSpec.name == "HabitatsMenuButton" then self.habitatsToggleBtn = btn
		elseif dSpec.name == "VehiclesMenuButton" then self.vehiclesToggleBtn = btn
		elseif dSpec.name == "PetsMenuButton" then self.petsToggleBtn = btn
		elseif dSpec.name == "ShopMenuButton" then self.shopToggleBtn = btn
		elseif dSpec.name == "CalendarMenuButton" then self.calendarToggleBtn = btn
		end
	end

	self.totalChickensLabel = createGuiElement("TextLabel", {
		Name = "TotalChickensLabel",
		Size = isRoblox and UDim2.new(0, 320, 0, 32) or nil,
		Position = isRoblox and UDim2.new(1, -336, 1, -42) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextXAlignment = isRoblox and Enum.TextXAlignment.Right or nil,
		TextColor3 = isRoblox and Color3.fromRGB(255, 225, 65) or nil,
		Text = "Całkowita liczba kurczaków: 0",
	}, root)
	addTextStroke(self.totalChickensLabel, 2.6)

	-- 7. Habitats Modal Drawer (Coops 1..4, supporting all 19 habitats)
	self:_buildHabitatsModal(root)

	-- 8. Vehicles Modal Drawer (Fleet slots 1..17 + live comparison bar)
	self:_buildVehiclesModal(root)

	-- 9. Research Modal Drawer (Multi-tier T1..T13 common + Epic research tab)
	self:_buildResearchModal(root)

	-- 10. Pets Modal Drawer (Equipped slots 3/5, inventory, fusion)
	self:_buildPetsModal(root)

	-- 11. Shop Modal Drawer (GE packs, Boosts, GamePasses)
	self:_buildShopModal(root)

	-- 12. Calendar & Trophies Modal Drawer (28-day calendar + 19 eggs cups)
	self:_buildCalendarModal(root)

	-- 13. Egg Upgrade Modal (PROD-02)
	self:_buildEggUpgradeModal(root)
end

function HUD:_buildCloseButton(parent, onClose)
	local closeBtn = createGuiElement("TextButton", {
		Name = "CloseBtn",
		Size = isRoblox and UDim2.new(0, 32, 0, 32) or nil,
		Position = isRoblox and UDim2.new(1, -40, 0, 8) or nil,
		BackgroundColor3 = isRoblox and Color3.fromRGB(235, 65, 65) or nil,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(255, 255, 255) or nil,
		Text = "✕",
	}, parent)
	addCornerAndStroke(closeBtn, 6, isRoblox and Color3.fromRGB(85, 20, 20) or nil, 2)
	if closeBtn.Activated and type(onClose) == "function" then
		closeBtn.Activated:Connect(onClose)
	end
	return closeBtn
end

function HUD:_buildHabitatsModal(root)
	local habitatsFrame = createGuiElement("Frame", {
		Name = "HabitatsFrame",
		Visible = false,
		Size = isRoblox and UDim2.new(0, 460, 0, 380) or nil,
		Position = isRoblox and UDim2.new(0.5, -230, 0.5, -190) or nil,
		BackgroundColor3 = isRoblox and Color3.fromRGB(78, 42, 24) or nil,
	}, root)
	addCornerAndStroke(habitatsFrame, 14, isRoblox and Color3.fromRGB(255, 205, 95) or nil, 3.2)
	self.habitatsModal = habitatsFrame

	createGuiElement("TextLabel", {
		Name = "ModalHeader",
		Size = isRoblox and UDim2.new(1, -50, 0, 36) or nil,
		Position = isRoblox and UDim2.new(0, 12, 0, 8) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(255, 235, 115) or nil,
		Text = "🏠 TWOJE KURNIKI (PARCELE 1-4)",
	}, habitatsFrame)

	self:_buildCloseButton(habitatsFrame, function()
		self.habitatsModal.Visible = false
	end)

	for slotId = 1, 4 do
		local card = createGuiElement("Frame", {
			Name = "HabitatCard_" .. tostring(slotId),
			Size = isRoblox and UDim2.new(1, -24, 0, 72) or nil,
			Position = isRoblox and UDim2.new(0, 12, 0, 48 + (slotId - 1) * 80) or nil,
			BackgroundColor3 = isRoblox and Color3.fromRGB(112, 64, 36) or nil,
		}, habitatsFrame)
		addCornerAndStroke(card, 8, isRoblox and Color3.fromRGB(42, 22, 12) or nil, 2)

		local titleLabel = createGuiElement("TextLabel", {
			Name = "TitleLabel",
			Size = isRoblox and UDim2.new(0.68, 0, 0, 24) or nil,
			Position = isRoblox and UDim2.new(0.03, 0, 0, 6) or nil,
			BackgroundTransparency = 1,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = true,
			TextXAlignment = isRoblox and Enum.TextXAlignment.Left or nil,
			TextColor3 = isRoblox and Color3.fromRGB(255, 245, 160) or nil,
			Text = "Parcela #" .. tostring(slotId) .. ": Kurnik (Coop)",
		}, card)
		addTextStroke(titleLabel, 1.8)

		local popLabel = createGuiElement("TextLabel", {
			Name = "PopulationLabel",
			Size = isRoblox and UDim2.new(0.68, 0, 0, 20) or nil,
			Position = isRoblox and UDim2.new(0.03, 0, 0, 30) or nil,
			BackgroundTransparency = 1,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = true,
			TextXAlignment = isRoblox and Enum.TextXAlignment.Left or nil,
			TextColor3 = isRoblox and Color3.fromRGB(255, 255, 255) or nil,
			Text = "0 / 250",
		}, card)
		addTextStroke(popLabel, 1.8)

		local nextLabel = createGuiElement("TextLabel", {
			Name = "NextUpgradeLabel",
			Size = isRoblox and UDim2.new(0.68, 0, 0, 18) or nil,
			Position = isRoblox and UDim2.new(0.03, 0, 0, 50) or nil,
			BackgroundTransparency = 1,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = true,
			TextXAlignment = isRoblox and Enum.TextXAlignment.Left or nil,
			TextColor3 = isRoblox and Color3.fromRGB(160, 240, 140) or nil,
			Text = "Następny: Chatka (Shack)",
		}, card)
		addTextStroke(nextLabel, 1.5)

		local upgBtn = createGuiElement("TextButton", {
			Name = "UpgradeHabitatBtn",
			Size = isRoblox and UDim2.new(0.26, 0, 0.72, 0) or nil,
			Position = isRoblox and UDim2.new(0.71, 0, 0.14, 0) or nil,
			BackgroundColor3 = isRoblox and Color3.fromRGB(95, 235, 45) or nil,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = true,
			TextColor3 = isRoblox and Color3.fromRGB(255, 255, 255) or nil,
			Text = "ULEPSZ",
		}, card)
		addCornerAndStroke(upgBtn, 6, isRoblox and Color3.fromRGB(22, 48, 12) or nil, 2)
		if upgBtn.Activated then
			upgBtn.Activated:Connect(function()
				if type(self.onQuickBuyHabitat) == "function" then
					self.onQuickBuyHabitat(slotId)
				end
			end)
		end

		self.habitatCards[slotId] = card
		self.habitatLabels[slotId] = popLabel
		self.habitatUpgBtns[slotId] = upgBtn
	end
end

function HUD:_buildVehiclesModal(root)
	local vFrame = createGuiElement("Frame", {
		Name = "VehiclesFrame",
		Visible = false,
		Size = isRoblox and UDim2.new(0, 500, 0, 460) or nil,
		Position = isRoblox and UDim2.new(0.5, -250, 0.5, -230) or nil,
		BackgroundColor3 = isRoblox and Color3.fromRGB(48, 62, 38) or nil,
	}, root)
	addCornerAndStroke(vFrame, 14, isRoblox and Color3.fromRGB(115, 245, 125) or nil, 3.2)
	self.vehiclesModal = vFrame

	createGuiElement("TextLabel", {
		Name = "VehiclesHeader",
		Size = isRoblox and UDim2.new(1, -50, 0, 36) or nil,
		Position = isRoblox and UDim2.new(0, 14, 0, 8) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(180, 255, 150) or nil,
		Text = "🚚 FLOTA TRANSPORTOWA (DO 17 POJAZDÓW)",
	}, vFrame)

	self:_buildCloseButton(vFrame, function()
		self.vehiclesModal.Visible = false
	end)

	-- Comparison gauge
	local gaugeFrame = createGuiElement("Frame", {
		Name = "ComparisonGaugeFrame",
		Size = isRoblox and UDim2.new(1, -28, 0, 58) or nil,
		Position = isRoblox and UDim2.new(0, 14, 0, 46) or nil,
		BackgroundColor3 = isRoblox and Color3.fromRGB(32, 44, 26) or nil,
	}, vFrame)
	addCornerAndStroke(gaugeFrame, 8, isRoblox and Color3.fromRGB(20, 28, 16) or nil, 2)
	self.shippingComparisonBar = gaugeFrame

	self.shippingComparisonStatusLabel = createGuiElement("TextLabel", {
		Name = "ComparisonStatusLabel",
		Size = isRoblox and UDim2.new(1, -12, 0, 24) or nil,
		Position = isRoblox and UDim2.new(0, 6, 0, 4) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(255, 255, 255) or nil,
		Text = "Spedycja: 0/min vs Produkcja: 0/min",
	}, gaugeFrame)
	addTextStroke(self.shippingComparisonStatusLabel, 1.8)

	local statusBadge = createGuiElement("TextLabel", {
		Name = "StatusBadge",
		Size = isRoblox and UDim2.new(1, -12, 0, 22) or nil,
		Position = isRoblox and UDim2.new(0, 6, 0, 30) or nil,
		BackgroundColor3 = isRoblox and Color3.fromRGB(50, 180, 70) or nil,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(255, 255, 255) or nil,
		Text = "Spedycja wystarczająca",
	}, gaugeFrame)
	addCornerAndStroke(statusBadge, 4, isRoblox and Color3.fromRGB(15, 60, 25) or nil, 1.5)

	-- Fleet Slots Container (displays slots 1..17)
	local slotsScroll = createGuiElement("Frame", {
		Name = "FleetSlotsContainer",
		Size = isRoblox and UDim2.new(1, -28, 0, 340) or nil,
		Position = isRoblox and UDim2.new(0, 14, 0, 110) or nil,
		BackgroundTransparency = 1,
	}, vFrame)

	for slotId = 1, 17 do
		local card = createGuiElement("Frame", {
			Name = "VehicleSlotCard_" .. tostring(slotId),
			Visible = (slotId <= 4), -- default first 4 visible, updated dynamically
			Size = isRoblox and UDim2.new(1, 0, 0, 48) or nil,
			Position = isRoblox and UDim2.new(0, 0, 0, (slotId - 1) * 52) or nil,
			BackgroundColor3 = isRoblox and Color3.fromRGB(65, 85, 52) or nil,
		}, slotsScroll)
		addCornerAndStroke(card, 6, isRoblox and Color3.fromRGB(28, 38, 22) or nil, 1.8)

		local titleLabel = createGuiElement("TextLabel", {
			Name = "Title",
			Size = isRoblox and UDim2.new(0.48, 0, 0.5, 0) or nil,
			Position = isRoblox and UDim2.new(0.02, 0, 0.05, 0) or nil,
			BackgroundTransparency = 1,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = true,
			TextXAlignment = isRoblox and Enum.TextXAlignment.Left or nil,
			TextColor3 = isRoblox and Color3.fromRGB(255, 255, 255) or nil,
			Text = "Pojazd #" .. tostring(slotId) .. ": Trójkołowiec",
		}, card)
		addTextStroke(titleLabel, 1.6)

		local capLabel = createGuiElement("TextLabel", {
			Name = "Capacity",
			Size = isRoblox and UDim2.new(0.48, 0, 0.45, 0) or nil,
			Position = isRoblox and UDim2.new(0.02, 0, 0.5, 0) or nil,
			BackgroundTransparency = 1,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = true,
			TextXAlignment = isRoblox and Enum.TextXAlignment.Left or nil,
			TextColor3 = isRoblox and Color3.fromRGB(165, 255, 140) or nil,
			Text = "Wydajność: 5K jaj/min",
		}, card)
		addTextStroke(capLabel, 1.5)

		local priceLabel = createGuiElement("TextLabel", {
			Name = "Price",
			Size = isRoblox and UDim2.new(0.24, 0, 0.9, 0) or nil,
			Position = isRoblox and UDim2.new(0.51, 0, 0.05, 0) or nil,
			BackgroundTransparency = 1,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = true,
			TextColor3 = isRoblox and Color3.fromRGB(255, 235, 95) or nil,
			Text = "$544.5",
		}, card)
		addTextStroke(priceLabel, 1.6)

		local upgBtn = createGuiElement("TextButton", {
			Name = "BuyVehicleButton",
			Size = isRoblox and UDim2.new(0.22, 0, 0.76, 0) or nil,
			Position = isRoblox and UDim2.new(0.76, 0, 0.12, 0) or nil,
			BackgroundColor3 = isRoblox and Color3.fromRGB(95, 235, 45) or nil,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = true,
			TextColor3 = isRoblox and Color3.fromRGB(255, 255, 255) or nil,
			Text = "ULEPSZ",
		}, card)
		addCornerAndStroke(upgBtn, 6, isRoblox and Color3.fromRGB(22, 48, 12) or nil, 1.8)
		if upgBtn.Activated then
			upgBtn.Activated:Connect(function()
				if type(self.onQuickBuyVehicle) == "function" then
					self.onQuickBuyVehicle(slotId)
				end
			end)
		end

		self.vehicleCards[slotId] = {
			card = card,
			titleLabel = titleLabel,
			capLabel = capLabel,
			priceLabel = priceLabel,
			upgBtn = upgBtn,
		}
	end
end

function HUD:_buildResearchModal(root)
	local shopFrame = createGuiElement("Frame", {
		Name = "ShopFrame",
		Visible = false,
		Size = isRoblox and UDim2.new(0, 520, 0, 480) or nil,
		Position = isRoblox and UDim2.new(0.5, -260, 0.5, -240) or nil,
		BackgroundColor3 = isRoblox and Color3.fromRGB(64, 34, 20) or nil,
	}, root)
	addCornerAndStroke(shopFrame, 14, isRoblox and Color3.fromRGB(115, 225, 255) or nil, 3.2)
	self.shopFrame = shopFrame

	createGuiElement("TextLabel", {
		Name = "ShopTitle",
		Size = isRoblox and UDim2.new(1, -50, 0, 36) or nil,
		Position = isRoblox and UDim2.new(0, 14, 0, 8) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(135, 235, 255) or nil,
		Text = "🔬 BADANIA I ULEPSZENIA TECHNOLOGICZNE",
	}, shopFrame)

	self:_buildCloseButton(shopFrame, function()
		self.shopFrame.Visible = false
	end)

	-- Tier Selector Bar: T1..T13 + EPICKIE
	local tabsRow = createGuiElement("Frame", {
		Name = "TierTabsRow",
		Size = isRoblox and UDim2.new(1, -24, 0, 32) or nil,
		Position = isRoblox and UDim2.new(0, 12, 0, 46) or nil,
		BackgroundTransparency = 1,
	}, shopFrame)

	local tabNames = { "T1", "T2", "T3", "T4", "T5", "T6", "T7", "T8", "T9", "T10", "T11", "T12", "T13", "EPICKIE" }
	for idx, tabName in ipairs(tabNames) do
		local tabBtn = createGuiElement("TextButton", {
			Name = "TierTab_" .. tabName,
			Size = isRoblox and UDim2.new(1 / #tabNames, -2, 1, 0) or nil,
			Position = isRoblox and UDim2.new((idx - 1) * (1 / #tabNames), 1, 0, 0) or nil,
			BackgroundColor3 = isRoblox and (if idx == 1 then Color3.fromRGB(115, 225, 255) else Color3.fromRGB(42, 22, 14)) or nil,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = true,
			TextColor3 = isRoblox and (if idx == 1 then Color3.fromRGB(18, 12, 10) else Color3.fromRGB(240, 240, 240)) or nil,
			Text = tabName,
		}, tabsRow)
		addCornerAndStroke(tabBtn, 4, isRoblox and Color3.fromRGB(20, 12, 8) or nil, 1.2)
		if tabBtn.Activated then
			tabBtn.Activated:Connect(function()
				self:selectResearchTier(idx)
			end)
		end
		self.researchTabButtons[idx] = tabBtn
	end

	-- Lock Banner
	self.researchTierLockBanner = createGuiElement("TextLabel", {
		Name = "TierLockBanner",
		Visible = false,
		Size = isRoblox and UDim2.new(1, -24, 0, 24) or nil,
		Position = isRoblox and UDim2.new(0, 12, 0, 82) or nil,
		BackgroundColor3 = isRoblox and Color3.fromRGB(140, 40, 40) or nil,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(255, 255, 255) or nil,
		Text = "🔒 Tier zablokowany! Wymaga więcej zakupionych badań",
	}, shopFrame)
	addCornerAndStroke(self.researchTierLockBanner, 4, isRoblox and Color3.fromRGB(60, 15, 15) or nil, 1.5)

	-- Research List container
	local listContainer = createGuiElement("Frame", {
		Name = "ResearchListContainer",
		Size = isRoblox and UDim2.new(1, -24, 0, 360) or nil,
		Position = isRoblox and UDim2.new(0, 12, 0, 110) or nil,
		BackgroundTransparency = 1,
	}, shopFrame)
	self.shopListContainer = listContainer
end

function HUD:_buildPetsModal(root)
	local pFrame = createGuiElement("Frame", {
		Name = "PetsFrame",
		Visible = false,
		Size = isRoblox and UDim2.new(0, 520, 0, 490) or nil,
		Position = isRoblox and UDim2.new(0.5, -260, 0.5, -245) or nil,
		BackgroundColor3 = isRoblox and Color3.fromRGB(65, 30, 60) or nil,
	}, root)
	addCornerAndStroke(pFrame, 14, isRoblox and Color3.fromRGB(245, 145, 255) or nil, 3.2)
	self.petsModal = pFrame

	createGuiElement("TextLabel", {
		Name = "PetsHeader",
		Size = isRoblox and UDim2.new(1, -50, 0, 36) or nil,
		Position = isRoblox and UDim2.new(0, 14, 0, 8) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(255, 195, 255) or nil,
		Text = "🐾 MOJE PETY I EWOLUCJA FUZYJNA",
	}, pFrame)

	self:_buildCloseButton(pFrame, function()
		self.petsModal.Visible = false
	end)

	-- Equipped slots (3 base, 5 with Pro Permit)
	local eqFrame = createGuiElement("Frame", {
		Name = "EquippedSlotsFrame",
		Size = isRoblox and UDim2.new(1, -28, 0, 62) or nil,
		Position = isRoblox and UDim2.new(0, 14, 0, 48) or nil,
		BackgroundColor3 = isRoblox and Color3.fromRGB(45, 20, 42) or nil,
	}, pFrame)
	addCornerAndStroke(eqFrame, 8, isRoblox and Color3.fromRGB(25, 10, 24) or nil, 2)

	for slotId = 1, 5 do
		local slotBtn = createGuiElement("TextButton", {
			Name = "EquippedSlot_" .. tostring(slotId),
			Size = isRoblox and UDim2.new(0.18, 0, 0.82, 0) or nil,
			Position = isRoblox and UDim2.new(0.015 + (slotId - 1) * 0.198, 0, 0.09, 0) or nil,
			BackgroundColor3 = isRoblox and (if slotId <= 3 then Color3.fromRGB(90, 42, 85) else Color3.fromRGB(60, 30, 58)) or nil,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = true,
			TextColor3 = isRoblox and Color3.fromRGB(255, 255, 255) or nil,
			Text = if slotId <= 3 then "+ Slot #" .. tostring(slotId) else "🔒 Pro Permit",
		}, eqFrame)
		addCornerAndStroke(slotBtn, 6, isRoblox and Color3.fromRGB(30, 12, 28) or nil, 1.5)
		if slotBtn.Activated then
			slotBtn.Activated:Connect(function()
				if type(self.onUnequipPet) == "function" then
					self.onUnequipPet(slotId)
				end
			end)
		end
		self.equippedPetSlots[slotId] = slotBtn
	end

	-- Inventory Section
	local invFrame = createGuiElement("Frame", {
		Name = "InventoryFrame",
		Size = isRoblox and UDim2.new(1, -28, 0, 230) or nil,
		Position = isRoblox and UDim2.new(0, 14, 0, 118) or nil,
		BackgroundColor3 = isRoblox and Color3.fromRGB(48, 22, 45) or nil,
	}, pFrame)
	addCornerAndStroke(invFrame, 8, isRoblox and Color3.fromRGB(28, 12, 26) or nil, 2)

	createGuiElement("TextLabel", {
		Name = "InvTitle",
		Size = isRoblox and UDim2.new(1, -12, 0, 22) or nil,
		Position = isRoblox and UDim2.new(0, 8, 0, 4) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextXAlignment = isRoblox and Enum.TextXAlignment.Left or nil,
		TextColor3 = isRoblox and Color3.fromRGB(255, 235, 145) or nil,
		Text = "Inwentarz Petów (Kliknij by założyć / zablokować):",
	}, invFrame)

	-- Sample default inventory entries
	for pIdx = 1, 4 do
		local pCard = createGuiElement("Frame", {
			Name = "PetCard_" .. tostring(pIdx),
			Size = isRoblox and UDim2.new(1, -16, 0, 44) or nil,
			Position = isRoblox and UDim2.new(0, 8, 0, 28 + (pIdx - 1) * 48) or nil,
			BackgroundColor3 = isRoblox and Color3.fromRGB(80, 36, 75) or nil,
		}, invFrame)
		addCornerAndStroke(pCard, 6, isRoblox and Color3.fromRGB(36, 16, 34) or nil, 1.5)

		local nameLbl = createGuiElement("TextLabel", {
			Name = "PetName",
			Size = isRoblox and UDim2.new(0.55, 0, 1, 0) or nil,
			Position = isRoblox and UDim2.new(0.02, 0, 0, 0) or nil,
			BackgroundTransparency = 1,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = true,
			TextXAlignment = isRoblox and Enum.TextXAlignment.Left or nil,
			TextColor3 = isRoblox and Color3.fromRGB(255, 255, 255) or nil,
			Text = if pIdx == 1 then "🐶 Piesek Farmerski (T1 Normalny)" elseif pIdx == 2 then "🐓 Robo-Kogut (T1 Złoty)" else "🐶 Piesek (T1 Normalny)",
		}, pCard)
		addTextStroke(nameLbl, 1.6)

		local equipBtn = createGuiElement("TextButton", {
			Name = "EquipBtn",
			Size = isRoblox and UDim2.new(0.20, 0, 0.76, 0) or nil,
			Position = isRoblox and UDim2.new(0.58, 0, 0.12, 0) or nil,
			BackgroundColor3 = isRoblox and Color3.fromRGB(95, 235, 45) or nil,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = true,
			TextColor3 = isRoblox and Color3.fromRGB(255, 255, 255) or nil,
			Text = "ZAŁÓŻ",
		}, pCard)
		addCornerAndStroke(equipBtn, 4, isRoblox and Color3.fromRGB(20, 50, 15) or nil, 1.5)
		if equipBtn.Activated then
			equipBtn.Activated:Connect(function()
				if type(self.onEquipPet) == "function" then
					self.onEquipPet("pet_" .. tostring(pIdx), 1)
				end
			end)
		end

		local lockBtn = createGuiElement("TextButton", {
			Name = "LockBtn",
			Size = isRoblox and UDim2.new(0.18, 0, 0.76, 0) or nil,
			Position = isRoblox and UDim2.new(0.80, 0, 0.12, 0) or nil,
			BackgroundColor3 = isRoblox and Color3.fromRGB(180, 140, 40) or nil,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = true,
			TextColor3 = isRoblox and Color3.fromRGB(255, 255, 255) or nil,
			Text = "🔓 ODBL.",
		}, pCard)
		addCornerAndStroke(lockBtn, 4, isRoblox and Color3.fromRGB(40, 30, 10) or nil, 1.5)
		if lockBtn.Activated then
			lockBtn.Activated:Connect(function()
				if type(self.onTogglePetLock) == "function" then
					self.onTogglePetLock("pet_" .. tostring(pIdx))
				end
			end)
		end

		self.petInventoryCards[pIdx] = pCard
	end

	-- Fusion Section
	local fusFrame = createGuiElement("Frame", {
		Name = "FusionFrame",
		Size = isRoblox and UDim2.new(1, -28, 0, 120) or nil,
		Position = isRoblox and UDim2.new(0, 14, 0, 356) or nil,
		BackgroundColor3 = isRoblox and Color3.fromRGB(42, 18, 40) or nil,
	}, pFrame)
	addCornerAndStroke(fusFrame, 8, isRoblox and Color3.fromRGB(22, 10, 20) or nil, 2)

	self.fusionChanceLabel = createGuiElement("TextLabel", {
		Name = "FusionChanceLabel",
		Size = isRoblox and UDim2.new(0.68, 0, 0, 24) or nil,
		Position = isRoblox and UDim2.new(0.02, 0, 0, 6) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextXAlignment = isRoblox and Enum.TextXAlignment.Left or nil,
		TextColor3 = isRoblox and Color3.fromRGB(255, 235, 120) or nil,
		Text = "Szansa Fuzji: 40% (Normalny ➔ Złoty)",
	}, fusFrame)
	addTextStroke(self.fusionChanceLabel, 1.8)

	self.fusionGuaranteeLabel = createGuiElement("TextLabel", {
		Name = "FusionGuaranteeLabel",
		Size = isRoblox and UDim2.new(0.68, 0, 0, 22) or nil,
		Position = isRoblox and UDim2.new(0.02, 0, 0, 32) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextXAlignment = isRoblox and Enum.TextXAlignment.Left or nil,
		TextColor3 = isRoblox and Color3.fromRGB(150, 245, 160) or nil,
		Text = "Gwarancja: 0 / 5 nieudanych prób",
	}, fusFrame)
	addTextStroke(self.fusionGuaranteeLabel, 1.8)

	self.fusionProPermitBadge = createGuiElement("TextLabel", {
		Name = "ProPermitBonusBadge",
		Size = isRoblox and UDim2.new(0.68, 0, 0, 20) or nil,
		Position = isRoblox and UDim2.new(0.02, 0, 0, 56) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextXAlignment = isRoblox and Enum.TextXAlignment.Left or nil,
		TextColor3 = isRoblox and Color3.fromRGB(255, 175, 240) or nil,
		Text = "✨ +10 p.p. Bonus Pro Permit (Dostępny)",
	}, fusFrame)
	addTextStroke(self.fusionProPermitBadge, 1.6)

	self.fusePetsButton = createGuiElement("TextButton", {
		Name = "FusePetsButton",
		Size = isRoblox and UDim2.new(0.28, 0, 0.72, 0) or nil,
		Position = isRoblox and UDim2.new(0.70, 0, 0.14, 0) or nil,
		BackgroundColor3 = isRoblox and Color3.fromRGB(160, 60, 200) or nil,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(255, 255, 255) or nil,
		Text = "POŁĄCZ\nPETY",
	}, fusFrame)
	addCornerAndStroke(self.fusePetsButton, 8, isRoblox and Color3.fromRGB(50, 15, 65) or nil, 2)
	addTextStroke(self.fusePetsButton, 2.0)
	if self.fusePetsButton.Activated then
		self.fusePetsButton.Activated:Connect(function()
			if type(self.onFusePets) == "function" then
				self.onFusePets("base_1", { "mat_1", "mat_2" })
			end
		end)
	end
end

function HUD:_buildShopModal(root)
	local sFrame = createGuiElement("Frame", {
		Name = "ShopModalFrame",
		Visible = false,
		Size = isRoblox and UDim2.new(0, 520, 0, 480) or nil,
		Position = isRoblox and UDim2.new(0.5, -260, 0.5, -240) or nil,
		BackgroundColor3 = isRoblox and Color3.fromRGB(56, 32, 48) or nil,
	}, root)
	addCornerAndStroke(sFrame, 14, isRoblox and Color3.fromRGB(255, 215, 65) or nil, 3.2)
	self.shopModal = sFrame

	createGuiElement("TextLabel", {
		Name = "ShopModalHeader",
		Size = isRoblox and UDim2.new(1, -50, 0, 36) or nil,
		Position = isRoblox and UDim2.new(0, 14, 0, 8) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(255, 235, 115) or nil,
		Text = "💎 SKLEP ZŁOTYCH JAJ I PRZEPUSTEK",
	}, sFrame)

	self:_buildCloseButton(sFrame, function()
		self.shopModal.Visible = false
	end)

	-- Tabs row: 1. Złote Jaja, 2. Wzmocnienia (Boosts), 3. Przepustki
	local tabsRow = createGuiElement("Frame", {
		Name = "ShopTabsRow",
		Size = isRoblox and UDim2.new(1, -28, 0, 36) or nil,
		Position = isRoblox and UDim2.new(0, 14, 0, 46) or nil,
		BackgroundTransparency = 1,
	}, sFrame)

	local sTabNames = { "Złote Jaja", "Wzmocnienia", "Przepustki" }
	for idx, sName in ipairs(sTabNames) do
		local tabBtn = createGuiElement("TextButton", {
			Name = "ShopTab_" .. tostring(idx),
			Size = isRoblox and UDim2.new(0.32, 0, 1, 0) or nil,
			Position = isRoblox and UDim2.new((idx - 1) * 0.34, 0, 0, 0) or nil,
			BackgroundColor3 = isRoblox and (if idx == 1 then Color3.fromRGB(255, 215, 65) else Color3.fromRGB(42, 22, 34)) or nil,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = true,
			TextColor3 = isRoblox and (if idx == 1 then Color3.fromRGB(24, 12, 10) else Color3.fromRGB(255, 255, 255)) or nil,
			Text = sName,
		}, tabsRow)
		addCornerAndStroke(tabBtn, 6, isRoblox and Color3.fromRGB(20, 12, 18) or nil, 1.8)
		if tabBtn.Activated then
			tabBtn.Activated:Connect(function()
				self:selectShopTab(idx)
			end)
		end
		self.shopModalTabButtons[idx] = tabBtn
	end

	-- Content Container
	local content = createGuiElement("Frame", {
		Name = "ShopContentContainer",
		Size = isRoblox and UDim2.new(1, -28, 0, 380) or nil,
		Position = isRoblox and UDim2.new(0, 14, 0, 88) or nil,
		BackgroundTransparency = 1,
	}, sFrame)

	-- Build static product cards for tab 1 (GE), tab 2 (Boosts), tab 3 (Passes)
	self:_buildShopProducts(content)
end

function HUD:_buildShopProducts(container)
	-- Tab 1: GE Packs
	local tab1Frame = createGuiElement("Frame", {
		Name = "Tab1_GEPacks",
		Visible = true,
		Size = isRoblox and UDim2.new(1, 0, 1, 0) or nil,
		BackgroundTransparency = 1,
	}, container)

	local geProducts = {
		{ id = "ge_pack_small", title = "Paczka Złotych Jaj (1,000 GE)", desc = "Zastrzyk Złotych Jaj na epickie badania i boosty", btnText = "KUP" },
		{ id = "ge_pack_large", title = "Wielka Paka Złotych Jaj (10,000 GE)", desc = "Maksymalna wartość Złotych Jaj na badania", btnText = "KUP" },
		{ id = "piggy_break", title = "Rozbij Skarbonkę (Break Piggy)", desc = "Wypłać wszystkie Złote Jaja zmagazynowane w Skarbonce", btnText = "ROZBIJ" },
	}

	for i, prod in ipairs(geProducts) do
		local card = createGuiElement("Frame", {
			Name = "ShopCard_" .. prod.id,
			Size = isRoblox and UDim2.new(1, 0, 0, 74) or nil,
			Position = isRoblox and UDim2.new(0, 0, 0, (i - 1) * 82) or nil,
			BackgroundColor3 = isRoblox and Color3.fromRGB(78, 44, 66) or nil,
		}, tab1Frame)
		addCornerAndStroke(card, 8, isRoblox and Color3.fromRGB(36, 18, 30) or nil, 1.8)

		local title = createGuiElement("TextLabel", {
			Name = "Title",
			Size = isRoblox and UDim2.new(0.70, 0, 0, 24) or nil,
			Position = isRoblox and UDim2.new(0.03, 0, 0, 8) or nil,
			BackgroundTransparency = 1,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = true,
			TextXAlignment = isRoblox and Enum.TextXAlignment.Left or nil,
			TextColor3 = isRoblox and Color3.fromRGB(255, 235, 95) or nil,
			Text = prod.title,
		}, card)
		addTextStroke(title, 1.8)

		local desc = createGuiElement("TextLabel", {
			Name = "Desc",
			Size = isRoblox and UDim2.new(0.70, 0, 0, 32) or nil,
			Position = isRoblox and UDim2.new(0.03, 0, 0, 34) or nil,
			BackgroundTransparency = 1,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = true,
			TextXAlignment = isRoblox and Enum.TextXAlignment.Left or nil,
			TextColor3 = isRoblox and Color3.fromRGB(240, 240, 240) or nil,
			Text = prod.desc,
		}, card)

		local buyBtn = createGuiElement("TextButton", {
			Name = "BuyProductButton",
			Size = isRoblox and UDim2.new(0.24, 0, 0.72, 0) or nil,
			Position = isRoblox and UDim2.new(0.73, 0, 0.14, 0) or nil,
			BackgroundColor3 = isRoblox and Color3.fromRGB(95, 235, 45) or nil,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = true,
			TextColor3 = isRoblox and Color3.fromRGB(255, 255, 255) or nil,
			Text = prod.btnText,
		}, card)
		addCornerAndStroke(buyBtn, 6, isRoblox and Color3.fromRGB(20, 50, 15) or nil, 1.8)
		if buyBtn.Activated then
			buyBtn.Activated:Connect(function()
				if type(self.onPurchaseProduct) == "function" then
					self.onPurchaseProduct(prod.id)
				end
			end)
		end
		self.shopProductCards[prod.id] = card
	end

	-- Tab 2: Boosts
	local tab2Frame = createGuiElement("Frame", {
		Name = "Tab2_Boosts",
		Visible = false,
		Size = isRoblox and UDim2.new(1, 0, 1, 0) or nil,
		BackgroundTransparency = 1,
	}, container)

	for i, bSpec in ipairs(BOOSTS_CATALOG) do
		local card = createGuiElement("Frame", {
			Name = "BoostCard_" .. bSpec.id,
			Size = isRoblox and UDim2.new(1, 0, 0, 42) or nil,
			Position = isRoblox and UDim2.new(0, 0, 0, (i - 1) * 46) or nil,
			BackgroundColor3 = isRoblox and Color3.fromRGB(68, 38, 58) or nil,
		}, tab2Frame)
		addCornerAndStroke(card, 6, isRoblox and Color3.fromRGB(32, 16, 28) or nil, 1.5)

		local title = createGuiElement("TextLabel", {
			Name = "Title",
			Size = isRoblox and UDim2.new(0.55, 0, 1, 0) or nil,
			Position = isRoblox and UDim2.new(0.02, 0, 0, 0) or nil,
			BackgroundTransparency = 1,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = true,
			TextXAlignment = isRoblox and Enum.TextXAlignment.Left or nil,
			TextColor3 = isRoblox and Color3.fromRGB(255, 255, 255) or nil,
			Text = bSpec.name .. " (" .. bSpec.effect .. ")",
		}, card)
		addTextStroke(title, 1.5)

		local priceLbl = createGuiElement("TextLabel", {
			Name = "Price",
			Size = isRoblox and UDim2.new(0.20, 0, 1, 0) or nil,
			Position = isRoblox and UDim2.new(0.58, 0, 0, 0) or nil,
			BackgroundTransparency = 1,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = true,
			TextColor3 = isRoblox and Color3.fromRGB(255, 215, 65) or nil,
			Text = tostring(bSpec.priceGE) .. " GE",
		}, card)
		addTextStroke(priceLbl, 1.5)

		local buyBtn = createGuiElement("TextButton", {
			Name = "BuyBoostButton",
			Size = isRoblox and UDim2.new(0.18, 0, 0.76, 0) or nil,
			Position = isRoblox and UDim2.new(0.80, 0, 0.12, 0) or nil,
			BackgroundColor3 = isRoblox and Color3.fromRGB(95, 235, 45) or nil,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = true,
			TextColor3 = isRoblox and Color3.fromRGB(255, 255, 255) or nil,
			Text = "KUP",
		}, card)
		addCornerAndStroke(buyBtn, 4, isRoblox and Color3.fromRGB(20, 50, 15) or nil, 1.5)
		if buyBtn.Activated then
			buyBtn.Activated:Connect(function()
				if type(self.onBuyBoost) == "function" then
					self.onBuyBoost(bSpec.id)
				end
			end)
		end
		self.shopProductCards[bSpec.id] = card
	end

	-- Tab 3: GamePasses
	local tab3Frame = createGuiElement("Frame", {
		Name = "Tab3_GamePasses",
		Visible = false,
		Size = isRoblox and UDim2.new(1, 0, 1, 0) or nil,
		BackgroundTransparency = 1,
	}, container)

	local passes = { SHOP_PRODUCTS_CATALOG.pro_permit, SHOP_PRODUCTS_CATALOG.buy_max }
	for i, pass in ipairs(passes) do
		local card = createGuiElement("Frame", {
			Name = "PassCard_" .. pass.id,
			Size = isRoblox and UDim2.new(1, 0, 0, 110) or nil,
			Position = isRoblox and UDim2.new(0, 0, 0, (i - 1) * 120) or nil,
			BackgroundColor3 = isRoblox and Color3.fromRGB(78, 44, 66) or nil,
		}, tab3Frame)
		addCornerAndStroke(card, 8, isRoblox and Color3.fromRGB(36, 18, 30) or nil, 1.8)

		local title = createGuiElement("TextLabel", {
			Name = "Title",
			Size = isRoblox and UDim2.new(0.70, 0, 0, 24) or nil,
			Position = isRoblox and UDim2.new(0.03, 0, 0, 6) or nil,
			BackgroundTransparency = 1,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = true,
			TextXAlignment = isRoblox and Enum.TextXAlignment.Left or nil,
			TextColor3 = isRoblox and Color3.fromRGB(255, 235, 95) or nil,
			Text = pass.name,
		}, card)
		addTextStroke(title, 1.8)

		local desc = createGuiElement("TextLabel", {
			Name = "Desc",
			Size = isRoblox and UDim2.new(0.70, 0, 0, 42) or nil,
			Position = isRoblox and UDim2.new(0.03, 0, 0, 30) or nil,
			BackgroundTransparency = 1,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = true,
			TextXAlignment = isRoblox and Enum.TextXAlignment.Left or nil,
			TextColor3 = isRoblox and Color3.fromRGB(240, 240, 240) or nil,
			Text = pass.desc,
		}, card)

		if pass.notice then
			local noticeLbl = createGuiElement("TextLabel", {
				Name = "Notice",
				Size = isRoblox and UDim2.new(0.70, 0, 0, 28) or nil,
				Position = isRoblox and UDim2.new(0.03, 0, 0, 74) or nil,
				BackgroundTransparency = 1,
				Font = isRoblox and Enum.Font.FredokaOne or nil,
				TextScaled = true,
				TextXAlignment = isRoblox and Enum.TextXAlignment.Left or nil,
				TextColor3 = isRoblox and Color3.fromRGB(255, 175, 140) or nil,
				Text = pass.notice,
			}, card)
		end

		local buyBtn = createGuiElement("TextButton", {
			Name = "BuyPassButton",
			Size = isRoblox and UDim2.new(0.24, 0, 0.44, 0) or nil,
			Position = isRoblox and UDim2.new(0.73, 0, 0.28, 0) or nil,
			BackgroundColor3 = isRoblox and Color3.fromRGB(95, 235, 45) or nil,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = true,
			TextColor3 = isRoblox and Color3.fromRGB(255, 255, 255) or nil,
			Text = "ODBLOKUJ",
		}, card)
		addCornerAndStroke(buyBtn, 6, isRoblox and Color3.fromRGB(20, 50, 15) or nil, 1.8)
		if buyBtn.Activated then
			buyBtn.Activated:Connect(function()
				if type(self.onPurchaseProduct) == "function" then
					self.onPurchaseProduct(pass.id)
				end
			end)
		end
		self.shopProductCards[pass.id] = card
	end
end

function HUD:_buildCalendarModal(root)
	local cFrame = createGuiElement("Frame", {
		Name = "CalendarFrame",
		Visible = false,
		Size = isRoblox and UDim2.new(0, 560, 0, 500) or nil,
		Position = isRoblox and UDim2.new(0.5, -280, 0.5, -250) or nil,
		BackgroundColor3 = isRoblox and Color3.fromRGB(48, 32, 58) or nil,
	}, root)
	addCornerAndStroke(cFrame, 14, isRoblox and Color3.fromRGB(255, 175, 75) or nil, 3.2)
	self.calendarModal = cFrame

	createGuiElement("TextLabel", {
		Name = "CalendarHeader",
		Size = isRoblox and UDim2.new(1, -50, 0, 36) or nil,
		Position = isRoblox and UDim2.new(0, 14, 0, 8) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(255, 215, 115) or nil,
		Text = "📅 KALENDARZ NAGRÓD I TROFEA",
	}, cFrame)

	self:_buildCloseButton(cFrame, function()
		self.calendarModal.Visible = false
	end)

	-- Tabs: 1. Kalendarz 28 Dni, 2. Trofea Jaj
	local tabsRow = createGuiElement("Frame", {
		Name = "CalendarTabsRow",
		Size = isRoblox and UDim2.new(1, -28, 0, 34) or nil,
		Position = isRoblox and UDim2.new(0, 14, 0, 46) or nil,
		BackgroundTransparency = 1,
	}, cFrame)

	local cTabNames = { "Kalendarz 28 Dni", "Trofea Jaj" }
	for idx, cName in ipairs(cTabNames) do
		local tabBtn = createGuiElement("TextButton", {
			Name = "CalendarTab_" .. tostring(idx),
			Size = isRoblox and UDim2.new(0.48, 0, 1, 0) or nil,
			Position = isRoblox and UDim2.new((idx - 1) * 0.52, 0, 0, 0) or nil,
			BackgroundColor3 = isRoblox and (if idx == 1 then Color3.fromRGB(255, 175, 75) else Color3.fromRGB(36, 22, 44)) or nil,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = true,
			TextColor3 = isRoblox and (if idx == 1 then Color3.fromRGB(24, 12, 10) else Color3.fromRGB(255, 255, 255)) or nil,
			Text = cName,
		}, tabsRow)
		addCornerAndStroke(tabBtn, 6, isRoblox and Color3.fromRGB(20, 12, 24) or nil, 1.8)
		if tabBtn.Activated then
			tabBtn.Activated:Connect(function()
				self:selectCalendarTab(idx)
			end)
		end
		self.calendarTabButtons[idx] = tabBtn
	end

	-- Tab 1: 28-day Calendar Grid
	local calContent = createGuiElement("Frame", {
		Name = "CalendarContent_Tab1",
		Visible = true,
		Size = isRoblox and UDim2.new(1, -28, 0, 330) or nil,
		Position = isRoblox and UDim2.new(0, 14, 0, 88) or nil,
		BackgroundColor3 = isRoblox and Color3.fromRGB(36, 22, 44) or nil,
	}, cFrame)
	addCornerAndStroke(calContent, 8, isRoblox and Color3.fromRGB(20, 12, 24) or nil, 2)

	-- 7 columns x 4 rows
	for day = 1, 28 do
		local col = (day - 1) % 7
		local row = math.floor((day - 1) / 7)
		local reward = CALENDAR_REWARDS_CATALOG[day] or { label = "Nagroda", icon = "🎁" }

		local dayCell = createGuiElement("Frame", {
			Name = "DayCell_" .. tostring(day),
			Size = isRoblox and UDim2.new(0.13, 0, 0.22, 0) or nil,
			Position = isRoblox and UDim2.new(0.015 + col * 0.14, 0, 0.03 + row * 0.24, 0) or nil,
			BackgroundColor3 = isRoblox and (if day == 1 then Color3.fromRGB(225, 160, 45) else Color3.fromRGB(56, 36, 68)) or nil,
		}, calContent)
		addCornerAndStroke(dayCell, 4, isRoblox and Color3.fromRGB(24, 14, 28) or nil, 1.2)

		local dayNum = createGuiElement("TextLabel", {
			Name = "DayNumber",
			Size = isRoblox and UDim2.new(1, 0, 0.35, 0) or nil,
			Position = isRoblox and UDim2.new(0, 0, 0.05, 0) or nil,
			BackgroundTransparency = 1,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = true,
			TextColor3 = isRoblox and Color3.fromRGB(255, 235, 120) or nil,
			Text = "D" .. tostring(day),
		}, dayCell)

		local dayRew = createGuiElement("TextLabel", {
			Name = "RewardText",
			Size = isRoblox and UDim2.new(1, 0, 0.55, 0) or nil,
			Position = isRoblox and UDim2.new(0, 0, 0.40, 0) or nil,
			BackgroundTransparency = 1,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = true,
			TextColor3 = isRoblox and Color3.fromRGB(255, 255, 255) or nil,
			Text = reward.icon .. "\n" .. reward.label,
		}, dayCell)

		self.calendarDayCells[day] = dayCell
	end

	-- Claim Daily Gift Button
	self.claimDailyGiftButton = createGuiElement("TextButton", {
		Name = "ClaimDailyGiftButton",
		Size = isRoblox and UDim2.new(1, -28, 0, 48) or nil,
		Position = isRoblox and UDim2.new(0, 14, 1, -58) or nil,
		BackgroundColor3 = isRoblox and Color3.fromRGB(95, 235, 45) or nil,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(255, 255, 255) or nil,
		Text = "🎁 ODBIERZ DZISIEJSZĄ NAGRODĘ",
	}, cFrame)
	addCornerAndStroke(self.claimDailyGiftButton, 8, isRoblox and Color3.fromRGB(20, 50, 15) or nil, 2.2)
	addTextStroke(self.claimDailyGiftButton, 2.0)
	if self.claimDailyGiftButton.Activated then
		self.claimDailyGiftButton.Activated:Connect(function()
			if type(self.onClaimDailyGift) == "function" then
				self.onClaimDailyGift()
			end
		end)
	end

	-- Tab 2: Trophies List
	local trophContent = createGuiElement("Frame", {
		Name = "TrophiesContent_Tab2",
		Visible = false,
		Size = isRoblox and UDim2.new(1, -28, 0, 380) or nil,
		Position = isRoblox and UDim2.new(0, 14, 0, 88) or nil,
		BackgroundColor3 = isRoblox and Color3.fromRGB(36, 22, 44) or nil,
	}, cFrame)
	addCornerAndStroke(trophContent, 8, isRoblox and Color3.fromRGB(20, 12, 24) or nil, 2)

	-- Sample eggs trophies cards (first 6 displayed, extensible)
	for eIdx = 0, 5 do
		local egg = EGGS_DATA[eIdx] or { name = "Jajo " .. tostring(eIdx) }
		local card = createGuiElement("Frame", {
			Name = "TrophyCard_Egg_" .. tostring(eIdx),
			Size = isRoblox and UDim2.new(1, -12, 0, 54) or nil,
			Position = isRoblox and UDim2.new(0, 6, 0, 6 + eIdx * 60) or nil,
			BackgroundColor3 = isRoblox and Color3.fromRGB(56, 36, 68) or nil,
		}, trophContent)
		addCornerAndStroke(card, 6, isRoblox and Color3.fromRGB(28, 16, 34) or nil, 1.5)

		local eName = createGuiElement("TextLabel", {
			Name = "EggTitle",
			Size = isRoblox and UDim2.new(0.35, 0, 1, 0) or nil,
			Position = isRoblox and UDim2.new(0.02, 0, 0, 0) or nil,
			BackgroundTransparency = 1,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = true,
			TextXAlignment = isRoblox and Enum.TextXAlignment.Left or nil,
			TextColor3 = isRoblox and Color3.fromRGB(255, 235, 120) or nil,
			Text = egg.name,
		}, card)
		addTextStroke(eName, 1.6)

		-- 5 Trophy Cups: Bronze, Silver, Gold, Platinum, Diamond
		for tIdx, tInfo in ipairs(TROPHY_POPULATION_TIERS) do
			local cupBtn = createGuiElement("TextButton", {
				Name = "CupBtn_" .. tostring(tIdx),
				Size = isRoblox and UDim2.new(0.11, 0, 0.76, 0) or nil,
				Position = isRoblox and UDim2.new(0.38 + (tIdx - 1) * 0.12, 0, 0.12, 0) or nil,
				BackgroundColor3 = isRoblox and Color3.fromRGB(78, 48, 92) or nil,
				Font = isRoblox and Enum.Font.FredokaOne or nil,
				TextScaled = true,
				TextColor3 = isRoblox and Color3.fromRGB(255, 255, 255) or nil,
				Text = tInfo.icon .. "\n" .. tInfo.name,
			}, card)
			addCornerAndStroke(cupBtn, 4, isRoblox and Color3.fromRGB(30, 15, 36) or nil, 1.2)
			if cupBtn.Activated then
				cupBtn.Activated:Connect(function()
					if type(self.onClaimTrophy) == "function" then
						self.onClaimTrophy(eIdx, tIdx)
					end
				end)
			end
		end

		self.trophyCards[eIdx] = card
	end
end

function HUD:_buildEggUpgradeModal(root)
	local eggModal = createGuiElement("Frame", {
		Name = "EggUpgradeModal",
		Visible = false,
		Size = isRoblox and UDim2.new(0, 440, 0, 390) or nil,
		Position = isRoblox and UDim2.new(0.5, -220, 0.5, -195) or nil,
		BackgroundColor3 = isRoblox and Color3.fromRGB(68, 36, 22) or nil,
	}, root)
	addCornerAndStroke(eggModal, 14, isRoblox and Color3.fromRGB(255, 215, 65) or nil, 3.2)
	self.eggUpgradeModal = eggModal

	createGuiElement("TextLabel", {
		Name = "EggUpgradeTitle",
		Size = isRoblox and UDim2.new(1, -60, 0, 36) or nil,
		Position = isRoblox and UDim2.new(0, 16, 0, 10) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(255, 225, 75) or nil,
		Text = "✨ STACJA BADAWCZA JAJ",
	}, eggModal)

	self:_buildCloseButton(eggModal, function()
		self.eggUpgradeModal.Visible = false
	end)

	self.eggUpgradeCurrentLabel = createGuiElement("TextLabel", {
		Name = "CurrentEggLabel",
		Size = isRoblox and UDim2.new(1, -32, 0, 26) or nil,
		Position = isRoblox and UDim2.new(0, 16, 0, 52) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(255, 255, 255) or nil,
		Text = "🥚 Aktualne: Jajo Jadalne (Edible)",
	}, eggModal)

	self.eggUpgradeNextLabel = createGuiElement("TextLabel", {
		Name = "NextEggLabel",
		Size = isRoblox and UDim2.new(1, -32, 0, 26) or nil,
		Position = isRoblox and UDim2.new(0, 16, 0, 82) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(115, 245, 115) or nil,
		Text = "✨ Następne: Jajo Superfood",
	}, eggModal)

	self.eggUpgradeMultLabel = createGuiElement("TextLabel", {
		Name = "MultiplierLabel",
		Size = isRoblox and UDim2.new(1, -32, 0, 24) or nil,
		Position = isRoblox and UDim2.new(0, 16, 0, 112) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(255, 215, 100) or nil,
		Text = "📈 Mnożnik Wartości: 5.0x",
	}, eggModal)

	self.eggUpgradeCurrentFvLabel = createGuiElement("TextLabel", {
		Name = "CurrentFvLabel",
		Size = isRoblox and UDim2.new(1, -32, 0, 24) or nil,
		Position = isRoblox and UDim2.new(0, 16, 0, 142) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(135, 225, 255) or nil,
		Text = "💰 Twoje Farm Value: $0",
	}, eggModal)

	self.eggUpgradeReqFvLabel = createGuiElement("TextLabel", {
		Name = "RequiredFvLabel",
		Size = isRoblox and UDim2.new(1, -32, 0, 24) or nil,
		Position = isRoblox and UDim2.new(0, 16, 0, 170) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(255, 185, 115) or nil,
		Text = "🎯 Wymagane Farm Value: $68.0M",
	}, eggModal)

	self.eggUpgradeWarningLabel = createGuiElement("TextLabel", {
		Name = "WarningLabel",
		Size = isRoblox and UDim2.new(1, -32, 0, 50) or nil,
		Position = isRoblox and UDim2.new(0, 16, 0, 202) or nil,
		BackgroundTransparency = 1,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(255, 200, 180) or nil,
		Text = "⚠️ Awans zresetuje bieżącą gotówkę, kurniki i pojazdy.\nPety, Złote Jaja i badania Epickie zostaną zachowane!",
	}, eggModal)

	local upgEggBtn = createGuiElement("TextButton", {
		Name = "UpgradeEggButton",
		Size = isRoblox and UDim2.new(1, -40, 0, 52) or nil,
		Position = isRoblox and UDim2.new(0, 20, 0, 260) or nil,
		BackgroundColor3 = isRoblox and Color3.fromRGB(95, 235, 55) or nil,
		Font = isRoblox and Enum.Font.FredokaOne or nil,
		TextScaled = true,
		TextColor3 = isRoblox and Color3.fromRGB(255, 255, 255) or nil,
		Text = "AWANSUJ NASTĘPNE JAJO",
	}, eggModal)
	addCornerAndStroke(upgEggBtn, 10, isRoblox and Color3.fromRGB(24, 60, 14) or nil, 2.5)
	self.eggUpgradeBtn = upgEggBtn

	if upgEggBtn.Activated then
		upgEggBtn.Activated:Connect(function()
			local farm = self.stateStore and self.stateStore:getFarm()
			local curEggIdx = (farm and farm.eggIndex) or 0
			local nextEggIdx = curEggIdx + 1
			if nextEggIdx <= 18 and type(self.onUpgradeEggRequested) == "function" then
				self.onUpgradeEggRequested(nextEggIdx)
			end
		end)
	end
end

-- ============================================================================
-- Modals Visibility & Mutual Exclusivity
-- ============================================================================

function HUD:closeAllModals()
	if self.habitatsModal then self.habitatsModal.Visible = false end
	if self.vehiclesModal then self.vehiclesModal.Visible = false end
	if self.shopFrame then self.shopFrame.Visible = false end
	if self.petsModal then self.petsModal.Visible = false end
	if self.shopModal then self.shopModal.Visible = false end
	if self.calendarModal then self.calendarModal.Visible = false end
	if self.eggUpgradeModal then self.eggUpgradeModal.Visible = false end
end

function HUD:toggleHabitatsModal(forceState)
	if not self.habitatsModal then return end
	local target = if forceState ~= nil then forceState else not self.habitatsModal.Visible
	self:closeAllModals()
	self.habitatsModal.Visible = target
end

function HUD:toggleVehiclesModal(forceState)
	if not self.vehiclesModal then return end
	local target = if forceState ~= nil then forceState else not self.vehiclesModal.Visible
	self:closeAllModals()
	self.vehiclesModal.Visible = target
end

function HUD:toggleResearchModal(forceState)
	if not self.shopFrame then return end
	local target = if forceState ~= nil then forceState else not self.shopFrame.Visible
	self:closeAllModals()
	self.shopFrame.Visible = target
end

function HUD:togglePetsModal(forceState)
	if not self.petsModal then return end
	local target = if forceState ~= nil then forceState else not self.petsModal.Visible
	self:closeAllModals()
	self.petsModal.Visible = target
end

function HUD:toggleShopModal(forceState)
	if not self.shopModal then return end
	local target = if forceState ~= nil then forceState else not self.shopModal.Visible
	self:closeAllModals()
	self.shopModal.Visible = target
end

function HUD:toggleCalendarModal(forceState)
	if not self.calendarModal then return end
	local target = if forceState ~= nil then forceState else not self.calendarModal.Visible
	self:closeAllModals()
	self.calendarModal.Visible = target
end

function HUD:toggleEggUpgradeModal(forceState)
	if not self.eggUpgradeModal then return end
	local target = if forceState ~= nil then forceState else not self.eggUpgradeModal.Visible
	self:closeAllModals()
	self.eggUpgradeModal.Visible = target
end

-- Tab selection methods
function HUD:selectResearchTier(tierIndex)
	self.selectedResearchTier = tierIndex
	for idx, btn in ipairs(self.researchTabButtons) do
		if isRoblox then
			btn.BackgroundColor3 = if idx == tierIndex then Color3.fromRGB(115, 225, 255) else Color3.fromRGB(42, 22, 14)
			btn.TextColor3 = if idx == tierIndex then Color3.fromRGB(18, 12, 10) else Color3.fromRGB(240, 240, 240)
		end
	end
	self:update()
end

function HUD:selectShopTab(tabIndex)
	self.selectedShopTab = tabIndex
	for idx, btn in ipairs(self.shopModalTabButtons) do
		if isRoblox then
			btn.BackgroundColor3 = if idx == tabIndex then Color3.fromRGB(255, 215, 65) else Color3.fromRGB(42, 22, 34)
			btn.TextColor3 = if idx == tabIndex then Color3.fromRGB(24, 12, 10) else Color3.fromRGB(255, 255, 255)
		end
	end
	local cont = self.shopModal and self.shopModal:FindFirstChild("ShopContentContainer")
	if cont then
		local t1 = cont:FindFirstChild("Tab1_GEPacks")
		local t2 = cont:FindFirstChild("Tab2_Boosts")
		local t3 = cont:FindFirstChild("Tab3_GamePasses")
		if t1 then t1.Visible = (tabIndex == 1) end
		if t2 then t2.Visible = (tabIndex == 2) end
		if t3 then t3.Visible = (tabIndex == 3) end
	end
end

function HUD:selectCalendarTab(tabIndex)
	self.selectedCalendarTab = tabIndex
	for idx, btn in ipairs(self.calendarTabButtons) do
		if isRoblox then
			btn.BackgroundColor3 = if idx == tabIndex then Color3.fromRGB(255, 175, 75) else Color3.fromRGB(36, 22, 44)
			btn.TextColor3 = if idx == tabIndex then Color3.fromRGB(24, 12, 10) else Color3.fromRGB(255, 255, 255)
		end
	end
	if self.calendarModal then
		local t1 = self.calendarModal:FindFirstChild("CalendarContent_Tab1")
		local t2 = self.calendarModal:FindFirstChild("TrophiesContent_Tab2")
		local claimBtn = self.claimDailyGiftButton
		if t1 then t1.Visible = (tabIndex == 1) end
		if t2 then t2.Visible = (tabIndex == 2) end
		if claimBtn then claimBtn.Visible = (tabIndex == 1) end
	end
end

-- ============================================================================
-- State & Subscriptions
-- ============================================================================

function HUD:_setupSubscriptions()
	if self.stateStore ~= nil and type(self.stateStore.onStatusChanged) == "function" then
		table.insert(self._unsubs, self.stateStore:onStatusChanged(function(newStatus)
			self:updateStatus(newStatus)
		end))
	end

	if self.stateStore ~= nil and type(self.stateStore.onStateChanged) == "function" then
		table.insert(self._unsubs, self.stateStore:onStateChanged(function()
			self:update()
		end))
	end

	local transport = self.intentControllers and self.intentControllers.transport
	if transport ~= nil and type(transport.onQuote) == "function" then
		table.insert(self._unsubs, transport:onQuote(function(quoteView)
			self:onQuoteReceived(quoteView)
		end))
	end
end

function HUD:updateStatus(newStatus)
	self.sessionStatus = newStatus or self.stateStore:getStatus()
	if self.sessionStatusLabel ~= nil then
		self.sessionStatusLabel.Text = self.sessionStatus
	end
	if isRoblox and self.sessionBanner ~= nil then
		self.sessionBanner.Visible = (self.sessionStatus ~= "READY")
	end
end

function HUD:update()
	self:updateStatus(self.stateStore:getStatus())

	local farm = self.stateStore:getFarm()
	if farm == nil then
		return
	end

	-- 1. Balances & Global Rates
	if self.cashLabel ~= nil then
		self.cashLabel.Text = HUD.formatCash(farm.cash)
	end
	if self.producedEggsLabel ~= nil then
		self.producedEggsLabel.Text = HUD.formatRate(farm.producedEggsPerSecond, "/s")
	end
	if self.soldEggsLabel ~= nil then
		self.soldEggsLabel.Text = HUD.formatRate(farm.soldEggsPerSecond, "/s")
	end
	if self.shippingLabel ~= nil then
		local fleetRate = (farm.fleet and farm.fleet.shippingPerMinute) or "0"
		self.shippingLabel.Text = HUD.formatRate(fleetRate, "/min")
	end

	-- 2. Hatchery Stock & Capacity
	if farm.hatchery ~= nil then
		local stock = farm.hatchery.stock
		local capacity = farm.hatchery.capacity
		local refill = farm.hatchery.refillPerSecond

		if self.hatcheryStockLabel ~= nil then
			self.hatcheryStockLabel.Text = string.format("%s / %s", formatCompact(stock), formatCompact(capacity))
		end
		if self.hatcheryRefillLabel ~= nil then
			self.hatcheryRefillLabel.Text = "+" .. HUD.formatRate(refill, "/s")
		end

		local sNum = tonumber(stock) or 0
		local cNum = tonumber(capacity) or 1
		self.hatcheryRatio = if cNum > 0 then math.clamp(sNum / cNum, 0, 1) else 0
	end

	-- 3. Habitats 1..4 & Total Chickens
	local totalPop = 0
	if type(farm.habitats) == "table" then
		for _, hab in ipairs(farm.habitats) do
			local slotId = hab.slotId
			if slotId and slotId >= 1 and slotId <= 4 then
				self.habitatPopulations[slotId] = hab.population
				self.habitatCapacities[slotId] = hab.capacity

				if self.habitatLabels[slotId] ~= nil then
					self.habitatLabels[slotId].Text = string.format("%s / %s", formatCompact(hab.population), formatCompact(hab.capacity))
				end

				local pNum = tonumber(hab.population) or 0
				local cNum = tonumber(hab.capacity) or 1
				totalPop += pNum
				self.habitatFillRatios[slotId] = if cNum > 0 then math.clamp(pNum / cNum, 0, 1) else 0

				-- Update Habitat card title & next upgrade label
				local card = self.habitatCards[slotId]
				if card then
					local currentIdx = hab.habitatIndex or 0
					local currentName = HABITAT_DISPLAY_NAMES[currentIdx] or ("Kurnik " .. tostring(currentIdx))
					local titleLabel = card:FindFirstChild("TitleLabel")
					if titleLabel then
						titleLabel.Text = string.format("Parcela #%d: %s", slotId, currentName)
					end
					local nextIdx = currentIdx + 1
					local nextName = HABITAT_DISPLAY_NAMES[nextIdx] or "MAX"
					local nextLabel = card:FindFirstChild("NextUpgradeLabel")
					if nextLabel then
						nextLabel.Text = if nextIdx <= 18 then ("Następny: " .. nextName) else "Maksymalny Kurnik"
					end
				end
			end
		end
	end
	self.totalChickensCount = totalPop
	if self.totalChickensLabel ~= nil then
		self.totalChickensLabel.Text = "Całkowita liczba kurczaków: " .. formatCompact(totalPop)
	end

	-- 4. Vehicles Modal Comparison Gauge & Slots
	self:_updateVehiclesModal(farm)

	-- 5. Research Modal Multi-tier view
	self:_updateResearchModal(farm)

	-- 6. Egg Upgrade Modal Refresh
	self:_updateEggUpgradeModal(farm)
end

function HUD:_updateVehiclesModal(farm)
	if not self.vehiclesModal or not farm then return end

	local fleetRate = tonumber((farm.fleet and farm.fleet.shippingPerMinute) or 0) or 0
	local eggPerSec = tonumber(farm.producedEggsPerSecond or 0) or 0
	local eggRatePerMin = eggPerSec * 60

	if self.shippingComparisonStatusLabel then
		self.shippingComparisonStatusLabel.Text = string.format("Spedycja: %s/min vs Produkcja: %s/min", formatCompact(fleetRate), formatCompact(eggRatePerMin))
	end

	local badge = self.shippingComparisonBar and self.shippingComparisonBar:FindFirstChild("StatusBadge")
	if badge then
		if fleetRate >= eggRatePerMin then
			badge.Text = "Spedycja wystarczająca"
			if isRoblox then badge.BackgroundColor3 = Color3.fromRGB(50, 180, 70) end
		else
			badge.Text = "Wąskie gardło spedycji!"
			if isRoblox then badge.BackgroundColor3 = Color3.fromRGB(220, 75, 45) end
		end
	end

	-- Update vehicle slot cards
	local vehiclesList = (farm.fleet and farm.fleet.vehicles) or {}
	local currentFleetSlots = #vehiclesList
	if currentFleetSlots == 0 then currentFleetSlots = 1 end

	for slotId = 1, 17 do
		local slotData = self.vehicleCards[slotId]
		if slotData then
			local vEntry = vehiclesList[slotId]
			local vIdx = vEntry and vEntry.vehicleIndex or 0
			local isUnlocked = (slotId <= math.max(currentFleetSlots, 1))

			slotData.card.Visible = (slotId <= 4 or isUnlocked)

			if isUnlocked then
				local vName = VEHICLE_DISPLAY_NAMES[vIdx] or ("Pojazd #" .. tostring(vIdx))
				local vCap = VEHICLE_CAPACITIES[vIdx] or 5000
				slotData.titleLabel.Text = string.format("Slot #%d: %s", slotId, vName)
				slotData.capLabel.Text = string.format("Wydajność: %s jaj/min", formatCompact(vCap))
				slotData.upgBtn.Text = "ULEPSZ"
				slotData.upgBtn.Active = true
				if isRoblox then slotData.upgBtn.BackgroundColor3 = Color3.fromRGB(95, 235, 45) end
			else
				slotData.titleLabel.Text = string.format("Slot #%d: Zablokowany", slotId)
				slotData.capLabel.Text = "🔒 Wymaga badań floty"
				slotData.priceLabel.Text = "-"
				slotData.upgBtn.Text = "ZABLOK."
				slotData.upgBtn.Active = false
				if isRoblox then slotData.upgBtn.BackgroundColor3 = Color3.fromRGB(120, 120, 120) end
			end
		end
	end
end

function HUD:_updateResearchModal(farm)
	if not self.shopFrame or not farm then return end

	local currentTier = self.selectedResearchTier or 1
	local isEpicTab = (currentTier == 14)

	-- Calculate total purchased research levels to evaluate tier unlocking
	local totalPurchasedLevels = 0
	if type(farm.common) == "table" then
		for _, r in ipairs(farm.common) do
			totalPurchasedLevels += (tonumber(r.level) or 0)
		end
	end

	local requiredLevels = if not isEpicTab then (TIER_THRESHOLDS[currentTier] or 0) else 0
	local isTierUnlocked = (totalPurchasedLevels >= requiredLevels)

	if self.researchTierLockBanner then
		if not isTierUnlocked and not isEpicTab then
			self.researchTierLockBanner.Visible = true
			self.researchTierLockBanner.Text = string.format("🔒 Tier %d zablokowany! Wymaga %d zakupionych badań (masz %d)", currentTier, requiredLevels, totalPurchasedLevels)
		else
			self.researchTierLockBanner.Visible = false
		end
	end

	-- Update items
	if not isEpicTab then
		local visibleIdx = 0
		if type(farm.common) == "table" then
			for _, research in ipairs(farm.common) do
				local rTier = COMMON_RESEARCH_TIERS[research.researchId] or 1
				local matchesTab = (rTier == currentTier)
				if matchesTab then
					visibleIdx += 1
				end
				self:_updateResearchItem(research, visibleIdx, matchesTab)
			end
		end
	else
		-- Epic research view: hide common items and render/update epic cards
		if type(farm.common) == "table" then
			for _, research in ipairs(farm.common) do
				local item = self.shopResearch[research.researchId]
				if item and item.card then
					item.card.Visible = false
				end
			end
		end
	end
end

function HUD:_updateResearchItem(research, displayOrder, isTabVisible)
	local id = research.researchId
	local item = self.shopResearch[id]

	if item == nil then
		local orderIdx = displayOrder or 1
		local shouldBeVisible = if isTabVisible ~= nil then isTabVisible else (research.blockedReason ~= "UNSUPPORTED")
		local card = createGuiElement("Frame", {
			Name = "ResearchCard_" .. id,
			Visible = shouldBeVisible,
			Size = isRoblox and UDim2.new(1, 0, 0, 42) or nil,
			Position = isRoblox and UDim2.new(0, 0, 0, (orderIdx - 1) * 46) or nil,
			BackgroundColor3 = isRoblox and Color3.fromRGB(102, 56, 32) or nil,
		}, self.shopListContainer or self.shopFrame)
		addCornerAndStroke(card, 6, isRoblox and Color3.fromRGB(38, 18, 10) or nil, 1.8)

		local friendlyName = RESEARCH_DISPLAY_NAMES[id] or id
		local nameLabel = createGuiElement("TextLabel", {
			Name = "Title",
			Size = isRoblox and UDim2.new(0.46, 0, 1, 0) or nil,
			Position = isRoblox and UDim2.new(0.02, 0, 0, 0) or nil,
			BackgroundTransparency = 1,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = true,
			TextXAlignment = isRoblox and Enum.TextXAlignment.Left or nil,
			TextColor3 = isRoblox and Color3.fromRGB(255, 255, 255) or nil,
			Text = friendlyName,
		}, card)
		addTextStroke(nameLabel, 1.8)

		local levelLabel = createGuiElement("TextLabel", {
			Name = "Level",
			Size = isRoblox and UDim2.new(0.14, 0, 1, 0) or nil,
			Position = isRoblox and UDim2.new(0.49, 0, 0, 0) or nil,
			BackgroundTransparency = 1,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = true,
			TextColor3 = isRoblox and Color3.fromRGB(255, 235, 95) or nil,
			Text = "Lv 0",
		}, card)
		addTextStroke(levelLabel, 1.8)

		local priceLabel = createGuiElement("TextLabel", {
			Name = "Price",
			Size = isRoblox and UDim2.new(0.16, 0, 1, 0) or nil,
			Position = isRoblox and UDim2.new(0.64, 0, 0, 0) or nil,
			BackgroundTransparency = 1,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = true,
			TextColor3 = isRoblox and Color3.fromRGB(115, 255, 85) or nil,
			Text = "$0",
		}, card)
		addTextStroke(priceLabel, 1.8)

		local statusLabel = createGuiElement("TextLabel", {
			Name = "Status",
			Visible = false,
			Text = "BUY",
		}, card)

		local buyBtn = createGuiElement("TextButton", {
			Name = "BuyButton",
			Size = isRoblox and UDim2.new(0.17, 0, 0.78, 0) or nil,
			Position = isRoblox and UDim2.new(0.81, 0, 0.11, 0) or nil,
			BackgroundColor3 = isRoblox and Color3.fromRGB(95, 235, 45) or nil,
			Font = isRoblox and Enum.Font.FredokaOne or nil,
			TextScaled = true,
			TextColor3 = isRoblox and Color3.fromRGB(255, 255, 255) or nil,
			Text = "KUP",
		}, card)
		addCornerAndStroke(buyBtn, 6, isRoblox and Color3.fromRGB(22, 48, 12) or nil, 2)
		addTextStroke(buyBtn, 1.8)

		item = {
			id = id,
			card = card,
			nameLabel = nameLabel,
			levelLabel = levelLabel,
			priceLabel = priceLabel,
			statusLabel = statusLabel,
			buyButton = buyBtn,
			available = true,
			blockedReason = nil,
			quote = nil,
		}

		if buyBtn.Activated ~= nil then
			buyBtn.Activated:Connect(function()
				self:buyResearch(id)
			end)
		end

		self.shopResearch[id] = item
	end

	if isTabVisible ~= nil then
		item.card.Visible = isTabVisible
		if isTabVisible and displayOrder then
			item.card.Position = isRoblox and UDim2.new(0, 0, 0, (displayOrder - 1) * 46) or nil
		end
	end

	item.level = research.level
	item.levelLabel.Text = "Lv " .. tostring(research.level)

	local quote = nil
	if self.intentControllers and self.intentControllers.shop then
		quote = self.intentControllers.shop:getCachedQuote({
			kind = "BuyResearch",
			args = { researchId = id, mode = "single" },
		})
	end
	item.quote = quote

	if quote ~= nil and quote.cashCost ~= nil then
		item.priceLabel.Text = HUD.formatCash(quote.cashCost)
	end

	local available = research.available
	local blockedReason = research.blockedReason

	if quote ~= nil then
		if not quote.available then
			available = false
			blockedReason = quote.blockedReason or blockedReason
		end
	end

	item.available = available
	item.blockedReason = blockedReason

	if available then
		item.buyButton.Active = true
		item.statusLabel.Text = "BUY"
		item.buyButton.Text = "KUP"
		if isRoblox then
			item.buyButton.BackgroundColor3 = Color3.fromRGB(95, 235, 45)
		end
	else
		item.buyButton.Active = false
		local reasonText = blockedReason or "LOCKED"
		item.statusLabel.Text = reasonText
		item.buyButton.Text = reasonText
		if isRoblox then
			item.buyButton.BackgroundColor3 = Color3.fromRGB(130, 115, 105)
		end
	end
end

function HUD:_updateEggUpgradeModal(farm)
	if not self.eggUpgradeModal or not farm then return end

	local curEggIdx = farm.eggIndex or 0
	local nextEggIdx = curEggIdx + 1
	local curEgg = EGGS_DATA[curEggIdx] or EGGS_DATA[0]
	local nextEgg = EGGS_DATA[nextEggIdx]

	local approxFv = calculateClientFarmValue(farm)
	if self.eggUpgradeCurrentLabel then
		self.eggUpgradeCurrentLabel.Text = string.format("🥚 Aktualne Jajo: %s ($%s)", curEgg.name, formatCompact(curEgg.eggValueBase))
	end

	if nextEgg then
		local reqFv = nextEgg.advanceFV
		local mult = nextEgg.eggValueBase / curEgg.eggValueBase
		if self.eggUpgradeNextLabel then
			self.eggUpgradeNextLabel.Text = string.format("✨ Następne Jajo: %s ($%s)", nextEgg.name, formatCompact(nextEgg.eggValueBase))
		end
		if self.eggUpgradeMultLabel then
			self.eggUpgradeMultLabel.Text = string.format("📈 Mnożnik Wartości: %.1fx", mult)
		end
		if self.eggUpgradeCurrentFvLabel then
			self.eggUpgradeCurrentFvLabel.Text = string.format("💰 Twoje Farm Value: $%s", formatCompact(approxFv))
		end
		if self.eggUpgradeReqFvLabel then
			self.eggUpgradeReqFvLabel.Text = string.format("🎯 Wymagane Farm Value: $%s", formatCompact(reqFv))
		end

		if self.eggUpgradeBtn then
			if approxFv >= reqFv then
				self.eggUpgradeBtn.Text = "AWANSUJ NASTĘPNE JAJO (" .. string.upper(nextEgg.name) .. ")"
				if isRoblox then self.eggUpgradeBtn.BackgroundColor3 = Color3.fromRGB(95, 235, 55) end
			else
				self.eggUpgradeBtn.Text = "WYMAGANE WIĘKSZE FARM VALUE"
				if isRoblox then self.eggUpgradeBtn.BackgroundColor3 = Color3.fromRGB(140, 140, 140) end
			end
		end
	else
		if self.eggUpgradeNextLabel then self.eggUpgradeNextLabel.Text = "🎉 Osiągnięto Oświecenie (MAX)!" end
		if self.eggUpgradeMultLabel then self.eggUpgradeMultLabel.Text = "Maksymalny gatunek osiągnięty" end
		if self.eggUpgradeReqFvLabel then self.eggUpgradeReqFvLabel.Text = "Brak dalszych poziomów" end
		if self.eggUpgradeBtn then
			self.eggUpgradeBtn.Text = "MAKSYMALNE JAJO"
			if isRoblox then self.eggUpgradeBtn.BackgroundColor3 = Color3.fromRGB(140, 140, 140) end
		end
	end
end

function HUD:onQuoteReceived(quoteView)
	if type(quoteView) ~= "table" or quoteView.kind ~= "QuoteView" then
		return
	end
	local target = quoteView.target
	if target and target.kind == "BuyResearch" and target.args and target.args.researchId then
		local item = self.shopResearch[target.args.researchId]
		if item ~= nil then
			item.quote = quoteView
			if quoteView.cashCost ~= nil then
				item.priceLabel.Text = HUD.formatCash(quoteView.cashCost)
			end
			if not quoteView.available then
				item.available = false
				item.blockedReason = quoteView.blockedReason
				item.buyButton.Active = false
				item.statusLabel.Text = quoteView.blockedReason or "LOCKED"
				item.buyButton.Text = quoteView.blockedReason or "LOCKED"
			end
		end
	end
end

-- ============================================================================
-- Intent Actions
-- ============================================================================

function HUD:pressHatch(callback)
	if self.intentControllers and self.intentControllers.hatch then
		return self.intentControllers.hatch:press(callback)
	end
	return nil
end

function HUD:startHoldHatch(callback)
	if self.intentControllers and self.intentControllers.hatch then
		return self.intentControllers.hatch:holdStart(callback)
	end
	return nil
end

function HUD:refreshHoldHatch(callback)
	if self.intentControllers and self.intentControllers.hatch then
		return self.intentControllers.hatch:holdRefresh(callback)
	end
	return nil
end

function HUD:stopHoldHatch(callback)
	if self.intentControllers and self.intentControllers.hatch then
		return self.intentControllers.hatch:holdStop(callback)
	end
	return nil
end

function HUD:buyResearch(researchId, callback)
	if not self.intentControllers or not self.intentControllers.shop then
		return false, "NO_SHOP_CONTROLLER"
	end

	local target = {
		kind = "BuyResearch",
		args = { researchId = researchId, mode = "single" },
	}

	local currentRevision = if self.stateStore then self.stateStore:getCommitRevision() else nil
	local quote = self.intentControllers.shop:getCachedQuote(target)
	if quote ~= nil and quote.available and (currentRevision == nil or quote.expectedRevision == currentRevision) then
		return self.intentControllers.shop:confirmPurchase(quote, callback)
	else
		return self.intentControllers.shop:requestQuote(target, function(newQuote)
			if newQuote and newQuote.kind == "QuoteView" and newQuote.available then
				self.intentControllers.shop:confirmPurchase(newQuote, callback)
			elseif callback then
				callback({ status = "REJECTED", errorCode = "NO_QUOTE" })
			end
		end)
	end
end

-- ============================================================================
-- Accessors for Verification & Tests
-- ============================================================================

function HUD:getSessionStatus() return self.sessionStatus end
function HUD:getCashText() return if self.cashLabel then self.cashLabel.Text else "" end
function HUD:getProducedEggsText() return if self.producedEggsLabel then self.producedEggsLabel.Text else "" end
function HUD:getSoldEggsText() return if self.soldEggsLabel then self.soldEggsLabel.Text else "" end
function HUD:getShippingText() return if self.shippingLabel then self.shippingLabel.Text else "" end
function HUD:getHatcheryText() return if self.hatcheryStockLabel then self.hatcheryStockLabel.Text else "" end
function HUD:getHatcheryRatio() return self.hatcheryRatio end
function HUD:getHatcheryRefillText() return if self.hatcheryRefillLabel then self.hatcheryRefillLabel.Text else "" end
function HUD:getHabitatText(slotId)
	local label = self.habitatLabels[slotId]
	return if label then label.Text else ""
end
function HUD:getHabitatRatio(slotId) return self.habitatFillRatios[slotId] or 0 end
function HUD:getShopResearchItem(researchId) return self.shopResearch[researchId] end

function HUD:getHabitatsModal() return self.habitatsModal end
function HUD:getVehiclesModal() return self.vehiclesModal end
function HUD:getResearchModal() return self.shopFrame end
function HUD:getPetsModal() return self.petsModal end
function HUD:getShopModal() return self.shopModal end
function HUD:getCalendarModal() return self.calendarModal end
function HUD:getEggUpgradeModal() return self.eggUpgradeModal end

function HUD:getShippingComparisonStatus()
	local badge = self.shippingComparisonBar and self.shippingComparisonBar:FindFirstChild("StatusBadge")
	return if badge then badge.Text else ""
end

function HUD:getCurrentResearchTier() return self.selectedResearchTier end
function HUD:getCurrentShopTab() return self.selectedShopTab end
function HUD:getCurrentCalendarTab() return self.selectedCalendarTab end

function HUD:destroy()
	for _, unsub in ipairs(self._unsubs) do
		unsub()
	end
	self._unsubs = {}
	if self.guiRoot ~= nil and type(self.guiRoot.Destroy) == "function" then
		self.guiRoot:Destroy()
	end
end

return table.freeze(HUD)
