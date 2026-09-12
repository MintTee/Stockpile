-- client/src/comms.lua
local log = dofile("/stockpile_client/lib/log.lua")
local protocol = "stockpile"
local server_id = nil
local pending = {}          -- uuid -> { callback, timer }
local basalt = nil

local comms = {}

local function gen_uuid()
    return math.random(1, 2^16)
end

local function open_all_modems()
    for _, peri in ipairs(peripheral.getNames()) do
        if peripheral.hasType(peri, "modem") then
            rednet.open(peri)
        end
    end
end

local function find_server()
    while not server_id do
        open_all_modems()
        server_id = rednet.lookup(protocol)
        if not server_id then
            print("Looking for stockpile server...")
            sleep(5)
        end
    end
    print("Server found, ID: " .. tostring(server_id))
end

-- Send a command; callback will be called with the result (or nil on timeout)
function comms.send(type, args, callback)
    local uuid = gen_uuid()
    local msg = { type = type, args = args, uuid = uuid }
    rednet.send(server_id, msg, protocol)

    local timer = os.startTimer(10)   -- 10 second timeout
    pending[uuid] = { callback = callback, timer = timer }
end

-- Internal: dispatch an incoming response
local function handle_response(msg)
    local uuid = msg.uuid
    local entry = pending[uuid]
    if not entry then return end

    os.cancelTimer(entry.timer)
    pending[uuid] = nil

    if entry.callback then
        entry.callback(msg.result)
    end
end

-- Called on every "rednet_message" event
function comms.onRednetMessage(sender, message, protocolName)
    if protocolName ~= protocol then return end
    if not message.uuid or not pending[message.uuid] then return end
    handle_response(message)
end

-- Called on every "timer" event
function comms.onTimer(timerID)
    for uuid, entry in pairs(pending) do
        if entry.timer == timerID then
            if entry.callback then entry.callback(nil) end
            pending[uuid] = nil
        end
    end
end

-- Initialise the module: find server and hook into Basalt's event system
function comms.init(bas)
    basalt = bas
    find_server()

    -- Register event listeners using basalt.onEvent (global function)
    basalt.onEvent("rednet_message", function(sender, message, protocolName)
        comms.onRednetMessage(sender, message, protocolName)
    end)
    basalt.onEvent("timer", function(timerID)
        comms.onTimer(timerID)
    end)
end

-- Async helpers for your application
function comms.getContentAsync(app, callback)
    comms.send("get_content", {}, function(result)
        if result then
            app.item_index = result.data.item_index
            app.inv_index = result.data.inv_index
        end
        if callback then callback(result) end
    end)
end

function comms.listAllInventoriesAsync(app, callback)
    comms.send("list_all_inventories", {}, function(result)
        if result then
            table.sort(result.data)
            app.groups.all = result.data
        end
        if callback then callback(result) end
    end)
end

function comms.moveItemAsync(from_invs, to_invs, item, qty, nbt, callback)
    comms.send("move_item", {from_invs, to_invs, item, qty, nbt}, callback)
end

return comms