--!strict
-- Local destruction, shared presence (docs/10-multiplayer-effects.md).
--
-- Everything here runs only on this client:
--   * persistent damage driven by YOUR stage progress (windows shatter, lamps swing, chairs scoot away)
--   * per-clap bursts (shockwave rings, dust, rattles, NPC flinches)
--   * NPC classmates in the ceremony hall (turn around, cover ears, hired ones clap on the beat)
--   * other players' claps as a lighter, throttled ambient layer
--   * shared spectacle moments (Standing Ovation, In Sync)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local Beat = require(script.Parent.Beat)
local Audio = require(script.Parent.Audio)

local Environment = {}

local player = Players.LocalPlayer
local rng = Random.new()

local stageId = 1
local progress = 0
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

-- other players' clap animation state (character -> last clap time)
local armClaps: { [Model]: number } = {}
local originalC0: { [Motor6D]: CFrame } = {}
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

-- expanding shockwave ring on the ground, built from segments so the middle stays clear
local RING_SEGMENTS = 18
function Environment.ring(origin: Vector3, radius: number, color: Color3, duration: number, startTransparency: number?)
	local t0 = startTransparency or 0.55
	local segments: { BasePart } = {}
	for i = 1, RING_SEGMENTS do
		segments[i] = localPart({ Name = "Shockwave", Material = Enum.Material.Neon, Color = color, Transparency = t0, Size = Vector3.new(0.4, 0.3, 0.4) })
	end
	local cframes: { CFrame } = table.create(RING_SEGMENTS)
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
			cframes[i] = CFrame.new(origin) * CFrame.Angles(0, angle, 0) * CFrame.new(r, 0, 0)
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

local function shards(part: BasePart)
	local count = 10
	for _ = 1, count do
		local shard = Instance.new("Part")
		shard.Size = Vector3.new(0.2, rng:NextNumber(0.6, 1.6), rng:NextNumber(0.6, 1.6))
		shard.Color = part.Color
		shard.Material = Enum.Material.Glass
		shard.Transparency = 0.3
		shard.CanCollide = true
		shard.CanQuery = false
		shard.CastShadow = false
		local local_ = Vector3.new(0, rng:NextNumber(-0.5, 0.5) * part.Size.Y, rng:NextNumber(-0.5, 0.5) * part.Size.Z)
		shard.CFrame = part.CFrame * CFrame.new(local_) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0)
		shard.Parent = effectsFolder
		local root = myRoot()
		local away = if root then (shard.Position - root.Position).Unit else Vector3.yAxis
		shard.AssemblyLinearVelocity = away * rng:NextNumber(10, 30) + Vector3.new(0, rng:NextNumber(5, 15), 0)
		Debris:AddItem(shard, 3)
	end
end

----------------------------------------------------------------------------------------------------
-- damage items

local function collectItems(model: Instance)
	table.clear(items)
	-- chairs are moved as a whole
	local chairs = model:FindFirstChild("Chairs")
	local chairParts: { [Instance]: boolean } = {}
	if chairs then
		for _, chair in chairs:GetChildren() do
			local parts = {}
			local base = {}
			for _, p in chair:GetDescendants() do
				if p:IsA("BasePart") then
					table.insert(parts, p)
					table.insert(base, p.CFrame)
					chairParts[p] = true
				end
			end
			local seat = chair:FindFirstChild("Seat") :: BasePart?
			local at = if seat then (seat:GetAttribute("DamageAt") :: number?) or 2 else 2
			local item: Item = {
				kind = "Topple",
				at = at,
				push = if seat then (seat:GetAttribute("Push") :: number?) or 2.5 else 0,
				parts = parts,
				base = base,
				pivot = (chair:GetAttribute("SeatCFrame") :: CFrame?) or (if #parts > 0 then parts[1].CFrame else CFrame.new()),
				phase = rng:NextNumber(0, 6.28),
				broken = false,
				kick = 0,
				offset = CFrame.new(),
				transparency = {},
			}
			chair:SetAttribute("ItemIndex", #items + 1)
			table.insert(items, item)
		end
	end
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and not chairParts[p] then
			local kind = p:GetAttribute("DamageKind") :: string?
			if kind then
				local pivot = p.CFrame
				if kind == "Swing" then
					pivot = p.CFrame * CFrame.new(0, 6.6, 0) -- top of the cord
				end
				local parts = { p }
				local base = { p.CFrame }
				if kind == "Swing" then
					-- swing the cord with the lamp
					local parent = p.Parent
					if parent then
						for _, sibling in parent:GetChildren() do
							if sibling:IsA("BasePart") and sibling.Name == "LightCord" and (sibling.Position - p.Position).Magnitude < 5 then
								table.insert(parts, sibling)
								table.insert(base, sibling.CFrame)
							end
						end
					end
				end
				table.insert(items, {
					kind = kind,
					at = (p:GetAttribute("DamageAt") :: number?) or 1,
					parts = parts,
					base = base,
					pivot = pivot,
					phase = rng:NextNumber(0, 6.28),
					broken = false,
					kick = 0,
					offset = CFrame.new(),
					push = 0,
					transparency = { p.Transparency },
				})
			end
		end
	end
end

local function restoreItems()
	for _, item in items do
		for i, p in item.parts do
			p.CFrame = item.base[i]
		end
		if item.kind == "Shatter" and item.broken then
			item.parts[1].Transparency = item.transparency[1]
		end
		item.broken = false
		item.offset = CFrame.new()
	end
end

local moveParts: { BasePart } = {}
local moveCFrames: { CFrame } = {}

local function updateItems(dt: number)
	local root = myRoot()
	local me = if root then root.Position else Vector3.zero
	local time = os.clock()
	rattleTimer = math.max(0, rattleTimer - dt)
	table.clear(moveParts)
	table.clear(moveCFrames)

	for _, item in items do
		local kind = item.kind
		if kind == "Shatter" then
			local shouldBreak = progress >= item.at
			if shouldBreak and not item.broken then
				item.broken = true
				item.parts[1].Transparency = 1
				shards(item.parts[1])
				Audio.glass()
			elseif not shouldBreak and item.broken then
				item.broken = false
				item.parts[1].Transparency = item.transparency[1]
			end
		elseif kind == "Swing" then
			item.kick = math.max(0, item.kick - dt * 0.6)
			local amp = math.max(0, progress - item.at) * 0.5 + item.kick
			if amp > 0.001 then
				local angle = math.sin(time * 2.4 + item.phase) * amp
				local rot = item.pivot * CFrame.Angles(angle, 0, angle * 0.4) * item.pivot:Inverse()
				for i, p in item.parts do
					table.insert(moveParts, p)
					table.insert(moveCFrames, rot * item.base[i])
				end
			end
		elseif kind == "Topple" then
			-- scoot (ceremony) or get blown across the room (gym) away from me
			local k = math.clamp((progress - item.at) * 4, 0, 1)
			local amount = k * item.push
			local away = item.pivot.Position - me
			away = Vector3.new(away.X, 0, away.Z)
			local dir = if away.Magnitude > 0.1 then away.Unit else Vector3.xAxis
			local jitter = rattleTimer * rattleStrength * 0.25
			local offsetPos = dir * amount + Vector3.new(rng:NextNumber(-1, 1) * jitter, 0, rng:NextNumber(-1, 1) * jitter)
			local yaw = math.sin(item.phase) * amount * 0.12
			-- big pushes knock the item over
			local roll = if item.push > 5 then k * math.rad(80) * math.sign(math.sin(item.phase * 3)) else 0
			item.offset = CFrame.new(offsetPos)
			if amount > 0 or jitter > 0 then
				local spin = CFrame.Angles(0, yaw, 0) * CFrame.fromAxisAngle(Vector3.new(-dir.Z, 0, dir.X), roll)
				for i, p in item.parts do
					local rel = item.pivot:ToObjectSpace(item.base[i])
					table.insert(moveParts, p)
					table.insert(moveCFrames, (item.pivot + offsetPos) * spin * rel)
				end
			end
		elseif kind == "Rattle" then
			if rattleTimer > 0 and progress >= item.at * 0.5 then
				local j = rattleTimer * rattleStrength * 0.12
				local p = item.parts[1]
				table.insert(moveParts, p)
				table.insert(moveCFrames, item.base[1] * CFrame.new(rng:NextNumber(-j, j), rng:NextNumber(-j, j) * 0.3, rng:NextNumber(-j, j)))
			elseif rattleTimer <= 0 and item.kick ~= -1 then
				item.kick = -1
				table.insert(moveParts, item.parts[1])
				table.insert(moveCFrames, item.base[1])
			end
			if rattleTimer > 0 then
				item.kick = 0
			end
		elseif kind == "Peel" then
			-- roofs lift off and spin away when the shockwave passes
			local amount = math.clamp((progress - item.at) * 8, 0, 1)
			if amount > 0 then
				local p = item.parts[1]
				local away = (item.pivot.Position - me)
				away = Vector3.new(away.X, 0, away.Z).Unit
				local lift = item.pivot + away * amount * 30 + Vector3.new(0, amount * 25, 0)
				table.insert(moveParts, p)
				table.insert(moveCFrames, lift * CFrame.Angles(amount * 2 + item.phase * 0.2, amount * 1.5, amount))
				p.Transparency = math.max(item.transparency[1], amount ^ 3)
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
			seat = npc.chair.pivot + npc.chair.offset.Position
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
-- character arm clapping (other players, and me on top-down stages)

local function shoulders(character: Model): (Motor6D?, Motor6D?)
	local r = character:FindFirstChild("RightShoulder", true) or character:FindFirstChild("Right Shoulder", true)
	local l = character:FindFirstChild("LeftShoulder", true) or character:FindFirstChild("Left Shoulder", true)
	return (if r and r:IsA("Motor6D") then r else nil), (if l and l:IsA("Motor6D") then l else nil)
end

local function poseCharacter(character: Model, closeness: number, active: number)
	local r, l = shoulders(character)
	for side, motor in { [1] = r, [-1] = l } do
		if motor then
			local orig = originalC0[motor]
			if not orig then
				orig = motor.C0
				originalC0[motor] = orig
			end
			if active <= 0 then
				motor.C0 = orig
			else
				local inward = math.rad(15 + 20 * closeness) * side
				motor.C0 = orig * CFrame.Angles(0, inward * active, 0) * CFrame.Angles(math.rad(85) * active, 0, 0)
			end
		end
	end
end

local function updateArmClaps()
	local now = os.clock()
	for character, clapAt in armClaps do
		if not character.Parent then
			armClaps[character] = nil
			continue
		end
		local since = now - clapAt
		local active = math.clamp(1 - (since - 0.6) * 3, 0, 1) -- arms stay up briefly between claps
		local closeness = math.max(0, 1 - since * 6)
		poseCharacter(character, closeness, active)
		if active <= 0 then
			armClaps[character] = nil
		end
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

	RunService.RenderStepped:Connect(function(dt)
		updateItems(dt)
		if stageId == 1 then
			updateNpcs(dt)
		end
		updateArmClaps()
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

function Environment.setProgress(t: number)
	progress = t
end

function Environment.setHired(count: number)
	if count ~= hiredCount then
		hiredCount = count
		assignHired()
	end
end

-- my clap: intensity is roughly 0..3 (stage - 1 + progress)
function Environment.selfClap(intensity: number, perfect: boolean)
	rattleTimer = 0.18
	rattleStrength = 0.4 + progress * 2.2
	for _, item in items do
		if item.kind == "Swing" then
			item.kick = math.min(0.35, item.kick + 0.02 + progress * 0.03)
		end
	end
	for _, npc in npcs do
		if not npc.hired and progress > 0.15 then
			npc.flinch = math.min(1, npc.flinch + progress * 0.8)
		end
	end

	local color = if perfect then GOLD else Color3.new(1, 1, 1)
	if stageId == 1 then
		-- first person: the HUD draws the ring at the hands; the floor ring appears once it gets loud
		if progress > 0.6 then
			local root = myRoot()
			if root then
				Environment.ring(root.Position - Vector3.new(0, 2.5, 0), 8 + progress * 25, Color3.fromRGB(235, 225, 210), 0.5, 0.75)
			end
		end
	else
		local root = myRoot()
		if root then
			local ground = root.Position - Vector3.new(0, 2.8, 0)
			local scale = if stageId == 2 then 1 else 6
			Environment.ring(ground, (6 + progress * 30) * scale, color, 0.45, 0.6)
			if math.random() < 0.5 then
				dust(ground, 6, (1.5 + progress * 2) * scale)
			end
		end
		if player.Character then
			armClaps[player.Character] = os.clock()
		end
	end
end

-- other players' claps: the ambient layer
function Environment.otherClap(userId: number, theirStage: number, count: number, perfect: boolean, inSync: boolean)
	if userId == player.UserId or theirStage ~= stageId then
		return
	end
	local other = Players:GetPlayerByUserId(userId)
	local character = other and other.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (character and root) then
		return
	end
	armClaps[character] = os.clock()
	local now = os.clock()
	if now - (lastPulseFx[userId] or 0) < 0.25 then
		return
	end
	lastPulseFx[userId] = now
	local intensity = theirStage - 1
	local color = if inSync then GOLD elseif perfect then Color3.new(1, 1, 1) else userColor(userId)
	local scale = if theirStage >= 3 then 6 else 1
	Environment.ring(root.Position - Vector3.new(0, 2.6, 0), (3 + count * 0.5) * scale, color, 0.4, 0.75)
	Audio.otherClap(character, intensity)
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
	local scale = if stageId >= 3 then 6 else 1
	Environment.ring(center - Vector3.new(0, 2.5, 0), (25 + 10 * #positions) * scale, GOLD, 0.8, 0.45)
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

return Environment
