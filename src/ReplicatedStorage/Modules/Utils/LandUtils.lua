--!strict
local LandUtils = {}

local RPS = game:GetService('ReplicatedStorage')

local LND_CONFIGS = require(RPS.Modules.Configs.LandConfigs)
local GRD_UTILS = require(RPS.Modules.Utils.GridUtils)
local CFG_TYPES = require(RPS.Modules.Types.ConfigTypes)

-- how many parcels are owned
function LandUtils.CountParcels(Parcels: {[string]: boolean}): number
	local count = 0

	for _, owned in Parcels do
		if owned then
			count += 1
		end
	end

	return count
end

-- cash price of the next parcel (nil when every parcel is owned)
function LandUtils.GetNextPrice(Parcels: {[string]: boolean}): number?
	return LND_CONFIGS.ParcelPrices[LandUtils.CountParcels(Parcels)]
end

-- Robux product tier for the next parcel
function LandUtils.GetParcelTier(Parcels: {[string]: boolean}): CFG_TYPES.ParcelTierConfig?
	local owned = LandUtils.CountParcels(Parcels)

	for _, tier in LND_CONFIGS.ParcelTiers do
		if owned <= tier.MaxOwned then
			return tier
		end
	end

	return nil
end

-- check a parcel key is on the land
function LandUtils.IsParcelInside(Key: string): boolean
	local parts = string.split(Key, '_')
	local x, z = tonumber(parts[1]), tonumber(parts[2])
	local size = LND_CONFIGS.ParcelGrid

	return #parts == 2 and x ~= nil and z ~= nil and x % 1 == 0 and z % 1 == 0
		and x >= 0 and z >= 0 and x < size and z < size
end

-- a parcel can be bought when it is free and touches one you own
function LandUtils.CanBuyParcel(Parcels: {[string]: boolean}, Key: string): boolean
	if not LandUtils.IsParcelInside(Key) or Parcels[Key] then
		return false
	end

	local x, z = GRD_UTILS.ParseCellKey(Key)

	for _, offset in {{1, 0}, {-1, 0}, {0, 1}, {0, -1}} do
		if Parcels[GRD_UTILS.CellKey(x + offset[1], z + offset[2])] then
			return true
		end
	end

	return false
end

-- first parcel that can be bought (used when a Robux purchase has no parcel picked)
function LandUtils.GetFirstBuyable(Parcels: {[string]: boolean}): string?
	for x = 0, LND_CONFIGS.ParcelGrid - 1 do
		for z = LND_CONFIGS.ParcelGrid - 1, 0, -1 do
			local key = GRD_UTILS.CellKey(x, z)

			if LandUtils.CanBuyParcel(Parcels, key) then
				return key
			end
		end
	end

	return nil
end

-- check a cell is on owned land
function LandUtils.IsCellOwned(Parcels: {[string]: boolean}, Cell: string): boolean
	return GRD_UTILS.IsCellInside(Cell) and Parcels[GRD_UTILS.CellParcel(Cell)] == true
end

-- a wall can go on an edge when the tile on either side is owned
function LandUtils.IsEdgeOwned(Parcels: {[string]: boolean}, Edge: string): boolean
	if not GRD_UTILS.IsEdgeInside(Edge) then
		return false
	end

	local a, b = GRD_UTILS.EdgeCells(Edge)

	return LandUtils.IsCellOwned(Parcels, a) or LandUtils.IsCellOwned(Parcels, b)
end

return LandUtils
