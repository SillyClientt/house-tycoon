--!strict
local PlayerServiceServer = {}

local PLS = game:GetService('Players')
local RPS = game:GetService('ReplicatedStorage')
local RNS = game:GetService('RunService')
local WKS = game:GetService('Workspace')

local DAT_Server = require(RPS.Modules.Packages.DataService).server

local testData = require(script.TestData)
local initialData = require(script.DefaultData)

-- initialize player service server-side
function PlayerServiceServer:Init()
	local testing = RNS:IsStudio() and WKS:GetAttribute('Testing') == true

	DAT_Server:init({
		template = if testing then testData else initialData,

		profileStoreIndex = 'Housing v2',
		resetData = RNS:IsStudio() and WKS:GetAttribute('ResetData') == true or nil,
		useMock = testing or nil,
	})

	PLS.PlayerAdded:Connect(function(Player)
		PlayerServiceServer:LoadPlayer(Player)
	end)

	for _, player in PLS:GetPlayers() do
		task.spawn(function()
			PlayerServiceServer:LoadPlayer(player)
		end)
	end
end

-- create leaderstats and keep them in sync with data
function PlayerServiceServer:LoadPlayer(Player: Player)
	DAT_Server:waitForData(Player)

	if Player.Parent ~= PLS then
		return
	end

	local leaderstats = Instance.new('Folder')
	leaderstats.Name = 'leaderstats'

	local cash = Instance.new('IntValue')
	cash.Name = 'Cash'
	cash.Value = DAT_Server:get(Player, 'Cash')
	cash.Parent = leaderstats

	local sold = Instance.new('IntValue')
	sold.Name = 'Sold'
	sold.Value = DAT_Server:get(Player, {'Stats', 'HousesSold'})
	sold.Parent = leaderstats

	leaderstats.Parent = Player

	DAT_Server:getChangedSignal(Player, 'Cash'):Connect(function(Value)
		cash.Value = Value
	end)

	DAT_Server:getChangedSignal(Player, {'Stats', 'HousesSold'}):Connect(function(Value)
		sold.Value = Value
	end)
end

return PlayerServiceServer
