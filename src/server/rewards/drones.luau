--!strict
-- drones.luau: authoritative server domain logic for drone spawning, hit qualification, and single reward claims.
-- Spec: docs/06; docs/13 §2; docs/16 §1; docs/27 §3.3, §4; NEXT-06 (#31).

local isStudio = (typeof(script) == "Instance")
local function resolve(studioGetter, lunePath)
	if isStudio then
		local ok, mod = pcall(studioGetter)
		if ok and mod then
			return if typeof(mod) == "Instance" then require(mod) else mod
		end
	end
	return require(lunePath)
end

local Codec = resolve(function()
	return game:GetService("ReplicatedStorage").HatchTheEgg.Shared.NumericCodec
end, "../../shared/NumericCodec")
local Equipment = resolve(function()
	return script.Parent.Parent.pets.equipment
end, "../pets/equipment")

local BigAmount = Codec.BigAmount
local ExactUInt = Codec.ExactUInt

local Drones = {
	VERSION = 1,
}

export type DroneReward = {
	type: "GE" | "Cash",
	amount: number,
	formattedAmount: string?,
}

export type DroneSpawn = {
	spawnId: string,
	createdAtMs: number,
	expiresAtMs: number,
	isElite: boolean,
	claimed: boolean,
	reward: DroneReward?,
}

export type DroneConfig = {
	flightDurationMs: number?,
	droneGoldGuaranteed: boolean?,
	droneCashGuaranteed: boolean?,
	droneCashChanceMult: number?,
	droneGoldChanceMult: number?,
	droneRewardMult: number?,
	onscreenChickenMultiplier: number?,
	epicDroneRewardsLvl: number?,
	pBaseOverride: number?,
}

-- Calculates struggleModifier based on Farm Value, population, and price curve 0 reference value.
-- Exception: population <= 100 returns double(float32(0.1)) which is exactly 0.10000000149011612 (docs/06, drone_and_silo_rules.json).
local function calculateStruggleModifier(farmValue: number, population: number, curve0FarmValue: number): number
	if population <= 100 then
		return 0.10000000149011612
	end

	local ratio = if curve0FarmValue > 0 then (100.0 * farmValue / curve0FarmValue) else 0.0

	if ratio < 3.0 then
		return 30.0
	elseif ratio < 15.0 then
		return 15.0
	elseif ratio < 30.0 then
		return 8.0
	elseif ratio < 100.0 then
		return 5.0
	elseif ratio < 200.0 then
		return 2.0
	elseif ratio < 1000.0 then
		return 1.0
	elseif ratio < 50000.0 then
		return 0.75
	elseif ratio < 1000000.0 then
		return 0.5
	else
		return 0.25
	end
end

-- Calculates elite drone probability given profile progression and pet multiplier.
local function calculateEliteChance(profile: any?, petEliteMult: number?, config: DroneConfig?): number
	local pBase = 0.08

	if profile then
		local prestigeCount = if profile.permanent then (profile.permanent.prestigeCount or "0") else "0"
		local maxEggReached = if profile.farm then (profile.farm.maxEggReached or 0) else 0

		if prestigeCount == "0" and maxEggReached <= 4 then
			pBase = 0.005 * maxEggReached
		end
	end

	if config and config.pBaseOverride ~= nil then
		pBase = config.pBaseOverride
	end

	local eliteMult = petEliteMult or 1.0
	return Equipment.calculateDroneEliteChance(pBase, eliteMult)
end

-- Authoritatively spawns a drone on the server.
local function createDroneSpawn(
	spawnId: string,
	nowMs: number,
	config: DroneConfig?,
	profile: any?,
	petEliteMult: number?,
	rollElite: number?
): DroneSpawn
	assert(type(spawnId) == "string" and #spawnId > 0, "Drones/INVALID_SPAWN_ID")
	assert(type(nowMs) == "number" and nowMs >= 0, "Drones/INVALID_NOW_MS")

	local pElite = calculateEliteChance(profile, petEliteMult, config)
	local roll = if rollElite ~= nil then rollElite else math.random()
	local isElite = (roll < pElite)

	local flightDurationMs = (config and config.flightDurationMs) or 15000
	local expiresAtMs = nowMs + flightDurationMs

	return {
		spawnId = spawnId,
		createdAtMs = nowMs,
		expiresAtMs = expiresAtMs,
		isElite = isElite,
		claimed = false,
		reward = nil,
	}
end

-- Claims a drone hit and applies rewards authoritatively to the profile.
local function claimDrone(
	spawnOrState: any,
	arg2: any,
	arg3: any?,
	arg4: any?,
	arg5: any?,
	arg6: any?,
	arg7: any?
): (boolean, any)
	-- Support both signatures:
	-- (spawn, nowMs, profile, config, rolls, farmValue, curve0FarmValue)
	-- and (spawnsState, spawnId, nowMs, profile, config, rolls, farmValue, curve0FarmValue)
	local spawn: DroneSpawn
	local nowMs: number
	local profile: any
	local config: DroneConfig?
	local rolls: any?
	local farmValue: number
	local curve0FarmValue: number

	if type(spawnOrState) == "table" and spawnOrState.spawnId ~= nil and spawnOrState.expiresAtMs ~= nil then
		spawn = spawnOrState
		nowMs = arg2
		profile = arg3
		config = arg4
		rolls = arg5
		farmValue = arg6 or 0.0
		curve0FarmValue = arg7 or 1.0
	elseif type(spawnOrState) == "table" and type(arg2) == "string" then
		spawn = spawnOrState[arg2]
		nowMs = arg3
		profile = arg4
		config = arg5
		rolls = arg6
		farmValue = arg7 or 0.0
		curve0FarmValue = 1.0
	else
		return false, "UNKNOWN_SPAWN"
	end

	if not spawn then
		return false, "UNKNOWN_SPAWN"
	end
	if spawn.claimed == true then
		return false, "ALREADY_CLAIMED"
	end
	if nowMs > spawn.expiresAtMs then
		return false, "SPAWN_EXPIRED"
	end
	if type(profile) ~= "table" then
		return false, "INVALID_PROFILE"
	end

	-- 1. Reward Type Determination (docs/06 §2)
	local isGE = false
	if config and config.droneGoldGuaranteed == true then
		isGE = true
	elseif config and config.droneCashGuaranteed == true then
		isGE = false
	else
		local u1 = if rolls and rolls.u1 ~= nil then rolls.u1 else math.random()
		local goldMult = (config and config.droneGoldChanceMult) or 1.0
		local cashMult = (config and config.droneCashChanceMult) or 1.0
		local ratio = if goldMult > 0 then (cashMult / goldMult) else 1.0
		isGE = (u1 * ratio <= 0.3)
	end

	local u2 = if rolls and rolls.u2 ~= nil then rolls.u2 else math.random()
	local epicDroneLvl = (config and config.epicDroneRewardsLvl)
		or (profile.permanent and profile.permanent.epic and profile.permanent.epic.drone_rewards)
		or 0
	local q = 1.0 + 0.1 * epicDroneLvl
	local droneRewardMult = (config and config.droneRewardMult) or 1.0

	if isGE then
		-- 2. Golden Egg Reward Calculation (docs/06 §3)
		local baseGE = 3
		if q > 1.5 and u2 < 0.01 then
			baseGE = 24
		elseif u2 < 0.1 * q then
			baseGE = 12
		elseif u2 < 0.7 * q then
			baseGE = 6
		else
			baseGE = 3
		end

		if spawn.isElite then
			baseGE = math.max(48, 8 * baseGE)
		end

		-- Threshold check: totalGESpent >= 152,500
		local totalSpentU = ExactUInt.decode(profile.permanent.totalGESpent or "0")
		local thresholdU = ExactUInt.fromSafeNumber(152500)
		local isSpentMet = ExactUInt.compare(totalSpentU, thresholdU) >= 0

		local calculatedGE = baseGE
		if isSpentMet then
			if spawn.isElite then
				calculatedGE = 2 * baseGE
			else
				calculatedGE = math.max(24, 2 * baseGE)
			end
		end

		local finalGE = math.floor(calculatedGE * droneRewardMult + 0.5)

		-- Apply GE to profile
		local currentGE_U = ExactUInt.decode(profile.permanent.GE or "0")
		local rewardGE_U = ExactUInt.fromSafeNumber(finalGE)
		profile.permanent.GE = ExactUInt.encode(ExactUInt.add(currentGE_U, rewardGE_U))

		spawn.claimed = true
		local reward: DroneReward = {
			type = "GE",
			amount = finalGE,
			formattedAmount = tostring(finalGE) .. " GE",
		}
		spawn.reward = reward
		return true, reward
	else
		-- 3. Cash Reward Calculation (docs/06 §4)
		local b = 0.02
		if u2 < 0.03 * q then
			b = 0.5
		elseif u2 < 0.1 * q then
			b = 0.1
		else
			b = 0.02
		end

		-- Compute total settled population for struggle calculation
		local population = 0
		if profile.farm and profile.farm.habitats then
			for _, h in profile.farm.habitats do
				if h.population then
					population += ExactUInt.toSafeNumber(ExactUInt.decode(h.population))
				end
			end
		end

		local struggle = calculateStruggleModifier(farmValue, population, curve0FarmValue)
		local chickenMult = (config and config.onscreenChickenMultiplier) or 1.0
		local chickenFactor = math.sqrt(chickenMult)

		local finalCash = 0.0
		if spawn.isElite then
			local eliteStruggle = math.min(struggle, 10.0)
			finalCash = farmValue * (10.0 / 50.0) * eliteStruggle * droneRewardMult * chickenFactor
		else
			finalCash = farmValue * (b / 50.0) * struggle * droneRewardMult * chickenFactor
		end

		-- Apply Cash to profile
		local currentCash = BigAmount.decode(profile.farm.cash or "0")
		local newCash = BigAmount.add(currentCash, finalCash)
		profile.farm.cash = BigAmount.encode(newCash)

		if profile.accounting then
			local currentEarned = BigAmount.decode(profile.accounting.lastCashEarned or "0")
			profile.accounting.lastCashEarned = BigAmount.encode(BigAmount.add(currentEarned, finalCash))
		end

		spawn.claimed = true
		local reward: DroneReward = {
			type = "Cash",
			amount = finalCash,
			formattedAmount = BigAmount.encode(finalCash),
		}
		spawn.reward = reward
		return true, reward
	end
end

Drones.calculateStruggleModifier = calculateStruggleModifier
Drones.calculateEliteChance = calculateEliteChance
Drones.createDroneSpawn = createDroneSpawn
Drones.claimDrone = claimDrone

return table.freeze(Drones)
