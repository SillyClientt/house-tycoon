--!strict
local BuildUtils = {}

local RPS = game:GetService('ReplicatedStorage')

local BLD_CONFIGS = require(RPS.Modules.Configs.BuildConfigs)
local GRD_UTILS = require(RPS.Modules.Utils.GridUtils)
local DAT_TYPES = require(RPS.Modules.Types.DataTypes)

-- bind position to grid
function BuildUtils.BindToGrid(pos: Vector3, gridSize: number): Vector3
	return Vector3.new(
		math.floor(pos.X / gridSize + 0.5) * gridSize,
		pos.Y,
		math.floor(pos.Z / gridSize + 0.5) * gridSize
	)
end

-- get the cost of one wall piece
function BuildUtils.GetWallCost(Wall: DAT_TYPES.WallData): number
	local style = BLD_CONFIGS.WallStyles[Wall.Style]
	local kind = BLD_CONFIGS.WallKinds[Wall.Kind]

	if not style or not kind then
		return 0
	end

	return style.Cost + kind.ExtraCost
end

-- get the value of one wall piece
function BuildUtils.GetWallValue(Wall: DAT_TYPES.WallData): number
	local style = BLD_CONFIGS.WallStyles[Wall.Style]
	local kind = BLD_CONFIGS.WallKinds[Wall.Kind]

	if not style or not kind then
		return 0
	end

	return style.Value + kind.ExtraValue
end

-- make a part for a house piece
local function newPart(Name: string, Size: Vector3, CF: CFrame, Color: Color3, Material: Enum.Material): Part
	local part = Instance.new('Part')
	part.Name = Name
	part.Anchored = true
	part.Size = Size
	part.CFrame = CF
	part.Color = Color
	part.Material = Material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth

	return part
end

-- turn a model into a see-through preview
function BuildUtils.MakeGhost(Model: Model, Color: Color3?)
	for _, child in Model:GetDescendants() do
		if child:IsA('BasePart') then
			child.Anchored = true
			child.CanCollide = false
			child.CanTouch = false
			child.CanQuery = false
			child.CastShadow = false
			child.Transparency = math.max(child.Transparency, 0.5)

			if Color then
				child.Color = Color
			end
		elseif child:IsA('Light') then
			child.Enabled = false
		end
	end
end

-- create a wall, window or door piece on an edge
function BuildUtils.CreateWall(Origin: Vector3, Level: number, Key: string, Wall: DAT_TYPES.WallData): Model
	local style = BLD_CONFIGS.WallStyles[Wall.Style] or BLD_CONFIGS.WallStyles.Plaster
	local axis, x, z = GRD_UTILS.ParseEdgeKey(Key)

	local length = BLD_CONFIGS.CellSize
	local height = BLD_CONFIGS.WallHeight
	local thick = BLD_CONFIGS.WallThickness

	-- centre of the edge, rotated so local X runs along the wall
	local center = if axis == 'X'
		then GRD_UTILS.PointToWorld(Origin, x + 0.5, z, Level)
		else GRD_UTILS.PointToWorld(Origin, x, z + 0.5, Level)

	local base = CFrame.new(center)

	if axis == 'Z' then
		base *= CFrame.Angles(0, math.rad(90), 0)
	end

	local model = Instance.new('Model')
	model.Name = Key
	model:SetAttribute('Piece', 'Wall')
	model:SetAttribute('Level', Level)

	-- add a solid block between two heights
	local function addBlock(Name: string, Bottom: number, Top: number, Width: number?, OffsetX: number?)
		local part = newPart(
			Name,
			Vector3.new(Width or length, Top - Bottom, thick),
			base * CFrame.new(OffsetX or 0, (Bottom + Top) / 2, 0),
			style.Color,
			style.Material
		)

		part.Parent = model
	end

	if Wall.Kind == 'Window' then
		local bottom = BLD_CONFIGS.WindowBottom
		local top = BLD_CONFIGS.WindowTop

		addBlock('Lower', 0, bottom)
		addBlock('Upper', top, height)

		local glass = newPart(
			'Glass',
			Vector3.new(length, top - bottom, thick * 0.3),
			base * CFrame.new(0, (bottom + top) / 2, 0),
			Color3.fromRGB(190, 225, 255),
			Enum.Material.Glass
		)

		glass.Transparency = 0.5
		glass.Parent = model

	elseif Wall.Kind == 'Door' then
		local top = BLD_CONFIGS.DoorTop
		local jamb = 0.4

		addBlock('Lintel', top, height)
		addBlock('LeftJamb', 0, top, jamb, -(length - jamb) / 2)
		addBlock('RightJamb', 0, top, jamb, (length - jamb) / 2)

	else
		addBlock('Wall', 0, height)
	end

	model.PrimaryPart = model:FindFirstChildWhichIsA('BasePart')

	return model
end

-- create a corner post that fills the gap where walls meet
function BuildUtils.CreatePost(Origin: Vector3, Level: number, X: number, Z: number, Style: string): Part
	local style = BLD_CONFIGS.WallStyles[Style] or BLD_CONFIGS.WallStyles.Plaster
	local size = BLD_CONFIGS.WallThickness + 0.02
	local height = BLD_CONFIGS.WallHeight

	local post = newPart(
		`P_{X}_{Z}`,
		Vector3.new(size, height, size),
		CFrame.new(GRD_UTILS.PointToWorld(Origin, X, Z, Level) + Vector3.new(0, height / 2, 0)),
		style.Color,
		style.Material
	)

	post:SetAttribute('Piece', 'Post')

	return post
end

-- create a floor tile on a cell
function BuildUtils.CreateFloor(Origin: Vector3, Level: number, Key: string, Style: string): Part
	local style = BLD_CONFIGS.FloorStyles[Style] or BLD_CONFIGS.FloorStyles.Wood
	local x, z = GRD_UTILS.ParseCellKey(Key)
	local size = BLD_CONFIGS.CellSize
	local thick = BLD_CONFIGS.FloorThickness

	local floor = newPart(
		Key,
		Vector3.new(size, thick, size),
		CFrame.new(GRD_UTILS.CellToWorld(Origin, x, z, Level) + Vector3.new(0, thick / 2, 0)),
		style.Color,
		style.Material
	)

	floor:SetAttribute('Piece', 'Floor')
	floor:SetAttribute('Level', Level)

	return floor
end

-- create a dirt spot on a cell (cleaned with its ProximityPrompt)
function BuildUtils.CreateDirt(Origin: Vector3, Dirt: DAT_TYPES.DirtData, Id: string): Part
	local x, z = GRD_UTILS.ParseCellKey(Dirt.Cell)

	-- spread spots around the tile so they don't all sit in the middle
	local seed = 0

	for index = 1, #Id do
		seed += string.byte(Id, index)
	end

	local offset = Vector3.new((seed % 5 - 2) * 0.5, 0, (seed % 7 - 3) * 0.4)
	local base = GRD_UTILS.CellToWorld(Origin, x, z, Dirt.Level) + Vector3.new(0, BLD_CONFIGS.FloorThickness, 0) + offset

	local spot: Part

	if Dirt.Kind == 'Trash' then
		spot = newPart(Id, Vector3.new(1.2, 1.2, 1.2), CFrame.new(base + Vector3.new(0, 0.6, 0)), Color3.fromRGB(40, 40, 45), Enum.Material.Plastic)
		spot.Shape = Enum.PartType.Ball
	else
		local color = if Dirt.Kind == 'Stain' then Color3.fromRGB(95, 70, 45) else Color3.fromRGB(150, 140, 120)

		spot = newPart(Id, Vector3.new(0.05, 2.6, 2.6), CFrame.new(base + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.Material.Sand)
		spot.Shape = Enum.PartType.Cylinder
		spot.Transparency = 0.15
	end

	spot.CanCollide = false
	spot.CanTouch = false
	spot.CastShadow = false
	spot:SetAttribute('Piece', 'Dirt')
	spot:SetAttribute('Level', Dirt.Level)

	local prompt = Instance.new('ProximityPrompt')
	prompt.Name = 'CleanPrompt'
	prompt.ActionText = 'Clean'
	prompt.ObjectText = Dirt.Kind
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = spot

	return spot
end

return BuildUtils
