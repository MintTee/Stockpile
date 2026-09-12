local data = {}

function data.save(filename, data)
    if type(data) == "table" then
        data = textutils.serialise(data)
    end
    local f = io.open(filename, "w")
    if not f then error("file couldn't be opened") return end
    f:write(data)
    f:close()
end

function data.load(filename)
    local f = io.open(filename, "r")
    if not f then error("file couldn't be opened") return end
    local s = f:read("a")
    f:close()
    return s
end

return data