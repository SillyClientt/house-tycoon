--!strict
-- Builds the suburb around the lands (Workspace.Map): sidewalks, road lines, fences,
-- street lamps, trees, a park and a town square. Then starts the day/night cycle.
-- Tweak the look in MapConfigs; the pieces themselves are in SceneryBuilder.
local MapServiceServer = {}

local RPS = game:GetService('ReplicatedStorage')
local WKS = game:GetService('Workspace')
local SSG = game:GetService('ServerStorage')

local MAP_CONFIGS = require(RPS.Modules.Configs.MapConfigs)
local LND_CONFIGS = require(RPS.Modules.Configs.LandConfigs)
local GRD_UTILS = require(RPS.Modules.Utils.GridUtils)
local PLT_Server = require(SSG.Modules.Services.PlotService.PlotServiceServer)

local SCENERY = require(script.Parent.SceneryBuilder)
local DAY_CYCLE = require(script.Parent.DayCycle)

local colors = MAP_CONFIGS.Colors

-- same seed every time, so the trees are always in the same spots
local random = Random.new(2026)

type Rect = {MinX: number, MaxX: number, MinZ: number, MaxZ: number}

local function isInside(Rect: Rect, X: number, Z: number): boolean
	return X > Rect.MinX and X < Rect.MaxX and Z > Rect.MinZ and Z < Rect.MaxZ
end

-- a flat slab whose top is at Top
local function slab(Parent: Instance, Name: string, CenterX: number, CenterZ: number, SizeX: number, SizeZ: number, Top: number, Color: Color3, Material: Enum.Material)
	SCENERY.Part(Parent, Vector3.new(SizeX, 1, SizeZ), CFrame.new(CenterX, Top - 0.5, CenterZ), Color,
		{Name = Name, Material = Material, Collide = true})
end

-- a square ring of slabs around a center (Inner = half the size of the hole)
local function ring(Parent: Instance, Name: string, Center: Vector3, Inner: number, Width: number, Top: number, Color: Color3, Material: Enum.Material)
	local outer = Inner + Width
	local middle = Inner + Width / 2

	slab(Parent, Name, Center.X, Center.Z - middle, outer * 2, Width, Top, Color, Material)
	slab(Parent, Name, Center.X, Center.Z + middle, outer * 2, Width, Top, Color, Material)
	slab(Parent, Name, Center.X - middle, Center.Z, Width, Inner * 2, Top, Color, Material)
	slab(Parent, Name, Center.X + middle, Center.Z, Width, Inner * 2, Top, Color, Material)
end

-- dashed yellow line from A to B, along X or Z
local function dashes(Parent: Instance, A: Vector3, B: Vector3)
	local length = (B - A).Magnitude
	local direction = (B - A).Unit
	local step = MAP_CONFIGS.DashLength + MAP_CONFIGS.DashGap
	local count = math.floor((length + MAP_CONFIGS.DashGap) / step)
	local start = (length - (count * step - MAP_CONFIGS.DashGap)) / 2

	for index = 0, count - 1 do
		local middle = A + direction * (start + index * step + MAP_CONFIGS.DashLength / 2)

		SCENERY.Part(Parent, Vector3.new(0.8, 0.05, MAP_CONFIGS.DashLength), CFrame.lookAt(middle, middle + direction),
			colors.RoadLine, {Name = 'RoadLine'})
	end
end

-- make (or empty) Workspace.Map
local function getMapFolder(): Folder
	local folder = WKS:FindFirstChild('Map')

	if folder and folder:IsA('Folder') then
		folder:ClearAllChildren()
		return folder
	end

	local newFolder = Instance.new('Folder')
	newFolder.Name = 'Map'
	newFolder.Parent = WKS

	return newFolder
end

-- initialize map service server-side (after PlotService has built the lands)
function MapServiceServer:Init()
	MapServiceServer:BuildSuburb()
	DAY_CYCLE:Start()
end

-- build all the scenery around the lands
function MapServiceServer:BuildSuburb()
	local plot = WKS:FindFirstChild('Plot')
	local ground = plot and plot:FindFirstChild('Ground')

	if not ground or not ground:IsA('BasePart') then
		warn('[MapServiceServer]: Workspace.Plot.Ground is missing, the suburb was not built')
		return
	end

	local folder = getMapFolder()
	local lands = PLT_Server:GetLands()

	local road = LND_CONFIGS.Neighborhood.RoadWidth
	local groundTop = ground.Position.Y + ground.Size.Y / 2
	local walkTop = groundTop + MAP_CONFIGS.CurbHeight

	local streets: Rect = {
		MinX = ground.Position.X - ground.Size.X / 2,
		MaxX = ground.Position.X + ground.Size.X / 2,
		MinZ = ground.Position.Z - ground.Size.Z / 2,
		MaxZ = ground.Position.Z + ground.Size.Z / 2,
	}

	if MAP_CONFIGS.RecolorBaseplate then
		local baseplate = WKS:FindFirstChild('Baseplate')

		if baseplate and baseplate:IsA('BasePart') then
			baseplate.Color = colors.Grass
			baseplate.Material = Enum.Material.Grass

			for _, child in baseplate:GetChildren() do
				if child:IsA('Texture') or child:IsA('Decal') then
					child:Destroy()
				end
			end
		end
	end

	-- grass under everything, a bit lower than the roads
	local park = MAP_CONFIGS.ParkWidth

	slab(folder, 'Park', ground.Position.X, ground.Position.Z, ground.Size.X + park * 2, ground.Size.Z + park * 2,
		groundTop - 0.05, colors.Grass, Enum.Material.Grass)

	local streetFolder = Instance.new('Folder')
	streetFolder.Name = 'Streets'
	streetFolder.Parent = folder

	for _, land in lands do
		MapServiceServer:DressLand(streetFolder, land, walkTop)
	end

	MapServiceServer:PaintRoads(streetFolder, lands, road, groundTop)
	MapServiceServer:BuildTownSquare(folder, streets, groundTop)
	MapServiceServer:PlantPark(folder, streets, groundTop)
end

-- sidewalk, curb, fence, lamps, trees and mailbox around one land
function MapServiceServer:DressLand(Parent: Instance, Land: BasePart, WalkTop: number)
	local model = Instance.new('Model')
	model.Name = `{Land.Name}Street`
	model.Parent = Parent

	local size = GRD_UTILS.LandStuds
	local half = size / 2
	local center = Land.Position
	local walk = MAP_CONFIGS.SidewalkWidth

	ring(model, 'Sidewalk', center, half, walk - 1, WalkTop, colors.Sidewalk, Enum.Material.Concrete)
	ring(model, 'Curb', center, half + walk - 1, 1, WalkTop + 0.1, colors.Curb, Enum.Material.Concrete)

	-- fence down both sides and across the back, a little outside the land so walls on the edge don't touch it
	local fenceOut = half + 1.4
	local back = center.Z - fenceOut
	local front = center.Z + half

	SCENERY.Fence(model, Vector3.new(center.X - fenceOut, WalkTop, front), Vector3.new(center.X - fenceOut, WalkTop, back))
	SCENERY.Fence(model, Vector3.new(center.X - fenceOut, WalkTop, back), Vector3.new(center.X + fenceOut, WalkTop, back))
	SCENERY.Fence(model, Vector3.new(center.X + fenceOut, WalkTop, back), Vector3.new(center.X + fenceOut, WalkTop, front))

	-- lamps along the front and back, leaning over the road
	local spacing = MAP_CONFIGS.LampSpacing
	local lampOut = half + walk - 1.8
	local x = center.X - half + spacing / 2

	while x < center.X + half do
		for _, side in {1, -1} do
			local at = Vector3.new(x, WalkTop, center.Z + lampOut * side)
			local light, bulb = SCENERY.Lamp(model, at, Vector3.new(0, 0, side))

			DAY_CYCLE:AddNightLight(light, bulb)
		end

		x += spacing
	end

	-- a row of trees down each side
	local trees = MAP_CONFIGS.TreesPerVerge
	local treeOut = half + walk / 2 + 0.4

	for index = 1, trees do
		local z = center.Z - half + size * (index - 0.5) / trees

		for _, side in {1, -1} do
			SCENERY.Tree(model, Vector3.new(center.X + treeOut * side, WalkTop, z), 0.75, random)
		end
	end

	-- mailbox by the starting parcel, where the owner spawns
	local parcelStuds = size / LND_CONFIGS.ParcelGrid
	local startX = GRD_UTILS.ParseCellKey(LND_CONFIGS.StartParcel)
	local origin = GRD_UTILS.GetOrigin(Land)

	SCENERY.Mailbox(model, Vector3.new(origin.X + (startX + 0.5) * parcelStuds - 8, WalkTop, center.Z + half + 2),
		Vector3.new(0, 0, 1))
end

-- dashed centre lines down every road, stopping at crossings
function MapServiceServer:PaintRoads(Parent: Instance, Lands: {BasePart}, Road: number, GroundTop: number)
	local half = GRD_UTILS.LandStuds / 2
	local columns: {number} = {}
	local rows: {number} = {}

	for _, land in Lands do
		if not table.find(columns, land.Position.X) then
			table.insert(columns, land.Position.X)
		end

		if not table.find(rows, land.Position.Z) then
			table.insert(rows, land.Position.Z)
		end
	end

	table.sort(columns)
	table.sort(rows)

	if #columns == 0 then
		return
	end

	-- centre of each road: one before every land and one after the last
	local function roadLines(Centers: {number}): {number}
		local lines = {Centers[1] - half - Road / 2}

		for _, centerValue in Centers do
			table.insert(lines, centerValue + half + Road / 2)
		end

		return lines
	end

	local xRoads = roadLines(columns)
	local zRoads = roadLines(rows)
	local y = GroundTop + 0.03

	for _, z in zRoads do
		for index = 1, #xRoads - 1 do
			dashes(Parent, Vector3.new(xRoads[index] + Road / 2, y, z), Vector3.new(xRoads[index + 1] - Road / 2, y, z))
		end
	end

	for _, x in xRoads do
		for index = 1, #zRoads - 1 do
			dashes(Parent, Vector3.new(x, y, zRoads[index] + Road / 2), Vector3.new(x, y, zRoads[index + 1] - Road / 2))
		end
	end
end

-- paved square with a fountain and shops, across the road from the front row
function MapServiceServer:BuildTownSquare(Parent: Instance, Streets: Rect, GroundTop: number)
	local config = MAP_CONFIGS.TownSquare

	local model = Instance.new('Model')
	model.Name = 'TownSquare'
	model.Parent = Parent

	local top = GroundTop + 0.2
	local centerX = (Streets.MinX + Streets.MaxX) / 2
	local centerZ = Streets.MaxZ + 4 + config.Depth / 2

	slab(model, 'Paving', centerX, centerZ, config.Width, config.Depth, top, config.PavingColor, Enum.Material.Pavement)

	-- fountain with benches around it
	local fountainAt = Vector3.new(centerX, top, centerZ - 14)
	SCENERY.Fountain(model, fountainAt)

	for _, angle in {45, 135, 225, 315} do
		local direction = Vector3.new(math.cos(math.rad(angle)), 0, math.sin(math.rad(angle)))
		local at = fountainAt + direction * 22

		SCENERY.Bench(model, at, -direction)
	end

	-- shops along the back, facing the neighbourhood
	local shops = config.Shops
	local gap = config.Width / #shops

	for index, shop in shops do
		local at = Vector3.new(centerX - config.Width / 2 + gap * (index - 0.5), top, centerZ + config.Depth / 2 - 17)

		for _, light in SCENERY.Shop(model, at, Vector3.new(0, 0, -1), shop.Name, shop.Color) do
			DAY_CYCLE:AddNightLight(light)
		end
	end

	-- lamps on the corners
	for _, corner in {{-1, -1}, {1, -1}} do
		local at = Vector3.new(centerX + corner[1] * (config.Width / 2 - 4), top, centerZ + corner[2] * (config.Depth / 2 - 4))
		local light, bulb = SCENERY.Lamp(model, at, Vector3.new(0, 0, -1))

		DAY_CYCLE:AddNightLight(light, bulb)
	end

	-- flower beds in front of the shops
	for index = 1, 6 do
		local x = centerX - config.Width / 2 + config.Width * (index - 0.5) / 6
		SCENERY.Flowers(model, Vector3.new(x, top, centerZ + config.Depth / 2 - 36), random)
	end
end

-- trees, bushes and flowers in the grass around the neighbourhood
function MapServiceServer:PlantPark(Parent: Instance, Streets: Rect, GroundTop: number)
	local folder = Instance.new('Folder')
	folder.Name = 'Park'
	folder.Parent = Parent

	local park = MAP_CONFIGS.ParkWidth
	local config = MAP_CONFIGS.TownSquare
	local centerX = (Streets.MinX + Streets.MaxX) / 2

	-- keep the road edge and the town square clear
	local keepOut: {Rect} = {
		{MinX = Streets.MinX - 10, MaxX = Streets.MaxX + 10, MinZ = Streets.MinZ - 10, MaxZ = Streets.MaxZ + 10},
		{
			MinX = centerX - config.Width / 2 - 8,
			MaxX = centerX + config.Width / 2 + 8,
			MinZ = Streets.MaxZ,
			MaxZ = Streets.MaxZ + config.Depth + 14,
		},
	}

	local function findSpot(): Vector3?
		for _ = 1, 30 do
			local x = random:NextNumber(Streets.MinX - park + 6, Streets.MaxX + park - 6)
			local z = random:NextNumber(Streets.MinZ - park + 6, Streets.MaxZ + park - 6)
			local blocked = false

			for _, rect in keepOut do
				if isInside(rect, x, z) then
					blocked = true
					break
				end
			end

			if not blocked then
				return Vector3.new(x, GroundTop, z)
			end
		end

		return nil
	end

	for _ = 1, MAP_CONFIGS.ParkTrees do
		local spot = findSpot()

		if spot then
			SCENERY.Tree(folder, spot, random:NextNumber(0.9, 1.5), random)
		end
	end

	for _ = 1, math.floor(MAP_CONFIGS.ParkTrees * 0.6) do
		local spot = findSpot()

		if spot then
			SCENERY.Bush(folder, spot, random:NextNumber(3, 5), random)
		end
	end

	for _ = 1, math.floor(MAP_CONFIGS.ParkTrees * 0.4) do
		local spot = findSpot()

		if spot then
			SCENERY.Flowers(folder, spot, random)
		end
	end
end

return MapServiceServer
