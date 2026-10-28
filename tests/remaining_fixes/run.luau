--!strict
-- Integration regressions for #85, #86, #90/#91. No real platform purchases.
local B=require('../../src/server/Bootstrap')
local C=require('../../src/shared/NumericCodec')
local S=require('../../src/server/ProfileSchema').new(C)
local Products=require('../../src/server/platform/products')
local Policy=require('../../src/shared/FeatureAvailability')
local serde=require('@lune/serde')
local count=0
local function eq(a: any,b: any,label: string)
 count+=1; assert(a==b,label..': '..tostring(a)..' != '..tostring(b))
end
local function near(a: number,b: number,label: string)
 count+=1; assert(math.abs(a-b)<1e-10,label)
end
local ORIGIN=1000000
local function make(mutate: any,events: any?)
 local b=B.new({initialNowMs=ORIGIN,liveEvents=events or {}})
 local p=S.createReference('1',ORIGIN);p.permanent.GE='1000000'
 mutate(p);eq(b:playerJoined('1',p).status,'JOINED','joined')
 return b
end
local function command(b: any,kind: string,args: any,id: string)
 return b:dispatch('1',{protocolVersion=1,kind=kind,args=args,requestId=id,operationId=id,expectedRevision=b:getCoordinator('1').snapshots().durable.meta.revision})
end
for _,pair in {{'afx_mission_time','afx_mission_time'},{'afx_mission_capacity','afx_mission_capacity'},{'afx_ship_capacity','afx_mission_capacity'},{'hold_to_research','hold_to_research'},{'epic_silo_quality','epic_silo_quality'},{'silo_quality','epic_silo_quality'},{'warp_shift','warp_shift'}} do
 for _,oldLevel in {0,2} do
  local b=make(function(p) if oldLevel>0 then p.permanent.epic[pair[2]]=oldLevel end end)
  local requestId='blocked-'..pair[1]
  local result=command(b,'BuyEpicResearch',{researchId=pair[1]},requestId)
  eq(result.status,'REJECTED','unsupported effect rejected')
  eq(result.result.errorCode,'FEATURE_UNAVAILABLE','availability reason')
  command(b,'BuyEpicResearch',{researchId=pair[1]},requestId)
  local p=b:getCoordinator('1').snapshots().durable
  eq(p.permanent.GE,'1000000','no debit on rejection/retry')
  eq(p.permanent.totalGESpent,'0','no spend recorded')
  eq(p.permanent.epic[pair[2]],if oldLevel>0 then oldLevel else nil,'existing level preserved')
  eq(p.permanent.epic[pair[1]],if pair[1]==pair[2] and oldLevel>0 then oldLevel else nil,'alias cannot create a level')
  local allowed=command(b,'BuyEpicResearch',{researchId='hold_to_hatch'},'allowed')
  eq(allowed.status,'APPLIED','supported research still purchasable')
  eq(b:getCoordinator('1').snapshots().durable.permanent.GE,'999990','supported price charged once')
 end
end
for _,id in {'auto_hatch','buy_max','epic_tier_1','epic_tier_2','epic_tier_3','epic_tier_4'} do
 local p=S.createReference('1',ORIGIN)
 p.entitlements.buy_max=true -- historical ownership is not removed by gating new sales
 eq(Policy.isProductAvailable(id),false,'shared policy')
 local before=serde.encode('json',p.permanent)
 local prepared,_,reason=Products.preparePurchase(p,id,'new',ORIGIN)
 eq(prepared,false,'planned product cannot reserve a purchase')
 eq(reason,'PRODUCT_UNAVAILABLE_AT_LAUNCH','planned product reason')
 eq(p.operations.new,nil,'no reservation written')
 p.operations.old={productId=id,terminalStatus='RESERVED'}
 local confirmed=Products.confirmPurchase(p,'old',nil,ORIGIN)
 eq(confirmed,false,'old pending reservation cannot grant unavailable product')
 eq(p.accounting.processedReceipts.old,nil,'no false receipt success')
 eq(serde.encode('json',p.permanent),before,'no economic mutation')
 eq(p.entitlements.buy_max,true,'existing ownership preserved')
end
for _,offset in {0,999,1000,1001} do
 local b=make(function(p)
  p.farm.cash='100'
  p.accounting.currentFarmCash='1000000';p.accounting.prestigeSessionArchivedCash='1000000';p.accounting.prestigeExtraEarnings='1000000'
 end,{{id='prestige4',type='prestige',multiplier=4,startTimeMs=ORIGIN,deadlineMs=ORIGIN+1000}})
 b.clock.advance(offset/1000);b:tick(0)
 local view=b:dispatch('1',{protocolVersion=1,kind='Bootstrap',requestId='view'})
 local preview=C.Real64.decode(view.view.farm.progress.pendingSE)
 near(preview,3000000^.15*(if offset<1000 then 4 else 1),'event start and deadline semantics')
 eq(command(b,'Prestige',{},'prestige').status,'APPLIED','prestige applied')
 near(C.Real64.decode(b:getCoordinator('1').snapshots().durable.permanent.SE),preview,'preview equals actual grant')
end
-- A connected view must refresh the preview when the event expires, not retain x4.
do
 local b=make(function(p)p.accounting.currentFarmCash="3000000" end,{{id='expiry',type='prestige',multiplier=4,startTimeMs=ORIGIN,deadlineMs=ORIGIN+1000}})
 b:dispatch('1',{protocolVersion=1,kind='Bootstrap',requestId='initial'})
 b.clock.advance(1);b:tick(0)
 local delta=b:createPlayerDelta('1')
 near(C.Real64.decode(delta.changes.farm.progress.pendingSE),3000000^.15,'event expiry changes the connected view')
end
local Client=require('../../src/client/Bootstrap')
for _,status in {'REJECTED','APPLIED'} do
 local sounds=0
 local client={audioController={playSFX=function()sounds+=1 end},onHitDrone=function()return {status=status} end,onClaimOffer=function()return {status=status} end}
 eq(Client.hitDrone(client,'drone').status,status,'drone result forwarded')
 eq(Client.claimOffer(client,'offer').status,status,'offer result forwarded')
 eq(sounds,0,'reward sound belongs to confirmed popup, not request')
end
print('Remaining fixes PASS: '..count..' assertions')
