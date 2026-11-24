--!strict
-- Small helpers that build one piece of scenery each (trees, lamps, fences, shops...).
-- Every piece is made of plain parts, so it's easy to restyle here or swap for a model.
local SceneryBuilder = {}

local RPS = game:GetService('ReplicatedStorage')

local MAP_CONFIGS = require(RPS.Modules.Configs.MapConfigs)

local colors = MAP_CONFIGS.Colors

export type PartOptions = {
	Name: string?,
	Shape: Enum.PartType?,
	Material: Enum.Material?,
	Collide: boolean?,
	Transparency: number?,
}

-- anchored decoration part (no touch/query so it never gets in the way of building or clicking)
function SceneryBuilder.Part(Parent: Instance, Size: Vector3, At: CFrame, Color: Color3, Options: PartOptions?): Part
	local options: PartOptions = Options or {}

	local part = Instance.new('Part')
	part.Name = options.Name or 'Part'
	part.Anchored = true
	part.Shape = options.Shape or Enum.PartType.Block
	part.Size = Size
	part.CFrame = At
	part.Color = Color
	part.Material = options.Material or Enum.Material.SmoothPlastic
	part.Transparency = options.Transparency or 0
	part.CanCollide = options.Collide == true
	part.CanTouch = false
	part.CanQuery = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = Parent

	return part
end

-- a round cartoon tree (Scale 1 is about 16 studs tall)
function SceneryBuilder.Tree(Parent: Instance, Ground: Vector3, Scale: number, Rng: Random): Model
	local model = Instance.new('Model')
	model.Name = 'Tree'

	local trunkHeight = 7 * Scale
	local leaves = colors.Leaves[Rng:NextInteger(1, #colors.Leaves)]

	SceneryBuilder.Part(model, Vector3.new(trunkHeight, 1.6 * Scale, 1.6 * Scale),
		CFrame.new(Ground + Vector3.new(0, trunkHeight / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		colors.Trunk, {Name = 'Trunk', Shape = Enum.PartType.Cylinder, Material = Enum.Material.Wood, Collide = true})

	-- a big ball on top with two smaller ones on the sides
	local top = Ground + Vector3.new(0, trunkHeight + 3 * Scale, 0)
	SceneryBuilder.Part(model, Vector3.one * 10 * Scale, CFrame.new(top), leaves,
		{Name = 'Leaves', Shape = Enum.PartType.Ball, Material = Enum.Material.Grass})

	for _ = 1, 2 do
		local angle = Rng:NextNumber(0, math.pi * 2)
		local offset = Vector3.new(math.cos(angle), Rng:NextNumber(-1.5, 0.5), math.sin(angle)) * 3.5 * Scale
		SceneryBuilder.Part(model, Vector3.one * 7 * Scale, CFrame.new(top + offset), leaves,
			{Name = 'Leaves', Shape = Enum.PartType.Ball, Material = Enum.Material.Grass})
	end

	model.Parent = Parent
	return model
end

-- a low round bush
function SceneryBuilder.Bush(Parent: Instance, Ground: Vector3, Size: number, Rng: Random)
	local leaves = colors.Leaves[Rng:NextInteger(1, #colors.Leaves)]

	SceneryBuilder.Part(Parent, Vector3.new(Size * 1.3, Size, Size * 1.3), CFrame.new(Ground + Vector3.new(0, Size * 0.3, 0)),
		leaves, {Name = 'Bush', Shape = Enum.PartType.Ball, Material = Enum.Material.Grass})
end

-- a patch of little flowers
function SceneryBuilder.Flowers(Parent: Instance, Ground: Vector3, Rng: Random)
	local color = colors.Flowers[Rng:NextInteger(1, #colors.Flowers)]

	for _ = 1, 6 do
		local offset = Vector3.new(Rng:NextNumber(-3, 3), 0.5, Rng:NextNumber(-3, 3))
		SceneryBuilder.Part(Parent, Vector3.one * 0.9, CFrame.new(Ground + offset), color,
			{Name = 'Flower', Shape = Enum.PartType.Ball})
	end
end

-- a street lamp facing Facing (the light is returned so the day cycle can switch it)
function SceneryBuilder.Lamp(Parent: Instance, Ground: Vector3, Facing: Vector3): (PointLight, BasePart)
	local model = Instance.new('Model')
	model.Name = 'StreetLamp'

	local height = MAP_CONFIGS.LampHeight
	local base = CFrame.lookAt(Ground, Ground + Facing)

	SceneryBuilder.Part(model, Vector3.new(1.4, 1, 1.4), base * CFrame.new(0, 0.5, 0), colors.LampPost,
		{Name = 'Foot', Material = Enum.Material.Metal, Collide = true})
	SceneryBuilder.Part(model, Vector3.new(height, 0.6, 0.6),
		base * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), colors.LampPost,
		{Name = 'Pole', Shape = Enum.PartType.Cylinder, Material = Enum.Material.Metal, Collide = true})

	-- arm reaching out over the street
	SceneryBuilder.Part(model, Vector3.new(0.4, 0.4, 3.5), base * CFrame.new(0, height - 0.2, -1.6), colors.LampPost,
		{Name = 'Arm', Material = Enum.Material.Metal})
	SceneryBuilder.Part(model, Vector3.new(2, 0.6, 2), base * CFrame.new(0, height - 0.3, -3.2), colors.LampPost,
		{Name = 'Shade', Material = Enum.Material.Metal})

	local bulb = SceneryBuilder.Part(model, Vector3.new(1.4, 0.4, 1.4), base * CFrame.new(0, height - 0.8, -3.2),
		colors.LampGlow, {Name = 'Bulb'})

	local light = Instance.new('PointLight')
	light.Range = MAP_CONFIGS.LampRange
	light.Brightness = MAP_CONFIGS.LampBrightness
	light.Color = colors.LampGlow
	light.Shadows = false
	light.Enabled = false
	light.Parent = bulb

	model.Parent = Parent
	return light, bulb
end

-- white picket fence from A to B (ground points)
function SceneryBuilder.Fence(Parent: Instance, A: Vector3, B: Vector3)
	local model = Instance.new('Model')
	model.Name = 'Fence'

	local length = (B - A).Magnitude
	local direction = (B - A).Unit
	local along = CFrame.lookAt(A, B)
	local height = MAP_CONFIGS.FenceHeight

	-- two rails
	for _, y in {height * 0.35, height * 0.75} do
		SceneryBuilder.Part(model, Vector3.new(0.3, 0.5, length), along * CFrame.new(0, y, -length / 2), colors.Fence,
			{Name = 'Rail', Collide = true})
	end

	-- pickets, each with a little point on top
	local count = math.floor(length / MAP_CONFIGS.PicketSpacing)

	for index = 0, count do
		local point = A + direction * math.min(index * MAP_CONFIGS.PicketSpacing, length)
		local at = CFrame.lookAt(point, point + direction)

		SceneryBuilder.Part(model, Vector3.new(0.5, height, 0.9), at * CFrame.new(0, height / 2, 0), colors.Fence,
			{Name = 'Picket'})
		SceneryBuilder.Part(model, Vector3.new(0.5, 0.64, 0.64),
			at * CFrame.new(0, height, 0) * CFrame.Angles(math.rad(45), 0, 0), colors.Fence, {Name = 'Tip'})
	end

	model.Parent = Parent
end

-- a mailbox on a post
function SceneryBuilder.Mailbox(Parent: Instance, Ground: Vector3, Facing: Vector3)
	local model = Instance.new('Model')
	model.Name = 'Mailbox'

	local base = CFrame.lookAt(Ground, Ground + Facing)

	SceneryBuilder.Part(model, Vector3.new(0.5, 3.5, 0.5), base * CFrame.new(0, 1.75, 0), colors.Trunk,
		{Material = Enum.Material.Wood, Collide = true})
	SceneryBuilder.Part(model, Vector3.new(1.4, 1.4, 2.4), base * CFrame.new(0, 4, 0), colors.Mailbox, {Collide = true})
	SceneryBuilder.Part(model, Vector3.new(0.15, 1, 0.3), base * CFrame.new(0.78, 4.6, 0.6), Color3.fromRGB(230, 60, 60))

	model.Parent = Parent
end

-- a park bench facing Facing
function SceneryBuilder.Bench(Parent: Instance, Ground: Vector3, Facing: Vector3)
	local model = Instance.new('Model')
	model.Name = 'Bench'

	local base = CFrame.lookAt(Ground, Ground + Facing)
	local wood = Color3.fromRGB(176, 120, 72)

	SceneryBuilder.Part(model, Vector3.new(6, 0.4, 2), base * CFrame.new(0, 1.8, 0), wood,
		{Material = Enum.Material.Wood, Collide = true})
	SceneryBuilder.Part(model, Vector3.new(6, 1.6, 0.3), base * CFrame.new(0, 3, 1), wood, {Material = Enum.Material.Wood})

	for _, x in {-2.6, 2.6} do
		SceneryBuilder.Part(model, Vector3.new(0.4, 1.8, 2), base * CFrame.new(x, 0.9, 0), colors.LampPost,
			{Material = Enum.Material.Metal})
	end

	model.Parent = Parent
end

-- a round fountain
function SceneryBuilder.Fountain(Parent: Instance, Ground: Vector3)
	local model = Instance.new('Model')
	model.Name = 'Fountain'

	local stone = Color3.fromRGB(196, 190, 180)
	local flat = CFrame.new(Ground) * CFrame.Angles(0, 0, math.rad(90))

	SceneryBuilder.Part(model, Vector3.new(2.4, 26, 26), flat * CFrame.new(1.2, 0, 0), stone,
		{Shape = Enum.PartType.Cylinder, Material = Enum.Material.Slate, Collide = true})
	SceneryBuilder.Part(model, Vector3.new(0.4, 23, 23), flat * CFrame.new(2.3, 0, 0), Color3.fromRGB(80, 170, 230),
		{Shape = Enum.PartType.Cylinder, Material = Enum.Material.Glass, Transparency = 0.25})
	SceneryBuilder.Part(model, Vector3.new(8, 3, 3), flat * CFrame.new(4, 0, 0), stone,
		{Shape = Enum.PartType.Cylinder, Material = Enum.Material.Slate, Collide = true})
	SceneryBuilder.Part(model, Vector3.new(1.2, 10, 10), flat * CFrame.new(7.5, 0, 0), stone,
		{Shape = Enum.PartType.Cylinder, Material = Enum.Material.Slate})
	SceneryBuilder.Part(model, Vector3.new(0.3, 8.6, 8.6), flat * CFrame.new(8.1, 0, 0), Color3.fromRGB(80, 170, 230),
		{Shape = Enum.PartType.Cylinder, Material = Enum.Material.Glass, Transparency = 0.25})

	-- water spray
	local nozzle = SceneryBuilder.Part(model, Vector3.one, CFrame.new(Ground + Vector3.new(0, 9, 0)), stone,
		{Transparency = 1})

	local attachment = Instance.new('Attachment')
	attachment.Parent = nozzle

	local spray = Instance.new('ParticleEmitter')
	spray.Color = ColorSequence.new(Color3.fromRGB(200, 235, 255))
	spray.LightEmission = 0.3
	spray.Size = NumberSequence.new(0.6, 0.2)
	spray.Transparency = NumberSequence.new(0.2, 1)
	spray.Lifetime = NumberRange.new(1, 1.4)
	spray.Rate = 60
	spray.Speed = NumberRange.new(12, 15)
	spray.SpreadAngle = Vector2.new(14, 14)
	spray.Acceleration = Vector3.new(0, -30, 0)
	spray.EmissionDirection = Enum.NormalId.Top
	spray.Parent = attachment

	model.Parent = Parent
end

-- a little shop with a sign, door and windows, its front facing Facing
function SceneryBuilder.Shop(Parent: Instance, Ground: Vector3, Facing: Vector3, Name: string, Color: Color3): {Light}
	local model = Instance.new('Model')
	model.Name = Name

	local base = CFrame.lookAt(Ground, Ground + Facing)
	local width, height, depth = 44, 20, 30
	local trim = Color3.fromRGB(250, 246, 236)
	local glass = Color3.fromRGB(150, 200, 230)
	local lights: {Light} = {}

	-- body and flat roof with a lip
	SceneryBuilder.Part(model, Vector3.new(width, height, depth), base * CFrame.new(0, height / 2, 0), Color,
		{Name = 'Body', Material = Enum.Material.Brick, Collide = true})
	SceneryBuilder.Part(model, Vector3.new(width + 2, 1.5, depth + 2), base * CFrame.new(0, height + 0.75, 0), trim,
		{Name = 'Roof', Collide = true})

	-- striped awning over the door
	for index = 0, 5 do
		local stripe = if index % 2 == 0 then trim else Color

		SceneryBuilder.Part(model, Vector3.new(width / 6, 0.4, 5),
			base * CFrame.new(-width / 2 + width / 12 + index * width / 6, 11, -depth / 2 - 2.3) * CFrame.Angles(math.rad(-18), 0, 0),
			stripe, {Name = 'Awning'})
	end

	-- door and two shop windows
	SceneryBuilder.Part(model, Vector3.new(7, 10, 0.4), base * CFrame.new(0, 5, -depth / 2 - 0.1), Color3.fromRGB(90, 62, 44),
		{Name = 'Door', Material = Enum.Material.Wood})

	for _, x in {-13, 13} do
		local window = SceneryBuilder.Part(model, Vector3.new(12, 7, 0.4), base * CFrame.new(x, 6.5, -depth / 2 - 0.1), glass,
			{Name = 'Window', Material = Enum.Material.Glass, Transparency = 0.1})

		-- the windows glow at night
		local light = Instance.new('SurfaceLight')
		light.Face = Enum.NormalId.Front
		light.Range = 14
		light.Brightness = 1.5
		light.Color = colors.LampGlow
		light.Enabled = false
		light.Parent = window

		table.insert(lights, light)
	end

	-- name sign
	local sign = SceneryBuilder.Part(model, Vector3.new(26, 4.5, 0.6), base * CFrame.new(0, 15.5, -depth / 2 - 0.3), trim,
		{Name = 'Sign'})

	local surface = Instance.new('SurfaceGui')
	surface.Face = Enum.NormalId.Front
	surface.PixelsPerStud = 30
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.Parent = sign

	local label = Instance.new('TextLabel')
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color
	label.Text = Name
	label.Parent = surface

	local padding = Instance.new('UIPadding')
	padding.PaddingTop = UDim.new(0.12, 0)
	padding.PaddingBottom = UDim.new(0.12, 0)
	padding.Parent = label

	model.Parent = Parent
	return lights
end

return SceneryBuilder
