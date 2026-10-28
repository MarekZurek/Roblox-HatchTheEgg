--!strict
-- Native Studio regression: a reward SFX must be Audio, load, advance and finish.
-- Oracle: user request 2026-10-28; enum Audio=3 comes from Roblox, not our IDs.
-- Run on a Play client with Main disabled, so no live game audio owns the folder.
-- Each run uses a fresh module clone to avoid require caching across mutations.
return function(audioModule: ModuleScript)
 assert(game:GetService("RunService"):IsRunning() and game:GetService("RunService"):IsClient(),"Audio playback requires a Play client")
 local soundService=game:GetService("SoundService")
 assert(not soundService:FindFirstChild("HatchTheEggAudio"),"Run with Main disabled and no live game audio")
 local copy=audioModule:Clone();copy.Parent=audioModule.Parent
 local audio=require(copy).new()
 local report={sounds={}}
 local ok,err=xpcall(function()
  for _,name in {"coin","pop"} do
   local id=audio.sfxAssets[name]
   local numeric=tonumber(id:match("%d+"))
   local info=game:GetService("MarketplaceService"):GetProductInfo(numeric,Enum.InfoType.Asset)
   assert(info.AssetTypeId==Enum.AssetType.Audio.Value,name..": expected Audio asset, got type "..tostring(info.AssetTypeId))
   local preload=Instance.new("Sound");preload.SoundId=id;preload.Parent=audio._soundFolder
   local status
   game:GetService("ContentProvider"):PreloadAsync({preload},function(_,s)status=s end)
   assert(status==Enum.AssetFetchStatus.Success,name..": preload must succeed")
   assert(preload.IsLoaded and preload.TimeLength>0,name..": decoded duration must be positive")
   local duration=preload.TimeLength;preload:Destroy()
   local row={name=name,id=id,assetName=info.Name,assetType=info.AssetTypeId,duration=duration,loaded=false,played=false,lifetime=0,maxPosition=0}
   table.insert(report.sounds,row)
   local sound;local created=0
   local con=audio._sfxGroup.ChildAdded:Connect(function(child)
    if child:IsA("Sound") and child.Name=="SFX_"..name then
     sound=child
     created=os.clock()
     child.Played:Connect(function() row.played=true end)
    end
   end)
   audio:playSFX(name)
   local deadline=os.clock()+5
   repeat
    if sound and sound.Parent then
     row.loaded=row.loaded or sound.IsLoaded
     row.maxPosition=math.max(row.maxPosition,sound.TimePosition)
     row.lifetime=os.clock()-created
    end
    task.wait(.01)
   until (sound~=nil and sound.Parent==nil) or os.clock()>=deadline
   con:Disconnect()
   assert(row.loaded,name..": actual SFX must load")
   assert(row.played,name..": actual SFX must emit Played")
   assert(row.maxPosition>0,name..": actual playback cursor must advance")
   -- AudioController destroys inside Ended. Deferred signals can disconnect an
   -- observer's later Ended callback; observe playback + destruction instead.
   assert(sound and sound.Parent==nil,name..": completed SFX must be cleaned up")
   assert(row.maxPosition>=duration*.75,name..": playback must reach the final quarter")
   assert(row.lifetime>=duration-.15 and row.lifetime<duration+.75,name..": natural cleanup must follow duration, before the four-second fallback")
  end
 end,debug.traceback)
 audio:destroy();copy:Destroy()
 assert(ok,err)
 return report
end
