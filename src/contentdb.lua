local queue = require("/stockpile/src/queue")
local table_utils = require("/stockpile/src/table_utils")
local logger = require("/stockpile/src/logger")
local data = require("/stockpile/src/data_manager")
require("/stockpile/var/globals")

contentdb = {}
contentdb.config_unit = {}

--///////////////////////////////////////////////////////////////////////////////////////////////////////

--Returns the inventory size (54 for a double chest for example) of the specified inventory id.
function get_inv_size(inv)
    local inv_size = peripheral.call(inv, "size") or nil --Gets the inventory size
    if inv_size then
        logger("Debug", "get_inv_size", "Got inventory size", "inv: "..inv.." size: "..inv_size)
        table_utils.set_nested_value(content, {"inv_index", inv, "size"}, inv_size)
    end
end

-- Sub function of "contentdb.scan". Scans the specified slot in the specified inventory and consequently updates the content table.
function get_slot_content(inv_id, slot)
    -- Get item details for the slot
    local slot_tbl = peripheral.call(inv_id, "getItemDetail", slot)
    
    if slot_tbl then
        process_item_nbt(slot_tbl, inv_id, slot)
    else
        handle_empty_slot(inv_id, slot)
    end
end

-- Process the found item in the slot. Sub function of get_slot_content().
function process_item_nbt(slot_tbl, inv_id, slot)
    local qty  = slot_tbl["count"]
    local item_stack_size = slot_tbl["maxCount"]
    local item = slot_tbl["name"]
    if slot_tbl["nbt"] and slot_tbl["nbt"] ~= "552887824c43124013fd24f6edcde0fb" then --Strange value :D
        logger("Debug", "process_item_nbt", "Item contains nbt data", "Hash = "..slot_tbl["nbt"])
        item = item.."-"..slot_tbl["nbt"]
    end

    local nbt = refine_nbt(slot_tbl)
    --nbt = textutils.serialise(nbt)

    logger("Debug", "get_slot_content", "Found", qty.." "..item.." in "..inv_id.." slot:"..slot)
    contentdb.update(inv_id, slot, item, qty, item_stack_size, _, nbt)
end

-- Handle empty slot, updating content with 0 quantity. Sub function of get_slot_content().
function handle_empty_slot(inv_id, slot)
    local previous_item = table_utils.try_get_value(content, {"inv_index", inv_id, slot})
    
    if previous_item then
        previous_item = next(previous_item)
        contentdb.update(inv_id, slot, previous_item, 0)  -- Assigns the slot qty to 0
    end

    logger("Debug_clutter", "get_slot_content", "Empty slot", inv_id.." slot:"..slot)
end

--Get rid of nbt data which is not useful in a normal context. You can modify this depending on your needs. At your own risks.
function refine_nbt(nbt_tbl)
    nbt_tbl["nbt"] = nil
    nbt_tbl["name"] = nil
    nbt_tbl["itemGroups"] = nil
    nbt_tbl["count"] = nil
    nbt_tbl["maxCount"] = nil
    table.sort(nbt_tbl)
    return nbt_tbl
end

--Scans the specified inventories and consequently updates the content table (representing all stockpile content).
--It uses a coroutine queue to achieve near instant scanning speed.
function contentdb.scan(invs)
    if type(invs) ~= "table" then --Checks valilidy of the arg
        return "Error : scan : Invalid 'invs' arg. It has to be a table."
    end

    --Parallel processing of all inv sizes. Queries and stores the invs sizes.
    for _, inv_id in ipairs(invs) do
        queue.add(get_inv_size, inv_id)
    end
    queue.run()

    --Parallel processing of all the slots of all invs. Update the content table. Processes 1 inv at a time (all slots in parallel)
    for _, inv_id in ipairs(invs) do 
        local inv_size =  table_utils.try_get_value(content, {"inv_index", inv_id, "size"}) or nil
        if type(inv_size) == "number" then
            for slot = 1, inv_size do
                queue.add(get_slot_content, inv_id, slot)
            end
        end
    end
    queue.run()

    data.save("/stockpile/database/content.txt", content)
    return "Info : scan : Done"
end

--///////////////////////////////////////////////////////////////////////////////////////////////////////

-- Returns all the "inventory" type peripherals found in the stockpile server's network.
function contentdb.list_all_inventories()
    logger("Debug", "list_all_inventories", "function called")
    
    local connected_peripherals = peripheral.getNames()
    local inv_peripherals = filter_inventories(connected_peripherals)
    table.sort(inv_peripherals)

    return inv_peripherals
end

-- Filters and returns only "inventory" type peripherals
function filter_inventories(connected_peripherals)
    local inv_peripherals = {}
    for _, peri in ipairs(connected_peripherals) do
        if peripheral.hasType(peri, "inventory") then
            table.insert(inv_peripherals, peri)
        end
    end
    return inv_peripherals
end

--///////////////////////////////////////////////////////////////////////////////////////////////////////

function contentdb.config_unit.counts_towards_total(unit_name, counts_towards_total)

    local function inv_counts_towards_total(inv, boolean)
        if not inventories["total_count"] then
            inventories["total_count"] = {}
        end
        inventories["total_count"][inv] = boolean
    end

    if unit_name == "total_count" then
        return "Error : config_unit.counts_towards_total : unit_name arg can't be 'total_count' because of a naming conflict."
    end
    if not inventories[unit_name] then
        return "Error : config_unit.counts_towards_total : unit_name does not yet exist. Use the API method 'config_unit' to create it."
    end

    --Sets the count towards total parameter in the inventories table. Just needs the unit name and a boolean.
    for _, inv in ipairs(inventories[unit_name]) do
        inv_counts_towards_total(inv, counts_towards_total)
    end

    data.save("/stockpile/database/inventories.txt", inventories)
    return "Info : config_unit.counts_towards_total : Done"
end

function contentdb.config_unit.add(invs, unit_name)

    if not inventories[unit_name] then
        inventories[unit_name] = {}
    end

    for _, inv in ipairs(invs) do
        if table_utils.contains_value(inventories[unit_name], inv) == false then
            table.insert(inventories[unit_name], inv)
            logger("Info", "contentdb.config_unit.add", "Added inventory", inv.." from unit "..unit_name)
        end
    end
    data.save("/stockpile/database/inventories.txt", inventories)
    return "Info : config_unit.add : Done."
end

function contentdb.config_unit.remove(invs, unit_name)

    if not inventories[unit_name] then
        return "Info : config_unit.remove : unit_name does not exist."
    end

    for _, inv in ipairs(invs) do
        for k, v in pairs(inventories[unit_name]) do
            if v == inv then
                table.remove(inventories[unit_name], k)
                logger("Info", "contentdb.config_unit.remove", "Removed inventory", inv.." from unit "..unit_name)
            end
        end
    end

    if #inventories[unit_name] == 0 then
        inventories[unit_name] = nil
    end

    data.save("/stockpile/database/inventories.txt", inventories)
    return "Info : config_unit.remove : Done."
end

function contentdb.config_unit.set(invs, unit_name)
    if not invs or invs[1] == nil then
        inventories[unit_name] = nil
        logger("Info", "contentdb.config_unit.set", "Successfully removed unit", unit_name)
    else
        inventories[unit_name] = invs
        logger("Info", "contentdb.config_unit.set", "Successfully set unit inventories", unit_name)
    end
    data.save("/stockpile/database/inventories.txt", inventories)
    return "Info : config_unit.set : Done."
end

--///////////////////////////////////////////////////////////////////////////////////////////////////////

-- Function to check if part filled slots exist for the specified item
local function has_part_filled_slots(item)
    return content["item_index"][item] and content["item_index"][item]["part_filled_slots"]
end

-- Function to process a single inventory and its slots
local function process_inventory_slots(current_inv, item, result)
    local current_inv_content = content["item_index"][item]["part_filled_slots"][current_inv]
    for slot, qty in pairs(current_inv_content) do
        local tuple = current_inv .. "|" .. slot .. "|" .. qty
        table.insert(result, tuple)
        logger("Debug", "contentdb.list_part_filled_slots", "Found part filled slot", tuple)
    end
end

-- Main function to list part-filled slots for the specified item in the given inventory list
function contentdb.list_part_filled_slots(item, invs)
    if not has_part_filled_slots(item) then
        return nil
    end

    local result = {}

    for _, current_inv in ipairs(invs) do
        if content["item_index"][item]["part_filled_slots"][current_inv] then
            process_inventory_slots(current_inv, item, result)
        end
    end

    return result
end

--///////////////////////////////////////////////////////////////////////////////////////////////////////

-- Function to handle finding the first empty slot in a given inventory
local function find_empty_slot_in_inventory(current_inv, current_inv_content, inv_size)
    for i = 1, inv_size do
        if current_inv_content[i] == nil then
            logger("Debug", "contentdb.first_empty_slot", "Found empty slot", i .. " in inv " .. current_inv)
            return {current_inv, i}
        end
    end
    return nil
end

-- Function to handle an inventory that is completely empty
local function handle_empty_inventory(current_inv)
    logger("Debug", "contentdb.first_empty_slot", "Found empty slot", "Set empty slot to #1 in inv " .. current_inv .. " because it's fully empty")
    return {current_inv, 1}
end

-- Main function to find the first empty slot in the provided inventories
function contentdb.first_empty_slot(invs)
    for _, current_inv in ipairs(invs) do
        if content["inv_index"][current_inv] then
            local current_inv_content = content["inv_index"][current_inv]
            local inv_size = content["inv_index"][current_inv]["size"]

            if not inv_size then
                contentdb.scan(invs)
                inv_size = content["inv_index"][current_inv]["size"]
            end

            local empty_slot = find_empty_slot_in_inventory(current_inv, current_inv_content, inv_size)
            if empty_slot then
                return empty_slot
            end
        else
            return handle_empty_inventory(current_inv)
        end
    end

    logger("Warn", "contentdb.first_empty_slot", "Couldn't find any empty slots in specified inventories", "Destination inventories are probably full!")
    return {false, false}
end

--///////////////////////////////////////////////////////////////////////////////////////////////////////

-- Helper function to calculate the total quantity for an item
local function calculate_total(item, qty, difference, inv_id)
    local total = table_utils.try_get_value(content, {"item_index", item, "total"}) or 0
    if inventories["total_count"][inv_id] == true then
        total = total + difference
    end
    return total < 0 and 0 or total
end

-- Helper function to update content for stack size, inventory size, etc.
local function update_content_tables(inv_id, slot, item, qty, stack_size, inv_size, total, nbt)
    if table_utils.try_get_value(content, {"inv_index", inv_id, "size"}) == nil then
        table_utils.set_nested_value(content, {"inv_index", inv_id, "size"}, inv_size)
    end

    table_utils.set_nested_value(content, {"inv_index", inv_id, slot, item}, qty)
    table_utils.set_nested_value(content, {"item_index", item, inv_id, slot}, qty)

    if table_utils.try_get_value(content, {"item_index", item, "stack_size"}) == nil then
        table_utils.set_nested_value(content, {"item_index", item, "stack_size"}, stack_size)
    end

    if table_utils.try_get_value(content, {"item_index", item, "nbt"}) == nil then
        table_utils.set_nested_value(content, {"item_index", item, "nbt"}, nbt)
    end

    if total == 0 then
        table_utils.set_nested_value(content, {"item_index", item, "total"}, nil)
    else
        table_utils.set_nested_value(content, {"item_index", item, "total"}, total)
    end
end

-- Helper function to update the part filled slots
local function update_part_filled_slots(item, inv_id, slot, qty, stack_size)
    if qty < stack_size then
        table_utils.set_nested_value(content, {"item_index", item, "part_filled_slots", inv_id, slot}, qty)
    else
        table_utils.set_nested_value(content, {"item_index", item, "part_filled_slots", inv_id, slot}, 0)
    end
end

-- Main update function
function contentdb.update(inv_id, slot, item, qty, stack_size, inv_size, nbt)
    stack_size = stack_size or table_utils.try_get_value(content, {"item_index", item, "stack_size"})
    local existing_qty = table_utils.try_get_value(content, {"inv_index", inv_id, slot, item}) or 0
    local difference = qty - existing_qty

    -- Calculate the new total
    local total = calculate_total(item, qty, difference, inv_id)

    -- Update the content tables
    update_content_tables(inv_id, slot, item, qty, stack_size, inv_size, total, nbt)

    -- Update the part filled slots
    update_part_filled_slots(item, inv_id, slot, qty, stack_size)

    -- Clean up empty tables
    table_utils.cleanup_empty_tables(content, {"inv_index", inv_id, slot, item})
    table_utils.cleanup_empty_tables(content, {"item_index", item, inv_id, slot})
    table_utils.cleanup_empty_tables(content, {"item_index", item, "total"})
    table_utils.cleanup_empty_tables(content, {"item_index", item, "part_filled_slots", inv_id, slot})

    -- Remove item entry if it only contains stack_size
    if table_utils.length(content["item_index"][item]) == 2 then
        content["item_index"][item] = nil
    end
end

--///////////////////////////////////////////////////////////////////////////////////////////////////////

--[[ DEPRECATED FUNCTION
--Returns the total amount of the specified item in the "content" table (stockpile's representation of the system's content).
--It will return 0 if the specified item is not in storage (also returns 0 if there is a typo in the item name).
function contentdb.check(item)
    if type(item) ~= "string" then
        return "Error : check : Invalid item name. It has to be a string."
    elseif not string.match(item, ":") then
        return "Error : check : Invalid item name. It has to be a complete item id, including the source. Example : 'minecraft:stone'."
    end
    return table_utils.try_get_value(content, {"item_index", item, "total"}) or 0
end
]]

--Returns the total amount of slots and occupied slots in the storage.
--May not be 100% accurate as it doesn't account for multiple partially filled slots.
--It also counts used slots of none storage inventories (inputs, outputs etc...).
function contentdb.usage()
    local all_slots, used_slots = 0, 0

    for _, inv in ipairs(inventories.storage) do
        all_slots = all_slots + (table_utils.try_get_value(content, {"inv_index", inv, "size"}) or 0)
    end

    for _, item_table in pairs(content.item_index) do
        if item_table.total and item_table.stack_size then
            used_slots = used_slots + math.floor(item_table.total / item_table.stack_size + 0.99)
        end
    end

    return {total_slots = all_slots, used_slots = used_slots}
end

--Searches and returns a list of all the matching items held in storage. Uses regex expressions.
function contentdb.search(name_search, nbt_search)
    local result = {}
    name_search = name_search or ""

    for item_name, item_data in pairs(content["item_index"]) do
        local nbt_data = nbt_search and textutils.serialize(item_data["nbt"])

        if string.match(item_name, name_search) and (not nbt_search or string.match(nbt_data, nbt_search)) then
            result[item_name] = table_utils.try_get_value(content, {"item_index", item_name, "total"}) or 0
        end
    end

    return result
end

function contentdb.get_nbt(item_id)
    if type(item_id) ~= "string" then return end
    return table_utils.try_get_value(content, {"item_index", item_id, "nbt"})
end

return contentdb