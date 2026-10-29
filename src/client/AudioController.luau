--!strict
-- AudioController.luau: Manages game sound effects (SFX) and background music (BGM).
-- Spec: PROD-08 (Issue #50).
-- Compatible with both Roblox Studio (SoundService, Sound instances) and pure Lune (safe mocks).

local AudioController = {}
AudioController.__index = AudioController

local isRoblox, SoundService = pcall(function()
	return game:GetService("SoundService")
end)

local DEFAULT_SFX_ASSETS: { [string]: string } = table.freeze({
	cluck = "rbxasset://sounds/electronicpingshort.wav",
	-- Free Creator Store Audio assets; validated by tests/audio/studio_asset_check.luau.
	coin = "rbxassetid://135483737426662", -- Coin Collect (G00byBBQSauce)
	pop = "rbxassetid://140323850218372", -- Pop Sound Effect (Siegegeddon)
	click = "rbxassetid://6895079853",
	fanfare = "rbxasset://sounds/victory.wav",
})

local DEFAULT_BGM_ASSETS: { [string]: string } = table.freeze({
	farm_bgm = "",
})

export type AudioControllerOptions = {
	sfxVolume: number?,
	bgmVolume: number?,
	muted: boolean?,
	sfxEnabled: boolean?,
	bgmEnabled: boolean?,
	sfxAssets: { [string]: string }?,
	bgmAssets: { [string]: string }?,
}

function AudioController.new(opts: AudioControllerOptions?)
	local options = opts or {}
	local sfxVol = if type(options.sfxVolume) == "number" then math.clamp(options.sfxVolume, 0, 1) else 0.8
	local bgmVol = if type(options.bgmVolume) == "number" then math.clamp(options.bgmVolume, 0, 1) else 0.5
	local isMuted = if options.muted ~= nil then options.muted == true else false
	local sfxOn = if options.sfxEnabled ~= nil then options.sfxEnabled == true else true
	local bgmOn = if options.bgmEnabled ~= nil then options.bgmEnabled == true else true

	local self = setmetatable({
		sfxVolume = sfxVol,
		bgmVolume = bgmVol,
		muted = isMuted,
		sfxEnabled = sfxOn,
		bgmEnabled = bgmOn,

		sfxAssets = options.sfxAssets or DEFAULT_SFX_ASSETS,
		bgmAssets = options.bgmAssets or DEFAULT_BGM_ASSETS,

		-- State tracking (useful for testing & assertions)
		lastPlayedSFX = nil :: string?,
		sfxPlayCounts = {} :: { [string]: number },
		currentBGMTrack = nil :: string?,
		bgmPlaying = false,

		-- Roblox instance handles
		_soundFolder = nil :: any,
		_sfxGroup = nil :: any,
		_bgmGroup = nil :: any,
		_bgmSoundInstance = nil :: any,
	}, AudioController)

	if isRoblox and SoundService then
		pcall(function()
			local folder = SoundService:FindFirstChild("HatchTheEggAudio")
			if not folder then
				folder = Instance.new("Folder")
				folder.Name = "HatchTheEggAudio"
				folder.Parent = SoundService
			end
			self._soundFolder = folder

			local sfxGrp = folder:FindFirstChild("SFXGroup")
			if not sfxGrp then
				sfxGrp = Instance.new("SoundGroup")
				sfxGrp.Name = "SFXGroup"
				sfxGrp.Parent = folder
			end
			sfxGrp.Volume = if self.muted or not self.sfxEnabled then 0 else self.sfxVolume
			self._sfxGroup = sfxGrp

			local bgmGrp = folder:FindFirstChild("BGMGroup")
			if not bgmGrp then
				bgmGrp = Instance.new("SoundGroup")
				bgmGrp.Name = "BGMGroup"
				bgmGrp.Parent = folder
			end
			bgmGrp.Volume = if self.muted or not self.bgmEnabled then 0 else self.bgmVolume
			self._bgmGroup = bgmGrp
		end)
	end

	return self
end

function AudioController:playSFX(sfxName: string, customVolume: number?)
	if not sfxName then return end

	-- Record play state
	self.lastPlayedSFX = sfxName
	self.sfxPlayCounts[sfxName] = (self.sfxPlayCounts[sfxName] or 0) + 1

	if self.muted or not self.sfxEnabled then
		return
	end

	if isRoblox and SoundService and self._soundFolder then
		local soundId = self.sfxAssets[sfxName] or DEFAULT_SFX_ASSETS[sfxName]
		if soundId then
			pcall(function()
				local s = Instance.new("Sound")
				s.Name = "SFX_" .. sfxName
				s.SoundId = soundId
				s.Volume = if type(customVolume) == "number" then math.clamp(customVolume, 0, 1) else 1.0
				s.SoundGroup = self._sfxGroup
				s.Parent = self._sfxGroup or self._soundFolder
				s:Play()
				s.Ended:Connect(function()
					s:Destroy()
				end)
				-- Fallback cleanup
				task.delay(4, function()
					if s and s.Parent then
						s:Destroy()
					end
				end)
			end)
		end
	end
end

function AudioController:playBGM(bgmName: string?)
	local track = bgmName or "farm_bgm"
	self.currentBGMTrack = track
	self.bgmPlaying = true

	if isRoblox and SoundService and self._soundFolder then
		local soundId = self.bgmAssets[track] or DEFAULT_BGM_ASSETS[track] or DEFAULT_BGM_ASSETS.farm_bgm
		pcall(function()
			if self._bgmSoundInstance and self._bgmSoundInstance.Parent then
				self._bgmSoundInstance:Stop()
				self._bgmSoundInstance:Destroy()
				self._bgmSoundInstance = nil
			end

			local bgm = Instance.new("Sound")
			bgm.Name = "BGM_" .. track
			bgm.SoundId = soundId
			bgm.Looped = true
			bgm.Volume = 1.0
			bgm.SoundGroup = self._bgmGroup
			bgm.Parent = self._bgmGroup or self._soundFolder
			self._bgmSoundInstance = bgm

			if not self.muted and self.bgmEnabled then
				bgm:Play()
			end
		end)
	end
end

function AudioController:stopBGM()
	self.bgmPlaying = false
	if isRoblox and self._bgmSoundInstance then
		pcall(function()
			self._bgmSoundInstance:Stop()
		end)
	end
end

function AudioController:pauseBGM()
	self.bgmPlaying = false
	if isRoblox and self._bgmSoundInstance then
		pcall(function()
			self._bgmSoundInstance:Pause()
		end)
	end
end

function AudioController:resumeBGM()
	self.bgmPlaying = true
	if isRoblox and self._bgmSoundInstance then
		pcall(function()
			if not self.muted and self.bgmEnabled then
				self._bgmSoundInstance:Resume()
			end
		end)
	end
end

function AudioController:setSFXVolume(volume: number)
	self.sfxVolume = math.clamp(volume, 0, 1)
	if isRoblox and self._sfxGroup then
		pcall(function()
			self._sfxGroup.Volume = if self.muted or not self.sfxEnabled then 0 else self.sfxVolume
		end)
	end
end

function AudioController:setBGMVolume(volume: number)
	self.bgmVolume = math.clamp(volume, 0, 1)
	if isRoblox and self._bgmGroup then
		pcall(function()
			self._bgmGroup.Volume = if self.muted or not self.bgmEnabled then 0 else self.bgmVolume
		end)
	end
end

function AudioController:getSFXVolume(): number
	return self.sfxVolume
end

function AudioController:getBGMVolume(): number
	return self.bgmVolume
end

function AudioController:toggleMute(): boolean
	self:setMuted(not self.muted)
	return self.muted
end

function AudioController:setMuted(muted: boolean)
	self.muted = muted == true

	if isRoblox then
		pcall(function()
			if self._sfxGroup then
				self._sfxGroup.Volume = if self.muted or not self.sfxEnabled then 0 else self.sfxVolume
			end
			if self._bgmGroup then
				self._bgmGroup.Volume = if self.muted or not self.bgmEnabled then 0 else self.bgmVolume
			end
			if self._bgmSoundInstance then
				if self.muted or not self.bgmEnabled then
					self._bgmSoundInstance:Pause()
				elseif self.bgmPlaying then
					self._bgmSoundInstance:Resume()
				end
			end
		end)
	end
end

function AudioController:isMuted(): boolean
	return self.muted
end

function AudioController:setSFXEnabled(enabled: boolean)
	self.sfxEnabled = enabled == true
	if isRoblox and self._sfxGroup then
		pcall(function()
			self._sfxGroup.Volume = if self.muted or not self.sfxEnabled then 0 else self.sfxVolume
		end)
	end
end

function AudioController:setBGMEnabled(enabled: boolean)
	self.bgmEnabled = enabled == true
	if isRoblox and self._bgmGroup then
		pcall(function()
			self._bgmGroup.Volume = if self.muted or not self.bgmEnabled then 0 else self.bgmVolume
		end)
	end
	if isRoblox and self._bgmSoundInstance then
		pcall(function()
			if self.bgmEnabled and not self.muted and self.bgmPlaying then
				self._bgmSoundInstance:Resume()
			else
				self._bgmSoundInstance:Pause()
			end
		end)
	end
end

function AudioController:isSFXEnabled(): boolean
	return self.sfxEnabled
end

function AudioController:isBGMEnabled(): boolean
	return self.bgmEnabled
end

function AudioController:isBGMPlaying(): boolean
	return self.bgmPlaying
end

function AudioController:getLastPlayedSFX(): string?
	return self.lastPlayedSFX
end

function AudioController:getSFXPlayCount(sfxName: string): number
	return self.sfxPlayCounts[sfxName] or 0
end

function AudioController:destroy()
	self:stopBGM()
	if isRoblox and self._soundFolder then
		pcall(function()
			self._soundFolder:Destroy()
			self._soundFolder = nil
			self._sfxGroup = nil
			self._bgmGroup = nil
			self._bgmSoundInstance = nil
		end)
	end
end

return table.freeze(AudioController)
