--!strict
-- Pure economy maths shared by server (authoritative) and client (display / prediction).
-- All currency and power values are log10 (see Num).

local Config = require(script.Parent.Config)
local Num = require(script.Parent.Num)

local T = Config.Tuning
local Formulas = {}

export type PlayerState = {
	applause: number,
	strongHands: number,
	techniques: { [string]: boolean },
	classmates: { [string]: number },
	stage: number,
	highestStage: number,
	totalClaps: number,
	runClaps: number,
	goodClaps: number, -- on-beat claps this run
	frenzy: number,
	peakPower: number, -- best log10 effective clap power this run
	bestPower: number, -- best ever (never reset; ranks the leaderboards)
	tier: number, -- tiers reached in the current stage
	-- Curtain Call (prestige): Bouquets boost clap power until the next Rebirth
	bouquets: number,
	curtainCalls: number,
	-- Rebirth: unlocked by filling Space's escape-velocity meter
	spaceProgress: number,
	rebirths: number,
	-- player settings
	boostEndsAt: number, -- os.time() when the x2 Applause boost (ads / product) runs out
	eventCurrency: { [string]: number }, -- per event id (Candy, Presents, ...)
	cosmetics: { [string]: boolean }, -- owned event cosmetics (kept forever)
	equipped: { [string]: string }, -- slot (wings/trail/title) -> item id
	purchases: { [string]: boolean }, -- processed receipt ids
	powerDisplay: number, -- 0.1..1, how big your claps look to you and everyone else
	showCosmetics: boolean,
}

function Formulas.newState(): PlayerState
	return {
		applause = Num.ZERO,
		strongHands = 0,
		techniques = {},
		classmates = {},
		stage = 1,
		highestStage = 1,
		totalClaps = 0,
		runClaps = 0,
		goodClaps = 0,
		frenzy = 0,
		peakPower = 0,
		bestPower = 0,
		tier = 0,
		bouquets = 0,
		curtainCalls = 0,
		spaceProgress = 0,
		rebirths = 0,
		boostEndsAt = 0,
		eventCurrency = {},
		cosmetics = {},
		equipped = {},
		purchases = {},
		powerDisplay = 1,
		showCosmetics = true,
	}
end

-- Practice: base clap power earned just by clapping on the beat this run
function Formulas.practice(state: PlayerState): number
	return math.floor(state.goodClaps / T.PracticeClaps)
end

-- log10 of Clap Power
function Formulas.clapPower(state: PlayerState): number
	local base = math.log10(1 + state.strongHands + Formulas.practice(state))
		+ math.log10(1 + T.BouquetBonus * state.bouquets)
		+ state.rebirths * math.log10(T.RebirthPowerMultiplier)
	for _, tech in Config.Techniques do
		if state.techniques[tech.id] then
			base += math.log10(tech.mult)
		end
	end
	return base
end

-- Clap power while standing in a stage: visiting an earlier stage caps it at that stage's
-- breakthrough power, so strong players can show off there but not farm it
function Formulas.clapPowerAt(state: PlayerState, viewStage: number): number
	local cp = Formulas.clapPower(state)
	if viewStage < state.stage then
		-- visiting: capped at what the stage can take, and less the further back you go
		return math.min(cp, Config.getStage(viewStage).threshold)
			+ (state.stage - viewStage) * math.log10(T.VisitorGainPerStageBack)
	end
	return cp
end

-- How hard a clap hits the stage on screen, in "stages": 1 once it's maxed, and a visitor adds one
-- per stage they're ahead (plus their progress there). The very first claps in the hall do almost
-- nothing; later stages start with a little already (you've wrecked a hall by then). Effects scale
-- with it.
function Formulas.clapForce(state: PlayerState, viewStage: number): number
	if viewStage < state.stage then
		return (state.stage - viewStage) + Formulas.progress(state, state.stage)
	end
	local base = math.min(0.3, 0.15 * (viewStage - 1))
	return base + (1 - base) * Formulas.progress(state, viewStage)
end

-- Grade one clap by its distance (seconds) from the nearest beat
function Formulas.grade(offset: number, repeatedInBeat: boolean): string
	if repeatedInBeat or offset > T.GoodWindow then
		return "Miss"
	elseif offset <= T.PerfectWindow then
		return "Perfect"
	elseif offset <= T.GreatWindow then
		return "Great"
	end
	return "Good"
end

function Formulas.comboFor(streak: number): number
	return 1 + (T.ComboMax - 1) * math.min(streak, T.StreakForMaxCombo) / T.StreakForMaxCombo
end

function Formulas.strongHandsCost(level: number): number
	return math.log10(T.StrongHandsBaseCost) + level * math.log10(T.StrongHandsGrowth)
end

function Formulas.techniqueCost(tech: Config.Technique): number
	return math.log10(tech.cost)
end

-- Techniques must be bought in order
function Formulas.nextTechnique(state: PlayerState): Config.Technique?
	for _, tech in Config.Techniques do
		if not state.techniques[tech.id] then
			return tech
		end
	end
	return nil
end

function Formulas.classmateCost(def: Config.Classmate, owned: number): number
	return math.log10(def.cost) + owned * math.log10(T.ClassmateGrowth)
end

function Formulas.autoClapsPerSecond(state: PlayerState): number
	local cps = 0
	for _, def in Config.Classmates do
		cps += def.cps * (state.classmates[def.id] or 0)
	end
	return cps
end

function Formulas.totalClassmates(state: PlayerState): number
	local n = 0
	for _, count in state.classmates do
		n += count
	end
	return n
end

-- 0..1 progress through the current stage
function Formulas.stageProgress(stageId: number, cpLog: number): number
	local stage = Config.getStage(stageId)
	local prev = if stageId > 1 then Config.getStage(stageId - 1).threshold else 0
	return math.clamp((cpLog - prev) / (stage.threshold - prev), 0, 1)
end

-- 0..1 progress shown for the stage you're standing in: Space fills by clapping (escape
-- velocity), earlier stages you're visiting are maxed out, otherwise the run's best power
function Formulas.progress(state: PlayerState, viewStage: number): number
	if viewStage < state.stage then
		return 1
	elseif viewStage == Config.lastBuiltStage() then
		return math.clamp(state.spaceProgress / T.SpaceGoal, 0, 1)
	end
	return Formulas.stageProgress(viewStage, state.peakPower)
end

-- How many of the stage's tiers this much progress has reached
function Formulas.tierAt(stageId: number, t: number): number
	local reached = 0
	for i, tier in Config.getStage(stageId).tiers do
		if t >= tier.at then
			reached = i
		end
	end
	return reached
end

-- Display value for the stage's unit, e.g. 134 (dB) or 66 (kg)
function Formulas.displayValue(stageId: number, t: number): number
	local d = Config.getStage(stageId).display
	if d.kind == "linear" then
		return d.from + (d.to - d.from) * t
	end
	local a, b = math.log10(d.from), math.log10(d.to)
	return 10 ^ (a + (b - a) * t)
end

-- Curtain Call: available any time after breaking through stage 3
function Formulas.canCurtainCall(state: PlayerState): boolean
	return state.stage >= T.CurtainCallStage
end

-- Bouquets grow with how far past the end of stage 3 this run's best clap got;
-- every Rebirth doubles them
function Formulas.bouquetsFor(state: PlayerState): number
	local over = state.peakPower - T.BouquetBasePower
	if over < 0 then
		return 0
	end
	return math.floor(T.BouquetScale * 10 ^ (T.BouquetExponent * over) * T.RebirthBouquetMultiplier ^ state.rebirths)
end

function Formulas.bouquetMultiplier(bouquets: number): number
	return 1 + T.BouquetBonus * bouquets
end

-- Rebirth: fill Space's escape-velocity meter
function Formulas.canRebirth(state: PlayerState): boolean
	return state.spaceProgress >= T.SpaceGoal
end

function Formulas.frenzyMultiplier(chainIndex: number): number
	return 2 ^ chainIndex
end

function Formulas.ovationTarget(playerCount: number): number
	return T.OvationBase + T.OvationPerPlayer * math.max(1, playerCount)
end

return Formulas
