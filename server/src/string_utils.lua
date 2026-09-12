local log = require "log"
local string_utils = {}

function string_utils.make_display(str)
	local name = str:match(":(.+)$") or str
	name = name:gsub("_", " ")
	name = name:gsub("-.*", "")
	name = name:gsub("(%l)(%w*)", function(first, rest)
		return first:upper() .. rest
	end)
	return name
end

return string_utils