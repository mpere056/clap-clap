--!strict
-- Layered clap audio per stage, ambience, and one-shot stingers.

local SoundService = game:GetService("SoundService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Sounds = require(Shared.Sounds)

local Audio = {}

local groups: { [string]: SoundGroup } = {}
local clapPool: { Sound } = {}
local clapIndex = 0
local lastClapSound = 0
local crowd: Sound? = nil
local music: Sound? = nil
local boomSmall: Sound? = nil

local MAX_CLAP_SOUNDS_PER_SECOND = 12

local function group(name: string, volume: number): SoundGroup
	local g = Instance.new("SoundGroup")
	g.Name = name
	g.Volume = volume
	g.Parent = SoundService
	groups[name] = g
	return g
end

local function sound(id: string, parent: Instance, soundGroup: SoundGroup, volume: number, looped: boolean?): Sound
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.Looped = looped == true
	s.SoundGroup = soundGroup
	s.Parent = parent
	return s
end

function Audio.init()
	local sfx = group("SFX", 0.9)
	local ambience = group("Ambience", 0.5)
	local musicGroup = group("Music", 0.35)
	local reverb = Instance.new("ReverbSoundEffect")
	reverb.DecayTime = 1.4
	reverb.WetLevel = -8
	reverb.Parent = sfx

	for i = 1, 8 do
		local id = Sounds.Claps[(i - 1) % #Sounds.Claps + 1]
		table.insert(clapPool, sound(id, SoundService, sfx, 0.8))
	end
	boomSmall = sound(Sounds.BoomSmall, SoundService, sfx, 0)
	crowd = sound(Sounds.Crowd, SoundService, ambience, 0.25, true)
	music = sound(Sounds.Music, SoundService, musicGroup, 0.5, true);
	(crowd :: Sound):Play();
	(music :: Sound):Play()
end

-- intensity: 0..3 (stage - 1 + progress)
function Audio.clap(intensity: number, perfect: boolean)
	local now = os.clock()
	if now - lastClapSound < 1 / MAX_CLAP_SOUNDS_PER_SECOND then
		return
	end
	lastClapSound = now
	clapIndex = clapIndex % #clapPool + 1
	local s = clapPool[clapIndex]
	s.PlaybackSpeed = (1.05 - intensity * 0.08) * (0.95 + math.random() * 0.1)
	s.Volume = 0.6 + math.min(0.4, intensity * 0.2) + (if perfect then 0.1 else 0)
	s.TimePosition = 0
	s:Play()

	-- low boom layer once the clap has become a shockwave
	if intensity > 0.75 and boomSmall then
		local layer = math.clamp((intensity - 0.75) / 1.5, 0, 1)
		boomSmall.Volume = 0.15 + 0.45 * layer
		boomSmall.PlaybackSpeed = 1.1 - 0.35 * layer + math.random() * 0.05
		boomSmall.TimePosition = 0
		boomSmall:Play()
	end
end

-- quieter clap from another player, positioned at their character
function Audio.otherClap(character: Model?, intensity: number)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local id = Sounds.Claps[math.random(1, #Sounds.Claps)]
	local s = sound(id, root, groups.SFX, 0.35 + math.min(0.3, intensity * 0.1))
	s.RollOffMaxDistance = 120
	s.RollOffMinDistance = 8
	s.PlaybackSpeed = (1.05 - intensity * 0.08) * (0.95 + math.random() * 0.1)
	s.PlayOnRemove = false
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
end

function Audio.oneShot(id: string, volume: number, speed: number?)
	local s = sound(id, SoundService, groups.SFX, volume)
	s.PlaybackSpeed = speed or 1
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
end

function Audio.glass()
	Audio.oneShot(Sounds.Glass, 0.5, 0.9 + math.random() * 0.2)
end

function Audio.breakthrough()
	Audio.oneShot(Sounds.Breakthrough, 0.9)
	Audio.oneShot(Sounds.BoomBig, 0.7)
end

-- the hall goes quiet as you get louder; crowd only in the ceremony
function Audio.setStage(stageId: number, t: number)
	if crowd then
		crowd.Volume = if stageId == 1 then 0.25 * (1 - t * 0.7) else 0
	end
end

return Audio
