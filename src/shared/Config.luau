--!strict
-- All tunable game data. Costs were calibrated with tools/pacing_sim.py --calibrate
-- (on-beat player: stages 1-3 in ~10 min; Space after ~5 h without Curtain Calls, ~1 h with
-- optimal Curtain Calls; then ~1 h of clapping in Space to unlock Rebirth).

local Config = {}

Config.Tuning = {
	MaxClapsPerSecond = 15, -- server rate cap for manual claps (spam is allowed, just punished)

	-- Rhythm: every clap is graded by its distance from the nearest beat.
	-- One clap per beat is optimal; a second clap in the same beat is a Miss.
	BeatInterval = 0.6, -- seconds per beat (100 BPM)
	PerfectWindow = 0.06,
	GreatWindow = 0.12,
	GoodWindow = 0.2, -- anything further off (the middle between beats) is a Miss
	GradeMultipliers = { Perfect = 3, Great = 2, Good = 1 } :: { [string]: number },
	MissPenaltyClaps = 2, -- a Miss costs this many claps' worth of Applause

	-- Combo comes from the streak of consecutive on-beat claps
	ComboMax = 3,
	StreakForMaxCombo = 20,
	StreakGraceBeats = 2, -- beats you can skip without losing the streak

	AutoEfficiency = 0.5, -- auto claps earn this fraction of a manual clap

	FrenzyClapsToFill = 150, -- on-beat claps
	FrenzyChain = 6, -- claps in a frenzy; clap i earns x2^i

	-- walking around is allowed on stages with solid ground (not on the globes or in space)
	MaxWalkStage = 6,

	-- stronger players visiting an earlier stage
	VisitorEncoreAssist = 1, -- each of their on-beat claps adds this x(stages ahead) to others' Encore meters
	VisitorOvationMultiplier = 3,
	VisitorGainPerStageBack = 0.1, -- their Applause per clap is capped at the stage's threshold, then x this per stage back

	OvationBase = 300, -- shared meter target = base + perPlayer * players (on-beat claps)
	OvationPerPlayer = 200,
	OvationDuration = 300,
	OvationMultiplier = 2,

	InSyncMinPlayers = 2,
	InSyncBonus = 1.5,

	-- Curtain Call (prestige): from the City onwards, start again with Bouquets.
	-- Bouquets = scale * 10^(exponent * (best power - base)) * 2^rebirths; each is +10% clap power.
	CurtainCallStage = 4,
	BouquetBasePower = 9,
	BouquetScale = 5,
	BouquetExponent = 0.18,
	BouquetBonus = 0.1,

	-- Space is beaten by filling the escape-velocity meter: each on-beat clap there adds
	-- grade x combo (about an hour of good clapping). Beating it unlocks Rebirth.
	SpaceGoal = 30000,
	RebirthPowerMultiplier = 10, -- per Rebirth, forever
	RebirthBouquetMultiplier = 2, -- per Rebirth, forever

	PracticeClaps = 10, -- every N on-beat claps this run: +1 base clap power, so clapping alone shows progress
	TierRewardClaps = 40, -- a tier-up pays this many claps' worth of Applause per tier number

	StrongHandsBaseCost = 8,
	StrongHandsGrowth = 1.15,
	ClassmateGrowth = 1.12,
}

-- Rewarded video ads: watching one grants the boost developer product for free (it can also be
-- bought with Robux). Create the developer product on the Creator Hub and put its id here.
Config.Ads = {
	BoostProductId = 0, -- 0 = ads switched off
	PlacementId = nil :: number?,
	BoostMinutes = 5,
	BoostMultiplier = 2, -- x2 Applause (manual and classmates)
	MaxBoostMinutes = 60, -- stacking cap
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

-- Milestones inside a stage (stage progress 0..1). Reaching one is a "tier up".
export type Tier = { at: number, name: string, jp: string? }

export type Stage = {
	id: number,
	key: string,
	icon: string, -- emoji for menus
	name: string,
	jp: string,
	threshold: number, -- log10 Clap Power needed to break through to the next stage
	built: boolean,
	origin: Vector3,
	display: StageDisplay,
	captions: { Caption },
	tiers: { Tier },
	breakthroughCaption: string,
}

local STAGE_SPACING = 3000 -- stages 1-3; later stages are bigger and placed further apart

Config.Stages = {
	{
		id = 1,
		key = "Ceremony",
		icon = "🎓",
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
		tiers = {
			{ at = 0.12, name = "Loud", jp = "大きい音" }, -- 120 dB
			{ at = 0.30, name = "Painful", jp = "耳が痛い" }, -- 135 dB
			{ at = 0.48, name = "Deafening", jp = "鼓膜が限界" }, -- 150 dB
			{ at = 0.65, name = "Window-rattling", jp = "窓が揺れる" }, -- 165 dB
			{ at = 0.83, name = "Glass-breaking", jp = "ガラスが割れる" }, -- 180 dB
		},
		breakthroughCaption = "194 dB. Your clap became a shockwave.",
	},
	{
		id = 2,
		key = "Gym",
		icon = "🏀",
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
		tiers = {
			{ at = 0.16, name = "Firecracker", jp = "爆竹" }, -- 3 kg
			{ at = 0.43, name = "Floor-shaker", jp = "床が揺れる" }, -- 20 kg
			{ at = 0.67, name = "Wall-cracker", jp = "壁にひび" }, -- 100 kg
			{ at = 0.87, name = "Roof-lifter", jp = "屋根が浮く" }, -- 400 kg
		},
		breakthroughCaption = "The roof gave up.",
	},
	{
		id = 3,
		key = "Town",
		icon = "🏘",
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
		tiers = {
			{ at = 0.16, name = "Street-shaker", jp = "道が揺れる" }, -- 3 t
			{ at = 0.43, name = "Window-smasher", jp = "窓が全部割れる" }, -- 20 t
			{ at = 0.67, name = "Roof-peeler", jp = "屋根が飛ぶ" }, -- 100 t
			{ at = 0.87, name = "Block-flattener", jp = "街が平らに" }, -- 400 t
		},
		breakthroughCaption = "You flattened the town. Keep going.",
	},
	{
		id = 4,
		key = "City",
		icon = "🏙",
		name = "The City",
		jp = "市",
		threshold = 12.5,
		built = true,
		origin = Vector3.new(9000, 0, 0),
		display = { kind = "log", from = 1, to = 1000, label = "TNT", suffix = " kt" },
		captions = {
			{ t = 0, text = "The city felt that one." },
			{ t = 0.4, text = "Craters are appearing wherever you clap." },
			{ t = 0.8, text = "You are now visible from orbit." },
		},
		tiers = {
			{ at = 0.16, name = "Block-buster", jp = "街区が吹き飛ぶ" }, -- 3 kt
			{ at = 0.43, name = "District-leveller", jp = "地区が平らに" }, -- 20 kt
			{ at = 0.67, name = "Skyline-shaker", jp = "ビル街が揺れる" }, -- 100 kt
			{ at = 0.87, name = "City-flattener", jp = "街が消える" }, -- 400 kt
		},
		breakthroughCaption = "A wall of dust rises to the horizon.",
	},
	{
		id = 5,
		key = "Region",
		icon = "🗻",
		name = "The Region",
		jp = "地方",
		threshold = 16,
		built = true,
		origin = Vector3.new(13000, 0, 0),
		display = { kind = "log", from = 1, to = 100, label = "TNT", suffix = " Mt" },
		captions = {
			{ t = 0, text = "The dust wall is heading for the mountains." },
			{ t = 0.45, text = "Weather forecasts now include you." },
			{ t = 0.85, text = "Bigger than the largest explosion humans ever made.", jp = "人類最大の爆発を超えた" },
		},
		tiers = {
			{ at = 0.25, name = "Valley-echo", jp = "谷に響く" }, -- 3 Mt
			{ at = 0.5, name = "Hill-flattener", jp = "丘が消える" }, -- 10 Mt
			{ at = 0.75, name = "Mountain-shaker", jp = "山が揺れる" }, -- 30 Mt
			{ at = 0.9, name = "Record-breaker", jp = "記録更新" }, -- 60 Mt
		},
		breakthroughCaption = "The sky over the whole region turned grey.",
	},
	{
		id = 6,
		key = "Country",
		icon = "🗾",
		name = "The Country",
		jp = "日本",
		threshold = 20,
		built = true,
		origin = Vector3.new(17000, 0, 0),
		display = { kind = "log", from = 100, to = 100000, label = "TNT", suffix = " Mt" },
		captions = {
			{ t = 0, text = "Heard across the whole country.", jp = "日本中に聞こえる" },
			{ t = 0.5, text = "Tsunami warnings have been issued. For clapping." },
			{ t = 0.85, text = "The sound wave is circling the Earth.", jp = "地球を一周する" },
		},
		tiers = {
			{ at = 0.2, name = "Nationwide", jp = "全国に響く" },
			{ at = 0.45, name = "Coast-to-coast", jp = "海岸から海岸へ" },
			{ at = 0.7, name = "Island-shaker", jp = "島が揺れる" },
			{ at = 0.87, name = "Round-the-world", jp = "地球一周" },
		},
		breakthroughCaption = "The glow spread across the ocean.",
	},
	{
		id = 7,
		key = "Planet",
		icon = "🌏",
		name = "The Planet",
		jp = "地球",
		threshold = 24,
		built = true,
		origin = Vector3.new(22000, 3000, 0),
		display = { kind = "log", from = 0.001, to = 1, label = "Dinosaur meteors", suffix = "×" },
		captions = {
			{ t = 0, text = "You can see your clap from space." },
			{ t = 0.5, text = "Molten rock is raining worldwide.", jp = "世界中に、焼けた岩の雨が降る" },
			{ t = 0.9, text = "Rivals the meteor that ended the dinosaurs.", jp = "恐竜を滅ぼした隕石に並ぶ" },
		},
		tiers = {
			{ at = 0.25, name = "Sky-splitter", jp = "空が割れる" },
			{ at = 0.5, name = "Ocean-crosser", jp = "海を越える" },
			{ at = 0.75, name = "Continental quake", jp = "大陸が揺れる" },
			{ at = 0.9, name = "Dinosaur moment", jp = "恐竜の気分" },
		},
		breakthroughCaption = "The whole planet turned orange.",
	},
	{
		id = 8,
		key = "Molten",
		icon = "🌋",
		name = "Molten Earth",
		jp = "灼熱",
		threshold = 30,
		built = true,
		origin = Vector3.new(28000, 3000, 0),
		display = { kind = "log", from = 1, to = 1e8, label = "Dinosaur meteors", suffix = "×" },
		captions = {
			{ t = 0, text = "The oceans are boiling away.", jp = "海の水が全部蒸発する" },
			{ t = 0.45, text = "The surface is melting.", jp = "地球の表面が溶ける" },
			{ t = 0.85, text = "Something deep inside the Earth just cracked." },
		},
		tiers = {
			{ at = 0.2, name = "Steam planet", jp = "湯気の星" },
			{ at = 0.45, name = "Boiling seas", jp = "海が沸騰" },
			{ at = 0.7, name = "Molten crust", jp = "地殻が溶ける" },
			{ at = 0.88, name = "Cracking core", jp = "核にひび" },
		},
		breakthroughCaption = "Earth broke apart on that clap.",
	},
	{
		id = 9,
		key = "Space",
		icon = "🌌",
		name = "Space",
		jp = "宇宙",
		threshold = 40,
		built = true,
		origin = Vector3.new(34000, 3000, 0),
		display = { kind = "linear", from = 0, to = 100, label = "Escape velocity", suffix = "%" },
		captions = {
			{ t = 0, text = "In space, no one can hear you clap.", jp = "宇宙では、拍手は無音" },
			{ t = 0.3, text = "You can't hear it. You can feel it." },
			{ t = 0.7, text = "The pieces drift further away with every clap." },
			{ t = 0.98, text = "You've beaten Space. Time to be reborn.", jp = "転生" },
		},
		tiers = {
			{ at = 0.2, name = "Fragment-pusher", jp = "破片を押す" },
			{ at = 0.5, name = "Moon-nudger", jp = "月が動く" },
			{ at = 0.8, name = "Orbit-bender", jp = "軌道が曲がる" },
		},
		breakthroughCaption = "",
	},
} :: { Stage }

export type Technique = { id: string, icon: string, name: string, mult: number, cost: number, stage: number }

-- One-off Clap Power multipliers, bought in order
Config.Techniques = {
	{ id = "Polite", icon = "👏", name = "Polite Clap", mult = 2, cost = 1.7e3, stage = 1 },
	{ id = "Firm", icon = "✊", name = "Firm Clap", mult = 2, cost = 1.3e4, stage = 1 },
	{ id = "Cupped", icon = "🙌", name = "Cupped Clap", mult = 3, cost = 5.5e4, stage = 1 },
	{ id = "Thunder", icon = "⚡", name = "Thunder Clap", mult = 10, cost = 1.5e6, stage = 2 },
	{ id = "Sonic", icon = "💨", name = "Sonic Clap", mult = 10, cost = 9.5e7, stage = 2 },
	{ id = "Shockwave", icon = "💥", name = "Shockwave Clap", mult = 10, cost = 1.9e9, stage = 2 },
	{ id = "Seismic", icon = "📳", name = "Seismic Clap", mult = 10, cost = 1.2e11, stage = 3 },
	{ id = "Tectonic", icon = "🗿", name = "Tectonic Clap", mult = 10, cost = 5.3e12, stage = 3 },
	{ id = "Volcanic", icon = "🌋", name = "Volcanic Clap", mult = 10, cost = 1e14, stage = 3 },
	{ id = "Avalanche", icon = "🏔", name = "Avalanche Clap", mult = 10, cost = 1.7e16, stage = 4 },
	{ id = "Hurricane", icon = "🌀", name = "Hurricane Clap", mult = 10, cost = 4.5e17, stage = 4 },
	{ id = "Earthquake", icon = "🏚", name = "Earthquake Clap", mult = 10, cost = 7.7e18, stage = 4 },
	{ id = "Tsunami", icon = "🌊", name = "Tsunami Clap", mult = 10, cost = 3.4e20, stage = 5 },
	{ id = "Mountain", icon = "⛰", name = "Mountain Clap", mult = 10, cost = 6.1e21, stage = 5 },
	{ id = "Supercell", icon = "⛈", name = "Supercell Clap", mult = 10, cost = 9.7e22, stage = 5 },
	{ id = "Continental", icon = "🗺", name = "Continental Clap", mult = 10, cost = 3.9e24, stage = 6 },
	{ id = "Tidal", icon = "🌙", name = "Tidal Clap", mult = 10, cost = 4.8e25, stage = 6 },
	{ id = "Atmospheric", icon = "☁", name = "Atmospheric Clap", mult = 10, cost = 7.1e26, stage = 6 },
	{ id = "Stratospheric", icon = "🚀", name = "Stratospheric Clap", mult = 10, cost = 1.2e28, stage = 6 },
	{ id = "Meteor", icon = "☄", name = "Meteor Clap", mult = 10, cost = 5.8e29, stage = 7 },
	{ id = "Extinction", icon = "🦖", name = "Extinction Clap", mult = 10, cost = 7.1e30, stage = 7 },
	{ id = "Mantle", icon = "🔥", name = "Mantle Clap", mult = 10, cost = 1.1e32, stage = 7 },
	{ id = "Core", icon = "💎", name = "Core Clap", mult = 10, cost = 1.7e33, stage = 7 },
	{ id = "Magma", icon = "🌡", name = "Magma Clap", mult = 100, cost = 9e34, stage = 8 },
	{ id = "Crustbreaker", icon = "🔨", name = "Crust-breaker Clap", mult = 100, cost = 1.9e37, stage = 8 },
	{ id = "Planetcracker", icon = "🌍", name = "Planet-cracker Clap", mult = 100, cost = 3.1e39, stage = 8 },
	{ id = "Gravity", icon = "🕳", name = "Gravity Clap", mult = 100, cost = 1.4e42, stage = 9 },
	{ id = "Orbital", icon = "🛰", name = "Orbital Clap", mult = 100, cost = 3.3e44, stage = 9 },
	{ id = "Cosmic", icon = "🌌", name = "Cosmic Clap", mult = 100, cost = 2.4e46, stage = 9 },
} :: { Technique }

export type Classmate = { id: string, icon: string, name: string, cps: number, cost: number, stage: number }

-- Auto-clappers; cost grows by Tuning.ClassmateGrowth per owned
Config.Classmates = {
	{ id = "Classmate", icon = "🎓", name = "Classmate", cps = 0.5, cost = 25, stage = 1 },
	{ id = "Teacher", icon = "📚", name = "Homeroom Teacher", cps = 3, cost = 800, stage = 1 },
	{ id = "Band", icon = "🎺", name = "Brass Band", cps = 15, cost = 4.3e4, stage = 2 },
	{ id = "Cheer", icon = "📣", name = "Cheer Squad", cps = 80, cost = 4.3e5, stage = 2 },
	{ id = "School", icon = "🏫", name = "Whole School", cps = 400, cost = 3.5e9, stage = 3 },
	{ id = "Choir", icon = "🎤", name = "Town Choir", cps = 2500, cost = 3.5e10, stage = 3 },
	{ id = "Orchestra", icon = "🎻", name = "City Orchestra", cps = 1.5e4, cost = 5.2e14, stage = 4 },
	{ id = "Stadium", icon = "🏟", name = "Stadium Crowd", cps = 1e5, cost = 1e19, stage = 5 },
	{ id = "Nation", icon = "🗾", name = "Nationwide Applause", cps = 8e5, cost = 1.2e23, stage = 6 },
	{ id = "Global", icon = "🌐", name = "Global Ovation", cps = 7e6, cost = 1.7e28, stage = 7 },
	{ id = "Drummers", icon = "🥁", name = "Tectonic Drummers", cps = 6e7, cost = 2.7e33, stage = 8 },
	{ id = "Cosmos", icon = "👽", name = "Cosmic Choir", cps = 5e8, cost = 4.4e40, stage = 9 },
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
