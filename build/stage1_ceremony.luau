-- Builds Stage 1 (The Ceremony) into workspace.Stages.Ceremony.
-- Run in Studio edit mode (via the Studio MCP execute_luau). Safe to re-run: replaces the old model.
--
-- Conventions used by the client (src/client/Environment.luau):
--   Spots/   Seat parts players are seated in (claimed by WorldService)
--   Chairs/  chair models; NPC classmates sit in chairs whose "Seat" attribute is not a player spot
--   Parts with attribute DamageKind = "Shatter" | "Swing" | "Rattle" | "Topple" react locally,
--   DamageAt = stage progress (0..1) at which the persistent damage appears.
--   CameraTarget part: where first-person cameras look.

local ORIGIN = Vector3.new(0, 0, 0)

local stages = workspace:FindFirstChild("Stages") or Instance.new("Folder")
stages.Name = "Stages"
stages.Parent = workspace
local old = stages:FindFirstChild("Ceremony")
if old then
	old:Destroy()
end

local model = Instance.new("Model")
model.Name = "Ceremony"

local function folder(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent or model
	return f
end

local function part(props)
	local p = Instance.new(props.ClassName or "Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		if k ~= "ClassName" and k ~= "Parent" and k ~= "Attrs" then
			p[k] = v
		end
	end
	if props.Attrs then
		for k, v in props.Attrs do
			p:SetAttribute(k, v)
		end
	end
	p.Parent = props.Parent or model
	return p
end

local function at(x, y, z)
	return CFrame.new(ORIGIN + Vector3.new(x, y, z))
end

local WOOD = Color3.fromRGB(201, 162, 122)
local WALL = Color3.fromRGB(236, 230, 218)
local CURTAIN = Color3.fromRGB(122, 30, 36)
local RED = Color3.fromRGB(196, 40, 48)
local WHITE = Color3.fromRGB(245, 243, 238)
local CHAIR = Color3.fromRGB(28, 28, 32)
local METAL = Color3.fromRGB(150, 150, 155)

local W, L, H = 110, 150, 42 -- hall width (x), length (z), height
local structure = folder("Structure")

-- floor & ceiling
part({ Name = "Floor", Size = Vector3.new(W, 1, L), CFrame = at(0, -0.5, 0), Color = WOOD, Material = Enum.Material.WoodPlanks, Parent = structure })
part({ Name = "Ceiling", Size = Vector3.new(W, 1, L), CFrame = at(0, H + 0.5, 0), Color = Color3.fromRGB(220, 216, 208), Parent = structure })

-- walls
part({ Name = "WallBack", Size = Vector3.new(W, H, 1), CFrame = at(0, H / 2, L / 2), Color = WALL, Parent = structure })
part({ Name = "WallFront", Size = Vector3.new(W, H, 1), CFrame = at(0, H / 2, -L / 2), Color = WALL, Parent = structure })

local windows = folder("Windows")
for side = -1, 1, 2 do
	local x = side * W / 2
	-- lower wall + upper band, windows between
	part({ Name = "WallLower", Size = Vector3.new(1, 20, L), CFrame = at(x, 10, 0), Color = WALL, Parent = structure })
	part({ Name = "WallUpper", Size = Vector3.new(1, 8, L), CFrame = at(x, H - 4, 0), Color = WALL, Parent = structure })
	for i = 0, 6 do
		local z = -L / 2 + 15 + i * 20
		part({ Name = "Pillar", Size = Vector3.new(1.6, H - 28, 3), CFrame = at(x, 20 + (H - 28) / 2, z - 10 + 1.5), Color = WALL, Parent = structure })
		part({
			Name = "Window",
			Size = Vector3.new(0.4, H - 28, 17),
			CFrame = at(x, 20 + (H - 28) / 2, z + 1.5),
			Color = Color3.fromRGB(190, 225, 245),
			Material = Enum.Material.Glass,
			Transparency = 0.45,
			Parent = windows,
			Attrs = { DamageKind = "Shatter", DamageAt = 0.82 + i * 0.02 },
		})
	end
	part({ Name = "Pillar", Size = Vector3.new(1.6, H - 28, 3), CFrame = at(x, 20 + (H - 28) / 2, L / 2 - 1.5), Color = WALL, Parent = structure })

	-- red & white bunting (kōhaku-maku) along the lower walls
	local stripe = 2
	for z = -L / 2 + 25, L / 2 - 6, stripe do
		local isRed = (math.floor((z + L) / stripe) % 2 == 0)
		part({
			Name = "Bunting",
			Size = Vector3.new(0.3, 9, stripe),
			CFrame = at(x - side * 0.8, 12, z + stripe / 2),
			Color = if isRed then RED else WHITE,
			Material = Enum.Material.Fabric,
			Parent = structure,
			Attrs = { DamageKind = "Rattle", DamageAt = 0.6 },
		})
	end
end

-- stage platform at the front (-Z)
local stageZ = -L / 2 + 14
part({ Name = "StagePlatform", Size = Vector3.new(W - 10, 4, 26), CFrame = at(0, 2, stageZ), Color = Color3.fromRGB(176, 136, 98), Material = Enum.Material.WoodPlanks, Parent = structure })
part({ Name = "StageSkirt", Size = Vector3.new(W - 10, 4, 0.4), CFrame = at(0, 2, stageZ + 13.2), Color = RED, Material = Enum.Material.Fabric, Parent = structure })
part({ Name = "StageStepL", Size = Vector3.new(8, 2, 3), CFrame = at(-30, 1, stageZ + 14.5), Color = Color3.fromRGB(176, 136, 98), Parent = structure })
part({ Name = "StageStepR", Size = Vector3.new(8, 2, 3), CFrame = at(30, 1, stageZ + 14.5), Color = Color3.fromRGB(176, 136, 98), Parent = structure })

-- curtains: back drop + side drapes made of folds
local curtains = folder("Curtains")
for i = -24, 24 do
	local x = i * 2.1
	part({
		Name = "CurtainFold",
		Size = Vector3.new(2.3, 32, 1.2),
		CFrame = at(x, 4 + 16, -L / 2 + 2 + (i % 2) * 0.6),
		Color = CURTAIN,
		Material = Enum.Material.Fabric,
		Parent = curtains,
		Attrs = { DamageKind = "Rattle", DamageAt = 0.7 },
	})
end
for side = -1, 1, 2 do
	for j = 0, 4 do
		part({
			Name = "CurtainFold",
			Size = Vector3.new(2.3, 34, 1.4),
			CFrame = at(side * (W / 2 - 6 - j * 2), 4 + 17, stageZ + 11 - (j % 2) * 0.7),
			Color = CURTAIN,
			Material = Enum.Material.Fabric,
			Parent = curtains,
		})
	end
end
part({ Name = "Valance", Size = Vector3.new(W - 8, 4, 1.6), CFrame = at(0, H - 4, stageZ + 11), Color = CURTAIN, Material = Enum.Material.Fabric, Parent = curtains })

-- ceremony banner: 卒業証書授与式
local banner = part({ Name = "Banner", Size = Vector3.new(44, 6.5, 0.6), CFrame = at(0, 31, -L / 2 + 3.5), Color = Color3.fromRGB(242, 239, 230), Parent = structure })
part({ Name = "BannerFrame", Size = Vector3.new(45.2, 7.6, 0.4), CFrame = at(0, 31, -L / 2 + 3.1), Color = Color3.fromRGB(40, 32, 26), Parent = structure })
local gui = Instance.new("SurfaceGui")
gui.Face = Enum.NormalId.Back
gui.CanvasSize = Vector2.new(1100, 160)
gui.LightInfluence = 0.6
gui.Parent = banner
local label = Instance.new("TextLabel")
label.Size = UDim2.fromScale(1, 1)
label.BackgroundTransparency = 1
label.Text = "卒業証書授与式"
label.TextScaled = true
label.FontFace = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold)
label.TextColor3 = Color3.fromRGB(25, 22, 20)
label.Parent = gui
local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0.12, 0)
pad.PaddingBottom = UDim.new(0.12, 0)
pad.Parent = label

-- lectern + flower stands
local props = folder("Props")
part({ Name = "Lectern", Size = Vector3.new(6, 5, 3.5), CFrame = at(0, 4 + 2.5, stageZ - 2), Color = Color3.fromRGB(110, 70, 42), Material = Enum.Material.Wood, Parent = props })
part({ Name = "LecternTop", Size = Vector3.new(6.6, 0.5, 4), CFrame = at(0, 9.2, stageZ - 2) * CFrame.Angles(math.rad(-12), 0, 0), Color = Color3.fromRGB(90, 56, 34), Material = Enum.Material.Wood, Parent = props })
part({ Name = "Table", Size = Vector3.new(10, 3.4, 4), CFrame = at(-14, 4 + 1.7, stageZ - 4), Color = WHITE, Material = Enum.Material.Fabric, Parent = props })
local flowerColors = { Color3.fromRGB(255, 182, 203), Color3.fromRGB(255, 240, 245), Color3.fromRGB(240, 120, 160), Color3.fromRGB(255, 220, 120), Color3.fromRGB(150, 200, 120) }
local rng = Random.new(7)
for _, fx in { -36, -20, 20, 36 } do
	part({ Name = "FlowerStand", Size = Vector3.new(1, 8, 1), CFrame = at(fx, 4 + 4, stageZ - 6), Color = Color3.fromRGB(40, 40, 40), Parent = props })
	for _ = 1, 18 do
		local offset = Vector3.new(rng:NextNumber(-2.4, 2.4), rng:NextNumber(-1.2, 1.8), rng:NextNumber(-2.4, 2.4))
		local d = rng:NextNumber(1.1, 1.8)
		part({
			Name = "Flower",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(d, d, d),
			CFrame = at(fx, 4 + 9.5, stageZ - 6) + offset,
			Color = flowerColors[rng:NextInteger(1, #flowerColors)],
			Parent = props,
			Attrs = { DamageKind = "Rattle", DamageAt = 0.5 },
		})
	end
end

-- hanging lights
local lights = folder("Lights")
for x = -30, 30, 30 do
	for z = -50, 50, 25 do
		part({ Name = "LightCord", Size = Vector3.new(0.2, 6, 0.2), CFrame = at(x, H - 3, z), Color = Color3.fromRGB(40, 40, 40), Parent = lights })
		local lamp = part({
			Name = "Lamp",
			Size = Vector3.new(3.4, 1.2, 3.4),
			CFrame = at(x, H - 6.6, z),
			Color = Color3.fromRGB(255, 250, 235),
			Material = Enum.Material.Neon,
			Parent = lights,
			Attrs = { DamageKind = "Swing", DamageAt = 0.45 },
		})
		local light = Instance.new("PointLight")
		light.Range = 34
		light.Brightness = 0.9
		light.Color = Color3.fromRGB(255, 240, 220)
		light.Shadows = false
		light.Parent = lamp
	end
end

-- chairs: 10 columns (aisle in the middle) x 9 rows, facing the stage (-Z)
local chairs = folder("Chairs")
local spots = folder("Spots")
local columns = { -22.5, -18, -13.5, -9, -4.5, 4.5, 9, 13.5, 18, 22.5 }
local spotIndex = 0
for row = 0, 8 do
	local z = -22 + row * 7
	for colIndex, x in columns do
		-- player spots: middle rows (3..4), all columns -> 20 seats
		local isSpot = row == 3 or row == 4
		local chair = Instance.new("Model")
		chair.Name = "Chair"
		local seatCF = at(x, 2.1, z)
		if isSpot then
			spotIndex += 1
			local seat = part({
				ClassName = "Seat",
				Name = string.format("Spot%02d", spotIndex),
				Size = Vector3.new(2.8, 0.4, 2.6),
				CFrame = seatCF,
				Color = CHAIR,
				Parent = spots,
			})
			;(seat :: Seat).Disabled = false
			chair:SetAttribute("PlayerSpot", seat.Name)
		else
			part({ Name = "Seat", Size = Vector3.new(2.8, 0.4, 2.6), CFrame = seatCF, Color = CHAIR, Parent = chair, Attrs = { DamageKind = "Topple", DamageAt = 0.35 + rng:NextNumber(0, 0.5) } })
		end
		part({ Name = "Back", Size = Vector3.new(2.8, 2.6, 0.3), CFrame = at(x, 3.6, z + 1.3) * CFrame.Angles(math.rad(8), 0, 0), Color = CHAIR, Parent = chair, Attrs = { DamageKind = "Rattle", DamageAt = 0.3 } })
		for _, lx in { -1.2, 1.2 } do
			part({ Name = "Leg", Size = Vector3.new(0.2, 2, 0.2), CFrame = at(x + lx, 1, z - 1), Color = METAL, Material = Enum.Material.Metal, Parent = chair })
			part({ Name = "Leg", Size = Vector3.new(0.2, 2, 0.2), CFrame = at(x + lx, 1, z + 1), Color = METAL, Material = Enum.Material.Metal, Parent = chair })
		end
		chair:SetAttribute("Row", row)
		chair:SetAttribute("Column", colIndex)
		chair:SetAttribute("SeatCFrame", seatCF)
		chair.Parent = chairs
	end
end

-- camera focus for first-person views
part({ Name = "CameraTarget", Size = Vector3.new(1, 1, 1), CFrame = at(0, 14, stageZ - 4), Transparency = 1, CanCollide = false, CanQuery = false, Parent = model })

for _, d in model:GetDescendants() do
	if d:IsA("BasePart") and d.Name ~= "Floor" and not d:IsA("Seat") then
		d.CanCollide = d.Name == "StagePlatform" or d.Name:find("Wall") ~= nil
	end
end

model.Parent = stages

-- remove template baseplate / spawn, add a spawn inside the hall
for _, name in { "Baseplate", "SpawnLocation" } do
	local inst = workspace:FindFirstChild(name)
	if inst then
		inst:Destroy()
	end
end
local spawn = Instance.new("SpawnLocation")
spawn.Name = "SpawnLocation"
spawn.Anchored = true
spawn.Size = Vector3.new(6, 0.4, 6)
spawn.CFrame = at(0, 0.2, 60)
spawn.Transparency = 1
spawn.CanCollide = false
spawn.Neutral = true
spawn.Duration = 0
spawn.Parent = workspace

return ("Ceremony built: %d parts, %d player spots"):format(#model:GetDescendants(), spotIndex)
