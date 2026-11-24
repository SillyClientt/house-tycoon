--!strict
local Shop = {}

local PLS = game:GetService('Players')
local RPS = game:GetService('ReplicatedStorage')

local MON_Client = require(RPS.Modules.Services.MonetizationService.MonetizationServiceClient)
local INT_CSignals = require(RPS.Modules.Services.InterfaceService.InterfaceClientSignals)
local MON_CONFIGS = require(RPS.Modules.Configs.MonetizationConfigs)
local MON_UTILS = require(RPS.Modules.Utils.MonetizationUtils)
local STR_UTILS = require(RPS.Modules.Utils.StringUtils)
local INT_UTILS = require(RPS.Modules.Utils.InterfaceUtils)

local PANEL_NAME = 'Shop'

local plr = PLS.LocalPlayer :: Player
local hud = plr:WaitForChild('PlayerGui'):WaitForChild('HUD')
local actions = INT_UTILS.Get(hud, 'Actions', 'Frame')
local shopBtn = INT_UTILS.Get(actions, 'Shop', 'TextButton') :: TextButton

local panel = INT_UTILS.Get(hud, 'ShopPanel', 'Frame') :: Frame
local closeBtn = INT_UTILS.Get(panel, 'Close', 'TextButton') :: TextButton
local passes = INT_UTILS.Get(panel, 'Passes', 'ScrollingFrame')
local passTemplate = INT_UTILS.Get(passes, 'PassTemplate', 'Frame') :: Frame
local cash = INT_UTILS.Get(panel, 'Cash', 'Frame')
local cashTemplate = INT_UTILS.Get(cash, 'CashTemplate', 'TextButton') :: TextButton

-- set a child label's text if it exists
local function setText(Parent: Instance, Name: string, Text: string)
	local label = Parent:FindFirstChild(Name)

	if label and label:IsA('TextLabel') then
		label.Text = Text
	end
end

-- sort config names by their Order
local function sortedKeys<T>(Configs: {[string]: T}, GetOrder: (T) -> number): {string}
	local keys = {}

	for key in Configs do
		table.insert(keys, key)
	end

	table.sort(keys, function(A, B)
		return GetOrder(Configs[A]) < GetOrder(Configs[B])
	end)

	return keys
end

-- rebuild the gamepass list (shows Owned when bought)
local function refreshPasses()
	INT_UTILS.ClearClones(passes)

	for index, name in sortedKeys(MON_CONFIGS.Gamepasses, function(C) return C.Order end) do
		local pass = MON_CONFIGS.Gamepasses[name]
		local row = INT_UTILS.CloneTemplate(passTemplate)
		row.LayoutOrder = index

		setText(row, 'Title', pass.DisplayName)
		setText(row, 'Description', pass.Description)

		local buy = row:FindFirstChild('Buy')

		if buy and buy:IsA('TextButton') then
			local owned = MON_Client:HasPass(name)

			buy.Text = if owned then 'Owned' else `R${pass.RobuxPrice}`
			buy.Active = not owned

			buy.Activated:Connect(function()
				if not MON_Client:HasPass(name) then
					MON_Client:PromptPass(name)
				end
			end)
		end
	end
end

-- build the cash pack buttons
local function buildCashPacks()
	for index, name in sortedKeys(MON_CONFIGS.CashPacks, function(C) return C.Order end) do
		local pack = MON_CONFIGS.CashPacks[name]
		local button = INT_UTILS.CloneTemplate(cashTemplate) :: TextButton
		button.LayoutOrder = index

		setText(button, 'Amount', STR_UTILS.FormatCash(pack.Cash))
		setText(button, 'Price', `R${pack.RobuxPrice}`)

		button.Activated:Connect(function()
			MON_Client:PromptCashPack(name)
		end)
	end
end

-- open / close the panel
local function setOpen(Open: boolean)
	panel.Visible = Open

	if Open then
		INT_CSignals.PanelOpened:Fire(PANEL_NAME)
		refreshPasses()
	end
end

-- initialize shop ui
function Shop:Init()
	shopBtn.Activated:Connect(function()
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

	-- a pass was bought while the shop is open
	for name in MON_CONFIGS.Gamepasses do
		plr:GetAttributeChangedSignal(MON_UTILS.PassAttribute(name)):Connect(function()
			if panel.Visible then
				refreshPasses()
			end
		end)
	end

	buildCashPacks()
end

return Shop
