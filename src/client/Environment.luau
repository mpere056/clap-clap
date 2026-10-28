--!strict
-- Local destruction, shared presence (docs/10-multiplayer-effects.md).
--
-- Everything here runs only on this client:
--   * persistent damage driven by YOUR stage progress (windows shatter, lamps swing, chairs scoot away)
--   * per-clap bursts by grade (sparks, debris, light flash, shockwave rings, rattles, NPC flinches)
--   * later-stage damage: buildings flatten, craters and glows grow, the planet tints, cracks, shatters
--   * NPC classmates in the ceremony hall (turn around, cover ears, hired ones clap on the beat)
--   * other players' claps as a lighter, throttled ambient layer
--   * shared spectacle moments (Standing Ovation, In Sync)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Icons = require(Shared.Icons)

local Beat = require(script.Parent.Beat)
local Audio = require(script.Parent.Audio)
local CameraRig = require(script.Parent.CameraRig)

local Environment = {}

local player = Players.LocalPlayer
local rng = Random.new()

local stageId = 1
local progress = 0
local walking = false
local hiredCount = 0
local effectsFolder: Folder

-- damage items for the current stage
type Item = {
	kind: string,
	at: number,
	parts: { BasePart },
	base: { CFrame },
	pivot: CFrame,
	phase: number,
	broken: boolean,
	kick: number,
	offset: CFrame, -- current displacement (chairs)
	push: number, -- how far a toppled item gets blown (studs)
	transparency: { number },
	size: Vector3, -- original size/colour for kinds that reshape parts
	color: Color3,
	last: number, -- last applied amount (reshaping kinds only update when it changes)
	data: { [string]: any }, -- the part's attributes
	cur: { CFrame }, -- where the lasting-damage layer puts each part this frame
	pose: CFrame, -- chairs: where the seat is now (NPCs ride along)
	center: Vector3, -- for distance checks against claps
	-- per-clap flight (Bend items use dpos/dang as the bend and its speed)
	dpos: Vector3,
	dvel: Vector3,
	drot: CFrame,
	dang: Vector3,
	active: boolean,
	healAt: number,
	brokenUntil: number, -- windows broken by a clap come back after this
}
local items: { Item } = {}
local rattleTimer = 0
local rattleStrength = 0

-- NPC classmates (stage 1 only)
type Npc = {
	model: Model,
	parts: { [string]: BasePart },
	chair: Item?,
	seat: CFrame,
	row: number,
	column: number,
	lookAt: number,
	coverAt: number,
	hired: boolean,
	flinch: number,
	beatOffset: number,
}
local npcs: { Npc } = {}

local lastPulseFx: { [number]: number } = {}

local SKIN_TONES = { Color3.fromRGB(234, 192, 160), Color3.fromRGB(222, 176, 140), Color3.fromRGB(240, 205, 175) }
local HAIR = { Color3.fromRGB(25, 22, 22), Color3.fromRGB(45, 32, 26), Color3.fromRGB(20, 20, 24) }
local NAVY = Color3.fromRGB(30, 42, 68)
local GOLD = Color3.fromRGB(232, 184, 102)

----------------------------------------------------------------------------------------------------
-- helpers

local function stageModel(id: number): Instance?
	local stages = workspace:FindFirstChild("Stages")
	return stages and stages:FindFirstChild(Config.getStage(id).key)
end

local function myRoot(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function localPart(props: { [string]: any }): Part
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
	p.Parent = props.Parent or effectsFolder
	return p
end

local function tween(duration: number, step: (number) -> (), done: (() -> ())?)
	local started = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local k = math.clamp((os.clock() - started) / duration, 0, 1)
		step(k)
		if k >= 1 then
			conn:Disconnect()
			if done then
				done()
			end
		end
	end)
end

local function userColor(userId: number): Color3
	return Color3.fromHSV((userId * 0.61803) % 1, 0.55, 1)
end

----------------------------------------------------------------------------------------------------
-- shockwave rings & dust

-- how big a "normal" ring is on each stage (the camera is much further away later on)
local RING_SCALE = { 1, 1, 8, 40, 8, 60, 40, 40, 6 }

-- the local "ground" under a character: below them, or towards the planet's centre on globe stages
local function groundUnder(root: BasePart): (Vector3, Vector3)
	if stageId == 7 or stageId == 8 then
		local up = (root.Position - Config.getStage(stageId).origin).Unit
		return root.Position - up * 2.8, up
	end
	return root.Position - Vector3.new(0, 2.8, 0), Vector3.yAxis
end

-- expanding shockwave ring on the ground, built from segments so the middle stays clear
local RING_SEGMENTS = 18
function Environment.ring(origin: Vector3, radius: number, color: Color3, duration: number, startTransparency: number?, up: Vector3?)
	local t0 = startTransparency or 0.55
	local segments: { BasePart } = {}
	for i = 1, RING_SEGMENTS do
		segments[i] = localPart({ Name = "Shockwave", Material = Enum.Material.Neon, Color = color, Transparency = t0, Size = Vector3.new(0.4, 0.3, 0.4) })
	end
	local cframes: { CFrame } = table.create(RING_SEGMENTS)
	local normal = up or Vector3.yAxis
	local side = if math.abs(normal.Y) > 0.9 then Vector3.xAxis else Vector3.yAxis
	local right = side:Cross(normal).Unit
	local basis = CFrame.fromMatrix(origin, right, normal)
	tween(duration, function(k)
		local eased = 1 - (1 - k) ^ 3
		local r = 0.5 + radius * eased
		local arc = 2 * math.pi * r / RING_SEGMENTS * 1.08
		local thickness = math.max(0.3, r * 0.05) * (1 - k * 0.6)
		local height = math.max(0.2, r * 0.025)
		for i, seg in segments do
			local angle = (i / RING_SEGMENTS) * math.pi * 2
			seg.Size = Vector3.new(thickness, height, arc)
			seg.Transparency = t0 + (1 - t0) * k
			cframes[i] = basis * CFrame.Angles(0, angle, 0) * CFrame.new(r, 0, 0)
		end
		workspace:BulkMoveTo(segments, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end, function()
		for _, seg in segments do
			seg:Destroy()
		end
	end)
end

local dustAttachment: Attachment? = nil
local dustEmitter: ParticleEmitter? = nil

local function dust(position: Vector3, amount: number, size: number)
	if not dustEmitter or not dustAttachment then
		return
	end
	dustAttachment.WorldPosition = position
	dustEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size * 0.5),
		NumberSequenceKeypoint.new(1, size * 1.6),
	})
	dustEmitter.Speed = NumberRange.new(size * 3, size * 8)
	dustEmitter:Emit(amount)
end

-- glass flying out of a window, away from the clap (they land, then fade)
local liveShards = 0
local function shards(part: BasePart, from: Vector3?)
	local count = math.clamp(math.floor(part.Size.Y * part.Size.Z / 12), 8, 18)
	for _ = 1, count do
		if liveShards >= 150 then
			return
		end
		liveShards += 1
		local shard = Instance.new("Part")
		shard.Size = Vector3.new(0.12, rng:NextNumber(0.8, 2.4), rng:NextNumber(0.8, 2.4))
		shard.Color = Color3.fromRGB(205, 232, 255)
		shard.Material = Enum.Material.Glass
		shard.Reflectance = 0.25
		shard.Transparency = 0.2
		shard.CanCollide = true
		shard.CanQuery = false
		shard.CanTouch = false
		shard.CastShadow = false
		local offset = Vector3.new(0, rng:NextNumber(-0.5, 0.5) * part.Size.Y, rng:NextNumber(-0.5, 0.5) * part.Size.Z)
		shard.CFrame = part.CFrame * CFrame.new(offset) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0)
		shard.Parent = effectsFolder
		local source = from or (myRoot() and (myRoot() :: BasePart).Position) or shard.Position - Vector3.yAxis
		local away = shard.Position - source
		away = if away.Magnitude > 0.1 then away.Unit else Vector3.yAxis
		shard.AssemblyLinearVelocity = away * rng:NextNumber(18, 40) + Vector3.new(0, rng:NextNumber(6, 18), 0)
		shard.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-15, 15), rng:NextNumber(-15, 15), rng:NextNumber(-15, 15))
		task.delay(2.4, function()
			tween(0.6, function(k)
				shard.Transparency = 0.2 + 0.8 * k
			end, function()
				shard:Destroy()
				liveShards -= 1
			end)
		end)
	end
end

----------------------------------------------------------------------------------------------------
-- damage items
--
-- Two layers move each item:
--   * the stage's lasting damage, driven by YOUR progress (chairs pushed back, the field cracking,
--     buildings flattening as you get stronger), and
--   * per-clap shoves from anyone's clap (yours and other players'), which fly, bounce and heal
--     back after a few seconds. Every client applies the same clap the same way, so everyone in the
--     stage sees the same chairs fly.

-- clap force (Formulas.clapForce): 0 on a fresh stage, 1 once it's maxed, +1 per stage a visitor is
-- ahead. Each kind of item needs this much force (after distance falloff) before it reacts, and
-- flies this far relative to a chair.
-- (a part or model can override both with Resist / Launch attributes)
local RESIST = { Topple = 0.1, Rattle = 0.04, Fly = 0.2, Swing = 0, Shatter = 0.3, Bend = 0.3, Flatten = 1.1, Drift = 0, Reveal = 0 }
local LAUNCH = { Topple = 1, Rattle = 1.3, Fly = 1, Flatten = 0.5, Drift = 1.6 }
local GRAVITY = 90 -- studs/s² on the hall's scale

-- how big the stage's props are, and how far claps carry, relative to the hall (the camera sees
-- far more of the later stages, so their effect visuals use RING_SCALE instead)
local REACH_SCALE = { 1, 2, 8, 40, 30, 60, 40, 40, 20 }

local function stageScale(): number
	return REACH_SCALE[stageId] or 6
end

-- how an item answers a shove: its own kind, or a React attribute (a flattening tower that also sways)
local function reaction(item: Item): string
	return (item.data.React :: string?) or item.kind
end

-- how far a clap of force F reaches (studs)
local function reach(force: number): number
	return stageScale() * (6 + 25 * math.min(force, 1) + 30 * math.max(force - 1, 0))
end

local function newItem(kind: string, parts: { BasePart }, pivot: CFrame, at: number): Item
	local base = {}
	for i, p in parts do
		base[i] = p.CFrame
	end
	local p = parts[1]
	return {
		kind = kind,
		at = at,
		parts = parts,
		base = base,
		cur = table.clone(base),
		pivot = pivot,
		pose = pivot,
		center = pivot.Position,
		phase = rng:NextNumber(0, 6.28),
		broken = false,
		kick = 0,
		offset = CFrame.new(),
		push = 0,
		transparency = { p.Transparency },
		size = p.Size,
		color = p.Color,
		last = -1,
		data = p:GetAttributes(),
		dpos = Vector3.zero,
		dvel = Vector3.zero,
		drot = CFrame.identity,
		dang = Vector3.zero,
		active = false,
		healAt = 0,
		brokenUntil = 0,
	}
end

local function collectItems(model: Instance)
	table.clear(items)
	local claimed: { [Instance]: boolean } = {}
	-- players' seats sit inside some of the chairs: they move with the chair (and so does whoever
	-- is sitting on them)
	local spots = model:FindFirstChild("Spots")
	local seats: { BasePart } = {}
	if spots then
		for _, spot in spots:GetChildren() do
			if spot:IsA("Seat") then
				table.insert(seats, spot)
			end
		end
	end
	-- chairs are moved as a whole
	local chairs = model:FindFirstChild("Chairs")
	if chairs then
		for _, chair in chairs:GetChildren() do
			local parts = {}
			for _, p in chair:GetDescendants() do
				if p:IsA("BasePart") then
					table.insert(parts, p)
					claimed[p] = true
				end
			end
			if #parts == 0 then
				continue
			end
			local seatAt = (chair:GetAttribute("SeatCFrame") :: CFrame?) or parts[1].CFrame
			for _, spot in seats do
				if not claimed[spot] and (spot.Position - seatAt.Position).Magnitude < 3 then
					table.insert(parts, spot)
					claimed[spot] = true
				end
			end
			local seat = chair:FindFirstChild("Seat") :: BasePart?
			local item = newItem("Topple", parts, seatAt, if seat then (seat:GetAttribute("DamageAt") :: number?) or 2 else 2)
			item.push = if seat then (seat:GetAttribute("Push") :: number?) or 2.5 else 0
			chair:SetAttribute("ItemIndex", #items + 1)
			table.insert(items, item)
		end
	end
	-- models marked with a DamageKind move as one (cars, trees, fences, goals)
	for _, m in model:GetDescendants() do
		if m:IsA("Model") and m:GetAttribute("DamageKind") then
			local parts = {}
			for _, p in m:GetDescendants() do
				if p:IsA("BasePart") then
					table.insert(parts, p)
					claimed[p] = true
				end
			end
			if #parts > 0 then
				local item = newItem(m:GetAttribute("DamageKind") :: string, parts, m:GetPivot(), (m:GetAttribute("DamageAt") :: number?) or 1)
				item.data = m:GetAttributes()
				table.insert(items, item)
			end
		end
	end
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and not claimed[p] then
			local kind = p:GetAttribute("DamageKind") :: string?
			if kind then
				local pivot = p.CFrame
				if kind == "Swing" then
					pivot = p.CFrame * CFrame.new(0, 6.6, 0) -- top of the cord
				elseif kind == "Bend" or p:GetAttribute("React") == "Bend" then
					pivot = CFrame.new(p.Position - Vector3.new(0, p.Size.Y / 2, 0)) -- bends from the bottom
				end
				local parts = { p }
				if kind == "Swing" then
					-- swing the cord with the lamp
					local parent = p.Parent
					if parent then
						for _, sibling in parent:GetChildren() do
							if sibling:IsA("BasePart") and sibling.Name == "LightCord" and (sibling.Position - p.Position).Magnitude < 5 then
								table.insert(parts, sibling)
							end
						end
					end
				end
				local item = newItem(kind, parts, pivot, (p:GetAttribute("DamageAt") :: number?) or 1)
				item.center = p.Position
				table.insert(items, item)
			end
		end
	end
end

local function restoreItems()
	for _, item in items do
		for i, p in item.parts do
			p.CFrame = item.base[i]
		end
		local p = item.parts[1]
		if p and item.transparency[1] then
			p.Transparency = item.transparency[1]
		end
		if p and item.last >= 0 then
			p.Size = item.size
			p.Color = item.color
		end
		item.broken = false
		item.last = -1
		item.offset = CFrame.new()
		item.active = false
	end
end

-- the "up" direction at an item: away from the planet's centre on the globe stages
local function upAt(position: Vector3): Vector3
	if stageId == 7 or stageId == 8 then
		return (position - Config.getStage(stageId).origin).Unit
	end
	return Vector3.yAxis
end

-- one clap's shove on every item in reach. origin: the clapper; force: their clap force x grade.
-- Returns how many windows it broke (the caller plays the glass sound once).
local function shoveItems(origin: Vector3, force: number, now: number): number
	local radius = reach(force)
	local scale = stageScale()
	local broke = 0
	local hold = 2.2 + math.min(force, 5) * 0.7
	for _, item in items do
		local resist = (item.data.Resist :: number?) or RESIST[item.kind]
		if not resist then
			continue
		end
		local offset = item.center - origin
		local distance = offset.Magnitude
		-- sound carries: glass breaks from further away than things get pushed
		local itemRadius = if item.kind == "Shatter" then radius * 2 else radius
		if distance > itemRadius or distance < 2.5 then
			continue -- out of reach, or the clapper's own seat
		end
		local f = force * (1 - distance / itemRadius) ^ 1.5
		local excess = f - resist
		if excess <= 0 then
			continue
		end
		local up = upAt(item.center)
		local flat = offset - up * offset:Dot(up)
		local dir = if flat.Magnitude > 0.01 then flat.Unit else Vector3.xAxis
		if item.kind == "Shatter" then
			if not item.broken and now >= item.brokenUntil then
				item.brokenUntil = now + 6 + rng:NextNumber(0, 2)
				item.data.LastClap = origin
				broke += 1
			end
		elseif item.kind == "Reveal" then
			item.kick = math.max(item.kick, math.min(1, excess * 2)) -- lava cracks flare up
		elseif item.kind == "Swing" then
			item.kick = math.min(0.7, item.kick + excess * 0.4)
		elseif reaction(item) == "Bend" then
			-- trees, lamp posts and towers bend away and spring back
			item.dang += Vector3.new(dir.Z, 0, -dir.X) * math.min(excess, 2) * 3
			item.active = true
			item.healAt = now
		else
			local launch = (item.data.Launch :: number?) or LAUNCH[item.kind] or 1
			if item.kind == "Drift" or item.data.Float == true then
				launch *= 0.35 -- nothing slows floating things down but drag: keep them in view
			end
			local e = math.min(excess, 6)
			item.dvel += (dir * (6 + 22 * e) + up * (3 + 16 * e)) * launch * scale
			local spinAxis = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
			if spinAxis.Magnitude > 0.01 then
				item.dang += spinAxis.Unit * (1 + 4 * e) * math.min(launch, 1.2)
			end
			item.active = true
			item.healAt = math.max(item.healAt, now + hold)
		end
	end
	return broke
end

local moveParts: { BasePart } = {}
local moveCFrames: { CFrame } = {}

-- per-clap flight: gravity, bounce on the floor, then ease back to where it belongs
local function stepFlight(item: Item, dt: number, now: number): boolean
	local scale = stageScale()
	if reaction(item) == "Bend" then
		-- a damped spring on the bend
		local tilt = item.dpos -- (axis * angle) for trees
		item.dang += (-tilt * 40 - item.dang * 5) * dt
		item.dpos = tilt + item.dang * dt
		local angle = item.dpos.Magnitude
		item.drot = if angle > 1e-4 then CFrame.fromAxisAngle(item.dpos.Unit, math.min(angle, 1.2)) else CFrame.identity
		if angle < 0.002 and item.dang.Magnitude < 0.01 then
			item.dpos, item.dang, item.drot = Vector3.zero, Vector3.zero, CFrame.identity
			return false
		end
		return true
	end
	local up = upAt(item.center)
	local floating = item.kind == "Drift" or item.data.Float == true -- no gravity or floor (space, clouds, ships)
	if now < item.healAt then
		if floating then
			item.dvel *= math.exp(-dt * 1.5)
		else
			item.dvel -= up * GRAVITY * scale * dt
		end
		item.dpos += item.dvel * dt
		local height = item.dpos:Dot(up)
		if height < 0 and not floating then
			item.dpos -= up * height
			local vUp = item.dvel:Dot(up)
			if vUp < 0 then
				item.dvel -= up * vUp * 1.3 -- bounce
			end
			local slide = item.dvel - up * item.dvel:Dot(up)
			item.dvel -= slide * (1 - math.exp(-dt * 5)) -- floor friction
			item.dang *= math.exp(-dt * 4)
		end
		local spin = item.dang.Magnitude
		if spin > 1e-4 then
			item.drot = CFrame.fromAxisAngle(item.dang.Unit, spin * dt) * item.drot
		end
		return true
	end
	-- heal: glide back home
	local k = 1 - math.exp(-dt * 3.5)
	item.dvel, item.dang = Vector3.zero, Vector3.zero
	item.dpos = item.dpos:Lerp(Vector3.zero, k)
	item.drot = item.drot:Lerp(CFrame.identity, k)
	if item.dpos.Magnitude < 0.02 * scale then
		local _, angle = item.drot:ToAxisAngle()
		if math.abs(angle) < 0.01 then
			item.dpos, item.drot = Vector3.zero, CFrame.identity
			return false
		end
	end
	return true
end

local function updateItems(dt: number)
	local root = myRoot()
	local me = if root then root.Position else Vector3.zero
	local time = os.clock()
	rattleTimer = math.max(0, rattleTimer - dt)
	table.clear(moveParts)
	table.clear(moveCFrames)

	for _, item in items do
		local kind = item.kind
		local moved = false -- the lasting-damage layer changed item.cur this frame
		if kind == "Shatter" then
			-- only claps break glass (see shoveItems), and it comes back a few seconds later
			local shouldBreak = time < item.brokenUntil
			if shouldBreak and not item.broken then
				item.broken = true
				item.parts[1].Transparency = 1
				shards(item.parts[1], item.data.LastClap)
			elseif not shouldBreak and item.broken then
				item.broken = false
				-- the pane fades back in
				local p = item.parts[1]
				local target = item.transparency[1]
				tween(0.5, function(k)
					p.Transparency = 1 - (1 - target) * k
				end)
			end
		elseif kind == "Swing" then
			item.kick = math.max(0, item.kick - dt * 0.6)
			local amp = math.max(0, progress - item.at) * 0.5 + item.kick
			if amp > 0.001 then
				local angle = math.sin(time * 2.4 + item.phase) * amp
				local rot = item.pivot * CFrame.Angles(angle, 0, angle * 0.4) * item.pivot:Inverse()
				for i in item.parts do
					item.cur[i] = rot * item.base[i]
				end
				moved = true
			end
		elseif kind == "Topple" then
			-- scoot (ceremony) or get blown across the room (gym) away from me
			local k = math.clamp((progress - item.at) * 4, 0, 1)
			local amount = k * item.push
			local away = item.pivot.Position - me
			away = Vector3.new(away.X, 0, away.Z)
			local dir = if away.Magnitude > 0.1 then away.Unit else Vector3.xAxis
			item.kick = math.max(0, item.kick - dt * 2)
			local jitter = rattleTimer * rattleStrength * 0.25 + item.kick * 0.15
			local offsetPos = dir * amount + Vector3.new(rng:NextNumber(-1, 1) * jitter, 0, rng:NextNumber(-1, 1) * jitter)
			local yaw = math.sin(item.phase) * amount * 0.12
			-- big pushes knock the item over
			local roll = if item.push > 5 then k * math.rad(80) * math.sign(math.sin(item.phase * 3)) else 0
			item.offset = CFrame.new(offsetPos)
			local spin = CFrame.Angles(0, yaw, 0) * CFrame.fromAxisAngle(Vector3.new(-dir.Z, 0, dir.X), roll)
			item.pose = (item.pivot + offsetPos) * spin
			if amount > 0 or jitter > 0 or item.last ~= 0 then
				item.last = if amount > 0 or jitter > 0 then 1 else 0
				for i in item.parts do
					item.cur[i] = item.pose * item.pivot:ToObjectSpace(item.base[i])
				end
				moved = true
			end
		elseif kind == "Rattle" then
			if rattleTimer > 0 and progress >= item.at * 0.5 then
				local j = rattleTimer * rattleStrength * 0.12
				item.cur[1] = item.base[1] * CFrame.new(rng:NextNumber(-j, j), rng:NextNumber(-j, j) * 0.3, rng:NextNumber(-j, j))
				item.kick = 0
				moved = true
			elseif item.kick ~= -1 then
				item.kick = -1
				item.cur[1] = item.base[1]
				moved = true
			end
		elseif kind == "Flatten" then
			-- buildings squash into rubble as the blast passes them
			local amount = math.clamp((progress - item.at) * 5, 0, 1)
			if math.abs(amount - item.last) > 0.02 then
				item.last = amount
				local p = item.parts[1]
				local drop = item.size.Y * 0.88 * amount
				p.Size = Vector3.new(item.size.X, item.size.Y - drop, item.size.Z)
				item.cur[1] = item.base[1] * CFrame.new(0, -drop / 2, 0)
				p.Color = item.color:Lerp(Color3.fromRGB(70, 62, 55), amount * 0.75)
				moved = true
			end
		elseif kind == "Crater" or kind == "Glow" then
			-- a disc centred on me that grows with my power (crater floor, or a glowing blast)
			local maxRadius = (item.data.MaxRadius :: number?) or 100
			local radius = math.max(0.5, maxRadius * (if kind == "Glow" then progress ^ 1.6 else progress ^ 0.8))
			if math.abs(radius - item.last) > maxRadius * 0.004 and root then
				item.last = radius
				local p = item.parts[1]
				local origin, up
				if item.data.OnGlobe then
					local center = Config.getStage(stageId).origin
					up = (me - center).Unit
					origin = center + up * ((item.data.GlobeRadius :: number?) or 600) * 1.004
				else
					origin = Vector3.new(me.X, item.base[1].Position.Y, me.Z)
					up = Vector3.yAxis
				end
				local side = if math.abs(up.Y) > 0.9 then Vector3.zAxis else Vector3.yAxis
				-- (on the globes it's a flattened sphere hugging the surface, not a flat lid)
				local thickness = if p:FindFirstChildOfClass("SpecialMesh") then radius * 0.3 else item.size.X
				p.Size = Vector3.new(thickness, radius * 2, radius * 2)
				p.CFrame = CFrame.fromMatrix(origin, up, side:Cross(up).Unit)
				if kind == "Glow" then
					p.Transparency = 0.45 + 0.35 * (1 - progress)
				else
					p.Transparency = if progress > 0.02 then item.transparency[1] else 1
				end
			end
		elseif kind == "Tint" then
			-- colour shifts across a progress range (oceans boil white, the planet turns orange)
			local from, to = (item.data.From :: number?) or 0, (item.data.To :: number?) or 1
			local amount = math.clamp((progress - from) / math.max(0.01, to - from), 0, 1)
			if math.abs(amount - item.last) > 0.01 then
				item.last = amount
				local target = (item.data.ColorB :: Color3?) or item.color
				item.parts[1].Color = item.color:Lerp(target, amount)
			end
		elseif kind == "Reveal" then
			-- fades in once progress passes its point (lava cracks, steam); claps make them flare
			item.kick = math.max(0, item.kick - dt * 3)
			local amount = math.clamp((progress - item.at) * 5, 0, 1)
			local untilAt = item.data.Until :: number?
			if untilAt then
				amount *= math.clamp((untilAt - progress) * 5, 0, 1)
			end
			amount = math.max(amount, item.kick)
			if math.abs(amount - item.last) > 0.02 then
				item.last = amount
				local visible = (item.data.Visible :: number?) or 0
				item.parts[1].Transparency = 1 - (1 - visible) * amount
			end
		elseif kind == "Approach" then
			-- e.g. the dust wall rolling in towards the city as you get stronger
			local offset = (item.data.Travel :: Vector3?) or Vector3.zero
			local amount = math.clamp((progress - item.at) / math.max(0.01, 1 - item.at), 0, 1)
			item.cur[1] = item.base[1] + offset * amount
			item.parts[1].Transparency = 1 - (1 - item.transparency[1]) * math.clamp(amount * 3, 0, 1)
			moved = true
		elseif kind == "Drift" then
			-- Earth's fragments drift away from me and tumble
			local away = item.base[1].Position - me
			local dir = if away.Magnitude > 0.1 then away.Unit else Vector3.yAxis
			local dist = progress * ((item.data.Drift :: number?) or 80)
			local spin = CFrame.Angles(time * 0.1 + item.phase, time * 0.07, 0)
			item.cur[1] = (item.base[1] + dir * dist) * spin
			moved = true
		end

		-- the per-clap layer on top
		if item.active then
			item.active = stepFlight(item, dt, time)
			local c = item.pivot.Position
			local t = CFrame.new(c + (if reaction(item) == "Bend" then Vector3.zero else item.dpos)) * item.drot * CFrame.new(-c)
			for i, p in item.parts do
				table.insert(moveParts, p)
				table.insert(moveCFrames, t * item.cur[i])
			end
			item.pose = t * (if item.kind == "Topple" then item.pose else item.pivot)
		elseif moved then
			for i, p in item.parts do
				table.insert(moveParts, p)
				table.insert(moveCFrames, item.cur[i])
			end
		end
	end
	if #moveParts > 0 then
		workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

----------------------------------------------------------------------------------------------------
-- NPC classmates

local function buildNpc(chair: Model, seat: CFrame, row: number, column: number): Npc
	local model = Instance.new("Model")
	model.Name = "Classmate"
	local skin = SKIN_TONES[rng:NextInteger(1, #SKIN_TONES)]
	local hair = HAIR[rng:NextInteger(1, #HAIR)]
	local parts: { [string]: BasePart } = {}
	local function add(name: string, size: Vector3, color: Color3, shape: Enum.PartType?)
		local p = localPart({ Name = name, Size = size, Color = color, Parent = model })
		if shape then
			p.Shape = shape
		end
		p.CastShadow = true
		parts[name] = p
	end
	add("Thighs", Vector3.new(1.7, 0.6, 1.9), NAVY)
	add("Shins", Vector3.new(1.7, 2.0, 0.6), NAVY)
	add("Torso", Vector3.new(1.9, 2.1, 1.0), NAVY)
	add("Head", Vector3.new(1.35, 1.35, 1.35), skin, Enum.PartType.Ball)
	add("Hair", Vector3.new(1.45, 1.45, 1.45), hair, Enum.PartType.Ball)
	add("ArmL", Vector3.new(0.55, 1.9, 0.55), NAVY)
	add("ArmR", Vector3.new(0.55, 1.9, 0.55), NAVY)
	add("HandL", Vector3.new(0.5, 0.5, 0.5), skin, Enum.PartType.Ball)
	add("HandR", Vector3.new(0.5, 0.5, 0.5), skin, Enum.PartType.Ball)
	model.Parent = effectsFolder

	local index = chair:GetAttribute("ItemIndex") :: number?
	return {
		model = model,
		parts = parts,
		chair = if index then items[index] else nil,
		seat = seat,
		row = row,
		column = column,
		lookAt = 0.12 + rng:NextNumber(0, 0.35),
		coverAt = 0.45 + rng:NextNumber(0, 0.35),
		hired = false,
		flinch = 0,
		beatOffset = rng:NextNumber(-0.04, 0.04),
	}
end

local function spawnNpcs(model: Instance)
	local chairs = model:FindFirstChild("Chairs")
	if not chairs then
		return
	end
	for _, chair in chairs:GetChildren() do
		if chair:IsA("Model") and not chair:GetAttribute("PlayerSpot") then
			local seat = chair:GetAttribute("SeatCFrame") :: CFrame?
			if seat then
				table.insert(npcs, buildNpc(chair, seat, (chair:GetAttribute("Row") :: number?) or 0, (chair:GetAttribute("Column") :: number?) or 0))
			end
		end
	end
end

local function clearNpcs()
	for _, npc in npcs do
		npc.model:Destroy()
	end
	table.clear(npcs)
end

-- hire the classmates sitting closest to me
local function assignHired()
	local root = myRoot()
	local me = if root then root.Position else Vector3.zero
	local sorted = table.clone(npcs)
	table.sort(sorted, function(a, b)
		return (a.seat.Position - me).Magnitude < (b.seat.Position - me).Magnitude
	end)
	for i, npc in sorted do
		npc.hired = i <= hiredCount
	end
end

local npcParts: { BasePart } = {}
local npcCFrames: { CFrame } = {}

local function updateNpcs(dt: number)
	if #npcs == 0 then
		return
	end
	local root = myRoot()
	local me = if root then root.Position else Vector3.zero
	local beatPhase = Beat.phase()
	table.clear(npcParts)
	table.clear(npcCFrames)

	local function put(p: BasePart, cf: CFrame)
		table.insert(npcParts, p)
		table.insert(npcCFrames, cf)
	end

	for _, npc in npcs do
		npc.flinch = math.max(0, npc.flinch - dt * 4)
		local seat = npc.seat
		if npc.chair then
			seat = npc.chair.pose -- ride along when the chair scoots or flies
		end
		local jitter = npc.flinch * 0.25
		local base = seat * CFrame.new(rng:NextNumber(-jitter, jitter), 0, rng:NextNumber(-jitter, jitter))

		-- turn round to stare at the noisy one (only people in front of me)
		local toMe = me - seat.Position
		local inFront = toMe.Z > 2
		local look = if inFront and not npc.hired then math.clamp((progress - npc.lookAt) * 5, 0, 1) else 0
		local side = if toMe.X >= 0 then 1 else -1
		local torsoYaw = look * math.rad(28) * -side
		local headYaw = look * math.rad(95) * -side
		local cover = if npc.hired then 0 else math.clamp((progress - npc.coverAt) * 6, 0, 1)

		local body = base * CFrame.Angles(0, torsoYaw, 0)
		put(npc.parts.Thighs, base * CFrame.new(0, 0.5, -0.6))
		put(npc.parts.Shins, base * CFrame.new(0, -0.95, -1.4))
		put(npc.parts.Torso, body * CFrame.new(0, 1.75, 0.3) * CFrame.Angles(math.rad(-npc.flinch * 8), 0, 0))
		local head = body * CFrame.new(0, 3.45, 0.3) * CFrame.Angles(0, headYaw - torsoYaw, 0)
		put(npc.parts.Head, head)
		put(npc.parts.Hair, head * CFrame.new(0, 0.12, 0.12))

		for _, armSide in { -1, 1 } do
			local shoulder = body * CFrame.new(armSide * 1.22, 2.65, 0.3)
			local rot: CFrame
			if npc.hired then
				-- clap on the beat, arms forward
				local phase = (beatPhase + npc.beatOffset) % 1
				local closed = math.max(0, 1 - phase * 5) -- snap closed right on the beat
				local inward = math.rad(18 + 14 * closed)
				rot = CFrame.Angles(0, -armSide * inward, 0) * CFrame.Angles(math.rad(75), 0, 0)
			elseif cover > 0 then
				rot = CFrame.Angles(0, 0, -armSide * math.rad(165) * cover)
			else
				rot = CFrame.new()
			end
			local arm = shoulder * rot * CFrame.new(0, -0.9, 0)
			put(if armSide < 0 then npc.parts.ArmL else npc.parts.ArmR, arm)
			put(if armSide < 0 then npc.parts.HandL else npc.parts.HandR, arm * CFrame.new(0, -0.95, 0))
		end
	end
	workspace:BulkMoveTo(npcParts, npcCFrames, Enum.BulkMoveMode.FireCFrameChanged)
end

----------------------------------------------------------------------------------------------------
-- character arm clapping: everyone's avatar, mine included whenever I'm not in first person
-- (walking, or standing on my spot in later stages). The pose is written to the joints' Transform
-- right after the Animator runs (PreSimulation), so it layers over walk/idle animations and works
-- on both Motor6D and AnimationConstraint rigs.

type ArmRig = { joints: { any }, elbows: { any }, r6: boolean }
type ArmClap = { start: number, last: number, rig: ArmRig, written: { [any]: CFrame } }
local armClaps: { [Model]: ArmClap } = {}

local ARM_RISE, ARM_HOLD, ARM_LOWER = 0.12, 1.0, 0.3 -- seconds: raise, stay up between claps, lower
local OPEN_YAW, CLOSED_YAW = math.rad(24), math.rad(56) -- arms swung inwards: apart / hands meeting
local PITCH, ELBOW = math.rad(62), math.rad(30)

local function findJoint(character: Model, names: { string }): any
	for _, name in names do
		local joint = character:FindFirstChild(name, true)
		if joint and (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) then
			return joint
		end
	end
	return nil
end

local function armRig(character: Model): ArmRig?
	local right = findJoint(character, { "RightShoulder", "Right Shoulder" })
	local left = findJoint(character, { "LeftShoulder", "Left Shoulder" })
	if not (right and left) then
		return nil
	end
	local elbows = {}
	for _, name in { "RightElbow", "LeftElbow" } do
		local elbow = findJoint(character, { name })
		if elbow then
			table.insert(elbows, elbow)
		end
	end
	return { joints = { right, left }, elbows = elbows, r6 = right.Name == "Right Shoulder" }
end

-- a clap by this character: raise the arms if they're down, then snap the hands together
local function armClap(character: Model)
	local now = os.clock()
	local entry = armClaps[character]
	if entry then
		if now - entry.last > ARM_HOLD then
			-- arms on their way down: pick up from where they are
			entry.start = now - ARM_RISE * (1 - math.clamp((now - entry.last - ARM_HOLD) / ARM_LOWER, 0, 1))
		end
		entry.last = now
		return
	end
	local rig = armRig(character)
	if rig then
		armClaps[character] = { start = now, last = now, rig = rig, written = {} }
	end
end

local function smooth(k: number): number
	return k * k * (3 - 2 * k)
end

local function updateArmClaps()
	local now = os.clock()
	for character, entry in armClaps do
		local since = now - entry.last
		local done = not character.Parent or since > ARM_HOLD + ARM_LOWER
		local raised = math.min(1, (now - entry.start) / ARM_RISE)
		local lowered = math.clamp((since - ARM_HOLD) / ARM_LOWER, 0, 1)
		local active = if done then 0 else smooth(math.min(raised, 1 - lowered))
		-- each clap: the hands snap together in 50 ms, then spring apart
		local closed = smooth(if since < 0.05 then since / 0.05 else math.max(0, 1 - (since - 0.05) / 0.22))
		local yaw = OPEN_YAW + (CLOSED_YAW - OPEN_YAW) * closed
		local pitch = PITCH + math.rad(6) * closed
		for i, joint in entry.rig.joints do
			local side = if i == 1 then 1 else -1
			local pose = if entry.rig.r6
				then CFrame.Angles(0, yaw * side, 0) * CFrame.Angles(0, 0, pitch * side)
				else CFrame.Angles(0, yaw * side, 0) * CFrame.Angles(pitch, 0, 0)
			-- blend over the Animator's pose; if no animation drives this joint, over the rest pose
			local base = if joint.Transform == entry.written[joint] then CFrame.identity else joint.Transform
			joint.Transform = base:Lerp(pose, active)
			entry.written[joint] = joint.Transform
		end
		for _, elbow in entry.rig.elbows do
			local base = if elbow.Transform == entry.written[elbow] then CFrame.identity else elbow.Transform
			elbow.Transform = base:Lerp(CFrame.Angles(ELBOW, 0, 0), active)
			entry.written[elbow] = elbow.Transform
		end
		if done then
			armClaps[character] = nil
		end
	end
end

-- where a character's hands meet when clapping
local function handsPoint(character: Model): Vector3?
	local torso = (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) :: BasePart?
	if not torso then
		return nil
	end
	local s = torso.Size.Y / 1.6 -- avatar scale
	return (torso.CFrame * CFrame.new(0, 0.55 * s, -1.35 * s)).Position
end

-- a comic "pop" where the hands meet: a bright disc inside a burst of rays, gone in a quarter second
local function clapPop(position: Vector3, color: Color3, size: number)
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = workspace.Terrain
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(size, size)
	gui.LightInfluence = 0
	gui.Parent = attachment
	local rays = Instance.new("ImageLabel")
	rays.BackgroundTransparency = 1
	rays.Image = Icons.get("ui_rays")
	rays.ImageColor3 = color
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.Position = UDim2.fromScale(0.5, 0.5)
	rays.Parent = gui
	local disc = Instance.new("Frame")
	disc.BackgroundColor3 = Color3.new(1, 1, 1)
	disc.AnchorPoint = Vector2.new(0.5, 0.5)
	disc.Position = UDim2.fromScale(0.5, 0.5)
	disc.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = disc
	local edge = Instance.new("UIStroke")
	edge.Color = color
	edge.Thickness = 3
	edge.Parent = disc
	local spin = rng:NextNumber(0, 360)
	tween(0.28, function(k)
		local out = 1 - (1 - k) ^ 3
		rays.Size = UDim2.fromScale(0.35 + 0.8 * out, 0.35 + 0.8 * out)
		rays.Rotation = spin + 25 * k
		rays.ImageTransparency = k ^ 1.5
		disc.Size = UDim2.fromScale(0.12 + 0.3 * out, 0.12 + 0.3 * out)
		disc.BackgroundTransparency = math.min(1, k * 1.6)
		edge.Transparency = k
	end, function()
		attachment:Destroy()
	end)
end

----------------------------------------------------------------------------------------------------
-- per-clap effects: sparks, flying debris and a light flash, scaled by grade and power

local sparkAttachment: Attachment
local sparkEmitter: ParticleEmitter
local flash: ColorCorrectionEffect
local flashAmount = 0
local liveChips = 0
local MAX_CHIPS = 60

local function buildClapFx()
	sparkAttachment = Instance.new("Attachment")
	sparkAttachment.Parent = workspace.Terrain
	sparkEmitter = Instance.new("ParticleEmitter")
	sparkEmitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkEmitter.LightEmission = 1
	sparkEmitter.Lifetime = NumberRange.new(0.25, 0.55)
	sparkEmitter.Speed = NumberRange.new(6, 16)
	sparkEmitter.SpreadAngle = Vector2.new(180, 180)
	sparkEmitter.Drag = 6
	sparkEmitter.Rate = 0
	sparkEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	sparkEmitter.Parent = sparkAttachment
	flash = Instance.new("ColorCorrectionEffect")
	flash.Name = "ClapFlash"
	flash.Parent = game:GetService("Lighting")
end

local function sparks(position: Vector3, count: number, color: Color3, size: number)
	if count <= 0 then
		return
	end
	sparkAttachment.WorldPosition = position
	sparkEmitter.Color = ColorSequence.new(color)
	sparkEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparkEmitter.Speed = NumberRange.new(size * 12, size * 30)
	sparkEmitter:Emit(count)
end

-- little pieces flung outwards: paper programmes in the hall, floor chips and rubble later
local CHIP_COLORS = {
	[1] = { Color3.fromRGB(245, 243, 238), Color3.fromRGB(230, 200, 205) },
	[2] = { Color3.fromRGB(216, 185, 140), Color3.fromRGB(40, 40, 44) },
}
local function chips(origin: Vector3, count: number, scale: number)
	local palette = CHIP_COLORS[stageId] or { Color3.fromRGB(150, 140, 130), Color3.fromRGB(110, 100, 92) }
	for _ = 1, count do
		if liveChips >= MAX_CHIPS then
			return
		end
		liveChips += 1
		local chip = Instance.new("Part")
		chip.Size = Vector3.new(rng:NextNumber(0.3, 0.8), 0.12, rng:NextNumber(0.3, 0.8)) * scale
		chip.Color = palette[rng:NextInteger(1, #palette)]
		chip.Material = Enum.Material.SmoothPlastic
		chip.CanCollide = false
		chip.CanQuery = false
		chip.CanTouch = false
		chip.CastShadow = false
		local angle = rng:NextNumber(0, math.pi * 2)
		local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
		chip.CFrame = CFrame.new(origin + outward * scale) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0)
		chip.AssemblyLinearVelocity = (outward * rng:NextNumber(14, 30) + Vector3.new(0, rng:NextNumber(14, 26), 0)) * math.sqrt(scale)
		chip.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-12, 12), rng:NextNumber(-12, 12), rng:NextNumber(-12, 12))
		chip.Parent = effectsFolder
		task.delay(1.4, function()
			chip:Destroy()
			liveChips -= 1
		end)
	end
end

local function updateFlash(dt: number)
	flashAmount = math.max(0, flashAmount - dt * 5)
	flash.Brightness = flashAmount * 0.12
	flash.Contrast = flashAmount * 0.08
end

----------------------------------------------------------------------------------------------------
-- Cosmetics, drawn locally on every character. Rebirths give wings (1+), a halo (2+) and a clap
-- trail (3+); event shop items can swap in their own wings/trail looks for anyone.

local cosmetics: { [Model]: { model: Model, key: string } } = {}

type WingStyle = { outer: Color3, inner: Color3, material: Enum.Material, sparkle: Color3 }
local WING_STYLES: { [string]: WingStyle } = {
	angel = { outer = Color3.fromRGB(245, 248, 255), inner = Color3.fromRGB(205, 225, 255), material = Enum.Material.Neon, sparkle = Color3.fromRGB(220, 235, 255) },
	bat = { outer = Color3.fromRGB(45, 28, 60), inner = Color3.fromRGB(110, 50, 140), material = Enum.Material.SmoothPlastic, sparkle = Color3.fromRGB(190, 120, 255) },
	snow = { outer = Color3.fromRGB(235, 248, 255), inner = Color3.fromRGB(160, 210, 255), material = Enum.Material.Neon, sparkle = Color3.new(1, 1, 1) },
}
local TRAIL_STYLES: { [string]: { a: Color3, b: Color3, transparency: number } } = {
	gold = { a = GOLD, b = Color3.fromRGB(150, 205, 255), transparency = 0.2 },
	ghost = { a = Color3.fromRGB(240, 240, 255), b = Color3.fromRGB(160, 120, 220), transparency = 0.4 },
	star = { a = Color3.fromRGB(255, 225, 120), b = Color3.new(1, 1, 1), transparency = 0.15 },
}
type Look = { wings: string?, halo: boolean, trail: string? }

local function weldTo(part: BasePart, anchor: BasePart, offset: CFrame)
	part.CFrame = anchor.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchor
	weld.Part1 = part
	weld.Parent = part
end

local function cosmeticPart(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = false
	p.Massless = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

local function buildCosmetics(character: Model, look: Look): Model?
	local torso = (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) :: BasePart?
	local head = character:FindFirstChild("Head") :: BasePart?
	if not (torso and head) then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "ClapCosmetics"
	local wingStyle = look.wings and WING_STYLES[look.wings]
	if wingStyle then
		-- wings: two layered feathers per side
		for _, side in { -1, 1 } do
			for layer = 0, 1 do
				local wing = cosmeticPart({
					Name = "Wing",
					Size = Vector3.new(0.15, 3.2 - layer * 0.8, 2.4 - layer * 0.6),
					Color = if layer == 0 then wingStyle.outer else wingStyle.inner,
					Material = wingStyle.material,
					Transparency = 0.15 + layer * 0.15,
				})
				local wedge = Instance.new("SpecialMesh")
				wedge.MeshType = Enum.MeshType.Wedge
				wedge.Parent = wing
				local offset = CFrame.new(side * (0.9 + layer * 0.5), 0.5 - layer * 0.3, 0.75)
					* CFrame.Angles(0, math.rad(side * (35 + layer * 10)), math.rad(side * -25))
				weldTo(wing, torso, offset)
				wing.Parent = model
			end
		end
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkle.Color = ColorSequence.new(wingStyle.sparkle)
		sparkle.Size = NumberSequence.new(0.25)
		sparkle.Lifetime = NumberRange.new(0.6, 1.2)
		sparkle.Rate = 6
		sparkle.Speed = NumberRange.new(0.5, 1.5)
		sparkle.LightEmission = 1
		sparkle.Parent = model:FindFirstChild("Wing")
	end
	if look.halo then
		local halo = cosmeticPart({
			Name = "Halo",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.12, 1.9, 1.9),
			Color = GOLD,
			Material = Enum.Material.Neon,
			Transparency = 0.2,
		})
		weldTo(halo, head, CFrame.new(0, 1.15, 0) * CFrame.Angles(0, 0, math.rad(90)))
		local light = Instance.new("PointLight")
		light.Color = GOLD
		light.Range = 8
		light.Brightness = 1.5
		light.Parent = halo
		halo.Parent = model
	end
	local trailStyle = look.trail and TRAIL_STYLES[look.trail]
	if trailStyle then
		local a0 = Instance.new("Attachment")
		a0.Name = "ClapTrail0"
		a0.Position = Vector3.new(0, 1, 0.4)
		a0.Parent = torso
		local a1 = Instance.new("Attachment")
		a1.Name = "ClapTrail1"
		a1.Position = Vector3.new(0, -1, 0.4)
		a1.Parent = torso
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Lifetime = 0.7
		trail.LightEmission = 1
		trail.Color = ColorSequence.new(trailStyle.a, trailStyle.b)
		trail.Transparency = NumberSequence.new(trailStyle.transparency, 1)
		trail.Parent = model
	end
	model.Parent = effectsFolder
	return model
end

local function clearCosmetics(character: Model)
	local entry = cosmetics[character]
	if entry then
		entry.model:Destroy()
		for _, d in character:GetDescendants() do
			if d:IsA("Attachment") and (d.Name == "ClapTrail0" or d.Name == "ClapTrail1") then
				d:Destroy()
			end
		end
		cosmetics[character] = nil
	end
end

local function updateCosmetics()
	for character in cosmetics do
		if not character.Parent then
			cosmetics[character].model:Destroy()
			cosmetics[character] = nil
		end
	end
	for _, other in Players:GetPlayers() do
		local character = other.Character
		if not character then
			continue
		end
		local level = (other:GetAttribute("Rebirths") :: number?) or 0
		local show = other:GetAttribute("ShowCosmetics") ~= false
		-- my own body is hidden in the first-person hall
		if other == player and stageId == 1 and not walking then
			show = false
		end
		-- equipped event items win over the Rebirth defaults
		local look: Look = {
			wings = (other:GetAttribute("Equipped_wings") :: string?) or (if level >= 1 then "angel" else nil),
			halo = level >= 2,
			trail = (other:GetAttribute("Equipped_trail") :: string?) or (if level >= 3 then "gold" else nil),
		}
		local key = if show then string.format("%s|%s|%s", tostring(look.wings), tostring(look.halo), tostring(look.trail)) else ""
		local entry = cosmetics[character]
		if entry and entry.key ~= key then
			clearCosmetics(character)
			entry = nil
		end
		if not entry and show and (look.wings or look.halo or look.trail) then
			local model = buildCosmetics(character, look)
			if model then
				cosmetics[character] = { model = model, key = key }
			end
		end
	end
end

-- after a Curtain Call: bouquets and petals rain down around me
function Environment.bouquetShower()
	local root = myRoot()
	if not root then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = root.Position + Vector3.new(0, 18, 0)
	attachment.Parent = workspace.Terrain
	local petals = Instance.new("ParticleEmitter")
	petals.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	petals.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 182, 203)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 240, 245)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 220, 120)),
	})
	petals.Size = NumberSequence.new(0.7)
	petals.Lifetime = NumberRange.new(3, 5)
	petals.Speed = NumberRange.new(4, 10)
	petals.SpreadAngle = Vector2.new(180, 180)
	petals.Acceleration = Vector3.new(0, -6, 0)
	petals.Drag = 1
	petals.Rate = 0
	petals.Parent = attachment
	petals:Emit(200)
	Debris:AddItem(attachment, 6)
end

----------------------------------------------------------------------------------------------------
-- leaderboard ranks: titles, auras and crowns (world ranks are grander than server ranks)

type RankStyle = { title: string, color: Color3, aura: number, crown: Color3? }

local CROWN_GOLD = Color3.fromRGB(255, 205, 80)
local CROWN_SILVER = Color3.fromRGB(215, 220, 230)
local CROWN_BRONZE = Color3.fromRGB(215, 140, 85)

local function rankStyle(target: Player): RankStyle?
	local world = target:GetAttribute("GlobalRank") :: number?
	local server = target:GetAttribute("ServerRank") :: number?
	if world then
		if world == 1 then
			return { title = "👑 #1 IN THE WORLD", color = CROWN_GOLD, aura = 3, crown = CROWN_GOLD }
		elseif world == 2 then
			return { title = "👑 #2 IN THE WORLD", color = CROWN_SILVER, aura = 3, crown = CROWN_SILVER }
		elseif world == 3 then
			return { title = "👑 #3 IN THE WORLD", color = CROWN_BRONZE, aura = 3, crown = CROWN_BRONZE }
		elseif world <= 5 then
			return { title = "🌟 WORLD TOP 5 · #" .. world, color = Color3.fromRGB(200, 140, 255), aura = 2 }
		elseif world <= 10 then
			return { title = "✨ WORLD TOP 10 · #" .. world, color = Color3.fromRGB(120, 190, 255), aura = 2 }
		elseif world <= 25 then
			return { title = "WORLD TOP 25 · #" .. world, color = Color3.fromRGB(150, 230, 200), aura = 1 }
		elseif world <= 50 then
			return { title = "WORLD TOP 50 · #" .. world, color = Color3.fromRGB(200, 220, 235), aura = 0 }
		end
		return { title = "WORLD TOP 100 · #" .. world, color = Color3.fromRGB(190, 195, 205), aura = 0 }
	end
	if server and server <= 5 and #Players:GetPlayers() > 1 then
		local medals = { "🥇", "🥈", "🥉" }
		return { title = (medals[server] or "") .. " SERVER #" .. server, color = Color3.fromRGB(235, 235, 240), aura = if server == 1 then 1 else 0 }
	end
	return nil
end

local rankFx: { [Model]: { model: Model, key: string } } = {}

local function buildRankFx(character: Model, style: RankStyle): Model?
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local head = character:FindFirstChild("Head") :: BasePart?
	if not (root and head) then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "RankFx"
	if style.aura > 0 then
		local anchor = cosmeticPart({ Name = "AuraAnchor", Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1 })
		weldTo(anchor, root, CFrame.new(0, -2.6, 0))
		anchor.Parent = model
		local aura = Instance.new("ParticleEmitter")
		aura.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		aura.LightEmission = 1
		aura.Color = if style.crown == CROWN_GOLD
			then ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)),
				ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 220, 90)),
				ColorSequenceKeypoint.new(0.66, Color3.fromRGB(90, 220, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 120, 255)),
			})
			else ColorSequence.new(style.color)
		aura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5 + style.aura * 0.15), NumberSequenceKeypoint.new(1, 0) })
		aura.Lifetime = NumberRange.new(0.8, 1.6)
		aura.Rate = 8 + style.aura * 10
		aura.Speed = NumberRange.new(2, 4 + style.aura)
		aura.SpreadAngle = Vector2.new(25, 25)
		aura.EmissionDirection = Enum.NormalId.Top
		aura.Parent = anchor
		if style.aura >= 2 then
			local glow = Instance.new("PointLight")
			glow.Color = style.color
			glow.Range = 10 + style.aura * 4
			glow.Brightness = 1 + style.aura * 0.5
			glow.Parent = anchor
		end
	end
	if style.crown then
		-- a little crown: a band and four points
		local band = cosmeticPart({ Name = "Crown", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.45, 1.25, 1.25), Color = style.crown, Material = Enum.Material.Neon })
		weldTo(band, head, CFrame.new(0, 0.95, 0) * CFrame.Angles(0, 0, math.rad(90)))
		band.Parent = model
		for i = 0, 3 do
			local a = i * math.pi / 2
			local spike = cosmeticPart({ Name = "CrownPoint", Shape = Enum.PartType.Ball, Size = Vector3.new(0.32, 0.32, 0.32), Color = style.crown, Material = Enum.Material.Neon })
			weldTo(spike, head, CFrame.new(math.cos(a) * 0.5, 1.35, math.sin(a) * 0.5))
			spike.Parent = model
		end
	end
	model.Parent = effectsFolder
	return model
end

local function updateRankFx()
	for character, entry in rankFx do
		if not character.Parent then
			entry.model:Destroy()
			rankFx[character] = nil
		end
	end
	for _, other in Players:GetPlayers() do
		local character = other.Character
		if not character then
			continue
		end
		local style = rankStyle(other)
		local hidden = other:GetAttribute("ShowCosmetics") == false or (other == player and stageId == 1 and not walking)
		local key = if style and not hidden then style.title else ""
		local entry = rankFx[character]
		if entry and entry.key ~= key then
			entry.model:Destroy()
			rankFx[character] = nil
			entry = nil
		end
		if not entry and style and key ~= "" then
			local model = buildRankFx(character, style)
			if model then
				rankFx[character] = { model = model, key = key }
			end
		end
	end
end

----------------------------------------------------------------------------------------------------
-- player markers: a dot and name above everyone once the world is too big to see people,
-- and a gold "Stage N Clapper" title over stronger players visiting an earlier stage

local function updateMarkers()
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then
			continue
		end
		local theirStage = other:GetAttribute("Stage") :: number?
		local best = (other:GetAttribute("BestStage") :: number?) or theirStage or 1
		local sameStage = theirStage == stageId
		local showsOff = other:GetAttribute("ShowCosmetics") ~= false
		local isVisitor = theirStage ~= nil and best > theirStage and showsOff
		local rank = if showsOff then rankStyle(other) else nil
		local eventTitle = if showsOff then other:GetAttribute("Equipped_title") :: string? else nil
		local showDot = sameStage and stageId >= 4
		local showTitle = sameStage and (isVisitor or rank ~= nil or eventTitle ~= nil)
		local marker = root:FindFirstChild("ClapMarker") :: BillboardGui?
		if not (showDot or showTitle) then
			if marker then
				marker.Enabled = false
			end
			continue
		end
		if not marker then
			local gui = Instance.new("BillboardGui")
			gui.Name = "ClapMarker"
			gui.Size = UDim2.fromOffset(200, 54)
			gui.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
			gui.AlwaysOnTop = true
			gui.LightInfluence = 0
			local dot = Instance.new("Frame")
			dot.Name = "Dot"
			dot.AnchorPoint = Vector2.new(0.5, 1)
			dot.Position = UDim2.new(0.5, 0, 1, 0)
			dot.Size = UDim2.fromOffset(12, 12)
			dot.BackgroundColor3 = if other == player then GOLD else userColor(other.UserId)
			dot.Parent = gui
			local round = Instance.new("UICorner")
			round.CornerRadius = UDim.new(1, 0)
			round.Parent = dot
			local label = Instance.new("TextLabel")
			label.Name = "Label"
			label.BackgroundTransparency = 1
			label.Size = UDim2.new(1, 0, 0, 36)
			label.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
			label.TextSize = 14
			label.TextColor3 = Color3.new(1, 1, 1)
			label.TextStrokeTransparency = 0.5
			label.RichText = true
			label.TextYAlignment = Enum.TextYAlignment.Bottom
			label.Parent = gui
			gui.Parent = root
			marker = gui
		end
		local gui = marker :: BillboardGui
		gui.Enabled = true
		;(gui:FindFirstChild("Dot") :: Frame).Visible = showDot
		local label = gui:FindFirstChild("Label") :: TextLabel
		local name = if other == player then "You" else other.DisplayName
		local lines = {}
		if rank then
			table.insert(lines, string.format('<font color="#%s">%s</font>', rank.color:ToHex(), rank.title))
		end
		if isVisitor then
			table.insert(lines, string.format('<font color="#E8B866">⭐ STAGE %d CLAPPER</font>', best))
		end
		if eventTitle then
			table.insert(lines, string.format('<font color="#FFB45A">%s</font>', eventTitle))
		end
		table.insert(lines, name)
		label.Text = table.concat(lines, "\n")
		gui.Size = UDim2.fromOffset(220, 18 * #lines + 18)
		label.Size = UDim2.new(1, 0, 1, -14)
	end
end

----------------------------------------------------------------------------------------------------
-- public API

function Environment.init()
	effectsFolder = Instance.new("Folder")
	effectsFolder.Name = "LocalEffects"
	effectsFolder.Parent = workspace

	local dustPart = localPart({ Name = "DustEmitter", Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2) })
	dustAttachment = Instance.new("Attachment")
	;(dustAttachment :: Attachment).Parent = workspace.Terrain
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(205, 195, 180))
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.8, 1.6)
	emitter.SpreadAngle = Vector2.new(180, 25)
	emitter.Drag = 3
	emitter.Rate = 0
	emitter.RotSpeed = NumberRange.new(-40, 40)
	emitter.Parent = dustAttachment
	dustEmitter = emitter
	dustPart:Destroy()

	buildClapFx()
	RunService.PreSimulation:Connect(updateArmClaps)
	local markerTimer = 0
	RunService.RenderStepped:Connect(function(dt)
		updateItems(dt)
		if stageId == 1 then
			updateNpcs(dt)
		end
		updateFlash(dt)
		markerTimer += dt
		if markerTimer > 0.5 then
			markerTimer = 0
			updateMarkers()
			updateCosmetics()
			updateRankFx()
		end
	end)
end

function Environment.setStage(id: number)
	restoreItems()
	clearNpcs()
	stageId = id
	local model = stageModel(id)
	if not model then
		table.clear(items)
		return
	end
	collectItems(model)
	if id == 1 then
		spawnNpcs(model)
		assignHired()
	end
end

function Environment.setWalking(on: boolean)
	walking = on
end

function Environment.setProgress(t: number)
	progress = t
end

function Environment.setHired(count: number)
	if count ~= hiredCount then
		hiredCount = count
		assignHired()
	end
end

----------------------------------------------------------------------------------------------------
-- the clap effect ladder
--
-- Every clap (mine, or another player's from their pulse) has a force F (Formulas.clapForce x the
-- beat grade x their "clap power shown" setting): 0 on a fresh stage, 1 once it's maxed, +1 per
-- stage a visitor is ahead. Effects switch on as F rises, and their size and reach grow with it:
--
--   F 0      the hands pop, nothing else: the very first claps barely register
--   F 0.05   a dust puff at your feet
--   F 0.12   a shockwave ring; light props nearby start to jitter and hop
--   F 0.25   sparks; chairs scoot; flying chips
--   F 0.3    nearby windows shatter (and come back a few seconds later)
--   F 0.35   birds burst out of the trees (Town, Region)
--   F 0.45   roofs lift off, trees bend, lamps swing hard
--   F 0.7    the floor cracks under you; the screen flashes
--   F 1      (a maxed stage, or any visitor) a second, wider wave; debris erupts from the ground
--   F 1.1    whole buildings jump
--   F 2      a shockwave dome; other players get knocked out of their seats
--   F 4      a pillar of light
--
-- Items fly with gravity, bounce, and heal back after a few seconds. Everyone in the stage applies
-- everyone's claps the same way, so the chaos is shared.

local GRADE_FORCE = { Perfect = 1, Great = 0.85, Good = 0.7, Miss = 0.2 }
local ERUPT_COLORS = {
	[1] = { Color3.fromRGB(170, 120, 80), Color3.fromRGB(120, 85, 55) },
	[2] = { Color3.fromRGB(216, 185, 140), Color3.fromRGB(150, 120, 90) },
	[3] = { Color3.fromRGB(120, 160, 90), Color3.fromRGB(140, 110, 80), Color3.fromRGB(150, 150, 150) },
	[4] = { Color3.fromRGB(150, 150, 155), Color3.fromRGB(110, 105, 100) },
	[5] = { Color3.fromRGB(140, 120, 100), Color3.fromRGB(100, 90, 80) },
	[6] = { Color3.fromRGB(210, 190, 150), Color3.fromRGB(90, 130, 80) },
	[7] = { Color3.fromRGB(110, 140, 90), Color3.fromRGB(80, 70, 60) },
	[8] = { Color3.fromRGB(255, 120, 40), Color3.fromRGB(60, 30, 20) },
	[9] = { Color3.fromRGB(150, 140, 160), Color3.fromRGB(255, 200, 120) },
}

local standUp: (() -> ())? = nil
local knockAt = 0
local pendingKnock: { dir: Vector3, power: number, at: number }? = nil

-- a starburst of cracks in the ground that fades away
local function groundCrack(ground: Vector3, up: Vector3, size: number)
	local side = if math.abs(up.Y) > 0.9 then Vector3.xAxis else Vector3.yAxis
	local basis = CFrame.fromMatrix(ground + up * 0.05, side:Cross(up).Unit, up)
	local parts: { BasePart } = {}
	local center = localPart({ Name = "Crack", Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(35, 28, 24), Transparency = 0.35, Size = Vector3.new(0.1, size * 0.5, size * 0.5), CFrame = basis * CFrame.Angles(0, 0, math.rad(90)) })
	table.insert(parts, center)
	for _ = 1, rng:NextInteger(6, 9) do
		local angle = rng:NextNumber(0, math.pi * 2)
		local length = size * rng:NextNumber(0.4, 1)
		table.insert(parts, localPart({
			Name = "Crack",
			Color = Color3.fromRGB(35, 28, 24),
			Size = Vector3.new(math.max(0.12, size * 0.02), 0.1, length),
			CFrame = basis * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -length / 2),
		}))
	end
	task.delay(2.5, function()
		tween(1, function(k)
			for _, p in parts do
				p.Transparency = math.max(p.Transparency, k)
			end
		end, function()
			for _, p in parts do
				p:Destroy()
			end
		end)
	end)
end

-- chunks of ground thrown up from the clap, falling back under "gravity" towards the local ground
local liveEruptions = 0
local function erupt(ground: Vector3, up: Vector3, count: number, size: number, speed: number)
	if liveEruptions > 6 then
		return
	end
	liveEruptions += 1
	local palette = ERUPT_COLORS[stageId] or ERUPT_COLORS[4]
	local side = if math.abs(up.Y) > 0.9 then Vector3.xAxis else Vector3.yAxis
	local right = side:Cross(up).Unit
	local forward = up:Cross(right).Unit
	local chunks: { BasePart } = {}
	local velocity: { Vector3 } = {}
	local spin: { Vector3 } = {}
	for i = 1, count do
		local s = size * rng:NextNumber(0.5, 1.2)
		chunks[i] = localPart({ Name = "Debris", Color = palette[rng:NextInteger(1, #palette)], Size = Vector3.new(s, s * rng:NextNumber(0.5, 1), s), Material = Enum.Material.Slate })
		local angle = rng:NextNumber(0, math.pi * 2)
		local out = (right * math.cos(angle) + forward * math.sin(angle)) * speed * rng:NextNumber(0.3, 1)
		velocity[i] = out + up * speed * rng:NextNumber(0.8, 1.6)
		spin[i] = Vector3.new(rng:NextNumber(-6, 6), rng:NextNumber(-6, 6), rng:NextNumber(-6, 6))
	end
	local gravity = speed * 2.2
	local cframes: { CFrame } = table.create(count)
	local duration = 1.5
	tween(duration, function(k)
		local t = k * duration
		for i, chunk in chunks do
			local p = ground + velocity[i] * t - up * (0.5 * gravity * t * t)
			-- stop at the ground
			local height = (p - ground):Dot(up)
			if height < 0 then
				p -= up * height
			end
			cframes[i] = CFrame.new(p) * CFrame.Angles(spin[i].X * t, spin[i].Y * t, spin[i].Z * t)
			chunk.Transparency = math.max(0, (k - 0.7) / 0.3)
		end
		workspace:BulkMoveTo(chunks, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end, function()
		for _, chunk in chunks do
			chunk:Destroy()
		end
		liveEruptions -= 1
	end)
end

-- an expanding see-through dome
local function dome(origin: Vector3, radius: number, color: Color3)
	local ball = localPart({ Name = "Dome", Shape = Enum.PartType.Ball, Material = Enum.Material.ForceField, Color = color, Transparency = 0, Size = Vector3.one, CFrame = CFrame.new(origin) })
	tween(0.7, function(k)
		local eased = 1 - (1 - k) ^ 3
		local d = 1 + radius * 2 * eased
		ball.Size = Vector3.new(d, d, d)
		ball.Transparency = k
	end, function()
		ball:Destroy()
	end)
end

-- a beam of light shooting up from the clapper
local function pillar(ground: Vector3, up: Vector3, height: number, width: number)
	local beam = localPart({ Name = "Pillar", Material = Enum.Material.Neon, Color = GOLD, Transparency = 0.2, Size = Vector3.new(width, 1, width) })
	local side = if math.abs(up.Y) > 0.9 then Vector3.xAxis else Vector3.yAxis
	local basis = CFrame.fromMatrix(ground, side:Cross(up).Unit, up)
	tween(0.9, function(k)
		local h = height * (1 - (1 - k) ^ 2)
		beam.Size = Vector3.new(width * (1 - k * 0.6), h, width * (1 - k * 0.6))
		beam.CFrame = basis * CFrame.new(0, h / 2, 0)
		beam.Transparency = 0.2 + 0.8 * k
	end, function()
		beam:Destroy()
	end)
end

-- a flock of birds bursting up out of the trees and scattering (outdoor ground stages)
local lastFlock = 0
local function flock(center: Vector3, spread: number, size: number)
	local now = os.clock()
	if now - lastFlock < 1.5 then
		return
	end
	lastFlock = now
	local birds: { BasePart } = {}
	local starts: { Vector3 } = {}
	local velocity: { Vector3 } = {}
	for i = 1, rng:NextInteger(8, 14) do
		local angle = rng:NextNumber(0, math.pi * 2)
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		starts[i] = center + out * spread * rng:NextNumber(0.3, 1) + Vector3.new(0, size * 3, 0)
		velocity[i] = (out * rng:NextNumber(6, 12) + Vector3.new(0, rng:NextNumber(5, 9), 0)) * size
		birds[i] = localPart({ Name = "Bird", Color = Color3.fromRGB(40, 38, 45), Size = Vector3.new(1.4, 0.15, 0.5) * size })
	end
	local cframes: { CFrame } = table.create(#birds)
	local duration = 3
	tween(duration, function(k)
		local t = k * duration
		for i, bird in birds do
			local v = velocity[i]
			local flap = math.abs(math.sin(t * 14 + i))
			bird.Size = Vector3.new((0.6 + 0.8 * flap) * size, 0.15 * size, 0.5 * size)
			cframes[i] = CFrame.lookAt(starts[i] + v * t, starts[i] + v * (t + 0.1))
			bird.Transparency = math.max(0, (k - 0.75) / 0.25)
		end
		workspace:BulkMoveTo(birds, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end, function()
		for _, bird in birds do
			bird:Destroy()
		end
	end)
end

-- every clap's shared part: items, classmates and the visual ladder. hands: where the pop goes
local function impact(root: BasePart, hands: Vector3?, force: number, color: Color3, mine: boolean)
	local now = os.clock()
	local ground, up = groundUnder(root)
	local scale = RING_SCALE[stageId] or 6
	local f = math.min(force, 9)
	local radius = reach(f)

	-- the world reacts
	local broke = shoveItems(root.Position, f, now)
	if broke > 0 then
		Audio.glass()
	end
	if f >= 0.12 then
		rattleStrength = math.max(if rattleTimer > 0 then rattleStrength else 0, 0.3 + f)
		rattleTimer = math.max(rattleTimer, 0.12 + 0.06 * math.min(f, 3))
	end
	for _, npc in npcs do
		if not npc.hired then
			local d = (npc.seat.Position - root.Position).Magnitude
			if d < radius then
				-- even quiet claps make heads twitch; loud ones make people jump
				npc.flinch = math.min(1, npc.flinch + 0.15 + f * (1 - d / radius))
			end
		end
	end

	-- the visual ladder
	if hands then
		clapPop(hands, color, root.Size.Y * (1.3 + 0.5 * math.min(f, 4)))
	end
	if f >= 0.05 then
		dust(ground, math.floor(2 + 8 * math.min(f, 3)), (1 + math.min(f, 1.5)) * scale * 0.4)
	end
	if f >= 0.12 then
		Environment.ring(ground, radius * 0.9, color, 0.45 + 0.1 * math.min(f, 3), 0.6, up)
	end
	if f >= 0.25 then
		sparks(hands or root.Position, math.floor(6 + 18 * math.min(f, 3)), color, 0.3 * math.sqrt(scale) * (1 + 0.3 * math.min(f, 3)))
		if stageId <= 3 then
			chips(ground + up * 0.5, math.floor(2 + 6 * math.min(f, 4)), (if stageId == 3 then 2 else 1) * (1 + 0.3 * math.min(f, 3)))
		end
	end
	if f >= 0.35 and (stageId == 3 or stageId == 5) then
		flock(ground, radius * 0.5, scale * 0.4)
	end
	if f >= 0.7 then
		groundCrack(ground, up, scale * (2.5 + 2 * math.min(f, 2)))
		if mine then
			flashAmount = math.min(1.5, flashAmount + 0.3 + 0.2 * math.min(f, 3))
		end
	end
	if f >= 1 then
		Environment.ring(ground, radius * 1.4, GOLD, 0.8, 0.5, up)
		erupt(ground, up, math.floor(4 + 4 * math.min(f, 5)), scale * (0.6 + 0.25 * math.min(f, 4)), scale * (14 + 6 * math.min(f, 4)))
		dust(ground, math.floor(10 + 6 * math.min(f, 5)), (1.5 + 0.5 * math.min(f, 2)) * scale * 0.6)
	end
	if f >= 2 then
		dome(root.Position, radius * 0.5, color)
		local cam = workspace.CurrentCamera
		if cam and (cam.CFrame.Position - root.Position).Magnitude < radius * 2.5 then
			CameraRig.bigShake(0.25 * math.min(f, 5))
		end
	end
	if f >= 4 then
		pillar(ground, up, scale * 60 * math.min(f, 8) / 4, scale * 3)
	end
end

-- fling my own character (it's mine, so everyone sees it)
local function launchMe(dir: Vector3, power: number)
	local character = player.Character
	local root = myRoot()
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (root and humanoid) then
		return
	end
	local p = math.min(power, 5)
	root.AssemblyLinearVelocity = dir * (25 + 18 * p) + Vector3.new(0, 18 + 10 * p, 0)
	humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
end

-- someone else's clap reached me with this much force
local function knocked(from: Vector3, power: number)
	local root = myRoot()
	local now = os.clock()
	if not root or power < 0.6 then
		return
	end
	if power < 1 or now - knockAt < 4 then
		CameraRig.bigShake(0.2 * power)
		return
	end
	local away = root.Position - from
	away = Vector3.new(away.X, 0, away.Z)
	local dir = if away.Magnitude > 0.1 then away.Unit else Vector3.xAxis
	if walking then
		knockAt = now
		launchMe(dir, power)
	elseif power >= 1.5 and standUp and stageId <= Config.Tuning.MaxWalkStage then
		-- knocked clean out of my seat
		knockAt = now
		pendingKnock = { dir = dir, power = power, at = now }
		standUp()
	else
		CameraRig.bigShake(0.25 * power)
	end
end

-- my clap. force: Formulas.clapForce x my "clap power shown"; visiting: showing off in an earlier stage
function Environment.selfClap(force: number, grade: string, visiting: boolean)
	local root = myRoot()
	if not root then
		return
	end
	local camera = workspace.CurrentCamera
	local f = force * (GRADE_FORCE[grade] or 0.7)
	local color = if grade == "Perfect" then GOLD elseif visiting then Color3.fromRGB(255, 225, 160) elseif grade == "Miss" then Color3.fromRGB(190, 190, 200) else Color3.new(1, 1, 1)
	local firstPerson = stageId == 1 and not walking
	local hands: Vector3?
	if firstPerson and camera then
		-- first person: the pop and sparks go between my on-screen hands
		hands = (camera.CFrame * CFrame.new(0, -0.7, -2.4)).Position
	elseif player.Character then
		hands = handsPoint(player.Character)
		armClap(player.Character)
	end
	if firstPerson and hands then
		sparks(hands, if grade == "Miss" then 0 else math.floor(4 + 10 * math.min(f, 2)), color, 0.25)
		impact(root, nil, f, color, true)
	else
		impact(root, hands, f, color, true)
	end
end

-- other players' claps: the same ladder at their force (throttled per player); strong ones reach me
function Environment.otherClap(userId: number, theirStage: number, count: number, perfect: boolean, inSync: boolean, visitor: number, force: number)
	if userId == player.UserId or theirStage ~= stageId then
		return
	end
	local other = Players:GetPlayerByUserId(userId)
	local character = other and other.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (character and root) then
		return
	end
	armClap(character)
	local now = os.clock()
	if now - (lastPulseFx[userId] or 0) < 0.25 then
		return
	end
	lastPulseFx[userId] = now
	local f = force * (if perfect then 1 else 0.8)
	local color = if inSync or visitor > 0 then GOLD elseif perfect then Color3.new(1, 1, 1) else userColor(userId)
	impact(root, handsPoint(character), f, color, false)
	Audio.otherClap(character, theirStage - 1 + f)

	-- does it reach me?
	local mine = myRoot()
	if mine then
		local radius = reach(math.min(f, 9))
		local d = (mine.Position - root.Position).Magnitude
		if d < radius then
			knocked(root.Position, f * (1 - d / radius) ^ 1.5)
		end
	end
end

-- my tier-up: one big wave through the room and everyone flinches
function Environment.tierBurst()
	local root = myRoot()
	if root then
		local ground, up = groundUnder(root)
		Environment.ring(ground, (30 + progress * 40) * (RING_SCALE[stageId] or 6), GOLD, 0.9, 0.35, up)
		flashAmount = 1.5
	end
	rattleTimer = 0.5
	rattleStrength = 1 + progress * 2.5
	for _, item in items do
		if item.kind == "Swing" then
			item.kick = math.min(0.4, item.kick + 0.15)
		end
	end
	for _, npc in npcs do
		if not npc.hired then
			npc.flinch = 1
		end
	end
end

-- shared spectacle: Standing Ovation
function Environment.ovation()
	local root = myRoot()
	local center = if root then root.Position else Vector3.zero
	for i = 0, 2 do
		task.delay(i * 0.25, function()
			Environment.ring(center - Vector3.new(0, 2.5, 0), 120 + i * 60, GOLD, 1.6, 0.4)
		end)
	end
	-- confetti
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = center + Vector3.new(0, 25, 0)
	attachment.Parent = workspace.Terrain
	local confetti = Instance.new("ParticleEmitter")
	confetti.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	confetti.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, GOLD),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 120, 150)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 200, 255)),
	})
	confetti.Size = NumberSequence.new(0.6)
	confetti.Lifetime = NumberRange.new(2, 4)
	confetti.Speed = NumberRange.new(20, 45)
	confetti.SpreadAngle = Vector2.new(180, 180)
	confetti.Acceleration = Vector3.new(0, -25, 0)
	confetti.Drag = 1.5
	confetti.Rate = 0
	confetti.Parent = attachment
	confetti:Emit(250)
	Debris:AddItem(attachment, 5)
	for _, npc in npcs do
		npc.flinch = 1
	end
end

-- shared spectacle: players clapping on the same beat get linked and their waves merge
function Environment.inSync(userIds: { number })
	local positions = {}
	for _, id in userIds do
		local p = Players:GetPlayerByUserId(id)
		local character = p and p.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and (p :: Player):GetAttribute("Stage") == stageId then
			table.insert(positions, root.Position)
		end
	end
	if #positions < 2 then
		return
	end
	local center = Vector3.zero
	for _, pos in positions do
		center += pos
	end
	center /= #positions
	for i, a in positions do
		local b = positions[i % #positions + 1]
		local length = (b - a).Magnitude
		local beam = localPart({
			Name = "SyncLink",
			Material = Enum.Material.Neon,
			Color = GOLD,
			Transparency = 0.2,
			Size = Vector3.new(0.25, 0.25, length),
			CFrame = CFrame.lookAt(a, b) * CFrame.new(0, 0, -length / 2),
		})
		tween(0.6, function(k)
			beam.Transparency = 0.2 + 0.8 * k
		end, function()
			beam:Destroy()
		end)
	end
	Environment.ring(center - Vector3.new(0, 2.5, 0), (25 + 10 * #positions) * (RING_SCALE[stageId] or 6), GOLD, 0.8, 0.45)
end

-- hide my own body in first person
function Environment.setOwnCharacterHidden(hidden: boolean)
	local character = player.Character
	if not character then
		return
	end
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			(d :: any).LocalTransparencyModifier = if hidden then 1 else 0
		end
	end
end

-- how to get me up out of my seat (when a strong clap knocks me out of it)
function Environment.setStandUp(fn: () -> ())
	standUp = fn
end

-- the server stood me up: if a clap knocked me out of my seat, now I go flying
function Environment.walkingChanged(on: boolean)
	local knock = pendingKnock
	pendingKnock = nil
	if on and knock and os.clock() - knock.at < 2 then
		task.delay(0.15, function()
			launchMe(knock.dir, knock.power)
		end)
	end
end

return Environment
