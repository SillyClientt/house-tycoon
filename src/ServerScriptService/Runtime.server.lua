--!strict
local SSG = game:GetService('ServerStorage')

local services = SSG.Modules.Services

-- data has to start first, everything else reads it
require(services.PlayerService.PlayerServiceServer):Init()

require(services.AnalyticsService.AnalyticsServiceServer):Init()
require(services.EconomyService.EconomyServiceServer):Init()
require(services.HouseService.HouseServiceServer):Init()
require(services.PlotService.PlotServiceServer):Init()
require(services.MapService.MapServiceServer):Init()
require(services.BuildService.BuildServiceServer):Init()
require(services.FurnitureService.FurnitureServiceServer):Init()
require(services.MarketService.MarketServiceServer):Init()
require(services.CleaningService.CleaningServiceServer):Init()
require(services.MonetizationService.MonetizationServiceServer):Init()
require(services.TenantService.TenantServiceServer):Init()
