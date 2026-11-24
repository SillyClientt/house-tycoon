--!strict
-- floating "House 1 | $8,400 | Rented" labels above the local player's houses
local HouseLabels = {}

local RPS = game:GetService('ReplicatedStorage')
local WKS = game:GetService('Workspace')

local DAT_Client = require(RPS.Modules.Packages.DataService).client
local HSE_Client = require(RPS.Modules.Services.HouseService.HouseServiceClient)
local HSE_CSignals = require(RPS.Modules.Services.HouseService.HouseClientSignals)
local MKT_CSignals = require(RPS.Modules.Services.MarketService.MarketClientSignals)
local PLT_Client = require(RPS.Modules.Services.PlotService.PlotServiceClient)
local BLD_CONFIGS = require(RPS.Modules.Configs.BuildConfigs)
local GRD_UTILS = require(RPS.Modules.Utils.GridUtils)
local STR_UTILS = require(RPS.Modules.Utils.StringUtils)

local STATUS_COLORS: {[string]: Color3} = {
	Building = Color3.fromRGB(200, 200, 210),
	['For Sale'] = Color3.fromRGB(255, 210, 90),
	['For Rent'] = Color3.fromRGB(120, 190, 255),
	Rented = Color3.fromRGB(120, 230, 140),
}

local folder: Folder

-- make one label line
local function addLine(Parent: Instance, Text: string, Color: Color3, Order: number, Size: number)
	local label = Instance.new('TextLabel')
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, Size)
	label.Font = Enum.Font.FredokaOne
	label.TextSize = Size - 4
	label.TextColor3 = Color
	label.TextStrokeTransparency = 0.3
	label.Text = Text
	label.LayoutOrder = Order
	label.Parent = Parent
end

-- rebuild every label
local function refresh()
	folder:ClearAllChildren()

	local origin = PLT_Client:GetOrigin()

	if not origin then
		return
	end

	for index, house in HSE_Client:GetHouses() do
		local status = HSE_Client:GetStatus(house.Id)
		local height = GRD_UTILS.LevelHeight(house.TopLevel) + BLD_CONFIGS.WallHeight + 4

		local anchor = Instance.new('Part')
		anchor.Name = house.Id
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.Transparency = 1
		anchor.Size = Vector3.new(0.2, 0.2, 0.2)
		anchor.CFrame = CFrame.new(origin + Vector3.new(house.CenterX, height, house.CenterZ))
		anchor.Parent = folder

		local billboard = Instance.new('BillboardGui')
		billboard.Size = UDim2.fromOffset(220, 74)
		billboard.MaxDistance = 220
		billboard.Adornee = anchor
		billboard.Parent = anchor

		local layout = Instance.new('UIListLayout')
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.Parent = billboard

		addLine(billboard, `House {index}`, Color3.new(1, 1, 1), 1, 26)
		addLine(billboard, STR_UTILS.FormatCash(house.Value), Color3.fromRGB(120, 230, 140), 2, 24)
		addLine(billboard, if house.DirtCount > 0 then `{status}  |  {house.DirtCount} dirt` else status, STATUS_COLORS[status] or Color3.new(1, 1, 1), 3, 22)
	end
end

-- initialize house labels ui
function HouseLabels:Init()
	folder = Instance.new('Folder')
	folder.Name = 'HouseLabels'
	folder.Parent = WKS

	DAT_Client:waitForData()

	HSE_CSignals.HousesChanged:Connect(refresh)
	MKT_CSignals.ListingsChanged:Connect(refresh)
	DAT_Client:getChangedSignal('Rentals'):Connect(function()
		-- rent ticks change Rentals often; only redraw when a rental starts or ends
		local count = 0

		for _ in DAT_Client:get('Rentals') do
			count += 1
		end

		if count ~= folder:GetAttribute('Rentals') then
			folder:SetAttribute('Rentals', count)
			refresh()
		end
	end)
end

return HouseLabels
