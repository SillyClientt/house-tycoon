--!strict
local Houses = {}

local PLS = game:GetService('Players')
local RPS = game:GetService('ReplicatedStorage')

local DAT_Client = require(RPS.Modules.Packages.DataService).client
local HSE_Client = require(RPS.Modules.Services.HouseService.HouseServiceClient)
local HSE_CSignals = require(RPS.Modules.Services.HouseService.HouseClientSignals)
local MKT_Client = require(RPS.Modules.Services.MarketService.MarketServiceClient)
local MKT_CSignals = require(RPS.Modules.Services.MarketService.MarketClientSignals)
local INT_CSignals = require(RPS.Modules.Services.InterfaceService.InterfaceClientSignals)
local MKT_CONFIGS = require(RPS.Modules.Configs.MarketConfigs)
local STR_UTILS = require(RPS.Modules.Utils.StringUtils)
local INT_UTILS = require(RPS.Modules.Utils.InterfaceUtils)
local DAT_TYPES = require(RPS.Modules.Types.DataTypes)

local PANEL_NAME = 'Houses'

local plr = PLS.LocalPlayer :: Player
local hud = plr:WaitForChild('PlayerGui'):WaitForChild('HUD')
local actions = INT_UTILS.Get(hud, 'Actions', 'Frame')
local housesBtn = INT_UTILS.Get(actions, 'Houses', 'TextButton') :: TextButton

local panel = INT_UTILS.Get(hud, 'HousesPanel', 'Frame') :: Frame
local closeBtn = INT_UTILS.Get(panel, 'Close', 'TextButton') :: TextButton
local collectBtn = INT_UTILS.Get(panel, 'CollectAll', 'TextButton') :: TextButton
local listBox = INT_UTILS.Get(panel, 'ListBox', 'Frame')
local noHouses = INT_UTILS.Get(listBox, 'NoHouses', 'TextLabel') :: TextLabel
local list = INT_UTILS.Get(listBox, 'List', 'ScrollingFrame') :: ScrollingFrame
local houseTemplate = INT_UTILS.Get(list, 'HouseTemplate', 'TextButton') :: TextButton

local details = INT_UTILS.Get(panel, 'Details', 'Frame')
local nameLabel = INT_UTILS.Get(details, 'Name', 'TextLabel') :: TextLabel
local statusLabel = INT_UTILS.Get(details, 'Status', 'TextLabel') :: TextLabel
local valueLabel = INT_UTILS.Get(details, 'Value', 'TextLabel') :: TextLabel
local statsLabel = INT_UTILS.Get(details, 'Stats', 'TextLabel') :: TextLabel
local roomsLabel = INT_UTILS.Get(details, 'Rooms', 'TextLabel') :: TextLabel
local buttons = INT_UTILS.Get(details, 'Buttons', 'Frame')
local sellBtn = INT_UTILS.Get(buttons, 'Sell', 'TextButton') :: TextButton
local rentBtn = INT_UTILS.Get(buttons, 'Rent', 'TextButton') :: TextButton
local unlistBtn = INT_UTILS.Get(buttons, 'Unlist', 'TextButton') :: TextButton
local evictBtn = INT_UTILS.Get(buttons, 'Evict', 'TextButton') :: TextButton
local noOffers = INT_UTILS.Get(details, 'NoOffers', 'TextLabel') :: TextLabel
local offersList = INT_UTILS.Get(details, 'Offers', 'ScrollingFrame') :: ScrollingFrame
local offerTemplate = INT_UTILS.Get(offersList, 'OfferTemplate', 'Frame') :: Frame

local selectedId: string? = nil
local timerLabels: {[string]: TextLabel} = {}
local lastOfferCount = 0

-- set a child label's text if it exists
local function setText(Parent: Instance, Name: string, Text: string)
	local label = Parent:FindFirstChild(Name)

	if label and label:IsA('TextLabel') then
		label.Text = Text
	end
end

-- "Bedroom and Bathroom"
local function roomNames(Types: {any}): string
	local names = {}

	for _, roomType in Types do
		table.insert(names, MKT_CONFIGS.RoomTypes[roomType].DisplayName)
	end

	return table.concat(names, ' and ')
end

-- percentage text
local function percent(Value: number): string
	return `{math.floor(Value * 100 + 0.5)}%`
end

-- the selected house (falls back to the first one)
local function getSelected(): (DAT_TYPES.HouseInfo?, number)
	local houses = HSE_Client:GetHouses()

	for index, house in houses do
		if house.Id == selectedId then
			return house, index
		end
	end

	selectedId = if houses[1] then houses[1].Id else nil

	return houses[1], 1
end

-- rebuild the offers list for the selected house
local function refreshOffers(House: DAT_TYPES.HouseInfo?)
	INT_UTILS.ClearClones(offersList)
	timerLabels = {}

	local listing = House and MKT_Client:GetListings()[House.Id]
	local offers = if listing then listing.Offers else {}

	noOffers.Visible = #offers == 0
	noOffers.Text = if listing then 'Waiting for offers...' else 'Put the house on the market to get offers'

	if not listing then
		return
	end

	local houseId = listing.HouseId
	local isSale = listing.Mode == 'Sale'

	for index, offer in offers do
		local row = INT_UTILS.CloneTemplate(offerTemplate)
		row.LayoutOrder = index

		setText(row, 'Buyer', offer.Name)
		setText(row, 'Amount', if isSale
			then STR_UTILS.FormatCash(offer.Amount)
			else `{STR_UTILS.FormatCash(offer.Amount)}/min`)

		local timerLabel = row:FindFirstChild('Timer')
		local acceptBtn = row:FindFirstChild('Accept')
		local declineBtn = row:FindFirstChild('Decline')

		if timerLabel and timerLabel:IsA('TextLabel') then
			timerLabels[offer.Id] = timerLabel
		end

		if acceptBtn and acceptBtn:IsA('GuiButton') then
			acceptBtn.Activated:Connect(function()
				MKT_Client:AcceptOffer(houseId, offer.Id)
			end)
		end

		if declineBtn and declineBtn:IsA('GuiButton') then
			declineBtn.Activated:Connect(function()
				MKT_Client:DeclineOffer(houseId, offer.Id)
			end)
		end
	end
end

-- show the selected house's details
local function refreshDetails()
	local house, number = getSelected()

	details.Visible = house ~= nil
	refreshOffers(house)

	if not house then
		return
	end

	local status = HSE_Client:GetStatus(house.Id)
	local rental = DAT_Client:get({'Rentals', house.Id})
	local listing = MKT_Client:GetListings()[house.Id]

	nameLabel.Text = `House {number}`
	valueLabel.Text = `Value: {STR_UTILS.FormatCash(house.Value)}`
	statsLabel.Text = `Lighting {percent(house.LitFraction)}  |  Clean {percent(house.Cleanliness)} ({house.DirtCount} dirt)  |  {house.CellCount} tiles`

	-- status line
	if status == 'Rented' and rental then
		statusLabel.Text = `Rented by {rental.Tenant} for {STR_UTILS.FormatCash(rental.Rent)}/min (less when dirty)`
	elseif listing then
		statusLabel.Text = `{status} at about {STR_UTILS.FormatCash(listing.Value)}`
	elseif not house.Livable then
		statusLabel.Text = `Needs a {roomNames(house.Missing)} to sell or rent`
	elseif house.Complete then
		statusLabel.Text = `Complete home! Value x{MKT_CONFIGS.CompleteMultiplier}`
	else
		statusLabel.Text = 'Ready to sell or rent'
	end

	-- rooms
	local lines = {}

	for _, room in house.Rooms do
		local roomType = room.Type
		local roomName = if roomType then MKT_CONFIGS.RoomTypes[roomType].DisplayName else 'Empty room'
		local lit = room.Lit / math.max(1, room.Size)

		table.insert(lines, `• {roomName} <font color="#AAB0BE">(floor {room.Level}, {room.Size} tiles, {percent(lit)} lit)</font>`)
	end

	roomsLabel.Text = table.concat(lines, '\n')

	-- buttons
	sellBtn.Visible = status == 'Building'
	rentBtn.Visible = status == 'Building'
	unlistBtn.Visible = status == 'For Sale' or status == 'For Rent'
	evictBtn.Visible = status == 'Rented'
end

-- rebuild the house list
local function refreshList()
	if not panel.Visible then
		return
	end

	INT_UTILS.ClearClones(list)

	local houses = HSE_Client:GetHouses()
	noHouses.Visible = #houses == 0

	for index, house in houses do
		local button = INT_UTILS.CloneTemplate(houseTemplate) :: TextButton
		button.LayoutOrder = index

		setText(button, 'Title', `House {index}`)
		setText(button, 'Status', HSE_Client:GetStatus(house.Id))
		setText(button, 'Value', STR_UTILS.FormatCash(house.Value))

		INT_UTILS.SetPicked(button, house.Id == selectedId)

		button.Activated:Connect(function()
			selectedId = house.Id
			refreshList()
		end)
	end

	refreshDetails()
end

-- total rent waiting
local function refreshCollect()
	local total = 0

	for _, rental in DAT_Client:get('Rentals') do
		total += math.floor(rental.Pending)
	end

	collectBtn.Text = `\u{1F4B5} Collect {STR_UTILS.FormatCash(total)}`
end

-- open / close the panel
local function setOpen(Open: boolean)
	panel.Visible = Open

	if Open then
		INT_CSignals.PanelOpened:Fire(PANEL_NAME)
		refreshList()
		refreshCollect()
	end
end

-- initialize houses ui
function Houses:Init()
	DAT_Client:waitForData()

	housesBtn.Activated:Connect(function()
		setOpen(not panel.Visible)
	end)

	closeBtn.Activated:Connect(function()
		setOpen(false)
	end)

	INT_CSignals.PanelOpened:Connect(function(Name)
		if Name ~= PANEL_NAME then
			panel.Visible = false
		end
	end)

	sellBtn.Activated:Connect(function()
		if selectedId then
			MKT_Client:ListHouse(selectedId, 'Sale')
		end
	end)

	rentBtn.Activated:Connect(function()
		if selectedId then
			MKT_Client:ListHouse(selectedId, 'Rent')
		end
	end)

	unlistBtn.Activated:Connect(function()
		if selectedId then
			MKT_Client:Unlist(selectedId)
		end
	end)

	evictBtn.Activated:Connect(function()
		if selectedId then
			MKT_Client:Evict(selectedId)
		end
	end)

	collectBtn.Activated:Connect(function()
		MKT_Client:CollectRent()
	end)

	HSE_CSignals.HousesChanged:Connect(refreshList)

	DAT_Client:getChangedSignal('Rentals'):Connect(function()
		refreshCollect()
	end)

	MKT_CSignals.ListingsChanged:Connect(function(Listings)
		refreshList()

		-- tell the player about new offers without opening the panel on top of what they're doing
		local offerCount = 0
		local newest: string? = nil

		for houseId, listing in Listings do
			offerCount += #listing.Offers

			if #listing.Offers > 0 then
				newest = houseId
			end
		end

		if offerCount > lastOfferCount and newest then
			if not panel.Visible then
				selectedId = newest
			end

			INT_CSignals.Notify:Fire('\u{1F4E8} New offer! Open Houses to see it', INT_UTILS.Colors.Gold)
		end

		lastOfferCount = offerCount
	end)

	-- offer countdowns
	task.spawn(function()
		while true do
			task.wait(0.5)

			for id, label in timerLabels do
				label.Text = `{math.ceil(MKT_Client:GetTimeLeft(id))}s`
			end
		end
	end)

	refreshCollect()
end

return Houses
