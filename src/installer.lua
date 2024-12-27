local files = {
    "config/logger_config.txt",
    "database/content.txt",
    "database/inventories.txt",
    "src/comms.lua",
    "src/contentdb.lua",
    "src/data_manager.lua",
    "src/logger.lua",
    "src/main.lua",
    "src/move_item.lua",
    "src/queue.lua",
    "src/table_utils.lua",
}

for _, file in ipairs(files) do
    local url = "https://raw.githubusercontent.com/MintTee/Stockpile/refs/heads/main/" .. file
    local response = http.get(url)
    if response then
        local content = response.readAll()
        response.close()
        local localFile = fs.open(file, "w")
        localFile.write(content)
        localFile.close()
        print(file .. " downloaded successfully!")
    else
        print("Failed to download " .. file)
    end
end

io.open("config/client_id_whitelist.txt", 'w'):write("{}"):close()
io.open("database/content.txt", 'w'):write("{}"):close()
io.open("database/inventories.txt", 'w'):write("{}"):close()
io.open("logs/logs.txt", 'w'):close()


--[[
local writeStartup
while writeStartup == nil do
  print('Run SIGILS when the computer starts up? (press y/n)')
  print('(If not, you must manually restart SIGILS if the chunk is unloaded.)')
  local event, char = os.pullEvent('char')
  print(char)
  if string.lower(char) == 'y' then
    writeStartup = true
  elseif string.lower(char) == 'n' then
    writeStartup = false
  end
end

if writeStartup then
  print('SIGILS will now run on startup.')
  io.open('startup', 'w'):write("shell.run('.sigils/sigils.lua')"):close()
end
]]