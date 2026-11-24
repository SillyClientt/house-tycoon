--!strict
local FurnitureServiceServer = {}

local PLS = game:GetService('Players')
local RPS = game:GetService('ReplicatedStorage')
local SSG = game:GetService('ServerStorage')
local HTP = game:GetService('HttpService')

local DAT_Server = require(RPS.Modules.Packages.DataService).server
local FUR_CONFIGS = require(RPS.Modules.Configs.FurnitureConfigs)
local BLD_CONFIGS = require(RPS.Modules.Configs.BuildConfigs)
local FUR_UTILS = require(RPS.Modules.Utils.FurnitureUtils)
local MON_UTILS = require(RPS.Modules.Utils.MonetizationUtils)
local DAT_TYPES = require(RPS.Modules.Types.DataTypes)
local HSE_Server = require(SSG.Modules.Services.HouseService.HouseServiceServer)
local ECN_Server = require(SSG.Modules.Services.EconomyService.EconomyServiceServer)
local ATC_SSignals = require(SSG.Modules.Services.AnalyticsService.AnalyticsServerSignals)
local BLD_HISTORY = require(SSG.Modules.Services.BuildService.BuildHistory)

local remotes = RPS.Remotes.FurnitureService

local REQUEST_COOLDOWN = 0.15
local MAX_FURNITURE = 400
local RED = Color3.fromRGB(235, 80, 80)

local lastRequest: {[Player]: number} = {}

-- check request (rate limit + land loaded)
local function checkRequest(Player: Player): boolean
	local now = os.clock()

	if now - (lastRequest[Player] or 0) < REQUEST_COOLDOWN then
		return false
	end

	lastRequest[Player] = now

	return HSE_Server:IsReady(Player)
end

-- check a value is a usable plot-local position
local function isPosition(Value: any): boolean
	return typeof(Value) == 'number' and Value == Value and math.abs(Value) < 1000
end

-- check a value is a whole floor number
local function isLevel(Value: any): boolean
	return typeof(Value) == 'number' and Value == Value and Value % 1 == 0 and Value >= 1 and Value <= 10
end

-- round to 2 decimals so saved data stays small
local function round(Value: number): number
	return math.floor(Value * 100 + 0.5) / 100
end

-- tell the player why an item can't go there
local function notifyBlocked(Player: Player, Reason: string?)
	RPS.Remotes.InterfaceService.Notify:FireClient(Player, Reason or "Can't place that there", RED)
end

-- check none of the tiles an item covers belong to a locked house
local function isAreaLocked(Player: Player, Name: string, X: number, Z: number, Rotation: number): boolean
	for _, cell in FUR_UTILS.GetCoveredCells(Name, X, Z, Rotation) do
		if HSE_Server:IsColumnLocked(Player, cell) then
			return true
		end
	end

	return false
end

-- check the player may use an item (premium unlocked / VIP pass)
function FurnitureServiceServer:HasAccess(Player: Player, Name: string): boolean
	local config = FUR_CONFIGS.Items[Name]

	if not config then
		return false
	end

	if config.Premium and not DAT_Server:get(Player, {'UnlockedItems', Name}) then
		return false
	end

	if config.Vip and not MON_UTILS.HasPass(Player, 'VipFurniture') then
		return false
	end

	return true
end

-- initialize furniture service server-side
function FurnitureServiceServer:Init()
	remotes.PlaceFurniture.OnServerEvent:Connect(function(Player, Name, Level, X, Z, Rotation)
		FurnitureServiceServer:PlaceFurniture(Player, Name, Level, X, Z, Rotation)
	end)

	remotes.MoveFurniture.OnServerEvent:Connect(function(Player, Id, Level, X, Z, Rotation)
		FurnitureServiceServer:MoveFurniture(Player, Id, Level, X, Z, Rotation)
	end)

	remotes.RotateFurniture.OnServerEvent:Connect(function(Player, Id)
		FurnitureServiceServer:RotateFurniture(Player, Id)
	end)

	remotes.RemoveFurniture.OnServerEvent:Connect(function(Player, Id)
		FurnitureServiceServer:RemoveFurniture(Player, Id)
	end)

	PLS.PlayerRemoving:Connect(function(Player)
		lastRequest[Player] = nil
	end)
end

-- buy and place a new item
function FurnitureServiceServer:PlaceFurniture(Player: Player, Name: any, Level: any, X: any, Z: any, Rotation: any)
	if typeof(Name) ~= 'string' or not isLevel(Level) or not isPosition(X) or not isPosition(Z) or typeof(Rotation) ~= 'number' then
		return
	end

	local config = FUR_CONFIGS.Items[Name]

	if not config or not checkRequest(Player) then
		return
	end

	if not FurnitureServiceServer:HasAccess(Player, Name) then
		notifyBlocked(Player, if config.Vip then 'Needs the VIP Furniture pass' else 'Unlock this item in the shop first')
		return
	end

	local land = HSE_Server:GetLand(Player)
	local total = 0

	for _ in land.Furniture do
		total += 1
	end

	if total >= MAX_FURNITURE then
		notifyBlocked(Player, 'Furniture limit reached')
		return
	end

	local x, z = round(X), round(Z)

	if isAreaLocked(Player, Name, x, z, Rotation) then
		HSE_Server:NotifyLocked(Player)
		return
	end

	local canPlace, reason = FUR_UTILS.CanPlace(land, HSE_Server:GetContext(Player), Name, Level, x, z, Rotation)

	if not canPlace then
		notifyBlocked(Player, reason)
		return
	end

	if not ECN_Server:TryDeduct(Player, config.Price, 'BuyFurniture') then
		return
	end

	local id = HTP:GenerateGUID(false)
	local item: DAT_TYPES.FurnitureData = {
		Name = Name,
		Level = Level,
		X = x,
		Z = z,
		Rotation = Rotation,
	}

	DAT_Server:set(Player, {'Land', 'Furniture', id}, item)
	HSE_Server:RenderFurniture(Player, id)

	BLD_HISTORY.Record(Player, {{Kind = 'Furniture', Level = Level, Key = id, Before = nil, After = table.clone(item)}}, config.Price)

	ATC_SSignals.LogJourney:Fire(Player, 'PlacedFurniture')
end

-- move (and optionally turn) an item the player already owns
function FurnitureServiceServer:MoveFurniture(Player: Player, Id: any, Level: any, X: any, Z: any, Rotation: any)
	if typeof(Id) ~= 'string' or not isLevel(Level) or not isPosition(X) or not isPosition(Z) or typeof(Rotation) ~= 'number' then
		return
	end

	if not checkRequest(Player) then
		return
	end

	local land = HSE_Server:GetLand(Player)
	local item = land.Furniture[Id]

	if not item then
		return
	end

	local x, z = round(X), round(Z)

	-- both the old and new spot must be editable
	if isAreaLocked(Player, item.Name, item.X, item.Z, item.Rotation) or isAreaLocked(Player, item.Name, x, z, Rotation) then
		HSE_Server:NotifyLocked(Player)
		return
	end

	local canPlace, reason = FUR_UTILS.CanPlace(land, HSE_Server:GetContext(Player), item.Name, Level, x, z, Rotation, Id)

	if not canPlace then
		notifyBlocked(Player, reason)
		return
	end

	local moved = table.clone(item)
	moved.Level = Level
	moved.X = x
	moved.Z = z
	moved.Rotation = Rotation

	DAT_Server:set(Player, {'Land', 'Furniture', Id}, moved)
	HSE_Server:RenderFurniture(Player, Id)

	BLD_HISTORY.Record(Player, {{Kind = 'Furniture', Level = Level, Key = Id, Before = table.clone(item), After = table.clone(moved)}}, 0)
end

-- turn an item 90 degrees
function FurnitureServiceServer:RotateFurniture(Player: Player, Id: any)
	if typeof(Id) ~= 'string' or not HSE_Server:IsReady(Player) then
		return
	end

	local item = HSE_Server:GetLand(Player).Furniture[Id]

	if not item then
		return
	end

	FurnitureServiceServer:MoveFurniture(Player, Id, item.Level, item.X, item.Z, (item.Rotation + 90) % 360)
end

-- remove an item and refund part of its price
function FurnitureServiceServer:RemoveFurniture(Player: Player, Id: any)
	if typeof(Id) ~= 'string' or not checkRequest(Player) then
		return
	end

	local item = HSE_Server:GetLand(Player).Furniture[Id]

	if not item then
		return
	end

	if isAreaLocked(Player, item.Name, item.X, item.Z, item.Rotation) then
		HSE_Server:NotifyLocked(Player)
		return
	end

	DAT_Server:set(Player, {'Land', 'Furniture', Id}, nil)
	HSE_Server:RenderFurniture(Player, Id)

	local config = FUR_CONFIGS.Items[item.Name]
	local refund = if config then math.floor(config.Price * BLD_CONFIGS.RefundRate) else 0

	if refund > 0 then
		ECN_Server:Reward(Player, {Cash = refund}, 'Refund')
	end

	BLD_HISTORY.Record(Player, {{Kind = 'Furniture', Level = item.Level, Key = Id, Before = table.clone(item), After = nil}}, -refund)
end

return FurnitureServiceServer
