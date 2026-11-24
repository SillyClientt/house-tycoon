--!strict
local Land = {}

local PLS = game:GetService('Players')
local RPS = game:GetService('ReplicatedStorage')

local DAT_Client = require(RPS.Modules.Packages.DataService).client
local PLT_Client = require(RPS.Modules.Services.PlotService.PlotServiceClient)
local MON_Client = require(RPS.Modules.Services.MonetizationService.MonetizationServiceClient)
local INT_CSignals = require(RPS.Modules.Services.InterfaceService.InterfaceClientSignals)
local LND_CONFIGS = require(RPS.Modules.Configs.LandConfigs)
local GRD_UTILS = require(RPS.Modules.Utils.GridUtils)
local LND_UTILS = require(RPS.Modules.Utils.LandUtils)
local STR_UTILS = require(RPS.Modules.Utils.StringUtils)
local INT_UTILS = require(RPS.Modules.Utils.InterfaceUtils)

local PANEL_NAME = 'Land'

local plr = PLS.LocalPlayer :: Player
local hud = plr:WaitForChild('PlayerGui'):WaitForChild('HUD')
local actions = INT_UTILS.Get(hud, 'Actions', 'Frame')
local landBtn = INT_UTILS.Get(actions, 'Land', 'TextButton') :: TextButton

local panel = INT_UTILS.Get(hud, 'LandPanel', 'Frame') :: Frame
local closeBtn = INT_UTILS.Get(panel, 'Close', 'TextButton') :: TextButton
local grid = INT_UTILS.Get(panel, 'Grid', 'Frame')
local parcelTemplate = INT_UTILS.Get(grid, 'ParcelTemplate', 'TextButton') :: TextButton
local infoLabel = INT_UTILS.Get(panel, 'Info', 'TextLabel') :: TextLabel
local buyCashBtn = INT_UTILS.Get(panel, 'BuyCash', 'TextButton') :: TextButton
local buyRobuxBtn = INT_UTILS.Get(panel, 'BuyRobux', 'TextButton') :: TextButton
local levelInfo = INT_UTILS.Get(panel, 'LevelInfo', 'TextLabel') :: TextLabel
local unlockLevelBtn = INT_UTILS.Get(panel, 'UnlockLevel', 'TextButton') :: TextButton

local OWNED_COLOR = Color3.fromRGB(64, 168, 98)
local LOCKED_COLOR = Color3.fromRGB(34, 36, 46)

local selectedKey: string? = nil

-- rebuild the parcel grid and buttons
local function refresh()
	if not panel.Visible then
		return
	end

	INT_UTILS.ClearClones(grid)

	local parcels = DAT_Client:get('Parcels')
	local price = LND_UTILS.GetNextPrice(parcels)
	local size = LND_CONFIGS.ParcelGrid

	if selectedKey and not LND_UTILS.CanBuyParcel(parcels, selectedKey) then
		selectedKey = nil
	end

	-- far side of the land on top, road side at the bottom
	for z = 0, size - 1 do
		for x = 0, size - 1 do
			local key = GRD_UTILS.CellKey(x, z)
			local button = INT_UTILS.CloneTemplate(parcelTemplate) :: TextButton
			button.LayoutOrder = z * size + x

			if parcels[key] then
				button.Text = 'Owned'
				button.BackgroundColor3 = OWNED_COLOR
			elseif LND_UTILS.CanBuyParcel(parcels, key) then
				button.Text = if price then STR_UTILS.GetCondensedAmount(price) else ''
				button.BackgroundColor3 = INT_UTILS.Colors.Button
			else
				button.Text = 'Locked'
				button.BackgroundColor3 = LOCKED_COLOR
			end

			INT_UTILS.SetPicked(button, key == selectedKey)

			button.Activated:Connect(function()
				if LND_UTILS.CanBuyParcel(parcels, key) then
					selectedKey = key
				end

				refresh()
			end)
		end
	end

	-- buy buttons
	local tier = LND_UTILS.GetParcelTier(parcels)
	local canBuy = selectedKey ~= nil and price ~= nil

	buyCashBtn.Visible = canBuy
	buyRobuxBtn.Visible = canBuy and tier ~= nil

	if not price then
		infoLabel.Text = 'You own all the land!'
	elseif selectedKey then
		infoLabel.Text = 'Buy this parcel to build more houses'
		buyCashBtn.Text = `Buy {STR_UTILS.FormatCash(price)}`
		buyRobuxBtn.Text = if tier then `Buy R${tier.RobuxPrice}` else ''
	else
		infoLabel.Text = 'Pick a parcel next to your land'
	end

	-- floors
	local levels = DAT_Client:get('Levels')
	local nextLevel = LND_CONFIGS.Levels[levels + 1]

	levelInfo.Text = `Floors unlocked: {levels}/{LND_CONFIGS.MaxLevels}`
	unlockLevelBtn.Text = if nextLevel
		then `Unlock {nextLevel.DisplayName} - {STR_UTILS.FormatCash(nextLevel.Cost)}`
		else 'All floors unlocked'
end

-- open / close the panel
local function setOpen(Open: boolean)
	panel.Visible = Open

	if Open then
		INT_CSignals.PanelOpened:Fire(PANEL_NAME)
		refresh()
	end
end

-- initialize land ui
function Land:Init()
	DAT_Client:waitForData()

	landBtn.Activated:Connect(function()
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

	buyCashBtn.Activated:Connect(function()
		if selectedKey then
			PLT_Client:BuyParcel(selectedKey)
		end
	end)

	buyRobuxBtn.Activated:Connect(function()
		if selectedKey then
			MON_Client:PromptParcel(selectedKey)
		end
	end)

	unlockLevelBtn.Activated:Connect(function()
		PLT_Client:UnlockLevel()
	end)

	DAT_Client:getChangedSignal('Parcels'):Connect(refresh)
	DAT_Client:getChangedSignal('Levels'):Connect(refresh)
end

return Land
