--!strict
-- Shared multiplayer systems: Standing Ovation meter, In Sync detection, clap pulses
-- (others' claps rendered as an ambient layer) and server-wide broadcasts.
-- See docs/10-multiplayer-effects.md.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)

local T = Config.Tuning
local SocialService = {}

local remotes: Folder
local ovationProgress = 0
local ovationEndsAt = 0

-- beat index -> { [Player]: true }
local beatHits: { [number]: { [Player]: boolean } } = {}
local inSyncUntil: { [Player]: number } = {}

-- per-player claps since last pulse
local pendingPulse: { [Player]: { count: number, perfect: boolean, stage: number, visitor: number, force: number } } = {}

local PULSE_INTERVAL = 0.2

local function publishOvation()
	ReplicatedStorage:SetAttribute("OvationProgress", ovationProgress)
	ReplicatedStorage:SetAttribute("OvationTarget", Formulas.ovationTarget(#Players:GetPlayers()))
	ReplicatedStorage:SetAttribute("OvationEndsAt", ovationEndsAt)
end

function SocialService.broadcast(kind: string, data: { [string]: any })
	(remotes.Broadcast :: RemoteEvent):FireAllClients(kind, data)
end

function SocialService.isOvationActive(): boolean
	return workspace:GetServerTimeNow() < ovationEndsAt
end

function SocialService.ovationMultiplier(): number
	return if SocialService.isOvationActive() then T.OvationMultiplier else 1
end

function SocialService.startOvation(triggeredBy: Player?)
	ovationProgress = 0
	ovationEndsAt = workspace:GetServerTimeNow() + T.OvationDuration
	publishOvation()
	SocialService.broadcast("Ovation", {
		endsAt = ovationEndsAt,
		by = if triggeredBy then triggeredBy.DisplayName else nil,
	})
end

-- count: all claps (drives other players' ambient effects); good: on-beat claps (fill the
-- Ovation); visitor: how many stages ahead of this stage the clapper is (0 = their own stage);
-- force: how hard their claps hit this stage (Formulas.clapForce, toned down by their setting)
function SocialService.addClaps(player: Player, count: number, good: number, perfect: boolean, stage: number, visitor: number, force: number)
	if count <= 0 then
		return
	end
	if good > 0 and not SocialService.isOvationActive() then
		ovationProgress += good * (if visitor > 0 then T.VisitorOvationMultiplier else 1)
		if ovationProgress >= Formulas.ovationTarget(#Players:GetPlayers()) then
			SocialService.startOvation(nil)
		end
	end
	local pulse = pendingPulse[player]
	if not pulse then
		pulse = { count = 0, perfect = false, stage = stage, visitor = visitor, force = force }
		pendingPulse[player] = pulse
	end
	pulse.count += count
	pulse.perfect = pulse.perfect or perfect
	pulse.stage = stage
	pulse.visitor = visitor
	pulse.force = force
end

function SocialService.registerPerfect(player: Player, beat: number)
	local hits = beatHits[beat]
	if not hits then
		hits = {}
		beatHits[beat] = hits
	end
	if hits[player] then
		return
	end
	hits[player] = true

	local members = {}
	for p in hits do
		if p.Parent then
			table.insert(members, p)
		end
	end
	if #members >= T.InSyncMinPlayers then
		local now = os.clock()
		local ids = {}
		for _, p in members do
			inSyncUntil[p] = now + T.BeatInterval * 3
			table.insert(ids, p.UserId)
		end
		-- announce once per beat when the group first forms, then for each joiner
		SocialService.broadcast("InSync", { beat = beat, userIds = ids })
	end
end

function SocialService.isInSync(player: Player): boolean
	return (inSyncUntil[player] or 0) > os.clock()
end

function SocialService.init(remoteFolder: Folder)
	remotes = remoteFolder
	publishOvation()

	-- Studio-only test hook: ServerStorage.DevOvation:Invoke()
	if game:GetService("RunService"):IsStudio() then
		local trigger = Instance.new("BindableFunction")
		trigger.Name = "DevOvation"
		trigger.OnInvoke = function()
			SocialService.startOvation(nil)
			return true
		end
		trigger.Parent = game:GetService("ServerStorage")
	end

	Players.PlayerAdded:Connect(publishOvation)
	Players.PlayerRemoving:Connect(function(player)
		inSyncUntil[player] = nil
		pendingPulse[player] = nil
		task.defer(publishOvation)
	end)

	task.spawn(function()
		local lastPublished = -1
		while true do
			task.wait(PULSE_INTERVAL)
			-- clap pulses: ambient layer of everyone else's claps
			for player, pulse in pendingPulse do
				if player.Parent then
					(remotes.ClapPulse :: UnreliableRemoteEvent):FireAllClients(
						player.UserId,
						pulse.stage,
						pulse.count,
						pulse.perfect,
						SocialService.isInSync(player),
						pulse.visitor,
						math.floor(pulse.force * 100 + 0.5) / 100
					)
				end
			end
			table.clear(pendingPulse)

			if ovationProgress ~= lastPublished then
				lastPublished = ovationProgress
				publishOvation()
			end

			-- forget old beats
			local current = math.floor(workspace:GetServerTimeNow() / T.BeatInterval)
			for beat in beatHits do
				if beat < current - 8 then
					beatHits[beat] = nil
				end
			end
		end
	end)
end

return SocialService
