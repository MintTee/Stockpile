-- /stockpile_client/logic/move.lua
local app   = require("app")
local comms = require("src.comms")

local move = {}

-- Returns (qty, nil) where qty == nil means "move everything",
-- or (nil, error_string) if the inputs can't be satisfied.
local function resolve_per_item_qty(mode, qty, n_items)
    if mode == "all" then
        return nil
    end
    if mode == "divided" then
        local q = math.floor(qty / n_items)
        if q <= 0 then
            return nil, "Quantity too small to split across selected items"
        end
        return q
    end
    -- "of each"
    if not qty or qty <= 0 then
        return nil, "Quantity must be a positive number"
    end
    return qty
end

function move.performMove(from_group, to_group, mode, qty, selectedItems, callback)
    if not from_group or from_group == "all" or not to_group or from_group == to_group then
        if callback then callback(false) end
        return
    end

    local sel_entries = selectedItems or {}
    if #sel_entries == 0 then
        if callback then callback(false) end
        return
    end

    -- Dedupe item ids while preserving order.
    local seen, item_list = {}, {}
    for _, v in ipairs(sel_entries) do
        if not seen[v.id] then
            seen[v.id] = true
            item_list[#item_list + 1] = v.id
        end
    end

    if #item_list == 0 then
        if callback then callback(false) end
        return
    end

    local q, err = resolve_per_item_qty(mode, qty, #item_list)
    if err then
        if callback then callback(false) end
        return
    end

    local from_invs = app.groups[from_group]
    local to_invs   = app.groups[to_group]

    -- "all" moves everything matching the filter, and a single item can
    -- never be misdivided. Both fit in one command.
    if mode == "all" or #item_list == 1 then
        local filter = (#item_list == 1) and item_list[1] or item_list
        comms.moveItemAsync(from_invs, to_invs, filter, q, function(result)
            if result and result.status == "done" then
                comms.getContentAsync(app, function()
                    if callback then callback(true) end
                end)
            else
                if callback then callback(false) end
            end
        end)
        return
    end

    -- Multiple items with a per-item qty: fire one command per item.
    local remaining  = #item_list
    local any_failed = false

    local function step_done(success)
        if not success then any_failed = true end
        remaining = remaining - 1
        if remaining > 0 then return end

        -- Refresh regardless, so the UI reflects what actually moved
        -- even when some sub-commands failed.
        comms.getContentAsync(app, function()
            if callback then callback(not any_failed) end
        end)
    end

    for _, item in ipairs(item_list) do
        comms.moveItemAsync(from_invs, to_invs, item, q, function(result)
            step_done(result and result.status == "done")
        end)
    end
end

return move