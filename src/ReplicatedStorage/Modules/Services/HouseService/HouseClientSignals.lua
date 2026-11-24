--!strict
local RPS = game:GetService('ReplicatedStorage')

local Signal = require(RPS.Modules.Packages.Signal)
local DAT_TYPES = require(RPS.Modules.Types.DataTypes)

local HouseClientSignals = {
	-- the houses on the local player's land were worked out again
	HousesChanged = Signal() :: Signal.Signal<{DAT_TYPES.HouseInfo}>,
}

return HouseClientSignals
