--!strict
-- Layered clap audio per stage, the beat metronome, ambience, stingers, and the silence of space.

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
local tickSound: Sound? = nil
local inSpace = false
local spaceSince = 0

local MAX_CLAP_SOUNDS_PER_SECOND = 12
local MUSIC_VOLUME = 0.25 -- kept low: the metronome carries the beat

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
	local beatGroup = group("Beat", 0.6)
	local reverb = Instance.new("ReverbSoundEffect")
	reverb.DecayTime = 1.4
	reverb.WetLevel = -8
	reverb.Parent = sfx

	for i = 1, 8 do
		local id = Sounds.Claps[(i - 1) % #Sounds.Claps + 1]
		table.insert(clapPool, sound(id, SoundService, sfx, 0.8))
	end
	boomSmall = sound(Sounds.BoomSmall, SoundService, sfx, 0)
	tickSound = sound(Sounds.Tick, SoundService, beatGroup, 0.35)
	crowd = sound(Sounds.Crowd, SoundService, ambience, 0.25, true)
	music = sound(Sounds.Music, SoundService, musicGroup, MUSIC_VOLUME, true);
	(crowd :: Sound):Play();
	(music :: Sound):Play()
end

-- intensity: (furthest stage - 1) + progress; grade: Perfect/Great/Good/Miss
function Audio.clap(intensity: number, grade: string)
	local now = os.clock()
	if now - lastClapSound < 1 / MAX_CLAP_SOUNDS_PER_SECOND then
		return
	end
	lastClapSound = now

	if inSpace then
		-- no sound in space: only a muffled thump you feel more than hear
		if boomSmall and grade ~= "Miss" then
			boomSmall.Volume = 0.12
			boomSmall.PlaybackSpeed = 0.45
			boomSmall.TimePosition = 0
			boomSmall:Play()
		end
		return
	end

	clapIndex = clapIndex % #clapPool + 1
	local s = clapPool[clapIndex]
	local power = math.min(intensity, 4)
	if grade == "Miss" then
		-- a limp, off-beat clap
		s.PlaybackSpeed = 0.75
		s.Volume = 0.3
	else
		s.PlaybackSpeed = (1.05 - power * 0.06) * (0.95 + math.random() * 0.1) * (if grade == "Perfect" then 1.05 else 1)
		s.Volume = 0.6 + math.min(0.4, power * 0.15) + (if grade == "Perfect" then 0.15 else 0)
	end
	s.TimePosition = 0
	s:Play()

	-- low boom layer once the clap has become a shockwave
	if grade ~= "Miss" and intensity > 0.75 and boomSmall then
		local layer = math.clamp((intensity - 0.75) / 2.5, 0, 1)
		boomSmall.Volume = 0.15 + 0.5 * layer + (if grade == "Perfect" then 0.1 else 0)
		boomSmall.PlaybackSpeed = 1.1 - 0.4 * layer + math.random() * 0.05
		boomSmall.TimePosition = 0
		boomSmall:Play()
	end
end

-- metronome: a soft click every beat, slightly louder on the first of every four
function Audio.tick(beatIndex: number)
	if not tickSound or inSpace then
		return
	end
	local accent = beatIndex % 4 == 0
	tickSound.Volume = if accent then 0.45 else 0.25
	tickSound.PlaybackSpeed = if accent then 1.15 else 1
	tickSound.TimePosition = 0
	tickSound:Play()
end

-- quieter clap from another player, positioned at their character; visitors sound bigger
function Audio.otherClap(character: Model?, intensity: number)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or inSpace then
		return
	end
	local id = Sounds.Claps[math.random(1, #Sounds.Claps)]
	local s = sound(id, root, groups.SFX, 0.35 + math.min(0.4, intensity * 0.1))
	s.RollOffMaxDistance = 150
	s.RollOffMinDistance = 8
	s.PlaybackSpeed = (1.05 - math.min(intensity, 4) * 0.08) * (0.95 + math.random() * 0.1)
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
	if not inSpace then
		Audio.oneShot(Sounds.Glass, 0.5, 0.9 + math.random() * 0.2)
	end
end

-- tier-up sting: a boom that deepens with each tier
function Audio.tierUp(tier: number)
	Audio.oneShot(Sounds.BoomSmall, if inSpace then 0.15 else 0.6, 1.15 - tier * 0.06)
end

function Audio.breakthrough()
	Audio.oneShot(Sounds.Breakthrough, 0.9)
	Audio.oneShot(Sounds.BoomBig, 0.7)
end

-- space: everything goes silent on arrival, then a quiet score fades back in
function Audio.setSpace(on: boolean)
	if on and not inSpace then
		spaceSince = os.clock()
	end
	inSpace = on
end

-- the hall goes quiet as you get louder; crowd only in the ceremony
function Audio.setStage(stageId: number, t: number)
	if crowd then
		crowd.Volume = if stageId == 1 then 0.25 * (1 - t * 0.7) else 0
	end
	if music then
		if inSpace then
			local since = os.clock() - spaceSince
			music.Volume = MUSIC_VOLUME * 0.5 * math.clamp((since - 6) / 6, 0, 1)
		else
			music.Volume = MUSIC_VOLUME
		end
	end
end

return Audio
