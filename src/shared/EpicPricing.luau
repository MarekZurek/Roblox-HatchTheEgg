--!strict
-- User-approved trial pricing 2026-10-28. Reference catalogues remain unchanged.
local P = {}
P.productIds = table.freeze({"epic_upgrade_9", "epic_upgrade_19", "epic_upgrade_39", "epic_upgrade_79"})
function P.ge(referencePrice: number): number
 return math.max(1, math.ceil(referencePrice / 2))
end
function P.product(referencePrice: number): (string, number)
 -- Keep the historical reference-price bands when reducing both currencies.
 if referencePrice <= 50 then return P.productIds[1], 9 end
 if referencePrice <= 200 then return P.productIds[2], 19 end
 if referencePrice <= 1000 then return P.productIds[3], 39 end
 return P.productIds[4], 79
end
function P.isProduct(id: string): boolean
 return table.find(P.productIds, id) ~= nil
end
return table.freeze(P)
