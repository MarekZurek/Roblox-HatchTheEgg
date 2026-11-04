--!strict
-- Source: user-approved four personal islands around one hub, 2026-11-04;
-- Studio STUDIO-01/02 reproduction in docs/workflow/studio_full_loop_2026_11_04.md.
local Client=require('../../src/client/Bootstrap')
local World=require('../../src/server/world/FarmWorld')
local Routes=require('../../src/client/RoutePresentation')
local n=0
local function eq(a:any,b:any,label:string)
	n+=1;assert(a==b,label..': expected '..tostring(b)..', got '..tostring(a))
end
local c=Client.new({playerId='1',wire=function()end})
local h=c:getHUD()
eq(h.calendarToggleBtn.Parent,h.rightDock,'Rewards is in the right dock, outside upper-left chat')
eq(h.calendarAlertBadge~=nil,true,'calendar notification retained after moving Rewards')
c:destroy()

local w=World.new():build()
local a,slot=w:assign('1');local b,slot2=w:assign('2')
eq(slot,1,'first available farm');eq(slot2,2,'second available farm')
eq(a==b,false,'different players never share a world builder')
eq(w:assign('1'),a,'assignment idempotent')
eq(a.origin.z,240,'south island');eq(b.origin.x,240,'east island')
local function farm(pop:string,index:number):any
	return {habitats={{slotId=1,habitatIndex=0,population=pop,capacity='250'},{slotId=2,habitatIndex=index,population='0',capacity='250'}}}
end
-- Billboard adapters are absent from the headless builder; native instances are tested in Studio.
a:getHabitats()[1].popLabel={Text=''};b:getHabitats()[1].popLabel={Text=''}
a:updateFromFarmView(farm('250',0));b:updateFromFarmView(farm('0',-1))
eq(a:getHabitats()[1].popLabel.Text,'250 / 250 🐔','updating second player does not overwrite first population')
eq(a:getHabitats()[2].currentTypeIndex,0,'first player purchased habitat stays built')
eq(b:getHabitats()[2].currentTypeIndex,-1,'second player empty habitat remains empty')
local d,s3=w:assign('3');local e,s4=w:assign('4')
eq(s3,3,'third island');eq(s4,4,'fourth island');eq(w:assign('5'),nil,'full server cannot share an owned island')
w:release('1');eq(w:get('1'),nil,'departed owner removed');eq(w:get('2'),b,'other owner stable on release')
local fresh,reused=w:assign('5');eq(reused,1,'free slot reused');eq(fresh==a,false,'reuse clears previous owner models')
eq(fresh:getHabitats()[2].currentTypeIndex,-1,'reused farm starts empty')
w:release('unknown');eq(w:get('2'),b,'unknown release harmless')

-- Translation changes neither local route shape nor elapsed travel time.
local origin={x=240,y=0,z=0}
local translated=Routes.new({worldOrigin=origin})
local base=Routes.new()
for i=1,4 do
	eq(translated:getRouteForSlot(i).travelDuration,base:getRouteForSlot(i).travelDuration,'travel duration unchanged')
	for _,t in {0,.25,.5,1} do
		local p=translated:interpolateRoutePosition(i,t);local q=base:interpolateRoutePosition(i,t)
		eq(p.x,q.x+240,'chicken follows assigned island X');eq(p.z,q.z,'local route Z unchanged')
	end
end
translated:spawnDrone('gift-test',false,1000,17.5,nil,{landedAtMs=3500,expiresAtMs=18500,position={x=-12,y=1.15,z=18}})
translated:update(4000)
local p=translated._activeDrones['gift-test'].currentPosition
eq(p.x,228,'gift visual translated to owner island');eq(p.z,18,'gift landing local Z retained')
translated:destroy();base:destroy()

-- Execute the actual entrypoint: each private Bootstrap must update its assigned builder.
local Main=require('../support/MainHarness')
local native=Main.new({studio=true,localMemory=true});native.join()
local first=native.player
native.remote({protocolVersion=1,kind='Bootstrap',requestId='first'})
local firstWorld=native.farms:get('1')
local firstUpdates=#firstWorld.updates
local second=native.addPlayer(2);native.services.Players.PlayerAdded:Fire(second)
native.player=second
native.remote({protocolVersion=1,kind='Bootstrap',requestId='second'})
eq(#firstWorld.updates,firstUpdates,'second Bootstrap cannot write first world')
eq(#native.farms:get('2').updates>0,true,'second Bootstrap writes second world')
eq(first.attributes.FarmSlot,1,'entrypoint assigns first spawn island')
eq(second.attributes.FarmSlot,2,'entrypoint assigns second spawn island')
native.services.Players.PlayerRemoving:Fire(first)
eq(native.farms:get('1'),nil,'entrypoint releases departing farm')
eq(native.farms:get('2')~=nil,true,'entrypoint keeps remaining farm')
print('Farm islands regressions PASS: '..n..' assertions')
