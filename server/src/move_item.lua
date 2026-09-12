local queue = require("/stockpile_server/src/queue")
local contentdb = require("/stockpile_server/src/contentdb")
local log = require("/stockpile_server/src/log")

-- Helper to test if an item name matches the given filter.
-- filter can be:
--   nil       -> matches everything
--   string    -> treated as a Lua pattern (like before)
--   table     -> list of strings; matches if any pattern matches
local function matches_item(name, filter)
    if filter == nil then
        return true
    elseif type(filter) == "string" then
        return string.match(name, filter) ~= nil
    elseif type(filter) == "table" then
        for _, pattern in ipairs(filter) do
            if string.match(name, pattern) then
                return true
            end
        end
        return false
    else
        -- Unknown type, treat as no filter
        return true
    end
end

--Moves the actually physical item in game. This functions is parallelized using the coroutine queue.
local function push_items(from_inv, from_slot, to_inv, to_slot, qty)

    local real_moved_qty = peripheral.call(from_inv, "pushItems", to_inv, from_slot, qty, to_slot)

    --minecraft inventory mechanics is such that this will only be an issue for removing or swapping items, not adding. Adding while move_item or scanning is active will not break db but removing or swapping will
    if real_moved_qty ~= qty then --if item swap with same qty, then invisible corruption occurs, no way to know if db is wrong is that case, altough that should be quite rare
        log.warn("The scanned content of an inv has been removed in some capacity by an external source (not stockpile - hopper taking items out or hand taking out, command blocks...). Therefore, it tries to move an item which is accually not there anymore (or not in the requiered quantity)")
        log.warn("order to move qty "..qty.." | Real moved : "..real_moved_qty)
        log.warn("from_inv, from_slot, to_inv, to_slot")
        log.warn(from_inv, from_slot, to_inv, to_slot)
        log.error("Corrupted db ! You have to fix your input and ouput systems to stockpile and rescan the whole storage system (or affected parts)")
    end
end

--Sub-function of the move_item function. Moves the actual item.
--Revieves a list of inv:slot tuple to move from the "move_item" function and decides where to send them.
local function move_list(to_move_list, to_invs)

    -- we have a list of items to move (from a set of inv to an other set)
    -- for each entry in the list : move the item
    for _, v in ipairs(to_move_list) do

        -- decompacts the info
        local from_inv, from_slot, from_qty = v.inv, v.slot, v.qty

        -- Get the item at the specified slot in the inventory
        local item = next(inv_index[from_inv].slots[from_slot])
        local stack_size = item_index[item].stack_size

        ::not_over::

        local real_qty = inv_index[from_inv].slots[from_slot][item]

        -- Determine if we need to insert into empty slots or fill partially filled slots
        local part_filled = contentdb.get_part_filled_slots(item, to_invs)
        if stack_size == from_qty or not part_filled then
            -- Insert directly into the first empty slot
            local empty = contentdb.first_empty_slot(to_invs)
            if not empty then --no empty slot
                return {status = "fail", detail = "Destination inventories are probably full, aborting transfer request. Please verify the target inventories have empty space"}
            end

            queue.add(push_items, from_inv, from_slot, empty.inv, empty.slot, from_qty) --Queues item transfer
            contentdb.update(empty.inv, empty.slot, item, from_qty)
            contentdb.update(from_inv, from_slot, item, real_qty - from_qty, stack_size)
        else
            -- Fill the part filled slots
            for _, pf in ipairs(part_filled) do

                local difference = stack_size - pf.qty --max amount to fill up the partially filled slot to stack size of that item.
                local qty_to_move = math.min(from_qty, difference)

                if qty_to_move == 0 then --wierd behavior with part filled slots, quick patch : break out of loop if qty to move is 0
                    break
                end

                from_qty = from_qty - qty_to_move
                queue.add(push_items, from_inv, from_slot, pf.inv, pf.slot, qty_to_move)  --Queues item transfer
                contentdb.update(from_inv, from_slot, item, real_qty - qty_to_move)
                contentdb.update(pf.inv, pf.slot, item, pf.qty + qty_to_move)

                --loop of part filled slot move item is not completly working fine, it takes a few queue process cycles to transfer all
                if from_qty > 0 then
                    goto not_over
                end
            end
        end
    end

    queue.run() --Execute all item transfers in parallel (instant transfers of arbitrary amount of items)
    return {status = "done", detail = "Moved specified items successfully"}
end

--The item and qty args are optional. If item arg is not specified, it moves all the inventories content.
--If qty arg is not specified, it only moves the specified item type.
--Regex filter arg : Only item with their nbt matching the arg will be marked to move. Can be combined with the item filter arg.
-- item arg can now be a single string (pattern) or a table of strings (list of patterns).
local function move_item(from_invs, to_invs, item, qty, nbt_regex_filter)

    local to_move_list, counter = {}, 0

    for _, inv in ipairs(from_invs) do
        local inv_content = inv_index[inv].slots
        if not inv_content then goto continue end

        for slot, slot_item in pairs(inv_content) do

            if type(slot) ~= "number" then
                goto skip_slot
            end

            -- Use the new helper to test item name against the filter
            local slot_name = next(slot_item)
            if not matches_item(slot_name, item) then
                goto skip_slot
            end

            if nbt_regex_filter and string.match(table.concat(item_index[slot_name].nbt), nbt_regex_filter) == nil then
                goto skip_slot
            end

            local _, slot_qty = next(slot_item)
            if qty and counter < qty then
                local move_qty = math.min(slot_qty, qty - counter)
                counter = counter + move_qty
                table.insert(to_move_list, {inv = inv, slot = slot, qty = move_qty})
            else
                table.insert(to_move_list, {inv = inv, slot = slot, qty = slot_qty})
            end

            if qty and counter >= qty then
                break
            end
            ::skip_slot::
        end
        if qty and counter >= qty then break end
        ::continue::
    end

    if #to_move_list == 0 then
        return {status = "done", detail = "Nothing to move. Found no item corresponding the filters"}
    end

    db_changed = true
    return move_list(to_move_list, to_invs)
end

return move_item