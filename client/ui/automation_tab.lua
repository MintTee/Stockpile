-- /stockpile_client/ui/automation_tab.lua
local bas = require("lib.basalt")
local app = require("app")
local comms = require("src.comms")
local parser = require("ui.automation_parser")
local data = require("src.data")

local AUTOMATION_STATE_FILE = "/stockpile_client/config/automation_pairs.txt"

local function setupAutomationTab(tab)
    local ui = {}
    local allPairs = {}
    local suppress_save = false

    local redstoneState = {}
    for _, side in ipairs(redstone.getSides()) do
        redstoneState[side] = redstone.getAnalogInput(side)
    end

    local H, W = tab:getHeight(), tab:getWidth()
    local PAIR_HEIGHT = 10
    local BOX_HEIGHT  = 5
    local halfW       = math.floor(W / 2)

    local addBtn = tab:addButton()
        :setPosition(2, 2):setSize(14, 1)
        :setText("+ New Pair"):setBackground(colors.green)
        :onClick(function() ui:addPair() end)
    addBtn.z = 20

    ui.pairsFrame = tab:addFrame()
        :setPosition(2, 4)
        :setSize(W, H - 4)
        :setScrollable(true)
    ui.pairsFrame.z = 1

    -- =====================================================================
    -- Pair factory
    -- =====================================================================
    local function createPair(index)
        local pair = {}
        pair.isRunning    = false
        pair.parsedOK     = true
        pair.conditionAst = nil
        pair.commandList  = {}
        pair.periodTimers = {}
        pair.lastMet      = false
        pair.metGeneration = 0

        local yBase = (index - 1) * (PAIR_HEIGHT + 1) + 1

        pair.frame = ui.pairsFrame:addFrame()
            :setPosition(1, yBase)
            :setSize(W - 5, PAIR_HEIGHT)
            :setBackground(colors.gray)
            :addBorder()
        pair.frame.z = 100 - index

        pair.titleLabel = pair.frame:addLabel()
            :setPosition(2, 1):setText("Pair " .. index):setForeground(colors.white)

        pair.toggleButton = pair.frame:addButton()
            :setPosition(13, 1):setSize(6, 1)
            :setText("OFF"):setBackground(colors.red)
            :onClick(function() pair:toggle() end)
        pair.toggleButton.z = 20

        pair.parseStatusLabel = pair.frame:addLabel()
            :setPosition(21, 1):setText(""):setForeground(colors.gray)

        local delBtn = pair.frame:addButton()
            :setPosition(pair.frame:getWidth() - 2, 1):setSize(2, 1)
            :setText("x"):setBackground(colors.red):setForeground(colors.white)
            :onClick(function() ui:removePair(pair) end)
        delBtn.z = 20

        pair.frame:addLabel():setPosition(2, 2):setText("Conditions:"):setForeground(colors.white)
        pair.frame:addLabel():setPosition(halfW + 2, 2):setText("Commands:"):setForeground(colors.white)

        pair.conditionsBox = pair.frame:addTextBox()
            :setPosition(2, 3)
            :setSize(halfW - 4, BOX_HEIGHT)
            :setBackground(colors.black)
            :setForeground(colors.white)
            :setEditable(true)
        pair.conditionsBox.set("name", "cond_box")
        pair.conditionsBox.z = 10

        pair.commandsBox = pair.frame:addTextBox()
            :setPosition(halfW + 2, 3)
            :setSize(halfW - 4, BOX_HEIGHT)
            :setBackground(colors.black)
            :setForeground(colors.white)
            :setEditable(true)
        pair.commandsBox.set("name", "cmd_box")
        pair.commandsBox.z = 10

        local condPatterns = {
            { "%f[%w_]and%f[%W]",  colors.orange },
            { "%f[%w_]or%f[%W]",   colors.orange },
            { "%f[%w_]xor%f[%W]",  colors.orange },
            { "%f[%w_]not%f[%W]",  colors.red },
            { "%f[%w_]period%f[%W]",   colors.lightBlue },
            { "%f[%w_]redstone%f[%W]", colors.lightBlue },
            { "%f[%w_]item_qty%f[%W]", colors.lightBlue },
        }
        for _, p in ipairs(condPatterns) do
            pair.conditionsBox:addSyntaxPattern(p[1], p[2])
        end
        pair.commandsBox:addSyntaxPattern("%f[%w_]scan_group%f[%W]", colors.lightBlue)
        pair.commandsBox:addSyntaxPattern("%f[%w_]move_item%f[%W]",  colors.lightBlue)

        pair.statusLabel = pair.frame:addLabel()
            :setPosition(2, 8):setText("Idle"):setForeground(colors.gray)

        pair.metLabel = pair.frame:addLabel()
            :setPosition(halfW + 2, 8):setText(""):setForeground(colors.yellow)

        local testBtn = pair.frame:addButton()
            :setPosition(2, 9):setSize(8, 1)
            :setText("Test"):setBackground(colors.orange)
            :onClick(function() pair:test() end)
        testBtn.z = 20

        local clearBtn = pair.frame:addButton()
            :setPosition(11, 9):setSize(8, 1)
            :setText("Clear"):setBackground(colors.lightGray)
            :onClick(function()
                pair.conditionsBox:setText("")
                pair.commandsBox:setText("")
                pair:tryParse()
            end)
        clearBtn.z = 20

        -- ================================================================
        -- Pair methods
        -- ================================================================
        function pair:setStatus(text, color)
            self.statusLabel:setText(text)
            self.statusLabel:setForeground(color or colors.gray)
        end

        function pair:flashMet()
            self.metGeneration = self.metGeneration + 1
            local gen = self.metGeneration
            self.metLabel:setText("MET " .. os.date("%H:%M:%S"))
            self.metLabel:setForeground(colors.yellow)
            bas.schedule(function()
                sleep(2)
                if self.metGeneration == gen then
                    self.metLabel:setText("")
                end
            end)
        end

        function pair:tryParse()
            local condText = self.conditionsBox:getText()
            local cmdText  = self.commandsBox:getText()

            if condText:match("^%s*$") then
                self.conditionAst = nil
                self.commandList  = {}
                self.parsedOK     = true
                self.parseStatusLabel:setText("empty"):setForeground(colors.gray)
                return true
            end

            local ok, result = pcall(parser.parse, condText, "condition")
            if not ok then
                self.conditionAst = nil
                self.commandList  = {}
                self.parsedOK     = false
                local msg = tostring(result):gsub("^.-:%d+:%s*", ""):sub(1, 40)
                self.parseStatusLabel:setText(msg):setForeground(colors.red)
                return false
            end

            local newCommands = {}
            local lineNum = 0
            for line in cmdText:gmatch("[^\n]+") do
                lineNum = lineNum + 1
                line = line:match("^%s*(.-)%s*$")
                if line ~= "" then
                    local ok2, ast = pcall(parser.parse, line, "command")
                    if not ok2 then
                        self.conditionAst = nil
                        self.commandList  = {}
                        self.parsedOK     = false
                        local msg = tostring(ast):gsub("^.-:%d+:%s*", ""):sub(1, 32)
                        self.parseStatusLabel:setText("L" .. lineNum .. ": " .. msg)
                            :setForeground(colors.red)
                        return false
                    end
                    newCommands[#newCommands + 1] = ast
                end
            end

            self.conditionAst = result
            self.commandList  = newCommands
            self.parsedOK     = true
            self.parseStatusLabel:setText("parsed"):setForeground(colors.green)
            return true
        end

        function pair:evaluateCondition(name, args, curState)
            if name == "period" then
                local interval = (args[1] and args[1].value) or 60
                local key      = "period:" .. tostring(interval)
                local now      = os.epoch("local") / 1000
                local nextFire = self.periodTimers[key]
                if not nextFire then
                    self.periodTimers[key] = now + interval
                    return false
                end
                if now >= nextFire then
                    self.periodTimers[key] = now + interval
                    return true
                end
                return false

            elseif name == "redstone" then
                local side  = args[1] and args[1].value
                local op    = args[2] and args[2].value
                local level = (args[3] and args[3].value) or 0

                local cur  = curState[side] or 0
                local prev = redstoneState[side] or cur

                if op == ">"           then return cur > level
                elseif op == "<"       then return cur < level
                elseif op == "="       then return cur == level
                elseif op == "rising"  then return cur > prev
                elseif op == "falling" then return cur < prev
                elseif op == "delta_any" then return cur ~= prev
                end
                return false

            elseif name == "item_qty" then
                local itemName = args[1] and args[1].value
                local group    = args[2] and args[2].value
                local op       = args[3] and args[3].value
                local qty      = (args[4] and args[4].value) or 0

                local searchLogic = require("logic.search")
                local results = searchLogic.run(itemName or "", "", group or "all",
                                                app.groups, app.item_index, app.inv_index)
                local total = 0
                for _, v in ipairs(results) do total = total + v.total end

                if op == ">" then return total > qty
                elseif op == "<" then return total < qty
                elseif op == "=" then return total == qty
                end
                return false
            end
            return false
        end

        function pair:executeCommand(ast)
            if ast.type ~= "condition" then return end
            local name = ast.name
            local args = ast.args

            local function val(a) return a and a.value end

            if name == "scan_group" then
                local group = val(args[1])
                local invs  = app.groups[group] or {}
                if #invs > 0 then
                    comms.scanAsync(invs, function(result)
                        if result and result.status == "done" then
                            comms.getContentAsync(app, function() end)
                        end
                    end)
                end

            elseif name == "move_item" then
                local itemName  = val(args[1])
                local fromGroup = val(args[2])
                local toGroup   = val(args[3])
                local qty       = (args[4] and args[4].value) or 0

                local moveLogic = require("logic.move")
                moveLogic.performMove(fromGroup, toGroup, "of each", qty,
                    {{ id = itemName }}, function(success)
                        if success then
                            comms.getContentAsync(app, function() end)
                        end
                    end)
            end
        end

        function pair:test()
            self:tryParse()
            if not self.parsedOK then
                self:setStatus("Fix parse errors first", colors.red)
                return
            end
            if not self.conditionAst then
                self:setStatus("No conditions", colors.yellow)
                return
            end
            local ctx = {
                evaluate_condition = function(n, a)
                    return self:evaluateCondition(n, a, redstoneState)
                end
            }
            local ok, result = pcall(parser.evaluate, self.conditionAst, ctx)
            if not ok then
                self:setStatus("Eval error: " .. tostring(result):sub(1, 30), colors.red)
                return
            end
            if result then
                self:setStatus("Test: met", colors.green)
                self:flashMet()
                for _, cmd in ipairs(self.commandList) do
                    self:executeCommand(cmd)
                end
            else
                self:setStatus("Test: not met", colors.yellow)
            end
        end

        function pair:toggle()
            if self.isRunning then
                self.isRunning = false
                self.toggleButton:setText("OFF"):setBackground(colors.red)
                self.metLabel:setText("")
                self:setStatus("Stopped", colors.gray)
                if not suppress_save then ui:save_pairs() end   -- <-- ADD
                return
            end

            self:tryParse()
            if not self.parsedOK then
                self:setStatus("Fix parse errors first", colors.red)
                return
            end
            if not self.conditionAst then
                self:setStatus("Nothing to run", colors.yellow)
                return
            end

            self.periodTimers = {}
            self.lastMet      = false
            self.isRunning    = true
            self.toggleButton:setText("ON"):setBackground(colors.green)
            self:setStatus("Running...", colors.green)
            if not suppress_save then ui:save_pairs() end       -- <-- ADD
        end

        function pair:evaluateAndExecute(curState)
            if not self.isRunning or not self.conditionAst then return end
            local ctx = {
                evaluate_condition = function(n, a)
                    return self:evaluateCondition(n, a, curState)
                end
            }
            local ok, result = pcall(parser.evaluate, self.conditionAst, ctx)
            if not ok then return end

            if result then
                if not self.lastMet then
                    self:flashMet()
                end
                for _, cmd in ipairs(self.commandList) do
                    self:executeCommand(cmd)
                end
            end
            self.lastMet = result
        end

        local function hookTextBox(box)
            local origChar  = box.char
            local origKey   = box.key
            local origPaste = box.paste

            box.char = function(self, ...)
                local r = origChar(self, ...)
                pair:tryParse()
                return r
            end
            box.key = function(self, ...)
                local r = origKey(self, ...)
                pair:tryParse()
                return r
            end
            box.paste = function(self, ...)
                local r = origPaste(self, ...)
                pair:tryParse()
                return r
            end
        end

        hookTextBox(pair.conditionsBox)
        hookTextBox(pair.commandsBox)

        return pair
    end

    -- =====================================================================
    -- Tab methods
    -- =====================================================================
    function ui:addPair()
        local pair = createPair(#allPairs + 1)
        allPairs[#allPairs + 1] = pair
        pair.conditionsBox:setText("period(60)")
        pair.commandsBox:setText("scan_group(input)")
        pair:tryParse()
        ui:updateLayout()
        return pair
    end

    function ui:removePair(pair)
        for i, p in ipairs(allPairs) do
            if p == pair then
                table.remove(allPairs, i)
                break
            end
        end
        pair.isRunning = false
        pair.frame:destroy()
        ui:updateLayout()
    end

    function ui:updateLayout()
        for i, pair in ipairs(allPairs) do
            pair.frame:setPosition(1, (i - 1) * (PAIR_HEIGHT + 1) + 1)
            pair.frame:set("z", 100 - i)
            pair.titleLabel:setText("Pair " .. i)
        end
    end

    -- =====================================================================
    -- Persistent pair data (separate file, because the number of pairs
    -- is variable and the tree-walk state can't create new pairs)
    -- =====================================================================

    --- Collect the current pair list into a plain serializable table.
    function ui:getPersistentData()
        local out = {}
        for i, pair in ipairs(allPairs) do
            out[i] = {
                cond    = pair.conditionsBox:getText(),
                cmd     = pair.commandsBox:getText(),
                running = pair.isRunning,
            }
        end
        return out
    end

    --- Write the pair list to disk.
    function ui:save_pairs()
        local ok, err = pcall(function()
            data.save(AUTOMATION_STATE_FILE,
                      textutils.serialise(ui:getPersistentData()))
        end)
        if not ok then
            bas.LOGGER.error("automation save_pairs failed: " .. tostring(err))
        end
    end

    --- Replace every existing pair with the ones in the saved file.
    --- Returns true if anything was loaded.
    function ui:load_pairs()
        if not fs.exists(AUTOMATION_STATE_FILE) then return false end
        local ok, pairs_data = pcall(function()
            local s = data.load(AUTOMATION_STATE_FILE)
            if not s or s == "" then return nil end
            return textutils.unserialize(s)
        end)
        if not ok or type(pairs_data) ~= "table" or #pairs_data == 0 then
            return false
        end

        suppress_save = true    -- <-- ADD

        while #allPairs > 0 do
            ui:removePair(allPairs[#allPairs])
        end

        for _, p in ipairs(pairs_data) do
            local pair = ui:addPair()
            pair.conditionsBox:setText(p.cond or "")
            pair.commandsBox:setText(p.cmd   or "")
            pair:tryParse()
            if p.running then
                if pair.conditionAst then
                    pair:toggle()
                end
            end
        end

        if #allPairs == 0 then
            ui:addPair()
        end

        suppress_save = false   -- <-- ADD
        return true
    end

    --- Kept for compatibility with main.lua's load orchestration.
    --- The pair data is already parsed inside load_pairs, so this is
    --- essentially a safety net if load_pairs was never called.
    function ui:afterStateLoad()
        for _, pair in ipairs(allPairs) do
            pair:tryParse()
        end
    end

    -- =====================================================================
    -- Shared event handling
    -- =====================================================================
    bas.onEvent("redstone", function()
        local newState = {}
        for _, side in ipairs(redstone.getSides()) do
            newState[side] = redstone.getAnalogInput(side)
        end

        for _, pair in ipairs(allPairs) do
            pair:evaluateAndExecute(newState)
        end

        for side, level in pairs(newState) do
            redstoneState[side] = level
        end
    end)

    bas.schedule(function()
        while true do
            sleep(1)
            for _, pair in ipairs(allPairs) do
                pair:evaluateAndExecute(redstoneState)
            end
        end
    end)

    ui:addPair()
    return ui
end

return setupAutomationTab