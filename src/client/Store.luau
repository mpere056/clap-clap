--!strict
-- Client-side copy of the player's state (authoritative values come from the server)
-- plus a tiny change signal.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Num = require(Shared.Num)

local Store = {}

Store.state = {
	applause = Num.ZERO,
	clapPower = 0,
	strongHands = 0,
	techniques = {},
	classmates = {},
	stage = 1,
	highestStage = 1,
	runClaps = 0,
	totalClaps = 0,
	frenzy = 0,
	frenzyChain = 0,
	combo = 1,
	capped = false,
} :: { [string]: any }

Store.loaded = false

local changed = Instance.new("BindableEvent")
Store.changed = changed.Event

function Store.set(snapshot: { [string]: any })
	local previousStage = Store.state.stage
	Store.state = snapshot
	Store.loaded = true
	changed:Fire(previousStage)
end

return Store
