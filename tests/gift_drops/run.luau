--!nocheck
-- User R 2026-10-28: owner proximity AFTER landing, ground lifetime15s, no click.
-- Independent times/positions/wallets. No formula under test produces its oracle.
local B=require('../../src/server/Bootstrap');local C=require('../../src/shared/NumericCodec');local D=require('../../src/server/PersistenceData')
local S=require('../../src/server/ProfileSchema').new(C);local G=require('../../src/server/GiftDrops');local Client=require('../../src/client/Bootstrap')
local Protocol=require('../../src/shared/ProtocolSchemas').new(C)
local count=0
local function eq(a,b,label)count+=1;assert(a==b,(label or '')..' expected '..tostring(b)..' got '..tostring(a))end
local function h(generate,mutate)
 local t={now=1000000,pos={x=100,y=3,z=100},records={}}
 t.clock={utcNowMs=function()return t.now end,elapsedNowSeconds=function()return (t.now-1000000)/1000 end}
 t.store={read=function(k)return true,t.records[k] and D.copy(t.records[k])end,update=function(k,fn)
  if t.before then local f=t.before;t.before=nil;f()end
  local p=fn(t.records[k] and D.copy(t.records[k]));if p then t.records[k]=D.copy(p) end
  if t.loseAck then t.loseAck=false;return false,'lost acknowledgement' end
  return true,p and D.copy(p)
 end}
 function t.start()
  t.b=B.new({clock=t.clock,store=t.store,giftDrops={observe=function(id)return if id=='1' then t.pos else nil end,generate=generate==true,draw=function()return .1 end}})
  local seed;if not t.records['player:1'] then seed=S.createReference('1',t.now);if mutate then mutate(seed) end end
  eq(t.b:playerJoined('1',seed).status,'JOINED','fixture joined')
 end
 t.start()
 function t.profile()return t.b:getCoordinator('1').snapshots().durable end
 function t.issue(id)
  eq(t.b:issueDrone('1',id,{groundGift=true,position={x=0,y=1.15,z=18},farmValue=1000,curve0FarmValue=1000,config={droneGoldGuaranteed=true},rollElite=.9,rolls={u2=.1}}),true,'managed gift issued')
 end
 return t
end
-- Pure geometry: living position comes only from host, never from a remote payload.
eq(G.inRange(nil,{x=0,y=0,z=0}),false,'SPEC/missing character cannot collect')
eq(G.inRange({x=0/0,y=0,z=0},{x=0,y=0,z=0}),false,'SPEC/nonfinite character cannot collect')
eq(G.inRange({x=6,y=0,z=0},{x=0,y=0,z=0}),true,'SPEC/pickup boundary inclusive')
eq(G.inRange({x=6.001,y=0,z=0},{x=0,y=0,z=0}),false,'SPEC/outside pickup radius')
eq(G.intervalMs(.1,.5),5000,'SPEC/short spawn distribution');eq(G.intervalMs(.5,.5),29500,'SPEC/long spawn distribution')
-- Timeline and atomic single grant: rejected early/far requests do not poison later proximity.
do
 local t=h();t.issue('window');local gift=t.profile().rewards.droneSpawns.window
 eq(gift.fixedReward.amount,'6','SPEC/outcome frozen at issue');
 local broken=D.copy(t.profile());broken.rewards.droneSpawns.window.expiresAtMs+=1
 eq(pcall(S.validate,broken,'1'),false,'SPEC/schema rejects wrong ground lifetime')
 eq(gift.landedAtMs,1002500,'SPEC/server landing2.5s');eq(gift.expiresAtMs,1017500,'SPEC/server15s after landing')
 t.pos={x=0,y=3,z=18};eq(t.b:collectGift('1','window'),false,'SPEC/no airborne collection')
 t.now=1002500;t.pos={x=100,y=3,z=100}
 eq(t.b:collectGift('1','window'),false,'SPEC/no distant collection')
 t.pos=nil;eq(t.b:collectGift('1','window'),false,'SPEC/no dead or missing character collection')
 t.pos={x=0,y=3,z=18}
 eq(t.b:hitDrone('1','window'),false,'SPEC/client click API cannot collect managed gift')
 eq(t.b:collectGift('1','window'),true,'SPEC/near owner collects after landing')
 eq(t.profile().permanent.GE,'16','SPEC/six GE credited once')
 t.b:collectGift('1','window');eq(t.profile().permanent.GE,'16','SPEC/duplicate cannot credit twice')
end
for _,time in {1017499,1017500,1017501} do
 local t=h();t.issue('expiry');t.now=time;t.pos={x=0,y=3,z=18}
 eq(t.b:collectGift('1','expiry'),time<1017500,'SPEC/exact expiry boundary '..time)
 eq(t.profile().permanent.GE,if time<1017500 then '16' else '10','SPEC/expiry wallet')
end
-- Amount is frozen at issue, even if spending crosses the reference quality threshold.
do
 local t=h(false,function(p)p.permanent.totalGESpent='152499' end);t.issue('fixed')
 local packet={protocolVersion=1,kind='BuyEpicResearch',requestId='spend',operationId='spend',expectedRevision=t.profile().meta.revision,args={researchId='hold_to_hatch'}}
 eq(t.b:dispatch('1',packet).status,'APPLIED','fixture crosses spending threshold')
 t.now=1002500;t.pos={x=0,y=3,z=18};eq(t.b:collectGift('1','fixed'),true,'fixed gift collected')
 eq(t.profile().permanent.GE,'6','SPEC/issued reward stays fixed after spending change')
end
-- A later spawn deadline cannot stack another live gift.
do
 local t=h(true);t.b:tick(0);t.now=1010000;t.b:tick(0);t.now=1013000;t.b:tick(0)
 eq(type(t.profile().rewards.droneSpawns),'table','SPEC/generator issues from tick')
 local n=0;for _,v in t.profile().rewards.droneSpawns do if not v.claimed and v.expiresAtMs>t.now then n+=1 end end
 eq(n,1,'SPEC/no stacked live gifts')
end
-- Recheck position and time in UpdateAsync-style validation, not just before submit.
for _,fault in {'move','expire'} do
 local t=h();t.issue('validate');t.now=1002500;t.pos={x=0,y=3,z=18}
 t.before=function()if fault=='move' then t.pos={x=100,y=3,z=100} else t.now=1017500 end end
 eq(t.b:collectGift('1','validate'),false,'SPEC/fresh validation '..fault)
 eq(t.profile().permanent.GE,'10','SPEC/fresh validation grants nothing')
 if fault=='move' then t.pos={x=0,y=3,z=18};eq(t.b:collectGift('1','validate'),true,'SPEC/retry after rejected validation') end
end
-- A grant whose acknowledgement was lost remains durable through fencing/rejoin.
do
 local t=h();t.issue('ack');t.now=1002500;t.pos={x=0,y=3,z=18};t.loseAck=true
 eq(t.b:collectGift('1','ack'),false,'SPEC/unknown is not a confirmed pickup')
 eq(t.records['player:1'].permanent.GE,'16','SPEC/unknown grant stored once')
 t.now+=120000;t.start();t.b:collectGift('1','ack');eq(t.profile().permanent.GE,'16','SPEC/rejoin does not replay credit')
end
-- docs/27: saved monetary values use canonical tokens, including frozen gift cash.
-- Independent quarter-dollar fixture:2+1.25=3.25; earned4+1.25=5.25.
do
 local t=h();t.issue('cash');local p=D.copy(t.profile())
 local gift=p.rewards.droneSpawns.cash;gift.fixedReward={type='Cash',amount='1.25',formattedAmount='1.25'}
 p.farm.cash='2';p.accounting.lastCashEarned='4'
 local serde=require('@lune/serde');p=serde.decode('json',serde.encode('json',p))
 eq(S.validate(p,'1'),true,'SPEC/canonical frozen cash survives JSON')
 eq(require('../../src/server/rewards/drones').claimDrone(p.rewards.droneSpawns.cash,1002500,p,{},{}),true,'SPEC/frozen cash delivered')
 eq(p.farm.cash,'3.25','SPEC/frozen cash wallet exact')
 eq(p.accounting.lastCashEarned,'5.25','SPEC/frozen cash ledger exact')
end
-- Generator executes from actual Bootstrap.tick, no missed-interval burst/offline backlog.
do
 local t=h(true);t.b:tick(0);t.now=1009999;t.b:tick(0)
 eq(next(t.profile().rewards.droneSpawns or {}),nil,'SPEC/no early generation')
 t.now=1010000;t.b:tick(0);eq(type(t.profile().rewards.droneSpawns),'table','SPEC/generator issues from tick');local id,gift=next(t.profile().rewards.droneSpawns)
 eq(id~=nil,true,'SPEC/generator issues from tick');eq(gift.landedAtMs,1012500,'SPEC/generated landing clock')
 t.now=1012500;t.pos={x=-12,y=3,z=18};t.b:tick(0)
 eq(t.profile().permanent.GE,'16','SPEC/server proximity automatically awards gift')
 eq(#t.b:takeGiftNotifications(),1,'SPEC/one confirmed notification');t.b:tick(0)
 eq(#t.b:takeGiftNotifications(),0,'SPEC/no duplicate pickup notification')
 t.pos={x=100,y=3,z=100};t.now=1070000
 for _=1,1000 do t.b:tick(0);if t.b:getCoordinator('1').snapshots().ready then break end end
 eq(type(t.profile().rewards.droneSpawns),'table','SPEC/generator issues from tick')
 local n=0;for _,v in t.profile().rewards.droneSpawns do if not v.claimed and v.expiresAtMs>t.now then n+=1 end end
 eq(n,1,'SPEC/late tick issues at most one gift')
 local client
 client=Client.new({playerId='1',wire=function(m)local r=t.b:dispatch('1',m);if r then eq(client:receive(r),true,'valid wire projection')end end})
 client:connect('gift-wire');local view=client:getFarm();eq(Protocol.validateServer(t.b:dispatch('1',{protocolVersion=1,kind='Bootstrap',requestId='wire-check'})),true,'SPEC/gift wire schema')
 local badPacket=t.b:dispatch('1',{protocolVersion=1,kind='Bootstrap',requestId='bad-wire'})
 badPacket.view.farm.progress.issuedDrones[1].expiresAtMs+=1
 eq(Protocol.validateServer(badPacket),false,'SPEC/wire rejects wrong ground lifetime')
 local projected=view.progress.issuedDrones[1];eq(projected.position.x,-12,'SPEC/authoritative landing position projected')
 local visual=client:getPresentation():getDrone(projected.id);eq(visual.p3.x,-12,'SPEC/client uses server landing position')
 client:update(projected.expiresAtMs-1);eq(client:getPresentation():getDrone(projected.id)~=nil,true,'SPEC/projected gift lives to server deadline')
 client:update(projected.expiresAtMs);eq(client:getPresentation():getDrone(projected.id),nil,'SPEC/projected gift disappears at deadline')
 client:destroy()
end
-- The same landing/expiry branch is exercised with Instance ports, not an alternate Lune lifetime.
for _,R in {require('../../src/client/RoutePresentation'),require('../support/GiftVisualHarness')} do
 local p=R.new();local e=p:spawnDrone('visual',false,1000000)
 p:updateDrones(1002500);eq(e.landed,true,'SPEC/visual has landed')
 eq(p:shootDrone('visual',true),false,'SPEC/visual click cannot collect')
 p:updateDrones(1017499);eq(p:getDrone('visual')~=nil,true,'SPEC/visual lives full ground15s')
 p:updateDrones(1017500);eq(p:getDrone('visual'),nil,'SPEC/visual disappears at deadline')
 if e.model.FindFirstChild then local box=e.model:FindFirstChild('GiftBoxPart');eq(box:FindFirstChildWhichIsA('ClickDetector',true),nil,'SPEC/no native click detector');eq(box:FindFirstChildWhichIsA('ProximityPrompt',true),nil,'SPEC/no native pickup prompt') end
end
-- Production entrypoint enables the generator and blocks forged remote claims.
do
 local Main=require('../support/MainHarness');local options={assertEqual=eq,loopSeconds=12};local t=Main.new(options);t.join()
 eq(t.server.giftDrops~=nil,true,'SPEC/production entrypoint enables gifts')
 local human={Health=0};local root={Position={X=0,Y=3,Z=18}}
 t.player.Character={FindFirstChildOfClass=function()return human end,FindFirstChild=function()return root end}
 eq(t.server.giftDrops.observe('1'),nil,'SPEC/production dead character has no pickup position')
 human.Health=100;eq(t.server.giftDrops.observe('1').z,18,'SPEC/production observes actual character')
 local old=t.profile().permanent.GE
 t.remote({protocolVersion=1,kind='HitDrone',requestId='forged',droneId='any'})
 eq(t.profile().permanent.GE,old,'SPEC/production remote cannot grant gifts')
 root.Position={X=100,Y=3,Z=100}
 local loopJob
 for i,job in t.jobs do
  if job.args.n==0 then
   -- Only bounded time in fake task.wait is allowed; all native loops stop safely.
   -- Constructor/registration alone cannot prove the production tick calls the generator.
   local elapsed=t.elapsed;local waits=t.waitCalls or 0;local ok,err=pcall(t.runJob,i)
   if t.elapsed>elapsed then loopJob=i end
   if (t.waitCalls or 0)>waits then
   eq(ok,false,'SPEC/production loop bounded')
   eq(tostring(err):find('TEST_LOOP_STOP',1,true)~=nil,true,'SPEC/production loop executes safely')
   else eq(ok,true,'SPEC/production startup job succeeds') end
  end
 end
 local found=false;local selected
 for _,gift in t.profile().rewards.droneSpawns or {} do if gift.kind=='GROUND_GIFT' then found=true;selected=gift end end
 eq(found,true,'SPEC/production loop generates gifts')
 root.Position={X=selected.position.x,Y=3,Z=selected.position.z};options.loopSeconds=3
 local ok,err=pcall(t.runJob,loopJob)
 eq(ok,false,'SPEC/pickup loop bounded');eq(tostring(err):find('TEST_LOOP_STOP',1,true)~=nil,true,'SPEC/pickup loop safely stops')
 eq(t.profile().rewards.droneSpawns[selected.spawnId].claimed,true,'SPEC/production loop collects near landed gift')
 local popups=0;for _,m in t.messages do if m.message.kind=='DroneRewardPopup' and m.message.droneId==selected.spawnId then popups+=1 end end
 eq(popups,1,'SPEC/production sends one confirmed pickup popup')
end
local fs,serde=require('@lune/fs'),require('@lune/serde')
fs.writeFile('build/gift_drops-results.json',serde.encode('json',{status='PASS_L',assertions=count,studioTested=false,realDataStoreTested=false}))
print('Ground gifts PASS: '..count..' assertions')
