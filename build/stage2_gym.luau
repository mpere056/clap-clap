-- Builds Stage 2 (The Shockwave, school gym) into workspace.Stages.Gym. Safe to re-run.
-- Seen top-down: players sit in chairs in the middle of the court, loose chairs get blown outwards.
-- Same conventions as stage1_ceremony.luau (Spots/, Chairs/, DamageKind/DamageAt attributes).

local ORIGIN = Vector3.new(3000, 0, 0)

local stages = workspace:FindFirstChild("Stages") or Instance.new("Folder")
stages.Name = "Stages"
stages.Parent = workspace
local old = stages:FindFirstChild("Gym")
if old then
	old:Destroy()
end

local model = Instance.new("Model")
model.Name = "Gym"

local function folder(name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = model
	return f
end

local function part(props)
	local p = Instance.new(props.ClassName or "Part")
	p.Anchored = true
	p.CanCollide = false
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

local COURT = Color3.fromRGB(216, 185, 140)
local LINE = Color3.fromRGB(226, 120, 50)
local WHITE_LINE = Color3.fromRGB(245, 245, 240)
local WALL = Color3.fromRGB(232, 228, 218)
local CHAIR = Color3.fromRGB(28, 28, 32)
local METAL = Color3.fromRGB(150, 150, 155)

local W, L, H = 120, 160, 64
local structure = folder("Structure")
local rng = Random.new(21)

-- court floor and markings
part({ Name = "Floor", Size = Vector3.new(W, 1, L), CFrame = at(0, -0.5, 0), Color = COURT, Material = Enum.Material.WoodPlanks, CanCollide = true, Parent = structure })
part({ Name = "CentreLine", Size = Vector3.new(W - 20, 0.05, 0.6), CFrame = at(0, 0.03, 0), Color = LINE, Parent = structure })
for _, z in { -70, 70 } do
	part({ Name = "EndLine", Size = Vector3.new(W - 20, 0.05, 0.6), CFrame = at(0, 0.03, z), Color = WHITE_LINE, Parent = structure })
end
for _, x in { -50, 50 } do
	part({ Name = "SideLine", Size = Vector3.new(0.6, 0.05, 140), CFrame = at(x, 0.03, 0), Color = WHITE_LINE, Parent = structure })
end
-- centre circle out of short segments
for i = 0, 35 do
	local a = i / 36 * math.pi * 2
	part({ Name = "CircleLine", Size = Vector3.new(0.6, 0.05, 2.4), CFrame = at(math.cos(a) * 14, 0.03, math.sin(a) * 14) * CFrame.Angles(0, -a, 0), Color = LINE, Parent = structure })
end
-- key areas
for _, z in { -58, 58 } do
	part({ Name = "Key", Size = Vector3.new(20, 0.04, 24), CFrame = at(0, 0.02, z), Color = Color3.fromRGB(196, 120, 70), Transparency = 0.35, Parent = structure })
end

-- walls, ceiling
part({ Name = "Ceiling", Size = Vector3.new(W, 1, L), CFrame = at(0, H, 0), Color = Color3.fromRGB(210, 210, 205), Transparency = 1, Parent = structure })
for side = -1, 1, 2 do
	part({ Name = "WallSide", Size = Vector3.new(1, H, L), CFrame = at(side * W / 2, H / 2, 0), Color = WALL, Parent = structure })
	part({ Name = "WallEnd", Size = Vector3.new(W, H, 1), CFrame = at(0, H / 2, side * L / 2), Color = WALL, Parent = structure })
	-- wall padding strip
	part({ Name = "Padding", Size = Vector3.new(0.6, 6, L), CFrame = at(side * (W / 2 - 0.8), 3, 0), Color = Color3.fromRGB(40, 70, 130), Parent = structure })
	-- red & white bunting along the sides
	for z = -L / 2 + 10, L / 2 - 10, 2 do
		local isRed = (math.floor(z / 2) % 2 == 0)
		part({
			Name = "Bunting",
			Size = Vector3.new(0.3, 7, 2),
			CFrame = at(side * (W / 2 - 1.2), 10, z + 1),
			Color = if isRed then Color3.fromRGB(196, 40, 48) else Color3.fromRGB(245, 243, 238),
			Material = Enum.Material.Fabric,
			Parent = structure,
			Attrs = { DamageKind = "Rattle", DamageAt = 0.1 },
		})
	end
end

-- basketball hoops
for _, side in { -1, 1 } do
	local z = side * (L / 2 - 6)
	part({ Name = "Backboard", Size = Vector3.new(12, 7, 0.4), CFrame = at(0, 20, z), Color = Color3.fromRGB(250, 250, 250), Parent = structure, Attrs = { DamageKind = "Rattle", DamageAt = 0.2 } })
	part({ Name = "Rim", Size = Vector3.new(4, 0.3, 4), CFrame = at(0, 17, z - side * 2.4), Color = LINE, Parent = structure })
	part({ Name = "Pole", Size = Vector3.new(1, 22, 1), CFrame = at(0, 11, z + side * 3), Color = METAL, Parent = structure })
end

-- loose props that get blown around (local "Topple" chairs)
local chairs = folder("Chairs")
local spots = folder("Spots")

local function chairModel(cf, isSpot, index)
	local chair = Instance.new("Model")
	chair.Name = "Chair"
	if isSpot then
		local seat = part({ ClassName = "Seat", Name = string.format("Spot%02d", index), Size = Vector3.new(2.8, 0.4, 2.6), CFrame = cf, Color = CHAIR, CanCollide = true, Parent = spots })
		chair:SetAttribute("PlayerSpot", seat.Name)
	else
		part({ Name = "Seat", Size = Vector3.new(2.8, 0.4, 2.6), CFrame = cf, Color = CHAIR, Parent = chair, Attrs = { DamageKind = "Topple", DamageAt = rng:NextNumber(0.02, 0.9), Push = rng:NextNumber(20, 40) } })
	end
	part({ Name = "Back", Size = Vector3.new(2.8, 2.6, 0.3), CFrame = cf * CFrame.new(0, 1.5, 1.3) * CFrame.Angles(math.rad(8), 0, 0), Color = CHAIR, Parent = chair })
	for _, lx in { -1.2, 1.2 } do
		for _, lz in { -1, 1 } do
			part({ Name = "Leg", Size = Vector3.new(0.2, 2, 0.2), CFrame = cf * CFrame.new(lx, -1.1, lz), Color = METAL, Parent = chair })
		end
	end
	chair:SetAttribute("SeatCFrame", cf)
	chair.Parent = chairs
end

-- player spots: a loose 5 x 4 grid around centre court
local index = 0
for row = 0, 3 do
	for col = 0, 4 do
		index += 1
		local x = (col - 2) * 11 + rng:NextNumber(-1, 1)
		local z = (row - 1.5) * 11 + rng:NextNumber(-1, 1)
		chairModel(at(x, 2.1, z) * CFrame.Angles(0, math.rad(rng:NextNumber(-10, 10)), 0), true, index)
	end
end

-- leftover ceremony chairs in rows around the edges
for row = 0, 5 do
	for col = 0, 9 do
		local x = -40 + col * 9 + rng:NextNumber(-0.5, 0.5)
		local z = (if row < 3 then -64 + row * 7 else 34 + (row - 3) * 7) + rng:NextNumber(-0.5, 0.5)
		chairModel(at(x, 2.1, z) * CFrame.Angles(0, math.rad(rng:NextNumber(-8, 8)), 0), false, 0)
	end
end
for _ = 1, 30 do
	local x = rng:NextNumber(-48, 48)
	local z = rng:NextNumber(-30, 30)
	if math.abs(x) > 28 or math.abs(z) > 22 then
		chairModel(at(x, 2.1, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), false, 0)
	end
end

-- gym mats and a ball cart that also slide away
local props = folder("Props")
for i = 1, 6 do
	part({
		Name = "Mat",
		Size = Vector3.new(8, 0.8, 5),
		CFrame = at(-52 + 4, 0.4, -40 + i * 12) * CFrame.Angles(0, math.rad(rng:NextNumber(-6, 6)), 0),
		Color = Color3.fromRGB(60, 100, 170),
		Parent = props,
		Attrs = { DamageKind = "Rattle", DamageAt = 0.05 },
	})
end

-- lighting: indoor lamps high up
for x = -36, 36, 36 do
	for z = -60, 60, 30 do
		local lamp = part({ Name = "Lamp", Size = Vector3.new(4, 1, 4), CFrame = at(x, H - 4, z), Color = Color3.fromRGB(255, 250, 235), Material = Enum.Material.Neon, Parent = structure })
		local light = Instance.new("PointLight")
		light.Range = 50
		light.Brightness = 1.1
		light.Shadows = false
		light.Parent = lamp
	end
end

model.WorldPivot = at(0, 0, 0)
model.Parent = stages
return ("Gym built: %d parts, %d player spots"):format(#model:GetDescendants(), index)
