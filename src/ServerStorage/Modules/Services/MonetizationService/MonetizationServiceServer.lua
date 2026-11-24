--!strict
local MonetizationServiceServer = {}

local PLS = game:GetService('Players')
local RPS = game:GetService('ReplicatedStorage')
local SSG = game:GetService('ServerStorage')
local MPS = game:GetService('MarketplaceService')
local RNS = game:GetService('RunService')
local WKS = game:GetService('Workspace')

local DAT_Server = require(RPS.Modules.Packages.DataService).server
local MON_CONFIGS = require(RPS.Modules.Configs.MonetizationConfigs)
local LND_CONFIGS = require(RPS.Modules.Configs.LandConfigs)
local FUR_CONFIGS = require(RPS.Modules.Configs.FurnitureConfigs)
local LND_UTILS = require(RPS.Modules.Utils.LandUtils)
local MON_UTILS = require(RPS.Modules.Utils.MonetizationUtils)
local ECN_Server = require(SSG.Modules.Services.EconomyService.EconomyServiceServer)
local PLT_Server = require(SSG.Modules.Services.PlotService.PlotServiceServer)
local ATC_SSignals = require(SSG.Modules.Services.AnalyticsService.AnalyticsServerSignals)

local remotes = RPS.Remotes.MonetizationService

local GOOD = Color3.fromRGB(90, 210, 120)

-- product id -> what it gives (filled in Init from the configs)
type ProductHandler = (Player: Player) -> ()

local productHandlers: {[number]: ProductHandler} = {}
local pendingParcels: {[Player]: string} = {}

-- send a message to the player
local function notify(Player: Player, Text: string)
	RPS.Remotes.InterfaceService.Notify:FireClient(Player, Text, GOOD)
end

-- give a parcel bought with Robux (the one the player picked, or the first free one)
local function grantParcel(Player: Player)
	local parcels = DAT_Server:get(Player, 'Parcels')
	local picked = pendingParcels[Player]
	local key = if picked and LND_UTILS.CanBuyParcel(parcels, picked) then picked else LND_UTILS.GetFirstBuyable(parcels)

	pendingParcels[Player] = nil

	if key then
		PLT_Server:UnlockParcel(Player, key)
	else
		-- every parcel was already owned: pay the cash price of the last one instead
		local prices = LND_CONFIGS.ParcelPrices
		ECN_Server:Reward(Player, {Cash = prices[#prices], Transaction = Enum.AnalyticsEconomyTransactionType.IAP}, 'Purchase')
	end
end

-- initialize monetization service server-side
function MonetizationServiceServer:Init()
	-- cash packs
	for _, pack in MON_CONFIGS.CashPacks do
		if pack.Id ~= 0 then
			productHandlers[pack.Id] = function(Player)
				ECN_Server:Reward(Player, {Cash = pack.Cash, Transaction = Enum.AnalyticsEconomyTransactionType.IAP}, 'Purchase')
			end
		end
	end

	-- land parcels
	for _, tier in LND_CONFIGS.ParcelTiers do
		if tier.ProductId ~= 0 then
			productHandlers[tier.ProductId] = grantParcel
		end
	end

	-- premium furniture
	for name, config in FUR_CONFIGS.Items do
		local premium = config.Premium

		if premium and premium.ProductId ~= 0 then
			productHandlers[premium.ProductId] = function(Player)
				DAT_Server:set(Player, {'UnlockedItems', name}, true)
				notify(Player, `{config.DisplayName} unlocked! Find it in the build menu.`)
			end
		end
	end

	MPS.ProcessReceipt = function(ReceiptInfo)
		return MonetizationServiceServer:ProcessReceipt(ReceiptInfo)
	end

	MPS.PromptGamePassPurchaseFinished:Connect(function(Player, PassId, Purchased)
		if not Purchased then
			return
		end

		for name, pass in MON_CONFIGS.Gamepasses do
			if pass.Id == PassId then
				Player:SetAttribute(MON_UTILS.PassAttribute(name), true)
				notify(Player, `{pass.DisplayName} is active!`)
			end
		end
	end)

	remotes.SetPendingParcel.OnServerEvent:Connect(function(Player, Key)
		if typeof(Key) == 'string' and LND_UTILS.IsParcelInside(Key) then
			pendingParcels[Player] = Key
		end
	end)

	PLS.PlayerAdded:Connect(function(Player)
		MonetizationServiceServer:LoadPasses(Player)
	end)

	for _, player in PLS:GetPlayers() do
		task.spawn(function()
			MonetizationServiceServer:LoadPasses(player)
		end)
	end

	PLS.PlayerRemoving:Connect(function(Player)
		pendingParcels[Player] = nil
	end)
end

-- check which gamepasses a player owns (all of them while testing in Studio)
function MonetizationServiceServer:LoadPasses(Player: Player)
	local testing = RNS:IsStudio() and WKS:GetAttribute('Testing') == true

	for name, pass in MON_CONFIGS.Gamepasses do
		local owned = testing

		if not owned and pass.Id ~= 0 then
			local success, result = pcall(function()
				return MPS:UserOwnsGamePassAsync(Player.UserId, pass.Id)
			end)

			owned = success and result == true
		end

		if owned then
			Player:SetAttribute(MON_UTILS.PassAttribute(name), true)
		end
	end
end

-- grant a developer product (safe to run twice for the same purchase)
function MonetizationServiceServer:ProcessReceipt(ReceiptInfo: {[string]: any}): Enum.ProductPurchaseDecision
	local player = PLS:GetPlayerByUserId(ReceiptInfo.PlayerId)
	local handler = productHandlers[ReceiptInfo.ProductId]

	if not player or not handler or not DAT_Server:hasProfile(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local purchaseId = tostring(ReceiptInfo.PurchaseId)
	local purchases: {string} = DAT_Server:get(player, 'Purchases')

	if table.find(purchases, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local success, err = pcall(handler, player)

	if not success then
		warn(`[MonetizationServiceServer]: Failed to grant {ReceiptInfo.ProductId}: {err}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- remember the purchase so it is never granted twice
	DAT_Server:update(player, 'Purchases', function(Old)
		local list = table.clone(Old)
		table.insert(list, purchaseId)

		while #list > MON_CONFIGS.PurchaseHistory do
			table.remove(list, 1)
		end

		return list
	end)

	ATC_SSignals.LogJourney:Fire(player, 'BoughtProduct')

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

return MonetizationServiceServer
