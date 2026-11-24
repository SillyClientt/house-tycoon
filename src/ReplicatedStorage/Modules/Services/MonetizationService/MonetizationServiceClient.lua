--!strict
local MonetizationServiceClient = {}

local PLS = game:GetService('Players')
local RPS = game:GetService('ReplicatedStorage')
local MPS = game:GetService('MarketplaceService')

local DAT_Client = require(RPS.Modules.Packages.DataService).client
local INT_CSignals = require(RPS.Modules.Services.InterfaceService.InterfaceClientSignals)
local MON_CONFIGS = require(RPS.Modules.Configs.MonetizationConfigs)
local FUR_CONFIGS = require(RPS.Modules.Configs.FurnitureConfigs)
local LND_UTILS = require(RPS.Modules.Utils.LandUtils)
local MON_UTILS = require(RPS.Modules.Utils.MonetizationUtils)

local plr = PLS.LocalPlayer
local remotes = RPS.Remotes.MonetizationService

local RED = Color3.fromRGB(235, 80, 80)

-- tell the player a product isn't on the website yet
local function notSetUp()
	INT_CSignals.Notify:Fire('This purchase is not set up yet', RED)
end

-- prompt a developer product
local function promptProduct(Id: number)
	if Id == 0 then
		notSetUp()
		return
	end

	MPS:PromptProductPurchase(plr, Id)
end

-- initialize monetization service client-side
function MonetizationServiceClient:Init() end

-- check the local player owns a gamepass
function MonetizationServiceClient:HasPass(Name: string): boolean
	return MON_UTILS.HasPass(plr, Name)
end

-- buy a gamepass
function MonetizationServiceClient:PromptPass(Name: string)
	local pass = MON_CONFIGS.Gamepasses[Name]

	if not pass or pass.Id == 0 then
		notSetUp()
		return
	end

	MPS:PromptGamePassPurchase(plr, pass.Id)
end

-- buy a cash pack
function MonetizationServiceClient:PromptCashPack(Name: string)
	local pack = MON_CONFIGS.CashPacks[Name]

	if pack then
		promptProduct(pack.Id)
	end
end

-- buy a parcel with Robux (the server gives the picked parcel)
function MonetizationServiceClient:PromptParcel(Key: string)
	local tier = LND_UTILS.GetParcelTier(DAT_Client:get('Parcels'))

	if not tier then
		return
	end

	remotes.SetPendingParcel:FireServer(Key)
	promptProduct(tier.ProductId)
end

-- unlock a premium furniture item
function MonetizationServiceClient:PromptPremium(Name: string)
	local config = FUR_CONFIGS.Items[Name]
	local premium = config and config.Premium

	if premium then
		promptProduct(premium.ProductId)
	end
end

-- check the player can use an item, or why not ('Premium' / 'Vip')
function MonetizationServiceClient:GetItemLock(Name: string): string?
	local config = FUR_CONFIGS.Items[Name]

	if not config then
		return nil
	end

	if config.Premium and not DAT_Client:get({'UnlockedItems', Name}) then
		return 'Premium'
	end

	if config.Vip and not MON_UTILS.HasPass(plr, 'VipFurniture') then
		return 'Vip'
	end

	return nil
end

return MonetizationServiceClient
