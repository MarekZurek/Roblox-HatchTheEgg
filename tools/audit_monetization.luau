--!strict
-- Read-only audit: actual active research catalogue vs the separate Beta proposal.
local fs=require('@lune/fs')
local serde=require('@lune/serde')
local Pricing=require('../src/shared/EpicPricing')
local Availability=require('../src/shared/FeatureAvailability')
local data=serde.decode('json',fs.readFile('docs/reference_data/research.json'))
local plan=serde.decode('json',fs.readFile('docs/workflow/monetization_beta_candidate_2026_11_04.json'))
local small,large=plan.products.ge_pack_small,plan.products.ge_pack_large
local bestRate=math.min(small.priceRobux/small.diamonds,large.priceRobux/large.diamonds)
local ids={'epic_upgrade_9','epic_upgrade_19','epic_upgrade_39','epic_upgrade_79'}
-- Historical pre-Beta rule, retained explicitly as a comparison baseline.
local function historical(reference:number):(string,number)
 if reference<=50 then return ids[1],9 end
 if reference<=200 then return ids[2],19 end
 if reference<=1000 then return ids[3],39 end
 return ids[4],79
end
local function proposed(ge:number):(string?,number?)
 if ge<plan.minimumDirectEpicCostGE then return nil,nil end
 for _,id in ids do local p=plan.products[id];if ge<=p.maxCostGE then return id,p.priceRobux end end
 return nil,nil
end
local rows={}
local counts={}
local minOld,maxOld=math.huge,0
local minNew,maxNew=math.huge,0
local active,total,covered=0,0,0
for _,research in data.epic do
 if not Availability.isEpicAvailable(research.id) then continue end
 active+=1
 for level,reference in research.prices do
  local ge=Pricing.ge(reference)
  local oldId,oldPrice=historical(reference)
  local oldRatio=oldPrice/(ge*bestRate)
  minOld=math.min(minOld,oldRatio);maxOld=math.max(maxOld,oldRatio)
  local newId,newPrice=proposed(ge)
  local actualId,actualPrice=Pricing.product(reference)
  assert(actualId==newId and actualPrice==newPrice,'runtime diverges from approved Beta offer')
  local newRatio=if newPrice then newPrice/(ge*bestRate) else nil
  if newRatio then
   assert(newRatio>=1-1e-12,'proposal undercuts best Diamonds rate')
   assert(newRatio<=plan.targets.maximumDirectEpicPremiumOverBestDiamondRate+1e-12,'proposal exceeds convenience-price bound')
   minNew=math.min(minNew,newRatio);maxNew=math.max(maxNew,newRatio)
   covered+=1;counts[newId]=(counts[newId]or 0)+1
  end
  total+=1
  table.insert(rows,{researchId=research.id,level=level,ge=ge,currentProduct=oldId,currentRobux=oldPrice,
   currentRatioToBestDiamondRate=oldRatio,proposedProduct=newId,proposedRobux=newPrice,
   proposedRatioToBestDiamondRate=newRatio,GEOnly=newId==nil})
 end
end
local function constantFarm(sessions:number,pro:boolean):number
 local activeHours=1/3
 local gap=(24-activeHours)/sessions
 return activeHours+sessions*math.min(gap,if pro then 18 else 6)*(if pro then 1 else .5)
end
local result={status='APPROVED_BETA_RUNTIME_AUDIT',activeResearch=active,levels=total,coveredDirectLevels=covered,
 GEOnlyLevels=total-covered,counts=counts,bestRobuxPerGE=bestRate,
 largePackQuantityValueBonus=(large.diamonds/large.priceRobux)/(small.diamonds/small.priceRobux)-1,
 currentDirectRatio={minimum=minOld,maximum=maxOld},proposedDirectRatio={minimum=minNew,maximum=maxNew},
 constantFarmIncomeExamples={oneDailySessionProRatio=constantFarm(1,true)/constantFarm(1,false),
 twoDailySessionsProRatio=constantFarm(2,true)/constantFarm(2,false),doubleCashRatio=2},
 limitations={'Not a progression simulation','Pass price optimality and conversion NOT ASSESSED: no telemetry',
 'All nine prices and Epic limits approved by user 2026-11-04',
 'Does not exercise platform prompts or actual receipts'},rows=rows}
fs.writeFile('build/monetization-balance-audit.json',serde.encode('json',result,true))
print(serde.encode('json',{active=active,levels=total,direct=covered,GEOnly=total-covered,
 current=result.currentDirectRatio,proposed=result.proposedDirectRatio,counts=counts,
 packBonus=result.largePackQuantityValueBonus,pro=result.constantFarmIncomeExamples}))
