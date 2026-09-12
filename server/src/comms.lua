--Server comms
local move_item = require("/stockpile_server/src/move_item")
local contentdb = require("/stockpile_server/src/contentdb")
local log = require("/stockpile_server/src/log")
require("/stockpile_server/var/globals")

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

-- Sends a response back to a client. The message always carries the `uuid`
-- (so the client can match it against the pending request) and a `result`
-- table (so the client's callback fires with *something*, even on error).
local function send_response(recipient, uuid, result)
    rednet.send(recipient, { uuid = uuid, result = result }, "stockpile")
end

-- Receives a command and adds it to the command queue if valid.
-- Malformed commands get an immediate error response so the client's
-- pending entry is resolved instead of silently timing out.
local function receive_command(cmd_queue)
    local id, cmd = rednet.receive("stockpile")

    local valid = type(cmd) == "table"
        and type(cmd.type) == "string"
        and type(cmd.args) == "table"
        and type(cmd.uuid) == "number"

    if not valid then
        log.error("Received command in wrong format from " .. tostring(id))
        -- Best-effort error response if we at least have a uuid to match against
        if type(cmd) == "table" and type(cmd.uuid) == "number" then
            send_response(id, cmd.uuid, { status = "fail", detail = "wrong argument format" })
        end
        return
    end

    cmd.sender = id
    table.insert(cmd_queue, cmd)
end

-- Runs the handler for a command type, catching errors and normalising the
-- return value so the client always receives a table with a `status` field.
local function run_handler(cmd_type, args)
    local handler = handlers[cmd_type]
    if not handler then
        log.warn("Unknown command type: " .. tostring(cmd_type))
        return { status = "fail", detail = "unknown command type: " .. tostring(cmd_type) }
    end

    local ok, result = pcall(handler, args)
    if not ok then
        log.error("Handler '" .. tostring(cmd_type) .. "' crashed: " .. tostring(result))
        return { status = "fail", detail = "handler error: " .. tostring(result) }
    end

    if type(result) ~= "table" then
        return { status = "fail", detail = "handler returned non-table result" }
    end

    return result
end

-- Processes a command from the queue and sends the result back to the client.
local function process_command(cmd_queue)
    if #cmd_queue > 0 then
        local cmd = table.remove(cmd_queue, 1)

        log.debug("cmd received = " .. textutils.serialise(cmd.type))

        local result = run_handler(cmd.type, cmd.args)

        send_response(cmd.sender, cmd.uuid, result)

        log.debug("Results : " .. textutils.serialise(result.status or "?"), cmd.uuid)
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
    if (item and type(item) ~= "string") or (nbt and type(nbt) ~= "string") then
        return {status = "fail", detail = "wrong argument format"}
    end
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