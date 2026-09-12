-- /installer.lua
-- Stockpile V2 unified installer
-- Usage: wget run https://raw.githubusercontent.com/MintTee/Stockpile/refs/heads/main/installer.lua

local REPO   = "MintTee/Stockpile"
local BRANCH = "main"
local BASE   = "https://raw.githubusercontent.com/" .. REPO .. "/refs/heads/" .. BRANCH .. "/"

-- =====================================================================
-- File manifests
--
-- Paths are relative to the repo root. The first path segment
-- ("client/" or "server/") is stripped when writing to disk, so
-- "client/ui/search_tab.lua" lands at "stockpile_client/ui/search_tab.lua".
--
-- Only code files are downloaded. Documentation, icons, logs, and
-- per-installation state (groups, database, dictionary) are NOT
-- shipped — they are created locally by this installer.
-- =====================================================================

local CLIENT_FILES = {
    "client/app.lua",
    "client/main.lua",
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
    "client/src/ui_state.lua",
    "client/ui/automation_parser.lua",
    "client/ui/automation_tab.lua",
    "client/ui/components.lua",
    "client/ui/dropdown_utils.lua",
    "client/ui/group_tab.lua",
    "client/ui/help_tab.lua",
    "client/ui/search_tab.lua",
}

local SERVER_FILES = {
    "server/lib/bitstream.lua",
    "server/lib/LibDeflate.lua",
    "server/src/bin.lua",
    "server/src/comms.lua",
    "server/src/contentdb.lua",
    "server/src/data_drive_splitter.lua",
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
-- Install profiles
--
-- Maps the user's single-character choice to the folder name and
-- file manifest for that side. The folder names match the absolute
-- `require` paths used inside the code, so no rewriting is needed.
-- =====================================================================

local PROFILES = {
    client = { root = "stockpile_client", files = CLIENT_FILES },
    server = { root = "stockpile_server", files = SERVER_FILES },
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

--- Write a file with the given content, creating parent directories.
local function write_file(path, content)
    ensure_dir(fs.getDir(path))
    local f = fs.open(path, "w")
    if f then
        f.write(content)
        f.close()
    end
end

--- Show a single-character prompt and return the matching value from
--- `valid` (a table of {char = value}). Loops until a valid char.
---
--- NOTE: we test with `~= nil` rather than truthiness, because the
--- valid table may legitimately map a key to `false` (as the y/n
--- prompts do), and `if false then` would keep looping forever.
local function prompt(question, valid)
    while true do
        print(question)
        local _, char = os.pullEvent("char")
        char = char:lower()
        if valid[char] ~= nil then
            return valid[char]
        end
    end
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

local profile = PROFILES[choice]
local ROOT    = profile.root
local files   = profile.files

print("")
print("Selected:  " .. choice)
print("Install to: " .. ROOT .. "/")
print("Files:     " .. #files .. " code files")

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
print("Downloading into " .. ROOT .. "/ ...")

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

-- =====================================================================
-- Runtime scaffolding
--
-- We deliberately do NOT ship any file that represents per-installation
-- state: the dev's groups, the dev's database, the dev's dictionary,
-- the dev's logs. Instead we create locally the minimum structure the
-- runtime needs to boot cleanly.
-- =====================================================================

print("")
print("Creating runtime scaffolding...")

if choice == "client" then
    -- The client calls app:loadGroups() on startup and errors if
    -- config/groups.txt is missing. Seed it with a valid empty table;
    -- the user populates it through the Groups tab.
    write_file(ROOT .. "/config/groups.txt",
        textutils.serialize({ all = {} }))
    print("  OK   config/groups.txt          (empty)")

    -- ui_state.json and automation_pairs.txt are created by the client
    -- on first save. They live in config/ alongside groups.txt, which
    -- now exists, so nothing more to do.

elseif choice == "server" then
    -- The server writes /bin/db.bin and /bin/dict.bin on first save,
    -- and appends to /logs/server.log continuously. Both directories
    -- must exist or those writes will silently fail.
    ensure_dir(ROOT .. "/bin")
    ensure_dir(ROOT .. "/logs")
    print("  OK   bin/                       (empty)")
    print("  OK   logs/                      (empty)")
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
    write_file("startup.lua", 'shell.run("' .. entry .. '")\n')
    print("startup.lua written -> " .. entry)
else
    print("Skipping startup hook. Run manually after boot.")
end

-- =====================================================================
-- Summary
-- =====================================================================

print("")
if fail_count == 0 then
    print("Installation complete (" .. ok_count .. " files into " .. ROOT .. "/).")
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