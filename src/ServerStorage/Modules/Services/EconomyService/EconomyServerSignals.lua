--!strict
local RPS = game:GetService('ReplicatedStorage')

local CFG_TYPES = require(RPS.Modules.Types.ConfigTypes)
local Signal = require(RPS.Modules.Packages.Signal)

local EconomyServerSignals = {
	Reward = Signal() :: Signal.Signal<Player, CFG_TYPES.RewardConfig, string?>,
	Deduct = Signal() :: Signal.Signal<Player, CFG_TYPES.DeductionConfig, string?>,
}

return EconomyServerSignals
