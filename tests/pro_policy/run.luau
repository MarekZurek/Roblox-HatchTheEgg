-- Variant A behavior, driven by current server policy rather than saved flags.
local B=require('../../src/server/Bootstrap')
local C=require('../../src/shared/NumericCodec')
local D=require('../../src/server/PersistenceData')
local Schema=require('../../src/server/ProfileSchema').new(C)
local Products=require('../../src/server/platform/products')
local Main=require('../support/MainHarness')
local Client=require('../../src/client/Bootstrap')
local fs,serde=require('@lune/fs'),require('@lune/serde')
local assertions=0
local function eq(a,b,label)assertions+=1;assert(a==b,(label or '')..' expected '..tostring(b)..' got '..tostring(a))end
local PASS=987654322
local function main(options)
 options=options or {};options.attributes={pro_permit_PlatformId=PASS};options.assertEqual=eq
 return Main.new(options)
end
local function jobs(h,list,reverse)
 if reverse then for i=#list,1,-1 do h.runJob(list[i])end else for _,i in list do h.runJob(i)end end
end
local function view(h)
 h.remote({protocolVersion=1,kind='Bootstrap',requestId='policy-view'})
 return h.messages[#h.messages].message.view.farm.progress
end
local function pets(p)
 for _,id in {'base','a','b'}do p.inventory.pets[id]={uid=id,speciesId='farmer_dog',tier=1,variant='normal',locked=false}end
end
local function fusionPolicy()
 return {mode='INTERNAL_TEST_ONLY',recipes={['1:golden']={requiredMaterials=2,baseChance=.4,guaranteeThreshold=2}},draw=function()return .45 end}
end

-- Missing, malformed, throwing or yielding policy never implies authorization.
local providers={
 function()return nil end,function()return 1 end,function()return 'true'end,
 function()return {}end,function()error('policy unavailable')end,function()coroutine.yield('unexpected I/O')end,
}
for _,provider in providers do
 eq(Products.readPaidRandomPolicy(provider,'1'),nil)
 local b=B.new({paidRandomAllowed=provider});eq(b:playerJoined('1').status,'JOINED')
 eq(b:grantEntitlement('1','pro_permit',{paidRandomAllowed=true}),true)
 local p=b:getCoordinator('1').snapshots().durable
 eq(p.entitlements.pro_permit,true,'base Pro survives unknown policy')
 eq(p.entitlements.pro_plus10_enabled,false,'caller context is not permission')
end
do
 local b=B.new();b:playerJoined('1');eq(b:grantEntitlement('1','pro_permit'),true)
 eq(b:getCoordinator('1').snapshots().durable.entitlements.pro_plus10_enabled,false)
end

-- Current policy at fulfillment, not receipt flags or the earlier preview.
for _,state in {'allowed','restricted','unknown'}do
 local p=Schema.createReference('1',1000000)
 eq(Products.preparePurchase(p,'pro_permit','pro',1000000,{paidRandomAllowed=true}),true)
 local context=if state=='unknown' then nil else {paidRandomAllowed=state=='allowed'}
 eq(Products.confirmPurchase(p,'pro',{paidRandomAllowed=true},1000001,nil,context),true)
 eq(p.entitlements.pro_permit,true)
 eq(p.entitlements.pro_plus10_enabled,state=='allowed')
end
for _,state in {'allowed','restricted','unknown'}do
 local p=Schema.createReference('1',1000000)
 local context=if state=='unknown' then nil else {paidRandomAllowed=state=='allowed'}
 local preview=Products.previewPurchase(p,'pro_permit',context)
 eq(preview.paidBonusAvailable,state=='allowed')
 eq(preview.isAvailable,state~='unknown')
 if state=='restricted' then eq(string.find(preview.description,'disabled',1,true)~=nil,true)end
 if state=='unknown' then eq(preview.error,'POLICY_UNAVAILABLE')end
end

-- Actual Main: both task orderings; all boolean/error/malformed API outcomes.
for _,state in {'allowed','restricted','error','missing','malformed'}do
 for _,reverse in {false,true}do
  local h=main()
  if state=='restricted' then h.policyResponse={ArePaidRandomItemsRestricted=true}
  elseif state=='error' then h.policyFailure=true
  elseif state=='missing' then h.policyResponse={}
  elseif state=='malformed' then h.policyResponse={ArePaidRandomItemsRestricted='false'}end
  local list=h.join();jobs(h,list,reverse)
  local p=view(h)
  eq(p.proPermit,true,'ownership is independent of policy request order')
  eq(p.proBonusAvailable,state=='allowed')
  eq(p.paidRandomPolicy,if state=='allowed' then 'allowed' elseif state=='restricted' then 'restricted' else 'unknown')
  eq(h.profile().entitlements.pro_permit,true)
 end
end

-- Old saved flags are never enabled before the new session obtains policy.
do
 local p=Schema.createReference('1',1000000);p.entitlements={pro_permit=true,pro_plus10_enabled=true}
 local h=main({records={['player:1']=p}});h.join()
 eq(view(h).proBonusAvailable,false);eq(view(h).paidRandomPolicy,'unknown')
end

-- Fresh policy is consulted before purchase disclosure; restricted accounts retain Pro.
do
 local h=main({owns={[PASS]=false}});jobs(h,h.join())
 h.policyResponse={ArePaidRandomItemsRestricted=true};local calls=h.policyCalls
 h.remote({protocolVersion=1,kind='PurchaseProduct',requestId='pro-preview',operationId='pro-preview',expectedRevision=h.profile().meta.revision,args={productId='pro_permit'}})
 eq(h.policyCalls,calls+1)
 local preview=h.messages[#h.messages].message
 eq(preview.status,'APPLIED');eq(preview.result.paidBonusAvailable,false)
 eq(string.find(preview.result.description,'disabled',1,true)~=nil,true)
 h.market.PromptGamePassPurchaseFinished:Fire(h.player,PASS,true)
 eq(h.profile().entitlements.pro_permit,true);eq(h.profile().entitlements.pro_plus10_enabled,false)
 h.runJob(#h.jobs);eq(view(h).proBonusAvailable,false)
end

-- A new account policy read can enable/disable the modifier without losing ownership.
do
 local p=Schema.createReference('1',1000000);pets(p)
 local h=main({records={['player:1']=p}});jobs(h,h.join())
 eq(view(h).proBonusAvailable,true)
 h.server.fusionPolicy=fusionPolicy();h.policyResponse={ArePaidRandomItemsRestricted=true}
 h.remote({protocolVersion=1,kind='FusePets',requestId='restricted-fusion',operationId='restricted-fusion',expectedRevision=h.profile().meta.revision,args={basePetId='base',materialIds={'a','b'}}})
 local result=h.messages[#h.messages].message;eq(result.status,'APPLIED');eq(result.result.success,false,'.45 loses at .40; ownership alone cannot make it .50')
 eq(h.profile().inventory.pets.base.variant,'normal');eq(view(h).proPermit,true);eq(view(h).proBonusAvailable,false)
end

-- Late responses from an older request or a removed player cannot enable the modifier.
do
 local h=main();local list=h.join();local calls=0
 h.onPolicy=function()calls+=1;if calls==1 then return coroutine.yield('pending')end;return {ArePaidRandomItemsRestricted=true}end
 local old=coroutine.create(function()h.runJob(list[1])end)
 local ok,state=coroutine.resume(old);eq(ok,true);eq(state,'pending')
 h.market.PromptGamePassPurchaseFinished:Fire(h.player,PASS,true)
 h.runJob(#h.jobs);eq(view(h).paidRandomPolicy,'restricted')
 eq(coroutine.resume(old,{ArePaidRandomItemsRestricted=false}),true)
 eq(view(h).proBonusAvailable,false);eq(view(h).paidRandomPolicy,'restricted')
end
do
 local h=main();local list=h.join()
 h.onPolicy=function()return coroutine.yield('old player')end
 local old=coroutine.create(function()h.runJob(list[1])end);eq(coroutine.resume(old),true)
 local departed=h.player;h.services.Players.PlayerRemoving:Fire(departed);departed.Parent=nil
 h.player=h.addPlayer(1);h.onPolicy=nil;h.policyResponse={ArePaidRandomItemsRestricted=true}
 jobs(h,h.join());eq(view(h).paidRandomPolicy,'restricted')
 eq(coroutine.resume(old,{ArePaidRandomItemsRestricted=false}),true)
 eq(view(h).proBonusAvailable,false)
end

-- A command suspended in a platform read cannot apply to a replacement session.
do
 local p=Schema.createReference('1',1000000);pets(p)
 local h=main({records={['player:1']=p}});jobs(h,h.join());h.server.fusionPolicy=fusionPolicy()
 h.onPolicy=function()return coroutine.yield('old command')end
 local old=coroutine.create(function()
  h.remote({protocolVersion=1,kind='FusePets',requestId='old-command',operationId='old-command',expectedRevision=h.profile().meta.revision,args={basePetId='base',materialIds={'a','b'}}})
 end)
 eq(coroutine.resume(old),true)
 local departed=h.player;h.services.Players.PlayerRemoving:Fire(departed);departed.Parent=nil
 h.player=h.addPlayer(1);h.onPolicy=nil;h.policyResponse={ArePaidRandomItemsRestricted=true};jobs(h,h.join())
 local before=D.fingerprint(h.profile().inventory)
 eq(coroutine.resume(old,{ArePaidRandomItemsRestricted=false}),true)
 eq(h.profile().operations['old-command'],nil);eq(D.fingerprint(h.profile().inventory),before)
end

-- Restricted/unknown eligibility does not remove the five owned Pro pet slots.
do
 local p=Schema.createReference('1',1000000)
 for i=1,5 do local id='pet-'..i;p.inventory.pets[id]={uid=id,speciesId='farmer_dog',tier=1,variant='normal',locked=false}end
 local h=main({records={['player:1']=p}});h.policyFailure=true;jobs(h,h.join(),true)
 for i=1,5 do eq(h.server:equipPet('1','pet-'..i),true)end
 eq(#h.profile().inventory.equipped,5);eq(view(h).proBonusAvailable,false);eq(view(h).proPermit,true)
end

-- One pending policy read per player; a concurrent request does not create a second.
do
 local h=main({owns={[PASS]=false}});local list=h.join()
 h.onPolicy=function()return coroutine.yield('pending')end
 local pending=coroutine.create(function()h.runJob(list[1])end);eq(coroutine.resume(pending),true)
 local calls=h.policyCalls
 h.remote({protocolVersion=1,kind='PurchaseProduct',requestId='pending-pro',operationId='pending-pro',expectedRevision=h.profile().meta.revision,args={productId='pro_permit'}})
 eq(h.policyCalls,calls)
 local result=h.messages[#h.messages].message;eq(result.status,'REJECTED');eq(result.result.errorCode,'POLICY_UNAVAILABLE')
 eq(coroutine.resume(pending,{ArePaidRandomItemsRestricted=false}),true)
 eq(view(h).paidRandomPolicy,'allowed')
end

-- Model tests use explicit server-only recipe fixtures; no production fusion enabled.
local function model(allowed,owned,flag)
 local cell={value=allowed};local records={};local beforeWrite
 local store={read=function(k)return true,records[k] and D.copy(records[k])end,update=function(k,cb)
  if beforeWrite then local hook=beforeWrite;beforeWrite=nil;hook()end
  local value=cb(records[k] and D.copy(records[k]));if value then records[k]=D.copy(value)end;return true,value and D.copy(value)
 end}
 local b=B.new({store=store,paidRandomAllowed=function()return cell.value end,fusionPolicy=fusionPolicy(),platformProducts={pro_permit={platformId=PASS}}})
 local p=Schema.createReference('1',1000000);pets(p);p.entitlements={pro_permit=owned,pro_plus10_enabled=flag}
 b:playerJoined('1',p);b:dispatch('1',{protocolVersion=1,kind='Bootstrap',requestId='boot'})
 local h={b=b,cell=cell}
 function h.profile()return b:getCoordinator('1').snapshots().durable end
 function h.request(kind,args,id)
  return b:dispatch('1',{protocolVersion=1,kind=kind,requestId=id,operationId=id,expectedRevision=h.profile().meta.revision,args=args})
 end
 function h.before(fn)beforeWrite=fn end
 return h
end
for _,case in {{allowed=true,owned=true,flag=false,win=true},{allowed=false,owned=true,flag=true,win=false},{owned=true,flag=true,win=false},{allowed=true,owned=false,flag=true,win=false}}do
 local h=model(case.allowed,case.owned,case.flag)
 local r=h.request('FusePets',{basePetId='base',materialIds={'a','b'}},'fusion')
 eq(r.status,'APPLIED');eq(r.result.success,case.win)
end
do
 local h=model(true,true,false);local before=D.fingerprint(h.profile().inventory)
 h.before(function()h.cell.value=false end)
 local r=h.request('FusePets',{basePetId='base',materialIds={'a','b'}},'policy-race')
 eq(r.status,'REJECTED');eq(r.result.errorCode,'POLICY_CHANGED');eq(D.fingerprint(h.profile().inventory),before)
end
do
 local h=model(true,false,false);h.before(function()h.cell.value=false end)
 local r=h.request('PurchaseProduct',{productId='pro_permit'},'preview-race')
 eq(r.status,'REJECTED');eq(r.result.errorCode,'POLICY_CHANGED');eq(h.profile().entitlements.pro_permit,false)
end
do
 local h=model(true,false,false);eq(h.b:grantEntitlement('1','pro_permit'),true)
 local first=h.profile().entitlements.pro_permit_effective_at
 h.cell.value=false;eq(h.b:grantEntitlement('1','pro_permit',{paidRandomAllowed=true}),true)
 eq(h.profile().entitlements.pro_plus10_enabled,false);eq(h.profile().entitlements.pro_permit_effective_at,first)
end

-- UI disclosure and confirmation use the same private policy view, not an old flag.
do
 local h=model(true,false,false);local prompts=0;local client
 client=Client.new({playerId='1',wire=function(packet)local response=h.b:dispatch('1',packet);eq(client:receive(response),true)end,promptPurchase=function()prompts+=1 end})
 client:connect('client-boot');client:purchaseProduct('pro_permit')
 eq(client.hud.purchasePreviewFrame.Visible,true);eq(prompts,0)
 h.cell.value=false;client.transport:sendRefreshState()
 client.hud.purchasePreviewFrame:FindFirstChild('Confirm').Activated:Fire()
 eq(prompts,0);eq(client.hud.lastActionResult.errorCode,'POLICY_CHANGED')
 client:purchaseProduct('pro_permit')
 eq(string.find(client.hud.purchasePreviewFrame:FindFirstChild('Terms').Text,'disabled',1,true)~=nil,true)
 client.hud.purchasePreviewFrame:FindFirstChild('Confirm').Activated:Fire()
 eq(prompts,1);eq(h.profile().entitlements.pro_permit,false,'prompt is not ownership')
 client:destroy()
end
do
 local h=model(true,true,false);local client
 client=Client.new({playerId='1',wire=function(packet)eq(client:receive(h.b:dispatch('1',packet)),true)end})
 client:connect('owned-boot');eq(client:getStore():getFarm().progress.proBonusAvailable,true)
 h.cell.value=nil;client.transport:sendRefreshState()
 eq(client:getStore():getFarm().progress.proBonusAvailable,false)
 eq(string.find(client.hud.fusionProPermitBadge.Text,'nieznana',1,true)~=nil,true)
 client:destroy()
end

fs.writeFile('build/pro-policy-results.json',serde.encode('json',{status='PASS_L',assertions=assertions,actualMainEntrypoint=true,studioTested=false,realPolicyServiceTested=false,realPurchasesTested=false}))
print('Pro account policy: '..assertions..' assertions PASS')
