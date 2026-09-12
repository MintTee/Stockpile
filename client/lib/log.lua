-- log.lua
-- Persistent circular buffer (max 150 lines), flush writes everything at once.

local log = {}
log.usecolor = true
log.outfile = "/stockpile_testing/log/client.log"
log.level = "trace"
log.max_lines = 300

local buf = {}
local head = 0
local count = 0

local modes = {
  { name = "trace", color = "\27[34m" },
  { name = "debug", color = "\27[36m" },
  { name = "info",  color = "\27[32m" },
  { name = "warn",  color = "\27[33m" },
  { name = "error", color = "\27[31m" },
  { name = "fatal", color = "\27[35m" },
}

local levels = {}
for i, v in ipairs(modes) do levels[v.name] = i end

local round = function(x, increment)
  increment = increment or 1
  x = x / increment
  return (x > 0 and math.floor(x + .5) or math.ceil(x - .5)) * increment
end

local _tostring = tostring
local tostring = function(...)
    local t = {}
    for i = 1, select('#', ...) do
        local x = select(i, ...)
        if type(x) == "number" then x = round(x, .01) end
        t[#t + 1] = _tostring(x)
    end
    return table.concat(t, " ")
end

for i, x in ipairs(modes) do
    local nameupper = x.name:upper()
    log[x.name] = function(...)
    if i < levels[log.level] then return end

        local msg = tostring(...)
        local info = debug.getinfo(2, "Sl")
        local lineinfo = info.short_src .. ":" .. info.currentline

        print(string.format("[%s]%-6s", nameupper, " " .. msg))

        if log.outfile then
            local str = string.format("[%-6s%s] %s: %s\n", nameupper, os.date(), lineinfo, msg)
            head = (head % log.max_lines) + 1
            buf[head] = str
            if count < log.max_lines then
            count = count + 1
            end
        end
    end
end

-- Write all buffered lines to the file in chronological order. The queue is NOT reset – file always contains the last up to max_lines lines.
function log.flush()
    if log.outfile and count > 0 then
    local fp = io.open(log.outfile, "w")
        if fp then
            -- Build output in order (oldest first)
            local start = head - count + 1
            for i = 1, count do
                local idx = ((start + i - 2) % log.max_lines) + 1
                fp:write(buf[idx])
            end
            fp:close()
        end
    end
end

return log