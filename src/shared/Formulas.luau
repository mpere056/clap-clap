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
	frenzy: number,
	peakPower: number, -- best log10 effective clap power this run
	diplomas: number,
	graduations: number,
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
		frenzy = 0,
		peakPower = 0,
		diplomas = 0,
		graduations = 0,
	}
end

-- log10 of Clap Power
function Formulas.clapPower(state: PlayerState): number
	local base = math.log10(1 + state.strongHands) + math.log10(1 + T.DiplomaBonus * state.diplomas)
	for _, tech in Config.Techniques do
		if state.techniques[tech.id] then
			base += math.log10(tech.mult)
		end
	end
	return base
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

-- Display value for the stage's unit, e.g. 134 (dB) or 66 (kg)
function Formulas.displayValue(stageId: number, t: number): number
	local d = Config.getStage(stageId).display
	if d.kind == "linear" then
		return d.from + (d.to - d.from) * t
	end
	local a, b = math.log10(d.from), math.log10(d.to)
	return 10 ^ (a + (b - a) * t)
end

-- Graduate once the run has pushed past the end of the graduation stage
function Formulas.canGraduate(state: PlayerState): boolean
	return state.stage >= T.GraduateStage and state.peakPower >= Config.getStage(T.GraduateStage).threshold
end

-- Diplomas grow with how far past the graduation threshold the run got
function Formulas.diplomasFor(state: PlayerState): number
	local over = state.peakPower - Config.getStage(T.GraduateStage).threshold
	if over < 0 then
		return 0
	end
	return math.floor(3 * (over + 1) ^ 1.5)
end

function Formulas.frenzyMultiplier(chainIndex: number): number
	return 2 ^ chainIndex
end

function Formulas.ovationTarget(playerCount: number): number
	return T.OvationBase + T.OvationPerPlayer * math.max(1, playerCount)
end

return Formulas
