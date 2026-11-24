--!strict
local RPS = game:GetService('ReplicatedStorage')

local Signal = require(RPS.Modules.Packages.Signal)

export type BuildMode = 'None' | 'Room' | 'Wall' | 'Door' | 'Window' | 'Floor' | 'Paint' | 'Furniture' | 'Edit' | 'Erase'

local BuildClientSignals = {
	-- UI asks for a tool: (mode, option, option)
	-- Room: (wall style, floor style)  Wall: (wall style)  Floor: (floor style)
	-- Paint: ('Wall' or 'Floor', style)  Furniture: (item name)
	ModeRequested = Signal() :: Signal.Signal<BuildMode, string?, string?>,

	-- the tool that is now active
	ModeChanged = Signal() :: Signal.Signal<BuildMode, string?, string?>,

	-- the floor being built on
	LevelChanged = Signal() :: Signal.Signal<number>,

	-- cost of what is being previewed (nil hides it)
	CostChanged = Signal() :: Signal.Signal<number?>,
}

return BuildClientSignals
