--!strict
export type WallKind = 'Wall' | 'Window' | 'Door'

export type RoomType = 'Bedroom' | 'Bathroom' | 'Kitchen' | 'LivingRoom' | 'DiningRoom' | 'Office' | 'Laundry'

export type FurnitureCategory = 'Bedroom' | 'Bathroom' | 'Kitchen' | 'Living' | 'Dining' | 'Office' | 'Laundry' | 'Lighting' | 'Decor' | 'Structure'

export type ListingMode = 'Sale' | 'Rent'

export type DirtKind = 'Dust' | 'Stain' | 'Trash'

export type RewardConfig = {
	Cash: number?,
	Transaction: Enum.AnalyticsEconomyTransactionType?
}

export type DeductionConfig = {
	Cash: number?,
	Transaction: Enum.AnalyticsEconomyTransactionType?
}

export type WallStyleConfig = {
	DisplayName: string,
	Order: number,
	Cost: number,
	Value: number,
	Color: Color3,
	Material: Enum.Material,
}

export type WallKindConfig = {
	DisplayName: string,
	Order: number,
	ExtraCost: number,
	ExtraValue: number,
}

export type FloorStyleConfig = {
	DisplayName: string,
	Order: number,
	Cost: number,
	Value: number,
	Color: Color3,
	Material: Enum.Material,
}

export type RoomTypeConfig = {
	DisplayName: string,
	Order: number,
	Bonus: number,
	IdealCells: number,
}

export type FurniturePartConfig = {
	Size: Vector3,
	Offset: Vector3,
	Color: Color3,
	Material: Enum.Material?,
	Transparency: number?,
	Light: boolean?, -- adds a PointLight (looks only - LightRange decides game lighting)
	Wedge: boolean?, -- WedgePart instead of Part (slope rises towards +Z)
	NoCollide: boolean?,
}

export type PremiumConfig = {
	ProductId: number, -- developer product that unlocks the item forever
	RobuxPrice: number, -- shown in the UI only, the real price is set on the website
}

export type FurnitureConfig = {
	DisplayName: string,
	Category: FurnitureCategory,
	Order: number,
	Price: number,
	Footprint: Vector2,
	Room: RoomType?, -- key item that decides a room's type
	Flat: boolean?, -- can overlap other furniture (rugs, ceiling lights)
	LightRange: number?, -- studs of floor this item lights up
	ValueRate: number?, -- overrides MarketConfigs.FurnitureValueRate
	CellAligned: boolean?, -- must line up with the build grid
	Stairs: boolean?, -- connects this floor to the one above
	Premium: PremiumConfig?, -- unlocked with Robux
	Vip: boolean?, -- needs the VIP Furniture gamepass
	Shape: {FurniturePartConfig}?,
}

export type ParcelTierConfig = {
	MaxOwned: number, -- tier used while the player owns this many parcels or fewer
	ProductId: number,
	RobuxPrice: number,
}

export type LevelConfig = {
	DisplayName: string,
	Cost: number,
}

export type GamepassConfig = {
	Id: number,
	DisplayName: string,
	Description: string,
	RobuxPrice: number,
	Order: number,
}

export type CashPackConfig = {
	Id: number,
	Cash: number,
	RobuxPrice: number,
	Order: number,
}

return nil
