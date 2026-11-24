--!strict
local Notify = {}

local PLS = game:GetService('Players')
local RPS = game:GetService('ReplicatedStorage')
local TWS = game:GetService('TweenService')

local INT_CSignals = require(RPS.Modules.Services.InterfaceService.InterfaceClientSignals)
local STR_UTILS = require(RPS.Modules.Utils.StringUtils)
local INT_UTILS = require(RPS.Modules.Utils.InterfaceUtils)

local plr = PLS.LocalPlayer :: Player
local hud = plr:WaitForChild('PlayerGui'):WaitForChild('HUD')
local container = INT_UTILS.Get(hud, 'Notifications', 'Frame') :: Frame
local template = INT_UTILS.Get(container, 'Template', 'TextLabel') :: TextLabel

local SHOW_TIME = 3.5
local MAX_SHOWN = 5
local FADE = TweenInfo.new(0.4)

local order = 0

-- show a message at the top of the screen
function Notify:Show(Text: string, Color: Color3?)
	order += 1

	local label = INT_UTILS.CloneTemplate(template) :: TextLabel
	label.Text = Text
	label.TextColor3 = Color or INT_UTILS.Colors.White
	label.LayoutOrder = order

	-- remove the oldest when there are too many
	local shown = {}

	for _, child in container:GetChildren() do
		if child:GetAttribute('Clone') and child:IsA('GuiObject') then
			table.insert(shown, child)
		end
	end

	if #shown > MAX_SHOWN then
		table.sort(shown, function(A, B)
			return A.LayoutOrder < B.LayoutOrder
		end)

		shown[1]:Destroy()
	end

	task.delay(SHOW_TIME, function()
		if not label.Parent then
			return
		end

		local tween = TWS:Create(label, FADE, {TextTransparency = 1, BackgroundTransparency = 1})
		tween:Play()
		tween.Completed:Wait()
		label:Destroy()
	end)
end

-- initialize notification ui
function Notify:Init()
	RPS.Remotes.InterfaceService.Notify.OnClientEvent:Connect(function(Text: string, Color: Color3?)
		Notify:Show(Text, Color)
	end)

	INT_CSignals.Notify:Connect(function(Text, Color)
		Notify:Show(Text, Color)
	end)

	RPS.Remotes.EconomyService.Rewarded.OnClientEvent:Connect(function(_Currency: string, Amount: number, _New: number, Tag: string?)
		-- refunds happen a lot while erasing, the cash counter is enough for those
		if Tag == 'Refund' then
			return
		end

		Notify:Show(`+{STR_UTILS.FormatCash(Amount)}`, INT_UTILS.Colors.Money)
	end)
end

return Notify
