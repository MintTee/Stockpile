local data = require("/stockpile/src/data_manager")
require("/stockpile/var/globals")

-- Define the maximum size for the logs table
local MAX_LOG_SIZE = 300
local SAVE_INTERVAL = 30
local log_start = 1
local log_count = #logs
local log_entries_since_last_save = 0

-- If the logs are pre-loaded and exceed MAX_LOG_SIZE, adjust the starting point and count
if log_count > MAX_LOG_SIZE then
    log_start = log_count - MAX_LOG_SIZE + 1
    log_count = MAX_LOG_SIZE
end

function logger(log_type, caller, desc, detail)
    if logger_config[log_type] == true then
        if not detail then
            detail = ""
        end
        local log_line = "[MC time:"..os.time().."|Uptime:"..os.clock().."] | "..caller.." | "..log_type.." : "..desc.." : "..detail
        add_log(log_line)
        print(log_line)
    end
end

-- Logger function to add a new log entry
function add_log(entry)
    if log_count < MAX_LOG_SIZE then
        log_count = log_count + 1
    else
        -- Overwrite the oldest entry
        log_start = (log_start % MAX_LOG_SIZE) + 1
    end
    logs[(log_start + log_count - 1) % MAX_LOG_SIZE + 1] = entry
    log_entries_since_last_save = log_entries_since_last_save + 1

    -- Auto-save logs if the save interval is reached
    if log_entries_since_last_save >= SAVE_INTERVAL then
        save_logs()
        log_entries_since_last_save = 0
    end
end

-- Function to retrieve all log entries in order
function get_logs()
    local result = {}
    for i = 1, log_count do
        result[i] = logs[(log_start + i - 1) % MAX_LOG_SIZE + 1]
    end
    return result
end

-- Function to save the logs back to the file
function save_logs()
    data.save("/stockpile/logs/logs.txt", logs)
end

return logger