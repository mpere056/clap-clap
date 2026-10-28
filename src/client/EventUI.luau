--!strict
-- Event banner (countdown, currency, rush timer), the event shop, and currency drop pop-ups.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Events = require(Shared.Events)
local Format = require(Shared.Format)
local Icons = require(Shared.Icons)

local Store = require(script.Parent.Store)
local UIKit = require(script.Parent.UIKit)

local EventUI = {}

local player = Players.LocalPlayer

local gui: ScreenGui
local banner: TextButton
local bannerText: TextLabel
local bannerIcon: ImageLabel
local panel: Frame
local shop: UIKit.Modal
local list: ScrollingFrame
local balanceLabel: TextLabel
local buyHandler: (string) -> ()
local equipHandler: (string, string?) -> ()

local function round(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

local function countdown(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local days = seconds // 86400
	return string.format("%dD %02d:%02d:%02d", days, (seconds // 3600) % 24, (seconds // 60) % 60, seconds % 60)
end

local function themeColor(event: Events.Event): Color3
	return if event.theme == "halloween" then Color3.fromRGB(110, 40, 150) elseif event.theme == "christmas" then Color3.fromRGB(170, 30, 45) else Color3.fromRGB(60, 60, 90)
end

local lastShopKey = ""

-- items from past events the player owns, so they can still wear them after the event ends
local function collection(event: Events.Event?): { { item: Events.ShopItem, event: Events.Event } }
	local owned = {}
	local cosmetics = Store.state.cosmetics or {}
	for _, past in Events.List do
		if past ~= event then
			for _, item in past.shop do
				if cosmetics[item.id] then
					table.insert(owned, { item = item, event = past })
				end
			end
		end
	end
	return owned
end

local KIND_LABEL = { wings = "WINGS", trail = "TRAIL", title = "TITLE", boost = "BOOST" }

local function renderShop(event: Events.Event?, force: boolean?)
	-- only rebuild when something visible changed (rebuilding mid-click would eat the click)
	local s0 = Store.state
	local key = if event then event.id .. ":" .. tostring((s0.eventCurrency and s0.eventCurrency[event.id]) or 0) else "-"
	for _, past in Events.List do
		for _, item in past.shop do
			key ..= ":" .. tostring(s0.cosmetics and s0.cosmetics[item.id]) .. tostring(s0.equipped and s0.equipped[item.kind])
		end
	end
	if key == lastShopKey and not force then
		return
	end
	lastShopKey = key
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local s = Store.state
	local cards: { { item: Events.ShopItem, event: Events.Event, past: boolean } } = {}
	if event then
		for _, item in event.shop do
			table.insert(cards, { item = item, event = event, past = false })
		end
	end
	for _, entry in collection(event) do
		table.insert(cards, { item = entry.item, event = entry.event, past = true })
	end
	local balance = if event then (s.eventCurrency and s.eventCurrency[event.id]) or 0 else 0
	balanceLabel.Text = if event
		then string.format("You have %s %s · items are yours to keep", Format.number(balance), event.currency.name)
		else "Items from past events are yours to keep"
	for i, entry in cards do
		local item = entry.item
		local owned = s.cosmetics and s.cosmetics[item.id]
		local equipped = s.equipped and s.equipped[item.kind] == item.id
		local card = UIKit.card({ color = themeColor(entry.event), parent = list, layoutOrder = i })
		UIKit.pill(card, KIND_LABEL[item.kind] or "", UDim2.fromOffset(8, 8))
		if entry.past then
			UIKit.pill(card, string.upper(entry.event.theme), UDim2.new(1, -8, 0, 8), Vector2.new(1, 0))
		end
		local disc = UIKit.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 14),
			Size = UDim2.fromOffset(86, 86),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 1,
			Parent = card,
		})
		UIKit.rays(disc, 150)
		UIKit.image({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(110, 110), Image = Icons.get(item.icon), Parent = disc })
		local name = UIKit.label({ Position = UDim2.fromOffset(8, 108), Size = UDim2.new(1, -16, 0, 24), Text = item.name, Parent = card })
		UIKit.fitText(name, 20)
		-- owned items say so; the rest show their price with the event's currency
		local costIcon, sub = UIKit.costLine(card, UDim2.fromOffset(8, 136), UDim2.new(1, -16, 0, 28), 22)
		costIcon.Image = Icons.get(entry.event.currency.image)
		costIcon.Visible = not owned
		sub.TextColor3 = if owned then UIKit.Colors.money else Color3.fromRGB(255, 205, 70)
		sub.Text = if owned then (if equipped then "Wearing ✓" else "Owned ✓") else Format.number(item.cost)
		local action: TextButton
		if owned then
			action = UIKit.button({ color = if equipped then UIKit.Colors.red else UIKit.Colors.blue, text = if equipped then "Take off" else "Wear", textSize = 22, size = UDim2.new(1, -16, 0, 50), position = UDim2.fromOffset(8, 178), parent = card })
			action.Activated:Connect(function()
				equipHandler(item.kind, if equipped then nil else item.id)
			end)
		else
			local affordable = balance >= item.cost
			action = UIKit.button({ color = if affordable then UIKit.Colors.green else UIKit.Colors.grey, text = if item.kind == "boost" then "Use" else "Buy", textSize = 22, size = UDim2.new(1, -16, 0, 50), position = UDim2.fromOffset(8, 178), parent = card })
			action.Activated:Connect(function()
				buyHandler(item.id)
			end)
		end
	end
end

function EventUI.init(onBuy: (string) -> (), onEquip: (string, string?) -> ())
	buyHandler = onBuy
	equipHandler = onEquip
	gui = Instance.new("ScreenGui")
	gui.Name = "ClapEvent"
	gui.DisplayOrder = 5 -- the shop opens over the HUD
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")

	-- banner sits in the free space at the top centre, above the Applause counter
	banner = Instance.new("TextButton")
	banner.Name = "EventBanner"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 8)
	banner.Size = UDim2.new(0, 540, 0, 46)
	banner.AutoButtonColor = true
	banner.Text = ""
	banner.Visible = false
	banner.Parent = gui
	-- shrink with the HUD on small screens (same rule as HUD's fitHud) so it stays above the counter
	local bannerScale = Instance.new("UIScale")
	bannerScale.Parent = banner
	local function fitBanner()
		local camera = workspace.CurrentCamera
		local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		local s = math.clamp(math.min(viewport.X / 1000, viewport.Y / 560), 0.5, 1)
		bannerScale.Scale = s
		banner.Position = UDim2.new(0.5, 0, 0, 8 * s)
	end
	fitBanner()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitBanner)
	round(banner, 12)
	UIKit.outline(banner, 3)
	UIKit.sheen(banner, 0.3)
	bannerIcon = UIKit.image({ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 6, 0.5, 0), Size = UDim2.fromOffset(44, 44), Parent = banner })
	bannerText = UIKit.label({ Size = UDim2.new(1, -66, 1, 0), Position = UDim2.fromOffset(54, 0), TextSize = 19, Text = "", Parent = banner })
	UIKit.fitText(bannerText, 19)

	shop = UIKit.modal({ name = "EventShop", title = "Event Shop", icon = "", color = UIKit.Colors.purple, size = Vector2.new(820, 440) })
	panel = shop.root
	balanceLabel = UIKit.label({ Size = UDim2.new(1, 0, 0, 24), TextSize = 19, TextColor3 = Color3.fromRGB(255, 205, 70), TextXAlignment = Enum.TextXAlignment.Left, Text = "", Parent = shop.body })
	local holder = UIKit.create("Frame", { Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 1, -32), BackgroundTransparency = 1, Parent = shop.body })
	list = UIKit.grid(holder, Vector2.new(178, 238))

	banner.Activated:Connect(function()
		-- during an event: its shop (plus your collection); between events: just your collection
		local event = Events.get(ReplicatedStorage:GetAttribute("EventId") :: string?)
		shop.toggle()
		if shop.isOpen() then
			shop.title.Text = if event then event.name .. " Shop" else "Your Collection"
			shop.icon.Image = Icons.get(if event then event.image else "cur_present")
			UIKit.setModalColor(shop, if event then themeColor(event) else UIKit.Colors.purple)
			renderShop(event, true)
		end
	end)

	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		acc += dt
		if acc < 0.25 then
			return
		end
		acc = 0
		local now = workspace:GetServerTimeNow()
		local event = Events.get(ReplicatedStorage:GetAttribute("EventId") :: string?)
		local nextEvent = Events.get(ReplicatedStorage:GetAttribute("NextEventId") :: string?)
		if event then
			local balance = (Store.state.eventCurrency and Store.state.eventCurrency[event.id]) or 0
			local rushLeft = Events.rushLeft(event, now)
			local ends = if ReplicatedStorage:GetAttribute("EventForced") then "Studio test" else "ends in " .. countdown(event.endsAt - now)
			bannerText.Text = if rushLeft > 0
				then string.format("<b>%s!</b> %d× %s · %s · %s %s", string.upper(event.rush.name), event.rush.multiplier, event.currency.name, Format.time(rushLeft), Format.number(balance), event.currency.name)
				else string.format("<b>%s</b> %s · %s · %s %s ›", string.upper(event.name), event.jp, ends, Format.number(balance), event.currency.name)
			bannerIcon.Image = Icons.get(event.image)
			banner.BackgroundColor3 = if rushLeft > 0 then Color3.fromRGB(200, 120, 30) else themeColor(event)
			banner.Visible = true
			if panel.Visible then
				renderShop(event)
			end
		elseif nextEvent then
			bannerText.Text = string.format("<b>%s</b> starts in %s", string.upper(nextEvent.name), countdown(nextEvent.startsAt - now))
			bannerIcon.Image = Icons.get(nextEvent.image)
			banner.BackgroundColor3 = themeColor(nextEvent)
			banner.Visible = true
			if panel.Visible then
				renderShop(nil)
			end
		else
			banner.Visible = false
			if shop.isOpen() then
				shop.close()
			end
		end
	end)
end

-- "+1 [candy]" floating up from the beat ring
function EventUI.drop(amount: number, _icon: string)
	local event = Events.get(ReplicatedStorage:GetAttribute("EventId") :: string?)
	local holder = UIKit.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5 + (math.random() - 0.5) * 0.1, 0, 0.62, 0),
		Size = UDim2.fromOffset(140, 36),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local size = if amount > 1 then 28 else 22
	local image, text = UIKit.costLine(holder, UDim2.new(), UDim2.fromScale(1, 1), size)
	image.Image = if event then Icons.get(event.currency.image) else ""
	text.Text = "+" .. amount
	text.TextColor3 = Color3.fromRGB(255, 205, 90)
	local info = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(holder, info, { Position = holder.Position - UDim2.new(0, 0, 0.08, 0) }):Play()
	TweenService:Create(image, info, { ImageTransparency = 1 }):Play()
	TweenService:Create(text, info, { TextTransparency = 1 }):Play()
	local stroke = text:FindFirstChildOfClass("UIStroke")
	if stroke then
		TweenService:Create(stroke, info, { Transparency = 1 }):Play()
	end
	task.delay(0.85, function()
		holder:Destroy()
	end)
end

return EventUI
