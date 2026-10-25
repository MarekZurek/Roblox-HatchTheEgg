--!strict
-- Authoritative server logic for 28-day daily calendar scaling, UTC day pacing, and PE/Epic conversions.
-- Spec: docs/15 §2, §3; docs/13 §2; docs/27 §3.3, §4; Issue #33 (NEXT-08).

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
local ExactUInt = Codec.ExactUInt
local BigAmount = Codec.BigAmount
local Reference = resolve(function() return script.Parent.Parent.ActionReferenceData end, "../ActionReferenceData")

local Calendar = {
	VERSION = 1,
	DAYS_PER_CYCLE = 28,
	MAX_PE_CYCLES = 24, -- cycles 0..23 award 1 PE (24 total), cycle >= 24 awards 100k GE
}

export type CalendarRewardType = "GE" | "PE" | "SE" | "Cash" | "CashPercent" | "ShellScripts" | "Piggy" | "PiggyLevel" | "Boost" | "Epic"

export type CalendarReward = {
	rewardType: CalendarRewardType,
	amount: string,
	amountNumber: number,
	researchId: string?,
	boostId: string?,
	day: number,
	cycle: number,
}

local DEFAULT_EPIC_PRICES = Reference.epic

local function getCycleAndDay(numCollected: number): (number, number)
	local count = math.max(0, math.floor(numCollected))
	local m = math.floor(count / Calendar.DAYS_PER_CYCLE)
	local day = (count % Calendar.DAYS_PER_CYCLE) + 1
	return m, day
end

-- Scaling formula for 5 variable items + day 28 conversion (docs/15 §2, §3)
local function computeDayReward(m: number, day: number, customRewards: any?): CalendarReward
	if customRewards and customRewards[day] then
		local def = customRewards[day]
		return {
			rewardType = def.rewardType,
			amount = def.amount or tostring(def.amountNumber or 1),
			amountNumber = def.amountNumber or 1,
			researchId = def.researchId,
			boostId = def.boostId,
			day = day,
			cycle = m,
		}
	end

    return Calendar.referenceReward(m*28+day-1,Reference.calendar)
end

-- Convert/apply Epic Research reward with excess -> GE conversion (docs/13 §2 L10-15)
local function applyEpicResearchReward(
	profile: any,
	researchId: string,
	levels: number?,
	customPrices: any?
): (boolean, number, number)
	assert(profile ~= nil and profile.permanent ~= nil, "Calendar/INVALID_PROFILE")
	profile.permanent.epic = profile.permanent.epic or {}

	local prices = customPrices or DEFAULT_EPIC_PRICES
	local spec = prices[researchId] or { maxLevel = 20, finalLevelPriceGE = 500 }
	local currentLvl = profile.permanent.epic[researchId] or 0
	local addLevels = math.max(1, math.floor(levels or 1))

	local newLvl = currentLvl
	local convertedGE = 0

	for _ = 1, addLevels do
		if newLvl < spec.maxLevel then
			newLvl += 1
		else
			convertedGE += spec.finalLevelPriceGE
		end
	end

	profile.permanent.epic[researchId] = newLvl

	if convertedGE > 0 then
		local curGE = ExactUInt.decode(profile.permanent.GE)
		local addExact = ExactUInt.fromSafeNumber(convertedGE)
		profile.permanent.GE = ExactUInt.encode(ExactUInt.add(curGE, addExact))
	end

	return true, newLvl, convertedGE
end

local function getUtcDayKey(nowMs: number): number
	return math.floor(nowMs / 86400000)
end

local function canClaimCalendarDay(profile: any, nowMs: number): boolean
	if not profile then
		return true
	end
	local currentUtcDay = getUtcDayKey(nowMs)
	local lastDay = (profile.rewards and profile.rewards.lastCalendarDayUtc) or -1
	return currentUtcDay > lastDay
end

-- Claim daily calendar gift with atomic UTC day verification and profile accounting.
local function claimDailyGift(
	profile: any,
	nowMs: number,
	customRewards: any?,
	customPrices: any?,
    prestigeEarningsMultiplier: number?
): (boolean, CalendarReward?, string?)
	assert(profile ~= nil, "Calendar/INVALID_PROFILE")
	local currentUtcDay = getUtcDayKey(nowMs)
	profile.rewards = profile.rewards or {}

	local lastDay = profile.rewards.lastCalendarDayUtc or -1
	if currentUtcDay <= lastDay then
		return false, nil, "ALREADY_CLAIMED_TODAY"
	end

	local numCollected = profile.rewards.numDailyGiftsCollected or 0
	local m, day = getCycleAndDay(numCollected)
	local reward = computeDayReward(m, day, customRewards)
    if not reward or reward.rewardType=="CashPercent" then return false,nil,"CALENDAR_CONTEXT_REQUIRED" end

	-- Increment counter BEFORE distribution (docs/13 §2 L53)
	profile.rewards.numDailyGiftsCollected = numCollected + 1
	profile.rewards.lastCalendarDayUtc = currentUtcDay

	-- Distribute reward to authoritative profile
	if reward.rewardType == "GE" then
		assert(profile.permanent ~= nil, "Calendar/INVALID_PERMANENT")
		local curGE = ExactUInt.decode(profile.permanent.GE)
		local addGE = ExactUInt.fromSafeNumber(reward.amountNumber)
		profile.permanent.GE = ExactUInt.encode(ExactUInt.add(curGE, addGE))
	elseif reward.rewardType == "PE" then
		assert(profile.permanent ~= nil, "Calendar/INVALID_PERMANENT")
		local curPE = ExactUInt.decode(profile.permanent.PE or "0")
		local addPE = ExactUInt.fromSafeNumber(reward.amountNumber)
		profile.permanent.PE = ExactUInt.encode(ExactUInt.add(curPE, addPE))
	elseif reward.rewardType == "SE" then
		assert(profile.permanent ~= nil, "Calendar/INVALID_PERMANENT")
		local curSE = BigAmount.decode(profile.permanent.SE)
		local addSE = reward.amountNumber
		profile.permanent.SE = BigAmount.encode(BigAmount.add(curSE, addSE))
	elseif reward.rewardType == "Cash" then
		assert(profile.farm ~= nil and profile.accounting ~= nil, "Calendar/INVALID_FARM")
		local curCash = BigAmount.decode(profile.farm.cash)
		local addCash = reward.amountNumber
		profile.farm.cash = BigAmount.encode(BigAmount.add(curCash, addCash))
		local lastEarned = BigAmount.decode(profile.accounting.lastCashEarned)
		profile.accounting.lastCashEarned = BigAmount.encode(BigAmount.add(lastEarned, addCash))
        -- currentFarmCash is the earned base, independent of spending the wallet.
        profile.accounting.currentFarmCash = BigAmount.encode(BigAmount.add(BigAmount.decode(profile.accounting.currentFarmCash or "0"),addCash))
        local multiplier=Codec.Real64.validate(prestigeEarningsMultiplier or 1)
        assert(multiplier>=1,"Calendar/INVALID_PRESTIGE_MULTIPLIER")
        local extra=BigAmount.multiply(addCash,multiplier-1)
        profile.accounting.prestigeExtraEarnings=BigAmount.encode(BigAmount.add(BigAmount.decode(profile.accounting.prestigeExtraEarnings or "0"),extra))
    elseif reward.rewardType == "ShellScripts" then
        local old=ExactUInt.decode(profile.permanent.shellScripts or "0")
        profile.permanent.shellScripts=ExactUInt.encode(ExactUInt.add(old,ExactUInt.fromSafeNumber(reward.amountNumber)))
	elseif reward.rewardType == "Piggy" then
		profile.piggy = profile.piggy or {}
		local curRaw = profile.piggy.rawAmount or "0"
        if type(curRaw)=="number" then curRaw=ExactUInt.encode(ExactUInt.fromSafeNumber(curRaw)) end
		profile.piggy.rawAmount = ExactUInt.encode(ExactUInt.add(ExactUInt.decode(curRaw),ExactUInt.fromSafeNumber(reward.amountNumber)))
	elseif reward.rewardType == "PiggyLevel" then
        local old=profile.piggy.level or "0"
        if type(old)=="number" then old=ExactUInt.encode(ExactUInt.fromSafeNumber(old)) end
        profile.piggy.level=ExactUInt.encode(ExactUInt.add(ExactUInt.decode(old),ExactUInt.fromSafeNumber(reward.amountNumber)))
    elseif reward.rewardType == "Boost" then
		profile.inventory = profile.inventory or {}
		profile.inventory.boosts = profile.inventory.boosts or {}
		local bId = reward.boostId or "unknown_boost"
		local old=profile.inventory.boosts[bId] or "0"
        if type(old)=="number" then old=ExactUInt.encode(ExactUInt.fromSafeNumber(old)) end
        profile.inventory.boosts[bId] = ExactUInt.encode(ExactUInt.add(ExactUInt.decode(old),ExactUInt.fromSafeNumber(reward.amountNumber)))
	elseif reward.rewardType == "Epic" then
		local rId = reward.researchId or "hold_to_hatch"
		applyEpicResearchReward(profile, rId, reward.amountNumber, customPrices)
	end

	return true, reward, nil
end

Calendar.getCycleAndDay = getCycleAndDay
Calendar.computeDayReward = computeDayReward
Calendar.applyEpicResearchReward = applyEpicResearchReward
Calendar.getUtcDayKey = getUtcDayKey
Calendar.canClaimCalendarDay = canClaimCalendarDay
Calendar.claimDailyGift = claimDailyGift

-- Canonical base-table resolver shared by payout preparation and private previews.
-- A nil result is an unresolved category, never an invented replacement reward.
function Calendar.referenceReward(numCollected: number, rows: any): any?
    local m,day=getCycleAndDay(numCollected)
    local row=rows[day]
    local types={[0]="GE",[2]="CashPercent",[14]="ShellScripts",[4]="SE",[5]="PE",[6]="Epic",[7]="Piggy",[9]="PiggyLevel",[10]="Boost"}
    local typ=types[row.type]
    if not typ then return nil end
    local n=row.rewardValues[math.min(m+1,#row.rewardValues)]
    if row.scalingMode==1 then n=row.rewardValues[1]
    elseif row.scalingMode==2 then n=math.min(row.cap,n*(m+1))
    elseif row.scalingMode==3 then n=math.min(row.cap,n*2^math.min(m,32)) end
    if day==28 and m>=24 then typ="GE";n=100000 end
    local subtype=row.subtypes[if row.scalingMode==1 then m%#row.subtypes+1 else math.min(m+1,#row.subtypes)]
    return {rewardType=typ,amount=tostring(n),amountNumber=n,day=day,cycle=m,
        researchId=if typ=="Epic" then subtype else nil,boostId=if typ=="Boost" then subtype else nil}
end

-- Resolve percent-of-home-FV at the authoritative claim instant. No earnings,
-- video, gift or away multipliers are applied to the resulting wallet grant.
function Calendar.resolveReward(numCollected: number, rows: any, homeFarmValue: number?): any?
    local reward=Calendar.referenceReward(numCollected,rows)
    if not reward then return nil end
    if reward.rewardType=="CashPercent" then
        if homeFarmValue==nil then return nil end
        local fv=BigAmount.validate(homeFarmValue)
        local amount=BigAmount.multiply(BigAmount.divide(reward.amountNumber,100),fv)
        reward.percentOfHomeFV=reward.amountNumber
        reward.rewardType="Cash"
        reward.amountNumber=amount
        reward.amount=BigAmount.encode(amount)
    end
    return reward
end

return table.freeze(Calendar)
