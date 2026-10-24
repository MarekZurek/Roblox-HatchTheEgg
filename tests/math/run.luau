--!nocheck
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local Codec = require("../../src/shared/NumericCodec")
local Catalog = require("../../src/server/CatalogRegistry").new(Codec, require("../../src/server/CatalogRegistry/Data"), {mode="INTERNAL_TEST_ONLY"})
local Module = require("../../src/server/FarmMath/production_research")
local M = Module.new(Codec, Catalog, {mode="INTERNAL_TEST_ONLY"})
local assertions = 0
local function eq(a,b) assertions += 1; assert(a == b, tostring(a).." != "..tostring(b)) end
local function near(a,b)
	assertions += 1
	assert(math.abs(a-b) <= math.max(math.abs(b)*2e-15, 1e-15), tostring(a).." != "..tostring(b))
end
local function reject(fn) assertions += 1; eq(pcall(fn), false) end
local n = M.research({})
eq(n.commonPoints,0);eq(n.refillPerSecond,3);eq(n.hatcheryCapacity,250)
eq(n.internalHatcheryPerHabPerMinute,0);eq(n.eggValue,0.25);eq(n.layingPerChickenPerSecond,1/30)
-- Independent per-level formulas from the seven documented reference dimensions.
local rules = {
	comfy_nests={50,"layingPerChickenPerSecond",function(l) return (1+0.1*l)/30 end},
	nutritional_sup={40,"eggValue",function(l) return 0.25*(1+0.25*l) end},
	better_incubators={15,"refillPerSecond",function(l) return 3*(1+0.1*l) end},
	hab_capacity1={8,"habCapacityMult",function(l) return 1+0.05*l end},
	internal_hatchery1={10,"internalHatcheryPerHabPerMinute",function(l) return 2*l end},
	hatchery_expansion={10,"hatcheryCapacity",function(l) return 250+10*l end},
	leafsprings={30,"vehicleCapacityMult",function(l) return 1+0.05*l end},
}
for id, rule in rules do
	for level=0,rule[1] do local r=M.research({[id]=level});eq(r.commonPoints,level);near(r[rule[2]],rule[3](level)) end
	for _,bad in {-1,0.5,rule[1]+1,math.huge,0/0,"1"} do reject(function() M.research({[id]=bad}) end) end
end
for tier,threshold in {0,30,80,160,280,400,520,650,800,980,1185,1390,1655} do
	-- All known thresholds are checked against attainable first-fragment points; high tiers remain locked.
	local level=math.min(50,threshold)
	eq(M.tierUnlocked({comfy_nests=level},tier-1),level>=threshold)
end
for _,p in {29,30,31,79,80,81} do
	local levels={comfy_nests=math.min(p,50),nutritional_sup=math.max(0,p-50)}
	eq(M.tierUnlocked(levels,1),p>=30);eq(M.tierUnlocked(levels,2),p>=80)
	eq(M.canResearch(levels,"hab_capacity1"),p>=30)
	eq(M.canResearch(levels,"leafsprings"),p>=80)
end
eq(M.canResearch({comfy_nests=50},"comfy_nests"),false)
reject(function() M.research({epic_egg_laying=20}) end)
reject(function() M.research({unsupported_common=0}) end)
reject(function() M.tierUnlocked({},13) end)
-- Multi-tier research aggregation tests
local rMultiLay = M.research({comfy_nests = 1, hen_house_ac = 1})
near(rMultiLay.layingPerChickenPerSecond, (1.1 * 1.05) / 30)
local rMultiVal = M.research({nutritional_sup = 1, bigger_eggs = 1})
near(rMultiVal.eggValue, 0.25 * (1.25 * 2.0))
local rFleet = M.research({vehicle_reliablity = 1})
eq(rFleet.maxFleetSize, 5)
near(M.shippingPerSecond({vehicle_reliablity = 1}, {0, 0, 0, 0, 0}), (5000 * 5) / 60)
local rFleetMax = M.research({vehicle_reliablity = 2, excoskeletons = 2})
eq(rFleetMax.maxFleetSize, 8)
local caps,total = M.capacities({hab_capacity1=1},{0,0,1,false})
eq(caps[1],263);eq(caps[2],263);eq(caps[3],525);eq(caps[4],0);eq(total,1051)
near(M.shippingPerSecond({},{0}),5000/60)
near(M.shippingPerSecond({leafsprings=1},{0,1}),20000*1.05/60)
eq(M.shippingPerSecond({},{}),0)
local state={commonLevels={},habitatTypes={0,false,false,false},settledPopulation={"100","0","0","0"},vehicleTypes={0},rcbMultiplier=1}
local before=serde.encode("json",state)
local step=M.productionStep(state,0.3)
near(step.producedEggs,1);near(step.soldEggs,1);near(step.cashIncome,0.25)
eq(step.usedSettledPopulation,100);eq(step.populationConversion,"EXACT_SAFE_INTEGER")
eq(serde.encode("json",state),before)
state.reservedInTransit={"150","0","0","0"}
near(M.productionStep(state,0.3).cashIncome,0.25) -- in-flight does not lay eggs
state.rcbMultiplier=5;near(M.productionStep(state,0.3).cashIncome,1.25)
state.commonLevels={comfy_nests=50};state.habitatTypes={1,1,1,1};state.settledPopulation={"500","500","500","500"}
step=M.productionStep(state,0.3)
near(step.producedEggs,120);near(step.soldEggs,25);near(step.cashIncome,31.25)
state.vehicleTypes={};eq(M.productionStep(state,0.3).soldEggs,0)
eq(M.productionStep(state,0).cashIncome,0)
state.vehicleTypes={0};state.rcbMultiplier=1
-- A representable dt immediately below 0.3 stays valid; do not round each step to milliseconds.
local edgeDt=0.29999999999999993
step=M.productionStep(state,edgeDt)
eq(step.soldEggs,(5000/60)*edgeDt)
eq(step.cashIncome,((5000/60)*edgeDt)*0.25)
for _,bad in {-1,math.huge,0/0,0.30000000000000004} do reject(function() M.productionStep(state,bad) end) end
state.settledPopulation[1]="501";reject(function() M.productionStep(state,0.3) end)
state.settledPopulation[1]="9007199254740992";reject(function() M.productionStep(state,0.3) end)
state.settledPopulation[1]="500";state.rcbMultiplier=0/0;reject(function() M.productionStep(state,0.3) end)
reject(function() M.capacities({},{0,false,false}) end)
reject(function() M.shippingPerSecond({},{0,0,0,0,0}) end)
reject(function() Module.new(Codec,Catalog,{mode="PRODUCTION"}) end)
fs.writeFile("build/math-results.json",serde.encode("json",{status="PASS",level="L",assertions=assertions,studioTested=false,dataStoreTested=false,scope="IMP-04 seven Common and pure production"},true))
print("FarmMath production/research PASS: "..assertions.." assertions")
