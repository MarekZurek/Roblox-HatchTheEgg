--!strict
-- Authoritative server logic for 2+1 delivery channels (packages and bonus offers).
-- Spec: docs/16 §4; docs/22 §3 (D04), §4 (D05); docs/24; docs/27 §3.3, §4; Issue #32 (NEXT-07).

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

local Offers = {
	VERSION = 1,
	MAX_ORDINARY_SLOTS = 2,
	MAX_BONUS_SLOTS = 1,
}

export type OfferChannel = "ordinary" | "bonus"
export type OfferStatus = "PENDING" | "RESERVED" | "CLAIMED" | "DISMISSED"
export type OfferRewardType = "Cash" | "GE" | "Boost"

export type OfferReward = {
	rewardType: OfferRewardType,
	amount: string, -- numeric encoded (BigAmount for Cash, ExactUInt for GE, count for Boost)
	amountNumber: number,
	boostId: string?,
}

export type DeliveryOffer = {
	offerId: string,
	channel: OfferChannel,
	status: OfferStatus,
	createdAtMs: number,
	reward: OfferReward,
	reservationToken: string?,
}

export type OffersState = {
	ordinary: { [string]: DeliveryOffer },
	bonus: { [string]: DeliveryOffer },
	nextOrdinaryAttemptMs: number?,
	nextBonusAttemptMs: number?,
}

export type ClaimResult = {
	success: boolean,
	reward: OfferReward?,
	isFree: boolean,
	costGE: number?,
	error: string?,
}

local function createOffersState(): OffersState
	return {
		ordinary = {},
		bonus = {},
	}
end

local function countActiveInChannel(channelMap: { [string]: DeliveryOffer }): number
	local count = 0
	for _, offer in channelMap do
		if offer.status == "PENDING" or offer.status == "RESERVED" then
			count += 1
		end
	end
	return count
end

local function getActiveCounts(state: OffersState): (number, number)
	return countActiveInChannel(state.ordinary), countActiveInChannel(state.bonus)
end

-- Creates a new delivery offer in the specified channel.
-- Slot is occupied from creation (PENDING) through delivery.
local function createOffer(
	state: OffersState,
	offerId: string,
	channel: OfferChannel,
	reward: OfferReward,
	nowMs: number
): (boolean, DeliveryOffer?, string?)
	assert(type(state) == "table", "Offers/INVALID_STATE")
	assert(type(offerId) == "string" and #offerId > 0, "Offers/INVALID_OFFER_ID")
	assert(channel == "ordinary" or channel == "bonus", "Offers/INVALID_CHANNEL")
	assert(type(reward) == "table", "Offers/INVALID_REWARD")

	local channelMap = state[channel]
	assert(channelMap ~= nil, "Offers/INVALID_CHANNEL_MAP")

	if channelMap[offerId] ~= nil then
		return false, nil, "DUPLICATE_OFFER_ID"
	end

	local maxSlots = if channel == "ordinary" then Offers.MAX_ORDINARY_SLOTS else Offers.MAX_BONUS_SLOTS
	local activeCount = countActiveInChannel(channelMap)
	if activeCount >= maxSlots then
		return false, nil, "CHANNEL_FULL"
	end

	local offer: DeliveryOffer = {
		offerId = offerId,
		channel = channel,
		status = "PENDING",
		createdAtMs = nowMs,
		reward = table.freeze({
			rewardType = reward.rewardType,
			amount = reward.amount,
			amountNumber = reward.amountNumber,
			boostId = reward.boostId,
		}),
		reservationToken = nil,
	}

	channelMap[offerId] = offer
	return true, offer, nil
end

local function findOffer(state: OffersState, offerId: string): (DeliveryOffer?, OfferChannel?)
	if state.ordinary[offerId] ~= nil then
		return state.ordinary[offerId], "ordinary"
	elseif state.bonus[offerId] ~= nil then
		return state.bonus[offerId], "bonus"
	end
	return nil, nil
end

-- Dismiss an offer without cost, freeing the channel slot (D05 R).
local function dismissOffer(state: OffersState, offerId: string): (boolean, string?)
	assert(type(state) == "table", "Offers/INVALID_STATE")
	local offer = findOffer(state, offerId)
	if not offer then
		return false, "OFFER_NOT_FOUND"
	end

	if offer.status == "RESERVED" then
		return false, "OFFER_RESERVED"
	elseif offer.status == "CLAIMED" then
		return false, "ALREADY_CLAIMED"
	elseif offer.status == "DISMISSED" then
		return false, "ALREADY_DISMISSED"
	end

	offer.status = "DISMISSED"
	return true, nil
end

-- UTC day helper: math.floor(nowMs / 86400000).
local function getUtcDayKey(nowMs: number): number
	return math.floor(nowMs / 86400000)
end

-- Check if bonus offer claim is free on this UTC day (D04 R).
local function isBonusClaimFree(profile: any, nowMs: number): boolean
	if not profile then
		return true
	end
	local currentUtcDay = getUtcDayKey(nowMs)
	local lastDay = (profile.rewards and profile.rewards.lastFreeBonusDayUtc) or -1
	return currentUtcDay > lastDay
end

-- Apply an offer's reward to the authoritative player profile.
-- Enlightenment safe: Boosts are placed in inventory.boosts without activating.
local function applyRewardToProfile(profile: any, reward: OfferReward)
	if not profile then
		return
	end

	if reward.rewardType == "GE" then
		assert(profile.permanent ~= nil, "Offers/INVALID_PROFILE_PERMANENT")
		local currentGE = ExactUInt.decode(profile.permanent.GE)
		local addGE = ExactUInt.fromSafeNumber(reward.amountNumber)
		profile.permanent.GE = ExactUInt.encode(ExactUInt.add(currentGE, addGE))
	elseif reward.rewardType == "Cash" then
		assert(profile.farm ~= nil and profile.accounting ~= nil, "Offers/INVALID_PROFILE_FARM")
		local currentCash = BigAmount.decode(profile.farm.cash)
		local addCash = reward.amountNumber
		profile.farm.cash = BigAmount.encode(BigAmount.add(currentCash, addCash))

		local lastEarned = BigAmount.decode(profile.accounting.lastCashEarned)
		profile.accounting.lastCashEarned = BigAmount.encode(BigAmount.add(lastEarned, addCash))
	elseif reward.rewardType == "Boost" then
		assert(profile.inventory ~= nil, "Offers/INVALID_PROFILE_INVENTORY")
		profile.inventory.boosts = profile.inventory.boosts or {}
		local bId = reward.boostId or "unknown_boost"
		local curCount = profile.inventory.boosts[bId] or 0
		profile.inventory.boosts[bId] = curCount + math.max(1, math.floor(reward.amountNumber))
	end
end

-- Claim an offer directly.
local function claimOffer(
	state: OffersState,
	offerId: string,
	nowMs: number,
	profile: any,
	paidGE: number?
): (boolean, ClaimResult)
	assert(type(state) == "table", "Offers/INVALID_STATE")
	local offer = findOffer(state, offerId)
	if not offer then
		return false, { success = false, error = "OFFER_NOT_FOUND", isFree = false }
	end

	if offer.status == "RESERVED" then
		return false, { success = false, error = "OFFER_RESERVED", isFree = false }
	elseif offer.status == "CLAIMED" then
		return false, { success = false, error = "ALREADY_CLAIMED", isFree = false }
	elseif offer.status == "DISMISSED" then
		return false, { success = false, error = "ALREADY_DISMISSED", isFree = false }
	elseif offer.status ~= "PENDING" then
		return false, { success = false, error = "INVALID_STATUS", isFree = false }
	end

	local isFree = true
	local costGE = nil

	if offer.channel == "bonus" then
		isFree = isBonusClaimFree(profile, nowMs)
		if isFree then
			if profile then
				profile.rewards = profile.rewards or {}
				profile.rewards.lastFreeBonusDayUtc = getUtcDayKey(nowMs)
			end
		else
			costGE = paidGE or 10 -- default fixture cost if paid
			if profile and profile.permanent then
				local currentGE = ExactUInt.decode(profile.permanent.GE)
				local costExact = ExactUInt.fromSafeNumber(costGE)
				if ExactUInt.compare(currentGE, costExact) < 0 then
					return false, { success = false, error = "INSUFFICIENT_GE", isFree = false, costGE = costGE }
				end
				profile.permanent.GE = ExactUInt.encode(ExactUInt.subtract(currentGE, costExact))
			end
		end
	end

	offer.status = "CLAIMED"
	applyRewardToProfile(profile, offer.reward)

	return true, {
		success = true,
		reward = offer.reward,
		isFree = isFree,
		costGE = costGE,
	}
end

-- Reserve an offer for a pending external payment transaction (D04/D05/D07 R).
local function reserveOffer(
	state: OffersState,
	offerId: string,
	reservationToken: string
): (boolean, string?)
	assert(type(state) == "table", "Offers/INVALID_STATE")
	assert(type(reservationToken) == "string" and #reservationToken > 0, "Offers/INVALID_TOKEN")

	local offer = findOffer(state, offerId)
	if not offer then
		return false, "OFFER_NOT_FOUND"
	end

	if offer.status == "RESERVED" then
		return false, "OFFER_RESERVED"
	elseif offer.status == "CLAIMED" then
		return false, "ALREADY_CLAIMED"
	elseif offer.status == "DISMISSED" then
		return false, "ALREADY_DISMISSED"
	elseif offer.status ~= "PENDING" then
		return false, "INVALID_STATUS"
	end

	offer.status = "RESERVED"
	offer.reservationToken = reservationToken
	return true, nil
end

-- Release an offer reservation upon payment cancellation/failure.
local function releaseReservation(
	state: OffersState,
	offerId: string,
	reservationToken: string
): (boolean, string?)
	assert(type(state) == "table", "Offers/INVALID_STATE")
	local offer = findOffer(state, offerId)
	if not offer then
		return false, "OFFER_NOT_FOUND"
	end

	if offer.status ~= "RESERVED" then
		return false, "NOT_RESERVED"
	end

	if offer.reservationToken ~= reservationToken then
		return false, "TOKEN_MISMATCH"
	end

	offer.status = "PENDING"
	offer.reservationToken = nil
	return true, nil
end

-- Confirm and finalize a reserved offer upon successful payment.
local function confirmReservedClaim(
	state: OffersState,
	offerId: string,
	reservationToken: string,
	profile: any
): (boolean, ClaimResult)
	assert(type(state) == "table", "Offers/INVALID_STATE")
	local offer = findOffer(state, offerId)
	if not offer then
		return false, { success = false, error = "OFFER_NOT_FOUND", isFree = false }
	end

	if offer.status ~= "RESERVED" then
		return false, { success = false, error = "NOT_RESERVED", isFree = false }
	end

	if offer.reservationToken ~= reservationToken then
		return false, { success = false, error = "TOKEN_MISMATCH", isFree = false }
	end

	offer.status = "CLAIMED"
	offer.reservationToken = nil
	applyRewardToProfile(profile, offer.reward)

	return true, {
		success = true,
		reward = offer.reward,
		isFree = false,
	}
end

Offers.createOffersState = createOffersState
Offers.getActiveCounts = getActiveCounts
Offers.createOffer = createOffer
Offers.findOffer = findOffer
Offers.dismissOffer = dismissOffer
Offers.getUtcDayKey = getUtcDayKey
Offers.isBonusClaimFree = isBonusClaimFree
Offers.claimOffer = claimOffer
Offers.reserveOffer = reserveOffer
Offers.releaseReservation = releaseReservation
Offers.confirmReservedClaim = confirmReservedClaim

return table.freeze(Offers)
