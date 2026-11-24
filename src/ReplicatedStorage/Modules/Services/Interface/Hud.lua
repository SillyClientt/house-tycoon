--!strict
local Hud = {}

local PLS = game:GetService('Players')
local RPS = game:GetService('ReplicatedStorage')
local TWS = game:GetService('TweenService')

local DAT_Client = require(RPS.Modules.Packages.DataService).client
local HSE_CSignals = require(RPS.Modules.Services.HouseService.HouseClientSignals)
local STR_UTILS = require(RPS.Modules.Utils.StringUtils)
local INT_UTILS = require(RPS.Modules.Utils.InterfaceUtils)

local plr = PLS.LocalPlayer :: Player
local hud = plr:WaitForChild('PlayerGui'):WaitForChild('HUD')
local topBar = INT_UTILS.Get(hud, 'TopBar', 'Frame')

local cashLabel = INT_UTILS.Get(INT_UTILS.Get(topBar, 'Cash', 'Frame'), 'Amount', 'TextLabel') :: TextLabel
local valueLabel = INT_UTILS.Get(INT_UTILS.Get(topBar, 'Value', 'Frame'), 'Amount', 'TextLabel') :: TextLabel

local shownCash = Instance.new('NumberValue')
local cashTween: Tween?

-- count the cash label up / down to the new amount
local function updateCash()
	if cashTween then
		cashTween:Cancel()
	end

	local tween = TWS:Create(shownCash, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {Value = DAT_Client:get('Cash')})
	cashTween = tween
	tween:Play()
end

-- initialize hud ui
function Hud:Init()
	DAT_Client:waitForData()

	shownCash.Changed:Connect(function(Value)
		cashLabel.Text = `\u{1F4B5} {STR_UTILS.FormatCash(math.floor(Value + 0.5))}`
	end)

	DAT_Client:getChangedSignal('Cash'):Connect(updateCash)

	-- estate value = every house added together
	HSE_CSignals.HousesChanged:Connect(function(Houses)
		local total = 0

		for _, house in Houses do
			total += house.Value
		end

		valueLabel.Text = `\u{1F3E0} Estate {STR_UTILS.FormatCash(total)}`
	end)

	updateCash()
end

return Hud
