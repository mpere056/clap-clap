-- Builds stages 4-9 into workspace.Stages: City, Region, Country, Planet, Molten, Space.
-- Run in Studio edit mode; safe to re-run (each stage model is replaced).
-- Origins must match src/shared/Config.luau. Damage kinds are simulated locally by
-- src/client/Environment.luau. Lasting damage (your progress): Flatten, Crater, Glow, Tint, Reveal,
-- Approach, Drift. Per-clap shoves that heal (anyone's claps): Fly / Bend items, or any item with a
-- Resist attribute; Launch = how far it flies, React = "Bend" to sway instead, Float = no gravity.
-- A Model with a DamageKind moves all its parts together.

local stages = workspace:FindFirstChild("Stages") or Instance.new("Folder")
stages.Name = "Stages"
stages.Parent = workspace

local function newStage(key)
	local old = stages:FindFirstChild(key)
	if old then
		old:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = key
	return model
end

local function folder(model, name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = model
	return f
end

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		if k ~= "Parent" and k ~= "Attrs" then
			p[k] = v
		end
	end
	if props.Attrs then
		for k, v in props.Attrs do
			p:SetAttribute(k, v)
		end
	end
	p.Parent = props.Parent
	return p
end

local function spot(parent, index, cf)
	part({ Name = string.format("Spot%02d", index), Size = Vector3.new(4, 0.2, 4), CFrame = cf, Transparency = 1, Parent = parent })
end

-- a disc lying flat (cylinder axis pointing up)
local FLAT = CFrame.Angles(0, 0, math.rad(90))

local rng = Random.new(404)
local built = {}

-- a group of parts that moves as one; attrs go on the model, pivot is where it bends/spins from
local function group(name, parent, attrs, pivot, parts)
	local m = Instance.new("Model")
	m.Name = name
	for k, v in attrs do
		m:SetAttribute(k, v)
	end
	for _, props in parts do
		props.Parent = m
		part(props)
	end
	m.WorldPivot = pivot
	m.Parent = parent
	return m
end

local function tree(parent, at, size, attrs)
	return group("Tree", parent, attrs, CFrame.new(at), {
		{ Name = "Trunk", Size = Vector3.new(0.2, 1, 0.2) * size, CFrame = CFrame.new(at + Vector3.new(0, size / 2, 0)), Color = Color3.fromRGB(105, 80, 60) },
		{ Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 0.8, 0.9) * size, CFrame = CFrame.new(at + Vector3.new(0, size * 1.15, 0)), Color = Color3.fromRGB(80 + rng:NextInteger(0, 30), 125 + rng:NextInteger(0, 25), 70) },
	})
end

local CAR_PAINT = { Color3.fromRGB(220, 60, 60), Color3.fromRGB(60, 120, 220), Color3.fromRGB(240, 240, 240), Color3.fromRGB(40, 40, 45), Color3.fromRGB(240, 200, 60) }

----------------------------------------------------------------------------------------------------
-- 4. The City: satellite view of farmland, a river and a dense city; craters grow, blocks flatten
do
	local O = Vector3.new(9000, 0, 0)
	local model = newStage("City")
	local ground = folder(model, "Ground")
	local city = folder(model, "City")
	part({ Name = "Land", Size = Vector3.new(2040, 2, 2040), CFrame = CFrame.new(O + Vector3.new(0, -1, 0)), Color = Color3.fromRGB(122, 150, 96), Material = Enum.Material.Grass, CanCollide = true, Parent = ground })
	-- farmland patchwork around the outskirts
	local fields = { Color3.fromRGB(150, 170, 90), Color3.fromRGB(190, 175, 110), Color3.fromRGB(105, 140, 80), Color3.fromRGB(170, 150, 100) }
	for x = -960, 960, 120 do
		for z = -960, 960, 120 do
			if math.abs(x) > 480 or math.abs(z) > 480 then
				part({ Name = "Field", Size = Vector3.new(112, 0.2, 112), CFrame = CFrame.new(O + Vector3.new(x, 0.1, z)), Color = fields[rng:NextInteger(1, #fields)], Parent = ground })
			end
		end
	end
	for i = 0, 24 do
		local z = -1000 + i * 84
		part({ Name = "River", Size = Vector3.new(46, 0.3, 90), CFrame = CFrame.new(O + Vector3.new(560 + math.sin(i * 0.45) * 70, 0.2, z)) * CFrame.Angles(0, math.cos(i * 0.45) * 0.5, 0), Color = Color3.fromRGB(90, 135, 185), Parent = ground })
	end
	for v = -450, 450, 90 do
		part({ Name = "Road", Size = Vector3.new(10, 0.3, 920), CFrame = CFrame.new(O + Vector3.new(v, 0.25, 0)), Color = Color3.fromRGB(140, 138, 132), Parent = ground })
		part({ Name = "Road", Size = Vector3.new(920, 0.3, 10), CFrame = CFrame.new(O + Vector3.new(0, 0.26, v)), Color = Color3.fromRGB(140, 138, 132), Parent = ground })
	end
	-- buildings: flatten from the centre outwards
	local tones = { Color3.fromRGB(225, 222, 215), Color3.fromRGB(200, 198, 195), Color3.fromRGB(175, 180, 190), Color3.fromRGB(235, 230, 220) }
	for bx = -405, 405, 90 do
		for bz = -405, 405, 90 do
			if not (math.abs(bx) < 60 and math.abs(bz) < 60) then
				for _ = 1, 4 do
					local w, d = rng:NextNumber(14, 30), rng:NextNumber(14, 30)
					local h = rng:NextNumber(10, 30) + math.max(0, 300 - math.sqrt(bx * bx + bz * bz)) * 0.15
					local x, z = bx + rng:NextNumber(-22, 22), bz + rng:NextNumber(-22, 22)
					local dist = math.sqrt(x * x + z * z)
					part({
						Name = "Building",
						Size = Vector3.new(w, h, d),
						CFrame = CFrame.new(O + Vector3.new(x, h / 2, z)),
						Color = tones[rng:NextInteger(1, #tones)],
						Parent = city,
						-- squashed for good as your progress reaches them; strong claps make them jump
						Attrs = { DamageKind = "Flatten", DamageAt = math.clamp(0.03 + dist / 640, 0, 0.97), Resist = 0.35, Launch = 0.3 },
					})
				end
			end
		end
	end
	-- traffic on the roads, trees, and radio masts (all thrown about by claps, then back)
	local props = folder(model, "Props")
	for _ = 1, 160 do
		local v = -450 + 90 * rng:NextInteger(0, 10)
		local along = rng:NextNumber(-440, 440)
		local horizontal = rng:NextNumber() < 0.5
		local pos = if horizontal then Vector3.new(along, 2, v + rng:NextNumber(-2.5, 2.5)) else Vector3.new(v + rng:NextNumber(-2.5, 2.5), 2, along)
		if math.abs(pos.X) > 55 or math.abs(pos.Z) > 55 then
			part({ Name = "Car", Size = if horizontal then Vector3.new(9, 3.5, 4.5) else Vector3.new(4.5, 3.5, 9), CFrame = CFrame.new(O + pos), Color = CAR_PAINT[rng:NextInteger(1, #CAR_PAINT)], Parent = props, Attrs = { DamageKind = "Fly", Resist = 0.08, Launch = 1.3 } })
		end
	end
	for i = 0, 23 do
		local a = i / 24 * math.pi * 2
		tree(props, O + Vector3.new(math.cos(a) * 62, 0.5, math.sin(a) * 62), rng:NextNumber(14, 20), { DamageKind = "Bend", Resist = 0.1 })
	end
	for _ = 1, 60 do
		local x, z = rng:NextNumber(-440, 440), rng:NextNumber(-440, 440)
		if math.abs(x) > 70 or math.abs(z) > 70 then
			tree(props, O + Vector3.new(x, 0, z), rng:NextNumber(12, 18), { DamageKind = "Bend", Resist = 0.12 })
		end
	end
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2 + 0.3
		local d = rng:NextNumber(200, 420)
		local h = rng:NextNumber(70, 110)
		local base = O + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
		local mast = {}
		for k = 0, 4 do
			table.insert(mast, { Name = "Mast", Size = Vector3.new(4 - k * 0.5, h / 5, 4 - k * 0.5), CFrame = CFrame.new(base + Vector3.new(0, h / 10 + k * h / 5, 0)), Color = if k % 2 == 0 then Color3.fromRGB(220, 60, 50) else Color3.fromRGB(245, 245, 245) })
		end
		table.insert(mast, { Name = "Beacon", Shape = Enum.PartType.Ball, Size = Vector3.new(4, 4, 4), CFrame = CFrame.new(base + Vector3.new(0, h + 2, 0)), Color = Color3.fromRGB(255, 70, 60), Material = Enum.Material.Neon })
		group("RadioMast", props, { DamageKind = "Bend", Resist = 0.2 }, CFrame.new(base), mast)
	end
	-- central park where everyone stands
	part({ Name = "Park", Size = Vector3.new(110, 0.4, 110), CFrame = CFrame.new(O + Vector3.new(0, 0.3, 0)), Color = Color3.fromRGB(110, 160, 90), CanCollide = true, Parent = ground })
	part({ Name = "Crater", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 10, 10), CFrame = CFrame.new(O + Vector3.new(0, 0.5, 0)) * FLAT, Color = Color3.fromRGB(95, 80, 66), Transparency = 0.1, Parent = model, Attrs = { DamageKind = "Crater", MaxRadius = 760 } })
	local spots = folder(model, "Spots")
	local i = 0
	for row = 0, 3 do
		for col = 0, 4 do
			i += 1
			spot(spots, i, CFrame.new(O + Vector3.new((col - 2) * 18, 0.6, (row - 1.5) * 18)))
		end
	end
	model.WorldPivot = CFrame.new(O)
	model.Parent = stages
	table.insert(built, "City " .. #model:GetDescendants())
end

----------------------------------------------------------------------------------------------------
-- 5. The Region: skyline against green mountains, a dust wall rolling in towards you
do
	local O = Vector3.new(13000, 0, 0)
	local model = newStage("Region")
	local ground = folder(model, "Ground")
	local skyline = folder(model, "Skyline")
	part({ Name = "Land", Size = Vector3.new(2040, 2, 2040), CFrame = CFrame.new(O + Vector3.new(0, -1, -700)), Color = Color3.fromRGB(110, 130, 90), Material = Enum.Material.Grass, CanCollide = true, Parent = ground })
	part({ Name = "Plaza", Size = Vector3.new(80, 1, 60), CFrame = CFrame.new(O + Vector3.new(0, 0, 10)), Color = Color3.fromRGB(170, 165, 158), CanCollide = true, Parent = ground })
	-- mountains (overlapping cones of green balls) far behind the city
	for i = 0, 16 do
		local x = -1000 + i * 125 + rng:NextNumber(-40, 40)
		local size = rng:NextNumber(300, 560)
		part({ Name = "Mountain", Shape = Enum.PartType.Ball, Size = Vector3.new(size, size, size), CFrame = CFrame.new(O + Vector3.new(x, -size * 0.2, -1350 - rng:NextNumber(0, 250))), Color = Color3.fromRGB(70 + rng:NextInteger(0, 30), 110 + rng:NextInteger(0, 30), 75), Material = Enum.Material.Grass, Parent = ground })
	end
	-- skyline: towers further away collapse first as the dust wall reaches them
	local tones = { Color3.fromRGB(150, 155, 165), Color3.fromRGB(185, 185, 190), Color3.fromRGB(120, 125, 140), Color3.fromRGB(205, 200, 195) }
	for _ = 1, 170 do
		local x = rng:NextNumber(-520, 520)
		local z = -rng:NextNumber(270, 800)
		local h = rng:NextNumber(20, 60) + math.max(0, 140 - math.abs(x) * 0.25) * rng:NextNumber(0.3, 1)
		local w = rng:NextNumber(14, 34)
		part({
			Name = "Tower",
			Size = Vector3.new(w, h, w),
			CFrame = CFrame.new(O + Vector3.new(x, h / 2, z)),
			Color = tones[rng:NextInteger(1, #tones)],
			Parent = skyline,
			-- collapse for good when the dust wall reaches them; every clap makes them sway
			Attrs = { DamageKind = "Flatten", DamageAt = math.clamp(0.3 + 0.6 * (1 - (-z - 270) / 530), 0.3, 0.92), React = "Bend", Resist = 0.12 },
		})
	end
	-- the countryside between you and the city: trees, power pylons, a car park and billboards
	local props = folder(model, "Props")
	for _ = 1, 40 do
		local x = rng:NextNumber(-260, 260)
		local z = rng:NextNumber(-250, 120)
		if math.abs(x) > 50 or z < -30 or z > 60 then
			tree(props, O + Vector3.new(x, 0, z), rng:NextNumber(10, 18), { DamageKind = "Bend", Resist = 0.06 })
		end
	end
	for _, side in { -1, 1 } do
		for k = 0, 4 do
			local base = O + Vector3.new(side * 110, 0, -40 - k * 50)
			group("Pylon", props, { DamageKind = "Bend", Resist = 0.15 }, CFrame.new(base), {
				{ Name = "Leg", Size = Vector3.new(2, 40, 2), CFrame = CFrame.new(base + Vector3.new(0, 20, 0)), Color = Color3.fromRGB(150, 150, 155) },
				{ Name = "Arm", Size = Vector3.new(18, 1.5, 1.5), CFrame = CFrame.new(base + Vector3.new(0, 36, 0)), Color = Color3.fromRGB(150, 150, 155) },
			})
		end
	end
	for k = 0, 11 do
		local pos = O + Vector3.new(52 + (k % 4) * 7, 1.6, -10 + math.floor(k / 4) * 12)
		part({ Name = "Car", Size = Vector3.new(4.5, 3, 9), CFrame = CFrame.new(pos), Color = CAR_PAINT[rng:NextInteger(1, #CAR_PAINT)], Parent = props, Attrs = { DamageKind = "Fly", Resist = 0.05, Launch = 1.2 } })
	end
	for k = -1, 1 do
		local base = O + Vector3.new(k * 70, 0, -70)
		group("Billboard", props, { DamageKind = "Fly", Resist = 0.2, Launch = 0.8 }, CFrame.new(base), {
			{ Name = "Post", Size = Vector3.new(1.5, 18, 1.5), CFrame = CFrame.new(base + Vector3.new(0, 9, 0)), Color = Color3.fromRGB(90, 90, 95) },
			{ Name = "Board", Size = Vector3.new(26, 11, 1), CFrame = CFrame.new(base + Vector3.new(0, 22, 0)), Color = Color3.fromHSV(rng:NextNumber(), 0.6, 0.95) },
		})
	end
	-- the dust wall: starts behind the mountains and travels towards the camera
	part({
		Name = "DustWall",
		Size = Vector3.new(2000, 520, 60),
		CFrame = CFrame.new(O + Vector3.new(0, 250, -1650)),
		Color = Color3.fromRGB(175, 150, 120),
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.2,
		Parent = model,
		Attrs = { DamageKind = "Approach", DamageAt = 0.15, Travel = Vector3.new(0, 0, 1450) },
	})
	local spots = folder(model, "Spots")
	local i = 0
	for row = 0, 3 do
		for col = 0, 4 do
			i += 1
			spot(spots, i, CFrame.new(O + Vector3.new((col - 2) * 9, 0.6, 18 - row * 8)))
		end
	end
	model.WorldPivot = CFrame.new(O + Vector3.new(0, 0, 10))
	model.Parent = stages
	table.insert(built, "Region " .. #model:GetDescendants())
end

----------------------------------------------------------------------------------------------------
-- 6. The Country: a stylised map of Japan on a deep blue ocean; your clap's glow spreads across it
do
	local O = Vector3.new(17000, 0, 0)
	local model = newStage("Country")
	local map = folder(model, "Map")
	part({ Name = "Ocean", Size = Vector3.new(2040, 2, 2040), CFrame = CFrame.new(O + Vector3.new(0, -1, 0)), Color = Color3.fromRGB(30, 63, 122), CanCollide = true, Parent = map })
	local LAND = Color3.fromRGB(230, 211, 168)
	local function island(points, width)
		for k = 1, #points - 1 do
			local a, b = points[k], points[k + 1]
			local mid = (a + b) / 2
			local len = (b - a).Magnitude + width * 0.6
			part({ Name = "Land", Size = Vector3.new(width, 3, len), CFrame = CFrame.lookAt(O + mid, O + b), Color = LAND, CanCollide = true, Parent = map })
			part({ Name = "Coast", Size = Vector3.new(width + 14, 1, len + 10), CFrame = CFrame.lookAt(O + mid - Vector3.new(0, 1.2, 0), O + b - Vector3.new(0, 1.2, 0)), Color = Color3.fromRGB(200, 225, 240), Transparency = 0.35, Parent = map })
		end
	end
	local v = Vector3.new
	-- Honshu arc, Hokkaido, Shikoku, Kyushu
	island({ v(-560, 0, 300), v(-420, 0, 230), v(-280, 0, 190), v(-150, 0, 150), v(-40, 0, 80), v(60, 0, -10), v(130, 0, -120), v(170, 0, -240), v(230, 0, -360) }, 95)
	island({ v(230, 0, -460), v(330, 0, -520), v(430, 0, -560), v(380, 0, -650) }, 120)
	island({ v(-380, 0, 380), v(-260, 0, 360) }, 60)
	island({ v(-660, 0, 400), v(-640, 0, 520), v(-560, 0, 560) }, 90)
	for _ = 1, 26 do
		local d = rng:NextNumber(60, 160)
		part({ Name = "Cloud", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, d, d), CFrame = CFrame.new(O + v(rng:NextNumber(-950, 950), 60 + rng:NextNumber(0, 30), rng:NextNumber(-950, 950))) * FLAT, Color = Color3.new(1, 1, 1), Transparency = 0.45, Parent = map, Attrs = { DamageKind = "Fly", Float = true, Resist = 0.03, Launch = 0.6 } })
	end
	-- ships on the sea and planes overhead, blown away by claps (they drift back)
	local traffic = folder(model, "Traffic")
	local coastline = { v(-560, 0, 300), v(-280, 0, 190), v(-40, 0, 80), v(130, 0, -120), v(230, 0, -360), v(330, 0, -520), v(-260, 0, 360), v(-640, 0, 520) }
	local ships = 0
	while ships < 30 do
		local pos = v(rng:NextNumber(-900, 900), 1.5, rng:NextNumber(-900, 900))
		local clear = true
		for _, c in coastline do
			if (pos - c).Magnitude < 170 then
				clear = false
			end
		end
		if clear then
			ships += 1
			local yaw = CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
			group("Ship", traffic, { DamageKind = "Fly", Float = true, Resist = 0.08, Launch = 1 }, CFrame.new(O + pos) * yaw, {
				{ Name = "Hull", Size = v(34, 5, 10), CFrame = CFrame.new(O + pos) * yaw, Color = Color3.fromRGB(70, 70, 80) },
				{ Name = "Deck", Size = v(12, 6, 8), CFrame = CFrame.new(O + pos + v(0, 5, 0)) * yaw * CFrame.new(-6, 0, 0), Color = Color3.fromRGB(240, 240, 240) },
			})
		end
	end
	for _ = 1, 10 do
		local pos = v(rng:NextNumber(-800, 800), 120 + rng:NextNumber(0, 40), rng:NextNumber(-800, 800))
		local yaw = CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
		group("Plane", traffic, { DamageKind = "Fly", Float = true, Resist = 0.04, Launch = 1.2 }, CFrame.new(O + pos) * yaw, {
			{ Name = "Body", Size = v(4, 4, 30), CFrame = CFrame.new(O + pos) * yaw, Color = Color3.new(1, 1, 1) },
			{ Name = "Wings", Size = v(30, 1, 6), CFrame = CFrame.new(O + pos) * yaw, Color = Color3.fromRGB(230, 230, 235) },
		})
	end
	part({ Name = "Glow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 10, 10), CFrame = CFrame.new(O + v(0, 4, 0)) * FLAT, Color = Color3.fromRGB(255, 170, 90), Material = Enum.Material.Neon, Transparency = 0.5, Parent = model, Attrs = { DamageKind = "Glow", MaxRadius = 1400 } })
	local spots = folder(model, "Spots")
	local i = 0
	for row = 0, 3 do
		for col = 0, 4 do
			i += 1
			spot(spots, i, CFrame.new(O + v(-40 + (col - 2) * 10, 1.8, 80 + (row - 1.5) * 10)))
		end
	end
	model.WorldPivot = CFrame.new(O + v(-40, 0, 80))
	model.Parent = stages
	table.insert(built, "Country " .. #model:GetDescendants())
end

----------------------------------------------------------------------------------------------------
-- globes for stages 7 and 8
local R = 600

local function globe(model, center, opts)
	local surface = folder(model, "Globe")
	local ocean = part({ Name = "Ocean", Shape = Enum.PartType.Ball, Size = Vector3.new(R * 2, R * 2, R * 2), CFrame = CFrame.new(center), Color = Color3.fromRGB(40, 90, 170), Parent = surface, Attrs = opts.ocean })
	ocean.CanCollide = true
	-- continents: big balls poking out of the surface
	local dirs = { Vector3.new(0, 1, 0.15), Vector3.new(0.5, 0.75, 0.2), Vector3.new(-0.6, 0.6, 0.3), Vector3.new(0.8, 0.1, 0.5), Vector3.new(-0.7, -0.1, 0.6), Vector3.new(0.2, -0.6, 0.8), Vector3.new(-0.3, 0.3, 0.9), Vector3.new(0.6, 0.4, -0.7), Vector3.new(-0.5, 0.2, -0.8), Vector3.new(0.1, -0.9, -0.3), Vector3.new(0.9, -0.3, -0.2), Vector3.new(-0.9, 0.4, -0.2) }
	for _, d in dirs do
		local size = rng:NextNumber(260, 420)
		local n = d.Unit
		part({ Name = "Continent", Shape = Enum.PartType.Ball, Size = Vector3.new(size, size, size), CFrame = CFrame.new(center + n * (R - size / 2 + 10)), Color = Color3.fromRGB(205, 190, 140):Lerp(Color3.fromRGB(110, 150, 90), rng:NextNumber(0, 0.6)), Parent = surface, Attrs = opts.land })
	end
	for _ = 1, 16 do
		local n = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)).Unit
		local size = rng:NextNumber(120, 240)
		part({ Name = "Cloud", Shape = Enum.PartType.Ball, Size = Vector3.new(size, size, size), CFrame = CFrame.new(center + n * (R - size / 2 + 22)), Color = Color3.new(1, 1, 1), Transparency = 0.35, Parent = surface, Attrs = opts.cloud })
	end
	-- satellites in orbit, knocked out of position by claps (they drift back)
	local orbit = folder(model, "Satellites")
	for _ = 1, 10 do
		local n = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.2, 1), rng:NextNumber(-1, 1)).Unit
		local pos = center + n * R * rng:NextNumber(1.18, 1.35)
		local look = CFrame.lookAt(pos, center)
		group("Satellite", orbit, { DamageKind = "Fly", Float = true, Resist = 0.04, Launch = 0.8 }, look, {
			{ Name = "Body", Size = Vector3.new(10, 10, 14), CFrame = look, Color = Color3.fromRGB(230, 190, 90), Material = Enum.Material.Metal },
			{ Name = "Panels", Size = Vector3.new(60, 1, 12), CFrame = look, Color = Color3.fromRGB(50, 80, 160) },
		})
	end
	part({ Name = "Atmosphere", Shape = Enum.PartType.Ball, Size = Vector3.new(R * 2.08, R * 2.08, R * 2.08), CFrame = CFrame.new(center), Color = Color3.fromRGB(130, 180, 255), Material = Enum.Material.Neon, Transparency = 0.9, Parent = surface })
	-- the blast glow: a flattened sphere (SpecialMesh) half sunk into the surface, so it hugs the globe
	local glow = part({ Name = "Glow", Size = Vector3.new(4, 10, 10), CFrame = CFrame.new(center + Vector3.new(0, R, 0)) * FLAT, Color = Color3.fromRGB(255, 180, 100), Material = Enum.Material.Neon, Transparency = 0.5, Parent = model, Attrs = { DamageKind = "Glow", OnGlobe = true, GlobeRadius = R, MaxRadius = R * 0.45 } })
	local lens = Instance.new("SpecialMesh")
	lens.MeshType = Enum.MeshType.Sphere
	lens.Parent = glow
	-- spots in a small patch on top of the globe
	local spots = folder(model, "Spots")
	local i = 0
	for row = 0, 3 do
		for col = 0, 4 do
			i += 1
			local up = Vector3.new((col - 2) * 0.012, 1, (row - 1.5) * 0.012).Unit
			local right = Vector3.zAxis:Cross(up).Unit
			spot(spots, i, CFrame.fromMatrix(center + up * (R + 0.5), right, up))
		end
	end
	model:SetAttribute("GlobeRadius", R)
	model.WorldPivot = CFrame.new(center + Vector3.new(0, R, 0))
end

-- 7. The Planet: the whole Earth; your blast glows across it and it starts to turn orange
do
	local center = Vector3.new(22000, 3000, 0)
	local model = newStage("Planet")
	globe(model, center, {
		ocean = { DamageKind = "Tint", ColorB = Color3.fromRGB(205, 120, 70), From = 0.7, To = 1 },
		land = { DamageKind = "Tint", ColorB = Color3.fromRGB(150, 80, 45), From = 0.6, To = 1 },
		cloud = { DamageKind = "Tint", ColorB = Color3.fromRGB(120, 110, 105), From = 0.5, To = 1, Resist = 0.04, Launch = 0.5, Float = true },
	})
	model.Parent = stages
	table.insert(built, "Planet " .. #model:GetDescendants())
end

-- 8. Molten Earth: oceans steam away, the crust darkens and glowing cracks open up
do
	local center = Vector3.new(28000, 3000, 0)
	local model = newStage("Molten")
	globe(model, center, {
		ocean = { DamageKind = "Tint", ColorB = Color3.fromRGB(215, 200, 190), From = 0, To = 0.45 },
		land = { DamageKind = "Tint", ColorB = Color3.fromRGB(55, 30, 22), From = 0.3, To = 0.7 },
		cloud = { DamageKind = "Tint", ColorB = Color3.fromRGB(240, 235, 230), From = 0, To = 0.4, Resist = 0.04, Launch = 0.5, Float = true },
	})
	local cracks = folder(model, "Cracks")
	-- glowing cracks: random great-circle arcs of short segments hugging the surface
	for c = 1, 26 do
		local axis = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)).Unit
		local start = axis:Cross(Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))).Unit
		local at = 0.5 + (c / 26) * 0.4
		for k = 0, 9 do
			local a = k * 0.09
			local p1 = CFrame.fromAxisAngle(axis, a) * start
			local p2 = CFrame.fromAxisAngle(axis, a + 0.09) * start
			local q1, q2 = center + p1 * (R + 3), center + p2 * (R + 3)
			part({ Name = "Crack", Size = Vector3.new(7, 7, (q2 - q1).Magnitude + 4), CFrame = CFrame.lookAt((q1 + q2) / 2, q2), Color = Color3.fromRGB(255, 120, 30), Material = Enum.Material.Neon, Transparency = 1, Parent = cracks, Attrs = { DamageKind = "Reveal", DamageAt = at, Visible = 0 } })
		end
	end
	part({ Name = "Steam", Shape = Enum.PartType.Ball, Size = Vector3.new(R * 2.12, R * 2.12, R * 2.12), CFrame = CFrame.new(center), Color = Color3.fromRGB(240, 240, 245), Transparency = 1, Parent = model, Attrs = { DamageKind = "Reveal", DamageAt = 0.12, Until = 0.55, Visible = 0.75 } })
	part({ Name = "CoreGlow", Shape = Enum.PartType.Ball, Size = Vector3.new(R * 2.03, R * 2.03, R * 2.03), CFrame = CFrame.new(center), Color = Color3.fromRGB(255, 110, 30), Material = Enum.Material.Neon, Transparency = 1, Parent = model, Attrs = { DamageKind = "Reveal", DamageAt = 0.82, Visible = 0.55 } })
	model.Parent = stages
	table.insert(built, "Molten " .. #model:GetDescendants())
end

----------------------------------------------------------------------------------------------------
-- 9. Space: you float among the glowing pieces of the Earth; they drift away with every clap
do
	local O = Vector3.new(34000, 3000, 0)
	local model = newStage("Space")
	local fragments = folder(model, "Fragments")
	local core = O + Vector3.new(0, -260, -180)
	part({ Name = "Core", Shape = Enum.PartType.Ball, Size = Vector3.new(120, 120, 120), CFrame = CFrame.new(core), Color = Color3.fromRGB(255, 140, 50), Material = Enum.Material.Neon, Parent = model })
	for _ = 1, 70 do
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)).Unit
		local dist = rng:NextNumber(110, 420)
		local size = Vector3.new(rng:NextNumber(18, 70), rng:NextNumber(14, 50), rng:NextNumber(18, 70))
		local hot = rng:NextNumber() < 0.35
		part({
			Name = "Fragment",
			Size = size,
			CFrame = CFrame.new(core + dir * dist) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0),
			Color = if hot then Color3.fromRGB(230, 85, 20) else Color3.fromRGB(120, 85, 60):Lerp(Color3.fromRGB(80, 110, 70), rng:NextNumber(0, 0.5)),
			Material = if hot then Enum.Material.Neon else Enum.Material.Slate,
			Parent = fragments,
			Attrs = { DamageKind = "Drift", Drift = rng:NextNumber(60, 160) },
		})
	end
	for _ = 1, 90 do
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)).Unit
		local s = rng:NextNumber(2, 7)
		part({ Name = "Rock", Size = Vector3.new(s, s, s), CFrame = CFrame.new(O + dir * rng:NextNumber(30, 160)) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0), Color = Color3.fromRGB(110, 90, 75), Material = Enum.Material.Slate, Parent = fragments, Attrs = { DamageKind = "Drift", Drift = rng:NextNumber(20, 60) } })
	end
	local spots = folder(model, "Spots")
	for i = 1, 20 do
		local a = (i / 20) * math.pi * 2
		spot(spots, i, CFrame.new(O + Vector3.new(math.cos(a) * (8 + (i % 2) * 10), 0, math.sin(a) * (8 + (i % 2) * 10))))
	end
	model.WorldPivot = CFrame.new(O)
	model.Parent = stages
	table.insert(built, "Space " .. #model:GetDescendants())
end

return "Built: " .. table.concat(built, ", ")
