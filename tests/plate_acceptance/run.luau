-- Independent integration acceptance: entry windows and authoritative conservation.
local B=require('../../src/server/Bootstrap')
local C=require('../../src/shared/NumericCodec')
local S=require('../../src/server/ProfileSchema').new(C)
local checks=0
local function ok(v,label) checks+=1;assert(v,label) end
local function eq(a,b,label)ok(a==b,label..': '..tostring(a)..' ~= '..tostring(b))end
local function harness(mutate)
 local h={now=1000000,elapsed=0}
 h.b=B.new({clock={utcNowMs=function()return h.now end,elapsedNowSeconds=function()return h.elapsed end}})
 local fixture=S.createReference('1',h.now)
 if mutate then mutate(fixture) end
 eq(h.b:playerJoined('1',fixture).status,'JOINED','join')
 h.b:dispatch('1',{protocolVersion=1,kind='Bootstrap',requestId='boot'})
 function h.state()return h.b:getCoordinator('1').snapshots().working end
 function h.step(ms,present)
  h.now+=ms;h.elapsed+=ms/1000
  if present~=nil then h.b:setPlatePresence('1',present) end
  h.b:tick(ms/1000)
  for _=1,1000 do if h.b:getCoordinator('1').snapshots().ready then break end;h.b:tick(0) end
 end
 function h.total()
  local f=h.state().farm;local n=0
  for _,hab in f.habitats do n+=tonumber(hab.population)+tonumber(hab.assignedInTransit) end
  return n
 end
 return h
end
local h=harness()
h.step(5000,false);eq(h.total(),0,'no plate grants outside observed presence')
h.b:setPlatePresence('1',true)
for _=1,8 do h.step(250,true) end
local n=h.total();ok(n>=58 and n<=60,'two seconds at approved rate, without prior five-second backfill')
local stock=C.BigAmount.decode(h.state().farm.hatcheryStock)
ok(stock>=0 and stock<=250,'stock bounds')
ok(math.abs(stock+n-256)<0.01,'stock consumed once with unchanged three-per-second refill')
h.b:setPlatePresence('1',false)
for _=1,24 do h.step(250,false) end
eq(h.total(),n,'exit stops releases; arrivals conserve count')
eq(h.state().farm.runningCount,'0','all released groups settle after route duration')
local groups=0 for _ in h.state().farm.groups do groups+=1 end
eq(groups,0,'settled groups removed')
h.b:setPlatePresence('1',true)
h.step(10000,nil)
ok(h.total()-n<=30,'expired observation cannot hatch throughout a ten-second pause')
h.b:setPlatePresence('1',false)
local old=h.total()
h.b:setPlatePresence('1',true)
h.step(250,true)
ok(h.total()-old<=8,'fresh entry does not replay expired debt')
h.b:close()
local reconnect=harness()
reconnect.b:setPlatePresence('1',true)
reconnect.step(500,true)
local beforeReconnect=reconnect.total()
reconnect.b:dispatch('1',{protocolVersion=1,kind='Bootstrap',requestId='new-stream'})
reconnect.step(250,nil)
eq(reconnect.total(),beforeReconnect,'new view stream discards old presence until fresh server observation')
reconnect.b:close()
local missingGateway=harness()
missingGateway.b:setPlatePresence('1',true)
missingGateway.step(500,true)
local beforeMissing=missingGateway.total()
missingGateway.b.gateway:unregisterPlayer('1')
missingGateway.step(250,nil)
eq(missingGateway.total(),beforeMissing,'missing gateway invalidates presence before simulation')
missingGateway.b:close()
local midStep=harness()
midStep.step(1,false)
midStep.now+=500;midStep.elapsed+=0.5
local observedEntry=midStep.now
midStep.b:setPlatePresence('1',true)
midStep.step(100,true)
ok(midStep.total()>0,'partial simulation step hatches after observed entry')
for _,group in midStep.state().farm.groups do
 ok(group.startInstantMs>=observedEntry,'plate route never starts before observed entry')
end
midStep.b:close()
local function rcbFixture(p)
 p.farm.habitats[1].population='100'
 p.farm.common.flock_motivation=10
end
local delayed,split=harness(rcbFixture),harness(rcbFixture)
delayed.now+=500;delayed.elapsed+=0.5
split.step(500,false)
delayed.b:setPlatePresence('1',true);split.b:setPlatePresence('1',true)
delayed.step(100,true);split.step(100,true)
ok(math.abs(C.BigAmount.decode(delayed.state().farm.cash)-C.BigAmount.decode(split.state().farm.cash))<1e-10,
 'plate entry mid-step cannot apply RCB to time before entry')
delayed.b:close();split.b:close()
local Client=require('../../src/client/Bootstrap')
local Route=require('../../src/client/RoutePresentation')
local visualHarness=harness()
local presentation=Route.new({maxActiveVisuals=1,modelFactory=function()return {}end})
local packets=0
local client
client=Client.new({playerId='1',routePresentation=presentation,wire=function(m)
 packets+=1;local r=visualHarness.b:dispatch('1',m);if r then client:receive(r) end
end})
client:connect('visual-independent')
for _=1,20 do client:hatchPress() end
client:receive(visualHarness.b:createPlayerDelta('1'))
local packetsBefore=packets
local spawned=0;presentation:on('groupSpawned',function()spawned+=1 end)
for i=0,60 do
 client:update(visualHarness.now+i*1000)
 ok(presentation:getActiveVisualCount()<=1,'configured global visual cap')
end
ok(spawned>8,'constant authoritative count keeps cosmetic stream alive')
eq(packets,packetsBefore,'visual stream sends no hatch or arrival packets')
eq(visualHarness.total(),20,'cosmetic frames never grant population')
ok(client._transitSpawnAccumulator<=4,'capped presentation drops spawn debt under slow frames')
client:destroy();eq(presentation:getActiveVisualCount(),0,'destroy clears visual models')
visualHarness.b:close()
print('Independent plate acceptance PASS: '..checks..' assertions')
