--!strict
-- Approved 2026-11-04. Real IDs belong only to this private Beta place/universe.
local B={universeId=10774701473,placeId=110937489000525}
B.products=table.freeze({
 pro_permit=table.freeze({platformId=2069996186,priceRobux=499,productType='gamepass'}),
 buy_max=table.freeze({platformId=2070469851,priceRobux=149,productType='gamepass'}),
 double_cash=table.freeze({platformId=2067026331,priceRobux=299,productType='gamepass'}),
 ge_pack_small=table.freeze({platformId=3728329433,priceRobux=99,diamonds=1000,productType='developer_product'}),
 ge_pack_large=table.freeze({platformId=3728329472,priceRobux=799,diamonds=10000,productType='developer_product'}),
 epic_upgrade_9=table.freeze({platformId=3728320227,priceRobux=9,productType='developer_product'}),
 epic_upgrade_19=table.freeze({platformId=3728329222,priceRobux=19,productType='developer_product'}),
 epic_upgrade_39=table.freeze({platformId=3728329301,priceRobux=39,productType='developer_product'}),
 epic_upgrade_79=table.freeze({platformId=3728329363,priceRobux=79,productType='developer_product'}),
})
function B.forPlace(universeId:number,placeId:number):any
 if universeId==B.universeId and placeId==B.placeId then return B.products end
 return nil
end
return table.freeze(B)
