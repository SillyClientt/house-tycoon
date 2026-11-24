--!strict
local BuildServiceClient = {}

local RPS = game:GetService('ReplicatedStorage')
local WKS = game:GetService('Workspace')
local UIS = game:GetService('UserInputService')
local RNS = game:GetService('RunService')

local BLD_CSignals = require(script.Parent.BuildClientSignals)
local DAT_Client = require(RPS.Modules.Packages.DataService).client
local PLT_Client = require(RPS.Modules.Services.PlotService.PlotServiceClient)
local BLD_CONFIGS = require(RPS.Modules.Configs.BuildConfigs)
local GRD_UTILS = require(RPS.Modules.Utils.GridUtils)
local BLD_UTILS = require(RPS.Modules.Utils.BuildUtils)
local HSE_UTILS = require(RPS.Modules.Utils.HouseUtils)
local LND_UTILS = require(RPS.Modules.Utils.LandUtils)
local INP_UTILS = require(RPS.Modules.Utils.InputUtils)
local DAT_TYPES = require(RPS.Modules.Types.DataTypes)

local remotes = RPS.Remotes.BuildService
local furnitureRemotes = RPS.Remotes.FurnitureService

local GHOST_COLOR = Color3.fromRGB(120, 200, 255)
local GOOD_COLOR = Color3.fromRGB(90, 210, 120)
local BAD_COLOR = Color3.fromRGB(235, 80, 80)
local PAINT_INTERVAL = 0.12

type BuildMode = BLD_CSignals.BuildMode

-- tools that drag out a shape on the grid
local DRAG_TOOLS: {[string]: boolean} = {Room = true, Wall = true, Floor = true}

-- tools that click on existing pieces
local CLICK_TOOLS: {[string]: boolean} = {Door = true, Window = true, Paint = true, Erase = true}

local mode: BuildMode = 'None'
local level = 1
local wallStyle = 'Plaster'
local floorStyle = 'Wood'
local paintTarget = 'Wall'
local paintStyle = 'Plaster'

local dragging = false
local dragStartX, dragStartZ = 0, 0
local dragEndX, dragEndZ = 0, 0
local previewKey = ''

local ghosts: Folder
local marker: Part
local hover: Highlight
local hoverTarget: Instance?
local lastActed: Instance?
local lastActTime = 0

-- check the active tool belongs to this service
local function isBuildTool(): boolean
	return DRAG_TOOLS[mode] == true or CLICK_TOOLS[mode] == true
end

-- remove every preview piece
local function clearPreview()
	ghosts:ClearAllChildren()
	previewKey = ''
	marker.Parent = nil
	hover.Adornee = nil
	hoverTarget = nil
end

-- the land / level data the player is editing
local function getLevelData(): DAT_TYPES.LevelData
	return HSE_UTILS.GetLevel(DAT_Client:get('Land'), level)
end

-- initialize build service client-side
function BuildServiceClient:Init()
	local previewFolder = Instance.new('Folder')
	previewFolder.Name = 'BuildPreview'
	previewFolder.Parent = WKS

	ghosts = Instance.new('Folder')
	ghosts.Name = 'Ghosts'
	ghosts.Parent = previewFolder

	marker = Instance.new('Part')
	marker.Name = 'Marker'
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.CastShadow = false
	marker.Material = Enum.Material.Neon
	marker.Color = GHOST_COLOR
	marker.Transparency = 0.35

	hover = Instance.new('Highlight')
	hover.FillTransparency = 0.45
	hover.DepthMode = Enum.HighlightDepthMode.Occluded
	hover.Parent = previewFolder

	BLD_CSignals.ModeRequested:Connect(function(Mode, OptionA, OptionB)
		BuildServiceClient:SetMode(Mode, OptionA, OptionB)
	end)

	RNS.RenderStepped:Connect(function()
		BuildServiceClient:Update()
	end)

	UIS.InputBegan:Connect(function(Input, Processed)
		if Processed then
			return
		end

		local ctrl = UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.RightControl)

		if INP_UTILS.IsPress(Input) then
			BuildServiceClient:Press()
		elseif mode == 'None' then
			return
		elseif Input.KeyCode == Enum.KeyCode.Z and ctrl then
			BuildServiceClient:Undo()
		elseif Input.KeyCode == Enum.KeyCode.PageUp then
			BuildServiceClient:SetLevel(level + 1)
		elseif Input.KeyCode == Enum.KeyCode.PageDown then
			BuildServiceClient:SetLevel(level - 1)
		elseif Input.KeyCode == Enum.KeyCode.Escape and isBuildTool() then
			BuildServiceClient:SetMode('None')
		end
	end)

	UIS.InputEnded:Connect(function(Input)
		if INP_UTILS.IsPress(Input) then
			BuildServiceClient:Release()
		end
	end)
end

-- get the active tool
function BuildServiceClient:GetMode(): BuildMode
	return mode
end

-- switch tool (every service listens to ModeChanged)
function BuildServiceClient:SetMode(Mode: BuildMode, OptionA: string?, OptionB: string?)
	dragging = false
	clearPreview()

	if Mode == 'Room' then
		wallStyle = if OptionA and BLD_CONFIGS.WallStyles[OptionA] then OptionA else wallStyle
		floorStyle = if OptionB and BLD_CONFIGS.FloorStyles[OptionB] then OptionB else floorStyle
	elseif Mode == 'Wall' then
		wallStyle = if OptionA and BLD_CONFIGS.WallStyles[OptionA] then OptionA else wallStyle
	elseif Mode == 'Floor' then
		floorStyle = if OptionA and BLD_CONFIGS.FloorStyles[OptionA] then OptionA else floorStyle
	elseif Mode == 'Paint' then
		paintTarget = if OptionA == 'Floor' then 'Floor' else 'Wall'

		local styles: {[string]: any} = if paintTarget == 'Floor' then BLD_CONFIGS.FloorStyles else BLD_CONFIGS.WallStyles

		if OptionB and styles[OptionB] then
			paintStyle = OptionB
		elseif not styles[paintStyle] then
			paintStyle = if paintTarget == 'Floor' then floorStyle else wallStyle
		end
	end

	mode = Mode

	BLD_CSignals.CostChanged:Fire(nil)
	BLD_CSignals.ModeChanged:Fire(Mode, OptionA, OptionB)
end

-- current picks (for the UI)
function BuildServiceClient:GetStyles(): (string, string, string, string)
	return wallStyle, floorStyle, paintTarget, paintStyle
end

-- get the floor being built on
function BuildServiceClient:GetLevel(): number
	return level
end

-- change the floor being built on (only unlocked floors)
function BuildServiceClient:SetLevel(Level: number)
	local newLevel = math.clamp(Level, 1, DAT_Client:get('Levels'))

	if newLevel == level then
		return
	end

	dragging = false
	clearPreview()

	level = newLevel
	BLD_CSignals.LevelChanged:Fire(level)
end

-- undo the last build action
function BuildServiceClient:Undo()
	remotes.Undo:FireServer()
end

-- grid point / cell under the pointer on the current floor
local function pointerHit(): (Vector3?, Vector3?)
	local origin = PLT_Client:GetOrigin()

	if not origin then
		return nil, nil
	end

	return origin, INP_UTILS.HitPlane(origin.Y + GRD_UTILS.LevelHeight(level))
end

-- follow the pointer every frame
function BuildServiceClient:Update()
	if not isBuildTool() or not PLT_Client:IsReady() then
		return
	end

	if CLICK_TOOLS[mode] then
		BuildServiceClient:UpdateHover()
		return
	end

	local origin, hit = pointerHit()

	if not origin or not hit then
		marker.Parent = nil
		return
	end

	local size = GRD_UTILS.LandCells
	local maxCells = BLD_CONFIGS.MaxDragCells
	local cellSize = BLD_CONFIGS.CellSize

	if mode == 'Wall' then
		local px, pz = GRD_UTILS.WorldToPoint(origin, hit)
		px, pz = math.clamp(px, 0, size), math.clamp(pz, 0, size)

		if dragging then
			-- walls only go in straight lines, along the axis moved most
			local dx, dz = px - dragStartX, pz - dragStartZ

			if math.abs(dx) >= math.abs(dz) then
				px, pz = dragStartX + math.clamp(dx, -maxCells, maxCells), dragStartZ
			else
				px, pz = dragStartX, dragStartZ + math.clamp(dz, -maxCells, maxCells)
			end

			dragEndX, dragEndZ = px, pz
			BuildServiceClient:DrawWallPreview(origin)
		end

		marker.Size = Vector3.new(1.2, 1.2, 1.2)
		marker.Shape = Enum.PartType.Ball
		marker.CFrame = CFrame.new(GRD_UTILS.PointToWorld(origin, px, pz, level) + Vector3.new(0, 0.8, 0))
	else
		local cx, cz = GRD_UTILS.WorldToCell(origin, hit)
		cx, cz = math.clamp(cx, 0, size - 1), math.clamp(cz, 0, size - 1)

		if dragging then
			cx = math.clamp(cx, dragStartX - maxCells + 1, dragStartX + maxCells - 1)
			cz = math.clamp(cz, dragStartZ - maxCells + 1, dragStartZ + maxCells - 1)

			dragEndX, dragEndZ = cx, cz

			if mode == 'Room' then
				BuildServiceClient:DrawRoomPreview(origin)
			else
				BuildServiceClient:DrawFloorPreview(origin)
			end
		end

		marker.Size = Vector3.new(cellSize - 0.4, 0.15, cellSize - 0.4)
		marker.Shape = Enum.PartType.Block
		marker.CFrame = CFrame.new(GRD_UTILS.CellToWorld(origin, cx, cz, level) + Vector3.new(0, BLD_CONFIGS.FloorThickness + 0.1, 0))
	end

	marker.Parent = ghosts.Parent
end

-- add see-through walls on edges, returns what they cost
local function ghostWalls(Origin: Vector3, Edges: {string}, Wall: DAT_TYPES.WallData, KeepExisting: boolean): number
	local levelData = getLevelData()
	local parcels = DAT_Client:get('Parcels')
	local cost = 0

	for _, edge in Edges do
		local old = levelData.Walls[edge]

		if KeepExisting and old then
			continue
		end

		local owned = LND_UTILS.IsEdgeOwned(parcels, edge)
		local model = BLD_UTILS.CreateWall(Origin, level, edge, Wall)
		BLD_UTILS.MakeGhost(model, if owned then GHOST_COLOR else BAD_COLOR)
		model.Parent = ghosts

		if not old or old.Kind ~= Wall.Kind or old.Style ~= Wall.Style then
			cost += BLD_UTILS.GetWallCost(Wall)
		end
	end

	return cost
end

-- add see-through floor tiles, returns what they cost
local function ghostFloors(Origin: Vector3, Cells: {string}, Style: string): number
	local levelData = getLevelData()
	local parcels = DAT_Client:get('Parcels')
	local config = BLD_CONFIGS.FloorStyles[Style]
	local cost = 0

	for _, cell in Cells do
		local floor = BLD_UTILS.CreateFloor(Origin, level, cell, Style)
		floor.Transparency = 0.35
		floor.CanCollide = false
		floor.CanQuery = false
		floor.CanTouch = false

		if not LND_UTILS.IsCellOwned(parcels, cell) then
			floor.Color = BAD_COLOR
		end

		floor.Parent = ghosts

		if levelData.Floors[cell] ~= Style then
			cost += config.Cost
		end
	end

	return cost
end

-- draw see-through walls along the drag line and show the cost
function BuildServiceClient:DrawWallPreview(Origin: Vector3)
	local key = `W{level}_{dragStartX}_{dragStartZ}_{dragEndX}_{dragEndZ}_{wallStyle}`

	if key == previewKey then
		return
	end

	previewKey = key
	ghosts:ClearAllChildren()

	local edges = GRD_UTILS.EdgesBetween(dragStartX, dragStartZ, dragEndX, dragEndZ)
	local cost = ghostWalls(Origin, edges, {Kind = 'Wall', Style = wallStyle}, false)

	BLD_CSignals.CostChanged:Fire(if cost > 0 then cost else nil)
end

-- draw see-through floor over the drag rectangle and show the cost
function BuildServiceClient:DrawFloorPreview(Origin: Vector3)
	local key = `F{level}_{dragStartX}_{dragStartZ}_{dragEndX}_{dragEndZ}_{floorStyle}`

	if key == previewKey then
		return
	end

	previewKey = key
	ghosts:ClearAllChildren()

	local cost = ghostFloors(Origin, GRD_UTILS.CellsBetween(dragStartX, dragStartZ, dragEndX, dragEndZ), floorStyle)

	BLD_CSignals.CostChanged:Fire(if cost > 0 then cost else nil)
end

-- draw a whole room (floor, walls around it and the front door)
function BuildServiceClient:DrawRoomPreview(Origin: Vector3)
	local key = `R{level}_{dragStartX}_{dragStartZ}_{dragEndX}_{dragEndZ}_{wallStyle}_{floorStyle}`

	if key == previewKey then
		return
	end

	previewKey = key
	ghosts:ClearAllChildren()

	local minX, maxX = math.min(dragStartX, dragEndX), math.max(dragStartX, dragEndX)
	local minZ, maxZ = math.min(dragStartZ, dragEndZ), math.max(dragStartZ, dragEndZ)

	local cost = ghostFloors(Origin, GRD_UTILS.CellsBetween(minX, minZ, maxX, maxZ), floorStyle)

	local doorEdge = GRD_UTILS.EdgeKey('X', math.floor((minX + maxX) / 2), maxZ + 1)
	local walls: {string} = {}

	for _, edge in GRD_UTILS.EdgesBetween(minX, minZ, maxX + 1, minZ) do
		table.insert(walls, edge)
	end

	for _, edge in GRD_UTILS.EdgesBetween(minX, maxZ + 1, maxX + 1, maxZ + 1) do
		if edge ~= doorEdge then
			table.insert(walls, edge)
		end
	end

	for _, edge in GRD_UTILS.EdgesBetween(minX, minZ, minX, maxZ + 1) do
		table.insert(walls, edge)
	end

	for _, edge in GRD_UTILS.EdgesBetween(maxX + 1, minZ, maxX + 1, maxZ + 1) do
		table.insert(walls, edge)
	end

	cost += ghostWalls(Origin, walls, {Kind = 'Wall', Style = wallStyle}, true)

	if not getLevelData().Walls[doorEdge] then
		cost += ghostWalls(Origin, {doorEdge}, {Kind = 'Door', Style = wallStyle}, true)
	end

	BLD_CSignals.CostChanged:Fire(if cost > 0 then cost else nil)
end

-- find the piece (wall model, floor part or furniture model) a part belongs to
local function getPiece(Hit: Instance): Instance?
	local current: Instance? = Hit

	while current and current:GetAttribute('Piece') == nil do
		current = current.Parent
	end

	return current
end

-- which piece folders the click tools can hit
local function getClickFolders(): {Instance}
	local names = if mode == 'Erase' then {'Walls', 'Floors', 'Furniture'}
		elseif mode == 'Paint' and paintTarget == 'Floor' then {'Floors'}
		else {'Walls'}

	local folders: {Instance} = {}

	for _, name in names do
		local folder = PLT_Client:GetPieceFolder(level, name)

		if folder then
			table.insert(folders, folder)
		end
	end

	return folders
end

-- highlight what the click tool is pointing at (and keep acting while held)
function BuildServiceClient:UpdateHover()
	local result = INP_UTILS.RaycastInclude(getClickFolders())
	local target = result and getPiece(result.Instance)

	hoverTarget = target
	hover.Adornee = target

	local color = if mode == 'Erase' then BAD_COLOR else GOOD_COLOR
	hover.FillColor = color
	hover.OutlineColor = color

	-- show what clicking would cost
	if target and mode ~= 'Erase' then
		BLD_CSignals.CostChanged:Fire(BuildServiceClient:GetClickCost(target))
	else
		BLD_CSignals.CostChanged:Fire(nil)
	end

	if dragging and target and target ~= lastActed then
		BuildServiceClient:ActOnTarget()
	end
end

-- cost of using the click tool on a piece
function BuildServiceClient:GetClickCost(Target: Instance): number?
	local levelData = getLevelData()

	if Target:GetAttribute('Piece') == 'Wall' then
		local old = levelData.Walls[Target.Name]

		if not old then
			return nil
		end

		local kind = if mode == 'Door' then 'Door' elseif mode == 'Window' then 'Window' else old.Kind
		local style = if mode == 'Paint' then paintStyle else old.Style

		return BLD_UTILS.GetWallCost({Kind = kind :: any, Style = style})
	elseif Target:GetAttribute('Piece') == 'Floor' then
		local config = BLD_CONFIGS.FloorStyles[paintStyle]

		return if config then config.Cost else nil
	end

	return nil
end

-- use the click tool on the piece under the pointer
function BuildServiceClient:ActOnTarget()
	local target = hoverTarget
	local now = os.clock()

	if not target or now - lastActTime < PAINT_INTERVAL then
		return
	end

	lastActed = target
	lastActTime = now

	local piece = target:GetAttribute('Piece')
	local key = target.Name

	if mode == 'Erase' then
		if piece == 'Wall' or piece == 'Floor' then
			remotes.RemovePiece:FireServer(level, piece, key)
		elseif piece == 'Furniture' then
			furnitureRemotes.RemoveFurniture:FireServer(key)
		end

		return
	end

	if piece == 'Wall' then
		local old = getLevelData().Walls[key]

		if not old then
			return
		end

		local kind = if mode == 'Door' then 'Door' elseif mode == 'Window' then 'Window' else old.Kind
		local style = if mode == 'Paint' then paintStyle else old.Style

		-- clicking a door with the door tool turns it back into a wall
		if (mode == 'Door' or mode == 'Window') and old.Kind == kind then
			kind = 'Wall'
		end

		local ax, az, bx, bz = GRD_UTILS.EdgePoints(key)
		remotes.PlaceWalls:FireServer(level, kind, style, ax, az, bx, bz)

	elseif piece == 'Floor' and mode == 'Paint' then
		local x, z = GRD_UTILS.ParseCellKey(key)
		remotes.PlaceFloors:FireServer(level, paintStyle, x, z, x, z)
	end
end

-- pointer pressed: start a drag
function BuildServiceClient:Press()
	if not isBuildTool() or not PLT_Client:IsReady() then
		return
	end

	if CLICK_TOOLS[mode] then
		dragging = true
		lastActed = nil
		BuildServiceClient:ActOnTarget()
		return
	end

	local origin, hit = pointerHit()

	if not origin or not hit then
		return
	end

	local size = GRD_UTILS.LandCells

	if mode == 'Wall' then
		local px, pz = GRD_UTILS.WorldToPoint(origin, hit)

		dragStartX, dragStartZ = math.clamp(px, 0, size), math.clamp(pz, 0, size)
	else
		local cx, cz = GRD_UTILS.WorldToCell(origin, hit)

		dragStartX, dragStartZ = math.clamp(cx, 0, size - 1), math.clamp(cz, 0, size - 1)
	end

	dragEndX, dragEndZ = dragStartX, dragStartZ
	previewKey = ''
	dragging = true
end

-- pointer released: send what was dragged out to the server
function BuildServiceClient:Release()
	if not dragging then
		return
	end

	dragging = false

	if mode == 'Wall' then
		if dragStartX ~= dragEndX or dragStartZ ~= dragEndZ then
			remotes.PlaceWalls:FireServer(level, 'Wall', wallStyle, dragStartX, dragStartZ, dragEndX, dragEndZ)
		end
	elseif mode == 'Floor' then
		remotes.PlaceFloors:FireServer(level, floorStyle, dragStartX, dragStartZ, dragEndX, dragEndZ)
	elseif mode == 'Room' then
		remotes.PlaceRoom:FireServer(level, wallStyle, floorStyle, dragStartX, dragStartZ, dragEndX, dragEndZ)
	end

	ghosts:ClearAllChildren()
	previewKey = ''

	if DRAG_TOOLS[mode] then
		BLD_CSignals.CostChanged:Fire(nil)
	end
end

return BuildServiceClient
