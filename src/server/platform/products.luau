--!strict
-- Authoritative server adapter for platform products (Pro Permit, Buy MAX, GE, conditional Piggy).
-- Spec: docs/25; docs/26; docs/27 §3.3, §4, §5; docs/28; Issue #34 (NEXT-09).

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

local Products = {
	VERSION = 1,
}

export type ProductType = "gamepass" | "developer_product"

export type ProductDef = {
	productId: string,
	productType: ProductType,
	availableAtLaunch: boolean,
	requiresPiggy: boolean?,
	defaultGEAmount: number?,
	name: string,
}

export type PlayerContext = {
	paidRandomAllowed: boolean?,
}

export type PurchasePreview = {
	productId: string,
	productType: ProductType,
	name: string,
	description: string,
	paidBonusAvailable: boolean,
	isAvailable: boolean,
	error: string?,
}

export type ReceiptInfo = {
	purchaseToken: string,
	playerId: string?,
	productId: string,
	paidRandomAllowed: boolean?,
	geAmount: number?,
}

export type PurchaseResult = {
	success: boolean,
	productId: string,
	alreadyApplied: boolean?,
	error: string?,
}

local CATALOG: { [string]: ProductDef } = table.freeze({
	pro_permit = table.freeze({
		productId = "pro_permit",
		productType = "gamepass",
		availableAtLaunch = true,
		name = "Pro Permit",
	}),
	buy_max = table.freeze({
		productId = "buy_max",
		productType = "gamepass",
		availableAtLaunch = true,
		name = "Buy MAX Research",
	}),
	ge_pack_small = table.freeze({
		productId = "ge_pack_small",
		productType = "developer_product",
		availableAtLaunch = true,
		defaultGEAmount = 1000,
		name = "Small Golden Egg Pack",
	}),
	ge_pack_large = table.freeze({
		productId = "ge_pack_large",
		productType = "developer_product",
		availableAtLaunch = true,
		defaultGEAmount = 10000,
		name = "Large Golden Egg Pack",
	}),
	piggy_break = table.freeze({
		productId = "piggy_break",
		productType = "developer_product",
		availableAtLaunch = true,
		requiresPiggy = true,
		name = "Break Piggy Bank",
	}),
	auto_hatch = table.freeze({
		productId = "auto_hatch",
		productType = "gamepass",
		availableAtLaunch = false, -- Out of launch scope (docs/26 L15)
		name = "Auto-Hatch Bot",
	}),
	vip = table.freeze({
		productId = "vip",
		productType = "gamepass",
		availableAtLaunch = false, -- Out of launch scope (docs/26 L16)
		name = "VIP Membership",
	}),
})

-- Discloses transparent terms and eligibility before purchase (Variant A - docs/26 R).
local function previewPurchase(
	profile: any,
	productId: string,
	playerContext: PlayerContext?,
	isPiggyEnabled: boolean?
): PurchasePreview
	local def = CATALOG[productId]
	if not def then
		return {
			productId = productId,
			productType = "developer_product",
			name = "Unknown Product",
			description = "Unknown product",
			paidBonusAvailable = false,
			isAvailable = false,
			error = "UNKNOWN_PRODUCT",
		}
	end

	if not def.availableAtLaunch then
		return {
			productId = productId,
			productType = def.productType,
			name = def.name,
			description = "This product is unavailable at launch.",
			paidBonusAvailable = false,
			isAvailable = false,
			error = "PRODUCT_UNAVAILABLE_AT_LAUNCH",
		}
	end

	if def.requiresPiggy and isPiggyEnabled ~= true then
		return {
			productId = productId,
			productType = def.productType,
			name = def.name,
			description = "Piggy bank is disabled pending release calibration.",
			paidBonusAvailable = false,
			isAvailable = false,
			error = "PIGGY_DISABLED",
		}
	end

	if def.productType == "gamepass" and profile and profile.entitlements and profile.entitlements[productId] == true then
		return {
			productId = productId,
			productType = def.productType,
			name = def.name,
			description = "You already own this permanent gamepass.",
			paidBonusAvailable = false,
			isAvailable = false,
			error = "ALREADY_OWNED",
		}
	end

	local paidBonusAvailable = true
	local desc = def.name

	if productId == "pro_permit" then
		paidBonusAvailable = if playerContext and playerContext.paidRandomAllowed == false then false else true
		if paidBonusAvailable then
			desc = "Pro Permit: 10 silos, 1.0x away rate, 5 boost slots, 5 pet slots, and +10 p.p. pet fusion chance."
		else
			desc = "Pro Permit: 10 silos, 1.0x away rate, 5 boost slots, and 5 pet slots. Note: Paid random chance modifier (+10 p.p.) is disabled for your account."
		end
	elseif productId == "buy_max" then
		desc = "Buy MAX Research: fast research purchase shortcut. Does not grant Pro Permit."
	end

	return {
		productId = productId,
		productType = def.productType,
		name = def.name,
		description = desc,
		paidBonusAvailable = paidBonusAvailable,
		isAvailable = true,
		error = nil,
	}
end

-- Prepare and durably reserve a purchase transaction (D07 Phase 1).
local function preparePurchase(
	profile: any,
	productId: string,
	purchaseToken: string,
	nowMs: number,
	playerContext: PlayerContext?,
	isPiggyEnabled: boolean?
): (boolean, PurchasePreview?, string?)
	assert(profile ~= nil, "Products/INVALID_PROFILE")
	assert(type(purchaseToken) == "string" and #purchaseToken > 0, "Products/INVALID_TOKEN")

	profile.operations = profile.operations or {}
	if profile.operations[purchaseToken] ~= nil then
		local existing = profile.operations[purchaseToken]
		if existing.terminalStatus == "APPLIED" then
			return false, nil, "ALREADY_APPLIED"
		elseif existing.terminalStatus == "RESERVED" then
			return false, nil, "ALREADY_RESERVED"
		end
	end

	local preview = previewPurchase(profile, productId, playerContext, isPiggyEnabled)
	if not preview.isAvailable then
		return false, preview, preview.error
	end

	local opRecord = {
		argsKey = productId,
		terminalStatus = "RESERVED",
		preparedAtMs = nowMs,
		preparedUtcDay = math.floor(nowMs / 86400000),
		productId = productId,
		paidRandomAllowed = preview.paidBonusAvailable,
		result = {},
	}

	profile.operations[purchaseToken] = opRecord
	return true, preview, nil
end

-- Confirm and atomically fulfill a purchase (D07 Phase 2). Idempotent!
local function confirmPurchase(
	profile: any,
	purchaseToken: string,
	receiptInfo: ReceiptInfo?,
	nowMs: number,
	isPiggyEnabled: boolean?
): (boolean, PurchaseResult)
	assert(profile ~= nil and profile.permanent ~= nil, "Products/INVALID_PROFILE")
	profile.operations = profile.operations or {}
	profile.entitlements = profile.entitlements or {}

	local op = profile.operations[purchaseToken]

	-- Replay protection / idempotency: return previous success without duplicate grant
	if op and op.terminalStatus == "APPLIED" then
		return true, {
			success = true,
			productId = op.productId or (receiptInfo and receiptInfo.productId) or "unknown",
			alreadyApplied = true,
		}
	end

	if op and op.terminalStatus == "REJECTED" then
		return false, {
			success = false,
			productId = op.productId or "unknown",
			error = "PURCHASE_CANCELLED",
		}
	end

	local productId = (op and op.productId) or (receiptInfo and receiptInfo.productId)
	if not productId then
		return false, { success = false, productId = "unknown", error = "MISSING_PRODUCT_ID" }
	end

	local def = CATALOG[productId]
	if not def or not def.availableAtLaunch then
		return false, { success = false, productId = productId, error = "PRODUCT_UNAVAILABLE_AT_LAUNCH" }
	end

	if def.requiresPiggy and isPiggyEnabled ~= true then
		return false, { success = false, productId = productId, error = "PIGGY_DISABLED" }
	end

	-- Execute single fulfillment
	if productId == "pro_permit" then
		profile.entitlements.pro_permit = true
		profile.entitlements.pro_permit_effective_at = nowMs
		local paidAllowed = if op then op.paidRandomAllowed else (receiptInfo and receiptInfo.paidRandomAllowed ~= false)
		profile.entitlements.pro_plus10_enabled = (paidAllowed == true)
	elseif productId == "buy_max" then
		profile.entitlements.buy_max = true
		profile.entitlements.buy_max_effective_at = nowMs
	elseif productId == "piggy_break" then
		profile.piggy = profile.piggy or {}
		local rawAmount = profile.piggy.rawAmount or 0
		local curGE = ExactUInt.decode(profile.permanent.GE)
		local addGE = ExactUInt.fromSafeNumber(rawAmount)
		profile.permanent.GE = ExactUInt.encode(ExactUInt.add(curGE, addGE))
		profile.piggy.rawAmount = 0
		profile.piggy.breaksCount = (profile.piggy.breaksCount or 0) + 1
	elseif string.sub(productId, 1, 7) == "ge_pack" then
		local geAmount = (receiptInfo and receiptInfo.geAmount) or def.defaultGEAmount or 1000
		local curGE = ExactUInt.decode(profile.permanent.GE)
		local addGE = ExactUInt.fromSafeNumber(geAmount)
		profile.permanent.GE = ExactUInt.encode(ExactUInt.add(curGE, addGE))
	end

	-- Mark operation record APPLIED
	if not op then
		op = { argsKey = productId, productId = productId }
		profile.operations[purchaseToken] = op
	end

	op.terminalStatus = "APPLIED"
	op.resultRevision = profile.meta.revision or "1"
	op.result = {
		productId = productId,
		fulfilledAtMs = nowMs,
	}

	return true, {
		success = true,
		productId = productId,
		alreadyApplied = false,
	}
end

-- Cancel a reserved purchase transaction.
local function cancelPurchase(profile: any, purchaseToken: string): (boolean, string?)
	assert(profile ~= nil and profile.operations ~= nil, "Products/INVALID_PROFILE")
	local op = profile.operations[purchaseToken]
	if not op then
		return false, "OPERATION_NOT_FOUND"
	end

	if op.terminalStatus == "APPLIED" then
		return false, "CANNOT_CANCEL_APPLIED"
	end

	op.terminalStatus = "REJECTED"
	return true, nil
end

Products.CATALOG = CATALOG
Products.previewPurchase = previewPurchase
Products.preparePurchase = preparePurchase
Products.confirmPurchase = confirmPurchase
Products.cancelPurchase = cancelPurchase

return table.freeze(Products)
