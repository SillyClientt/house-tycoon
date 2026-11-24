--!strict
local GridUtils = {}

local RPS = game:GetService('ReplicatedStorage')

local BLD_CONFIGS = require(RPS.Modules.Configs.BuildConfigs)
local LND_CONFIGS = require(RPS.Modules.Configs.LandConfigs)

export type Axis = 'X' | 'Z'

--[[
	The build grid covers the whole land and starts at its -X/-Z corner.

	cell        "x_z"        - the square between points (x, z) and (x + 1, z + 1)
	point                    - a grid corner, used by walls
	edge        "X_x_z"      - wall from point (x, z) to (x + 1, z)
	            "Z_x_z"      - wall from point (x, z) to (x, z + 1)
	level cell  "level|x_z"  - a cell on a given floor
	parcel      "px_pz"      - ParcelCells x ParcelCells cells of land
]]

-- cells per side of a whole land
GridUtils.LandCells = LND_CONFIGS.ParcelGrid * LND_CONFIGS.ParcelCells

-- studs per side of a whole land
GridUtils.LandStuds = GridUtils.LandCells * BLD_CONFIGS.CellSize

-- get the world position of the grid corner (top of the land part)
function GridUtils.GetOrigin(Land: BasePart): Vector3
	return Land.Position - Vector3.new(Land.Size.X / 2, -Land.Size.Y / 2, Land.Size.Z / 2)
end

-- height of a floor above the land (level 1 = 0)
function GridUtils.LevelHeight(Level: number): number
	return (Level - 1) * BLD_CONFIGS.WallHeight
end

-- data key for a floor ("L1", "L2", ...)
function GridUtils.LevelKey(Level: number): string
	return `L{Level}`
end

-- cell keys
function GridUtils.CellKey(X: number, Z: number): string
	return `{X}_{Z}`
end

function GridUtils.ParseCellKey(Key: string): (number, number)
	local parts = string.split(Key, '_')

	return tonumber(parts[1]) or 0, tonumber(parts[2]) or 0
end

-- level cell keys ("2|4_7")
function GridUtils.LevelCell(Level: number, Key: string): string
	return `{Level}|{Key}`
end

function GridUtils.ParseLevelCell(Key: string): (number, string)
	local parts = string.split(Key, '|')

	return tonumber(parts[1]) or 1, parts[2] or ''
end

-- edge keys
function GridUtils.EdgeKey(Axis: Axis, X: number, Z: number): string
	return `{Axis}_{X}_{Z}`
end

function GridUtils.ParseEdgeKey(Key: string): (Axis, number, number)
	local parts = string.split(Key, '_')
	local axis: Axis = if parts[1] == 'Z' then 'Z' else 'X'

	return axis, tonumber(parts[2]) or 0, tonumber(parts[3]) or 0
end

-- check keys are real and inside the land
function GridUtils.IsCellInside(Key: string): boolean
	local parts = string.split(Key, '_')
	local x, z = tonumber(parts[1]), tonumber(parts[2])
	local size = GridUtils.LandCells

	if #parts ~= 2 or not x or not z then
		return false
	end

	return x % 1 == 0 and z % 1 == 0 and x >= 0 and z >= 0 and x < size and z < size
end

function GridUtils.IsEdgeInside(Key: string): boolean
	local parts = string.split(Key, '_')
	local x, z = tonumber(parts[2]), tonumber(parts[3])
	local size = GridUtils.LandCells

	if #parts ~= 3 or not x or not z or x % 1 ~= 0 or z % 1 ~= 0 then
		return false
	end

	if parts[1] == 'X' then
		return x >= 0 and x < size and z >= 0 and z <= size
	elseif parts[1] == 'Z' then
		return x >= 0 and x <= size and z >= 0 and z < size
	end

	return false
end

-- the two cells on each side of an edge (either may be outside the land)
function GridUtils.EdgeCells(Key: string): (string, string)
	local axis, x, z = GridUtils.ParseEdgeKey(Key)

	if axis == 'X' then
		return GridUtils.CellKey(x, z - 1), GridUtils.CellKey(x, z)
	end

	return GridUtils.CellKey(x - 1, z), GridUtils.CellKey(x, z)
end

-- the four edges around a cell
function GridUtils.CellEdges(X: number, Z: number): {string}
	return {
		GridUtils.EdgeKey('X', X, Z),
		GridUtils.EdgeKey('X', X, Z + 1),
		GridUtils.EdgeKey('Z', X, Z),
		GridUtils.EdgeKey('Z', X + 1, Z),
	}
end

-- get every edge on a straight line between two points
function GridUtils.EdgesBetween(AX: number, AZ: number, BX: number, BZ: number): {string}
	local edges = {}

	if AZ == BZ and AX ~= BX then
		for x = math.min(AX, BX), math.max(AX, BX) - 1 do
			table.insert(edges, GridUtils.EdgeKey('X', x, AZ))
		end
	elseif AX == BX and AZ ~= BZ then
		for z = math.min(AZ, BZ), math.max(AZ, BZ) - 1 do
			table.insert(edges, GridUtils.EdgeKey('Z', AX, z))
		end
	end

	return edges
end

-- get every cell in the rectangle between two cells
function GridUtils.CellsBetween(AX: number, AZ: number, BX: number, BZ: number): {string}
	local cells = {}

	for x = math.min(AX, BX), math.max(AX, BX) do
		for z = math.min(AZ, BZ), math.max(AZ, BZ) do
			table.insert(cells, GridUtils.CellKey(x, z))
		end
	end

	return cells
end

-- get the edges touching a point (used for corner posts)
function GridUtils.EdgesAtPoint(X: number, Z: number): {string}
	return {
		GridUtils.EdgeKey('X', X - 1, Z),
		GridUtils.EdgeKey('X', X, Z),
		GridUtils.EdgeKey('Z', X, Z - 1),
		GridUtils.EdgeKey('Z', X, Z),
	}
end

-- get the two end points of an edge
function GridUtils.EdgePoints(Key: string): (number, number, number, number)
	local axis, x, z = GridUtils.ParseEdgeKey(Key)

	if axis == 'X' then
		return x, z, x + 1, z
	end

	return x, z, x, z + 1
end

-- parcel holding a cell
function GridUtils.CellParcel(Key: string): string
	local x, z = GridUtils.ParseCellKey(Key)
	local size = LND_CONFIGS.ParcelCells

	return GridUtils.CellKey(math.floor(x / size), math.floor(z / size))
end

-- world positions
function GridUtils.PointToWorld(Origin: Vector3, X: number, Z: number, Level: number?): Vector3
	local size = BLD_CONFIGS.CellSize

	return Origin + Vector3.new(X * size, GridUtils.LevelHeight(Level or 1), Z * size)
end

function GridUtils.CellToWorld(Origin: Vector3, X: number, Z: number, Level: number?): Vector3
	local size = BLD_CONFIGS.CellSize

	return Origin + Vector3.new((X + 0.5) * size, GridUtils.LevelHeight(Level or 1), (Z + 0.5) * size)
end

-- plot-local studs (used by furniture) to world
function GridUtils.LocalToWorld(Origin: Vector3, X: number, Z: number, Level: number?): Vector3
	return Origin + Vector3.new(X, GridUtils.LevelHeight(Level or 1), Z)
end

function GridUtils.WorldToLocal(Origin: Vector3, Position: Vector3): (number, number)
	local offset = Position - Origin

	return offset.X, offset.Z
end

-- nearest grid point to a world position
function GridUtils.WorldToPoint(Origin: Vector3, Position: Vector3): (number, number)
	local size = BLD_CONFIGS.CellSize
	local x, z = GridUtils.WorldToLocal(Origin, Position)

	return math.floor(x / size + 0.5), math.floor(z / size + 0.5)
end

-- cell under a world position
function GridUtils.WorldToCell(Origin: Vector3, Position: Vector3): (number, number)
	local size = BLD_CONFIGS.CellSize
	local x, z = GridUtils.WorldToLocal(Origin, Position)

	return math.floor(x / size), math.floor(z / size)
end

-- cell that holds a plot-local position
function GridUtils.LocalToCell(X: number, Z: number): string
	local size = BLD_CONFIGS.CellSize

	return GridUtils.CellKey(math.floor(X / size), math.floor(Z / size))
end

return GridUtils
