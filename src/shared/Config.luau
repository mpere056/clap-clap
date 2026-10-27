--!strict
-- All tunable game data. Costs were calibrated with tools/pacing_sim.py
-- (stages 1-3 clear at roughly 3 / 7 / 12 minutes at 6 clicks/sec).

local Config = {}

Config.Tuning = {
	MaxClapsPerSecond = 15, -- server rate cap for manual claps
	BeatInterval = 0.5, -- seconds per beat (120 BPM)
	PerfectWindow = 0.11, -- +/- seconds around a beat that count as "Perfect"
	PerfectBonus = 2, -- Applause multiplier on a Perfect clap

	ComboMax = 3,
	ComboGainPerClap = 0.02,
	ComboGainPerPerfect = 0.06,
	ComboDecayDelay = 1.0, -- seconds without clapping before combo decays
	ComboDecayPerSecond = 0.8,

	AutoEfficiency = 0.5, -- auto claps earn this fraction of a manual clap

	FrenzyClapsToFill = 400,
	FrenzyChain = 8, -- claps in a frenzy; clap i earns x2^i

	OvationBase = 900, -- shared meter target = base + perPlayer * players
	OvationPerPlayer = 450,
	OvationDuration = 300,
	OvationMultiplier = 2,

	InSyncMinPlayers = 2,
	InSyncBonus = 1.5,

	-- Graduate (prestige): available once you've maxed out this stage
	GraduateStage = 3,
	DiplomaBonus = 0.1, -- each Diploma: +10% clap power, forever

	StrongHandsBaseCost = 15,
	StrongHandsGrowth = 1.15,
	ClassmateGrowth = 1.12,
}

export type StageDisplay = {
	kind: "linear" | "log",
	from: number,
	to: number,
	label: string, -- shown under "1 clap ="
	suffix: string,
	meter: boolean?, -- show the dB-style meter with ticks
}

export type Caption = { t: number, text: string, jp: string? }

export type Stage = {
	id: number,
	key: string,
	name: string,
	jp: string,
	threshold: number, -- log10 Clap Power needed to break through to the next stage
	built: boolean,
	origin: Vector3,
	display: StageDisplay,
	captions: { Caption },
	breakthroughCaption: string,
}

local STAGE_SPACING = 3000

Config.Stages = {
	{
		id = 1,
		key = "Ceremony",
		name = "The Ceremony",
		jp = "卒業式",
		threshold = 3,
		built = true,
		origin = Vector3.new(0, 0, 0),
		display = { kind = "linear", from = 110, to = 194, label = "Sound", suffix = " dB", meter = true },
		captions = {
			{ t = 0, text = "Everyone stopped clapping.", jp = "みんなの拍手が、鳴りやんだ" },
			{ t = 0.08, text = "You didn't." },
			{ t = 0.3, text = "Your classmates are starting to stare." },
			{ t = 0.55, text = "Pain threshold reached. Somebody cover their ears.", jp = "うるさい！" },
			{ t = 0.8, text = "The windows are rattling." },
			{ t = 0.95, text = "Air can't carry a louder sound than this." },
		},
		breakthroughCaption = "194 dB. Your clap became a shockwave.",
	},
	{
		id = 2,
		key = "Gym",
		name = "The Shockwave",
		jp = "体育館",
		threshold = 6,
		built = true,
		origin = Vector3.new(STAGE_SPACING, 0, 0),
		display = { kind = "log", from = 1, to = 1000, label = "TNT", suffix = " kg" },
		captions = {
			{ t = 0, text = "Your clap became a shockwave.", jp = "拍手の音が、衝撃波に変わった" },
			{ t = 0.3, text = "Chairs are leaving the building." },
			{ t = 0.6, text = "The gym lights would like a word." },
			{ t = 0.9, text = "The roof is getting nervous." },
		},
		breakthroughCaption = "The roof gave up.",
	},
	{
		id = 3,
		key = "Town",
		name = "The Town",
		jp = "町",
		threshold = 9,
		built = true,
		origin = Vector3.new(STAGE_SPACING * 2, 0, 0),
		display = { kind = "log", from = 1, to = 1000, label = "TNT", suffix = " t" },
		captions = {
			{ t = 0, text = "The whole town heard that one." },
			{ t = 0.35, text = "Roofs are peeling off like stickers." },
			{ t = 0.7, text = "Nobody asked you to do this." },
		},
		breakthroughCaption = "You flattened the town. Keep going.",
	},
	{
		id = 4,
		key = "City",
		name = "The City",
		jp = "市",
		threshold = 12.5,
		built = false,
		origin = Vector3.new(STAGE_SPACING * 3, 0, 0),
		display = { kind = "log", from = 1, to = 1000, label = "TNT", suffix = " kt" },
		captions = {},
		breakthroughCaption = "",
	},
	{
		id = 5,
		key = "Region",
		name = "The Region",
		jp = "地方",
		threshold = 16,
		built = false,
		origin = Vector3.new(STAGE_SPACING * 4, 0, 0),
		display = { kind = "log", from = 1, to = 100, label = "TNT", suffix = " Mt" },
		captions = {},
		breakthroughCaption = "",
	},
	{
		id = 6,
		key = "Country",
		name = "The Country",
		jp = "日本",
		threshold = 20,
		built = false,
		origin = Vector3.new(STAGE_SPACING * 5, 0, 0),
		display = { kind = "log", from = 100, to = 100000, label = "TNT", suffix = " Mt" },
		captions = {},
		breakthroughCaption = "",
	},
	{
		id = 7,
		key = "Planet",
		name = "The Planet",
		jp = "地球",
		threshold = 24,
		built = false,
		origin = Vector3.new(STAGE_SPACING * 6, 0, 0),
		display = { kind = "log", from = 0.001, to = 1, label = "Dinosaur meteors", suffix = "×" },
		captions = {},
		breakthroughCaption = "",
	},
	{
		id = 8,
		key = "Molten",
		name = "Molten Earth",
		jp = "灼熱",
		threshold = 30,
		built = false,
		origin = Vector3.new(STAGE_SPACING * 7, 0, 0),
		display = { kind = "log", from = 1, to = 1e8, label = "Dinosaur meteors", suffix = "×" },
		captions = {},
		breakthroughCaption = "",
	},
	{
		id = 9,
		key = "Space",
		name = "Space",
		jp = "宇宙",
		threshold = 40,
		built = false,
		origin = Vector3.new(STAGE_SPACING * 8, 0, 0),
		display = { kind = "log", from = 1, to = 1e10, label = "Earths shattered", suffix = "×" },
		captions = {},
		breakthroughCaption = "",
	},
} :: { Stage }

export type Technique = { id: string, name: string, mult: number, cost: number, stage: number }

-- One-off Clap Power multipliers, bought in order
Config.Techniques = {
	{ id = "Polite", name = "Polite Clap", mult = 2, cost = 5e3, stage = 1 },
	{ id = "Firm", name = "Firm Clap", mult = 2, cost = 2.5e4, stage = 1 },
	{ id = "Cupped", name = "Cupped Clap", mult = 3, cost = 1.2e5, stage = 1 },
	{ id = "Thunder", name = "Thunder Clap", mult = 10, cost = 6e5, stage = 2 },
	{ id = "Sonic", name = "Sonic Clap", mult = 10, cost = 3e7, stage = 2 },
	{ id = "Shockwave", name = "Shockwave Clap", mult = 10, cost = 1.2e9, stage = 2 },
	{ id = "Seismic", name = "Seismic Clap", mult = 10, cost = 2.5e11, stage = 3 },
	{ id = "Tectonic", name = "Tectonic Clap", mult = 10, cost = 6e12, stage = 3 },
	{ id = "Volcanic", name = "Volcanic Clap", mult = 10, cost = 9e13, stage = 3 },
} :: { Technique }

export type Classmate = { id: string, name: string, cps: number, cost: number, stage: number }

-- Auto-clappers; cost grows by Tuning.ClassmateGrowth per owned
Config.Classmates = {
	{ id = "Classmate", name = "Classmate", cps = 0.5, cost = 40, stage = 1 },
	{ id = "Teacher", name = "Homeroom Teacher", cps = 3, cost = 3e3, stage = 1 },
	{ id = "Band", name = "Brass Band", cps = 15, cost = 2e5, stage = 2 },
	{ id = "Cheer", name = "Cheer Squad", cps = 80, cost = 3e6, stage = 2 },
	{ id = "School", name = "Whole School", cps = 400, cost = 3e8, stage = 3 },
	{ id = "Choir", name = "Town Choir", cps = 2500, cost = 4e9, stage = 3 },
} :: { Classmate }

function Config.getStage(id: number): Stage
	return Config.Stages[math.clamp(id, 1, #Config.Stages)]
end

function Config.lastBuiltStage(): number
	local last = 1
	for _, s in Config.Stages do
		if s.built then
			last = s.id
		end
	end
	return last
end

return Config
