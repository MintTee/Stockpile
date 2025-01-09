local queue = require("/stockpile/src/queue")
local table_utils = require("/stockpile/src/table_utils")
local contentdb = require("/stockpile/src/contentdb")
local logger = require("/stockpile/src/logger")
local data = require("/stockpile/src/data_manager")

--Function to physically move items from and to inventories.
--The item and qty args are optional. If item arg is not specified, it moves all the inventories content.
--If qty arg is not specified, it only moves the specified item type.
--Regex filter arg : Only item with their nbt matching the arg will be marked to move. Can be combined with the item filter arg.
function move_item(from_invs, to_invs, item, qty, nbt_regex_filter)
    local to_move, counter = {}, 0

    if type(to_invs) == "string" then to_invs = {to_invs} end
    if type(from_invs) == "string" then from_invs = {from_invs} end
    if type(to_invs) ~= "table" or type(from_invs) ~= "table" then
        return "Error : move_item : The to and from invs args have to be tables or strings."
    end

    for _, inv in ipairs(from_invs) do
        local inv_content = content["inv_index"][inv]
        if not inv_content then goto continue end

        for slot, slot_item in pairs(inv_content) do
            if type(slot) ~= "number" then goto skip_slot end
            if item and string.match(next(slot_item), item) == nil then goto skip_slot end
            if nbt_regex_filter and string.match(textutils.serialise(content["item_index"][next(slot_item)]["nbt"]), nbt_regex_filter) == nil then goto skip_slot end

            local _, slot_qty = next(slot_item)
            if qty and counter < qty then
                local move_qty = math.min(slot_qty, qty - counter)
                counter = counter + move_qty
                table.insert(to_move, inv.."|"..slot.."|"..move_qty)
                logger("Debug", "move_item", "Marking slot at quantity to be moved", slot)
            else
                table.insert(to_move, inv.."|"..slot.."|"..slot_qty)
                logger("Debug", "move_item", "Marking slot at stack size quantity to be moved", slot)
            end

            if qty and counter >= qty then
                logger("Debug", "move_item", "Required quantity reached", qty)
                break
            end
            ::skip_slot::
        end
        if qty and counter >= qty then break end
        ::continue::
    end

    if #to_move == 0 then 
        logger("Debug", "move_item", "Nothing to move")
        return "Debug : move_item : Nothing to move. Found no item corresponding the filters."
    end

    logger("Debug", "move_item", "Calling the move_list function")
    local result = move_list(to_move, to_invs)

    data.save_large_file_to_disks("content.txt", content)
    return result
end

--Sub-function of the move_item function. Moves the actual item.
--Revieves a list of inv:slot tuple to move from the "move_item" function and decides where to send them.
function move_list(to_move, to_invs)
    
    for _, tuple in ipairs(to_move) do
        logger("Debug", "move_list", "Next item entry", tuple)
        
        -- Deconcatenate the tuple to get from_inv, from_slot, and from_qty
        local from_inv, from_slot, from_qty = string.match(tuple, "([^|]+)|([^|]+)|([^|]+)")
        from_slot, from_qty = tonumber(from_slot), tonumber(from_qty)
        
        -- Get the item at the specified slot in the inventory
        local from_item = next(content["inv_index"][from_inv][from_slot])
        local stack_size = content["item_index"][from_item]["stack_size"]

        ::not_over::
        
        -- List partially filled slots for the item in the target inventories
        local part_filled_slot_list = contentdb.list_part_filled_slots(from_item, to_invs) or {}
        local real_qty = content["inv_index"][from_inv][from_slot][from_item]
        
        -- Determine if we need to insert into empty slots or fill partially filled slots
        if (stack_size == from_qty and #part_filled_slot_list == 1) or not next(part_filled_slot_list) then
            -- Insert directly into the first empty slot
            local first_empty_inv, first_empty_slot = table.unpack(contentdb.first_empty_slot(to_invs))

            if first_empty_inv == false or first_empty_slot == false then
                return "Warn : move_item : Destination inventories are probably full, aborting transfer request. Please verify the destinations have empty space"
            end
            logger("Debug", "move_list", "Inserting into empty slot", first_empty_inv.." "..first_empty_slot)
            queue.add(push_items, from_inv, from_slot, first_empty_inv, first_empty_slot, from_qty) --Queues item transfer
            contentdb.update(first_empty_inv, first_empty_slot, from_item, from_qty)
            contentdb.update(from_inv, from_slot, from_item, real_qty - from_qty, stack_size)
        else
            -- Fill the part filled slots
            logger("Debug", "move_list", "Inserting into partially filled slot")
            
            for _, tuple in ipairs(part_filled_slot_list) do
                local part_inv, part_slot, part_qty = string.match(tuple, "([^|]+)|([^|]+)|([^|]+)")
                part_slot, part_qty = tonumber(part_slot), tonumber(part_qty)

                logger("Debug", "move_list", "Topping up", part_inv.." "..part_slot)
                
                local difference = stack_size - part_qty
                local qty_to_move = math.min(from_qty, difference)
                
                from_qty = from_qty - qty_to_move

                queue.add(push_items, from_inv, from_slot, part_inv, part_slot, qty_to_move)  --Queues item transfer

                contentdb.update(from_inv, from_slot, from_item, real_qty - qty_to_move)
                contentdb.update(part_inv, part_slot, from_item, part_qty + qty_to_move)

                if from_qty > 0 then
                    goto not_over
                end

            end
        end
    end
    queue.run() --Execute all item transfers in parallel (instant transfers of arbitrary amount of items)
    return "Info : move_item : Success"
end

--Moves the accually physical item in game. This functions is parallelized using the coroutine queue.
function push_items(from_inv, from_slot, to_inv, to_slot, qty)
    logger("Debug","push_items","function called")
    peripheral.call(from_inv, "pushItems", to_inv, from_slot, qty, to_slot)
end

return move_item