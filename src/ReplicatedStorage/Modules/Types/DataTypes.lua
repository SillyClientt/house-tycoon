--!strict
local CFG_TYPES = require(script.Parent.ConfigTypes)

--[[
	Keys used in data:
	cell        "x_z"        a tile on one floor
	edge        "X_x_z"      a wall line (see GridUtils)
	level cell  "level|x_z"  a tile on a given floor, e.g. "2|4_7"
	level key   "L1".."L3"   index into LandData.Levels
	parcel      "px_pz"      a 10x10 tile piece of land
]]

export type WallData = {
	Kind: CFG_TYPES.WallKind,
	Style: string,
}

export type LevelData = {
	Walls: {[string]: WallData},
	Floors: {[string]: string},
}

export type FurnitureData = {
	Name: string,
	Level: number,
	X: number, -- plot-local studs
	Z: number,
	Rotation: number,
}

export type DirtData = {
	Level: number,
	Cell: string,
	Kind: CFG_TYPES.DirtKind,
}

export type LandData = {
	Levels: {[string]: LevelData},
	Furniture: {[string]: FurnitureData},
	Dirt: {[string]: DirtData},
}

export type RentalData = {
	Tenant: string,
	Rent: number, -- per minute, before cleanliness and passes
	Value: number,
	Pending: number,
	Started: number,
	Cells: {string}, -- level cells of the house
}

export type StatsData = {
	HousesSold: number,
	HousesRented: number,
	TotalEarned: number,
	DirtCleaned: number,
}

export type PlayerData = {
	Cash: number,
	Parcels: {[string]: boolean},
	Levels: number, -- floors unlocked
	Land: LandData,
	Rentals: {[string]: RentalData}, -- key = house id
	UnlockedItems: {[string]: boolean},
	Purchases: {string},
	Stats: StatsData,
	LastOnline: number,
}

export type OfferData = {
	Id: string,
	Name: string,
	Amount: number, -- sale price, or rent per minute
	Expires: number, -- server: os.clock() time / client: seconds left when sent
}

export type ListingData = {
	HouseId: string,
	Mode: CFG_TYPES.ListingMode,
	Value: number,
	Offers: {OfferData},
}

export type RoomData = {
	Level: number,
	Cells: {string},
	Size: number,
	Type: CFG_TYPES.RoomType?,
	Lit: number, -- how many of its tiles are lit
	LitCells: {[string]: boolean},
}

export type HouseInfo = {
	Id: string, -- lowest level cell of the house, stays the same while it is locked
	Rooms: {RoomData},
	Cells: {[string]: boolean}, -- level cells
	CellCount: number,
	LitFraction: number,
	DirtCount: number,
	Cleanliness: number, -- 0.5 .. 1 value multiplier
	BaseValue: number, -- before cleanliness
	Value: number,
	Livable: boolean,
	Complete: boolean,
	Missing: {CFG_TYPES.RoomType},
	CenterX: number, -- plot-local studs
	CenterZ: number,
	TopLevel: number,
}

return nil
