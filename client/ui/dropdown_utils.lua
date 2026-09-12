-- ui/dropdown_utils.lua
local dropdownUtils = {}

function dropdownUtils.makeScrollable(dropdown)
    dropdown:registerCallback("mouse_scroll", function(self, direction, x, y)
        local items = self.get("items")
        if not items or #items == 0 then return end

        -- Find current selected index (default 1)
        local currentIndex = 1
        for i, item in ipairs(items) do
            if type(item) == "table" and item.selected then
                currentIndex = i
                break
            end
        end

        local total = #items
        local newIndex = currentIndex + (direction > 0 and 1 or -1)

        -- Loopback
        if newIndex > total then newIndex = 1 end
        if newIndex < 1 then newIndex = total end

        -- Deselect all
        for _, item in ipairs(items) do
            if type(item) == "table" then
                item.selected = false
            end
        end

        -- Select new item
        local newItem = items[newIndex]
        if type(newItem) == "string" then
            newItem = {text = newItem}
            items[newIndex] = newItem
        end
        newItem.selected = true

        -- Update offset so selected item is visible when dropdown opens
        local dropdownHeight = self.get("dropdownHeight") or 5
        local visible = math.min(dropdownHeight, total)
        local maxOffset = math.max(0, total - visible)
        local newOffset = math.max(0, math.min(maxOffset, newIndex - 1))
        self.set("offset", newOffset)

        -- If dropdown is open, also adjust offset to keep selection in view
        if self.get("isOpen") then
            local height = self.get("height") - 1  -- visible items when open
            if height > 0 then
                local offset = self.get("offset")
                if newIndex < offset + 1 then
                    self.set("offset", math.max(0, newIndex - 1))
                elseif newIndex > offset + height then
                    self.set("offset", math.min(maxOffset, newIndex - height))
                end
            end
        end

        self:updateRender()
        self:fireEvent("select", newIndex, newItem)
    end)

    return dropdown
end

-- Size a dropdown so the longest item plus padding fits.
function dropdownUtils.fitWidth(dropdown, minWidth)
    local maxLen = minWidth or 4
    for _, item in ipairs(dropdown:getItems() or {}) do
        local text = type(item) == "table" and item.text or item
        if text and #text > maxLen then maxLen = #text end
    end
    dropdown:setWidth(maxLen + 2)
    return dropdown
end

return dropdownUtils