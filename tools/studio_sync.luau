-- Pulls every script in src/ into Studio from a local file server, mirroring the Rojo layout.
-- 1. python -m http.server 47811 --bind 127.0.0.1 --directory src
-- 2. run this in Studio edit mode (e.g. via the Studio MCP execute_luau tool)
-- HTTP is switched on only for the duration of the sync and restored afterwards.

local HttpService = game:GetService("HttpService")
local BASE = "http://127.0.0.1:47811/"

local ROOTS = {
	{ dir = "shared", parent = game:GetService("ReplicatedStorage"), name = "Shared", class = "Folder" },
	{ dir = "server", parent = game:GetService("ServerScriptService"), name = "Server", class = "Script" },
	{ dir = "client", parent = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"), name = "Client", class = "LocalScript" },
}

local function ensure(parent: Instance, name: string, class: string): Instance
	local inst = parent:FindFirstChild(name)
	if inst and inst.ClassName ~= class then
		inst:Destroy()
		inst = nil
	end
	if not inst then
		inst = Instance.new(class)
		inst.Name = name
		inst.Parent = parent
	end
	return inst :: Instance
end

local wasEnabled = HttpService.HttpEnabled
HttpService.HttpEnabled = true
local ok, result = pcall(function()
	local log = {}
	for _, root in ROOTS do
		local container = ensure(root.parent, root.name, root.class)
		local listing = HttpService:GetAsync(BASE .. root.dir .. "/", true)
		for file in listing:gmatch('href="([%w_%.]+%.luau)"') do
			local source = HttpService:GetAsync(BASE .. root.dir .. "/" .. file, true):gsub("\r\n", "\n")
			local stem = file:gsub("%.luau$", "")
			if stem:match("^init%.") then
				(container :: any).Source = source
			else
				(ensure(container, stem, "ModuleScript") :: any).Source = source
			end
			table.insert(log, root.dir .. "/" .. file)
		end
	end
	return table.concat(log, ", ")
end)
HttpService.HttpEnabled = wasEnabled
return (if ok then "synced: " else "sync failed: ") .. tostring(result)
