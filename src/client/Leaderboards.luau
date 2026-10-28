--!strict
-- 🏆 leaderboard panel (World top 100 / This server) and the board on the wall of the hall.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local Icons = require(Shared.Icons)

local UIKit = require(script.Parent.UIKit)

local Leaderboards = {}

local player = Players.LocalPlayer
local SANS_MED = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium)
local SERIF = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold)
local GOLD = Color3.fromRGB(232, 184, 102)
local MEDALS = { Color3.fromRGB(255, 205, 80), Color3.fromRGB(215, 220, 230), Color3.fromRGB(215, 140, 85) }

type Entry = { userId: number, name: string, rebirths: number, power: number, score: number }

local data: { world: { Entry }, server: { Entry } } = { world = {}, server = {} }
local tab = "world"
local list: ScrollingFrame
local panel: Frame
local yourRank: TextLabel
local tabs: { [string]: TextButton } = {}
local board: Part? = nil

local function label(props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextColor3 = Color3.new(1, 1, 1)
	l.FontFace = UIKit.FONT
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.RichText = true
	for k, v in props do
		(l :: any)[k] = v
	end
	return l
end

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function row(parent: Instance, rank: number, entry: Entry, order: number, height: number, textSize: number)
	local frame = Instance.new("Frame")
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, 0, 0, height)
	frame.BackgroundColor3 = if entry.userId == player.UserId then Color3.fromRGB(110, 85, 25) else Color3.fromRGB(28, 30, 42)
	frame.Parent = parent
	corner(frame, 10)
	local outline = Instance.new("UIStroke")
	outline.Color = UIKit.Colors.outline
	outline.Thickness = 2.5
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	outline.Parent = frame
	local medal = MEDALS[rank]
	label({
		Size = UDim2.new(0, 44, 1, 0),
		Position = UDim2.new(0, 8, 0, 0),
		TextSize = textSize + 2,
		FontFace = SERIF,
		TextColor3 = medal or Color3.new(1, 1, 1),
		Text = "#" .. rank,
		Parent = frame,
	})
	-- the #1 gets a crown before their name
	local nameX = 56
	if rank == 1 then
		UIKit.image({ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 52, 0.5, 0), Size = UDim2.fromOffset(height - 8, height - 8), Image = Icons.get("ui_crown"), Parent = frame })
		nameX += height - 4
	end
	label({
		Size = UDim2.new(1, -(nameX + 150), 1, 0),
		Position = UDim2.new(0, nameX, 0, 0),
		TextSize = textSize,
		TextColor3 = medal or Color3.new(1, 1, 1),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = entry.name,
		Parent = frame,
	})
	-- [wings] rebirths · best power, packed against the right edge
	local right = Instance.new("Frame")
	right.AnchorPoint = Vector2.new(1, 0)
	right.Position = UDim2.new(1, -10, 0, 0)
	right.Size = UDim2.new(0, 170, 1, 0)
	right.BackgroundTransparency = 1
	right.Parent = frame
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = right
	UIKit.image({ LayoutOrder = 1, Size = UDim2.fromOffset(height - 10, height - 10), Image = Icons.get("ui_rebirth"), Parent = right })
	label({
		LayoutOrder = 2,
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = textSize - 1,
		FontFace = SANS_MED,
		Text = string.format("%d · %s", entry.rebirths, Format.short(entry.power)),
		Parent = right,
	})
end

local function render()
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local entries = if tab == "world" then data.world else data.server
	for i, entry in entries do
		row(list, i, entry, i, 42, 18)
	end
	for key, button in tabs do
		UIKit.setButton(button, if key == tab then UIKit.Colors.gold else UIKit.Colors.grey)
	end
	local worldRank = player:GetAttribute("GlobalRank") :: number?
	local serverRank = player:GetAttribute("ServerRank") :: number?
	yourRank.Text = string.format(
		"You: %s in the world · #%s in this server",
		if worldRank then "#" .. worldRank else "not in the top 100",
		tostring(serverRank or "?")
	)
	if #data.world == 0 and tab == "world" then
		local empty = Instance.new("Frame")
		empty.BackgroundTransparency = 1
		empty.Size = UDim2.new(1, 0, 0, 40)
		empty.Parent = list
		label({ Size = UDim2.fromScale(1, 1), TextSize = 14, FontFace = SANS_MED, TextTransparency = 0.3, Text = "World rankings are loading (or need the published game).", Parent = empty })
	end
end

-- the board on the hall's left wall: world top 10 and this server's top 5
local function renderBoard()
	local stages = workspace:FindFirstChild("Stages")
	local hall = stages and stages:FindFirstChild("Ceremony")
	if not hall then
		return
	end
	if not board then
		local p = Instance.new("Part")
		p.Name = "LeaderboardBoard"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.Size = Vector3.new(0.4, 13, 24)
		p.CFrame = CFrame.new(-54.2, 12.5, -24)
		p.Color = Color3.fromRGB(28, 30, 38)
		p.Material = Enum.Material.SmoothPlastic
		p.Parent = workspace
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Right
		gui.CanvasSize = Vector2.new(960, 520)
		gui.LightInfluence = 0
		gui.Parent = p
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 4)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = gui
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 24)
		padding.PaddingRight = UDim.new(0, 24)
		padding.PaddingTop = UDim.new(0, 16)
		padding.Parent = gui
		board = p
	end
	local gui = (board :: Part):FindFirstChildOfClass("SurfaceGui") :: SurfaceGui
	for _, child in gui:GetChildren() do
		if child:IsA("Frame") or child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	label({ LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 52), FontFace = SERIF, TextSize = 40, TextColor3 = GOLD, Text = "WORLD TOP 10", Parent = gui })
	for i = 1, math.min(10, #data.world) do
		row(gui, i, data.world[i], i, 40, 26)
	end
	if #data.world == 0 then
		label({ LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 40), TextSize = 24, FontFace = SANS_MED, TextTransparency = 0.3, Text = "Rankings loading…", Parent = gui })
	end
end

function Leaderboards.init(remote: RemoteEvent)
	local modal = UIKit.modal({ name = "Leaderboard", title = "Leaderboards", icon = Icons.get("ui_trophy"), color = UIKit.Colors.purple, size = Vector2.new(600, 560) })
	local body = modal.body
	for i, key in { "world", "server" } do
		local b = UIKit.button({
			color = UIKit.Colors.grey,
			text = if key == "world" then "World top 100" else "This server",
			icon = Icons.get(if key == "world" then "crowd_Global" else "ui_crowd"),
			textSize = 20,
			size = UDim2.new(0.5, -6, 0, 52),
			position = UDim2.new((i - 1) * 0.5, (i - 1) * 6, 0, 0),
			parent = body,
		})
		b.Activated:Connect(function()
			tab = key
			render()
		end)
		tabs[key] = b
	end
	yourRank = label({ Position = UDim2.fromOffset(4, 60), Size = UDim2.new(1, -8, 0, 22), TextSize = 16, Text = "", Parent = body })
	list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(0, 88)
	list.Size = UDim2.new(1, 0, 1, -88)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = body
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingLeft = UDim.new(0, 4)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = list
	panel = modal.root
	modal.onOpen = render

	local toggle = UIKit.dockButton({ name = "LeaderboardToggle", text = "", icon = Icons.get("ui_trophy"), color = UIKit.Colors.purple, width = 66, order = 2 })
	toggle.Activated:Connect(modal.toggle)

	remote.OnClientEvent:Connect(function(payload)
		data = payload
		if panel.Visible then
			render()
		end
		renderBoard()
	end)
end

return Leaderboards
