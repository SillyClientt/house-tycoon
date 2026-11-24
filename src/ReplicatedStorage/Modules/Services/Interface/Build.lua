--!strict
local Build = {}

local PLS = game:GetService('Players')
local RPS = game:GetService('ReplicatedStorage')

local BLD_CSignals = require(RPS.Modules.Services.BuildService.BuildClientSignals)
local BLD_Client = require(RPS.Modules.Services.BuildService.BuildServiceClient)
local BLD_View = require(RPS.Modules.Services.BuildService.BuildViewClient)
local MON_Client = require(RPS.Modules.Services.MonetizationService.MonetizationServiceClient)
local INT_CSignals = require(RPS.Modules.Services.InterfaceService.InterfaceClientSignals)
local BLD_CONFIGS = require(RPS.Modules.Configs.BuildConfigs)
local FUR_CONFIGS = require(RPS.Modules.Configs.FurnitureConfigs)
local LND_CONFIGS = require(RPS.Modules.Configs.LandConfigs)
local CFG_TYPES = require(RPS.Modules.Types.ConfigTypes)
local STR_UTILS = require(RPS.Modules.Utils.StringUtils)
local INT_UTILS = require(RPS.Modules.Utils.InterfaceUtils)

type BuildMode = BLD_CSignals.BuildMode

local plr = PLS.LocalPlayer :: Player
local hud = plr:WaitForChild('PlayerGui'):WaitForChild('HUD')
local actions = INT_UTILS.Get(hud, 'Actions', 'Frame')
local buildBtn = INT_UTILS.Get(actions, 'Build', 'TextButton') :: TextButton

local bar = INT_UTILS.Get(hud, 'BuildBar', 'Frame') :: Frame
local tabs = INT_UTILS.Get(bar, 'Tabs', 'Frame')
local options = INT_UTILS.Get(bar, 'Options', 'Frame')
local items = INT_UTILS.Get(bar, 'Items', 'ScrollingFrame') :: ScrollingFrame
local hintLabel = INT_UTILS.Get(bar, 'Hint', 'TextLabel') :: TextLabel
local costLabel = INT_UTILS.Get(bar, 'Cost', 'TextLabel') :: TextLabel
local levelBox = INT_UTILS.Get(bar, 'LevelBox', 'Frame')
local levelDown = INT_UTILS.Get(levelBox, 'LevelDown', 'TextButton') :: TextButton
local levelUp = INT_UTILS.Get(levelBox, 'LevelUp', 'TextButton') :: TextButton
local levelLabel = INT_UTILS.Get(levelBox, 'LevelLabel', 'TextLabel') :: TextLabel
local lightsBtn = INT_UTILS.Get(levelBox, 'Lights', 'TextButton') :: TextButton

local optionTemplate = INT_UTILS.Get(options, 'OptionTemplate', 'TextButton') :: TextButton
local itemTemplate = INT_UTILS.Get(items, 'ItemTemplate', 'TextButton') :: TextButton

local GREY = Color3.fromRGB(200, 200, 200)
local CAMERA_HINT = 'WASD move  |  scroll zoom  |  Q/E or right-drag turn  |  Ctrl+Z undo'

local HINTS: {[BuildMode]: string} = {
	None = '',
	Room = 'Drag a box to build a whole room (walls, floor and a front door)',
	Wall = 'Drag from corner to corner to build walls',
	Door = 'Click a wall to put a door in it (click again to remove)',
	Window = 'Click a wall to put a window in it (click again to remove)',
	Floor = 'Drag a box to lay floor',
	Paint = 'Click or drag over walls / floors to repaint them',
	Furniture = 'Pick an item below. Lamps light up rooms and raise the value',
	Edit = 'Click your furniture to rotate, move or sell it',
	Erase = 'Click or drag over pieces to remove them (75% back)',
}

-- tab button name -> tool
local TAB_MODES: {[string]: BuildMode} = {
	Room = 'Room',
	Walls = 'Wall',
	Door = 'Door',
	Window = 'Window',
	Floors = 'Floor',
	Paint = 'Paint',
	Furniture = 'Furniture',
	Edit = 'Edit',
	Erase = 'Erase',
}

local mode: BuildMode = 'None'
local category: CFG_TYPES.FurnitureCategory = 'Bedroom'
local furnitureItem: string? = nil

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

-- add an option button (top row)
local function addOption(Text: string, Order: number, Picked: boolean, OnClick: () -> ())
	local button = INT_UTILS.CloneTemplate(optionTemplate) :: TextButton
	button.Text = Text
	button.LayoutOrder = Order
	button.BackgroundColor3 = if Picked then INT_UTILS.Colors.Active else INT_UTILS.Colors.Button
	button.Activated:Connect(OnClick)
end

-- add an item button (bottom row), Badge shows R$ / VIP / Light
local function addItem(Title: string, Price: number, Color: Color3, Order: number, Picked: boolean, OnClick: () -> (), Badge: string?)
	local button = INT_UTILS.CloneTemplate(itemTemplate) :: TextButton
	button.LayoutOrder = Order

	local swatch = button:FindFirstChild('Swatch') :: Frame?
	local title = button:FindFirstChild('Title') :: TextLabel?
	local price = button:FindFirstChild('Price') :: TextLabel?
	local badge = button:FindFirstChild('Badge') :: TextLabel?

	if swatch then
		swatch.BackgroundColor3 = Color
	end

	if title then
		title.Text = Title
	end

	if price then
		price.Text = STR_UTILS.FormatCash(Price)
	end

	if badge then
		badge.Visible = Badge ~= nil
		badge.Text = Badge or ''
	end

	INT_UTILS.SetPicked(button, Picked)
	button.Activated:Connect(OnClick)
end

-- list wall styles as items
local function addWallStyles(Picked: string, OnPick: (string) -> ())
	for _, name in sortedKeys(BLD_CONFIGS.WallStyles, function(C) return C.Order end) do
		local config = BLD_CONFIGS.WallStyles[name]

		addItem(config.DisplayName, config.Cost, config.Color, config.Order, name == Picked, function()
			OnPick(name)
		end)
	end
end

-- list floor styles as items
local function addFloorStyles(Picked: string, OnPick: (string) -> ())
	for _, name in sortedKeys(BLD_CONFIGS.FloorStyles, function(C) return C.Order end) do
		local config = BLD_CONFIGS.FloorStyles[name]

		addItem(config.DisplayName, config.Cost, config.Color, config.Order, name == Picked, function()
			OnPick(name)
		end)
	end
end

-- rebuild the option and item rows for the open tool
local function refresh()
	INT_UTILS.ClearClones(options)
	INT_UTILS.ClearClones(items)

	local wallStyle, floorStyle, paintTarget, paintStyle = BLD_Client:GetStyles()

	if mode == 'Room' then
		-- top row: wall style, bottom row: floor style
		for _, name in sortedKeys(BLD_CONFIGS.WallStyles, function(C) return C.Order end) do
			local config = BLD_CONFIGS.WallStyles[name]

			addOption(`{config.DisplayName} walls`, config.Order, name == wallStyle, function()
				BLD_CSignals.ModeRequested:Fire('Room', name, floorStyle)
			end)
		end

		addFloorStyles(floorStyle, function(Name)
			BLD_CSignals.ModeRequested:Fire('Room', wallStyle, Name)
		end)

	elseif mode == 'Wall' then
		addWallStyles(wallStyle, function(Name)
			BLD_CSignals.ModeRequested:Fire('Wall', Name)
		end)

	elseif mode == 'Floor' then
		addFloorStyles(floorStyle, function(Name)
			BLD_CSignals.ModeRequested:Fire('Floor', Name)
		end)

	elseif mode == 'Paint' then
		addOption('Walls', 1, paintTarget == 'Wall', function()
			BLD_CSignals.ModeRequested:Fire('Paint', 'Wall')
		end)

		addOption('Floors', 2, paintTarget == 'Floor', function()
			BLD_CSignals.ModeRequested:Fire('Paint', 'Floor')
		end)

		if paintTarget == 'Floor' then
			addFloorStyles(paintStyle, function(Name)
				BLD_CSignals.ModeRequested:Fire('Paint', 'Floor', Name)
			end)
		else
			addWallStyles(paintStyle, function(Name)
				BLD_CSignals.ModeRequested:Fire('Paint', 'Wall', Name)
			end)
		end

	elseif mode == 'Furniture' then
		for index, info in FUR_CONFIGS.Categories do
			addOption(info.DisplayName, index, info.Name == category, function()
				category = info.Name
				refresh()
			end)
		end

		for _, name in sortedKeys(FUR_CONFIGS.Items, function(C) return C.Order end) do
			local config = FUR_CONFIGS.Items[name]

			if config.Category ~= category then
				continue
			end

			local lock = MON_Client:GetItemLock(name)
			local premium = config.Premium
			local badge = if lock == 'Premium' and premium then `R${premium.RobuxPrice}`
				elseif lock == 'Vip' then 'VIP'
				elseif config.LightRange then 'Light'
				else nil

			addItem(config.DisplayName, config.Price, GREY, config.Order, name == furnitureItem, function()
				-- locked items open the purchase instead
				if lock == 'Premium' then
					MON_Client:PromptPremium(name)
				elseif lock == 'Vip' then
					MON_Client:PromptPass('VipFurniture')
				else
					BLD_CSignals.ModeRequested:Fire('Furniture', name)
				end
			end, badge)
		end
	end

	-- highlight the open tab
	for tabName, tabMode in TAB_MODES do
		local tab = tabs:FindFirstChild(tabName)

		if tab and tab:IsA('GuiButton') then
			tab.BackgroundColor3 = if tabMode == mode then INT_UTILS.Colors.Active else INT_UTILS.Colors.Button
		end
	end

	local hint = if mode == 'Furniture' and furnitureItem
		then 'Click to place  |  R rotate  |  Esc stop'
		else HINTS[mode]

	hintLabel.Text = if hint ~= '' then `{hint}\n{CAMERA_HINT}` else ''
end

-- open a tool using the last options picked for it
local function openTab(TabName: string)
	local tabMode = TAB_MODES[TabName]

	if tabMode then
		BLD_CSignals.ModeRequested:Fire(tabMode)
	end
end

-- show the floor being built on
local function refreshLevel(Level: number)
	local config = LND_CONFIGS.Levels[Level]

	levelLabel.Text = if config then config.DisplayName else `Floor {Level}`
end

-- initialize build ui
function Build:Init()
	buildBtn.Activated:Connect(function()
		if bar.Visible then
			BLD_CSignals.ModeRequested:Fire('None')
		else
			openTab('Room')
		end
	end)

	for tabName in TAB_MODES do
		local tab = tabs:FindFirstChild(tabName)

		if tab and tab:IsA('GuiButton') then
			tab.Activated:Connect(function()
				openTab(tabName)
			end)
		end
	end

	local close = INT_UTILS.Get(tabs, 'Close', 'TextButton') :: TextButton
	local undo = INT_UTILS.Get(tabs, 'Undo', 'TextButton') :: TextButton

	close.Activated:Connect(function()
		BLD_CSignals.ModeRequested:Fire('None')
	end)

	undo.Activated:Connect(function()
		BLD_Client:Undo()
	end)

	BLD_CSignals.ModeChanged:Connect(function(Mode, OptionA)
		mode = Mode
		furnitureItem = nil

		if Mode == 'Furniture' and OptionA then
			furnitureItem = OptionA

			local config = FUR_CONFIGS.Items[OptionA]

			if config then
				category = config.Category
			end
		end

		bar.Visible = Mode ~= 'None'
		actions.Visible = Mode == 'None'

		-- building closes any open panel
		if Mode ~= 'None' then
			INT_CSignals.PanelOpened:Fire('Build')
		end
		costLabel.Text = ''

		refresh()
	end)

	levelDown.Activated:Connect(function()
		BLD_Client:SetLevel(BLD_Client:GetLevel() - 1)
	end)

	levelUp.Activated:Connect(function()
		BLD_Client:SetLevel(BLD_Client:GetLevel() + 1)
	end)

	lightsBtn.Activated:Connect(function()
		BLD_View:SetLightView(not BLD_View:IsLightView())
		lightsBtn.Text = if BLD_View:IsLightView() then '\u{1F4A1} On' else '\u{1F4A1} Off'
	end)

	BLD_CSignals.LevelChanged:Connect(refreshLevel)
	refreshLevel(BLD_Client:GetLevel())

	BLD_CSignals.CostChanged:Connect(function(Cost)
		costLabel.Text = if Cost then `Cost: {STR_UTILS.FormatCash(Cost)}` else ''
	end)
end

return Build
