--!strict
-- Runs live events from shared/Events: publishes what's on (and what's coming) for the banner,
-- announces the rush (e.g. Witching Minute) on every server at the same moment, and rolls
-- event-currency drops for on-beat claps.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Events = require(Shared.Events)

local EventService = {}

local remotes: Folder
local forced: string? = nil
local rng = Random.new()

function EventService.active(): Events.Event?
	return Events.active(os.time(), forced)
end

-- event currency for one on-beat clap of this grade (doubled during the rush)
function EventService.dropFor(grade: string): number
	local event = EventService.active()
	if not event then
		return 0
	end
	local chance = event.dropChance[grade] or 0
	if rng:NextNumber() >= chance then
		return 0
	end
	return if Events.rushLeft(event, os.time()) > 0 then event.rush.multiplier else 1
end

local function publish()
	local now = os.time()
	local event = EventService.active()
	local upcoming = Events.upcoming(now)
	ReplicatedStorage:SetAttribute("EventId", if event then event.id else "")
	ReplicatedStorage:SetAttribute("NextEventId", if upcoming then upcoming.id else "")
	ReplicatedStorage:SetAttribute("EventForced", forced ~= nil)
end

function EventService.init(remoteFolder: Folder)
	remotes = remoteFolder
	publish()
	task.spawn(function()
		local wasRush = false
		while true do
			task.wait(1)
			publish()
			local event = EventService.active()
			local rush = event ~= nil and Events.rushLeft(event :: Events.Event, os.time()) > 0
			if rush and not wasRush then
				(remotes.Broadcast :: RemoteEvent):FireAllClients("Rush", {
					name = (event :: Events.Event).rush.name,
					seconds = (event :: Events.Event).rush.seconds,
					multiplier = (event :: Events.Event).rush.multiplier,
					icon = (event :: Events.Event).currency.icon,
				})
			end
			wasRush = rush
		end
	end)

	-- Studio-only: ServerStorage.DevEvent:Invoke("christmas2026") forces an event, "" clears it
	if RunService:IsStudio() then
		local dev = Instance.new("BindableFunction")
		dev.Name = "DevEvent"
		dev.OnInvoke = function(id: string?)
			forced = if id and id ~= "" then id else nil
			publish()
			return EventService.active() and (EventService.active() :: Events.Event).id or "none"
		end
		dev.Parent = game:GetService("ServerStorage")
	end
end

return EventService
