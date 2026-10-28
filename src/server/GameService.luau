--!strict
-- Authoritative clap economy: grades every clap against the shared beat, awards (or docks)
-- Applause, handles purchases, auto-clappers, Encore Frenzy, tiers, breakthroughs, travelling
-- back to earlier stages, Curtain Calls (prestige), Space's escape velocity and Rebirth.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local Num = require(Shared.Num)
local Events = require(Shared.Events)

local DataService = require(script.Parent.DataService)
local EventService = require(script.Parent.EventService)
local MonetisationService = require(script.Parent.MonetisationService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local SocialService = require(script.Parent.SocialService)
local WorldService = require(script.Parent.WorldService)

local T = Config.Tuning
local GameService = {}

type Runtime = {
	state: Formulas.PlayerState,
	tokens: number,
	tokenAt: number,
	streak: number, -- consecutive on-beat claps
	lastGoodBeat: number,
	lastClapBeat: number, -- a second clap in the same beat is a miss
	lastClapTime: number, -- server time of the last accepted clap
	frenzyChain: number, -- remaining doubled claps
	view: number, -- stage the player is standing in (lower than state.stage when visiting)
	assistNoticeAt: number,
	dirty: boolean,
}

local remotes: Folder
local runtimes: { [Player]: Runtime } = {}

local STATE_SEND_INTERVAL = 0.1
local MAX_BUY = 500
local MAX_CLAP_AGE = 2 -- seconds; older claps in a batch are ignored

local function broadcastTo(player: Player, kind: string, data: { [string]: any })
	(remotes.Broadcast :: RemoteEvent):FireClient(player, kind, data)
end

local function combo(rt: Runtime): number
	return Formulas.comboFor(rt.streak)
end

local function snapshot(rt: Runtime): { [string]: any }
	local s = rt.state
	return {
		applause = s.applause,
		clapPower = Formulas.clapPower(s),
		strongHands = s.strongHands,
		techniques = s.techniques,
		classmates = s.classmates,
		stage = s.stage,
		view = rt.view,
		highestStage = s.highestStage,
		runClaps = s.runClaps,
		goodClaps = s.goodClaps,
		totalClaps = s.totalClaps,
		frenzy = s.frenzy,
		frenzyChain = rt.frenzyChain,
		streak = rt.streak,
		combo = combo(rt),
		capped = s.stage >= Config.lastBuiltStage(),
		peakPower = s.peakPower,
		tier = s.tier,
		bouquets = s.bouquets,
		curtainCalls = s.curtainCalls,
		canCurtainCall = Formulas.canCurtainCall(s) and rt.view == s.stage,
		bouquetsOnCall = Formulas.bouquetsFor(s),
		spaceProgress = s.spaceProgress,
		rebirths = s.rebirths,
		canRebirth = Formulas.canRebirth(s),
		boostEndsAt = s.boostEndsAt,
		eventCurrency = s.eventCurrency,
		cosmetics = s.cosmetics,
		equipped = s.equipped,
		powerDisplay = s.powerDisplay,
		showCosmetics = s.showCosmetics,
	}
end

-- attributes other clients read to draw titles, wings/halos and scale this player's claps
local function publishProfile(player: Player, rt: Runtime)
	local s = rt.state
	player:SetAttribute("Stage", rt.view)
	player:SetAttribute("BestStage", s.stage)
	player:SetAttribute("Rebirths", s.rebirths)
	player:SetAttribute("PowerDisplay", s.powerDisplay)
	player:SetAttribute("ShowCosmetics", s.showCosmetics)
	for _, slot in { "wings", "trail", "title" } do
		local item = s.equipped[slot] and Events.item(s.equipped[slot])
		player:SetAttribute("Equipped_" .. slot, if item then item.style else nil)
	end
end

local function setView(player: Player, rt: Runtime, stageId: number)
	rt.view = stageId
	publishProfile(player, rt)
end

-- wipe the current run (shared by Curtain Call and Rebirth)
local function resetRun(rt: Runtime)
	local s = rt.state
	local fresh = Formulas.newState()
	s.applause = fresh.applause
	s.strongHands = fresh.strongHands
	s.techniques = fresh.techniques
	s.classmates = fresh.classmates
	s.stage = 1
	s.runClaps = 0
	s.goodClaps = 0
	s.frenzy = 0
	s.peakPower = 0
	s.tier = 0
	rt.streak = 0
	rt.frenzyChain = 0
end

-- Tier-ups: milestones inside a stage, each paying a bonus that grows with the tier number
local function checkTier(player: Player, rt: Runtime)
	local s = rt.state
	local reached = Formulas.tierAt(s.stage, Formulas.progress(s, s.stage))
	if reached <= s.tier then
		return
	end
	local cp = Formulas.clapPower(s)
	local bonus = Num.ZERO
	for tier = s.tier + 1, reached do
		bonus = Num.add(bonus, cp + math.log10(T.TierRewardClaps * tier))
	end
	s.tier = reached
	s.applause = Num.add(s.applause, bonus)
	rt.dirty = true
	local info = Config.getStage(s.stage).tiers[reached]
	broadcastTo(player, "TierUp", {
		stage = s.stage,
		tier = reached,
		count = #Config.getStage(s.stage).tiers,
		name = info.name,
		jp = info.jp,
		bonus = bonus,
	})
end

local function tryBreakthrough(player: Player, rt: Runtime)
	local s = rt.state
	local stage = Config.getStage(s.stage)
	if s.stage >= Config.lastBuiltStage() or rt.view ~= s.stage then
		return
	end
	local effective = Formulas.clapPower(s) + math.log10(combo(rt))
	if effective < stage.threshold then
		return
	end
	s.stage += 1
	s.tier = 0
	s.highestStage = math.max(s.highestStage, s.stage)
	setView(player, rt, s.stage)
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
			WorldService.place(player, rt.view)
		end
	end)
end

local function addFrenzy(player: Player, rt: Runtime, amount: number)
	if rt.frenzyChain > 0 then
		return
	end
	local s = rt.state
	s.frenzy += amount
	if s.frenzy >= T.FrenzyClapsToFill then
		s.frenzy = 0
		rt.frenzyChain = T.FrenzyChain
		broadcastTo(player, "Frenzy", { chain = T.FrenzyChain })
	end
	rt.dirty = true
end

-- A stronger player visiting an earlier stage charges everyone else's Encore there
local function assistEncores(player: Player, rt: Runtime, good: number)
	local level = rt.state.stage - rt.view
	if level <= 0 or good <= 0 then
		return
	end
	local helped = 0
	for other, ort in runtimes do
		if other ~= player and ort.view == rt.view then
			addFrenzy(other, ort, good * T.VisitorEncoreAssist * level)
			helped += 1
			local now = os.clock()
			if now - ort.assistNoticeAt > 15 then
				ort.assistNoticeAt = now
				broadcastTo(other, "Assisted", { name = player.DisplayName, stage = rt.state.stage })
			end
		end
	end
	local now = os.clock()
	if helped > 0 and now - rt.assistNoticeAt > 15 then
		rt.assistNoticeAt = now
		broadcastTo(player, "AssistGiven", { players = helped })
	end
end

-- times: server timestamps (workspace:GetServerTimeNow()) of each clap, oldest first
local function onClapBatch(player: Player, times: any)
	local rt = runtimes[player]
	if not rt or type(times) ~= "table" then
		return
	end
	local clock = os.clock()
	rt.tokens = math.min(T.MaxClapsPerSecond, rt.tokens + (clock - rt.tokenAt) * T.MaxClapsPerSecond)
	rt.tokenAt = clock
	local allowed = math.floor(rt.tokens)

	local s = rt.state
	local serverNow = workspace:GetServerTimeNow()
	local cp = Formulas.clapPowerAt(s, rt.view)
	local boost = SocialService.ovationMultiplier()
		* (if SocialService.isInSync(player) then T.InSyncBonus else 1)
		* (if os.time() < s.boostEndsAt then Config.Ads.BoostMultiplier else 1)
	local earned, penalty = Num.ZERO, Num.ZERO
	local total, good, misses = 0, 0, 0
	local inSpace = rt.view == s.stage and s.stage == Config.lastBuiltStage()
	local drops = 0
	local wasRebirthReady = Formulas.canRebirth(s)
	local anyPerfect = false

	for _, t in times do
		if total >= allowed then
			break
		end
		if type(t) ~= "number" or t ~= t or t <= rt.lastClapTime or t > serverNow + 0.25 or t < serverNow - MAX_CLAP_AGE then
			continue
		end
		total += 1
		rt.lastClapTime = t
		local beat = math.floor(t / T.BeatInterval + 0.5)
		local grade = Formulas.grade(math.abs(t - beat * T.BeatInterval), beat == rt.lastClapBeat)
		rt.lastClapBeat = beat
		if grade == "Miss" then
			misses += 1
			rt.streak = 0
			penalty = Num.add(penalty, cp + math.log10(T.MissPenaltyClaps))
			continue
		end
		if beat - rt.lastGoodBeat > T.StreakGraceBeats + 1 then
			rt.streak = 0
		end
		rt.streak += 1
		rt.lastGoodBeat = beat
		good += 1
		local mult = combo(rt) * T.GradeMultipliers[grade] * boost
		if rt.frenzyChain > 0 then
			mult *= Formulas.frenzyMultiplier(T.FrenzyChain - rt.frenzyChain + 1)
			rt.frenzyChain -= 1
		else
			addFrenzy(player, rt, 1)
		end
		earned = Num.add(earned, cp + math.log10(mult))
		drops += EventService.dropFor(grade)
		if inSpace then
			s.spaceProgress = math.min(T.SpaceGoal, s.spaceProgress + combo(rt) * T.GradeMultipliers[grade])
		end
		if grade ~= "Good" then
			anyPerfect = true
			SocialService.registerPerfect(player, beat)
		end
	end
	if total == 0 then
		return
	end
	rt.tokens -= total

	s.applause = Num.sub(Num.add(s.applause, earned), penalty)
	if drops > 0 then
		local event = EventService.active()
		if event then
			s.eventCurrency[event.id] = (s.eventCurrency[event.id] or 0) + drops
			broadcastTo(player, "EventDrop", { amount = drops, icon = event.currency.icon })
		end
	end
	s.runClaps += total
	s.totalClaps += total
	s.goodClaps += good
	rt.dirty = true

	SocialService.addClaps(player, total, good, anyPerfect, rt.view, s.stage - rt.view, Formulas.clapForce(s, rt.view) * (s.powerDisplay or 1))
	assistEncores(player, rt, good)
	if rt.view == s.stage then
		s.peakPower = math.max(s.peakPower, Formulas.clapPower(s) + math.log10(combo(rt)))
		s.bestPower = math.max(s.bestPower, s.peakPower)
		checkTier(player, rt)
		tryBreakthrough(player, rt)
	end
	if not wasRebirthReady and Formulas.canRebirth(s) then
		SocialService.broadcast("RebirthReady", { userId = player.UserId, name = player.DisplayName })
	end
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

-- go back to (or return from) an earlier stage you've already reached this run
local function onTravel(player: Player, stageId: any): (boolean, string?)
	local rt = runtimes[player]
	if not rt or type(stageId) ~= "number" or stageId ~= math.floor(stageId) then
		return false, "Not ready"
	end
	if stageId < 1 or stageId > rt.state.stage then
		return false, "You haven't reached that stage yet"
	end
	if stageId == rt.view then
		return false, "You're already here"
	end
	local from = rt.view
	setView(player, rt, stageId)
	rt.dirty = true
	broadcastTo(player, "Travel", { from = from, to = stageId })
	task.delay(0.9, function()
		if player.Parent then
			WorldService.place(player, rt.view)
		end
	end)
	return true
end

-- Curtain Call: take a bow and start the show again, keeping Bouquets (+10% power each)
local function onCurtainCall(player: Player): (boolean, string?)
	local rt = runtimes[player]
	if not rt then
		return false, "Not ready"
	end
	local s = rt.state
	if not Formulas.canCurtainCall(s) or rt.view ~= s.stage then
		return false, "Break through stage " .. (T.CurtainCallStage - 1) .. " first"
	end
	local gained = Formulas.bouquetsFor(s)
	resetRun(rt)
	s.bouquets += gained
	s.curtainCalls += 1
	setView(player, rt, 1)
	rt.dirty = true
	LeaderboardService.update(player)
	SocialService.broadcast("CurtainCall", {
		userId = player.UserId,
		name = player.DisplayName,
		gained = gained,
		total = s.bouquets,
	})
	task.delay(1.2, function()
		if player.Parent then
			WorldService.place(player, 1)
		end
	end)
	return true, tostring(gained)
end

-- Rebirth: after beating Space. Resets everything including Bouquets, for a permanent x10
-- clap power, x2 Bouquets and new cosmetics.
local function onRebirth(player: Player): (boolean, string?)
	local rt = runtimes[player]
	if not rt then
		return false, "Not ready"
	end
	local s = rt.state
	if not Formulas.canRebirth(s) then
		return false, "Fill Space's escape velocity first"
	end
	resetRun(rt)
	s.bouquets = 0
	s.curtainCalls = 0
	s.spaceProgress = 0
	s.rebirths += 1
	setView(player, rt, 1)
	rt.dirty = true
	LeaderboardService.update(player)
	SocialService.broadcast("Rebirth", { userId = player.UserId, name = player.DisplayName, rebirths = s.rebirths })
	task.delay(1.6, function()
		if player.Parent then
			WorldService.place(player, 1)
		end
	end)
	return true, tostring(s.rebirths)
end

local function grantBoost(player: Player, seconds: number)
	local rt = runtimes[player]
	if rt then
		local s = rt.state
		local now = os.time()
		s.boostEndsAt = math.min(math.max(s.boostEndsAt, now) + seconds, now + Config.Ads.MaxBoostMinutes * 60)
		rt.dirty = true
	end
end

-- buy from the running event's shop with its currency (cosmetics are kept forever)
local function onEventShop(player: Player, itemId: any): (boolean, string?)
	local rt = runtimes[player]
	local event = EventService.active()
	if not rt or not event or type(itemId) ~= "string" then
		return false, "No event running"
	end
	local item: Events.ShopItem? = nil
	for _, candidate in event.shop do
		if candidate.id == itemId then
			item = candidate
		end
	end
	if not item then
		return false, "Not in this event's shop"
	end
	local s = rt.state
	if item.kind ~= "boost" and s.cosmetics[item.id] then
		return false, "You already own that"
	end
	local balance = s.eventCurrency[event.id] or 0
	if balance < item.cost then
		return false, "Not enough " .. event.currency.name
	end
	s.eventCurrency[event.id] = balance - item.cost
	if item.kind == "boost" then
		grantBoost(player, (item.minutes or 10) * 60)
	else
		s.cosmetics[item.id] = true
		s.equipped[item.kind] = item.id
		publishProfile(player, rt)
	end
	rt.dirty = true
	return true
end

-- wear or take off an owned event cosmetic (slot = wings / trail / title)
local function onEquip(player: Player, slot: any, itemId: any)
	local rt = runtimes[player]
	if not rt or (slot ~= "wings" and slot ~= "trail" and slot ~= "title") then
		return
	end
	local s = rt.state
	if itemId == nil then
		s.equipped[slot] = nil
	elseif type(itemId) == "string" and s.cosmetics[itemId] then
		local item = Events.item(itemId)
		if not item or item.kind ~= slot then
			return
		end
		s.equipped[slot] = itemId
	else
		return
	end
	publishProfile(player, rt)
	rt.dirty = true
end

-- stand up and walk around (stages with ground only), or sit back down
local function onWalk(player: Player, on: any)
	local rt = runtimes[player]
	if not rt or type(on) ~= "boolean" then
		return
	end
	if on and rt.view <= T.MaxWalkStage then
		WorldService.walk(player)
	else
		WorldService.place(player, rt.view)
	end
end

local function onPlayerAdded(player: Player)
	local state = DataService.load(player)
	if not state then
		player:Kick("We couldn't load your progress safely. Please rejoin in a moment.")
		return
	end
	-- older saves may reference stages that are no longer built
	state.stage = math.clamp(state.stage, 1, Config.lastBuiltStage())
	-- there's no settings menu any more: everyone's claps show at full size, cosmetics shown
	state.powerDisplay = 1
	state.showCosmetics = true
	local now = os.clock()
	local rt: Runtime = {
		state = state,
		tokens = T.MaxClapsPerSecond,
		tokenAt = now,
		streak = 0,
		lastGoodBeat = -math.huge,
		lastClapBeat = -math.huge,
		lastClapTime = 0,
		frenzyChain = 0,
		view = state.stage,
		assistNoticeAt = 0,
		dirty = true,
	}
	runtimes[player] = rt
	setView(player, rt, state.stage)
	player:SetAttribute("Loaded", true)
end

-- (Rebirths, best clap power ever) for the leaderboards
function GameService.profile(player: Player): (number?, number?)
	local rt = runtimes[player]
	if not rt then
		return nil, nil
	end
	return rt.state.rebirths, rt.state.bestPower
end

function GameService.getStage(player: Player): number
	local rt = runtimes[player]
	return if rt then rt.view else 1
end

function GameService.init(remoteFolder: Folder)
	remotes = remoteFolder;
	(remotes.ClapBatch :: RemoteEvent).OnServerEvent:Connect(onClapBatch);
	(remotes.Purchase :: RemoteFunction).OnServerInvoke = onPurchase;
	(remotes.CurtainCall :: RemoteFunction).OnServerInvoke = onCurtainCall;
	(remotes.Rebirth :: RemoteFunction).OnServerInvoke = onRebirth;
	(remotes.Travel :: RemoteFunction).OnServerInvoke = onTravel;
	(remotes.Walk :: RemoteEvent).OnServerEvent:Connect(onWalk);
	(remotes.EventShop :: RemoteFunction).OnServerInvoke = onEventShop;
	(remotes.Equip :: RemoteEvent).OnServerEvent:Connect(onEquip)
	MonetisationService.init(remotes, grantBoost)

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		runtimes[player] = nil
	end)

	-- auto-clappers (always at full power, even while visiting) and streak decay
	local autoAccumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		autoAccumulator += dt
		if autoAccumulator < 0.5 then
			return
		end
		local elapsed = autoAccumulator
		autoAccumulator = 0
		local ovation = SocialService.ovationMultiplier()
		local beat = math.floor(workspace:GetServerTimeNow() / T.BeatInterval + 0.5)
		for _, rt in runtimes do
			if rt.streak > 0 and beat - rt.lastGoodBeat > T.StreakGraceBeats + 1 then
				rt.streak = 0
				rt.dirty = true
			end
			local cps = Formulas.autoClapsPerSecond(rt.state)
			if cps > 0 then
				local boosted = if os.time() < rt.state.boostEndsAt then Config.Ads.BoostMultiplier else 1
				local earned = Formulas.clapPower(rt.state) + math.log10(cps * elapsed * T.AutoEfficiency * ovation * boosted)
				rt.state.applause = Num.add(rt.state.applause, earned)
				rt.dirty = true
			end
		end
	end)

	-- Studio-only test hook:
	-- ServerStorage.DevGrant:Invoke(userId, applauseLog?, techniquesUpToStage?, jumpToStage?, spaceFill0to1?, eventCurrency?)
	if RunService:IsStudio() then
		local grant = Instance.new("BindableFunction")
		grant.Name = "DevGrant"
		grant.OnInvoke = function(userId: number, applauseLog: number?, allTechniquesUpTo: number?, jumpToStage: number?, spaceFill: number?, eventCurrency: number?)
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
					if jumpToStage then
						-- puts the save at exactly this stage (also back down, e.g. after testing later stages)
						rt.state.stage = math.clamp(jumpToStage, 1, Config.lastBuiltStage())
						rt.state.highestStage = rt.state.stage
						rt.state.tier = 0
						setView(player, rt, rt.state.stage)
						broadcastTo(player, "Travel", { from = 0, to = rt.view })
						task.delay(0.9, WorldService.place, player, rt.view)
					end
					if spaceFill then
						rt.state.spaceProgress = T.SpaceGoal * math.clamp(spaceFill, 0, 1)
					end
					local event = EventService.active()
					if eventCurrency and event then
						rt.state.eventCurrency[event.id] = (rt.state.eventCurrency[event.id] or 0) + eventCurrency
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
