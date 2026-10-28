--!strict
-- Client entry point: input → graded locally for instant feedback → timestamps batched to the
-- server, which grades them again authoritatively.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Formulas = require(Shared.Formulas)
local Events = require(Shared.Events)

local Ads = require(script.Ads)
local Audio = require(script.Audio)
local Beat = require(script.Beat)
local CameraRig = require(script.CameraRig)
local Environment = require(script.Environment)
local EventTheme = require(script.EventTheme)
local EventUI = require(script.EventUI)
local Hands = require(script.Hands)
local HUD = require(script.HUD)
local Leaderboards = require(script.Leaderboards)
local UpdateBoard = require(script.UpdateBoard)
local StageLighting = require(script.StageLighting)
local Store = require(script.Store)

local T = Config.Tuning
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local clapRemote = remotes:WaitForChild("ClapBatch") :: RemoteEvent
local purchaseRemote = remotes:WaitForChild("Purchase") :: RemoteFunction
local curtainCallRemote = remotes:WaitForChild("CurtainCall") :: RemoteFunction
local rebirthRemote = remotes:WaitForChild("Rebirth") :: RemoteFunction
local settingsRemote = remotes:WaitForChild("Settings") :: RemoteEvent
local walkRemote = remotes:WaitForChild("Walk") :: RemoteEvent
local watchAdRemote = remotes:WaitForChild("WatchAd") :: RemoteEvent
local eventShopRemote = remotes:WaitForChild("EventShop") :: RemoteFunction
local equipRemote = remotes:WaitForChild("Equip") :: RemoteEvent
local travelRemote = remotes:WaitForChild("Travel") :: RemoteFunction
local stateRemote = remotes:WaitForChild("State") :: RemoteEvent
local broadcastRemote = remotes:WaitForChild("Broadcast") :: RemoteEvent
local pulseRemote = remotes:WaitForChild("ClapPulse") :: UnreliableRemoteEvent
local leaderboardRemote = remotes:WaitForChild("Leaderboard") :: RemoteEvent

local BATCH_INTERVAL = 0.15
local GOLD = Color3.fromRGB(232, 184, 102)
local PINK = Color3.fromRGB(255, 150, 175)

local shownStage = 0 -- the stage whose world/camera is currently shown
local inCinematic = false
local pendingTimes: { number } = {}
local lastClapAt = 0
local lastClapBeat = -math.huge
local lastGoodBeat = -math.huge
local localStreak = 0
local localClapCount = 0
local lastRunKey = ""
local lastBeatIndex = 0
local walking = false
local aerial = true -- stages 2+: the stage's wide camera (true) or the close follow camera
local standRequestedAt = 0

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
local applyBody: () -> ()

local function invoke(remote: RemoteFunction, ...: any)
	local args = table.pack(...)
	task.spawn(function()
		local ok, result = remote:InvokeServer(table.unpack(args, 1, args.n))
		if not ok and result then
			HUD.toast(tostring(result), Color3.fromRGB(255, 170, 170), 1.8)
		end
	end)
end

Audio.init()
Environment.init()
Leaderboards.init(leaderboardRemote)
Ads.init(watchAdRemote)
EventTheme.init()
UpdateBoard.init()
EventUI.init(function(itemId)
	invoke(eventShopRemote, itemId)
end, function(slot, itemId)
	equipRemote:FireServer(slot, itemId)
end)

-- the event look follows both the running event and the stage on screen
local function applyEventTheme(freshLighting: boolean?)
	local event = Events.get(ReplicatedStorage:GetAttribute("EventId") :: string?)
	local stageId = math.max(shownStage, 1)
	EventTheme.apply(if event then event.theme else "", stageId, Config.getStage(stageId).key, freshLighting)
end
ReplicatedStorage:GetAttributeChangedSignal("EventId"):Connect(function()
	applyEventTheme()
end)
Hands.init()
CameraRig.init()
HUD.init({
	buy = function(kind, id, amount)
		invoke(purchaseRemote, kind, id, amount)
	end,
	curtainCall = function()
		invoke(curtainCallRemote)
	end,
	rebirth = function()
		invoke(rebirthRemote)
	end,
	setting = function(key, value)
		settingsRemote:FireServer(key, value)
	end,
	view = function()
		aerial = not aerial
		applyBody()
	end,
	travel = function(stageId)
		invoke(travelRemote, stageId)
	end,
})

local function visiting(): boolean
	local s = Store.state
	return (s.view or s.stage) < s.stage
end

-- progress through the stage on screen (visitors have maxed it out; Space fills by clapping)
local function progress(): number
	local s = Store.state
	return Formulas.progress(s :: any, s.view or s.stage)
end

-- how hard claps hit: grows with the furthest stage reached (and Rebirths), so visitors clap at
-- full force; the "clap power shown" setting tones it down
local function intensity(): number
	local s = Store.state
	return ((s.stage - 1) + progress() + (s.rebirths or 0)) * (s.powerDisplay or 1)
end

-- seated: the stage's cinematic camera (first person in the hall); walking: the normal follow
-- camera. On stages 2+ the View button swaps between the wide stage camera and the close one.
function applyBody()
	local firstPerson = shownStage == 1 and not walking
	local close = if shownStage == 1 then walking else not aerial
	Hands.setVisible(firstPerson)
	Environment.setOwnCharacterHidden(firstPerson)
	Environment.setWalking(walking)
	CameraRig.setWalking(close)
	HUD.setView(shownStage >= 2 and shownStage <= T.MaxWalkStage, aerial)
end

player:GetAttributeChangedSignal("Walking"):Connect(function()
	walking = player:GetAttribute("Walking") == true
	-- getting up brings the camera in close; sitting back down goes wide again
	aerial = not walking
	applyBody()
	Environment.walkingChanged(walking)
end)

-- moving or jumping while seated gets you up (on stages with ground to walk on)
local function standUp()
	local now = os.clock()
	if walking or inCinematic or not Store.loaded or shownStage > T.MaxWalkStage or now - standRequestedAt < 1 then
		return
	end
	standRequestedAt = now
	walkRemote:FireServer(true)
end
UserInputService.JumpRequest:Connect(standUp)
Environment.setStandUp(standUp)

local function applyStage(stageId: number)
	shownStage = stageId
	aerial = not walking
	Environment.setStage(stageId)
	CameraRig.setStage(stageId)
	applyBody()
	StageLighting.apply(stageId)
	UpdateBoard.place(stageId, Config.getStage(stageId).key)
	applyEventTheme(true)
	Audio.setSpace(stageId >= 9)
end

player.CharacterAdded:Connect(function()
	task.wait(0.5)
	applyBody()
end)

----------------------------------------------------------------------------------------------------
-- clapping

local function clap()
	local clock = os.clock()
	if clock - lastClapAt < 1 / T.MaxClapsPerSecond or inCinematic or not Store.loaded then
		return
	end
	lastClapAt = clock

	-- grade it now for instant feedback; the server grades the same timestamp again
	local now = Beat.now()
	local beat = math.floor(now / T.BeatInterval + 0.5)
	local grade = Formulas.grade(math.abs(now - beat * T.BeatInterval), beat == lastClapBeat)
	lastClapBeat = beat
	table.insert(pendingTimes, now)
	localClapCount += 1

	local s = Store.state
	local cp = Formulas.clapPowerAt(s :: any, s.view or s.stage)
	if grade == "Miss" then
		localStreak = 0
		HUD.grade(grade, cp + math.log10(T.MissPenaltyClaps), 1)
	else
		if beat - lastGoodBeat > T.StreakGraceBeats + 1 then
			localStreak = 0
		end
		localStreak += 1
		lastGoodBeat = beat
		local combo = Formulas.comboFor(localStreak)
		HUD.grade(grade, cp + math.log10(combo * T.GradeMultipliers[grade]), combo, localStreak)
	end

	local power = intensity()
	Hands.clap(if grade == "Miss" then 0.4 else 1 + progress())
	CameraRig.clap(power, grade)
	Audio.clap(power, grade)
	Environment.selfClap(Formulas.clapForce(s :: any, s.view or s.stage) * (s.powerDisplay or 1), grade, visiting())
	if shownStage == 1 then
		HUD.screenRing(grade, progress())
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	local t = input.UserInputType
	if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
		clap()
	elseif input.KeyCode == Enum.KeyCode.ButtonR2 or input.KeyCode == Enum.KeyCode.F then
		clap()
	end
end)

task.spawn(function()
	while true do
		task.wait(BATCH_INTERVAL)
		if #pendingTimes > 0 then
			clapRemote:FireServer(pendingTimes)
			pendingTimes = {}
		end
	end
end)

----------------------------------------------------------------------------------------------------
-- server → client

stateRemote.OnClientEvent:Connect(function(snapshot)
	Store.set(snapshot)
	local runKey = snapshot.curtainCalls .. ":" .. snapshot.rebirths
	if runKey ~= lastRunKey then
		-- a new run (Curtain Call or Rebirth): the clap counter starts again
		lastRunKey = runKey
		localClapCount = snapshot.runClaps
	end
	localClapCount = math.max(localClapCount, snapshot.runClaps)
	-- trust the server's streak once our own claps have settled
	if os.clock() - lastClapAt > 0.8 then
		localStreak = snapshot.streak or 0
	end
	Environment.setHired(Formulas.totalClassmates(snapshot))
	if shownStage == 0 then
		applyStage(snapshot.view or snapshot.stage)
	end
end)

-- shared transition: optional rise + white-out, wait to be moved, then show the new stage
local function transition(toStage: number, caption: string?, jp: string?, big: boolean)
	inCinematic = true
	HUD.lockCaption(true)
	if caption and caption ~= "" then
		HUD.setCaption(caption, jp)
	end
	if big then
		Audio.breakthrough()
		CameraRig.breakthrough()
		task.wait(0.5)
	end
	HUD.whiteOut(if big then 0.8 else 0.35)
	task.wait(if big then 0.9 else 0.4)
	local origin = Config.getStage(toStage).origin
	local deadline = os.clock() + 5
	while os.clock() < deadline do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and (root.Position - origin).Magnitude < 2500 then
			break
		end
		task.wait(0.1)
	end
	applyStage(toStage)
	CameraRig.endTransition()
	HUD.flash(0.15)
	HUD.lockCaption(false)
	inCinematic = false
end

local function stageToast(stageId: number, prefix: string?)
	local stage = Config.getStage(stageId)
	HUD.toast(string.format("%sSTAGE %d · %s  %s", prefix or "", stage.id, string.upper(stage.name), stage.jp), GOLD, 4)
end

broadcastRemote.OnClientEvent:Connect(function(kind: string, data: any)
	if kind == "CurtainCall" then
		if data.userId == player.UserId then
			task.spawn(function()
				transition(1, "You took a bow. The audience threw flowers.", "カーテンコール", true)
				Environment.bouquetShower()
				HUD.toast(string.format("💐 +%s Bouquets · %s total · clap power ×%s", Format.number(data.gained), Format.number(data.total), Format.number(Formulas.bouquetMultiplier(data.total))), PINK, 5)
			end)
		else
			HUD.toast(string.format("🎭 %s took a Curtain Call (+%s 💐)", data.name, Format.number(data.gained)), PINK)
		end
	elseif kind == "Rebirth" then
		if data.userId == player.UserId then
			task.spawn(function()
				transition(1, "Reborn. Everything is quiet again. For now.", "転生", true)
				HUD.toast(string.format("🕊 REBIRTH %d · clap power ×%s forever", data.rebirths, Format.number(T.RebirthPowerMultiplier ^ data.rebirths)), Color3.fromRGB(150, 205, 255), 6)
			end)
		else
			HUD.toast(string.format("🕊 %s was REBORN (Rebirth %d)!", data.name, data.rebirths), Color3.fromRGB(150, 205, 255), 5)
		end
	elseif kind == "RebirthReady" then
		if data.userId == player.UserId then
			HUD.toast("🕊 You've beaten Space! Rebirth is ready.", Color3.fromRGB(150, 205, 255), 6)
			Environment.ovation()
		else
			HUD.toast(string.format("🕊 %s has beaten Space!", data.name), Color3.fromRGB(150, 205, 255), 5)
		end
	elseif kind == "Breakthrough" then
		if data.userId == player.UserId then
			task.spawn(function()
				transition(data.to, Config.getStage(data.to - 1).breakthroughCaption, nil, true)
				stageToast(data.to)
			end)
		else
			HUD.toast(string.format("%s broke through to %s!", data.name, Config.getStage(data.to).name))
		end
	elseif kind == "Travel" then
		task.spawn(function()
			local best = Store.state.stage
			local caption = if data.to < best then "You're back. They remember you." else nil
			transition(data.to, caption, nil, false)
			stageToast(data.to, if data.to < best then "VISITING · " else nil)
			if data.to < best then
				local back = best - data.to
				local d = (1 / T.VisitorGainPerStageBack) ^ back
				local divisor = if d < 1e4 then string.format("%d", math.floor(d + 0.5)) else string.format("10^%d", math.floor(math.log10(d) + 0.5))
				HUD.toast(string.format("Visiting %d stage%s back: Applause ÷%s per clap. Your claps hit much harder here!", back, if back == 1 then "" else "s", divisor), PINK, 5)
			end
		end)
	elseif kind == "Ovation" then
		HUD.toast(string.format("STANDING OVATION! ×%d Applause for everyone · 5:00", T.OvationMultiplier), GOLD, 5)
		Environment.ovation()
		Audio.breakthrough()
		CameraRig.bigShake(1.5)
	elseif kind == "InSync" then
		local includesMe = table.find(data.userIds, player.UserId) ~= nil
		Environment.inSync(data.userIds)
		if includesMe then
			HUD.toast(string.format("IN SYNC ×%s! %d players on the beat", tostring(T.InSyncBonus), #data.userIds), GOLD, 1.6)
		end
	elseif kind == "TierUp" then
		HUD.tierUp(data.tier, data.count, data.name, data.jp, data.bonus)
		Environment.tierBurst()
		Audio.tierUp(data.tier)
		CameraRig.bigShake(0.5 + data.tier * 0.15)
	elseif kind == "Frenzy" then
		HUD.toast(string.format("ENCORE! The next %d on-beat claps each double!", data.chain), PINK, 3)
		CameraRig.bigShake(0.8)
	elseif kind == "EventDrop" then
		EventUI.drop(data.amount, data.icon)
	elseif kind == "Rush" then
		HUD.toast(string.format("⚡ %s! %d× %s for %d seconds, clap on the beat!", string.upper(data.name), data.multiplier, data.icon, data.seconds), Color3.fromRGB(255, 180, 90), 5)
		CameraRig.bigShake(0.6)
	elseif kind == "BoostGranted" then
		HUD.toast(
			string.format("%s ×2 Applause for %d minutes!", if data.fromAd then "📺 Thanks for watching!" else "⚡ Thanks for your support!", data.minutes),
			GOLD,
			4
		)
		Environment.bouquetShower()
	elseif kind == "TopPlayer" then
		HUD.toast(string.format("👑 #%d in the world, %s, is in this server!", data.rank, data.name), GOLD, 6)
	elseif kind == "Assisted" then
		HUD.toast(string.format("⭐ %s (Stage %d) is charging your Encore!", data.name, data.stage), PINK, 3)
	elseif kind == "AssistGiven" then
		HUD.toast(string.format("⭐ Your claps are charging %d players' Encores", data.players), PINK, 3)
	end
end)

pulseRemote.OnClientEvent:Connect(function(userId: number, stage: number, count: number, perfect: boolean, inSync: boolean, visitor: number?, force: number?)
	Environment.otherClap(userId, stage, count, perfect, inSync, visitor or 0, force or 0)
end)

----------------------------------------------------------------------------------------------------
-- per frame

local hudAccumulator = 0
RunService.RenderStepped:Connect(function(dt)
	if not Store.loaded then
		return
	end
	-- metronome
	local beatIndex = math.floor(Beat.now() / T.BeatInterval)
	if beatIndex ~= lastBeatIndex then
		lastBeatIndex = beatIndex
		Audio.tick(beatIndex)
	end

	local s = Store.state
	local view = s.view or s.stage
	-- the humanoid still reports which way you're pushing while the seat holds you
	local humanoid = if walking then nil else player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.MoveDirection.Magnitude > 0.3 then
		standUp()
	end
	local t = if inCinematic then 1 else progress()
	if shownStage == view then
		CameraRig.setProgress(t)
		Environment.setProgress(t)
		Audio.setStage(shownStage, t)
	end
	hudAccumulator += dt
	if hudAccumulator >= 0.05 then
		hudAccumulator = 0
		HUD.setPredictedClaps(math.max(0, localClapCount - s.runClaps))
		HUD.setStreak(localStreak)
		HUD.update(if shownStage == view then t else 1, math.max(shownStage, 1))
	end
end)
