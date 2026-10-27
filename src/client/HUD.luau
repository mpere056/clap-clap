--!strict
-- HUD in the source video's style: big serif clap count + 回目, "1 clap =" with a gold value,
-- dB meter, deadpan captions. Plus Applause, combo/beat ring, Encore, Standing Ovation and the shop.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local Format = require(Shared.Format)
local Num = require(Shared.Num)

local Beat = require(script.Parent.Beat)
local Store = require(script.Parent.Store)

local HUD = {}

local player = Players.LocalPlayer
local T = Config.Tuning

local SERIF = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold)
local SANS = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
local SANS_MED = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium)
local GOLD = Color3.fromRGB(232, 184, 102)
local WHITE = Color3.new(1, 1, 1)
local PANEL = Color3.fromRGB(16, 18, 26)

local gui: ScreenGui
local refs: { [string]: any } = {}
local lastCaptionKey = ""
local onBuy: ((string, string?, any) -> ())? = nil
local onGraduate: (() -> ())? = nil
local shopOpen = false
local predictedClaps = 0
local captionLocked = false

----------------------------------------------------------------------------------------------------
-- builders

local function create(className: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(className)
	for k, v in props do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function corner(radius: number): UICorner
	return create("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function stroke(transparency: number, thickness: number?): UIStroke
	return create("UIStroke", { Color = WHITE, Transparency = transparency, Thickness = thickness or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function text(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		TextColor3 = WHITE,
		FontFace = SANS,
		TextXAlignment = Enum.TextXAlignment.Left,
		RichText = true,
	}
	for k, v in props do
		defaults[k] = v
	end
	local label = create("TextLabel", defaults)
	-- soft drop shadow like the video's captions
	create("UIStroke", { Color = Color3.new(0, 0, 0), Transparency = 0.72, Thickness = 1.5, Parent = label })
	return label
end

local function button(props: { [string]: any }): TextButton
	local defaults = {
		BackgroundColor3 = Color3.fromRGB(40, 44, 58),
		TextColor3 = WHITE,
		FontFace = SANS,
		TextSize = 16,
		AutoButtonColor = true,
	}
	for k, v in props do
		defaults[k] = v
	end
	local b = create("TextButton", defaults)
	corner(8).Parent = b
	return b
end

----------------------------------------------------------------------------------------------------
-- layout

local function buildPowerBlock(parent: Instance)
	local block = create("Frame", {
		Name = "Power",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 22, 0, 64),
		Size = UDim2.new(0, 340, 0, 210),
		Parent = parent,
	})
	create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = block })
	refs.count = text({ Name = "Count", LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 60), FontFace = SERIF, TextSize = 52, Text = "0", Parent = block })
	local pill = create("Frame", {
		Name = "Pill",
		LayoutOrder = 2,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 0, 24),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.55,
		Parent = block,
	}, { corner(12), stroke(0.35), create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }) })
	refs.pill = text({ Name = "Text", AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), TextSize = 14, FontFace = SANS_MED, Text = "", Parent = pill })
	refs.clapEq = text({ Name = "ClapEq", LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 22), TextSize = 16, FontFace = SANS_MED, Text = "1 clap =", Parent = block })
	refs.value = text({ Name = "Value", LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 44), TextSize = 22, Text = "", Parent = block })

	-- meter (dB for the ceremony, progress bar elsewhere)
	local meter = create("Frame", { Name = "Meter", LayoutOrder = 5, BackgroundTransparency = 1, Size = UDim2.new(0, 260, 0, 34), Parent = block })
	local track = create("Frame", {
		Name = "Track",
		Size = UDim2.new(1, 0, 0, 8),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.8,
		Parent = meter,
	}, { corner(4) })
	refs.meterFill = create("Frame", {
		Name = "Fill",
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = WHITE,
		Parent = track,
	}, {
		corner(4),
		create("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(143, 209, 106)),
				ColorSequenceKeypoint.new(0.55, Color3.fromRGB(242, 193, 78)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(224, 82, 74)),
			}),
		}),
	})
	refs.meterTicks = create("Frame", { Name = "Ticks", BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 11), Size = UDim2.new(1, 0, 0, 16), Parent = meter })
	for _, tick in { { 0.3, "Noisy" }, { 0.55, "Pain" }, { 0.95, "Limit" } } do
		text({ Size = UDim2.new(0, 60, 1, 0), Position = UDim2.new(tick[1], -30, 0, 0), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 11, FontFace = SANS_MED, TextTransparency = 0.25, Text = tick[2], Parent = refs.meterTicks })
	end
	refs.meterLabel = text({ Name = "Next", Position = UDim2.new(0, 0, 0, 11), Size = UDim2.new(1, 0, 0, 16), TextSize = 12, FontFace = SANS_MED, TextTransparency = 0.2, Text = "", Parent = meter })
end

local function buildTopCenter(parent: Instance)
	local frame = create("Frame", {
		Name = "Applause",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 58),
		Size = UDim2.new(0, 300, 0, 64),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	refs.applause = text({ Size = UDim2.new(1, 0, 0, 38), TextXAlignment = Enum.TextXAlignment.Center, FontFace = SERIF, TextSize = 32, Text = "👏 0", Parent = frame })
	refs.rate = text({ Position = UDim2.new(0, 0, 0, 38), Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 14, FontFace = SANS_MED, TextTransparency = 0.15, Text = "", Parent = frame })
end

local function buildOvation(parent: Instance)
	local frame = create("Frame", {
		Name = "Ovation",
		-- top centre, under Applause: the top-right corner belongs to Roblox's player list
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 126),
		Size = UDim2.new(0, 220, 0, 52),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.55,
		Parent = parent,
	}, { corner(10), stroke(0.6) })
	refs.ovationTitle = text({ Position = UDim2.new(0, 12, 0, 6), Size = UDim2.new(1, -24, 0, 18), TextSize = 13, Text = "STANDING OVATION", Parent = frame })
	local track = create("Frame", { Position = UDim2.new(0, 12, 0, 30), Size = UDim2.new(1, -24, 0, 10), BackgroundColor3 = WHITE, BackgroundTransparency = 0.8, Parent = frame }, { corner(5) })
	refs.ovationFill = create("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = GOLD, Parent = track }, { corner(5) })
	refs.ovationFrame = frame
end

local function buildCenter(parent: Instance)
	-- beat ring + combo above the caption
	local holder = create("Frame", {
		Name = "Beat",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -150),
		Size = UDim2.new(0, 120, 0, 120),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	refs.beatRing = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(64, 64),
		BackgroundTransparency = 1,
		Parent = holder,
	}, { create("UICorner", { CornerRadius = UDim.new(1, 0) }), create("UIStroke", { Color = WHITE, Thickness = 3, Transparency = 0.3 }) })
	refs.beatDot = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.2,
		Parent = holder,
	}, { create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	refs.combo = text({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(0, 220, 0, 22), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 16, Text = "", Parent = holder })
	refs.perfect = text({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.new(0, 220, 0, 24), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 20, TextColor3 = GOLD, TextTransparency = 1, Text = "PERFECT", Parent = holder })

	-- encore frenzy meter
	local encore = create("Frame", {
		Name = "Encore",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -118),
		Size = UDim2.new(0, 180, 0, 6),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.8,
		Parent = parent,
	}, { corner(3) })
	refs.encoreFill = create("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(255, 120, 150), Parent = encore }, { corner(3) })
	refs.encoreLabel = text({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 2), Size = UDim2.new(0, 260, 0, 16), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 12, FontFace = SANS_MED, TextTransparency = 0.25, Text = "ENCORE", Parent = encore })

	-- captions
	refs.caption = text({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -62),
		Size = UDim2.new(0.9, 0, 0, 32),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 26,
		TextWrapped = true,
		Text = "",
		Parent = parent,
	})
	refs.captionJp = text({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -40),
		Size = UDim2.new(0.9, 0, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 15,
		FontFace = SANS_MED,
		TextTransparency = 0.25,
		Text = "",
		Parent = parent,
	})
	refs.hint = text({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.55, 0),
		Size = UDim2.new(0, 400, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 20,
		Text = "Click / tap / Space to clap",
		Parent = parent,
	})
end

local function buildToasts(parent: Instance)
	local list = create("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.38, 0),
		Size = UDim2.new(0, 520, 0, 200),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	create("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	refs.toasts = list
	refs.flash = create("Frame", {
		Name = "Flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		ZIndex = 50,
		Parent = parent,
	})
	refs.popups = create("Frame", { Name = "Popups", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = parent })
end

----------------------------------------------------------------------------------------------------
-- shop

type ShopRow = { frame: Frame, title: TextLabel, detail: TextLabel, buttons: { TextButton } }
local shopRows: { [string]: ShopRow } = {}

local function shopRow(parent: Instance, key: string, order: number, buyLabels: { string }, onClick: (number) -> ()): ShopRow
	local frame = create("Frame", {
		Name = key,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 62),
		BackgroundColor3 = Color3.fromRGB(30, 33, 44),
		Parent = parent,
	}, { corner(10) })
	local title = text({ Position = UDim2.new(0, 12, 0, 8), Size = UDim2.new(1, -150, 0, 22), TextSize = 17, Text = key, Parent = frame })
	local detail = text({ Position = UDim2.new(0, 12, 0, 32), Size = UDim2.new(1, -150, 0, 20), TextSize = 13, FontFace = SANS_MED, TextTransparency = 0.2, Text = "", Parent = frame })
	local buttons = {}
	for i, label in buyLabels do
		local b = button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10 - (#buyLabels - i) * 46, 0.5, 0),
			Size = UDim2.new(0, 42, 0, 36),
			Text = label,
			TextSize = 14,
			Parent = frame,
		})
		b.Activated:Connect(function()
			onClick(i)
		end)
		table.insert(buttons, b)
	end
	local row = { frame = frame, title = title, detail = detail, buttons = buttons }
	shopRows[key] = row
	return row
end

local AMOUNTS = { 1, 10, "max" }

local function buildShop(parent: Instance)
	local toggle = button({
		Name = "ShopToggle",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -22, 1, -22),
		Size = UDim2.new(0, 150, 0, 48),
		BackgroundColor3 = Color3.fromRGB(232, 184, 102),
		TextColor3 = Color3.fromRGB(30, 24, 16),
		TextSize = 20,
		Text = "Upgrades",
		Parent = parent,
	})
	local panel = create("Frame", {
		Name = "Shop",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -22, 1, -80),
		Size = UDim2.new(0, 400, 0.62, 0),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.08,
		Active = true, -- sink clicks so they don't count as claps
		Visible = false,
		Parent = parent,
	}, { corner(14), stroke(0.85) })
	create("UISizeConstraint", { MaxSize = Vector2.new(400, 560), Parent = panel })
	local scroll = create("ScrollingFrame", {
		Position = UDim2.new(0, 10, 0, 10),
		Size = UDim2.new(1, -20, 1, -20),
		BackgroundTransparency = 1,
		ScrollBarThickness = 4,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = panel,
	})
	create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })
	toggle.Activated:Connect(function()
		shopOpen = not shopOpen
		panel.Visible = shopOpen
	end)
	refs.shop = panel

	local function buy(kind: string, id: string?, amount: any)
		if onBuy then
			onBuy(kind, id, amount)
		end
	end

	text({ LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 22), TextSize = 14, FontFace = SANS_MED, TextTransparency = 0.3, Text = "YOUR CLAP", Parent = scroll })
	shopRow(scroll, "Strong Hands", 1, { "×1", "×10", "Max" }, function(i)
		buy("hands", nil, AMOUNTS[i])
	end)
	shopRow(scroll, "Technique", 2, { "Buy" }, function()
		local tech = Formulas.nextTechnique(Store.state :: any)
		if tech then
			buy("technique", tech.id, 1)
		end
	end)
	text({ LayoutOrder = 10, Size = UDim2.new(1, 0, 0, 22), TextSize = 14, FontFace = SANS_MED, TextTransparency = 0.3, Text = "CLASSMATES (AUTO-CLAP)", Parent = scroll })
	for i, def in Config.Classmates do
		shopRow(scroll, def.id, 10 + i, { "×1", "×10", "Max" }, function(j)
			buy("classmate", def.id, AMOUNTS[j])
		end)
	end
end

local function refreshShop()
	if not refs.shop or not refs.shop.Visible then
		return
	end
	local s = Store.state
	local applause = s.applause
	local function setAffordable(row: ShopRow, cost: number?, locked: boolean)
		for _, b in row.buttons do
			local ok = not locked and cost ~= nil and Num.gte(applause, cost)
			b.BackgroundColor3 = if ok then Color3.fromRGB(232, 184, 102) else Color3.fromRGB(52, 56, 70)
			b.TextColor3 = if ok then Color3.fromRGB(30, 24, 16) else Color3.fromRGB(150, 150, 160)
		end
	end

	local hands = shopRows["Strong Hands"]
	local handsCost = Formulas.strongHandsCost(s.strongHands)
	hands.title.Text = string.format("Strong Hands <font transparency=\"0.4\">Lv %d</font>", s.strongHands)
	hands.detail.Text = string.format("+1 base clap power · 👏 %s", Format.short(handsCost))
	setAffordable(hands, handsCost, false)

	local techRow = shopRows["Technique"]
	local tech = Formulas.nextTechnique(s :: any)
	if tech then
		local locked = tech.stage > s.stage
		techRow.title.Text = string.format("%s <font color=\"#E8B866\">×%d</font>", tech.name, tech.mult)
		techRow.detail.Text = if locked
			then string.format("Unlocks at stage %d · %s", tech.stage, Config.getStage(tech.stage).name)
			else string.format("Clap power ×%d · 👏 %s", tech.mult, Format.short(Formulas.techniqueCost(tech)))
		setAffordable(techRow, Formulas.techniqueCost(tech), locked)
	else
		techRow.title.Text = "All techniques learned"
		techRow.detail.Text = "More in future stages"
		setAffordable(techRow, nil, true)
	end

	for _, def in Config.Classmates do
		local row = shopRows[def.id]
		local owned = s.classmates[def.id] or 0
		local locked = def.stage > s.stage
		row.frame.Visible = def.stage <= s.stage + 1
		local cost = Formulas.classmateCost(def, owned)
		row.title.Text = string.format("%s <font transparency=\"0.4\">×%d</font>", def.name, owned)
		row.detail.Text = if locked
			then string.format("Unlocks at stage %d", def.stage)
			else string.format("%s claps/s · 👏 %s", Format.number(def.cps), Format.short(cost))
		setAffordable(row, cost, locked)
	end
end

----------------------------------------------------------------------------------------------------
-- graduate (prestige)

local function buildGraduate(parent: Instance)
	local graduate = button({
		Name = "Graduate",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 186),
		Size = UDim2.new(0, 220, 0, 46),
		BackgroundColor3 = Color3.fromRGB(255, 120, 150),
		TextColor3 = Color3.fromRGB(40, 16, 24),
		TextSize = 17,
		Text = "🎓 Graduate 卒業",
		Visible = false,
		Parent = parent,
	})
	refs.graduate = graduate

	local dialog = create("Frame", {
		Name = "GraduateDialog",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.9, 0, 0, 250),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.04,
		Active = true, -- sink clicks so they don't count as claps
		Visible = false,
		ZIndex = 20,
		Parent = parent,
	}, { corner(16), stroke(0.8), create("UISizeConstraint", { MaxSize = Vector2.new(420, 250) }) })
	text({ Position = UDim2.new(0, 22, 0, 18), Size = UDim2.new(1, -44, 0, 34), FontFace = SERIF, TextSize = 28, Text = "Graduate? 卒業", ZIndex = 21, Parent = dialog })
	refs.graduateBody = text({
		Position = UDim2.new(0, 22, 0, 60),
		Size = UDim2.new(1, -44, 0, 110),
		TextSize = 16,
		FontFace = SANS_MED,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "",
		ZIndex = 21,
		Parent = dialog,
	})
	local confirm = button({
		Name = "Confirm",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -22, 1, -18),
		Size = UDim2.new(0, 170, 0, 44),
		BackgroundColor3 = Color3.fromRGB(255, 120, 150),
		TextColor3 = Color3.fromRGB(40, 16, 24),
		TextSize = 18,
		Text = "Graduate",
		ZIndex = 21,
		Parent = dialog,
	})
	local cancel = button({
		Name = "Cancel",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 22, 1, -18),
		Size = UDim2.new(0, 140, 0, 44),
		Text = "Not yet",
		ZIndex = 21,
		Parent = dialog,
	})
	graduate.Activated:Connect(function()
		dialog.Visible = true
	end)
	cancel.Activated:Connect(function()
		dialog.Visible = false
	end)
	confirm.Activated:Connect(function()
		dialog.Visible = false
		if onGraduate then
			onGraduate()
		end
	end)
	refs.graduateDialog = dialog
end

----------------------------------------------------------------------------------------------------
-- public API

function HUD.init(buyHandler: (string, string?, any) -> (), graduateHandler: () -> ())
	onBuy = buyHandler
	onGraduate = graduateHandler
	gui = create("ScreenGui", {
		Name = "ClapHUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local safe = create("Frame", { Name = "Safe", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
	buildPowerBlock(safe)
	buildTopCenter(safe)
	buildOvation(safe)
	buildCenter(safe)
	buildToasts(safe)
	buildShop(safe)
	buildGraduate(safe)

	-- beat ring animation
	RunService.RenderStepped:Connect(function()
		local phase = Beat.phase()
		local pulse = math.max(0, 1 - phase * 4) -- big right on the beat
		local size = 64 + 26 * (1 - phase)
		refs.beatRing.Size = UDim2.fromOffset(size, size)
		local ringStroke = refs.beatRing:FindFirstChildOfClass("UIStroke")
		if ringStroke then
			ringStroke.Transparency = 0.15 + 0.7 * phase
		end
		refs.beatDot.BackgroundTransparency = 0.6 - 0.5 * pulse
		refs.beatDot.Size = UDim2.fromOffset(16 + 10 * pulse, 16 + 10 * pulse)
		HUD.updateOvation()
	end)
end

function HUD.setPredictedClaps(n: number)
	predictedClaps = n
end

local function captionFor(stageId: number, t: number): Config.Caption?
	local stage = Config.getStage(stageId)
	local chosen = nil
	for _, caption in stage.captions do
		if t >= caption.t then
			chosen = caption
		end
	end
	return chosen
end

function HUD.lockCaption(locked: boolean)
	captionLocked = locked
end

function HUD.setCaption(textValue: string, jp: string?)
	if refs.caption.Text == textValue then
		return
	end
	refs.caption.Text = textValue
	refs.captionJp.Text = jp or ""
	refs.caption.TextTransparency = 1
	refs.captionJp.TextTransparency = 1
	TweenService:Create(refs.caption, TweenInfo.new(0.5), { TextTransparency = 0 }):Play()
	TweenService:Create(refs.captionJp, TweenInfo.new(0.5), { TextTransparency = 0.25 }):Play()
end

-- stageId is the stage currently on screen (lags behind the server during a breakthrough)
function HUD.update(t: number, stageId: number)
	local s = Store.state
	local stage = Config.getStage(stageId)
	local capped = stageId >= Config.lastBuiltStage()
	local claps = s.runClaps + predictedClaps

	refs.count.Text = string.format("%s<font size=\"22\"> 回目</font>", Format.commas(claps))
	refs.pill.Text = string.format("STAGE %d · %s  %s", stage.id, string.upper(stage.name), stage.jp)

	local d = stage.display
	local value = Formulas.displayValue(stage.id, t)
	local valueText: string
	if d.suffix == " dB" then
		valueText = string.format("%d dB", math.floor(value))
	elseif d.suffix == "×" then
		valueText = Format.number(value) .. "×"
	else
		valueText = Format.number(value) .. d.suffix
	end
	refs.value.Text = string.format("%s <font face=\"Merriweather\" size=\"36\" color=\"#E8B866\">%s</font>", d.label, valueText)

	refs.meterFill.Size = UDim2.new(t, 0, 1, 0)
	refs.meterTicks.Visible = d.meter == true
	if d.meter then
		refs.meterLabel.Text = ""
	elseif capped then
		refs.meterLabel.Text = "Final stage for now · more coming soon"
	else
		local nextStage = Config.getStage(stage.id + 1)
		refs.meterLabel.Text = string.format("Next: %s · %d%%", nextStage.name, math.floor(t * 100))
	end

	refs.applause.Text = "👏 " .. Format.short(s.applause)
	local auto = Formulas.autoClapsPerSecond(s :: any)
	local rate = if auto > 0
		then string.format("Classmates: +%s/s · Power %s", Format.short(s.clapPower + math.log10(auto * T.AutoEfficiency)), Format.short(s.clapPower))
		else string.format("Clap power %s", Format.short(s.clapPower))
	local diplomas = s.diplomas or 0
	if diplomas > 0 then
		rate ..= string.format(" · 🎓 %d (+%d%%)", diplomas, math.floor(diplomas * T.DiplomaBonus * 100 + 0.5))
	end
	refs.rate.Text = rate

	local canGraduate = s.canGraduate == true and stageId == s.stage
	refs.graduate.Visible = canGraduate
	if canGraduate then
		local gained = s.diplomasOnGraduate or 0
		local after = (diplomas + gained) * T.DiplomaBonus * 100
		refs.graduate.Text = string.format("🎓 Graduate 卒業  +%d", gained)
		refs.graduateBody.Text = string.format(
			"Start over from the ceremony with <font color=\"#E8B866\">+%d Diplomas</font>.\n\nYou'll have %d Diplomas: <b>+%d%% clap power forever</b>.\nApplause, upgrades and classmates reset. Keep clapping longer before graduating to earn more.",
			gained,
			diplomas + gained,
			math.floor(after + 0.5)
		)
	elseif refs.graduateDialog.Visible then
		refs.graduateDialog.Visible = false
	end

	local combo = s.combo or 1
	refs.combo.Text = if combo > 1.05 then string.format("×%.1f COMBO", combo) else ""

	local chain = s.frenzyChain or 0
	if chain > 0 then
		refs.encoreFill.Size = UDim2.new(chain / T.FrenzyChain, 0, 1, 0)
		refs.encoreLabel.Text = string.format("ENCORE! next clap ×%d", Formulas.frenzyMultiplier(T.FrenzyChain - chain + 1))
		refs.encoreLabel.TextColor3 = Color3.fromRGB(255, 150, 175)
	else
		refs.encoreFill.Size = UDim2.new(math.clamp(s.frenzy / T.FrenzyClapsToFill, 0, 1), 0, 1, 0)
		refs.encoreLabel.Text = "ENCORE"
		refs.encoreLabel.TextColor3 = WHITE
	end

	if captionLocked then
		-- a cinematic owns the caption
	elseif canGraduate then
		HUD.setCaption("You've outgrown this school. Time to graduate.", "卒業おめでとう")
	elseif capped and t >= 1 then
		HUD.setCaption("This is as far as the stage goes (for now). Keep clapping!")
	else
		local caption = captionFor(stageId, t)
		local key = if caption then stageId .. ":" .. caption.text else ""
		if caption and key ~= lastCaptionKey then
			lastCaptionKey = key
			HUD.setCaption(caption.text, caption.jp)
		end
	end
	refs.hint.Visible = claps == 0
	refreshShop()
end

function HUD.updateOvation()
	local progress = (ReplicatedStorage:GetAttribute("OvationProgress") :: number?) or 0
	local target = (ReplicatedStorage:GetAttribute("OvationTarget") :: number?) or 1
	local endsAt = (ReplicatedStorage:GetAttribute("OvationEndsAt") :: number?) or 0
	local remaining = endsAt - workspace:GetServerTimeNow()
	if remaining > 0 then
		refs.ovationTitle.Text = string.format("<font color=\"#E8B866\">OVATION ×%d APPLAUSE</font>  %s", T.OvationMultiplier, Format.time(remaining))
		refs.ovationFill.Size = UDim2.new(remaining / T.OvationDuration, 0, 1, 0)
	else
		refs.ovationTitle.Text = "STANDING OVATION"
		refs.ovationFill.Size = UDim2.new(math.clamp(progress / target, 0, 1), 0, 1, 0)
	end
end

function HUD.toast(message: string, color: Color3?, duration: number?)
	local frame = create("Frame", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 0, 34),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Parent = refs.toasts,
	}, { corner(17), create("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }) })
	local label = text({ AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), TextSize = 17, TextColor3 = color or WHITE, Text = message, Parent = frame })
	task.delay(duration or 3.5, function()
		TweenService:Create(frame, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		task.wait(0.45)
		frame:Destroy()
	end)
end

function HUD.flash(hold: number?)
	refs.flash.BackgroundTransparency = 0
	task.delay(hold or 0.05, function()
		TweenService:Create(refs.flash, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
	end)
end

function HUD.whiteOut(duration: number)
	TweenService:Create(refs.flash, TweenInfo.new(duration), { BackgroundTransparency = 0 }):Play()
end

function HUD.perfect()
	refs.perfect.TextTransparency = 0
	refs.perfect.Position = UDim2.new(0.5, 0, 0, 4)
	TweenService:Create(refs.perfect, TweenInfo.new(0.45), { TextTransparency = 1, Position = UDim2.new(0.5, 0, 0, -10) }):Play()
end

-- first-person shockwave: a ring bursting out from between the hands
function HUD.screenRing(perfect: boolean, t: number)
	local ring = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.72),
		Size = UDim2.fromOffset(30, 30),
		BackgroundTransparency = 1,
		Parent = refs.popups,
	}, {
		create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		create("UIStroke", { Color = if perfect then GOLD else WHITE, Thickness = 5 + t * 6, Transparency = 0.15 }),
	})
	local finalSize = 160 + t * 520
	local ringStroke = ring:FindFirstChildOfClass("UIStroke") :: UIStroke
	local info = TweenInfo.new(0.35 + t * 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(ring, info, { Size = UDim2.fromOffset(finalSize, finalSize * 0.75) }):Play()
	TweenService:Create(ringStroke, info, { Transparency = 1, Thickness = 1 }):Play()
	task.delay(0.55, function()
		ring:Destroy()
	end)
end

-- floating "+1.2K" near the centre
function HUD.popup(amountLog: number, gold: boolean)
	local label = text({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5 + (math.random() - 0.5) * 0.18, 0, 0.44 + (math.random() - 0.5) * 0.06, 0),
		Size = UDim2.new(0, 200, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = if gold then 26 else 20,
		FontFace = SERIF,
		TextColor3 = if gold then GOLD else WHITE,
		Text = "+" .. Format.short(amountLog),
		Parent = refs.popups,
	})
	local target = label.Position - UDim2.new(0, 0, 0.06, 0)
	TweenService:Create(label, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = target, TextTransparency = 1 }):Play()
	task.delay(0.75, function()
		label:Destroy()
	end)
end

return HUD
