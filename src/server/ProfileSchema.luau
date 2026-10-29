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
		if p.farm.hatchGroupSequence~=nil then uint(p.farm.hatchGroupSequence) end
		assert(type(p.farm.habitats)=="table" and #p.farm.habitats==4, "INVALID_HABITATS")
		local reserved=U.fromSafeNumber(0)
		for _, hab in p.farm.habitats do
			uint(hab.population);uint(hab.assignedInTransit)
			local fraction=R.decode(hab.fractionalIHR); assert(fraction>=0,"INVALID_IHR_FRACTION")
			reserved=U.add(reserved,U.decode(hab.assignedInTransit))
		end
		assert(U.encode(reserved)==p.farm.runningCount,"INCONSISTENT_RESERVATIONS")
		uint(p.permanent.GE); uint(p.permanent.totalGESpent); A.decode(p.permanent.SE);uint(p.permanent.PE)
		if p.permanent.shellScripts~=nil then uint(p.permanent.shellScripts) end
		if p.permanent.epicPurchases~=nil then
			local s=p.permanent.epicPurchases
			assert(type(s)=="table" and type(s.credits)=="table","INVALID_EPIC_PURCHASES")
			for key,n in s.credits do assert(type(key)=="string" and string.match(key,"^epic_upgrade_%d+$"),"INVALID_EPIC_CREDIT_PRODUCT");uint(n) end
			if s.pending~=nil then
				local q=s.pending
				assert(type(q)=="table" and type(q.researchId)=="string" and type(q.productId)=="string" and string.match(q.productId,"^epic_upgrade_%d+$"),"INVALID_EPIC_INTENT")
				assert(type(q.level)=="number" and q.level%1==0 and q.level>0 and q.level<=65535,"INVALID_EPIC_INTENT_LEVEL")
				instant(q.platformId);assert(q.platformId>0,"INVALID_EPIC_INTENT_PRODUCT")
			end
		end
		for _,name in {"prestigeSessionArchivedCash","prestigeExtraEarnings","lastBaseEarnings","currentFarmCash","lastCashEarned"} do A.decode(p.accounting[name]) end
		instant(p.timeline.settledWallThrough)
        if p.timeline.selectionState~=nil then local seed=U.toSafeNumber(U.decode(p.timeline.selectionState));assert(seed>0 and seed<4294967296,"INVALID_SELECTION_STATE") end
		if p.effects.boosts~=nil then
			assert(type(p.effects.boosts)=="table","INVALID_BOOSTS")
			for _,boost in p.effects.boosts do
				assert(type(boost)=="table" and type(boost.id)=="string","INVALID_BOOST")
				local remaining=if type(boost.remainingSeconds)=="string" then R.decode(boost.remainingSeconds) else R.validate(boost.remainingSeconds)
				assert(remaining>=0,"INVALID_BOOST_DURATION")
			end
		end
		if p.effects.videoDoublerEndsAtMs~=nil then instant(p.effects.videoDoublerEndsAtMs) end
		if p.effects.videoDoubler~=nil then instant(p.effects.videoDoubler.endsAtMs) end
		if p.inventory.petSequence~=nil then uint(p.inventory.petSequence) end
		if p.rewards.droneSpawns~=nil then
			assert(type(p.rewards.droneSpawns)=="table","INVALID_DRONE_REGISTRY")
			for id,spawn in p.rewards.droneSpawns do
				assert(type(id)=="string" and type(spawn)=="table" and spawn.spawnId==id and spawn.ownerId==playerId,"INVALID_DRONE_OWNER")
				instant(spawn.createdAtMs);instant(spawn.expiresAtMs)
                if spawn.kind~=nil then
                 assert(spawn.kind=='GROUND_GIFT','INVALID_GIFT_KIND');instant(spawn.landedAtMs)
                 assert(spawn.landedAtMs==spawn.createdAtMs+2500 and spawn.expiresAtMs==spawn.landedAtMs+15000,'INVALID_GIFT_WINDOW')
                 assert(type(spawn.position)=='table','INVALID_GIFT_POSITION')
                 assert(type(spawn.fixedReward)=='table' and (spawn.fixedReward.type=='GE' or spawn.fixedReward.type=='Cash'),'INVALID_GIFT_REWARD')
                 local amount=spawn.fixedReward.amount;assert(type(amount)=='string','INVALID_GIFT_REWARD')
                 if spawn.fixedReward.type=='GE' then uint(amount) else A.decode(amount) end
                 for _,k in {'x','y','z'} do local n=spawn.position[k];assert(type(n)=='number' and n==n and math.abs(n)<=1000,'INVALID_GIFT_POSITION') end
                end
				assert(spawn.expiresAtMs>=spawn.createdAtMs and type(spawn.claimed)=="boolean" and type(spawn.isElite)=="boolean" and type(spawn.terms)=="table","INVALID_DRONE_RECORD")
			end
		end
		if p.rewards.offers~=nil then
			assert(type(p.rewards.offers)=="table","INVALID_OFFER_REGISTRY")
			for _,channel in {"ordinary","bonus"} do
				assert(type(p.rewards.offers[channel])=="table","INVALID_OFFER_CHANNEL")
				for id,offer in p.rewards.offers[channel] do
					assert(type(id)=="string" and type(offer)=="table" and offer.offerId==id and offer.ownerId==playerId and offer.channel==channel,"INVALID_OFFER_OWNER")
					instant(offer.createdAtMs)
					assert(offer.status=="PENDING" or offer.status=="RESERVED" or offer.status=="CLAIMED" or offer.status=="DISMISSED","INVALID_OFFER_STATUS")
					assert(type(offer.reward)=="table" and type(offer.reward.amount)=="string","INVALID_OFFER_REWARD")
					if offer.costGE~=nil then assert(type(offer.costGE)=="number" and offer.costGE>0 and offer.costGE<=9007199254740991 and offer.costGE%1==0,"INVALID_OFFER_COST") end
				end
			end
		end
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
			farm={eggIndex=0,maxEggReached=0,cash="0",habitats=habitats,vehicles={{typeIndex=0}},fleetLimit=4,siloOwned=1,common={},hatcheryStock="250",runningCount="0",hatchGroupSequence="0",groups={}},
			accounting={prestigeSessionArchivedCash="0",prestigeExtraEarnings="0",lastBaseEarnings="0",currentFarmCash="0",lastCashEarned="0"},
			permanent={GE="10",shellScripts="0",totalGESpent="0",SE="0",PE="0",epic={},hyperloop=false,prestigeCount="0"},
			inventory={boosts={},pets={},equipped={},guarantees={}}, effects={boosts={}},
			timeline={settledWallThrough=nowMs},rewards={},piggy={},entitlements={},operations={},
		}
	end
	return table.freeze({ validate=validate, createReference=createReference })
end
return table.freeze(Schema)
