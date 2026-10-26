-- Transaction regressions: simulated income and a purchase share one commit.
local B=require('../../src/server/Bootstrap')
local C=require('../../src/shared/NumericCodec')
local D=require('../../src/server/PersistenceData')
local S=require('../../src/server/ProfileSchema').new(C)
local fs,serde=require('@lune/fs'),require('@lune/serde')
local count=0
local function eq(a,b,label) count+=1;assert(a==b,(label or '')..' expected '..tostring(b)..' got '..tostring(a)) end
local function near(a,b,label) count+=1;assert(math.abs(a-b)<=math.max(1,math.abs(b))*2e-12,(label or '')..' expected '..tostring(b)..' got '..tostring(a)) end
local ORIGIN=1000000
local function harness(mutate)
	local h={now=ORIGIN,records={},writes=0}
	h.clock={utcNowMs=function()return h.now end,elapsedNowSeconds=function()return (h.now-ORIGIN)/1000 end}
	h.store={read=function(k)return true,h.records[k] and D.copy(h.records[k])end,update=function(k,cb)
		h.writes+=1
		if h.beforeWrite then local hook=h.beforeWrite;h.beforeWrite=nil;hook() end
		if h.failBefore then h.failBefore=false;return false,'write not reached' end
		if h.defer then
			h.defer=false;h.late=function()local p=cb(D.copy(h.records[k]));if p then h.records[k]=D.copy(p) end end
			return false,'write still in flight'
		end
		local input=h.records[k] and D.copy(h.records[k])
		if h.retryCallback then h.retryCallback=false;cb(input and D.copy(input)) end
		local p=cb(h.records[k] and D.copy(h.records[k]));if p then h.records[k]=D.copy(p) end
		if h.retryAfterCommit then h.retryAfterCommit=false;p=cb(D.copy(h.records[k])) end
		if h.loseAck then h.loseAck=false;return false,'ack lost after commit' end
		return true,p and D.copy(p)
	end}
	function h.restart()h.b=B.new({store=h.store,clock=h.clock}) end
	h.restart()
	local p=S.createReference('1',ORIGIN);p.farm.habitats[1].population='18'
	if mutate then mutate(p) end
	eq(h.b:playerJoined('1',p).status,'JOINED','fixture joined')
	h.b:dispatch('1',{protocolVersion=1,kind='Bootstrap',requestId='boot'})
	function h.state()return h.b:getCoordinator('1').snapshots()end
	function h.step(seconds)
		for _=1,seconds*2 do h.now+=500;h.b:tick(.5) end
		eq(h.state().ready,true,'simulation ready')
	end
	function h.quote(kind,args)
		return h.b:dispatch('1',{protocolVersion=1,kind='QuoteRequest',requestId='q',target={kind=kind,args=args}})
	end
	function h.packet(q,id)
		local args=D.copy(q.target.args);args.quoteId=q.quoteId
		return {protocolVersion=1,kind=q.target.kind,requestId='request-'..id,operationId=id,expectedRevision=q.expectedRevision,args=args}
	end
	function h.send(packet)return h.b:dispatch('1',packet)end
	function h.cash()return C.BigAmount.decode(h.records['player:1'].farm.cash)end
	function h.settle()
		for _=1,1000 do h.b:tick(0);if h.state().ready then return end end
		error('settlement never completed')
	end
	return h
end
local research={researchId='comfy_nests',mode='single'}
do
	local h=harness();h.step(20)
	near(C.BigAmount.decode(h.state().working.farm.cash),3,'18 hens earn $3 in 20s')
	eq(h.cash(),0,'income is not checkpointed')
	local q=h.quote('BuyResearch',research);eq(q.available,true,'quote sees new earnings')
	local packet=h.packet(q,'spend-earned')
	local result=h.send(packet)
	eq(result.status,'APPLIED','spend new earnings without a checkpoint')
	near(h.cash(),3-0.50260546768497227,'one income credit minus one research cost')
	eq(h.records['player:1'].farm.common.comfy_nests,1,'research granted once')
	near(C.BigAmount.decode(h.records['player:1'].accounting.currentFarmCash),3,'spending does not reduce earned accumulator')
	local saved=D.fingerprint(h.records['player:1']);local writes=h.writes
	packet.expectedRevision='999';packet.requestId='retry-new-request'
	eq(h.send(packet).status,'REPLAYED','old revision returns saved result')
	eq(h.writes,writes,'replay does not write')
	eq(D.fingerprint(h.records['player:1']),saved,'replay does not debit or credit again')
	h.step(10)
	near(C.BigAmount.decode(h.state().working.farm.cash),3-0.50260546768497227+1.65,'only next 10s accrue at upgraded rate')
	local _,cp=h.b:checkpointPlayer('1');eq(cp.status,'APPLIED','later checkpoint succeeds')
	near(h.cash(),3-0.50260546768497227+1.65,'checkpoint cannot replay old income')
	near(C.BigAmount.decode(h.records['player:1'].accounting.currentFarmCash),4.65,'earned accumulator conserved')
end

local DOMAIN={'farm','accounting','permanent','inventory','effects','timeline','rewards','piggy','entitlements'}
local function sameDomain(actual,expected,label)
	for _,section in DOMAIN do eq(D.fingerprint(actual[section]),D.fingerprint(expected[section]),label..' '..section) end
end
-- Income accrued between the last tick and the command also shares the commit.
do
	local h=harness();h.step(4)
	local q=h.quote('BuyResearch',research);eq(q.available,true)
	h.now+=500
	eq(h.send(h.packet(q,'between-ticks')).status,'APPLIED')
	near(h.cash(),.675-C.BigAmount.decode(q.cashCost),'4.5 seconds credited once')
	near(C.BigAmount.decode(h.records['player:1'].accounting.currentFarmCash),.675)
	eq(h.records['player:1'].timeline.settledWallThrough,ORIGIN+4500)
	h.settle()
	near(C.BigAmount.decode(h.state().working.farm.cash),h.cash(),'same instant cannot produce twice')
end
-- All three cash purchase paths use fresh production, including provisional timers.
for _,spec in {
	{kind='BuyResearch',args=research},
	{kind='BuyHabitat',args={slotId=1,habitatId='SHACK'}},
	{kind='BuyVehicle',args={slotId=2,vehicleId='TRIKE'}},
} do
	local h=harness(function(p)
		-- Test-only production magnitude, not a balance change.
		p.permanent.SE='1000000'
		p.effects.boosts={{id='jimbos_blue_v2',remainingSeconds='10'}}
	end)
	h.step(20)
	local before=h.state().working;eq(h.cash(),0,'nothing checkpointed before '..spec.kind)
	local q=h.quote(spec.kind,spec.args);eq(q.available,true,'fresh income funds '..spec.kind)
	local price=C.BigAmount.decode(q.cashCost);local income=C.BigAmount.decode(before.farm.cash)
	local writes=h.writes;local packet=h.packet(q,'fresh-'..spec.kind)
	eq(h.send(packet).status,'APPLIED',spec.kind..' applied')
	eq(h.writes,writes+1,'single atomic write, no preparatory checkpoint')
	local saved=h.records['player:1']
	near(h.cash(),income-price,'fresh cash debited once')
	near(C.BigAmount.decode(saved.accounting.currentFarmCash),C.BigAmount.decode(before.accounting.currentFarmCash),'earned amount preserved')
	if spec.kind=='BuyResearch' then eq(saved.farm.common.comfy_nests,1,'one research level')
	elseif spec.kind=='BuyHabitat' then eq(saved.farm.habitats[1].typeIndex,1,'one habitat upgrade')
	else eq(saved.farm.vehicles[2].typeIndex,0,'one vehicle') end
	for _,section in {'timeline','effects','inventory','permanent','entitlements','rewards','piggy'} do
		eq(D.fingerprint(saved[section]),D.fingerprint(before[section]),'pending section saved once: '..section)
	end
	local original=D.copy(saved)
	for _=1,3 do eq(h.send(packet).status,'REPLAYED','duplicate command result') end
	sameDomain(h.records['player:1'],original,'duplicate preserves domain')
	local _,cp=h.b:checkpointPlayer('1');eq(cp.status,'APPLIED')
	sameDomain(h.records['player:1'],original,'checkpoint preserves domain')
	eq(h.b:playerLeaving('1'),true,'disconnect')
	eq(h.b:playerJoined('1').status,'JOINED','reconnect')
	sameDomain(h.state().working,original,'reconnect preserves committed progress')
end

-- Two consecutive purchases cannot spend the same income twice.
do
	local h=harness();h.step(20)
	local q1=h.quote('BuyResearch',research);local p1=h.packet(q1,'first')
	eq(h.send(p1).status,'APPLIED')
	local q2=h.quote('BuyResearch',{researchId='nutritional_sup',mode='single'})
	eq(q2.available,true);local p2=h.packet(q2,'second');eq(h.send(p2).status,'APPLIED')
	local remaining=3-C.BigAmount.decode(q1.cashCost)-C.BigAmount.decode(q2.cashCost)
	near(h.cash(),remaining,'sequential debits conserve total income')
	near(C.BigAmount.decode(h.records['player:1'].accounting.currentFarmCash),3)
	local saved=D.copy(h.records['player:1'])
	local stale=D.copy(p1);stale.operationId='stale-new-id';stale.requestId='stale-request'
	eq(h.send(stale).result.errorCode,'STALE_REVISION','new intent cannot reuse old revision')
	sameDomain(h.records['player:1'],saved,'stale quote cannot mutate domain')
	eq(h.send(p1).status,'REPLAYED');eq(h.send(p2).status,'REPLAYED')
	near(h.cash(),remaining,'duplicates cannot double debit')
end

-- A real affordability rejection retains uncheckpointed income and timeline.
do
	local h=harness();h.step(1)
	local before=h.state().working
	local q=h.quote('BuyResearch',research);eq(q.available,false)
	local packet=h.packet(q,'insufficient');local result=h.send(packet)
	eq(result.status,'REJECTED');eq(result.result.errorCode,'INSUFFICIENT_CASH')
	sameDomain(h.state().working,before,'rejection preserves provisional progress')
	eq(h.cash(),0,'rejection does not partially credit income')
	eq(h.records['player:1'].farm.common.comfy_nests,nil,'no grant on rejection')
	local _,cp=h.b:checkpointPlayer('1');eq(cp.status,'APPLIED')
	sameDomain(h.records['player:1'],before,'checkpoint saves rejected purchase progress')
	h.step(19)
	local fresh=h.quote('BuyResearch',research);eq(fresh.available,true)
	eq(h.send(h.packet(fresh,'new-decision')).status,'APPLIED')
	near(h.cash(),3-C.BigAmount.decode(fresh.cashCost),'new decision spends once')
	eq(h.send(packet).status,'REPLAYED','old rejection cannot turn into a charge')
	near(h.cash(),3-C.BigAmount.decode(fresh.cashCost))
end

-- UpdateAsync-style callback repeats rebase from the durable input each time.
for _,fault in {'retryCallback','retryAfterCommit'} do
	local h=harness();h.step(20)
	local q=h.quote('BuyResearch',research);local packet=h.packet(q,fault)
	h[fault]=true
	local result=h.send(packet)
	eq(result.status,if fault=='retryAfterCommit' then 'REPLAYED' else 'APPLIED',fault)
	near(h.cash(),3-C.BigAmount.decode(q.cashCost),'retry has one credit and debit')
	near(C.BigAmount.decode(h.records['player:1'].accounting.currentFarmCash),3)
	eq(h.records['player:1'].farm.common.comfy_nests,1)
	eq(h.state().durable.farm.cash,h.records['player:1'].farm.cash,'actor adopts confirmed callback result')
end

-- Lost acknowledgements: freeze, query and fenced restart; never reapply a grant.
do
	local h=harness();h.step(20)
	local q=h.quote('BuyResearch',research);local packet=h.packet(q,'lost-ack')
	h.loseAck=true;eq(h.send(packet).status,'UNKNOWN')
	local saved=D.copy(h.records['player:1']);near(h.cash(),3-C.BigAmount.decode(q.cashCost))
	eq(h.state().working,nil,'unconfirmed state is hidden')
	local actor=h.b:getCoordinator('1')
	eq(actor.query('lost-ack').status,'REPLAYED','query finds committed result')
	local new=D.copy(packet);new.operationId='unresolved-new-id'
	eq(h.send(new).admission,'NOT_ACCEPTED','no new effects before recovery')
	h.now+=120000
	h.restart();eq(h.b:playerJoined('1').status,'JOINED','restart fences old owner')
	eq(h.send(packet).status,'REPLAYED','same ID after restart returns saved result')
	sameDomain(h.records['player:1'],saved,'restart/replay cannot recredit income')
	eq(actor.checkpoint({operationId='old-owner-save',kind='Checkpoint',expectedRevision='1',args={}}).status,'NOT_ACCEPTED')
	-- Old actor remains blocked; an expired owner cannot flush stale work.
	eq(actor.snapshots().working,nil)
	sameDomain(h.records['player:1'],saved,'old owner cannot overwrite new session')
end

-- No write / delayed write: fence the old callback, replay the time from the saved
-- boundary, then make an explicit new purchase. Pro fixture keeps offline quality 1.
for _,fault in {'failBefore','defer'} do
	local h=harness(function(p)p.entitlements.pro_permit=true end);h.step(20)
	local q=h.quote('BuyResearch',research);local packet=h.packet(q,'unconfirmed-'..fault)
	h[fault]=true;eq(h.send(packet).status,'UNKNOWN')
	eq(h.cash(),0);eq(h.records['player:1'].timeline.settledWallThrough,ORIGIN)
	eq(h.records['player:1'].operations[packet.operationId],nil,'no fabricated terminal result')
	local actor=h.b:getCoordinator('1');eq(actor.query(packet.operationId).status,'UNKNOWN')
	h.now+=120000
	local recovery=actor.recover(packet.operationId);eq(recovery.status,'ACQUIRED')
	eq(actor.resultOf(packet.operationId).status,'NOT_APPLIED','fence resolves missing write')
	if h.late then h.late() end
	eq(h.cash(),0,'late callback cannot write after fence')
	eq(h.records['player:1'].farm.common.comfy_nests,nil,'no late grant')
	h.settle()
	near(C.BigAmount.decode(h.state().working.farm.cash),21,'140s recomputed once from saved boundary')
	local fresh=h.quote('BuyResearch',research)
	eq(h.send(h.packet(fresh,'explicit-new-'..fault)).status,'APPLIED')
	near(h.cash(),21-C.BigAmount.decode(fresh.cashCost),'recovery saves time and charge once')
	near(C.BigAmount.decode(h.records['player:1'].accounting.currentFarmCash),21)
	eq(h.records['player:1'].timeline.settledWallThrough,h.now,'saved simulation cursor advances once')
end

-- Rebase refuses to overwrite a changed durable source even with an unchanged
-- revision, and blocks later checkpoints until recovery rather than losing data.
do
	local h=harness();h.step(20)
	local q=h.quote('BuyResearch',research)
	h.beforeWrite=function()h.records['player:1'].farm.cash='9' end
	local result=h.send(h.packet(q,'base-changed'))
	eq(result.status,'REJECTED');eq(result.result.errorCode,'SIMULATION_BASE_CHANGED')
	eq(h.cash(),9,'new durable cash cannot be overwritten by old simulation')
	eq(h.records['player:1'].farm.common.comfy_nests,nil)
	eq(h.state().working,nil,'divergent provisional state hidden')
	local writes=h.writes
	h.b:checkpointPlayer('1')
	eq(h.writes,writes,'stale provisional work cannot be checkpointed')
	eq(h.cash(),9)
end
fs.writeFile('build/fresh_cash_purchases-results.json',serde.encode('json',{status='PASS',assertions=count,level='L',studioTested=false,dataStoreTested=false}))
print('Fresh cash purchases PASS: '..count..' assertions')
