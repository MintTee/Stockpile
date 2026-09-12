local queue = require("/stockpile_server/src/queue")
local table_utils = require("/stockpile_server/src/table_utils")
local log = require("/stockpile_server/src/log")
local string_utils = require("/stockpile_server/src/string_utils")
require("/stockpile_server/var/globals")

local contentdb = {}

--Flatten NBT and extract all searchable words into a list. Used for regex search while keeping the nbt data collection small and less redundant.
local function cleanup_nbt(nbt_tbl, item_name)
    nbt_tbl.nbt = nil
    nbt_tbl.name = nil
    nbt_tbl.itemGroups = nil
    nbt_tbl.count = nil
    nbt_tbl.maxCount = nil
    nbt_tbl.mapColor = nil
    nbt_tbl.mapColour = nil
    nbt_tbl.nbt = nil --hash
    nbt_tbl.displayName = nil

    -- Flatten NBT and extract all searchable words
    local flat = table_utils.recursive_traverse(nbt_tbl)
    local result_fields = {}

    -- Helper: split string by slashes and spaces, convert underscores to spaces
    local function split_words(str)
        str = str:gsub("_", " "):gsub("^.*:", "")  -- Remove prefix, convert underscores
        local words = {}
        for word in string.gmatch(str, "[^/ ]+") do
            table.insert(words, word)
        end
        return words
    end

    -- Collect all words from flattened NBT
    for _, s in ipairs(flat) do
        for _, word in ipairs(split_words(s)) do
            result_fields[word] = true
        end
    end

    -- Common words to filter out
    local remove_list = {
        name = true, tags = true, maxDamage = true, displayName = true, that = true, ["in"] = true, of = true, can = true, ["and"] = true, as = true, by = true, like = true, ["if"] = true, ["for"] = true, this = true, all = true, only = true, items = true, up = true, from = true, none = true, non = true
    }

    -- Remove common words
    for k in pairs(result_fields) do
        if remove_list[k] then
            result_fields[k] = nil
        end
    end

    -- make a word singular
    local function singular(word)
        local singulars = {
            {"ies$", "y"},     -- cities -> city
            {"ves$", "f"},     -- leaves -> leaf
            {"ves$", "fe"},    -- knives -> knife
            {"([sxz])es$", "%1"},   -- boxes -> box, quizzes -> quiz
            {"([^aeiou])ies$", "%1y"}, -- applies to "flies" -> "fly" but not "species"
            {"([cs]h)es$", "%1"},    -- churches -> church, bushes -> bush
            {"([^aeiou])es$", "%1"},  -- cases where es is just added
            {"s$", ""}         -- stones -> stone
        }

        local lower_word = string.lower(word)
        for _, pattern in ipairs(singulars) do
            local matched, count = string.gsub(lower_word, pattern[1], pattern[2])
            if count > 0 then
                return matched
            end
        end
        return lower_word
    end

    -- Remove redundant fields (containment + plural matching)
    for k1 in pairs(result_fields) do
        local lower_k1 = k1:lower()
        local singular_k1 = singular(lower_k1)

        -- Check against item_name
        if item_name:match(singular_k1) then
            result_fields[k1] = nil
        end

        -- Check containment with other fields
        for k2 in pairs(result_fields) do
            if k1 ~= k2 and lower_k1:match(k2:lower()) then
                result_fields[k2] = nil
            end
        end
    end

    result_fields = table_utils.switch_to_list(result_fields)
    return result_fields
end

-- Process the found item in the slot. Sub function of contentdb.get_slot_content().
local function process_item_nbt(slot_tbl, inv_id, slot)
    local qty  = slot_tbl.count
    local item_stack_size = slot_tbl.maxCount
    local item = slot_tbl.name
    local dispn = slot_tbl.displayName
    local hash = slot_tbl.nbt

    --if custom nbt hash, append it to item name
    if hash and hash ~= "552887824c43124013fd24f6edcde0fb" then --Strange value :D
        item = item.."-"..hash
    end

    local nbt = cleanup_nbt(slot_tbl, item)
    contentdb.update(inv_id, slot, item, qty, item_stack_size, _, nbt, dispn)
end

--Returns the inventory size (54 for a double chest for example) of the specified inventory id.
local function get_inv_size(inv)
    local inv_size = peripheral.call(inv, "size") or nil --Gets the inventory size
    if inv_size then
        table_utils.set_nested_value(inv_index, {inv, "size"}, inv_size)
    end
end

-- Handle empty slot, updating content with 0 quantity. Sub function of contentdb.get_slot_content().
local function handle_empty_slot(inv, slot)
    local previous_item = table_utils.try_get_value(inv_index, {inv, "slots", slot})

    if previous_item then
        previous_item = next(previous_item)
        contentdb.update(inv, slot, previous_item, 0)  -- Assigns the slot qty to 0
    end
end

-- Sub function of "contentdb.scan". Scans the specified slot in the specified inventory and consequently updates the content table.
function contentdb.get_slot_content(inv, slot)
    if not table_utils.try_get_value(inv_index, {inv, "slots"}) then table_utils.set_nested_value(inv_index, {inv, "slots"},{}) end

    -- Get item details for the slot
    local slot_tbl = peripheral.call(inv, "getItemDetail", slot)

    if slot_tbl then
        --there is someting in slot
        process_item_nbt(slot_tbl, inv, slot)
    else
        handle_empty_slot(inv, slot)
    end
end

--Scans the specified inventories and consequently updates the content table (representing all stockpile content). It uses a coroutine queue to achieve near instant scanning speed.
function contentdb.scan(invs)

    --Parallel processing of all inv sizes. Queries and stores the invs sizes.
    for _, inv_id in ipairs(invs) do
        queue.add(get_inv_size, inv_id)
    end
    queue.run()

    --Parallel processing of all the slots of all invs. Update the content table. Processes 1 inv at a time (all slots in parallel)
    for _, inv_id in ipairs(invs) do

        local inv_size = table_utils.try_get_value(inv_index, {inv_id, "size"})
        if inv_size then
            for slot = 1, inv_size do
                queue.add(contentdb.get_slot_content, inv_id, slot)
            end
        end
    end
    queue.run()

    --verify scan :
    --[[local f = io.open("/stockpile_server/debug/raw_scan.txt", "w")
    if not f then return end
    f:write(textutils.serialise(inv_index["minecraft:chest_10"]))
    f:close()]]

    db_changed = true
    return {status = "done", detail = "scan successful in updating db content"}
end

--///////////////////////////////////////////////////////////////////////////////////////////////////////

-- Filters and returns only "inventory" type peripherals
local function filter_inventories(connected_peripherals, filter_type)
    local inv_peripherals = {}
    for _, peri in ipairs(connected_peripherals) do
        if peripheral.hasType(peri, filter_type) then
            table.insert(inv_peripherals, peri)
        end
    end
    return inv_peripherals
end

-- Returns all the "inventory" type peripherals found in the stockpile server's network.
function contentdb.list_all_inventories()
    local connected_peripherals = peripheral.getNames()
    all_invs = filter_inventories(connected_peripherals, "inventory")
    table.sort(all_invs)
    return {status = "done", detail = "successfully sent all connected inventories list", data = all_invs}
end

--///////////////////////////////////////////////////////////////////////////////////////////////////////

-- Function to list partially filled slots for the specified item in the given inventory list
function contentdb.get_part_filled_slots(item, invs)
    --checks if the item has a partially filled slot
    if not item_index[item] and not item_index[item].part_filled_slots then
        return nil
    end

    local part_filled = {}

    for _, inv in ipairs(invs) do
        if item_index[item].part_filled_slots and item_index[item].part_filled_slots[inv] then
            local current_inv_content = item_index[item].part_filled_slots[inv]
            for slot, qty in pairs(current_inv_content) do
                table.insert(part_filled, {inv = inv, slot = slot, qty = qty}) --entry of partially filled inv:slot:qty triplet (in normal use there should only be one partially filled entry since stockpile auto stacks everything)
            end
        end
    end

    if not next(part_filled) then
        return nil
    else
        return part_filled
    end
end

--///////////////////////////////////////////////////////////////////////////////////////////////////////

-- Function to handle finding the first empty slot in a given inventory
local function find_empty_slot_in_inventory(inv)
    for slot = 1, inv_index[inv].size do
        if not inv_index[inv].slots then inv_index[inv].slots = {} end
        if not inv_index[inv].slots[slot] then --nothing in this slot, so thats 1st empt slot
            return {inv = inv, slot = slot}
        end
    end
    return nil
end

-- Function to find the first empty slot in the provided inventories
function contentdb.first_empty_slot(invs)

    for _, current_inv in ipairs(invs) do
        if inv_index[current_inv] then

            local empty_slot = find_empty_slot_in_inventory(current_inv)
            if empty_slot then return empty_slot end --returns the inv and slot of first empty slot option
        else
            --the inventory is completly empty, returns the slot #1
            return {current_inv, 1}
        end
    end

    log.warn("Couldn't find any empty slots in specified inventories : Destination inventories are probably full!")
    return nil
end

--///////////////////////////////////////////////////////////////////////////////////////////////////////

-- Helper function to calculate the total quantity for an item
local function calculate_total(item, difference)
    local total = table_utils.try_get_value(item_index, {item, "total"}) or 0
    total = total + difference
    return total < 0 and 0 or total
end

-- Helper function to update content for stack size, inventory size, etc.
local function update_content_tables(inv_id, slot, item, qty, stack_size, inv_size, total, nbt, dispn)

    if table_utils.try_get_value(item_index, {item, "displayName"}) == nil then
        table_utils.set_nested_value(item_index, {item, "displayName"}, dispn)
    end

    if table_utils.try_get_value(inv_index, {inv_id, "size"}) == nil then
        table_utils.set_nested_value(inv_index, {inv_id, "size"}, inv_size)
    end

    table_utils.set_nested_value(inv_index, {inv_id, "slots", slot, item}, qty)
    table_utils.set_nested_value(item_index, {item, "location", inv_id, slot}, qty)

    if table_utils.try_get_value(item_index, {item, "stack_size"}) == nil then
        table_utils.set_nested_value(item_index, {item, "stack_size"}, stack_size)
    end

    if table_utils.try_get_value(item_index, {item, "nbt"}) == nil then
        table_utils.set_nested_value(item_index, {item, "nbt"}, nbt)
    end

    if total == 0 then
        table_utils.set_nested_value(item_index, {item, "total"}, nil)
    else
        table_utils.set_nested_value(item_index, {item, "total"}, total)
    end
end

-- Helper function to update the partially filled slots
local function update_part_filled_slots(item, inv_id, slot, qty, stack_size)
    if qty < stack_size then
        table_utils.set_nested_value(item_index, {item, "part_filled_slots", inv_id, slot}, qty)
    else
        table_utils.set_nested_value(item_index, {item, "part_filled_slots", inv_id, slot}, 0)
    end
end

-- Main update function
function contentdb.update(inv_id, slot, item, qty, stack_size, inv_size, nbt, dispn)

    stack_size = stack_size or table_utils.try_get_value(item_index, {item, "stack_size"})
    local existing_qty = table_utils.try_get_value(inv_index, {inv_id, "slots", slot, item}) or 0
    local difference = qty - existing_qty

    -- Calculate the new total
    local total = calculate_total(item, difference)

    -- Update the content tables
    update_content_tables(inv_id, slot, item, qty, stack_size, inv_size, total, nbt, dispn)

    -- Update the part filled slots
    update_part_filled_slots(item, inv_id, slot, qty, stack_size)

    -- Clean up empty tables
    table_utils.cleanup_empty_tables(inv_index, {inv_id, "slots", slot, item})
    table_utils.cleanup_empty_tables(item_index, {item, "location", inv_id, slot})
    table_utils.cleanup_empty_tables(item_index, {item, "total"})
    table_utils.cleanup_empty_tables(item_index, {item, "part_filled_slots", inv_id, slot})

    -- Remove item entry if it only contains "stack_size" and "total"
    if table_utils.length(item_index[item]) == 2 then
        item_index[item] = nil
    end
end

--Returns the total amount of slots and occupied slots in the storage.
--May not be 100% accurate as it doesn't account for multiple partially filled slots.
--It also counts used slots of none storage inventories (inputs, outputs etc...).
function contentdb.usage()
    local all_slots, used_slots = 0, 0

    for _, inv in ipairs(all_invs) do
        all_slots = all_slots + (table_utils.try_get_value(inv_index, {inv, "size"}) or 0)
    end

    for _, item_table in pairs(item_index) do
        if item_table.total and item_table.stack_size then
            used_slots = used_slots + math.floor(item_table.total / item_table.stack_size + 0.99)
        end
    end

    return {status = "done", detail = "successfully calculated usage of storage", data = {total_slots = all_slots, used_slots = used_slots}}
end

--Searches and returns a list of all the matching items held in storage. Uses regex expressions.
function contentdb.search(name_search, nbt_search)
    local result = {}
    name_search = name_search or ""

    for item_name, item in pairs(item_index) do
        local nbt
        if item.nbt then
            nbt = nbt_search and table.concat(item.nbt)
        end

        if string.match(item_name, name_search) and (not nbt_search or string.match(nbt, nbt_search)) then
            result[item_name] = table_utils.try_get_value(item_index, {item_name, "total"})
        end
    end

    return {status = "done", detail = "successfully searched db for specified filters", data = result}
end

-- Returns the first found location (inv = inv, slot = slot, qty = qty) of a given item
local function get_first_location(item)
    if not item_index[item] or not item_index[item].location then return end
    local inv, loc = next(item_index[item].location)
    local slot, qty = next(loc)
    return {inv = inv, slot = slot, qty = qty}
end

function contentdb.get_nbt(item_id)
    local loc = get_first_location(item_id)
    local nbt = peripheral.call(loc.inv, "getItemDetail", loc.slot)
    return {status = "done", detail = "successfully got nbt for specified item id", data = nbt}
end

function contentdb.get_content()
    return {status = "done", detail = "successully sends entire db content", data = {item_index = item_index, inv_index = inv_index}}
end

return contentdb