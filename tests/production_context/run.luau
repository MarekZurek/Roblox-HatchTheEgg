-- Actual Bootstrap/Timeline/Repository regressions; independent arithmetic expectations.
local B=require('../../src/server/Bootstrap')
local C=require('../../src/shared/NumericCodec')
local D=require('../../src/server/PersistenceData')
local S=require('../../src/server/ProfileSchema').new(C)
local Progress=require('../../src/server/ProgressActions')
local fs,serde=require('@lune/fs'),require('@lune/serde')
local assertions=0
local function eq(a,b,label)assertions+=1;assert(a==b,(label or '')..' expected '..tostring(b)..' got '..tostring(a))end
local function near(a,b)assertions+=1;assert(math.abs(a-b)<=math.max(1,math.abs(b))*1e-12,tostring(a)..' != '..tostring(b))end
local function create(mutate,options)
 options=options or {};options.initialNowMs=10000000
 local b=B.new(options);local p=S.createReference('1',10000000);p.farm.habitats[1].population='100'
 if mutate then mutate(p) end
 local joined=b:playerJoined('1',p);eq(joined.status,'JOINED')
 return b,joined
end
local function state(b)return b:getCoordinator('1').snapshots()end
local function step(b,seconds)
 b:tick(seconds)
 local n=0
 while not state(b).ready and state(b).working do b:tick(0);n+=1;assert(n<5000,'settling stalled') end
 eq(state(b).ready,true)
 return state(b).working
end
local function cash(p)return C.BigAmount.decode(p.farm.cash)end
local function pet(p,id,bonuses)
 p.inventory.pets[id]={uid=id,speciesId='fixture',tier=1,variant='normal',locked=false,customBonus=bonuses}
 table.insert(p.inventory.equipped,id)
end
-- Catalog values from reference_data/infrastructure; not values from the function under test.
for index,value in { [0]=1.0,[1]=3.0,[2]=10.0,[17]=1.5e14,[18]=1e-7 } do
 local b=create(function(p)p.farm.eggIndex=index end)
 near(cash(step(b,.3)),value)
end
for _,case in {{se='0',pe='0',sf=0,pb=0,m=1},{se='1000',pe='2',sf=0,pb=0,m=111.25},
 {se='1000',pe='2',sf=2,pb=3,m=1+1000*.12*1.08^2},{se='0',pe='18446744073709551615',sf=0,pb=0,m=1}} do
 local b=create(function(p)p.permanent.SE=case.se;p.permanent.PE=case.pe;p.permanent.epic={soul_eggs=case.sf,prophecy_bonus=case.pb}end)
 local p=step(b,.3);near(cash(p),1.0*case.m);eq(p.permanent.PE,case.pe)
end
do
 local b=create(function(p)p.permanent.epic.epic_egg_laying=1 end);near(cash(step(b,.3)),1.0*1.05)
end
do
 local b=create(function(p)pet(p,'a',{eggValueMult=.5});pet(p,'b',{eggValueMult=.5})end)
 near(cash(step(b,.3)),2.0)
 local h=create(function(p)pet(p,'lay',{layingRateMult=100})end)
 near(cash(step(h,.3)),(5000/60*.3)*1.0) -- laying increase is capped BEFORE sale, not after
end
do
 local b=create(function(p)
  pet(p,'dog',{eggValueMult=.5});pet(p,'alien',{boostBoostMult=.5})
  p.effects.boosts={{id='jimbos_blue_v2',remainingSeconds='10'},{id='boost_beacon_blue',remainingSeconds=10}}
  p.effects.videoDoublerEndsAtMs=10010000
 end)
 local p=step(b,.3);near(cash(p),1.0*1.5*(3*2*1.5))
 near(C.Real64.decode(p.effects.boosts[1].remainingSeconds),9.7)
 local snapshot=b:dispatch('1',{protocolVersion=1,kind='Bootstrap',requestId='view'})
 near(C.BigAmount.decode(snapshot.view.farm.cashIncomePerSecond),(100*(1/30))*1.0*1.5*(3*2*1.5))
end
do
 local b=create(function(p)pet(p,'alien',{boostBoostMult=100})end)
 near(cash(step(b,.3)),1.0) -- no boost category means neutral, not 101x
 local p=step(b,.3);near(cash(p),2.0)
end
do
 local b=create(function(p)
  p.farm.common={internal_hatchery1=1};p.farm.habitats[1].population='0';p.farm.habitats[1].fractionalIHR='0.8'
  pet(p,'ihr',{ihrMult=.5});pet(p,'alien',{boostBoostMult=.5})
  p.effects.boosts={{id='tachyon_prism_blue_v2',remainingSeconds=10},{id='boost_beacon_blue',remainingSeconds=10}}
 end)
 local p=step(b,.3);eq(p.farm.habitats[1].population,'1');near(C.Real64.decode(p.farm.habitats[1].fractionalIHR),.25);eq(cash(p),0)
 near(cash(step(b,.3)),1*(1/30)*.3*1.0)
end
do
 local b=create(function(p)
  p.farm.habitats[1].population='375';pet(p,'cow',{habCapacityMult=.5})
 end)
 local p=step(b,.3);eq(p.farm.habitats[1].capacity,'375');eq(p.farm.habitats[1].population,'375')
 eq(b:unequipPet('1','cow'),true)
 p=step(b,.3);eq(p.farm.habitats[1].capacity,'250');eq(p.farm.habitats[1].population,'375');near(cash(p),7.5)
end
do
 local b=create(function(p)p.farm.common.hab_capacity1=1;pet(p,'cow',{habCapacityMult=.1})end)
 eq(step(b,.3).farm.habitats[1].capacity,'289') -- ceil(250*1.05*1.1), not ceil(ceil(250*1.05)*1.1)
 eq(pcall(function()b.productionMath.productionStep({commonLevels={},habitatTypes={0,0,false,false},settledPopulation={'5000000000000000','5000000000000000','0','0'},vehicleTypes={0},permitExistingPopulation=true},.3)end),false)
end
do
 local b=create(function(p)p.effects.boosts={{id='jimbos_blue_v2',remainingSeconds='0'}}end)
 local p=step(b,.3);near(cash(p),3.0);eq(#p.effects.boosts,0)
 near(cash(step(b,.3)),4.0)
 local d=create(function(p)p.effects.videoDoublerEndsAtMs=10000300 end)
 near(cash(step(d,.3)),1.0) -- legacy deadline has no effect
end
do
 local b=create(function(p)
  p.farm.eggIndex=18;pet(p,'all',{eggValueMult=100,layingRateMult=100,ihrMult=100,habCapacityMult=100,boostBoostMult=100,prestigeEarningsMult=100})
  p.effects.boosts={{id='jimbos_blue_v2',remainingSeconds='10'}}
 end)
 local p=step(b,.3);near(cash(p),1e-7);eq(p.effects.boosts[1].remainingSeconds,'10');eq(p.farm.habitats[1].capacity,'250');eq(#p.inventory.equipped,1)
end
do
 local b=create(function(p)
  p.accounting.prestigeSessionArchivedCash='1000';p.accounting.lastBaseEarnings='1000'
  pet(p,'phoenix',{prestigeEarningsMult=.5});p.effects.boosts={{id='soul_beacon_blue_v2',remainingSeconds=10}}
 end)
 local p=step(b,.3);near(cash(p),1.0);near(C.BigAmount.decode(p.accounting.prestigeExtraEarnings),1.0*(5*1.5-1))
 eq(p.accounting.prestigeSessionArchivedCash,'1000');eq(p.permanent.SE,'0')
end
-- An equipment change settles elapsed time with the old set before the new bonus.
do
 local b=create(function(p)p.inventory.pets.dog={uid='dog',speciesId='fixture',tier=1,variant='normal',locked=false,customBonus={eggValueMult=.5}}end)
 b.clock.advance(.3);eq(b:equipPet('1','dog'),true)
 near(cash(state(b).durable),1.0)
 near(cash(step(b,.3)),1.0+1.5)
end
-- Both a real UpgradeEgg command and a real Prestige result feed future production.
do
 local b,joined=create(function(p)p.permanent.SE='1000000000000' end)
 b.clock.advance(.3)
 local result=b:dispatch('1',{protocolVersion=1,kind='UpgradeEgg',requestId='up',operationId='up',expectedRevision='0',args={targetEggIndex=1}})
 eq(result.status,'APPLIED');local p=state(b).durable;eq(p.farm.eggIndex,1)
 near(C.BigAmount.decode(p.accounting.prestigeSessionArchivedCash),1.0*(1+1e12*.1))
 -- Actual hatch -> actual arrival; reset population isn't replaced by a test grant.
 eq(b:dispatch('1',{protocolVersion=1,kind='HatchPress',requestId='h',streamId=joined.streamId,inputSeq='1'}).kind,'HatchPress')
 step(b,4);local before=cash(state(b).working);near(cash(step(b,.3))-before,1*(1/30)*.3*3.0*(1+1e12*.1))
end
do
 local b,joined=create(function(p)p.accounting.currentFarmCash='1000000' end)
 local actor=b:getCoordinator('1');eq(actor.submit({operationId='prestige',kind='Prestige',expectedRevision='0',args={}}).status,'PENDING');actor.drain()
 eq(actor.resultOf('prestige').status,'APPLIED');near(C.Real64.decode(state(b).durable.permanent.SE),1e6^.15)
 b:dispatch('1',{protocolVersion=1,kind='HatchPress',requestId='h',streamId=joined.streamId,inputSeq='1'})
 step(b,4);local before=cash(state(b).working);near(cash(step(b,.3))-before,(1/30)*.3*1.0*(1+1e6^.15*.1))
end
-- Serialization after production but before growth resumes the same frozen bonuses.
do
 local function setup()
  return create(function(p)pet(p,'dog',{eggValueMult=.5});p.effects.boosts={{id='jimbos_blue_v2',remainingSeconds='10'}}end)
 end
 local whole=setup();local expected=step(whole,1)
 local b=setup();b.clock.advance(1);local c=b:getCoordinator('1')
 eq(c.tick({kind='TimeAdvance',targetMs=b.clock.utcNowMs(),budget=1}).status,'PENDING');c.drain()
 eq(state(b).working.timeline.integrationCheckpoint~=nil,true)
 eq(b:checkpointPlayer('1'),true);eq(b:playerLeaving('1'),true);eq(b:playerJoined('1').status,'JOINED')
 local p=step(b,0);eq(p.farm.cash,expected.farm.cash);eq(p.effects.boosts[1].remainingSeconds,expected.effects.boosts[1].remainingSeconds)
 eq(p.timeline.settledWallThrough,expected.timeline.settledWallThrough)
end
do
 local b=create(function(p)p.farm.siloOwned=0;p.timeline.settledWallThrough=10000000-61000;p.effects.boosts={{id='jimbos_blue_v2',remainingSeconds='10'}}end)
 local p=step(b,0);eq(cash(p),0);eq(p.effects.boosts[1].remainingSeconds,'10');eq(p.timeline.settledWallThrough,10000000)
end
for _,pro in {false,true} do
 local b=create(function(p)
  p.timeline.settledWallThrough=10000000-61000;p.entitlements.pro_permit=pro
  pet(p,'dog',{eggValueMult=.5});p.effects.boosts={{id='jimbos_blue_v2',remainingSeconds='100'}}
 end)
 local p=step(b,0);near(cash(p),(100*(1/30))*1.0*61*1.5*3*(if pro then 1 else .5))
 local remaining,timer=61,100
 while remaining>0 do local dt=math.min(remaining,.3);timer-=dt;remaining-=dt end
 eq(p.effects.boosts[1].remainingSeconds,C.Real64.encode(timer));eq(p.timeline.settledWallThrough,10000000)
end
do
 local b=create(function(p)
  p.timeline.settledWallThrough=10000000-61000;p.farm.habitats[1].population='0'
  p.farm.common.internal_hatchery1=1;p.permanent.epic.int_hatch_calm=20
 end)
 local p=step(b,0);eq(p.farm.habitats[1].population,'6');near(C.Real64.decode(p.farm.habitats[1].fractionalIHR),.1)
end
do
 local b=create(function(p)p.effects.boosts={{id='jimbos_blue_v2',remainingSeconds='10'}}end,{liveEvents={{id='full',type='earnings',multiplier=3,startTimeMs=10000000,deadlineMs=10010000}}})
 near(cash(step(b,.3)),1.0*3*3) -- whole-step event context; partial-step weighting remains issue #61
end
-- Farm Value continues using research-only inputs, not pet/boost production stats.
do
 local b=create();local p=state(b).durable;local before=Progress.calculateProfileFarmValue(p,b.catalog,b.productionMath)
 local changed=D.copy(p);pet(changed,'dog',{eggValueMult=100,habCapacityMult=100});changed.effects.boosts={{id='jimbos_orange',remainingSeconds=10}}
 eq(Progress.calculateProfileFarmValue(changed,b.catalog,b.productionMath),before)
end
fs.writeFile('build/production_context-results.json',serde.encode('json',{status='PASS',assertions=assertions,level='L',studioTested=false,dataStoreTested=false},true))
print('Production context #54-55: '..assertions..' assertions PASS')
