--!nocheck
-- Execute the real HUD constructor's header branch with Lune datatypes and a recording
-- Instance port. Stop after DomButton is parented; no native rendering/layout claim.
local fs,luau=require('@lune/fs'),require('@lune/luau')
local Roblox=require('@lune/roblox')
local Availability=require('../../src/shared/FeatureAvailability')
local StudUi=require('../../src/client/ui/StudUi')
local UiAssets=require('../../src/client/ui/UiAssets')
return function()
 local nodes={}
 local function signal()return {Connect=function()return {Disconnect=function()end}end}end
 local function node(class)
  local n={ClassName=class,Activated=signal(),Children={}}
  function n:SetAttribute()end
  function n:GetAttribute()return nil end
  function n:FindFirstChild()return nil end
  function n:GetChildren()return self.Children end
  function n:GetDescendants()return {} end
  table.insert(nodes,n)
  return setmetatable(n,{__newindex=function(t,k,v)
   rawset(t,k,v)
   if k=='Parent' and t.Name=='DomButton' then error('HUD_HEADER_CAPTURE_COMPLETE') end
  end})
 end
 local module=luau.load(fs.readFile('src/client/HUD.luau'),{debugName='HUD-header-under-test',environment={
  Instance={new=node},UDim2=Roblox.UDim2,UDim=Roblox.UDim,Color3=Roblox.Color3,
  Vector2=Roblox.Vector2,Enum=Roblox.Enum,
  game={GetService=function()error('No native services in header test')end},
  require=function(path)
   if path=='../shared/FeatureAvailability' then return Availability end
   if path=='./ui/StudUi' then return StudUi end
   if path=='./ui/UiAssets' then return UiAssets end
   error('Unexpected header dependency: '..tostring(path))
  end,
 }})()
 local success,err=pcall(module.new,{stateStore={},intentControllers={},codec={}})
 assert(not success and tostring(err):find('HUD_HEADER_CAPTURE_COMPLETE',1,true),'Header capture must reach DomButton: '..tostring(err))
 local byName={}
 for _,n in nodes do byName[n.Name or n.ClassName]=n end
 return byName
end
