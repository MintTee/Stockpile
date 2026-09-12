-- stockpile_client/app.lua
local app = {
    groups = { all = {} },
    item_index = nil,
    inv_index = nil,
    lshift = false,
    lctrl = false,
}

-- Load groups from disk
function app:loadGroups()
    local data = dofile("/stockpile_client/src/data.lua")
    local s = data.load("/stockpile_client/config/groups.txt")
    self.groups = textutils.unserialize(s) or { all = {} }   -- full replace!
end

-- Save groups to disk
function app:saveGroups()
    local data = dofile("/stockpile_client/src/data.lua")
    data.save("/stockpile_client/config/groups.txt", textutils.serialize(self.groups))
end

-- Refresh inventory data from server
function app:refreshInventoryData()
    local comms = dofile("/stockpile_client/src/comms.lua")
    comms.get_content(self)
    comms.list_all_inventories(self)
end

return app