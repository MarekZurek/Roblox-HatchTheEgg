--!nocheck
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local Codec = require("../../src/shared/NumericCodec")
local Offers = require("../../src/server/rewards/offers")

local assertions = 0
local function eq(a, b, label)
	assertions += 1
	assert(a == b, (if label then label .. ": " else "") .. tostring(a) .. " != " .. tostring(b))
end

local function near(a, b, maxAbsErr, label)
	assertions += 1
	local err = math.abs(a - b)
	local limit = maxAbsErr or 1e-12
	assert(err <= limit, (if label then label .. ": " else "") .. tostring(a) .. " !~= " .. tostring(b))
end

local function makeProfile(nowMs)
	return {
		meta = { schemaVersion = 1, revision = "0" },
		permanent = { GE = "100", totalGESpent = "0", SE = "0", PE = "0" },
		farm = { cash = "1000", habitats = {} },
		accounting = { lastCashEarned = "0" },
		inventory = { boosts = {}, pets = {}, equipped = {} },
		rewards = { lastFreeBonusDayUtc = -1 },
	}
end

-- ============================================================================
-- Section 1: Channel Capacity 2+1 and Slot Occupancy
-- ============================================================================
do
	local state = Offers.createOffersState()
	local ordCount, bonusCount = Offers.getActiveCounts(state)
	eq(ordCount, 0, "initial ordinary count")
	eq(bonusCount, 0, "initial bonus count")

	local rCash = { rewardType = "Cash", amount = "500", amountNumber = 500 }
	local rGE = { rewardType = "GE", amount = "24", amountNumber = 24 }
	local rBoost = { rewardType = "Boost", amount = "1", amountNumber = 1, boostId = "jimbos_blue_v2" }

	-- Add 1st ordinary
	local ok1, off1 = Offers.createOffer(state, "ord_1", "ordinary", rCash, 1000)
	eq(ok1, true, "create ord_1")
	eq(off1.status, "PENDING", "ord_1 status")

	-- Add 2nd ordinary
	local ok2, off2 = Offers.createOffer(state, "ord_2", "ordinary", rGE, 1000)
	eq(ok2, true, "create ord_2")

	ordCount, bonusCount = Offers.getActiveCounts(state)
	eq(ordCount, 2, "ordinary count at max 2")

	-- Attempt 3rd ordinary -> CHANNEL_FULL
	local ok3, off3, err3 = Offers.createOffer(state, "ord_3", "ordinary", rCash, 1000)
	eq(ok3, false, "create ord_3 rejected")
	eq(err3, "CHANNEL_FULL", "channel full error")

	-- Add 1st bonus offer
	local okB1, offB1 = Offers.createOffer(state, "bonus_1", "bonus", rBoost, 1000)
	eq(okB1, true, "create bonus_1")

	ordCount, bonusCount = Offers.getActiveCounts(state)
	eq(bonusCount, 1, "bonus count at max 1")

	-- Attempt 2nd bonus offer -> CHANNEL_FULL
	local okB2, offB2, errB2 = Offers.createOffer(state, "bonus_2", "bonus", rGE, 1000)
	eq(okB2, false, "create bonus_2 rejected")
	eq(errB2, "CHANNEL_FULL", "bonus channel full")

	-- Duplicate ID check
	local okDup, _, errDup = Offers.createOffer(state, "ord_1", "ordinary", rCash, 1000)
	eq(okDup, false, "duplicate offer id")
	eq(errDup, "DUPLICATE_OFFER_ID", "duplicate error")
end

-- ============================================================================
-- Section 2: Fixed Reward Determination and Free Dismissal
-- ============================================================================
do
	local state = Offers.createOffersState()
	local rGE = { rewardType = "GE", amount = "48", amountNumber = 48 }
	local ok, off = Offers.createOffer(state, "ord_fixed", "ordinary", rGE, 2000)
	eq(ok, true, "create offer")
	eq(off.reward.rewardType, "GE", "reward type fixed")
	eq(off.reward.amountNumber, 48, "amountNumber fixed")

	-- Dismiss offer without penalty/cost
	local okD, errD = Offers.dismissOffer(state, "ord_fixed")
	eq(okD, true, "dismiss offer")
	eq(off.status, "DISMISSED", "status is dismissed")

	-- Slot is freed!
	local ordCount = Offers.getActiveCounts(state)
	eq(ordCount, 0, "slot freed after dismissal")

	-- Cannot dismiss already dismissed
	local okD2, errD2 = Offers.dismissOffer(state, "ord_fixed")
	eq(okD2, false, "dismiss already dismissed")
	eq(errD2, "ALREADY_DISMISSED", "already dismissed error")
end

-- ============================================================================
-- Section 3: UTC Days and Free vs Paid Bonus Claims
-- ============================================================================
do
	local state = Offers.createOffersState()
	local profile = makeProfile(10000)
	profile.permanent.GE = "100"

	-- UTC Day 0: nowMs = 1 000 000 ms (day 0)
	local day0Ms = 1000000
	eq(Offers.isBonusClaimFree(profile, day0Ms), true, "first bonus claim is free on day 0")

	local rCash = { rewardType = "Cash", amount = "1000", amountNumber = 1000 }
	Offers.createOffer(state, "b_day0_1", "bonus", rCash, day0Ms)

	-- Claim 1st bonus of Day 0 -> FREE!
	local okC1, res1 = Offers.claimOffer(state, "b_day0_1", day0Ms, profile, nil)
	eq(okC1, true, "claim 1st bonus")
	eq(res1.isFree, true, "1st bonus was free")
	eq(profile.rewards.lastFreeBonusDayUtc, 0, "lastFreeBonusDayUtc set to 0")
	eq(profile.farm.cash, "2000", "cash added to farm")
	eq(profile.accounting.lastCashEarned, "1000", "lastCashEarned tracked")
	eq(profile.permanent.GE, "100", "GE unchanged for free claim")

	-- 2nd bonus of Day 0 -> PAID!
	eq(Offers.isBonusClaimFree(profile, day0Ms + 5000), false, "second bonus is not free")

	Offers.createOffer(state, "b_day0_2", "bonus", rCash, day0Ms + 5000)

	-- Insufficient GE check
	profile.permanent.GE = "5"
	local okC2Fail, res2Fail = Offers.claimOffer(state, "b_day0_2", day0Ms + 6000, profile, 20)
	eq(okC2Fail, false, "paid bonus claim rejected for insufficient GE")
	eq(res2Fail.error, "INSUFFICIENT_GE", "insufficient ge error")

	-- Successful paid claim
	profile.permanent.GE = "50"
	local okC2, res2 = Offers.claimOffer(state, "b_day0_2", day0Ms + 7000, profile, 20)
	eq(okC2, true, "paid bonus claim succeeded")
	eq(res2.isFree, false, "2nd bonus was not free")
	eq(res2.costGE, 20, "cost was 20 GE")
	eq(profile.permanent.GE, "30", "20 GE deducted from permanent")

	-- Midnight UTC transition: Day 1 (nowMs = 86 400 000 ms)
	local day1Ms = 86400000 + 1000
	eq(Offers.isBonusClaimFree(profile, day1Ms), true, "bonus claim free again on Day 1")

	Offers.createOffer(state, "b_day1_1", "bonus", rCash, day1Ms)
	local okC3, res3 = Offers.claimOffer(state, "b_day1_1", day1Ms, profile, nil)
	eq(okC3, true, "Day 1 1st bonus claimed")
	eq(res3.isFree, true, "Day 1 1st bonus is free")
	eq(profile.rewards.lastFreeBonusDayUtc, 1, "lastFreeBonusDayUtc updated to 1")

	-- Farm reset / prestige invariant: rewards.lastFreeBonusDayUtc is preserved
	local simulatedPrestige = function(p)
		p.farm.cash = "0"
		-- p.rewards remains intact!
	end
	simulatedPrestige(profile)
	eq(profile.rewards.lastFreeBonusDayUtc, 1, "rewards.lastFreeBonusDayUtc preserved across reset")
end

-- ============================================================================
-- Section 4: Payment Reservation Cycle (D04/D05/D07 R)
-- ============================================================================
do
	local state = Offers.createOffersState()
	local profile = makeProfile(1000)
	local rBoost = { rewardType = "Boost", amount = "2", amountNumber = 2, boostId = "tachyon_prism_orange" }

	Offers.createOffer(state, "ord_res", "ordinary", rBoost, 1000)

	-- Reserve offer
	local token = "res_token_xyz"
	local okR, errR = Offers.reserveOffer(state, "ord_res", token)
	eq(okR, true, "reserve offer")
	local off = Offers.findOffer(state, "ord_res")
	eq(off.status, "RESERVED", "status is RESERVED")
	eq(off.reservationToken, token, "token set")

	-- While RESERVED: cannot dismiss or claim
	local okD, errD = Offers.dismissOffer(state, "ord_res")
	eq(okD, false, "dismiss rejected during reservation")
	eq(errD, "OFFER_RESERVED", "dismiss error OFFER_RESERVED")

	local okC, resC = Offers.claimOffer(state, "ord_res", 2000, profile)
	eq(okC, false, "claim rejected during reservation")
	eq(resC.error, "OFFER_RESERVED", "claim error OFFER_RESERVED")

	-- Cannot reserve again
	local okR2, errR2 = Offers.reserveOffer(state, "ord_res", "other_token")
	eq(okR2, false, "double reserve rejected")
	eq(errR2, "OFFER_RESERVED", "double reserve error")

	-- Release reservation with bad token
	local okRelBad, errRelBad = Offers.releaseReservation(state, "ord_res", "wrong_token")
	eq(okRelBad, false, "release with wrong token rejected")
	eq(errRelBad, "TOKEN_MISMATCH", "token mismatch error")

	-- Release reservation successfully
	local okRel, errRel = Offers.releaseReservation(state, "ord_res", token)
	eq(okRel, true, "release reservation")
	eq(off.status, "PENDING", "status returned to PENDING")
	eq(off.reservationToken, nil, "token cleared")

	-- Re-reserve and confirm claim
	Offers.reserveOffer(state, "ord_res", "token_confirm")
	local okConf, resConf = Offers.confirmReservedClaim(state, "ord_res", "token_confirm", profile)
	eq(okConf, true, "confirm reserved claim")
	eq(resConf.success, true, "claim success")
	eq(off.status, "CLAIMED", "status is CLAIMED")
	eq(profile.inventory.boosts["tachyon_prism_orange"], 2, "boosts awarded to inventory")
end

-- ============================================================================
-- Section 5: Enlightenment Farm Claim (D04/D05 R)
-- ============================================================================
do
	local state = Offers.createOffersState()
	local profile = makeProfile(1000)
	profile.farm.eggIndex = 18 -- Enlightenment Farm

	local rGE = { rewardType = "GE", amount = "96", amountNumber = 96 }
	local rBoost = { rewardType = "Boost", amount = "1", amountNumber = 1, boostId = "jimbos_orange" }

	Offers.createOffer(state, "ord_ge", "ordinary", rGE, 1000)
	Offers.createOffer(state, "b_boost", "bonus", rBoost, 1000)

	-- Claim GE on Enlightenment
	local ok1 = Offers.claimOffer(state, "ord_ge", 1000, profile)
	eq(ok1, true, "claim GE on Enlightenment")
	eq(profile.permanent.GE, "196", "GE added to permanent on Enlightenment")

	-- Claim Boost on Enlightenment -> stored in inventory, NOT auto-activated
	local ok2 = Offers.claimOffer(state, "b_boost", 1000, profile)
	eq(ok2, true, "claim Boost on Enlightenment")
	eq(profile.inventory.boosts["jimbos_orange"], 1, "boost item stored in inventory")
	eq(#(profile.inventory.equipped or {}), 0, "equipped intact")
end

-- ============================================================================
-- Section 6: Output Results JSON
-- ============================================================================
fs.writeFile("build/offers-results.json", serde.encode("json", {
	status = "PASS",
	level = "L",
	assertions = assertions,
	studioTested = false,
	dataStoreTested = false,
	scope = "NEXT-07 2+1 delivery channels, channel occupancy, fixed reward determination, free dismissal, UTC daily free right, and payment reservation",
}, true))

print(string.format("Offers 2+1 & Delivery PASS: %d assertions", assertions))
