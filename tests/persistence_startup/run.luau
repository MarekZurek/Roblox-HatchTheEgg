-- Startup/payment invariants, including execution of the actual Main entrypoint.
-- External Roblox services are controlled; Bootstrap, repository and adapter are real.
local fs,serde,luau=require('@lune/fs'),require('@lune/serde'),require('@lune/luau')
local B=require('../../src/server/Bootstrap')
local Port=require('../../src/server/RobloxDataStorePort')
local Products=require('../../src/server/platform/products')
local C=require('../../src/shared/NumericCodec')
local D=require('../../src/server/PersistenceData')
local Schema=require('../../src/server/ProfileSchema').new(C)
local mainSource=fs.readFile('src/server/Main.server.luau')
local assertions=0
local function eq(a,b,label)assertions+=1;assert(a==b,(label or '')..' expected '..tostring(b)..' got '..tostring(a))end
local function signal()
 local s={callbacks={}}
 function s:Connect(fn)table.insert(self.callbacks,fn);return {Disconnect=function()end}end
 function s:Fire(...)for _,fn in table.clone(self.callbacks)do fn(...)end end
 return s
end
local function runMain(options)
 options=options or {}
 local h={reads=0,writes=0,opens=0,constructs=0,worldBuilds=0,kicks=0,elapsed=0,jobs={},messages={},records=options.records or {},warnings={}}
 local services={};h.services=services
 local function node(class)
  local n={Name=class,ClassName=class,children={}}
  function n:FindFirstChild(name)return self.children[name]end
  if class=='RemoteEvent' then
   n.OnServerEvent=signal()
   function n:FireClient(player,message)table.insert(h.messages,{player=player,message=message})end
  end
  return setmetatable(n,{__newindex=function(t,k,v)rawset(t,k,v);if k=='Parent' and v then v.children[t.Name]=t end end})
 end
 local players={PlayerAdded=signal(),PlayerRemoving=signal(),list={}}
 function players:GetPlayers()return self.list end
 function players:GetPlayerByUserId(id)for _,p in self.list do if p.UserId==id and p.Parent==self then return p end end end
 services.Players=players
 function h.addPlayer(id)
  local p={UserId=id,Parent=players,CharacterAdded=signal(),kickCount=0}
  function p:Kick(message)self.kickCount+=1;h.kicks+=1;self.kickMessage=message end
  table.insert(players.list,p);return p
 end
 h.player=h.addPlayer(1)
 services.ReplicatedStorage=node('ReplicatedStorage')
 services.RunService={IsStudio=function()return options.studio==true end}
 local market={PromptGamePassPurchaseFinished=signal(),ownershipChecks=0}
 function market:UserOwnsGamePassAsync()self.ownershipChecks+=1;return true end
 services.MarketplaceService=market;h.market=market
 local native={}
 function native:GetAsync(key,readOptions)
  h.reads+=1;h.readOptions=readOptions
  if options.probeError or h.reads<=(options.transientReads or 0) then error('simulated read outage')end
  return h.records[key] and D.copy(h.records[key]) -- missing health key is not an outage
 end
 function native:UpdateAsync(key,transform)
  h.writes+=1
  if h.onWrite then local hook=h.onWrite;h.onWrite=nil;hook()end
  if h.writeFailure or options.writeFailure then error('simulated write outage')end
  local old=h.records[key] and D.copy(h.records[key])
  local value=transform(old)
  if value then h.records[key]=D.copy(value)end
  if h.loseWriteAck then
   h.loseWriteAck=false
   if h.disconnectAfterAckLoss then h.writeFailure=true end
   error('write committed, acknowledgement lost')
  end
  return value and D.copy(value)
 end
 services.DataStoreService={GetDataStore=function(_self,name)
  h.opens+=1;eq(name,'HatchTheEgg_PlayerProfile_v1')
  h.receiptBeforeOpen=if market.ProcessReceipt then market.ProcessReceipt({}) else nil
  if options.openError then error('simulated open outage')end
  if options.nilStore then return nil end
  return native
 end}
 services.PolicyService={GetPolicyInfoForPlayerAsync=function()return {ArePaidRandomItemsRestricted=false}end}
 local gameObject={GetService=function(_self,name)assert(services[name],name);return services[name]end,BindToClose=function(_self,fn)h.close=fn end}
 local attrs=options.attributes or {}
 attrs.UseLocalMemoryStore=options.localMemory
 local scriptObject={Parent={Bootstrap='bootstrap',RobloxDataStorePort='port',platform={products='products'},world={FarmPlotBuilder='world'}},GetAttribute=function(_self,name)return attrs[name]end}
 local runtime={
  game=gameObject,script=scriptObject,Enum={ProductPurchaseDecision={NotProcessedYet='NotProcessedYet',PurchaseGranted='PurchaseGranted'}},
  DateTime={now=function()return {UnixTimestampMillis=options.nowMs or 1000000}end},os={clock=function()return h.elapsed end},
  typeof=function(v)return if v==gameObject then 'Instance' else typeof(v)end,
  Instance={new=node},warn=function(message)table.insert(h.warnings,message)end,print=function()end,
  task={spawn=function(fn,...)table.insert(h.jobs,{fn=fn,args=table.pack(...)})end,defer=function(fn,...)table.insert(h.jobs,{fn=fn,args=table.pack(...)})end,wait=function()error('test must not run background loops')end},
  require=function(module)
   if module=='bootstrap' then return {new=function(deps)
    h.constructs+=1;h.constructorMode=deps.storageMode
    h.server=B.new(deps);return h.server
   end}
   elseif module=='port' then return Port
   elseif module=='products' then return Products
   elseif module=='world' then return {SPAWN_LOCATION_POS={x=0,y=0,z=0},new=function()return {build=function()h.worldBuilds+=1 end,updateFromFarmView=function()end}end}
   else error('unexpected module '..tostring(module))end
  end,
 }
 local fn=luau.load(mainSource,{debugName='real-Main.server-storage-test',environment=runtime})
 local ok,err=pcall(fn);eq(ok,true,'entrypoint must handle outage: '..tostring(err))
 function h.runJob(index)
  local job=h.jobs[index];assert(job,'missing queued job');job.fn(table.unpack(job.args,1,job.args.n))
 end
 function h.join()players.PlayerAdded:Fire(h.player)end
 function h.remote(message)
  local root=services.ReplicatedStorage:FindFirstChild('HatchTheEgg')
  local remotes=root and root:FindFirstChild('Remotes')
  local remote=remotes and remotes:FindFirstChild('ClientToServer')
  assert(remote,'remote must exist only after startup admission');remote.OnServerEvent:Fire(h.player,message)
 end
 function h.profile()return h.server:getCoordinator('1').snapshots().durable end
 function h.receipt(id)
  return market.ProcessReceipt({PlayerId=1,ProductId=987654321,PurchaseId=id})
 end
 return h
end

-- No production factory may turn a missing or malformed persistent port into memory.
for _,store in {false,{}, {read=function()end}, {update=function()end}} do
 eq(pcall(B.new,{storageMode='PERSISTENT',store=store}),false)
end
eq(pcall(B.new,{storageMode='PERSISTENT'}),false)
eq(pcall(B.new,{storageMode='STUDIO_MEMORY',isStudio=false}),false)
eq(pcall(B.new,{storageMode='STUDIO_MEMORY',isStudio=true,store={}}),false)

-- Also execute the real runtime branch of Bootstrap; no trusting a forged deps flag.
do
 local fakeScript={Parent={}}
 local env={script=fakeScript,typeof=function(v)return if v==fakeScript then 'Instance' else typeof(v)end,
  game={GetService=function()return {IsStudio=function()return false end}end},
  require=function(path)
   if string.sub(path,1,1)=='@' then return require(path)end
   return require('../../src/server/'..path)
  end}
 local runtimeB=luau.load(fs.readFile('src/server/Bootstrap.luau'),{debugName='runtime-Bootstrap-storage-test',environment=env})()
 eq(pcall(runtimeB.new,{}),false,'runtime default must require storage')
 eq(pcall(runtimeB.new,{storageMode='INTERNAL_TEST_ONLY'}),false,'test memory is not a Roblox runtime mode')
 eq(pcall(runtimeB.new,{storageMode='STUDIO_MEMORY',isStudio=true}),false,'live RunService rejects the forged Studio flag')
end

-- Permanent startup faults: reject existing/future players, no server/world/receipts.
for _,options in {{openError=true},{nilStore=true},{probeError=true},{openError=true,localMemory=true},{probeError=true,studio=true},{probeError=true,studio=true,localMemory='true'}} do
 local h=runMain(options)
 eq(h.constructs,0,'no fallback server');eq(h.worldBuilds,0);eq(h.writes,0)
 eq(h.player.kickCount,1);eq(type(h.player.kickMessage),'string');eq(utf8.len(h.player.kickMessage)~=nil,true)
 eq(h.market.ProcessReceipt({}),'NotProcessedYet','a failed startup still owns a safe receipt callback')
 eq(h.receiptBeforeOpen,'NotProcessedYet','safe handler precedes even the open call')
 eq(h.services.ReplicatedStorage:FindFirstChild('HatchTheEgg'),nil,'no economy remotes in failed startup')
 local later=h.addPlayer(2);h.services.Players.PlayerAdded:Fire(later);eq(later.kickCount,1)
end

-- A transient probe retries instead of creating a new local account.
do
 local profile=Schema.createReference('1',1000000);profile.permanent.GE='321'
 local h=runMain({transientReads=1,records={['player:1']=profile}})
 eq(h.receiptBeforeOpen,'NotProcessedYet');eq(h.reads,2);eq(h.readOptions.UseCache,false)
 eq(h.constructs,1);eq(h.constructorMode,'PERSISTENT');h.join();eq(h.kicks,0)
 eq(h.profile().permanent.GE,'321','real persistent profile, not the starter balance')
 h.server:close()
end

-- A healthy read probe is insufficient: failure to acquire/write refuses the player.
do
 local profile=Schema.createReference('1',1000000);profile.permanent.GE='123'
 local h=runMain({writeFailure=true,records={['player:1']=profile}});local before=D.fingerprint(h.records)
 h.join();eq(h.kicks,1);eq(h.server:getPlayer('1'),nil);eq(D.fingerprint(h.records),before)
 eq(h.receipt('failed-acquire'),'NotProcessedYet');eq(h.constructs,1,'never reconstructed in memory')
 local writes=h.writes
 for i=1,5 do h.remote({protocolVersion=1,kind='Bootstrap',requestId='retry-'..i})end
 eq(h.writes,writes,'refused connection cannot flood acquisition attempts')
end

-- Healthy entrypoint: durable fulfillment, then outage, without changing its port.
do
 local h=runMain({attributes={ge_pack_small_PlatformId=987654321}});h.join()
 eq(h.kicks,0);eq(h.profile().permanent.GE,'10');local port=h.server.store
 eq(h.receipt('durable-first'),'PurchaseGranted');eq(h.records['player:1'].permanent.GE,'1010')
 h.writeFailure=true
 eq(h.receipt('outage-new-receipt'),'NotProcessedYet');eq(h.records['player:1'].permanent.GE,'1010')
 eq(h.server.store,port,'runtime outage never swaps storage');eq(h.constructs,1)
 local revision=h.profile().meta.revision
 h.remote({protocolVersion=1,kind='ClaimDailyGift',requestId='outage',operationId='outage-calendar',expectedRevision=revision,args={}})
 eq(h.records['player:1'].permanent.GE,'1010');eq(h.server:getCoordinator('1').snapshots().ready,false)
end

-- A lost write ACK stays unresolved until durable state is recovered, never paid twice.
do
 local h=runMain({attributes={ge_pack_small_PlatformId=987654321}});h.join();h.loseWriteAck=true
 eq(h.receipt('retry-confirmed'),'PurchaseGranted','retry may acknowledge only when it confirms the durable record')
 eq(h.records['player:1'].permanent.GE,'1010')
 eq(h.receipt('retry-confirmed'),'PurchaseGranted');eq(h.records['player:1'].permanent.GE,'1010')
 h.remote({protocolVersion=1,kind='ClaimDailyGift',requestId='after-confirmed-retry',operationId='after-confirmed-retry',expectedRevision=h.profile().meta.revision,args={}})
 eq(h.records['player:1'].permanent.GE,'1202','the next command must not overwrite a grant confirmed by retry')
end
do
 local h=runMain({attributes={ge_pack_small_PlatformId=987654321}});h.join();h.loseWriteAck=true;h.disconnectAfterAckLoss=true
 eq(h.receipt('lost-write-ack'),'NotProcessedYet')
 eq(h.records['player:1'].permanent.GE,'1010','only the persistent write contains the grant')
 local nextServer=runMain({nowMs=1120001,records=h.records,attributes={ge_pack_small_PlatformId=987654321}})
 nextServer.join()
 eq(nextServer.receipt('lost-write-ack'),'PurchaseGranted','saved success replays after a fresh process, without in-process entries')
 eq(nextServer.records['player:1'].permanent.GE,'1010')
end

-- REPLAYED is not sufficient: a durable rejection is never a purchase grant.
do
 local h=runMain({attributes={ge_pack_small_PlatformId=987654321}});h.join()
 local receipt={PlayerId=1,ProductId=987654321,PurchaseId='rejected'}
 local c=h.server:getCoordinator('1')
 c.submit({operationId='receipt-rejected',kind='PlatformPurchase',expectedRevision='999',args={purchaseToken='rejected',receiptInfo=receipt}})
 c.drain();eq(c.resultOf('receipt-rejected').status,'REJECTED')
 local queried=c.query('receipt-rejected');eq(queried.status,'REPLAYED');eq(queried.terminalStatus,'REJECTED')
 eq(h.market.ProcessReceipt(receipt),'NotProcessedYet');eq(h.records['player:1'].permanent.GE,'10')
end

-- Explicit Studio memory is offline-only, including direct trusted port calls.
do
 local h=runMain({studio=true,localMemory=true,openError=true,attributes={ge_pack_small_PlatformId=987654321,pro_permit_PlatformId=987654322}})
 eq(h.opens,0,'explicit local mode does not touch cloud');eq(h.constructorMode,'STUDIO_MEMORY')
 h.join();eq(h.kicks,0);eq(h.profile().permanent.GE,'10');eq(h.receipt('local'),'NotProcessedYet')
 local before=D.fingerprint({h.profile().permanent,h.profile().entitlements})
 eq(h.server:applyPurchase('1',{PurchaseId='direct',ProductId=987654321}),false)
 eq(h.server:grantEntitlement('1','pro_permit'),false)
 h.market.PromptGamePassPurchaseFinished:Fire(h.player,987654322,true)
 h.remote({protocolVersion=1,kind='PurchaseProduct',requestId='local-buy',operationId='local-buy',expectedRevision=h.profile().meta.revision,args={productId='ge_pack_small'}})
 local result=h.messages[#h.messages].message;eq(result.status,'REJECTED');eq(result.result.errorCode,'LOCAL_PAYMENTS_DISABLED')
 eq(D.fingerprint({h.profile().permanent,h.profile().entitlements}),before)
 eq(h.opens,0);eq(h.writes,0)
 -- Local free gameplay is still usable and remains intentionally nonpersistent.
 h.remote({protocolVersion=1,kind='ClaimDailyGift',requestId='local-calendar',operationId='local-calendar',expectedRevision=h.profile().meta.revision,args={}})
 eq(h.profile().permanent.GE,'202');eq(h.receipt('still-local'),'NotProcessedYet')
end

-- A handshake arriving while UpdateAsync yields must not open a second session.
do
 local h=runMain()
 h.onWrite=function()h.remote({protocolVersion=1,kind='Bootstrap',requestId='waiting-boot'})end
 h.join();eq(h.kicks,0);eq(h.writes,1,'one acquisition, not duplicate loading sessions')
 eq(h.messages[1].message.kind,'StateSnapshot');eq(h.messages[1].message.requestId,'waiting-boot')
end

fs.writeFile('build/persistence-startup-results.json',serde.encode('json',{status='PASS_L',assertions=assertions,actualMainEntrypoint=true,studioTested=false,realDataStoreTested=false,realPurchasesTested=false}))
print('Persistent startup fail-closed: '..assertions..' assertions PASS')
