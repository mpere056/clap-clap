-- Builds Stage 3 (The Town) into workspace.Stages.Town. Safe to re-run.
-- Seen from a high aerial camera: the school sits in the middle of a grid town; players stand on
-- the sports field. Roofs ("Peel") fly off earlier the closer they are to the school, trees rattle.

local ORIGIN = Vector3.new(6000, 0, 0)

local stages = workspace:FindFirstChild("Stages") or Instance.new("Folder")
stages.Name = "Stages"
stages.Parent = workspace
local old = stages:FindFirstChild("Town")
if old then
	old:Destroy()
end

local model = Instance.new("Model")
model.Name = "Town"

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
	p.CastShadow = true
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

local rng = Random.new(33)
local SIZE = 960
local BLOCK = 64
local ROAD = 10

local ground = folder("Ground")
part({ Name = "Grass", Size = Vector3.new(SIZE, 2, SIZE), CFrame = at(0, -1, 0), Color = Color3.fromRGB(127, 163, 106), Material = Enum.Material.Grass, CanCollide = true, Parent = ground })

-- road grid
local half = SIZE / 2
for v = -half + BLOCK / 2, half - BLOCK / 2, BLOCK do
	part({ Name = "Road", Size = Vector3.new(ROAD, 0.1, SIZE), CFrame = at(v, 0.05, 0), Color = Color3.fromRGB(150, 148, 140), Parent = ground })
	part({ Name = "Road", Size = Vector3.new(SIZE, 0.1, ROAD), CFrame = at(0, 0.06, v), Color = Color3.fromRGB(150, 148, 140), Parent = ground })
end

-- river along one side
for i = 0, 30 do
	local z = -half + i * (SIZE / 30)
	local x = 330 + math.sin(i * 0.5) * 30
	part({ Name = "River", Size = Vector3.new(34, 0.15, SIZE / 30 + 6), CFrame = at(x, 0.08, z) * CFrame.Angles(0, math.cos(i * 0.5) * 0.4, 0), Color = Color3.fromRGB(110, 150, 190), Material = Enum.Material.Glass, Transparency = 0.1, Parent = ground })
end

-- school in the middle block: main building, gym, sports field
local school = folder("School")
local field = part({ Name = "Field", Size = Vector3.new(70, 0.2, 54), CFrame = at(0, 0.1, 12), Color = Color3.fromRGB(196, 160, 110), Material = Enum.Material.Sand, CanCollide = true, Parent = school })
part({ Name = "SchoolBuilding", Size = Vector3.new(60, 18, 14), CFrame = at(0, 9, -30), Color = Color3.fromRGB(238, 234, 222), Parent = school })
part({ Name = "SchoolRoof", Size = Vector3.new(62, 1.2, 16), CFrame = at(0, 18.6, -30), Color = Color3.fromRGB(150, 150, 150), Parent = school, Attrs = { DamageKind = "Peel", DamageAt = 0.55 } })
for i = -5, 5 do
	part({ Name = "Window", Size = Vector3.new(3, 3, 0.2), CFrame = at(i * 5, 12, -22.9), Color = Color3.fromRGB(180, 215, 235), Material = Enum.Material.Glass, Parent = school, Attrs = { DamageKind = "Shatter", DamageAt = 0.05 + math.abs(i) * 0.02 } })
	part({ Name = "Window", Size = Vector3.new(3, 3, 0.2), CFrame = at(i * 5, 5, -22.9), Color = Color3.fromRGB(180, 215, 235), Material = Enum.Material.Glass, Parent = school, Attrs = { DamageKind = "Shatter", DamageAt = 0.08 + math.abs(i) * 0.02 } })
end
part({ Name = "Gym", Size = Vector3.new(30, 14, 24), CFrame = at(-48, 7, -6), Color = Color3.fromRGB(220, 215, 205), Parent = school })
part({ Name = "GymRoof", Size = Vector3.new(32, 1.5, 26), CFrame = at(-48, 14.75, -6), Color = Color3.fromRGB(70, 90, 120), Parent = school, Attrs = { DamageKind = "Peel", DamageAt = 0.02 } })

-- cherry trees around the field (video has one outside the school)
local trees = folder("Trees")
local function tree(x, z, blossom)
	part({ Name = "Trunk", Size = Vector3.new(1.2, 6, 1.2), CFrame = at(x, 3, z), Color = Color3.fromRGB(110, 80, 60), Parent = trees })
	local leafColor = if blossom then Color3.fromRGB(246, 196, 214) else Color3.fromRGB(96, 140, 80)
	part({ Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.new(7, 6, 7), CFrame = at(x, 7.5, z), Color = leafColor, Parent = trees, Attrs = { DamageKind = "Peel", DamageAt = 0.2 + math.sqrt(x * x + z * z) / 500 } })
end
for i = 0, 9 do
	tree(-38 + i * 8.5, 44, true)
end

-- houses on every other block
local houses = folder("Houses")
local WALLS = { Color3.fromRGB(240, 236, 226), Color3.fromRGB(226, 220, 205), Color3.fromRGB(210, 205, 196), Color3.fromRGB(236, 224, 200) }
local ROOFS = { Color3.fromRGB(80, 90, 105), Color3.fromRGB(120, 70, 60), Color3.fromRGB(70, 100, 120), Color3.fromRGB(95, 95, 95) }
local count = 0
for bx = -half + BLOCK, half - BLOCK, BLOCK do
	for bz = -half + BLOCK, half - BLOCK, BLOCK do
		local cx, cz = bx, bz
		local isSchool = math.abs(cx) < BLOCK and math.abs(cz) < BLOCK
		local inRiver = cx > 280 and cx < 380
		if not isSchool and not inRiver then
			-- 2 x 2 houses per block with gardens
			for hx = -1, 1, 2 do
				for hz = -1, 1, 2 do
					if rng:NextNumber() < 0.85 then
						local w = rng:NextNumber(12, 18)
						local d = rng:NextNumber(12, 18)
						local h = rng:NextNumber(8, 13)
						local x = cx + hx * 14 + rng:NextNumber(-2, 2)
						local z = cz + hz * 14 + rng:NextNumber(-2, 2)
						local yaw = CFrame.Angles(0, math.rad(rng:NextInteger(0, 1) * 90), 0)
						part({ Name = "House", Size = Vector3.new(w, h, d), CFrame = at(x, h / 2, z) * yaw, Color = WALLS[rng:NextInteger(1, #WALLS)], Parent = houses })
						local dist = math.sqrt(x * x + z * z)
						part({
							Name = "Roof",
							Size = Vector3.new(w + 1.5, 1.6, d + 1.5),
							CFrame = at(x, h + 0.8, z) * yaw,
							Color = ROOFS[rng:NextInteger(1, #ROOFS)],
							Parent = houses,
							Attrs = { DamageKind = "Peel", DamageAt = math.clamp(0.04 + dist / 520, 0, 0.98) + rng:NextNumber(-0.03, 0.03) },
						})
						count += 1
					else
						tree(cx + hx * 14, cz + hz * 14, false)
					end
				end
			end
		end
	end
end

-- player spots on the sports field
local spots = folder("Spots")
local index = 0
for row = 0, 3 do
	for col = 0, 4 do
		index += 1
		part({ Name = string.format("Spot%02d", index), Size = Vector3.new(4, 0.2, 4), CFrame = at((col - 2) * 12, 0.2, 12 + (row - 1.5) * 11), Transparency = 1, Parent = spots })
	end
end

model.WorldPivot = field.CFrame
model.Parent = stages
return ("Town built: %d parts, %d houses, %d player spots"):format(#model:GetDescendants(), count, index)
