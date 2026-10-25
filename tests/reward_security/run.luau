-- Regression through the exact ingress called by Main.server, not only leaf modules.
local B=require('../../src/server/Bootstrap')
local C=require('../../src/shared/NumericCodec')
local D=require('../../src/server/PersistenceData')
local Schema=require('../../src/server/ProfileSchema').new(C)
local serde=require('@lune/serde')
local fs=require('@lune/fs')
local count=0
local function eq(a,b,label) count+=1;assert(a==b,(label or '')..' expected '..tostring(b)..' got '..tostring(a)) end
local function harness(policy)
 local h={records={},now=1000000,elapsed=0,updates=0}
 h.clock={utcNowMs=function()return h.now end,elapsedNowSeconds=function()return h.elapsed end}
 function h.advance(ms)h.now+=ms;h.elapsed+=ms/1000 end
 h.store={read=function(key)return true,h.records[key] and D.copy(h.records[key])end,
  update=function(key,cb)
   h.updates+=1
   if h.beforeCallback then local hook=h.beforeCallback;h.beforeCallback=nil;hook() end
   local p=h.records[key] and D.copy(h.records[key])
   if h.retry then h.retry=false;cb(p and D.copy(p)) end
   local next=cb(p)
   if h.before then h.before=false;return false,'timeout before storage' end
   if next then h.records[key]=D.copy(next) end
   if h.after then h.after=false;return false,'saved, response lost' end
   return true,next and D.copy(next)
  end}
 h.b=B.new({clock=h.clock,store=h.store,petHatchTestPolicy=policy})
 function h.join(id)eq(h.b:playerJoined(id).status,'JOINED')end
 function h.profile(id)return h.b:getCoordinator(id or '1').snapshots().durable end
 h.join('1');return h
end
local function request(kind,id,op)
 local m={kind=kind,protocolVersion=1,requestId='r',operationId=op}
 if kind=='HitDrone' then m.droneId=id elseif kind=='ClaimOffer' then m.offerId=id else m.eggType='standard_egg' end
 return m
end
local terms={farmValue=10000,curve0FarmValue=2000,config={droneGoldGuaranteed=true},rollElite=0.99,rolls={u2=0.8}}
local reward={rewardType='GE',amount='3',amountNumber=3}
local function protected(p)return D.fingerprint({farm=p.farm,permanent=p.permanent,inventory=p.inventory,rewards=p.rewards})end
do
 local h=harness();local before=protected(h.profile())
 local updates=h.updates
 for _,patch in {{costGE=0},{roll=0},{variantRoll=0},{petUid='chosen'},{petSerial='chosen'}} do
  local m=request('HatchPetEgg');for k,v in patch do m[k]=v end
  local ok,code=h.b:handleRewardRequest('1',m);eq(ok,false);eq(code,'INVALID_REQUEST');eq(protected(h.profile()),before)
 end
 for _,kind in {'HatchPetEgg','HatchPet'} do
  local ok,code=h.b:handleRewardRequest('1',request(kind));eq(ok,false);eq(code,'FEATURE_UNAVAILABLE')
 end
 eq(protected(h.profile()),before);eq(h.b:getCoordinator('1').snapshots().ready,true)
 eq(h.updates,updates)
end
do
 local draws=0
 local h=harness({mode='INTERNAL_TEST_ONLY',costGE=7,draw=function()draws+=1;return 0.9 end})
 h.retry=true
 local ok,r=h.b:handleRewardRequest('1',request('HatchPetEgg',nil,'hatch-1'))
 eq(ok,true);eq(r.costGE,7);eq(r.pet.speciesId,'farmer_dog');eq(r.pet.variant,'normal');eq(r.pet.uid,'pet-1')
 eq(h.profile().permanent.GE,'3');eq(h.profile().permanent.totalGESpent,'7');eq(draws,2)
 local a,r2=h.b:handleRewardRequest('1',request('HatchPetEgg',nil,'hatch-1'));eq(a,true);eq(r2.pet.uid,r.pet.uid);eq(draws,2);eq(h.profile().permanent.GE,'3')
 local a2,e2=h.b:handleRewardRequest('1',request('HatchPetEgg',nil,'hatch-2'));eq(a2,false);eq(e2,'INSUFFICIENT_GE');eq(draws,2);eq(h.b:getCoordinator('1').snapshots().ready,true)
 h.b.petHatchTestPolicy=nil
 eq(h.b:handleRewardRequest('1',request('HatchPetEgg',nil,'hatch-1')),true);eq(h.profile().permanent.GE,'3');eq(draws,2)
end
do
 local h=harness();local before=D.fingerprint(h.profile());local writes=h.updates
 for _,kind in {'HitDrone','ClaimOffer'} do
  for _,id in {'unknown-1','unknown-2'} do
   local ok,code=h.b:handleRewardRequest('1',request(kind,id));eq(ok,false);eq(code,if kind=='HitDrone' then 'UNKNOWN_SPAWN' else 'OFFER_NOT_FOUND')
  end
 end
 eq(D.fingerprint(h.profile()),before);eq(h.updates,writes)
 for _,bad in {false,42,'id',{},setmetatable({kind='HitDrone'},{}),{kind='HitDrone',protocolVersion=1,droneId=string.rep('x',65)}} do
  local ok,code=h.b:handleRewardRequest('1',bad);eq(ok,false);eq(code,'INVALID_REQUEST')
 end
 for _,kind in {'HitDrone','ClaimOffer'} do
  local m=request(kind,'unknown');m.reward={rewardType='GE',amount='999'}
  local ok,code=h.b:handleRewardRequest('1',m);eq(ok,false);eq(code,'INVALID_REQUEST')
 end
 eq(h.b:getCoordinator('1').snapshots().ready,true)
end
do
 local h=harness({mode='INTERNAL_TEST_ONLY',costGE=7,draw=function()return 0.9 end})
 local packet=request('HatchPetEgg');packet.requestId='retry-same-packet'
 local a,r=h.b:handleRewardRequest('1',packet);eq(a,true)
 local b,again=h.b:handleRewardRequest('1',packet);eq(b,true);eq(again.pet.uid,r.pet.uid);eq(h.profile().permanent.GE,'3')
end
do
 local h=harness();h.join('2')
 eq(h.b:issueDrone('1','d',terms),true)
 local ok,code=h.b:handleRewardRequest('2',request('HitDrone','d'));eq(ok,false);eq(code,'UNKNOWN_SPAWN');eq(h.profile('2').permanent.GE,'10')
 local tampered=request('HitDrone','d');tampered.config={droneGoldGuaranteed=true}
 eq(h.b:handleRewardRequest('1',tampered),false)
 h.retry=true;eq(h.b:handleRewardRequest('1',request('HitDrone','d','claim-d')),true)
 eq(h.profile().permanent.GE,'13');eq(h.profile().rewards.droneSpawns.d.claimed,true)
 eq(h.b:handleRewardRequest('1',request('HitDrone','d','claim-d')),true);eq(h.profile().permanent.GE,'13')
 local a,e=h.b:handleRewardRequest('1',request('HitDrone','d','another'));eq(a,false);eq(e,'ALREADY_CLAIMED');eq(h.profile().permanent.GE,'13')
 eq(h.b:issueDrone('1','expired',terms),true);h.advance(15001)
 local x,y=h.b:handleRewardRequest('1',request('HitDrone','expired'));eq(x,false);eq(y,'SPAWN_EXPIRED');eq(h.profile().permanent.GE,'13')
 eq(h.profile().rewards.droneSpawns.expired.claimed,false)
end
do
 local h=harness();h.join('2');eq(h.b:issueOffer('1','o','ordinary',reward),true)
 local x,y=h.b:handleRewardRequest('2',request('ClaimOffer','o'));eq(x,false);eq(y,'OFFER_NOT_FOUND')
 local before=D.fingerprint(h.profile());local copy=h.b:getOffersState('1');copy.ordinary.o.reward.amount='99999';eq(D.fingerprint(h.profile()),before)
 h.retry=true;eq(h.b:handleRewardRequest('1',request('ClaimOffer','o','claim-o')),true);eq(h.profile().permanent.GE,'13');eq(h.profile().rewards.offers.ordinary.o.status,'CLAIMED')
 eq(h.b:handleRewardRequest('1',request('ClaimOffer','o','claim-o')),true);eq(h.profile().permanent.GE,'13')
 local a,e=h.b:handleRewardRequest('1',request('ClaimOffer','o','again'));eq(a,false);eq(e,'ALREADY_CLAIMED')
 eq(h.b:playerLeaving('1'),true);h.join('1');eq(h.profile().rewards.offers.ordinary.o.status,'CLAIMED')
 eq(h.b:handleRewardRequest('1',request('ClaimOffer','o','claim-o')),true);eq(h.profile().permanent.GE,'13')
end
-- Failed writes never consume a runtime-only offer; saved-but-unacknowledged
-- writes retain both the claim and reward and resolve by fencing, without reroll.
for _,saved in {false,true} do
 local h=harness();eq(h.b:issueOffer('1','fault','ordinary',reward),true)
 if saved then h.after=true else h.before=true end
 local a=h.b:handleRewardRequest('1',request('ClaimOffer','fault','fault-op'));eq(a,false)
 local record=h.records['player:1'];eq(record.permanent.GE,if saved then '13' else '10');eq(record.rewards.offers.ordinary.fault.status,if saved then 'CLAIMED' else 'PENDING')
 eq(h.b:getCoordinator('1').snapshots().working,nil)
 h.advance(120001);local c=h.b:getCoordinator('1');eq(c.recover('fault-op').status,'ACQUIRED');eq(c.setReady(true).status,'READY_SET')
 eq(h.b:handleRewardRequest('1',request('ClaimOffer','fault','fault-op')),true);eq(h.profile().permanent.GE,'13');eq(h.profile().rewards.offers.ordinary.fault.status,'CLAIMED')
end
do
 local h=harness();eq(h.b:issueOffer('1','free','bonus',reward),true);eq(h.b:claimOffer('1','free'),true)
 eq(h.b:issueOffer('1','paid','bonus',reward),true)
 local before=protected(h.profile());local ok,code=h.b:claimOffer('1','paid');eq(ok,false);eq(code,'FEATURE_UNAVAILABLE');eq(protected(h.profile()),before)
 eq(h.b:issueOffer('1','priced','bonus',reward,2),false) -- pending bonus slot remains occupied
end
do
 local h=harness();eq(h.b:issueOffer('1','first','bonus',reward),true);eq(h.b:claimOffer('1','first'),true)
 eq(h.b:issueOffer('1','second','bonus',reward,2),true)
 local tampered=request('ClaimOffer','second');tampered.paidGE=0
 eq(h.b:handleRewardRequest('1',tampered),false);eq(h.profile().permanent.GE,'13')
 eq(h.b:claimOffer('1','second'),true);eq(h.profile().permanent.GE,'14')
 eq(h.b:issueOffer('1','third','bonus',reward,20),true)
 local before=protected(h.profile());local a,e=h.b:claimOffer('1','third');eq(a,false);eq(e,'INSUFFICIENT_GE');eq(protected(h.profile()),before)
 eq(h.b:getCoordinator('1').snapshots().ready,true)
end
do
 local h=harness();eq(h.b:issueDrone('1','late',terms),true)
 h.beforeCallback=function()h.advance(15001)end
 local a,e=h.b:hitDrone('1','late');eq(a,false);eq(e,'SPAWN_NOT_ACTIVE');eq(h.profile().permanent.GE,'10');eq(h.profile().rewards.droneSpawns.late.claimed,false)
 local packet=request('IssueDrone','injected');packet.terms=terms
 eq(h.b:handleRewardRequest('1',packet),false)
 eq(h.b:dispatch('1',{protocolVersion=1,kind='IssueDrone',requestId='x',args={}}).admission,'NOT_ACCEPTED')
end
do
 local h=harness();eq(h.b:issueDrone('1','schema-d',terms),true);eq(h.b:issueOffer('1','schema-o','ordinary',reward),true)
 local p=h.profile();eq(Schema.validate(p,'1'),true)
 for _,bad in {'01','-1','18446744073709551616'} do
  local corrupt=D.copy(p);corrupt.inventory.petSequence=bad
  eq(pcall(function()Schema.validate(corrupt,'1')end),false)
 end
 local corrupt=D.copy(p);corrupt.rewards.droneSpawns['schema-d'].ownerId='2';eq(pcall(function()Schema.validate(corrupt,'1')end),false)
 corrupt=D.copy(p);corrupt.rewards.offers.ordinary['schema-o'].status='UNKNOWN';eq(pcall(function()Schema.validate(corrupt,'1')end),false)
end
fs.writeFile('build/reward_security-results.json',serde.encode('json',{status='PASS',assertions=count,level='L',studioTested=false,dataStoreTested=false},true))
print('Reward security #51-53: '..count..' assertions PASS')
