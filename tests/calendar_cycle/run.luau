-- Full calendar journeys through the real server, protocol, transport and storage.
-- Expectations: independent Python oracle + simplified documented FV arithmetic.
local Server=require('../../src/server/Bootstrap')
local Transport=require('../../src/client/ClientTransport')
local State=require('../../src/client/ClientStateStore')
local C=require('../../src/shared/NumericCodec')
local Protocol=require('../../src/shared/ProtocolSchemas').new(C)
local D=require('../../src/server/PersistenceData')
local Schema=require('../../src/server/ProfileSchema').new(C)
local fs,serde=require('@lune/fs'),require('@lune/serde')
local oracle=serde.decode('json',fs.readFile('tests/calendar_cycle/oracle.json'))
local research=serde.decode('json',fs.readFile('docs/reference_data/research.json')).epic
local assertions,claims=0,0
local function eq(a,b,label)assertions+=1;assert(a==b,(label or '')..' expected '..tostring(b)..' got '..tostring(a))end
local function near(a,b,label)assertions+=1;assert(math.abs(a-b)<=math.max(1,math.abs(b))*1e-12,(label or '')..': '..tostring(a)..' != '..tostring(b))end
local epic={};for _,row in research do epic[row.id]=row end
local function assets(p)return D.fingerprint({p.farm.cash,p.permanent,p.accounting,p.inventory,p.rewards,p.piggy})end
local function create(mutate,options)
 options=options or {};local h={now=1000000,elapsed=0,records={},serial=0,fail=false,lose=false,retry=false}
 local clock={utcNowMs=function()return h.now end,elapsedNowSeconds=function()return h.elapsed end}
 local storage={read=function(k)return true,h.records[k] and D.copy(h.records[k])end,update=function(k,cb)
  local old=h.records[k] and D.copy(h.records[k]);local out=cb(old)
  if h.retry then h.retry=false;out=cb(old and D.copy(old))end
  if h.fail then h.fail=false;return false,'storage unavailable' end
  if out then h.records[k]=D.copy(out)end
  if h.lose then h.lose=false;return false,'lost ACK' end
  return true,out and D.copy(out)
 end}
 h.b=Server.new({clock=clock,store=storage})
 local p=Schema.createReference('1',h.now)
 -- A zero offline window isolates the calendar in multi-day journeys. It is a
 -- boundary fixture, not a change to the one-silo production baseline or balance.
 p.farm.siloOwned=0
 if mutate then mutate(p)end
 eq(h.b:playerJoined('1',p).status,'JOINED')
 h.transport=Transport.new({protocol=Protocol,wire=function(message)
  local response=h.b:dispatch('1',message)
  eq(h.transport:receive(response),true,'actual response passes wire schema')
 end})
 h.state=State.new({transport=h.transport,codec=C})
 h.transport:sendBootstrap()
 function h.profile()return h.b:getCoordinator('1').snapshots().durable end
 function h.refresh()h.transport:sendRefreshState()end
 function h.command(kind,args)
  h.serial+=1;local response
  local packet=h.transport:sendPurchase(kind,'request-'..h.serial,'claim-'..h.serial,h.state:getCommitRevision(),args,function(r)response=r end)
  h.refresh();return response,packet
 end
 function h.claim()return h.command('ClaimDailyGift',{})end
 function h.nextDay(days)
  h.b:playerLeaving('1')
  h.now+=(days or 1)*86400000;h.elapsed+=(days or 1)*86400
  eq(h.b:playerJoined('1').status,'JOINED','persisted account reacquires after offline')
  h.transport:sendBootstrap()
 end
 return h
end

-- Fixed independent FV for an empty Edible farm with one 250-capacity henhouse:
-- 50*K*L*eggValue*(P+F), K=1200, L=1/30, P=0, F=250^.6.
local function expectedFV(se,pe,soulFood,epicMultiplier)
 -- Calendar day 11 grants Epic Multiplier: its cap is +2 per level, so
 -- the documented FV factor is (1 + 2*level)^0.25 on this empty farm.
 return 50*1200*(1+se*(.1+.01*soulFood)*1.05^pe)*(1/30)*.50*250^.6*(1+2*(epicMultiplier or 0))^.25
end

-- Exact uint64, including above 2^53, persists through prestige and old profiles.
do
 local h=create(function(p)p.rewards.numDailyGiftsCollected=9;p.permanent.shellScripts='9007199254740993'end)
 eq(h.claim().status,'APPLIED');eq(h.profile().permanent.shellScripts,'9007199254740998')
 h.nextDay();eq(h.profile().permanent.shellScripts,'9007199254740998')
 local p=h.profile();local valid=Schema.validate(p,'1');eq(valid,true)
 p.permanent.shellScripts='01';eq(pcall(Schema.validate,p,'1'),false,'noncanonical currency is not accepted')
 local old=create(function(p)p.rewards.numDailyGiftsCollected=17;p.permanent.shellScripts=nil end)
 eq(old.state:getFarm().progress.shellScripts,'0');eq(old.claim().status,'APPLIED');eq(old.profile().permanent.shellScripts,'10')
end

for _,case in oracle.cases do
 local m=case.cycle
 local h=create(function(p)p.rewards.numDailyGiftsCollected=m*28;p.permanent.PE=tostring(math.min(24,m))end)
 local expected={GE=10,SE=0,PE=math.min(24,m),cash=0,piggy=0,level=0,shells=0,epic={},boosts={}}
 for _,row in case.rewards do
  local day=row.day
  local fv=expectedFV(expected.SE,expected.PE,expected.epic.soul_eggs or 0,expected.epic.epic_multiplier or 0)
  local amount=if row.kind=='Cash' then row.amount/100*fv else row.amount
  local preview=h.state:getFarm().progress.calendar[day]
  eq(preview.available,true,'every calendar day has an available preview')
  eq(preview.rewardType,row.kind);near(C.BigAmount.decode(preview.amount),amount,'base preview uses same current farm, independent oracle')
  if row.kind=='GE' then expected.GE+=row.amount
  elseif row.kind=='SE' then expected.SE+=row.amount
  elseif row.kind=='PE' then expected.PE+=row.amount
  elseif row.kind=='Cash' then expected.cash+=amount
  elseif row.kind=='ShellScripts' then expected.shells+=row.amount
  elseif row.kind=='Piggy' then expected.piggy+=row.amount
  elseif row.kind=='PiggyLevel' then expected.level+=row.amount
  elseif row.kind=='Boost' then expected.boosts[row.subtype]=(expected.boosts[row.subtype] or 0)+row.amount
  elseif row.kind=='Epic' then
   local old=expected.epic[row.subtype] or 0;local max=epic[row.subtype].maxLevel
   local granted=math.min(row.amount,max-old)
   expected.epic[row.subtype]=old+granted
   expected.GE+=(row.amount-granted)*epic[row.subtype].prices[max]
  end
  if day%2==0 then h.retry=true end
  local result,packet=h.claim();claims+=1
  eq(result.status,'APPLIED','full cycle '..m..', day '..day)
  eq(result.result.rewardType,row.kind);near(C.BigAmount.decode(result.result.amount),amount,'actual grant amount')
  local p=h.profile()
  eq(p.rewards.numDailyGiftsCollected,m*28+day);eq(p.rewards.lastCalendarDayUtc,math.floor(h.now/86400000))
  eq(p.permanent.GE,tostring(expected.GE));near(C.BigAmount.decode(p.permanent.SE),expected.SE);eq(p.permanent.PE,tostring(expected.PE))
  eq(p.permanent.shellScripts,tostring(expected.shells));eq(p.piggy.rawAmount or '0',tostring(expected.piggy));eq(p.piggy.level or '0',tostring(expected.level))
  near(C.BigAmount.decode(p.farm.cash),expected.cash)
  near(C.BigAmount.decode(p.accounting.currentFarmCash),expected.cash,'calendar cash stays in prestige base')
  near(C.BigAmount.decode(p.accounting.lastCashEarned),expected.cash)
  eq(p.permanent.totalGESpent,'0','free calendar never debits GE')
  for id,value in expected.epic do eq(p.permanent.epic[id],value)end
  for id,value in expected.boosts do eq(p.inventory.boosts[id],tostring(value))end
  eq(h.state:getFarm().progress.shellScripts,p.permanent.shellScripts,'private view counter')
  local before=assets(p)
  local replay=h.b:dispatch('1',packet);eq(replay.status,'REPLAYED');eq(assets(h.profile()),before,'same operation does not grant twice')
  local duplicate=h.claim();eq(duplicate.status,'REJECTED');eq(duplicate.result.errorCode,'ALREADY_CLAIMED_TODAY');eq(assets(h.profile()),before,'new operation cannot claim the same day')
  h.nextDay()
 end
 -- Position 29 is the next cycle's first gift, never a stuck/extra day.
 local next=h.claim();eq(next.status,'APPLIED');eq(next.result.day,1);eq(next.result.cycle,m+1)
 h.b:playerLeaving('1')
end

-- Missed days grant exactly one next gift, not catch-up for each absent day.
do
 local h=create();eq(h.claim().status,'APPLIED');h.nextDay(5)
 local r=h.claim();eq(r.status,'APPLIED');eq(r.result.day,2);eq(h.profile().rewards.numDailyGiftsCollected,2)
end
-- Cash is calculated at claim, without direct pet/earnings/VD/event reward scaling.
do
 local h=create(function(p)
  p.rewards.numDailyGiftsCollected=3
  p.effects.boosts={{id='jimbos_blue_v2',remainingSeconds='100'},{id='soul_beacon_blue_v2',remainingSeconds='100'}}
  p.effects.videoDoublerEndsAtMs=2000000
  p.inventory.pets.bonus={uid='bonus',speciesId='fixture',tier=1,variant='normal',locked=false,customBonus={eggValueMult=9,prestigeEarningsMult=1}}
  p.inventory.equipped={'bonus'}
 end)
 local amount=.5*expectedFV(0,0,0)
 local r=h.claim();eq(r.status,'APPLIED');near(C.BigAmount.decode(h.profile().farm.cash),amount)
 -- Soul Beacon blue is x5 and Phoenix fixture x2: extra earnings = amount*(10-1).
 near(C.BigAmount.decode(h.profile().accounting.prestigeExtraEarnings),amount*9)
 local saved=C.BigAmount.decode(h.profile().accounting.currentFarmCash)
 local extra=C.BigAmount.decode(h.profile().accounting.prestigeExtraEarnings)
 h.now+=300;h.elapsed+=.3;h.b:tick(.3)
 local working=h.b:getCoordinator('1').snapshots().working
 near(C.BigAmount.decode(working.accounting.currentFarmCash),saved,'no population means no EPS income')
 near(C.BigAmount.decode(working.accounting.prestigeExtraEarnings),extra,'cash prestige bonus is not counted twice')
end

-- An egg change after the preview must use the new home FV at claim time.
do
 local h=create(function(p)p.rewards.numDailyGiftsCollected=3;p.permanent.SE='1000000000'end)
 local old=C.BigAmount.decode(h.state:getFarm().progress.calendar[4].amount)
 eq(h.command('UpgradeEgg',{targetEggIndex=1}).status,'APPLIED')
 local amount=.5*(50*1800*(1+1000000000*.1)*(1/30)*1.25*250^.6)
 local r=h.claim();eq(r.status,'APPLIED');near(C.BigAmount.decode(r.result.amount),amount)
 near(C.BigAmount.decode(h.profile().farm.cash),amount);eq(amount>old,true)
end
-- Spending the cash reward cannot lower the earned prestige base.
do
 local h=create(function(p)p.rewards.numDailyGiftsCollected=14 end)
 local amount=.75*expectedFV(0,0,0)
 eq(h.claim().status,'APPLIED')
 local quote
 h.transport:sendQuoteRequest('cash-research-quote',{kind='BuyResearch',args={researchId='comfy_nests',mode='single'}},function(r)quote=r end)
 eq(quote.available,true)
 eq(h.command('BuyResearch',{researchId='comfy_nests',mode='single',quoteId=quote.quoteId}).status,'APPLIED')
 eq(C.BigAmount.decode(h.profile().farm.cash)<amount,true)
 near(C.BigAmount.decode(h.profile().accounting.currentFarmCash),amount)
 local r=h.command('Prestige',{});eq(r.status,'APPLIED');near(C.BigAmount.decode(h.profile().permanent.SE),amount^.15)
end
-- Every formerly blocked reward remains one operation on timeout and overflow.
for _,day in {4,10,15,18,22} do
 local h=create(function(p)p.rewards.numDailyGiftsCollected=day-1 end)
 local before=assets(h.profile());h.fail=true
 local r=h.claim();eq(r.status,'UNKNOWN');eq(assets(h.profile()),before,'failed write has no half-grant or consumed calendar day')
end
do
 local h=create(function(p)p.rewards.numDailyGiftsCollected=9;p.permanent.shellScripts='18446744073709551615'end)
 local before=assets(h.profile());local r=h.claim()
 eq(r.status=='APPLIED' or r.status=='REPLAYED',false,'uint64 overflow cannot grant or wrap')
 eq(assets(h.profile()),before)
end

fs.writeFile('build/calendar-cycle-results.json',serde.encode('json',{status='PASS_L',assertions=assertions,completeCycles=#oracle.cases,daysPerCycle=28,claims=claims,studioTested=false,realDataStoreTested=false}))
print('Full calendar cycles: '..assertions..' assertions PASS ('..#oracle.cases..' x 28 days)')
