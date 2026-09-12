-- /installer.lua
-- Stockpile V2 unified installer
-- Usage: wget run https://raw.githubusercontent.com/MintTee/Stockpile/refs/heads/main/installer.lua

local REPO   = "MintTee/Stockpile"
local BRANCH = "main"
local BASE   = "https://raw.githubusercontent.com/" .. REPO .. "/refs/heads/" .. BRANCH .. "/"
local ROOT   = "stockpile"          -- top-level install folder

-- =====================================================================
-- File manifests
--
-- Paths are relative to the repo root. The first path segment
-- ("client/" or "server/") is stripped when writing to disk, so
-- "client/ui/search_tab.lua" lands at "stockpile/ui/search_tab.lua".
--
-- Only code files are downloaded. Documentation, icons, and other
-- non-runtime assets stay on GitHub and are not installed.
-- =====================================================================

local CLIENT_FILES = {
    "client/app.lua",
    "client/main.lua",
    "client/config/groups.txt",
    "client/lib/basalt.lua",
    "client/lib/log.lua",
    "client/logic/groups.lua",
    "client/logic/move.lua",
    "client/logic/search.lua",
    "client/logic/usage.lua",
    "client/src/comms.lua",
    "client/src/data.lua",
    "client/src/string_utils.lua",
    "client/src/table_utils.lua",
    "client/ui/automation_parser.lua",
    "client/ui/automation_tab.lua",
    "client/ui/components.lua",
    "client/ui/dropdown_utils.lua",
    "client/ui/group_tab.lua",
    "client/ui/help_tab.lua",
    "client/ui/search_tab.lua",
}

local SERVER_FILES = {
    "server/bin/db.bin",
    "server/bin/dict.bin",
    "server/lib/bitstream.lua",
    "server/lib/LibDeflate.lua",
    "server/src/bin.lua",
    "server/src/comms.lua",
    "server/src/contentdb.lua",
    "server/src/data_manager.lua",
    "server/src/dict.lua",
    "server/src/log.lua",
    "server/src/main.lua",
    "server/src/move_item.lua",
    "server/src/queue.lua",
    "server/src/string_utils.lua",
    "server/src/table_utils.lua",
    "server/var/globals.lua",
}

-- =====================================================================
-- Helpers
-- =====================================================================

--- Recursively create directories. CC:Tweaked's fs.makeDir does not
--- create parent directories, so we walk the path one level at a time.
local function ensure_dir(path)
    local parts = {}
    for part in path:gmatch("[^/]+") do
        parts[#parts + 1] = part
    end
    local current = ""
    for _, part in ipairs(parts) do
        current = current .. "/" .. part
        if not fs.exists(current) then
            fs.makeDir(current)
        end
    end
end

--- Download one file from `url` to `local_path`. Returns (true) on
--- success, (false, err) on failure.
local function download_file(url, local_path)
    ensure_dir(fs.getDir(local_path))
    local response = http.get(url)
    if not response then
        return false, "HTTP request failed"
    end
    local content = response.readAll()
    response.close()
    if content == nil or content == "" then
        return false, "empty response"
    end
    local f = fs.open(local_path, "w")
    if not f then
        return false, "cannot open " .. local_path
    end
    f.write(content)
    f.close()
    return true
end

--- Show a single-character prompt and return the matching value from
--- `valid` (a table of {char = value}). Loops until a valid char.
local function prompt(question, valid)
    while true do
        print(question)
        local _, char = os.pullEvent("char")
        char = char:lower()
        if valid[char] then
            return valid[char]
        end
    end
end

--- Write an empty file (used for logs and default configs).
local function touch(path)
    ensure_dir(fs.getDir(path))
    local f = fs.open(path, "w")
    if f then f.close() end
end

-- =====================================================================
-- Main
-- =====================================================================

print("=========================================")
print("        Stockpile V2 installer")
print("=========================================")
print("")
print("  [c] Client   - the UI computer")
print("  [s] Server   - the storage/inventory host")
print("  [q] Quit")
print("")

local choice = prompt("Choose an option (c/s/q):",
    { c = "client", s = "server", q = "quit" })

if choice == "quit" then
    print("Installation cancelled.")
    return
end

local files
if choice == "client" then
    files = CLIENT_FILES
else
    files = SERVER_FILES
end

-- If the install folder already exists, ask before clobbering it.
if fs.exists(ROOT) then
    print("")
    print("Directory '" .. ROOT .. "' already exists.")
    local overwrite = prompt("Overwrite existing install? (y/n):",
        { y = true, n = false })
    if not overwrite then
        print("Installation cancelled.")
        return
    end
end

ensure_dir(ROOT)

-- --- Component files --------------------------------------------------

print("")
print("Downloading " .. choice .. " files...")

local ok_count, fail_count = 0, 0

for _, file in ipairs(files) do
    local rel        = file:gsub("^[^/]+/", "")  -- strip client/ or server/
    local local_path = ROOT .. "/" .. rel
    local ok, err    = download_file(BASE .. file, local_path)
    if ok then
        print("  OK   " .. rel)
        ok_count = ok_count + 1
    else
        print("  FAIL " .. rel .. " (" .. tostring(err) .. ")")
        fail_count = fail_count + 1
    end
end

-- --- Runtime files ----------------------------------------------------
-- Logs and per-machine configs should start empty; we never ship the
-- dev's logs or user groups.

if choice == "server" then
    touch(ROOT .. "/logs/server.log")
end

-- =====================================================================
-- Startup hook
-- =====================================================================

print("")
local startup_yes = prompt("Run Stockpile on computer startup? (y/n):",
    { y = true, n = false })

if startup_yes then
    local entry
    if choice == "client" then
        entry = ROOT .. "/main.lua"
    else
        entry = ROOT .. "/src/main.lua"
    end
    local f = fs.open("startup.lua", "w")
    f.write('shell.run("' .. entry .. '")\n')
    f.close()
    print("startup.lua written.")
end

-- =====================================================================
-- Summary
-- =====================================================================

print("")
if fail_count == 0 then
    print("Installation complete (" .. ok_count .. " files).")
    if startup_yes then
        print("Rebooting in 3 seconds...")
        sleep(3)
        os.reboot()
    else
        if choice == "client" then
            print("Start manually with:  " .. ROOT .. "/main.lua")
        else
            print("Start manually with:  " .. ROOT .. "/src/main.lua")
        end
    end
else
    print("Finished with " .. fail_count .. " failure(s).")
    print("Re-run the installer or check the GitHub page:")
    print("  https://github.com/" .. REPO)
end