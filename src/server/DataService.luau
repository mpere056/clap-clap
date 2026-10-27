--!strict
-- Loads and saves player state with a session lock, so a player hopping servers can't have two
-- servers writing their data at once (lost or duplicated progress).
--
-- Saved record: { version, savedAt, state = PlayerState, lock = { jobId, time }? }
--   * load claims the lock; if another live server holds it we wait for it to release, and
--     take it over after LOAD_STEAL_AFTER seconds (that server may have crashed)
--   * saves only write while we still own the lock; release clears it
--   * the lock goes stale after LOCK_STALE_AFTER seconds without an autosave refreshing it
--
-- Falls back to in-memory data when DataStores are unavailable (unpublished place, or
-- "Enable Studio Access to API Services" turned off).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Formulas = require(Shared.Formulas)

local DataService = {}

local STORE_NAME = "ClapClap_v1"
local SAVE_VERSION = 2
local AUTOSAVE_INTERVAL = 60
local LOCK_STALE_AFTER = 180
local LOAD_RETRY_INTERVAL = 4
local LOAD_STEAL_AFTER = 30
local MAX_LOAD_ERRORS = 5

local store: DataStore? = nil
local enabled = false

local states: { [Player]: Formulas.PlayerState } = {}
local owned: { [Player]: boolean } = {} -- we hold the session lock

local function sessionId(): string
	return if game.JobId ~= "" then game.JobId else "studio"
end

local function key(player: Player): string
	return "p_" .. player.UserId
end

local function reconcile(data: any): Formulas.PlayerState
	local state = Formulas.newState()
	if type(data) ~= "table" then
		return state
	end
	for field, default in pairs(state :: any) do
		local value = data[field]
		if value ~= nil and type(value) == type(default) then
			(state :: any)[field] = value
		end
	end
	return state
end

-- version 1 records stored the state at the top level
local function stateOf(record: any): any
	if type(record) ~= "table" then
		return nil
	end
	return if record.state ~= nil then record.state else record
end

function DataService.isPersistent(): boolean
	return enabled
end

function DataService.init()
	if game.PlaceId == 0 then
		warn("[DataService] Place is unpublished - using in-memory data (progress won't save).")
		return
	end
	local ok, err = pcall(function()
		store = DataStoreService:GetDataStore(STORE_NAME)
		-- probe once so a missing Studio API permission falls back cleanly instead of kicking players
		;(store :: DataStore):GetAsync("probe")
	end)
	if not ok then
		warn("[DataService] DataStores unavailable - using in-memory data:", err)
		store = nil
		return
	end
	enabled = true

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player in states do
				task.spawn(DataService.save, player, false)
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player in states do
			pending += 1
			task.spawn(function()
				DataService.save(player, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

-- Returns the player's state, or nil if it couldn't be loaded safely (the caller should kick).
function DataService.load(player: Player): Formulas.PlayerState?
	if not enabled or not store then
		local state = Formulas.newState()
		states[player] = state
		return state
	end

	local me = sessionId()
	local started = os.clock()
	local errors = 0
	while player.Parent do
		local waitedTooLong = os.clock() - started >= LOAD_STEAL_AFTER
		local ok, result = pcall(function()
			return (store :: DataStore):UpdateAsync(key(player), function(record: any)
				record = if type(record) == "table" then record else {}
				local lock = record.lock
				local heldElsewhere = type(lock) == "table"
					and lock.jobId ~= me
					and os.time() - (tonumber(lock.time) or 0) < LOCK_STALE_AFTER
				if heldElsewhere and not waitedTooLong then
					return nil -- cancel; another server still has this player
				end
				record.lock = { jobId = me, time = os.time() }
				return record
			end)
		end)
		if ok then
			local record = result :: any
			if type(record) == "table" and type(record.lock) == "table" and record.lock.jobId == me then
				local state = reconcile(stateOf(record))
				states[player] = state
				owned[player] = true
				return state
			end
		else
			errors += 1
			warn("[DataService] Load attempt failed for", player.Name, result)
			if errors >= MAX_LOAD_ERRORS then
				return nil
			end
		end
		task.wait(LOAD_RETRY_INTERVAL)
	end
	return nil
end

function DataService.get(player: Player): Formulas.PlayerState?
	return states[player]
end

-- release = true clears the session lock (player leaving / server closing)
function DataService.save(player: Player, release: boolean?)
	local state = states[player]
	if not (enabled and store and state and owned[player]) then
		return
	end
	local me = sessionId()
	local lostLock = false
	local ok, err = pcall(function()
		return (store :: DataStore):UpdateAsync(key(player), function(record: any)
			record = if type(record) == "table" then record else {}
			local lock = record.lock
			if type(lock) == "table" and lock.jobId ~= me then
				lostLock = true
				return nil -- another server took over; never overwrite its data
			end
			record.version = SAVE_VERSION
			record.savedAt = os.time()
			record.state = table.clone(state)
			record.lock = if release then nil else { jobId = me, time = os.time() }
			return record
		end)
	end)
	if not ok then
		warn("[DataService] Save failed for", player.Name, err)
	elseif lostLock then
		owned[player] = nil
		warn("[DataService] Session for", player.Name, "was taken over by another server")
		if player.Parent and not release then
			player:Kick("Your progress was loaded on another server. Please rejoin.")
		end
	end
end

function DataService.release(player: Player)
	DataService.save(player, true)
	states[player] = nil
	owned[player] = nil
end

Players.PlayerRemoving:Connect(function(player)
	if states[player] then
		DataService.release(player)
	end
end)

return DataService
