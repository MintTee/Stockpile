-- /stockpile_client/ui/search_tab.lua
local bas          = require("lib.basalt")
local app          = require("app")
local components   = require("ui.components")
local searchLogic  = require("logic.search")
local moveLogic    = require("logic.move")
local dropdownUtils = require("ui.dropdown_utils")
local usage        = require("logic.usage")
local string_utils = require("src.string_utils")

local function setupSearchTab(tab)
    local ui = {}

    local function format_qty(n)
        if n < 64 then return "" end
        local SB, ST = 64 * 27, 64
        local sb    = math.floor(n / SB)
        local rem   = n % SB
        local st    = math.floor(rem / ST)
        local units = rem % ST
        local parts = {}
        if sb    > 0 then table.insert(parts, sb .. "sb") end
        if st    > 0 then table.insert(parts, st .. "st") end
        if units > 0 then table.insert(parts, tostring(units)) end
        return table.concat(parts, "+")
    end

    ui.itemFilter = tab:addInput()
        :setPosition(1, 1)
        :setWidth(10)
        :setPlaceholder("item")
        :onClick(function(self) self:setText("") end)

    ui.nbtFilter = tab:addInput()
        :setPosition(12, 1)
        :setWidth(10)
        :setPlaceholder("nbt")
        :onClick(function(self) self:setText("") end)

    ui.usageLabel = tab:addLabel()
        :setPosition(1, tab:getHeight() - 1)
        :setForeground(colors.gray)

    ui.movePanel = tab:addFrame()
        :setSize(14, tab:getHeight() - 4)
        :setBackground(colors.yellow)
        :setPosition(tab:getWidth() / 2 + 12, 2)

    ui.movePanel:addLabel()
        :setText("Move item")
        :setForeground(colors.gray)
        :setPosition(ui.movePanel:getWidth() / 2 - 4, 1)

    ui.fromGroupLabel = ui.movePanel:addLabel()
        :setForeground(colors.gray)
        :setPosition(1, 3)

    ui.movePanel:addLabel()
        :setForeground(colors.gray)
        :setPosition(1, 4)
        :setText("to")

    ui.toGroupDropdown = ui.movePanel:addDropDown()
        :setPosition(4, 4)
        :setBackground(colors.lightBlue)
        :setSize(10, 1)
    dropdownUtils.makeScrollable(ui.toGroupDropdown)

    ui.fmtQty = ui.movePanel:addLabel()
        :setForeground(colors.gray)
        :setPosition(1, 8)
        :setText("")

    ui.qtyInput = ui.movePanel:addInput()
        :setPosition(1, 6)
        :setSize(4, 1)
        :setPlaceholder("qty")
        :onClick(function(self) self:setText("") end)
        :onChange("text", function(self)
            self:setText(self.text:gsub("%D", ""))
            self:setText(self.text:gsub("^0+(.)", ""))
            if self.text ~= "" then
                ui.fmtQty:setText(format_qty(tonumber(self.text)))
            end
        end)
        :listenEvent("mouse_scroll", true)
        :registerCallback("mouse_scroll", function(self, direction)
            if self.text == "" then self:setText("0") end
            local multiplier = 1
            if app.lshift then multiplier = 16 end
            if app.lctrl then multiplier = 64 end
            local val = tonumber(self.text) or 0
            if direction == -1 then
                val = val + multiplier
            else
                val = math.max(0, val - multiplier)
            end
            self:setText(tostring(val))
            self.cursorPos = #self.text + 1
        end)

    ui.modeDropdown = ui.movePanel:addDropDown()
        :setPosition(1, 10)
        :setBackground(colors.pink)
        :setSize(9, 1)
        :addItem({ text = "of each", selected = false })
        :addItem({ text = "divided", selected = false })
        :addItem({ text = "all",     selected = false })
        :onSelect(function(_, _, mode)
            mode = mode.text
            ui.qtyInput:setVisible(mode ~= "all")
            ui.fmtQty:setVisible(mode ~= "all")
        end)
    ui.modeDropdown.items[1].selected = true
    dropdownUtils.makeScrollable(ui.modeDropdown)

    ui.moveButton = ui.movePanel:addButton()
        :setText("move item")
        :setPosition(3, 12)
        :setBackground(colors.green)
        :onClick(function(self)
            self:setText("processing...")
            self:setBackground(colors.yellow)

            ui:performMove(function(success)
                self:setBackground(success and colors.blue or colors.red)
                self:setText(success and "done" or "fail")
                bas.schedule(function()
                    sleep(2)
                    self:setBackground(colors.green)
                    self:setText("move item")
                end)
            end)
        end)

    ui.groupDropdown = tab:addDropDown()
        :setPosition(22, 1)
        :setWidth(14)
        :setBackground(colors.gray)
        :setForeground(colors.white)
    ui.groupDropdown.z = 99
    dropdownUtils.makeScrollable(ui.groupDropdown)

    ui.resultsList = components.createBetterList(tab, 1, 2, tab:getWidth() / 2 + 10, tab:getHeight() - 4, {
        multiSelection = true,
        background = colors.white,
    })

    function ui:refreshSearchResults()
        ui.resultsList:clear()
        ui.resultsList:scrollToTop()

        local groupName = ui.groupDropdown:getSelectedItem()
            and ui.groupDropdown:getSelectedItem().text or "all"

        local res = searchLogic.run(
            ui.itemFilter:getText(),
            ui.nbtFilter:getText(),
            groupName,
            app.groups,
            app.item_index,
            app.inv_index
        )

        for _, v in ipairs(res) do
            ui.resultsList:addItem({
                text = string.format("%s %s",
                    string_utils.formatMetricPrefix(v.total),
                    v.displayName or v.item),
                id = v.item,
            })
        end

        local itemFilterText = ui.itemFilter:getText()
        local nbtFilterText  = ui.nbtFilter:getText()
        if #res > 0 and (itemFilterText ~= "" or nbtFilterText ~= "") then
            local firstItem = ui.resultsList:getList():getItems()[1]
            if firstItem then
                if type(firstItem) == "string" then
                    firstItem = { text = firstItem, selected = true }
                    ui.resultsList:getList():getItems()[1] = firstItem
                else
                    firstItem.selected = true
                end
                ui.resultsList:updateIndicator()
            end
        end
    end

    function ui:performMove(callback)
        bas.LOGGER.debug("performMove called")

        local from_group = ui.groupDropdown:getSelectedItem()
            and ui.groupDropdown:getSelectedItem().text
        bas.LOGGER.debug("from_group: " .. tostring(from_group))

        local to_group   = ui.toGroupDropdown:getSelectedItem()
            and ui.toGroupDropdown:getSelectedItem().text
        local mode       = ui.modeDropdown:getSelectedItem()
            and ui.modeDropdown:getSelectedItem().text
        local qty        = tonumber(ui.qtyInput.text)
        local selected   = ui.resultsList:getSelectedItems()

        moveLogic.performMove(from_group, to_group, mode, qty, selected, function(success)
            if success then
                ui:refreshSearchResults()
                ui:refreshUsageLabel()
            end
            if callback then callback(success) end
        end)
    end

    function ui:refreshGroupDropdowns()
        ui.groupDropdown:clear()
        ui.toGroupDropdown:clear()

        for group in pairs(app.groups) do
            ui.groupDropdown:addItem({ text = group, selected = false })
        end

        local current = ui.groupDropdown:getSelectedItem()
            and ui.groupDropdown:getSelectedItem().text

        for group in pairs(app.groups) do
            if group ~= "all" and group ~= current then
                ui.toGroupDropdown:addItem({ text = group, selected = false })
            end
        end

        if ui.groupDropdown.items[1]   then ui.groupDropdown.items[1].selected   = true end
        if ui.toGroupDropdown.items[1] then ui.toGroupDropdown.items[1].selected = true end
    end

    function ui:refreshUsageLabel()
        local slots       = usage.getSlots(app)
        local item_total  = usage.getTotal(app)
        if slots then
            ui.usageLabel:setText(string.format("%s items (%d%%)",
                string_utils.formatMetricPrefix(item_total),
                slots.used / slots.total * 100))
        else
            ui.usageLabel:setText("usage:unknown ")
        end
    end

    ui.itemFilter:onChange("text", function() ui:refreshSearchResults() end)
    ui.nbtFilter:onChange("text",  function() ui:refreshSearchResults() end)

    ui.groupDropdown:onSelect(function(_, _, group)
        ui:refreshSearchResults()
        ui.fromGroupLabel:setText("from " .. group.text)

        ui.toGroupDropdown:clear()
        for g in pairs(app.groups) do
            if g ~= "all" and g ~= group.text then
                ui.toGroupDropdown:addItem({ text = g, selected = false })
            end
        end
        if ui.toGroupDropdown.items[1] then ui.toGroupDropdown.items[1].selected = true end
    end)

    -- Refresh the visible list whenever the server sends fresh content.
    bas.onEvent("content_updated", function()
        ui:refreshSearchResults()
        ui:refreshUsageLabel()
    end)

    ui:refreshGroupDropdowns()
    ui.fromGroupLabel:setText("from " ..
        (ui.groupDropdown:getSelectedItem() and ui.groupDropdown:getSelectedItem().text or ""))
    ui:refreshSearchResults()
    ui.refreshUsageLabel()

    return ui
end

return setupSearchTab