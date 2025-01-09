local move_item = require("/stockpile/src/move_item")
local contentdb = require("/stockpile/src/contentdb")
local logger = require("/stockpile/src/logger")
require("/stockpile/var/globals")

-- Environment for the modules
local default_env = {
    move_item = move_item,
    --check = contentdb.check, --DEPRECATED METHOD
    scan = contentdb.scan,
    --list_all_inventories = contentdb.list_all_inventories, --DEPRECATED METHOD
    search = contentdb.search,
    usage = contentdb.usage,
    unit = contentdb.unit,
    get_nbt = contentdb.get_nbt,
    get_content = contentdb.get_content,
    units = units,
}

local comms = {}

-- Main function that waits for commands and processes them concurrently
function comms.wait_for_command()
    logger("Debug", "wait_for_command", "Waiting for a client to send a command...")
    local cmd_queue = {}

    parallel.waitForAny(
        function() while true do receive_command(cmd_queue) end end,
        function() while true do process_command(cmd_queue) end end
    )
end

-- Receives a command and adds it to the command queue if valid
function receive_command(cmd_queue)
    local sender_id, message = rednet.receive("stockpile")
    if type(message) ~= "string" and type(message) ~= "table" then
        logger("Error", "receive_command", "Improper command recieved", "Command needs to be a table or a string type.")
        rednet.send(sender_id, "Improper command recieved. Command needs to be a table or a string type. Consult the API for the proper syntax.", "stockpile")
        return
    end

    if type(message) == "string" then message = {message} end
    if not message[2] then message[2] = 1 end --Sets the UUID to 1 of none is provided

    if sanitize_input(message[1]) == true then
        logger("Info", "receive_command", "Command recieved", message[1].." UUID: "..message[2].." from computer id #"..sender_id)
        table.insert(cmd_queue, {cmd = message[1], UUID = message[2], sender_id = sender_id})
    else
        logger("Warn", "receive_command", "Improper command recieved.", "Didn't pass the sanitization step.")
        rednet.send(sender_id, "Improper command recieved. Consult the API for the proper syntax.", "stockpile")
    end
end

-- Processes a command from the queue and sends the result back
function process_command(cmd_queue)
    if #cmd_queue > 0 then
        local cmd_info = table.remove(cmd_queue, 1)
        logger("Info", "wait_for_command", "Executing command", cmd_info.cmd)
        local result = execute_chunk(cmd_info.cmd)
        rednet.send(cmd_info.sender_id, {result, cmd_info.UUID}, "stockpile")
        logger("Info", "wait_for_command", "Returned results to client")
    else
        os.sleep(0.1)
    end
end

-- Function to execute a chunk with the default environment
function execute_chunk(chunk_str)
    -- Load the chunk with the default environment
    local chunk, err = load("return " .. chunk_str, "chunk", "t", default_env)
    if not chunk then
        return "Error : execute_chunk : Invalid method name. Refer to the Stockpile API wiki for the proper syntaxe."
    end

    local status, result_or_err = pcall(chunk)
    
    if not status then
        return "Error : execute_chunk : Internal error, couldn't execute the method properly. "..result_or_err
    end
    
    -- Return the result of the executed chunk
    return result_or_err
end

-- Function to sanitize user input
function sanitize_input(user_input)
    -- Define the keys from the default_env table
    local valid_keys = {
        ["move_item" ]= true,
        --check = true, --DEPRECATED METHOD
        ["scan"] = true,
        --["list_all_inventories"] = true, --DEPRECATED METHOD
        ["search"] = true,
        ["usage"] = true,
        ["unit.add"] = true,
        ["unit.remove"] = true,
        ["unit.set"] = true,
        ["unit.is_io"] = true,
        ["unit.get"] = true,
        ["get_nbt"] = true,
        ["get_content"] = true,
    }

    local function_part = string.match(user_input, "^(.-)%(")

    -- Return true if the key is found in the valid_keys table, otherwise return false
    if valid_keys[function_part] == true then
        return true
    else
        return false
    end
end

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
        logger("Warn", "open_all_modems", "No modem found in the network", "Can't communicate with other computers.")
        return false
    else
        return true
    end
end

return comms