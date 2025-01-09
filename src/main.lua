local comms = require("/stockpile/src/comms")
local logger = require("/stockpile/src/logger")
local contentdb = require("/stockpile/src/contentdb")
local autoscan = require("/stockpile/src/autoscan")
require("/stockpile/var/globals")

local function get_floppy_disks()
    local disks = {}
    for _, entry in ipairs(fs.list("/")) do
        if entry:match("^disk%d*$") then table.insert(disks, "/" .. entry .. "/") end
    end
    return disks
end

local function calculate_capacity(disk_count)
    return disk_count * 125 / 2 * 1000
end

local function main()
    term.clear()
    term.setCursorPos(1, 1)
    print("[Stockpile initializing...]\n")

    local disks = get_floppy_disks()
    if #disks == 0 then
        print("No disk drives with floppy disks found.\nStockpile requires floppy disks for data storage (~75,000 items per disk).\nA storage system for 1 million items needs ~16 disks.\n")
        return
    end

    print('Rednet : Hosting the "stockpile" protocol under the the id: '..tostring(os.computerID()).."\n")
    rednet.host("stockpile", tostring(os.computerID()))

    print(("%d floppy disks found. Stockpile can store data for ~ %d items.\n"):format(#disks, calculate_capacity(#disks)))
    print("Autoscan I/O running.")
    print("Opened all modems in the network.\n")
    
    logger("Info", "main", "Stockpile initialized...", "Listening for client commands")
    if next(units) == nil then contentdb.unit.get() end

    if comms.open_all_modems() then
        parallel.waitForAny(comms.wait_for_command, autoscan)
    end
end

main()