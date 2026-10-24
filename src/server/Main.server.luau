--!nocheck
-- Main Server Entrypoint for HatchTheEgg (VIS-01, VIS-02, VIS-03).
-- Automatically starts the authoritative server in Roblox Studio:
-- 1. Creates ReplicatedStorage/HatchTheEgg/Remotes (ClientToServer & ServerToClient RemoteEvents).
-- 2. Generates the 3D Candy & Chocolate Farm Island world via FarmPlotBuilder.
-- 3. Manages player sessions (PlayerAdded / PlayerRemoving) via ServerBootstrap.
-- 4. Runs authoritative simulation ticks and replicates StateSnapshot / StateDelta views.

local isRoblox = (typeof(game) == "Instance")
if not isRoblox then
	return {}
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerBootstrap = require(script.Parent.Bootstrap)
local FarmPlotBuilder = require(script.Parent.world.FarmPlotBuilder)

local function resolveNumericPlayerId(player)
	local uid = player and player.UserId or 1
	if type(uid) == "number" and uid > 0 then
		return tostring(math.floor(uid))
	end
	return tostring(math.abs(tonumber(uid) or 1) + 1000)
end

-- 1. Ensure ReplicatedStorage/HatchTheEgg/Remotes exists
local rootFolder = ReplicatedStorage:FindFirstChild("HatchTheEgg")
if not rootFolder then
	rootFolder = Instance.new("Folder")
	rootFolder.Name = "HatchTheEgg"
	rootFolder.Parent = ReplicatedStorage
end

local remotesFolder = rootFolder:FindFirstChild("Remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = rootFolder
end

local clientToServer = remotesFolder:FindFirstChild("ClientToServer")
if not clientToServer then
	clientToServer = Instance.new("RemoteEvent")
	clientToServer.Name = "ClientToServer"
	clientToServer.Parent = remotesFolder
end

local serverToClient = remotesFolder:FindFirstChild("ServerToClient")
if not serverToClient then
	serverToClient = Instance.new("RemoteEvent")
	serverToClient.Name = "ServerToClient"
	serverToClient.Parent = remotesFolder
end

-- 2. Generate the 3D Candy & Chocolate Farm Island World in Workspace
local worldBuilder = FarmPlotBuilder.new()
worldBuilder:build()

-- 3. Initialize Authoritative ServerBootstrap
local server = ServerBootstrap.new({
	initialNowMs = 1000000,
})

local activePlayerObjects = {} -- [pId] = Player

local function syncWorldAndDelta(pId, playerObj)
	local delta = server:createPlayerDelta(pId)
	if delta and playerObj and playerObj.Parent == Players then
		local farmChanges = delta.changes and delta.changes.farm
		if farmChanges and next(farmChanges) ~= nil then
			serverToClient:FireClient(playerObj, delta)
		end
	end

	-- Update 3D Diegetic Billboards & Buy Pads in Workspace from authoritative projection
	local pState = server:getGateway():getPlayerState(pId)
	if pState and pState.previousOwnView and pState.previousOwnView.farm then
		worldBuilder:updateFromFarmView(pState.previousOwnView.farm, server.catalog)
	end
end

-- 4. Player Lifecycle (PlayerAdded & PlayerRemoving)
local function onPlayerAdded(player)
	local pId = resolveNumericPlayerId(player)
	activePlayerObjects[pId] = player

	local joinRes, err = server:playerJoined(pId)
	if not joinRes then
		warn("[HatchTheEgg Server] Failed to acquire session for player " .. tostring(pId) .. ": " .. tostring(err))
		return
	end

	-- Position character on the Farm SpawnLocation when character loads
	player.CharacterAdded:Connect(function(character)
		task.defer(function()
			local hrp = character:WaitForChild("HumanoidRootPart", 5)
			if hrp then
				hrp.CFrame = CFrame.new(
					FarmPlotBuilder.SPAWN_LOCATION_POS.x,
					FarmPlotBuilder.SPAWN_LOCATION_POS.y + 3.5,
					FarmPlotBuilder.SPAWN_LOCATION_POS.z
				)
			end
		end)
	end)
end

local function onPlayerRemoving(player)
	local pId = resolveNumericPlayerId(player)
	activePlayerObjects[pId] = nil
	server:playerLeaving(pId)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, existingPlayer in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, existingPlayer)
end

-- 5. Handle Incoming Client Protocol Messages
clientToServer.OnServerEvent:Connect(function(player, message)
	if type(message) ~= "table" then
		return
	end
	local pId = resolveNumericPlayerId(player)
	if not server:getPlayer(pId) then
		onPlayerAdded(player)
	end

	local response = server:dispatch(pId, message)
	if response then
		serverToClient:FireClient(player, response)
	end

	if message.kind == "Bootstrap" or message.kind == "RefreshState" then
		if response and response.view and response.view.farm then
			worldBuilder:updateFromFarmView(response.view.farm, server.catalog)
		end
	elseif
		message.kind == "BuyResearch"
		or message.kind == "BuyHabitat"
		or message.kind == "BuyVehicle"
		or message.kind == "HatchPress"
		or message.kind == "HatchInput"
	then
		syncWorldAndDelta(pId, player)
	end
end)

-- 6. Authoritative Server Simulation Loop (0.5s steps)
task.spawn(function()
	while true do
		task.wait(0.5)
		server:tick(0.5)
		for pId, playerObj in pairs(activePlayerObjects) do
			syncWorldAndDelta(pId, playerObj)
		end
	end
end)
