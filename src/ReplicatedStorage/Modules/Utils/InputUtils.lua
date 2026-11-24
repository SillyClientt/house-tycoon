--!strict
-- client-side helpers for working out what the mouse / finger is pointing at
local InputUtils = {}

local UIS = game:GetService('UserInputService')
local WKS = game:GetService('Workspace')

local RAY_LENGTH = 1000

-- ray from the camera through the pointer
function InputUtils.GetPointerRay(): Ray
	local camera = WKS.CurrentCamera
	local location = UIS:GetMouseLocation()

	return camera:ViewportPointToRay(location.X, location.Y)
end

-- where the pointer meets a flat plane at a height (ignores every part)
function InputUtils.HitPlane(Height: number): Vector3?
	local ray = InputUtils.GetPointerRay()

	if math.abs(ray.Direction.Y) < 1e-4 then
		return nil
	end

	local distance = (Height - ray.Origin.Y) / ray.Direction.Y

	if distance < 0 or distance > RAY_LENGTH then
		return nil
	end

	return ray.Origin + ray.Direction * distance
end

-- raycast from the pointer, only hitting the given instances
function InputUtils.RaycastInclude(Include: {Instance}): RaycastResult?
	local ray = InputUtils.GetPointerRay()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = Include

	return WKS:Raycast(ray.Origin, ray.Direction * RAY_LENGTH, params)
end

-- check an input is a click / tap
function InputUtils.IsPress(Input: InputObject): boolean
	return Input.UserInputType == Enum.UserInputType.MouseButton1
		or Input.UserInputType == Enum.UserInputType.Touch
end

return InputUtils
