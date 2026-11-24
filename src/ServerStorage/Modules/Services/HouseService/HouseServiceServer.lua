--!strict
local HouseServiceServer = {}

local PLS = game:GetService('Players')
local RPS = game:GetService('ReplicatedStorage')
local SSG = game:GetService('ServerStorage')
local WKS = game:GetService('Workspace')

local DAT_Server = require(RPS.Modules.Packages.DataService).server
local BLD_CONFIGS = require(RPS.Modules.Configs.BuildConfigs)
local LND_CONFIGS = require(RPS.Modules.Configs.LandConfigs)
local GRD_UTILS = require(RPS.Modules.Utils.GridUtils)
local BLD_UTILS = require(RPS.Modules.Utils.BuildUtils)
local FUR_UTILS = require(RPS.Modules.Utils.FurnitureUtils)
local HSE_UTILS = require(RPS.Modules.Utils.HouseUtils)
local LND_UTILS = require(RPS.Modules.Utils.LandUtils)
local STR_UTILS = require(RPS.Modules.Utils.StringUtils)
local DAT_TYPES = require(RPS.Modules.Types.DataTypes)

local PLT_CONTAINER = require(SSG.Modules.Services.PlotService.PlotContainer)

local PIECE_FOLDERS = {'Walls', 'Posts', 'Floors', 'Furniture', 'Dirt'}
local RED = Color3.fromRGB(235, 80, 80)

local housesFolder: Folder
local landFolders: {[Player]: Folder} = {}
local lockedColumns: {[Player]: {[string]: boolean}} = {}

-- initialize house service server-side
function HouseServiceServer:Init()
	housesFolder = Instance.new('Folder')
	housesFolder.Name = 'Houses'
	housesFolder.Parent = WKS

	PLS.PlayerRemoving:Connect(function(Player)
		local folder = landFolders[Player]

		if folder then
			folder:Destroy()
		end

		landFolders[Player] = nil
		lockedColumns[Player] = nil
	end)
end

-- get the grid corner of a player's land
function HouseServiceServer:GetOrigin(Player: Player): Vector3?
	local land = PLT_CONTAINER[Player]

	return land and GRD_UTILS.GetOrigin(land)
end

-- get the player's land data
function HouseServiceServer:GetLand(Player: Player): DAT_TYPES.LandData
	return DAT_Server:get(Player, 'Land')
end

-- what the player may build on
function HouseServiceServer:GetContext(Player: Player): FUR_UTILS.PlaceContext
	return {
		Parcels = DAT_Server:get(Player, 'Parcels'),
		Levels = DAT_Server:get(Player, 'Levels'),
	}
end

-- every house on the player's land, and a map of level cell -> house id
function HouseServiceServer:GetHouses(Player: Player): ({DAT_TYPES.HouseInfo}, {[string]: string})
	return HSE_UTILS.GetHouses(HouseServiceServer:GetLand(Player))
end

-- find one house by id
function HouseServiceServer:FindHouse(Player: Player, Id: string): (DAT_TYPES.HouseInfo?, {[string]: string})
	local houses, cellHouse = HouseServiceServer:GetHouses(Player)

	for _, house in houses do
		if house.Id == Id then
			return house, cellHouse
		end
	end

	return nil, cellHouse
end

-- the folder a level's pieces of one kind live in
local function getFolder(Player: Player, Level: number, Kind: string): Folder?
	local land = landFolders[Player]
	local level = land and land:FindFirstChild(`L{Level}`)
	local folder = level and level:FindFirstChild(Kind)

	return if folder and folder:IsA('Folder') then folder else nil
end

-- get the player's land folder (used to check a prompt belongs to them)
function HouseServiceServer:GetLandFolder(Player: Player): Folder?
	return landFolders[Player]
end

-- lock / unlock tile columns (houses on the market or rented can't be edited)
function HouseServiceServer:SetLockedColumns(Player: Player, Columns: {[string]: boolean})
	lockedColumns[Player] = Columns
end

-- check a tile column is locked
function HouseServiceServer:IsColumnLocked(Player: Player, Cell: string): boolean
	local columns = lockedColumns[Player]

	return columns ~= nil and columns[Cell] == true
end

-- check a wall line is locked (either side locked)
function HouseServiceServer:IsEdgeLocked(Player: Player, Edge: string): boolean
	local a, b = GRD_UTILS.EdgeCells(Edge)

	return HouseServiceServer:IsColumnLocked(Player, a) or HouseServiceServer:IsColumnLocked(Player, b)
end

-- tell the player why they can't edit
function HouseServiceServer:NotifyLocked(Player: Player)
	RPS.Remotes.InterfaceService.Notify:FireClient(Player, 'That house is on the market or rented - you can\'t change it', RED)
end

-- check the land is loaded
function HouseServiceServer:IsReady(Player: Player): boolean
	return landFolders[Player] ~= nil
end

-- load a player's land onto their plot
function HouseServiceServer:LoadLand(Player: Player)
	if landFolders[Player] then
		return
	end

	DAT_Server:waitForData(Player)

	if Player.Parent ~= PLS or not PLT_CONTAINER[Player] then
		return
	end

	local folder = Instance.new('Folder')
	folder.Name = `Land_{Player.UserId}`
	folder:SetAttribute('Owner', Player.UserId)

	for level = 1, LND_CONFIGS.MaxLevels do
		local levelFolder = Instance.new('Folder')
		levelFolder.Name = `L{level}`

		for _, name in PIECE_FOLDERS do
			local child = Instance.new('Folder')
			child.Name = name
			child.Parent = levelFolder
		end

		levelFolder.Parent = folder
	end

	local parcels = Instance.new('Folder')
	parcels.Name = 'Parcels'
	parcels.Parent = folder

	folder.Parent = housesFolder
	landFolders[Player] = folder

	HouseServiceServer:RenderParcels(Player)
	HouseServiceServer:RenderAll(Player)
end

-- show locked parcels with their price
function HouseServiceServer:RenderParcels(Player: Player)
	local origin = HouseServiceServer:GetOrigin(Player)
	local folder = landFolders[Player]
	local parcelFolder = folder and folder:FindFirstChild('Parcels')

	if not origin or not parcelFolder then
		return
	end

	parcelFolder:ClearAllChildren()

	local parcels = DAT_Server:get(Player, 'Parcels')
	local price = LND_UTILS.GetNextPrice(parcels)
	local studs = LND_CONFIGS.ParcelCells * BLD_CONFIGS.CellSize

	for px = 0, LND_CONFIGS.ParcelGrid - 1 do
		for pz = 0, LND_CONFIGS.ParcelGrid - 1 do
			local key = GRD_UTILS.CellKey(px, pz)

			if parcels[key] then
				continue
			end

			local part = Instance.new('Part')
			part.Name = key
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part.Material = Enum.Material.SmoothPlastic
			part.Color = Color3.fromRGB(40, 40, 46)
			part.Transparency = 0.6
			part.Size = Vector3.new(studs - 0.4, 0.1, studs - 0.4)
			part.CFrame = CFrame.new(origin + Vector3.new((px + 0.5) * studs, 0.06, (pz + 0.5) * studs))
			part:SetAttribute('Parcel', key)

			-- price sign on parcels that can be bought now
			if price and LND_UTILS.CanBuyParcel(parcels, key) then
				local sign = Instance.new('BillboardGui')
				sign.Size = UDim2.fromScale(10, 2.5)
				sign.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
				sign.MaxDistance = 200
				sign.Parent = part

				local label = Instance.new('TextLabel')
				label.Size = UDim2.fromScale(1, 1)
				label.BackgroundTransparency = 1
				label.Font = Enum.Font.FredokaOne
				label.TextScaled = true
				label.TextColor3 = Color3.fromRGB(120, 230, 140)
				label.TextStrokeTransparency = 0.3
				label.Text = `For Sale: {STR_UTILS.FormatCash(price)}`
				label.Parent = sign
			end

			part.Parent = parcelFolder
		end
	end
end

-- destroy everything rendered for a player's land
function HouseServiceServer:ClearRender(Player: Player)
	for level = 1, LND_CONFIGS.MaxLevels do
		for _, name in PIECE_FOLDERS do
			local folder = getFolder(Player, level, name)

			if folder then
				folder:ClearAllChildren()
			end
		end
	end
end

-- render the whole land from data
function HouseServiceServer:RenderAll(Player: Player)
	HouseServiceServer:ClearRender(Player)

	local land = HouseServiceServer:GetLand(Player)

	for level = 1, LND_CONFIGS.MaxLevels do
		local levelData = HSE_UTILS.GetLevel(land, level)

		for key in levelData.Walls do
			HouseServiceServer:RenderWall(Player, level, key)
		end

		for key in levelData.Floors do
			HouseServiceServer:RenderFloor(Player, level, key)
		end
	end

	for id in land.Furniture do
		HouseServiceServer:RenderFurniture(Player, id)
	end

	for id in land.Dirt do
		HouseServiceServer:RenderDirt(Player, id)
	end
end

-- render (or remove) one wall piece and fix the posts at its ends
function HouseServiceServer:RenderWall(Player: Player, Level: number, Key: string)
	local origin = HouseServiceServer:GetOrigin(Player)
	local folder = getFolder(Player, Level, 'Walls')

	if not origin or not folder then
		return
	end

	local old = folder:FindFirstChild(Key)

	if old then
		old:Destroy()
	end

	local wall = HSE_UTILS.GetLevel(HouseServiceServer:GetLand(Player), Level).Walls[Key]

	if wall then
		BLD_UTILS.CreateWall(origin, Level, Key, wall).Parent = folder
	end

	local ax, az, bx, bz = GRD_UTILS.EdgePoints(Key)

	HouseServiceServer:RenderPost(Player, Level, ax, az)
	HouseServiceServer:RenderPost(Player, Level, bx, bz)
end

-- render the corner post at a grid point if any wall touches it
function HouseServiceServer:RenderPost(Player: Player, Level: number, X: number, Z: number)
	local origin = HouseServiceServer:GetOrigin(Player)
	local folder = getFolder(Player, Level, 'Posts')

	if not origin or not folder then
		return
	end

	local name = `P_{X}_{Z}`
	local old = folder:FindFirstChild(name)

	if old then
		old:Destroy()
	end

	local walls = HSE_UTILS.GetLevel(HouseServiceServer:GetLand(Player), Level).Walls

	for _, key in GRD_UTILS.EdgesAtPoint(X, Z) do
		local wall = walls[key]

		if wall then
			BLD_UTILS.CreatePost(origin, Level, X, Z, wall.Style).Parent = folder
			return
		end
	end
end

-- render (or remove) one floor tile
function HouseServiceServer:RenderFloor(Player: Player, Level: number, Key: string)
	local origin = HouseServiceServer:GetOrigin(Player)
	local folder = getFolder(Player, Level, 'Floors')

	if not origin or not folder then
		return
	end

	local old = folder:FindFirstChild(Key)

	if old then
		old:Destroy()
	end

	local style = HSE_UTILS.GetLevel(HouseServiceServer:GetLand(Player), Level).Floors[Key]

	if style then
		BLD_UTILS.CreateFloor(origin, Level, Key, style).Parent = folder
	end
end

-- find a rendered furniture model on any floor
local function findFurniture(Player: Player, Id: string): Instance?
	for level = 1, LND_CONFIGS.MaxLevels do
		local folder = getFolder(Player, level, 'Furniture')
		local model = folder and folder:FindFirstChild(Id)

		if model then
			return model
		end
	end

	return nil
end

-- render (or remove) one furniture item
function HouseServiceServer:RenderFurniture(Player: Player, Id: string)
	local origin = HouseServiceServer:GetOrigin(Player)

	if not origin then
		return
	end

	local old = findFurniture(Player, Id)
	local item = HouseServiceServer:GetLand(Player).Furniture[Id]
	local folder = item and getFolder(Player, item.Level, 'Furniture')

	-- same item on the same floor just moved: keep the model
	if old and item and folder and old.Parent == folder and old:IsA('Model') and old:GetAttribute('Item') == item.Name then
		FUR_UTILS.PlaceFurniture(old, FUR_UTILS.GetWorldPosition(origin, item), item.Rotation)
		return
	end

	if old then
		old:Destroy()
	end

	if not item or not folder then
		return
	end

	local model = FUR_UTILS.CreateModel(item.Name)

	if not model then
		warn(`[HouseServiceServer]: Couldn't create furniture {item.Name}`)
		return
	end

	model.Name = Id
	model:SetAttribute('Item', item.Name)
	model:SetAttribute('Level', item.Level)

	FUR_UTILS.PlaceFurniture(model, FUR_UTILS.GetWorldPosition(origin, item), item.Rotation)

	model.Parent = folder
end

-- render (or remove) one dirt spot
function HouseServiceServer:RenderDirt(Player: Player, Id: string)
	local origin = HouseServiceServer:GetOrigin(Player)

	if not origin then
		return
	end

	for level = 1, LND_CONFIGS.MaxLevels do
		local folder = getFolder(Player, level, 'Dirt')
		local old = folder and folder:FindFirstChild(Id)

		if old then
			old:Destroy()
		end
	end

	local dirt = HouseServiceServer:GetLand(Player).Dirt[Id]
	local folder = dirt and getFolder(Player, dirt.Level, 'Dirt')

	if dirt and folder then
		BLD_UTILS.CreateDirt(origin, dirt, Id).Parent = folder
	end
end

-- swap the whole land (used when a house is sold)
function HouseServiceServer:SetLand(Player: Player, Land: DAT_TYPES.LandData)
	DAT_Server:set(Player, 'Land', Land)
	HouseServiceServer:RenderAll(Player)
end

return HouseServiceServer
