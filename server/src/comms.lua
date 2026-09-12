--Server comms
local move_item = require("/stockpile_server/src/move_item")
local contentdb = require("/stockpile_server/src/contentdb")
local log = require("/stockpile_server/src/log")
require("/stockpile_server/var/globals")

--[[    EXAMPLE STRUCTURE OF COMMAND FROM A CLIENT

invs = {minecraft:chest_1, minecraft:chest_2}
rednet.send(
    server_id,
    {
        type = "scan",
        args = {invs, "arg2", 123},
        uuid = 123,
    },
    "stockpile"
    
)

]]

local comms = {}
local handlers = {}

--Opens all modems found in the network
function comms.open_all_modems()
    local connected_peripherals = peripheral.getNames()
    local modem_found = false

    for _, peri in ipairs(connected_peripherals) do
        if peripheral.hasType(peri, "modem") then
            rednet.open(peri)
            modem_found = true
        end
    end

    if modem_found == false then
        log.warn("No modem found in the network, Can't communicate with other computers.")
        return false
    else
        return true
    end
end

-- Receives a command and adds it to the command queue if valid
local function receive_command(cmd_queue)
    local id, cmd = rednet.receive("stockpile")

    --check types, early return
    if type(cmd.type) ~= "string" or (cmd.arg and type(cmd.arg) ~= "table") or type(cmd.uuid) ~= "number" then
        log.error("Recieved command in wrong format")
        return
    end

    cmd.sender = id --adds the sender to the body of the cmd
    table.insert(cmd_queue, cmd)
end

-- Processes a command from the queue and sends the result back to the client
local function process_command(cmd_queue)
    if #cmd_queue > 0 then
        local cmd = table.remove(cmd_queue, 1)

        local handler = handlers[cmd.type]
        if handler then
            log.debug("cmd recieved = "..textutils.serialise(cmd.type))
            cmd.result = handler(cmd.args)
            rednet.send(cmd.sender, cmd, "stockpile") --respondes with the same message table + new result field
            log.debug("Results : "..textutils.serialise(cmd.result.status), cmd.uuid)
        end
    end
    sleep(0.05)
end

-- Main function that waits for commands and processes them concurrently
function comms.wait_for_command()
    log.info("Waiting for a client to send a command...")
    local cmd_queue = {}

    parallel.waitForAny(
        function() while true do receive_command(cmd_queue) end end,
        function() while true do process_command(cmd_queue) end end
    )
end

-- /////////// API Handles ////////////

handlers.scan = function(args)
    local invs = table.unpack(args)
    if type(invs) ~= "table" then return {status = "fail", detail = "wrong argument format"} end
    return contentdb.scan(invs)
end

handlers.move_item = function(args)
    local from_invs, to_invs, item, qty, nbt = table.unpack(args)
    if
        type(from_invs) ~= "table"
        or type(to_invs) ~= "table"
        or (item and (type(item) ~= "string" and type(item) ~= "table"))
        or (qty and type(qty) ~= "number")
        or (nbt and type(nbt) ~= "string") then
        return {status = "fail", detail = "wrong argument format"}
    end

    return move_item(from_invs, to_invs, item, qty, nbt)
end
handlers.search = function(args)
    local item, nbt = table.unpack(args)
    if (item and type(item) ~= "string") or (nbt and type(nbt) ~= "string") then return {status = "fail", detail = "wrong argument format"} end
    return contentdb.search(item, nbt)
end
handlers.usage = function()
    return contentdb.usage()
end
handlers.get_nbt = function(args)
    local item_id = table.unpack(args)
    if type(item_id) ~= "string" then return {status = "fail", detail = "wrong argument format"} end
    return contentdb.get_nbt(item_id)
end
handlers.list_all_inventories = function()
    return contentdb.list_all_inventories()
end
handlers.get_content = function()
    return contentdb.get_content()
end

return comms