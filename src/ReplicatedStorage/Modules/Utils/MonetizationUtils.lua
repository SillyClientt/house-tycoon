--!strict
-- shared gamepass checks (the server stores owned passes as player attributes)
local MonetizationUtils = {}

-- attribute name for a gamepass
function MonetizationUtils.PassAttribute(Name: string): string
	return `Pass_{Name}`
end

-- check a player owns a gamepass (works on server and client)
function MonetizationUtils.HasPass(Player: Player, Name: string): boolean
	return Player:GetAttribute(MonetizationUtils.PassAttribute(Name)) == true
end

return MonetizationUtils
