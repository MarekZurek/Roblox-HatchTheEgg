-- Controlled native services for execution of the actual Main.server entrypoint.
local fs,serde,luau=require('@lune/fs'),require('@lune/serde'),require('@lune/luau')
local B=require('../../src/server/Bootstrap')
local Port=require('../../src/server/RobloxDataStorePort')
local Products=require('../../src/server/platform/products')
local D=require('../../src/server/PersistenceData')
local mainSource=fs.readFile('src/server/Main.server.luau')
local function signal()
 local s={callbacks={}}
 function s:Connect(fn)table.insert(self.callbacks,fn);return {Disconnect=function()end}end
 function s:Fire(...)for _,fn in table.clone(self.callbacks)do fn(...)end end
 return s
end
local function runMain(options)
 options=options or {}
 local eq=options.assertEqual or function(a,b,label)assert(a==b,(label or "").." expected "..tostring(b).." got "..tostring(a))end
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
 h.owns=options.owns or {};h.policyCalls=0;h.policyResponse=options.policyResult or {ArePaidRandomItemsRestricted=false}
 local market={PromptGamePassPurchaseFinished=signal(),ownershipChecks=0}
 function market:UserOwnsGamePassAsync(_id,passId)self.ownershipChecks+=1;if h.ownershipError then error("ownership unavailable")end;return if h.owns[passId]==nil then true else h.owns[passId] end
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
 services.PolicyService={GetPolicyInfoForPlayerAsync=function(_self,player)
  h.policyCalls+=1
  if h.onPolicy then return h.onPolicy(player)end
  if h.policyFailure then error("policy unavailable")end
  return h.policyResponse and D.copy(h.policyResponse)
 end}
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
 function h.join()
  local before=#h.jobs;players.PlayerAdded:Fire(h.player)
  local jobs={};for i=before+1,#h.jobs do table.insert(jobs,i)end;return jobs
 end
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

return table.freeze({new=runMain})
