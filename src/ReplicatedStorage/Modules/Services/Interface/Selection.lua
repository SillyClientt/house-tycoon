--!strict
local Selection = {}

local PLS = game:GetService('Players')
local RPS = game:GetService('ReplicatedStorage')

local FUR_CSignals = require(RPS.Modules.Services.FurnitureService.FurnitureClientSignals)
local FUR_Client = require(RPS.Modules.Services.FurnitureService.FurnitureServiceClient)
local FUR_CONFIGS = require(RPS.Modules.Configs.FurnitureConfigs)
local BLD_CONFIGS = require(RPS.Modules.Configs.BuildConfigs)
local STR_UTILS = require(RPS.Modules.Utils.StringUtils)
local INT_UTILS = require(RPS.Modules.Utils.InterfaceUtils)

local plr = PLS.LocalPlayer :: Player
local hud = plr:WaitForChild('PlayerGui'):WaitForChild('HUD')
local panel = INT_UTILS.Get(hud, 'Selection', 'Frame') :: Frame

local title = INT_UTILS.Get(panel, 'Title', 'TextLabel') :: TextLabel
local buttons = INT_UTILS.Get(panel, 'Buttons', 'Frame')
local rotateBtn = INT_UTILS.Get(buttons, 'Rotate', 'TextButton') :: TextButton
local moveBtn = INT_UTILS.Get(buttons, 'Move', 'TextButton') :: TextButton
local removeBtn = INT_UTILS.Get(buttons, 'Remove', 'TextButton') :: TextButton

-- initialize selection ui
function Selection:Init()
	FUR_CSignals.SelectionChanged:Connect(function(Id, ItemName)
		local config = ItemName and FUR_CONFIGS.Items[ItemName]

		panel.Visible = Id ~= nil

		if config then
			title.Text = config.DisplayName
			removeBtn.Text = `\u{1F4B0} Sell {STR_UTILS.FormatCash(math.floor(config.Price * BLD_CONFIGS.RefundRate))}`
		else
			title.Text = 'Furniture'
			removeBtn.Text = '\u{1F4B0} Sell (X)'
		end
	end)

	rotateBtn.Activated:Connect(function()
		FUR_Client:RotateSelected()
	end)

	moveBtn.Activated:Connect(function()
		FUR_Client:MoveSelected()
	end)

	removeBtn.Activated:Connect(function()
		FUR_Client:RemoveSelected()
	end)
end

return Selection
