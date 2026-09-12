-- main.lua
local bas = require("/stockpile_client/lib/basalt")
local app = dofile("/stockpile_client/app.lua")
local comms = dofile("/stockpile_client/src/comms.lua")

-- Enable logging (and write to file)
bas.LOGGER.setEnabled(true)
bas.LOGGER.setLogToFile(true)   -- creates "basalt.log" in the current directory

-- Initialise async comms (finds server, hooks events)
comms.init(bas)

-- We no longer block; data will be loaded asynchronously.
-- Build UI only after initial data arrives.
local function build_ui()
    -- Import tab builders
    local setupSearchTab = dofile("/stockpile_client/ui/search_tab.lua")
    local setupGroupTab = dofile("/stockpile_client/ui/group_tab.lua")
    local setupAutomationTab = dofile("/stockpile_client/ui/automation_tab.lua")
    local setupHelpTab = dofile("/stockpile_client/ui/help_tab.lua")

    -- Main window
    local rootf = bas.getMainFrame()

    -- Tab control
    local tabs = rootf:addTabControl()
        :setSize("{parent.width}", "{parent.height}")
        :setBackground(colors.lightGray)

    -- Create tabs and store controllers
    local searchTab = tabs:newTab("search")
    local groupTab = tabs:newTab("groups")
    local automationTab = tabs:newTab("automation")
    local helpTab = tabs:newTab("help")

    -- Build tabs – capture the search controller
    local searchCtrl = setupSearchTab(searchTab, app, bas)
    local groupCtrl = setupGroupTab(groupTab, app, bas)   -- not used yet
    setupAutomationTab(automationTab, app, bas)
    setupHelpTab(helpTab, bas)

    searchCtrl:refreshUsageLabel()

    -- After creating searchCtrl, register the event listener
    bas.onEvent("groups_updated", function()
        searchCtrl:refreshGroupDropdowns()
        searchCtrl:refreshSearchResults()
    end)

    -- Keyboard shortcuts
    rootf:onKeyUp(function(self, key)
        key = keys.getName(key)
        if key == "leftCtrl" then app.lctrl = false end
        if key == "leftShift" then app.lshift = false end
    end)

    rootf:onKey(function(self, key)
        bas.LOGGER.debug("Key pressed: " .. tostring(key))

        if tabs.activeTab ~= 1 then return end  -- only on search tab
        local num_key = key
        key = keys.getName(key)

        if key == "leftCtrl" then
            app.lctrl = true
        elseif key == "leftShift" then
            app.lshift = true
        elseif key == "down" then
            searchCtrl.resultsList:selectNext()
        elseif key == "up" then
            searchCtrl.resultsList:selectPrevious()
        elseif num_key >= 48 and num_key <= 57 and not searchCtrl.nbtFilter.focused then
            if not searchCtrl.qtyInput.focused then
                searchCtrl.qtyInput:setText("")
            end
            searchCtrl.qtyInput:setFocused(true)
        elseif key == "backspace" and not searchCtrl.nbtFilter.focused and not searchCtrl.qtyInput.focused then
            searchCtrl.itemFilter:setText("")
            searchCtrl.itemFilter:setCursor(#searchCtrl.itemFilter.text, 1, false, colors.blue)
            searchCtrl.itemFilter:setFocused(true)
        elseif key == "enter" then
            local btn = searchCtrl.moveButton
            btn:setText("processing")
            btn:setBackground(colors.yellow)
            -- Perform the move asynchronously
            searchCtrl:performMove(function(success)
                btn:setBackground(success and colors.blue or colors.red)
                btn:setText(success and "done" or "fail")
                bas.schedule(function()
                    sleep(2)
                    btn:setBackground(colors.green)
                    btn:setText("move item")
                end)
            end)
        elseif not searchCtrl.nbtFilter.focused then
            searchCtrl.itemFilter:setFocused(true)
            searchCtrl.itemFilter:setCursor(#searchCtrl.itemFilter.text, 1, false, colors.blue)
        end
    end)
end

-- Asynchronously fetch initial data, then build UI
comms.getContentAsync(app, function()
    comms.listAllInventoriesAsync(app, function()
        app:loadGroups()
        build_ui()
    end)
end)

-- Start the Basalt event loop (keeps the program alive)
bas.run()