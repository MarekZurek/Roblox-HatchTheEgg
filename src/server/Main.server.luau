--!nocheck
-- Main Server Entrypoint for HatchTheEgg (VIS-01, VIS-02, VIS-03, PROD-04).
-- Automatically starts the authoritative server in Roblox Studio / Production:
-- 1. Creates ReplicatedStorage/HatchTheEgg/Remotes (ClientToServer & ServerToClient RemoteEvents).
-- 2. Requires persistent storage; memory is an explicit Studio-only, payment-free mode.
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
local MarketplaceService = game:GetService("MarketplaceService")
-- Installed before any yielding startup work: an uninitialized server must never
-- acknowledge receipts. Keep one platform callback and switch only its delegate.
local receiptHandler = function(_receipt) return Enum.ProductPurchaseDecision.NotProcessedYet end
MarketplaceService.ProcessReceipt = function(receipt) return receiptHandler(receipt) end
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

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

-- Explicit Studio-only local mode. A live server ignores this attribute.
local studio = RunService:IsStudio()
local studioMemory = studio and script:GetAttribute("UseLocalMemoryStore") == true
local storageMode = if studioMemory then "STUDIO_MEMORY" else "PERSISTENT"
local persistentStore, storageError
if not studioMemory then persistentStore, storageError = RobloxDataStorePort.open(DataStoreService) end
local storageMessage = "Zapis jest chwilowo niedostępny. Spróbuj ponownie później."
if not studioMemory and not persistentStore then
    warn("[HatchTheEgg Server] Persistent storage unavailable: "..tostring(storageError))
    local function refusePlayer(player) player:Kick(storageMessage) end
    Players.PlayerAdded:Connect(refusePlayer)
    for _,player in Players:GetPlayers() do refusePlayer(player) end
    return -- no world, sessions, remotes, economy or payment fulfillment
end
if studioMemory then warn("[HatchTheEgg Server] Explicit Studio memory mode: no persistence; platform purchases disabled.") end

-- 1. Ensure ReplicatedStorage/HatchTheEgg/Remotes exists only after storage admission.
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
local configuredProducts={}
for _,catalogId in {"pro_permit","buy_max","ge_pack_small","ge_pack_large"} do
    local id=script:GetAttribute(catalogId.."_PlatformId")
    if type(id)=="number" and id>0 and id%1==0 then
        Products.registerProductId(id,catalogId)
        configuredProducts[catalogId]={platformId=id}
    end
end
local policyByPlayer={}
local server = ServerBootstrap.new({
    storageMode = storageMode,
    isStudio = studio,
    platformProducts=configuredProducts,
    paidRandomAllowed=function(id)return policyByPlayer[tostring(id)] end,
	clock = serverClock,
	store = persistentStore,
})

local activePlayerObjects = {} -- [pId] = Player
local joining, pendingBootstrap, refusedPlayers = {}, {}, {}

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
    if joining[pId] or server:getPlayer(pId) or refusedPlayers[pId]==player then return end
    joining[pId] = true
    local opened, joinRes, err = pcall(server.playerJoined, server, pId)
    joining[pId] = nil
    if not opened or not joinRes then
        refusedPlayers[pId] = player
        pendingBootstrap[pId] = nil
        warn("[HatchTheEgg Server] Session unavailable: " .. tostring(if opened then err else joinRes))
        player:Kick(storageMessage)
        return
    end
    if player.Parent ~= Players then server:playerLeaving(pId); return end
    activePlayerObjects[pId] = player
    local boot = pendingBootstrap[pId]
    pendingBootstrap[pId] = nil
    if boot then
        local response = server:dispatch(pId,boot)
        if response then serverToClient:FireClient(player,response) end
    end

	task.spawn(function()
        local ok,policy=pcall(function() return game:GetService("PolicyService"):GetPolicyInfoForPlayerAsync(player) end)
        if ok and type(policy)=="table" and type(policy.ArePaidRandomItemsRestricted)=="boolean" then policyByPlayer[pId]=not policy.ArePaidRandomItemsRestricted end
    end)
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
    if server.purchasesEnabled then task.spawn(function()
        local passMapping={}
        for _,catalogId in {"pro_permit","buy_max"} do
            if configuredProducts[catalogId] then passMapping[configuredProducts[catalogId].platformId]=catalogId end
        end
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
    end) end
end

local function onPlayerRemoving(player)
	local pId = resolveNumericPlayerId(player)
    activePlayerObjects[pId] = nil
    pendingBootstrap[pId] = nil
	if refusedPlayers[pId]==player then refusedPlayers[pId]=nil end
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
    if refusedPlayers[pId]==player then return end
    if not server:getPlayer(pId) then
        if (message.kind=="Bootstrap" or message.kind=="RefreshState") and server.protocol.validateClient(message) then
            pendingBootstrap[pId]=message -- one bounded waiting handshake, not a command queue
        end
        if not joining[pId] then onPlayerAdded(player) end
        return
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

if server.purchasesEnabled then receiptHandler = processReceipt end

-- In-game GamePass purchase completion
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
    if not server.purchasesEnabled then return end
	if wasPurchased and player and player.Parent == Players then
		local pId = resolveNumericPlayerId(player)
		local catalogId = Products.resolveCatalogId(passId)
        if not catalogId or not configuredProducts[catalogId] or configuredProducts[catalogId].platformId~=passId then return end
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
