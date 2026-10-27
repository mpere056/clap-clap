--!strict
-- Server entry point.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local DataService = require(script.DataService)
local GameService = require(script.GameService)
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
remote("RemoteEvent", "State")
remote("RemoteEvent", "Broadcast")
remote("UnreliableRemoteEvent", "ClapPulse")
remotes.Parent = ReplicatedStorage

DataService.init()
SocialService.init(remotes)
GameService.init(remotes)
WorldService.init(GameService.getStage)
