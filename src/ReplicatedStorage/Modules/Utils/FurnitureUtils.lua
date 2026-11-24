--!strict
local FurnitureUtils = {}

local RPS = game:GetService('ReplicatedStorage')

local FUR_CONFIGS = require(RPS.Modules.Configs.FurnitureConfigs)
local BLD_CONFIGS = require(RPS.Modules.Configs.BuildConfigs)
local GRD_UTILS = require(RPS.Modules.Utils.GridUtils)
local DAT_TYPES = require(RPS.Modules.Types.DataTypes)

local OVERLAP_TOLERANCE = 0.05

-- what a player is allowed to build on (from their data)
export type PlaceContext = {
	Parcels: {[string]: boolean},
	Levels: number,
}

function FurnitureUtils.GetPosition(
	Position: Vector3,
	Rotation: number
): CFrame
	return CFrame.new(Position)
		* CFrame.Angles(0, math.rad(Rotation), 0)
end

function FurnitureUtils.PlaceFurniture(
	Furniture: Model,
	Position: Vector3,
	Rotation: number
)
	Furniture:PivotTo(
		FurnitureUtils.GetPosition(Position, Rotation)
	)
end

-- check a rotation is one of the four allowed angles
function FurnitureUtils.IsValidRotation(Rotation: number): boolean
	return Rotation == 0 or Rotation == 90 or Rotation == 180 or Rotation == 270
end

-- world position (bottom centre) of a placed item
function FurnitureUtils.GetWorldPosition(Origin: Vector3, Item: DAT_TYPES.FurnitureData): Vector3
	return GRD_UTILS.LocalToWorld(Origin, Item.X, Item.Z, Item.Level) + Vector3.new(0, BLD_CONFIGS.FloorThickness, 0)
end

-- create a furniture model with its pivot at the bottom centre
function FurnitureUtils.CreateModel(Name: string): Model?
	local config = FUR_CONFIGS.Items[Name]

	if not config then
		return nil
	end

	local templates = RPS:FindFirstChild('Furniture')
	local template = templates and templates:FindFirstChild(Name)
	local model: Model

	if template and template:IsA('Model') then
		-- a hand-made model from ReplicatedStorage.Furniture
		model = template:Clone()

		local boxCFrame, boxSize = model:GetBoundingBox()
		local bottom = boxCFrame.Position - Vector3.new(0, boxSize.Y / 2, 0)

		model.PrimaryPart = nil
		model.WorldPivot = CFrame.new(bottom)

	elseif config.Shape then
		-- build it from the config shape
		model = Instance.new('Model')

		for index, partConfig in config.Shape do
			local part: BasePart = if partConfig.Wedge then Instance.new('WedgePart') else Instance.new('Part')
			part.Name = `Part{index}`
			part.Size = partConfig.Size
			part.CFrame = CFrame.new(partConfig.Offset)
			part.Color = partConfig.Color
			part.Material = partConfig.Material or Enum.Material.SmoothPlastic
			part.Transparency = partConfig.Transparency or 0
			part.CanCollide = not partConfig.NoCollide
			part.TopSurface = Enum.SurfaceType.Smooth
			part.BottomSurface = Enum.SurfaceType.Smooth

			if partConfig.Light then
				local light = Instance.new('PointLight')
				light.Range = config.LightRange or 12
				light.Brightness = 1.2
				light.Color = partConfig.Color
				light.Shadows = true
				light.Parent = part
			end

			part.Parent = model
		end

		model.WorldPivot = CFrame.new()
	else
		return nil
	end

	for _, child in model:GetDescendants() do
		if child:IsA('BasePart') then
			child.Anchored = true
		end
	end

	model.Name = Name
	model:SetAttribute('Piece', 'Furniture')

	return model
end

-- get the footprint corners (plot-local studs) of a placed item
function FurnitureUtils.GetBounds(Name: string, X: number, Z: number, Rotation: number): (number, number, number, number)
	local config = FUR_CONFIGS.Items[Name]
	local footprint = if config then config.Footprint else Vector2.new(1, 1)

	local width, depth = footprint.X, footprint.Y

	if Rotation == 90 or Rotation == 270 then
		width, depth = depth, width
	end

	return X - width / 2, Z - depth / 2, X + width / 2, Z + depth / 2
end

-- every cell an item's footprint covers
function FurnitureUtils.GetCoveredCells(Name: string, X: number, Z: number, Rotation: number): {string}
	local size = BLD_CONFIGS.CellSize
	local minX, minZ, maxX, maxZ = FurnitureUtils.GetBounds(Name, X, Z, Rotation)
	local cells = {}

	for cellX = math.floor((minX + OVERLAP_TOLERANCE) / size), math.floor((maxX - OVERLAP_TOLERANCE) / size) do
		for cellZ = math.floor((minZ + OVERLAP_TOLERANCE) / size), math.floor((maxZ - OVERLAP_TOLERANCE) / size) do
			table.insert(cells, GRD_UTILS.CellKey(cellX, cellZ))
		end
	end

	return cells
end

-- level cells that are stair openings (the floor above every staircase)
function FurnitureUtils.GetStairwells(Land: DAT_TYPES.LandData): {[string]: boolean}
	local stairwells: {[string]: boolean} = {}

	for _, item in Land.Furniture do
		local config = FUR_CONFIGS.Items[item.Name]

		if config and config.Stairs then
			for _, cell in FurnitureUtils.GetCoveredCells(item.Name, item.X, item.Z, item.Rotation) do
				stairwells[GRD_UTILS.LevelCell(item.Level + 1, cell)] = true
			end
		end
	end

	return stairwells
end

-- check an item can go at a spot (owned land, right floor, not overlapping)
function FurnitureUtils.CanPlace(
	Land: DAT_TYPES.LandData,
	Context: PlaceContext,
	Name: string,
	Level: number,
	X: number,
	Z: number,
	Rotation: number,
	IgnoreId: string?
): (boolean, string?)
	local config = FUR_CONFIGS.Items[Name]

	if not config then
		return false, 'Unknown item'
	end

	if not FurnitureUtils.IsValidRotation(Rotation) then
		return false, 'Bad rotation'
	end

	if Level < 1 or Level > Context.Levels or Level % 1 ~= 0 then
		return false, 'Unlock this floor first'
	end

	local minX, minZ, maxX, maxZ = FurnitureUtils.GetBounds(Name, X, Z, Rotation)

	-- stairs and similar must line up with the tiles
	if config.CellAligned then
		local size = BLD_CONFIGS.CellSize

		if math.abs(minX / size - math.floor(minX / size + 0.5)) > 0.01
			or math.abs(minZ / size - math.floor(minZ / size + 0.5)) > 0.01
		then
			return false, 'Line it up with the tiles'
		end
	end

	local levelData = Land.Levels[GRD_UTILS.LevelKey(Level)]
	local aboveData = Land.Levels[GRD_UTILS.LevelKey(Level + 1)]

	for _, cell in FurnitureUtils.GetCoveredCells(Name, X, Z, Rotation) do
		if not GRD_UTILS.IsCellInside(cell) or not Context.Parcels[GRD_UTILS.CellParcel(cell)] then
			return false, 'Buy this land first'
		end

		if Level > 1 and not (levelData and levelData.Floors[cell]) then
			return false, 'Needs a floor under it'
		end

		if config.Stairs and aboveData and aboveData.Floors[cell] then
			return false, 'Remove the floor above the stairs first'
		end
	end

	if config.Stairs and Level + 1 > Context.Levels then
		return false, 'Unlock the next floor first'
	end

	if config.Flat then
		return true
	end

	for id, item in Land.Furniture do
		local otherConfig = FUR_CONFIGS.Items[item.Name]

		if id == IgnoreId or item.Level ~= Level or not otherConfig or otherConfig.Flat then
			continue
		end

		local oMinX, oMinZ, oMaxX, oMaxZ = FurnitureUtils.GetBounds(item.Name, item.X, item.Z, item.Rotation)

		local overlapX = math.min(maxX, oMaxX) - math.max(minX, oMinX)
		local overlapZ = math.min(maxZ, oMaxZ) - math.max(minZ, oMinZ)

		if overlapX > OVERLAP_TOLERANCE and overlapZ > OVERLAP_TOLERANCE then
			return false, 'Something is in the way'
		end
	end

	return true
end

return FurnitureUtils
