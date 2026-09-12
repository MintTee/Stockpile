-- /stockpile_client/src/comms.lua
local basalt = require("lib.basalt")

local protocol  = "stockpile"
local server_id = nil
local pending   = {}

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

function comms.send(kind, args, callback)
    assert(server_id, "comms.send: server_id not set (call comms.init() first)")
    local uuid = gen_uuid()
    rednet.send(server_id, { type = kind, args = args, uuid = uuid }, protocol)
    pending[uuid] = { callback = callback, timer = os.startTimer(10) }
end

local function handle_response(msg)
    local entry = pending[msg.uuid]
    if not entry then return end
    os.cancelTimer(entry.timer)
    pending[msg.uuid] = nil
    if entry.callback then entry.callback(msg.result) end
end

function comms.onRednetMessage(_, message, protocolName)
    if protocolName ~= protocol then return end
    if not message.uuid or not pending[message.uuid] then return end
    handle_response(message)
end

function comms.onTimer(timerID)
    for uuid, entry in pairs(pending) do
        if entry.timer == timerID then
            if entry.callback then entry.callback(nil) end
            pending[uuid] = nil
        end
    end
end

function comms.init()
    find_server()
    basalt.onEvent("rednet_message", comms.onRednetMessage)
    basalt.onEvent("timer", comms.onTimer)
end

function comms.getContentAsync(app, callback)
    comms.send("get_content", {}, function(result)
        if result and result.status == "done" and result.data then
            app.item_index = result.data.item_index
            app.inv_index  = result.data.inv_index
            basalt.triggerEvent("content_updated")
        end
        if callback then callback(result) end
    end)
end

function comms.listAllInventoriesAsync(app, callback)
    comms.send("list_all_inventories", {}, function(result)
        if result and result.status == "done" and result.data then
            table.sort(result.data)
            app.groups.all = result.data
        end
        if callback then callback(result) end
    end)
end

function comms.moveItemAsync(from_invs, to_invs, item, qty, callback)
    comms.send("move_item", { from_invs, to_invs, item, qty }, callback)
end

function comms.scanAsync(invs, callback)
    comms.send("scan", { invs }, callback)
end

return comms