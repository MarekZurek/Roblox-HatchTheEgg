--!nocheck
-- Main Client Entrypoint for HatchTheEgg (VIS-01, VIS-03, VIS-04, VIS-05).
-- Wires the client runtime in Roblox Studio:
-- 1. Connects ClientBootstrap to ReplicatedStorage/HatchTheEgg/Remotes.
-- 2. Mounts the Candy & Studs HUD in PlayerGui and wires TutorialController.
-- 3. Connects 3D Physical Pressure Plate, Studded Step-On Buy Pads, and ProximityPrompts
--    to authoritative client intents (HatchPress, BuyHabitat, BuyVehicle, BuyResearch).
-- 4. Drives 60 FPS 3D Kawaii Chicken route interpolation and flying Candy Drones.

local isRoblox = (typeof(game) == "Instance")
if not isRoblox then
	return {}
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ProximityPromptService = game:GetService("ProximityPromptService")

local ClientBootstrap = require(script.Parent.Bootstrap)
local TutorialController = require(script.Parent.onboarding.TutorialController)

local localPlayer = Players.LocalPlayer
if not localPlayer then
	return {}
end

local function resolveNumericPlayerId(player)
	local uid = player and player.UserId or 1
	if type(uid) == "number" and uid > 0 then
		return tostring(math.floor(uid))
	end
	return tostring(math.abs(tonumber(uid) or 1) + 1000)
end

local playerGui = localPlayer:WaitForChild("PlayerGui")
local hteRoot = ReplicatedStorage:WaitForChild("HatchTheEgg", 15)
local remotesFolder = hteRoot and hteRoot:WaitForChild("Remotes", 15)
local clientToServer = remotesFolder and remotesFolder:WaitForChild("ClientToServer", 15)
local serverToClient = remotesFolder and remotesFolder:WaitForChild("ServerToClient", 15)

-- Container in Workspace for 3D running kawaii chickens and flying candy drones
local chickensContainer = Workspace:FindFirstChild("HatchTheEggVisualActors")
if not chickensContainer then
	chickensContainer = Instance.new("Folder")
	chickensContainer.Name = "HatchTheEggVisualActors"
	chickensContainer.Parent = Workspace
end

local screenGui = playerGui:FindFirstChild("HatchTheEggHUD")
if screenGui then
	screenGui:ClearAllChildren()
else
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "HatchTheEggHUD"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui
end

-- Helper to determine next habitat upgrade for a slot (1..4) with automatic quote resolution
local client
local pendingQuotedPurchase = nil

local function upgradeHabitatSlot(slotId)
	if not client or not client:getStore():isReady() then return end
	local farm = client:getFarm()
	if not farm or type(farm.habitats) ~= "table" then return end

	local targetSlot = slotId or 1
	if slotId == nil then
		-- Pick first empty or upgradeable slot
		for s = 1, 4 do
			local h = farm.habitats[s]
			if h and (h.habitatIndex == nil or h.habitatIndex < 1) then
				targetSlot = s
				break
			end
		end
	end

	local hab = farm.habitats[targetSlot]
	local currentIdx = hab and hab.habitatIndex
	local nextHabitatId = if currentIdx == nil then "COOP" else "SHACK"
	local reqId, err = client:buyHabitat(targetSlot, nextHabitatId)
	if not reqId and err == "MISSING_QUOTE" then
		pendingQuotedPurchase = function()
			client:buyHabitat(targetSlot, nextHabitatId)
		end
		client:requestQuote({ kind = "BuyHabitat", args = { slotId = targetSlot, habitatId = nextHabitatId } })
	end
end

local function upgradeVehicleSlot(slotId)
	if not client or not client:getStore():isReady() then return end
	local farm = client:getFarm()
	if not farm or not farm.fleet then return end

	local targetSlot = slotId or 1
	local currentIdx = nil
	for _, v in ipairs(farm.fleet.vehicles or {}) do
		if v.slotId == targetSlot then
			currentIdx = v.vehicleIndex
		end
	end
	local nextVehicleId = if currentIdx == nil then "TRIKE" else "TRANSIT VAN"
	local reqId, err = client:buyVehicle(targetSlot, nextVehicleId)
	if not reqId and err == "MISSING_QUOTE" then
		pendingQuotedPurchase = function()
			client:buyVehicle(targetSlot, nextVehicleId)
		end
		client:requestQuote({ kind = "BuyVehicle", args = { slotId = targetSlot, vehicleId = nextVehicleId } })
	end
end

local function buyResearchWithQuote(researchId)
	if not client or not client:getStore():isReady() or not researchId then return end
	local reqId, err = client:buyResearch(researchId)
	if not reqId and err == "MISSING_QUOTE" then
		pendingQuotedPurchase = function()
			client:buyResearch(researchId)
		end
		client:requestQuote({ kind = "BuyResearch", args = { researchId = researchId, mode = "single" } })
	end
end

-- Initialize ClientBootstrap
client = ClientBootstrap.new({
	playerId = resolveNumericPlayerId(localPlayer),
	guiRoot = screenGui,
	modelsContainer = chickensContainer,
	wire = function(msg)
		if clientToServer then
			clientToServer:FireServer(msg)
		end
	end,
})

_G.HatchTheEggClient = client
shared.HatchTheEggClient = client

local hud = client:getHUD()
if hud then
	hud.onQuickBuyResearch = function(researchId)
		buyResearchWithQuote(researchId or "comfy_nests")
	end
	hud.onQuickBuyHabitat = function(slotId)
		upgradeHabitatSlot(slotId)
	end
	hud.onQuickBuyVehicle = function(slotId)
		upgradeVehicleSlot(slotId)
	end
end

local tutorialController = TutorialController.new(client:getStore(), screenGui)

-- Listen to ServerToClient RemoteEvent
if serverToClient then
	serverToClient.OnClientEvent:Connect(function(message)
		client:receive(message)
		if type(message) == "table" and (message.kind == "QuoteView" or message.kind == "GetPurchaseQuote") and pendingQuotedPurchase then
			local fn = pendingQuotedPurchase
			pendingQuotedPurchase = nil
			fn()
		end
	end)
end

-- Update tutorial banner when state changes
local localClockMs = 1000000
client:getStore():onStateChanged(function()
	local obs = client:getStore():getServerObservedAt()
	if type(obs) == "number" and obs > localClockMs then
		localClockMs = obs
	end

	local farm = client:getFarm()
	if farm and hud and hud.tutorialLabel then
		local totalPop = hud.totalChickensCount or 0
		local hasResearch = false
		for _, r in ipairs(farm.common or {}) do
			if (r.level or 0) > 0 then
				hasResearch = true
				break
			end
		end
		local hasUpgradedHab = false
		for s = 1, 4 do
			local h = farm.habitats and farm.habitats[s]
			if h and ((s == 1 and (h.habitatIndex or 0) > 0) or (s > 1 and h.habitatIndex ~= nil)) then
				hasUpgradedHab = true
				break
			end
		end

		if type(farm.tutorialStep) == "number" then
			tutorialController:setStep(farm.tutorialStep)
		elseif totalPop == 0 then
			tutorialController:setStep(1)
		elseif not hasResearch then
			tutorialController:setStep(2)
		elseif not hasUpgradedHab then
			tutorialController:setStep(3)
		else
			tutorialController:setStep(4)
		end

		local info = tutorialController:getCurrentStepInfo()
		if info.isCompleted then
			hud.tutorialLabel.Text = "🎉 " .. info.title .. " " .. info.instruction
		else
			hud.tutorialLabel.Text = string.format("🎯 Krok %d/4: %s — %s", info.step, info.title, info.instruction)
		end

		-- Refresh quotes for visible shop research items when shop is open
		if hud.shopFrame and hud.shopFrame.Visible then
			for _, rId in ipairs({
				"comfy_nests",
				"nutritional_sup",
				"better_incubators",
				"hab_capacity1",
				"internal_hatchery1",
				"hatchery_expansion",
				"leafsprings",
			}) do
				client:requestQuote({ kind = "BuyResearch", args = { researchId = rId, mode = "single" } })
			end
		end
	end
end)

-- Connect to server and request initial StateSnapshot
task.spawn(function()
	task.wait(0.2)
	client:connect("boot-studio-1")
end)

-- ============================================================================
-- Wire 3D ProximityPrompts (Hatchery, Habitats, Research Stall, Shipping Depot)
-- ============================================================================

ProximityPromptService.PromptTriggered:Connect(function(prompt, playerWhoTriggered)
	if playerWhoTriggered ~= localPlayer then return end
	if not client:getStore():isReady() then return end

	local pName = prompt.Name
	if pName == "HatchProximityPrompt" then
		client:hatchPress()
	elseif pName == "HabitatProximityPrompt" then
		local slotId = prompt:GetAttribute("SlotId") or 1
		upgradeHabitatSlot(slotId)
		if hud then
			hud:toggleHabitatsModal(true)
		end
	elseif pName == "ResearchProximityPrompt" then
		if hud then
			hud:toggleResearchModal(true)
			for _, rId in ipairs({
				"comfy_nests",
				"nutritional_sup",
				"better_incubators",
				"hab_capacity1",
				"internal_hatchery1",
				"hatchery_expansion",
				"leafsprings",
			}) do
				client:requestQuote({ kind = "BuyResearch", args = { researchId = rId, mode = "single" } })
			end
		end
	elseif pName == "DepotProximityPrompt" then
		upgradeVehicleSlot(1)
	end
end)

-- ============================================================================
-- Wire 3D Step-On Pressure Plate & Studded Buy Pads + 60 FPS Presentation Loop
-- ============================================================================

local lastHatchStepAt = 0
local padCooldowns = {} -- [Instance] = os.clock()
local nextDroneSpawnAt = os.clock() + 6.0
local droneSerial = 0

local function isCharacterTouchingPart(character, part)
	if not character or not part or not part:IsA("BasePart") then
		return false
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return false
	end
	local okParts, parts = pcall(function()
		return Workspace:GetPartsInPart(part)
	end)
	if okParts and type(parts) == "table" then
		for _, hit in ipairs(parts) do
			if hit:IsDescendantOf(character) then
				return true
			end
		end
	end
	-- Fallback horizontal + vertical bounding box check
	local diff = hrp.Position - part.Position
	local half = part.Size * 0.5
	if math.abs(diff.X) <= (half.X + 1.5) and math.abs(diff.Z) <= (half.Z + 1.5) and math.abs(diff.Y) <= 5.5 then
		return true
	end
	return false
end

RunService.RenderStepped:Connect(function(dt)
	localClockMs += math.floor(dt * 1000 + 0.5)
	client:update(localClockMs)

	local nowClock = os.clock()

	-- Spawn periodic visual Candy Drones overhead
	if nowClock >= nextDroneSpawnAt and client:getStore():isReady() then
		nextDroneSpawnAt = nowClock + 14.0
		droneSerial += 1
		local dId = "drone-" .. tostring(droneSerial)
		local isElite = (droneSerial % 3 == 0)
		client:getPresentation():spawnDrone(dId, isElite, localClockMs, 10.0)
	end

	-- Physical Step-On Pads check
	local character = localPlayer.Character
	local worldFolder = Workspace:FindFirstChild("HatchTheEggWorld")
	if not character or not worldFolder or not client:getStore():isReady() then
		return
	end

	-- 1. Check Red Hatchery Pressure Plate
	local hatchery = worldFolder:FindFirstChild("Hatchery")
	local pressurePlate = hatchery and hatchery:FindFirstChild("HatchPressurePlate")
	if pressurePlate then
		local standing = isCharacterTouchingPart(character, pressurePlate)
		if standing then
			pressurePlate.Color = Color3.fromRGB(255, 135, 145)
			if nowClock - lastHatchStepAt >= 0.28 then
				lastHatchStepAt = nowClock
				client:hatchPress()
			end
		else
			pressurePlate.Color = Color3.fromRGB(255, 58, 75)
		end
	end

	-- 2. Check All Studded Step-On Buy Pads (Habitats, Vehicles, Research)
	for _, desc in ipairs(worldFolder:GetDescendants()) do
		if desc.Name == "TouchPlate" and desc:IsA("BasePart") then
			local padKind = desc:GetAttribute("PadKind")
			if padKind then
				local touching = isCharacterTouchingPart(character, desc)
				local lastTriggered = padCooldowns[desc] or 0
				if touching and (nowClock - lastTriggered >= 1.25) then
					padCooldowns[desc] = nowClock
					if padKind == "BuyHabitat" then
						local slotId = desc:GetAttribute("SlotId") or 1
						upgradeHabitatSlot(slotId)
					elseif padKind == "BuyVehicle" then
						local slotId = desc:GetAttribute("SlotId") or 1
						upgradeVehicleSlot(slotId)
					elseif padKind == "BuyResearch" then
						local rId = desc:GetAttribute("ResearchId")
						if rId then
							buyResearchWithQuote(rId)
						end
					end
				end
			end
		end
	end
end)
