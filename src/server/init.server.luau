--!strict
-- Server entry point.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local DataService = require(script.DataService)
local EventService = require(script.EventService)
local GameService = require(script.GameService)
local LeaderboardService = require(script.LeaderboardService)
local SocialService = require(script.SocialService)
local WorldService = require(script.WorldService)

Players.CharacterAutoLoads = true

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local function remote(className: string, name: string)
	local r = Instance.new(className)
	r.Name = name
	r.Parent = remotes
end
remote("RemoteEvent", "ClapBatch")
remote("RemoteFunction", "Purchase")
remote("RemoteFunction", "CurtainCall")
remote("RemoteFunction", "Rebirth")
remote("RemoteEvent", "Settings")
remote("RemoteEvent", "Walk")
remote("RemoteEvent", "WatchAd")
remote("RemoteFunction", "EventShop")
remote("RemoteEvent", "Equip")
remote("RemoteFunction", "Travel")
remote("RemoteEvent", "State")
remote("RemoteEvent", "Broadcast")
remote("UnreliableRemoteEvent", "ClapPulse")
remote("RemoteEvent", "Leaderboard")
remotes.Parent = ReplicatedStorage

DataService.init()
EventService.init(remotes)
SocialService.init(remotes)
GameService.init(remotes)
WorldService.init(GameService.getStage)
LeaderboardService.init(remotes, GameService.profile)
