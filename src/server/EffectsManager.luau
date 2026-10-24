--!strict
-- EffectsManager: authoritative server domain logic for Video Doubler, boosts, decay, and live events.
-- Spec: docs/11 §2, §4; docs/12 §2; docs/27 §3; NEXT-03 (#28).

local EffectsManager = {
	VERSION = 1,
}

export type BoostCatalogItem = {
	id: string,
	dimension_raw: number,
	durationSeconds: number,
	effect: number,
}

export type ActiveBoost = {
	id: string,
	dimension_raw: number?,
	effect: number?,
	multiplier: number?,
	remainingSeconds: number,
	activatedAtMs: number?,
}

export type LiveEvent = {
	id: string,
	type: string,
	multiplier: number,
	startTimeMs: number,
	deadlineMs: number?,
	durationSeconds: number?,
}

-- Embedded reference catalog of boosts (docs/reference_data/boosts.json)
local BOOST_CATALOG: { [string]: BoostCatalogItem } = table.freeze({
	-- Dimension 2: Jimbo Bird Feed (earnings)
	jimbos_blue_v2 = table.freeze({ id = "jimbos_blue_v2", dimension_raw = 2, durationSeconds = 1200.0, effect = 3.0 }),
	jimbos_purple_v2 = table.freeze({ id = "jimbos_purple_v2", dimension_raw = 2, durationSeconds = 900.0, effect = 10.0 }),
	jimbos_purple_big = table.freeze({ id = "jimbos_purple_big", dimension_raw = 2, durationSeconds = 10800.0, effect = 10.0 }),
	jimbos_orange = table.freeze({ id = "jimbos_orange", dimension_raw = 2, durationSeconds = 600.0, effect = 50.0 }),
	jimbos_orange_big = table.freeze({ id = "jimbos_orange_big", dimension_raw = 2, durationSeconds = 7200.0, effect = 50.0 }),

	-- Dimension 4: Tachyon Prism (IHR)
	tachyon_prism_blue_v2 = table.freeze({ id = "tachyon_prism_blue_v2", dimension_raw = 4, durationSeconds = 600.0, effect = 10.0 }),
	tachyon_prism_blue_big = table.freeze({ id = "tachyon_prism_blue_big", dimension_raw = 4, durationSeconds = 14400.0, effect = 10.0 }),
	tachyon_prism_purple_v2 = table.freeze({ id = "tachyon_prism_purple_v2", dimension_raw = 4, durationSeconds = 600.0, effect = 100.0 }),
	tachyon_prism_purple_big = table.freeze({ id = "tachyon_prism_purple_big", dimension_raw = 4, durationSeconds = 7200.0, effect = 100.0 }),
	tachyon_prism_orange = table.freeze({ id = "tachyon_prism_orange", dimension_raw = 4, durationSeconds = 600.0, effect = 1000.0 }),
	tachyon_prism_orange_big = table.freeze({ id = "tachyon_prism_orange_big", dimension_raw = 4, durationSeconds = 3600.0, effect = 1000.0 }),

	-- Dimension 7: Boost Beacon (multiplier for other boosts)
	boost_beacon_blue = table.freeze({ id = "boost_beacon_blue", dimension_raw = 7, durationSeconds = 1800.0, effect = 2.0 }),
	boost_beacon_purple = table.freeze({ id = "boost_beacon_purple", dimension_raw = 7, durationSeconds = 600.0, effect = 10.0 }),
	boost_beacon_blue_big = table.freeze({ id = "boost_beacon_blue_big", dimension_raw = 7, durationSeconds = 3600.0, effect = 5.0 }),
	boost_beacon_orange = table.freeze({ id = "boost_beacon_orange", dimension_raw = 7, durationSeconds = 600.0, effect = 50.0 }),

	-- Dimension 9: Soul Beacon (prestige earnings)
	soul_beacon_blue_v2 = table.freeze({ id = "soul_beacon_blue_v2", dimension_raw = 9, durationSeconds = 1800.0, effect = 5.0 }),
	soul_beacon_purple_v2 = table.freeze({ id = "soul_beacon_purple_v2", dimension_raw = 9, durationSeconds = 1200.0, effect = 50.0 }),
	soul_beacon_orange = table.freeze({ id = "soul_beacon_orange", dimension_raw = 9, durationSeconds = 600.0, effect = 500.0 }),

	-- Dimension 10: Instant cash
	subsidy_application = table.freeze({ id = "subsidy_application", dimension_raw = 10, durationSeconds = 0.0, effect = 0.1 }),
	blank_check = table.freeze({ id = "blank_check", dimension_raw = 10, durationSeconds = 0.0, effect = 1.0 }),
	money_printer = table.freeze({ id = "money_printer", dimension_raw = 10, durationSeconds = 0.0, effect = 5.0 }),
})

-- Checks whether a live event is active in the current timestamp (docs/11 §2).
local function isEventActive(event: any, nowMs: number): boolean
	if type(event) ~= "table" or type(nowMs) ~= "number" then
		return false
	end
	local start = event.startTimeMs or 0
	local deadline = event.deadlineMs or (start + (event.durationSeconds or 0) * 1000)
	return nowMs >= start and nowMs < deadline
end

-- Calculates effective multipliers for earnings, IHR, and prestige at the specified simulation instant.
local function calculateMultipliers(
	effects: any?,
	farm: any?,
	nowMs: number,
	liveEvents: { [any]: any }?,
	options: any?
): { [string]: any }
	-- 1. Video Doubler (docs/12 §2, docs/27 §3)
	-- Strict inequality in continuous binary64 without floor to ms.
	local vdEndsAtMs = if effects
		then (effects.videoDoublerEndsAtMs or (effects.videoDoubler and effects.videoDoubler.endsAtMs) or 0)
		else 0
	local isVDActive = (nowMs < vdEndsAtMs)
	local vdMult = if isVDActive then 2.0 else 1.0

	-- 2. Farm Enlightenment check (docs/11 §4, docs/27 §3.1)
	-- On Enlightenment (eggIndex == 18), boosts are paused.
	local eggIndex = if farm then (farm.eggIndex or 0) else 0
	local boostsEnabled = (eggIndex ~= 18)

	local effectiveEarningsBoost = 1.0
	local effectiveIHRBoost = 1.0
	local effectivePrestigeBoost = 1.0
	local beaconFactor = 1.0

	if boostsEnabled and effects and effects.boosts then
		local jimboSum = 0
		local tachyonSum = 0
		local soulBeaconSum = 0
		local beaconSum = 0

		for _, b in effects.boosts do
			if type(b) == "table" and (b.remainingSeconds == nil or b.remainingSeconds >= 0) then
				local def = BOOST_CATALOG[b.id]
				local dim = b.dimension_raw or (def and def.dimension_raw)
				local val = b.effect or b.multiplier or (def and def.effect) or 1.0

				if dim == 2 then
					jimboSum += val
				elseif dim == 4 then
					tachyonSum += val
				elseif dim == 9 then
					soulBeaconSum += val
				elseif dim == 7 then
					beaconSum += val
				end
			end
		end

		beaconFactor = if beaconSum > 0 then beaconSum else 1.0
		effectiveEarningsBoost = if jimboSum > 1.0 then jimboSum * beaconFactor else 1.0
		effectiveIHRBoost = if tachyonSum > 1.0 then tachyonSum * beaconFactor else 1.0
		effectivePrestigeBoost = if soulBeaconSum > 1.0 then soulBeaconSum * beaconFactor else 1.0
	end

	-- 3. Live Events (docs/11 §2)
	local eventEarningsMult = 1.0
	local eventIHRMult = 1.0
	local eventPrestigeMult = 1.0

	if liveEvents then
		for _, ev in liveEvents do
			if isEventActive(ev, nowMs) then
				local mult = ev.multiplier or 1.0
				if ev.type == "earnings-boost" or ev.type == "earnings" then
					eventEarningsMult *= mult
				elseif ev.type == "ihr-boost" or ev.type == "ihr" then
					eventIHRMult *= mult
				elseif ev.type == "prestige-boost" or ev.type == "prestige" then
					eventPrestigeMult *= mult
				end
			end
		end
	end

	-- 4. Multiplier composition
	local earningsMultiplier = effectiveEarningsBoost * vdMult * eventEarningsMult
	local ihrMultiplier = effectiveIHRBoost * eventIHRMult
	local prestigeMultiplier = effectivePrestigeBoost * eventPrestigeMult

	return {
		earningsMultiplier = earningsMultiplier,
		ihrMultiplier = ihrMultiplier,
		prestigeMultiplier = prestigeMultiplier,
		boostsEnabled = boostsEnabled,
		videoDoublerActive = isVDActive,
		effectiveEarningsBoost = effectiveEarningsBoost,
		effectiveIHRBoost = effectiveIHRBoost,
		effectivePrestigeBoost = effectivePrestigeBoost,
		beaconFactor = beaconFactor,
		vdMultiplier = vdMult,
		eventEarningsMult = eventEarningsMult,
		eventIHRMult = eventIHRMult,
		eventPrestigeMult = eventPrestigeMult,
	}
end

-- Decrements remaining duration for active boosts.
-- Preserves entries when remainingSeconds == 0; removes strictly when remainingSeconds < 0.
-- On Enlightenment (eggIndex == 18), time does not decay.
local function stepDecay(effects: any?, farm: any?, dt: number): any?
	if not effects or not effects.boosts then
		return effects
	end

	local eggIndex = if farm then (farm.eggIndex or 0) else 0
	if eggIndex == 18 then
		return effects
	end

	local boosts = effects.boosts
	local i = 1
	while i <= #boosts do
		local b = boosts[i]
		if b and type(b.remainingSeconds) == "number" then
			b.remainingSeconds = b.remainingSeconds - dt
			if b.remainingSeconds < 0 then
				table.remove(boosts, i)
			else
				i += 1
			end
		else
			i += 1
		end
	end

	return effects
end

-- Activates or renews Video Doubler (docs/12 §2, docs/27 §3).
-- Allowed only when remaining time < 7200s (2h). Overwrites deadline to nowMs + durationMs.
local function activateVideoDoubler(effects: any, nowMs: number, epicDurationLevel: number?): (boolean, any)
	assert(type(effects) == "table", "EffectsManager/INVALID_EFFECTS")
	assert(type(nowMs) == "number" and nowMs >= 0, "EffectsManager/INVALID_NOW_MS")

	local currentEndsAtMs = effects.videoDoublerEndsAtMs
		or (effects.videoDoubler and effects.videoDoubler.endsAtMs)
		or 0

	local remainingSeconds = math.max(0, (currentEndsAtMs - nowMs) / 1000)
	if remainingSeconds >= 7200 then
		return false, "CANNOT_RENEW"
	end

	local epicLvl = epicDurationLevel or 0
	local durationSeconds = (2 + 0.5 * epicLvl) * 3600
	local newEndsAtMs = nowMs + durationSeconds * 1000

	effects.videoDoublerEndsAtMs = newEndsAtMs
	if effects.videoDoubler and type(effects.videoDoubler) == "table" then
		effects.videoDoubler.endsAtMs = newEndsAtMs
	end

	return true, newEndsAtMs
end

-- Activates a boost from inventory into effects.boosts (docs/11 §4).
-- Slot limit: 2 standard, 5 Pro permit.
local function activateBoost(
	effects: any,
	inventory: any,
	boostId: string,
	catalog: any?,
	nowMs: number,
	durationMult: number?,
	permitLevel: number?
): (boolean, any)
	assert(type(effects) == "table", "EffectsManager/INVALID_EFFECTS")
	assert(type(inventory) == "table", "EffectsManager/INVALID_INVENTORY")
	assert(type(boostId) == "string", "EffectsManager/INVALID_BOOST_ID")

	effects.boosts = effects.boosts or {}
	local maxSlots = if (permitLevel or 0) >= 1 then 5 else 2
	if #effects.boosts >= maxSlots then
		return false, "MAX_ACTIVE_BOOSTS"
	end

	inventory.boosts = inventory.boosts or {}
	local available = inventory.boosts[boostId] or 0
	if available < 1 then
		return false, "INSUFFICIENT_INVENTORY"
	end

	local def = (catalog and (catalog[boostId] or (catalog.getBoost and catalog.getBoost(boostId))))
		or BOOST_CATALOG[boostId]
	if not def then
		return false, "UNKNOWN_BOOST"
	end

	inventory.boosts[boostId] = available - 1

	local durMult = durationMult or 1.0
	local durationSeconds = def.durationSeconds * durMult

	local entry: ActiveBoost = {
		id = boostId,
		dimension_raw = def.dimension_raw,
		effect = def.effect or 1.0,
		remainingSeconds = durationSeconds,
		activatedAtMs = nowMs,
	}

	table.insert(effects.boosts, entry)
	return true, entry
end

EffectsManager.BOOST_CATALOG = BOOST_CATALOG
EffectsManager.isEventActive = isEventActive
EffectsManager.calculateMultipliers = calculateMultipliers
EffectsManager.stepDecay = stepDecay
EffectsManager.activateVideoDoubler = activateVideoDoubler
EffectsManager.activateBoost = activateBoost

return table.freeze(EffectsManager)
