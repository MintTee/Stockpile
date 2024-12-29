local comms = require("/stockpile/src/comms")
local logger = require("/stockpile/src/logger")

function main()
    term.clear()
    term.setCursorPos(1, 1)
    print("[Stockpile initializing...]\n")
    logger("Info", "main", "main function called", "Stockpile initializing... Listening for client command")
    local opened_modem = comms.open_all_modems()
    if opened_modem == true then comms.wait_for_command() end    
end

main()