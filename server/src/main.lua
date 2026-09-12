--[[

//////////////// TO DO LIST ////////////////

- Bug when I scan all invs and update db and then idk why I lose the displayName on the client side for some wierd reasons, when restarting server and loading from bin db, it works again idk why. 

- write super test function to do all API commands at once (from client testing)
    -get all invs, scan all invs, write db, load db, 

- Test queue functions and see how much they can transfer at once.
    test max transfer speed (parallel transfers)

- fractionnal db bin in multiple floppy disks for super large storages

]]

local comms = require("/stockpile_server/src/comms")
local log = require("/stockpile_server/src/log")
local contentdb = require("/stockpile_server/src/contentdb")
local bin = require("/stockpile_server/src/bin")
require("/stockpile_server/var/globals")

local function get_floppy_disks()
    local disks = {}
    for _, entry in ipairs(fs.list("/")) do
        if entry:match("^disk%d*$") then table.insert(disks, "/" .. entry .. "/") end
    end
    return disks
end

--obsolete
local function calculate_capacity(disk_count)
    return disk_count * 125 / 2 * 1000
end

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