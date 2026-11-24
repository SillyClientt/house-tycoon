--!strict
local Interface = {}

-- initialize interface
function Interface:Init()
	for _, child in script:GetChildren() do
		if child:IsA('ModuleScript') then
			task.spawn(function()
				(require(child) :: {Init: (self: any) -> ()}):Init()
			end)
		end
	end
end

return Interface
