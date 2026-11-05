--!strict
-- User-approved Beta offer contract, 2026-11-04; expectations independent of runtime bands.
local Pricing=require('../../src/shared/EpicPricing')
local E=require('../../src/server/EpicPurchases')
local Schema=require('../../src/server/ProfileSchema').new(require('../../src/shared/NumericCodec'))
local count=0
local function eq(a:any,b:any,label:string?)
 count+=1;assert(a==b,(label or 'assertion')..': expected '..tostring(b)..', got '..tostring(a))
end
do -- Published Beta configuration must stay isolated and use the approved nine prices.
 local config=require('../../src/server/BetaProducts')
 eq(config.forPlace(10774701473,110937489000525),config.products,'Beta IDs enabled in correct place')
 eq(config.forPlace(0,110937489000525),nil,'other universe cannot use Beta IDs')
 eq(config.forPlace(10774701473,1),nil,'other place cannot use Beta IDs')
 local seen={};local n=0
 for id,price in {pro_permit=499,buy_max=149,double_cash=299,ge_pack_small=99,ge_pack_large=799,epic_upgrade_9=9,epic_upgrade_19=19,epic_upgrade_39=39,epic_upgrade_79=79} do
  local row=config.products[id];n+=1
  eq(row.priceRobux,price,'approved Beta price '..id)
  eq(type(row.platformId)=='number' and row.platformId>0 and row.platformId%1==0,true,'valid platform ID '..id)
  eq(seen[row.platformId],nil,'unique platform ID '..id);seen[row.platformId]=true
 end
 eq(n,9,'nine offers tested')
 eq(config.products.ge_pack_small.diamonds,1000,'small pack amount')
 eq(config.products.ge_pack_large.diamonds,10000,'large pack amount')
end
-- Arrange/act/assert: reference costs convert to ceil(reference/2) Diamonds.
for _,v in {{98,false},{99,'epic_upgrade_9',9},{100,'epic_upgrade_9',9},
 {200,'epic_upgrade_9',9},{201,'epic_upgrade_19',19},{400,'epic_upgrade_19',19},
 {401,'epic_upgrade_39',39},{900,'epic_upgrade_39',39},{901,'epic_upgrade_79',79},
 {1800,'epic_upgrade_79',79},{1801,false},{50000,false}} do
 local id,price=Pricing.product(v[1])
 eq(id,if v[2]==false then nil else v[2],'approved cost boundary '..v[1])
 eq(price,v[3],'approved boundary price '..v[1])
end
local products={epic_upgrade_9={platformId=7001},epic_upgrade_19={platformId=7002},epic_upgrade_39={platformId=7003},epic_upgrade_79={platformId=7004}}
local prices={98,99,200,201,400,401,900,901,1800,1801}
local catalog={epicIds={'hold_to_hatch'},getEpic=function(_id:string)return {maxLevel=#prices,prices=prices}end}
do -- Rejection must not mutate currency, pending choices, or paid units.
 local p=Schema.createReference('1',1000)
 local ok,reason=E.prepare(p,'hold_to_hatch',catalog,products)
 eq(ok,false,'below minimum rejected');eq(reason,'DIAMONDS_ONLY','specific eligibility reason')
 eq(p.permanent.epicPurchases,nil,'no intent created for unavailable direct offer')
 eq(#E.offers(p,catalog,products),0,'no out-of-band offer projected')
 p.permanent.epic={hold_to_hatch=9}
 ok,reason=E.prepare(p,'hold_to_hatch',catalog,products)
 eq(ok,false,'above maximum rejected');eq(reason,'DIAMONDS_ONLY','upper eligibility reason')
end
do -- Historical paid intent remains fulfillable even when outside new bands.
 local p=Schema.createReference('1',1000)
 p.permanent.epicPurchases={credits={},pending={researchId='hold_to_hatch',level=1,productId='epic_upgrade_9',platformId=7001}}
 local receipt={PlayerId=1,ProductId=7001}
 eq(E.receive(p,'legacy-paid',receipt,products,1001),true,'legacy receipt accepted')
 eq(p.permanent.epic.hold_to_hatch,nil,'legacy receipt does not automatically apply the level')
 eq(E.receive(p,'legacy-paid',receipt,products,1002),true,'legacy replay acknowledged')
 eq(p.permanent.epicPurchases.credits.epic_upgrade_9,'1','legacy replay cannot duplicate the credit')
 eq(E.offers(p,catalog,products)[1].credits,'1','legacy credit is visible on the promised level outside current bands')
 eq(E.prepare(p,'hold_to_hatch',catalog,products,true),true,'explicit USE honors legacy selection outside current bands')
 eq(p.permanent.epic.hold_to_hatch,1,'legacy USE delivers promised level')
 eq(p.permanent.epicPurchases.credits.epic_upgrade_9,'0','legacy paid unit consumed once')
end
do -- A canceled prompt has no receipt and grants nothing; saved unused credit survives choice.
 local p=Schema.createReference('1',1000);p.permanent.epic={hold_to_hatch=1}
 E.receive(p,'unused-paid',{PlayerId=1,ProductId=7004},products,1001)
 local ok,result=E.prepare(p,'hold_to_hatch',catalog,products)
 eq(ok,true,'eligible preview allowed');eq(result.granted,false,'preview grants nothing')
 eq(p.permanent.epic.hold_to_hatch,1,'no receipt no level')
 eq(p.permanent.epicPurchases.credits.epic_upgrade_79,'1','unmatched paid credit preserved')
 eq(E.offers(p,catalog,products)[1].productId,'epic_upgrade_9','eligible offer follows actual GE cost')
end
do -- Actual Main callback wiring, with controlled Marketplace/DataStore ports.
 local Main=require('../support/MainHarness')
 local config=require('../../src/server/BetaProducts')
 local h=Main.new({gameId=10774701473,placeId=110937489000525,assertEqual=eq})
 assert(h.server,table.concat(h.warnings,'; '))
 h.join()
 for _,id in {'pro_permit','buy_max','double_cash'} do
  h.market.PromptGamePassPurchaseFinished:Fire(h.player,config.products[id].platformId,false)
  eq(h.profile().entitlements[id],nil,'cancel does not grant '..id)
  h.market.PromptGamePassPurchaseFinished:Fire(h.player,config.products[id].platformId,true)
  eq(h.profile().entitlements[id],true,'confirmed platform callback grants '..id)
 end
 local before=h.profile().permanent.GE
 for _,id in {'ge_pack_small','ge_pack_large','epic_upgrade_9','epic_upgrade_19','epic_upgrade_39','epic_upgrade_79'} do
  local receipt={PlayerId=1,PurchaseId='beta-'..id,ProductId=config.products[id].platformId,
   CurrencyType=require('@lune/roblox').Enum.CurrencyType.Robux,CurrencySpent=config.products[id].priceRobux,PlaceIdWherePurchased=110937489000525}
  eq(h.market.ProcessReceipt(receipt),'PurchaseGranted','Main handles real Beta ID '..id)
  eq(h.market.ProcessReceipt(receipt),'PurchaseGranted','Main receipt retry '..id)
 end
 local U=require('../../src/shared/NumericCodec').ExactUInt
 local expectedGE=U.encode(U.add(U.decode(before),U.decode('11000')))
 eq(h.profile().permanent.GE,expectedGE,'both packs pay exact total once')
 for _,id in {'epic_upgrade_9','epic_upgrade_19','epic_upgrade_39','epic_upgrade_79'} do
  eq(h.profile().permanent.epicPurchases.credits[id],'1','unselected credit retained '..id)
 end
 h.server:close()
 local again=Main.new({gameId=10774701473,placeId=110937489000525,records=h.records,nowMs=1010000,assertEqual=eq});again.join()
 eq(again.profile().permanent.GE,expectedGE,'pack balance survives server restart')
 for _,id in {'pro_permit','buy_max','double_cash'} do eq(again.profile().entitlements[id],true,'pass survives restart '..id) end
 for _,id in {'epic_upgrade_9','epic_upgrade_19','epic_upgrade_39','epic_upgrade_79'} do
  eq(again.profile().permanent.epicPurchases.credits[id],'1','unused credit survives restart '..id)
 end
 eq(again.market.ProcessReceipt({PlayerId=1,PurchaseId='beta-ge_pack_small',ProductId=config.products.ge_pack_small.platformId}),'PurchaseGranted','receipt replay after restart acknowledged')
 eq(again.profile().permanent.GE,expectedGE,'reconnect replay cannot pay twice')
 again.server:close()
end
do -- A receipt arriving while another operation writes must not become terminally stale.
 local Main=require('../support/MainHarness');local config=require('../../src/server/BetaProducts')
 local h=Main.new({gameId=10774701473,placeId=110937489000525,assertEqual=eq});h.join()
 local receipt={PlayerId=1,ProductId=config.products.epic_upgrade_9.platformId,PurchaseId='racing-receipt'}
 h.onWrite=function() eq(h.market.ProcessReceipt(receipt),'NotProcessedYet','busy writer defers receipt acknowledgement') end
 h.server:grantEntitlement('1','buy_max')
 eq(h.market.ProcessReceipt(receipt),'PurchaseGranted','racing receipt succeeds on retry')
 eq(h.profile().permanent.epicPurchases.credits.epic_upgrade_9,'1','concurrent receipt grants exactly one unit')
 h.server:close()
end
do -- Persisted STALE_REVISION from an older build must be recoverable after reconnect.
 local Main=require('../support/MainHarness');local config=require('../../src/server/BetaProducts')
 local D=require('../../src/server/PersistenceData')
 local receipt={PlayerId=1,ProductId=config.products.epic_upgrade_9.platformId,PurchaseId='legacy-stale'}
 local p=Schema.createReference('1',1000000)
 p.operations['receipt-legacy-stale']={kind='PlatformPurchase',terminalStatus='REJECTED',resultRevision='0',result={errorCode='STALE_REVISION'},
  argsKey=D.fingerprint({kind='PlatformPurchase',args={purchaseToken='legacy-stale',receiptInfo=receipt},quoteId=''})}
 local h=Main.new({gameId=10774701473,placeId=110937489000525,records={['player:1']=p},assertEqual=eq});h.join()
 eq(h.market.ProcessReceipt(receipt),'PurchaseGranted','historical stale receipt recovered')
 eq(h.profile().permanent.epicPurchases.credits.epic_upgrade_9,'1','recovery pays promised unit')
 eq(h.profile().operations['receipt-legacy-stale'].terminalStatus,'REJECTED','historical record preserved')
 eq(h.market.ProcessReceipt(receipt),'PurchaseGranted','recovery replay acknowledged')
 eq(h.profile().permanent.epicPurchases.credits.epic_upgrade_9,'1','recovery cannot double-pay')
 h.server:close()
end
print('Beta monetization PASS: '..count..' assertions')
