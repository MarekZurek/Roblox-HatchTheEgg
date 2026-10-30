-- Authoritative effect/price previews and HUD behavior, including empty fleet slots.
local B=require('../../src/server/Bootstrap')
local Client=require('../../src/client/Bootstrap')
local C=require('../../src/shared/NumericCodec')
local Schema=require('../../src/server/ProfileSchema').new(C)
local Protocol=require('../../src/shared/ProtocolSchemas').new(C)
local HUD=require('../../src/client/HUD')
local Projector=require('../../src/server/ViewProjector')
local fs,serde=require('@lune/fs'),require('@lune/serde')
local count=0
local function eq(a,b,label)count+=1;assert(a==b,(label or '')..' expected '..tostring(b)..' got '..tostring(a))end
local function near(a,b,label)count+=1;assert(math.abs(a-b)<=math.max(1,math.abs(b))*2e-12,label or tostring(a)..' != '..tostring(b))end
local function harness(mutate)
	local h={b=B.new({initialNowMs=1000000})}
	local p=Schema.createReference('1',1000000);p.farm.cash='1000000'
	if mutate then mutate(p) end
	eq(h.b:playerJoined('1',p).status,'JOINED')
	h.client=Client.new({playerId='1',wire=function(m)local r=h.b:dispatch('1',m);if r then eq(h.client:receive(r),true,'valid server message')end end})
	h.client:connect('preview-boot');h.hud=h.client:getHUD()
	function h.sync()eq(h.client:receive(h.b:createPlayerDelta('1')),true)end
	return h
end
do
	local h=harness();local farm=h.client:getFarm()
	eq(h.hud.shopResearch.comfy_nests.subtitleLabel.Text,'Tempo znoszenia: +0% → +10%')
	eq(h.hud.shopResearch.internal_hatchery1.subtitleLabel.Text,'Kurczaki/min/kurnik: +0 → +2')
	eq(h.hud.unifiedResearch.comfy_nests.levelLabel.Text,'★ POZ. 0/180','unified comfy_nests starts at 0/180')
	eq(h.hud.unifiedResearch.internal_hatchery1.levelLabel.Text,'★ POZ. 0/345','unified internal_hatchery starts at 0/345')
	eq(h.hud.goldenEggsLabel.Text,'Diamenty: 10','GE visible without opening a modal')
	for i=1,4 do
		eq(h.hud.vehicleCards[i].card.Visible,true,'four base slots visible')
		eq(h.hud.vehicleCards[i].upgBtn.Active,true,'four base slots purchasable')
	end
	eq(h.hud.vehicleCards[2].titleLabel.Text,'Slot #2: Puste miejsce')
	eq(h.hud.vehicleCards[2].upgBtn.Text,'$22.41','price replaces upgrade action')
	eq(h.hud.habitatUpgBtns[1].Text,'$466.67','server SHACK price')
	eq(farm.habitats[2].nextHabitatId,'COOP','empty plot builds COOP')
	eq(h.hud.vehicleCards[5].card.Visible,false,'no fabricated fifth base slot')
	local result
	h.client:buyResearch('comfy_nests',function(r)result=r end);eq(result.status,'APPLIED');h.sync()
	eq(h.hud.shopResearch.comfy_nests.subtitleLabel.Text,'Tempo znoszenia: +10% → +20%','effect updates after purchase')
	eq(h.hud.unifiedResearch.comfy_nests.levelLabel.Text,'★ POZ. 1/180','unified comfy_nests advances to 1/180')
	h.client:buyHabitat(1,'SHACK',function(r)result=r end);eq(result.status,'APPLIED');h.sync()
	eq(h.client:getFarm().habitats[1].nextHabitatId,'SUPER SHACK','next target advances past SHACK')
	local quote
	h.client:requestQuote({kind='BuyHabitat',args={slotId=1,habitatId='SUPER SHACK'}},function(q)quote=q end)
	eq(h.hud.habitatUpgBtns[1].Text,HUD.formatCash(quote.cashCost),'button matches current purchase quote')
	h.client:buyVehicle(4,'TRIKE',function(r)result=r end);eq(result.status,'APPLIED');h.sync()
	local saved=h.b:getCoordinator('1').snapshots().durable
	eq(saved.farm.vehicles[2].typeIndex,-1,'empty slot 2 retained')
	eq(saved.farm.vehicles[3].typeIndex,-1,'empty slot 3 retained')
	eq(Schema.validate(saved,'1'),true,'gapped fleet has a valid persistent representation')
	h.b:tick(.3);eq(h.b:getCoordinator('1').snapshots().ready,true,'empty slots do not break production')
	eq(h.client:getFarm().fleet.vehicles[2].slotId,4,'occupied fleet can have a gap')
	eq(h.hud.vehicleCards[2].titleLabel.Text,'Slot #2: Puste miejsce','gap is not a vehicle')
	eq(h.hud.vehicleCards[4].titleLabel.Text,'Slot #4: Tier 1','slot identity, not list index')
	h.client:claimDailyGift(function(r)result=r end)
	eq(result.status,'APPLIED')
	eq(h.hud.goldenEggsLabel.Text,'Diamenty: 202','GE counter reacts to new server balance')
	eq(h.b:playerLeaving('1'),true);eq(h.b:playerJoined('1').status,'JOINED')
	h.client:connect('fleet-reconnect')
	eq(h.hud.vehicleCards[4].titleLabel.Text,'Slot #4: Tier 1','reconnect preserves slot identities')
	h.client:buyVehicle(2,'TRIKE',function(r)result=r end);eq(result.status,'APPLIED');h.sync()
	eq(h.b:getCoordinator('1').snapshots().durable.farm.vehicles[2].typeIndex,0,'empty placeholder can be purchased later')
	h.client:destroy();h.b:close()
end
-- New view fields retain strict numeric validation and are never public data.
do
	local h=harness();local packet=h.b:dispatch('1',{protocolVersion=1,kind='RefreshState',requestId='schema-test'})
	packet.view.farm.habitats[1].upgradePrice='-1';eq(Protocol.validateServer(packet),false,'negative preview cost rejected')
	packet.view.farm.habitats[1].upgradePrice='1'
	packet.view.farm.common[1].effects[1].current='NaN';eq(Protocol.validateServer(packet),false,'invalid preview effect rejected')
	h.client:destroy();h.b:close()
end
do
	local h=harness(function(p)
		p.farm.habitats[1].typeIndex=18;p.farm.vehicles[1].typeIndex=11;p.permanent.hyperloop=true
		p.farm.common.comfy_nests=50;p.farm.common.coordinated_clucking=1
	end)
	eq(h.hud.habitatUpgBtns[1].Text,'MAX');eq(h.hud.habitatUpgBtns[1].Active,false)
	eq(h.hud.vehicleCards[1].upgBtn.Text,'MAX');eq(h.hud.vehicleCards[1].upgBtn.Active,false)
	eq(h.hud.shopResearch.comfy_nests.subtitleLabel.Text,'Tempo znoszenia: +500% (MAX)')
	eq(h.hud.unifiedResearch.comfy_nests.levelLabel.Text,'★ POZ. 50/180','unified comfy_nests tracks cumulative chain levels')
	eq(h.hud.shopResearch.coordinated_clucking.subtitleLabel.Text:find('%%'),nil,'RCB limit is additive, not percent')
	h.client:destroy();h.b:close()
end
do
	local h=harness(function(p)p.permanent.epic.cheaper_contractors=10;p.permanent.epic.bust_unions=10;p.farm.fleetLimit=5 end)
	local q
	h.client:requestQuote({kind='BuyHabitat',args={slotId=1,habitatId='SHACK'}},function(r)q=r end)
	eq(h.hud.habitatUpgBtns[1].Text,HUD.formatCash(q.cashCost),'habitat discount reflected')
	h.client:requestQuote({kind='BuyVehicle',args={slotId=5,vehicleId='TRIKE'}},function(r)q=r end)
	eq(q.available,true);eq(h.hud.vehicleCards[5].upgBtn.Text,HUD.formatCash(q.cashCost),'extra slot follows server limit and discount')
	eq(h.hud.vehicleCards[5].card.Visible,true)
	h.client:destroy();h.b:close()
end
-- Every Common descriptor at zero and max uses independent reference rows.
do
	local b=B.new({initialNowMs=1000000})
	local projector=Projector.new({codec=C,catalog=b.catalog,productionMath=b.productionMath})
	local refs=serde.decode('json',fs.readFile('docs/reference_data/research.json')).common
	local additive={hatcheryCapacity=true,internalHatcheryRate=true,maxFleetSize=true,onscreenChickenMultMax=true,hyperloopMaxTrainLength=true}
	for _,row in refs do
		for _,level in {0,row.maxLevel} do
			local p=Schema.createReference('1',1000000);p.farm.common[row.id]=level
			local snapshot=projector:projectPrivateView(p,'preview','1',1000000,'preview')
			eq(Protocol.validateServer(snapshot),true,'all reference previews fit wire bounds')
			local entry
			for _,v in snapshot.view.farm.common do if v.researchId==row.id then entry=v end end
			local current=row.effectsByLevel[level+1]
			local nextLevel=if level<row.maxLevel then row.effectsByLevel[level+2] else nil
			eq(entry~=nil,true,'SPEC/common research entry exists')
			local expectedKeys, actualKeys = {}, {}
			for key in current do expectedKeys[key]=true end
			for key in nextLevel or {} do expectedKeys[key]=true end
			for _,effect in entry.effects do
				eq(actualKeys[effect.stat],nil,'SPEC/common effects have no duplicates')
				actualKeys[effect.stat]=true
				eq(expectedKeys[effect.stat],true,'SPEC/common effects have no extra keys')
				local neutral=if additive[effect.stat] then 0 else 1
				near(C.BigAmount.decode(effect.current),current[effect.stat] or neutral,'reference current effect')
				if nextLevel then near(C.BigAmount.decode(effect.next),nextLevel[effect.stat] or neutral,'reference next effect')
				else eq(effect.next,nil,'MAX has no fictional next level') end
			end
			for key in expectedKeys do eq(actualKeys[key],true,'SPEC/common effect missing: '..row.id..'/'..key) end
		end
	end
end
for _,size in {{1920,1080},{800,600},{390,844},{844,390}} do
	local w,h,s=HUD.modalLayout(size[1],size[2],540)
	eq(w<=size[1],true);eq(h<=size[2],true);eq(s>0 and s<=1,true)
	if size[1]>=700 then near(w,size[1]*.7,'desktop uses 70% width') end
end
print('Upgrade previews PASS: '..count..' assertions')
