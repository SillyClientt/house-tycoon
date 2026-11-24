--!strict
local InterfaceUtils = {}

InterfaceUtils.Colors = {
	Button = Color3.fromRGB(118, 132, 172),
	Active = Color3.fromRGB(66, 135, 245),
	Green = Color3.fromRGB(76, 190, 92),
	Red = Color3.fromRGB(235, 84, 84),
	Gold = Color3.fromRGB(255, 196, 40),
	Ink = Color3.fromRGB(34, 38, 66),
	Money = Color3.fromRGB(120, 255, 140),
	Muted = Color3.fromRGB(112, 118, 140),
	White = Color3.new(1, 1, 1),
}

-- clone a hidden template and mark the copy so it can be cleared later
function InterfaceUtils.CloneTemplate(Template: GuiObject): GuiObject
	local clone = Template:Clone()
	clone.Visible = true
	clone:SetAttribute('Clone', true)
	clone.Parent = Template.Parent

	return clone
end

-- destroy every copy made with CloneTemplate inside a container
function InterfaceUtils.ClearClones(Container: Instance)
	for _, child in Container:GetChildren() do
		if child:GetAttribute('Clone') then
			child:Destroy()
		end
	end
end

-- show a button as picked / not picked
function InterfaceUtils.SetPicked(Button: GuiObject, Picked: boolean)
	local stroke = Button:FindFirstChildOfClass('UIStroke')

	if stroke then
		stroke.Color = if Picked then InterfaceUtils.Colors.Gold else InterfaceUtils.Colors.Ink
		stroke.Thickness = if Picked then 5 else 3
	end
end

-- find a child and make sure it is the expected class (errors early if the UI was renamed)
function InterfaceUtils.Get(Parent: Instance, Name: string, ClassName: string): Instance
	local child = Parent:WaitForChild(Name, 10)

	assert(child, `[InterfaceUtils]: Missing {Name} in {Parent:GetFullName()}`)
	assert(child:IsA(ClassName), `[InterfaceUtils]: {child:GetFullName()} should be a {ClassName}`)

	return child
end

return InterfaceUtils
