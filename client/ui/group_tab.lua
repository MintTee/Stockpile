-- ui/group_tab.lua
local components = dofile("/stockpile_client/ui/components.lua")
local groupsLogic = dofile("/stockpile_client/logic/groups.lua")
local dropdownUtils = dofile("/stockpile_client/ui/dropdown_utils.lua")

local function setupGroupTab(tab, app, bas)
    local ui = {}

    -- Inventory list for the selected group
    ui.invList = components.createBetterList(tab, 1, 2, 22, tab:getHeight() - 4, {
        multiSelection = true,
        background = colors.white
    })

    -- Group dropdown
    ui.groupDropdown = tab:addDropDown()
        :setPosition(1, 1)
        :setSize(22, 1)
        :setBackground(colors.orange)
    ui.groupDropdown.z = 10
    dropdownUtils.makeScrollable(ui.groupDropdown)

    -- Refresh group dropdown and select a given group
    local function refreshGroupDropdown(selectGroup)
        ui.groupDropdown:clear()
        for group in pairs(app.groups) do
            ui.groupDropdown:addItem({text = group, selected = false})
        end
        -- Try to select the given group
        local found = false
        for i, item in ipairs(ui.groupDropdown.items) do
            if item.text == selectGroup then
                ui.groupDropdown.items[i].selected = true
                found = true
                break
            end
        end
        if not found and ui.groupDropdown.items[1] then
            ui.groupDropdown.items[1].selected = true
        end
    end

    -- Refresh the inventory list for the selected group
    function ui:refreshInventoryList()
        ui.invList:clear()
        ui.invList:scrollToTop()
        local group = ui.groupDropdown:getSelectedItem() and ui.groupDropdown:getSelectedItem().text
        if not group then return end
        local invs = app.groups[group] or {}
        for _, inv in ipairs(invs) do
            ui.invList:addItem(inv)
        end
    end

    -- When group dropdown changes
    ui.groupDropdown:onSelect(function() ui:refreshInventoryList() end)

    -- Buttons
    -- Create group
    tab:addButton()
        :setPosition(12, tab:getHeight() - 1)
        :setSize(12, 1)
        :setText("create group")
        :setBackground(colors.blue)
        :onClick(function()
            local popup = components.createPopup(tab, "New Group", 30, 10)
            popup:addLabel()
                :setPosition(2, 3)
                :setText("Group name:")
            local nameInput = popup:addInput()
                :setPosition(14, 3)
                :setSize(14, 1)
            popup:addButton()
                :setPosition(14, 6)
                :setSize(8, 1)
                :setText("Create")
                :setBackground(colors.green)
                :onClick(function()
                    local name = nameInput:getText()
                    if groupsLogic.createGroup(name, app) then
                        refreshGroupDropdown(name)
                        ui:refreshInventoryList()
                        popup:destroy()
                        bas.triggerEvent("groups_updated")
                    end
                end)
        end)

    -- Delete group
    tab:addButton()
        :setPosition(1, tab:getHeight() - 1)
        :setSize(9, 1)
        :setText("del group")
        :setBackground(colors.red)
        :onClick(function()
            local group = ui.groupDropdown:getSelectedItem() and ui.groupDropdown:getSelectedItem().text
            if not group then return end
            groupsLogic.deleteGroup(group, app)
            refreshGroupDropdown("all")
            ui:refreshInventoryList()
            bas.triggerEvent("groups_updated")
        end)

    -- Add inventories to group
    tab:addButton()
        :setPosition(1, tab:getHeight() - 2)
        :setSize(9, 1)
        :setText("add to")
        :setBackground(colors.green)
        :onClick(function()
            local sel_group = ui.groupDropdown:getSelectedItem() and ui.groupDropdown:getSelectedItem().text
            if not sel_group then return end
            local selection = ui.invList:getSelectedItems()
            if #selection == 0 then return end

            local popup = components.createPopup(tab, "Add invs to group", 30, 10)
            popup:addLabel()
                :setPosition(2, 3)
                :setText("Target group:")

            local targetDropdown = popup:addDropDown()
                :setPosition(14, 3)
                :setSize(14, 1)
                :setBackground(colors.green)

            for group in pairs(app.groups) do
                if group ~= sel_group then
                    targetDropdown:addItem({text = group, selected = false})
                end
            end
            if targetDropdown.items[1] then targetDropdown.items[1].selected = true end
            dropdownUtils.makeScrollable(ui.groupDropdown)

            popup:addButton()
                :setPosition(14, 6)
                :setSize(8, 1)
                :setText("Add")
                :setBackground(colors.green)
                :onClick(function()
                    local target_group = targetDropdown:getSelectedItem() and targetDropdown:getSelectedItem().text
                    if not target_group then return end
                    local invNames = {}
                    for _, inv in ipairs(selection) do
                        table.insert(invNames, inv.text)
                    end
                    groupsLogic.addInventoriesToGroup(target_group, invNames, app)
                    refreshGroupDropdown(target_group)
                    ui:refreshInventoryList()
                    popup:destroy()
                end)
        end)

    -- Remove inventories from group
    tab:addButton()
        :setPosition(12, tab:getHeight() - 2)
        :setSize(11, 1)
        :setText("remove from")
        :setBackground(colors.yellow)
        :onClick(function()
            local group = ui.groupDropdown:getSelectedItem() and ui.groupDropdown:getSelectedItem().text
            if not group then return end
            local selection = ui.invList:getSelectedItems()
            if #selection == 0 then return end
            local invNames = {}
            for _, inv in ipairs(selection) do
                table.insert(invNames, inv.text)
            end
            groupsLogic.removeInventoriesFromGroup(group, invNames, app)
            refreshGroupDropdown(group)
            ui:refreshInventoryList()
        end)

    -- Initial refresh
    refreshGroupDropdown("all")
    ui:refreshInventoryList()

    -- Expose refresh method for external updates (e.g., after data load)
    function ui:refresh()
        refreshGroupDropdown(ui.groupDropdown:getSelectedItem() and ui.groupDropdown:getSelectedItem().text or "all")
        ui:refreshInventoryList()
    end

    return ui
end

return setupGroupTab