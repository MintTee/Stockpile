table_utils = {}

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

--[[ NOT USED RN
function table_utils.sort_table_by_keys(t)
    -- Step 1: Extract the keys
    local keys = {}
    for key in pairs(t) do
        table.insert(keys, key)
    end

    -- Step 2: Sort the keys
    table.sort(keys)

    -- Step 3: Create a sorted list of key-value pairs
    local sorted_table = {}
    for _, key in ipairs(keys) do
        table.insert(sorted_table, { key = key, value = t[key] })
    end

    return sorted_table
end]]

return table_utils