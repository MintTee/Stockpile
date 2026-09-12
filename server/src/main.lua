local comms = require("/stockpile_server/src/comms")
local log = require("/stockpile_server/src/log")
local contentdb = require("/stockpile_server/src/contentdb")
local bin = require("/stockpile_server/src/bin")
require("/stockpile_server/var/globals")

local function main()
    term.clear()
    term.setCursorPos(1, 1)
    log.info("[Stockpile server initializing...]\n")

    log.info("Loading database from the binary file on disk...")
    bin.decode_db()
    log.info("Loading success")

    contentdb.list_all_inventories()
    log.info("Listed all available inventories to the server")

    log.trace('Rednet : Hosting the "stockpile" protocol under the the id: '..tostring(os.getComputerID()).."\n")
    rednet.host("stockpile", tostring(os.getComputerID()))

    comms.open_all_modems()
    log.info("Opened all modems in the network")

    --period in second to encode and save the db bin
    local DB_BIN_SAVE_INTERVAL = 5

    parallel.waitForAll(
        function() while true do comms.wait_for_command() end end,
        function() while true do log.flush() sleep(3) end end,
        function()
            while true do
                if db_changed == true then
                    bin.encode_db()
                    db_changed = false
                end
                sleep(DB_BIN_SAVE_INTERVAL)
            end
        end
    )
end

--local res = peripheral.call("minecraft:chest_10", "pushItems", "minecraft:chest_0", 1, 56, 2)
main()