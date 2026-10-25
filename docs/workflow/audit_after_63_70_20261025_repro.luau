-- Read-only source audit. All mutations affect isolated local fixture stores only.
local B=require('../../src/server/Bootstrap')
local C=require('../../src/shared/NumericCodec')
local D=require('../../src/server/PersistenceData')
local S=require('../../src/server/ProfileSchema').new(C)
local Progress=require('../../src/server/ProgressActions')
local Main=require('../../tests/support/MainHarness')
local fs,serde=require('@lune/fs'),require('@lune/serde')
local ORIGIN=1000000
local observations={}
local function record(id,actual,expected,evidence)
 local mismatch=if type(actual)=='number' and type(expected)=='number' then math.abs(actual-expected)>math.max(1,math.abs(expected))*1e-10 else actual~=expected
 local row={id=id,actual=actual,expected=expected,mismatch=mismatch,evidence=evidence}
 table.insert(observations,row);print(serde.encode('json',row))
end
local function harness(mutate,events)
 local h={now=ORIGIN,records={}}
 h.store={read=function(k)return true,h.records[k] and D.copy(h.records[k])end,update=function(k,fn)
  if h.beforeWrite then local hook=h.beforeWrite;h.beforeWrite=nil;hook()end
  local out=fn(h.records[k] and D.copy(h.records[k]));if out then h.records[k]=D.copy(out)end
  return true,out and D.copy(out)
 end}
 h.b=B.new({storageMode='INTERNAL_TEST_ONLY',clock={utcNowMs=function()return h.now end,elapsedNowSeconds=function()return (h.now-ORIGIN)/1000 end},store=h.store,liveEvents=events or {}})
 local p=S.createReference('1',ORIGIN);p.farm.cash='1000000';if mutate then mutate(p)end
 assert(S.validate(p,'1'));assert(h.b:playerJoined('1',p))
 function h.p()local ss=h.b:getCoordinator('1').snapshots();return ss.working or ss.durable end
 function h.cmd(kind,args,id)return h.b:dispatch('1',{protocolVersion=1,kind=kind,requestId=id,operationId=id,expectedRevision=h.p().meta.revision,args=args or {}})end
 function h.input(state,seq)return h.b:dispatch('1',{protocolVersion=1,kind='HatchInput',requestId='input-'..seq,streamId=h.b:getPlayer('1').hatchingRuntime.streamId,inputSeq=tostring(seq),state=state})end
 return h
end
-- A. An owned pass must be reconciled after the bounded offline settlement finishes.
do
 local p=S.createReference('1',ORIGIN-61000)
 local h=Main.new({records={['player:1']=p},owns={[987654322]=true},attributes={pro_permit_PlatformId=987654322}})
 local jobs=h.join();local grants={}
 local grant=h.server.grantEntitlement
 function h.server:grantEntitlement(...)local ok,detail=grant(self,...);table.insert(grants,{ok=ok,detail=detail});return ok,detail end
 for _,index in jobs do h.runJob(index)end
 local n=0
 while not h.server:getCoordinator('1').snapshots().ready do h.server:tick(0);n+=1;assert(n<100,'settlement stuck')end
 local ss=h.server:getCoordinator('1').snapshots()
 record('owned_pro_after_offline',ss.durable.entitlements.pro_permit==true,true,{ownershipChecks=h.market.ownershipChecks,ready=ss.ready,settledThrough=ss.working.timeline.settledWallThrough,serverNow=ORIGIN,settlingTicks=n,grants=grants,platformOwned=true})
end
-- B. The maximum RCB research term in FV is not the current running bonus.
do
 local p=S.createReference('1',ORIGIN);p.farm.common.coordinated_clucking=50
 local expected=50*1200*(1/30)*.25*(250^.6)*(11^.25)
 record('fv_max_rcb',Progress.calculateProfileFarmValue(p),expected,{researchMaxRCBBase=10,researchMaxRCBMult=1,expectedRCBTerm='(5+10-4)^0.25'})
end
-- C. Existing Epic cost effects must apply to the actual quote and wallet debit.
do
 local rawResearch=serde.decode('json',fs.readFile('docs/reference_data/research.json'))
 local rawInfra=serde.decode('json',fs.readFile('docs/reference_data/infrastructure.json'))
 local comfy
 for _,r in rawResearch.common do if r.id=='comfy_nests' then comfy=r.prices[1]end end
 local cases={
  {id='research_discount',epic='cheaper_research',kind='BuyResearch',args={researchId='comfy_nests',mode='single'},base=comfy},
  {id='habitat_discount',epic='cheaper_contractors',kind='BuyHabitat',args={slotId=1,habitatId='SHACK'},base=rawInfra.habitats[2].prices[1]},
  {id='vehicle_discount',epic='bust_unions',kind='BuyVehicle',args={slotId=1,vehicleId='TRANSIT VAN'},base=rawInfra.vehicles[2].prices[1]},
 }
 for _,case in cases do
  local h=harness(function(p)p.permanent.epic[case.epic]=10 end)
  local q=h.b:dispatch('1',{protocolVersion=1,kind='QuoteRequest',requestId='discount-quote',target={kind=case.kind,args=case.args}})
  local args=D.copy(case.args);args.quoteId=q.quoteId
  local result=h.cmd(case.kind,args,'discount-buy')
  record(case.id,C.BigAmount.decode(q.cashCost),case.base*.5,{result=result.status,walletAfter=h.p().farm.cash,expectedWalletAfter=C.BigAmount.encode(1000000-case.base*.5),referenceBasePrice=case.base})
 end
end
-- D. A rejected reset must not terminate a still-valid active hold intention.
do
 local h=harness(function(p)p.permanent.epic.hold_to_hatch=15;p.accounting.currentFarmCash='1000000' end,
  {{type='prestige',multiplier=4,startTimeMs=ORIGIN,deadlineMs=ORIGIN+100}})
 h.input('start',1)
 h.beforeWrite=function()h.now=ORIGIN+100 end
 local rejected=h.cmd('Prestige',{},'rejected-prestige')
 h.input('refresh',2);h.now=ORIGIN+400;h.b:tick(.3)
 record('rejected_reset_kills_hold',h.p().farm.hatchGroupSequence~='0',true,{result=rejected,runtime=h.b:getPlayer('1').hatchingRuntime,prestigeCount=h.p().permanent.prestigeCount,earnings=h.p().accounting.currentFarmCash})
end
fs.writeFile('build/audit_after_63_70_results.json',serde.encode('json',{level='L',observations=observations,studioTested=false,realDataStoreTested=false},true))
