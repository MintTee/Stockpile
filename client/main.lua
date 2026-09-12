-- /stockpile_client/main.lua

local ROOT = "/stockpile_client"
package.path = ROOT .. "/?.lua;" .. ROOT .. "/?/init.lua;" .. package.path

local base_require = require
local bas = base_require("lib.basalt")

local basalt_require = require
require = function(path)
    local result = basalt_require(path)
    if result ~= nil then return result end
    return package.loaded[path]
end

local app      = require("app")
local comms    = require("src.comms")
local ui_state = require("src.ui_state")

bas.LOGGER.setEnabled(true)
bas.LOGGER.setLogToFile(true)

comms.init()

local function build_ui()
    local setupSearchTab     = require("ui.search_tab")
    local setupGroupTab      = require("ui.group_tab")
    local setupAutomationTab = require("ui.automation_tab")
    local setupHelpTab       = require("ui.help_tab")

    local rootf = bas.getMainFrame()

    local tabs = rootf:addTabControl()
        :setSize("{parent.width}", "{parent.height}")
        :setBackground(colors.lightGray)

    local searchTab     = tabs:newTab("search")
    local groupTab      = tabs:newTab("groups")
    local automationTab = tabs:newTab("automation")
    local helpTab       = tabs:newTab("help")

    local searchCtrl     = setupSearchTab(searchTab)
    local groupCtrl      = setupGroupTab(groupTab)
    local automationCtrl = setupAutomationTab(automationTab)
    setupHelpTab(helpTab)

    if automationCtrl and automationCtrl.load_pairs then
        pcall(function() automationCtrl:load_pairs() end)
    end

    if ui_state.load(rootf) then
        if automationCtrl and automationCtrl.afterStateLoad then
            automationCtrl:afterStateLoad()
        end
    end

    searchCtrl:refreshUsageLabel()

    local function persist_all()
        ui_state.save(rootf)
        if automationCtrl and automationCtrl.save_pairs then
            pcall(function() automationCtrl:save_pairs() end)
        end
    end

    tabs:onChange("activeTab", function()
        persist_all()
    end)

    bas.onEvent("groups_updated", function()
        searchCtrl:refreshGroupDropdowns()
        searchCtrl:refreshSearchResults()
        ui_state.reapply_selections(rootf)
    end)

    bas.onEvent("content_updated", function()
        ui_state.reapply_selections(rootf)
    end)

    -- -----------------------------------------------------------------
    -- Keyboard shortcuts
    -- -----------------------------------------------------------------
    rootf:onKeyUp(function(_, key)
        key = keys.getName(key)
        if key == "leftCtrl"  then app.lctrl = false end
        if key == "leftShift" then app.lshift = false end
    end)

    rootf:onKey(function(_, key)
        bas.LOGGER.debug("Key pressed: " .. tostring(key))

        if tabs.activeTab ~= 1 then return end
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

    -- -----------------------------------------------------------------
    -- Save on exit as a safety net. Tab-switch saves cover normal
    -- usage; this catches the case where the user terminates the
    -- program while still on the tab they've been working on.
    -- -----------------------------------------------------------------
    bas.onEvent("terminate", function()
        persist_all()
    end)
end

comms.getContentAsync(app, function(result)
    if not result or result.status ~= "done" then
        print("Failed to fetch content: " .. (result and result.detail or "timeout"))
        return
    end
    comms.listAllInventoriesAsync(app, function(result)
        if not result or result.status ~= "done" then
            print("Failed to list inventories: " .. (result and result.detail or "timeout"))
            return
        end
        app:loadGroups()
        build_ui()
    end)
end)

bas.run()