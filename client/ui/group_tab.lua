-- /stockpile_client/ui/group_tab.lua
local bas           = require("lib.basalt")
local app           = require("app")
local components    = require("ui.components")
local groupsLogic   = require("logic.groups")
local dropdownUtils = require("ui.dropdown_utils")
local comms         = require("src.comms")

local function setupGroupTab(tab)
    local ui = {}

    ui.invList = components.createBetterList(tab, 1, 2, 22, tab:getHeight() - 4, {
        multiSelection = true,
        background = colors.white,
    })

    ui.groupDropdown = tab:addDropDown()
        :setPosition(1, 1)
        :setSize(22, 1)
        :setBackground(colors.orange)
    ui.groupDropdown.z = 10
    dropdownUtils.makeScrollable(ui.groupDropdown)

    local function refreshGroupDropdown(selectGroup)
        ui.groupDropdown:clear()
        for group in pairs(app.groups) do
            ui.groupDropdown:addItem({ text = group, selected = false })
        end
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

    function ui:refreshInventoryList()
        ui.invList:clear()
        ui.invList:scrollToTop()
        local group = ui.groupDropdown:getSelectedItem()
            and ui.groupDropdown:getSelectedItem().text
        if not group then return end
        for _, inv in ipairs(app.groups[group] or {}) do
            ui.invList:addItem(inv)
        end
    end

    ui.groupDropdown:onSelect(function() ui:refreshInventoryList() end)

    tab:addButton()
        :setPosition(12, tab:getHeight() - 1)
        :setSize(12, 1)
        :setText("create group")
        :setBackground(colors.blue)
        :onClick(function()
            local popup = components.createPopup(tab, "New Group", 30, 10)
            popup:addLabel():setPosition(2, 3):setText("Group name:")
            local nameInput = popup:addInput():setPosition(14, 3):setSize(14, 1)
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

    tab:addButton()
        :setPosition(1, tab:getHeight() - 1)
        :setSize(9, 1)
        :setText("del group")
        :setBackground(colors.red)
        :onClick(function()
            local group = ui.groupDropdown:getSelectedItem()
                and ui.groupDropdown:getSelectedItem().text
            if not group then return end
            groupsLogic.deleteGroup(group, app)
            refreshGroupDropdown("all")
            ui:refreshInventoryList()
            bas.triggerEvent("groups_updated")
        end)

    tab:addButton()
        :setPosition(1, tab:getHeight() - 2)
        :setSize(9, 1)
        :setText("add to")
        :setBackground(colors.green)
        :onClick(function()
            local sel_group = ui.groupDropdown:getSelectedItem()
                and ui.groupDropdown:getSelectedItem().text
            if not sel_group then return end
            local selection = ui.invList:getSelectedItems()
            if #selection == 0 then return end

            local popup = components.createPopup(tab, "Add invs to group", 30, 10)
            popup:addLabel():setPosition(2, 3):setText("Target group:")

            local targetDropdown = popup:addDropDown()
                :setPosition(14, 3)
                :setSize(14, 1)
                :setBackground(colors.green)

            for group in pairs(app.groups) do
                if group ~= sel_group then
                    targetDropdown:addItem({ text = group, selected = false })
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
                    local target_group = targetDropdown:getSelectedItem()
                        and targetDropdown:getSelectedItem().text
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

    tab:addButton()
        :setPosition(12, tab:getHeight() - 2)
        :setSize(11, 1)
        :setText("remove from")
        :setBackground(colors.yellow)
        :onClick(function()
            local group = ui.groupDropdown:getSelectedItem()
                and ui.groupDropdown:getSelectedItem().text
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
    
        -- Rescan group content tab
        tab:addButton()
            :setPosition(25, tab:getHeight() - 1)
            :setSize(10, 1)
            :setText("scan group")
            :setBackground(colors.lightBlue)
            :onClick(function(self)
                local group = ui.groupDropdown:getSelectedItem()
                    and ui.groupDropdown:getSelectedItem().text
                if not group then return end

                local invs = app.groups[group] or {}
                if #invs == 0 then
                    self:setBackground(colors.red)
                    self:setText("empty group")
                    bas.schedule(function()
                        sleep(1)
                        self:setBackground(colors.lightBlue)
                        self:setText("scan group")
                    end)
                    return
                end

                self:setBackground(colors.yellow)
                self:setText("scanning...")

                comms.scanAsync(invs, function(result)
                    if result and result.status == "done" then
                        -- Refresh the item/inv index so the search tab picks up
                        -- the new totals before we tell it to redraw.
                        comms.getContentAsync(app, function()
                            self:setBackground(colors.green)
                            self:setText("scan done")
                            bas.schedule(function()
                                sleep(2)
                                self:setBackground(colors.lightBlue)
                                self:setText("scan group")
                            end)
                            bas.triggerEvent("groups_updated")
                        end)
                    else
                        self:setBackground(colors.red)
                        self:setText("scan fail")
                        bas.schedule(function()
                            sleep(2)
                            self:setBackground(colors.lightBlue)
                            self:setText("scan group")
                        end)
                    end
                end)
            end)

    refreshGroupDropdown("all")
    ui:refreshInventoryList()

    function ui:refresh()
        refreshGroupDropdown(ui.groupDropdown:getSelectedItem()
            and ui.groupDropdown:getSelectedItem().text or "all")
        ui:refreshInventoryList()
    end

    return ui
end

return setupGroupTab