--!strict
-- Per-stage camera rigs, clap punch/shake, and the Breakthrough pull-back.
--   Stage 1: first-person from your seat
--   Stage 2: top-down on you (rises with progress)
--   Stage 3: high aerial over the town

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local CameraRig = {}

local player = Players.LocalPlayer
local stageId = 1
local progress = 0
local shake = 0
local punch = 0
local transition: { started: number, from: CFrame, rise: number }? = nil
local smoothed: CFrame? = nil

local BASE_FOV = 70

local function rootPart(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function stageModel(id: number): Instance?
	local stages = workspace:FindFirstChild("Stages")
	return stages and stages:FindFirstChild(Config.getStage(id).key)
end

local function targetCFrame(): CFrame?
	local root = rootPart()
	if not root then
		return nil
	end
	local pos = root.Position
	if stageId == 1 then
		local model = stageModel(1)
		local target = model and model:FindFirstChild("CameraTarget") :: BasePart?
		local humanoid = (player.Character :: Model):FindFirstChildOfClass("Humanoid")
		local seat = humanoid and humanoid.SeatPart
		local eye = if seat then seat.Position + Vector3.new(0, 4.4, 0) else pos + Vector3.new(0, 1.6, 0)
		-- look at the stage, but mostly straight ahead so side seats don't feel skewed
		local look = if target then Vector3.new(eye.X * 0.65 + target.Position.X * 0.35, target.Position.Y, target.Position.Z) else eye + Vector3.new(0, 0, -50)
		-- subtle mouse parallax so the view feels alive
		local mouse = UserInputService:GetMouseLocation()
		local viewport = (workspace.CurrentCamera :: Camera).ViewportSize
		local mx = math.clamp((mouse.X / math.max(1, viewport.X) - 0.5) * 2, -1, 1)
		local my = math.clamp((mouse.Y / math.max(1, viewport.Y) - 0.5) * 2, -1, 1)
		return CFrame.lookAt(eye, look) * CFrame.Angles(math.rad(-my * 3), math.rad(-mx * 5), 0)
	elseif stageId == 2 then
		local height = 16 + 34 * progress
		return CFrame.lookAt(pos + Vector3.new(0, height, 0.01), pos) * CFrame.Angles(0, 0, 0)
	else
		local height = 70 + 110 * progress
		local back = 45 + 60 * progress
		return CFrame.lookAt(pos + Vector3.new(0, height, back), pos)
	end
end

function CameraRig.init()
	local camera = workspace.CurrentCamera :: Camera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = BASE_FOV

	RunService:BindToRenderStep("ClapCamera", Enum.RenderPriority.Camera.Value, function(dt)
		camera = workspace.CurrentCamera :: Camera
		camera.CameraType = Enum.CameraType.Scriptable
		shake = math.max(0, shake - dt * 3)
		punch = math.max(0, punch - dt * 6)

		local target: CFrame?
		if transition then
			local elapsed = os.clock() - transition.started
			local k = math.clamp(elapsed / 1.2, 0, 1)
			local eased = k * k * (3 - 2 * k)
			local pos = transition.from.Position + Vector3.new(0, transition.rise * eased, 0)
			local keep = transition.from.Rotation + pos
			local lookDown = CFrame.lookAt(pos, pos - Vector3.new(0, 1, 0.001))
			target = keep:Lerp(lookDown, eased)
		else
			target = targetCFrame()
		end
		if not target then
			return
		end

		if smoothed == nil or transition then
			smoothed = target
		else
			local alpha = 1 - math.exp(-dt * (if stageId == 1 then 20 else 6))
			smoothed = (smoothed :: CFrame):Lerp(target, alpha)
		end

		local amount = shake * shake
		local offset = Vector3.new(
			(math.random() - 0.5) * amount,
			(math.random() - 0.5) * amount,
			(math.random() - 0.5) * amount
		)
		camera.CFrame = (smoothed :: CFrame) + offset
		camera.FieldOfView = BASE_FOV - punch * 4
	end)
end

function CameraRig.setStage(id: number)
	stageId = id
	smoothed = nil
end

function CameraRig.setProgress(t: number)
	progress = t
end

-- intensity roughly 0..3 (stage - 1 + progress)
function CameraRig.clap(intensity: number)
	punch = math.min(1, punch + 0.6)
	shake = math.min(2.2, shake + 0.12 + intensity * 0.12)
end

function CameraRig.bigShake(amount: number)
	shake = math.min(4, shake + amount)
end

-- camera rockets upward while the screen flashes; ends when the new stage is set
function CameraRig.breakthrough()
	local camera = workspace.CurrentCamera :: Camera
	transition = { started = os.clock(), from = camera.CFrame, rise = 120 }
	shake = 3
end

function CameraRig.endTransition()
	transition = nil
	smoothed = nil
end

return CameraRig
