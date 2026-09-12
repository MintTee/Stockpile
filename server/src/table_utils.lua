local table_utils = {}

--Allows to dynamically add nested keys to a table. Used in the update_content function
function table_utils.set_nested_value(t, keys, value)

    local current = t
    for i = 1, #keys - 1 do
        local key = keys[i]
        if key ~= nil then
            if current[key] == nil then
                current[key] = {}
            end
            current = current[key]
        end
    end
    if keys[#keys] ~= nil then
        current[keys[#keys]] = value
    end
end

-- Recursively cleans up empty nested tables, starting from the deepest level
function table_utils.cleanup_empty_tables(t, keys)
    -- Check if the keys list is empty
    if #keys == 0 then
        return
    end

    local key = keys[1]

    if #keys == 1 then
        -- If it's the last key, check if the table at this key is empty or has only 0 values
        if type(t[key]) == "table" then
            local is_empty = true
            for k, v in pairs(t[key]) do
                if v ~= 0 then
                    is_empty = false
                    break
                end
            end
            if is_empty then
                t[key] = nil
            end
        elseif t[key] == nil or t[key] == 0 then
            t[key] = nil
        end
    else
        -- If not the last key, recursively call for the next key in the chain
        if t[key] then
            table_utils.cleanup_empty_tables(t[key], {table.unpack(keys, 2)})

            -- After cleaning deeper levels, check if the current table is empty or has only 0 values
            if type(t[key]) == "table" then
                local is_empty = true
                for k, v in pairs(t[key]) do
                    if v ~= 0 then
                        is_empty = false
                        break
                    end
                end
                if is_empty then
                    t[key] = nil
                end
            end
        end
    end
end

--Returns the lenght (number of entries) of a key value and/or index value table.
function table_utils.length(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

--Tries to find the value held in a nested table accessed from a key chain. If the key chain doesn't exit, it returns nil.
function table_utils.try_get_value(tbl, keychain)
    local current = tbl
    for _, key in ipairs(keychain) do
        if type(current) ~= "table" or current[key] == nil then
            return nil
        end
        current = current[key]
    end
    return current
end

-- Function to check if a value is contained in a table
function table_utils.contains_value(tbl, value)
    for _, v in pairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

-- Function to print a multi-dimensional table
function table_utils.print(tbl, indent)
    indent = indent or 0  -- Set default indent value to 0 if not provided

    for key, value in pairs(tbl) do
        local formatting = string.rep("  ", indent) .. key .. ": "
        if type(value) == "table" then
            print(formatting)
            table_utils.print(value, indent + 1)
        else
            print(formatting .. tostring(value))
        end
    end
end

--traverses all keys and values of a multi dimentionnal table and returns a list of all values & keys (as strings)
function table_utils.recursive_traverse(t, res)
    res = res or {}
    for k, v in pairs(t) do
		if tonumber(k) == nil then table.insert(res, tostring(k)) end
        if type(v) == "table" then
            table_utils.recursive_traverse(v, res)
		elseif type(v) == "string" then
            table.insert(res, v)
        end
    end
    return res
end

-- transforms a dict with key = bool to a list of all keys
-- Does not modify the input.
function table_utils.switch_to_list(t)
    local res = {}
    for k in pairs(t) do
        res[#res + 1] = k
    end
    return res
end

-- transforms list to a dict : key = bool
function table_utils.switch_to_dict(t)
    local res = {}
    for _, v in ipairs(t) do
        res[v] = true
    end
    return res
end

function table_utils.xor_table(t, t2)
    local in_t  = table_utils.switch_to_dict(t)
    local in_t2 = table_utils.switch_to_dict(t2)
    local seen  = {}

    local res = {}
    for _, v in ipairs(t) do
        if not in_t2[v] and not seen[v] then
            seen[v] = true
            res[#res + 1] = v
        end
    end
    for _, v in ipairs(t2) do
        if not in_t[v] and not seen[v] then
            seen[v] = true
            res[#res + 1] = v
        end
    end
    return res
end

--[[ Not used

--Returns a table (key = octet index and value = octet value) of a binary file
function table_utils.bin_to_table(str)
	local all_octets = {}
	for i = 1, #str  do
		local octet = string.byte(str ,i)
		table.insert(all_octets, octet)
	end
	return all_octets
end

function table_utils.sort_table_by_keys(t)
    local keys = {}
    for key in pairs(t) do
        table.insert(keys, key)
    end

    table.sort(keys)

    local sorted_table = {}
    for _, key in ipairs(keys) do
        table.insert(sorted_table, { key = key, value = t[key] })
    end

    return sorted_table
end
]]

return table_utils