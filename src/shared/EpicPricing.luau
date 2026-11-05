--!strict
-- User-approved Beta bands 2026-11-04. Reference/GE costs remain unchanged.
local P = {}
P.productIds = table.freeze({"epic_upgrade_9", "epic_upgrade_19", "epic_upgrade_39", "epic_upgrade_79"})
function P.ge(referencePrice: number): number
 return math.max(1, math.ceil(referencePrice / 2))
end
function P.product(referencePrice: number): (string?, number?)
 local ge = P.ge(referencePrice)
 if ge < 50 or ge > 900 then return nil, nil end
 if ge <= 100 then return P.productIds[1], 9 end
 if ge <= 200 then return P.productIds[2], 19 end
 if ge <= 450 then return P.productIds[3], 39 end
 return P.productIds[4], 79
end
function P.isProduct(id: string): boolean
 return table.find(P.productIds, id) ~= nil
end
return table.freeze(P)
