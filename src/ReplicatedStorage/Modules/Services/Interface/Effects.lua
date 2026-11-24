--!strict
-- bouncy buttons and panels that pop open, for every button / panel in the HUD
local Effects = {}

local PLS = game:GetService('Players')
local TWS = game:GetService('TweenService')

local plr = PLS.LocalPlayer :: Player
local hud = plr:WaitForChild('PlayerGui'):WaitForChild('HUD')

local HOVER_SCALE = 1.06
local PRESS_SCALE = 0.92
local QUICK = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local POP = TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

-- panels that pop when they open
local PANELS = {'HousesPanel', 'LandPanel', 'ShopPanel', 'Selection', 'BuildBar'}

local hooked: {[GuiButton]: boolean} = setmetatable({}, {__mode = 'k'}) :: any

-- get (or add) the UIScale on a gui object
local function getScale(Object: GuiObject): UIScale
	local scale = Object:FindFirstChildOfClass('UIScale')

	if not scale then
		local newScale = Instance.new('UIScale')
		newScale.Parent = Object
		scale = newScale
	end

	return scale :: UIScale
end

-- tween a scale to a size
local function scaleTo(Scale: UIScale, Size: number, Info: TweenInfo?)
	TWS:Create(Scale, Info or QUICK, {Scale = Size}):Play()
end

-- make a button grow on hover and squish when pressed
local function hookButton(Button: GuiButton)
	if hooked[Button] then
		return
	end

	hooked[Button] = true

	local scale = getScale(Button)
	scale.Scale = 1

	Button.MouseEnter:Connect(function()
		scaleTo(scale, HOVER_SCALE)
	end)

	Button.MouseLeave:Connect(function()
		scaleTo(scale, 1)
	end)

	Button.MouseButton1Down:Connect(function()
		scaleTo(scale, PRESS_SCALE)
	end)

	Button.MouseButton1Up:Connect(function()
		scaleTo(scale, HOVER_SCALE, POP)
	end)
end

-- make a panel pop in every time it becomes visible
local function hookPanel(Panel: GuiObject)
	local scale = getScale(Panel)

	Panel:GetPropertyChangedSignal('Visible'):Connect(function()
		if Panel.Visible then
			scale.Scale = 0.8
			scaleTo(scale, 1, POP)
		end
	end)
end

-- initialize effects
function Effects:Init()
	for _, descendant in hud:GetDescendants() do
		if descendant:IsA('GuiButton') then
			hookButton(descendant)
		end
	end

	hud.DescendantAdded:Connect(function(Descendant)
		if Descendant:IsA('GuiButton') then
			hookButton(Descendant)
		end
	end)

	for _, name in PANELS do
		local panel = hud:FindFirstChild(name)

		if panel and panel:IsA('GuiObject') then
			hookPanel(panel)
		end
	end
end

return Effects
