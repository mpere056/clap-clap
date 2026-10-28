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

local Beat = require(script.Parent.Beat)
local Store = require(script.Parent.Store)
local UIKit = require(script.Parent.UIKit)
local UpgradesUI = require(script.Parent.UpgradesUI)
local Icons = require(Shared.Icons)

local HUD = {}

local player = Players.LocalPlayer
local T = Config.Tuning

local SERIF = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold)
local SANS = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
local SANS_MED = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium)
local GOLD = Color3.fromRGB(232, 184, 102)
local WHITE = Color3.new(1, 1, 1)

local gui: ScreenGui
local refs: { [string]: any } = {}
local lastCaptionKey = ""
export type Handlers = {
	buy: (string, string?, any) -> (),
	curtainCall: () -> (),
	rebirth: () -> (),
	setting: (string, any) -> (),
	view: () -> (),
	travel: (number) -> (),
}
local handlers: Handlers
local streak = 0
local shopOpen = false
local shopEverOpened = false
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
	refs.meterTicks = create("Frame", { Name = "Ticks", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 8), Parent = track })
	refs.meterLabel = text({ Name = "Next", Position = UDim2.new(0, 0, 0, 11), Size = UDim2.new(1, 0, 0, 16), TextSize = 12, FontFace = SANS_MED, TextTransparency = 0.2, Text = "", Parent = meter })
end

-- small notches on the meter, one per tier of the current stage
local tickStage = 0
local function refreshTicks(stageId: number, tier: number)
	local tiers = Config.getStage(stageId).tiers
	if tickStage ~= stageId or #refs.meterTicks:GetChildren() ~= #tiers then
		tickStage = stageId
		refs.meterTicks:ClearAllChildren()
		for i, info in tiers do
			create("Frame", {
				Name = "Tick" .. i,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(info.at, 0, 0.5, 0),
				Size = UDim2.fromOffset(3, 14),
				BorderSizePixel = 0,
				Parent = refs.meterTicks,
			}, { corner(2) })
		end
	end
	for i in tiers do
		local tick = refs.meterTicks:FindFirstChild("Tick" .. i)
		if tick then
			tick.BackgroundColor3 = if i <= tier then GOLD else WHITE
			tick.BackgroundTransparency = if i <= tier then 0 else 0.35
		end
	end
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
	-- [hands] 1.2K, centred as a pair
	local icon, label = UIKit.costLine(frame, UDim2.new(), UDim2.new(1, 0, 0, 38), 32)
	icon.Image = Icons.get("ui_hands")
	icon.Size = UDim2.fromOffset(40, 40)
	label.FontFace = SERIF
	refs.applause = label
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
		Position = UDim2.new(0.5, 0, 1, -190),
		Size = UDim2.new(0, 120, 0, 120),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	refs.beatTarget = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(64, 64),
		BackgroundTransparency = 1,
		Parent = holder,
	}, { create("UICorner", { CornerRadius = UDim.new(1, 0) }), create("UIStroke", { Color = WHITE, Thickness = 4, Transparency = 0.4 }) })
	refs.beatRing = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(150, 150),
		BackgroundTransparency = 1,
		Parent = holder,
	}, { create("UICorner", { CornerRadius = UDim.new(1, 0) }), create("UIStroke", { Color = WHITE, Thickness = 2, Transparency = 0.3 }) })
	refs.beatDot = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.2,
		Parent = holder,
	}, { create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	refs.combo = text({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(0, 320, 0, 22), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 16, Text = "", Parent = holder })
	refs.gradeLabel = text({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.new(0, 260, 0, 30), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 24, TextColor3 = GOLD, TextTransparency = 1, Text = "", Parent = holder })

	-- encore frenzy meter
	local encore = create("Frame", {
		Name = "Encore",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -158),
		Size = UDim2.new(0, 180, 0, 6),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.8,
		Parent = parent,
	}, { corner(3) })
	refs.encoreFill = create("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(255, 120, 150), Parent = encore }, { corner(3) })
	refs.encoreLabel = text({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 2), Size = UDim2.new(0, 260, 0, 16), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 12, FontFace = SANS_MED, TextTransparency = 0.25, Text = "ENCORE", Parent = encore })

	-- captions (above the button dock)
	refs.caption = text({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -102),
		Size = UDim2.new(0.9, 0, 0, 32),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 26,
		TextWrapped = true,
		Text = "",
		Parent = parent,
	})
	refs.captionJp = text({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -80),
		Size = UDim2.new(0.9, 0, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 15,
		FontFace = SANS_MED,
		TextTransparency = 0.25,
		Text = "",
		Parent = parent,
	})
	refs.hint = text({
		-- just above the beat ring (which sits 190 from the bottom), on any screen height
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -318),
		Size = UDim2.new(0, 560, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 20,
		Text = "Clap on the beat: click / tap / F when the ring lands",
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
	-- above panels, so tier-up banners stay visible with the shop open
	refs.popups = create("Frame", { Name = "Popups", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 10, Parent = parent })
end

----------------------------------------------------------------------------------------------------
-- upgrades (the menu itself lives in UpgradesUI)

local function buildShop(parent: Instance)
	UpgradesUI.init(function(kind, id, amount)
		handlers.buy(kind, id, amount)
	end)
	local toggle = UIKit.dockButton({ name = "UpgradesToggle", text = "Upgrades", icon = Icons.get("ui_upgrade"), color = UIKit.Colors.gold, width = 190, order = 5 })
	toggle.Activated:Connect(function()
		shopEverOpened = true
		UpgradesUI.toggle()
	end)
	refs.shopToggle = toggle
	refs.shopBadge = UIKit.badge(toggle)
	-- first-time nudge towards the shop
	refs.shopHint = UIKit.label({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -22, 1, -86),
		Size = UDim2.new(0, 300, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextSize = 20,
		TextColor3 = UIKit.Colors.gold,
		Text = "Spend Applause in Upgrades!",
		Visible = false,
		Parent = parent,
	})
end

local function refreshShop()
	local affordable = UpgradesUI.anyAffordable()
	shopOpen = UpgradesUI.isOpen()
	refs.shopBadge.Visible = affordable and not shopOpen
	refs.shopHint.Visible = affordable and not shopEverOpened
	UpgradesUI.refresh()
end

----------------------------------------------------------------------------------------------------
-- stage travel

type StageCard = { frame: Frame, status: TextLabel, go: TextButton, lock: Frame, lockText: TextLabel }
local stageCards: { StageCard } = {}
local stagesModal: UIKit.Modal

local function buildStages(parent: Instance)
	stagesModal = UIKit.modal({ name = "Stages", title = "Stages", icon = Icons.get("ui_map"), color = UIKit.Colors.blue, size = Vector2.new(820, 520) })
	UIKit.label({
		Size = UDim2.new(1, 0, 0, 40),
		TextSize = 16,
		TextWrapped = true,
		Text = "Visit any stage you've reached to show off. Your claps hit at full force there but earn little, and your on-beat claps charge everyone's Encore.",
		Parent = stagesModal.body,
	}, 1.5)
	local holder = UIKit.create("Frame", { Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 1, -48), BackgroundTransparency = 1, Parent = stagesModal.body })
	local grid = UIKit.grid(holder, Vector2.new(178, 206))
	for _, stage in Config.Stages do
		if stage.built then
			local card = UIKit.card({ color = UIKit.StageColors[stage.id] or UIKit.Colors.grey, parent = grid, layoutOrder = stage.id })
			UIKit.pill(card, tostring(stage.id), UDim2.fromOffset(8, 8))
			local disc = UIKit.create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 10),
				Size = UDim2.fromOffset(78, 78),
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = 1,
				Parent = card,
			})
			UIKit.rays(disc, 150)
			UIKit.image({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(102, 102), Image = Icons.get("stage_" .. stage.key), Parent = disc })
			local name = UIKit.label({ Position = UDim2.fromOffset(8, 92), Size = UDim2.new(1, -16, 0, 24), Text = stage.name, Parent = card })
			UIKit.fitText(name, 20)
			UIKit.label({ Position = UDim2.fromOffset(8, 114), Size = UDim2.new(1, -16, 0, 18), TextSize = 15, TextTransparency = 0.15, Text = stage.jp, Parent = card }, 1.5)
			local status = UIKit.label({ Position = UDim2.fromOffset(8, 132), Size = UDim2.new(1, -16, 0, 18), TextSize = 15, TextColor3 = UIKit.Colors.money, Text = "", Parent = card }, 1.5)
			local go = UIKit.button({
				color = UIKit.Colors.green,
				text = "Go",
				textSize = 22,
				size = UDim2.new(1, -16, 0, 46),
				position = UDim2.fromOffset(8, 152),
				parent = card,
			})
			go.Activated:Connect(function()
				handlers.travel(stage.id)
				stagesModal.close()
			end)
			local lock, lockText = UIKit.lockCover(card)
			table.insert(stageCards, { frame = card, status = status, go = go, lock = lock, lockText = lockText })
		end
	end
	local toggle = UIKit.dockButton({ name = "StagesToggle", text = "Stages", icon = Icons.get("ui_map"), color = UIKit.Colors.blue, width = 160, order = 4 })
	toggle.Activated:Connect(stagesModal.toggle)
	refs.stagesToggle = toggle
end

local function refreshStages()
	if not stagesModal.isOpen() then
		return
	end
	local s = Store.state
	local view = s.view or s.stage
	for i, card in stageCards do
		local stage = Config.getStage(i)
		local reached = stage.id <= s.stage
		local here = stage.id == view
		card.lock.Visible = not reached
		card.lockText.Text = "Not reached yet"
		card.go.Visible = reached and not here
		UIKit.setButton(card.go, if stage.id == s.stage then UIKit.Colors.gold else UIKit.Colors.green, if stage.id == s.stage then "Return" else "Go")
		card.status.Text = if here then "You are here!" elseif stage.id == s.stage then "Your stage" elseif reached then "Show off here" else ""
	end
end

----------------------------------------------------------------------------------------------------
-- Curtain Call (prestige) and Rebirth: a button that opens a confirm menu

local function buildPrestige(parent: Instance, key: string, y: number, color: Color3, title: string, iconName: string, confirmText: string, onConfirm: () -> ())
	local open = UIKit.button({
		name = key,
		color = color,
		text = title,
		icon = Icons.get(iconName),
		textSize = 22,
		size = UDim2.fromOffset(310, 60),
		anchor = Vector2.new(0.5, 0),
		position = UDim2.new(0.5, 0, 0, y),
		parent = parent,
	})
	open.Visible = false
	local modal = UIKit.modal({ name = key .. "Dialog", title = title, icon = Icons.get(iconName), color = color, size = Vector2.new(560, 380) })
	local body = UIKit.label({
		Size = UDim2.new(1, 0, 1, -72),
		TextSize = 19,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		LineHeight = 1.1,
		Text = "",
		Parent = modal.body,
	}, 2)
	local confirm = UIKit.button({
		name = "Confirm",
		color = color,
		text = confirmText,
		textSize = 24,
		size = UDim2.fromOffset(250, 60),
		anchor = Vector2.new(1, 1),
		position = UDim2.fromScale(1, 1),
		parent = modal.body,
	})
	local cancel = UIKit.button({
		name = "Cancel",
		color = UIKit.Colors.grey,
		text = "Not yet",
		textSize = 22,
		size = UDim2.fromOffset(170, 60),
		anchor = Vector2.new(0, 1),
		position = UDim2.fromScale(0, 1),
		parent = modal.body,
	})
	open.Activated:Connect(modal.open)
	cancel.Activated:Connect(modal.close)
	confirm.Activated:Connect(function()
		modal.close()
		onConfirm()
	end)
	refs[key] = { button = open, modal = modal, body = body }
end

----------------------------------------------------------------------------------------------------
-- walk, and settings: clap power display slider and cosmetics toggle

-- no Walk/Sit button: moving or jumping gets you up, walking into a seat sits you down
local function buildView(parent: Instance)
	-- stages 2+: swap between the wide stage camera and the close follow camera
	local view = UIKit.dockButton({ name = "ViewToggle", text = "Close", icon = Icons.get("ui_camera"), color = UIKit.Colors.teal, width = 130, order = 1 })
	view.Visible = false
	view.Activated:Connect(function()
		handlers.view()
	end)
	refs.view = view
end

-- available: the stage has both cameras; aerial: the wide one is showing (the button offers the other)
function HUD.setView(available: boolean, aerial: boolean)
	if refs.view then
		refs.view.Visible = available
		UIKit.setButton(refs.view, nil, if aerial then "Close" else "Aerial")
	end
end

local powerValue = 1
local dragging = false
local settingsModal: UIKit.Modal

local function buildSettings(parent: Instance)
	settingsModal = UIKit.modal({ name = "Settings", title = "Settings", icon = Icons.get("ui_gear"), color = UIKit.Colors.teal, size = Vector2.new(520, 300) })
	local body = settingsModal.body
	refs.powerLabel = UIKit.label({ Size = UDim2.new(1, 0, 0, 26), TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left, Text = "Clap power shown: 100%", Parent = body })
	UIKit.label({
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 0, 40),
		TextSize = 15,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTransparency = 0.15,
		Text = "Tone down how big your claps look (to you and everyone else). Your earnings don't change.",
		Parent = body,
	}, 1.5)
	local track = UIKit.create("TextButton", {
		Name = "Track",
		Position = UDim2.fromOffset(4, 88),
		Size = UDim2.new(1, -8, 0, 18),
		BackgroundColor3 = UIKit.Colors.inset,
		Text = "",
		AutoButtonColor = false,
		Parent = body,
	})
	UIKit.corner(track, 9)
	UIKit.outline(track, 3)
	refs.powerFill = UIKit.create("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = UIKit.Colors.gold, Parent = track })
	UIKit.corner(refs.powerFill, 9)
	refs.powerKnob = UIKit.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(32, 32),
		BackgroundColor3 = WHITE,
		Parent = track,
	})
	UIKit.corner(refs.powerKnob)
	UIKit.outline(refs.powerKnob, 3)
	local function setFromX(x: number)
		local k = math.clamp((x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0.1, 1)
		powerValue = math.floor(k * 20 + 0.5) / 20
	end
	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setFromX(input.Position.X)
		end
	end)
	game:GetService("UserInputService").InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setFromX(input.Position.X)
		end
	end)
	game:GetService("UserInputService").InputEnded:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			handlers.setting("powerDisplay", powerValue)
		end
	end)
	refs.cosmeticsButton = UIKit.button({
		color = UIKit.Colors.purple,
		text = "Wings, halo & titles: shown",
		textSize = 20,
		size = UDim2.new(1, 0, 0, 58),
		position = UDim2.fromOffset(0, 134),
		parent = body,
	})
	refs.cosmeticsButton.Activated:Connect(function()
		handlers.setting("showCosmetics", not (Store.state.showCosmetics ~= false))
	end)
	local toggle = UIKit.dockButton({ name = "SettingsToggle", text = "", icon = Icons.get("ui_gear"), color = UIKit.Colors.teal, width = 66, order = 3 })
	toggle.Activated:Connect(settingsModal.toggle)
end

local function refreshSettings()
	local s = Store.state
	if not dragging then
		powerValue = s.powerDisplay or 1
	end
	refs.powerLabel.Text = string.format("Clap power shown: %d%%", math.floor(powerValue * 100 + 0.5))
	refs.powerFill.Size = UDim2.new(powerValue, 0, 1, 0)
	refs.powerKnob.Position = UDim2.new(powerValue, 0, 0.5, 0)
	UIKit.setButton(refs.cosmeticsButton, nil, if s.showCosmetics ~= false then "Wings, halo & titles: shown" else "Wings, halo & titles: hidden")
end

----------------------------------------------------------------------------------------------------
-- public API

function HUD.init(callbacks: Handlers)
	handlers = callbacks
	gui = create("ScreenGui", {
		Name = "ClapHUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local safe = create("Frame", { Name = "Safe", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
	-- small screens (phones): lay the HUD out on a bigger virtual screen and scale it down to fit,
	-- so the beat ring, counters and panels keep their spacing instead of piling up
	local safeScale = create("UIScale", { Parent = safe })
	local function fitHud()
		local camera = workspace.CurrentCamera
		local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		-- (the layout needs about 1000 x 560 to keep the ring clear of the counters and captions)
		local s = math.clamp(math.min(viewport.X / 1000, viewport.Y / 560), 0.5, 1)
		safeScale.Scale = s
		safe.Size = UDim2.fromScale(1 / s, 1 / s)
	end
	fitHud()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitHud)
	buildPowerBlock(safe)
	buildTopCenter(safe)
	buildOvation(safe)
	buildCenter(safe)
	buildToasts(safe)
	buildShop(safe)
	buildStages(safe)
	buildSettings(safe)
	buildView(safe)
	buildPrestige(safe, "curtainCall", 186, UIKit.Colors.pink, "Curtain Call", "ui_curtain", "Take a bow", function()
		handlers.curtainCall()
	end)
	buildPrestige(safe, "rebirth", 250, UIKit.Colors.sky, "Rebirth", "ui_rebirth", "Be reborn", function()
		handlers.rebirth()
	end)

	-- beat ring animation
	RunService.RenderStepped:Connect(function()
		local phase = Beat.phase()
		local pulse = math.max(0, 1 - phase * 4) -- big right on the beat
		local toBeat = 1 - phase -- 1 just after a beat, 0 on the next one
		local size = 64 + 86 * toBeat
		refs.beatRing.Size = UDim2.fromOffset(size, size)
		local ringStroke = refs.beatRing:FindFirstChildOfClass("UIStroke") :: UIStroke
		ringStroke.Transparency = 0.1 + 0.8 * toBeat
		local offset = math.min(phase, 1 - phase) * T.BeatInterval
		local inWindow = offset <= T.GoodWindow
		local targetStroke = refs.beatTarget:FindFirstChildOfClass("UIStroke") :: UIStroke
		targetStroke.Color = if offset <= T.PerfectWindow then GOLD elseif inWindow then WHITE else Color3.fromRGB(150, 150, 160)
		targetStroke.Transparency = if inWindow then 0.05 else 0.55
		refs.beatDot.BackgroundTransparency = 0.6 - 0.5 * pulse
		refs.beatDot.Size = UDim2.fromOffset(16 + 10 * pulse, 16 + 10 * pulse)
		-- the badge pulses on the beat when something is affordable
		if refs.shopBadge.Visible then
			refs.shopBadge.Size = UDim2.fromOffset(26 + 6 * pulse, 26 + 6 * pulse)
		end
		HUD.updateOvation()
	end)
end

function HUD.setPredictedClaps(n: number)
	predictedClaps = n
end

function HUD.setStreak(n: number)
	streak = n
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
	local isVisiting = stageId < s.stage
	local value = Formulas.displayValue(stage.id, t)
	local valueText: string
	if d.suffix == " dB" then
		valueText = string.format("%d dB", math.floor(value))
	elseif d.suffix == "×" then
		valueText = Format.number(value) .. "×"
	else
		valueText = Format.number(value) .. d.suffix
	end
	if isVisiting then
		valueText ..= " MAX"
	end
	refs.value.Text = string.format("%s <font face=\"Merriweather\" size=\"36\" color=\"#E8B866\">%s</font>", d.label, valueText)

	refs.meterFill.Size = UDim2.new(t, 0, 1, 0)
	local tier = if stageId == s.stage then (s.tier or 0) else #stage.tiers
	refreshTicks(stageId, tier)
	local nextTier = stage.tiers[tier + 1]
	local function unitText(value: number): string
		if d.suffix == " dB" then
			return string.format("%d dB", math.floor(value))
		elseif d.suffix == "×" then
			return Format.number(value) .. "×"
		end
		return Format.number(value) .. d.suffix
	end
	if isVisiting then
		refs.meterLabel.Text = string.format("⭐ Visiting · your best is Stage %d · earnings reduced here", s.stage)
	elseif nextTier then
		refs.meterLabel.Text = string.format(
			"Tier %d/%d · next: <b>%s</b> at %s",
			tier,
			#stage.tiers,
			nextTier.name,
			unitText(Formulas.displayValue(stage.id, nextTier.at))
		)
	elseif capped then
		refs.meterLabel.Text = "Final stage for now · more coming soon"
	else
		refs.meterLabel.Text = string.format("Next: <b>BREAKTHROUGH</b> at %s", unitText(Formulas.displayValue(stage.id, 1)))
	end

	refs.applause.Text = Format.short(s.applause)
	local auto = Formulas.autoClapsPerSecond(s :: any)
	local rate = if auto > 0
		then string.format("Classmates: +%s/s · Power %s", Format.short(s.clapPower + math.log10(auto * T.AutoEfficiency)), Format.short(s.clapPower))
		else string.format("Clap power %s", Format.short(s.clapPower))
	local bouquets = s.bouquets or 0
	if bouquets > 0 then
		rate ..= string.format(" · Bouquets %s (×%s)", Format.number(bouquets), Format.number(Formulas.bouquetMultiplier(bouquets)))
	end
	local rebirths = s.rebirths or 0
	if rebirths > 0 then
		rate ..= string.format(" · Rebirth %d", rebirths)
	end
	refs.rate.Text = rate

	-- Curtain Call: from the City onwards, any time you're in your own stage
	local call = refs.curtainCall
	local canCall = s.canCurtainCall == true and stageId == s.stage
	call.button.Visible = canCall
	if canCall then
		local gained = s.bouquetsOnCall or 0
		UIKit.setButton(call.button, nil, string.format("Curtain Call  +%s Bouquets", Format.number(gained)))
		call.body.Text = string.format(
			"Take a bow and start the show again from the ceremony with <font color=\"#E8B866\">+%s Bouquets</font>.\n\nBouquets: %s → %s, clap power <b>×%s</b> (until you Rebirth).\nApplause, upgrades, classmates and stages reset. The further you get before your Curtain Call, the more Bouquets you're thrown.",
			Format.number(gained),
			Format.number(bouquets),
			Format.number(bouquets + gained),
			Format.number(Formulas.bouquetMultiplier(bouquets + gained))
		)
	elseif call.modal.isOpen() then
		call.modal.close()
	end

	-- Rebirth: once Space's escape velocity is full
	local reborn = refs.rebirth
	reborn.button.Visible = s.canRebirth == true
	if s.canRebirth then
		UIKit.setButton(reborn.button, nil, string.format("Rebirth %d", rebirths + 1))
		reborn.body.Text = string.format(
			"Start everything again, Bouquets included, as Rebirth %d:\n\n• clap power <b>×%d</b> forever (×%s total)\n• Bouquets <b>×%d</b> from every Curtain Call\n• %s\n\nYour Rebirths count on the leaderboards.",
			rebirths + 1,
			T.RebirthPowerMultiplier,
			Format.number(T.RebirthPowerMultiplier ^ (rebirths + 1)),
			T.RebirthBouquetMultiplier ^ (rebirths + 1),
			if rebirths == 0 then "angel wings" elseif rebirths == 1 then "a glowing halo" else "a brighter clap trail"
		)
	elseif reborn.modal.isOpen() then
		reborn.modal.close()
	end

	if captionLocked then
		-- a cinematic owns the caption
	elseif s.canRebirth and stageId == s.stage then
		HUD.setCaption("You've beaten Space. Time to be reborn.", "転生")
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
	refreshStages()
	refreshSettings()
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

local GRADE_STYLE: { [string]: { text: string, color: Color3 } } = {
	Perfect = { text = "PERFECT", color = GOLD },
	Great = { text = "GREAT", color = Color3.fromRGB(150, 210, 255) },
	Good = { text = "GOOD", color = WHITE },
	Miss = { text = "MISS", color = Color3.fromRGB(255, 95, 95) },
}

-- grade text over the beat ring + floating amount (gained, or lost on a Miss)
function HUD.grade(grade: string, amountLog: number, combo: number, streakNow: number?)
	local style = GRADE_STYLE[grade]
	refs.gradeLabel.Text = style.text
	refs.gradeLabel.TextColor3 = style.color
	refs.gradeLabel.TextTransparency = 0
	refs.gradeLabel.Position = UDim2.new(0.5, 0, 0, 4)
	local scale = refs.gradeLabel:FindFirstChildOfClass("UIScale") or create("UIScale", { Parent = refs.gradeLabel })
	scale.Scale = if grade == "Perfect" then 1.35 else 1.1
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	TweenService:Create(refs.gradeLabel, TweenInfo.new(0.5), { TextTransparency = 1, Position = UDim2.new(0.5, 0, 0, -12) }):Play()
	if grade == "Miss" then
		HUD.popup(amountLog, style.color, "−")
	else
		HUD.popup(amountLog, if grade == "Perfect" then GOLD else WHITE, "+")
	end
	if streakNow and streakNow > 0 and streakNow % 10 == 0 then
		HUD.toast(string.format("%d beat streak! ×%.1f combo", streakNow, combo), GOLD, 1.2)
	end
end

-- big centre banner for a tier-up: "TIER 2 · PAINFUL" + bonus
function HUD.tierUp(tier: number, count: number, name: string, jp: string?, bonusLog: number)
	local holder = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(520, 120),
		BackgroundTransparency = 1,
		Parent = refs.popups,
	})
	local small = text({
		Size = UDim2.new(1, 0, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 18,
		TextColor3 = GOLD,
		Text = string.format("TIER %d / %d", tier, count),
		Parent = holder,
	})
	local big = text({
		Position = UDim2.new(0, 0, 0, 22),
		Size = UDim2.new(1, 0, 0, 56),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = SERIF,
		TextSize = 48,
		Text = string.upper(name),
		Parent = holder,
	})
	local sub = text({
		Position = UDim2.new(0, 0, 0, 80),
		Size = UDim2.new(1, 0, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 18,
		FontFace = SANS_MED,
		Text = string.format("%s  +%s Applause", jp or "", Format.short(bonusLog)),
		Parent = holder,
	})
	local scale = create("UIScale", { Scale = 0.6, Parent = holder })
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(1.8, function()
		local fade = TweenInfo.new(0.5)
		for _, label in { small, big, sub } do
			TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
		end
		task.wait(0.55)
		holder:Destroy()
	end)
end

-- first-person shockwave: a ring bursting out from between the hands
function HUD.screenRing(grade: string, t: number)
	if grade == "Miss" then
		return
	end
	local perfect = grade == "Perfect"
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
function HUD.popup(amountLog: number, color: Color3, sign: string)
	local label = text({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5 + (math.random() - 0.5) * 0.18, 0, 0.44 + (math.random() - 0.5) * 0.06, 0),
		Size = UDim2.new(0, 200, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = if color == GOLD then 26 else 20,
		FontFace = SERIF,
		TextColor3 = color,
		Text = sign .. Format.short(amountLog),
		Parent = refs.popups,
	})
	local target = label.Position - UDim2.new(0, 0, 0.06, 0)
	TweenService:Create(label, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = target, TextTransparency = 1 }):Play()
	task.delay(0.75, function()
		label:Destroy()
	end)
end

return HUD
