-- /stockpile_client/main.lua
--[[

How to implement the automation tab ?

Triggers / conditions :

period,
redstone ss level < > = delta rising, delta falling, delta any, side of client computer (default to any)
Threshold of item (all, each) > = < qty or (Item) in given group

Command :

Scan group
move item (or blank) to from qty (all by default)

COMBINE both sides (condition) WITH BOOL LOGIC (command just have AND option)
    AND
    OR
    XOR
    NOT
]]

local ROOT = "/stockpile_client"
package.path = ROOT .. "/?.lua;" .. ROOT .. "/?/init.lua;" .. package.path

local base_require = require
local bas = base_require("lib.basalt")

-- Basalt replaces the global `require` with an override whose fallback
-- path calls the original require but forgets to `return` it, so every
-- external module resolves to nil even though it loaded fine. Wrap it
-- so the fallback returns what was loaded.
--
-- IMPORTANT: every external require(...) below MUST happen after this
-- wrapper is installed, otherwise the module comes back as nil.
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

    -- -----------------------------------------------------------------
    -- Restore persisted UI state.
    --
    -- Order matters:
    --
    --   1. load_pairs() REPLACES the single default pair created by
    --      setupAutomationTab with however many pairs were saved.
    --      This has to run BEFORE ui_state.load because the tree
    --      walk keys pairs by their position among siblings — the
    --      right number of frames must exist.
    --
    --   2. ui_state.load() restores text boxes, dropdown selections,
    --      list selections, visibility, etc. DropDown restore fires
    --      its select event so dependent lists repopulate, then a
    --      second pass re-applies list item selections.
    --
    --   3. afterStateLoad() re-parses any pair whose text survived
    --      the tree walk but whose AST was never rebuilt.
    -- -----------------------------------------------------------------
    if automationCtrl and automationCtrl.load_pairs then
        pcall(function() automationCtrl:load_pairs() end)
    end

    if ui_state.load(rootf) then
        if automationCtrl and automationCtrl.afterStateLoad then
            automationCtrl:afterStateLoad()
        end
    end

    searchCtrl:refreshUsageLabel()

    -- -----------------------------------------------------------------
    -- Persistence helper. Called on tab switch and on terminate.
    -- -----------------------------------------------------------------
    local function persist_all()
        ui_state.save(rootf)
        if automationCtrl and automationCtrl.save_pairs then
            pcall(function() automationCtrl:save_pairs() end)
        end
    end

    -- -----------------------------------------------------------------
    -- Save whenever the user switches tabs. This is the natural
    -- checkpoint: any text they typed, any selection they made, any
    -- pair they toggled, is captured the moment they leave the tab.
    -- -----------------------------------------------------------------
    tabs:onChange("activeTab", function()
        persist_all()
    end)

    -- -----------------------------------------------------------------
    -- Keep selections stable across data refreshes.
    --
    -- Whenever groups are updated or server content comes in, several
    -- Lists/DropDowns get rebuilt from scratch and lose their
    -- selection. reapply_selections re-applies only the selection
    -- state from the last snapshot, without touching text boxes or
    -- any other live user input.
    -- -----------------------------------------------------------------
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