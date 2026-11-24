--!strict
-- remembers each player's last build actions so they can be undone (Ctrl+Z)
local BuildHistory = {}

local PLS = game:GetService('Players')
local RPS = game:GetService('ReplicatedStorage')

local BLD_CONFIGS = require(RPS.Modules.Configs.BuildConfigs)

export type Change = {
	Kind: string, -- 'Wall' | 'Floor' | 'Furniture'
	Level: number, -- unused for furniture (the item data has its own Level)
	Key: string, -- edge key, cell key or furniture id
	Before: any, -- data before the action (nil = nothing was there)
	After: any,
}

export type Action = {
	Changes: {Change},
	Spent: number, -- cash the action cost (negative when it paid the player back)
}

local stacks: {[Player]: {Action}} = {}

PLS.PlayerRemoving:Connect(function(Player)
	stacks[Player] = nil
end)

-- save an action
function BuildHistory.Record(Player: Player, Changes: {Change}, Spent: number)
	if #Changes == 0 then
		return
	end

	local stack = stacks[Player] or {}
	stacks[Player] = stack

	table.insert(stack, {Changes = Changes, Spent = Spent})

	while #stack > BLD_CONFIGS.UndoSteps do
		table.remove(stack, 1)
	end
end

-- take the last action off the stack
function BuildHistory.Pop(Player: Player): Action?
	local stack = stacks[Player]

	return stack and table.remove(stack)
end

-- put an action back (used when an undo can't happen)
function BuildHistory.Push(Player: Player, Action: Action)
	local stack = stacks[Player] or {}
	stacks[Player] = stack

	table.insert(stack, Action)
end

-- forget everything (used when the land is swapped, e.g. a house was sold)
function BuildHistory.Clear(Player: Player)
	stacks[Player] = nil
end

return BuildHistory
