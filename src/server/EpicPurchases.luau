--!strict
-- Shared-price purchases grant durable upgrade units, never an ephemeral selection.
-- Receipt IDs, units, intent and level are committed together by PlayerCoordinator.
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
local function consume(p: any, intent: any): boolean
 if not Availability.isEpicAvailable(intent.researchId) then return false end
 local s = state(p)
 local n = U.decode(s.credits[intent.productId] or "0")
 if U.compare(n,U.decode("1")) < 0 then return false end
 local current = E.level(p,intent.researchId)
 if current ~= intent.level-1 then return false end
 s.credits[intent.productId] = U.encode(U.subtract(n,U.decode("1")))
 p.permanent.epic=p.permanent.epic or {}
 p.permanent.epic[intent.researchId] = intent.level
 -- Preserve compatibility aliases already stored by older builds.
 for alias,canonical in aliases do if canonical==intent.researchId and p.permanent.epic[alias]~=nil then p.permanent.epic[alias]=intent.level end end
 s.pending=nil
 return true
end
function E.prepare(p: any, id: string, catalog: any, products: any): (boolean, any)
 id=E.canonical(id)
 if not Availability.isEpicAvailable(id) then return false,"FEATURE_UNAVAILABLE" end
 local ok,row=pcall(catalog.getEpic,id)
 if not ok then return false,"UNSUPPORTED_RESEARCH" end
 local level=E.level(p,id)+1
 if level>row.maxLevel then return false,"MAX_LEVEL" end
 local productId,nominal=Pricing.product(row.prices[level])
 local spec=products[productId]
 if not spec then return false,"PRODUCT_NOT_CONFIGURED" end
 local platformId=spec.platformId
 if type(platformId)~="number" or platformId%1~=0 or platformId<=0 or platformId>9007199254740991 then return false,"PRODUCT_NOT_CONFIGURED" end
 local s=state(p)
 -- A new explicit choice replaces the intent only; purchased units survive.
 local intent={researchId=id,level=level,productId=productId,platformId=platformId}
 s.pending=intent
 local granted=consume(p,intent)
 return true,{success=true,productId=productId,platformId=platformId,productType="developer_product",researchId=id,level=level,granted=granted,
  description="1 poziom wybranego badania Epic. Opłacone ulepszenie tej grupy cenowej pozostaje na koncie do wykorzystania. Cena bazowa: "..nominal.." R$. Ostateczna cena w oknie Roblox."}
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
 local pending=s.pending
 local granted=pending~=nil and pending.productId==productId and pending.platformId==receipt.ProductId and consume(p,pending)
 p.accounting.processedReceipts[token]={productId=productId,fulfilledAtMs=now}
 return true,{success=true,productId=productId,granted=granted,alreadyApplied=false}
end
function E.offers(p: any,catalog: any,products: any): any
 local rows={};local saved=p.permanent.epicPurchases
 for _,id in catalog.epicIds do
  if not Availability.isEpicAvailable(id) then continue end
  local row=catalog.getEpic(id);local level=E.level(p,id)+1
  if level>row.maxLevel then continue end
  local product,price=Pricing.product(row.prices[level])
  table.insert(rows,{researchId=id,productId=product,nominalPriceRobux=price,configured=products[product]~=nil,
   credits=if saved then saved.credits[product] or "0" else "0"})
 end
 return rows
end
return table.freeze(E)
