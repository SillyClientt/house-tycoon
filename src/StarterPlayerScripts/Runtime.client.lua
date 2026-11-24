--!strict
local RPS = game:GetService('ReplicatedStorage')

local DAT_Client = require(RPS.Modules.Packages.DataService).client

task.spawn(function()
	DAT_Client:init()
end)

local function safeRequire(Module: ModuleScript)
	local success, result = pcall(function()
		(require(Module) :: {Init: (self: any) -> ()}):Init()
	end)

	if not success then
		warn(`Failed to require {Module.Name}: {result}`)
	end
end

local services = RPS.Modules.Services

safeRequire(services.PlotService.PlotServiceClient)
safeRequire(services.MarketService.MarketServiceClient)
safeRequire(services.HouseService.HouseServiceClient)
safeRequire(services.MonetizationService.MonetizationServiceClient)
safeRequire(services.CleaningService.CleaningServiceClient)
safeRequire(services.BuildService.BuildServiceClient)
safeRequire(services.BuildService.BuildViewClient)
safeRequire(services.BuildService.BuildCameraClient)
safeRequire(services.FurnitureService.FurnitureServiceClient)
safeRequire(services.Interface)
