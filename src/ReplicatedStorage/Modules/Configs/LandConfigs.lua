--!strict
local LandConfigs = {}

local RPS = game:GetService('ReplicatedStorage')

local CFG_TYPES = require(RPS.Modules.Types.ConfigTypes)

-- Each player's land is a 4x4 grid of parcels, each parcel is 8x8 tiles (48x48 studs).
-- Full land = 32x32 tiles = 192x192 studs.
LandConfigs.ParcelCells = 8
LandConfigs.ParcelGrid = 4

-- the free parcel everyone starts with (front row, next to the road where players spawn)
LandConfigs.StartParcel = '1_3'

-- cash price of the next parcel, by how many parcels the player already owns
LandConfigs.ParcelPrices = {
	[1] = 2500,
	[2] = 6000,
	[3] = 12000,
	[4] = 20000,
	[5] = 32000,
	[6] = 50000,
	[7] = 75000,
	[8] = 110000,
	[9] = 160000,
	[10] = 230000,
	[11] = 320000,
	[12] = 450000,
	[13] = 620000,
	[14] = 850000,
	[15] = 1200000,
}

-- Robux parcel products. Make 3 developer products on the website and paste their ids here.
local parcelTiers: {CFG_TYPES.ParcelTierConfig} = {
	{MaxOwned = 4, ProductId = 0, RobuxPrice = 49},
	{MaxOwned = 9, ProductId = 0, RobuxPrice = 99},
	{MaxOwned = 15, ProductId = 0, RobuxPrice = 199},
}

LandConfigs.ParcelTiers = parcelTiers

-- floors
local levels: {[number]: CFG_TYPES.LevelConfig} = {
	[1] = {DisplayName = 'Ground Floor', Cost = 0},
	[2] = {DisplayName = '2nd Floor', Cost = 25000},
	[3] = {DisplayName = '3rd Floor', Cost = 100000},
}

LandConfigs.Levels = levels
LandConfigs.MaxLevels = #levels

-- Where the neighbourhood is built (6 lands, 3 x 2, with roads between).
-- Move Center to place it somewhere else on your map. Set Max Players to 6 in Game Settings.
LandConfigs.Neighborhood = {
	Center = Vector3.new(-560, 0.1, -100), -- top of the ground (just above the baseplate, west of spawn)
	Columns = 3,
	Rows = 2,
	RoadWidth = 40,
	GrassColor = Color3.fromRGB(96, 156, 82),
	RoadColor = Color3.fromRGB(70, 72, 78),
}

return LandConfigs
