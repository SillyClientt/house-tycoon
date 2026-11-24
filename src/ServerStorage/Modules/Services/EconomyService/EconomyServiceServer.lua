--!strict
local EconomyServiceServer = {}

local RPS = game:GetService('ReplicatedStorage')
local SSG = game:GetService('ServerStorage')

local ECN_SSignals = require(script.Parent.EconomyServerSignals)
local DAT_Server = require(RPS.Modules.Packages.DataService).server
local ATC_SSignals = require(SSG.Modules.Services.AnalyticsService.AnalyticsServerSignals)
local CFG_TYPES = require(RPS.Modules.Types.ConfigTypes)

-- initialize economy service server-side
function EconomyServiceServer:Init()
	ECN_SSignals.Reward:Connect(function(Player, Reward, Tag)
		EconomyServiceServer:Reward(Player, Reward, Tag)
	end)

	ECN_SSignals.Deduct:Connect(function(Player, Deduction, Tag)
		EconomyServiceServer:Deduct(Player, Deduction, Tag)
	end)
end

-- get a player's cash
function EconomyServiceServer:GetCash(Player: Player): number
	return DAT_Server:get(Player, 'Cash') or 0
end

-- reward using reward config
function EconomyServiceServer:Reward(Player: Player, RewardConfig: CFG_TYPES.RewardConfig, Tag: string?)
	local transaction = RewardConfig.Transaction or Enum.AnalyticsEconomyTransactionType.Gameplay
	local amount: number = RewardConfig.Cash or 0

	if amount <= 0 then
		return
	end

	local new = DAT_Server:update(Player, 'Cash', function(Old)
		return Old + amount
	end)

	ATC_SSignals.LogEconomy:Fire(Player, 'Cash', Enum.AnalyticsEconomyFlowType.Source, transaction.Name, amount)
	RPS.Remotes.EconomyService.Rewarded:FireClient(Player, 'Cash', amount, new, Tag)
end

-- deduct using deduction config (does not check the player can afford it)
function EconomyServiceServer:Deduct(Player: Player, DeductionConfig: CFG_TYPES.DeductionConfig, Tag: string?)
	local transaction = DeductionConfig.Transaction or Enum.AnalyticsEconomyTransactionType.Shop
	local amount: number = DeductionConfig.Cash or 0

	if amount <= 0 then
		return
	end

	local new = DAT_Server:update(Player, 'Cash', function(Old)
		return Old - amount
	end)

	ATC_SSignals.LogEconomy:Fire(Player, 'Cash', Enum.AnalyticsEconomyFlowType.Sink, transaction.Name, amount)
	RPS.Remotes.EconomyService.Deducted:FireClient(Player, 'Cash', amount, new, Tag)
end

-- deduct only if the player can afford it, returns whether it went through
function EconomyServiceServer:TryDeduct(Player: Player, Amount: number, Tag: string?): boolean
	if Amount <= 0 then
		return true
	end

	if EconomyServiceServer:GetCash(Player) < Amount then
		RPS.Remotes.InterfaceService.Notify:FireClient(Player, 'Not enough cash!', Color3.fromRGB(235, 80, 80))
		return false
	end

	EconomyServiceServer:Deduct(Player, {Cash = Amount}, Tag)

	return true
end

return EconomyServiceServer
