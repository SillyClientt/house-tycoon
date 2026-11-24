--!strict
-- while building: hides the floors above the one being edited and shows which tiles are lit
local BuildViewClient = {}

local RPS = game:GetService('ReplicatedStorage')
local WKS = game:GetService('Workspace')

local BLD_CSignals = require(script.Parent.BuildClientSignals)
local HSE_CSignals = require(RPS.Modules.Services.HouseService.HouseClientSignals)
local HSE_Client = require(RPS.Modules.Services.HouseService.HouseServiceClient)
local PLT_Client = require(RPS.Modules.Services.PlotService.PlotServiceClient)
local BLD_CONFIGS = require(RPS.Modules.Configs.BuildConfigs)
local LND_CONFIGS = require(RPS.Modules.Configs.LandConfigs)
local DAT_Client = require(RPS.Modules.Packages.DataService).client
local GRD_UTILS = require(RPS.Modules.Utils.GridUtils)

local LIT_COLOR = Color3.fromRGB(255, 220, 90)
local DARK_COLOR = Color3.fromRGB(30, 40, 90)

local active = false
local level = 1
local lightView = true

local overlay: Folder
local grid: Folder
local hiddenParts: {[BasePart]: boolean} = {}
local landConnection: RBXScriptConnection?

-- the floor number a part is on (from its Lx folder)
local function getPartLevel(Part: Instance, Land: Folder): number?
	local current: Instance? = Part

	while current and current.Parent ~= Land do
		current = current.Parent
	end

	if not current then
		return nil
	end

	return tonumber(string.match(current.Name, '^L(%d+)$'))
end

-- folders whose parts go see-through on the floor being edited (so you can see inside rooms)
local SEE_THROUGH: {[string]: boolean} = {Walls = true, Posts = true}
local WALL_FADE = 0.65

-- hide a part above the floor being edited, fade the walls on it
local function checkPart(Part: Instance, Land: Folder)
	if not Part:IsA('BasePart') or not active then
		return
	end

	local partLevel = getPartLevel(Part, Land)

	if not partLevel then
		return
	end

	if partLevel > level then
		Part.LocalTransparencyModifier = 1
		hiddenParts[Part] = true
	elseif partLevel == level then
		local kind = Part:FindFirstAncestorWhichIsA('Folder')

		-- the piece folder (Walls / Posts) sits right under the level folder
		while kind and kind.Parent and kind.Parent.Parent ~= Land do
			kind = kind.Parent:FindFirstAncestorWhichIsA('Folder')
		end

		if kind and SEE_THROUGH[kind.Name] then
			Part.LocalTransparencyModifier = WALL_FADE
			hiddenParts[Part] = true
		end
	end
end

-- show everything again, then hide the floors above
local function refreshHidden()
	for part in hiddenParts do
		part.LocalTransparencyModifier = 0
	end

	hiddenParts = {}

	local land = PLT_Client:GetLandFolder()

	if not land or not active then
		return
	end

	for current = level, LND_CONFIGS.MaxLevels do
		local levelFolder = land:FindFirstChild(`L{current}`)

		if levelFolder then
			for _, descendant in levelFolder:GetDescendants() do
				checkPart(descendant, land)
			end
		end
	end
end

-- draw lit / dark tiles for the rooms on the floor being edited
local function refreshOverlay()
	overlay:ClearAllChildren()

	local origin = PLT_Client:GetOrigin()

	if not active or not lightView or not origin then
		return
	end

	local size = BLD_CONFIGS.CellSize
	local height = BLD_CONFIGS.FloorThickness + 0.06

	for _, house in HSE_Client:GetHouses() do
		for _, room in house.Rooms do
			if room.Level ~= level then
				continue
			end

			for _, cell in room.Cells do
				local x, z = GRD_UTILS.ParseCellKey(cell)
				local lit = room.LitCells[cell] == true

				local tile = Instance.new('Part')
				tile.Name = cell
				tile.Anchored = true
				tile.CanCollide = false
				tile.CanQuery = false
				tile.CanTouch = false
				tile.CastShadow = false
				tile.Material = Enum.Material.SmoothPlastic
				tile.Color = if lit then LIT_COLOR else DARK_COLOR
				tile.Transparency = if lit then 0.75 else 0.45
				tile.Size = Vector3.new(size - 0.3, 0.05, size - 0.3)
				tile.CFrame = CFrame.new(GRD_UTILS.CellToWorld(origin, x, z, level) + Vector3.new(0, height, 0))
				tile.Parent = overlay
			end
		end
	end
end

-- draw grid lines over every owned parcel on the floor being edited
local function refreshGrid()
	grid:ClearAllChildren()

	local origin = PLT_Client:GetOrigin()

	if not active or not origin then
		return
	end

	local cell = BLD_CONFIGS.CellSize
	local parcelCells = LND_CONFIGS.ParcelCells
	local parcelStuds = parcelCells * cell
	local height = GRD_UTILS.LevelHeight(level) + (if level == 1 then 0.08 else BLD_CONFIGS.FloorThickness + 0.04)

	-- add one thin line
	local function line(Center: Vector3, Size: Vector3, Edge: boolean)
		local part = Instance.new('Part')
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		part.Color = if Edge then Color3.fromRGB(120, 200, 255) else Color3.new(1, 1, 1)
		part.Transparency = if Edge then 0.2 else 0.65
		part.Size = Size
		part.CFrame = CFrame.new(Center)
		part.Parent = grid
	end

	for key, owned in DAT_Client:get('Parcels') do
		if not owned then
			continue
		end

		local px, pz = GRD_UTILS.ParseCellKey(key)
		local corner = origin + Vector3.new(px * parcelStuds, height, pz * parcelStuds)

		for index = 0, parcelCells do
			local edge = index == 0 or index == parcelCells
			local width = if edge then 0.25 else 0.1

			line(corner + Vector3.new(index * cell, 0, parcelStuds / 2), Vector3.new(width, 0.05, parcelStuds), edge)
			line(corner + Vector3.new(parcelStuds / 2, 0, index * cell), Vector3.new(parcelStuds, 0.05, width), edge)
		end
	end
end

-- refresh every view
local function refresh()
	refreshHidden()
	refreshOverlay()
	refreshGrid()
end

-- watch the land for new pieces on hidden floors
local function watchLand()
	if landConnection then
		return
	end

	local land = PLT_Client:GetLandFolder()

	if land then
		landConnection = land.DescendantAdded:Connect(function(Descendant)
			checkPart(Descendant, land)
		end)
	end
end

-- turn the lighting heatmap on / off
function BuildViewClient:SetLightView(Enabled: boolean)
	lightView = Enabled
	refreshOverlay()
end

function BuildViewClient:IsLightView(): boolean
	return lightView
end

-- initialize build view client-side
function BuildViewClient:Init()
	overlay = Instance.new('Folder')
	overlay.Name = 'LightOverlay'
	overlay.Parent = WKS

	grid = Instance.new('Folder')
	grid.Name = 'BuildGrid'
	grid.Parent = WKS

	BLD_CSignals.ModeChanged:Connect(function(Mode)
		active = Mode ~= 'None'
		watchLand()
		refresh()
	end)

	BLD_CSignals.LevelChanged:Connect(function(Level)
		level = Level
		refresh()
	end)

	HSE_CSignals.HousesChanged:Connect(function()
		refreshOverlay()
	end)

	task.spawn(function()
		DAT_Client:waitForData()
		DAT_Client:getChangedSignal('Parcels'):Connect(refreshGrid)
	end)
end

return BuildViewClient
