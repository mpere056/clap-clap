--!strict
-- The "NEXT UPDATE" countdown board, drawn locally beside where everyone stands. Dates come from
-- shared/Events (Events.Updates).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Events = require(Shared.Events)

local UpdateBoard = {}

local GOLD = Color3.fromRGB(232, 184, 102)
local NAVY = Color3.fromRGB(28, 36, 64)
local SANS = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Heavy)

-- board scale per walkable stage (matches the event decorations); none in the space stages
local SCALE = { 0.7, 1, 1.6, 6, 2.4, 12 }

local board: Model? = nil
local titleLabel: TextLabel
local timeLabel: TextLabel

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

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = SANS
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	for k, v in props do
		(l :: any)[k] = v
	end
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(10, 12, 24)
	stroke.Parent = l
	l.Parent = parent
	return l
end

local function build(cf: CFrame, scale: number, legH: number): Model
	local model = Instance.new("Model")
	model.Name = "UpdateBoard"
	local w, h = 12 * scale, 6.5 * scale
	-- two posts, a frame, and the screen facing the players
	for _, side in { -1, 1 } do
		part(model, { Size = Vector3.new(0.6, legH + h, 0.6) * Vector3.new(scale, 1, scale), CFrame = cf * CFrame.new(side * (w / 2 - 0.6 * scale), (legH + h) / 2, 0.3 * scale), Color = Color3.fromRGB(70, 60, 80) })
	end
	part(model, { Size = Vector3.new(w + 0.8 * scale, h + 0.8 * scale, 0.4 * scale), CFrame = cf * CFrame.new(0, legH + h / 2, 0.2 * scale), Color = GOLD, Material = Enum.Material.Neon })
	local screen = part(model, { Size = Vector3.new(w, h, 0.5 * scale), CFrame = cf * CFrame.new(0, legH + h / 2, 0), Color = NAVY })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40 / scale
	gui.LightInfluence = 0
	gui.Parent = screen
	label(gui, { Size = UDim2.fromScale(1, 0.14), Position = UDim2.fromScale(0, 0.1), TextColor3 = GOLD, Text = "👏 CLAP CLAP 👏" })
	titleLabel = label(gui, { Size = UDim2.fromScale(0.9, 0.3), Position = UDim2.fromScale(0.05, 0.28), Text = "NEXT UPDATE" })
	timeLabel = label(gui, { Size = UDim2.fromScale(0.8, 0.26), Position = UDim2.fromScale(0.1, 0.62), Text = "" })
	model.Parent = workspace
	return model
end

local function refresh()
	local update, released = Events.nextUpdate(workspace:GetServerTimeNow())
	local model = board
	if not model then
		return
	end
	model.Parent = if update then workspace else nil
	if not update then
		return
	end
	if released then
		titleLabel.Text = "UPDATE IS OUT!"
		timeLabel.Text = "🎉 Rejoin to play it"
	else
		local left = math.max(0, math.floor(update.at - workspace:GetServerTimeNow()))
		titleLabel.Text = string.upper(update.name)
		timeLabel.Text = string.format("%dd %dh %02dm %02ds", left // 86400, (left // 3600) % 24, (left // 60) % 60, left % 60)
	end
end

function UpdateBoard.init()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 1 then
			acc = 0
			refresh()
		end
	end)
end

-- put the board beside the audience of this stage: front-right of the spots, turned towards them
function UpdateBoard.place(stageId: number, stageKey: string)
	if board then
		board:Destroy()
		board = nil
	end
	local scale = SCALE[stageId]
	local stages = workspace:FindFirstChild("Stages")
	local model = stages and stages:FindFirstChild(stageKey)
	local spots = model and model:FindFirstChild("Spots")
	if not (scale and spots) then
		return
	end
	local list = spots:GetChildren()
	if #list == 0 then
		return
	end
	local facing = (list[1] :: BasePart).CFrame
	local look = Vector3.new(facing.LookVector.X, 0, facing.LookVector.Z).Unit
	local right = look:Cross(Vector3.yAxis)
	local center, maxRight, maxAhead = Vector3.zero, -math.huge, -math.huge
	for _, spot in list do
		local pos = (spot :: BasePart).Position
		center += pos
		maxRight = math.max(maxRight, pos:Dot(right))
		maxAhead = math.max(maxAhead, pos:Dot(look))
	end
	center /= #list
	-- right of the rightmost spot (the stats panel is on the left) and ahead of the front row; in the
	-- seated first-person hall it stands by the stage instead, where everyone is looking
	local sideways = if stageId == 1 then 17 else maxRight - center:Dot(right) + 6 * scale
	local ahead = maxAhead - center:Dot(look) + (if stageId == 1 then 20 else 8 * scale)
	local spot = center + right * sideways + look * ahead
	local hit = workspace:Raycast(spot + Vector3.new(0, 8 * scale, 0), Vector3.new(0, -40 * scale, 0))
	local ground = if hit then hit.Position else Vector3.new(spot.X, center.Y - 1, spot.Z)
	-- taller posts in the hall so it stands clear of the seated classmates' heads
	local legH = if stageId == 1 then 6 else 4 * scale
	board = build(CFrame.lookAt(ground, Vector3.new(center.X, ground.Y, center.Z)), scale, legH)
	refresh()
end

return UpdateBoard
