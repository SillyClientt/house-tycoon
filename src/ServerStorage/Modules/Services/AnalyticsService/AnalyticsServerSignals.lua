--!strict
local RPS = game:GetService('ReplicatedStorage')

local Signal = require(RPS.Modules.Packages.Signal)

local AnalyticsServerSignals = {
	FlushEconomy = Signal() :: Signal.Signal<Player, string>,
	LogEconomy = Signal() :: Signal.Signal<Player, string,  Enum.AnalyticsEconomyFlowType, string, number, {[string]: number | string}?>,
	LogJourney = Signal() :: Signal.Signal<Player, string>
}

return AnalyticsServerSignals
