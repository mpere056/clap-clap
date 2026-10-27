--!strict
-- First-person clapping hands (stage 1). A local-only viewmodel attached to the camera.

local RunService = game:GetService("RunService")

local Hands = {}

local SKIN = Color3.fromRGB(234, 192, 160)
local SLEEVE = Color3.fromRGB(30, 42, 68)
local CUFF = Color3.fromRGB(240, 240, 240)

local model: Model? = nil
local left: Model? = nil
local right: Model? = nil
local visible = false
local clapT = 1 -- 0..1 through the current clap animation
local clapStrength = 1
local idleTime = 0

local function newPart(parent: Instance, name: string, size: Vector3, color: Color3, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

local HAND_SCALE = 0.62

-- Builds one hand in local space. side = 1 is the left hand (palm faces +X), -1 the right (mirrored).
-- Fingers point up (+Y), the thumb points towards the camera (+Z).
local function buildHand(side: number): Model
	local hand = Instance.new("Model")
	hand.Name = if side == 1 then "LeftHand" else "RightHand"
	local root = newPart(hand, "Root", Vector3.new(0.1, 0.1, 0.1), SKIN)
	root.Transparency = 1
	hand.PrimaryPart = root

	local S = HAND_SCALE
	local function add(name: string, size: Vector3, color: Color3, offset: CFrame, shape: Enum.PartType?)
		local p = newPart(hand, name, size * S, color, shape)
		p:SetAttribute("Offset", CFrame.new(offset.Position * S) * offset.Rotation)
	end

	add("Palm", Vector3.new(0.34, 1.2, 1.0), SKIN, CFrame.new(0, 0, 0))
	-- separate fingers with rounded tips, slightly fanned
	local fingerZ = { -0.36, -0.12, 0.12, 0.36 }
	local fingerLen = { 0.85, 1.0, 0.95, 0.72 }
	for i, z in fingerZ do
		local len = fingerLen[i]
		local fan = CFrame.Angles(math.rad((i - 2.5) * -4), 0, 0)
		local base = CFrame.new(0.02 * side, 0.58, z) * fan
		add("Finger", Vector3.new(0.27, len, 0.2), SKIN, base * CFrame.new(0, len / 2, 0))
		add("Tip", Vector3.new(0.27, 0.27, 0.27), SKIN, base * CFrame.new(0, len, 0), Enum.PartType.Ball)
	end
	-- thumb sticks out towards the camera and leans inwards
	local thumb = CFrame.new(0.1 * side, -0.05, 0.5) * CFrame.Angles(math.rad(40), 0, math.rad(-side * 16))
	add("Thumb", Vector3.new(0.29, 0.7, 0.26), SKIN, thumb * CFrame.new(0, 0.35, 0))
	add("ThumbTip", Vector3.new(0.29, 0.29, 0.29), SKIN, thumb * CFrame.new(0, 0.7, 0), Enum.PartType.Ball)
	add("Wrist", Vector3.new(0.6, 0.62, 0.62), SKIN, CFrame.new(0, -0.75, 0.05) * CFrame.Angles(0, 0, math.rad(90)), Enum.PartType.Cylinder)
	add("Cuff", Vector3.new(0.22, 0.86, 0.86), CUFF, CFrame.new(0, -1.08, 0.05) * CFrame.Angles(0, 0, math.rad(90)), Enum.PartType.Cylinder)
	add("Sleeve", Vector3.new(2.6, 1.0, 1.0), SLEEVE, CFrame.new(0, -2.45, 0.1) * CFrame.Angles(0, 0, math.rad(90)), Enum.PartType.Cylinder)
	return hand
end

local function placeHand(hand: Model, cf: CFrame)
	(hand.PrimaryPart :: BasePart).CFrame = cf
	for _, p in hand:GetChildren() do
		if p:IsA("BasePart") and p ~= hand.PrimaryPart then
			local offset = p:GetAttribute("Offset") :: CFrame?
			if offset then
				p.CFrame = cf * offset
			end
		end
	end
end

function Hands.init()
	model = Instance.new("Model")
	model.Name = "ClapHands"
	left = buildHand(1)
	right = buildHand(-1)
	;(left :: Model).Parent = model
	;(right :: Model).Parent = model

	RunService:BindToRenderStep("ClapHands", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local camera = workspace.CurrentCamera
		if not (model and left and right and camera) then
			return
		end
		if not visible then
			model.Parent = nil
			return
		end
		model.Parent = camera
		idleTime += dt
		clapT = math.min(1, clapT + dt / 0.2)

		-- clap curve: fast in (first 30%), slower out
		local closeness: number
		if clapT < 0.3 then
			closeness = clapT / 0.3
		else
			closeness = 1 - (clapT - 0.3) / 0.7
		end
		closeness = math.clamp(closeness, 0, 1) ^ 0.7

		local gap = 0.42 - 0.31 * closeness -- half distance between palms
		local bob = math.sin(idleTime * 2) * 0.02
		local push = -0.12 * closeness * clapStrength
		local base = camera.CFrame * CFrame.new(0, -1.1 + bob, -2.3 + push) * CFrame.Angles(math.rad(-8), 0, 0)

		-- hands lean outwards when open and snap upright as they meet
		local tilt = math.rad(14 - 12 * closeness)
		local turn = math.rad(18)
		placeHand(left, base * CFrame.new(-gap, 0, 0) * CFrame.Angles(0, -turn, -tilt))
		placeHand(right, base * CFrame.new(gap, 0, 0) * CFrame.Angles(0, turn, tilt))
	end)
end

function Hands.setVisible(on: boolean)
	visible = on
end

function Hands.clap(strength: number)
	clapT = 0
	clapStrength = strength
end

-- world position between the palms (for shockwave rings)
function Hands.clapPoint(): Vector3?
	local camera = workspace.CurrentCamera
	if not (visible and camera) then
		return nil
	end
	return (camera.CFrame * CFrame.new(0, -0.7, -2.4)).Position
end

return Hands
