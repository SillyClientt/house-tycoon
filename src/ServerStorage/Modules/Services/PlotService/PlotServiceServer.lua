--!strict
local PlotServiceServer = {}

local PLS = game:GetService('Players')
local RPS = game:GetService('ReplicatedStorage')
local WKS = game:GetService('Workspace')
local SSG = game:GetService('ServerStorage')

local DAT_Server = require(RPS.Modules.Packages.DataService).server
local LND_CONFIGS = require(RPS.Modules.Configs.LandConfigs)
local GRD_UTILS = require(RPS.Modules.Utils.GridUtils)
local LND_UTILS = require(RPS.Modules.Utils.LandUtils)
local STR_UTILS = require(RPS.Modules.Utils.StringUtils)
local HSE_Server = require(SSG.Modules.Services.HouseService.HouseServiceServer)
local ECN_Server = require(SSG.Modules.Services.EconomyService.EconomyServiceServer)
local ATC_SSignals = require(SSG.Modules.Services.AnalyticsService.AnalyticsServerSignals)

local PLT_CONTAINER = require(script.Parent.PlotContainer)

local remotes = RPS.Remotes.PlotService

local GOOD = Color3.fromRGB(90, 210, 120)
local BAD = Color3.fromRGB(235, 80, 80)

local lands: {BasePart} = {}
local signs: {[Player]: BillboardGui} = {}
local lastRequest: {[Player]: number} = {}

-- send a message to the player
local function notify(Player: Player, Text: string, Color: Color3)
	RPS.Remotes.InterfaceService.Notify:FireClient(Player, Text, Color)
end

-- rate limit + data loaded
local function checkRequest(Player: Player): boolean
	local now = os.clock()

	if now - (lastRequest[Player] or 0) < 0.4 or not DAT_Server:hasProfile(Player) then
		return false
	end

	lastRequest[Player] = now
	return true
end

-- initialize plot service server-side
function PlotServiceServer:Init()
	PlotServiceServer:BuildNeighborhood()

	PLS.PlayerAdded:Connect(function(Player)
		PlotServiceServer:AssignPlot(Player)
	end)

	for _, player in PLS:GetPlayers() do
		task.spawn(function()
			PlotServiceServer:AssignPlot(player)
		end)
	end

	PLS.PlayerRemoving:Connect(function(Player)
		local land = PLT_CONTAINER[Player]

		if land then
			land:SetAttribute('Owner', nil)
		end

		local sign = signs[Player]

		if sign then
			sign:Destroy()
		end

		PLT_CONTAINER[Player] = nil
		signs[Player] = nil
		lastRequest[Player] = nil
	end)

	remotes.BuyParcel.OnServerEvent:Connect(function(Player, Key)
		PlotServiceServer:BuyParcel(Player, Key)
	end)

	remotes.UnlockLevel.OnServerEvent:Connect(function(Player)
		PlotServiceServer:UnlockLevel(Player)
	end)
end

-- build the ground, roads and one land per player slot (Workspace.Plot)
function PlotServiceServer:BuildNeighborhood()
	local config = LND_CONFIGS.Neighborhood
	local landSize = GRD_UTILS.LandStuds
	local road = config.RoadWidth

	local width = config.Columns * landSize + (config.Columns + 1) * road
	local depth = config.Rows * landSize + (config.Rows + 1) * road

	local folder = WKS:FindFirstChild('Plot')

	if not folder then
		folder = Instance.new('Folder')
		folder.Name = 'Plot'
		folder.Parent = WKS
	end

	assert(folder)

	-- old plot parts are replaced by generated lands
	folder:ClearAllChildren()

	local ground = Instance.new('Part')
	ground.Name = 'Ground'
	ground.Anchored = true
	ground.Material = Enum.Material.Asphalt
	ground.Color = config.RoadColor
	ground.Size = Vector3.new(width, 1, depth)
	ground.CFrame = CFrame.new(config.Center - Vector3.new(0, 0.5, 0))
	ground.TopSurface = Enum.SurfaceType.Smooth
	ground.Parent = folder

	local index = 0

	for row = 0, config.Rows - 1 do
		for column = 0, config.Columns - 1 do
			index += 1

			local x = config.Center.X - width / 2 + road + landSize / 2 + column * (landSize + road)
			local z = config.Center.Z - depth / 2 + road + landSize / 2 + row * (landSize + road)

			local land = Instance.new('Part')
			land.Name = `Land{index}`
			land.Anchored = true
			land.Material = Enum.Material.Grass
			land.Color = config.GrassColor
			land.Size = Vector3.new(landSize, 1, landSize)
			land.CFrame = CFrame.new(x, config.Center.Y + 0.2 - 0.5, z)
			land.TopSurface = Enum.SurfaceType.Smooth
			land.Parent = folder

			table.insert(lands, land)
		end
	end
end

-- every land part, in the order they are handed out
function PlotServiceServer:GetLands(): {BasePart}
	return lands
end

-- give a player a free land and load it
function PlotServiceServer:AssignPlot(Player: Player)
	if PLT_CONTAINER[Player] then
		return
	end

	local designated: BasePart?

	for _, land in lands do
		if land:GetAttribute('Owner') == nil then
			designated = land
			break
		end
	end

	if not designated then
		Player:Kick('No land available! Try another server.')
		return
	end

	assert(designated)

	designated:SetAttribute('Owner', Player.UserId)
	PLT_CONTAINER[Player] = designated
	Player:SetAttribute('Plot', designated.Name)

	PlotServiceServer:CreateSign(Player, designated)

	Player.CharacterAdded:Connect(function(Character)
		PlotServiceServer:SpawnAtPlot(Player, Character)
	end)

	if Player.Character then
		PlotServiceServer:SpawnAtPlot(Player, Player.Character)
	end

	HSE_Server:LoadLand(Player)
end

-- move a character to the road in front of their land, next to their first parcel
function PlotServiceServer:SpawnAtPlot(Player: Player, Character: Model)
	local land = PLT_CONTAINER[Player]

	if not land then
		return
	end

	task.defer(function()
		if not Character.Parent then
			return
		end

		local origin = GRD_UTILS.GetOrigin(land)
		local px = GRD_UTILS.ParseCellKey(LND_CONFIGS.StartParcel)
		local parcelStuds = GRD_UTILS.LandStuds / LND_CONFIGS.ParcelGrid
		local front = origin + Vector3.new((px + 0.5) * parcelStuds, 4, GRD_UTILS.LandStuds + 8)

		Character:PivotTo(CFrame.lookAt(front, front - Vector3.new(0, 0, 1)))
	end)
end

-- show the owner's name at the front of the land
function PlotServiceServer:CreateSign(Player: Player, Land: BasePart)
	local attachment = Instance.new('Attachment')
	attachment.Name = 'SignAttachment'
	attachment.Position = Vector3.new(0, 12, Land.Size.Z / 2)
	attachment.Parent = Land

	local sign = Instance.new('BillboardGui')
	sign.Name = 'OwnerSign'
	sign.Size = UDim2.fromScale(16, 4)
	sign.MaxDistance = 300
	sign.Adornee = attachment
	sign.Parent = attachment

	local label = Instance.new('TextLabel')
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Text = `{Player.DisplayName}'s Estate`
	label.Parent = sign

	signs[Player] = sign

	sign.Destroying:Connect(function()
		attachment:Destroy()
	end)
end

-- give a parcel (after paying cash or Robux)
function PlotServiceServer:UnlockParcel(Player: Player, Key: string)
	DAT_Server:set(Player, {'Parcels', Key}, true)
	HSE_Server:RenderParcels(Player)

	ATC_SSignals.LogJourney:Fire(Player, 'BoughtParcel')
	notify(Player, 'New land unlocked!', GOOD)
end

-- buy a parcel with cash
function PlotServiceServer:BuyParcel(Player: Player, Key: any)
	if typeof(Key) ~= 'string' or not checkRequest(Player) then
		return
	end

	local parcels = DAT_Server:get(Player, 'Parcels')

	if not LND_UTILS.CanBuyParcel(parcels, Key) then
		notify(Player, 'You can only buy land next to land you own', BAD)
		return
	end

	local price = LND_UTILS.GetNextPrice(parcels)

	if not price or not ECN_Server:TryDeduct(Player, price, 'BuyParcel') then
		return
	end

	PlotServiceServer:UnlockParcel(Player, Key)
end

-- unlock the next floor
function PlotServiceServer:UnlockLevel(Player: Player)
	if not checkRequest(Player) then
		return
	end

	local nextLevel = DAT_Server:get(Player, 'Levels') + 1
	local config = LND_CONFIGS.Levels[nextLevel]

	if not config then
		notify(Player, 'All floors are unlocked', BAD)
		return
	end

	if not ECN_Server:TryDeduct(Player, config.Cost, 'UnlockFloor') then
		return
	end

	DAT_Server:set(Player, 'Levels', nextLevel)

	ATC_SSignals.LogJourney:Fire(Player, `UnlockedLevel{nextLevel}`)
	notify(Player, `{config.DisplayName} unlocked for {STR_UTILS.FormatCash(config.Cost)}! Place stairs to reach it.`, GOOD)
end

return PlotServiceServer
