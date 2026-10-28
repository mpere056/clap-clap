--!strict
-- The shared look for menus, in the chunky style of popular simulators: thick black outlines,
-- buttons with a 3D bottom edge, striped colour headers with a red X, rarity-coloured item cards,
-- and the button dock along the bottom of the screen. Only one menu (modal) is open at a time.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Icons = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Icons"))

local UIKit = {}

UIKit.FONT = Font.fromEnum(Enum.Font.FredokaOne)

UIKit.Colors = {
	green = Color3.fromRGB(95, 205, 65),
	blue = Color3.fromRGB(55, 155, 245),
	gold = Color3.fromRGB(255, 185, 55),
	orange = Color3.fromRGB(255, 135, 45),
	red = Color3.fromRGB(230, 55, 60),
	purple = Color3.fromRGB(150, 85, 230),
	pink = Color3.fromRGB(255, 105, 160),
	sky = Color3.fromRGB(120, 195, 255),
	teal = Color3.fromRGB(30, 175, 175),
	grey = Color3.fromRGB(105, 110, 125),
	panel = Color3.fromRGB(36, 38, 52),
	inset = Color3.fromRGB(24, 26, 36),
	outline = Color3.fromRGB(12, 12, 18),
	money = Color3.fromRGB(120, 245, 90),
}

-- card colours by stage, like item rarities (grey → green → blue → purple → …)
UIKit.StageColors = {
	Color3.fromRGB(150, 158, 172),
	Color3.fromRGB(80, 190, 80),
	Color3.fromRGB(55, 150, 240),
	Color3.fromRGB(150, 90, 230),
	Color3.fromRGB(250, 150, 45),
	Color3.fromRGB(230, 65, 75),
	Color3.fromRGB(35, 190, 190),
	Color3.fromRGB(255, 95, 35),
	Color3.fromRGB(105, 75, 225),
}

function UIKit.darken(c: Color3, k: number): Color3
	return c:Lerp(Color3.new(0, 0, 0), k)
end

function UIKit.lighten(c: Color3, k: number): Color3
	return c:Lerp(Color3.new(1, 1, 1), k)
end

function UIKit.create(className: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(className)
	for k, v in props do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end
local create = UIKit.create

function UIKit.corner(parent: Instance, radius: number?): UICorner
	return create("UICorner", { CornerRadius = if radius then UDim.new(0, radius) else UDim.new(1, 0), Parent = parent })
end

function UIKit.outline(parent: Instance, thickness: number?): UIStroke
	return create("UIStroke", {
		Color = UIKit.Colors.outline,
		Thickness = thickness or 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = parent,
	})
end

-- a top-lit sheen: brighter at the top, darker at the bottom
function UIKit.sheen(parent: Instance, amount: number?)
	local k = amount or 0.22
	create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(1 - k, 1 - k, 1 - k)),
		Parent = parent,
	})
end

-- cartoon text: white with a thick black outline
function UIKit.label(props: { [string]: any }, strokeThickness: number?): TextLabel
	local defaults: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = UIKit.FONT,
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 18,
		RichText = true,
	}
	for k, v in props do
		defaults[k] = v
	end
	local label = create("TextLabel", defaults)
	create("UIStroke", { Color = UIKit.Colors.outline, Thickness = strokeThickness or 2, LineJoinMode = Enum.LineJoinMode.Round, Parent = label })
	return label
end

-- one line of text that shrinks to fit instead of overflowing
function UIKit.fitText(label: TextLabel, maxSize: number)
	label.TextScaled = true
	create("UITextSizeConstraint", { MaxTextSize = maxSize, MinTextSize = 8, Parent = label })
end

-- one of the game's icons (see shared/Icons) as a transparent, aspect-fitted image
function UIKit.image(props: { [string]: any }): ImageLabel
	local defaults: { [string]: any } = {
		Name = "Icon",
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
		Image = "",
	}
	for k, v in props do
		defaults[k] = v
	end
	return create("ImageLabel", defaults)
end

-- slowly turning light rays behind an icon, like item slots in popular simulators
local spinning: { ImageLabel } = {}
local spinStarted = false

function UIKit.rays(parent: Instance, size: number, transparency: number?): ImageLabel
	local rays = UIKit.image({
		Name = "Rays",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		Image = Icons.get("ui_rays"),
		ImageTransparency = transparency or 0.35,
		ZIndex = 0,
		Parent = parent,
	})
	table.insert(spinning, rays)
	if not spinStarted then
		spinStarted = true
		game:GetService("RunService").RenderStepped:Connect(function()
			local angle = (os.clock() * 14) % 360
			for i = #spinning, 1, -1 do
				local r = spinning[i]
				if r.Parent then
					r.Rotation = angle
				else
					table.remove(spinning, i) -- cards that were rebuilt
				end
			end
		end)
	end
	return rays
end

-- an icon followed by text, centred as a pair (e.g. a cost: [hands] 1.2K)
function UIKit.costLine(parent: Instance, position: UDim2, size: UDim2, textSize: number): (ImageLabel, TextLabel)
	local row = create("Frame", { Name = "CostLine", Position = position, Size = size, BackgroundTransparency = 1, Parent = parent })
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = row,
	})
	local icon = UIKit.image({ LayoutOrder = 1, Size = UDim2.fromOffset(textSize + 6, textSize + 6), Parent = row })
	local label = UIKit.label({ LayoutOrder = 2, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, TextSize = textSize, Text = "", Parent = row })
	return icon, label
end

local function pressFeel(b: GuiButton, face: GuiObject, depth: number)
	local scale = create("UIScale", { Parent = b })
	local info = TweenInfo.new(0.08, Enum.EasingStyle.Quad)
	b.MouseEnter:Connect(function()
		TweenService:Create(scale, info, { Scale = 1.05 }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(scale, info, { Scale = 1 }):Play()
		face.Position = UDim2.new()
	end)
	b.MouseButton1Down:Connect(function()
		face.Position = UDim2.fromOffset(0, depth - 1)
	end)
	b.MouseButton1Up:Connect(function()
		face.Position = UDim2.new()
	end)
end

export type ButtonProps = {
	color: Color3,
	text: string,
	icon: string?, -- image id shown left of the text (or centred when there's no text)
	textSize: number?,
	size: UDim2,
	position: UDim2?,
	anchor: Vector2?,
	parent: Instance?,
	name: string?,
	layoutOrder: number?,
	depth: number?,
	radius: number?,
}

-- a chunky button: coloured face over a darker bottom edge, both outlined
function UIKit.button(props: ButtonProps): TextButton
	local depth = props.depth or 5
	local b = create("TextButton", {
		Name = props.name or "Button",
		Size = props.size,
		Position = props.position or UDim2.new(),
		AnchorPoint = props.anchor or Vector2.zero,
		LayoutOrder = props.layoutOrder or 0,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
	})
	local edge = create("Frame", {
		Name = "Edge",
		Size = UDim2.new(1, 0, 1, -depth),
		Position = UDim2.fromOffset(0, depth),
		BackgroundColor3 = UIKit.darken(props.color, 0.45),
		Parent = b,
	})
	UIKit.corner(edge, props.radius or 10)
	UIKit.outline(edge, 2.5)
	local face = create("Frame", {
		Name = "Face",
		Size = UDim2.new(1, 0, 1, -depth),
		BackgroundColor3 = props.color,
		Parent = b,
	})
	UIKit.corner(face, props.radius or 10)
	UIKit.outline(face, 2.5)
	UIKit.sheen(face)
	local label = UIKit.label({
		Name = "Label",
		Size = UDim2.new(1, -8, 1, 0),
		Position = UDim2.fromOffset(4, 0),
		TextSize = props.textSize or 20,
		Text = props.text,
		Parent = face,
	})
	if props.icon then
		if props.text == "" then
			UIKit.image({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.8, 0.8), SizeConstraint = Enum.SizeConstraint.RelativeYY, Image = props.icon, Parent = face })
		else
			-- icon on the left, text in the rest
			UIKit.image({ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 6, 0.5, 0), Size = UDim2.fromScale(0.8, 0.8), SizeConstraint = Enum.SizeConstraint.RelativeYY, Image = props.icon, Parent = face })
			label.AnchorPoint = Vector2.new(1, 0)
			label.Position = UDim2.new(1, -6, 0, 0)
			label.Size = UDim2.new(1, -16, 1, 0)
			label.TextXAlignment = Enum.TextXAlignment.Center
			-- leave room for the icon: it's as wide as 80% of the button's height
			local function fit()
				local iconWidth = face.AbsoluteSize.Y * 0.8 + 8
				label.Size = UDim2.new(1, -(iconWidth + 6), 1, 0)
			end
			face:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
			fit()
		end
	end
	pressFeel(b, face, depth)
	if props.parent then
		b.Parent = props.parent
	end
	return b
end

-- recolour / relabel / re-icon a UIKit button
function UIKit.setButton(b: Instance, color: Color3?, text: string?, icon: string?)
	local face = b:FindFirstChild("Face") :: Frame?
	local edge = b:FindFirstChild("Edge") :: Frame?
	if not (face and edge) then
		return
	end
	if color and face.BackgroundColor3 ~= color then
		face.BackgroundColor3 = color
		edge.BackgroundColor3 = UIKit.darken(color, 0.45)
	end
	local label = face:FindFirstChild("Label") :: TextLabel?
	if text and label and label.Text ~= text then
		label.Text = text
	end
	local image = face:FindFirstChild("Icon") :: ImageLabel?
	if icon and image and image.Image ~= icon then
		image.Image = icon
	end
end

-- a red dot with "!" in a button's top-right corner
function UIKit.badge(parent: Instance): Frame
	local dot = create("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = UIKit.Colors.red,
		ZIndex = 5,
		Visible = false,
		Parent = parent,
	})
	UIKit.corner(dot)
	UIKit.outline(dot, 2.5)
	UIKit.label({ Size = UDim2.fromScale(1, 1), TextSize = 18, Text = "!", ZIndex = 5, Parent = dot })
	return dot
end

-- a rarity-coloured card with a black outline and a sheen
function UIKit.card(props: { color: Color3, size: UDim2?, parent: Instance?, layoutOrder: number?, name: string? }): Frame
	local card = create("Frame", {
		Name = props.name or "Card",
		Size = props.size or UDim2.fromOffset(180, 230),
		LayoutOrder = props.layoutOrder or 0,
		BackgroundColor3 = props.color,
	})
	UIKit.corner(card, 14)
	UIKit.outline(card, 3)
	UIKit.sheen(card, 0.4)
	if props.parent then
		card.Parent = props.parent
	end
	return card
end

-- a small dark pill with text, e.g. "Lv 12" or "STAGE 3"
function UIKit.pill(parent: Instance, text: string, position: UDim2, anchor: Vector2?): TextLabel
	local pill = UIKit.label({
		Name = "Pill",
		AnchorPoint = anchor or Vector2.zero,
		Position = position,
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		TextSize = 14,
		Text = text,
		ZIndex = 3, -- above the card's icon
		Parent = parent,
	}, 1.5)
	UIKit.corner(pill, 11)
	create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = pill })
	return pill
end

-- a grey "locked" cover over a card
function UIKit.lockCover(card: Instance): (Frame, TextLabel)
	local cover = create("Frame", {
		Name = "Lock",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(20, 20, 28),
		BackgroundTransparency = 0.12,
		ZIndex = 4,
		Visible = false,
		Parent = card,
	})
	UIKit.corner(cover, 14)
	UIKit.image({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, -64), Size = UDim2.fromOffset(68, 68), Image = Icons.get("ui_lock"), ZIndex = 4, Parent = cover })
	local text = UIKit.label({
		Size = UDim2.new(1, -16, 0, 44),
		Position = UDim2.new(0, 8, 0.5, 8),
		TextSize = 17,
		TextWrapped = true,
		Text = "",
		ZIndex = 4,
		Parent = cover,
	})
	return cover, text
end

----------------------------------------------------------------------------------------------------
-- menus

local player = Players.LocalPlayer
local menuGui: ScreenGui? = nil

local function getMenuGui(): ScreenGui
	if not menuGui then
		menuGui = create("ScreenGui", {
			Name = "ClapMenus",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			DisplayOrder = 10,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			Parent = player:WaitForChild("PlayerGui"),
		})
	end
	return menuGui :: ScreenGui
end

export type Modal = {
	root: Frame,
	header: Frame,
	body: Frame,
	title: TextLabel,
	icon: ImageLabel,
	open: () -> (),
	close: () -> (),
	toggle: () -> (),
	isOpen: () -> boolean,
	onOpen: (() -> ())?,
	onClose: (() -> ())?,
}

local modals: { Modal } = {}

function UIKit.closeAll()
	for _, modal in modals do
		if modal.isOpen() then
			modal.close()
		end
	end
end

-- a centred menu with a striped colour header, a title and a red X
function UIKit.modal(opts: { name: string, title: string, color: Color3, size: Vector2, icon: string? }): Modal
	local root = create("Frame", {
		Name = opts.name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, -24),
		Size = UDim2.fromOffset(opts.size.X, opts.size.Y),
		BackgroundColor3 = UIKit.Colors.panel,
		Active = true, -- clicks on menus never count as claps
		Visible = false,
		Parent = getMenuGui(),
	})
	UIKit.corner(root, 18)
	UIKit.outline(root, 4)
	local scale = create("UIScale", { Parent = root })

	local headerHeight = 66
	local header = create("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, headerHeight),
		BackgroundColor3 = opts.color,
		Parent = root,
	})
	UIKit.corner(header, 18)
	local headerGradient = ColorSequence.new(UIKit.lighten(opts.color, 0.25), opts.color)
	create("UIGradient", { Color = headerGradient, Parent = header })
	-- square off the header's bottom corners
	local filler = create("Frame", {
		Name = "Filler",
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.new(0, 0, 1, -20),
		BackgroundColor3 = opts.color,
		BorderSizePixel = 0,
		Parent = header,
	})
	create("UIGradient", { Color = headerGradient, Parent = filler })
	-- two diagonal light stripes, drawn with a gradient so they stay inside the header
	local stripes = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 2, Parent = header })
	UIKit.corner(stripes, 18)
	create("UIGradient", {
		Rotation = -3, -- gradient space is stretched to the header, so a few degrees slants the stripes a lot
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.6, 1),
			NumberSequenceKeypoint.new(0.601, 0.78),
			NumberSequenceKeypoint.new(0.66, 0.78),
			NumberSequenceKeypoint.new(0.661, 1),
			NumberSequenceKeypoint.new(0.7, 1),
			NumberSequenceKeypoint.new(0.701, 0.85),
			NumberSequenceKeypoint.new(0.73, 0.85),
			NumberSequenceKeypoint.new(0.731, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = stripes,
	})
	create("Frame", {
		Name = "Rule",
		Size = UDim2.new(1, 0, 0, 4),
		Position = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = UIKit.Colors.outline,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = header,
	})
	local icon = UIKit.image({
		Name = "TitleIcon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(58, 58),
		Image = opts.icon or "",
		ZIndex = 3,
		Parent = header,
	})
	local title = UIKit.label({
		Name = "Title",
		Position = UDim2.fromOffset(if opts.icon ~= nil then 76 else 20, 0), -- icon may be "" now and set later
		Size = UDim2.new(1, -160, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 36,
		Text = opts.title,
		ZIndex = 3,
		Parent = header,
	}, 3)
	local close = UIKit.button({
		name = "Close",
		color = UIKit.Colors.red,
		text = "X",
		textSize = 32,
		size = UDim2.fromOffset(54, 54),
		anchor = Vector2.new(1, 0.5),
		position = UDim2.new(1, -10, 0.5, 2),
		depth = 4,
		parent = header,
	})
	close.ZIndex = 3
	for _, d in close:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex = 3
		end
	end

	local body = create("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(0, headerHeight + 4),
		Size = UDim2.new(1, 0, 1, -(headerHeight + 4)),
		BackgroundTransparency = 1,
		Parent = root,
	})
	create("UIPadding", {
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
		PaddingTop = UDim.new(0, 14),
		PaddingBottom = UDim.new(0, 14),
		Parent = body,
	})

	-- shrink to fit small screens, leaving room for the dock; on short phone screens use nearly the
	-- whole height instead (the menu sits over the dock) so the cards stay readable
	local function fit(): number
		local camera = workspace.CurrentCamera
		local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		local reserve = if viewport.Y < 500 then 16 else 120
		return math.min(1, (viewport.X - 16) / opts.size.X, (viewport.Y - reserve) / opts.size.Y)
	end

	local modal: Modal
	modal = {
		root = root,
		header = header,
		body = body,
		title = title,
		icon = icon,
		open = function()
			for _, other in modals do
				if other ~= modal and other.isOpen() then
					other.close()
				end
			end
			root.Visible = true
			local target = fit()
			scale.Scale = target * 0.85
			TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = target }):Play()
			if modal.onOpen then
				(modal.onOpen :: () -> ())()
			end
		end,
		close = function()
			root.Visible = false
			if modal.onClose then
				(modal.onClose :: () -> ())()
			end
		end,
		toggle = function()
			if root.Visible then
				modal.close()
			else
				modal.open()
			end
		end,
		isOpen = function()
			return root.Visible
		end,
	}
	close.Activated:Connect(modal.close)
	table.insert(modals, modal)
	return modal
end

-- recolour a menu's header (e.g. to match the running event)
function UIKit.setModalColor(modal: Modal, color: Color3)
	local gradient = ColorSequence.new(UIKit.lighten(color, 0.25), color)
	for _, frame in { modal.header, modal.header:FindFirstChild("Filler") } do
		if frame and frame:IsA("Frame") then
			frame.BackgroundColor3 = color
			local g = frame:FindFirstChildOfClass("UIGradient")
			if g then
				g.Color = gradient
			end
		end
	end
end

-- a scrolling grid of cards inside a menu
function UIKit.grid(parent: Instance, cell: Vector2, props: { [string]: any }?): ScrollingFrame
	local defaults: { [string]: any } = {
		Name = "Grid",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Color3.new(1, 1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}
	for k, v in props or {} do
		defaults[k] = v
	end
	local grid = create("ScrollingFrame", defaults)
	create("UIGridLayout", {
		CellSize = UDim2.fromOffset(cell.X, cell.Y),
		CellPadding = UDim2.fromOffset(12, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	-- room for the outlines and the hover grow
	create("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), Parent = grid })
	grid.Parent = parent
	return grid
end

----------------------------------------------------------------------------------------------------
-- the dock: the row of big buttons at the bottom right

local dock: Frame? = nil

local function getDock(): Frame
	if not dock then
		local gui = create("ScreenGui", {
			Name = "ClapDock",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			DisplayOrder = 3,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			Parent = player:WaitForChild("PlayerGui"),
		})
		local frame = create("Frame", {
			Name = "Dock",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -16, 1, -12),
			Size = UDim2.new(1, -32, 0, 66),
			BackgroundTransparency = 1,
			Parent = gui,
		})
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = frame,
		})
		-- narrow or short screens: shrink the whole dock (but keep buttons big enough to tap)
		local scale = create("UIScale", { Parent = frame })
		local function fit()
			local camera = workspace.CurrentCamera
			local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
			scale.Scale = math.clamp(math.min(viewport.X / 900, viewport.Y / 560), 0.7, 1)
		end
		fit()
		local camera = workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
		end
		dock = frame
	end
	return dock :: Frame
end

-- a big dock button; order sets its place from the left
function UIKit.dockButton(opts: { name: string, text: string, color: Color3, width: number, order: number, textSize: number?, icon: string? }): TextButton
	return UIKit.button({
		name = opts.name,
		color = opts.color,
		text = opts.text,
		icon = opts.icon,
		textSize = opts.textSize or 24,
		size = UDim2.fromOffset(opts.width, 62),
		layoutOrder = opts.order,
		radius = 12,
		parent = getDock(),
	})
end

return UIKit
