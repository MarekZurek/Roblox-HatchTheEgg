-- Behavior acceptance tests. Oracles are documented invariants and independent
-- JSON reference rows, never the implementation's preview/result calculator.
local Server=require('../../src/server/Bootstrap')
local Client=require('../../src/client/Bootstrap')
local C=require('../../src/shared/NumericCodec')
local Data=require('../../src/server/PersistenceData')
local Schema=require('../../src/server/ProfileSchema').new(C)
local fs,serde=require('@lune/fs'),require('@lune/serde')
local assertions=0
local function eq(a,b,why) assertions+=1;assert(a==b,(why or '')..' expected '..tostring(b)..' got '..tostring(a)) end
local function near(a,b,why) assertions+=1;assert(math.abs(a-b)<=1e-10*math.max(1,math.abs(b)),why or tostring(a)..' != '..tostring(b))end
local function read(name)return serde.decode('json',fs.readFile('docs/reference_data/'..name..'.json'))end
local function harness(mutate,options)
 options=options or {};local h={now=options.startMs or 1000000,elapsed=0,records={},sent={},responses={},callbacks=0,prompts={}}
 options.clock={utcNowMs=function()return h.now end,elapsedNowSeconds=function()return h.elapsed end}
 options.store={read=function(k)return true,h.records[k] and Data.copy(h.records[k])end,update=function(k,cb)
  local old=h.records[k] and Data.copy(h.records[k]);local out=cb(old)
  if h.retryCallback then h.retryCallback=false;out=cb(old and Data.copy(old)) end
  if h.failBefore then h.failBefore=false;return false,'before write' end
  if out then h.records[k]=Data.copy(out) end
  if h.loseAck then h.loseAck=false;return false,'lost ack' end
  return true,out and Data.copy(out)
 end}
 h.server=Server.new(options)
 local profile=Schema.createReference('1',h.now);if mutate then mutate(profile) end
 eq(h.server:playerJoined('1',profile).status,'JOINED','real session acquired')
 function h.profile()return h.server:getCoordinator('1').snapshots().durable end
 function h.send(packet)
  table.insert(h.sent,Data.copy(packet))
  local reply=h.server:dispatch('1',packet);table.insert(h.responses,reply)
  if h.hold then h.held=reply elseif reply then
   local ok,err=h.client:receive(reply);eq(ok,true,'server reply must pass actual client schema: '..tostring(err))
  end
 end
 h.client=Client.new({playerId='1',wire=h.send,promptPurchase=function(preview)table.insert(h.prompts,preview)end})
 h.client:connect('boot')
 eq(h.client:getStore():isReady(),true,'bootstrapped through real wire')
 function h.call(method,...)
  local result
  local args=table.pack(...);args.n+=1;args[args.n]=function(r)h.callbacks+=1;result=r end
  local packet=h.client[method](h.client,table.unpack(args,1,args.n))
  return result,packet
 end
 function h.refresh()h.client.transport:sendRefreshState()end
 function h.expect(result,status,code)
  eq(result.status,status,'confirmed operation status')
  if code then eq((result.result and result.result.errorCode) or result.errorCode,code,'stable failure reason') end
 end
 function h.nextDay()
  -- Advance the external clock, keeping an empty farm for deterministic payouts.
  h.now+=86400000;h.elapsed+=86400
  h.server:tick(0)
  local attempts=0
  while not h.server:getCoordinator('1').snapshots().ready do h.server:tick(0);attempts+=1;assert(attempts<5000,'offline never settles')end
  h.refresh()
 end
 return h
end
local function pet(p,id)
 p.inventory.pets[id]={uid=id,speciesId='farmer_dog',tier=1,variant='normal',locked=false}
end
local function assets(p)return Data.fingerprint({p.permanent,p.inventory,p.rewards,p.piggy,p.farm.cash})end

-- #56: unloaded/disconnected clients cannot fabricate success.
do
 local client=Client.new({playerId='1'});local replies={}
 for _,method in {'claimDailyGift','prestige'} do
  local packet,code=client[method](client,function(r)table.insert(replies,r)end)
  eq(packet,nil);eq(code,'SESSION_NOT_READY')
 end
 eq(#replies,2);eq(replies[1].status,'NOT_ACCEPTED');client:destroy()
end

-- A click sends one intent, changes only the authoritative account and waits for ACK.
do
 local h=harness();h.hold=true;local n=h.callbacks
 local reply,packet=h.call('claimDailyGift');eq(reply,nil,'no success before response');eq(h.callbacks,n)
 eq(packet.kind,'ClaimDailyGift');eq(h.profile().permanent.GE,'202','10 starter GE + 192 calendar GE')
 eq(h.client:getStore():getFarm().progress.GE,'10','view is unchanged before ACK')
 local saved=h.held;h.hold=false;eq(h.client:receive(saved),true)
 eq(h.callbacks,n+1);eq(h.client:getStore():getFarm().progress.GE,'202','view refreshed after commit')
 local replay=h.server:dispatch('1',packet);eq(replay.status,'REPLAYED');eq(replay.result.terminalStatus,'APPLIED');eq(h.profile().permanent.GE,'202')
 h.expect(h.call('claimDailyGift'),'REJECTED','ALREADY_CLAIMED_TODAY');eq(h.profile().permanent.GE,'202')
 eq(h.profile().rewards.numDailyGiftsCollected,1)
 -- Unknown fields cannot supply rewards or override the price.
 local forged=Data.copy(packet);forged.operationId='forged';forged.args.amount='999999'
 local refused=h.server:dispatch('1',forged);eq(refused.admission,'NOT_ACCEPTED');eq(h.profile().permanent.GE,'202')
 h.client:destroy()
end

-- Five scaling rewards: independent scalar equation across boundaries/caps.
for _,row in read('rewards').calendar do
 if row.scalingMode==3 then
  for _,cycle in {0,1,2,4,5,7,24,1000} do
   local h=harness(function(p)p.rewards.numDailyGiftsCollected=cycle*28+row.day-1 end)
   local amount=if cycle>20 then row.cap else math.min(row.cap,row.rewardValues[1]*2^cycle)
   local result=h.call('claimDailyGift');h.expect(result,'APPLIED')
   if row.type==0 then eq(h.profile().permanent.GE,tostring(10+amount)) else eq(h.profile().piggy.rawAmount,tostring(amount)) end
   eq(result.result.day,row.day);eq(result.result.cycle,cycle)
   h.client:destroy()
  end
 end
end
for _,cycle in {0,23,24,25,1000} do
 local h=harness(function(p)p.rewards.numDailyGiftsCollected=cycle*28+27 end)
 h.expect(h.call('claimDailyGift'),'APPLIED')
 eq(h.profile().permanent.PE,if cycle<24 then '1' else '0');eq(h.profile().permanent.GE,if cycle<24 then '10' else '100010')
 h.client:destroy()
end

-- Reference boost/Epic rewards, rotation and max-level conversion; no mock grants.
do
 local h=harness(function(p)p.rewards.numDailyGiftsCollected=1 end)
 h.expect(h.call('claimDailyGift'),'APPLIED');eq(h.profile().inventory.boosts.jimbos_purple_v2,'2')
 eq(h.profile().inventory.boosts.jimbos_blue_v2,nil,'do not grant an unrelated fixture boost')
 h.client:destroy()
 local h2=harness(function(p)p.rewards.numDailyGiftsCollected=2;p.permanent.epic.hold_to_hatch=15 end)
 h2.retryCallback=true;h2.expect(h2.call('claimDailyGift'),'APPLIED');eq(h2.profile().permanent.GE,'510');eq(h2.profile().permanent.epic.hold_to_hatch,15)
 h2.client:destroy()
end
-- Regression #62: every formerly blocked calendar position now grants its own type.
for _,day in {4,10,15,18,22} do
 local h=harness(function(p)p.rewards.numDailyGiftsCollected=day-1 end)
 h.expect(h.call('claimDailyGift'),'APPLIED');eq(h.profile().rewards.numDailyGiftsCollected,day)
 if day==10 or day==18 then eq(h.profile().permanent.shellScripts,if day==10 then '5' else '10')
 else eq(C.BigAmount.decode(h.profile().farm.cash)>0,true) end
 h.client:destroy()
end

-- All 95 trophy payouts use JSON oracles, not the embedded trophy fixture table.
for _,egg in read('infrastructure').eggs do
 for tier=1,5 do
  local threshold=egg.trophyPopulations[tier]
  local h=harness(function(p)p.farm.eggIndex=egg.index;p.farm.habitats[1].population=tostring(threshold);p.farm.habitats[1].typeIndex=18 end)
  h.client.hud.trophyCards[egg.index]:FindFirstChild('CupBtn_'..tostring(tier)).Activated:Fire()
  h.expect(h.client.hud.lastActionResult,'APPLIED')
  eq(h.profile().permanent.GE,tostring(10+egg.trophyGoldenEggRewards[tier]))
  near(C.BigAmount.decode(h.profile().permanent.SE),egg.trophySoulEggRewards[tier])
  eq(h.profile().permanent.PE,tostring(egg.trophyProphecyEggRewards[tier]))
  h.expect(h.call('claimTrophy',egg.index,tier),'REJECTED','ALREADY_CLAIMED')
  h.client:destroy()
 end
end
do
 local h=harness(function(p)p.farm.habitats[1].population='9999999';p.farm.habitats[1].typeIndex=18 end)
 h.expect(h.call('claimTrophy',0,1),'REJECTED','POPULATION_TOO_LOW')
 h.expect(h.call('claimTrophy',1,1),'REJECTED','WRONG_EGG');eq(h.profile().permanent.SE,'0')
 h.client:destroy()
end

-- Fusion recipe below is an isolated test configuration, not a production balance.
local function fusionOptions(roll,draws)
 return {fusionPolicy={mode='INTERNAL_TEST_ONLY',recipes={['1:golden']={requiredMaterials=2,baseChance=.4,guaranteeThreshold=2}},draw=function()draws.n+=1;return roll end}}
end
local function fusionProfile(p)for _,id in {'base','a','b'} do pet(p,id)end end
do
 local h=harness(fusionProfile);local before=assets(h.profile())
 h.expect(h.call('fusePets','base',{'a','b'}),'REJECTED','FEATURE_UNAVAILABLE');eq(assets(h.profile()),before);h.client:destroy()
end
for _,case in {{roll=.1,success=true},{roll=.9,success=false}} do
 local draws={n=0};local h=harness(fusionProfile,fusionOptions(case.roll,draws));h.retryCallback=true
 local result,packet=h.call('fusePets','base',{'a','b'});h.expect(result,'APPLIED');eq(result.result.success,case.success)
 eq(h.profile().inventory.pets.base.variant,if case.success then 'golden' else 'normal')
 eq(h.profile().inventory.pets.a,nil);eq(h.profile().inventory.pets.b,nil);eq(h.profile().permanent.GE,'10')
 local n=draws.n;h.expect(h.server:dispatch('1',packet),'REPLAYED');eq(draws.n,n,'retries do not reroll')
 h.client:destroy()
end
for _,mutate in {function(p)p.inventory.pets.a.locked=true end,function(p)table.insert(p.inventory.equipped,'base')end,function(p)p.inventory.pets.a.tier=2 end} do
 local draws={n=0};local h=harness(function(p)fusionProfile(p);mutate(p)end,fusionOptions(.1,draws));local before=assets(h.profile())
 local result=h.call('fusePets','base',{'a','b'});eq(result.status,'REJECTED');eq(assets(h.profile()),before);eq(draws.n,0,'invalid fusion must not draw');h.client:destroy()
end

-- UI pet commands use server UIDs and correlated results. Lock replay is not a toggle twice.
for _,allowed in {false,true} do
 local draws={n=0};local opts=fusionOptions(.45,draws);opts.paidRandomAllowed=function()return allowed end
 local h=harness(function(p)fusionProfile(p);p.entitlements.pro_permit=true;p.entitlements.pro_plus10_enabled=allowed end,opts)
 local r=h.call('fusePets','base',{'a','b'});h.expect(r,'APPLIED')
 eq(r.result.success,allowed,'40% plus 10 percentage points only when eligible; 45% is above 40% and below 50%')
 h.client:destroy()
end
do
 local draws={n=0};local h=harness(function(p)for _,id in {'base','a','b','c','d','e','f'}do pet(p,id)end end,fusionOptions(.99,draws))
 h.expect(h.call('fusePets','base',{'a','b'}),'APPLIED');eq(h.profile().inventory.guarantees['farmer_dog:1:golden'],1)
 h.expect(h.call('fusePets','base',{'c','d'}),'APPLIED');eq(h.profile().inventory.guarantees['farmer_dog:1:golden'],2)
 h.expect(h.call('prestige'),'APPLIED');eq(h.profile().inventory.guarantees['farmer_dog:1:golden'],2,'prestige preserves guarantee')
 local r=h.call('fusePets','base',{'e','f'});h.expect(r,'APPLIED');eq(r.result.success,true,'next attempt is guaranteed even at roll .99')
 eq(h.profile().inventory.guarantees['farmer_dog:1:golden'],0);h.client:destroy()
end

do
 local h=harness(fusionProfile)
 local r,packet=h.call('togglePetLock','base');h.expect(r,'APPLIED');eq(h.profile().inventory.pets.base.locked,true)
 h.expect(h.server:dispatch('1',packet),'REPLAYED');eq(h.profile().inventory.pets.base.locked,true)
 h.expect(h.call('equipPet','a',1),'APPLIED');eq(h.profile().inventory.equipped[1],'a')
 h.expect(h.call('unequipPet',1),'APPLIED');eq(#h.profile().inventory.equipped,0)
 h.expect(h.call('equipPet','missing',1),'REJECTED','PET_NOT_FOUND');h.client:destroy()
end

-- No client-provided GE prices, grant amounts, random rolls or platform receipts.
do
 local h=harness();local before=assets(h.profile())
 h.expect(h.call('buyBoost','jimbos_blue_v2'),'REJECTED','FEATURE_UNAVAILABLE')
 h.expect(h.call('purchaseProduct','ge_pack_small'),'REJECTED','FEATURE_UNAVAILABLE')
 eq(#h.prompts,0);eq(assets(h.profile()),before);h.client:destroy()
end
do
 local h=harness(nil,{boostShop={mode='INTERNAL_TEST_ONLY',jimbos_blue_v2={costGE='7'}}})
 local r,packet=h.call('buyBoost','jimbos_blue_v2');h.expect(r,'APPLIED')
 eq(h.profile().permanent.GE,'3');eq(h.profile().permanent.totalGESpent,'7');eq(h.profile().inventory.boosts.jimbos_blue_v2,'1')
 h.expect(h.server:dispatch('1',packet),'REPLAYED');eq(h.profile().permanent.GE,'3')
 h.expect(h.call('buyBoost','jimbos_blue_v2'),'REJECTED','INSUFFICIENT_GE');eq(h.profile().inventory.boosts.jimbos_blue_v2,'1');h.client:destroy()
end
do
 local h=harness(nil,{platformProducts={ge_pack_small={platformId=987654321}}});local before=assets(h.profile())
 h.expect(h.call('purchaseProduct','ge_pack_small'),'APPLIED');eq(#h.prompts,0,'disclosure is shown before the purchase prompt')
 h.client.hud.purchasePreviewFrame:FindFirstChild('Confirm').Activated:Fire();eq(#h.prompts,1)
 eq(h.prompts[1].platformId,987654321);eq(h.prompts[1].productType,'developer_product');eq(assets(h.profile()),before,'opening a prompt is not fulfillment')
 h.client:destroy()
end

-- Farm arithmetic oracle: real tick, independent .25 cash/egg, 1 egg /30 chicken-seconds.
do
 local h=harness();local receipt={PlayerId=1,ProductId='ge_pack_small',PurchaseId='external-test-receipt',geAmount=17}
 eq(h.server:applyPurchase('1',receipt),true);eq(h.profile().permanent.GE,'27','explicit trusted fixture amount, not a production pack size')
 eq(h.server:applyPurchase('1',receipt),true);eq(h.profile().permanent.GE,'27','receipt replay cannot pay twice')
 h.client:destroy()
end

-- Real headless GUI signals, not injected success callbacks.
do
 local draws={n=0};local h=harness(fusionProfile,fusionOptions(.1,draws));local hud=h.client.hud
 hud.claimDailyGiftButton.Activated:Fire();eq(h.profile().permanent.GE,'202')
 local p=hud:getPetsModal():FindFirstChild('InventoryFrame')
 p:FindFirstChild('PetCard_1'):FindFirstChild('PetName').Activated:Fire()
 p:FindFirstChild('PetCard_2'):FindFirstChild('PetName').Activated:Fire()
 p:FindFirstChild('PetCard_3'):FindFirstChild('PetName').Activated:Fire()
 eq(hud.fusionBaseUid,'a','base is an owned UID from the view, not a fabricated ID')
 eq(#hud.fusionMaterialUids,2)
 hud.fusePetsButton.Activated:Fire();eq(h.profile().inventory.pets.a.variant,'golden')
 eq(h.profile().inventory.pets.b,nil);eq(h.profile().inventory.pets.base,nil)
 eq(hud.lastActionResult.result.terminalStatus,'APPLIED');h.client:destroy()
end

-- Exact UTC boundary; no catch-up for missed days; claims cannot be repeated.
do
 local h=harness(nil,{startMs=86399999})
 h.expect(h.call('claimDailyGift'),'APPLIED');eq(h.profile().permanent.GE,'202')
 h.now+=2;h.elapsed+=.002
 h.expect(h.call('claimDailyGift'),'APPLIED');eq(h.profile().rewards.numDailyGiftsCollected,2)
 eq(h.profile().inventory.boosts.jimbos_purple_v2,'2')
 h.expect(h.call('claimDailyGift'),'REJECTED','ALREADY_CLAIMED_TODAY');h.client:destroy()
end
-- Authority boundary, two players, stale revision and failed persistence.
do
 local h=harness(fusionProfile);eq(h.server:playerJoined('2').status,'JOINED')
 local packet={protocolVersion=1,kind='TogglePetLock',requestId='cross',operationId='cross',expectedRevision=h.profile().meta.revision,args={petUid='base'}}
 local stranger=h.server:dispatch('2',packet);eq(stranger.status,'REJECTED');eq(h.profile().inventory.pets.base.locked,false)
 local stale=Data.copy(packet);stale.expectedRevision='999';stale.requestId='stale';stale.operationId='stale'
 local refusal=h.server:dispatch('1',stale);eq(refusal.status,'REJECTED');eq(refusal.result.errorCode,'STALE_REVISION');eq(h.profile().inventory.pets.base.locked,false)
 h.refresh();local before=assets(h.profile());h.failBefore=true
 local result=h.call('claimDailyGift');eq(result.status,'UNKNOWN','a storage failure is not success');eq(assets(h.profile()),before)
 h.client:destroy()
end
-- ACK loss does not reroll or duplicate an already committed calendar reward.
do
 local h=harness();h.loseAck=true
 local result,packet=h.call('claimDailyGift')
 eq(result.status,'UNKNOWN');eq(h.records['player:1'].permanent.GE,'202','storage committed, caller remains uncertain')
 eq(h.server:getCoordinator('1').snapshots().ready,false,'unknown result fences the session')
 local called=h.callbacks
 h.client.transport:sendOperationStatus('check-blocked',packet.operationId)
 eq(h.callbacks,called,'a refused status request must not resolve the original operation')
 h.now+=120001;h.elapsed+=120.001
 eq(h.server:getCoordinator('1').recover(packet.operationId).status,'ACQUIRED')
 eq(h.server:getCoordinator('1').setReady(true).status,'READY_SET')
 h.refresh()
 local replay=h.server:dispatch('1',packet);eq(replay.status,'REPLAYED');eq(h.profile().permanent.GE,'202')
 h.client.transport:sendOperationStatus('check-recovered',packet.operationId)
 eq(h.callbacks,called+1,'the original callback survives UNKNOWN and status-admission failures')
 h.client:destroy()
end
-- Premium disclosure is shown before opening Roblox's purchase dialog.
for _,allowed in {true,false} do
 local h=harness(nil,{platformProducts={pro_permit={platformId=987654322}},paidRandomAllowed=function()return allowed end})
 h.expect(h.call('purchaseProduct','pro_permit'),'APPLIED')
 local frame=h.client.hud.purchasePreviewFrame;eq(type(frame:FindFirstChild('Terms').Text),'string')
 eq(#h.prompts,0);frame:FindFirstChild('Cancel').Activated:Fire();eq(#h.prompts,0)
 eq(h.profile().entitlements.pro_permit,nil,'cancel/preview cannot grant Pro');h.client:destroy()
end
do
 local h=harness(nil,{platformProducts={pro_permit={platformId=987654322}}})
 h.expect(h.call('purchaseProduct','pro_permit'),'REJECTED','POLICY_UNAVAILABLE');eq(#h.prompts,0);h.client:destroy()
end
-- Prestiż is a real command; resets farm state and preserves permanent assets.
do
 local h=harness(function(p)p.farm.eggIndex=2;p.farm.cash='900';p.permanent.GE='77';p.permanent.SE='10';p.permanent.PE='2';pet(p,'kept') end)
 h.expect(h.call('prestige'),'APPLIED');eq(h.profile().farm.eggIndex,0);eq(h.profile().farm.cash,'0')
 eq(h.profile().permanent.GE,'77');eq(h.profile().permanent.PE,'2');eq(h.profile().inventory.pets.kept.uid,'kept');eq(h.profile().permanent.prestigeCount,'1')
 h.client:destroy()
end

for _,population in {0,1,30,100,10000} do
 local h=harness(function(p)p.farm.habitats[1].population=tostring(population);p.farm.habitats[1].typeIndex=18 end)
 h.now+=300;h.elapsed+=.3;h.server:tick(.3)
 local working=h.server:getCoordinator('1').snapshots().working
 near(C.BigAmount.decode(working.farm.cash),math.min(population/30,5000/60)*.3*.25,'shipping capped before valuing eggs')
 h.client:destroy()
end

fs.writeFile('build/game-behavior-results.json',serde.encode('json',{status='PASS_L',assertions=assertions,
 oracle='docs + independent reference JSON + conservation/temporal invariants',studioTested=false,realPurchasesTested=false}))
print('Game behavior acceptance: '..assertions..' assertions PASS')
