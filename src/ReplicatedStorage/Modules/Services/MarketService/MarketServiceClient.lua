--!strict
local MarketServiceClient = {}

local RPS = game:GetService('ReplicatedStorage')

local MKT_CSignals = require(script.Parent.MarketClientSignals)
local DAT_TYPES = require(RPS.Modules.Types.DataTypes)
local CFG_TYPES = require(RPS.Modules.Types.ConfigTypes)

local remotes = RPS.Remotes.MarketService

local listings: {[string]: DAT_TYPES.ListingData} = {}
local expiresAt: {[string]: number} = {}

-- initialize market service client-side
function MarketServiceClient:Init()
	remotes.ListingsUpdated.OnClientEvent:Connect(function(Listings: {[string]: DAT_TYPES.ListingData})
		local now = os.clock()

		listings = Listings
		expiresAt = {}

		for _, listing in Listings do
			for _, offer in listing.Offers do
				expiresAt[offer.Id] = now + offer.Expires
			end
		end

		MKT_CSignals.ListingsChanged:Fire(Listings)
	end)
end

-- every house on the market (key = house id)
function MarketServiceClient:GetListings(): {[string]: DAT_TYPES.ListingData}
	return listings
end

-- seconds left on an offer
function MarketServiceClient:GetTimeLeft(OfferId: string): number
	local expires = expiresAt[OfferId]

	return if expires then math.max(0, expires - os.clock()) else 0
end

function MarketServiceClient:ListHouse(HouseId: string, Mode: CFG_TYPES.ListingMode)
	remotes.ListHouse:FireServer(HouseId, Mode)
end

function MarketServiceClient:Unlist(HouseId: string)
	remotes.Unlist:FireServer(HouseId)
end

function MarketServiceClient:AcceptOffer(HouseId: string, OfferId: string)
	remotes.AcceptOffer:FireServer(HouseId, OfferId)
end

function MarketServiceClient:DeclineOffer(HouseId: string, OfferId: string)
	remotes.DeclineOffer:FireServer(HouseId, OfferId)
end

function MarketServiceClient:CollectRent()
	remotes.CollectRent:FireServer()
end

function MarketServiceClient:Evict(HouseId: string)
	remotes.Evict:FireServer(HouseId)
end

return MarketServiceClient
