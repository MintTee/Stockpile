-- ui/components.lua
local components = {}

function components.createBetterList(parent, x, y, width, height, opts)
    opts = opts or {}
    local self = {}
    self.multiSelection = opts.multiSelection or false

    self.frame = parent:addFrame()
        :setPosition(x, y)
        :setSize(width, height)
        :setBackground(opts.background or colors.white)

    self.list = self.frame:addList()
        :setPosition(1, 1)
        :setWidth(width)
        :setHeight(height - 2)
        :setBackground(colors.white)
    self.list.multiSelection = self.multiSelection

    -- 🔽 Make scroll step = 2 by firing the scroll event twice
    local originalScroll = self.list.mouse_scroll
    self.list.mouse_scroll = function(list, direction, x, y)
        if list:isInBounds(x, y) then
            -- First scroll (1 step)
            originalScroll(list, direction, x, y)
            -- Second scroll (another step)
            originalScroll(list, direction, x, y)
            return true
        end
        return false
    end

    self.indicator = self.frame:addLabel()
        :setPosition(7, height)
        :setSize(width - 2, 1)
        :setText("")
        :setBackground(colors.green)

    -- Toggle button
    self.toggleBtn = self.frame:addButton()
        :setPosition(1, height)
        :setSize(1, 1)
        :setText("x")
        :setForeground(colors.white)
        :setBackground(colors.red)
        :onClick(function()
            local selected = self.list:getSelectedItems()
            if #selected == 0 then
                -- Select all
                local items = self.list:getItems()
                for i, item in ipairs(items) do
                    if type(item) == "string" then
                        items[i] = {text = item, selected = true}
                    else
                        item.selected = true
                    end
                end
            else
                -- Deselect all
                for _, item in ipairs(self.list:getItems()) do
                    if type(item) == "table" then
                        item.selected = false
                    end
                end
            end
            self:updateIndicator()
            self:updateToggleButton()
        end)

    self.frame:addButton()
        :setPosition(3, height)
        :setSize(1, 1)
        :setText("^")
        :setForeground(colors.lightGray)
        :setBackground(colors.white)
        :onClick(function() self:scrollToTop() end)

    self.frame:addButton()
        :setPosition(5, height)
        :setSize(1, 1)
        :setText("v")
        :setForeground(colors.lightGray)
        :setBackground(colors.white)
        :onClick(function() self:scrollToBottom() end)

    function self:updateToggleButton()
        local selected = self.list:getSelectedItems()
        if #selected == 0 then
            self.toggleBtn:setText("o")
            self.toggleBtn:setBackground(colors.green)
        else
            self.toggleBtn:setText("x")
            self.toggleBtn:setBackground(colors.red)
        end
    end

    function self:updateIndicator()
        local selected = self.list:getSelectedItems()
        self.indicator:setText(#selected > 0 and "selected: " .. #selected or "")
        self:updateToggleButton()
    end

    function self:deselectAll()
        for _, item in ipairs(self.list:getItems()) do
            if type(item) == "table" then
                item.selected = false
            end
        end
        self:updateIndicator()
    end

    function self:addItem(text)
        local item = self.list:addItem(text)
        self:updateIndicator()
        return item
    end

    function self:clear()
        self.list:clear()
        self:updateIndicator()
    end

    function self:selectIndex(index)
        local items = self.list.get("items")
        if not items or #items == 0 or index < 1 or index > #items then return end

        -- Deselect all
        for _, item in ipairs(items) do
            if type(item) == "table" then
                item.selected = false
            end
        end

        -- Select target
        local target = items[index]
        if type(target) == "string" then
            target = {text = target, selected = true}
            items[index] = target
        else
            target.selected = true
        end

        -- Ensure item is visible (scroll to it)
        local listHeight = self.list.get("height") or 1
        local offset = self.list.get("offset") or 0
        if index < offset + 1 then
            self.list.set("offset", math.max(0, index - 1))
        elseif index > offset + listHeight then
            self.list.set("offset", index - listHeight)
        end

        self:updateIndicator()
        self.list:updateRender()
    end

    function self:selectNext()
        local items = self.list.get("items")
        if not items or #items == 0 then return end

        -- Find current selection
        local currentIndex = 1
        for i, item in ipairs(items) do
            if type(item) == "table" and item.selected then
                currentIndex = i
                break
            end
        end

        -- Move to next (wrap around)
        local nextIndex = currentIndex + 1
        if nextIndex > #items then nextIndex = 1 end

        self:selectIndex(nextIndex)
    end

    function self:selectPrevious()
        local items = self.list.get("items")
        if not items or #items == 0 then return end

        -- Find current selection
        local currentIndex = 1
        for i, item in ipairs(items) do
            if type(item) == "table" and item.selected then
                currentIndex = i
                break
            end
        end

        -- Move to previous (wrap around)
        local prevIndex = currentIndex - 1
        if prevIndex < 1 then prevIndex = #items end

        self:selectIndex(prevIndex)
    end

    self.list:onSelect(function() self:updateIndicator() end)

    self.getSelectedItems = function() return self.list:getSelectedItems() end
    self.scrollToTop = function() self.list:scrollToTop() end
    self.scrollToBottom = function() self.list:scrollToBottom() end
    self.getList = function() return self.list end
    self.getFrame = function() return self.frame end

    self:updateIndicator()

    return self
end

function components.createPopup(parent, title, width, height)
    local pw, ph = parent:getWidth(), parent:getHeight()
    local x = math.floor((pw - width) / 2)
    local y = math.floor((ph - height) / 2)

    local frame = parent:addFrame()
        :setPosition(x, y)
        :setSize(width, height)
        :addBorder()

    frame:addLabel()
        :setPosition(width/2 - #title/2 + 1, 1)
        :setSize(width - 2, 1)
        :setText(title or "Popup")
        :setForeground(colors.gray)

    frame:addButton()
        :setPosition(width, 1)
        :setSize(1, 1)
        :setText("X")
        :setBackground(colors.red)
        :setForeground(colors.white)
        :onClick(function() frame:destroy() end)

    return frame
end

return components