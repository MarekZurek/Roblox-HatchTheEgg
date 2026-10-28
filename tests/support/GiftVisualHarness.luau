--!nocheck
-- Actual gift visual branch with recording Instance ports; no native physics/render claim.
local fs,luau,serde=require('@lune/fs'),require('@lune/luau'),require('@lune/serde')
local rb=require('@lune/roblox')
local function signal()
 local handlers={};return {Connect=function(_,f)table.insert(handlers,f);return {Disconnect=function()end}end,Fire=function(_,...)for _,f in handlers do f(...)end end}
end
local character={};local player={Character=character}
local function instance(class)
 local n={Name=class,ClassName=class,Children={},Touched=signal(),Triggered=signal(),MouseClick=signal(),CFrame=rb.CFrame.new()}
 function n:FindFirstChild(name,recursive)
  for _,c in self.Children do if c.Name==name then return c end;if recursive then local got=c:FindFirstChild(name,true);if got then return got end end end
 end
 function n:FindFirstChildWhichIsA(class,recursive)
  for _,c in self.Children do if c.ClassName==class then return c end;if recursive then local got=c:FindFirstChildWhichIsA(class,true);if got then return got end end end
 end
 function n:IsA(c)return self.ClassName==c or c=='BasePart' and self.ClassName=='Part' end
 function n:Destroy()self.destroyed=true end
 return setmetatable(n,{__newindex=function(t,k,v)rawset(t,k,v);if k=='Parent' and v then table.insert(v.Children,t)end end})
end
local env={Instance={new=instance},game={GetService=function(_,name)assert(name=='Players');return {LocalPlayer=player}end}}
for _,name in {'Vector3','CFrame','Color3','UDim2','UDim','Enum','NumberRange','NumberSequence','ColorSequence'} do env[name]=rb[name]end
local source=fs.readFile('src/client/RoutePresentation.luau')
local R=luau.load(source,{debugName='gift-branch-under-review',environment=env})()

return R
