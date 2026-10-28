--!strict
-- Public availability metadata. The server checks it again before spending/granting.
local blockedEpic: {[string]: boolean} = table.freeze({
 video_doubler_time=true, afx_mission_time=true, afx_mission_capacity=true,
 hold_to_research=true, epic_silo_quality=true, warp_shift=true,
})
local blockedProducts: {[string]: boolean} = table.freeze({
 auto_hatch=true, buy_max=true,
 epic_tier_1=true, epic_tier_2=true, epic_tier_3=true, epic_tier_4=true,
})
return table.freeze({
 blockedEpic=blockedEpic,
 isEpicAvailable=function(id: string): boolean return blockedEpic[id] ~= true end,
 isProductAvailable=function(id: string): boolean return blockedProducts[id] ~= true end,
})
