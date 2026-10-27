--!strict
-- Authoritative clap economy: validates clap batches, awards Applause, handles purchases,
-- auto-clappers, Encore Frenzy and stage breakthroughs.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local Num = require(Shared.Num)

local DataService = require(script.Parent.DataService)
local SocialService = require(script.Parent.SocialService)
local WorldService = require(script.Parent.WorldService)

local T = Config.Tuning
local GameService = {}

type Runtime = {
	state: Formulas.PlayerState,
	tokens: number,
	tokenAt: number,
	combo: number,
	comboDecayedAt: number,
	lastClapAt: number,
	frenzyChain: number, -- remaining doubled claps
	lastBeat: number,
	dirty: boolean,
}

local remotes: Folder
local runtimes: { [Player]: Runtime } = {}

local STATE_SEND_INTERVAL = 0.1
local MAX_BUY = 500

local function snapshot(rt: Runtime): { [string]: any }
	local s = rt.state
	return {
		applause = s.applause,
		clapPower = Formulas.clapPower(s),
		strongHands = s.strongHands,
		techniques = s.techniques,
		classmates = s.classmates,
		stage = s.stage,
		highestStage = s.highestStage,
		runClaps = s.runClaps,
		totalClaps = s.totalClaps,
		frenzy = s.frenzy,
		frenzyChain = rt.frenzyChain,
		combo = rt.combo,
		capped = s.stage >= Config.lastBuiltStage(),
		diplomas = s.diplomas,
		graduations = s.graduations,
		canGraduate = Formulas.canGraduate(s),
		diplomasOnGraduate = Formulas.diplomasFor(s),
	}
end

local function decayCombo(rt: Runtime, now: number)
	local from = math.max(rt.lastClapAt + T.ComboDecayDelay, rt.comboDecayedAt)
	if now > from then
		rt.combo = math.max(1, rt.combo - (now - from) * T.ComboDecayPerSecond)
		rt.comboDecayedAt = now
	end
end

local function tryBreakthrough(player: Player, rt: Runtime)
	local s = rt.state
	local stage = Config.getStage(s.stage)
	if s.stage >= Config.lastBuiltStage() then
		return
	end
	local effective = Formulas.clapPower(s) + math.log10(rt.combo)
	if effective < stage.threshold then
		return
	end
	s.stage += 1
	s.highestStage = math.max(s.highestStage, s.stage)
	rt.dirty = true
	SocialService.broadcast("Breakthrough", {
		userId = player.UserId,
		name = player.DisplayName,
		from = stage.id,
		to = s.stage,
		clap = s.runClaps,
	})
	-- give the client a moment to start the cinematic before moving the character
	task.delay(1.2, function()
		if player.Parent then
			WorldService.place(player, s.stage)
		end
	end)
end

local function onClapBatch(player: Player, count: any, perfectBeats: any)
	local rt = runtimes[player]
	if not rt or type(count) ~= "number" or count ~= count then
		return
	end
	local now = os.clock()

	-- token bucket rate limit
	rt.tokens = math.min(T.MaxClapsPerSecond, rt.tokens + (now - rt.tokenAt) * T.MaxClapsPerSecond)
	rt.tokenAt = now
	local claps = math.clamp(math.floor(count), 0, math.floor(rt.tokens))
	if claps <= 0 then
		return
	end
	rt.tokens -= claps

	-- validate perfect beats: unique, recent, increasing
	local serverBeat = math.floor(workspace:GetServerTimeNow() / T.BeatInterval)
	local perfects = 0
	if type(perfectBeats) == "table" then
		for _, beat in perfectBeats do
			if perfects >= claps then
				break
			end
			if type(beat) == "number" and beat > rt.lastBeat and math.abs(beat - serverBeat) <= 3 then
				rt.lastBeat = beat
				perfects += 1
				SocialService.registerPerfect(player, beat)
			end
		end
	end

	decayCombo(rt, now)
	rt.lastClapAt = now

	local s = rt.state
	local cp = Formulas.clapPower(s)
	local boost = SocialService.ovationMultiplier() * (if SocialService.isInSync(player) then T.InSyncBonus else 1)
	local earned = Num.ZERO
	for i = 1, claps do
		local perfect = i <= perfects
		rt.combo = math.min(T.ComboMax, rt.combo + (if perfect then T.ComboGainPerPerfect else T.ComboGainPerClap))
		local mult = rt.combo * boost * (if perfect then T.PerfectBonus else 1)
		if rt.frenzyChain > 0 then
			local index = T.FrenzyChain - rt.frenzyChain + 1
			mult *= Formulas.frenzyMultiplier(index)
			rt.frenzyChain -= 1
		else
			s.frenzy += 1
			if s.frenzy >= T.FrenzyClapsToFill then
				s.frenzy = 0
				rt.frenzyChain = T.FrenzyChain;
				(remotes.Broadcast :: RemoteEvent):FireClient(player, "Frenzy", { chain = T.FrenzyChain })
			end
		end
		earned = Num.add(earned, cp + math.log10(mult))
	end

	s.applause = Num.add(s.applause, earned)
	s.peakPower = math.max(s.peakPower, cp + math.log10(rt.combo))
	s.runClaps += claps
	s.totalClaps += claps
	rt.dirty = true

	SocialService.addClaps(player, claps, perfects > 0, s.stage)
	tryBreakthrough(player, rt)
end

local function buyOne(rt: Runtime, kind: string, id: string?): (boolean, string?)
	local s = rt.state
	if kind == "hands" then
		local cost = Formulas.strongHandsCost(s.strongHands)
		if not Num.gte(s.applause, cost) then
			return false, "Not enough Applause"
		end
		s.applause = Num.sub(s.applause, cost)
		s.strongHands += 1
		return true
	elseif kind == "technique" then
		local tech = Formulas.nextTechnique(s)
		if not tech or tech.id ~= id then
			return false, "Not available"
		end
		if tech.stage > s.stage then
			return false, "Reach stage " .. tech.stage
		end
		local cost = Formulas.techniqueCost(tech)
		if not Num.gte(s.applause, cost) then
			return false, "Not enough Applause"
		end
		s.applause = Num.sub(s.applause, cost)
		s.techniques[tech.id] = true
		return true
	elseif kind == "classmate" then
		for _, def in Config.Classmates do
			if def.id == id then
				if def.stage > s.stage then
					return false, "Reach stage " .. def.stage
				end
				local owned = s.classmates[def.id] or 0
				local cost = Formulas.classmateCost(def, owned)
				if not Num.gte(s.applause, cost) then
					return false, "Not enough Applause"
				end
				s.applause = Num.sub(s.applause, cost)
				s.classmates[def.id] = owned + 1
				return true
			end
		end
		return false, "Unknown classmate"
	end
	return false, "Unknown purchase"
end

local function onPurchase(player: Player, kind: any, id: any, amount: any): (boolean, string?)
	local rt = runtimes[player]
	if not rt or type(kind) ~= "string" then
		return false, "Not ready"
	end
	if id ~= nil and type(id) ~= "string" then
		return false, "Bad id"
	end
	local times = if amount == "max" then MAX_BUY elseif type(amount) == "number" then math.clamp(math.floor(amount), 1, MAX_BUY) else 1
	local bought, lastErr = 0, nil
	for _ = 1, times do
		local ok, err = buyOne(rt, kind, id)
		if not ok then
			lastErr = err
			break
		end
		bought += 1
		if kind == "technique" then
			break
		end
	end
	if bought > 0 then
		rt.dirty = true
		return true, tostring(bought)
	end
	return false, lastErr
end

local function onGraduate(player: Player): (boolean, string?)
	local rt = runtimes[player]
	if not rt then
		return false, "Not ready"
	end
	local s = rt.state
	if not Formulas.canGraduate(s) then
		return false, "Finish stage " .. T.GraduateStage .. " first"
	end
	local gained = Formulas.diplomasFor(s)
	local fresh = Formulas.newState()
	s.applause = fresh.applause
	s.strongHands = fresh.strongHands
	s.techniques = fresh.techniques
	s.classmates = fresh.classmates
	s.stage = 1
	s.runClaps = 0
	s.frenzy = 0
	s.peakPower = 0
	s.diplomas += gained
	s.graduations += 1
	rt.combo = 1
	rt.frenzyChain = 0
	rt.dirty = true
	SocialService.broadcast("Graduated", {
		userId = player.UserId,
		name = player.DisplayName,
		gained = gained,
		total = s.diplomas,
	})
	task.delay(1.2, function()
		if player.Parent then
			WorldService.place(player, 1)
		end
	end)
	return true, tostring(gained)
end

local function onPlayerAdded(player: Player)
	local state = DataService.load(player)
	if not state then
		player:Kick("We couldn't load your progress safely. Please rejoin in a moment.")
		return
	end
	-- older saves may reference stages that are no longer built
	state.stage = math.clamp(state.stage, 1, Config.lastBuiltStage())
	local now = os.clock()
	runtimes[player] = {
		state = state,
		tokens = T.MaxClapsPerSecond,
		tokenAt = now,
		combo = 1,
		comboDecayedAt = 0,
		lastClapAt = 0,
		frenzyChain = 0,
		lastBeat = -math.huge,
		dirty = true,
	}
	player:SetAttribute("Stage", state.stage)
	player:SetAttribute("Loaded", true)
end

function GameService.getStage(player: Player): number
	local rt = runtimes[player]
	return if rt then rt.state.stage else 1
end

function GameService.init(remoteFolder: Folder)
	remotes = remoteFolder;
	(remotes.ClapBatch :: RemoteEvent).OnServerEvent:Connect(onClapBatch);
	(remotes.Purchase :: RemoteFunction).OnServerInvoke = onPurchase;
	(remotes.Graduate :: RemoteFunction).OnServerInvoke = onGraduate

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		runtimes[player] = nil
	end)

	-- auto-clappers
	local autoAccumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		autoAccumulator += dt
		if autoAccumulator < 0.5 then
			return
		end
		local elapsed = autoAccumulator
		autoAccumulator = 0
		local ovation = SocialService.ovationMultiplier()
		local now = os.clock()
		for _, rt in runtimes do
			decayCombo(rt, now)
			local cps = Formulas.autoClapsPerSecond(rt.state)
			if cps > 0 then
				local earned = Formulas.clapPower(rt.state) + math.log10(cps * elapsed * T.AutoEfficiency * ovation)
				rt.state.applause = Num.add(rt.state.applause, earned)
				rt.dirty = true
			end
		end
	end)

	-- Studio-only test hook: ServerStorage.DevGrant:Invoke(userId, applauseLog?, techniques?)
	if RunService:IsStudio() then
		local grant = Instance.new("BindableFunction")
		grant.Name = "DevGrant"
		grant.OnInvoke = function(userId: number, applauseLog: number?, allTechniquesUpTo: number?)
			for player, rt in runtimes do
				if player.UserId == userId or userId == 0 then
					if applauseLog then
						rt.state.applause = Num.add(rt.state.applause, applauseLog)
					end
					if allTechniquesUpTo then
						for _, tech in Config.Techniques do
							if tech.stage <= allTechniquesUpTo then
								rt.state.techniques[tech.id] = true
							end
						end
					end
					rt.dirty = true
				end
			end
			return true
		end
		grant.Parent = game:GetService("ServerStorage")
	end

	-- state replication to each owner
	task.spawn(function()
		while true do
			task.wait(STATE_SEND_INTERVAL)
			for player, rt in runtimes do
				if rt.dirty and player.Parent then
					rt.dirty = false;
					(remotes.State :: RemoteEvent):FireClient(player, snapshot(rt))
				end
			end
		end
	end)
end

return GameService
