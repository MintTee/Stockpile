-- logic/groups.lua
local table_utils = dofile("/stockpile_client/src/table_utils.lua")
local groupsLogic = {}

-- Add inventories to a target group (avoids duplicates)
function groupsLogic.addInventoriesToGroup(targetGroup, invNames, app)
    local compare = table_utils.switch_to_dict(app.groups[targetGroup] or {})
    for _, inv in ipairs(invNames) do
        if not compare[inv] then
            table.insert(app.groups[targetGroup], inv)
        end
    end
    app:saveGroups()
end

-- Remove inventories from a group
function groupsLogic.removeInventoriesFromGroup(group, invNames, app)
    for _, inv in ipairs(invNames) do
        for i, existing in ipairs(app.groups[group]) do
            if existing == inv then
                table.remove(app.groups[group], i)
                break
            end
        end
    end
    app:saveGroups()
end

-- Delete a group
function groupsLogic.deleteGroup(groupName, app)
    app.groups[groupName] = nil
    app:saveGroups()
end

-- Create a new group (empty)
function groupsLogic.createGroup(groupName, app)
    if groupName and groupName ~= "" and not app.groups[groupName] then
        app.groups[groupName] = {}
        app:saveGroups()
        return true
    end
    return false
end

return groupsLogic