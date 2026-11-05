--!strict
-- Shared-price purchases grant durable upgrade units, never an ephemeral selection.
-- Receipts add credits. Only an explicit redemption spends one and grants a level.
local studio = typeof(script) == "Instance"
local Pricing = if studio then require(game:GetService("ReplicatedStorage").HatchTheEgg.Shared.EpicPricing) else require("../shared/EpicPricing")
local Availability = if studio then require(game:GetService("ReplicatedStorage").HatchTheEgg.Shared.FeatureAvailability) else require("../shared/FeatureAvailability")
local Codec = if studio then require(game:GetService("ReplicatedStorage").HatchTheEgg.Shared.NumericCodec) else require("../shared/NumericCodec")
local U = Codec.ExactUInt
local E = {}
local aliases = {lab_upgrade="cheaper_research",epic_int_hatchery="epic_internal_incubators",silo_quality="epic_silo_quality",internal_hatchery_calm="int_hatch_calm",soul_food="soul_eggs",epic_comfy_nests="epic_egg_laying",transportation_fleet="transportation_lobbyist",afx_ship_capacity="afx_mission_capacity"}
function E.canonical(id: string): string return aliases[id] or id end
function E.level(p: any,id: string): number
 local epic=p.permanent.epic or {}
 local level=epic[id] or 0
 for alias,canonical in aliases do if canonical==id then level=math.max(level,epic[alias] or 0) end end
 return level
end
local function state(p: any): any
 p.permanent.epicPurchases = p.permanent.epicPurchases or {credits={}}
 return p.permanent.epicPurchases
end
local function legacyCredit(saved: any, id: string, level: number): string?
 -- Older builds offered levels outside today's bands. Honor that saved selection
 -- on explicit USE when the corresponding paid credit is available.
 local pending = saved and saved.pending
 if pending and pending.researchId == id and pending.level == level
  and Pricing.isProduct(pending.productId) and (saved.credits[pending.productId] or "0") ~= "0" then
  return pending.productId
 end
 return nil
end
local bands = {epic_upgrade_9="50–100", epic_upgrade_19="101–200", epic_upgrade_39="201–450", epic_upgrade_79="451–900"}

function E.prepare(p: any, id: string, catalog: any, products: any, useCredit: boolean?): (boolean, any)
 id=E.canonical(id)
 if not Availability.isEpicAvailable(id) then return false,"FEATURE_UNAVAILABLE" end
 local ok,row=pcall(catalog.getEpic,id)
 if not ok then return false,"UNSUPPORTED_RESEARCH" end
 local level=E.level(p,id)+1
 if level>row.maxLevel then return false,"MAX_LEVEL" end
 local saved=p.permanent.epicPurchases
 local productId,nominal=Pricing.product(row.prices[level])
 local legacy=if useCredit then legacyCredit(saved,id,level) else nil
 productId=legacy or productId
 if not productId then return false,"DIAMONDS_ONLY" end
 local spec=products[productId]
 local platformId=spec and spec.platformId
 local description
 if useCredit then
  local credit=saved and saved.credits[productId] or "0"
  if credit=="0" then return false,"NO_EPIC_CREDIT" end
  saved.credits[productId]=U.encode(U.subtract(U.decode(credit),U.decode("1")))
  p.permanent.epic=p.permanent.epic or {}
  p.permanent.epic[id]=level
  for alias,canonical in aliases do
   if canonical==id and p.permanent.epic[alias]~=nil then p.permanent.epic[alias]=level end
  end
  if legacy then saved.pending=nil end
  platformId=platformId or 0
  description="Epic credit used."
 else
  if type(platformId)~="number" or platformId%1~=0 or platformId<=0 or platformId>9007199254740991 then return false,"PRODUCT_NOT_CONFIGURED" end
  description="Buy 1 Epic credit for a research level in the "..bands[productId].." Diamonds band. "
   .."The credit stays on your account. Choose an eligible research and tap USE to apply it. "
   .."Base price: "..tostring(nominal).." R$. Final price in Roblox window."
 end
 return true,{success=true,productId=productId,platformId=platformId,productType="developer_product",researchId=id,level=level,granted=useCredit==true,description=description}
end
function E.receive(p: any, token: string, receipt: any, products: any, now: number): (boolean, any)
 local productId
 for _,id in Pricing.productIds do if products[id] and products[id].platformId==receipt.ProductId then productId=id;break end end
 if not productId then return false,"NOT_EPIC_PRODUCT" end
 if tostring(receipt.PlayerId)~=p.meta.playerId then return false,"RECEIPT_OWNER_MISMATCH" end
 p.accounting.processedReceipts=p.accounting.processedReceipts or {}
 local saved=p.accounting.processedReceipts[token]
 if saved then
  if saved.productId~=productId then return false,"RECEIPT_PRODUCT_MISMATCH" end
  return true,{success=true,alreadyApplied=true,productId=productId}
 end
 local s=state(p)
 s.credits[productId]=U.encode(U.add(U.decode(s.credits[productId] or "0"),U.decode("1")))
 p.accounting.processedReceipts[token]={productId=productId,fulfilledAtMs=now}
 return true,{success=true,productId=productId,granted=false,alreadyApplied=false}
end
function E.offers(p: any,catalog: any,products: any): any
 local rows={};local saved=p.permanent.epicPurchases
 for _,id in catalog.epicIds do
  if not Availability.isEpicAvailable(id) then continue end
  local row=catalog.getEpic(id);local level=E.level(p,id)+1
  if level>row.maxLevel then continue end
  local product,price=Pricing.product(row.prices[level])
  product=legacyCredit(saved,id,level) or product
  if not product then continue end
  table.insert(rows,{researchId=id,productId=product,nominalPriceRobux=price or 0,configured=products[product]~=nil,
   credits=if saved then saved.credits[product] or "0" else "0"})
 end
 return rows
end
return table.freeze(E)
