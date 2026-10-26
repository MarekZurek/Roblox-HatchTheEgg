-- Independent black-box acceptance across authoritative views, UI and real purchase paths.
local B=require('../../src/server/Bootstrap')
local Client=require('../../src/client/Bootstrap')
local C=require('../../src/shared/NumericCodec')
local S=require('../../src/server/ProfileSchema').new(C)
local n=0
local function ok(v,label)n+=1;assert(v,label)end
local function eq(a,b,label)ok(a==b,label..': '..tostring(a)..' ~= '..tostring(b))end
local function visible(node)
 while node do if node.Visible==false then return false end;node=node.Parent end
 return true
end
local function textWidget(h,text)
 for _,node in h.hud.guiRoot:GetDescendants() do
  if node.Text and string.find(node.Text,text,1,true) and visible(node) then return node end
 end
end
local function harness(mutate)
 local h={now=1000000,elapsed=0,packets={}}
 h.b=B.new({clock={utcNowMs=function()return h.now end,elapsedNowSeconds=function()return h.elapsed end}})
 local p=S.createReference('1',h.now);p.farm.cash='1000000'
 if mutate then mutate(p) end
 eq(h.b:playerJoined('1',p).status,'JOINED','join')
 h.client=Client.new({playerId='1',wire=function(m)
  table.insert(h.packets,m);local r=h.b:dispatch('1',m);if r then h.client:receive(r) end
 end})
 h.client:connect('ui-integration');h.hud=h.client:getHUD()
 function h.sync()local d=h.b:createPlayerDelta('1');if d then h.client:receive(d) end end
 function h.close()h.client:destroy();h.b:close()end
 return h
end
local h=harness(function(p)p.farm.habitats[1].population='245'end)
eq(textWidget(h,'Brak miejsca w kurnikach'),nil,'five free places do not show full')
for _=1,5 do h.client:hatchPress() end
h.sync()
ok(textWidget(h,'Brak miejsca w kurnikach')~=nil,'five in-transit reservations fill remaining places')
local beforePackets=#h.packets
for i=1,120 do h.client:update(h.now+i*16) end
eq(#h.packets,beforePackets,'idle feedback frames add no requests')
h.client:getStore():setStatus('RESYNCING')
eq(textWidget(h,'Brak miejsca w kurnikach'),nil,'status-only resync hides stale blockage')
h.hud:update()
eq(textWidget(h,'Brak miejsca w kurnikach'),nil,'rendering stale farm during resync keeps blockage hidden')
h.client.transport:sendRefreshState('ui-resume')
ok(textWidget(h,'Brak miejsca w kurnikach')~=nil,'fresh authoritative snapshot restores full status')
local action=textWidget(h,'Kurniki')
ok(action~=nil and action.Activated~=nil,'full status has habitat action')
action.Activated:Fire()
eq(h.hud:getHabitatsModal().Visible,true,'action opens habitat modal')
h.hud:toggleHabitatsModal(false)
local result
h.client:buyHabitat(1,'SHACK',function(r)result=r end)
eq(result.status,'APPLIED','existing habitat purchase path retained')
h.sync()
eq(textWidget(h,'Brak miejsca w kurnikach'),nil,'capacity purchase removes stale full status')
eq(h.client:getFarm().habitats[1].habitatIndex,1,'persistent type ID unchanged')
ok(string.find(h.hud.habitatCards[1]:FindFirstChild('TitleLabel').Text,'Tier 2',1,true)~=nil,'upgraded habitat name is Tier 2')
h.client:buyVehicle(4,'TRIKE',function(r)result=r end)
eq(result.status,'APPLIED','fleet modal purchase path remains usable without pads')
h.sync()
ok(string.find(h.hud.vehicleCards[4].titleLabel.Text,'Tier 1',1,true)~=nil,'fleet slot4 type0 displays Tier1')
ok(string.find(h.hud.vehicleCards[2].titleLabel.Text,'Puste miejsce',1,true)~=nil,'fleet gap remains empty')
h.close()
local mixed=harness(function(p)
 p.farm.habitats[1].population='250';p.farm.habitats[2].typeIndex=0
end)
eq(textWidget(mixed,'Brak miejsca w kurnikach'),nil,'another built habitat vacancy prevents global-full feedback')
mixed.close()
local priced=harness(function(p)p.farm.habitats[2].typeIndex=1 end)
local Builder=require('../../src/server/world/FarmPlotBuilder')
local world=Builder.new({}):build()
local farm=priced.client:getFarm()
world:updateFromFarmView(farm,priced.b.catalog)
eq(#world:getBuyPads(),4,'only four habitat pads remain in generated world')
for _,pad in world:getBuyPads() do eq(pad.padType,'BuyHabitat','vehicle pads removed, habitat pads retained') end
local expected=C.BigAmount.decode(farm.habitats[1].upgradePrice)
ok(expected<1000,'fixture keeps price unabridged for exact comparison')
local shown=world:getHabitats()[1].buyPad.line3Label.Text
ok(math.abs((tonumber(string.sub(shown,2)) or -1)-expected)<0.51,
 'world pad uses authoritative same-type purchase price: '..shown..' vs '..tostring(expected))
priced.close()
local empty=harness(function(p)p.farm.hatcheryStock='0.5'end)
ok(textWidget(empty,'Brak jaj do wyl\u{119}gu')~=nil,'fractional stock below one shows refill')
empty.now+=300;empty.elapsed+=.3;empty.b:tick(.3);empty.sync()
eq(textWidget(empty,'Brak jaj do wyl\u{119}gu'),nil,'refill restores normal hatch status')
empty.close()
local both=harness(function(p)p.farm.habitats[1].population='250';p.farm.hatcheryStock='0'end)
ok(textWidget(both,'Brak miejsca w kurnikach')~=nil,'capacity takes precedence over stock')
eq(textWidget(both,'Brak jaj do wyl\u{119}gu'),nil,'no conflicting empty stock message')
both.close()
print('UI #77-80 independent integration PASS: '..n..' assertions')
