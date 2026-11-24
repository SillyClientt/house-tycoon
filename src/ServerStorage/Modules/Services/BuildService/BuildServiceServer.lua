--!strict
local BuildServiceServer = {}

local PLS = game:GetService('Players')
local RPS = game:GetService('ReplicatedStorage')
local SSG = game:GetService('ServerStorage')

local DAT_Server = require(RPS.Modules.Packages.DataService).server
local BLD_CONFIGS = require(RPS.Modules.Configs.BuildConfigs)
local GRD_UTILS = require(RPS.Modules.Utils.GridUtils)
local BLD_UTILS = require(RPS.Modules.Utils.BuildUtils)
local FUR_UTILS = require(RPS.Modules.Utils.FurnitureUtils)
local HSE_UTILS = require(RPS.Modules.Utils.HouseUtils)
local LND_UTILS = require(RPS.Modules.Utils.LandUtils)
local DAT_TYPES = require(RPS.Modules.Types.DataTypes)
local HSE_Server = require(SSG.Modules.Services.HouseService.HouseServiceServer)
local ECN_Server = require(SSG.Modules.Services.EconomyService.EconomyServiceServer)
local ATC_SSignals = require(SSG.Modules.Services.AnalyticsService.AnalyticsServerSignals)

local BLD_HISTORY = require(script.Parent.BuildHistory)

local remotes = RPS.Remotes.BuildService

local REQUEST_COOLDOWN = 0.1
local MAX_WALLS_PER_LEVEL = 2500
local RED = Color3.fromRGB(235, 80, 80)

local lastRequest: {[Player]: number} = {}

-- send a message to the player
local function notify(Player: Player, Text: string)
	RPS.Remotes.InterfaceService.Notify:FireClient(Player, Text, RED)
end

-- check request (rate limit + land loaded)
local function checkRequest(Player: Player): boolean
	local now = os.clock()

	if now - (lastRequest[Player] or 0) < REQUEST_COOLDOWN then
		return false
	end

	lastRequest[Player] = now

	return HSE_Server:IsReady(Player)
end

-- check a value is a whole number
local function isInteger(Value: any): boolean
	return typeof(Value) == 'number' and Value == Value and Value % 1 == 0 and math.abs(Value) < 10000
end

-- check a floor number is unlocked
local function isLevelUnlocked(Player: Player, Level: any): boolean
	return isInteger(Level) and Level >= 1 and Level <= DAT_Server:get(Player, 'Levels')
end

-- count the keys in a table
local function count(Dictionary: {[string]: any}): number
	local total = 0

	for _ in Dictionary do
		total += 1
	end

	return total
end

-- data path of a wall or floor
local function piecePath(Kind: 'Wall' | 'Floor', Level: number, Key: string): {string}
	return {'Land', 'Levels', GRD_UTILS.LevelKey(Level), if Kind == 'Wall' then 'Walls' else 'Floors', Key}
end

-- write a wall / floor / furniture value and redraw it
local function applyChange(Player: Player, Change: BLD_HISTORY.Change, Value: any)
	if Change.Kind == 'Furniture' then
		DAT_Server:set(Player, {'Land', 'Furniture', Change.Key}, if Value then table.clone(Value) else nil)
		HSE_Server:RenderFurniture(Player, Change.Key)
	elseif Change.Kind == 'Wall' then
		DAT_Server:set(Player, piecePath('Wall', Change.Level, Change.Key), if Value then table.clone(Value) else nil)
		HSE_Server:RenderWall(Player, Change.Level, Change.Key)
	else
		DAT_Server:set(Player, piecePath('Floor', Change.Level, Change.Key), Value)
		HSE_Server:RenderFloor(Player, Change.Level, Change.Key)
	end
end

-- pay for a list of changes, apply them and remember them for undo
local function commit(Player: Player, Changes: {BLD_HISTORY.Change}, Cost: number, Refund: number, Tag: string): boolean
	if #Changes == 0 then
		return false
	end

	if not ECN_Server:TryDeduct(Player, Cost, Tag) then
		return false
	end

	if Refund > 0 then
		ECN_Server:Reward(Player, {Cash = Refund}, 'Refund')
	end

	for _, change in Changes do
		applyChange(Player, change, change.After)
	end

	BLD_HISTORY.Record(Player, Changes, Cost - Refund)

	return true
end

-- check a wall line can be built on (owned, not locked, supported upstairs)
local function checkEdge(Player: Player, Land: DAT_TYPES.LandData, Parcels: {[string]: boolean}, Level: number, Edge: string): string?
	if not LND_UTILS.IsEdgeOwned(Parcels, Edge) then
		return 'Buy this land first'
	end

	if HSE_Server:IsEdgeLocked(Player, Edge) then
		return 'locked'
	end

	-- walls upstairs need a floor next to them (here or below)
	if Level > 1 then
		local levelData = HSE_UTILS.GetLevel(Land, Level)
		local belowData = HSE_UTILS.GetLevel(Land, Level - 1)
		local a, b = GRD_UTILS.EdgeCells(Edge)

		if not (levelData.Floors[a] or levelData.Floors[b] or belowData.Floors[a] or belowData.Floors[b]) then
			return 'Walls upstairs need a floor next to them'
		end
	end

	return nil
end

-- tell the player why a check failed
local function reject(Player: Player, Reason: string)
	if Reason == 'locked' then
		HSE_Server:NotifyLocked(Player)
	else
		notify(Player, Reason)
	end
end

-- initialize build service server-side
function BuildServiceServer:Init()
	remotes.PlaceWalls.OnServerEvent:Connect(function(Player, Level, Kind, Style, AX, AZ, BX, BZ)
		BuildServiceServer:PlaceWalls(Player, Level, Kind, Style, AX, AZ, BX, BZ)
	end)

	remotes.PlaceFloors.OnServerEvent:Connect(function(Player, Level, Style, AX, AZ, BX, BZ)
		BuildServiceServer:PlaceFloors(Player, Level, Style, AX, AZ, BX, BZ)
	end)

	remotes.PlaceRoom.OnServerEvent:Connect(function(Player, Level, WallStyle, FloorStyle, AX, AZ, BX, BZ)
		BuildServiceServer:PlaceRoom(Player, Level, WallStyle, FloorStyle, AX, AZ, BX, BZ)
	end)

	remotes.RemovePiece.OnServerEvent:Connect(function(Player, Level, Piece, Key)
		BuildServiceServer:RemovePiece(Player, Level, Piece, Key)
	end)

	remotes.Undo.OnServerEvent:Connect(function(Player)
		BuildServiceServer:Undo(Player)
	end)

	PLS.PlayerRemoving:Connect(function(Player)
		lastRequest[Player] = nil
	end)
end

-- place a straight line of walls, windows or doors between two grid points
-- (also used to turn one wall into a door/window, or to repaint it)
function BuildServiceServer:PlaceWalls(Player: Player, Level: any, Kind: any, Style: any, AX: any, AZ: any, BX: any, BZ: any)
	if typeof(Kind) ~= 'string' or typeof(Style) ~= 'string' then
		return
	end

	if not isInteger(AX) or not isInteger(AZ) or not isInteger(BX) or not isInteger(BZ) then
		return
	end

	if not BLD_CONFIGS.WallKinds[Kind] or not BLD_CONFIGS.WallStyles[Style] then
		return
	end

	if not checkRequest(Player) or not isLevelUnlocked(Player, Level) then
		return
	end

	local edges = GRD_UTILS.EdgesBetween(AX, AZ, BX, BZ)

	if #edges == 0 or #edges > BLD_CONFIGS.MaxDragCells then
		return
	end

	local land = HSE_Server:GetLand(Player)
	local parcels = DAT_Server:get(Player, 'Parcels')
	local levelData = HSE_UTILS.GetLevel(land, Level)
	local newWall: DAT_TYPES.WallData = {Kind = Kind :: any, Style = Style}

	local changes: {BLD_HISTORY.Change} = {}
	local cost, refund = 0, 0

	for _, edge in edges do
		local problem = checkEdge(Player, land, parcels, Level, edge)

		if problem then
			reject(Player, problem)
			return
		end

		local old = levelData.Walls[edge]

		if old and old.Kind == newWall.Kind and old.Style == newWall.Style then
			continue
		end

		table.insert(changes, {Kind = 'Wall', Level = Level, Key = edge, Before = old and table.clone(old), After = newWall})
		cost += BLD_UTILS.GetWallCost(newWall)

		if old then
			refund += math.floor(BLD_UTILS.GetWallCost(old) * BLD_CONFIGS.RefundRate)
		end
	end

	if count(levelData.Walls) + #changes > MAX_WALLS_PER_LEVEL then
		notify(Player, 'Wall limit reached')
		return
	end

	if commit(Player, changes, cost, refund, 'BuildWall') then
		ATC_SSignals.LogJourney:Fire(Player, 'PlacedWall')
	end
end

-- work out the floor changes for a set of cells (nil + reason when not allowed)
local function planFloors(Player: Player, Land: DAT_TYPES.LandData, Level: number, Style: string, Cells: {string}): ({BLD_HISTORY.Change}?, number, number, string?)
	local parcels = DAT_Server:get(Player, 'Parcels')
	local levelData = HSE_UTILS.GetLevel(Land, Level)
	local belowData = HSE_UTILS.GetLevel(Land, Level - 1)
	local stairwells = FUR_UTILS.GetStairwells(Land)
	local styleConfig = BLD_CONFIGS.FloorStyles[Style]

	local changes: {BLD_HISTORY.Change} = {}
	local cost, refund = 0, 0

	for _, cell in Cells do
		if not LND_UTILS.IsCellOwned(parcels, cell) then
			return nil, 0, 0, 'Buy this land first'
		end

		if HSE_Server:IsColumnLocked(Player, cell) then
			return nil, 0, 0, 'locked'
		end

		-- stair openings stay open
		if stairwells[GRD_UTILS.LevelCell(Level, cell)] then
			continue
		end

		if Level > 1 and not belowData.Floors[cell] then
			return nil, 0, 0, 'Upstairs floors need a floor below them'
		end

		local old = levelData.Floors[cell]

		if old == Style then
			continue
		end

		table.insert(changes, {Kind = 'Floor', Level = Level, Key = cell, Before = old, After = Style})
		cost += styleConfig.Cost

		local oldConfig = old and BLD_CONFIGS.FloorStyles[old]

		if oldConfig then
			refund += math.floor(oldConfig.Cost * BLD_CONFIGS.RefundRate)
		end
	end

	return changes, cost, refund, nil
end

-- fill a rectangle of cells with floor (also used to repaint one tile)
function BuildServiceServer:PlaceFloors(Player: Player, Level: any, Style: any, AX: any, AZ: any, BX: any, BZ: any)
	if typeof(Style) ~= 'string' or not BLD_CONFIGS.FloorStyles[Style] then
		return
	end

	if not isInteger(AX) or not isInteger(AZ) or not isInteger(BX) or not isInteger(BZ) then
		return
	end

	local maxCells = BLD_CONFIGS.MaxDragCells

	if math.abs(AX - BX) >= maxCells or math.abs(AZ - BZ) >= maxCells then
		return
	end

	if not checkRequest(Player) or not isLevelUnlocked(Player, Level) then
		return
	end

	local land = HSE_Server:GetLand(Player)
	local changes, cost, refund, problem = planFloors(Player, land, Level, Style, GRD_UTILS.CellsBetween(AX, AZ, BX, BZ))

	if problem or not changes then
		reject(Player, problem or 'Can\'t build there')
		return
	end

	if commit(Player, changes, cost, refund, 'BuildFloor') then
		ATC_SSignals.LogJourney:Fire(Player, 'PlacedFloor')
	end
end

-- build a whole room: walls around the rectangle, floor inside and a door at the front
function BuildServiceServer:PlaceRoom(Player: Player, Level: any, WallStyle: any, FloorStyle: any, AX: any, AZ: any, BX: any, BZ: any)
	if typeof(WallStyle) ~= 'string' or not BLD_CONFIGS.WallStyles[WallStyle] then
		return
	end

	if typeof(FloorStyle) ~= 'string' or not BLD_CONFIGS.FloorStyles[FloorStyle] then
		return
	end

	if not isInteger(AX) or not isInteger(AZ) or not isInteger(BX) or not isInteger(BZ) then
		return
	end

	local minX, maxX = math.min(AX, BX), math.max(AX, BX)
	local minZ, maxZ = math.min(AZ, BZ), math.max(AZ, BZ)
	local maxCells = BLD_CONFIGS.MaxDragCells

	if maxX - minX >= maxCells or maxZ - minZ >= maxCells then
		return
	end

	if maxX == minX and maxZ == minZ then
		notify(Player, 'Drag out a room at least 2 tiles big')
		return
	end

	if not checkRequest(Player) or not isLevelUnlocked(Player, Level) then
		return
	end

	local land = HSE_Server:GetLand(Player)
	local parcels = DAT_Server:get(Player, 'Parcels')
	local levelData = HSE_UTILS.GetLevel(land, Level)

	-- floor first (also checks the land and upstairs support)
	local changes, cost, refund, problem = planFloors(Player, land, Level, FloorStyle, GRD_UTILS.CellsBetween(minX, minZ, maxX, maxZ))

	if problem or not changes then
		reject(Player, problem or 'Can\'t build there')
		return
	end

	assert(changes)

	-- walls all the way round (existing walls, doors and windows are kept)
	local perimeter: {string} = {}

	for x = minX, maxX do
		table.insert(perimeter, GRD_UTILS.EdgeKey('X', x, minZ))
		table.insert(perimeter, GRD_UTILS.EdgeKey('X', x, maxZ + 1))
	end

	for z = minZ, maxZ do
		table.insert(perimeter, GRD_UTILS.EdgeKey('Z', minX, z))
		table.insert(perimeter, GRD_UTILS.EdgeKey('Z', maxX + 1, z))
	end

	local hasDoor = false

	for _, edge in perimeter do
		local old = levelData.Walls[edge]

		if old and old.Kind == 'Door' then
			hasDoor = true
		end
	end

	-- the door goes in the middle of the side facing the road (+Z)
	local doorEdge = if hasDoor then nil else GRD_UTILS.EdgeKey('X', math.floor((minX + maxX) / 2), maxZ + 1)

	for _, edge in perimeter do
		local old = levelData.Walls[edge]
		local wantDoor = edge == doorEdge

		if old and not wantDoor then
			continue
		end

		local edgeProblem = checkEdge(Player, land, parcels, Level, edge)

		if edgeProblem and edgeProblem ~= 'Walls upstairs need a floor next to them' then
			reject(Player, edgeProblem)
			return
		end

		local newWall: DAT_TYPES.WallData = {Kind = if wantDoor then 'Door' else 'Wall', Style = if old then old.Style else WallStyle}

		table.insert(changes, {Kind = 'Wall', Level = Level, Key = edge, Before = old and table.clone(old), After = newWall})
		cost += BLD_UTILS.GetWallCost(newWall)

		if old then
			refund += math.floor(BLD_UTILS.GetWallCost(old) * BLD_CONFIGS.RefundRate)
		end
	end

	if commit(Player, changes, cost, refund, 'BuildRoom') then
		ATC_SSignals.LogJourney:Fire(Player, 'PlacedRoom')
	end
end

-- check nothing rests on a floor tile (floor above, furniture on it)
local function getFloorBlocker(Land: DAT_TYPES.LandData, Level: number, Key: string): string?
	if HSE_UTILS.GetLevel(Land, Level + 1).Floors[Key] then
		return 'Remove the floor above first'
	end

	for _, item in Land.Furniture do
		if item.Level == Level then
			for _, cell in FUR_UTILS.GetCoveredCells(item.Name, item.X, item.Z, item.Rotation) do
				if cell == Key then
					return 'Move the furniture off this tile first'
				end
			end
		end
	end

	return nil
end

-- remove one wall or floor piece and refund part of its cost
function BuildServiceServer:RemovePiece(Player: Player, Level: any, Piece: any, Key: any)
	if typeof(Key) ~= 'string' or (Piece ~= 'Wall' and Piece ~= 'Floor') then
		return
	end

	if not checkRequest(Player) or not isLevelUnlocked(Player, Level) then
		return
	end

	local land = HSE_Server:GetLand(Player)
	local levelData = HSE_UTILS.GetLevel(land, Level)

	if Piece == 'Wall' then
		local wall = levelData.Walls[Key]

		if not wall then
			return
		end

		if HSE_Server:IsEdgeLocked(Player, Key) then
			HSE_Server:NotifyLocked(Player)
			return
		end

		local refund = math.floor(BLD_UTILS.GetWallCost(wall) * BLD_CONFIGS.RefundRate)

		commit(Player, {{Kind = 'Wall', Level = Level, Key = Key, Before = table.clone(wall), After = nil}}, 0, refund, 'Remove')
	else
		local style = levelData.Floors[Key]
		local config = style and BLD_CONFIGS.FloorStyles[style]

		if not config then
			return
		end

		if HSE_Server:IsColumnLocked(Player, Key) then
			HSE_Server:NotifyLocked(Player)
			return
		end

		local blocker = getFloorBlocker(land, Level, Key)

		if blocker then
			notify(Player, blocker)
			return
		end

		local refund = math.floor(config.Cost * BLD_CONFIGS.RefundRate)

		commit(Player, {{Kind = 'Floor', Level = Level, Key = Key, Before = style, After = nil}}, 0, refund, 'Remove')

		-- dirt can't float in the air
		for id, dirt in land.Dirt do
			if dirt.Level == Level and dirt.Cell == Key then
				DAT_Server:set(Player, {'Land', 'Dirt', id}, nil)
				HSE_Server:RenderDirt(Player, id)
			end
		end
	end
end

-- check a change touches nothing that is locked (on the market or rented)
local function isChangeLocked(Player: Player, Change: BLD_HISTORY.Change): boolean
	if Change.Kind == 'Wall' then
		return HSE_Server:IsEdgeLocked(Player, Change.Key)
	elseif Change.Kind == 'Floor' then
		return HSE_Server:IsColumnLocked(Player, Change.Key)
	end

	for _, item in {Change.Before, Change.After} do
		if item then
			for _, cell in FUR_UTILS.GetCoveredCells(item.Name, item.X, item.Z, item.Rotation) do
				if HSE_Server:IsColumnLocked(Player, cell) then
					return true
				end
			end
		end
	end

	return false
end

-- undo the last build action (cash goes back exactly as it was)
function BuildServiceServer:Undo(Player: Player)
	if not checkRequest(Player) then
		return
	end

	local action = BLD_HISTORY.Pop(Player)

	if not action then
		notify(Player, 'Nothing to undo')
		return
	end

	assert(action)

	for _, change in action.Changes do
		if isChangeLocked(Player, change) then
			HSE_Server:NotifyLocked(Player)
			return
		end
	end

	-- give back what it cost, or take back what it refunded
	if action.Spent < 0 then
		if not ECN_Server:TryDeduct(Player, -action.Spent, 'Undo') then
			BLD_HISTORY.Push(Player, action)
			return
		end
	elseif action.Spent > 0 then
		ECN_Server:Reward(Player, {Cash = action.Spent}, 'Refund')
	end

	for index = #action.Changes, 1, -1 do
		local change = action.Changes[index]
		applyChange(Player, change, change.Before)
	end
end

-- let other services add to the undo history (furniture)
function BuildServiceServer:Record(Player: Player, Changes: {BLD_HISTORY.Change}, Spent: number)
	BLD_HISTORY.Record(Player, Changes, Spent)
end

return BuildServiceServer
