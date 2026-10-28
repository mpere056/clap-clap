--!strict
-- The Upgrades menu: two tabs of item cards. "Your Clap" has Strong Hands and the next
-- techniques; "Crowd" has the auto-clapping classmates. Cards are coloured by the stage they
-- belong to, like item rarities.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local Format = require(Shared.Format)
local Num = require(Shared.Num)
local Icons = require(Shared.Icons)

local Store = require(script.Parent.Store)
local UIKit = require(script.Parent.UIKit)

local UpgradesUI = {}

local C = UIKit.Colors
local AMOUNTS: { any } = { 1, 10, "max" }
local CARD = Vector2.new(178, 238)
local TECH_SLOTS = 3 -- the next technique plus the two after it

type Card = {
	frame: Frame,
	icon: ImageLabel,
	level: TextLabel,
	stagePill: TextLabel,
	name: TextLabel,
	stat: TextLabel,
	cost: TextLabel,
	costIcon: ImageLabel,
	buttons: { TextButton },
	lock: Frame,
	lockText: TextLabel,
}

local modal: UIKit.Modal
local onBuy: (string, string?, any) -> ()
local tab = "clap"
local tabButtons: { [string]: TextButton } = {}
local grids: { [string]: ScrollingFrame } = {}
local handsCard: Card
local techCards: { Card } = {}
local crowdCards: { [string]: Card } = {}
type StatRow = { value: TextLabel }
local stats: { [string]: StatRow } = {}

local function makeCard(parent: Instance, order: number, color: Color3, buttonLabels: { string }, onClick: (number) -> ()): Card
	local frame = UIKit.card({ color = color, parent = parent, layoutOrder = order })
	-- icon on a soft dark disc
	local disc = UIKit.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(86, 86),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Parent = frame,
	})
	UIKit.rays(disc, 150)
	local icon = UIKit.image({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(110, 110), Parent = disc })
	local level = UIKit.pill(frame, "", UDim2.fromOffset(8, 8))
	local stagePill = UIKit.pill(frame, "", UDim2.new(1, -8, 0, 8), Vector2.new(1, 0))
	local name = UIKit.label({ Position = UDim2.fromOffset(8, 104), Size = UDim2.new(1, -16, 0, 24), Text = "", Parent = frame })
	UIKit.fitText(name, 20)
	local stat = UIKit.label({ Position = UDim2.fromOffset(8, 128), Size = UDim2.new(1, -16, 0, 26), TextSize = 22, TextColor3 = C.money, Text = "", Parent = frame }, 2.5)
	UIKit.fitText(stat, 22)
	local costIcon, cost = UIKit.costLine(frame, UDim2.fromOffset(8, 154), UDim2.new(1, -16, 0, 24), 18)
	costIcon.Image = Icons.get("ui_hands")
	local buttons = {}
	local gap = 6
	local width = (CARD.X - 16 - gap * (#buttonLabels - 1)) / #buttonLabels
	for i, labelText in buttonLabels do
		local b = UIKit.button({
			color = C.green,
			text = labelText,
			textSize = if #buttonLabels == 1 then 22 else 18,
			size = UDim2.fromOffset(width, 48),
			position = UDim2.fromOffset(8 + (i - 1) * (width + gap), 182),
			parent = frame,
		})
		b.Activated:Connect(function()
			onClick(i)
		end)
		table.insert(buttons, b)
	end
	local lock, lockText = UIKit.lockCover(frame)
	return { frame = frame, icon = icon, level = level, stagePill = stagePill, name = name, stat = stat, cost = cost, costIcon = costIcon, buttons = buttons, lock = lock, lockText = lockText }
end

local function setButtons(card: Card, cost: number?, locked: boolean)
	local ok = not locked and cost ~= nil and Num.gte(Store.state.applause, cost)
	for _, b in card.buttons do
		UIKit.setButton(b, if ok then C.green else C.grey)
	end
end

local function setTab(key: string)
	tab = key
	for k, grid in grids do
		grid.Visible = k == key
	end
	UIKit.setButton(tabButtons.clap, if key == "clap" then C.orange else C.grey)
	UIKit.setButton(tabButtons.crowd, if key == "crowd" then C.blue else C.grey)
end

function UpgradesUI.init(buy: (string, string?, any) -> ())
	onBuy = buy
	modal = UIKit.modal({ name = "Upgrades", title = "Upgrades", icon = Icons.get("ui_hands"), color = C.orange, size = Vector2.new(820, 520) })

	-- left column: tabs and your numbers
	local side = UIKit.create("Frame", { Name = "Side", Size = UDim2.new(0, 176, 1, 0), BackgroundTransparency = 1, Parent = modal.body })
	tabButtons.clap = UIKit.button({ name = "ClapTab", color = C.orange, text = "Your Clap", icon = Icons.get("ui_strong"), textSize = 21, size = UDim2.new(1, 0, 0, 58), parent = side })
	tabButtons.crowd = UIKit.button({ name = "CrowdTab", color = C.grey, text = "Crowd", icon = Icons.get("ui_crowd"), textSize = 21, size = UDim2.new(1, 0, 0, 58), position = UDim2.fromOffset(0, 68), parent = side })
	tabButtons.clap.Activated:Connect(function()
		setTab("clap")
	end)
	tabButtons.crowd.Activated:Connect(function()
		setTab("crowd")
	end)
	local box = UIKit.create("Frame", {
		Position = UDim2.fromOffset(0, 142),
		Size = UDim2.new(1, 0, 1, -142),
		BackgroundColor3 = C.inset,
		Parent = side,
	})
	UIKit.corner(box, 12)
	UIKit.outline(box, 3)
	-- your numbers, one icon row each
	for i, row in {
		{ key = "applause", icon = "ui_hands", title = "Applause", color = Color3.fromRGB(255, 205, 70) },
		{ key = "power", icon = "tech_Thunder", title = "Clap power", color = Color3.fromRGB(255, 205, 70) },
		{ key = "crowd", icon = "ui_crowd", title = "Crowd", color = C.money },
		{ key = "techniques", icon = "crowd_Teacher", title = "Techniques", color = Color3.fromRGB(150, 210, 255) },
	} do
		local y = 8 + (i - 1) * 70
		UIKit.image({ Position = UDim2.fromOffset(8, y + 4), Size = UDim2.fromOffset(46, 46), Image = Icons.get(row.icon), Parent = box })
		UIKit.label({ Position = UDim2.fromOffset(60, y), Size = UDim2.new(1, -66, 0, 22), TextSize = 16, TextColor3 = row.color, TextXAlignment = Enum.TextXAlignment.Left, Text = row.title, Parent = box })
		local value = UIKit.label({ Position = UDim2.fromOffset(60, y + 24), Size = UDim2.new(1, -66, 0, 24), TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, Text = "", Parent = box })
		UIKit.fitText(value, 20)
		stats[row.key] = { value = value }
	end

	local area = UIKit.create("Frame", {
		Position = UDim2.fromOffset(190, 0),
		Size = UDim2.new(1, -190, 1, 0),
		BackgroundTransparency = 1,
		Parent = modal.body,
	})
	grids.clap = UIKit.grid(area, CARD)
	grids.crowd = UIKit.grid(area, CARD, { Visible = false })

	handsCard = makeCard(grids.clap, 1, C.gold, { "+1", "+10", "MAX" }, function(i)
		onBuy("hands", nil, AMOUNTS[i])
	end)
	for slot = 1, TECH_SLOTS do
		local card = makeCard(grids.clap, 1 + slot, C.grey, { "Learn" }, function()
			local tech = Formulas.nextTechnique(Store.state :: any)
			if tech then
				onBuy("technique", tech.id, 1)
			end
		end)
		table.insert(techCards, card)
	end
	for i, def in Config.Classmates do
		crowdCards[def.id] = makeCard(grids.crowd, i, UIKit.StageColors[def.stage] or C.grey, { "+1", "+10", "MAX" }, function(j)
			onBuy("classmate", def.id, AMOUNTS[j])
		end)
	end
	modal.onOpen = function()
		UpgradesUI.refresh()
	end
	setTab("clap")
end

function UpgradesUI.toggle()
	modal.toggle()
end

function UpgradesUI.isOpen(): boolean
	return modal.isOpen()
end

-- is any upgrade affordable right now? (drives the dock badge)
function UpgradesUI.anyAffordable(): boolean
	local s = Store.state
	if Num.gte(s.applause, Formulas.strongHandsCost(s.strongHands)) then
		return true
	end
	local tech = Formulas.nextTechnique(s :: any)
	if tech and tech.stage <= s.stage and Num.gte(s.applause, Formulas.techniqueCost(tech)) then
		return true
	end
	for _, def in Config.Classmates do
		if def.stage <= s.stage and Num.gte(s.applause, Formulas.classmateCost(def, s.classmates[def.id] or 0)) then
			return true
		end
	end
	return false
end

-- the techniques from the next unlearned one onwards
local function upcomingTechniques(): { Config.Technique }
	local s = Store.state
	local list = {}
	for _, tech in Config.Techniques do
		if not s.techniques[tech.id] then
			table.insert(list, tech)
			if #list == TECH_SLOTS then
				break
			end
		end
	end
	return list
end

function UpgradesUI.refresh()
	if not modal or not modal.isOpen() then
		return
	end
	local s = Store.state
	local learned = 0
	for _ in s.techniques do
		learned += 1
	end
	local auto = Formulas.autoClapsPerSecond(s :: any)
	stats.applause.value.Text = Format.short(s.applause)
	stats.power.value.Text = Format.short(s.clapPower)
	stats.crowd.value.Text = Format.number(auto) .. " /s"
	stats.techniques.value.Text = string.format("%d / %d", learned, #Config.Techniques)

	-- Strong Hands
	local handsCost = Formulas.strongHandsCost(s.strongHands)
	handsCard.icon.Image = Icons.get("ui_strong")
	handsCard.level.Text = "Lv " .. s.strongHands
	handsCard.stagePill.Visible = false
	handsCard.name.Text = "Strong Hands"
	handsCard.stat.Text = "+1 Clap Power"
	handsCard.cost.Text = Format.short(handsCost)
	setButtons(handsCard, handsCost, false)

	-- next techniques: the first can be learned, the rest show what's coming
	local upcoming = upcomingTechniques()
	for slot, card in techCards do
		local tech = upcoming[slot]
		card.frame.Visible = tech ~= nil
		if tech then
			local cost = Formulas.techniqueCost(tech)
			local stageLocked = tech.stage > s.stage
			local locked = stageLocked or slot > 1
			card.frame.BackgroundColor3 = UIKit.StageColors[tech.stage] or C.grey
			card.icon.Image = Icons.get("tech_" .. tech.id)
			card.level.Text = string.format("×%d", tech.mult)
			card.stagePill.Text = "STAGE " .. tech.stage
			card.name.Text = tech.name
			card.stat.Text = string.format("×%d Clap Power", tech.mult)
			card.stat.TextColor3 = Color3.fromRGB(255, 205, 70)
			card.cost.Text = Format.short(cost)
			card.costIcon.Visible = true
			card.lock.Visible = locked
			card.lockText.Text = if stageLocked
				then string.format("Reach Stage %d\n%s", tech.stage, Config.getStage(tech.stage).name)
				elseif slot > 1 then string.format("Learn %s first", upcoming[slot - 1].name)
				else ""
			setButtons(card, cost, locked)
		end
	end
	if #upcoming == 0 then
		local card = techCards[1]
		card.frame.Visible = true
		card.icon.Image = Icons.get("ui_trophy")
		card.level.Text = ""
		card.stagePill.Text = "DONE"
		card.name.Text = "All learned!"
		card.stat.Text = "Master clapper"
		card.cost.Text = ""
		card.costIcon.Visible = false
		card.lock.Visible = false
		setButtons(card, nil, true)
	end

	-- the crowd: everything up to one stage ahead
	for _, def in Config.Classmates do
		local card = crowdCards[def.id]
		local owned = s.classmates[def.id] or 0
		local locked = def.stage > s.stage
		card.frame.Visible = def.stage <= s.stage + 1
		local cost = Formulas.classmateCost(def, owned)
		card.icon.Image = Icons.get("crowd_" .. def.id)
		card.level.Text = "×" .. owned
		card.stagePill.Text = "STAGE " .. def.stage
		card.name.Text = def.name
		card.stat.Text = string.format("+%s claps/s", Format.number(def.cps))
		card.cost.Text = Format.short(cost)
		card.lock.Visible = locked
		card.lockText.Text = string.format("Reach Stage %d\n%s", def.stage, Config.getStage(def.stage).name)
		setButtons(card, cost, locked)
	end
end

return UpgradesUI
