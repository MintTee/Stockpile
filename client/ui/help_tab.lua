-- ui/help_tab.lua
local function setupHelpTab(tab)
    tab:addLabel()
        :setPosition(2, 2)
        :setText("Help / documentation here.")
end
return setupHelpTab