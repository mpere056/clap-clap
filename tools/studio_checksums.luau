-- Run in Studio edit mode; compare the output with `python tools/checksums.py`.
local out = {}
local function sum(s)
	local t = 0
	for i = 1, #s do
		t = (t + string.byte(s, i)) % 1000003
	end
	return t
end
local function walk(inst, path)
	if inst:IsA("LuaSourceContainer") then
		table.insert(out, path .. " " .. #inst.Source .. " " .. sum(inst.Source))
	end
	for _, c in inst:GetChildren() do
		walk(c, path .. "." .. c.Name)
	end
end
walk(game.ReplicatedStorage.Shared, "ReplicatedStorage.Shared")
walk(game.ServerScriptService.Server, "ServerScriptService.Server")
walk(game.StarterPlayer.StarterPlayerScripts.Client, "StarterPlayer.StarterPlayerScripts.Client")
table.sort(out)
return table.concat(out, "\n")
