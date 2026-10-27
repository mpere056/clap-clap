--!strict
-- Client entry point: input → local feedback (instant) → batched to the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)

local Audio = require(script.Audio)
local Beat = require(script.Beat)
local CameraRig = require(script.CameraRig)
local Environment = require(script.Environment)
local Hands = require(script.Hands)
local HUD = require(script.HUD)
local StageLighting = require(script.StageLighting)
local Store = require(script.Store)

local T = Config.Tuning
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local clapRemote = remotes:WaitForChild("ClapBatch") :: RemoteEvent
local purchaseRemote = remotes:WaitForChild("Purchase") :: RemoteFunction
local graduateRemote = remotes:WaitForChild("Graduate") :: RemoteFunction
local stateRemote = remotes:WaitForChild("State") :: RemoteEvent
local broadcastRemote = remotes:WaitForChild("Broadcast") :: RemoteEvent
local pulseRemote = remotes:WaitForChild("ClapPulse") :: UnreliableRemoteEvent

local BATCH_INTERVAL = 0.15

local shownStage = 0 -- the stage whose world/camera is currently shown
local inCinematic = false
local pendingClaps = 0
local pendingPerfects: { number } = {}
local lastPerfectBeat = -1
local lastClapAt = 0
local localClapCount = 0
local localCombo = 1
local lastGraduations = -1

----------------------------------------------------------------------------------------------------
-- setup

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)
-- chat lives bottom-left so it doesn't cover the clap counter
pcall(function()
	local chatWindow = game:GetService("TextChatService"):FindFirstChildOfClass("ChatWindowConfiguration")
	if chatWindow then
		chatWindow.VerticalAlignment = Enum.VerticalAlignment.Bottom
	end
end)
task.spawn(function()
	local ok, playerModule = pcall(function()
		local module = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 10)
		return if module then require(module) :: any else nil
	end)
	if ok and playerModule then
		playerModule:GetControls():Disable()
	end
end)

Audio.init()
Environment.init()
Hands.init()
CameraRig.init()
HUD.init(function(kind, id, amount)
	task.spawn(function()
		local ok, result = purchaseRemote:InvokeServer(kind, id, amount)
		if not ok and result then
			HUD.toast(tostring(result), Color3.fromRGB(255, 170, 170), 1.5)
		end
	end)
end, function()
	task.spawn(function()
		local ok, result = graduateRemote:InvokeServer()
		if not ok and result then
			HUD.toast(tostring(result), Color3.fromRGB(255, 170, 170), 2)
		end
	end)
end)

local function progress(): number
	local s = Store.state
	return Formulas.stageProgress(s.stage, s.clapPower)
end

local function applyStage(stageId: number)
	shownStage = stageId
	Environment.setStage(stageId)
	CameraRig.setStage(stageId)
	Hands.setVisible(stageId == 1)
	Environment.setOwnCharacterHidden(stageId == 1)
	StageLighting.apply(stageId)
end

player.CharacterAdded:Connect(function()
	task.wait(0.5)
	Environment.setOwnCharacterHidden(shownStage == 1)
end)

----------------------------------------------------------------------------------------------------
-- clapping

local function clap()
	local now = os.clock()
	if now - lastClapAt < 1 / T.MaxClapsPerSecond or inCinematic or not Store.loaded then
		return
	end
	lastClapAt = now

	local beat, perfect = Beat.check()
	if perfect and beat ~= lastPerfectBeat then
		lastPerfectBeat = beat
		table.insert(pendingPerfects, beat)
	else
		perfect = false
	end
	pendingClaps += 1
	localClapCount += 1

	local s = Store.state
	local t = progress()
	local intensity = (s.stage - 1) + t

	-- predicted Applause for the popup (server stays authoritative)
	localCombo = math.min(T.ComboMax, math.max(localCombo, s.combo or 1) + (if perfect then T.ComboGainPerPerfect else T.ComboGainPerClap))
	local mult = localCombo * (if perfect then T.PerfectBonus else 1)
	HUD.popup(s.clapPower + math.log10(mult), perfect)
	if perfect then
		HUD.perfect()
	end

	Hands.clap(1 + t)
	CameraRig.clap(intensity)
	Audio.clap(intensity, perfect)
	Environment.selfClap(intensity, perfect)
	if s.stage == 1 then
		HUD.screenRing(perfect, t)
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	local t = input.UserInputType
	if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
		clap()
	elseif input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonR2 or input.KeyCode == Enum.KeyCode.ButtonA then
		clap()
	end
end)

task.spawn(function()
	while true do
		task.wait(BATCH_INTERVAL)
		if pendingClaps > 0 then
			clapRemote:FireServer(pendingClaps, pendingPerfects)
			pendingClaps = 0
			pendingPerfects = {}
		end
	end
end)

----------------------------------------------------------------------------------------------------
-- server → client

stateRemote.OnClientEvent:Connect(function(snapshot)
	Store.set(snapshot)
	if snapshot.graduations ~= lastGraduations then
		-- a new run: the clap counter starts again
		lastGraduations = snapshot.graduations
		localClapCount = snapshot.runClaps
	end
	localClapCount = math.max(localClapCount, snapshot.runClaps)
	localCombo = snapshot.combo or 1
	Environment.setHired(Formulas.totalClassmates(snapshot))
	if shownStage == 0 then
		applyStage(snapshot.stage)
	end
end)

local function playBreakthrough(toStage: number)
	inCinematic = true
	local stage = Config.getStage(toStage)
	local fromStage = Config.getStage(toStage - 1)
	HUD.lockCaption(true)
	HUD.setCaption(fromStage.breakthroughCaption)
	Audio.breakthrough()
	CameraRig.breakthrough()
	task.wait(0.5)
	HUD.whiteOut(0.8)
	task.wait(0.9)
	-- wait for the server to move us into the new world
	local deadline = os.clock() + 5
	while os.clock() < deadline do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and (root.Position - stage.origin).Magnitude < 1500 then
			break
		end
		task.wait(0.1)
	end
	applyStage(toStage)
	CameraRig.endTransition()
	HUD.flash(0.15)
	HUD.toast(string.format("STAGE %d · %s  %s", stage.id, string.upper(stage.name), stage.jp), Color3.fromRGB(232, 184, 102), 4)
	HUD.lockCaption(false)
	inCinematic = false
end

-- back to the ceremony after graduating
local function playGraduation(gained: number, total: number)
	inCinematic = true
	HUD.lockCaption(true)
	HUD.setCaption("You graduated. Then you sat back down.", "卒業おめでとう")
	Audio.breakthrough()
	CameraRig.breakthrough()
	task.wait(0.5)
	HUD.whiteOut(0.8)
	task.wait(0.9)
	local origin = Config.getStage(1).origin
	local deadline = os.clock() + 5
	while os.clock() < deadline do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and (root.Position - origin).Magnitude < 1500 then
			break
		end
		task.wait(0.1)
	end
	applyStage(1)
	CameraRig.endTransition()
	HUD.flash(0.15)
	HUD.toast(string.format("🎓 +%d Diplomas · %d total · +%d%% clap power", gained, total, math.floor(total * T.DiplomaBonus * 100 + 0.5)), Color3.fromRGB(255, 150, 175), 5)
	HUD.lockCaption(false)
	inCinematic = false
end

broadcastRemote.OnClientEvent:Connect(function(kind: string, data: any)
	if kind == "Graduated" then
		if data.userId == player.UserId then
			task.spawn(playGraduation, data.gained, data.total)
		else
			HUD.toast(string.format("🎓 %s graduated with %d Diplomas!", data.name, data.gained), Color3.fromRGB(255, 150, 175))
		end
	elseif kind == "Breakthrough" then
		if data.userId == player.UserId then
			task.spawn(playBreakthrough, data.to)
		else
			HUD.toast(string.format("%s broke through to %s!", data.name, Config.getStage(data.to).name))
		end
	elseif kind == "Ovation" then
		HUD.toast(
			string.format("STANDING OVATION! ×%d Applause for everyone · %s", T.OvationMultiplier, "5:00"),
			Color3.fromRGB(232, 184, 102),
			5
		)
		Environment.ovation()
		Audio.breakthrough()
		CameraRig.bigShake(1.5)
	elseif kind == "InSync" then
		local includesMe = table.find(data.userIds, player.UserId) ~= nil
		Environment.inSync(data.userIds)
		if includesMe then
			HUD.toast(string.format("IN SYNC ×%s! %d players on the beat", tostring(T.InSyncBonus), #data.userIds), Color3.fromRGB(232, 184, 102), 1.6)
		end
	elseif kind == "Frenzy" then
		HUD.toast(string.format("ENCORE! The next %d claps each double!", data.chain), Color3.fromRGB(255, 150, 175), 3)
		CameraRig.bigShake(0.8)
	end
end)

pulseRemote.OnClientEvent:Connect(function(userId: number, stage: number, count: number, perfect: boolean, inSync: boolean)
	Environment.otherClap(userId, stage, count, perfect, inSync)
end)

----------------------------------------------------------------------------------------------------
-- per frame

local hudAccumulator = 0
RunService.RenderStepped:Connect(function(dt)
	if not Store.loaded then
		return
	end
	local t = if inCinematic then 1 else progress()
	if shownStage == Store.state.stage then
		CameraRig.setProgress(t)
		Environment.setProgress(t)
		Audio.setStage(shownStage, t)
	end
	hudAccumulator += dt
	if hudAccumulator >= 0.05 then
		hudAccumulator = 0
		HUD.setPredictedClaps(math.max(0, localClapCount - Store.state.runClaps))
		HUD.update(if shownStage == Store.state.stage then t else 1, math.max(shownStage, 1))
	end
end)
