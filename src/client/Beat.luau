--!strict
-- Shared rhythm clock. Every client uses server time so beats line up across players (In Sync).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local T = Config.Tuning
local Beat = {}

function Beat.now(): number
	return workspace:GetServerTimeNow()
end

-- 0..1 position within the current beat (0 = on the beat)
function Beat.phase(): number
	return (Beat.now() % T.BeatInterval) / T.BeatInterval
end

-- nearest beat index and whether "now" is inside the Perfect window
function Beat.check(): (number, boolean)
	local now = Beat.now()
	local nearest = math.floor(now / T.BeatInterval + 0.5)
	local offset = math.abs(now - nearest * T.BeatInterval)
	return nearest, offset <= T.PerfectWindow
end

return Beat
