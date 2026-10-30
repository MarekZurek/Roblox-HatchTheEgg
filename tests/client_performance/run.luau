-- Regressions for event-driven HUD, immutable presentation views and timed intents.
local C = require('../../src/shared/NumericCodec')
local Server = require('../../src/server/Bootstrap')
local Client = require('../../src/client/Bootstrap')
local Schema = require('../../src/server/ProfileSchema').new(C)
local assertions = 0
local function eq(a,b,label)
	assertions += 1
	assert(a == b, label .. ': expected ' .. tostring(b) .. ', got ' .. tostring(a))
end
local now, elapsed = 1000000, 0
local server = Server.new({clock={utcNowMs=function() return now end, elapsedNowSeconds=function() return elapsed end}})
local profile = Schema.createReference('1', now)
profile.farm.cash = '1000'
profile.accounting.currentFarmCash = '1000'
profile.accounting.lastBaseEarnings = '1000'
eq(server:playerJoined('1',profile).status,'JOINED','session joined')
local sent, client = {}, nil
client = Client.new({playerId='1',wire=function(message)
	table.insert(sent,message)
	local reply = server:dispatch('1',message)
	if reply then client:receive(reply) end
end})
local hud, store = client:getHUD(), client:getStore()
local updates, originalUpdate = 0, hud.update
hud.update = function(self) updates += 1; return originalUpdate(self) end
client:connect('perf-boot')
eq(updates,1,'one HUD repaint per snapshot, without duplicate bootstrap subscription')
local view = store:getPresentationFarm()
eq(view,store:getPresentationFarm(),'presentation reads reuse a view')
eq(table.isfrozen(view),true,'view frozen')
eq(table.isfrozen(view.habitats[1]),true,'nested view frozen')
eq(pcall(function() view.habitats[1].population='999' end),false,'mutation rejected')
local copy = store:getFarm()
copy.habitats[1].population='999'
eq(store:getFarm().habitats[1].population,'0','mutable copy remains isolated')
updates=0
for frame=1,120 do client:update(now+frame) end
eq(updates,0,'idle frames do not repaint HUD')
eq(store:getPresentationFarm(),view,'idle frames retain cached view')
client.transport:sendRefreshState('perf-refresh')
eq(updates,1,'snapshot immediately repaints HUD')
eq(store:getPresentationFarm()==view,false,'snapshot replaces cached view')

local function count(kind, phase)
	local n=0
	for _,message in sent do if message.kind==kind and (phase==nil or message.phase==phase) then n+=1 end end
	return n
end
hud:toggleResearchModal(true)
local beforeQuotes=count('QuoteRequest')
updates=0
-- Let quotes expire while the farm view itself remains unchanged.
for _=1,120 do
	now+=500; elapsed+=0.5
	server:tick(0.5)
end
hud._lastTierQuoteReqTime=nil
client:update(now)
eq(count('QuoteRequest')>beforeQuotes,true,'expired visible-tier quotes renewed without a state change')
eq(updates,0,'quote maintenance does not repaint full HUD')
local result
client:buyResearch('egg_diet',function(r) result=r end)
eq(result.status,'APPLIED','research purchase succeeds after timed renewal')
client:receive(server:createPlayerDelta('1'))
eq(store:getFarm().common[1].level,1,'research level projected')
eq(server:getCoordinator('1').snapshots().durable.farm.common.egg_diet,1,'research durable')
hud:toggleResearchModal(false)
updates=0
local hatchResult
client:hatchPress(function(r) hatchResult=r end)
eq(hatchResult.status,'ACCEPTED','manual hatch accepted')
eq(server:getCoordinator('1').snapshots().working.farm.runningCount,'1','hatch reaches authoritative simulation')
client:receive(server:createPlayerDelta('1'))
eq(updates,1,'hatch delta repaints once')
local afterHatch=store:getPresentationFarm()
eq(afterHatch==view,false,'delta replaces cached view')
eq(view.hatchery.stock,'250','retained old snapshot is stable')

client:hatchHoldStart()
local function refreshCount()
	local n=0
	for _,m in sent do if m.kind=='HatchInput' and m.state=='refresh' then n+=1 end end
	return n
end
local beforeRefresh=refreshCount()
now+=600; elapsed+=0.6
client:update(now)
eq(refreshCount(),beforeRefresh+1,'hold lease renewed from frame tick')
client:hatchHoldStop()
now+=600; elapsed+=0.6
client:update(now)
eq(refreshCount(),beforeRefresh+1,'stopped hold does not renew')
client:destroy()
server:close()
print(string.format('Client performance regressions PASS: %d assertions',assertions))
