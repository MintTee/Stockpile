data = {}

--Function to serialize and save data to a txt file in the computer.
function data.save(filename, data)
    local file = fs.open(filename, "w")  -- Open file for writing
    if file then
        file.write(textutils.serialize(data))  -- Serialize data and save it
        file.close()  -- Close the file
    else
        print("Error: Could not open file :"..filename.." for writing.")
    end
end

--Function load data from a txt file in the computer and deserialize it.
function data.load(filename)
    local file = fs.open(filename, "r")  -- Open file for reading
    if file then
        local data = textutils.unserialize(file.readAll())  -- Read and unserialize data
        file.close()  -- Close the file
        return data
    else
        print("Error: Could not open file : "..filename.." for reading.")
        return nil
    end
end

-- Constant for large file save function
local RESERVED_SPACE = 20 * 1024  -- Reserve 20KB on each floppy disk

-- Helper function to remove old chunks associated with a given base name
local function remove_old_chunks(base_name)
    local disks = {}  -- Collect available disks
    for _, entry in ipairs(fs.list("/")) do
        if entry:match("^disk%d+$") or entry:match("^disk$") then
            local disk_path = "/" .. entry .. "/"
            table.insert(disks, disk_path)
        end
    end

    -- Add the 'disk' folder first
    table.insert(disks, 1, "/disk/")

    for _, disk_path in ipairs(disks) do
        for _, file_name in ipairs(fs.list(disk_path)) do
            if file_name:match("^" .. base_name .. "_chunk%d+%.txt$") then
                fs.delete(disk_path .. file_name)
            end
        end
    end
end

-- Save a table to floppy disk(s), fragmenting it dynamically with one chunk per disk
function data.save_large_file_to_disks(filename, table_data)
    local base_name = filename:gsub("%.txt$", "")  -- Strip ".txt" extension if present
    remove_old_chunks(base_name)  -- Remove old chunks first

    local serialized_content = textutils.serialize(table_data)  -- Serialize the table
    local lines = {}

    -- Split serialized content into lines for dynamic chunking
    for line in serialized_content:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end

    local disks = {}  -- Collect available disks
    for _, entry in ipairs(fs.list("/")) do
        if entry:match("^disk%d+$") or entry:match("^disk$") then
            local disk_path = "/" .. entry .. "/"
            if #fs.list(disk_path) == 0 then  -- Only consider empty disks
                table.insert(disks, disk_path)
            end
        end
    end

    -- Add the 'disk' folder first, if empty
    if #fs.list("/disk/") == 0 then
        table.insert(disks, 1, "/disk/")
    end

    if #disks == 0 then
        error("No suitable empty disks found.")
    end

    local line_index = 1
    local chunk_index = 1

    -- Write chunks to disks
    for _, disk_path in ipairs(disks) do
        local free_space = fs.getFreeSpace(disk_path)

        if free_space > RESERVED_SPACE then
            free_space = free_space - RESERVED_SPACE

            local current_chunk = ""
            local current_size = 0

            -- Build the chunk content
            while line_index <= #lines and (current_size + #lines[line_index] + 1) <= free_space do
                current_chunk = current_chunk .. (current_chunk == "" and "" or "\n") .. lines[line_index]
                current_size = current_size + #lines[line_index] + 1
                line_index = line_index + 1
            end

            if current_chunk ~= "" then
                -- Write the chunk to a file
                local chunk_filename = disk_path .. base_name .. "_chunk" .. chunk_index .. ".txt"
                local file = fs.open(chunk_filename, "w")
                if file then
                    file.write(current_chunk)
                    file.close()
                    chunk_index = chunk_index + 1
                else
                    error("Failed to write chunk to disk: " .. disk_path)
                end
            end

            -- Stop after writing one chunk per disk
            if line_index > #lines then
                break
            end
        end
    end

    if line_index <= #lines then
        error("Not enough space across all disks to save the file.")
    end
end

-- Load a table from floppy disk(s) and reassemble it
function data.load_large_file_from_disks(filename)
    local base_name = filename:gsub("%.txt$", "")  -- Strip ".txt" extension if present
    local content_chunks = {}
    local chunk_index = 1

    local disks = {}  -- Collect available disks
    for _, entry in ipairs(fs.list("/")) do
        if entry:match("^disk%d+$") or entry:match("^disk$") then
            table.insert(disks, "/" .. entry .. "/")
        end
    end

    -- Add the 'disk' folder first
    table.insert(disks, 1, "/disk/")

    if #disks == 0 then
        error("No disks found.")
    end

    while true do
        local found_chunk = false

        for _, disk_path in ipairs(disks) do
            local chunk_filename = disk_path .. base_name .. "_chunk" .. chunk_index .. ".txt"
            local file = fs.open(chunk_filename, "r")
            if file then
                table.insert(content_chunks, file.readAll())
                file.close()
                found_chunk = true
                break
            end
        end

        if not found_chunk then
            if #content_chunks > 0 then
                local reassembled_content = table.concat(content_chunks, "\n")
                return textutils.unserialize(reassembled_content)  -- Return reassembled table
            else
                print("File not found: "..filename)
                return
            end
        end

        chunk_index = chunk_index + 1
    end
end

return data