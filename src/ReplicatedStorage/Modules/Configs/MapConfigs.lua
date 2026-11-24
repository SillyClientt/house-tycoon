--!strict
local MapConfigs = {}

-- The suburb is built around the lands when the server starts (see MapServiceServer).
-- Everything here is safe to tweak. Sizes are in studs.

-- turn the grey Baseplate into grass so the suburb doesn't float on studs
MapConfigs.RecolorBaseplate = true

MapConfigs.Colors = {
	Grass = Color3.fromRGB(104, 168, 84),
	Road = Color3.fromRGB(64, 66, 72),
	RoadLine = Color3.fromRGB(250, 214, 80),
	Sidewalk = Color3.fromRGB(205, 200, 190),
	Curb = Color3.fromRGB(170, 166, 158),
	Fence = Color3.fromRGB(250, 248, 240),
	Trunk = Color3.fromRGB(110, 78, 52),
	Leaves = {
		Color3.fromRGB(86, 160, 72),
		Color3.fromRGB(70, 140, 62),
		Color3.fromRGB(112, 176, 80),
		Color3.fromRGB(150, 190, 80),
	},
	LampPost = Color3.fromRGB(48, 52, 64),
	LampGlow = Color3.fromRGB(255, 214, 150),
	Mailbox = Color3.fromRGB(58, 110, 200),
	Flowers = {
		Color3.fromRGB(240, 90, 110),
		Color3.fromRGB(255, 200, 70),
		Color3.fromRGB(190, 120, 230),
		Color3.fromRGB(255, 255, 255),
	},
}

-- streets
MapConfigs.SidewalkWidth = 7
MapConfigs.CurbHeight = 0.3
MapConfigs.DashLength = 8
MapConfigs.DashGap = 10

-- picket fence around the sides and back of each land (the front stays open)
MapConfigs.FenceHeight = 3.5
MapConfigs.PicketSpacing = 5

-- street lamps along every sidewalk
MapConfigs.LampSpacing = 48
MapConfigs.LampHeight = 14
MapConfigs.LampRange = 28
MapConfigs.LampBrightness = 2

-- green belt and park around the neighbourhood
MapConfigs.ParkWidth = 110 -- grass around the outside edge
MapConfigs.ParkTrees = 70
MapConfigs.TreesPerVerge = 3 -- trees on the sidewalk side of each land

-- town square in front of the neighbourhood, where visitors come from
MapConfigs.TownSquare = {
	Depth = 90,
	Width = 200,
	PavingColor = Color3.fromRGB(214, 196, 168),
	Shops = {
		{Name = 'Realty Office', Color = Color3.fromRGB(240, 120, 90)},
		{Name = 'Furniture Store', Color = Color3.fromRGB(90, 150, 230)},
		{Name = 'Cafe', Color = Color3.fromRGB(250, 196, 80)},
	},
}

-- day and night
MapConfigs.DayCycle = {
	Enabled = true,
	MinutesPerDay = 12, -- real minutes for a full 24 hours
	StartTime = 9, -- clock time when the server starts
	NightStart = 18.25, -- street lamps turn on
	NightEnd = 6.25, -- street lamps turn off
}

-- lighting is blended between these two looks as the sun moves
MapConfigs.DayLook = {
	Ambient = Color3.fromRGB(120, 120, 130),
	OutdoorAmbient = Color3.fromRGB(150, 150, 140),
	Brightness = 3,
	ColorTint = Color3.fromRGB(255, 246, 232),
	Saturation = 0.12,
	AtmosphereColor = Color3.fromRGB(199, 220, 240),
	AtmosphereDecay = Color3.fromRGB(106, 150, 190),
}

MapConfigs.NightLook = {
	Ambient = Color3.fromRGB(70, 74, 110),
	OutdoorAmbient = Color3.fromRGB(80, 88, 130),
	Brightness = 1.2,
	ColorTint = Color3.fromRGB(210, 220, 255),
	Saturation = 0.05,
	AtmosphereColor = Color3.fromRGB(60, 70, 110),
	AtmosphereDecay = Color3.fromRGB(40, 44, 80),
}

return MapConfigs
