--!strict
-- Loads and saves player state. Falls back to in-memory data when DataStores are
-- unavailable (unpublished place, or API access disabled in Studio).
-- TODO: move to ProfileStore (session locking) before launch.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Formulas = require(Shared.Formulas)

local DataService = {}

local STORE_NAME = "ClapClap_v1"
local AUTOSAVE_INTERVAL = 60
local SAVE_VERSION = 1

local store: DataStore? = nil
local enabled = false

local states: { [Player]: Formulas.PlayerState } = {}

local function reconcile(data: any): Formulas.PlayerState
	local state = Formulas.newState()
	if type(data) ~= "table" then
		return state
	end
	for key, default in pairs(state :: any) do
		local value = data[key]
		if value ~= nil and type(value) == type(default) then
			(state :: any)[key] = value
		end
	end
	return state
end

local function withRetries<T>(fn: () -> T): (boolean, T | string)
	local lastErr: any
	for attempt = 1, 3 do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastErr = result
		task.wait(attempt)
	end
	return false, tostring(lastErr)
end

function DataService.init()
	if game.PlaceId == 0 then
		warn("[DataService] Place is unpublished - using in-memory data (progress won't save).")
		return
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
		enabled = true
	else
		warn("[DataService] DataStores unavailable - using in-memory data:", result)
	end

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player in states do
				task.spawn(DataService.save, player)
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player in states do
			pending += 1
			task.spawn(function()
				DataService.save(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

function DataService.load(player: Player): Formulas.PlayerState
	local data = nil
	if enabled and store then
		local ok, result = withRetries(function()
			return (store :: DataStore):GetAsync("p_" .. player.UserId)
		end)
		if ok then
			data = result
		else
			warn("[DataService] Load failed for", player.Name, result)
		end
	end
	local state = reconcile(data)
	states[player] = state
	return state
end

function DataService.get(player: Player): Formulas.PlayerState?
	return states[player]
end

function DataService.save(player: Player)
	local state = states[player]
	if not (enabled and store and state) then
		return
	end
	local payload = table.clone(state) :: any
	payload.version = SAVE_VERSION
	payload.savedAt = os.time()
	local ok, err = withRetries(function()
		return (store :: DataStore):UpdateAsync("p_" .. player.UserId, function()
			return payload
		end)
	end)
	if not ok then
		warn("[DataService] Save failed for", player.Name, err)
	end
end

function DataService.release(player: Player)
	DataService.save(player)
	states[player] = nil
end

Players.PlayerRemoving:Connect(function(player)
	if states[player] then
		DataService.release(player)
	end
end)

return DataService
