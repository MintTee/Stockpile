local comms = require("/stockpile/src/comms")
local logger = require("/stockpile/src/logger")
local data = require("/stockpile/src/data_manager")
local contentdb = require("/stockpile/src/contentdb")
local autoscan = require("/stockpile/src/autoscan")
require("/stockpile/var/globals")

function main()
    term.clear()
    term.setCursorPos(1, 1)
    print("[Stockpile initializing...]\n")

    local disks = {}  -- Collect available disks
    for _, entry in ipairs(fs.list("/")) do
        if entry:match("^disk%d+$") or entry:match("^disk$") then
            table.insert(disks, "/" .. entry .. "/")
        end
    end

    if #disks == 0 then
        print("No disk drives containing floppy disks were found in the network.\nStockpile requires disk drives with floppy disks inside them to store large amount of data.\nOne floppy disk can hold data for ~75,000 items.\nFor example, if you plan to have a storage system with a capacity of 1 million items, you will need 16 floppy disks.")
        return
    end

    --1,000 items (64 stacked) is ~2Kb of data to be stored to disk
    local max_capacity_storage = #disks * 125 / 2 * 1000
    print(#disks.." floppy disks were found in the network, Stockpile can currently store the data of ~ "..max_capacity_storage.." items. \n")
    print("Opened all modems in the network.\n")
    
    logger("Info", "main", "main function called", "Stockpile initializing... Listening for client command")
    if units == {} then contentdb.unit.get() end

    if comms.open_all_modems() == true then
        parallel.waitForAny(
            comms.wait_for_command,
            autoscan
        )
    end
end

main()