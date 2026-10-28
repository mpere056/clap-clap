-- Builds Stage 3 (The Town) into workspace.Stages.Town. Safe to re-run.
-- Seen from a high aerial camera: the school sits in the middle of a grid town; players stand on
-- the sports field. Nothing here breaks for good: claps shove things (Environment.luau) and they
-- heal. The only lasting damage is the field cracking as your progress grows.
--
-- Each breakable carries DamageKind (and optionally Resist = clap force needed at that spot, Launch
-- = how far it flies) on the part, or on a Model to move all of its parts together:
--   Fly      thrown by the blast, bounces, flies home (roofs, chimneys, doors, fences, cars...)
--   Bend     bends away and springs back (trees, street lamps)
--   Shatter  glass breaks into shards, the pane comes back later
--   Reveal   fades in as your progress passes DamageAt (field cracks)

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
model.Parent = stages -- parented early and built in chunks so Studio doesn't freeze

local function folder(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent or model
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

-- a group that moves as one (cars, trees, lamps, mailboxes, goals); pivot: where it bends/spins from
local function group(name, parent, attrs, pivot)
	local m = Instance.new("Model")
	m.Name = name
	for k, v in attrs do
		m:SetAttribute(k, v)
	end
	m.Parent = parent
	return m, function()
		m.WorldPivot = pivot
	end
end

local function at(x, y, z)
	return CFrame.new(ORIGIN + Vector3.new(x, y, z))
end

local rng = Random.new(33)
local SIZE = 960
local BLOCK = 64
local ROAD = 10
local DETAIL = 330 -- houses closer than this to the school get the full set of breakables

local GLASS = Color3.fromRGB(180, 215, 235)
local WHITE = Color3.fromRGB(245, 245, 240)

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

----------------------------------------------------------------------------------------------------
-- school in the middle block: main building, gym, sports field

local school = folder("School")
local field = part({ Name = "Field", Size = Vector3.new(70, 0.2, 54), CFrame = at(0, 0.1, 12), Color = Color3.fromRGB(196, 160, 110), Material = Enum.Material.Sand, CanCollide = true, Parent = school })
part({ Name = "SchoolBuilding", Size = Vector3.new(60, 18, 14), CFrame = at(0, 9, -30), Color = Color3.fromRGB(238, 234, 222), Parent = school })
part({ Name = "SchoolRoof", Size = Vector3.new(62, 1.2, 16), CFrame = at(0, 18.6, -30), Color = Color3.fromRGB(150, 150, 150), Parent = school, Attrs = { DamageKind = "Fly", Resist = 0.45, Launch = 0.6 } })
for i = -5, 5 do
	for _, y in { 12, 5 } do
		part({ Name = "Window", Size = Vector3.new(3, 3, 0.2), CFrame = at(i * 5, y, -22.9), Color = GLASS, Material = Enum.Material.Glass, Parent = school, Attrs = { DamageKind = "Shatter", Resist = 0.1 } })
	end
end
-- clock on the front
part({ Name = "Clock", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 4, 4), CFrame = at(0, 15.5, -22.8) * CFrame.Angles(0, math.rad(90), 0), Color = WHITE, Parent = school, Attrs = { DamageKind = "Fly", Resist = 0.25, Launch = 1 } })
part({ Name = "Gym", Size = Vector3.new(30, 14, 24), CFrame = at(-48, 7, -6), Color = Color3.fromRGB(220, 215, 205), Parent = school })
part({ Name = "GymRoof", Size = Vector3.new(32, 1.5, 26), CFrame = at(-48, 14.75, -6), Color = Color3.fromRGB(70, 90, 120), Parent = school, Attrs = { DamageKind = "Fly", Resist = 0.4, Launch = 0.7 } })
for i = -2, 2 do
	part({ Name = "Window", Size = Vector3.new(0.2, 3, 3.5), CFrame = at(-32.9, 9, -6 + i * 4.5), Color = GLASS, Material = Enum.Material.Glass, Parent = school, Attrs = { DamageKind = "Shatter", Resist = 0.1 } })
end

-- field furniture: goals, balls, benches
local fieldStuff = folder("FieldProps", school)
for _, side in { -1, 1 } do
	local goal, done = group("Goal", fieldStuff, { DamageKind = "Fly", Resist = 0.1, Launch = 0.9 }, at(side * 33, 0, 12))
	for _, z in { -4, 4 } do
		part({ Name = "Post", Size = Vector3.new(0.4, 4, 0.4), CFrame = at(side * 33, 2.2, 12 + z), Color = WHITE, Parent = goal })
	end
	part({ Name = "Bar", Size = Vector3.new(0.4, 0.4, 8.4), CFrame = at(side * 33, 4.2, 12), Color = WHITE, Parent = goal })
	part({ Name = "Net", Size = Vector3.new(2.5, 4, 8), CFrame = at(side * 34.3, 2.2, 12), Color = WHITE, Transparency = 0.6, Parent = goal })
	done()
end
for i = 1, 5 do
	part({ Name = "Ball", Shape = Enum.PartType.Ball, Size = Vector3.new(1.2, 1.2, 1.2), CFrame = at(rng:NextNumber(-28, 28), 0.8, rng:NextNumber(-10, 34)), Color = if i % 2 == 0 then WHITE else Color3.fromRGB(240, 120, 60), Parent = fieldStuff, Attrs = { DamageKind = "Fly", Resist = 0.01, Launch = 1.6 } })
end
for i = -3, 3 do
	local bench, done = group("Bench", fieldStuff, { DamageKind = "Fly", Resist = 0.06, Launch = 1 }, at(i * 9, 0, 42))
	part({ Name = "Seat", Size = Vector3.new(5, 0.4, 1.4), CFrame = at(i * 9, 1.4, 42), Color = Color3.fromRGB(160, 110, 70), Parent = bench })
	part({ Name = "Back", Size = Vector3.new(5, 1.2, 0.3), CFrame = at(i * 9, 2.2, 42.6), Color = Color3.fromRGB(160, 110, 70), Parent = bench })
	for _, x in { -2, 2 } do
		part({ Name = "Leg", Size = Vector3.new(0.3, 1.2, 1.2), CFrame = at(i * 9 + x, 0.6, 42), Color = Color3.fromRGB(80, 80, 85), Parent = bench })
	end
	done()
end

-- lasting damage: the field cracks open as your progress grows (thin dark lines, hidden at first)
local cracks = folder("FieldCracks", school)
for i = 1, 14 do
	local angle = (i / 14) * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
	local length = rng:NextNumber(10, 26)
	local cf = at(0, 0.22, 12) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -length / 2 - 2)
	part({ Name = "Crack", Size = Vector3.new(rng:NextNumber(0.4, 0.9), 0.05, length), CFrame = cf, Color = Color3.fromRGB(60, 45, 35), Transparency = 1, CastShadow = false, Parent = cracks, Attrs = { DamageKind = "Reveal", DamageAt = 0.05 + (i / 14) * 0.85, Visible = 0 } })
end

----------------------------------------------------------------------------------------------------
-- trees and street lamps (bend and spring back)

local trees = folder("Trees")
local function tree(x, z, blossom)
	local t, done = group("Tree", trees, { DamageKind = "Bend", Resist = 0.12 }, at(x, 0, z))
	part({ Name = "Trunk", Size = Vector3.new(1.2, 6, 1.2), CFrame = at(x, 3, z), Color = Color3.fromRGB(110, 80, 60), Parent = t })
	local leafColor = if blossom then Color3.fromRGB(246, 196, 214) else Color3.fromRGB(96, 140, 80)
	part({ Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.new(7, 6, 7), CFrame = at(x, 7.5, z), Color = leafColor, Parent = t })
	done()
end
for i = 0, 9 do
	tree(-38 + i * 8.5, 50, true)
end

local lamps = folder("StreetLamps")
for v = -half + BLOCK / 2, half - BLOCK / 2, BLOCK do
	for w = -half + BLOCK / 2, half - BLOCK / 2, BLOCK do
		-- (a road crossing runs under the school field: no lamp there)
		if math.sqrt(v * v + w * w) < DETAIL and not (math.abs(v) < 40 and math.abs(w) < 40) then
			local x, z = v + 6.5, w + 6.5
			local lamp, done = group("Lamp", lamps, { DamageKind = "Bend", Resist = 0.1 }, at(x, 0, z))
			part({ Name = "Pole", Size = Vector3.new(0.5, 12, 0.5), CFrame = at(x, 6, z), Color = Color3.fromRGB(70, 72, 80), Parent = lamp })
			part({ Name = "Head", Size = Vector3.new(1.6, 0.6, 1.6), CFrame = at(x, 12.2, z), Color = Color3.fromRGB(255, 236, 180), Material = Enum.Material.Neon, Parent = lamp })
			done()
		end
	end
end

----------------------------------------------------------------------------------------------------
-- houses: 2 x 2 per block with gardens

local houses = folder("Houses")
local WALLS = { Color3.fromRGB(240, 236, 226), Color3.fromRGB(226, 220, 205), Color3.fromRGB(210, 205, 196), Color3.fromRGB(236, 224, 200), Color3.fromRGB(214, 228, 238) }
local ROOFS = { Color3.fromRGB(80, 90, 105), Color3.fromRGB(150, 70, 60), Color3.fromRGB(70, 100, 130), Color3.fromRGB(95, 95, 95), Color3.fromRGB(120, 80, 50) }
local CARS = { Color3.fromRGB(220, 60, 60), Color3.fromRGB(60, 120, 220), Color3.fromRGB(240, 240, 240), Color3.fromRGB(40, 40, 45), Color3.fromRGB(240, 200, 60), Color3.fromRGB(90, 170, 110) }
local PITCH = math.rad(28)

-- front: +1 / -1, which way (in z) the house faces the street
local function house(x, z, front, detailed)
	local w = rng:NextNumber(12, 18)
	local d = rng:NextNumber(12, 16)
	local h = rng:NextNumber(8, 12)
	local home = folder("Home", houses)
	local wall = WALLS[rng:NextInteger(1, #WALLS)]
	local roofColor = ROOFS[rng:NextInteger(1, #ROOFS)]
	-- the walls only jump for the very strongest claps
	part({ Name = "House", Size = Vector3.new(w, h, d), CFrame = at(x, h / 2, z), Color = wall, Parent = home, Attrs = { DamageKind = "Fly", Resist = 1.2, Launch = 0.35 } })
	-- pitched roof: two slabs meeting at a ridge along x
	local slab = d / 2 / math.cos(PITCH) + 0.9
	local rise = (d / 4) * math.tan(PITCH)
	for _, side in { -1, 1 } do
		part({
			Name = "Roof",
			Size = Vector3.new(w + 1.4, 0.7, slab),
			CFrame = at(x, h + rise + 0.2, z + side * d / 4) * CFrame.Angles(side * PITCH, 0, 0),
			Color = roofColor,
			Parent = home,
			Attrs = { DamageKind = "Fly", Resist = 0.28 + rng:NextNumber(0, 0.06), Launch = 1.3 },
		})
	end
	part({ Name = "Chimney", Size = Vector3.new(1.6, 4, 1.6), CFrame = at(x + w * 0.28, h + rise + 1.4, z - front * d / 4), Color = Color3.fromRGB(150, 90, 70), Parent = home, Attrs = { DamageKind = "Fly", Resist = 0.18, Launch = 1.2 } })
	if not detailed then
		return
	end
	-- windows front and back, a door at the front
	for _, face in { -1, 1 } do
		for _, wx in { -w / 4, w / 4 } do
			if not (face == front and math.abs(wx) < 2.5) then
				part({ Name = "Window", Size = Vector3.new(2.6, 2.4, 0.2), CFrame = at(x + wx, h * 0.62, z + face * (d / 2 + 0.1)), Color = GLASS, Material = Enum.Material.Glass, Parent = home, Attrs = { DamageKind = "Shatter", Resist = 0.1 } })
			end
		end
	end
	part({ Name = "Door", Size = Vector3.new(2.4, 4.6, 0.3), CFrame = at(x, 2.3, z + front * (d / 2 + 0.15)), Color = Color3.fromRGB(120, 80, 55), Parent = home, Attrs = { DamageKind = "Fly", Resist = 0.2, Launch = 1 } })
	-- garden fence along the street side, with a gap for the path
	local fz = z + front * (d / 2 + 5)
	local span = w + 6
	for _, seg in { -1, 1 } do
		local length = span / 2 - 1.5
		local fence, done = group("Fence", home, { DamageKind = "Fly", Resist = 0.08, Launch = 1.1 }, at(x + seg * (span / 4 + 0.75), 0, fz))
		part({ Name = "Rail", Size = Vector3.new(length, 0.3, 0.25), CFrame = at(x + seg * (span / 4 + 0.75), 1.4, fz), Color = WHITE, Parent = fence })
		for k = 0, 3 do
			part({ Name = "Picket", Size = Vector3.new(0.3, 1.8, 0.3), CFrame = at(x + seg * (1.5 + k * (length - 0.3) / 3), 0.9, fz), Color = WHITE, Parent = fence })
		end
		done()
	end
	-- mailbox and bin by the gate
	local mx = x + 2.2
	local mailbox, doneMail = group("Mailbox", home, { DamageKind = "Fly", Resist = 0.05, Launch = 1.2 }, at(mx, 0, fz + front * 1))
	part({ Name = "Post", Size = Vector3.new(0.3, 3, 0.3), CFrame = at(mx, 1.5, fz + front * 1), Color = Color3.fromRGB(90, 70, 50), Parent = mailbox })
	part({ Name = "Box", Size = Vector3.new(1, 0.9, 1.4), CFrame = at(mx, 3.3, fz + front * 1), Color = Color3.fromRGB(200, 50, 50), Parent = mailbox })
	doneMail()
	part({ Name = "Bin", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 1.3, 1.3), CFrame = at(x - 2.4, 1, fz + front * 1) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(60, 110, 70), Parent = home, Attrs = { DamageKind = "Fly", Resist = 0.03, Launch = 1.4 } })
	-- a car parked in the street now and then
	if rng:NextNumber() < 0.45 then
		local cz = z + front * (d / 2 + 11.5)
		local car, doneCar = group("Car", home, { DamageKind = "Fly", Resist = 0.15, Launch = 0.9 }, at(x, 0, cz))
		local paint = CARS[rng:NextInteger(1, #CARS)]
		part({ Name = "Body", Size = Vector3.new(6, 1.5, 2.8), CFrame = at(x, 1.15, cz), Color = paint, Parent = car })
		part({ Name = "Cabin", Size = Vector3.new(3.4, 1.2, 2.5), CFrame = at(x - 0.3, 2.5, cz), Color = paint, Parent = car })
		part({ Name = "Glass", Size = Vector3.new(3.5, 0.9, 2.55), CFrame = at(x - 0.3, 2.5, cz), Color = Color3.fromRGB(60, 80, 100), Material = Enum.Material.Glass, Transparency = 0.3, Parent = car })
		for _, wx in { -1.9, 1.9 } do
			for _, wz in { -1.3, 1.3 } do
				part({ Name = "Wheel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 1.2, 1.2), CFrame = at(x + wx, 0.6, cz + wz) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(30, 30, 30), Parent = car })
			end
		end
		doneCar()
	end
end

local count = 0
for bx = -half + BLOCK, half - BLOCK, BLOCK do
	for bz = -half + BLOCK, half - BLOCK, BLOCK do
		local isSchool = math.abs(bx) < BLOCK and math.abs(bz) < BLOCK
		local inRiver = bx > 280 and bx < 380
		if not isSchool and not inRiver then
			local detailed = math.sqrt(bx * bx + bz * bz) < DETAIL
			for hx = -1, 1, 2 do
				for hz = -1, 1, 2 do
					local x = bx + hx * 14 + rng:NextNumber(-1.5, 1.5)
					local z = bz + hz * 12
					if rng:NextNumber() < 0.85 then
						house(x, z, hz, detailed)
						count += 1
						if count % 25 == 0 then
							task.wait()
						end
					else
						tree(x, z, false)
					end
				end
			end
		end
	end
end

----------------------------------------------------------------------------------------------------
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
return ("Town built: %d parts, %d houses, %d player spots"):format(#model:GetDescendants(), count, index)
