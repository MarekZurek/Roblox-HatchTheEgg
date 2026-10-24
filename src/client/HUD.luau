--!nocheck
-- HUD for HatchTheEgg.
-- Minimal HUD and user interface binding for HatchTheEgg:
-- 1. Numeric formatting for UI display (K, M, B, T suffixes) - presentation only, NEVER parsed back into domain numbers.
-- 2. StateStore subscription:
--    - Economy balances: cash, producedEggsPerSecond, soldEggsPerSecond, shippingPerMinute.
--    - Hatchery indicator: stock / capacity and refill rate.
--    - Habitat coops 1..4: population / capacity.
--    - Shop view: Common research, habitats, vehicles with quote prices and button states (active or blocked by TIER_LOCKED, MAX_LEVEL, INSUFFICIENT_CASH).
--    - Session status banner: CONNECTING, LOADING, READY, RESYNCING, SESSION_LOST.
-- 3. Compatible with pure Lune mock GUI and Roblox Studio instances (ScreenGui, Frame, TextLabel, TextButton).
--
-- CRITICAL ARCHITECTURAL INVARIANT:
-- HUD and controllers NEVER modify authoritative state, grant resources, or alter economy balances.

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
-- GUI Instance Helpers (Studio & Lune Mock)
-- ============================================================================

local isRoblox = (typeof(Instance) == "table" and type(Instance.new) == "function")

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
		guiRoot = createGuiElement("ScreenGui", { Name = "HatchTheEggHUD" })
	end

	local self = setmetatable({
		stateStore = deps.stateStore,
		intentControllers = deps.intentControllers,
		codec = deps.codec,
		guiRoot = guiRoot,

		-- Cached view data
		sessionStatus = "CONNECTING",
		hatcheryRatio = 0,
		habitatFillRatios = { 0, 0, 0, 0 },
		habitatPopulations = { "0", "0", "0", "0" },
		habitatCapacities = { "0", "0", "0", "0" },

		-- UI Component hierarchy
		sessionBanner = nil,
		sessionStatusLabel = nil,
		cashLabel = nil,
		producedEggsLabel = nil,
		soldEggsLabel = nil,
		shippingLabel = nil,
		hatcheryStockLabel = nil,
		hatcheryRefillLabel = nil,
		hatchButton = nil,
		habitatCards = {},
		habitatLabels = {},
		shopResearch = {},
		shopHabitats = {},
		shopVehicles = {},

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
	self.sessionBanner = createGuiElement("Frame", { Name = "SessionBanner" }, root)
	self.sessionStatusLabel = createGuiElement("TextLabel", {
		Name = "StatusLabel",
		Text = "CONNECTING",
	}, self.sessionBanner)

	-- 2. Top Bar (Cash & Global Rates)
	local topBar = createGuiElement("Frame", { Name = "TopBar" }, root)
	self.cashLabel = createGuiElement("TextLabel", { Name = "CashLabel", Text = "$0" }, topBar)
	self.producedEggsLabel = createGuiElement("TextLabel", { Name = "ProducedEggsLabel", Text = "0/s" }, topBar)
	self.soldEggsLabel = createGuiElement("TextLabel", { Name = "SoldEggsLabel", Text = "0/s" }, topBar)
	self.shippingLabel = createGuiElement("TextLabel", { Name = "ShippingLabel", Text = "0/min" }, topBar)

	-- 3. Hatchery Control Frame
	local hatcheryFrame = createGuiElement("Frame", { Name = "HatcheryFrame" }, root)
	self.hatcheryStockLabel = createGuiElement("TextLabel", { Name = "StockLabel", Text = "0 / 0" }, hatcheryFrame)
	self.hatcheryRefillLabel = createGuiElement("TextLabel", { Name = "RefillLabel", Text = "+0/s" }, hatcheryFrame)
	self.hatchButton = createGuiElement("TextButton", { Name = "HatchButton", Text = "HATCH" }, hatcheryFrame)

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

	-- 4. Habitats Frame (Coops 1..4)
	local habitatsFrame = createGuiElement("Frame", { Name = "HabitatsFrame" }, root)
	for slotId = 1, 4 do
		local card = createGuiElement("Frame", { Name = "HabitatCard_" .. tostring(slotId) }, habitatsFrame)
		local popLabel = createGuiElement("TextLabel", { Name = "PopulationLabel", Text = "0 / 0" }, card)
		self.habitatCards[slotId] = card
		self.habitatLabels[slotId] = popLabel
	end

	-- 5. Shop Frame
	self.shopFrame = createGuiElement("Frame", { Name = "ShopFrame" }, root)
end

function HUD:_setupSubscriptions()
	-- Subscribe to ClientStateStore status changes
	if self.stateStore ~= nil and type(self.stateStore.onStatusChanged) == "function" then
		table.insert(self._unsubs, self.stateStore:onStatusChanged(function(newStatus)
			self:updateStatus(newStatus)
		end))
	end

	-- Subscribe to ClientStateStore state changes (snapshots & deltas)
	if self.stateStore ~= nil and type(self.stateStore.onStateChanged) == "function" then
		table.insert(self._unsubs, self.stateStore:onStateChanged(function()
			self:update()
		end))
	end

	-- Subscribe to transport QuoteView messages to keep shop quotes fresh
	local transport = self.intentControllers and self.intentControllers.transport
	if transport ~= nil and type(transport.onQuote) == "function" then
		table.insert(self._unsubs, transport:onQuote(function(quoteView)
			self:onQuoteReceived(quoteView)
		end))
	end
end

-- ============================================================================
-- State & View Synchronization
-- ============================================================================

function HUD:updateStatus(newStatus)
	self.sessionStatus = newStatus or self.stateStore:getStatus()
	if self.sessionStatusLabel ~= nil then
		self.sessionStatusLabel.Text = self.sessionStatus
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

	-- 2. Hatchery Stock, Capacity & Refill
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

	-- 3. Habitats 1..4 (Population / Capacity)
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
				self.habitatFillRatios[slotId] = if cNum > 0 then math.clamp(pNum / cNum, 0, 1) else 0
			end
		end
	end

	-- 4. Shop View (Common Research)
	if type(farm.common) == "table" then
		for _, research in ipairs(farm.common) do
			self:_updateResearchItem(research)
		end
	end
end

function HUD:_updateResearchItem(research)
	local id = research.researchId
	local item = self.shopResearch[id]

	if item == nil then
		local card = createGuiElement("Frame", { Name = "ResearchCard_" .. id }, self.shopFrame)
		local nameLabel = createGuiElement("TextLabel", { Name = "Title", Text = id }, card)
		local levelLabel = createGuiElement("TextLabel", { Name = "Level", Text = "Lv 0" }, card)
		local priceLabel = createGuiElement("TextLabel", { Name = "Price", Text = "$0" }, card)
		local statusLabel = createGuiElement("TextLabel", { Name = "Status", Text = "BUY" }, card)
		local buyBtn = createGuiElement("TextButton", { Name = "BuyButton", Text = "BUY" }, card)

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

	item.level = research.level
	item.levelLabel.Text = "Lv " .. tostring(research.level)

	-- Look up cached quote from ShopController
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

	-- Determine availability & blockedReason
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
	else
		item.buyButton.Active = false
		local reasonText = blockedReason or "LOCKED"
		item.statusLabel.Text = reasonText
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
			end
		end
	end
end

-- ============================================================================
-- Intent Actions (Triggered by Player UI Interactions)
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

	local quote = self.intentControllers.shop:getCachedQuote(target)
	if quote ~= nil then
		return self.intentControllers.shop:confirmPurchase(quote, callback)
	else
		return self.intentControllers.shop:requestQuote(target, function(newQuote)
			if newQuote and newQuote.kind == "QuoteView" then
				self.intentControllers.shop:confirmPurchase(newQuote, callback)
			elseif callback then
				callback({ status = "REJECTED", errorCode = "NO_QUOTE" })
			end
		end)
	end
end

-- ============================================================================
-- Accessors for UI Verification
-- ============================================================================

function HUD:getSessionStatus()
	return self.sessionStatus
end

function HUD:getCashText()
	return if self.cashLabel then self.cashLabel.Text else ""
end

function HUD:getProducedEggsText()
	return if self.producedEggsLabel then self.producedEggsLabel.Text else ""
end

function HUD:getSoldEggsText()
	return if self.soldEggsLabel then self.soldEggsLabel.Text else ""
end

function HUD:getShippingText()
	return if self.shippingLabel then self.shippingLabel.Text else ""
end

function HUD:getHatcheryText()
	return if self.hatcheryStockLabel then self.hatcheryStockLabel.Text else ""
end

function HUD:getHatcheryRatio()
	return self.hatcheryRatio
end

function HUD:getHatcheryRefillText()
	return if self.hatcheryRefillLabel then self.hatcheryRefillLabel.Text else ""
end

function HUD:getHabitatText(slotId)
	local label = self.habitatLabels[slotId]
	return if label then label.Text else ""
end

function HUD:getHabitatRatio(slotId)
	return self.habitatFillRatios[slotId] or 0
end

function HUD:getShopResearchItem(researchId)
	return self.shopResearch[researchId]
end

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
