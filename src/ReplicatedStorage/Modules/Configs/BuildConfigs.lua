--!strict
local BuildConfigs = {}

local RPS = game:GetService('ReplicatedStorage')

local CFG_TYPES = require(RPS.Modules.Types.ConfigTypes)

-- grid
BuildConfigs.CellSize = 6 -- studs per grid tile
BuildConfigs.WallHeight = 14 -- also the height of one floor
BuildConfigs.WallThickness = 0.8
BuildConfigs.FloorThickness = 0.5
BuildConfigs.MaxDragCells = 20
BuildConfigs.RefundRate = 0.75 -- cash back when removing walls, floors or furniture

-- window & door shapes (studs from the ground)
BuildConfigs.WindowBottom = 4
BuildConfigs.WindowTop = 10.5
BuildConfigs.DoorTop = 10
BuildConfigs.UndoSteps = 25 -- build actions remembered for Ctrl+Z

local wallKinds: {[string]: CFG_TYPES.WallKindConfig} = {
	Wall = {DisplayName = 'Wall', Order = 1, ExtraCost = 0, ExtraValue = 0},
	Window = {DisplayName = 'Window', Order = 2, ExtraCost = 40, ExtraValue = 30},
	Door = {DisplayName = 'Door', Order = 3, ExtraCost = 60, ExtraValue = 45},
}

BuildConfigs.WallKinds = wallKinds

local wallStyles: {[string]: CFG_TYPES.WallStyleConfig} = {
	Plaster = {
		DisplayName = 'Plaster',
		Order = 1,
		Cost = 30,
		Value = 21,
		Color = Color3.fromRGB(236, 230, 218),
		Material = Enum.Material.SmoothPlastic,
	},
	Wood = {
		DisplayName = 'Wood',
		Order = 2,
		Cost = 45,
		Value = 33,
		Color = Color3.fromRGB(161, 116, 76),
		Material = Enum.Material.WoodPlanks,
	},
	Painted = {
		DisplayName = 'Painted',
		Order = 3,
		Cost = 45,
		Value = 34,
		Color = Color3.fromRGB(150, 190, 210),
		Material = Enum.Material.SmoothPlastic,
	},
	Brick = {
		DisplayName = 'Brick',
		Order = 4,
		Cost = 60,
		Value = 45,
		Color = Color3.fromRGB(158, 84, 64),
		Material = Enum.Material.Brick,
	},
	Stone = {
		DisplayName = 'Stone',
		Order = 5,
		Cost = 90,
		Value = 69,
		Color = Color3.fromRGB(150, 150, 145),
		Material = Enum.Material.Cobblestone,
	},
}

BuildConfigs.WallStyles = wallStyles

local floorStyles: {[string]: CFG_TYPES.FloorStyleConfig} = {
	Wood = {
		DisplayName = 'Wood',
		Order = 1,
		Cost = 45,
		Value = 39,
		Color = Color3.fromRGB(176, 128, 84),
		Material = Enum.Material.WoodPlanks,
	},
	Carpet = {
		DisplayName = 'Carpet',
		Order = 2,
		Cost = 52,
		Value = 45,
		Color = Color3.fromRGB(120, 140, 170),
		Material = Enum.Material.Fabric,
	},
	Tile = {
		DisplayName = 'Tile',
		Order = 3,
		Cost = 68,
		Value = 57,
		Color = Color3.fromRGB(225, 225, 225),
		Material = Enum.Material.Slate,
	},
	Concrete = {
		DisplayName = 'Concrete',
		Order = 4,
		Cost = 60,
		Value = 51,
		Color = Color3.fromRGB(170, 170, 170),
		Material = Enum.Material.Concrete,
	},
	Marble = {
		DisplayName = 'Marble',
		Order = 5,
		Cost = 135,
		Value = 120,
		Color = Color3.fromRGB(240, 238, 232),
		Material = Enum.Material.Marble,
	},
}

BuildConfigs.FloorStyles = floorStyles

return BuildConfigs
