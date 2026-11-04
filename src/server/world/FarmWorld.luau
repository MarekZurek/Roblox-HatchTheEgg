--!strict
-- Four server-owned farm plots. Layout affects presentation, never economy coordinates.
local Builder = if typeof(script)=='Instance' then require(script.Parent.FarmPlotBuilder) else require('./FarmPlotBuilder')
local FarmWorld = {}
FarmWorld.__index = FarmWorld
local ORIGINS = table.freeze({
	table.freeze({x=0,y=0,z=240}), table.freeze({x=240,y=0,z=0}),
	table.freeze({x=0,y=0,z=-240}), table.freeze({x=-240,y=0,z=0}),
})

function FarmWorld.new(deps: any?): any
	local d = deps or {}
	return setmetatable({builders={},owners={},slots={},factory=d.factory or Builder.new,root=nil},FarmWorld)
end

function FarmWorld:build(): any
	local env = Builder.new()
	if typeof(game) == 'Instance' then
		local old = workspace:FindFirstChild('HatchTheEggWorld')
		if old then old:Destroy() end
		local baseplate=workspace:FindFirstChild('Baseplate')
		if baseplate then baseplate:Destroy() end
		local root = Instance.new('Folder')
		root.Name='HatchTheEggWorld';root.Parent=workspace;self.root=root
		env:_configureSunnyLighting();env:_buildOceanWater(root)
		local hub=Instance.new('Model');hub.Name='CentralIsland';hub.Parent=root
		local function part(name: string,size: Vector3,position: Vector3,color: Color3): BasePart
			local p=Instance.new('Part');p.Name=name;p.Size=size;p.Position=position
			p.Color=color;p.Anchored=true;p.TopSurface=Enum.SurfaceType.Studs;p.Parent=hub
			return p
		end
		part('Beach',Vector3.new(144,10,144),Vector3.new(0,-5,0),Color3.fromRGB(238,206,138))
		part('Grass',Vector3.new(140,1,140),Vector3.zero,Color3.fromRGB(106,222,42))
		part('Monument',Vector3.new(18,4,18),Vector3.new(0,2,0),Color3.fromRGB(225,175,105))
		local egg=part('GoldenEgg',Vector3.new(14,19,14),Vector3.new(0,13,0),Color3.fromRGB(255,215,35))
		egg.Shape=Enum.PartType.Ball
		for i,o in ORIGINS do
			local northSouth=o.x==0
			local x,z=o.x*.5,o.z*.5
			part('Bridge_'..i,if northSouth then Vector3.new(14,1,106) else Vector3.new(106,1,14),Vector3.new(x,0,z),Color3.fromRGB(185,132,78))
			for _,side in {-1,1} do
				part('Rail_'..i..'_'..side,if northSouth then Vector3.new(1,3,106) else Vector3.new(106,3,1),Vector3.new(x+(if northSouth then side*7 else 0),2,z+(if northSouth then 0 else side*7)),Color3.fromRGB(125,82,44))
			end
		end
	end
	for i,o in ORIGINS do
		local b=self.factory({workspace=self.root,name='Farm_'..i,origin=o,farmOnly=true}):build()
		self.builders[i]=b
		if typeof(game)=='Instance' then
			b.worldFolder:SetAttribute('FarmSlot',i)
			-- All four islands have identical initial geometry and empty-account presentation.
			b.worldFolder:SetAttribute('OwnerPlayerId','')
		end
	end
	return self
end

function FarmWorld:assign(id: string): (any?, number?)
	local existing=self.slots[id]
	if existing then return self.builders[existing],existing end
	for i,b in self.builders do
		if not self.owners[i] then
			self.owners[i]=id;self.slots[id]=i
			if typeof(game)=='Instance' then b.worldFolder:SetAttribute('OwnerPlayerId',id) end
			return b,i
		end
	end
	return nil,nil
end

function FarmWorld:get(id: string): any?
	return self.builders[self.slots[id]]
end

function FarmWorld:release(id: string)
	local i=self.slots[id]
	if not i then return end
	self.slots[id]=nil;self.owners[i]=nil
	-- Rebuild only the departed owner's farm; no stale models on slot reuse.
	self.builders[i]=self.factory({workspace=self.root,name='Farm_'..i,origin=ORIGINS[i],farmOnly=true}):build()
	if typeof(game)=='Instance' then
		self.builders[i].worldFolder:SetAttribute('FarmSlot',i)
		self.builders[i].worldFolder:SetAttribute('OwnerPlayerId','')
	end
end

return FarmWorld
