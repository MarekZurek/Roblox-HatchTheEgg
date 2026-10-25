--!nocheck
-- Main Server Entrypoint for HatchTheEgg (VIS-01, VIS-02, VIS-03, PROD-04).
-- Automatically starts the authoritative server in Roblox Studio / Production:
-- 1. Creates ReplicatedStorage/HatchTheEgg/Remotes (ClientToServer & ServerToClient RemoteEvents).
-- 2. Connects to Roblox DataStoreService with resilient retries (falling back to memory in Studio without API access).
-- 3. Generates the 3D Farm Island world via FarmPlotBuilder.
-- 4. Manages player sessions (PlayerAdded / PlayerRemoving) via ServerBootstrap.
-- 5. Runs authoritative simulation ticks and replicates StateSnapshot / StateDelta views.
-- 6. Runs autosave loop (every 300s) and handles safe flush on server shutdown (BindToClose).

local isRoblox = (typeof(game) == "Instance")
if not isRoblox then
	return {}
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")

local ServerBootstrap = require(script.Parent.Bootstrap)
local FarmPlotBuilder = require(script.Parent.world.FarmPlotBuilder)
local RobloxDataStorePort = require(script.Parent.RobloxDataStorePort)
local Products = require(script.Parent.platform.products)

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

-- 2. Create Production DataStore Port with graceful Studio fallback
local function createProductionStore()
	local ok, dsInstance = pcall(function()
		return DataStoreService:GetDataStore("HatchTheEgg_PlayerProfile_v1")
	end)
	if not ok or not dsInstance then
		warn("[HatchTheEgg Server] DataStoreService unavailable, falling back to in-memory store.")
		return nil
	end

	-- Connectivity probe: in Studio, GetAsync throws if "Enable Studio Access to API Services" is unchecked
	local testOk, testErr = pcall(function()
		return dsInstance:GetAsync("__HatchTheEgg_Studio_Connection_Check__")
	end)
	if not testOk then
		warn("[HatchTheEgg Server] DataStore API access not enabled (" .. tostring(testErr) .. "). Falling back to in-memory store.")
		return nil
	end

	print("[HatchTheEgg Server] Connected to Roblox DataStore: HatchTheEgg_PlayerProfile_v1")
	return RobloxDataStorePort.new(dsInstance)
end

local persistentStore = createProductionStore()

-- Synchronized server clock (monotonic with true UTC start baseline)
local startUtc = DateTime.now().UnixTimestampMillis
local startElapsed = os.clock()
local serverClock = {
	utcNowMs = function()
		local elapsed = os.clock() - startElapsed
		return startUtc + math.floor(elapsed * 1000 + 0.5)
	end,
	elapsedNowSeconds = function()
		return os.clock()
	end,
}

-- 3. Generate the 3D Farm Island World in Workspace
local worldBuilder = FarmPlotBuilder.new()
worldBuilder:build()

-- 4. Initialize Authoritative ServerBootstrap
local server = ServerBootstrap.new({
	clock = serverClock,
	store = persistentStore,
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

-- 5. Player Lifecycle (PlayerAdded & PlayerRemoving)
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

	-- Asynchronously check and grant owned GamePasses (Pro Permit, Buy MAX)
	task.spawn(function()
		local passMapping = {
			[Products.CATALOG_ID_TO_PRODUCT_ID.pro_permit or 2001] = "pro_permit",
			[Products.CATALOG_ID_TO_PRODUCT_ID.buy_max or 2002] = "buy_max",
		}
		for passId, catalogId in pairs(passMapping) do
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
			end)
			if ok and owns then
				server:grantEntitlement(pId, catalogId)
			end
		end
		if player.Parent == Players then
			syncWorldAndDelta(pId, player)
		end
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

-- 6. Handle Incoming Client Protocol Messages
clientToServer.OnServerEvent:Connect(function(player, message)
	if type(message) ~= "table" then
		return
	end
	local pId = resolveNumericPlayerId(player)
	if not server:getPlayer(pId) then
		onPlayerAdded(player)
	end

	-- PROD-06: 3D Diegetic Actors Intents (HitDrone and ClaimOffer)
	if message.kind == "HitDrone" then
		local droneId = message.droneId
		local okHit, reward = server:handleRewardRequest(pId, message)
		if okHit and reward then
			serverToClient:FireClient(player, {
				kind = "DroneRewardPopup",
				droneId = droneId,
				reward = reward,
			})
			syncWorldAndDelta(pId, player)
		end
		return
	elseif message.kind == "ClaimOffer" then
		local offerId = message.offerId
		local okClaim, resClaim = server:handleRewardRequest(pId, message)
		if okClaim and resClaim then
			serverToClient:FireClient(player, {
				kind = "OfferClaimedPopup",
				offerId = offerId,
				reward = resClaim.reward or resClaim,
			})
			syncWorldAndDelta(pId, player)
		end
		return
	elseif message.kind == "HatchPetEgg" or message.kind == "HatchPet" then
		local okHatch, resHatch = server:handleRewardRequest(pId, message)
		if okHatch and resHatch then
			serverToClient:FireClient(player, {
				kind = "PetHatched",
				pet = resHatch.pet or resHatch,
				costGE = resHatch.costGE,
			})
			syncWorldAndDelta(pId, player)
		else
			serverToClient:FireClient(player, {
				kind = "PetHatchFailed",
				error = tostring(resHatch),
			})
		end
		return
	elseif message.kind == "EquipPet" then
		local petUid = message.petUid or message.petId
		server:equipPet(pId, petUid)
		syncWorldAndDelta(pId, player)
		return
	elseif message.kind == "UnequipPet" then
		local petUid = message.petUid or message.petId
		server:unequipPet(pId, petUid)
		syncWorldAndDelta(pId, player)
		return
	elseif message.kind == "TogglePetLock" then
		local petUid = message.petUid or message.petId
		server:togglePetLock(pId, petUid, message.locked)
		syncWorldAndDelta(pId, player)
		return
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
		or message.kind == "UpgradeEgg"
	then
		syncWorldAndDelta(pId, player)
	end
end)

-- 7. Platform Payments: ProcessReceipt for Developer Products & GamePass Handling
local function processReceipt(receiptInfo)
	if type(receiptInfo) ~= "table" then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local playerId = receiptInfo.PlayerId
	if not playerId then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local pId = tostring(playerId)
	local session = server:getPlayer(pId)
	if not session then
		-- Player not currently active on this server instance; keep in Roblox retry queue
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local success, result = server:applyPurchase(pId, receiptInfo)
	if success then
		local playerObj = Players:GetPlayerByUserId(playerId)
		if playerObj then
			syncWorldAndDelta(pId, playerObj)
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	else
		warn("[HatchTheEgg Server] ProcessReceipt failed for player " .. tostring(pId) .. ": " .. tostring(result))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

MarketplaceService.ProcessReceipt = processReceipt

-- In-game GamePass purchase completion
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
	if wasPurchased and player and player.Parent == Players then
		local pId = resolveNumericPlayerId(player)
		local catalogId = Products.resolveCatalogId(passId)
		if catalogId then
			server:grantEntitlement(pId, catalogId)
			syncWorldAndDelta(pId, player)
		end
	end
end)

-- 8. Authoritative Server Simulation Loop (0.5s steps)
task.spawn(function()
	while true do
		task.wait(0.5)
		server:tick(0.5)
		for pId, playerObj in pairs(activePlayerObjects) do
			syncWorldAndDelta(pId, playerObj)
		end
	end
end)

-- 8. Autosave loop (every 300s = 5 minutes)
task.spawn(function()
	while true do
		task.wait(300)
		for pId, _ in pairs(activePlayerObjects) do
			task.spawn(function()
				local ok, res = server:checkpointPlayer(pId)
				if not ok then
					warn("[HatchTheEgg Server] Autosave checkpoint failed for player " .. tostring(pId) .. ": " .. tostring(res))
				end
			end)
		end
	end
end)

-- 9. Safe server shutdown via BindToClose
game:BindToClose(function()
	print("[HatchTheEgg Server] BindToClose triggered. Safely flushing and releasing all active player sessions...")
	server:close()
	print("[HatchTheEgg Server] All player sessions saved and released.")
end)
