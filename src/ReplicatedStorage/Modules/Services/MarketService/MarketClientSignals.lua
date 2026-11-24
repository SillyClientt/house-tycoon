--!strict
local RPS = game:GetService('ReplicatedStorage')

local Signal = require(RPS.Modules.Packages.Signal)
local DAT_TYPES = require(RPS.Modules.Types.DataTypes)

local MarketClientSignals = {
	-- every house on the market (key = house id)
	ListingsChanged = Signal() :: Signal.Signal<{[string]: DAT_TYPES.ListingData}>,
}

return MarketClientSignals
