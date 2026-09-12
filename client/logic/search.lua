-- logic/search.lua
local table_utils = dofile("/stockpile_client/src/table_utils.lua")
local search = {}

function search.run(name_search, nbt_search, selectedGroup, groups, item_index, inv_index)
    name_search = string.gsub(string.gsub(name_search or "", "%s+", " "), " ", "_")
    nbt_search = string.gsub(string.gsub(nbt_search or "", "%s+", " "), " ", "_")

    if not selectedGroup then return {} end
    local invs = groups[selectedGroup] or {}
    local not_invs = table_utils.xor_table(invs, groups.all or {})

    local item_list = {}
    if #invs > #not_invs then
        for item, data in pairs(item_index) do
            item_list[item] = {
                displayName = data.displayName,
                nbt = data.nbt,
                total = data.total
            }
        end
        for _, inv in ipairs(not_invs) do
            local slots = inv_index[inv].slots
            for slot, v in pairs(slots) do
                if type(slot) == "number" then
                    local item, qty = next(v)
                    if item_list[item] then
                        item_list[item].total = item_list[item].total - qty
                    end
                end
            end
        end
    else
        local function build(invs)
            local res = {}
            for _, inv in ipairs(invs) do
                local content = inv_index[inv].slots
                for slot, v in pairs(content) do
                    if type(slot) == "number" then
                        local item, qty = next(v)
                        if not res[item] then res[item] = 0 end
                        res[item] = res[item] + qty
                    end
                end
            end
            for item, total in pairs(res) do
                local data = item_index[item]
                res[item] = { displayName = data.displayName, nbt = data.nbt, total = total }
            end
            return res
        end
        item_list = build(invs)
    end

    local result = {}
    for item, v in pairs(item_list) do
        if v.total > 0 then
            local nbt_str = nbt_search and table.concat(v.nbt) or ""
            if string.match(item, name_search) and (not nbt_search or string.match(nbt_str, nbt_search)) then
                table.insert(result, {
                    item = item,
                    displayName = v.displayName,
                    total = v.total
                })
            end
        end
    end
    table.sort(result, function(a, b) return a.total > b.total end)
    return result
end

return search