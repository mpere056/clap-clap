--!strict
-- Places each player's character in the stage world they've reached.
-- Each stage model in workspace.Stages has a "Spots" folder of Seats or Parts.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local WorldService = {}

local occupied: { [Instance]: Player } = {}
local playerSpot: { [Player]: Instance } = {}

local function stageModel(stageId: number): Instance?
	local stages = workspace:FindFirstChild("Stages")
	return stages and stages:FindFirstChild(Config.getStage(stageId).key)
end

local function release(player: Player)
	local spot = playerSpot[player]
	if spot then
		occupied[spot] = nil
		playerSpot[player] = nil
	end
end

local function claimSpot(player: Player, stageId: number): Instance?
	local model = stageModel(stageId)
	local spots = model and model:FindFirstChild("Spots")
	if not spots then
		return nil
	end
	-- fill the most central spots first
	local center = (model :: Model):GetPivot().Position
	local function distance(spot: Instance): number
		local offset = (spot :: BasePart).Position - center
		return Vector2.new(offset.X, offset.Z).Magnitude
	end
	local list = spots:GetChildren()
	table.sort(list, function(a, b)
		return distance(a) < distance(b)
	end)
	for _, spot in list do
		if not occupied[spot] then
			occupied[spot] = player
			playerSpot[player] = spot
			return spot
		end
	end
	return list[1] -- overflow: share the first spot
end

function WorldService.place(player: Player, stageId: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (character and humanoid and root) then
		return
	end
	release(player)
	local spot = claimSpot(player, stageId)
	player:SetAttribute("Stage", stageId)
	if not spot then
		return
	end

	root.Anchored = false
	humanoid.Sit = false
	local currentSeat = humanoid.SeatPart
	if currentSeat then
		-- the seat weld would drag the character back to the old seat
		local weld = currentSeat:FindFirstChild("SeatWeld")
		if weld then
			weld:Destroy()
		end
		task.wait()
	end
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0
	humanoid.WalkSpeed = 0

	local spotPart = spot :: BasePart
	character:PivotTo(spotPart.CFrame * CFrame.new(0, 3, 0))
	if spot:IsA("Seat") then
		task.defer(function()
			(spot :: Seat):Sit(humanoid)
		end)
	else
		root.Anchored = true
		character:PivotTo(spotPart.CFrame * CFrame.new(0, 3 + humanoid.HipHeight, 0))
	end
end

function WorldService.init(getStage: (Player) -> number)
	local function onCharacter(player: Player, character: Model)
		character:WaitForChild("HumanoidRootPart")
		while not player:GetAttribute("Loaded") and player.Parent do
			task.wait(0.1)
		end
		task.wait(0.2)
		WorldService.place(player, getStage(player))
	end
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
	Players.PlayerRemoving:Connect(release)
end

return WorldService
