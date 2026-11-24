--!strict
local HouseUtils = {}

local RPS = game:GetService('ReplicatedStorage')

local MKT_CONFIGS = require(RPS.Modules.Configs.MarketConfigs)
local FUR_CONFIGS = require(RPS.Modules.Configs.FurnitureConfigs)
local BLD_CONFIGS = require(RPS.Modules.Configs.BuildConfigs)
local LND_CONFIGS = require(RPS.Modules.Configs.LandConfigs)
local GRD_UTILS = require(RPS.Modules.Utils.GridUtils)
local BLD_UTILS = require(RPS.Modules.Utils.BuildUtils)
local FUR_UTILS = require(RPS.Modules.Utils.FurnitureUtils)
local DAT_TYPES = require(RPS.Modules.Types.DataTypes)
local CFG_TYPES = require(RPS.Modules.Types.ConfigTypes)

export type HousePieces = {
	Walls: {{Level: number, Key: string}},
	Floors: {{Level: number, Key: string}},
	Furniture: {string},
	Dirt: {string},
}

-- rooms that make up one house while grouping
type Group = {
	Rooms: {DAT_TYPES.RoomData},
	RoomIndexes: {[number]: boolean},
	Cells: {[string]: boolean},
	Id: string,
}

local EMPTY_LEVEL: DAT_TYPES.LevelData = {Walls = {}, Floors = {}}

-- create empty land data
function HouseUtils.NewLand(): DAT_TYPES.LandData
	local levels: {[string]: DAT_TYPES.LevelData} = {}

	for level = 1, LND_CONFIGS.MaxLevels do
		levels[GRD_UTILS.LevelKey(level)] = {Walls = {}, Floors = {}}
	end

	return {
		Levels = levels,
		Furniture = {},
		Dirt = {},
	}
end

-- deep copy land data
function HouseUtils.CloneLand(Land: DAT_TYPES.LandData): DAT_TYPES.LandData
	local copy = HouseUtils.NewLand()

	for levelKey, levelData in Land.Levels do
		local levelCopy: DAT_TYPES.LevelData = {Walls = {}, Floors = {}}

		for key, wall in levelData.Walls do
			levelCopy.Walls[key] = table.clone(wall)
		end

		for key, style in levelData.Floors do
			levelCopy.Floors[key] = style
		end

		copy.Levels[levelKey] = levelCopy
	end

	for id, item in Land.Furniture do
		copy.Furniture[id] = table.clone(item)
	end

	for id, dirt in Land.Dirt do
		copy.Dirt[id] = table.clone(dirt)
	end

	return copy
end

-- get one floor's walls and floors (empty if missing)
function HouseUtils.GetLevel(Land: DAT_TYPES.LandData, Level: number): DAT_TYPES.LevelData
	return Land.Levels[GRD_UTILS.LevelKey(Level)] or EMPTY_LEVEL
end

-- most dirt spots a house of this size can have
function HouseUtils.GetMaxDirt(CellCount: number): number
	return math.max(1, math.floor(CellCount / MKT_CONFIGS.CellsPerDirt))
end

-- value multiplier for a number of dirt spots
function HouseUtils.GetCleanFactor(DirtCount: number): number
	return math.max(MKT_CONFIGS.MinCleanFactor, 1 - DirtCount * MKT_CONFIGS.DirtPenalty)
end

-- get the starting rent per minute for a house value
function HouseUtils.GetBaseRent(Value: number): number
	return math.max(1, math.floor(Value * MKT_CONFIGS.RentPerMinuteRate))
end

-- find every valid room on one floor (closed in by walls, fully floored, has a way in)
function HouseUtils.GetRooms(Land: DAT_TYPES.LandData, Level: number, Stairwells: {[string]: boolean}): {DAT_TYPES.RoomData}
	local levelData = HouseUtils.GetLevel(Land, Level)
	local size = GRD_UTILS.LandCells
	local visited: {[string]: boolean} = {}
	local rooms: {DAT_TYPES.RoomData} = {}

	-- a stair opening counts as floor and as a way in
	local function isFloored(Key: string): boolean
		return levelData.Floors[Key] ~= nil or Stairwells[GRD_UTILS.LevelCell(Level, Key)] == true
	end

	for startKey in levelData.Floors do
		if visited[startKey] then
			continue
		end

		visited[startKey] = true

		local startX, startZ = GRD_UTILS.ParseCellKey(startKey)
		local queue: {{number}} = {{startX, startZ}}
		local cells: {string} = {}
		local head = 1

		local outdoor = false
		local floored = true
		local hasEntrance = false

		-- flood fill until walls stop us
		while head <= #queue do
			local x, z = queue[head][1], queue[head][2]
			head += 1

			local key = GRD_UTILS.CellKey(x, z)
			table.insert(cells, key)

			if not isFloored(key) then
				floored = false
			end

			if Stairwells[GRD_UTILS.LevelCell(Level, key)] then
				hasEntrance = true
			end

			local neighbours = {
				{x - 1, z, GRD_UTILS.EdgeKey('Z', x, z)},
				{x + 1, z, GRD_UTILS.EdgeKey('Z', x + 1, z)},
				{x, z - 1, GRD_UTILS.EdgeKey('X', x, z)},
				{x, z + 1, GRD_UTILS.EdgeKey('X', x, z + 1)},
			}

			for _, neighbour in neighbours do
				local nextX = neighbour[1] :: number
				local nextZ = neighbour[2] :: number
				local wall = levelData.Walls[neighbour[3] :: string]

				if wall then
					if wall.Kind == 'Door' then
						hasEntrance = true
					end

					continue
				end

				if nextX < 0 or nextZ < 0 or nextX >= size or nextZ >= size then
					outdoor = true
					continue
				end

				local nextKey = GRD_UTILS.CellKey(nextX, nextZ)

				if not visited[nextKey] then
					visited[nextKey] = true
					table.insert(queue, {nextX, nextZ})
				end
			end
		end

		if not outdoor and floored and hasEntrance and #cells >= MKT_CONFIGS.MinRoomCells then
			table.insert(rooms, {
				Level = Level,
				Cells = cells,
				Size = #cells,
				Type = nil,
				Lit = 0,
				LitCells = {},
			})
		end
	end

	return rooms
end

-- find every house: rooms joined by doors, or stacked on top of each other
-- returns the houses (sorted by id) and a map of level cell -> house id
function HouseUtils.GetHouses(Land: DAT_TYPES.LandData): ({DAT_TYPES.HouseInfo}, {[string]: string})
	local stairwells = FUR_UTILS.GetStairwells(Land)
	local rooms: {DAT_TYPES.RoomData} = {}
	local cellRoom: {[string]: number} = {}

	for level = 1, LND_CONFIGS.MaxLevels do
		for _, room in HouseUtils.GetRooms(Land, level, stairwells) do
			table.insert(rooms, room)

			for _, cell in room.Cells do
				cellRoom[GRD_UTILS.LevelCell(level, cell)] = #rooms
			end
		end
	end

	-- union-find over rooms
	local parent: {number} = {}

	for index in rooms do
		parent[index] = index
	end

	local function find(Index: number): number
		while parent[Index] ~= Index do
			parent[Index] = parent[parent[Index]]
			Index = parent[Index]
		end

		return Index
	end

	local function union(A: number, B: number)
		local rootA, rootB = find(A), find(B)

		if rootA ~= rootB then
			parent[rootB] = rootA
		end
	end

	for index, room in rooms do
		local levelData = HouseUtils.GetLevel(Land, room.Level)

		for _, cell in room.Cells do
			-- through doors
			local x, z = GRD_UTILS.ParseCellKey(cell)

			for _, edge in GRD_UTILS.CellEdges(x, z) do
				local wall = levelData.Walls[edge]

				if wall and wall.Kind == 'Door' then
					local a, b = GRD_UTILS.EdgeCells(edge)
					local other = if a == cell then b else a
					local otherRoom = cellRoom[GRD_UTILS.LevelCell(room.Level, other)]

					if otherRoom then
						union(index, otherRoom)
					end
				end
			end

			-- stacked floors
			if room.Level > 1 then
				local below = cellRoom[GRD_UTILS.LevelCell(room.Level - 1, cell)]

				if below then
					union(index, below)
				end
			end
		end
	end

	-- room types from key furniture, and which lights are in which room
	local votes: {[number]: {[CFG_TYPES.RoomType]: number}} = {}
	local roomLights: {[number]: {DAT_TYPES.FurnitureData}} = {}
	local itemRoom: {[string]: number} = {}

	for id, item in Land.Furniture do
		local config = FUR_CONFIGS.Items[item.Name]
		local index = cellRoom[GRD_UTILS.LevelCell(item.Level, GRD_UTILS.LocalToCell(item.X, item.Z))]

		if not config or not index then
			continue
		end

		itemRoom[id] = index

		if config.Room then
			votes[index] = votes[index] or {}
			votes[index][config.Room] = (votes[index][config.Room] or 0) + 1
		end

		if config.LightRange then
			roomLights[index] = roomLights[index] or {}
			table.insert(roomLights[index], item)
		end
	end

	local cellSize = BLD_CONFIGS.CellSize

	for index, room in rooms do
		-- type
		local best: CFG_TYPES.RoomType? = nil
		local bestVotes = 0

		for roomType, count in votes[index] or {} do
			local better = count > bestVotes
				or (count == bestVotes and best ~= nil
					and MKT_CONFIGS.RoomTypes[roomType].Order < MKT_CONFIGS.RoomTypes[best].Order)

			if better then
				best = roomType
				bestVotes = count
			end
		end

		room.Type = best

		-- lighting: lamps light tiles in range, windows light the tile next to them
		local levelData = HouseUtils.GetLevel(Land, room.Level)
		local lights = roomLights[index] or {}
		local lit = 0

		for _, cell in room.Cells do
			local x, z = GRD_UTILS.ParseCellKey(cell)
			local centerX, centerZ = (x + 0.5) * cellSize, (z + 0.5) * cellSize
			local isLit = false

			for _, edge in GRD_UTILS.CellEdges(x, z) do
				local wall = levelData.Walls[edge]

				if wall and wall.Kind == 'Window' then
					isLit = true
					break
				end
			end

			if not isLit then
				for _, item in lights do
					local range = FUR_CONFIGS.Items[item.Name].LightRange or 0
					local dx, dz = item.X - centerX, item.Z - centerZ

					if dx * dx + dz * dz <= range * range then
						isLit = true
						break
					end
				end
			end

			if isLit then
				lit += 1
				room.LitCells[cell] = true
			end
		end

		room.Lit = lit
	end

	-- group rooms into houses
	local groups: {[number]: Group} = {}

	for index, room in rooms do
		local root = find(index)
		local group = groups[root]

		if not group then
			group = {Rooms = {}, RoomIndexes = {}, Cells = {}, Id = ''}
			groups[root] = group
		end

		assert(group)

		table.insert(group.Rooms, room)
		group.RoomIndexes[index] = true

		for _, cell in room.Cells do
			local levelCell = GRD_UTILS.LevelCell(room.Level, cell)
			group.Cells[levelCell] = true

			if group.Id == '' or levelCell < group.Id then
				group.Id = levelCell
			end
		end
	end

	local houses: {DAT_TYPES.HouseInfo} = {}
	local cellHouse: {[string]: string} = {}

	for _, group in groups do
		local total = 0
		local cellCount, litCount = 0, 0
		local sumX, sumZ, topLevel = 0, 0, 1
		local countedWalls: {[string]: boolean} = {}

		-- walls and floors around / under every tile
		for levelCell in group.Cells do
			local level, cell = GRD_UTILS.ParseLevelCell(levelCell)
			local levelData = HouseUtils.GetLevel(Land, level)
			local x, z = GRD_UTILS.ParseCellKey(cell)

			cellCount += 1
			sumX += (x + 0.5) * cellSize
			sumZ += (z + 0.5) * cellSize
			topLevel = math.max(topLevel, level)
			cellHouse[levelCell] = group.Id

			local style = levelData.Floors[cell]
			local floorConfig = style and BLD_CONFIGS.FloorStyles[style]

			if floorConfig then
				total += floorConfig.Value
			end

			for _, edge in GRD_UTILS.CellEdges(x, z) do
				local wall = levelData.Walls[edge]
				local wallKey = `{level}|{edge}`

				if wall and not countedWalls[wallKey] then
					countedWalls[wallKey] = true
					total += BLD_UTILS.GetWallValue(wall)
				end
			end
		end

		-- furniture
		for id, index in itemRoom do
			if group.RoomIndexes[index] then
				local item = Land.Furniture[id]
				local config = FUR_CONFIGS.Items[item.Name]

				total += config.Price * (config.ValueRate or MKT_CONFIGS.FurnitureValueRate)
			end
		end

		-- room bonuses (biggest rooms of each type count first)
		local sorted = table.clone(group.Rooms)
		local counted: {[CFG_TYPES.RoomType]: number} = {}

		table.sort(sorted, function(A, B)
			return A.Size > B.Size
		end)

		for _, room in sorted do
			litCount += room.Lit

			local roomType = room.Type

			if not roomType then
				continue
			end

			local config = MKT_CONFIGS.RoomTypes[roomType]
			local count = counted[roomType] or 0

			if count < MKT_CONFIGS.MaxBonusRoomsPerType then
				counted[roomType] = count + 1
				total += config.Bonus * math.min(1, room.Size / config.IdealCells)
			end
		end

		-- requirements
		local missing: {CFG_TYPES.RoomType} = {}

		for _, roomType in MKT_CONFIGS.RequiredRooms do
			if not counted[roomType] then
				table.insert(missing, roomType)
			end
		end

		local complete = true

		for _, roomType in MKT_CONFIGS.CompleteRooms do
			if not counted[roomType] then
				complete = false
			end
		end

		-- lighting and completeness
		local litFraction = if cellCount > 0 then litCount / cellCount else 0
		local minLight = MKT_CONFIGS.MinLightFactor

		total *= minLight + (1 - minLight) * litFraction

		if complete then
			total *= MKT_CONFIGS.CompleteMultiplier
		end

		table.insert(houses, {
			Id = group.Id,
			Rooms = group.Rooms,
			Cells = group.Cells,
			CellCount = cellCount,
			LitFraction = litFraction,
			DirtCount = 0,
			Cleanliness = 1,
			BaseValue = math.floor(total),
			Value = math.floor(total),
			Livable = #missing == 0,
			Complete = complete,
			Missing = missing,
			CenterX = sumX / math.max(1, cellCount),
			CenterZ = sumZ / math.max(1, cellCount),
			TopLevel = topLevel,
		})
	end

	-- dirt lowers value
	local houseById: {[string]: DAT_TYPES.HouseInfo} = {}

	for _, house in houses do
		houseById[house.Id] = house
	end

	for _, dirt in Land.Dirt do
		local houseId = cellHouse[GRD_UTILS.LevelCell(dirt.Level, dirt.Cell)]
		local house = houseId and houseById[houseId]

		if house then
			house.DirtCount += 1
		end
	end

	for _, house in houses do
		house.Cleanliness = HouseUtils.GetCleanFactor(house.DirtCount)
		house.Value = math.floor(house.BaseValue * house.Cleanliness)
	end

	table.sort(houses, function(A, B)
		return A.Id < B.Id
	end)

	return houses, cellHouse
end

-- everything that belongs to a house (walls shared with another house are kept)
function HouseUtils.GetHousePieces(Land: DAT_TYPES.LandData, House: DAT_TYPES.HouseInfo, CellHouse: {[string]: string}): HousePieces
	local pieces: HousePieces = {Walls = {}, Floors = {}, Furniture = {}, Dirt = {}}
	local seenWalls: {[string]: boolean} = {}

	for levelCell in House.Cells do
		local level, cell = GRD_UTILS.ParseLevelCell(levelCell)
		local levelData = HouseUtils.GetLevel(Land, level)
		local x, z = GRD_UTILS.ParseCellKey(cell)

		if levelData.Floors[cell] then
			table.insert(pieces.Floors, {Level = level, Key = cell})
		end

		for _, edge in GRD_UTILS.CellEdges(x, z) do
			local wallKey = `{level}|{edge}`

			if not levelData.Walls[edge] or seenWalls[wallKey] then
				continue
			end

			seenWalls[wallKey] = true

			local a, b = GRD_UTILS.EdgeCells(edge)
			local other = if a == cell then b else a
			local otherHouse = CellHouse[GRD_UTILS.LevelCell(level, other)]

			if not otherHouse or otherHouse == House.Id then
				table.insert(pieces.Walls, {Level = level, Key = edge})
			end
		end
	end

	for id, item in Land.Furniture do
		if House.Cells[GRD_UTILS.LevelCell(item.Level, GRD_UTILS.LocalToCell(item.X, item.Z))] then
			table.insert(pieces.Furniture, id)
		end
	end

	for id, dirt in Land.Dirt do
		if House.Cells[GRD_UTILS.LevelCell(dirt.Level, dirt.Cell)] then
			table.insert(pieces.Dirt, id)
		end
	end

	return pieces
end

-- tile columns ("x_z", every floor) covered by a list of level cells
function HouseUtils.GetColumns(LevelCells: {string}): {[string]: boolean}
	local columns: {[string]: boolean} = {}

	for _, levelCell in LevelCells do
		local _, cell = GRD_UTILS.ParseLevelCell(levelCell)
		columns[cell] = true
	end

	return columns
end

-- turn a house's cell set into a sorted list (for saving)
function HouseUtils.GetCellList(House: DAT_TYPES.HouseInfo): {string}
	local list = {}

	for levelCell in House.Cells do
		table.insert(list, levelCell)
	end

	table.sort(list)

	return list
end

return HouseUtils
