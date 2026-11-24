--!strict
local PlotServiceClient = {}

local PLS = game:GetService('Players')
local RPS = game:GetService('ReplicatedStorage')
local WKS = game:GetService('Workspace')

local DAT_Client = require(RPS.Modules.Packages.DataService).client
local GRD_UTILS = require(RPS.Modules.Utils.GridUtils)
local FUR_UTILS = require(RPS.Modules.Utils.FurnitureUtils)

local plr = PLS.LocalPlayer
local remotes = RPS.Remotes.PlotService

local dataReady = false

-- initialize plot service client-side
function PlotServiceClient:Init()
	task.spawn(function()
		DAT_Client:waitForData()
		dataReady = true
	end)
end

-- check data, land and rendered pieces have all loaded
function PlotServiceClient:IsReady(): boolean
	return dataReady and PlotServiceClient:GetPlot() ~= nil and PlotServiceClient:GetLandFolder() ~= nil
end

-- get the local player's land part
function PlotServiceClient:GetPlot(): BasePart?
	local name = plr:GetAttribute('Plot')
	local plots = WKS:FindFirstChild('Plot')
	local plot = typeof(name) == 'string' and plots and plots:FindFirstChild(name)

	if plot and plot:IsA('BasePart') then
		return plot
	end

	return nil
end

-- get the world position of the build grid corner
function PlotServiceClient:GetOrigin(): Vector3?
	local plot = PlotServiceClient:GetPlot()

	return plot and GRD_UTILS.GetOrigin(plot)
end

-- get the folder the server renders the land into
function PlotServiceClient:GetLandFolder(): Folder?
	local houses = WKS:FindFirstChild('Houses')
	local folder = houses and houses:FindFirstChild(`Land_{plr.UserId}`)

	if folder and folder:IsA('Folder') then
		return folder
	end

	return nil
end

-- get the folder of one kind of piece on one floor
function PlotServiceClient:GetPieceFolder(Level: number, Kind: string): Folder?
	local land = PlotServiceClient:GetLandFolder()
	local level = land and land:FindFirstChild(`L{Level}`)
	local folder = level and level:FindFirstChild(Kind)

	return if folder and folder:IsA('Folder') then folder else nil
end

-- what the player may build on
function PlotServiceClient:GetContext(): FUR_UTILS.PlaceContext
	return {
		Parcels = DAT_Client:get('Parcels'),
		Levels = DAT_Client:get('Levels'),
	}
end

-- buy a parcel with cash
function PlotServiceClient:BuyParcel(Key: string)
	remotes.BuyParcel:FireServer(Key)
end

-- unlock the next floor
function PlotServiceClient:UnlockLevel()
	remotes.UnlockLevel:FireServer()
end

return PlotServiceClient
