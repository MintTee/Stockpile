-- logic/search.lua
local table_utils = require("src.table_utils")
local search = {}

local function get_slots(inv_index, inv)
    local entry = inv_index and inv_index[inv]
    return entry and entry.slots
end

function search.run(name_search, nbt_search, selectedGroup, groups, item_index, inv_index)
    name_search = string.gsub(string.gsub(name_search or "", "%s+", " "), " ", "_")
    nbt_search  = string.gsub(string.gsub(nbt_search  or "", "%s+", " "), " ", "_")

    if not selectedGroup then return {} end

    -- Before the first get_content response, both are nil. Treat as empty.
    item_index = item_index or {}
    inv_index  = inv_index  or {}

    local invs     = groups[selectedGroup] or {}
    local not_invs = table_utils.xor_table(invs, groups.all or {})

    local item_list = {}

    if #invs > #not_invs then
        for item, data in pairs(item_index) do
            item_list[item] = {
                displayName = data.displayName,
                nbt         = data.nbt or {},
                total       = data.total or 0,
            }
        end

        for _, inv in ipairs(not_invs) do
            local slots = get_slots(inv_index, inv)
            if slots then
                for slot, v in pairs(slots) do
                    if type(slot) == "number" then
                        local item, qty = next(v)
                        local entry = item_list[item]
                        if entry then
                            entry.total = (entry.total or 0) - qty
                        end
                    end
                end
            end
        end
    else
        local res = {}
        for _, inv in ipairs(invs) do
            local slots = get_slots(inv_index, inv)
            if slots then
                for slot, v in pairs(slots) do
                    if type(slot) == "number" then
                        local item, qty = next(v)
                        res[item] = (res[item] or 0) + qty
                    end
                end
            end
        end

        for item, total in pairs(res) do
            local data = item_index[item]
            if data then
                item_list[item] = {
                    displayName = data.displayName,
                    nbt         = data.nbt or {},
                    total       = total,
                }
            end
        end
    end

    local result = {}
    for item, v in pairs(item_list) do
        if v.total > 0 then
            local nbt_str = nbt_search and table.concat(v.nbt) or ""
            if string.match(item, name_search)
               and (not nbt_search or string.match(nbt_str, nbt_search)) then
                table.insert(result, {
                    item        = item,
                    displayName = v.displayName,
                    total       = v.total,
                })
            end
        end
    end

    table.sort(result, function(a, b) return a.total > b.total end)
    return result
end

return search