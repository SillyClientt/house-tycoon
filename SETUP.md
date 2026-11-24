# House Tycoon - setup

The full game is in `place/HouseTycoon.rbxlx`; the code in `src/` is the same code, synced with Rojo.
`tools/` has the Python scripts that generate the HUD (`make_hud2.py`) and build the place file (`rbxl_to_rbxlx.py`).

## 1. Clean the place (once, in Studio)
- Move `StarterPack.Modules` and `StarterPack.Modules (server)` to `ServerStorage.Archive` (or delete them).
- `Workspace.Plot` is rebuilt by the server every time the game starts (ground, roads and 6 lands). Anything you put in it is removed.
- The neighbourhood is centred on `LandConfigs.Neighborhood.Center` (-560, 0.1, -100), on the empty west side of the baseplate. Change `Center` to move it.
- Game Settings > Places > Max Players = **6**.
- Keep `ReplicatedStorage.Furniture`: a Model in there named like an item in `FurnitureConfigs` replaces that item's simple block shape (the existing `Chair` already does).

- `Workspace.Map` is also rebuilt on start: sidewalks, road lines, fences, street lamps, trees, the park and the town square. Tweak it in `MapConfigs` (colours, lamp spacing, tree counts, day length, day/night look). The pieces are built in `ServerStorage.Modules.Services.MapService.SceneryBuilder`.

## 2. Robux setup (Creator Hub > your game > Monetization)
Create these and paste the ids into the configs (an id of 0 shows "not set up yet" in game):

| What | Type | Config |
|---|---|---|
| 2x Rent, Auto Cleaner, VIP Furniture, Quick Sale | Gamepasses | `MonetizationConfigs.Gamepasses` |
| 4 cash packs ($10k, $50k, $250k, $1M) | Developer products | `MonetizationConfigs.CashPacks` |
| Land parcel tier 1/2/3 | Developer products | `LandConfigs.ParcelTiers` |
| Golden Bed, Jacuzzi, Grand Piano, Chandelier | Developer products | `FurnitureConfigs.Items[...].Premium` |

Everything gives a fixed result, with no luck or crates.

## 3. Sync with Rojo
`rojo serve` in this folder. Rojo owns `ReplicatedStorage.Modules`, `ReplicatedStorage.Remotes`, `ServerStorage.Modules`, both `Runtime` scripts and `StarterGui.HUD` (`src/StarterGui/HUD.rbxmx`, edit it in Studio and save it back over that file).

## 4. Testing in Studio
- Workspace attribute `Testing = true`: mock data, $1,000,000, all 3 floors and every gamepass.
- Workspace attribute `ResetData = true`: wipe your save on join.

## How the game works
| Part | Rules |
|---|---|
| Land | 4x4 parcels of 10x10 tiles. You start with 1 and buy ones next to land you own (cash or Robux) in the Land panel. |
| Floors | Up to 3. Unlock them in the Land panel, place **Stairs** (Stairs tab), then switch floor with the arrows / PgUp / PgDn. Upstairs floors need a floor below. |
| Rooms | Closed in by walls, fully floored, with a door (or stairs up into it). Key furniture sets the type: bed = Bedroom, toilet/shower/bath = Bathroom, fridge/stove = Kitchen, sofa/TV = Living Room, dining table = Dining, desk = Office, washer/dryer = Laundry. |
| Houses | Rooms joined by doors or stacked on top of each other are one house. Houses can share walls and are sold/rented separately (Houses panel). Bedroom + Bathroom are needed to sell or rent. |
| Value | Walls + floors + every furniture piece + room bonuses, x lighting, x1.25 for a complete home (bedroom, bathroom, kitchen, living room), x cleanliness. |
| Lighting | Lamps light tiles in range (ceiling light 14 studs, floor lamp 10, table lamp 7), windows light the tile next to them. Dark tiles lower the value. Build mode shows yellow (lit) / dark blue (dark) tiles. |
| Dirt | Spots appear over time (every 60s in rented houses, 180s otherwise). Each spot is -6% value and rent (down to -50%). Hold E on a spot to clean it. |
| Sell | Buyers make timed offers. Selling removes the house and frees the land. |
| Rent | The house stays on your land, locked, and earns rent (also offline, up to 3h). Collect in the Houses panel; End Lease to edit it again. |

All numbers are in `Modules/Configs` (Build, Furniture, Land, Market, Monetization).

## Where things live
| Area | Server (ServerStorage.Modules.Services) | Client (ReplicatedStorage.Modules.Services) |
|---|---|---|
| Save data, leaderstats | PlayerService | - |
| Cash | EconomyService | - |
| Neighbourhood, lands, parcels, floors | PlotService | PlotService |
| Drawing the land from data, edit locks | HouseService | HouseService (works out houses for the UI) |
| Walls / floors | BuildService | BuildService (+ BuildViewClient: hide upper floors, light heatmap) |
| Furniture | FurnitureService | FurnitureService |
| Selling / renting | MarketService | MarketService |
| Dirt | CleaningService | CleaningService |
| Robux | MonetizationService | MonetizationService |
| UI | - | Interface (one module per HUD part) |

Shared logic in `Modules/Utils`: GridUtils (grid, floors, parcels), HouseUtils (rooms, houses, lighting, value), BuildUtils (wall/floor/dirt models), FurnitureUtils (furniture models + placement rules), LandUtils (parcel rules), MonetizationUtils (gamepass checks).
