--!strict
-- top-down camera while building: WASD / arrows pan, scroll zooms, Q / E or right-drag rotates
local BuildCameraClient = {}

local PLS = game:GetService('Players')
local RPS = game:GetService('ReplicatedStorage')
local WKS = game:GetService('Workspace')
local UIS = game:GetService('UserInputService')
local RNS = game:GetService('RunService')

local BLD_CSignals = require(script.Parent.BuildClientSignals)
local PLT_Client = require(RPS.Modules.Services.PlotService.PlotServiceClient)
local GRD_UTILS = require(RPS.Modules.Utils.GridUtils)

local plr = PLS.LocalPlayer

local MIN_DISTANCE, MAX_DISTANCE = 25, 260
local MIN_PITCH, MAX_PITCH = math.rad(30), math.rad(85)
local PAN_SPEED = 1.1 -- studs per frame per 50 studs of zoom
local ROTATE_SPEED = math.rad(1.6)
local MOUSE_ROTATE = 0.005

local active = false
local level = 1
local focus = Vector3.zero
local yaw = 0
local pitch = math.rad(55)
local distance = 90
local rotating = false

-- the default character controls (walking is turned off while building)
local function getControls(): any?
	local playerScripts = plr:FindFirstChild('PlayerScripts')
	local module = playerScripts and playerScripts:FindFirstChild('PlayerModule')

	if not module or not module:IsA('ModuleScript') then
		return nil
	end

	local success, controls = pcall(function()
		return (require(module) :: any):GetControls()
	end)

	return if success then controls else nil
end

-- keep the focus point on the land
local function clampFocus()
	local origin = PLT_Client:GetOrigin()

	if not origin then
		return
	end

	local size = GRD_UTILS.LandStuds

	focus = Vector3.new(
		math.clamp(focus.X, origin.X - 20, origin.X + size + 20),
		origin.Y + GRD_UTILS.LevelHeight(level),
		math.clamp(focus.Z, origin.Z - 20, origin.Z + size + 20)
	)
end

-- start the build camera above the player
local function enter()
	local camera = WKS.CurrentCamera
	local character = plr.Character
	local root = character and character:FindFirstChild('HumanoidRootPart')

	focus = if root and root:IsA('BasePart') then root.Position else camera.Focus.Position

	-- face the same way the normal camera was facing
	local look = camera.CFrame.LookVector
	yaw = math.atan2(-look.X, -look.Z)

	clampFocus()

	camera.CameraType = Enum.CameraType.Scriptable

	local controls = getControls()

	if controls then
		controls:Disable()
	end
end

-- give the camera and walking back
local function exit()
	local camera = WKS.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom

	UIS.MouseBehavior = Enum.MouseBehavior.Default
	rotating = false

	local controls = getControls()

	if controls then
		controls:Enable()
	end
end

-- move the camera every frame
local function update(DT: number)
	if not active then
		return
	end

	local scale = DT * 60
	local move = Vector3.zero

	if not UIS:GetFocusedTextBox() then
		if UIS:IsKeyDown(Enum.KeyCode.W) or UIS:IsKeyDown(Enum.KeyCode.Up) then move += Vector3.new(0, 0, -1) end
		if UIS:IsKeyDown(Enum.KeyCode.S) or UIS:IsKeyDown(Enum.KeyCode.Down) then move += Vector3.new(0, 0, 1) end
		if UIS:IsKeyDown(Enum.KeyCode.A) or UIS:IsKeyDown(Enum.KeyCode.Left) then move += Vector3.new(-1, 0, 0) end
		if UIS:IsKeyDown(Enum.KeyCode.D) or UIS:IsKeyDown(Enum.KeyCode.Right) then move += Vector3.new(1, 0, 0) end
		if UIS:IsKeyDown(Enum.KeyCode.Q) then yaw += ROTATE_SPEED * scale end
		if UIS:IsKeyDown(Enum.KeyCode.E) then yaw -= ROTATE_SPEED * scale end
	end

	if move.Magnitude > 0 then
		local direction = CFrame.Angles(0, yaw, 0):VectorToWorldSpace(move.Unit)
		focus += direction * PAN_SPEED * (distance / 50) * scale
	end

	clampFocus()

	local offset = CFrame.Angles(0, yaw, 0) * CFrame.Angles(-pitch, 0, 0) * Vector3.new(0, 0, distance)

	WKS.CurrentCamera.CFrame = CFrame.lookAt(focus + offset, focus)
end

-- jump the camera to a world position (e.g. a house from the Houses panel)
function BuildCameraClient:FocusOn(Position: Vector3)
	focus = Position
	clampFocus()
end

-- initialize build camera client-side
function BuildCameraClient:Init()
	BLD_CSignals.ModeChanged:Connect(function(Mode)
		local wasActive = active
		active = Mode ~= 'None'

		if active and not wasActive then
			enter()
		elseif wasActive and not active then
			exit()
		end
	end)

	BLD_CSignals.LevelChanged:Connect(function(Level)
		level = Level
		clampFocus()
	end)

	UIS.InputBegan:Connect(function(Input, Processed)
		if active and not Processed and Input.UserInputType == Enum.UserInputType.MouseButton2 then
			rotating = true
			UIS.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
		end
	end)

	UIS.InputEnded:Connect(function(Input)
		if Input.UserInputType == Enum.UserInputType.MouseButton2 and rotating then
			rotating = false
			UIS.MouseBehavior = Enum.MouseBehavior.Default
		end
	end)

	UIS.InputChanged:Connect(function(Input, Processed)
		if not active then
			return
		end

		if Input.UserInputType == Enum.UserInputType.MouseWheel and not Processed then
			distance = math.clamp(distance * (1 - Input.Position.Z * 0.12), MIN_DISTANCE, MAX_DISTANCE)
		elseif Input.UserInputType == Enum.UserInputType.MouseMovement and rotating then
			yaw -= Input.Delta.X * MOUSE_ROTATE
			pitch = math.clamp(pitch + Input.Delta.Y * MOUSE_ROTATE, MIN_PITCH, MAX_PITCH)
		end
	end)

	RNS:BindToRenderStep('BuildCamera', Enum.RenderPriority.Camera.Value + 1, update)
end

return BuildCameraClient
