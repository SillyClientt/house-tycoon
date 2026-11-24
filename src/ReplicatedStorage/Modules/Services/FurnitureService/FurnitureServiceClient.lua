--!strict
local FurnitureServiceClient = {}

local RPS = game:GetService('ReplicatedStorage')
local WKS = game:GetService('Workspace')
local UIS = game:GetService('UserInputService')
local RNS = game:GetService('RunService')

local FUR_CSignals = require(script.Parent.FurnitureClientSignals)
local BLD_CSignals = require(RPS.Modules.Services.BuildService.BuildClientSignals)
local DAT_Client = require(RPS.Modules.Packages.DataService).client
local PLT_Client = require(RPS.Modules.Services.PlotService.PlotServiceClient)
local FUR_CONFIGS = require(RPS.Modules.Configs.FurnitureConfigs)
local BLD_CONFIGS = require(RPS.Modules.Configs.BuildConfigs)
local GRD_UTILS = require(RPS.Modules.Utils.GridUtils)
local FUR_UTILS = require(RPS.Modules.Utils.FurnitureUtils)
local BLD_UTILS = require(RPS.Modules.Utils.BuildUtils)
local INP_UTILS = require(RPS.Modules.Utils.InputUtils)
local DAT_TYPES = require(RPS.Modules.Types.DataTypes)

local remotes = RPS.Remotes.FurnitureService

local VALID_COLOR = Color3.fromRGB(90, 210, 120)
local INVALID_COLOR = Color3.fromRGB(235, 80, 80)
local SELECT_COLOR = Color3.fromRGB(255, 220, 90)
local SNAP = 0.5 -- studs

local editing = false
local level = 1

local placingName: string?
local movingId: string?
local preview: Model?
local previewHighlight: Highlight?
local rotation = 0
local placeX, placeZ = 0, 0
local canPlace = false

local selectedId: string?
local selectedModel: Instance?
local selection: Highlight

-- snap a plot-local position to the furniture grid
local function snap(Value: number): number
	return math.floor(Value / SNAP + 0.5) * SNAP
end

-- snap so the footprint's corner sits on a tile corner (stairs)
local function snapToCells(Value: number, Length: number): number
	local size = BLD_CONFIGS.CellSize

	return math.floor((Value - Length / 2) / size + 0.5) * size + Length / 2
end

-- stop showing the placement preview
function FurnitureServiceClient:StopPlacement()
	if preview then
		preview:Destroy()
	end

	preview = nil
	previewHighlight = nil
	placingName = nil
	movingId = nil
	canPlace = false

	BLD_CSignals.CostChanged:Fire(nil)
end

-- clear selection
function FurnitureServiceClient:ClearSelection()
	if not selectedId then
		return
	end

	selectedId = nil
	selectedModel = nil
	selection.Adornee = nil

	FUR_CSignals.SelectionChanged:Fire(nil, nil)
end

-- start placing an item (or moving one when MovingId is given)
function FurnitureServiceClient:StartPlacement(Name: string, MovingId: string?, Rotation: number?)
	FurnitureServiceClient:StopPlacement()

	local config = FUR_CONFIGS.Items[Name]
	local model = FUR_UTILS.CreateModel(Name)

	if not config or not model then
		warn(`[FurnitureServiceClient]: Unknown furniture {Name}`)
		return
	end

	BLD_UTILS.MakeGhost(model)

	local highlight = Instance.new('Highlight')
	highlight.FillTransparency = 0.6
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model

	model.Name = 'FurniturePreview'
	model.Parent = WKS

	preview = model
	previewHighlight = highlight
	placingName = Name
	movingId = MovingId
	rotation = Rotation or rotation

	if not MovingId then
		BLD_CSignals.CostChanged:Fire(config.Price)
	end

	FurnitureServiceClient:UpdatePreview()
end

-- move the preview to the pointer and colour it by whether it fits
function FurnitureServiceClient:UpdatePreview()
	local model = preview
	local name = placingName

	if not model or not name or not PLT_Client:IsReady() then
		return
	end

	local origin = PLT_Client:GetOrigin()
	local floorHeight = BLD_CONFIGS.FloorThickness + GRD_UTILS.LevelHeight(level)
	local hit = origin and INP_UTILS.HitPlane(origin.Y + floorHeight)

	if not origin or not hit then
		canPlace = false
		return
	end

	local x, z = GRD_UTILS.WorldToLocal(origin, hit)
	local config = FUR_CONFIGS.Items[name]

	if config and config.CellAligned then
		local minX, minZ, maxX, maxZ = FUR_UTILS.GetBounds(name, 0, 0, rotation)
		x, z = snapToCells(x, maxX - minX), snapToCells(z, maxZ - minZ)
	else
		x, z = snap(x), snap(z)
	end

	local land: DAT_TYPES.LandData = DAT_Client:get('Land')

	placeX, placeZ = x, z
	canPlace = FUR_UTILS.CanPlace(land, PLT_Client:GetContext(), name, level, x, z, rotation, movingId)

	FUR_UTILS.PlaceFurniture(
		model,
		GRD_UTILS.LocalToWorld(origin, x, z, level) + Vector3.new(0, BLD_CONFIGS.FloorThickness, 0),
		rotation
	)

	if previewHighlight then
		local color = if canPlace then VALID_COLOR else INVALID_COLOR

		previewHighlight.FillColor = color
		previewHighlight.OutlineColor = color
	end
end

-- place / move the previewed item
function FurnitureServiceClient:Confirm()
	FurnitureServiceClient:UpdatePreview()

	local name = placingName

	if not preview or not name or not canPlace then
		return
	end

	if movingId then
		remotes.MoveFurniture:FireServer(movingId, level, placeX, placeZ, rotation)
		FurnitureServiceClient:StopPlacement()
	else
		-- keep the preview so the player can place more
		remotes.PlaceFurniture:FireServer(name, level, placeX, placeZ, rotation)
	end
end

-- rotate the preview, or the selected item
function FurnitureServiceClient:Rotate()
	if preview then
		rotation = (rotation + 90) % 360
		FurnitureServiceClient:UpdatePreview()
	elseif selectedId then
		remotes.RotateFurniture:FireServer(selectedId)
	end
end

-- select the furniture under the pointer
function FurnitureServiceClient:Select()
	local furnitureFolder = PLT_Client:GetPieceFolder(level, 'Furniture')

	if not furnitureFolder then
		return
	end

	local result = INP_UTILS.RaycastInclude({furnitureFolder})
	local current: Instance? = result and result.Instance

	-- walk up to the furniture model
	while current and current.Parent ~= furnitureFolder do
		current = current.Parent
	end

	if not current then
		FurnitureServiceClient:ClearSelection()
		return
	end

	selectedId = current.Name
	selectedModel = current
	selection.Adornee = current

	local itemName = current:GetAttribute('Item')

	FUR_CSignals.SelectionChanged:Fire(current.Name, if typeof(itemName) == 'string' then itemName else nil)
end

-- pick up the selected item to move it
function FurnitureServiceClient:MoveSelected()
	local id = selectedId

	if not id then
		return
	end

	local land: DAT_TYPES.LandData = DAT_Client:get('Land')
	local item = land.Furniture[id]

	FurnitureServiceClient:ClearSelection()

	if item then
		FurnitureServiceClient:StartPlacement(item.Name, id, item.Rotation)
	end
end

-- sell the selected item
function FurnitureServiceClient:RemoveSelected()
	local id = selectedId

	if id then
		remotes.RemoveFurniture:FireServer(id)
		FurnitureServiceClient:ClearSelection()
	end
end

-- rotate the selected item
function FurnitureServiceClient:RotateSelected()
	if selectedId then
		remotes.RotateFurniture:FireServer(selectedId)
	end
end

-- initialize furniture service client-side
function FurnitureServiceClient:Init()
	selection = Instance.new('Highlight')
	selection.FillTransparency = 0.8
	selection.FillColor = SELECT_COLOR
	selection.OutlineColor = SELECT_COLOR
	selection.Parent = WKS

	BLD_CSignals.LevelChanged:Connect(function(Level)
		level = Level
		FurnitureServiceClient:ClearSelection()
	end)

	BLD_CSignals.ModeChanged:Connect(function(Mode, OptionA)
		FurnitureServiceClient:StopPlacement()
		FurnitureServiceClient:ClearSelection()

		editing = Mode == 'Edit'

		if Mode == 'Furniture' and OptionA then
			FurnitureServiceClient:StartPlacement(OptionA)
		end
	end)

	RNS.RenderStepped:Connect(function()
		if preview then
			FurnitureServiceClient:UpdatePreview()
		end

		-- the selected item was sold or the house was cleared
		if selectedModel and not selectedModel.Parent then
			FurnitureServiceClient:ClearSelection()
		end
	end)

	UIS.InputBegan:Connect(function(Input, Processed)
		if Processed then
			return
		end

		local active = preview ~= nil or editing

		if INP_UTILS.IsPress(Input) then
			if preview then
				FurnitureServiceClient:Confirm()
			elseif editing then
				FurnitureServiceClient:Select()
			end

		elseif not active then
			return

		elseif Input.KeyCode == Enum.KeyCode.R then
			FurnitureServiceClient:Rotate()

		elseif Input.KeyCode == Enum.KeyCode.M then
			FurnitureServiceClient:MoveSelected()

		elseif Input.KeyCode == Enum.KeyCode.X or Input.KeyCode == Enum.KeyCode.Delete then
			FurnitureServiceClient:RemoveSelected()

		elseif Input.KeyCode == Enum.KeyCode.Escape then
			if movingId then
				FurnitureServiceClient:StopPlacement()
			else
				BLD_CSignals.ModeRequested:Fire('None')
			end
		end
	end)
end

return FurnitureServiceClient
