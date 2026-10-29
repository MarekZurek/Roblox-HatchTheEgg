--!nocheck
-- User R 2026-10-28: shared-price products; one unit per unique paid receipt;
-- no lost upgrades on reconnect/retry; GE prices halved with ceil/min1.
local B=require('../../src/server/Bootstrap')
local C=require('../../src/shared/NumericCodec')
local D=require('../../src/server/PersistenceData')
local S=require('../../src/server/ProfileSchema').new(C)
local P=require('../../src/shared/EpicPricing')
local Protocol=require('../../src/shared/ProtocolSchemas').new(C)
local count=0
local function eq(a,b,label) count+=1;assert(a==b,(label or '')..' expected '..tostring(b)..' got '..tostring(a)) end
local products={epic_upgrade_9={platformId=7001},epic_upgrade_19={platformId=7002},epic_upgrade_39={platformId=7003},epic_upgrade_79={platformId=7004}}
local function harness()
 local h={now=1000000,records={},serial=0}
 h.clock={utcNowMs=function()return h.now end,elapsedNowSeconds=function()return h.now/1000 end}
 h.store={read=function(k)return true,h.records[k] and D.copy(h.records[k]) end,update=function(k,cb)
  if h.failBefore then h.failBefore=false;return false,'before commit' end
  local old=h.records[k] and D.copy(h.records[k])
  if h.retry then h.retry=false;cb(old and D.copy(old)) end
  local p=cb(old);if p then h.records[k]=D.copy(p) end
  if h.loseAck then h.loseAck=false;return false,'lost acknowledgement' end
  return true,p and D.copy(p)
 end}
 function h.open(seed)
  h.b=B.new({store=h.store,clock=h.clock,platformProducts=products})
  eq(h.b:playerJoined('1',seed).status,'JOINED','session opened')
  for i=1,20 do if h.b:getCoordinator('1').snapshots().ready then break end;h.b:tick(.5) end
  h.b:dispatch('1',{protocolVersion=1,kind='Bootstrap',requestId='boot'})
 end
 local seed=S.createReference('1',h.now);seed.permanent.GE='1000';h.open(seed)
 function h.state() return h.b:getCoordinator('1').snapshots().durable end
 function h.cmd(kind,args)
  h.serial+=1
  local r=h.b:dispatch('1',{protocolVersion=1,kind=kind,args=args,requestId='r'..h.serial,operationId='op'..h.serial,expectedRevision=h.state().meta.revision})
  eq(Protocol.validateServer(r),true,'server result wire valid');return r
 end
 function h.buy(id) return h.cmd('BuyEpicRobux',{researchId=id}) end
 function h.receipt(token,id,owner)
  return h.b:applyPurchase('1',{PlayerId=owner or 1,PurchaseId=token,ProductId=id or 7001,CurrencySpent=9})
 end
 function h.reconnect(abrupt)
  if abrupt then h.now+=200000 else h.b:playerLeaving('1') end
  h.open()
 end
 return h
end

do -- Independent approved pricing vectors, including odd values and all bands.
 for _,v in {{1,1},{2,1},{10,5},{45,23},{80,40},{10000,5000}} do eq(P.ge(v[1]),v[2],'halved GE ceil') end
 for _,v in {{50,'epic_upgrade_9',9},{51,'epic_upgrade_19',19},{200,'epic_upgrade_19',19},{201,'epic_upgrade_39',39},{1000,'epic_upgrade_39',39},{1001,'epic_upgrade_79',79}} do local id,n=P.product(v[1]);eq(id,v[2],'price group');eq(n,v[3],'nominal Robux') end
end
do
 local h=harness();local a=h.buy('hold_to_hatch');eq(a.status,'APPLIED','research selection prepared');eq(a.result.platformId,7001,'shared product chosen');eq(a.result.granted,false,'selection alone grants nothing')
 eq(h.state().permanent.epic.hold_to_hatch,nil,'no optimistic level')
 eq(h.receipt('paid-1'),true,'paid receipt grants level')
 eq(h.state().permanent.epic.hold_to_hatch,1,'selected research gets exactly one level')
 eq(h.state().permanent.GE,'1000','Robux does not charge GE');eq(h.state().permanent.totalGESpent,'0','no GE spend recorded')
 eq(h.receipt('paid-1'),true,'receipt replay acknowledged');eq(h.state().permanent.epic.hold_to_hatch,1,'replay cannot grant another level')
 local operationId=a.operationId
 local replay=h.b:dispatch('1',{protocolVersion=1,kind='BuyEpicRobux',args={researchId='hold_to_hatch'},requestId='replay-request',operationId=operationId,expectedRevision='0'})
 eq(replay.status,'REPLAYED','selection operation replay returns stored outcome before revision checks')
 eq(h.state().permanent.epic.hold_to_hatch,1,'selection replay cannot grant again')
 h.reconnect();eq(h.receipt('paid-1'),true,'receipt replay after reconnect acknowledged');eq(h.state().permanent.epic.hold_to_hatch,1,'reconnect replay cannot grant another level')
 eq(h.receipt('paid-extra'),true,'unselected paid unit retained');eq(h.state().permanent.epicPurchases.credits.epic_upgrade_9,'1','one paid credit')
 local b=h.buy('epic_hatchery');eq(b.result.platformId,7001,'different research same price shares product');eq(b.result.granted,true,'existing paid unit redeemed without prompt')
 eq(h.state().permanent.epic.epic_hatchery,1,'unit gives selected research level');eq(h.state().permanent.epicPurchases.credits.epic_upgrade_9,'0','unit consumed once')
 eq(h.receipt('paid-extra'),true,'redeemed receipt replay acknowledged');eq(h.state().permanent.epic.epic_hatchery,1,'redeemed receipt cannot recreate unit')
 local view=h.b:createPlayerDelta('1');eq(Protocol.validateServer(view),true,'offer projection wire valid')
end
do
 local h=harness();h.buy('hold_to_hatch');h.reconnect();eq(h.receipt('after-disconnect'),true,'intent persists before payment');eq(h.state().permanent.epic.hold_to_hatch,1,'reconnect grants originally selected research')
end
for _,fault in {'loseAck','failBefore','retry'} do
 local h=harness();h.buy('hold_to_hatch');h[fault]=true
 h.receipt('network-'..fault)
 h.reconnect(true)
 eq(h.receipt('network-'..fault),true,'receipt recovered after '..fault)
 eq(h.state().permanent.epic.hold_to_hatch,1,'one level after '..fault)
 eq(h.state().permanent.epicPurchases.credits.epic_upgrade_9,'0','no extra unit after '..fault)
 eq(h.state().permanent.GE,'1000','no lost GE after '..fault)
end
do
 local h=harness();h.buy('hold_to_hatch');eq(h.receipt('wrong-owner',7001,2),false,'receipt must belong to player');eq(h.state().permanent.epic.hold_to_hatch,nil,'wrong owner cannot grant')
 eq(h.receipt('other-group',7004),true,'other paid price group safely retained');eq(h.state().permanent.epic.hold_to_hatch,nil,'wrong product cannot satisfy intent');eq(h.state().permanent.epicPurchases.credits.epic_upgrade_79,'1','other group not lost')
 eq(h.receipt('proper-group',7001),true,'correct price group fulfills intent');eq(h.state().permanent.epic.hold_to_hatch,1,'correct grant')
end
do
 local h=harness();h.buy('hold_to_hatch');local r=h.cmd('BuyEpicResearch',{researchId='hold_to_hatch'});eq(r.status,'APPLIED','GE purchase still works');eq(r.result.costGE,'5','approved GE price charged')
 h.receipt('late-after-ge');eq(h.state().permanent.epic.hold_to_hatch,1,'late payment cannot grant stale target level');eq(h.state().permanent.epicPurchases.credits.epic_upgrade_9,'1','late payment retained for explicit redemption')
 local redeem=h.buy('hold_to_hatch');eq(redeem.result.granted,true,'unit can buy current eligible level');eq(h.state().permanent.epic.hold_to_hatch,2,'one new level from retained unit')
end
do
 local h=harness();h.buy('hold_to_hatch');h.buy('epic_hatchery');h.receipt('late-choice');eq(h.state().permanent.epic.epic_hatchery,1,'latest explicit same-price selection uses fungible unit');eq(h.state().permanent.epic.hold_to_hatch,nil,'replaced selection not granted as well')
 eq(h.buy('video_doubler_time').status,'REJECTED','removed research cannot sell');eq(h.buy('afx_mission_time').status,'REJECTED','unimplemented effect cannot sell')
 local missing=B.new();local seed=S.createReference('2',1000000);missing:playerJoined('2',seed)
 local r=missing:dispatch('2',{protocolVersion=1,kind='BuyEpicRobux',requestId='missing',operationId='missing',expectedRevision=missing:getCoordinator('2').snapshots().durable.meta.revision,args={researchId='hold_to_hatch'}})
 eq(r.result.errorCode,'PRODUCT_NOT_CONFIGURED','unconfigured products cannot be sold')
end
do -- Receipt before choice and after commit/reconnect: no in-memory intent required.
 local h=harness();h.receipt('before-choice');h.reconnect()
 eq(h.state().permanent.epicPurchases.credits.epic_upgrade_9,'1','unselected payment survives reconnect')
 local r=h.buy('epic_hatchery');eq(r.result.granted,true,'saved payment redeemed after reconnect');eq(h.state().permanent.epic.epic_hatchery,1,'one redeemed level')
end
do -- Durable receipt guard is independent of coordinator operation caching.
 local E=require('../../src/server/EpicPurchases');local p=S.createReference('1',1000000)
 E.prepare(p,'hold_to_hatch',harness().b.catalog,products)
 local receipt={PlayerId=1,ProductId=7001}
 E.receive(p,'domain-receipt',receipt,products,1000000)
 E.receive(p,'domain-receipt',receipt,products,1000001)
 eq(p.permanent.epic.hold_to_hatch,1,'durable receipt guard prevents duplicate level')
 eq(p.permanent.epicPurchases.credits.epic_upgrade_9,'0','durable receipt guard prevents duplicate paid unit')
 eq(S.validate(p,'1'),true,'new optional state validates')
end
do
 local h=harness();h.buy('hold_to_hatch');local old=h.b;h.reconnect(true)
 eq(old:applyPurchase('1',{PlayerId=1,PurchaseId='stale-server',ProductId=7001}),false,'old session cannot fulfill after ownership takeover')
 eq(h.receipt('stale-server'),true,'new owner fulfills receipt');eq(h.state().permanent.epic.hold_to_hatch,1,'new owner grants once')
end
do -- Actual client and HUD paths, no direct server handler stand-in.
 local h=harness();local Client=require('../../src/client/Bootstrap');local prompts={}
 local c=Client.new({wire=h.b,playerId='1',promptPurchase=function(p)table.insert(prompts,p)end})
 c:connect('client');local hud=c:getHUD();hud:update()
 local card=hud.epicResearchCards.hold_to_hatch
 eq(card.buyBtn.Text,'5 💎','HUD uses approved GE cost');eq(card.buyRobuxBtn.Active,true,'configured offer enabled');eq(card.buyRobuxBtn.Text,'9 R$*','HUD shared price shown')
 card.buyRobuxBtn.Activated:Fire();eq(#prompts,0,'no platform prompt before explicit confirmation')
 eq(h.state().permanent.epic.hold_to_hatch,nil,'client selection does not grant')
 local frame=hud.purchasePreviewFrame;eq(frame~=nil,true,'server preview shown')
 frame:FindFirstChild('Confirm').Activated:Fire();eq(#prompts,1,'confirmation opens one platform prompt');eq(prompts[1].platformId,7001,'client prompts server-selected shared product')
 frame:FindFirstChild('Confirm').Activated:Fire();eq(#prompts,1,'repeated confirm cannot prompt another payment')
 h.receipt('client-paid');c:getTransport():sendRefreshState();eq(c:getFarm().progress.epic.hold_to_hatch,1,'client state reflects actual receipt grant')
 c:destroy()
end
print('Epic Robux PASS: '..count..' assertions')
