--!strict
-- The look of a live event, drawn locally: colour grading, decorations around the stage you're
-- in, and ambient particles (bats, snow) that follow the camera. Add a new event look by adding
-- an entry to THEMES.

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local EventTheme = {}

type Theme = {
	tint: Color3,
	saturation: number,
	ambient: Color3?, -- blended into the stage's ambient light
	decor: (CFrame, number, Random) -> Model, -- one decoration at a spot, scaled
	particles: (ParticleEmitter) -> (),
}

local function piece(model: Model, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = model
	return p
end

local THEMES: { [string]: Theme } = {
	halloween = {
		tint = Color3.fromRGB(232, 212, 255),
		saturation = 0.1,
		ambient = Color3.fromRGB(110, 70, 150),
		decor = function(cf: CFrame, scale: number, rng: Random): Model
			-- jack-o'-lantern with a glowing face
			local model = Instance.new("Model")
			model.Name = "JackOLantern"
			local size = scale * rng:NextNumber(1.6, 2.6)
			local body = piece(model, { Shape = Enum.PartType.Ball, Size = Vector3.one * size, CFrame = cf + Vector3.new(0, size * 0.42, 0), Color = Color3.fromRGB(235, 120, 30) })
			piece(model, { Size = Vector3.new(0.15, 0.4, 0.15) * scale, CFrame = body.CFrame * CFrame.new(0, size * 0.52, 0), Color = Color3.fromRGB(70, 110, 50) })
			local face = piece(model, { Size = Vector3.new(size * 0.5, size * 0.25, 0.1 * scale), CFrame = body.CFrame * CFrame.new(0, 0, -size * 0.47), Color = Color3.fromRGB(255, 210, 90), Material = Enum.Material.Neon })
			-- a real light only indoors; a ring of big lights washes out the outdoor stages
			if scale <= 1.2 then
				local light = Instance.new("PointLight")
				light.Color = Color3.fromRGB(255, 150, 50)
				light.Range = 10
				light.Brightness = 1.2
				light.Parent = face
			end
			return model
		end,
		particles = function(emitter: ParticleEmitter)
			-- bats fluttering around
			emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
			emitter.Color = ColorSequence.new(Color3.fromRGB(30, 20, 40))
			emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.3) })
			emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.2), NumberSequenceKeypoint.new(1, 1) })
			emitter.Lifetime = NumberRange.new(2, 4)
			emitter.Rate = 6
			emitter.Speed = NumberRange.new(6, 12)
			emitter.SpreadAngle = Vector2.new(180, 40)
			emitter.RotSpeed = NumberRange.new(-300, 300)
		end,
	},
	christmas = {
		tint = Color3.fromRGB(225, 238, 255),
		saturation = -0.05,
		ambient = Color3.fromRGB(120, 140, 170),
		decor = function(cf: CFrame, scale: number, rng: Random): Model
			-- wrapped present with a ribbon
			local model = Instance.new("Model")
			model.Name = "Present"
			local colors = { Color3.fromRGB(200, 40, 50), Color3.fromRGB(40, 140, 70), Color3.fromRGB(240, 240, 245) }
			local size = scale * rng:NextNumber(1.4, 2.4)
			local box = piece(model, { Size = Vector3.one * size, CFrame = cf * CFrame.Angles(0, rng:NextNumber(0, 6), 0) + Vector3.new(0, size / 2, 0), Color = colors[rng:NextInteger(1, #colors)] })
			local gold = Color3.fromRGB(250, 205, 80)
			piece(model, { Size = Vector3.new(size * 1.02, size * 1.02, size * 0.18), CFrame = box.CFrame, Color = gold })
			piece(model, { Size = Vector3.new(size * 0.18, size * 1.02, size * 1.02), CFrame = box.CFrame, Color = gold })
			piece(model, { Shape = Enum.PartType.Ball, Size = Vector3.one * size * 0.35, CFrame = box.CFrame * CFrame.new(0, size * 0.55, 0), Color = gold, Material = Enum.Material.Neon })
			return model
		end,
		particles = function(emitter: ParticleEmitter)
			-- falling snow
			emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			emitter.Color = ColorSequence.new(Color3.new(1, 1, 1))
			emitter.Size = NumberSequence.new(0.3)
			emitter.Transparency = NumberSequence.new(0.1)
			emitter.Lifetime = NumberRange.new(4, 6)
			emitter.Rate = 60
			emitter.Speed = NumberRange.new(4, 7)
			emitter.SpreadAngle = Vector2.new(20, 20)
			emitter.EmissionDirection = Enum.NormalId.Bottom
			emitter.Acceleration = Vector3.new(1, -1, 0)
		end,
	},
}

-- decoration scale per stage; space stages have no ground for decorations
local DECOR_SCALE = { 1, 1.2, 3, 12, 4, 20 }

local folder: Folder
local grade: ColorCorrectionEffect
local emitterPart: Part
local emitter: ParticleEmitter
local current = ""
local baseAmbient: Color3? = nil -- the stage's own ambient, before any event tint

local function stageModel(stageId: number, key: string): Instance?
	local stages = workspace:FindFirstChild("Stages")
	return stages and stages:FindFirstChild(key)
end

function EventTheme.init()
	folder = Instance.new("Folder")
	folder.Name = "EventDecor"
	folder.Parent = workspace
	grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "EventGrade"
	grade.Enabled = false
	grade.Parent = Lighting
	emitterPart = Instance.new("Part")
	emitterPart.Name = "EventParticles"
	emitterPart.Anchored = true
	emitterPart.CanCollide = false
	emitterPart.CanQuery = false
	emitterPart.Transparency = 1
	emitterPart.Size = Vector3.new(80, 1, 80)
	emitterPart.Parent = folder
	emitter = Instance.new("ParticleEmitter")
	emitter.Enabled = false
	emitter.Parent = emitterPart
	-- keep the ambient particles around the camera
	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if camera and emitter.Enabled then
			emitterPart.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 25, 0))
		end
	end)
end

-- themeName "" clears the event look; stageKey is the stage model's name. freshLighting = stage
-- lighting was just reset, so Lighting.Ambient is the stage's own again.
function EventTheme.apply(themeName: string, stageId: number, stageKey: string, freshLighting: boolean?)
	local theme = THEMES[themeName]
	if freshLighting or not baseAmbient then
		baseAmbient = Lighting.Ambient
	end
	local base = baseAmbient :: Color3
	Lighting.Ambient = if theme and theme.ambient then base:Lerp(theme.ambient, 0.5) else base
	local key = themeName .. ":" .. stageId
	if key == current then
		return
	end
	current = key
	emitterPart.Parent = nil -- keep it out of the clear-out
	folder:ClearAllChildren()
	emitterPart.Parent = folder
	if not theme then
		grade.Enabled = false
		emitter.Enabled = false
		return
	end
	grade.Enabled = true
	grade.TintColor = theme.tint
	grade.Saturation = theme.saturation
	theme.particles(emitter)
	emitter.Enabled = true

	local scale = DECOR_SCALE[stageId]
	local model = stageModel(stageId, stageKey)
	local spots = model and model:FindFirstChild("Spots")
	if not (scale and spots) then
		return
	end
	-- a ring of decorations around where everyone stands
	local center = (model :: Model):GetPivot().Position
	local rng = Random.new(stageId * 97)
	local count = 14
	for i = 1, count do
		local angle = (i / count) * math.pi * 2 + rng:NextNumber(-0.15, 0.15)
		local radius = scale * rng:NextNumber(14, 26)
		local spot = center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		-- sit on whatever floor is there
		local hit = workspace:Raycast(spot + Vector3.new(0, 6 * scale, 0), Vector3.new(0, -30 * scale, 0))
		local ground = if hit then hit.Position else spot
		local facing = CFrame.lookAt(ground, Vector3.new(center.X, ground.Y, center.Z))
		local decor = theme.decor(facing, scale, rng)
		decor.Parent = folder
	end
end

return EventTheme
