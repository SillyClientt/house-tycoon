--!strict
local RPS = game:GetService('ReplicatedStorage')

local HSE_UTILS = require(RPS.Modules.Utils.HouseUtils)
local LND_CONFIGS = require(RPS.Modules.Configs.LandConfigs)
local DAT_TYPES = require(RPS.Modules.Types.DataTypes)

local data: DAT_TYPES.PlayerData = {
	Cash = 5000,
	Parcels = {
		[LND_CONFIGS.StartParcel] = true,
	},
	Levels = 1,

	Land = HSE_UTILS.NewLand(),
	Rentals = {},
	UnlockedItems = {},
	Purchases = {},

	Stats = {
		HousesSold = 0,
		HousesRented = 0,
		TotalEarned = 0,
		DirtCleaned = 0,
	},

	LastOnline = 0,
}

return data
