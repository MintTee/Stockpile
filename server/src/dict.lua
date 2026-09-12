-- dict.lua
-- Dictionary compression module for string <-> ID mapping with persistence.

local df = require("/stockpile_server/lib/LibDeflate")
require("/stockpile_server/var/globals")

local dict = {}
local sn = {}
local ns = {}

function dict.exists(v)
    if type(v) == "string" then
        return sn[v] ~= nil
    elseif type(v) == "number" then
        return ns[v] ~= nil
    end
    return false
end

function dict.new_entry(v)
    if dict.exists(v) then return end
    table.insert(ns, v)
    sn[v] = #ns
end

function dict.switch(v)
    if not dict.exists(v) then return end
    if type(v) == "string" then
        return sn[v]
    elseif type(v) == "number" then
        return ns[v]
    end
    return nil
end

function dict.conv(v)
    if not dict.exists(v) then dict.new_entry(v) end
    return dict.switch(v)
end

function dict.save()
    for i, s in pairs(ns) do
		if s:sub(1, 10) == "minecraft:" then
			ns[i] = s:sub(10)
		end
	end

    local f = io.open("/stockpile_server/bin/dict.bin", "wb")
    if not f then return end
    f:write(df:CompressDeflate(table.concat(ns, "\0")))
    f:close()

    --verify dict :
    --[[f = io.open("/stockpile_server/debug/dict_decoded.txt", "w")
    if not f then return end
    f:write(textutils.serialise(ns))
    f:close()]]
end

function dict.load()
    local f = io.open("/stockpile_server/bin/dict.bin", "rb")
    if not f then return end
    local compressed = f:read("a")
    f:close()
    local decompressed = df:DecompressDeflate(compressed)

    ns = {}
    for entry in string.gmatch(decompressed, "[^\0]+") do
        if entry:sub(1, 1) == ":" then
            entry = "minecraft" .. entry
        end
        table.insert(ns, entry)
    end

    sn = {}
    for i, v in ipairs(ns) do
        sn[v] = i
    end
end

function dict.generate()
    dict.reset()

    for item_name, item_data in pairs(item_index) do
        dict.conv(item_name)
        if item_data.displayName then dict.conv(item_data.displayName) end
        for _, nbt in ipairs(item_data.nbt) do
            dict.conv(nbt)
        end
    end

    for inv, _ in pairs(inv_index) do
        dict.conv(inv)
    end
end

function dict.get_ns_length()
    return #ns
end

function dict.reset()
    ns, sn = {}, {}
end

return dict