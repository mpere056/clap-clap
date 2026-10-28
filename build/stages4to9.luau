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
						-- squashed for good as your progress reaches them. Claps: a maxed City player makes
						-- them hop; a Region-level visitor (force 1+) throws them across the blocks
						Attrs = { DamageKind = "Flatten", DamageAt = math.clamp(0.03 + dist / 640, 0, 0.97), Resist = 0.45, Launch = 0.45 },
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
			part({ Name = "Car", Size = if horizontal then Vector3.new(9, 3.5, 4.5) else Vector3.new(4.5, 3.5, 9), CFrame = CFrame.new(O + pos), Color = CAR_PAINT[rng:NextInteger(1, #CAR_PAINT)], Parent = props, Attrs = { DamageKind = "Fly", Resist = 0.08, Launch = 0.6 } })
		end
	end
	for i = 0, 23 do
		local a = i / 24 * math.pi * 2
		tree(props, O + Vector3.new(math.cos(a) * 62, 0.5, math.sin(a) * 62), rng:NextNumber(14, 20), { DamageKind = "Bend", Resist = 0.1, Launch = 0.4 })
	end
	for _ = 1, 60 do
		local x, z = rng:NextNumber(-440, 440), rng:NextNumber(-440, 440)
		if math.abs(x) > 70 or math.abs(z) > 70 then
			tree(props, O + Vector3.new(x, 0, z), rng:NextNumber(12, 18), { DamageKind = "Bend", Resist = 0.12, Launch = 0.4 })
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
		group("RadioMast", props, { DamageKind = "Bend", Resist = 0.2, Launch = 0.35 }, CFrame.new(base), mast)
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
			Attrs = { DamageKind = "Flatten", DamageAt = math.clamp(0.3 + 0.6 * (1 - (-z - 270) / 530), 0.3, 0.92), React = "Bend", Resist = 0.12, Launch = 0.3 },
		})
	end
	-- the countryside between you and the city: trees, power pylons, a car park and billboards
	local props = folder(model, "Props")
	for _ = 1, 40 do
		local x = rng:NextNumber(-260, 260)
		local z = rng:NextNumber(-250, 120)
		if math.abs(x) > 50 or z < -30 or z > 60 then
			tree(props, O + Vector3.new(x, 0, z), rng:NextNumber(10, 18), { DamageKind = "Bend", Resist = 0.06, Launch = 0.4 })
		end
	end
	for _, side in { -1, 1 } do
		for k = 0, 4 do
			local base = O + Vector3.new(side * 110, 0, -40 - k * 50)
			group("Pylon", props, { DamageKind = "Bend", Resist = 0.15, Launch = 0.35 }, CFrame.new(base), {
				{ Name = "Leg", Size = Vector3.new(2, 40, 2), CFrame = CFrame.new(base + Vector3.new(0, 20, 0)), Color = Color3.fromRGB(150, 150, 155) },
				{ Name = "Arm", Size = Vector3.new(18, 1.5, 1.5), CFrame = CFrame.new(base + Vector3.new(0, 36, 0)), Color = Color3.fromRGB(150, 150, 155) },
			})
		end
	end
	for k = 0, 11 do
		local pos = O + Vector3.new(52 + (k % 4) * 7, 1.6, -10 + math.floor(k / 4) * 12)
		part({ Name = "Car", Size = Vector3.new(4.5, 3, 9), CFrame = CFrame.new(pos), Color = CAR_PAINT[rng:NextInteger(1, #CAR_PAINT)], Parent = props, Attrs = { DamageKind = "Fly", Resist = 0.05, Launch = 0.5 } })
	end
	for k = -1, 1 do
		local base = O + Vector3.new(k * 70, 0, -70)
		group("Billboard", props, { DamageKind = "Fly", Resist = 0.2, Launch = 0.5 }, CFrame.new(base), {
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
-- 6. The Country: Japan seen from orbit. Mountains, Fuji, cities and the bullet train on the land,
-- ships, planes and clouds around it, Korea, China and Sakhalin at the edges. Your clap's glow and
-- its pressure rings spread across it (lasting); every clap tosses ships, planes, clouds, trains and
-- city blocks (shared, heals).
do
	local O = Vector3.new(17000, 0, 0)
	local model = newStage("Country")
	local map = folder(model, "Map")
	local v = Vector3.new
	part({ Name = "Ocean", Size = v(2040, 2, 2040), CFrame = CFrame.new(O + v(0, -1, 0)), Color = Color3.fromRGB(30, 63, 122), CanCollide = true, Parent = map })
	-- more sea north and south, so the camera never sees the map's edge (not east or west: the
	-- other stages sit along that axis and would see it)
	for _, dz in { -1, 1 } do
		part({ Name = "OpenSea", Size = v(2040, 2, 2040), CFrame = CFrame.new(O + v(0, -1.2, dz * 2040)), Color = Color3.fromRGB(26, 56, 112), Parent = map })
	end
	local LOWLAND = Color3.fromRGB(150, 175, 105)
	local SAND = Color3.fromRGB(230, 211, 168)
	local function island(points, width, color)
		for k = 1, #points - 1 do
			local a, b = points[k], points[k + 1]
			local mid = (a + b) / 2
			local len = (b - a).Magnitude + width * 0.6
			part({ Name = "Land", Size = Vector3.new(width, 3, len), CFrame = CFrame.lookAt(O + mid, O + b), Color = color or LOWLAND, CanCollide = true, Parent = map })
			part({ Name = "Beach", Size = Vector3.new(width + 8, 2.6, len + 6), CFrame = CFrame.lookAt(O + mid - v(0, 0.3, 0), O + b - v(0, 0.3, 0)), Color = SAND, Parent = map })
			part({ Name = "Coast", Size = Vector3.new(width + 24, 1, len + 18), CFrame = CFrame.lookAt(O + mid - v(0, 1.2, 0), O + b - v(0, 1.2, 0)), Color = Color3.fromRGB(120, 190, 225), Transparency = 0.35, Parent = map })
		end
		-- round discs at every bend so the coastline curves instead of showing box corners
		for _, pt in points do
			part({ Name = "Land", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, width, width), CFrame = CFrame.new(O + pt) * FLAT, Color = color or LOWLAND, CanCollide = true, Parent = map })
			part({ Name = "Beach", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.6, width + 8, width + 8), CFrame = CFrame.new(O + pt - v(0, 0.3, 0)) * FLAT, Color = SAND, Parent = map })
			part({ Name = "Coast", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, width + 24, width + 24), CFrame = CFrame.new(O + pt - v(0, 1.2, 0)) * FLAT, Color = Color3.fromRGB(120, 190, 225), Transparency = 0.35, Parent = map })
		end
	end
	-- Honshu, Hokkaido, Shikoku, Kyushu
	local honshu = { v(-560, 0, 300), v(-420, 0, 230), v(-280, 0, 190), v(-150, 0, 150), v(-40, 0, 80), v(60, 0, -10), v(130, 0, -120), v(170, 0, -240), v(230, 0, -360) }
	island(honshu, 95)
	island({ v(230, 0, -460), v(330, 0, -520), v(430, 0, -560), v(380, 0, -650) }, 120)
	island({ v(-380, 0, 380), v(-260, 0, 360) }, 60)
	island({ v(-660, 0, 400), v(-640, 0, 520), v(-560, 0, 560) }, 90)
	-- the Okinawa chain, Sado, and the neighbours at the edges of the map
	for k = 0, 5 do
		island({ v(-720 - k * 45, 0, 640 + k * 55), v(-735 - k * 45, 0, 668 + k * 55) }, 18)
	end
	island({ v(110, 0, 70), v(140, 0, 40) }, 22)
	island({ v(-880, 0, 120), v(-850, 0, 260), v(-800, 0, 400) }, 110, Color3.fromRGB(165, 170, 115))
	island({ v(-1010, 0, -600), v(-1000, 0, -200), v(-1010, 0, 200), v(-1010, 0, 700) }, 120, Color3.fromRGB(175, 165, 110))
	island({ v(470, 0, -760), v(500, 0, -900), v(520, 0, -1010) }, 50, Color3.fromRGB(140, 160, 110))
	island({ v(-1000, 0, 950), v(-960, 0, 1010) }, 40, Color3.fromRGB(150, 170, 105))

	-- mountains down the spine of each island, some with snow
	local terrain = folder(model, "Terrain")
	local spine = { v(-470, 0, 255), v(-320, 0, 200), v(-200, 0, 165), v(-100, 0, 125), v(110, 0, -70), v(150, 0, -170), v(195, 0, -300), v(330, 0, -560), v(-630, 0, 470) }
	for _, c in spine do
		for _ = 1, 3 do
			local d = rng:NextNumber(26, 46)
			local at = O + c + v(rng:NextNumber(-25, 25), 0, rng:NextNumber(-25, 25))
			part({ Name = "Mountain", Shape = Enum.PartType.Ball, Size = v(d, d, d), CFrame = CFrame.new(at + v(0, -d * 0.18, 0)), Color = Color3.fromRGB(90 + rng:NextInteger(0, 25), 125 + rng:NextInteger(0, 20), 80), Parent = terrain })
			if rng:NextNumber() < 0.4 then
				part({ Name = "Snow", Shape = Enum.PartType.Ball, Size = v(d * 0.5, d * 0.5, d * 0.5), CFrame = CFrame.new(at + v(0, d * 0.22, 0)), Color = Color3.fromRGB(245, 247, 250), Parent = terrain })
			end
		end
	end
	-- Mount Fuji: stacked discs, blue-grey with a white cap
	local fuji = O + v(15, 0, 25)
	for k = 0, 5 do
		local r = 46 - k * 7
		part({ Name = "Fuji", Shape = Enum.PartType.Cylinder, Size = v(5, r * 2, r * 2), CFrame = CFrame.new(fuji + v(0, 2 + k * 5, 0)) * FLAT, Color = if k >= 4 then Color3.fromRGB(250, 250, 252) else Color3.fromRGB(95, 115, 150), Parent = terrain })
	end
	-- forests: dark green patches on the land
	for _ = 1, 40 do
		local a, b = honshu[rng:NextInteger(1, #honshu - 1)], nil
		b = a + v(rng:NextNumber(-45, 45), 0, rng:NextNumber(-45, 45))
		local d = rng:NextNumber(18, 34)
		part({ Name = "Forest", Shape = Enum.PartType.Cylinder, Size = v(1, d, d), CFrame = CFrame.new(O + b + v(0, 1.7, 0)) * FLAT, Color = Color3.fromRGB(60, 105, 60), Parent = terrain })
	end

	-- cities: blocks of buildings; strong claps make them jump (only a visitor throws them far)
	local cities = folder(model, "Cities")
	local CITY = { { v(-640, 0, 470), 14 }, { v(-420, 0, 232), 14 }, { v(-280, 0, 190), 26 }, { v(-150, 0, 150), 18 }, { v(95, 0, -35), 40 }, { v(170, 0, -235), 12 }, { v(380, 0, -560), 16 } }
	for _, cdef in CITY do
		local c, n = cdef[1], cdef[2]
		for _ = 1, n do
			local h = rng:NextNumber(3, 6 + n * 0.35)
			local w = rng:NextNumber(4, 8)
			local at = O + c + v(rng:NextNumber(-1, 1) * n * 0.9, 1.5 + h / 2, rng:NextNumber(-1, 1) * n * 0.9)
			part({ Name = "Block", Size = v(w, h, w), CFrame = CFrame.new(at), Color = Color3.fromRGB(200, 200, 205):Lerp(Color3.fromRGB(150, 155, 170), rng:NextNumber()), Parent = cities, Attrs = { DamageKind = "Fly", Resist = 0.5, Launch = 0.35 } })
		end
	end
	-- the bullet-train line between the cities, and a train on it
	local rail = folder(model, "Rail")
	for k = 1, #CITY - 1 do
		local a, b = O + CITY[k][1] + v(0, 1.8, 0), O + CITY[k + 1][1] + v(0, 1.8, 0)
		part({ Name = "Track", Size = v(2, 0.4, (b - a).Magnitude), CFrame = CFrame.lookAt((a + b) / 2, b), Color = Color3.fromRGB(235, 235, 240), Parent = rail })
	end
	do
		local a, b = O + CITY[4][1], O + CITY[5][1]
		local dir = (b - a).Unit
		for k = 0, 2 do
			local at = a + dir * (60 + k * 13) + v(0, 3.4, 0)
			local car = CFrame.lookAt(at, at + dir)
			group("Shinkansen", rail, { DamageKind = "Fly", Resist = 0.08, Launch = 0.9 }, car, {
				{ Name = "Car", Size = v(4, 3, 12), CFrame = car, Color = Color3.fromRGB(250, 250, 252) },
				{ Name = "Stripe", Size = v(4.1, 0.6, 12.1), CFrame = car * CFrame.new(0, -0.4, 0), Color = Color3.fromRGB(30, 80, 170) },
			})
		end
	end

	-- clouds, ships and planes, blown away by claps (they drift back)
	for _ = 1, 26 do
		local d = rng:NextNumber(60, 160)
		part({ Name = "Cloud", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, d, d), CFrame = CFrame.new(O + v(rng:NextNumber(-950, 950), 60 + rng:NextNumber(0, 30), rng:NextNumber(-950, 950))) * FLAT, Color = Color3.new(1, 1, 1), Transparency = 0.45, Parent = map, Attrs = { DamageKind = "Fly", Float = true, Resist = 0.03, Launch = 0.6 } })
	end
	local traffic = folder(model, "Traffic")
	local coastline = { v(-560, 0, 300), v(-280, 0, 190), v(-40, 0, 80), v(130, 0, -120), v(230, 0, -360), v(330, 0, -520), v(-260, 0, 360), v(-640, 0, 520), v(-850, 0, 260), v(-1000, 0, 0) }
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

	-- lasting: the glow spreads, and pressure rings ripple out across the sea as your progress grows
	part({ Name = "Glow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 10, 10), CFrame = CFrame.new(O + v(0, 4, 0)) * FLAT, Color = Color3.fromRGB(255, 170, 90), Material = Enum.Material.Neon, Transparency = 0.5, Parent = model, Attrs = { DamageKind = "Glow", MaxRadius = 1400 } })
	local rings = folder(model, "PressureRings")
	local origin = O + v(-40, 2.4, 80)
	for k, radius in { 160, 320, 500, 700, 920 } do
		local segments = 40
		for i = 0, segments - 1 do
			local a = (i + 0.5) / segments * math.pi * 2
			local pos = origin + v(math.cos(a) * radius, 0, math.sin(a) * radius)
			part({ Name = "Ring", Size = v(5, 0.6, 2 * math.pi * radius / segments * 1.05), CFrame = CFrame.lookAt(pos, pos + v(-math.sin(a), 0, math.cos(a))), Color = Color3.fromRGB(255, 240, 200), Material = Enum.Material.Neon, Transparency = 1, Parent = rings, Attrs = { DamageKind = "Reveal", DamageAt = 0.1 + k * 0.15, Visible = 0.35 } })
		end
	end

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
	-- the real continents, turned so Japan (where everyone stands) is on top
	local function latlon(lat, lon)
		local a, b = math.rad(lat), math.rad(lon)
		return Vector3.new(math.cos(a) * math.cos(b), math.sin(a), -math.cos(a) * math.sin(b))
	end
	local japan = latlon(36, 138)
	local turn = CFrame.fromAxisAngle(japan:Cross(Vector3.yAxis).Unit, math.acos(japan:Dot(Vector3.yAxis)))
	local GREEN, DRY, DESERT, ICE = Color3.fromRGB(105, 150, 85), Color3.fromRGB(160, 160, 100), Color3.fromRGB(215, 190, 135), Color3.fromRGB(240, 245, 250)
	local LAND = {
		-- Eurasia
		{ 50, 10, 8, GREEN }, { 55, 40, 13, GREEN }, { 58, 75, 15, DRY }, { 60, 105, 15, GREEN }, { 63, 135, 12, GREEN }, { 66, 160, 9, DRY },
		{ 45, 90, 12, DESERT }, { 35, 105, 11, GREEN }, { 30, 80, 8, DRY }, { 21, 78, 8, GREEN }, { 28, 47, 9, DESERT }, { 14, 103, 7, GREEN },
		{ 42, 125, 6, GREEN }, { 36, 138, 3, GREEN }, { 43, 142, 2, GREEN }, { 0, 113, 5, GREEN },
		-- Africa
		{ 20, 10, 13, DESERT }, { 18, 30, 9, DESERT }, { 3, 20, 12, GREEN }, { -12, 27, 10, GREEN }, { -26, 25, 8, DRY },
		-- the Americas
		{ 55, -105, 14, GREEN }, { 42, -95, 12, GREEN }, { 63, -150, 7, DRY }, { 30, -102, 8, DRY }, { 18, -95, 5, GREEN },
		{ 2, -62, 11, GREEN }, { -14, -54, 10, GREEN }, { -34, -66, 7, DRY },
		-- Australia, Greenland and the poles
		{ -24, 134, 10, DESERT }, { 72, -40, 8, ICE }, { -85, 0, 25, ICE }, { 87, 0, 13, ICE },
	}
	for _, c in LAND do
		local n = turn * latlon(c[1], c[2])
		local size = 2 * R * math.sin(math.rad(c[3])) * 1.15 + 30
		part({ Name = "Continent", Shape = Enum.PartType.Ball, Size = Vector3.new(size, size, size), CFrame = CFrame.new(center + n * (R - size / 2 + math.min(42, size * 0.14))), Color = c[4], Parent = surface, Attrs = opts.land })
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
	if opts.moon then
		-- the Moon: only the biggest claps (a visitor from Space) can nudge it
		local at = center + Vector3.new(-1, 0.45, -0.6).Unit * R * 2.7
		local moon = { { Name = "Moon", Shape = Enum.PartType.Ball, Size = Vector3.new(330, 330, 330), CFrame = CFrame.new(at), Color = Color3.fromRGB(200, 200, 205), Material = Enum.Material.Slate } }
		for _ = 1, 7 do
			local n = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(0.2, 1)).Unit
			local d = rng:NextNumber(40, 80)
			table.insert(moon, { Name = "Crater", Shape = Enum.PartType.Ball, Size = Vector3.new(d, d, d), CFrame = CFrame.new(at + n * (165 - d * 0.3)), Color = Color3.fromRGB(150, 150, 158), Material = Enum.Material.Slate })
		end
		group("Moon", model, { DamageKind = "Fly", Float = true, Resist = 2.5, Launch = 0.25 }, CFrame.new(at), moon)
	end
	if opts.lights then
		-- city lights speckled over the land
		local lights = folder(model, "CityLights")
		for _ = 1, 45 do
			local c = LAND[rng:NextInteger(1, 16)]
			local n = turn * latlon(c[1] + rng:NextNumber(-c[3], c[3]) * 0.6, c[2] + rng:NextNumber(-c[3], c[3]) * 0.6)
			part({ Name = "Lights", Shape = Enum.PartType.Ball, Size = Vector3.new(9, 9, 9), CFrame = CFrame.new(center + n * (R + 14)), Color = Color3.fromRGB(255, 230, 150), Material = Enum.Material.Neon, Parent = lights })
		end
	end
	if opts.rings then
		-- lasting: concentric light rings spreading round the globe from where everyone stands
		local rings = folder(model, "BlastRings")
		for k, deg in { 10, 20, 32, 46, 62, 80 } do
			local segments = 48
			local polar = math.rad(deg)
			for i = 0, segments - 1 do
				local a = (i + 0.5) / segments * math.pi * 2
				local n = Vector3.new(math.sin(polar) * math.cos(a), math.cos(polar), math.sin(polar) * math.sin(a))
				local tangent = Vector3.new(-math.sin(a), 0, math.cos(a))
				local pos = center + n * (R + 18)
				local length = 2 * math.pi * R * math.sin(polar) / segments * 1.08
				part({ Name = "Ring", Size = Vector3.new(7, 5, length), CFrame = CFrame.lookAt(pos, pos + tangent, n), Color = Color3.fromRGB(255, 210, 140), Material = Enum.Material.Neon, Transparency = 1, Parent = rings, Attrs = { DamageKind = "Reveal", DamageAt = 0.05 + k * 0.13, Visible = 0.25 } })
			end
		end
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

-- 7. The Planet: the whole Earth with the Moon; your blast glows across it, light rings spread round
-- it and it starts to turn orange
do
	local center = Vector3.new(22000, 3000, 0)
	local model = newStage("Planet")
	globe(model, center, {
		ocean = { DamageKind = "Tint", ColorB = Color3.fromRGB(205, 120, 70), From = 0.7, To = 1 },
		land = { DamageKind = "Tint", ColorB = Color3.fromRGB(150, 80, 45), From = 0.6, To = 1 },
		cloud = { DamageKind = "Tint", ColorB = Color3.fromRGB(120, 110, 105), From = 0.5, To = 1, Resist = 0.04, Launch = 0.5, Float = true },
		moon = true,
		lights = true,
		rings = true,
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
