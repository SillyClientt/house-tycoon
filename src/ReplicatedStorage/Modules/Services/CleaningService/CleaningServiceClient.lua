--!strict
-- every player's dirt has a Clean prompt; only show the ones on your own land
local CleaningServiceClient = {}

local PLS = game:GetService('Players')
local WKS = game:GetService('Workspace')

local plr = PLS.LocalPlayer

-- hide a Clean prompt that isn't on the local player's land
local function checkPrompt(Prompt: Instance)
	if not Prompt:IsA('ProximityPrompt') or Prompt.Name ~= 'CleanPrompt' then
		return
	end

	-- walk up to the land folder (it has an Owner attribute)
	local current: Instance? = Prompt.Parent

	while current and current:GetAttribute('Owner') == nil do
		current = current.Parent
	end

	Prompt.Enabled = current ~= nil and current:GetAttribute('Owner') == plr.UserId
end

-- initialize cleaning service client-side
function CleaningServiceClient:Init()
	task.spawn(function()
		local houses = WKS:WaitForChild('Houses')

		houses.DescendantAdded:Connect(checkPrompt)

		for _, descendant in houses:GetDescendants() do
			checkPrompt(descendant)
		end
	end)
end

return CleaningServiceClient
