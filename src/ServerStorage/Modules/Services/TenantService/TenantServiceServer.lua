--!strict
-- NPC tenants living in rented houses, and viewers walking through listed houses
local TenantServiceServer = {}

local PLS = game:GetService('Players')
local RPS = game:GetService('ReplicatedStorage')
local SSG = game:GetService('ServerStorage')
local PFS = game:GetService('PathfindingService')

local DAT_Server = require(RPS.Modules.Packages.DataService).server
local TNT_CONFIGS = require(RPS.Modules.Configs.TenantConfigs)
local MKT_CONFIGS = require(RPS.Modules.Configs.MarketConfigs)
local FUR_CONFIGS = require(RPS.Modules.Configs.FurnitureConfigs)
local BLD_CONFIGS = require(RPS.Modules.Configs.BuildConfigs)
local GRD_UTILS = require(RPS.Modules.Utils.GridUtils)
local FUR_UTILS = require(RPS.Modules.Utils.FurnitureUtils)
local DAT_TYPES = require(RPS.Modules.Types.DataTypes)
local HSE_Server = require(SSG.Modules.Services.HouseService.HouseServiceServer)
local MKT_Server = require(SSG.Modules.Services.MarketService.MarketServiceServer)

local SYNC_INTERVAL = 3
local MOVE_TIMEOUT = 4

type Npc = {
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Bubble: TextLabel,
	Tracks: {[string]: AnimationTrack},
	Alive: boolean,
}

type Group = {
	Npcs: {Npc},
	HouseId: string,
	Viewer: boolean,
}

-- a piece of furniture a tenant can use, worked out from land data
type Spot = {
	Use: TNT_CONFIGS.UseConfig,
	Position: Vector3, -- bottom centre of the item
	Facing: CFrame, -- the item's rotation
	Approach: Vector3, -- where to stand in front of it
}

local random = Random.new()

local groups: {[Player]: {[string]: Group}} = {}
local houseInfo: {[Player]: {[string]: DAT_TYPES.HouseInfo}} = {}

-- random entry from a list
local function pick<T>(List: {T}): T
	return List[random:NextInteger(1, #List)]
end

-- random number of seconds in a range
local function between(Range: {Min: number, Max: number}): number
	return random:NextNumber(Range.Min, Range.Max)
end

-- show text over an NPC's head for a few seconds (nil hides it)
local function say(Npc: Npc, Text: string?, Duration: number?)
	Npc.Bubble.Text = Text or ''
	Npc.Bubble.Visible = Text ~= nil

	if Text and Duration then
		task.delay(Duration, function()
			if Npc.Alive and Npc.Bubble.Text == Text then
				Npc.Bubble.Visible = false
			end
		end)
	end
end

-- the folder NPCs on a land live in
local function getPeopleFolder(Player: Player): Folder?
	local land = HSE_Server:GetLandFolder(Player)

	if not land then
		return nil
	end

	local folder = land:FindFirstChild('People')

	if not folder then
		local newFolder = Instance.new('Folder')
		newFolder.Name = 'People'
		newFolder.Parent = land
		folder = newFolder
	end

	return folder :: Folder
end

-- make an NPC with random colours, a name tag and a speech bubble
local function createNpc(Name: string, Parent: Instance, At: Vector3): Npc?
	local description = Instance.new('HumanoidDescription')
	local skin = pick(TNT_CONFIGS.SkinColors)

	description.HeadColor = skin
	description.LeftArmColor = skin
	description.RightArmColor = skin
	description.TorsoColor = pick(TNT_CONFIGS.ShirtColors)
	description.LeftLegColor = pick(TNT_CONFIGS.PantsColors)
	description.RightLegColor = description.LeftLegColor

	local success, model = pcall(function()
		return PLS:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)

	if not success or not model then
		warn(`[TenantServiceServer]: Couldn't make NPC: {model}`)
		return nil
	end

	local humanoid = model:FindFirstChildOfClass('Humanoid')
	local root = model:FindFirstChild('HumanoidRootPart')
	local head = model:FindFirstChild('Head')

	if not humanoid or not root or not root:IsA('BasePart') or not head then
		model:Destroy()
		return nil
	end

	local rootPart = root :: BasePart

	model.Name = Name
	humanoid.DisplayName = Name
	humanoid.NameDisplayDistance = 60
	humanoid.WalkSpeed = 10
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer

	-- the default Animate script only runs for players, so animate on the server
	local animate = model:FindFirstChild('Animate')

	if animate then
		animate:Destroy()
	end

	local animator = humanoid:FindFirstChildOfClass('Animator')

	if not animator then
		local newAnimator = Instance.new('Animator')
		newAnimator.Parent = humanoid
		animator = newAnimator
	end

	assert(animator)

	local tracks: {[string]: AnimationTrack} = {}

	for name, id in TNT_CONFIGS.Animations do
		local animation = Instance.new('Animation')
		animation.AnimationId = id

		local track = animator:LoadAnimation(animation)
		track.Looped = true
		tracks[name] = track
	end

	humanoid.Running:Connect(function(Speed)
		if rootPart.Anchored then
			return
		end

		if Speed > 0.5 then
			if not tracks.Walk.IsPlaying then
				tracks.Idle:Stop(0.2)
				tracks.Walk:Play(0.2)
			end
		elseif not tracks.Idle.IsPlaying then
			tracks.Walk:Stop(0.2)
			tracks.Idle:Play(0.2)
		end
	end)

	-- speech bubble
	local billboard = Instance.new('BillboardGui')
	billboard.Name = 'Bubble'
	billboard.Size = UDim2.fromOffset(240, 34)
	billboard.StudsOffset = Vector3.new(0, 3.6, 0)
	billboard.MaxDistance = 90
	billboard.Parent = head

	-- the bubble grows sideways to fit its text, so short lines stay small
	local bubble = Instance.new('TextLabel')
	bubble.AnchorPoint = Vector2.new(0.5, 1)
	bubble.Position = UDim2.fromScale(0.5, 1)
	bubble.Size = UDim2.fromOffset(0, 28)
	bubble.AutomaticSize = Enum.AutomaticSize.X
	bubble.BackgroundColor3 = Color3.new(1, 1, 1)
	bubble.TextColor3 = Color3.fromRGB(34, 38, 66)
	bubble.Font = Enum.Font.FredokaOne
	bubble.TextSize = 17
	bubble.Visible = false
	bubble.Parent = billboard

	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = bubble

	local stroke = Instance.new('UIStroke')
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(34, 38, 66)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = bubble

	local padding = Instance.new('UIPadding')
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = bubble

	model:PivotTo(CFrame.new(At + Vector3.new(0, 3, 0)))
	model.Parent = Parent

	pcall(function()
		rootPart:SetNetworkOwner(nil)
	end)

	tracks.Idle:Play()

	return {
		Model = model,
		Humanoid = humanoid,
		Root = rootPart,
		Bubble = bubble,
		Tracks = tracks,
		Alive = true,
	}
end

-- walk an NPC to a point using pathfinding (gives up quietly if stuck)
local function walkTo(Npc: Npc, Target: Vector3)
	if not Npc.Alive then
		return
	end

	local path = PFS:CreatePath({
		AgentRadius = 1.4,
		AgentHeight = 5,
		AgentCanJump = false,
		WaypointSpacing = 4,
	})

	local computed = pcall(function()
		path:ComputeAsync(Npc.Root.Position, Target)
	end)

	local waypoints = if computed and path.Status == Enum.PathStatus.Success then path:GetWaypoints() else {}

	if #waypoints == 0 then
		return
	end

	for _, waypoint in waypoints do
		if not Npc.Alive then
			return
		end

		local reached = false
		local connection = Npc.Humanoid.MoveToFinished:Once(function()
			reached = true
		end)

		Npc.Humanoid:MoveTo(waypoint.Position)

		local started = os.clock()

		while not reached and Npc.Alive and os.clock() - started < MOVE_TIMEOUT do
			task.wait(0.1)
		end

		connection:Disconnect()
	end
end

-- furniture in a house that tenants can use
local function getSpots(Player: Player, House: DAT_TYPES.HouseInfo): {Spot}
	local origin = HSE_Server:GetOrigin(Player)
	local spots: {Spot} = {}

	if not origin then
		return spots
	end

	for _, item in HSE_Server:GetLand(Player).Furniture do
		local use = TNT_CONFIGS.Uses[item.Name]
		local config = FUR_CONFIGS.Items[item.Name]
		local cell = GRD_UTILS.LevelCell(item.Level, GRD_UTILS.LocalToCell(item.X, item.Z))

		if not use or not config or not House.Cells[cell] then
			continue
		end

		local position = FUR_UTILS.GetWorldPosition(origin, item)
		local facing = CFrame.Angles(0, math.rad(item.Rotation), 0)
		local front = facing:VectorToWorldSpace(Vector3.new(0, 0, -1))

		table.insert(spots, {
			Use = use,
			Position = position,
			Facing = facing,
			Approach = position + front * (config.Footprint.Y / 2 + 1.8),
		})
	end

	return spots
end

-- centre of a random tile in a house (world position on its floor)
local function randomTile(Player: Player, House: DAT_TYPES.HouseInfo, GroundOnly: boolean?): Vector3?
	local origin = HSE_Server:GetOrigin(Player)
	local cells: {string} = {}

	for levelCell in House.Cells do
		local level = GRD_UTILS.ParseLevelCell(levelCell)

		if not GroundOnly or level == 1 then
			table.insert(cells, levelCell)
		end
	end

	if not origin or #cells == 0 then
		return nil
	end

	local level, cell = GRD_UTILS.ParseLevelCell(pick(cells))
	local x, z = GRD_UTILS.ParseCellKey(cell)

	return GRD_UTILS.CellToWorld(origin, x, z, level) + Vector3.new(0, BLD_CONFIGS.FloorThickness, 0)
end

-- sit / lie / stand at a piece of furniture for a while
local function useSpot(Npc: Npc, Spot: Spot)
	walkTo(Npc, Spot.Approach)

	if not Npc.Alive then
		return
	end

	local use = Spot.Use
	local height = use.Height or 0

	say(Npc, use.Icon)

	if use.Pose == 'Stand' then
		local look = Vector3.new(Spot.Position.X, Npc.Root.Position.Y, Spot.Position.Z)

		if (look - Npc.Root.Position).Magnitude > 0.1 then
			Npc.Root.CFrame = CFrame.lookAt(Npc.Root.Position, look)
		end
	else
		Npc.Root.Anchored = true
		Npc.Tracks.Walk:Stop()

		if use.Pose == 'Sit' then
			-- sit facing the front of the item
			Npc.Root.CFrame = CFrame.new(Spot.Position + Vector3.new(0, height + 1.1, 0)) * Spot.Facing
			Npc.Tracks.Idle:Stop()
			Npc.Tracks.Sit:Play(0.2)
		else
			-- lie on the back, head towards the headboard (+Z of the bed)
			Npc.Root.CFrame = CFrame.new(Spot.Position + Vector3.new(0, height, 0)) * Spot.Facing * CFrame.Angles(math.rad(90), 0, 0)
		end
	end

	task.wait(between(use.Time))

	if not Npc.Alive then
		return
	end

	say(Npc, nil)

	if Npc.Root.Anchored then
		Npc.Tracks.Sit:Stop(0.2)
		Npc.Root.CFrame = CFrame.new(Spot.Approach + Vector3.new(0, 3, 0))
		Npc.Root.Anchored = false
		Npc.Tracks.Idle:Play(0.2)
	end
end

-- how a house feels to the people in it
local function getMood(Player: Player, HouseId: string, Viewer: boolean): string?
	local house = houseInfo[Player] and houseInfo[Player][HouseId]

	if not house then
		return nil
	end

	if house.DirtCount > 0 then
		return pick(if Viewer then TNT_CONFIGS.Moods.ViewerBad else TNT_CONFIGS.Moods.Dirty)
	elseif house.LitFraction < TNT_CONFIGS.DarkLitFraction then
		return pick(if Viewer then TNT_CONFIGS.Moods.ViewerBad else TNT_CONFIGS.Moods.Dark)
	end

	return pick(if Viewer then TNT_CONFIGS.Moods.ViewerGood else TNT_CONFIGS.Moods.Happy)
end

-- a tenant's day: use furniture, wander, say how they feel
local function tenantLife(Player: Player, Npc: Npc, HouseId: string)
	local nextMood = os.clock() + between(TNT_CONFIGS.MoodInterval)

	while Npc.Alive do
		local house = houseInfo[Player] and houseInfo[Player][HouseId]

		if not house then
			task.wait(2)
			continue
		end

		local spots = getSpots(Player, house)

		if #spots > 0 and random:NextNumber() < 0.75 then
			useSpot(Npc, pick(spots))
		else
			local tile = randomTile(Player, house)

			if tile then
				walkTo(Npc, tile)
			end

			task.wait(between({Min = 2, Max = 5}))
		end

		if Npc.Alive and os.clock() >= nextMood then
			nextMood = os.clock() + between(TNT_CONFIGS.MoodInterval)
			say(Npc, getMood(Player, HouseId, false), 4)
			task.wait(4)
		end
	end
end

-- a viewer walks in from the road, looks around, walks out, and comes back again
local function viewerLife(Player: Player, Npc: Npc, HouseId: string, Entrance: Vector3)
	while Npc.Alive do
		for _ = 1, TNT_CONFIGS.ViewerStops do
			local house = houseInfo[Player] and houseInfo[Player][HouseId]
			local tile = house and randomTile(Player, house, true)

			if not Npc.Alive or not tile then
				break
			end

			walkTo(Npc, tile)
			say(Npc, getMood(Player, HouseId, true), 3)
			task.wait(between(TNT_CONFIGS.ViewerLookTime))
		end

		walkTo(Npc, Entrance)
		task.wait(between({Min = 4, Max = 8}))
	end
end

-- remove a group of NPCs
local function despawn(Group: Group)
	for _, npc in Group.Npcs do
		npc.Alive = false
		npc.Model:Destroy()
	end

	Group.Npcs = {}
end

-- how many tenants a house gets (one per bed, bunk beds count twice)
local function getTenantCount(Player: Player, House: DAT_TYPES.HouseInfo): number
	local beds = 0

	for _, item in HSE_Server:GetLand(Player).Furniture do
		local use = TNT_CONFIGS.Uses[item.Name]
		local cell = GRD_UTILS.LevelCell(item.Level, GRD_UTILS.LocalToCell(item.X, item.Z))

		if use and use.Pose == 'Sleep' and House.Cells[cell] then
			beds += if TNT_CONFIGS.BunkBeds[item.Name] then 2 else 1
		end
	end

	return math.clamp(beds, 1, TNT_CONFIGS.MaxPerHouse)
end

-- spawn the tenants (or viewers) for one house
local function spawnGroup(Player: Player, House: DAT_TYPES.HouseInfo, Viewer: boolean, Budget: number): Group?
	local folder = getPeopleFolder(Player)
	local origin = HSE_Server:GetOrigin(Player)

	if not folder or not origin or Budget <= 0 then
		return nil
	end

	local group: Group = {Npcs = {}, HouseId = House.Id, Viewer = Viewer}
	local rental: DAT_TYPES.RentalData? = DAT_Server:get(Player, {'Rentals', House.Id})

	-- viewers start on the road in front of the house
	local entrance = origin + Vector3.new(House.CenterX, BLD_CONFIGS.FloorThickness, GRD_UTILS.LandStuds + 10)

	local count = if Viewer then TNT_CONFIGS.ViewersPerHouse else getTenantCount(Player, House)
	local lastName = pick(MKT_CONFIGS.LastNames)

	for index = 1, math.min(count, Budget) do
		local name = if rental and index == 1 then rental.Tenant else `{pick(MKT_CONFIGS.FirstNames)} {lastName}`

		if Viewer then
			name = `{pick(MKT_CONFIGS.FirstNames)} (viewing)`
		end

		local start = if Viewer then entrance else randomTile(Player, House, true)

		if not start then
			continue
		end

		local npc = createNpc(name, folder, start)

		if npc then
			table.insert(group.Npcs, npc)

			task.spawn(function()
				if Viewer then
					viewerLife(Player, npc, House.Id, entrance)
				else
					tenantLife(Player, npc, House.Id)
				end
			end)
		end
	end

	return group
end

-- make the NPCs match what is rented / listed right now
function TenantServiceServer:Sync(Player: Player)
	local houses = HSE_Server:GetHouses(Player)
	local byId: {[string]: DAT_TYPES.HouseInfo} = {}

	for _, house in houses do
		byId[house.Id] = house
	end

	houseInfo[Player] = byId

	local wanted: {[string]: boolean} = {}

	for houseId in DAT_Server:get(Player, 'Rentals') do
		wanted[`R:{houseId}`] = true
	end

	for houseId in MKT_Server:GetListings(Player) do
		wanted[`V:{houseId}`] = true
	end

	local playerGroups = groups[Player] or {}
	groups[Player] = playerGroups

	local total = 0

	for key, group in playerGroups do
		if not wanted[key] or not byId[group.HouseId] then
			despawn(group)
			playerGroups[key] = nil
		else
			total += #group.Npcs
		end
	end

	for key in wanted do
		if playerGroups[key] then
			continue
		end

		local houseId = string.sub(key, 3)
		local house = byId[houseId]

		if house then
			local group = spawnGroup(Player, house, string.sub(key, 1, 1) == 'V', TNT_CONFIGS.MaxPerPlayer - total)

			if group then
				playerGroups[key] = group
				total += #group.Npcs
			end
		end
	end
end

-- initialize tenant service server-side
function TenantServiceServer:Init()
	PLS.PlayerRemoving:Connect(function(Player)
		for _, group in groups[Player] or {} do
			despawn(group)
		end

		groups[Player] = nil
		houseInfo[Player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(SYNC_INTERVAL)

			for _, player in PLS:GetPlayers() do
				if HSE_Server:IsReady(player) and DAT_Server:hasProfile(player) then
					local success, err = pcall(function()
						TenantServiceServer:Sync(player)
					end)

					if not success then
						warn(`[TenantServiceServer]: {err}`)
					end
				end
			end
		end
	end)
end

return TenantServiceServer
