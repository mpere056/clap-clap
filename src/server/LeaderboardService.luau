--!strict
-- World (all servers) and server leaderboards.
--
-- Score = Rebirths × 1000 + best clap power ever (log10), so Rebirths rank first and the
-- biggest clap breaks ties. The world board is an OrderedDataStore read every minute
-- (top 100); each player's own score is written every couple of minutes and on Rebirth.
-- Ranks are published as player attributes (GlobalRank, ServerRank) for titles and auras,
-- the lists go to clients for the 🏆 panel and the board in the hall.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Format)

local LeaderboardService = {}

local STORE_NAME = "ClapLeaderboard_v1"
local TOP = 100
local REFRESH_INTERVAL = 60
local WRITE_INTERVAL = 120

export type Entry = { userId: number, name: string, rebirths: number, power: number, score: number }

local remotes: Folder
local store: OrderedDataStore? = nil
local getProfile: (Player) -> (number, number)? -- (rebirths, best power)
local worldTop: { Entry } = {}
local names: { [number]: string } = {}
local lastWrite: { [Player]: number } = {}
local announced: { [Player]: boolean } = {}

local function score(rebirths: number, power: number): number
	return rebirths * 1000 + power
end

local function nameFor(userId: number): string
	local cached = names[userId]
	if cached then
		return cached
	end
	local inServer = Players:GetPlayerByUserId(userId)
	if inServer then
		names[userId] = inServer.DisplayName
		return inServer.DisplayName
	end
	local ok, result = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local name = if ok then result else ("Player " .. userId)
	names[userId] = name
	return name
end

local function serverEntries(): { Entry }
	local list = {}
	for _, player in Players:GetPlayers() do
		local rebirths, power = (getProfile :: any)(player)
		if rebirths then
			table.insert(list, { userId = player.UserId, name = player.DisplayName, rebirths = rebirths, power = power, score = score(rebirths, power) })
		end
	end
	table.sort(list, function(a, b)
		return a.score > b.score
	end)
	return list
end

local function publish()
	local server = serverEntries()
	local worldRank: { [number]: number } = {}
	for i, entry in worldTop do
		worldRank[entry.userId] = i
	end
	for i, entry in server do
		local player = Players:GetPlayerByUserId(entry.userId)
		if player then
			player:SetAttribute("ServerRank", i)
			local rank = worldRank[entry.userId]
			player:SetAttribute("GlobalRank", rank)
			if rank and rank <= 3 and not announced[player] then
				announced[player] = true;
				(remotes.Broadcast :: RemoteEvent):FireAllClients("TopPlayer", { name = player.DisplayName, rank = rank })
			end
			local stats = player:FindFirstChild("leaderstats")
			if stats then
				(stats:FindFirstChild("Power") :: StringValue).Value = Format.short(entry.power)
			end
		end
	end
	(remotes.Leaderboard :: RemoteEvent):FireAllClients({ world = worldTop, server = server })
end

local function write(player: Player)
	if not store then
		return
	end
	local rebirths, power = (getProfile :: any)(player)
	-- Studio's multi-client test players (Player1, ...) have negative ids: keep them off the world board
	if not rebirths or player.UserId <= 0 then
		return
	end
	lastWrite[player] = os.clock()
	local value = math.floor(score(rebirths, power) * 100)
	pcall(function()
		(store :: OrderedDataStore):SetAsync(tostring(player.UserId), value)
	end)
end

local function refresh()
	if not store then
		publish()
		return
	end
	local ok, pages = pcall(function()
		return (store :: OrderedDataStore):GetSortedAsync(false, TOP)
	end)
	if ok then
		local list = {}
		for _, item in (pages :: DataStorePages):GetCurrentPage() do
			local userId = tonumber(item.key)
			if userId and userId > 0 then
				local value = (item.value :: number) / 100
				local rebirths = math.floor(value / 1000)
				table.insert(list, { userId = userId, name = nameFor(userId), rebirths = rebirths, power = value - rebirths * 1000, score = value })
			end
		end
		worldTop = list
	end
	publish()
end

-- call after a Rebirth or another big moment so the boards catch up quickly
function LeaderboardService.update(player: Player)
	task.spawn(function()
		write(player)
		refresh()
	end)
end

function LeaderboardService.rankOf(player: Player): number?
	return player:GetAttribute("GlobalRank") :: number?
end

function LeaderboardService.init(remoteFolder: Folder, profile: (Player) -> (number, number)?)
	remotes = remoteFolder
	getProfile = profile
	-- Studio fresh-save test (see DataService): keep the throwaway progress off the world board
	local freshSave = game:GetService("RunService"):IsStudio() and game:GetService("ServerStorage"):GetAttribute("DevFreshSave") == true
	if game.PlaceId ~= 0 and not freshSave then
		local ok, result = pcall(function()
			local s = DataStoreService:GetOrderedDataStore(STORE_NAME)
			s:GetSortedAsync(false, 1)
			return s
		end)
		if ok then
			store = result
		else
			warn("[Leaderboard] World leaderboard unavailable - server ranks only:", result)
		end
	end

	local function addStats(player: Player)
		-- player-list columns
		local stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		local rebirths = Instance.new("IntValue")
		rebirths.Name = "Rebirths"
		rebirths.Parent = stats
		local stage = Instance.new("IntValue")
		stage.Name = "Stage"
		stage.Parent = stats
		local power = Instance.new("StringValue")
		power.Name = "Power"
		power.Parent = stats
		stats.Parent = player
		local function sync()
			rebirths.Value = (player:GetAttribute("Rebirths") :: number?) or 0
			stage.Value = (player:GetAttribute("BestStage") :: number?) or 1
		end
		player:GetAttributeChangedSignal("Rebirths"):Connect(sync)
		player:GetAttributeChangedSignal("BestStage"):Connect(sync)
		sync()
	end
	Players.PlayerAdded:Connect(addStats)
	for _, player in Players:GetPlayers() do
		if not player:FindFirstChild("leaderstats") then
			addStats(player)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		write(player)
		lastWrite[player] = nil
		announced[player] = nil
		task.defer(publish)
	end)

	task.spawn(function()
		task.wait(5)
		while true do
			for _, player in Players:GetPlayers() do
				if os.clock() - (lastWrite[player] or 0) > WRITE_INTERVAL then
					write(player)
				end
			end
			refresh()
			task.wait(REFRESH_INTERVAL)
		end
	end)
	-- server ranks change as people clap, so republish them more often than the world list
	task.spawn(function()
		while true do
			task.wait(10)
			publish()
		end
	end)
end

return LeaderboardService
