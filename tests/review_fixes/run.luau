--!strict
-- Approved review corrections, 2026-11-04. Mystery keeps the existing day-28 payout.
-- Each case reports separately so the unfixed snapshot proves every regression.
local fs = require('@lune/fs')
local C = require('../../src/shared/NumericCodec')
local B = require('../../src/server/Bootstrap')
local Schema = require('../../src/server/ProfileSchema').new(C)
local Products = require('../../src/server/platform/products')
local HUD = require('../../src/client/HUD')
local Client = require('../../src/client/Bootstrap')
local Transport = require('../../src/client/ClientTransport')
local State = require('../../src/client/ClientStateStore')
local Controllers = require('../../src/client/IntentControllers')
local Protocol = require('../../src/shared/ProtocolSchemas').new(C)
local Assets = require('../../src/client/ui/UiAssets')
local failures, assertions = 0, 0
local function eq(a: any, b: any, label: string)
 assertions += 1
 assert(a == b, label .. ': expected ' .. tostring(b) .. ', got ' .. tostring(a))
end
local function check(name: string, fn: () -> ())
 local ok, err = pcall(fn)
 print((if ok then 'PASS ' else 'FAIL ') .. name .. (if ok then '' else ': ' .. tostring(err)))
 if not ok then failures += 1 end
end
local function makeHUD(): (any, any)
 local t = Transport.new({protocol=Protocol,wire=function() end})
 local s = State.new({transport=t,codec=C})
 return HUD.new({stateStore=s,intentControllers=Controllers.new({transport=t,stateStore=s,codec=C}),codec=C}),t
end
local function command(b: any, kind: string, args: any, id: string): any
 return b:dispatch('1',{protocolVersion=1,kind=kind,args=args,requestId=id,operationId=id,
  expectedRevision=b:getCoordinator('1').snapshots().durable.meta.revision})
end

check('deferred prophecy purchase cannot spend Diamonds or Robux credits', function()
 local b = B.new({initialNowMs=1000000,platformProducts={epic_upgrade_79={platformId=987654321}}})
 local p = Schema.createReference('1',1000000)
 p.permanent.GE='1000000'
 p.permanent.epicPurchases={credits={epic_upgrade_79='1'}}
 eq(b:playerJoined('1',p).status,'JOINED','join')
 for _,kind in {'BuyEpicResearch','BuyEpicRobux'} do
  local result=command(b,kind,{researchId='prophecy_bonus'},kind)
  eq(result.status,'REJECTED',kind .. ' rejects deferred research')
  eq(result.result.errorCode,'FEATURE_UNAVAILABLE','explicit reason')
  eq(command(b,kind,{researchId='prophecy_bonus'},kind).status,'REPLAYED','rejection replay')
 end
 local after=b:getCoordinator('1').snapshots().durable
 eq(after.permanent.GE,'1000000','no Diamond debit')
 eq(after.permanent.epicPurchases.credits.epic_upgrade_79,'1','no credit debit')
 eq(after.permanent.epic.prophecy_bonus,nil,'no hidden level grant')
end)

check('deferred trophy command rejects without granting resources', function()
 local b=B.new({initialNowMs=1000000})
 local p=Schema.createReference('1',1000000)
 p.farm.habitats[1].population='10000000';p.farm.habitats[1].capacity='10000000'
 eq(b:playerJoined('1',p).status,'JOINED','join')
 local before=b:getCoordinator('1').snapshots().durable
 local result=command(b,'ClaimTrophy',{eggIndex=0,tierIndex=1},'trophy')
 eq(result.status,'REJECTED','deferred trophy unavailable')
 eq(result.result.errorCode,'FEATURE_UNAVAILABLE','reason')
 local after=b:getCoordinator('1').snapshots().durable
 eq(after.permanent.GE,before.permanent.GE,'no Diamond grant')
 eq(after.permanent.SE,before.permanent.SE,'no Soul Egg grant')
 eq(after.permanent.PE,before.permanent.PE,'no PE grant')
end)

check('shop blocks unavailable boost purchase and trophy navigation', function()
 local h=makeHUD();local bought=false
 h.onBuyBoost=function() bought=true end
 local card=h.shopProductCards.jimbos_blue_v2
 local button=card:FindFirstChild('BuyBoostButton')
 eq(button.Active,false,'boost purchase disabled')
 eq(button.Text,'SOON','boost availability disclosed')
 button.Activated:Fire();eq(bought,false,'mock activation cannot dispatch purchase')
 h:selectCalendarTab(2)
 eq(h:getCurrentCalendarTab(),1,'deferred trophy tab cannot open')
 eq(h.calendarModal:FindFirstChild('TrophiesContent_Tab2').Visible,false,'trophies stay hidden')
 local claimed=false
 h.onClaimTrophy=function() claimed=true end
 h.calendarModal:FindFirstChild('TrophiesContent_Tab2'):FindFirstChild('TrophyCard_Egg_0'):FindFirstChild('CupBtn_1').Activated:Fire()
 eq(claimed,false,'retained hidden button cannot dispatch')
 h:destroy()
end)

check('Mystery preserves the approved day-28 reward, replay and reconnect',function()
 local b=B.new({initialNowMs=1000000})
 local p=Schema.createReference('1',1000000)
 p.rewards.numDailyGiftsCollected=27;p.permanent.PE='7'
 eq(b:playerJoined('1',p).status,'JOINED','join')
 local h,t=makeHUD()
 eq(t:receive(b:dispatch('1',{protocolVersion=1,kind='Bootstrap',requestId='mystery-view'})),true,'receive real snapshot')
 h:update()
 eq(h.calendarDayCells[28]:FindFirstChild('RewardText').Text,'🎁 Mystery','day-28 presentation')
 local result=command(b,'ClaimDailyGift',{},'mystery-claim')
 eq(result.status,'APPLIED','claim succeeds')
 eq(result.result.rewardType,'PE','approved existing reward is preserved')
 eq(b:getCoordinator('1').snapshots().durable.permanent.PE,'8','exactly one PE added')
 eq(command(b,'ClaimDailyGift',{},'mystery-claim').status,'REPLAYED','claim is idempotent')
 eq(b:getCoordinator('1').snapshots().durable.permanent.PE,'8','replay grants nothing extra')
 b:playerLeaving('1');eq(b:playerJoined('1').status,'JOINED','reconnect')
 eq(b:getCoordinator('1').snapshots().durable.permanent.PE,'8','existing PE preserved after reconnect')
 h:destroy()
end)

check('PRO offer discloses current benefits and unavailable fusion', function()
 local p=Schema.createReference('1',1000000)
 for _,allowed in {true,false} do
  local preview=Products.previewPurchase(p,'pro_permit',{paidRandomAllowed=allowed})
  eq(preview.isAvailable,true,'base PRO remains available')
  eq(preview.paidBonusAvailable,false,'fusion not currently available')
  eq(string.find(preview.description,'100%',1,true)~=nil,true,'full offline income disclosed')
  eq(string.find(preview.description,'not available in this version',1,true)~=nil,true,'fusion deferred disclosure')
  local b=B.new({initialNowMs=1000000,platformProducts={pro_permit={platformId=987654322}},paidRandomAllowed=function()return allowed end})
  eq(b:playerJoined('1').status,'JOINED','PRO account joined')
  local result=command(b,'PurchaseProduct',{productId='pro_permit'},'pro-preview')
  eq(result.status,'APPLIED','PRO preview command succeeds')
  eq(result.result.paidRandomAllowed,allowed,'account policy is separate from the deferred bonus')
  eq(Protocol.validateServer(result),true,'full PRO disclosure fits the wire limits')
 end
end)

check('PRO can be confirmed for either eligible policy while fusion is deferred',function()
 for _,allowed in {true,false} do
  local b=B.new({initialNowMs=1000000,platformProducts={pro_permit={platformId=987654322}},paidRandomAllowed=function()return allowed end})
  eq(b:playerJoined('1').status,'JOINED','join')
  local prompts=0
  local client=Client.new({playerId='1',wire=b,promptPurchase=function()prompts+=1 end})
  client:connect('pro-confirm-boot');client:purchaseProduct('pro_permit')
  eq(client.hud.purchasePreviewFrame.Visible,true,'terms shown before platform prompt')
  eq(prompts,0,'no prompt before confirmation')
  client.hud.purchasePreviewFrame:FindFirstChild('Confirm').Activated:Fire()
  eq(prompts,1,'base PRO confirmation does not require an active fusion bonus')
  eq(b:getCoordinator('1').snapshots().durable.entitlements.pro_permit,nil,'platform prompt grants no entitlement')
  client:destroy()
 end
end)

check('shop names prestige effects without promising premium currency', function()
 for _,row in Assets.catalogs.EPIC_RESEARCH_CATALOG do
  if row.id=='soul_eggs' or row.id=='prestige_bonus' then
   eq(string.find(row.desc,'Golden Egg',1,true),nil,'Soul Egg research currency')
   eq(string.find(row.desc,'Soul Egg',1,true)~=nil,true,'Soul Egg research explained')
  end
 end
 for _,row in Assets.catalogs.BOOSTS_CATALOG do
  if row.dimension==9 then
   eq(string.find(row.effect,'Golden Egg',1,true),nil,'beacon never promises Diamonds')
   eq(string.find(row.effect,'Prestige Earnings',1,true)~=nil,true,'beacon describes earnings input')
  end
 end
end)

-- The original binder can be run unchanged in isolation on the baseline snapshot.
-- This proves a behavioral failure, not a missing-module/import failure.
local function event(): any
 local listeners={}
 return {Connect=function(_self: any,fn: any) table.insert(listeners,fn) end,
  Fire=function(_self: any,...) for _,fn in listeners do fn(...) end end}
end
local function fixture(): any
 local f: any={now=10,calls=0,jobs={}}
 local function spawn(fn: any)
  local co=coroutine.create(fn)
  local ok,delay=coroutine.resume(co);assert(ok,delay)
  if coroutine.status(co)~='dead' then table.insert(f.jobs,{co=co,due=f.now+delay}) end
 end
 local function waitFor(delay: number) coroutine.yield(delay) end
 f.button={Active=true,Visible=true,MouseButton1Down=event(),MouseButton1Up=event(),MouseLeave=event(),Activated=event()}
 local action=function() f.calls+=1;return true end
 if fs.isFile('src/client/ui/HoldToBuy.luau') then
  local Hold=require('../../src/client/ui/HoldToBuy')
  Hold.bind(f.button,action,{native=true,spawn=spawn,wait=waitFor,isPointerActivation=function(input: any) return input~='gamepad' end})
 else
  local source=fs.readFile('src/client/HUD.luau')
  local start=assert(string.find(source,'local function bindHoldToBuy(',1,true))
  local finish=assert(string.find(source,'local function addShimmerEffect(',start,true))
  local load=assert(loadstring('return function(isRoblox,os,task)\n'..string.sub(source,start,finish-1)..'\nreturn bindHoldToBuy end'))
  load()(true,{clock=function()return f.now end},{spawn=spawn,wait=waitFor})(f.button,action)
 end
 f.advance=function(delta: number)
  local target=f.now+delta
  while true do
   local nextJob=nil
   for i,job in f.jobs do if job.due<=target and (not nextJob or job.due<f.jobs[nextJob].due) then nextJob=i end end
   if not nextJob then break end
   local job=table.remove(f.jobs,nextJob);f.now=job.due
   local ok,delay=coroutine.resume(job.co);assert(ok,delay)
   if coroutine.status(job.co)~='dead' then table.insert(f.jobs,{co=job.co,due=f.now+delay}) end
  end
  f.now=target
 end
 return f
end
check('release at 0.32 seconds buys only once',function()
 local f=fixture();f.button.MouseButton1Down:Fire();f.advance(.32)
 f.button.MouseButton1Up:Fire();f.button.Activated:Fire()
 eq(f.calls,1,'release must not add a second purchase before hold begins')
 f.advance(1);eq(f.calls,1,'release cancels queued repeat')
end)
check('long hold repeats and release adds no extra purchase',function()
 local f=fixture();f.button.MouseButton1Down:Fire();f.advance(.6)
 eq(f.calls,3,'immediate, 0.35 and 0.55 purchases')
 f.button.MouseButton1Up:Fire();f.button.Activated:Fire()
 eq(f.calls,3,'release has no extra purchase')
 f.advance(1);eq(f.calls,3,'repeat stopped')
end)
check('cancelled mouse hold does not swallow gamepad activation',function()
 local f=fixture();f.button.MouseButton1Down:Fire();f.button.MouseLeave:Fire()
 f.button.Activated:Fire('gamepad');eq(f.calls,2,'gamepad is a separate activation')
 f.advance(1);eq(f.calls,2,'mouse cancellation stops repeat')
end)
check('disabled button stops a held repeat',function()
 local f=fixture();f.button.MouseButton1Down:Fire();f.button.Active=false;f.advance(1)
 eq(f.calls,1,'no repeat after disabling')
end)
assert(failures==0,tostring(failures)..' review regression cases failed')
print('Review fixes PASS: '..assertions..' assertions')
