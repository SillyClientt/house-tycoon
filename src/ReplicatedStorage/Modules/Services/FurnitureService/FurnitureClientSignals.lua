--!strict
local RPS = game:GetService('ReplicatedStorage')

local Signal = require(RPS.Modules.Packages.Signal)

local FurnitureClientSignals = {
	-- id and item name of the selected furniture (nil when nothing is selected)
	SelectionChanged = Signal() :: Signal.Signal<string?, string?>,
}

return FurnitureClientSignals
