if http.checkURL("https://raw.githubusercontent.com") then
    print("URL is allowed!")
else
    print("URL is not allowed.")
end

local files = {
    "file1.lua",
    "file2.lua",
    -- Add more files as needed
}

for _, file in ipairs(files) do
    local url = "https://raw.githubusercontent.com/username/repository/branch/" .. file
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
    