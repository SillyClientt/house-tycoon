--!strict
-- used in Studio when Workspace has the attribute Testing = true
local DEFAULT_DATA = require(script.Parent.DefaultData)

local data = table.clone(DEFAULT_DATA)
data.Cash = 1000000
data.Levels = 3

return data
