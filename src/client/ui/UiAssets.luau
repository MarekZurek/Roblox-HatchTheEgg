--!nocheck
-- Image asset integration surface for the #82 stud-style window family (ONE place to bind ids).
--
-- The UI never invents an image id. Every icon/texture the migrated windows can draw is listed
-- here with its exact local source file and an empty `id`. Root uploads those files to the game
-- owner and fills `id` (or replaces this table); until then StudUi draws no image for that key
-- and the existing text label alone carries the meaning. Nothing here is guessed.
--
-- Provenance (root reviewed the downloaded licenses, see build/issue82_assets):
--   * studui/*    - StudUI Lite 1.1.3 (free) by semajh. License: use/modify in any number of
--                   Roblox experiences (including monetized) is allowed; the kit itself may not
--                   be resold/reshared and the author may not be miscredited.
--   * gvesster/*  - Free Icon Pack v3.1 (Basic) by @gvesster. License: commercial use in a game
--                   is allowed, icons may not be resold/reshared as a pack or claimed as own.
-- Only the selected files below are used; no pack, RBXMX, demo script or example value is copied.

local STUDUI = "studui/StudUI_Lite/Upload/"
local ICONS = "gvesster/Free Icon Pack v3.1 (Basic)/"

local function asset(source, id)
	return table.freeze({ source = source, id = id or "" })
end

-- key -> { source = local file uploaded to theZuraz (11647593962), id = uploaded rbxassetid or "" }
local images = table.freeze({
	-- StudUI Lite textures (window stud pattern + accent stripe), used sparingly and transparent.
	["texture.stud"] = asset(STUDUI .. "StudUI_stud.png", "rbxassetid://131341485666607"),
	["texture.stripes"] = asset(STUDUI .. "StudUI_stripes.png"),

	-- Window headings (gvesster 256px "1st Outline" variants uploaded to theZuraz).
	["window.research"] = asset(ICONS .. "Item/Book/256px/Blue Book 1st Outline 256px.png", "rbxassetid://105864065338181"),
	["window.habitats"] = asset(ICONS .. "Main/House/256px/Green House 1st Outline 256px.png", "rbxassetid://134178063134703"),
	["window.fleet"] = asset(ICONS .. "Item/Rocket/256px/Rocket 1st Outline 256px.png", "rbxassetid://70778451286598"),
	["window.pets"] = asset(ICONS .. "Main/Paw/256px/Paw 1st Outline 256px.png", "rbxassetid://103320313492528"),
	["window.shop"] = asset(ICONS .. "Main/Shopping Cart/256px/Golden Shopping Cart 1st Outline 256px.png", "rbxassetid://117587068465023"),
	["window.calendar"] = asset(ICONS .. "Item/Calendar/256px/Calendar 1st Outline 256px.png", "rbxassetid://104025891237053"),
	["window.egg"] = asset(ICONS .. "Item/Egg/256px/Golden Egg 1st Outline 256px.png", "rbxassetid://131144454901847"),
	["window.hatch"] = asset(ICONS .. "Item/Gift/256px/Red Gift 1st Outline 256px.png", "rbxassetid://133508181437045"),

	-- Window sub-sections and tab icons.
	["tab.trophies"] = asset(ICONS .. "Item/Trophy/256w/Golden Trophy 1st Outline 256px.png", "rbxassetid://95628265314432"),
	["tab.boosts"] = asset(ICONS .. "Item/Potion/256px/Blue Potion 1st Outline 256px.png", "rbxassetid://72308823693688"),
	["tab.passes"] = asset(ICONS .. "Main/Upgrade/256px/Green Upgrade 1st Outline 256px.png", "rbxassetid://125059444460019"),
	["tab.ge"] = asset(ICONS .. "Currency/Diamond/256px/Blue Diamond 1st Outline 256px.png", "rbxassetid://123463156806216"),

	-- Shared control icons.
	["control.close"] = asset(ICONS .. "UI/Close Button/256px/Close Button 1st Outline 256px.png", "rbxassetid://113170557670552"),
	["control.lock"] = asset(ICONS .. "Item/Lock/256px/Lock 1st 256px.png"),
	["control.warning"] = asset(ICONS .. "UI/Warning/256px/Warning 1st 256px.png"),
	["control.upgrade"] = asset(ICONS .. "Main/Upgrade/256px/Green Upgrade 1st Outline 256px.png", "rbxassetid://125059444460019"),
	["control.target"] = asset(ICONS .. "Item/Target/256px/Target 1st 256px.png"),
})

return table.freeze({
	-- Bumped when root fills the 14 approved uploaded asset ids.
	manifestVersion = 1,
	-- False once all keys in images are bound; True while the 4 optional unuploaded keys remain id == "".
	uploadPending = true,
	license = table.freeze({
		studui = "StudUI Lite 1.1.3 - semajh - use/modify in games allowed, no reshare as a kit",
		gvesster = "Free Icon Pack v3.1 (Basic) - @gvesster - commercial use allowed, no resale/edits-for-resale",
	}),
	images = images,
})
