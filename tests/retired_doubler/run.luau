--!strict
-- Product decision 2026-10-28: old saved timers/research are readable but inert.
local B = require('../../src/server/Bootstrap')
local C = require('../../src/shared/NumericCodec')
local S = require('../../src/server/ProfileSchema').new(C)
local serde = require('@lune/serde')
local fs = require('@lune/fs')
local Catalog = require('../../src/server/CatalogRegistry').new(C,require('../../src/server/CatalogRegistry/Data'),{mode='INTERNAL_TEST_ONLY'})
local count = 0
local function eq(a: any, b: any, label: string)
 count += 1
 assert(a == b, label .. ': ' .. tostring(a) .. ' != ' .. tostring(b))
end
local function near(a: number, b: number, label: string)
 count += 1
 assert(math.abs(a-b) < 1e-10, label)
end
for _, legacy in {false, true} do
 local server = B.new({initialNowMs=10000000})
 local p = S.createReference('1', 10000000)
 p.farm.habitats[1].population='30'
 p.farm.eggIndex=1 -- fixed $1.25 fixture, independent of unrelated first-egg balance edits
 p.permanent.GE='100000'
 p.permanent.totalGESpent='123'
 p.entitlements.double_cash=true -- distinct pass must survive unchanged
 if legacy then
  p.effects.videoDoublerEndsAtMs=90000000
  p.effects.videoDoubler={endsAtMs=90000000}
  p.permanent.epic.video_doubler_time=12
 end
 p=serde.decode('json',serde.encode('json',p))
 eq(S.validate(p,'1'),true,'legacy schema accepted')
 eq(server:playerJoined('1',p).status,'JOINED','old/new profile loads')
 local packet={protocolVersion=1,kind='BuyEpicResearch',requestId='retired-1',operationId='retired-buy',expectedRevision='0',args={researchId='video_doubler_time'}}
 local response=server:dispatch('1',packet)
 assert(response.status ~= 'APPLIED' and response.status ~= 'REPLAYED','retired purchase cannot succeed'); count+=1
 local response2=server:dispatch('1',packet)
 assert(response2.status ~= 'APPLIED', 'retry cannot buy retired research'); count+=1
 local durable=server:getCoordinator('1').snapshots().durable
 eq(durable.permanent.GE,'100000','no charge')
 eq(durable.permanent.totalGESpent,'123','no spend recorded')
 eq(durable.permanent.epic.video_doubler_time,if legacy then 12 else nil,'saved research preserved')
 eq(durable.entitlements.double_cash,true,'separate pass preserved')
 server:tick(3)
 local working=server:getCoordinator('1').snapshots().working
 near(C.BigAmount.decode(working.farm.cash),3.75,'30 hens * 1/30 eggs/s * $1.25 * 3s, no timed bonus')
 near(C.BigAmount.decode(working.accounting.currentFarmCash),3.75,'ledger matches cash')
 if legacy then eq(working.effects.videoDoublerEndsAtMs,90000000,'timer retained for compatibility') end
end
local hud=fs.readFile('src/client/HUD.luau')
eq(string.find(hud,'Dłuższe Wzmocnienia',1,true),nil,'retired label absent')
eq(string.find(hud,'id = "video_doubler_time"',1,true),nil,'retired offer absent')
for _, get in {function() return Catalog.getEpic('video_doubler_time') end,function() return Catalog.epicPrice('video_doubler_time',0) end,function() return Catalog.epicEffects('video_doubler_time',12) end} do
 eq(pcall(get),false,'retired catalog access rejected')
end
print('Retired timed doubler PASS: '..count..' assertions')
