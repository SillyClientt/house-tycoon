--!strict
local MonetizationConfigs = {}

local RPS = game:GetService('ReplicatedStorage')

local CFG_TYPES = require(RPS.Modules.Types.ConfigTypes)

-- Make these on the website (Creator Hub > your game > Monetization) and paste the ids.
-- Id = 0 means "not set up yet": the button tells the player instead of prompting.
-- Everything here gives a fixed, guaranteed result (no luck, no crates).

local gamepasses: {[string]: CFG_TYPES.GamepassConfig} = {
	DoubleRent = {
		Id = 0,
		DisplayName = '2x Rent',
		Description = 'Every tenant pays you double rent.',
		RobuxPrice = 249,
		Order = 1,
	},
	AutoCleaner = {
		Id = 0,
		DisplayName = 'Auto Cleaner',
		Description = 'A cleaner removes one dirt spot every 15 seconds.',
		RobuxPrice = 199,
		Order = 2,
	},
	VipFurniture = {
		Id = 0,
		DisplayName = 'VIP Furniture',
		Description = 'Unlocks the VIP furniture set (worth 50% more).',
		RobuxPrice = 299,
		Order = 3,
	},
	QuickSale = {
		Id = 0,
		DisplayName = 'Quick Sale',
		Description = 'Offers come twice as fast and are 10% higher.',
		RobuxPrice = 149,
		Order = 4,
	},
}

MonetizationConfigs.Gamepasses = gamepasses

local cashPacks: {[string]: CFG_TYPES.CashPackConfig} = {
	Small = {Id = 0, Cash = 10000, RobuxPrice = 49, Order = 1},
	Medium = {Id = 0, Cash = 50000, RobuxPrice = 199, Order = 2},
	Large = {Id = 0, Cash = 250000, RobuxPrice = 799, Order = 3},
	Huge = {Id = 0, Cash = 1000000, RobuxPrice = 2499, Order = 4},
}

MonetizationConfigs.CashPacks = cashPacks

-- gamepass effects
MonetizationConfigs.DoubleRentMultiplier = 2
MonetizationConfigs.AutoCleanInterval = 15
MonetizationConfigs.QuickSaleDelayMultiplier = 0.5
MonetizationConfigs.QuickSaleOfferBonus = 1.1

-- how many purchase ids to remember (stops a receipt being granted twice)
MonetizationConfigs.PurchaseHistory = 50

return MonetizationConfigs
