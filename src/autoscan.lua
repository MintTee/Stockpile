local queue = require("/stockpile/src/queue")
local contentdb = require("/stockpile/src/contentdb")
require("/stockpile/var/globals")

local INTERVAL = 3 --Interval for autoscan in seconds
local toggle, io_content, io_content_bis = true, {}, {}

local function compare_io_contents()
    local current, previous = toggle and io_content or io_content_bis, toggle and io_content_bis or io_content
    local to_rescan = {}
    for inv, total in pairs(current) do
        if previous[inv] ~= total then table.insert(to_rescan, inv) end
    end
    return to_rescan
end

local function scan_inv(inv)
    local total = 0
    for _, item in pairs(peripheral.call(inv, "list") or {}) do
        total = total + (item.count or 0)
    end
    (toggle and io_content or io_content_bis)[inv] = total
end

--Lightweight way to dynamically rescan units marked as "io". It can scan up to 2000 inventories per second
--and order a real rescan of the ones that changed content recently (eg. Player or hopper interaction)
local function autoscan()
    while true do

        local timer_id = os.startTimer(INTERVAL)
        local event, id
        repeat
            event, id = os.pullEvent("timer")
        until id == timer_id

        logger("Debug", "autoscan","Running an autoscan")

        for unit, _ in pairs(units) do
            if units[unit]["io"] then
                for _, inv in ipairs(units[unit]) do
                    queue.add(scan_inv, inv)
                end
            end
        end
        queue.run()

        toggle = not toggle
        local to_rescan = compare_io_contents()
        if #to_rescan > 0 then contentdb.scan(to_rescan) end
    end
end

return autoscan
