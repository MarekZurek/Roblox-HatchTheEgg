--!nocheck
-- Internal first-farm wire profile. Existing unknown sections are retained.
local Schema = {}
function Schema.new(codec)
	local U, R, A = codec.ExactUInt, codec.Real64, codec.BigAmount
	local function uint(text) U.decode(text) end
	local function real(text) R.decode(text) end
	local function instant(n) assert(type(n)=="number" and n>=0 and n<=9007199254740991 and n%1==0, "INVALID_INSTANT") end
	local function validate(p, playerId)
		assert(type(p)=="table" and type(p.meta)=="table", "CORRUPT_PROFILE")
		if p.meta.schemaVersion ~= 1 then return false, "UNSUPPORTED_SCHEMA" end
		if p.meta.numericCodecVersion ~= codec.VERSION or p.meta.calculationVersion ~= 1 then return false,"UNSUPPORTED_VERSION" end
		assert(p.meta.playerId==playerId and type(p.meta.configRevision)=="string", "PROFILE_IDENTITY")
		uint(p.meta.revision)
		for _, section in {"ownership","farm","accounting","permanent","inventory","effects","timeline","rewards","piggy","entitlements","operations"} do
			assert(type(p[section])=="table", "MISSING_SECTION:"..section)
		end
		uint(p.ownership.generation); instant(p.ownership.endsAtMs)
		assert(type(p.ownership.ownerToken)=="string", "INVALID_OWNER")
		A.decode(p.farm.cash); A.decode(p.farm.hatcheryStock); uint(p.farm.runningCount)
		assert(type(p.farm.habitats)=="table" and #p.farm.habitats==4, "INVALID_HABITATS")
		local reserved=U.fromSafeNumber(0)
		for _, hab in p.farm.habitats do
			uint(hab.population);uint(hab.assignedInTransit)
			local fraction=R.decode(hab.fractionalIHR); assert(fraction>=0 and fraction<1,"INVALID_IHR_FRACTION")
			reserved=U.add(reserved,U.decode(hab.assignedInTransit))
		end
		assert(U.encode(reserved)==p.farm.runningCount,"INCONSISTENT_RESERVATIONS")
		uint(p.permanent.GE); uint(p.permanent.totalGESpent); A.decode(p.permanent.SE);uint(p.permanent.PE)
		for _,name in {"prestigeSessionArchivedCash","prestigeExtraEarnings","lastBaseEarnings","currentFarmCash","lastCashEarned"} do A.decode(p.accounting[name]) end
		instant(p.timeline.settledWallThrough)
		for id, op in p.operations do
			assert(type(id)=="string" and type(op)=="table" and type(op.argsKey)=="string" and type(op.result)=="table", "INVALID_LEDGER")
			assert(op.terminalStatus=="APPLIED" or op.terminalStatus=="REJECTED", "INVALID_LEDGER_STATUS")
			uint(op.resultRevision)
		end
		return true
	end
	local function createReference(playerId, nowMs)
		instant(nowMs)
		local habitats = {}
		for i=1,4 do habitats[i]={typeIndex=if i==1 then 0 else -1,population="0",assignedInTransit="0",fractionalIHR="0"} end
		return {
			meta={schemaVersion=1,numericCodecVersion=codec.VERSION,calculationVersion=1,configRevision="first-farm-neutral:1",revision="0",playerId=playerId,mode="INTERNAL_TEST_ONLY"},
			ownership={generation="0",ownerToken="",endsAtMs=0},
			farm={eggIndex=0,maxEggReached=0,cash="0",habitats=habitats,vehicles={{typeIndex=0}},fleetLimit=4,siloOwned=1,common={},hatcheryStock="250",runningCount="0",groups={}},
			accounting={prestigeSessionArchivedCash="0",prestigeExtraEarnings="0",lastBaseEarnings="0",currentFarmCash="0",lastCashEarned="0"},
			permanent={GE="10",totalGESpent="0",SE="0",PE="0",epic={},hyperloop=false,prestigeCount="0"},
			inventory={boosts={},pets={},equipped={},guarantees={}}, effects={boosts={}},
			timeline={settledWallThrough=nowMs},rewards={},piggy={},entitlements={},operations={},
		}
	end
	return table.freeze({ validate=validate, createReference=createReference })
end
return table.freeze(Schema)
