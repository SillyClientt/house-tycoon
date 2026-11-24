--!strict
local StringUtils = {}

local SUFFIXES = {'', 'K', 'M', 'B', 'T'}

-- 1234567 -> "1,234,567"
function StringUtils.FormatNumber(Amount: number): string
	local whole = tostring(math.floor(math.abs(Amount)))
	local grouped = string.gsub(whole:reverse(), '(%d%d%d)', '%1,')
	local formatted = grouped:reverse()

	if formatted:sub(1, 1) == ',' then
		formatted = formatted:sub(2)
	end

	return if Amount < 0 then `-{formatted}` else formatted
end

-- 1234567 -> "$1,234,567"
function StringUtils.FormatCash(Amount: number): string
	return `${StringUtils.FormatNumber(Amount)}`
end

-- 1234567 -> "1.2M"
function StringUtils.GetCondensedAmount(Amount: number): string
	local value = math.abs(Amount)
	local index = 1

	while value >= 1000 and index < #SUFFIXES do
		value /= 1000
		index += 1
	end

	local text = if index == 1
		then tostring(math.floor(value))
		else (string.gsub(string.format('%.1f', math.floor(value * 10) / 10), '%.0$', ''))

	return `{if Amount < 0 then '-' else ''}{text}{SUFFIXES[index]}`
end

return StringUtils
