--!strict
local RPS = game:GetService('ReplicatedStorage')

local Signal = require(RPS.Modules.Packages.Signal)

local InterfaceClientSignals = {
	-- a panel opened, others close themselves (name of the panel)
	PanelOpened = Signal() :: Signal.Signal<string>,

	-- show a message from client code
	Notify = Signal() :: Signal.Signal<string, Color3?>,
}

return InterfaceClientSignals
