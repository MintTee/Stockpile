local files = {
    "stockpile/config/logger_config.txt",
    "stockpile/database/content.txt",
    "stockpile/database/inventories.txt",
    "stockpile/src/comms.lua",
    "stockpile/src/contentdb.lua",
    "stockpile/src/data_manager.lua",
    "stockpile/src/logger.lua",
    "stockpile/src/main.lua",
    "stockpile/src/move_item.lua",
    "stockpile/src/queue.lua",
    "stockpile/src/table_utils.lua",
}
local install_success = true

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
        install_success = false
    end
end

io.open("stockpile/config/client_id_whitelist.txt", 'w'):write("{}"):close()
io.open("stockpile/database/content.txt", 'w'):write("{}"):close()
io.open("stockpile/database/inventories.txt", 'w'):write("{}"):close()
io.open("stockpile/logs/logs.txt", 'w'):close()

local write_startup
while write_startup == nil do
  print('Run Stockpile when the computer starts up? (press y/n)')
  print('(If not, you must manually restart Stockpile if the chunk the computer is in is unloaded.)')
  local event, char = os.pullEvent('char')
  print(char)
  if string.lower(char) == 'y' then
    write_startup = true
  elseif string.lower(char) == 'n' then
    write_startup = false
  end
end

if write_startup then
  print('Stockpile will now run on startup.')
  io.open('startup', 'w'):write("shell.run('.sigils/sigils.lua')"):close()
end

if install_success == true then
    print("Stockpile was successfully installed !")

    if write_startup == true then
        print("Restarting the computer in")
        print("3")
        sleep(1)
        print("2")
        sleep(1)
        print("1")
        sleep(1)
        os.reboot()
    else
        print("To manually start Stockpile, run the program : '/stockpile/src/main.lua'")
    end
else
    print("Couldn't properly download every file. If the problem persists, Open a new issue on the Stockpile's GitHub page :\n https://github.com/MintTee/Stockpile")
    sleep(3)
end