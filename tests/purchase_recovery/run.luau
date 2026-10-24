--!nocheck
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local Codec = require("../../src/shared/NumericCodec")
local Products = require("../../src/server/platform/products")

local assertions = 0
local function eq(a, b, label)
	assertions += 1
	assert(a == b, (if label then label .. ": " else "") .. tostring(a) .. " != " .. tostring(b))
end

local function makeProfile()
	return {
		meta = { schemaVersion = 1, revision = "0" },
		permanent = { GE = "100", totalGESpent = "0", SE = "0", PE = "0" },
		farm = { cash = "1000" },
		accounting = { lastCashEarned = "0" },
		entitlements = {},
		operations = {},
		piggy = { rawAmount = 5000, breaksCount = 0 },
	}
end

-- ============================================================================
-- Section 1: Launch Scope and Blocked Products (docs/26 R)
-- ============================================================================
do
	local p = makeProfile()

	-- Auto-Hatch and VIP are blocked at launch
	local prevAuto = Products.previewPurchase(p, "auto_hatch")
	eq(prevAuto.isAvailable, false, "auto_hatch unavailable at launch")
	eq(prevAuto.error, "PRODUCT_UNAVAILABLE_AT_LAUNCH", "auto_hatch error")

	local okPrepAuto, _, errPrepAuto = Products.preparePurchase(p, "auto_hatch", "tok_auto", 1000)
	eq(okPrepAuto, false, "prepare auto_hatch fails")
	eq(errPrepAuto, "PRODUCT_UNAVAILABLE_AT_LAUNCH", "prepare auto_hatch error")

	local prevVIP = Products.previewPurchase(p, "vip")
	eq(prevVIP.isAvailable, false, "vip unavailable at launch")
	eq(prevVIP.error, "PRODUCT_UNAVAILABLE_AT_LAUNCH", "vip error")
end

-- ============================================================================
-- Section 2: Pro Permit, Buy MAX Independence and Re-purchase Protection
-- ============================================================================
do
	local p = makeProfile()

	-- Buy MAX does not grant Pro Permit
	local okPrepBM, prevBM = Products.preparePurchase(p, "buy_max", "tok_bm", 1000)
	eq(okPrepBM, true, "prepare buy_max")
	local okConfBM, resBM = Products.confirmPurchase(p, "tok_bm", nil, 1050)
	eq(okConfBM, true, "confirm buy_max")
	eq(p.entitlements.buy_max, true, "buy_max entitlement granted")
	eq(p.entitlements.pro_permit, nil, "pro_permit NOT granted by buy_max")

	-- Cannot re-purchase already owned gamepass
	local prevBM2 = Products.previewPurchase(p, "buy_max")
	eq(prevBM2.isAvailable, false, "cannot repurchase buy_max")
	eq(prevBM2.error, "ALREADY_OWNED", "already owned error")

	-- Purchasing Pro Permit does not grant Buy MAX
	local okPrepPro, prevPro = Products.preparePurchase(p, "pro_permit", "tok_pro", 2000, { paidRandomAllowed = true })
	eq(okPrepPro, true, "prepare pro_permit")
	local okConfPro, resPro = Products.confirmPurchase(p, "tok_pro", nil, 2050)
	eq(okConfPro, true, "confirm pro_permit")
	eq(p.entitlements.pro_permit, true, "pro_permit granted")
	eq(p.entitlements.pro_plus10_enabled, true, "plus10 enabled for qualified player")

	-- Cannot re-purchase pro_permit
	local prevPro2 = Products.previewPurchase(p, "pro_permit")
	eq(prevPro2.isAvailable, false, "cannot repurchase pro_permit")
	eq(prevPro2.error, "ALREADY_OWNED", "already owned error")
end

-- ============================================================================
-- Section 3: Variant A for Pro Permit (docs/26 R)
-- ============================================================================
do
	local p = makeProfile()

	-- Qualified player: paidRandomAllowed = true
	local prevQual = Products.previewPurchase(p, "pro_permit", { paidRandomAllowed = true })
	eq(prevQual.paidBonusAvailable, true, "plus10 available for qualified")

	-- Non-qualified player: paidRandomAllowed = false (Variant A)
	local prevNonQual = Products.previewPurchase(p, "pro_permit", { paidRandomAllowed = false })
	eq(prevNonQual.paidBonusAvailable, false, "plus10 disabled for non-qualified")
	eq(string.find(prevNonQual.description, "disabled") ~= nil, true, "description discloses disabled bonus")

	-- Purchase as non-qualified
	local okPrep, _ = Products.preparePurchase(p, "pro_permit", "tok_pro_nonqual", 1000, { paidRandomAllowed = false })
	eq(okPrep, true, "prepare non-qualified pro")
	local okConf, _ = Products.confirmPurchase(p, "tok_pro_nonqual", { paidRandomAllowed = false }, 1050)
	eq(okConf, true, "confirm non-qualified pro")
	eq(p.entitlements.pro_permit, true, "pro_permit active")
	eq(p.entitlements.pro_plus10_enabled, false, "plus10 explicitly false in entitlements")
end

-- ============================================================================
-- Section 4: Conditional Piggy Bank (docs/25 L13, docs/26 L14)
-- ============================================================================
do
	local p = makeProfile()
	p.piggy.rawAmount = 15000

	-- When isPiggyEnabled is false/nil -> PIGGY_DISABLED
	local prevPiggyOff = Products.previewPurchase(p, "piggy_break", nil, false)
	eq(prevPiggyOff.isAvailable, false, "piggy preview unavailable when disabled")
	eq(prevPiggyOff.error, "PIGGY_DISABLED", "piggy disabled error")

	local okPrepOff, _, errPrepOff = Products.preparePurchase(p, "piggy_break", "tok_pig_off", 1000, nil, false)
	eq(okPrepOff, false, "prepare piggy fails when disabled")
	eq(errPrepOff, "PIGGY_DISABLED", "piggy disabled error")

	-- When isPiggyEnabled is true -> succeeds and empties piggy bank to GE
	local prevPiggyOn = Products.previewPurchase(p, "piggy_break", nil, true)
	eq(prevPiggyOn.isAvailable, true, "piggy available when enabled")

	local okPrepOn, _ = Products.preparePurchase(p, "piggy_break", "tok_pig_on", 1000, nil, true)
	eq(okPrepOn, true, "prepare piggy succeeds")

	local curGE = p.permanent.GE -- "100"
	local okConfOn, _ = Products.confirmPurchase(p, "tok_pig_on", nil, 1050, true)
	eq(okConfOn, true, "confirm piggy succeeds")
	eq(p.permanent.GE, "15100", "piggy amount added to GE")
	eq(p.piggy.rawAmount, 0, "piggy bank emptied")
	eq(p.piggy.breaksCount, 1, "breaksCount incremented")
end

-- ============================================================================
-- Section 5: Transaction Idempotency and Recovery (D07)
-- ============================================================================
do
	local p = makeProfile()
	p.permanent.GE = "100"

	-- GE pack purchase: 1000 GE
	local okPrep, _ = Products.preparePurchase(p, "ge_pack_small", "tok_ge_repeat", 1000)
	eq(okPrep, true, "prepare GE pack")
	eq(p.operations["tok_ge_repeat"].terminalStatus, "RESERVED", "status is RESERVED")

	-- First confirmation: awards 1000 GE -> total 1100
	local okConf1, res1 = Products.confirmPurchase(p, "tok_ge_repeat", { geAmount = 1000 }, 1050)
	eq(okConf1, true, "confirm 1st time")
	eq(res1.alreadyApplied, false, "first execution")
	eq(p.permanent.GE, "1100", "GE balance is 1100")
	eq(p.operations["tok_ge_repeat"].terminalStatus, "APPLIED", "status is APPLIED")

	-- Replay confirmation (e.g. retry / reconnect / network duplication)
	local okConf2, res2 = Products.confirmPurchase(p, "tok_ge_repeat", { geAmount = 1000 }, 1100)
	eq(okConf2, true, "confirm 2nd time")
	eq(res2.alreadyApplied, true, "detected already applied")
	eq(p.permanent.GE, "1100", "GE balance unchanged (no duplicate payout)")

	-- Cannot cancel already applied operation
	local okCanc, errCanc = Products.cancelPurchase(p, "tok_ge_repeat")
	eq(okCanc, false, "cancel applied purchase rejected")
	eq(errCanc, "CANNOT_CANCEL_APPLIED", "cannot cancel error")

	-- Cancellation of unconfirmed reservation
	Products.preparePurchase(p, "ge_pack_small", "tok_ge_cancel", 2000)
	local okCanc2, _ = Products.cancelPurchase(p, "tok_ge_cancel")
	eq(okCanc2, true, "cancel unconfirmed reservation succeeds")
	eq(p.operations["tok_ge_cancel"].terminalStatus, "REJECTED", "status is REJECTED")

	-- Attempting to confirm cancelled purchase fails
	local okConfCanc, resConfCanc = Products.confirmPurchase(p, "tok_ge_cancel", nil, 2050)
	eq(okConfCanc, false, "confirm cancelled purchase fails")
	eq(resConfCanc.error, "PURCHASE_CANCELLED", "purchase cancelled error")
end

-- ============================================================================
-- Section 6: Midnight UTC Crossing (docs/24 CROSS-1, docs/27 §3.3)
-- ============================================================================
do
	local p = makeProfile()
	p.permanent.GE = "500"

	-- Prepared at 23:59:50 UTC (day 0, nowMs = 86 390 000 ms)
	local beforeMidnightMs = 86390000
	local okPrep, _ = Products.preparePurchase(p, "ge_pack_large", "tok_midnight", beforeMidnightMs)
	eq(okPrep, true, "prepared before midnight")
	eq(p.operations["tok_midnight"].preparedUtcDay, 0, "preparedUtcDay is 0")

	-- Confirmed at 00:00:10 UTC (day 1, nowMs = 86 410 000 ms)
	local afterMidnightMs = 86410000
	local okConf, resConf = Products.confirmPurchase(p, "tok_midnight", { geAmount = 10000 }, afterMidnightMs)
	eq(okConf, true, "confirmed after midnight")
	eq(resConf.alreadyApplied, false, "fulfilled successfully")
	eq(p.permanent.GE, "10500", "10,000 GE awarded cleanly across midnight")
end

-- ============================================================================
-- Section 7: Save Results JSON
-- ============================================================================
fs.writeFile("build/purchase_recovery-results.json", serde.encode("json", {
	status = "PASS",
	level = "L",
	assertions = assertions,
	studioTested = false,
	dataStoreTested = false,
	scope = "NEXT-09 Products adapter for Pro Permit, Buy MAX, GE packs, conditional Piggy, Variant A disclosure, and idempotent recovery",
}, true))

print(string.format("Purchase Recovery & Products PASS: %d assertions", assertions))
