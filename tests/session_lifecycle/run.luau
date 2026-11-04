--!strict
-- QA-DATA-01/02: actual Main + Bootstrap; controlled storage yields and scheduler.
local H=require('../support/MainHarness')
local C=require('../../src/shared/NumericCodec')
local S=require('../../src/server/ProfileSchema').new(C)
local D=require('../../src/server/PersistenceData')
local n=0
local failures={}
local function check(ok:any,label:string)n+=1;assert(ok,label)end
local function eq(a:any,b:any,label:string)check(a==b,label..': '..tostring(a)..' ~= '..tostring(b))end
local function scenario(name:string,fn:()->())
 local ok,err=pcall(fn);if not ok then table.insert(failures,name..': '..tostring(err))end
end
local function resume(thread:thread):any
 local ok,result=coroutine.resume(thread);assert(ok,result);return result
end
scenario('shutdown waits for writer and concurrent PlayerRemoving',function()
 local initial=S.createReference('1',1000000)
 initial.farm.habitats[1].population='250'
 local h=H.new({records={['player:1']=initial},onWait=function(state,seconds)
  if seconds==.05 then state.elapsed+=seconds;coroutine.yield('LIFECYCLE_WAIT');return true end
  return false
 end})
 h.join();h.elapsed=2;h.server:tick()
 local p=h.server:getCoordinator('1').snapshots().working
 check(tonumber(p.farm.cash)>0,'fixture has earned uncheckpointed cash to preserve')
 h.onWrite=function()coroutine.yield('WRITE_PAUSED')end
 local writer=coroutine.create(function()return h.server:checkpointPlayer('1')end)
 eq(resume(writer),'WRITE_PAUSED','storage actually yields')
 local leaving=coroutine.create(function()h.services.Players.PlayerRemoving:Fire(h.player)end)
 eq(resume(leaving),'LIFECYCLE_WAIT','leave must await in-flight durable write')
 local closing=coroutine.create(h.close)
 eq(resume(closing),'LIFECYCLE_WAIT','BindToClose must join existing leave')
 check(h.server:getPlayer('1')~=nil,'keep session until durability confirmed')
 check(h.records['player:1'].ownership.ownerToken~='','do not pretend released while write paused')
 local cash=h.server:getCoordinator('1').snapshots().working.farm.cash
 h.server:tick(0.5)
 eq(h.server:getCoordinator('1').snapshots().working.farm.cash,cash,'no simulation during close')
 eq(h.server:dispatch('1',{protocolVersion=1,kind='Bootstrap',requestId='closing'}).errorCode,'SESSION_CLOSING','no fresh command admission during close')
 resume(writer);resume(leaving);resume(closing)
 eq(coroutine.status(leaving),'dead','leave completes')
 eq(coroutine.status(closing),'dead','shutdown completes')
 eq(h.server:getPlayer('1'),nil,'remove after confirmed release')
 eq(h.records['player:1'].ownership.ownerToken,'','cloud owner released')
 eq(h.records['player:1'].ownership.endsAtMs,0,'cloud lease cleared')
 eq(h.records['player:1'].farm.cash,p.farm.cash,'final working cash survives shutdown')
end)
scenario('release outage retains unresolved actor after successful checkpoint',function()
 local h=H.new();h.join()
 h.onWrite=function()h.onWrite=function()h.writeFailure=true end end
 local ok=h.server:playerLeaving('1')
 eq(ok,false,'release failure is not success')
 check(h.server:getPlayer('1')~=nil,'failed release retains actor')
 check(h.records['player:1'].ownership.ownerToken~='','cloud lock not invented as cleared')
end)
scenario('busy wait is bounded and a completed writer can then be closed',function()
 local h=H.new({onWait=function(state,seconds)
  if seconds==.05 then state.elapsed+=1;return true end
  return false
 end})
 h.join();h.onWrite=function()coroutine.yield('WRITE_PAUSED')end
 local writer=coroutine.create(function()return h.server:checkpointPlayer('1')end)
 eq(resume(writer),'WRITE_PAUSED','pause before durability')
 local ok,reason=h.server:playerLeaving('1')
 eq(ok,false,'timeout is a failure')
 eq(reason,'SESSION_CLOSE_TIMEOUT','bounded lifecycle wait')
 check(h.elapsed<=25,'close cannot busy-loop beyond shutdown budget')
 check(h.server:getPlayer('1')~=nil,'timeout must preserve unresolved actor')
 resume(writer)
 eq(h.server:playerLeaving('1'),true,'retry after writer completion saves and releases')
 eq(h.records['player:1'].ownership.ownerToken,'','retry releases durable lock')
end)
scenario('failed checkpoint never reports saved or releases ownership',function()
 local h=H.new();h.join();h.writeFailure=true
 h.close()
 check(h.server:getPlayer('1')~=nil,'retain unresolved session for recovery')
 check(h.records['player:1'].ownership.ownerToken~='','failed save must not release')
 check(#h.warnings>0,'shutdown failure must be visible')
 for _,message in h.logs do check(not string.find(message,'All player sessions saved',1,true),'no false shutdown success')end
end)
scenario('bootstrap is delivered after offline settlement without client retry',function()
 local profile=S.createReference('1',900000)
 profile.farm.habitats[1].population='250'
 local h=H.new({records={['player:1']=profile},loopSeconds=3})
 h.join();h.server:tick(0.5,1000000)
 eq(h.server:getCoordinator('1').snapshots().ready,false,'offline work really exceeds one budget')
 local boot={protocolVersion=1,kind='Bootstrap',requestId='original-handshake'}
 h.remote(boot)
 local ok,err=pcall(function()h.runJob(2)end)
 check(not ok and string.find(tostring(err),'TEST_LOOP_STOP',1,true)~=nil,'bounded real Main loop executed')
 eq(h.server:getCoordinator('1').snapshots().ready,true,'offline eventually ready')
 local delivered=0
 for _,row in h.messages do
  if row.message.kind=='StateSnapshot' and row.message.requestId==boot.requestId then
   delivered+=1
   eq(row.message.view.farm.habitats[1].population,'250','original farm restored in handshake')
  end
 end
 eq(delivered,1,'one original bootstrap must finish without a second request')
end)
if #failures>0 then for _,failure in failures do print('FAIL '..failure)end;error('Session lifecycle regressions failed: '..#failures)end
print('Session lifecycle regressions PASS: '..n..' assertions')
