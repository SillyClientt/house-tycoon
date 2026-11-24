--!strict
local FurnitureConfigs = {}

local RPS = game:GetService('ReplicatedStorage')

local CFG_TYPES = require(RPS.Modules.Types.ConfigTypes)

-- Every piece adds Price * ValueRate (default MarketConfigs.FurnitureValueRate) to its house.
-- Each item is built from its Shape (simple parts) unless a Model with the same
-- name exists in ReplicatedStorage.Furniture - then that model is used instead.
-- Offsets are from the bottom-centre of the item. The front of an item faces -Z.

local WHITE = Color3.fromRGB(240, 240, 240)
local OAK = Color3.fromRGB(176, 128, 84)
local WALNUT = Color3.fromRGB(110, 74, 50)
local FABRIC = Color3.fromRGB(96, 118, 150)
local DARK = Color3.fromRGB(35, 35, 40)
local STEEL = Color3.fromRGB(190, 195, 200)
local GREEN = Color3.fromRGB(78, 140, 70)

local GOLD = Color3.fromRGB(232, 190, 80)
local MARBLE = Color3.fromRGB(240, 238, 232)
local WARM_LIGHT = Color3.fromRGB(255, 236, 190)

local WOOD = Enum.Material.Wood
local CLOTH = Enum.Material.Fabric
local METAL = Enum.Material.Metal

-- shorthand for one part of an item's shape
local function part(
	Size: Vector3,
	Offset: Vector3,
	Color: Color3,
	Material: Enum.Material?,
	Transparency: number?
): CFG_TYPES.FurniturePartConfig
	return {
		Size = Size,
		Offset = Offset,
		Color = Color,
		Material = Material,
		Transparency = Transparency,
	}
end

-- a glowing part that also adds a PointLight
local function light(Size: Vector3, Offset: Vector3, Color: Color3?): CFG_TYPES.FurniturePartConfig
	return {
		Size = Size,
		Offset = Offset,
		Color = Color or WARM_LIGHT,
		Material = Enum.Material.Neon,
		Light = true,
	}
end

-- stairs: an invisible ramp to walk on + visible steps (1 tile wide, 2 tiles long, one floor high)
local function stairs(Color: Color3): {CFG_TYPES.FurniturePartConfig}
	local list: {CFG_TYPES.FurniturePartConfig} = {
		{
			Size = Vector3.new(6, 14, 12),
			Offset = Vector3.new(0, 7, 0),
			Color = Color,
			Transparency = 1,
			Wedge = true,
		},
		part(Vector3.new(0.4, 14, 12), Vector3.new(-2.8, 7, 0), Color, WOOD),
	}

	for step = 1, 14 do
		table.insert(list, {
			Size = Vector3.new(5.6, 0.5, 1),
			Offset = Vector3.new(0, step - 0.25, -6 + (12 / 14) * (step - 0.5)),
			Color = Color,
			Material = WOOD,
			NoCollide = true,
		})
	end

	return list
end

-- four legs under a rectangular top
local function legs(Width: number, Depth: number, Height: number, Color: Color3): {CFG_TYPES.FurniturePartConfig}
	local x = Width / 2 - 0.25
	local z = Depth / 2 - 0.25

	return {
		part(Vector3.new(0.4, Height, 0.4), Vector3.new(x, Height / 2, z), Color, WOOD),
		part(Vector3.new(0.4, Height, 0.4), Vector3.new(-x, Height / 2, z), Color, WOOD),
		part(Vector3.new(0.4, Height, 0.4), Vector3.new(x, Height / 2, -z), Color, WOOD),
		part(Vector3.new(0.4, Height, 0.4), Vector3.new(-x, Height / 2, -z), Color, WOOD),
	}
end

-- join part lists into one shape
local function shape(...: {CFG_TYPES.FurniturePartConfig}): {CFG_TYPES.FurniturePartConfig}
	local result = {}

	for _, list in {...} do
		for _, item in list do
			table.insert(result, item)
		end
	end

	return result
end

local categories: {{Name: CFG_TYPES.FurnitureCategory, DisplayName: string}} = {
	{Name = 'Bedroom', DisplayName = 'Bedroom'},
	{Name = 'Bathroom', DisplayName = 'Bathroom'},
	{Name = 'Kitchen', DisplayName = 'Kitchen'},
	{Name = 'Living', DisplayName = 'Living'},
	{Name = 'Dining', DisplayName = 'Dining'},
	{Name = 'Office', DisplayName = 'Office'},
	{Name = 'Laundry', DisplayName = 'Laundry'},
	{Name = 'Lighting', DisplayName = 'Lights'},
	{Name = 'Decor', DisplayName = 'Decor'},
	{Name = 'Structure', DisplayName = 'Stairs'},
}

FurnitureConfigs.Categories = categories

local items: {[string]: CFG_TYPES.FurnitureConfig} = {
	-- bedroom
	SingleBed = {
		DisplayName = 'Single Bed',
		Category = 'Bedroom',
		Order = 1,
		Price = 250,
		Footprint = Vector2.new(3.5, 7),
		Room = 'Bedroom',
		Shape = {
			part(Vector3.new(3.5, 1.2, 7), Vector3.new(0, 0.6, 0), WALNUT, WOOD),
			part(Vector3.new(3.2, 0.6, 6.6), Vector3.new(0, 1.5, 0), WHITE, CLOTH),
			part(Vector3.new(3.3, 0.2, 4.2), Vector3.new(0, 1.9, -1.2), FABRIC, CLOTH),
			part(Vector3.new(2.4, 0.4, 1.2), Vector3.new(0, 2, 2.6), WHITE, CLOTH),
			part(Vector3.new(3.5, 3, 0.4), Vector3.new(0, 1.5, 3.3), WALNUT, WOOD),
		},
	},
	DoubleBed = {
		DisplayName = 'Double Bed',
		Category = 'Bedroom',
		Order = 2,
		Price = 450,
		Footprint = Vector2.new(5.5, 7),
		Room = 'Bedroom',
		Shape = {
			part(Vector3.new(5.5, 1.2, 7), Vector3.new(0, 0.6, 0), WALNUT, WOOD),
			part(Vector3.new(5.2, 0.6, 6.6), Vector3.new(0, 1.5, 0), WHITE, CLOTH),
			part(Vector3.new(5.3, 0.2, 4.2), Vector3.new(0, 1.9, -1.2), FABRIC, CLOTH),
			part(Vector3.new(2, 0.4, 1.2), Vector3.new(-1.3, 2, 2.6), WHITE, CLOTH),
			part(Vector3.new(2, 0.4, 1.2), Vector3.new(1.3, 2, 2.6), WHITE, CLOTH),
			part(Vector3.new(5.5, 3.4, 0.4), Vector3.new(0, 1.7, 3.3), WALNUT, WOOD),
		},
	},
	Nightstand = {
		DisplayName = 'Nightstand',
		Category = 'Bedroom',
		Order = 3,
		Price = 60,
		Footprint = Vector2.new(1.6, 1.6),
		Shape = {
			part(Vector3.new(1.6, 2, 1.6), Vector3.new(0, 1, 0), WALNUT, WOOD),
			part(Vector3.new(1.2, 0.5, 0.05), Vector3.new(0, 1.3, -0.82), OAK, WOOD),
		},
	},
	Wardrobe = {
		DisplayName = 'Wardrobe',
		Category = 'Bedroom',
		Order = 4,
		Price = 220,
		Footprint = Vector2.new(4, 2),
		Shape = {
			part(Vector3.new(4, 7, 2), Vector3.new(0, 3.5, 0), WALNUT, WOOD),
			part(Vector3.new(0.1, 6.4, 0.05), Vector3.new(0, 3.5, -1.02), DARK),
		},
	},

	-- bathroom
	Toilet = {
		DisplayName = 'Toilet',
		Category = 'Bathroom',
		Order = 1,
		Price = 150,
		Footprint = Vector2.new(2, 3),
		Room = 'Bathroom',
		Shape = {
			part(Vector3.new(1.4, 1.4, 1.8), Vector3.new(0, 0.7, -0.3), WHITE),
			part(Vector3.new(1.8, 0.3, 2), Vector3.new(0, 1.55, -0.4), WHITE),
			part(Vector3.new(1.8, 2, 0.8), Vector3.new(0, 2, 1.1), WHITE),
		},
	},
	Sink = {
		DisplayName = 'Bathroom Sink',
		Category = 'Bathroom',
		Order = 2,
		Price = 120,
		Footprint = Vector2.new(2.5, 1.8),
		Shape = {
			part(Vector3.new(2.5, 2.8, 1.8), Vector3.new(0, 1.4, 0), OAK, WOOD),
			part(Vector3.new(2.2, 0.3, 1.4), Vector3.new(0, 2.95, 0), WHITE),
			part(Vector3.new(0.2, 0.6, 0.2), Vector3.new(0, 3.4, 0.6), STEEL, METAL),
		},
	},
	Shower = {
		DisplayName = 'Shower',
		Category = 'Bathroom',
		Order = 3,
		Price = 300,
		Footprint = Vector2.new(4, 4),
		Room = 'Bathroom',
		Shape = {
			part(Vector3.new(4, 0.3, 4), Vector3.new(0, 0.15, 0), WHITE),
			part(Vector3.new(0.15, 7, 4), Vector3.new(-1.93, 3.8, 0), Color3.fromRGB(200, 230, 255), Enum.Material.Glass, 0.6),
			part(Vector3.new(4, 7, 0.15), Vector3.new(0, 3.8, -1.93), Color3.fromRGB(200, 230, 255), Enum.Material.Glass, 0.6),
			part(Vector3.new(0.6, 0.2, 0.6), Vector3.new(0, 7.2, 1.5), STEEL, METAL),
		},
	},
	Bathtub = {
		DisplayName = 'Bathtub',
		Category = 'Bathroom',
		Order = 4,
		Price = 380,
		Footprint = Vector2.new(3.5, 7),
		Room = 'Bathroom',
		Shape = {
			part(Vector3.new(3.5, 2.2, 7), Vector3.new(0, 1.1, 0), WHITE),
			part(Vector3.new(3, 0.2, 6.4), Vector3.new(0, 2.05, 0), Color3.fromRGB(120, 190, 230), Enum.Material.SmoothPlastic, 0.3),
		},
	},

	-- kitchen
	Fridge = {
		DisplayName = 'Fridge',
		Category = 'Kitchen',
		Order = 1,
		Price = 350,
		Footprint = Vector2.new(3, 3),
		Room = 'Kitchen',
		Shape = {
			part(Vector3.new(3, 7.5, 3), Vector3.new(0, 3.75, 0), STEEL, METAL),
			part(Vector3.new(0.2, 2.5, 0.2), Vector3.new(1.1, 4.5, -1.6), DARK),
			part(Vector3.new(3, 0.08, 0.05), Vector3.new(0, 5, -1.52), DARK),
		},
	},
	Stove = {
		DisplayName = 'Stove',
		Category = 'Kitchen',
		Order = 2,
		Price = 300,
		Footprint = Vector2.new(3, 3),
		Room = 'Kitchen',
		Shape = {
			part(Vector3.new(3, 3, 3), Vector3.new(0, 1.5, 0), WHITE),
			part(Vector3.new(3, 0.2, 3), Vector3.new(0, 3.1, 0), DARK),
			part(Vector3.new(2.2, 1.4, 0.05), Vector3.new(0, 1.4, -1.52), DARK, Enum.Material.Glass),
		},
	},
	Counter = {
		DisplayName = 'Counter',
		Category = 'Kitchen',
		Order = 3,
		Price = 140,
		Footprint = Vector2.new(3, 3),
		Shape = {
			part(Vector3.new(3, 3, 3), Vector3.new(0, 1.5, 0), OAK, WOOD),
			part(Vector3.new(3.1, 0.3, 3.1), Vector3.new(0, 3.15, 0), Color3.fromRGB(60, 60, 64), Enum.Material.Granite),
		},
	},
	KitchenSink = {
		DisplayName = 'Kitchen Sink',
		Category = 'Kitchen',
		Order = 4,
		Price = 180,
		Footprint = Vector2.new(3, 3),
		Shape = {
			part(Vector3.new(3, 3, 3), Vector3.new(0, 1.5, 0), OAK, WOOD),
			part(Vector3.new(3.1, 0.3, 3.1), Vector3.new(0, 3.15, 0), Color3.fromRGB(60, 60, 64), Enum.Material.Granite),
			part(Vector3.new(2, 0.1, 1.8), Vector3.new(0, 3.32, -0.2), STEEL, METAL),
			part(Vector3.new(0.2, 0.8, 0.2), Vector3.new(0, 3.7, 1), STEEL, METAL),
		},
	},

	-- living
	Sofa = {
		DisplayName = 'Sofa',
		Category = 'Living',
		Order = 1,
		Price = 400,
		Footprint = Vector2.new(7, 3),
		Room = 'LivingRoom',
		Shape = {
			part(Vector3.new(7, 1.6, 3), Vector3.new(0, 0.8, 0), FABRIC, CLOTH),
			part(Vector3.new(7, 2.2, 0.8), Vector3.new(0, 2.7, 1.1), FABRIC, CLOTH),
			part(Vector3.new(0.8, 2.4, 3), Vector3.new(3.1, 1.2, 0), FABRIC, CLOTH),
			part(Vector3.new(0.8, 2.4, 3), Vector3.new(-3.1, 1.2, 0), FABRIC, CLOTH),
		},
	},
	Armchair = {
		DisplayName = 'Armchair',
		Category = 'Living',
		Order = 2,
		Price = 180,
		Footprint = Vector2.new(3, 3),
		Shape = {
			part(Vector3.new(3, 1.6, 3), Vector3.new(0, 0.8, 0), FABRIC, CLOTH),
			part(Vector3.new(3, 2.2, 0.7), Vector3.new(0, 2.7, 1.15), FABRIC, CLOTH),
			part(Vector3.new(0.6, 2.4, 3), Vector3.new(1.2, 1.2, 0), FABRIC, CLOTH),
			part(Vector3.new(0.6, 2.4, 3), Vector3.new(-1.2, 1.2, 0), FABRIC, CLOTH),
		},
	},
	TV = {
		DisplayName = 'TV',
		Category = 'Living',
		Order = 3,
		Price = 500,
		Footprint = Vector2.new(5, 1.6),
		Room = 'LivingRoom',
		Shape = {
			part(Vector3.new(5, 2, 1.6), Vector3.new(0, 1, 0), WALNUT, WOOD),
			part(Vector3.new(4.6, 2.8, 0.2), Vector3.new(0, 3.6, 0.3), DARK, Enum.Material.Glass),
		},
	},
	CoffeeTable = {
		DisplayName = 'Coffee Table',
		Category = 'Living',
		Order = 4,
		Price = 120,
		Footprint = Vector2.new(4, 2.5),
		Shape = shape(
			{part(Vector3.new(4, 0.3, 2.5), Vector3.new(0, 1.65, 0), OAK, WOOD)},
			legs(4, 2.5, 1.5, WALNUT)
		),
	},

	-- dining
	DiningTable = {
		DisplayName = 'Dining Table',
		Category = 'Dining',
		Order = 1,
		Price = 300,
		Footprint = Vector2.new(6, 4),
		Room = 'DiningRoom',
		Shape = shape(
			{part(Vector3.new(6, 0.3, 4), Vector3.new(0, 3.15, 0), OAK, WOOD)},
			legs(6, 4, 3, WALNUT)
		),
	},
	Chair = {
		DisplayName = 'Chair',
		Category = 'Dining',
		Order = 2,
		Price = 60,
		Footprint = Vector2.new(2.5, 2.5),
		Shape = shape(
			{
				part(Vector3.new(2, 0.4, 2), Vector3.new(0, 1.8, 0), OAK, WOOD),
				part(Vector3.new(2, 2.4, 0.4), Vector3.new(0, 3.2, 0.8), OAK, WOOD),
			},
			legs(2, 2, 1.6, WALNUT)
		),
	},

	-- office
	Desk = {
		DisplayName = 'Desk',
		Category = 'Office',
		Order = 1,
		Price = 250,
		Footprint = Vector2.new(5, 2.5),
		Room = 'Office',
		Shape = {
			part(Vector3.new(5, 0.3, 2.5), Vector3.new(0, 3.15, 0), OAK, WOOD),
			part(Vector3.new(0.3, 3, 2.5), Vector3.new(2.35, 1.5, 0), WALNUT, WOOD),
			part(Vector3.new(1.6, 3, 2.5), Vector3.new(-1.7, 1.5, 0), WALNUT, WOOD),
		},
	},
	Bookshelf = {
		DisplayName = 'Bookshelf',
		Category = 'Office',
		Order = 2,
		Price = 200,
		Footprint = Vector2.new(4, 1.5),
		Shape = {
			part(Vector3.new(4, 7, 1.5), Vector3.new(0, 3.5, 0), WALNUT, WOOD),
			part(Vector3.new(3.4, 1.2, 0.05), Vector3.new(0, 1.5, -0.77), Color3.fromRGB(150, 60, 60)),
			part(Vector3.new(3.4, 1.2, 0.05), Vector3.new(0, 3.5, -0.77), Color3.fromRGB(60, 90, 150)),
			part(Vector3.new(3.4, 1.2, 0.05), Vector3.new(0, 5.5, -0.77), Color3.fromRGB(70, 130, 80)),
		},
	},

	-- decor
	Plant = {
		DisplayName = 'Plant',
		Category = 'Decor',
		Order = 1,
		Price = 40,
		Footprint = Vector2.new(1.6, 1.6),
		Shape = {
			part(Vector3.new(1.4, 1.4, 1.4), Vector3.new(0, 0.7, 0), Color3.fromRGB(170, 95, 70), Enum.Material.Slate),
			part(Vector3.new(2, 2.2, 2), Vector3.new(0, 2.5, 0), GREEN, Enum.Material.Grass),
		},
	},
	Rug = {
		DisplayName = 'Rug',
		Category = 'Decor',
		Order = 3,
		Price = 80,
		Footprint = Vector2.new(6, 4),
		Flat = true,
		Shape = {
			part(Vector3.new(6, 0.05, 4), Vector3.new(0, 0.03, 0), Color3.fromRGB(150, 70, 70), CLOTH),
		},
	},

	BunkBed = {
		DisplayName = 'Bunk Bed',
		Category = 'Bedroom',
		Order = 5,
		Price = 380,
		Footprint = Vector2.new(3.5, 7),
		Room = 'Bedroom',
		Shape = {
			part(Vector3.new(3.5, 0.8, 7), Vector3.new(0, 1, 0), WALNUT, WOOD),
			part(Vector3.new(3.2, 0.5, 6.6), Vector3.new(0, 1.65, 0), FABRIC, CLOTH),
			part(Vector3.new(3.5, 0.8, 7), Vector3.new(0, 4.6, 0), WALNUT, WOOD),
			part(Vector3.new(3.2, 0.5, 6.6), Vector3.new(0, 5.25, 0), Color3.fromRGB(170, 90, 90), CLOTH),
			part(Vector3.new(0.4, 6.5, 0.4), Vector3.new(1.55, 3.25, 3.3), WALNUT, WOOD),
			part(Vector3.new(0.4, 6.5, 0.4), Vector3.new(-1.55, 3.25, 3.3), WALNUT, WOOD),
			part(Vector3.new(0.4, 6.5, 0.4), Vector3.new(1.55, 3.25, -3.3), WALNUT, WOOD),
			part(Vector3.new(0.4, 6.5, 0.4), Vector3.new(-1.55, 3.25, -3.3), WALNUT, WOOD),
		},
	},
	Dresser = {
		DisplayName = 'Dresser',
		Category = 'Bedroom',
		Order = 6,
		Price = 160,
		Footprint = Vector2.new(4, 1.8),
		Shape = {
			part(Vector3.new(4, 3.2, 1.8), Vector3.new(0, 1.6, 0), OAK, WOOD),
			part(Vector3.new(3.6, 0.08, 0.05), Vector3.new(0, 1.1, -0.92), WALNUT),
			part(Vector3.new(3.6, 0.08, 0.05), Vector3.new(0, 2.1, -0.92), WALNUT),
		},
	},
	BathCabinet = {
		DisplayName = 'Bath Cabinet',
		Category = 'Bathroom',
		Order = 5,
		Price = 90,
		Footprint = Vector2.new(2, 1.2),
		Shape = {
			part(Vector3.new(2, 4, 1.2), Vector3.new(0, 2, 0), WHITE),
			part(Vector3.new(1.6, 1.6, 0.05), Vector3.new(0, 3, -0.62), Color3.fromRGB(200, 230, 255), Enum.Material.Glass),
		},
	},
	Dishwasher = {
		DisplayName = 'Dishwasher',
		Category = 'Kitchen',
		Order = 5,
		Price = 220,
		Footprint = Vector2.new(3, 3),
		Shape = {
			part(Vector3.new(3, 3, 3), Vector3.new(0, 1.5, 0), STEEL, METAL),
			part(Vector3.new(3.1, 0.3, 3.1), Vector3.new(0, 3.15, 0), Color3.fromRGB(60, 60, 64), Enum.Material.Granite),
			part(Vector3.new(2, 0.15, 0.1), Vector3.new(0, 2.6, -1.55), DARK),
		},
	},
	KitchenIsland = {
		DisplayName = 'Kitchen Island',
		Category = 'Kitchen',
		Order = 6,
		Price = 320,
		Footprint = Vector2.new(6, 3),
		Shape = {
			part(Vector3.new(5.6, 3, 2.6), Vector3.new(0, 1.5, 0), OAK, WOOD),
			part(Vector3.new(6, 0.3, 3), Vector3.new(0, 3.15, 0), MARBLE, Enum.Material.Marble),
		},
	},
	Fireplace = {
		DisplayName = 'Fireplace',
		Category = 'Living',
		Order = 5,
		Price = 600,
		Footprint = Vector2.new(5, 1.8),
		LightRange = 6,
		Shape = {
			part(Vector3.new(5, 5, 1.8), Vector3.new(0, 2.5, 0), Color3.fromRGB(150, 150, 145), Enum.Material.Cobblestone),
			part(Vector3.new(2.6, 2, 0.2), Vector3.new(0, 1.3, -0.85), DARK),
			light(Vector3.new(1.8, 0.8, 0.3), Vector3.new(0, 0.8, -0.8), Color3.fromRGB(255, 140, 60)),
		},
	},
	BeanBag = {
		DisplayName = 'Bean Bag',
		Category = 'Living',
		Order = 6,
		Price = 70,
		Footprint = Vector2.new(2.5, 2.5),
		Shape = {
			part(Vector3.new(2.5, 1.6, 2.5), Vector3.new(0, 0.8, 0), Color3.fromRGB(200, 110, 60), CLOTH),
		},
	},
	BarStool = {
		DisplayName = 'Bar Stool',
		Category = 'Dining',
		Order = 3,
		Price = 50,
		Footprint = Vector2.new(1.6, 1.6),
		Shape = {
			part(Vector3.new(0.3, 2.8, 0.3), Vector3.new(0, 1.4, 0), DARK, METAL),
			part(Vector3.new(1.6, 0.3, 1.6), Vector3.new(0, 2.95, 0), Color3.fromRGB(170, 60, 60), CLOTH),
			part(Vector3.new(1.2, 0.1, 1.2), Vector3.new(0, 0.05, 0), DARK, METAL),
		},
	},
	Sideboard = {
		DisplayName = 'Sideboard',
		Category = 'Dining',
		Order = 4,
		Price = 180,
		Footprint = Vector2.new(5, 1.6),
		Shape = {
			part(Vector3.new(5, 3, 1.6), Vector3.new(0, 1.8, 0), WALNUT, WOOD),
			part(Vector3.new(0.3, 0.3, 1.4), Vector3.new(2.2, 0.15, 0), DARK),
			part(Vector3.new(0.3, 0.3, 1.4), Vector3.new(-2.2, 0.15, 0), DARK),
		},
	},
	OfficeChair = {
		DisplayName = 'Office Chair',
		Category = 'Office',
		Order = 3,
		Price = 110,
		Footprint = Vector2.new(2.2, 2.2),
		Shape = {
			part(Vector3.new(1.6, 0.2, 1.6), Vector3.new(0, 0.1, 0), DARK, METAL),
			part(Vector3.new(0.3, 1.6, 0.3), Vector3.new(0, 0.9, 0), DARK, METAL),
			part(Vector3.new(2, 0.4, 2), Vector3.new(0, 1.9, 0), DARK, CLOTH),
			part(Vector3.new(2, 2.4, 0.4), Vector3.new(0, 3.2, 0.8), DARK, CLOTH),
		},
	},
	FilingCabinet = {
		DisplayName = 'Filing Cabinet',
		Category = 'Office',
		Order = 4,
		Price = 90,
		Footprint = Vector2.new(1.6, 2),
		Shape = {
			part(Vector3.new(1.6, 4, 2), Vector3.new(0, 2, 0), STEEL, METAL),
			part(Vector3.new(0.6, 0.1, 0.1), Vector3.new(0, 3.2, -1.02), DARK),
			part(Vector3.new(0.6, 0.1, 0.1), Vector3.new(0, 1.8, -1.02), DARK),
		},
	},
	Washer = {
		DisplayName = 'Washing Machine',
		Category = 'Laundry',
		Order = 1,
		Price = 260,
		Footprint = Vector2.new(2.8, 2.8),
		Room = 'Laundry',
		Shape = {
			part(Vector3.new(2.8, 3.4, 2.8), Vector3.new(0, 1.7, 0), WHITE),
			part(Vector3.new(1.6, 1.6, 0.1), Vector3.new(0, 1.6, -1.42), Color3.fromRGB(120, 170, 210), Enum.Material.Glass),
		},
	},
	Dryer = {
		DisplayName = 'Dryer',
		Category = 'Laundry',
		Order = 2,
		Price = 240,
		Footprint = Vector2.new(2.8, 2.8),
		Room = 'Laundry',
		Shape = {
			part(Vector3.new(2.8, 3.4, 2.8), Vector3.new(0, 1.7, 0), Color3.fromRGB(225, 225, 230)),
			part(Vector3.new(1.6, 1.6, 0.1), Vector3.new(0, 1.6, -1.42), DARK, Enum.Material.Glass),
		},
	},
	LaundryBasket = {
		DisplayName = 'Laundry Basket',
		Category = 'Laundry',
		Order = 3,
		Price = 40,
		Footprint = Vector2.new(1.6, 1.6),
		Shape = {
			part(Vector3.new(1.6, 1.8, 1.6), Vector3.new(0, 0.9, 0), Color3.fromRGB(200, 180, 140), Enum.Material.Fabric),
		},
	},

	-- lighting (LightRange = how far the light reaches on the floor, in studs)
	CeilingLight = {
		DisplayName = 'Ceiling Light',
		Category = 'Lighting',
		Order = 1,
		Price = 120,
		Footprint = Vector2.new(2, 2),
		Flat = true,
		LightRange = 14,
		Shape = {
			part(Vector3.new(0.2, 0.6, 0.2), Vector3.new(0, 13.2, 0), DARK, METAL),
			light(Vector3.new(2, 0.3, 2), Vector3.new(0, 12.8, 0)),
		},
	},
	FloorLamp = {
		DisplayName = 'Floor Lamp',
		Category = 'Lighting',
		Order = 2,
		Price = 90,
		Footprint = Vector2.new(1.4, 1.4),
		LightRange = 10,
		Shape = {
			part(Vector3.new(1.2, 0.2, 1.2), Vector3.new(0, 0.1, 0), DARK, METAL),
			part(Vector3.new(0.3, 5, 0.3), Vector3.new(0, 2.7, 0), DARK, METAL),
			light(Vector3.new(1.4, 1.2, 1.4), Vector3.new(0, 5.6, 0)),
		},
	},
	TableLamp = {
		DisplayName = 'Table Lamp',
		Category = 'Lighting',
		Order = 3,
		Price = 60,
		Footprint = Vector2.new(1.6, 1.6),
		LightRange = 7,
		Shape = {
			part(Vector3.new(1.6, 2, 1.6), Vector3.new(0, 1, 0), OAK, WOOD),
			part(Vector3.new(0.2, 0.8, 0.2), Vector3.new(0, 2.4, 0), DARK, METAL),
			light(Vector3.new(1, 0.8, 1), Vector3.new(0, 3.2, 0)),
		},
	},

	-- decor
	BigPlant = {
		DisplayName = 'Big Plant',
		Category = 'Decor',
		Order = 4,
		Price = 90,
		Footprint = Vector2.new(2, 2),
		Shape = {
			part(Vector3.new(1.8, 1.8, 1.8), Vector3.new(0, 0.9, 0), WHITE, Enum.Material.Slate),
			part(Vector3.new(0.4, 2.5, 0.4), Vector3.new(0, 3, 0), WALNUT, WOOD),
			part(Vector3.new(2.6, 2.6, 2.6), Vector3.new(0, 5, 0), GREEN, Enum.Material.Grass),
		},
	},
	Clock = {
		DisplayName = 'Grandfather Clock',
		Category = 'Decor',
		Order = 5,
		Price = 150,
		Footprint = Vector2.new(1.6, 1.2),
		Shape = {
			part(Vector3.new(1.6, 7, 1.2), Vector3.new(0, 3.5, 0), WALNUT, WOOD),
			part(Vector3.new(1.1, 1.1, 0.05), Vector3.new(0, 5.8, -0.62), WHITE),
		},
	},
	Aquarium = {
		DisplayName = 'Aquarium',
		Category = 'Decor',
		Order = 6,
		Price = 450,
		Footprint = Vector2.new(4, 1.6),
		LightRange = 5,
		Shape = {
			part(Vector3.new(4, 2.6, 1.6), Vector3.new(0, 1.3, 0), WALNUT, WOOD),
			part(Vector3.new(4, 2.2, 1.6), Vector3.new(0, 3.7, 0), Color3.fromRGB(90, 170, 230), Enum.Material.Glass, 0.4),
			light(Vector3.new(3.8, 0.2, 1.4), Vector3.new(0, 4.9, 0), Color3.fromRGB(150, 210, 255)),
		},
	},

	-- structure
	Stairs = {
		DisplayName = 'Stairs',
		Category = 'Structure',
		Order = 1,
		Price = 400,
		Footprint = Vector2.new(6, 12),
		CellAligned = true,
		Stairs = true,
		Shape = stairs(OAK),
	},

	-- premium (unlocked once with Robux, then bought with cash)
	GoldenBed = {
		DisplayName = 'Golden Bed',
		Category = 'Bedroom',
		Order = 20,
		Price = 2000,
		ValueRate = 1.6,
		Footprint = Vector2.new(5.5, 7),
		Room = 'Bedroom',
		Premium = {ProductId = 0, RobuxPrice = 99},
		Shape = {
			part(Vector3.new(5.5, 1.4, 7), Vector3.new(0, 0.7, 0), GOLD, Enum.Material.Foil),
			part(Vector3.new(5.2, 0.6, 6.6), Vector3.new(0, 1.7, 0), WHITE, CLOTH),
			part(Vector3.new(5.3, 0.2, 4.2), Vector3.new(0, 2.1, -1.2), Color3.fromRGB(140, 40, 60), CLOTH),
			part(Vector3.new(5.5, 4.5, 0.5), Vector3.new(0, 2.25, 3.25), GOLD, Enum.Material.Foil),
		},
	},
	Jacuzzi = {
		DisplayName = 'Jacuzzi',
		Category = 'Bathroom',
		Order = 20,
		Price = 2500,
		ValueRate = 1.6,
		Footprint = Vector2.new(6, 6),
		Room = 'Bathroom',
		Premium = {ProductId = 0, RobuxPrice = 149},
		Shape = {
			part(Vector3.new(6, 2.4, 6), Vector3.new(0, 1.2, 0), MARBLE, Enum.Material.Marble),
			part(Vector3.new(5.2, 0.2, 5.2), Vector3.new(0, 2.25, 0), Color3.fromRGB(110, 200, 240), Enum.Material.SmoothPlastic, 0.3),
		},
	},
	GrandPiano = {
		DisplayName = 'Grand Piano',
		Category = 'Living',
		Order = 20,
		Price = 3000,
		ValueRate = 1.6,
		Footprint = Vector2.new(5, 6),
		Premium = {ProductId = 0, RobuxPrice = 199},
		Shape = shape(
			{
				part(Vector3.new(5, 1.2, 6), Vector3.new(0, 2.8, 0), DARK),
				part(Vector3.new(4.6, 0.3, 1), Vector3.new(0, 2.4, -2.8), WHITE),
			},
			legs(5, 6, 2.2, DARK)
		),
	},
	Chandelier = {
		DisplayName = 'Chandelier',
		Category = 'Lighting',
		Order = 20,
		Price = 1500,
		ValueRate = 1.6,
		Footprint = Vector2.new(3, 3),
		Flat = true,
		LightRange = 22,
		Premium = {ProductId = 0, RobuxPrice = 99},
		Shape = {
			part(Vector3.new(0.2, 1.4, 0.2), Vector3.new(0, 12.8, 0), GOLD, Enum.Material.Foil),
			part(Vector3.new(3, 0.3, 3), Vector3.new(0, 12, 0), GOLD, Enum.Material.Foil),
			light(Vector3.new(2.2, 0.8, 2.2), Vector3.new(0, 11.5, 0)),
		},
	},

	-- VIP gamepass set
	VipSofa = {
		DisplayName = 'VIP Sofa',
		Category = 'Living',
		Order = 30,
		Price = 1500,
		ValueRate = 1.6,
		Footprint = Vector2.new(8, 3.5),
		Room = 'LivingRoom',
		Vip = true,
		Shape = {
			part(Vector3.new(8, 1.6, 3.5), Vector3.new(0, 0.8, 0), Color3.fromRGB(120, 40, 160), CLOTH),
			part(Vector3.new(8, 2.4, 0.8), Vector3.new(0, 2.8, 1.35), Color3.fromRGB(120, 40, 160), CLOTH),
			part(Vector3.new(8.2, 0.2, 3.7), Vector3.new(0, 0.1, 0), GOLD, Enum.Material.Foil),
		},
	},
	NeonSign = {
		DisplayName = 'Neon Sign',
		Category = 'Lighting',
		Order = 30,
		Price = 600,
		ValueRate = 1.6,
		Footprint = Vector2.new(3, 1),
		LightRange = 9,
		Vip = true,
		Shape = {
			part(Vector3.new(0.3, 3, 0.3), Vector3.new(0, 1.5, 0), DARK, METAL),
			light(Vector3.new(3, 1.4, 0.3), Vector3.new(0, 3.7, 0), Color3.fromRGB(255, 80, 200)),
		},
	},
	MarbleStatue = {
		DisplayName = 'Marble Statue',
		Category = 'Decor',
		Order = 30,
		Price = 1200,
		ValueRate = 1.6,
		Footprint = Vector2.new(2.5, 2.5),
		Vip = true,
		Shape = {
			part(Vector3.new(2.5, 1.5, 2.5), Vector3.new(0, 0.75, 0), MARBLE, Enum.Material.Marble),
			part(Vector3.new(1.2, 4, 1.2), Vector3.new(0, 3.5, 0), MARBLE, Enum.Material.Marble),
			part(Vector3.new(1.4, 1.4, 1.4), Vector3.new(0, 6.2, 0), MARBLE, Enum.Material.Marble),
		},
	},
}

FurnitureConfigs.Items = items

return FurnitureConfigs
