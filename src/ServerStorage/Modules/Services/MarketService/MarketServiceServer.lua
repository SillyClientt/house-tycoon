--!strict
local MarketServiceServer = {}

local PLS = game:GetService('Players')
local RPS = game:GetService('ReplicatedStorage')
local SSG = game:GetService('ServerStorage')
local HTP = game:GetService('HttpService')

local DAT_Server = require(RPS.Modules.Packages.DataService).server
local MKT_CONFIGS = require(RPS.Modules.Configs.MarketConfigs)
local MON_CONFIGS = require(RPS.Modules.Configs.MonetizationConfigs)
local GRD_UTILS = require(RPS.Modules.Utils.GridUtils)
local HSE_UTILS = require(RPS.Modules.Utils.HouseUtils)
local MON_UTILS = require(RPS.Modules.Utils.MonetizationUtils)
local STR_UTILS = require(RPS.Modules.Utils.StringUtils)
local DAT_TYPES = require(RPS.Modules.Types.DataTypes)
local CFG_TYPES = require(RPS.Modules.Types.ConfigTypes)
local HSE_Server = require(SSG.Modules.Services.HouseService.HouseServiceServer)
local BLD_HISTORY = require(SSG.Modules.Services.BuildService.BuildHistory)
local ECN_Server = require(SSG.Modules.Services.EconomyService.EconomyServiceServer)
local ATC_SSignals = require(SSG.Modules.Services.AnalyticsService.AnalyticsServerSignals)

local remotes = RPS.Remotes.MarketService

local GOOD = Color3.fromRGB(90, 210, 120)
local BAD = Color3.fromRGB(235, 80, 80)

type Listing = {
	HouseId: string,
	Mode: CFG_TYPES.ListingMode,
	Value: number,
	Offers: {DAT_TYPES.OfferData},
	NextOffer: number,
	Cells: {string},
}

local random = Random.new()
local listings: {[Player]: {[string]: Listing}} = {}
local lastRequest: {[Player]: number} = {}

-- check request (rate limit + land loaded)
local function checkRequest(Player: Player): boolean
	local now = os.clock()

	if now - (lastRequest[Player] or 0) < 0.25 or not HSE_Server:IsReady(Player) then
		return false
	end

	lastRequest[Player] = now
	return true
end

-- send a message to the player
local function notify(Player: Player, Text: string, Color: Color3)
	RPS.Remotes.InterfaceService.Notify:FireClient(Player, Text, Color)
end

-- random number between a min and max
local function between(Range: {Min: number, Max: number}): number
	return random:NextNumber(Range.Min, Range.Max)
end

-- random NPC name
local function randomName(): string
	local first = MKT_CONFIGS.FirstNames[random:NextInteger(1, #MKT_CONFIGS.FirstNames)]
	local last = MKT_CONFIGS.LastNames[random:NextInteger(1, #MKT_CONFIGS.LastNames)]

	return `{first} {last}`
end

-- seconds until the next offer (Quick Sale halves it)
local function offerDelay(Player: Player, Range: {Min: number, Max: number}): number
	local delay = between(Range)

	if MON_UTILS.HasPass(Player, 'QuickSale') then
		delay *= MON_CONFIGS.QuickSaleDelayMultiplier
	end

	return delay
end

-- the player's listings (created on demand)
local function getListings(Player: Player): {[string]: Listing}
	local playerListings = listings[Player]

	if not playerListings then
		playerListings = {}
		listings[Player] = playerListings
	end

	assert(playerListings)
	return playerListings
end

-- rentals from data
local function getRentals(Player: Player): {[string]: DAT_TYPES.RentalData}
	return DAT_Server:get(Player, 'Rentals')
end

-- lock every house that is listed or rented
function MarketServiceServer:UpdateLocks(Player: Player)
	local cells: {string} = {}

	for _, listing in getListings(Player) do
		table.move(listing.Cells, 1, #listing.Cells, #cells + 1, cells)
	end

	for _, rental in getRentals(Player) do
		table.move(rental.Cells, 1, #rental.Cells, #cells + 1, cells)
	end

	HSE_Server:SetLockedColumns(Player, HSE_UTILS.GetColumns(cells))
end

-- initialize market service server-side
function MarketServiceServer:Init()
	remotes.ListHouse.OnServerEvent:Connect(function(Player, HouseId, Mode)
		MarketServiceServer:ListHouse(Player, HouseId, Mode)
	end)

	remotes.Unlist.OnServerEvent:Connect(function(Player, HouseId)
		if typeof(HouseId) == 'string' and checkRequest(Player) then
			MarketServiceServer:Unlist(Player, HouseId)
		end
	end)

	remotes.AcceptOffer.OnServerEvent:Connect(function(Player, HouseId, OfferId)
		MarketServiceServer:AcceptOffer(Player, HouseId, OfferId)
	end)

	remotes.DeclineOffer.OnServerEvent:Connect(function(Player, HouseId, OfferId)
		MarketServiceServer:DeclineOffer(Player, HouseId, OfferId)
	end)

	remotes.CollectRent.OnServerEvent:Connect(function(Player)
		MarketServiceServer:CollectRent(Player)
	end)

	remotes.Evict.OnServerEvent:Connect(function(Player, HouseId)
		MarketServiceServer:Evict(Player, HouseId)
	end)

	PLS.PlayerAdded:Connect(function(Player)
		MarketServiceServer:LoadPlayer(Player)
	end)

	for _, player in PLS:GetPlayers() do
		task.spawn(function()
			MarketServiceServer:LoadPlayer(player)
		end)
	end

	PLS.PlayerRemoving:Connect(function(Player)
		listings[Player] = nil
		lastRequest[Player] = nil
	end)

	-- save the time the player left, for offline rent
	DAT_Server:addPlayerRemovingCallback(function(_Player, Data)
		Data.LastOnline = os.time()
	end)

	-- offers
	task.spawn(function()
		while true do
			task.wait(1)

			for player in listings do
				MarketServiceServer:UpdateOffers(player)
			end
		end
	end)

	-- rent
	task.spawn(function()
		while true do
			local waited = task.wait(MKT_CONFIGS.RentTickInterval)

			for _, player in PLS:GetPlayers() do
				if DAT_Server:hasProfile(player) then
					MarketServiceServer:AddRent(player, waited)
					DAT_Server:set(player, 'LastOnline', os.time(), true)
				end
			end
		end
	end)
end

-- lock rented houses and pay rent earned while offline
function MarketServiceServer:LoadPlayer(Player: Player)
	DAT_Server:waitForData(Player)

	if Player.Parent ~= PLS then
		return
	end

	MarketServiceServer:UpdateLocks(Player)

	local lastOnline = DAT_Server:get(Player, 'LastOnline')
	local now = os.time()

	DAT_Server:set(Player, 'LastOnline', now, true)

	if lastOnline <= 0 then
		return
	end

	local offline = math.clamp(now - lastOnline, 0, MKT_CONFIGS.OfflineRentHours * 3600)
	local earned = MarketServiceServer:AddRent(Player, offline)

	if earned >= 1 then
		task.delay(3, function()
			notify(Player, `Your tenants paid {STR_UTILS.FormatCash(earned)} while you were away!`, GOOD)
		end)
	end
end

-- rent a tenant pays per minute right now (cleanliness + 2x Rent pass)
function MarketServiceServer:GetCurrentRent(Player: Player, Rental: DAT_TYPES.RentalData): number
	local land = HSE_Server:GetLand(Player)
	local cells: {[string]: boolean} = {}
	local dirt = 0

	for _, cell in Rental.Cells do
		cells[cell] = true
	end

	for _, spot in land.Dirt do
		if cells[GRD_UTILS.LevelCell(spot.Level, spot.Cell)] then
			dirt += 1
		end
	end

	local rent = Rental.Rent * HSE_UTILS.GetCleanFactor(dirt)

	if MON_UTILS.HasPass(Player, 'DoubleRent') then
		rent *= MON_CONFIGS.DoubleRentMultiplier
	end

	return rent
end

-- add rent to every rental for the time passed, returns the total added
function MarketServiceServer:AddRent(Player: Player, Seconds: number): number
	local total = 0

	for id, rental in getRentals(Player) do
		local earned = MarketServiceServer:GetCurrentRent(Player, rental) * Seconds / 60

		total += earned
		DAT_Server:set(Player, {'Rentals', id, 'Pending'}, rental.Pending + earned)
	end

	return math.floor(total)
end

-- every house the player has on the market (key = house id)
function MarketServiceServer:GetListings(Player: Player): {[string]: any}
	return getListings(Player)
end

-- send every listing to the player
function MarketServiceServer:SendListings(Player: Player)
	local now = os.clock()
	local data: {[string]: DAT_TYPES.ListingData} = {}

	for houseId, listing in getListings(Player) do
		-- the client gets seconds left instead of server clock times
		local offers: {DAT_TYPES.OfferData} = {}

		for _, offer in listing.Offers do
			table.insert(offers, {
				Id = offer.Id,
				Name = offer.Name,
				Amount = offer.Amount,
				Expires = math.max(0, offer.Expires - now),
			})
		end

		data[houseId] = {
			HouseId = houseId,
			Mode = listing.Mode,
			Value = listing.Value,
			Offers = offers,
		}
	end

	remotes.ListingsUpdated:FireClient(Player, data)
end

-- put a house on the market for sale or rent
function MarketServiceServer:ListHouse(Player: Player, HouseId: any, Mode: any)
	if typeof(HouseId) ~= 'string' or (Mode ~= 'Sale' and Mode ~= 'Rent') or not checkRequest(Player) then
		return
	end

	if getListings(Player)[HouseId] or getRentals(Player)[HouseId] then
		return
	end

	local house = HSE_Server:FindHouse(Player, HouseId)

	if not house then
		notify(Player, 'That house changed - open the Houses panel again', BAD)
		return
	end

	if not house.Livable then
		local missing = {}

		for _, roomType in house.Missing do
			table.insert(missing, MKT_CONFIGS.RoomTypes[roomType].DisplayName)
		end

		notify(Player, `This house needs: {table.concat(missing, ', ')}`, BAD)
		return
	end

	getListings(Player)[HouseId] = {
		HouseId = HouseId,
		Mode = Mode :: CFG_TYPES.ListingMode,
		Value = house.Value,
		Offers = {},
		NextOffer = os.clock() + offerDelay(Player, MKT_CONFIGS.FirstOfferDelay),
		Cells = HSE_UTILS.GetCellList(house),
	}

	MarketServiceServer:UpdateLocks(Player)
	MarketServiceServer:SendListings(Player)

	ATC_SSignals.LogJourney:Fire(Player, 'ListedHouse')

	local text = if Mode == 'Sale' then 'House listed! Buyers will make offers soon.' else 'House up for rent! Tenants will apply soon.'
	notify(Player, text, GOOD)
end

-- take a house off the market
function MarketServiceServer:Unlist(Player: Player, HouseId: string)
	local playerListings = getListings(Player)

	if not playerListings[HouseId] then
		return
	end

	playerListings[HouseId] = nil

	MarketServiceServer:UpdateLocks(Player)
	MarketServiceServer:SendListings(Player)
end

-- remove expired offers and add new ones
function MarketServiceServer:UpdateOffers(Player: Player)
	local now = os.clock()
	local changed = false

	for _, listing in getListings(Player) do
		for index = #listing.Offers, 1, -1 do
			if listing.Offers[index].Expires <= now then
				table.remove(listing.Offers, index)
				changed = true
			end
		end

		if now < listing.NextOffer or #listing.Offers >= MKT_CONFIGS.MaxOffers then
			continue
		end

		local amount = if listing.Mode == 'Sale'
			then listing.Value * between(MKT_CONFIGS.SaleOfferRange)
			else HSE_UTILS.GetBaseRent(listing.Value) * between(MKT_CONFIGS.RentOfferRange)

		if MON_UTILS.HasPass(Player, 'QuickSale') then
			amount *= MON_CONFIGS.QuickSaleOfferBonus
		end

		table.insert(listing.Offers, {
			Id = HTP:GenerateGUID(false),
			Name = randomName(),
			Amount = math.max(1, math.floor(amount)),
			Expires = now + MKT_CONFIGS.OfferLifetime,
		})

		listing.NextOffer = now + offerDelay(Player, MKT_CONFIGS.OfferDelay)
		changed = true
	end

	if changed then
		MarketServiceServer:SendListings(Player)
	end
end

-- find an offer in a listing
local function findOffer(Listing: Listing, Id: string): (DAT_TYPES.OfferData?, number?)
	for index, offer in Listing.Offers do
		if offer.Id == Id then
			return offer, index
		end
	end

	return nil, nil
end

-- sell: remove the house's pieces from the land
function MarketServiceServer:RemoveHouse(Player: Player, HouseId: string): boolean
	local house, cellHouse = HSE_Server:FindHouse(Player, HouseId)

	if not house then
		return false
	end

	local land = HSE_UTILS.CloneLand(HSE_Server:GetLand(Player))
	local pieces = HSE_UTILS.GetHousePieces(land, house, cellHouse)

	for _, wall in pieces.Walls do
		land.Levels[GRD_UTILS.LevelKey(wall.Level)].Walls[wall.Key] = nil
	end

	for _, floor in pieces.Floors do
		land.Levels[GRD_UTILS.LevelKey(floor.Level)].Floors[floor.Key] = nil
	end

	for _, id in pieces.Furniture do
		land.Furniture[id] = nil
	end

	for _, id in pieces.Dirt do
		land.Dirt[id] = nil
	end

	HSE_Server:SetLand(Player, land)

	-- undo can't bring back (or refund) a house that was sold
	BLD_HISTORY.Clear(Player)

	return true
end

-- accept a buyer's or tenant's offer
function MarketServiceServer:AcceptOffer(Player: Player, HouseId: any, OfferId: any)
	if typeof(HouseId) ~= 'string' or typeof(OfferId) ~= 'string' or not checkRequest(Player) then
		return
	end

	local listing = getListings(Player)[HouseId]
	local offer = listing and findOffer(listing, OfferId)

	if not listing or not offer then
		return
	end

	if offer.Expires <= os.clock() then
		notify(Player, 'That offer expired', BAD)
		return
	end

	local amount: number = offer.Amount

	getListings(Player)[HouseId] = nil

	if listing.Mode == 'Sale' then
		if not MarketServiceServer:RemoveHouse(Player, HouseId) then
			notify(Player, 'That house changed, the sale was cancelled', BAD)
			MarketServiceServer:UpdateLocks(Player)
			MarketServiceServer:SendListings(Player)
			return
		end

		ECN_Server:Reward(Player, {Cash = amount}, 'HouseSale')

		DAT_Server:update(Player, {'Stats', 'HousesSold'}, function(Old)
			return Old + 1
		end)

		DAT_Server:update(Player, {'Stats', 'TotalEarned'}, function(Old)
			return Old + amount
		end)

		ATC_SSignals.LogJourney:Fire(Player, 'SoldHouse')
		notify(Player, `Sold to {offer.Name} for {STR_UTILS.FormatCash(amount)}! The land is free again.`, GOOD)
	else
		local rental: DAT_TYPES.RentalData = {
			Tenant = offer.Name,
			Rent = amount,
			Value = listing.Value,
			Pending = 0,
			Started = os.time(),
			Cells = listing.Cells,
		}

		DAT_Server:set(Player, {'Rentals', HouseId}, rental)

		DAT_Server:update(Player, {'Stats', 'HousesRented'}, function(Old)
			return Old + 1
		end)

		ATC_SSignals.LogJourney:Fire(Player, 'RentedHouse')
		notify(Player, `{offer.Name} moved in for {STR_UTILS.FormatCash(amount)}/min. Keep the house clean to keep the rent up!`, GOOD)
	end

	MarketServiceServer:UpdateLocks(Player)
	MarketServiceServer:SendListings(Player)
end

-- turn down an offer
function MarketServiceServer:DeclineOffer(Player: Player, HouseId: any, OfferId: any)
	if typeof(HouseId) ~= 'string' or typeof(OfferId) ~= 'string' or not checkRequest(Player) then
		return
	end

	local listing = getListings(Player)[HouseId]

	if not listing then
		return
	end

	local _, index = findOffer(listing, OfferId)

	if index then
		table.remove(listing.Offers, index)
		MarketServiceServer:SendListings(Player)
	end
end

-- collect all rent waiting in every rental
function MarketServiceServer:CollectRent(Player: Player)
	if not checkRequest(Player) then
		return
	end

	local total = 0

	for id, rental in getRentals(Player) do
		local whole = math.floor(rental.Pending)

		if whole > 0 then
			total += whole
			DAT_Server:set(Player, {'Rentals', id, 'Pending'}, rental.Pending - whole)
		end
	end

	if total <= 0 then
		notify(Player, 'No rent to collect yet', BAD)
		return
	end

	ECN_Server:Reward(Player, {Cash = total}, 'Rent')

	DAT_Server:update(Player, {'Stats', 'TotalEarned'}, function(Old)
		return Old + total
	end)

	ATC_SSignals.LogJourney:Fire(Player, 'CollectedRent')
end

-- end a lease (the house can be edited, sold or rented again)
function MarketServiceServer:Evict(Player: Player, HouseId: any)
	if typeof(HouseId) ~= 'string' or not checkRequest(Player) then
		return
	end

	local rental = getRentals(Player)[HouseId]

	if not rental then
		return
	end

	-- pay out what the tenant still owes first
	local owed = math.floor(rental.Pending)

	if owed > 0 then
		ECN_Server:Reward(Player, {Cash = owed}, 'Rent')
	end

	DAT_Server:set(Player, {'Rentals', HouseId}, nil)
	MarketServiceServer:UpdateLocks(Player)

	notify(Player, `{rental.Tenant} moved out. You can edit the house again.`, GOOD)
end

return MarketServiceServer
