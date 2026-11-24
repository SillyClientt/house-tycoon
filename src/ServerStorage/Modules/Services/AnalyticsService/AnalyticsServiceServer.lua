--!strict
local AnalyticsServiceServer = {}

local ANS = game:GetService('AnalyticsService')
local RPS = game:GetService('ReplicatedStorage')
local PLS = game:GetService('Players')

local ATC_SSignals = require(script.Parent.AnalyticsServerSignals)
local DAT_Server = require(RPS.Modules.Packages.DataService).server

local FLUSH_INTERVAL = 30

type PendingLog = {
	CustomData: {[string]: string | number}?,
	FlowType: Enum.AnalyticsEconomyFlowType,
	Amount: number,
	TransactionType: string
}

local pendingEconomyLogs: {[Player]: {[string]: PendingLog?}} = {}
local nodesCompleted: {[Player]: {[string]: boolean}} = {}

-- initialize analytics service server-side
function AnalyticsServiceServer:Init()
	ATC_SSignals.LogEconomy:Connect(function(Player, Economy, FlowType, TransactionType, Amount, CustomData)
		AnalyticsServiceServer:AddToPending(Player, Economy, FlowType, TransactionType, Amount, CustomData)
	end)

	ATC_SSignals.FlushEconomy:Connect(function(Player, Economy)
		AnalyticsServiceServer:Flush(Player, Economy)
	end)

	ATC_SSignals.LogJourney:Connect(function(Player, Node)
		AnalyticsServiceServer:LogJourney(Player, Node)
	end)

	PLS.PlayerAdded:Connect(function(Player)
		nodesCompleted[Player] = {}
	end)

	for _, player in PLS:GetPlayers() do
		nodesCompleted[player] = {}
	end

	PLS.PlayerRemoving:Connect(function(Player)
		AnalyticsServiceServer:FlushAll(Player)

		pendingEconomyLogs[Player] = nil
		nodesCompleted[Player] = nil
	end)

	-- send batched economy logs every so often
	task.spawn(function()
		while true do
			task.wait(FLUSH_INTERVAL)

			for _, player in PLS:GetPlayers() do
				AnalyticsServiceServer:FlushAll(player)
			end
		end
	end)
end

-- add to player pending economy log (same-type logs are added together)
function AnalyticsServiceServer:AddToPending(Player: Player, Economy: string, FlowType: Enum.AnalyticsEconomyFlowType, TransactionType: string, Amount: number, CustomData: {[string]: number | string}?)
	local plrLogs = pendingEconomyLogs[Player]

	if not plrLogs then
		plrLogs = {}
		pendingEconomyLogs[Player] = plrLogs
	end

	assert(plrLogs)

	local oldLog = plrLogs[Economy]

	if oldLog and (oldLog.FlowType ~= FlowType or oldLog.TransactionType ~= TransactionType or CustomData ~= nil) then
		AnalyticsServiceServer:Flush(Player, Economy)
		oldLog = nil
	end

	if oldLog then
		oldLog.Amount += Amount
	else
		plrLogs[Economy] = {
			FlowType = FlowType,
			TransactionType = TransactionType,
			Amount = Amount,
			CustomData = CustomData
		}
	end
end

-- flush player economy log
function AnalyticsServiceServer:Flush(Player: Player, Economy: string)
	local plrLogs = pendingEconomyLogs[Player]
	local pendingLog = plrLogs and plrLogs[Economy]

	if not plrLogs or not pendingLog then
		return
	end

	plrLogs[Economy] = nil

	if not DAT_Server:hasProfile(Player) then
		return
	end

	local endingBalance = DAT_Server:get(Player, 'Cash')

	pcall(function()
		ANS:LogEconomyEvent(Player, pendingLog.FlowType, Economy, pendingLog.Amount, endingBalance, pendingLog.TransactionType, nil, pendingLog.CustomData)
	end)
end

-- flush every pending economy log for a player
function AnalyticsServiceServer:FlushAll(Player: Player)
	local plrLogs = pendingEconomyLogs[Player]

	if not plrLogs then
		return
	end

	for economy in plrLogs do
		AnalyticsServiceServer:Flush(Player, economy)
	end
end

-- log a one-time milestone for a player session (e.g. 'SoldHouse')
function AnalyticsServiceServer:LogJourney(Player: Player, Node: string)
	local completed = nodesCompleted[Player]

	if not completed or completed[Node] then
		return
	end

	completed[Node] = true

	pcall(function()
		ANS:LogCustomEvent(Player, Node)
	end)
end

return AnalyticsServiceServer
