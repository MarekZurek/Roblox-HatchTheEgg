local B=require('../../src/server/Bootstrap')
local C=require('../../src/shared/NumericCodec')
local S=require('../../src/server/ProfileSchema').new(C)
local D=require('../../src/server/PersistenceData')
local serde=require('@lune/serde')
local results={}
local function run(name,fn)
 local ok,value=pcall(fn);results[name]={ok=ok,value=if ok then value else tostring(value)}
end
local function server(egg,boost)
 local b=B.new();local p=S.createReference('1',1000000)
 p.farm.habitats[1].population='100';p.farm.eggIndex=egg or 0
 if boost then p.effects.boosts={{id='jimbos_blue_v2',remainingSeconds=1000}} end
 assert(b:playerJoined('1',p));return b
end
local function snap(b)return b:getCoordinator('1').snapshots()end
run('client_controls_pet_result',function()
 local b=server();local before=snap(b).durable.permanent.GE
 local ok,r=b:hatchPet('1',{costGE=0,roll=0,variantRoll=0,petUid='attacker-selected'})
 local after=snap(b).durable
 return {success=ok,geBefore=before,geAfter=after.permanent.GE,pet=after.inventory.pets['attacker-selected'],result=r}
end)
run('invented_drone_ids',function()
 local b=server();local before=snap(b).durable.permanent.GE
 local a,x=b:hitDrone('1','never-spawned-1');local c,y=b:hitDrone('1','never-spawned-2')
 return {first=a,second=c,reward1=x,reward2=y,geBefore=before,geAfter=snap(b).durable.permanent.GE,cashAfter=snap(b).durable.farm.cash}
end)
run('invented_offer_id',function()
 local b=server();local ok,r=b:claimOffer('1','never-offered')
 return {success=ok,result=r,cash=snap(b).durable.farm.cash}
end)
run('production_egg_and_effects',function()
 local values={}
 for _,case in {{name='edible',egg=0},{name='superfood',egg=1},{name='jimbo3',egg=0,boost=true}} do
  local b=server(case.egg,case.boost);b:tick(1)
  local p=snap(b).working
  values[case.name]={cash=p.farm.cash,boosts=p.effects.boosts,settled=p.timeline.settledWallThrough}
 end
 return values
end)
run('restricted_pro_default',function()
 local b=server();local ok,r=b:grantEntitlement('1','pro_permit')
 return {success=ok,entitlements=snap(b).durable.entitlements}
end)
run('client_fake_success',function()
 local Client=require('../../src/client/Bootstrap');local sends=0
 local client=Client.new({playerId='1',send=function()sends+=1 end})
 local a=client:claimDailyGift();local b=client:fusePets('none',{'none2'});local c=client:purchaseProduct('ge_pack_small')
 return {daily=a,fusion=b,purchase=c,networkSends=sends}
end)
run('prestige_resets_group_sequence',function()
 local P=require('../../src/server/ProgressActions');local p=S.createReference('1',1000000)
 p.farm.hatchGroupSequence='123';p.accounting.currentFarmCash='1000000'
 local out=P.applyPrestige(p,{kind='Prestige',args={}})
 return {status=out.terminalStatus,sequence=out.profile.farm.hatchGroupSequence}
end)
run('soul_and_pet_production',function()
 local values={}
 for _,kind in {'base','soul','pet'} do
  local b=B.new();local p=S.createReference('1',1000000);p.farm.habitats[1].population='100'
  if kind=='soul' then p.permanent.SE='1000';p.permanent.PE='2' end
  if kind=='pet' then p.inventory.pets={dog={uid='dog',speciesId='farmer_dog',tier=1,variant='normal',locked=false}};p.inventory.equipped={'dog'} end
  assert(b:playerJoined('1',p));b:tick(1);values[kind]=snap(b).working.farm.cash
 end
 return values
end)
run('unsupported_player_commands',function()
 local b=server();local out={}
 for _,kind in {'Prestige','ClaimDailyGift','ClaimTrophy','FusePets','BuyBoost'} do
  out[kind]=b:dispatch('1',{protocolVersion=1,kind=kind,requestId='audit-'..kind,operationId='audit-'..kind,expectedRevision='0',args={}})
 end
 return out
end)
run('event_boundary_not_weighted',function()
 local b=server();local p=snap(b).durable;local f=D.copy(p.farm)
 f.cash=0;f.hatcheryStock=250;f.commonLevels={};f.vehicleTypes={0}
 for i,h in f.habitats do h.capacity=if i==1 then '250' else '0';h.fractionalIHR=0 end
 local a=D.copy(p.accounting);for k in a do a[k]=0 end
 local state={farm=f,accounting=a,settledWallThrough=1000000}
 local cp=b.timeline.begin(state,1000300,{revision='audit',pro=false,siloCapacityLevel=0,liveEvents={{id='e',type='earnings',multiplier=3,startTimeMs=1000000,deadlineMs=1000100}}})
 cp=b.timeline.advance(cp,10)
 return {cash=cp.state.farm.cash,expectedWeighted=(100/30*.25)*(.1*3+.2)}
end)
print(serde.encode('json',results,true))
require('@lune/fs').writeFile('build/audit_20261025_results.json',serde.encode('json',results,true))

