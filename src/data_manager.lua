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

return data