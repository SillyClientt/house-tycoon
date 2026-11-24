--!strict
local MarketConfigs = {}

local RPS = game:GetService('ReplicatedStorage')

local CFG_TYPES = require(RPS.Modules.Types.ConfigTypes)

-- rooms
-- A room is an area fully closed in by walls, fully floored, with a door (or stairs).
-- Its type comes from the key furniture inside it (FurnitureConfigs.Items[...].Room).
-- Rooms joined by a door, or stacked on top of each other, are one house.
MarketConfigs.MinRoomCells = 2
MarketConfigs.MaxBonusRoomsPerType = 3

local roomTypes: {[CFG_TYPES.RoomType]: CFG_TYPES.RoomTypeConfig} = {
	Bedroom = {DisplayName = 'Bedroom', Order = 1, Bonus = 800, IdealCells = 6},
	Bathroom = {DisplayName = 'Bathroom', Order = 2, Bonus = 700, IdealCells = 3},
	Kitchen = {DisplayName = 'Kitchen', Order = 3, Bonus = 900, IdealCells = 4},
	LivingRoom = {DisplayName = 'Living Room', Order = 4, Bonus = 800, IdealCells = 8},
	DiningRoom = {DisplayName = 'Dining Room', Order = 5, Bonus = 500, IdealCells = 4},
	Office = {DisplayName = 'Office', Order = 6, Bonus = 500, IdealCells = 3},
	Laundry = {DisplayName = 'Laundry Room', Order = 7, Bonus = 400, IdealCells = 2},
}

MarketConfigs.RoomTypes = roomTypes

-- a house can only be sold or rented when it has these rooms
local requiredRooms: {CFG_TYPES.RoomType} = {'Bedroom', 'Bathroom'}
MarketConfigs.RequiredRooms = requiredRooms

-- having all of these multiplies the whole value
local completeRooms: {CFG_TYPES.RoomType} = {'Bedroom', 'Bathroom', 'Kitchen', 'LivingRoom'}
MarketConfigs.CompleteRooms = completeRooms
MarketConfigs.CompleteMultiplier = 1.25

-- every furniture piece in a house adds Price * this (items can override with ValueRate)
MarketConfigs.FurnitureValueRate = 1.1

-- lighting: house value * (MinLightFactor + (1 - MinLightFactor) * lit fraction)
MarketConfigs.MinLightFactor = 0.5
MarketConfigs.WindowLightCells = 1 -- tiles lit inwards from each window

-- cleanliness: each dirt spot takes this much off, down to the minimum
MarketConfigs.DirtPenalty = 0.06
MarketConfigs.MinCleanFactor = 0.5
MarketConfigs.CellsPerDirt = 3 -- most dirt a house can have = tiles / this (at least 1)
MarketConfigs.DirtInterval = {Rented = 60, Other = 180} -- seconds between new dirt per house
MarketConfigs.DirtTick = 5
MarketConfigs.CleanDistance = 12

-- offers
MarketConfigs.FirstOfferDelay = {Min = 5, Max = 10}
MarketConfigs.OfferDelay = {Min = 10, Max = 20}
MarketConfigs.OfferLifetime = 45
MarketConfigs.MaxOffers = 3
MarketConfigs.SaleOfferRange = {Min = 0.85, Max = 1.2} -- times the house value
MarketConfigs.RentOfferRange = {Min = 0.85, Max = 1.15} -- times the base rent

-- rent
MarketConfigs.RentPerMinuteRate = 0.012 -- rent per minute = value * rate
MarketConfigs.RentTickInterval = 5
MarketConfigs.OfflineRentHours = 3

MarketConfigs.FirstNames = {
	'Ava', 'Noah', 'Mia', 'Liam', 'Zara', 'Omar', 'Lena', 'Yusuf', 'Ivy', 'Leo',
	'Sara', 'Adam', 'Nora', 'Ethan', 'Layla', 'Hugo', 'Maya', 'Idris', 'Chloe', 'Sam',
}

MarketConfigs.LastNames = {
	'Hart', 'Stone', 'Rivers', 'Khan', 'Brooks', 'Ward', 'Fields', 'Moss', 'Reed', 'Lane',
	'Price', 'Hale', 'Cole', 'Frost', 'Wells', 'Nash', 'Grant', 'Shaw', 'Blake', 'Dale',
}

return MarketConfigs
