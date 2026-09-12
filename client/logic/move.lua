-- logic/move.lua
local comms = dofile("/stockpile_client/src/comms.lua")
local table_utils = dofile("/stockpile_client/src/table_utils.lua")
local move = {}

-- Now asynchronous: performs the move and calls callback(success, result)
function move.performMove(from_group, to_group, mode, qty, selectedItems, app, callback)
    -- Validation
    if not from_group or from_group == "all" or not to_group or from_group == to_group then
        if callback then callback(false) end
        return
    end
    local sel_entries = selectedItems or {}
    if #sel_entries == 0 then
        if callback then callback(false) end
        return
    end

    local item_list = {}
    for _, v in ipairs(sel_entries) do
        item_list[v.id] = true
    end
    item_list = table_utils.switch_to_list(item_list)

    if mode == "all" then
        qty = nil
    elseif mode == "divided" then
        qty = qty / #item_list
    elseif not qty or qty <= 0 then
        if callback then callback(false) end
        return
    end

    -- Send move command asynchronously
    comms.moveItemAsync(app.groups[from_group], app.groups[to_group], item_list, qty,
        function(result)
            if result and result.status == "done" then
                -- Refresh inventory data after successful move
                comms.getContentAsync(app, function()
                    if callback then callback(true) end
                end)
            else
                if callback then callback(false) end
            end
        end
    )
end

return move