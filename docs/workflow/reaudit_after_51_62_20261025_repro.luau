-- Audit probes only. No gameplay source changes, cloud access or production data.
local B=require('../../src/server/Bootstrap')
local C=require('../../src/shared/NumericCodec')
local D=require('../../src/server/PersistenceData')
local S=require('../../src/server/ProfileSchema').new(C)
local Progress=require('../../src/server/ProgressActions')
local fs,serde=require('@lune/fs'),require('@lune/serde')
local results={}
local ORIGIN=1000000
local function record(id,actual,expected,extra)
 local row={id=id,actual=actual,expected=expected,evidence=extra}
 row.mismatch=if type(actual)=='number' and type(expected)=='number' then math.abs(actual-expected)>math.max(1,math.abs(expected))*1e-10 else actual~=expected
 table.insert(results,row);print(serde.encode('json',row))
end
local function create(mutate,events)
 local now=ORIGIN
 local b=B.new({storageMode='INTERNAL_TEST_ONLY',clock={utcNowMs=function()return now end,elapsedNowSeconds=function()return (now-ORIGIN)/1000 end},liveEvents=events or {}})
 local p=S.createReference('1',ORIGIN);p.farm.habitats[1].population='100'
 if mutate then mutate(p) end
 local valid,err=S.validate(p,'1');assert(valid,err)
 local joined=b:playerJoined('1',p);assert(joined and joined.status=='JOINED')
 return b,joined,function(seconds)now+=seconds*1000;b:tick(seconds)end
end
local function snap(b)return b:getCoordinator('1').snapshots().working end
local function mutate(b,kind,args,id)
 return b:dispatch('1',{protocolVersion=1,kind=kind,requestId=id,operationId=id,expectedRevision=snap(b).meta.revision,args=args or {}})
end
-- 1. Effective prestige collection event must come from the trusted current context.
do
 local b=create(function(p)p.accounting.currentFarmCash='1000000' end,{{type='prestige',multiplier=4,startTimeMs=ORIGIN-1000,deadlineMs=ORIGIN+10000}})
 local response=mutate(b,'Prestige',{},'audit-prestige-event')
 record('prestige_event',C.Real64.decode(snap(b).permanent.SE),4*(1000000^.15),{response=response})
end
-- 2. An existing Epic valuation upgrade must affect the documented FV calculation.
do
 local p=S.createReference('1',ORIGIN)
 local base=Progress.calculateProfileFarmValue(p)
 p.permanent.epic.accounting_tricks=20
 record('fv_valuation',Progress.calculateProfileFarmValue(p),base*2,{base=base,epicLevel=20,referenceMultiplier=2})
end
-- 3. Already-in-flight chickens must actually affect income with non-neutral RCB research.
do
 local b,_,step=create(function(p)
  p.farm.common.excitable_chickens=25
  p.farm.runningCount='10';p.farm.hatchGroupSequence='10';p.farm.habitats[1].assignedInTransit='10'
  p.farm.groups['hatch:10']={groupId='hatch:10',targetSlot=1,count='10',routeVersion='audit',startInstantMs=ORIGIN,travelDurationSeconds=10,status='IN_TRANSIT'}
 end)
 step(.3)
 record('active_rcb',C.BigAmount.decode(snap(b).farm.cash),.25*(1.025^10),{running=snap(b).farm.runningCount,referenceC=1.025,referenceK=5})
end
-- 4. Hold to Hatch is owned at max level, with space and full stock.
do
 local b,joined,step=create(function(p)p.farm.habitats[1].population='0';p.permanent.epic.hold_to_hatch=15 end)
 local response=b:dispatch('1',{protocolVersion=1,kind='HatchInput',requestId='audit-hold',streamId=joined.streamId,inputSeq='1',state='start'})
 step(.3)
 record('hold_hatching',snap(b).farm.runningCount~='0',true,{response=response,runtime=b:getPlayer('1').hatchingRuntime,stock=snap(b).farm.hatcheryStock,sequence=snap(b).farm.hatchGroupSequence})
end
-- 5. Full first habitat donates 100% IHR; second also receives its own 0.01 increment.
do
 local b,_,step=create(function(p)
  p.farm.habitats[1].population='250';p.farm.habitats[2].typeIndex=0
  p.farm.common.internal_hatchery1=1;p.permanent.epic.int_hatch_sharing=10
 end)
 step(.3)
 record('ihr_sharing',C.Real64.decode(snap(b).farm.habitats[2].fractionalIHR),.02,{commonRatePerHabPerMinute=2,sharing=1,dt=.3})
end
-- 6. Hyperloop train quoted and purchased despite permanent unlock=false.
do
 local b=create(function(p)p.farm.cash='1e40' end)
 local q=b:dispatch('1',{protocolVersion=1,kind='QuoteRequest',requestId='audit-train-quote',target={kind='BuyVehicle',args={slotId=1,vehicleId='HYPERLOOP TRAIN'}}})
 local r=mutate(b,'BuyVehicle',{slotId=1,vehicleId='HYPERLOOP TRAIN',quoteId=q.quoteId},'audit-train-buy')
 record('hyperloop_unlock',snap(b).farm.vehicles[1].typeIndex==11,false,{stationOwned=snap(b).permanent.hyperloop,quote=q,response=r})
end
-- 7. uint64 PE is valid and SE=0 avoids exponent overflow; FV must not demand safe uint53.
do
 local b=create(function(p)p.permanent.PE='9007199254740993';p.permanent.SE='0' end)
 local ok,res=pcall(b.dispatch,b,'1',{protocolVersion=1,kind='Bootstrap',requestId='audit-pe-view'})
 record('uint64_pe_projection',ok,true,{result=tostring(res),PE=snap(b).permanent.PE,SE=snap(b).permanent.SE})
end
-- 8. Main's current client-visible IDs have no server-issued records.
do
 local Main=require('../../tests/support/MainHarness')
 local h=Main.new();h.join()
 local b=h.server
 local droneOk,droneError=b:handleRewardRequest('1',{protocolVersion=1,kind='HitDrone',droneId='drone-1',operationId='audit-ui-drone'})
 local offerOk,offerError=b:handleRewardRequest('1',{protocolVersion=1,kind='ClaimOffer',offerId='offer_2plus1',operationId='audit-ui-offer'})
 h.remote({protocolVersion=1,kind='HitDrone',droneId='drone-1',operationId='audit-ui-drone'})
 h.remote({protocolVersion=1,kind='ClaimOffer',offerId='offer_2plus1',operationId='audit-ui-offer'})
 local popups=0
 for _,row in h.messages do if row.message.kind=='DroneRewardPopup' or row.message.kind=='OfferClaimedPopup' then popups+=1 end end
 record('visible_rewards_unissued',droneOk or offerOk,true,{droneError=droneError,offerError=offerError,realMainPopups=popups,GE=h.profile().permanent.GE})
end
-- 9. A fresh client must not reuse a durable ID for a newly intended research purchase.
do
 local Client=require('../../src/client/Bootstrap')
 local b=create(function(p)p.farm.cash='1000000' end)
 local function client()
  local c
  c=Client.new({playerId='1',wire=function(packet)
   local response=b:dispatch('1',packet)
   if response then c:receive(response) end
  end})
  c:connect('audit-client-connect');return c
 end
 local first=client();local firstResult
 first:buyResearch('comfy_nests',function(r)firstResult=r end)
 local firstLevel=snap(b).farm.common.comfy_nests
 first:destroy();b:playerLeaving('1');assert(b:playerJoined('1'))
 local second=client();local secondResult
 second:buyResearch('comfy_nests',function(r)secondResult=r end)
 record('research_after_reconnect',snap(b).farm.common.comfy_nests,2,{firstLevel=firstLevel,firstResult=firstResult,secondResult=secondResult})
end
fs.writeFile('build/reaudit_20261025_results.json',serde.encode('json',{level='L',studioTested=false,realDataStoreTested=false,results=results},true))
