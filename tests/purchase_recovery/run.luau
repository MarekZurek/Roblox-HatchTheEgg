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

	-- VIP is blocked at launch
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

	-- double_cash grants 2x income entitlement
	local okPrepDC, prevDC = Products.preparePurchase(p, "double_cash", "tok_dc", 1100)
	eq(okPrepDC, true, "prepare double_cash")
	local okConfDC, resDC = Products.confirmPurchase(p, "tok_dc", nil, 1150)
	eq(okConfDC, true, "confirm double_cash")
	eq(p.entitlements.double_cash, true, "double_cash entitlement granted")

	-- auto_hatch grants auto_hatch entitlement
	local okPrepAH, prevAH = Products.preparePurchase(p, "auto_hatch", "tok_ah", 1200)
	eq(okPrepAH, true, "prepare auto_hatch")
	local okConfAH, resAH = Products.confirmPurchase(p, "tok_ah", nil, 1250)
	eq(okConfAH, true, "confirm auto_hatch")
	eq(p.entitlements.auto_hatch, true, "auto_hatch entitlement granted")

	-- Cannot re-purchase already owned gamepass
	local prevBM2 = Products.previewPurchase(p, "buy_max")
	eq(prevBM2.isAvailable, false, "cannot repurchase buy_max")
	eq(prevBM2.error, "ALREADY_OWNED", "already owned error")

	-- Purchasing Pro Permit does not grant Buy MAX
	local okPrepPro, prevPro = Products.preparePurchase(p, "pro_permit", "tok_pro", 2000, { paidRandomAllowed = true })
	eq(okPrepPro, true, "prepare pro_permit")
	local okConfPro, resPro = Products.confirmPurchase(p, "tok_pro", nil, 2050, nil, {paidRandomAllowed=true})
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
-- Section 7: Product ID Mappings (Roblox Asset ID <-> Internal Catalog ID)
-- ============================================================================
do
	eq(Products.resolveCatalogId(1001), "ge_pack_small", "1001 maps to ge_pack_small")
	eq(Products.resolveCatalogId("1001"), "ge_pack_small", "'1001' maps to ge_pack_small")
	eq(Products.resolveCatalogId(1002), "ge_pack_large", "1002 maps to ge_pack_large")
	eq(Products.resolveCatalogId(1003), "piggy_break", "1003 maps to piggy_break")
	eq(Products.resolveCatalogId(2001), "pro_permit", "2001 maps to pro_permit")
	eq(Products.resolveCatalogId(2002), "buy_max", "2002 maps to buy_max")
	eq(Products.resolveCatalogId(2003), "double_cash", "2003 maps to double_cash")
	eq(Products.resolveCatalogId(2004), "auto_hatch", "2004 maps to auto_hatch")
	eq(Products.resolveCatalogId(3001), "epic_tier_1", "3001 maps to epic_tier_1")
	eq(Products.resolveCatalogId(3002), "epic_tier_2", "3002 maps to epic_tier_2")
	eq(Products.resolveCatalogId(3003), "epic_tier_3", "3003 maps to epic_tier_3")
	eq(Products.resolveCatalogId(3004), "epic_tier_4", "3004 maps to epic_tier_4")

	eq(Products.resolveProductId("ge_pack_small"), 1001, "ge_pack_small maps to 1001")
	eq(Products.resolveProductId("ge_pack_large"), 1002, "ge_pack_large maps to 1002")
	eq(Products.resolveProductId("piggy_break"), 1003, "piggy_break maps to 1003")
	eq(Products.resolveProductId("pro_permit"), 2001, "pro_permit maps to 2001")
	eq(Products.resolveProductId("buy_max"), 2002, "buy_max maps to 2002")
	eq(Products.resolveProductId("double_cash"), 2003, "double_cash maps to 2003")
	eq(Products.resolveProductId("auto_hatch"), 2004, "auto_hatch maps to 2004")
	eq(Products.resolveProductId("epic_tier_1"), 3001, "epic_tier_1 maps to 3001")
	eq(Products.resolveProductId("epic_tier_2"), 3002, "epic_tier_2 maps to 3002")
	eq(Products.resolveProductId("epic_tier_3"), 3003, "epic_tier_3 maps to 3003")
	eq(Products.resolveProductId("epic_tier_4"), 3004, "epic_tier_4 maps to 3004")

	-- Register custom external product ID
	Products.registerProductId(987654, "ge_pack_large")
	eq(Products.resolveCatalogId(987654), "ge_pack_large", "custom ID maps correctly")
	eq(Products.resolveCatalogId("987654"), "ge_pack_large", "custom string ID maps correctly")
end

-- ============================================================================
-- Section 8: Processed Receipts Auditing & Idempotency
-- ============================================================================
do
	local p = makeProfile()
	p.permanent.GE = "100"

	-- Receive receipt with numeric Roblox ProductId
	local receipt = {
		PurchaseId = "purchase_test_123",
		PlayerId = 42,
		ProductId = 1001,
	}

	local okConf1, res1 = Products.confirmPurchase(p, "purchase_test_123", receipt, 500000)
	eq(okConf1, true, "confirm receipt succeeds")
	eq(res1.alreadyApplied, false, "first execution not already applied")
	eq(p.permanent.GE, "1100", "GE increased by 1000")
	eq(p.accounting.processedReceipts ~= nil, true, "processedReceipts table created")
	eq(p.accounting.processedReceipts["purchase_test_123"] ~= nil, true, "receipt recorded in accounting")
	eq(p.accounting.processedReceipts["purchase_test_123"].productId, "ge_pack_small")

	-- Replay receipt
	local okConf2, res2 = Products.confirmPurchase(p, "purchase_test_123", receipt, 501000)
	eq(okConf2, true, "replay confirm succeeds")
	eq(res2.alreadyApplied, true, "replay detected as already applied")
	eq(p.permanent.GE, "1100", "GE balance unchanged on replay")
end

-- ============================================================================
-- Section 9: Full ServerBootstrap Platform Receipt Integration & GamePasses
-- ============================================================================
do
	local ServerBootstrap = require("../../src/server/Bootstrap")
	local nowVal = 10000000
	local clock = {
		utcNowMs = function() return nowVal end,
		elapsedNowSeconds = function() return nowVal / 1000 end,
		advance = function(dt) nowVal += math.floor(dt * 1000 + 0.5) end,
	}

	local server = ServerBootstrap.new({
		clock = clock,
		initialNowMs = 10000000,
        paidRandomAllowed = function(id)return id=="7701" end,
	})

	local j1 = server:playerJoined("7701")
	eq(j1 ~= nil, true, "Player 7701 joined")

	-- Mock Roblox ProcessReceipt logic
	local function mockProcessReceipt(receiptInfo)
		local pId = tostring(receiptInfo.PlayerId)
		local session = server:getPlayer(pId)
		if not session then
			return "NotProcessedYet"
		end
		local success, result = server:applyPurchase(pId, receiptInfo)
		if success then
			return "PurchaseGranted"
		end
		return "NotProcessedYet"
	end

	-- Test 1: Active player purchases 1,000 GE Developer Product
	local receipt1 = {
		PurchaseId = "tx-roblox-1001-a",
		PlayerId = 7701,
		ProductId = 1001,
		CurrencySpent = 80,
	}
	local decision1 = mockProcessReceipt(receipt1)
	eq(decision1, "PurchaseGranted", "ProcessReceipt returns PurchaseGranted")

	local snap = server:getCoordinator("7701"):snapshots().durable
	eq(snap.permanent.GE, "1010", "10 initial GE + 1000 granted GE = 1010")

	-- Test 2: Platform duplicate receipt retry (same PurchaseId)
	local decision2 = mockProcessReceipt(receipt1)
	eq(decision2, "PurchaseGranted", "Replayed receipt returns PurchaseGranted")
	snap = server:getCoordinator("7701"):snapshots().durable
	eq(snap.permanent.GE, "1010", "GE balance remains 1010 without double grant")

	-- Test 3: Disconnected player receipt -> NotProcessedYet
	local ghostReceipt = {
		PurchaseId = "tx-roblox-ghost-1",
		PlayerId = 9999,
		ProductId = 1001,
	}
	local ghostDecision = mockProcessReceipt(ghostReceipt)
	eq(ghostDecision, "NotProcessedYet", "Disconnected player returns NotProcessedYet")

	-- Test 4: GamePass Pro Permit grant (qualified account: paidRandomAllowed = true)
	local okPass, passRes = server:grantEntitlement("7701", "pro_permit", { paidRandomAllowed = true })
	eq(okPass, true, "grantEntitlement pro_permit succeeds")
	snap = server:getCoordinator("7701"):snapshots().durable
	eq(snap.entitlements.pro_permit, true, "pro_permit entitlement active")
	eq(snap.entitlements.pro_plus10_enabled, true, "pro_plus10 enabled for qualified player")

	-- Test 5: GamePass Pro Permit grant with Variant A (non-qualified account: paidRandomAllowed = false)
	local j2 = server:playerJoined("7702")
	eq(j2 ~= nil, true, "Player 7702 joined")
	local okPass2, _ = server:grantEntitlement("7702", "pro_permit", { paidRandomAllowed = false })
	eq(okPass2, true, "grantEntitlement pro_permit non-qual succeeds")
	local snap2 = server:getCoordinator("7702"):snapshots().durable
	eq(snap2.entitlements.pro_permit, true, "pro_permit active")
	eq(snap2.entitlements.pro_plus10_enabled, false, "pro_plus10 explicitly false (Variant A)")

	-- Test 6: GamePass Buy MAX grant
	local okBM, _ = server:grantEntitlement("7701", "buy_max")
	eq(okBM, true, "grantEntitlement buy_max succeeds")
	snap = server:getCoordinator("7701"):snapshots().durable
	eq(snap.entitlements.buy_max, true, "buy_max entitlement active")

	-- Test 6b: GamePass Double Cash grant
	local okDC, _ = server:grantEntitlement("7701", "double_cash")
	eq(okDC, true, "grantEntitlement double_cash succeeds")
	snap = server:getCoordinator("7701"):snapshots().durable
	eq(snap.entitlements.double_cash, true, "double_cash entitlement active")

	-- Test 7: Large GE pack (10,000 GE) receipt
	local receiptLarge = {
		PurchaseId = "tx-roblox-1002-large",
		PlayerId = 7701,
		ProductId = 1002,
		CurrencySpent = 500,
	}
	local decisionLarge = mockProcessReceipt(receiptLarge)
	eq(decisionLarge, "PurchaseGranted", "Large GE pack granted")
	snap = server:getCoordinator("7701"):snapshots().durable
	eq(snap.permanent.GE, "11010", "1010 + 10,000 = 11010 GE")

	server:close()
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
