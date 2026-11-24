--!strict
-- works out the local player's houses whenever their land changes (shared by the UI)
local HouseServiceClient = {}

local RPS = game:GetService('ReplicatedStorage')

local HSE_CSignals = require(script.Parent.HouseClientSignals)
local DAT_Client = require(RPS.Modules.Packages.DataService).client
local MKT_Client = require(RPS.Modules.Services.MarketService.MarketServiceClient)
local HSE_UTILS = require(RPS.Modules.Utils.HouseUtils)
local DAT_TYPES = require(RPS.Modules.Types.DataTypes)

export type HouseStatus = 'Building' | 'For Sale' | 'For Rent' | 'Rented'

local REFRESH_DELAY = 0.2

local houses: {DAT_TYPES.HouseInfo} = {}
local refreshQueued = false

-- work the houses out again (batched so a big drag only refreshes once)
local function queueRefresh()
	if refreshQueued then
		return
	end

	refreshQueued = true

	task.delay(REFRESH_DELAY, function()
		refreshQueued = false
		houses = HSE_UTILS.GetHouses(DAT_Client:get('Land'))

		HSE_CSignals.HousesChanged:Fire(houses)
	end)
end

-- initialize house service client-side
function HouseServiceClient:Init()
	task.spawn(function()
		DAT_Client:waitForData()

		DAT_Client:getChangedSignal('Land'):Connect(queueRefresh)
		queueRefresh()
	end)
end

-- latest houses
function HouseServiceClient:GetHouses(): {DAT_TYPES.HouseInfo}
	return houses
end

-- what is happening with a house
function HouseServiceClient:GetStatus(HouseId: string): HouseStatus
	local rentals = DAT_Client:get('Rentals')

	if rentals[HouseId] then
		return 'Rented'
	end

	local listing = MKT_Client:GetListings()[HouseId]

	if listing then
		return if listing.Mode == 'Sale' then 'For Sale' else 'For Rent'
	end

	return 'Building'
end

return HouseServiceClient
