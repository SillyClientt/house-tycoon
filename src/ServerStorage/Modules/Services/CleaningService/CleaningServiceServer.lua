--!strict
local CleaningServiceServer = {}

local PLS = game:GetService('Players')
local RPS = game:GetService('ReplicatedStorage')
local SSG = game:GetService('ServerStorage')
local HTP = game:GetService('HttpService')
local PPS = game:GetService('ProximityPromptService')

local DAT_Server = require(RPS.Modules.Packages.DataService).server
local MKT_CONFIGS = require(RPS.Modules.Configs.MarketConfigs)
local MON_CONFIGS = require(RPS.Modules.Configs.MonetizationConfigs)
local GRD_UTILS = require(RPS.Modules.Utils.GridUtils)
local HSE_UTILS = require(RPS.Modules.Utils.HouseUtils)
local MON_UTILS = require(RPS.Modules.Utils.MonetizationUtils)
local DAT_TYPES = require(RPS.Modules.Types.DataTypes)
local CFG_TYPES = require(RPS.Modules.Types.ConfigTypes)
local HSE_Server = require(SSG.Modules.Services.HouseService.HouseServiceServer)
local ATC_SSignals = require(SSG.Modules.Services.AnalyticsService.AnalyticsServerSignals)

local DIRT_KINDS: {CFG_TYPES.DirtKind} = {'Dust', 'Stain', 'Trash'}

local random = Random.new()

-- seconds since each house last got dirty: [player][house id]
local timers: {[Player]: {[string]: number}} = {}
local autoCleanTimers: {[Player]: number} = {}

-- initialize cleaning service server-side
function CleaningServiceServer:Init()
	PPS.PromptTriggered:Connect(function(Prompt, Player)
		CleaningServiceServer:OnPrompt(Prompt, Player)
	end)

	PLS.PlayerRemoving:Connect(function(Player)
		timers[Player] = nil
		autoCleanTimers[Player] = nil
	end)

	task.spawn(function()
		while true do
			local waited = task.wait(MKT_CONFIGS.DirtTick)

			for _, player in PLS:GetPlayers() do
				if HSE_Server:IsReady(player) then
					CleaningServiceServer:Tick(player, waited)
				end
			end
		end
	end)
end

-- dirt builds up in every house over time
function CleaningServiceServer:Tick(Player: Player, DT: number)
	local houses = HSE_Server:GetHouses(Player)
	local rentals = DAT_Server:get(Player, 'Rentals')
	local playerTimers = timers[Player] or {}
	local seen: {[string]: number} = {}

	timers[Player] = playerTimers

	for _, house in houses do
		local interval = if rentals[house.Id] then MKT_CONFIGS.DirtInterval.Rented else MKT_CONFIGS.DirtInterval.Other
		local elapsed = (playerTimers[house.Id] or 0) + DT

		if elapsed >= interval then
			elapsed = 0

			if house.DirtCount < HSE_UTILS.GetMaxDirt(house.CellCount) then
				CleaningServiceServer:SpawnDirt(Player, house)
			end
		end

		seen[house.Id] = elapsed
	end

	-- forget houses that no longer exist
	timers[Player] = seen

	-- Auto Cleaner gamepass
	if MON_UTILS.HasPass(Player, 'AutoCleaner') then
		local autoElapsed = (autoCleanTimers[Player] or 0) + DT

		if autoElapsed >= MON_CONFIGS.AutoCleanInterval then
			autoElapsed = 0

			local id = next(HSE_Server:GetLand(Player).Dirt)

			if id then
				CleaningServiceServer:CleanDirt(Player, id)
			end
		end

		autoCleanTimers[Player] = autoElapsed
	end
end

-- put a dirt spot on a random clean floor tile of a house
function CleaningServiceServer:SpawnDirt(Player: Player, House: DAT_TYPES.HouseInfo)
	local land = HSE_Server:GetLand(Player)
	local dirty: {[string]: boolean} = {}

	for _, dirt in land.Dirt do
		dirty[GRD_UTILS.LevelCell(dirt.Level, dirt.Cell)] = true
	end

	local options: {string} = {}

	for levelCell in House.Cells do
		local level, cell = GRD_UTILS.ParseLevelCell(levelCell)

		if not dirty[levelCell] and HSE_UTILS.GetLevel(land, level).Floors[cell] then
			table.insert(options, levelCell)
		end
	end

	if #options == 0 then
		return
	end

	local level, cell = GRD_UTILS.ParseLevelCell(options[random:NextInteger(1, #options)])
	local id = HTP:GenerateGUID(false)
	local dirt: DAT_TYPES.DirtData = {
		Level = level,
		Cell = cell,
		Kind = DIRT_KINDS[random:NextInteger(1, #DIRT_KINDS)],
	}

	DAT_Server:set(Player, {'Land', 'Dirt', id}, dirt)
	HSE_Server:RenderDirt(Player, id)
end

-- remove a dirt spot
function CleaningServiceServer:CleanDirt(Player: Player, Id: string)
	if not HSE_Server:GetLand(Player).Dirt[Id] then
		return
	end

	DAT_Server:set(Player, {'Land', 'Dirt', Id}, nil)
	HSE_Server:RenderDirt(Player, Id)

	DAT_Server:update(Player, {'Stats', 'DirtCleaned'}, function(Old)
		return Old + 1
	end)

	ATC_SSignals.LogJourney:Fire(Player, 'CleanedDirt')
end

-- a player held the Clean prompt on a dirt spot
function CleaningServiceServer:OnPrompt(Prompt: ProximityPrompt, Player: Player)
	if Prompt.Name ~= 'CleanPrompt' then
		return
	end

	local spot = Prompt.Parent
	local landFolder = HSE_Server:GetLandFolder(Player)

	-- only the owner can clean their own houses
	if not spot or not landFolder or not spot:IsDescendantOf(landFolder) then
		return
	end

	CleaningServiceServer:CleanDirt(Player, spot.Name)
end

return CleaningServiceServer
