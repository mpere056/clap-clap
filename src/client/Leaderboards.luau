--!strict
-- The leaderboard: a big framed board standing at the front left of the hall (stage 1), facing the
-- seats, like the boards in popular simulators. World top 8 by clap power (this server's players
-- when world rankings aren't available, e.g. in an unpublished place). No button or menu.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local Icons = require(Shared.Icons)

local UIKit = require(script.Parent.UIKit)

local Leaderboards = {}

local player = Players.LocalPlayer
local ROWS = 8
local FRAME = Color3.fromRGB(80, 170, 255)
local FRAME_DARK = Color3.fromRGB(40, 110, 200)
local SCREEN = Color3.fromRGB(16, 20, 36)
local PILL = Color3.fromRGB(60, 200, 110)
local MEDALS = { Color3.fromRGB(255, 205, 80), Color3.fromRGB(215, 220, 230), Color3.fromRGB(225, 150, 95) }

type Entry = { userId: number, name: string, rebirths: number, power: number, score: number }

local data: { world: { Entry }, server: { Entry } } = { world = {}, server = {} }
local rows: { { frame: Frame, rank: TextLabel, avatar: ImageLabel, name: TextLabel, value: TextLabel, wings: ImageLabel, crown: ImageLabel } } = {}
local subtitle: TextLabel
local footer: TextLabel
local thumbnails: { [number]: string } = {}

local function part(model: Model, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = model
	return p
end

local function text(parent: Instance, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = UIKit.FONT
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	for k, v in props do
		(l :: any)[k] = v
	end
	UIKit.outline(l, 3)
	l.Parent = parent
	return l
end

local function headshot(userId: number): string
	if thumbnails[userId] then
		return thumbnails[userId]
	end
	thumbnails[userId] = ""
	if userId > 0 then
		task.spawn(function()
			local ok, url = pcall(function()
				return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
			end)
			if ok then
				thumbnails[userId] = url
				Leaderboards.refresh()
			end
		end)
	end
	return ""
end

-- the board: two posts, a thick blue frame, a title banner on top and the list screen
local function build(cf: CFrame)
	local model = Instance.new("Model")
	model.Name = "LeaderboardBoard"
	-- tall legs so the list clears the seated classmates' heads
	local w, h, legH = 13, 15, 9
	for _, side in { -1, 1 } do
		part(model, { Size = Vector3.new(0.8, legH + 1, 0.8), CFrame = cf * CFrame.new(side * (w / 2 - 1.5), (legH + 1) / 2, 0.4), Color = FRAME_DARK })
	end
	part(model, { Size = Vector3.new(w + 1.6, h + 1.6, 0.6), CFrame = cf * CFrame.new(0, legH + h / 2, 0.3), Color = FRAME, Material = Enum.Material.Neon })
	part(model, { Size = Vector3.new(w + 2.4, 1, 1.2), CFrame = cf * CFrame.new(0, legH + 0.2, 0.2), Color = FRAME_DARK })
	local screen = part(model, { Size = Vector3.new(w, h, 0.6), CFrame = cf * CFrame.new(0, legH + h / 2, 0), Color = SCREEN })
	local banner = part(model, { Size = Vector3.new(w + 3, 3.6, 0.8), CFrame = cf * CFrame.new(0, legH + h + 1.6, -0.2) * CFrame.Angles(0, 0, math.rad(2)), Color = FRAME })

	-- title banner
	local top = Instance.new("SurfaceGui")
	top.Face = Enum.NormalId.Front
	top.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	top.PixelsPerStud = 40
	top.LightInfluence = 0
	top.Parent = banner
	local title = text(top, { Size = UDim2.fromScale(0.94, 0.86), Position = UDim2.fromScale(0.03, 0.07), Text = "TOP CLAPPERS", TextColor3 = Color3.fromRGB(255, 225, 90) })
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.fromRGB(255, 240, 120), Color3.fromRGB(120, 230, 90))
	gradient.Rotation = 90
	gradient.Parent = title

	-- the list
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = screen
	subtitle = text(gui, { Size = UDim2.new(1, -40, 0, 34), Position = UDim2.fromOffset(20, 10), Text = "WORLD · CLAP POWER", TextColor3 = Color3.fromRGB(150, 200, 255) })
	local list = Instance.new("Frame")
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(16, 52)
	list.Size = UDim2.new(1, -32, 1, -104)
	list.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	for i = 1, ROWS do
		local frame = Instance.new("Frame")
		frame.LayoutOrder = i
		frame.Size = UDim2.new(1, 0, 1 / ROWS, -6)
		frame.BackgroundColor3 = Color3.fromRGB(245, 248, 255)
		frame.Parent = list
		UIKit.corner(frame, 10)
		UIKit.outline(frame, 3)
		local rank = text(frame, { Size = UDim2.new(0, 46, 0.8, 0), Position = UDim2.new(0, 6, 0.1, 0), Text = "#" .. i })
		local avatar = Instance.new("ImageLabel")
		avatar.BackgroundColor3 = Color3.fromRGB(190, 215, 255)
		avatar.Size = UDim2.new(0, 40, 0, 40)
		avatar.AnchorPoint = Vector2.new(0, 0.5)
		avatar.Position = UDim2.new(0, 56, 0.5, 0)
		avatar.Parent = frame
		UIKit.corner(avatar, 8)
		UIKit.outline(avatar, 2)
		local crown = UIKit.image({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0, 76, 0, 4), Size = UDim2.fromOffset(28, 28), Image = Icons.get("ui_crown"), Parent = frame })
		local name = text(frame, { Size = UDim2.new(1, -290, 0.7, 0), Position = UDim2.new(0, 104, 0.15, 0), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(30, 34, 50), Text = "" })
		name:FindFirstChildOfClass("UIStroke"):Destroy()
		-- clap power pill on the right, with Rebirth wings when they have any
		local pill = Instance.new("Frame")
		pill.AnchorPoint = Vector2.new(1, 0.5)
		pill.Position = UDim2.new(1, -8, 0.5, 0)
		pill.Size = UDim2.new(0, 170, 0.8, 0)
		pill.BackgroundColor3 = PILL
		pill.Parent = frame
		UIKit.corner(pill, 8)
		UIKit.outline(pill, 2.5)
		local wings = UIKit.image({ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 4, 0.5, 0), Size = UDim2.fromOffset(30, 30), Image = Icons.get("ui_rebirth"), Parent = pill })
		local value = text(pill, { Size = UDim2.new(1, -40, 0.8, 0), Position = UDim2.new(0, 36, 0.1, 0), Text = "" })
		rows[i] = { frame = frame, rank = rank, avatar = avatar, name = name, value = value, wings = wings, crown = crown }
	end
	footer = text(gui, { AnchorPoint = Vector2.new(0, 1), Size = UDim2.new(1, -40, 0, 34), Position = UDim2.new(0, 20, 1, -10), Text = "", TextColor3 = Color3.fromRGB(255, 225, 120) })
	model.WorldPivot = cf
	model:ScaleTo(0.6) -- (shrinks round its feet)
	model.Parent = workspace
end

function Leaderboards.refresh()
	if #rows == 0 then
		return
	end
	local world = #data.world > 0
	local entries = if world then data.world else data.server
	subtitle.Text = if world then "WORLD · CLAP POWER" else "THIS SERVER · CLAP POWER"
	for i, r in rows do
		local entry = entries[i]
		r.frame.Visible = entry ~= nil
		if entry then
			local me = entry.userId == player.UserId
			r.frame.BackgroundColor3 = if me then Color3.fromRGB(255, 236, 160) else Color3.fromRGB(245, 248, 255)
			r.rank.TextColor3 = MEDALS[i] or Color3.new(1, 1, 1)
			r.crown.Visible = i == 1
			r.avatar.Image = headshot(entry.userId)
			r.name.Text = entry.name
			r.wings.Visible = entry.rebirths > 0
			r.value.Text = if entry.rebirths > 0 then string.format("%d · %s", entry.rebirths, Format.short(entry.power)) else Format.short(entry.power)
		end
	end
	local worldRank = player:GetAttribute("GlobalRank") :: number?
	footer.Text = if worldRank then string.format("You're #%d in the world!", worldRank) else "Clap harder to make the board!"
end

-- stand the board by the left corner of the stage, turned towards the seats (the Next Update board
-- stands at the front right), low enough to read and high enough to clear the classmates' heads
local function place()
	local stages = workspace:WaitForChild("Stages", 30)
	local hall = stages and stages:WaitForChild("Ceremony", 30)
	local spots = hall and hall:FindFirstChild("Spots")
	if not spots or #spots:GetChildren() == 0 then
		return
	end
	local list = spots:GetChildren()
	local facing = (list[1] :: BasePart).CFrame
	local look = Vector3.new(facing.LookVector.X, 0, facing.LookVector.Z).Unit
	local right = look:Cross(Vector3.yAxis)
	local center, maxAhead = Vector3.zero, -math.huge
	for _, spot in list do
		local pos = (spot :: BasePart).Position
		center += pos
		maxAhead = math.max(maxAhead, pos:Dot(look))
	end
	center /= #list
	local spot = center - right * 21 + look * (maxAhead - center:Dot(look) + 36)
	local hit = workspace:Raycast(spot + Vector3.new(0, 8, 0), Vector3.new(0, -40, 0))
	local ground = if hit then hit.Position else Vector3.new(spot.X, center.Y - 1, spot.Z)
	build(CFrame.lookAt(ground, Vector3.new(center.X, ground.Y, center.Z)))
end

function Leaderboards.init(remote: RemoteEvent)
	task.spawn(function()
		place()
		Leaderboards.refresh()
	end)
	remote.OnClientEvent:Connect(function(payload)
		data = payload
		Leaderboards.refresh()
	end)
end

return Leaderboards
