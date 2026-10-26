--!nocheck
-- Shared stud-style window family for HatchTheEgg (issue #82).
--
-- Structural adaptation of the user-selected FREE StudUI Lite 1.1.3 (window chrome, gradient
-- depth, stud texture, FredokaOne headings, centred windows) plus the selected gvesster Free Icon
-- Pack v3.1 (Basic) icons. No StudUI demo script, example counter, example product or balance is
-- copied, and no gameplay/economy/persistence behaviour lives here: this module only builds
-- presentation components for the views the game already has.
--
-- Design rules kept in one place so every migrated window matches:
--   * legible thick borders and a coloured header bar per window family,
--   * tactile action buttons with gradient depth, pressed and disabled states, >= 44px touch,
--   * restrained stud texture (one decoration pass per instance, never per update),
--   * readable text: a window is reflowed/fitted instead of globally down-scaled,
--   * images only from genuine uploaded ids (UiAssets); an unmapped key draws nothing and the
--     text label alone stays meaningful, so no fake asset is ever implied.
--
-- Instance creation is injected (`create`) so the HUD keeps its single Studio/Lune element path;
-- decoration is injected (`decorate`) so all Instance.new usage stays in the HUD.

local StudUi = {}
StudUi.__index = StudUi

local TOKENS = table.freeze({
	font = "FredokaOne",
	-- Minimum readable touch target for close buttons and every action button.
	minTouch = 44,
	radius = table.freeze({ window = 16, header = 12, card = 10, button = 10, tab = 8, slot = 10 }),
	stroke = table.freeze({ window = 3.5, header = 2, card = 1.8, button = 2, tab = 1.6 }),
	-- Restrained stud pattern: one tiled overlay at very low opacity.
	stud = table.freeze({ transparency = 0.94, tile = 64 }),
	text = table.freeze({ body = { 240, 240, 240 }, dim = { 214, 196, 184 }, gold = { 255, 235, 95 } }),
	white = table.freeze({ 255, 255, 255 }),
	black = table.freeze({ 24, 12, 10 }),
})

StudUi.TOKENS = TOKENS


-- One family per migrated window: surface, border, header gradient, accent and heading colour.
local FAMILIES = table.freeze({
	research = table.freeze({
		surface = { 62, 39, 35 }, border = { 43, 24, 16 },
		headerTop = { 104, 68, 60 }, header = { 74, 48, 42 },
		accent = { 245, 158, 11 }, title = { 255, 235, 150 }, icon = "window.research",
	}),
	habitats = table.freeze({
		surface = { 66, 38, 22 }, border = { 42, 22, 12 },
		headerTop = { 122, 70, 36 }, header = { 88, 50, 26 },
		accent = { 255, 205, 95 }, title = { 255, 240, 170 }, icon = "window.habitats",
	}),
	fleet = table.freeze({
		surface = { 48, 62, 38 }, border = { 28, 38, 22 },
		headerTop = { 84, 108, 64 }, header = { 60, 78, 46 },
		accent = { 115, 245, 125 }, title = { 190, 255, 160 }, icon = "window.fleet",
	}),
	pets = table.freeze({
		surface = { 65, 30, 60 }, border = { 36, 16, 34 },
		headerTop = { 106, 52, 98 }, header = { 76, 36, 70 },
		accent = { 245, 145, 255 }, title = { 255, 205, 255 }, icon = "window.pets",
	}),
	shop = table.freeze({
		surface = { 56, 32, 48 }, border = { 32, 16, 28 },
		headerTop = { 100, 58, 84 }, header = { 72, 40, 62 },
		accent = { 255, 215, 65 }, title = { 255, 235, 115 }, icon = "window.shop",
	}),
	calendar = table.freeze({
		surface = { 48, 32, 58 }, border = { 24, 14, 30 },
		headerTop = { 84, 56, 100 }, header = { 60, 40, 72 },
		accent = { 255, 175, 75 }, title = { 255, 225, 125 }, icon = "window.calendar",
	}),
	egg = table.freeze({
		surface = { 68, 36, 22 }, border = { 40, 20, 12 },
		headerTop = { 118, 68, 40 }, header = { 86, 48, 28 },
		accent = { 255, 215, 65 }, title = { 255, 235, 130 }, icon = "window.egg",
	}),
	hatch = table.freeze({
		surface = { 55, 25, 55 }, border = { 30, 12, 30 },
		headerTop = { 96, 48, 92 }, header = { 68, 34, 66 },
		accent = { 120, 235, 140 }, title = { 255, 235, 110 }, icon = "window.hatch",
	}),
})

StudUi.FAMILIES = FAMILIES

-- Button tones: fill + gradient top + border + text. State colours are shared by every window so
-- "owned / claimed / disabled / loading" never looks different between two dialogs.
local TONES = table.freeze({
	primary = table.freeze({ fill = { 95, 235, 45 }, top = { 152, 255, 104 }, stroke = { 22, 48, 12 }, text = { 255, 255, 255 } }),
	gold = table.freeze({ fill = { 245, 158, 11 }, top = { 255, 205, 80 }, stroke = { 120, 70, 10 }, text = { 40, 22, 4 } }),
	boost = table.freeze({ fill = { 160, 60, 200 }, top = { 205, 118, 238 }, stroke = { 50, 15, 65 }, text = { 255, 255, 255 } }),
	danger = table.freeze({ fill = { 235, 65, 65 }, top = { 255, 122, 112 }, stroke = { 85, 20, 20 }, text = { 255, 255, 255 } }),
	neutral = table.freeze({ fill = { 78, 44, 66 }, top = { 116, 70, 100 }, stroke = { 32, 16, 28 }, text = { 255, 255, 255 } }),
	locked = table.freeze({ fill = { 127, 29, 29 }, top = { 176, 60, 56 }, stroke = { 69, 10, 10 }, text = { 254, 226, 226 } }),
	disabled = table.freeze({ fill = { 120, 120, 120 }, top = { 158, 158, 158 }, stroke = { 60, 60, 60 }, text = { 235, 235, 235 } }),
	expensive = table.freeze({ fill = { 156, 163, 175 }, top = { 196, 202, 212 }, stroke = { 75, 85, 99 }, text = { 255, 255, 255 } }),
	claimed = table.freeze({ fill = { 46, 120, 74 }, top = { 92, 176, 112 }, stroke = { 20, 60, 36 }, text = { 226, 255, 236 } }),
})

StudUi.TONES = TONES

-- ============================================================================
-- Pure layout maths (no instances, so they are checkable without a viewport)
-- ============================================================================

-- The desktop budget: a window may use at most ~70% of the viewport (94% on phones) and the
-- content is never globally down-scaled below this ratio. Kept identical to the historical
-- HUD.modalLayout contract that the existing UI suites assert.
function StudUi.modalSize(viewportWidth, viewportHeight, designWidth)
	local width = tonumber(viewportWidth) or 0
	local height = tonumber(viewportHeight) or 0
	if width <= 0 then width = 1280 end
	if height <= 0 then height = 720 end
	local w = math.min(1600, width * (if width < 700 then 0.94 else 0.7))
	local h = math.min(1100, height * (if height < 500 then 0.9 else 0.7))
	return w, h, math.min(1, w / math.max(540, tonumber(designWidth) or 540))
end

function StudUi.viewportMode(viewportWidth)
	local width = tonumber(viewportWidth) or 0
	if width <= 0 then return "desktop" end
	if width < 480 then return "phone" end
	if width < 700 then return "compact" end
	return "desktop"
end

-- Resolves the on-screen window size. A window keeps its design size (readable text, no global
-- scaling) and only shrinks to fit the safe area; roomy viewports may grow it toward the desktop
-- budget, but never past 1.35x its design so content is not stretched thin.
function StudUi.windowFit(viewportWidth, viewportHeight, designWidth, designHeight)
	local vw = tonumber(viewportWidth) or 0
	local vh = tonumber(viewportHeight) or 0
	if vw <= 0 then vw = 1280 end
	if vh <= 0 then vh = 720 end
	local dw = math.max(240, tonumber(designWidth) or 520)
	local dh = math.max(200, tonumber(designHeight) or 480)

	local safeWidth = math.max(200, vw - 20)
	local safeHeight = math.max(180, vh - 20)
	local budgetWidth, budgetHeight = StudUi.modalSize(vw, vh, dw)

	local width = math.min(dw, safeWidth)
	local height = math.min(dh, safeHeight)
	local mayGrow = dw >= 520
	if mayGrow and safeWidth > width then
		width = math.min(safeWidth, math.max(width, math.min(budgetWidth, dw * 1.35)))
	end
	if mayGrow and safeHeight > height then
		height = math.min(safeHeight, math.max(height, math.min(budgetHeight, dh * 1.35)))
	end

	return {
		width = width, height = height, scale = 1,
		mode = StudUi.viewportMode(vw),
		safeWidth = safeWidth, safeHeight = safeHeight,
		budgetWidth = budgetWidth, budgetHeight = budgetHeight,
		scrolls = (height < dh) or (width < dw),
	}
end

function StudUi.touchTarget(size)
	return math.max(TOKENS.minTouch, tonumber(size) or 0)
end

-- Column count for a wrapping grid/list: never below 1, never above maxColumns, and only as many
-- columns as actually fit at minCellWidth so text does not become unreadable on a phone.
function StudUi.reflowColumns(availableWidth, minCellWidth, maxColumns)
	local width = math.max(0, tonumber(availableWidth) or 0)
	local minWidth = math.max(24, tonumber(minCellWidth) or 64)
	local maxCols = math.max(1, math.floor(tonumber(maxColumns) or 1))
	local gap = 4
	return math.clamp(math.floor((width + gap) / (minWidth + gap)), 1, maxCols)
end

-- Full grid plan for the daily calendar (and any other wrapping list). Returns absolute offsets
-- inside a container of `availableWidth`, so a reflow only repositions existing cells.
function StudUi.gridPlan(count, availableWidth, minCellWidth, maxColumns, cellHeight, gap)
	local total = math.max(0, math.floor(tonumber(count) or 0))
	local width = math.max(0, tonumber(availableWidth) or 0)
	local cellWidthMin = math.max(24, tonumber(minCellWidth) or 64)
	local cellHeightWanted = math.max(24, tonumber(cellHeight) or 52)
	local gapSize = math.max(0, tonumber(gap) or 4)
	local columns = StudUi.reflowColumns(width, cellWidthMin, maxColumns)
	local cellWidth = (width - gapSize * (columns - 1)) / columns
	local rows = if total > 0 then math.ceil(total / columns) else 0

	local cells = {}
	for index = 1, total do
		local column = (index - 1) % columns
		local row = math.floor((index - 1) / columns)
		table.insert(cells, {
			index = index, column = column + 1, row = row + 1,
			x = column * (cellWidth + gapSize),
			y = row * (cellHeightWanted + gapSize),
			width = cellWidth, height = cellHeightWanted,
		})
	end

	return {
		columns = columns, rows = rows, cellWidth = cellWidth, cellHeight = cellHeightWanted,
		gap = gapSize, canvasHeight = if rows > 0 then rows * cellHeightWanted + (rows - 1) * gapSize else 0,
		cells = cells,
	}
end

-- Layout for a row list of cards: side by side while the row is roomy, stacked on a phone so the
-- price/action button keeps its readable size instead of squeezing the text column.
function StudUi.listCardLayout(availableWidth, options)
	options = options or {}
	local width = math.max(0, tonumber(availableWidth) or 0)
	local minSideBySide = tonumber(options.minSideBySide) or 420
	if width < minSideBySide then
		return {
			compact = true,
			cardHeight = tonumber(options.compactHeight) or 140,
			rowSpacing = tonumber(options.compactSpacing) or 148,
		}
	end
	return {
		compact = false,
		cardHeight = tonumber(options.height) or 90,
		rowSpacing = tonumber(options.spacing) or 96,
	}
end

-- ============================================================================
-- Component builder
-- ============================================================================

-- deps:
--   create   = function(className, properties, parent) -> instance   (the HUD's element factory)
--   decorate = function(instance, spec) -> ()                        (corners/strokes/gradients/stud)
--   isRoblox = boolean, Color3/UDim2/UDim/Vector2/Enum = the HUD's Roblox-or-mock constructors
--   assets   = the UiAssets.images table (key -> uploaded id, possibly still empty)
function StudUi.new(deps)
	assert(type(deps) == "table" and type(deps.create) == "function", "STUDUI_CREATE_REQUIRED")
	local self = setmetatable({
		create = deps.create,
		decorate = deps.decorate or function() end,
		isRoblox = deps.isRoblox == true,
		Color3 = deps.Color3, UDim2 = deps.UDim2, UDim = deps.UDim,
		Vector2 = deps.Vector2, Enum = deps.Enum,
		assets = deps.assets or {},
		manifestVersion = tonumber(deps.manifestVersion) or 0,
		_mapped = {},
		_pending = {},
		_icons = {},
	}, StudUi)
	self:_indexAssets()
	return self
end

function StudUi:_indexAssets()
	for key, entry in pairs(self.assets or {}) do
		if self:assetId(key) == nil then
			table.insert(self._pending, key)
		else
			table.insert(self._mapped, key)
		end
	end
	table.sort(self._pending)
	table.sort(self._mapped)
end

-- Returns a usable "rbxassetid://<id>" or nil. A pending key resolves to nil, never to a guess.
function StudUi:assetId(key)
	if type(key) ~= "string" or key == "" then return nil end
	local entry = self.assets and self.assets[key]
	local id = nil
	if type(entry) == "string" and entry ~= "" then id = entry
	elseif type(entry) == "table" and entry.id ~= nil then
		if type(entry.id) == "string" and entry.id ~= "" then id = entry.id
		elseif type(entry.id) == "number" and entry.id > 0 then id = string.format("%d", entry.id) end
	end
	if id == nil then return nil end
	if string.find(id, "rbxassetid://", 1, true) == 1 then return id end
	return "rbxassetid://" .. id
end

function StudUi:hasAsset(key) return self:assetId(key) ~= nil end

-- Reported by HUD:getAssetStatus() so a reviewer can see which bindings are still pending.
function StudUi:assetStatus()
	return {
		manifestVersion = self.manifestVersion,
		mapped = #self._mapped,
		pending = #self._pending,
		pendingKeys = table.clone(self._pending),
		mappedKeys = table.clone(self._mapped),
		iconsCreated = #self._icons,
	}
end

function StudUi:rgb(triple)
	return self.Color3.fromRGB(triple[1], triple[2], triple[3])
end

function StudUi:family(name)
	return FAMILIES[name] or FAMILIES.shop
end

function StudUi:tone(name)
	return TONES[name] or TONES.primary
end

function StudUi:size(spec)
	return self.UDim2.new(spec[1], spec[2], spec[3], spec[4])
end

-- ---------------------------------------------------------------------------
-- Small building blocks
-- ---------------------------------------------------------------------------

-- A plain themed label. `align` = "Left"|"Center"|"Right".
function StudUi:label(parent, spec)
	local props = {
		Name = spec.name,
		Size = self:size(spec.size),
		Position = self:size(spec.position),
		BackgroundTransparency = 1,
		Font = self.Enum.Font.FredokaOne,
		Text = spec.text or "",
		TextColor3 = self:rgb(spec.color or TOKENS.text.body),
		TextScaled = spec.scaled ~= false,
		TextWrapped = spec.wrapped == true,
		Visible = spec.visible,
		ZIndex = spec.zIndex or 1,
	}
	if spec.textSize ~= nil then props.TextScaled = false; props.TextSize = spec.textSize end
	if spec.align ~= nil and self.Enum.TextXAlignment ~= nil then
		props.TextXAlignment = self.Enum.TextXAlignment[spec.align]
	end
	if spec.valign ~= nil and self.Enum.TextYAlignment ~= nil then
		props.TextYAlignment = self.Enum.TextYAlignment[spec.valign]
	end
	local label = self.create("TextLabel", props, parent)
	self.decorate(label, { kind = "text", textStroke = spec.textStroke or 2.0, maxTextSize = spec.maxTextSize })
	return label
end

-- A window heading: FredokaOne, thick readable stroke, optional font-size cap.
function StudUi:heading(parent, spec)
	local headingSpec = table.clone(spec)
	headingSpec.textStroke = spec.textStroke or 2.4
	return self:label(parent, headingSpec)
end

-- Icon badge for a genuine uploaded image. Returns nil when the key has no id yet, so the caller
-- can lay the text out without an empty hole (and never imply a working asset).
function StudUi:iconSlot(parent, spec)
	local id = self:assetId(spec.key)
	if id == nil then return nil, nil end
	local size = spec.size or 38
	local slot = self.create("Frame", {
		Name = spec.name or "IconSlot",
		Size = self.UDim2.new(0, size, 0, size),
		Position = self:size(spec.position or { 0, 0, 0, 0 }),
		BackgroundColor3 = self:rgb(spec.background or TOKENS.white),
		BackgroundTransparency = spec.transparency or 0.12,
	}, parent)
	self.decorate(slot, { kind = "iconSlot", radius = TOKENS.radius.slot, stroke = spec.border, thickness = 1.5 })
	local image = self.create("ImageLabel", {
		Name = "IconImage",
		Size = self.UDim2.new(1, -6, 1, -6),
		Position = self.UDim2.new(0, 3, 0, 3),
		BackgroundTransparency = 1,
		Image = id,
		ImageColor3 = self:rgb(TOKENS.white),
	}, slot)
	table.insert(self._icons, image)
	return slot, image
end

-- Inline icon (no badge) used next to a menu label. nil while the key is pending.
function StudUi:inlineIcon(parent, spec)
	local id = self:assetId(spec.key)
	if id == nil then return nil end
	local image = self.create("ImageLabel", {
		Name = spec.name or "Icon",
		Size = self:size(spec.size),
		Position = self:size(spec.position),
		BackgroundTransparency = 1,
		Image = id,
		ImageColor3 = self:rgb(TOKENS.white),
		ZIndex = spec.zIndex or 2,
	}, parent)
	table.insert(self._icons, image)
	return image
end

-- ---------------------------------------------------------------------------
-- Windows, cards, buttons, tabs, scroll areas
-- ---------------------------------------------------------------------------

-- One cohesive window: surface + thick border, coloured header bar with an accent underline, an
-- icon badge only when the genuine image is bound, the FredokaOne title (and optional subtitle).
-- Returns every part so the caller keeps updating text in place instead of rebuilding the window.
function StudUi:window(spec)
	local family = self:family(spec.family)
	local designWidth = spec.designWidth or 520
	local designHeight = spec.designHeight or 480

	local frame = self.create("Frame", {
		Name = spec.name,
		Visible = spec.visible == true,
		Size = self.UDim2.new(0, designWidth, 0, designHeight),
		Position = self.UDim2.new(0.5, -designWidth / 2, 0.5, -designHeight / 2),
		BackgroundColor3 = self:rgb(family.surface),
		ZIndex = spec.zIndex or 10,
	}, spec.parent)
	self.decorate(frame, {
		kind = "window", radius = TOKENS.radius.window,
		stroke = family.border, thickness = TOKENS.stroke.window,
		gradient = { top = family.headerTop, bottom = family.surface },
		studId = self:assetId("texture.stud"), studTransparency = TOKENS.stud.transparency,
	})

	local header = self.create("Frame", {
		Name = "WindowHeader",
		Size = self.UDim2.new(1, -24, 0, spec.headerHeight or 52),
		Position = self.UDim2.new(0, 12, 0, 10),
		BackgroundColor3 = self:rgb(family.header),
	}, frame)
	self.decorate(header, {
		kind = "header", radius = TOKENS.radius.header,
		stroke = family.border, thickness = TOKENS.stroke.header,
		gradient = { top = family.headerTop, bottom = family.header },
	})

	local accent = self.create("Frame", {
		Name = "HeaderAccent",
		Size = self.UDim2.new(1, -16, 0, 4),
		Position = self.UDim2.new(0, 8, 1, -6),
		BackgroundColor3 = self:rgb(family.accent),
		BorderSizePixel = 0,
	}, header)
	self.decorate(accent, { kind = "accent", radius = 2 })

	local slot = self:iconSlot(header, {
		key = spec.iconKey or family.icon, size = 38, position = { 0, 7, 0, 7 },
		background = family.accent, border = family.border,
	})
	local textLeft = if slot ~= nil then 52 else 14
	local hasSubtitle = type(spec.subtitle) == "string" and spec.subtitle ~= ""

	local title = self:heading(header, {
		name = "WindowTitle",
		size = { 1, -(textLeft + 56), 0, if hasSubtitle then 22 else 26 },
		position = { 0, textLeft, 0, if hasSubtitle then 4 else 9 },
		text = spec.title or "",
		color = family.title,
		align = "Left",
		maxTextSize = 26,
	})

	local subtitle = nil
	if hasSubtitle then
		subtitle = self:label(header, {
			name = "WindowSubtitle",
			size = { 1, -(textLeft + 56), 0, 16 },
			position = { 0, textLeft, 0, 28 },
			text = spec.subtitle,
			color = TOKENS.text.dim,
			align = "Left",
			textSize = 12,
			textStroke = 0,
		})
	end

	return {
		frame = frame, header = header, accent = accent, iconSlot = slot,
		title = title, subtitle = subtitle, family = family,
		designWidth = designWidth, designHeight = designHeight,
	}
end

-- A content card inside a window: themed surface, thick border and optional gradient depth.
function StudUi:card(parent, spec)
	local fill = spec.fill or self:family(spec.family).surface
	local props = {
		Name = spec.name,
		Size = self:size(spec.size),
		Position = self:size(spec.position),
		BackgroundColor3 = self:rgb(fill),
		Visible = spec.visible,
		ZIndex = spec.zIndex or 2,
	}
	if spec.className == "TextButton" then
		props.Text = spec.text or ""
		props.AutoButtonColor = false
		props.Font = self.Enum.Font.FredokaOne
	end
	local card = self.create(spec.className or "Frame", props, parent)
	self.decorate(card, {
		kind = "card", radius = spec.radius or TOKENS.radius.card,
		stroke = spec.border, thickness = TOKENS.stroke.card,
		gradient = if spec.top ~= nil then { top = spec.top, bottom = fill } else nil,
	})
	return card
end

-- Tactile action button: gradient depth, thick border, >= 44px height, pressed feedback, tones.
function StudUi:button(parent, spec)
	local tone = self:tone(spec.tone or "primary")
	local height = StudUi.touchTarget(spec.height or TOKENS.minTouch)
	local btn = self.create(spec.className or "TextButton", {
		Name = spec.name,
		Text = spec.text or "",
		Visible = spec.visible ~= false,
		Size = self.UDim2.new(spec.size[1], spec.size[2], 0, height),
		Position = self:size(spec.position),
		BackgroundColor3 = self:rgb(tone.fill),
		Font = self.Enum.Font.FredokaOne,
		TextScaled = spec.scaled ~= false,
		TextColor3 = self:rgb(tone.text),
		AutoButtonColor = false,
		Active = spec.active ~= false,
		ZIndex = spec.zIndex or 3,
	}, parent)
	self.decorate(btn, {
		kind = "button", radius = spec.radius or TOKENS.radius.button,
		stroke = tone.stroke, thickness = TOKENS.stroke.button,
		gradient = { top = tone.top, bottom = tone.fill },
		pressScale = true, textStroke = spec.textStroke or 2.0, maxTextSize = spec.maxTextSize,
	})
	if type(btn) == "table" then btn._studTone = spec.tone or "primary" elseif btn.SetAttribute then btn:SetAttribute("StudTone", spec.tone or "primary") end
	if type(spec.onClick) == "function" and btn.Activated then
		btn.Activated:Connect(spec.onClick)
	end
	return btn
end

-- Window tab: same family as the buttons, with a shared active/inactive look and an optional icon.
function StudUi:tabButton(parent, spec)
	local tab = self:button(parent, {
		name = spec.name, text = spec.text or "",
		size = spec.size, position = spec.position,
		height = StudUi.touchTarget(spec.height or 40),
		tone = if spec.active then "gold" else "neutral",
		onClick = spec.onClick, textStroke = spec.textStroke or 1.8,
		maxTextSize = spec.maxTextSize, zIndex = spec.zIndex,
	})
	if type(tab) == "table" then tab._studActive = spec.active == true elseif tab.SetAttribute then tab:SetAttribute("StudActive", spec.active == true) end
	if spec.iconKey ~= nil then
		self:inlineIcon(tab, {
			key = spec.iconKey, name = "TabIcon",
			size = { 0, 22, 0, 22 }, position = { 0, 6, 0.5, -11 },
		})
	end
	return tab
end

function StudUi:setTabActive(tab, isActive)
	if tab == nil then return end
	if type(tab) == "table" then tab._studActive = isActive == true elseif tab.SetAttribute then tab:SetAttribute("StudActive", isActive == true) end
	self:setButtonTone(tab, if isActive then "gold" else "neutral")
end

-- Applies a tone to an existing button (used by the state updates instead of ad-hoc colours).
function StudUi:setButtonTone(btn, toneName)
	if btn == nil then return end
	local tone = self:tone(toneName)
	if type(btn) == "table" then btn._studTone = toneName elseif btn.SetAttribute then btn:SetAttribute("StudTone", toneName) end
	if not self.isRoblox then return end
	btn.BackgroundColor3 = self:rgb(tone.fill)
	btn.TextColor3 = self:rgb(tone.text)
	local stroke = btn:FindFirstChildOfClass("UIStroke")
	if stroke ~= nil then stroke.Color = self:rgb(tone.stroke) end
	local gradient = btn:FindFirstChildOfClass("UIGradient")
	if gradient ~= nil then gradient.Color = ColorSequence.new(self:rgb(tone.top), self:rgb(tone.fill)) end
end

-- Consistent scroll area: thin themed scrollbar, no border, canvas height set by the caller.
function StudUi:scroll(parent, spec)
	return self.create("ScrollingFrame", {
		Name = spec.name,
		Size = self:size(spec.size),
		Position = self:size(spec.position),
		BackgroundTransparency = if spec.fill ~= nil then 0 else 1,
		BackgroundColor3 = if spec.fill ~= nil then self:rgb(spec.fill) else nil,
		BorderSizePixel = 0,
		ScrollBarThickness = spec.scrollBarThickness or 6,
		ScrollBarImageColor3 = if spec.scrollBarColor ~= nil then self:rgb(spec.scrollBarColor) else nil,
		CanvasSize = self.UDim2.new(0, 0, 0, spec.canvasHeight or 0),
		Visible = spec.visible,
		ZIndex = spec.zIndex or 2,
	}, parent)
end

-- Themed status pill / banner: a TextLabel with a real background, so existing text getters
-- (badge.Text, lock-banner.Text) keep working while the look matches the window family.
function StudUi:pill(parent, spec)
	local tone = self:tone(spec.tone or "neutral")
	local props = {
		Name = spec.name,
		Size = self:size(spec.size),
		Position = self:size(spec.position),
		BackgroundColor3 = self:rgb(spec.fill or tone.fill),
		BackgroundTransparency = spec.transparency or 0,
		Font = self.Enum.Font.FredokaOne,
		Text = spec.text or "",
		TextColor3 = self:rgb(spec.color or tone.text),
		TextScaled = spec.scaled ~= false,
		TextWrapped = spec.wrapped == true,
		Visible = spec.visible,
		ZIndex = spec.zIndex or 2,
	}
	if spec.align ~= nil and self.Enum.TextXAlignment ~= nil then
		props.TextXAlignment = self.Enum.TextXAlignment[spec.align]
	end
	if spec.valign ~= nil and self.Enum.TextYAlignment ~= nil then
		props.TextYAlignment = self.Enum.TextYAlignment[spec.valign]
	end
	local pill = self.create("TextLabel", props, parent)
	self.decorate(pill, {
		kind = "pill", radius = spec.radius or 8,
		stroke = spec.stroke or tone.stroke, thickness = spec.thickness or 1.5,
		textStroke = spec.textStroke or 1.6, maxTextSize = spec.maxTextSize,
	})
	if type(pill) == "table" then pill._studTone = spec.tone or "neutral" elseif pill.SetAttribute then pill:SetAttribute("StudTone", spec.tone or "neutral") end
	return pill
end

-- Recolours an existing pill (status badge / lock banner) without touching its text.
function StudUi:setPillTone(pill, toneName)
	if pill == nil then return end
	local tone = self:tone(toneName)
	if type(pill) == "table" then pill._studTone = toneName elseif pill.SetAttribute then pill:SetAttribute("StudTone", toneName) end
	if not self.isRoblox then return end
	pill.BackgroundColor3 = self:rgb(tone.fill)
	pill.TextColor3 = self:rgb(tone.text)
	local stroke = pill:FindFirstChildOfClass("UIStroke")
	if stroke ~= nil then stroke.Color = self:rgb(tone.stroke) end
end

-- The window close control: 44x44, danger tone, image only when "control.close" is bound.
function StudUi:closeButton(parent, onClose, spec)
	spec = spec or {}
	local size = StudUi.touchTarget(spec.size or TOKENS.minTouch)
	local btn = self:button(parent, {
		name = "CloseBtn", text = "X", tone = "danger",
		size = { 0, size }, position = spec.position or { 1, -(size + 6), 0, 6 },
		height = size, textStroke = 2.4, zIndex = 20,
	})
	local id = self:assetId(spec.key or "control.close")
	if id ~= nil then
		btn.Text = ""
		local image = self.create("ImageLabel", {
			Name = "CloseIcon",
			Size = self.UDim2.new(1, -14, 1, -14),
			Position = self.UDim2.new(0, 7, 0, 7),
			BackgroundTransparency = 1,
			Image = id,
			ImageColor3 = self:rgb(TOKENS.white),
			ZIndex = 21,
		}, btn)
		table.insert(self._icons, image)
	end
	if type(onClose) == "function" and btn.Activated then
		btn.Activated:Connect(onClose)
	end
	return btn
end

-- ============================================================================
-- Responsive application (event driven: one AbsoluteSize connection per surface)
-- ============================================================================

-- Fits a window to the viewport without globally shrinking its text, then reports the resolved
-- layout to `onLayout(fit, viewportSize)` so lists can reflow (columns collapse, canvases grow).
function StudUi:applyWindowResponsive(frame, root, designWidth, designHeight, onLayout)
	if not self.isRoblox or frame == nil or root == nil then return end
	local scale = frame:FindFirstChild("WindowScale")
	if scale == nil then
		scale = self.create("UIScale", { Name = "WindowScale", Scale = 1 }, frame)
	end
	frame.AnchorPoint = self.Vector2.new(0.5, 0.5)
	frame.Position = self.UDim2.new(0.5, 0, 0.5, 0)
	local function resize()
		local viewport = root.AbsoluteSize
		if viewport == nil or viewport.X <= 0 or viewport.Y <= 0 then return end
		local fit = StudUi.windowFit(viewport.X, viewport.Y, designWidth, designHeight)
		scale.Scale = fit.scale
		frame.Size = self.UDim2.fromOffset(fit.width, fit.height)
		if type(onLayout) == "function" then onLayout(fit, viewport) end
	end
	local connection = root:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	frame.Destroying:Connect(function() connection:Disconnect() end)
	resize()
end

-- Repositions existing grid cells for the current scroll width (no re-creation, no per-frame work).
function StudUi:applyGridReflow(scroll, cells, options)
	if not self.isRoblox or scroll == nil or type(cells) ~= "table" or #cells == 0 then return end
	options = options or {}
	local padding = options.padding or 6
	local function reflow()
		local size = scroll.AbsoluteSize
		if size == nil or size.X <= 0 then return end
		local plan = StudUi.gridPlan(
			#cells, math.max(0, size.X - padding * 2),
			options.minCellWidth or 64, options.maxColumns or 7,
			options.cellHeight or 52, options.gap or 4)
		for index, cell in ipairs(cells) do
			local slot = plan.cells[index]
			if slot ~= nil then
				cell.Size = self.UDim2.fromOffset(slot.width, slot.height)
				cell.Position = self.UDim2.fromOffset(padding + slot.x, padding + slot.y)
			end
		end
		scroll.CanvasSize = self.UDim2.fromOffset(0, plan.canvasHeight + padding * 2)
		if type(options.onPlan) == "function" then options.onPlan(plan, size) end
	end
	local connection = scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(reflow)
	scroll.Destroying:Connect(function() connection:Disconnect() end)
	reflow()
end

return StudUi
