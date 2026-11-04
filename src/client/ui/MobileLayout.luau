--!strict
-- Responsive presentation only. No commands, catalog values or player state are changed.
local MobileLayout = {}

export type Rect = {x:number,y:number,w:number,h:number}
local function rect(x:number,y:number,w:number,h:number): Rect return {x=x,y=y,w=w,h=h} end

function MobileLayout.hudPlan(w:number,h:number): any
	local portrait=w<h
	local dockHeight=math.max(64,math.min(451,h-290))
	return {
		portrait=portrait,
		tutorial=if portrait then rect(8,200,w-100,116) else rect((w-math.min(400,w-300))/2,202,math.min(400,w-300),94),
		dock=if portrait then rect(w-82,110,72,dockHeight) else rect(w-258,82,246,118),
		stock=if portrait then rect(8,h-158,210,44) else rect(8,146,136,44),
		cash=if portrait then rect(8,h-208,210,44) else rect(154,104,210,44),
		diamonds=if portrait then rect(8,h-258,182,44) else rect(154,154,182,44),
		status=if portrait then rect(8,h-318,w-100,48) else rect((w-math.min(380,w-300))/2,202,math.min(380,w-300),44),
		badge=if portrait then rect(8,108,w-100,80) else rect(8,80,136,60),
	}
end

function MobileLayout.researchPlan(width:number): any
	local compact=width<480
	return {compact=compact,height=if compact then 152 else 90,spacing=if compact then 160 else 96,
		buy=if compact then rect(8,98,(width-24)/2,46) else rect(width-196,21,92,48),
		max=if compact then rect(16+(width-24)/2,98,(width-24)/2,46) else rect(width-98,21,92,48),
		text=if compact then rect(58,26,width-70,40) else rect(58,24,width-266,40)}
end

function MobileLayout.bodyItem(yScale:number,yOffset:number,hScale:number,hOffset:number,designHeight:number,start:number?): any
	return {y=yScale*designHeight+yOffset-(start or 60),height=hScale*designHeight+hOffset}
end

function MobileLayout.shopPlan(w:number,h:number): any
	local narrow=w<600
	return {narrow=narrow,
		tabs=if narrow then rect(12,56,w-24,48) else rect(16,52,128,h-68),
		banner=if narrow then rect(12,110,w-24,44) else rect(156,48,w-172,44),
		content=if narrow then rect(12,162,w-24,h-174) else rect(156,100,w-172,h-114)}
end

function MobileLayout.researchTabsPlan(width:number): any
	local columns=if width<516 then 2 else 4
	local tabWidth=(width-6*(columns-1))/columns
	local tabs={}
	for i=1,4 do table.insert(tabs,rect(((i-1)%columns)*(tabWidth+6),math.floor((i-1)/columns)*48,tabWidth,44))end
	return {height=if columns==2 then 92 else 44,tabs=tabs}
end

local function box(v:any,r:Rect)
	if not v then return end
	v.AnchorPoint=Vector2.zero;v.Position=UDim2.fromOffset(r.x,r.y);v.Size=UDim2.fromOffset(r.w,r.h)
end
local function child(v:any,name:string): any return v and v:FindFirstChild(name) end
local function set(v:any,name:string,r:Rect) box(child(v,name),r) end
local function full(v:any,y:number,height:number)
	v.Position=UDim2.fromOffset(0,y);v.Size=UDim2.new(1,-8,0,height)
end
local function visibleCards(v:any): {any}
	local out={}
	for _,c in v:GetChildren() do if c:IsA('GuiObject') and c.Visible then table.insert(out,c) end end
	table.sort(out,function(a,b)return a.Position.Y.Offset<b.Position.Y.Offset end)
	return out
end

function MobileLayout.attach(hud:any,root:any): any
	local self:any={connections={},pending=false,busy=false,bodyWindows={},pressScales={},activeTouches={},
		menuButtons={hud.researchToggleBtn,hud.habitatsToggleBtn,hud.shopToggleBtn,hud.vehiclesToggleBtn,hud.epicResearchToggleBtn,hud.prestigeToggleBtn,hud.calendarToggleBtn}}
	local function schedule()
		if self.pending then return end
		self.pending=true
		task.defer(function() self.pending=false;if root.Parent then self:refresh() end end)
	end
	local function watch(signal:any) table.insert(self.connections,signal:Connect(schedule)) end
	local function scrollBody(win:any,designHeight:number,start:number?)
		if self.bodyWindows[win] then return end
		local existing=win:FindFirstChild('ResponsiveBody')
		if existing then self.bodyWindows[win]=existing;return end
		local inset=start or 60
		local body=Instance.new('ScrollingFrame')
		body.Name='ResponsiveBody';body.BackgroundTransparency=1;body.BorderSizePixel=0
		body.Active=true;body.ScrollingDirection=Enum.ScrollingDirection.Y
		body.Position=UDim2.fromOffset(0,inset);body.Size=UDim2.new(1,0,1,-inset-10)
		body.ScrollBarThickness=6;body.ZIndex=win.ZIndex+1;body.Parent=win
		local bottom=0
		for _,v in win:GetChildren() do
			if v:IsA('GuiObject') and v~=body and v.Name~='WindowHeader' and v.Name~='CloseBtn' then
				local pos=v.Position;local item=MobileLayout.bodyItem(pos.Y.Scale,pos.Y.Offset,v.Size.Y.Scale,v.Size.Y.Offset,designHeight,inset)
				bottom=math.max(bottom,item.y+inset+item.height)
				v.Position=UDim2.new(pos.X.Scale,pos.X.Offset,0,item.y)
				v.Size=UDim2.new(v.Size.X.Scale,v.Size.X.Offset,0,item.height);v.Parent=body
			end
		end
		body.CanvasSize=UDim2.fromOffset(0,bottom-inset+12)
		self.bodyWindows[win]=body
	end
	local pets=root:FindFirstChild('PetsFrame')
	if pets then local inventory=pets:FindFirstChild('InventoryFrame',true);if inventory then inventory.Size=UDim2.new(1,-28,0,248)end end
	for name,height in {PrestigeModal=580,EggUpgradeModal=360,PetHatchModal=460,PetsFrame=540} do
		local win=root:FindFirstChild(name)
		if win then scrollBody(win,height) end
	end
	if hud.petRevealCard then scrollBody(hud.petRevealCard,440,0);watch(hud.petRevealCard:GetPropertyChangedSignal('Visible')) end
	local prestige=root:FindFirstChild('PrestigeModal')
	if prestige then
		local close=prestige.WindowHeader.CloseBtn
		close.Size=UDim2.fromOffset(46,46);close.Position=UDim2.new(1,-50,.5,-23)
	end

	function self:refresh()
		if self.busy then return end
		self.busy=true
		local w,h=root.AbsoluteSize.X,root.AbsoluteSize.Y
		if w<=0 or h<=0 then self.busy=false;return end
		local small=w<600 or h<500 or game:GetService('UserInputService').TouchEnabled
		if hud.petRevealCard then
			hud.petRevealCard.AnchorPoint=Vector2.new(.5,.5);hud.petRevealCard.Position=UDim2.fromScale(.5,.5)
			hud.petRevealCard.Size=UDim2.fromOffset(math.min(380,w-20),math.min(440,h-20))
		end
		if small then
			local p=MobileLayout.hudPlan(w,h)
			local count=0
			for _,b in self.menuButtons do if b and b.Visible then count+=1 end end
			if p.portrait then
				p.dock.h=math.min(p.dock.h,math.max(73,count*63+10))
				hud.rightDock.CanvasSize=UDim2.fromOffset(0,count*63+10);hud.rightDock.ScrollingEnabled=true
			else
				p.dock.w=math.max(66,math.min(4,count)*60+6);p.dock.x=w-12-p.dock.w
				p.dock.h=math.max(62,math.ceil(count/4)*56+6)
				hud.rightDock.CanvasSize=UDim2.fromOffset(0,p.dock.h);hud.rightDock.ScrollingEnabled=false;hud.rightDock.CanvasPosition=Vector2.zero
			end
			local index=0
			for _,b in self.menuButtons do
				if b and b.Visible then
					index+=1
					box(b,if p.portrait then rect(7,8+(index-1)*63,62,58) else rect(6+((index-1)%4)*60,6+math.floor((index-1)/4)*56,54,50))
					local icon=child(b,'ButtonIcon');if icon then local size=if p.portrait then 36 else 26;icon.Size=UDim2.fromOffset(size,size);icon.Position=UDim2.new(.5,-size/2,0,3)end
					local caption=child(b,'MenuCaption');if caption then caption.Size=UDim2.new(1,-4,0,if p.portrait then 16 else 14);caption.Position=UDim2.new(0,2,1,if p.portrait then -18 else -16)end
				end
			end
			box(hud.tutorialCardFrame,p.tutorial);box(hud.rightDock,p.dock)
			box(hud.hatcheryFrame,p.stock);box(hud.bottomLeftCluster,p.cash)
			box(hud.diamondsPillFrame,p.diamonds);box(hud.hatchStatusFrame,p.status);box(hud.playerFarmBadge,p.badge)
			if hud.tutorialCardFrame.Visible and hud.hatchStatusFrame then hud.hatchStatusFrame.Visible=false end
			if hud.tutorialCardFrame then
				set(hud.tutorialCardFrame,'TutorialStepBadge',rect(10,8,74,26))
				set(hud.tutorialCardFrame,'TutorialTitleLabel',rect(94,8,p.tutorial.w-106,32))
				set(hud.tutorialCardFrame,'TutorialBodyLabel',rect(10,44,p.tutorial.w-20,p.tutorial.h-50))
				hud.tutorialBodyLabel.TextScaled=false;hud.tutorialBodyLabel.TextSize=14
				hud.tutorialTitleLabel.TextWrapped=true
			end
			if hud.playerFarmBadge then
				if p.portrait then set(hud.playerFarmBadge,'RebirthClickButton',rect(68,34,p.badge.w-72,44)) end
				for _,v in hud.playerFarmBadge:GetChildren() do
					if v:IsA('GuiObject') and v.Name~='EggAvatarButton' then v.Visible=p.portrait end
				end
			end
			set(hud.bottomLeftCluster,'CashPlusBtn',rect(p.cash.w-46,0,44,44))
			set(hud.diamondsPillFrame,'DiamondsPlusBtn',rect(p.diamonds.w-46,0,44,44))
			local dock=hud.rightDock
			if dock then
				local target=hud.calendarToggleBtn
				if p.portrait and target and target.Visible and hud.tutorialCardFrame.Visible then
					dock.CanvasPosition=Vector2.new(0,math.max(0,target.Position.Y.Offset+target.Size.Y.Offset-p.dock.h+8))
				end
			end
		end

		-- Unified research replaced the old cards; reflow its actual controls as well.
		local research=hud.shopListContainer
		if research then
			local plan=MobileLayout.researchPlan(research.AbsoluteSize.X-6)
			local count=0
			for _,item in hud.unifiedResearch or {} do
				if item.card.Visible then
					local order=item.displayOrder or 1;count=math.max(count,order)
					full(item.card,(order-1)*plan.spacing,plan.height)
					box(item.buyButton,plan.buy);box(item.buyMaxButton,plan.max)
					box(item.subtitleLabel,plan.text)
					box(item.nameLabel,rect(58,6,plan.text.w,20))
					box(item.levelLabel,rect(58,if plan.compact then 68 else 70,95,16))
					set(item.card,'ProgressTrack',if plan.compact then rect(58,86,plan.text.w,7) else rect(156,74,math.max(0,research.AbsoluteSize.X-306),7))
				end
			end
			research.CanvasSize=UDim2.fromOffset(0,count*plan.spacing+8)
			local tabs=child(hud.shopFrame,'TierTabsRow')
			if tabs then
				local tabPlan=MobileLayout.researchTabsPlan(tabs.AbsoluteSize.X)
				tabs.Size=UDim2.new(1,-24,0,tabPlan.height);tabs.CanvasSize=UDim2.fromOffset(0,0)
				tabs.ScrollingEnabled=false;tabs.CanvasPosition=Vector2.zero
				for i,b in hud.researchTabButtons do box(b,tabPlan.tabs[i])end
				local y=52+tabPlan.height+6
				local banner=hud.researchTierLockBanner
				if banner then box(banner,rect(12,y,hud.shopFrame.AbsoluteSize.X-24,26));if banner.Visible then y+=32 end end
				research.Position=UDim2.fromOffset(12,y);research.Size=UDim2.new(1,-24,1,-y-12)
			end
		end

		-- Preserve readable product cards by using a horizontal tab bar and one column.
		local shop=hud.shopModal
		if shop then
			local sw=shop.AbsoluteSize.X
			local layout=MobileLayout.shopPlan(sw,shop.AbsoluteSize.Y)
			local narrow=layout.narrow
			local tabs=child(shop,'ShopTabsRow');local content=child(shop,'ShopContentContainer')
			if tabs and content then
				box(tabs,layout.tabs);box(content,layout.content);set(shop,'HeroPromoBanner',layout.banner)
				for i,b in hud.shopModalTabButtons do
					if narrow then
						box(b,rect(4+(i-1)*(sw-32)/3,2,(sw-44)/3,44));b.TextYAlignment=Enum.TextYAlignment.Center
					else b.Size=UDim2.new(1,-12,0,88);b.Position=UDim2.fromOffset(6,8+(i-1)*96);b.TextYAlignment=Enum.TextYAlignment.Bottom end
					local icon=child(b,'TabIcon');if icon then icon.Visible=not narrow end
				end
				local width=content.AbsoluteSize.X-8
				local packs=child(content,'Tab1_GEPacks')
				if packs then
					packs.Size=UDim2.new(1,-8,0,if narrow then 648 else 420)
					for i,id in {'ge_pack_small','ge_pack_large'} do
						local card=child(packs,'ShopCard_'..id)
						if card then
							if narrow then
								full(card,6+(i-1)*320,308)
								set(card,'ArtworkPanel',rect(8,8,width-24,104))
								set(card,'BadgeLabel',rect(8,116,width-24,26));set(card,'Title',rect(8,148,width-24,30))
								set(card,'Desc',rect(8,182,width-24,52))
								local art=child(card.ArtworkPanel,'CardArtIcon');if art then art.Size=UDim2.fromOffset(76,76);art.Position=UDim2.new(.5,-38,.5,-38)end
								for _,b in card:GetChildren()do if b:IsA('GuiButton')then box(b,rect(8,248,width-24,48))end end
							else
								card.Size=UDim2.new(.47,0,0,404);card.Position=UDim2.new((i-1)*.5+.015,0,0,6)
								local art=card.ArtworkPanel;art.Size=UDim2.new(1,-16,0,210);art.Position=UDim2.fromOffset(8,8)
								art.CardArtIcon.Size=UDim2.fromOffset(112,112);art.CardArtIcon.Position=UDim2.new(.5,-56,.5,-58)
								card.BadgeLabel.Size=UDim2.new(.72,0,0,26);card.BadgeLabel.Position=UDim2.new(.14,0,0,204)
								card.Title.Size=UDim2.new(.9,0,0,30);card.Title.Position=UDim2.new(.05,0,0,240)
								card.Desc.Size=UDim2.new(.88,0,0,44);card.Desc.Position=UDim2.new(.06,0,0,274)
								card.BuyProductButton.Size=UDim2.new(.88,0,0,52);card.BuyProductButton.Position=UDim2.new(.06,0,1,-64)
							end
						end
					end
				end
				-- Pass and boost descriptions also need the full card width on a phone.
				for _,tabName in {'Tab2_Boosts','Tab3_GamePasses'}do
					local tab=child(content,tabName)
					if tab then
						local y=if tabName=='Tab2_Boosts' then 40 else 0
						for _,card in visibleCards(tab)do
							if card:IsA('Frame') then
								local pass=string.sub(card.Name,1,8)=='PassCard'
								local height=if pass then 240 else 152
								full(card,y,height);y+=height+8
								set(card,'BadgeLabel',rect(8,6,width-24,22));set(card,'Title',rect(8,if pass then 32 else 6,width-24,26))
								set(card,'Desc',rect(8,62,width-24,60));set(card,'Notice',rect(8,126,width-24,44))
								set(card,'BuyPassButton',rect(8,184,width-24,46))
								set(card,'DurationSubtitle',rect(8,34,width-24,32));set(card,'OwnedCount',rect(8,70,(width-24)/2,24));set(card,'Price',rect(width/2,70,(width-24)/2,24))
								set(card,'ActivateBoostButton',rect(8,102,(width-32)/2,44));set(card,'BuyBoostButton',rect(16+(width-32)/2,102,(width-32)/2,44))
								for _,name in {'Desc','Notice','DurationSubtitle'}do local label=child(card,name);if label then label.TextScaled=false;label.TextSize=14;label.TextWrapped=true end end
							end
						end
						tab.Size=UDim2.new(1,-8,0,y+8)
					end
				end
				for _,tab in content:GetChildren()do if tab:IsA('GuiObject') and tab.Visible then content.CanvasSize=UDim2.fromOffset(0,tab.Size.Y.Offset+12)end end
			end
		end
		local epic=hud.epicResearchListContainer
		if epic and epic.AbsoluteSize.X<600 then
			local y=0;local width=epic.AbsoluteSize.X-6
			for _,card in visibleCards(epic)do
				full(card,y,152);y+=160
				set(card,'Title',rect(8,6,width-16,24));set(card,'Desc',rect(8,34,width-16,38))
				set(card,'LevelLabel',rect(8,76,130,20));set(card,'ProgressTrack',rect(146,82,width-158,8))
				set(card,'BuyEpicButton',rect(8,102,(width-24)/2,44));set(card,'BuyRobuxButton',rect(16+(width-24)/2,102,(width-24)/2,44))
			end
			epic.CanvasSize=UDim2.fromOffset(0,y+8)
		end
		local preview=hud.purchasePreviewFrame
		if preview and preview.Parent then
			preview.AnchorPoint=Vector2.new(.5,.5);preview.Position=UDim2.fromScale(.5,.5)
			preview.Size=UDim2.fromOffset(math.min(420,w-20),220)
			preview.Terms.Size=UDim2.new(1,-20,0,140)
			for _,name in {'Confirm','Cancel'}do local b=preview[name];b.Size=UDim2.new(.45,0,0,48);b.Position=UDim2.new(if name=='Confirm'then .025 else .525,0,1,-58)end
		end
		self.busy=false
	end
	watch(root:GetPropertyChangedSignal('AbsoluteSize'))
	for _,v in root:GetDescendants()do if v:IsA('UIScale')and v.Name=='PressScale'then self.pressScales[v]=true end end
	table.insert(self.connections,root.DescendantAdded:Connect(function(v)
		if v:IsA('UIScale')and v.Name=='PressScale'then self.pressScales[v]=true end
		schedule()
	end))
	table.insert(self.connections,root.DescendantRemoving:Connect(function(v)self.pressScales[v]=nil end))
	-- A touch may end outside its button, so MouseButton1Up alone leaves its pressed scale stuck.
	local input=game:GetService('UserInputService')
	table.insert(self.connections,input.InputBegan:Connect(function(began)
		if began.UserInputType==Enum.UserInputType.Touch then self.activeTouches[began]=true end
	end))
	table.insert(self.connections,input.InputEnded:Connect(function(ended)
		if ended.UserInputType~=Enum.UserInputType.Touch then return end
		self.activeTouches[ended]=nil
		task.delay(.1,function()
			if root.Parent and next(self.activeTouches)==nil then
				for scale in self.pressScales do if scale.Parent then scale.Scale=1 end end
			end
		end)
	end))
	for _,v in root:GetChildren()do
		if v:IsA('GuiObject')then watch(v:GetPropertyChangedSignal('Visible'));watch(v:GetPropertyChangedSignal('AbsoluteSize'))end
	end
	for _,v in root:GetDescendants()do
		if v.Name=='Tab1_GEPacks' or v.Name=='Tab2_Boosts' or v.Name=='Tab3_GamePasses' then watch(v:GetPropertyChangedSignal('Visible'))end
	end
	root.Destroying:Connect(function()for _,c in self.connections do c:Disconnect()end end)
	self:refresh()
	return self
end

return table.freeze(MobileLayout)
