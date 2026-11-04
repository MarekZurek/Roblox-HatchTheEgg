--!strict
-- Approved task: usable phone UI/tutorial in both orientations, with unchanged economy.
-- Native baseline: portrait locked, overlapping research actions, narrow shop, offscreen prestige.
local M=require('../../src/client/ui/MobileLayout')
local Tutorial=require('../../src/client/onboarding/TutorialController')
local fs=require('@lune/fs')
local serde=require('@lune/serde')
local n=0
local function check(v:boolean,label:string) n+=1;assert(v,label) end
local function eq(a:any,b:any,label:string) check(a==b,label..': expected '..tostring(b)..', got '..tostring(a)) end
local function overlap(a:any,b:any): boolean
	return a.x<b.x+b.w and b.x<a.x+a.w and a.y<b.y+b.h and b.y<a.y+a.h
end
for _,size in {{320,582},{375,667},{413,756},{640,302},{667,317},{801,355},{896,356}}do
	local w,h=size[1],size[2];local p=M.hudPlan(w,h)
	for _,name in {'tutorial','dock','stock','cash','diamonds','badge'}do
		local r=p[name]
		check(r.x>=0 and r.y>=0 and r.x+r.w<=w and r.y+r.h<=h,'phone bounds: '..name..' at '..w..'x'..h)
	end
	check(not overlap(p.tutorial,p.dock),'tutorial clear of menu')
	check(not overlap(p.tutorial,p.stock),'tutorial clear of stock')
	check(not overlap(p.cash,p.diamonds),'currency controls separated')
	check(not overlap(p.badge,p.tutorial),'badge clear of tutorial')
	local jump={x=w-95,y=h-90,w=70,h=70}
	check(not overlap(p.tutorial,jump),'tutorial clear of native jump')
	check(not overlap(p.dock,jump),'dock clear of native jump')
	check(not overlap(p.stock,jump),'stock clear of native jump')
	check(not overlap(p.cash,jump),'cash clear of native jump')
	check(not overlap(p.diamonds,jump),'Diamonds clear of native jump')
end
for _,w in {270,323,361,450,510,600}do
	local r=M.researchPlan(w)
	check(r.buy.w>=44 and r.buy.h>=44 and r.max.w>=44 and r.max.h>=44,'research touch controls >=44')
	check(not overlap(r.text,r.buy),'research description clear of BUY')
	check(not overlap(r.text,r.max),'research description clear of MAX')
	check(not overlap(r.buy,r.max),'BUY and MAX are separate targets')
	check(r.buy.x+r.buy.w<=w and r.max.x+r.max.w<=w,'research actions stay in card')
	check(r.buy.y+r.buy.h<=r.height,'research action within scrolling row')
	if w<480 then check(r.text.w>=w-70,'phone research keeps readable description width')end
end
local h=M.bodyItem(1,-66,0,52,460)
eq(h.y,334,'bottom-anchored hatch action preserved in scroll body')
eq(h.height,52,'hatch target retains height')
local p=M.bodyItem(0,474,0,60,580)
eq(p.y,414,'prestige action is inside scrollable canvas')
eq(p.y+p.height,474,'prestige content extent independent of viewport height')
eq(M.bodyItem(0,342,0,48,440,0).y,342,'pet reveal content keeps zero inset')
for _,size in {{300,520},{393,560},{540,335},{781,335},{880,560}}do
	local plan=M.shopPlan(size[1],size[2])
	check(plan.banner.h>=44,'promo banner is a full touch target')
	check(not overlap(plan.banner,plan.content),'promo banner separate from product scrolling')
	check(not overlap(plan.tabs,plan.content),'shop tabs separate from product content')
	check(plan.content.h>=44,'product scroll remains usable in landscape')
end
local manifest=serde.decode('json',fs.readFile('default.project.json'))
for _,width in {276,369,516,536}do
	local plan=M.researchTabsPlan(width)
	eq(#plan.tabs,4,'all research categories present')
	for i,r in plan.tabs do
		check(r.w>=44 and r.h>=44,'category touch target >=44')
		check(r.x>=0 and r.x+r.w<=width+.001 and r.y+r.h<=plan.height,'category visible without swiping')
		for j=1,i-1 do check(not overlap(r,plan.tabs[j]),'category targets do not overlap')end
	end
end
eq(manifest.tree.StarterGui['$properties'].ScreenOrientation,'Sensor','both device orientations enabled')
local source=fs.readFile('src/client/ui/MobileLayout.luau')
check(string.find(source,'body.Active=true',1,true)~=nil,'scroll body accepts native touch gestures (Studio regression)')
check(string.find(source,'body.ScrollingDirection=Enum.ScrollingDirection.Y',1,true)~=nil,'modal content scrolls vertically')
local t=Tutorial.new(nil,nil);t:setStep(4)
check(string.find(t:getInstruction(),'right',1,true)~=nil,'tutorial points to actual Rewards dock')
print('Mobile UI regressions PASS: '..n..' assertions')
