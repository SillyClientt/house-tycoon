--!strict
local TenantConfigs = {}

export type Pose = 'Sit' | 'Sleep' | 'Stand'

export type UseConfig = {
	Pose: Pose,
	Icon: string, -- shown in the bubble while using it
	Time: {Min: number, Max: number}, -- seconds spent using it
	Height: number?, -- studs above the floor to sit / lie at
}

-- what tenants do with each piece of furniture (items not listed are ignored)
local uses: {[string]: UseConfig} = {
	SingleBed = {Pose = 'Sleep', Icon = '\u{1F4A4}', Time = {Min = 25, Max = 45}, Height = 2.6},
	DoubleBed = {Pose = 'Sleep', Icon = '\u{1F4A4}', Time = {Min = 25, Max = 45}, Height = 2.6},
	BunkBed = {Pose = 'Sleep', Icon = '\u{1F4A4}', Time = {Min = 25, Max = 45}, Height = 2.6},
	GoldenBed = {Pose = 'Sleep', Icon = '\u{1F4A4}', Time = {Min = 25, Max = 45}, Height = 2.8},

	Sofa = {Pose = 'Sit', Icon = '\u{1F4FA}', Time = {Min = 15, Max = 30}, Height = 1.7},
	VipSofa = {Pose = 'Sit', Icon = '\u{1F4FA}', Time = {Min = 15, Max = 30}, Height = 1.7},
	Armchair = {Pose = 'Sit', Icon = '\u{1F4D6}', Time = {Min = 12, Max = 25}, Height = 1.7},
	BeanBag = {Pose = 'Sit', Icon = '\u{1F3AE}', Time = {Min = 12, Max = 25}, Height = 1.6},
	Chair = {Pose = 'Sit', Icon = '\u{1F37D}', Time = {Min = 10, Max = 20}, Height = 2.1},
	BarStool = {Pose = 'Sit', Icon = '\u{2615}', Time = {Min = 8, Max = 15}, Height = 3.2},
	OfficeChair = {Pose = 'Sit', Icon = '\u{1F4BB}', Time = {Min = 15, Max = 30}, Height = 2.2},
	Toilet = {Pose = 'Sit', Icon = '\u{1F6BD}', Time = {Min = 6, Max = 10}, Height = 1.8},

	Stove = {Pose = 'Stand', Icon = '\u{1F373}', Time = {Min = 10, Max = 18}},
	Fridge = {Pose = 'Stand', Icon = '\u{1F96A}', Time = {Min = 5, Max = 8}},
	KitchenSink = {Pose = 'Stand', Icon = '\u{1F37D}', Time = {Min = 6, Max = 12}},
	Counter = {Pose = 'Stand', Icon = '\u{1F52A}', Time = {Min = 6, Max = 12}},
	KitchenIsland = {Pose = 'Stand', Icon = '\u{1F96B}', Time = {Min = 6, Max = 12}},
	Sink = {Pose = 'Stand', Icon = '\u{1FAA5}', Time = {Min = 5, Max = 8}},
	Shower = {Pose = 'Stand', Icon = '\u{1F6BF}', Time = {Min = 8, Max = 14}},
	Bathtub = {Pose = 'Stand', Icon = '\u{1F6C1}', Time = {Min = 10, Max = 16}},
	Jacuzzi = {Pose = 'Stand', Icon = '\u{1F6C1}', Time = {Min = 12, Max = 20}},
	Desk = {Pose = 'Stand', Icon = '\u{1F4BB}', Time = {Min = 10, Max = 20}},
	Bookshelf = {Pose = 'Stand', Icon = '\u{1F4DA}', Time = {Min = 5, Max = 10}},
	TV = {Pose = 'Stand', Icon = '\u{1F4FA}', Time = {Min = 6, Max = 12}},
	Washer = {Pose = 'Stand', Icon = '\u{1F9FA}', Time = {Min = 6, Max = 12}},
	Dryer = {Pose = 'Stand', Icon = '\u{1F9FA}', Time = {Min = 6, Max = 12}},
	Wardrobe = {Pose = 'Stand', Icon = '\u{1F455}', Time = {Min = 4, Max = 8}},
	GrandPiano = {Pose = 'Stand', Icon = '\u{1F3B9}', Time = {Min = 10, Max = 20}},
	Aquarium = {Pose = 'Stand', Icon = '\u{1F420}', Time = {Min = 5, Max = 10}},
}

TenantConfigs.Uses = uses

-- how many tenants live in a house: one per bed (bunk beds count as 2), at least 1
TenantConfigs.MaxPerHouse = 3
TenantConfigs.MaxPerPlayer = 12
TenantConfigs.BunkBeds = {BunkBed = true}

-- buyers / renters walking in to look at a listed house
TenantConfigs.ViewersPerHouse = 1
TenantConfigs.ViewerLookTime = {Min = 3, Max = 6}
TenantConfigs.ViewerStops = 3

-- how often tenants say how they feel (seconds) and what they say
TenantConfigs.MoodInterval = {Min = 25, Max = 50}
TenantConfigs.DarkLitFraction = 0.7 -- below this a tenant complains about the light

TenantConfigs.Moods = {
	Dirty = {'\u{1F922} It\'s dirty in here!', '\u{1F9F9} Can someone clean this?', '\u{1F92E} Ew, trash on the floor'},
	Dark = {'\u{1F620} It\'s too dark!', '\u{1F526} I can\'t see a thing', '\u{1F4A1} We need more lamps'},
	Happy = {'\u{1F60A} I love this place!', '\u{1F3E1} Best home ever', '\u{2764} So cozy'},
	ViewerGood = {'\u{1F60D} Wow, nice!', '\u{1F44D} I like it', '\u{1F914} Hmm, not bad'},
	ViewerBad = {'\u{1F928} A bit dirty...', '\u{1F914} Kinda dark in here', '\u{1F610} Hmm...'},
}

-- skin tones and outfit colours picked at random for each NPC
TenantConfigs.SkinColors = {
	Color3.fromRGB(255, 219, 172), Color3.fromRGB(241, 194, 125), Color3.fromRGB(224, 172, 105),
	Color3.fromRGB(198, 134, 66), Color3.fromRGB(141, 85, 36), Color3.fromRGB(92, 56, 30),
}

TenantConfigs.ShirtColors = {
	Color3.fromRGB(220, 70, 70), Color3.fromRGB(70, 130, 220), Color3.fromRGB(80, 180, 90),
	Color3.fromRGB(240, 190, 60), Color3.fromRGB(150, 90, 200), Color3.fromRGB(250, 250, 250),
	Color3.fromRGB(40, 40, 50), Color3.fromRGB(240, 130, 180),
}

TenantConfigs.PantsColors = {
	Color3.fromRGB(40, 50, 90), Color3.fromRGB(30, 30, 35), Color3.fromRGB(110, 80, 60),
	Color3.fromRGB(90, 90, 100), Color3.fromRGB(60, 90, 140),
}

-- default R15 animations
TenantConfigs.Animations = {
	Idle = 'rbxassetid://507766388',
	Walk = 'rbxassetid://507777826',
	Sit = 'rbxassetid://2506281703',
}

return TenantConfigs
