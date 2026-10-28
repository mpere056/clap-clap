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
local walking = false
local smoothed: CFrame? = nil

-- first-person look-around: drag with the right mouse button, eases back to the stage on release
local lookYaw, lookPitch = 0, 0
local drag: { from: Vector2, yaw: number, pitch: number }? = nil

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
		-- turn around the world up axis, then tilt, so the horizon never rolls
		local dir = (look - eye).Unit
		local baseYaw = math.atan2(-dir.X, -dir.Z)
		local basePitch = math.asin(math.clamp(dir.Y, -1, 1))
		return CFrame.new(eye) * CFrame.Angles(0, baseYaw + math.rad(lookYaw), 0) * CFrame.Angles(basePitch + math.rad(lookPitch), 0, 0)
	elseif stageId == 2 then
		-- top-down on your chair in the gym
		local height = 16 + 34 * progress
		return CFrame.lookAt(pos + Vector3.new(0, height, 0.01), pos)
	elseif stageId == 3 then
		-- aerial over the town
		local height = 70 + 110 * progress
		local back = 45 + 60 * progress
		return CFrame.lookAt(pos + Vector3.new(0, height, back), pos)
	elseif stageId == 4 then
		-- satellite view, straight down, climbing as the craters grow
		local height = 260 + 700 * progress
		return CFrame.lookAt(pos + Vector3.new(0, height, 0.01), pos)
	elseif stageId == 5 then
		-- low and behind you, looking at the skyline and the mountains
		return CFrame.lookAt(pos + Vector3.new(0, 40 + 12 * progress, 110), pos + Vector3.new(0, 70, -900))
	elseif stageId == 6 then
		-- orbital view of the country
		return CFrame.lookAt(pos + Vector3.new(0, 500 + 900 * progress, 260 + 300 * progress), pos)
	elseif stageId == 7 or stageId == 8 then
		-- the whole planet from space, with you on top
		local center = Config.getStage(stageId).origin
		local model = stageModel(stageId)
		local radius = (model and model:GetAttribute("GlobeRadius") :: number?) or 600
		local up = (pos - center).Unit
		local dir = (up + Vector3.new(0, 0, 0.8)).Unit
		return CFrame.lookAt(center + dir * (radius * 2.6 + 700 * progress), center)
	else
		-- floating in space: slow orbit around you
		local angle = os.clock() * 0.08
		return CFrame.lookAt(pos + Vector3.new(math.cos(angle) * 46, 14, math.sin(angle) * 46), pos)
	end
end

function CameraRig.init()
	local camera = workspace.CurrentCamera :: Camera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = BASE_FOV

	RunService:BindToRenderStep("ClapCamera", Enum.RenderPriority.Camera.Value, function(dt)
		camera = workspace.CurrentCamera :: Camera
		if walking and not transition then
			-- Roblox's own follow camera is in charge; just add the clap punch
			shake = math.max(0, shake - dt * 3)
			punch = math.max(0, punch - dt * 6)
			camera.FieldOfView = BASE_FOV - punch * 4
			return
		end
		camera.CameraType = Enum.CameraType.Scriptable
		shake = math.max(0, shake - dt * 3)
		punch = math.max(0, punch - dt * 6)

		if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
			local mouse = UserInputService:GetMouseLocation()
			if not drag then
				drag = { from = mouse, yaw = lookYaw, pitch = lookPitch }
			end
			local start = drag :: { from: Vector2, yaw: number, pitch: number }
			local viewport = camera.ViewportSize
			lookYaw = math.clamp(start.yaw - (mouse.X - start.from.X) / math.max(1, viewport.X) * 140, -40, 40)
			lookPitch = math.clamp(start.pitch - (mouse.Y - start.from.Y) / math.max(1, viewport.Y) * 70, -15, 15)
		else
			drag = nil
			local ease = math.exp(-dt * 2.5)
			lookYaw *= ease
			lookPitch *= ease
		end

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

-- on: Roblox's follow camera (walking, or the close view on stages 2+); off: the stage's own rig
function CameraRig.setWalking(on: boolean)
	local was = walking
	walking = on
	local camera = workspace.CurrentCamera :: Camera
	if on and not was then
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local root = rootPart()
		camera.CameraType = Enum.CameraType.Custom
		if humanoid then
			camera.CameraSubject = humanoid
		end
		-- start behind the character instead of keeping the stage rig's angle
		if root then
			camera.CFrame = CFrame.lookAt((root.CFrame * CFrame.new(0, 5, 13)).Position, root.Position + Vector3.new(0, 2, 0))
		end
	else
		smoothed = nil
	end
end

function CameraRig.setStage(id: number)
	stageId = id
	smoothed = nil
end

function CameraRig.setProgress(t: number)
	progress = t
end

-- intensity: (furthest stage - 1) + progress; on-beat claps hit harder, misses barely register
function CameraRig.clap(intensity: number, grade: string)
	if grade == "Miss" then
		punch = math.min(1, punch + 0.15)
		return
	end
	local strength = if grade == "Perfect" then 1.4 elseif grade == "Great" then 1.1 else 0.8
	punch = math.min(1, punch + 0.6 * strength)
	shake = math.min(2.4, shake + (0.12 + math.min(intensity, 4) * 0.12) * strength)
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
