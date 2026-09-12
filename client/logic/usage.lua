-- usage.lua
local usage = {}

function usage.getTotal(app)
    if not app.inv_index or not app.item_index then return end
    local c = 0
    for _, item in pairs(app.item_index) do
        if not item.total then item.total = 1 end
        c = c + item.total
    end
    return c
end

function usage.getSlots(app)
    if not app.inv_index or not app.item_index then return end

    local all_slots, used_slots = 0, 0

    for _, inv in ipairs(app.groups.all) do
        all_slots = all_slots + app.inv_index[inv].size
    end

    for _, item in pairs(app.item_index) do
        if item.total and item.stack_size then
            used_slots = used_slots + math.floor(item.total / item.stack_size + 0.99)
        end
    end

    return {total = all_slots, used = used_slots}
end

return usage