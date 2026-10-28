--!strict
-- Server-only ground gifts. Clock/position/random ports are trusted host dependencies.
local GiftDrops = {}
GiftDrops.DESCENT_MS = 2500
GiftDrops.GROUND_MS = 15000
GiftDrops.PICKUP_RADIUS = 6
local function finite(n: any): boolean return type(n)=='number' and n==n and math.abs(n)<math.huge end
function GiftDrops.inRange(point: any, target: any): boolean
 if type(point)~='table' or type(target)~='table' then return false end
 for _,k in {'x','y','z'} do if not finite(point[k]) or not finite(target[k]) then return false end end
 return (point.x-target.x)^2+(point.y-target.y)^2+(point.z-target.z)^2 <= GiftDrops.PICKUP_RADIUS^2
end
-- docs/06: 25% uniform2..8s, otherwise uniform12..47s; no offline backlog.
function GiftDrops.intervalMs(branch: number, roll: number): number
 assert(branch>=0 and branch<1 and roll>=0 and roll<1,'INVALID_GIFT_DRAW')
 return math.floor((if branch<0.25 then 2+6*roll else 12+35*roll)*1000+0.5)
end
function GiftDrops.new(options: any): any
 assert(type(options.observe)=='function','GIFT_OBSERVER_REQUIRED')
 local self: any={observe=options.observe,draw=options.draw or math.random,rows={},serial=0,generate=options.generate~=false}
 function self:step(server: any)
  local now=server.clock.utcNowMs()
  for id,row in self.rows do if server.players[id]~=row.session then self.rows[id]=nil end end
  for id,session in server.players do
   local snapshots=session.coordinator.snapshots()
   if not snapshots.ready then continue end
   local profile=snapshots.working or snapshots.durable
   local row=self.rows[id]
   if not row then row={session=session,nextAt=now+10000};self.rows[id]=row end
   local hasLive=false
   for giftId,gift in profile.rewards.droneSpawns or {} do
    if gift.kind=='GROUND_GIFT' and not gift.claimed and now<gift.expiresAtMs then
     hasLive=true
     if now>=gift.landedAtMs and GiftDrops.inRange(self.observe(id),gift.position) then
      local ok,reward=server:collectGift(id,giftId)
      if ok then table.insert(server._giftNotifications,{playerId=id,id=giftId,reward=reward}) end
     end
    end
   end
   if self.generate and now>=row.nextAt and not hasLive and self.observe(id)~=nil then
    if not row.pending then
     self.serial+=1
     local giftId='gift-'..profile.ownership.generation..'-'..tostring(now)..'-'..self.serial
     local x=(math.floor(self.draw()*3)-1)*12
     row.pending={id=giftId,terms=server:giftDropTerms(id,{x=x,y=1.15,z=18},self.draw)}
    end
    local pending=row.pending
    local ok=server:_rewardOperation(id,'IssueDrone',{id=pending.id,terms=pending.terms},'issue-'..pending.id)
    if ok then row.pending=nil;row.nextAt=now+GiftDrops.intervalMs(self.draw(),self.draw()) end
   end
  end
 end
 return self
end
return table.freeze(GiftDrops)
