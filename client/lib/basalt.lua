local minified = true
local minified_elementDirectory = {}
local minified_pluginDirectory = {}
local project = {}
local loadedProject = {}
local baseRequire = require
require = function(path) if(project[path..".lua"])then if(loadedProject[path]==nil)then loadedProject[path] = project[path..".lua"]() end return loadedProject[path] end baseRequire(path) end
minified_elementDirectory["Timer"] = {}
minified_elementDirectory["ScrollBar"] = {}
minified_elementDirectory["TextBox"] = {}
minified_elementDirectory["Slider"] = {}
minified_elementDirectory["List"] = {}
minified_elementDirectory["Image"] = {}
minified_elementDirectory["DropDown"] = {}
minified_elementDirectory["Label"] = {}
minified_elementDirectory["CheckBox"] = {}
minified_elementDirectory["VisualElement"] = {}
minified_elementDirectory["Program"] = {}
minified_elementDirectory["BarChart"] = {}
minified_pluginDirectory["state"] = {}
minified_pluginDirectory["benchmark"] = {}
minified_elementDirectory["BigFont"] = {}
minified_pluginDirectory["debug"] = {}
minified_elementDirectory["SideNav"] = {}
minified_elementDirectory["TabControl"] = {}
minified_elementDirectory["Menu"] = {}
minified_pluginDirectory["reactive"] = {}
minified_pluginDirectory["animation"] = {}
minified_pluginDirectory["canvas"] = {}
minified_pluginDirectory["xml"] = {}
minified_elementDirectory["LineChart"] = {}
minified_elementDirectory["FlexBox"] = {}
minified_elementDirectory["Container"] = {}
minified_elementDirectory["ComboBox"] = {}
minified_elementDirectory["Switch"] = {}
minified_elementDirectory["Display"] = {}
minified_elementDirectory["Table"] = {}
minified_elementDirectory["BaseFrame"] = {}
minified_elementDirectory["BaseElement"] = {}
minified_elementDirectory["Input"] = {}
minified_elementDirectory["ProgressBar"] = {}
minified_elementDirectory["Tree"] = {}
minified_elementDirectory["Graph"] = {}
minified_elementDirectory["Button"] = {}
minified_elementDirectory["Frame"] = {}
minified_pluginDirectory["theme"] = {}
project["elementManager.lua"] = function(...) local args = table.pack(...)
local dir = fs.getDir(args[2] or "basalt")
local subDir = args[1]
if(dir==nil)then
    error("Unable to find directory "..args[2].." please report this bug to our discord.")
end

local log = require("log")
local defaultPath = package.path
local format = "path;/path/?.lua;/path/?/init.lua;"
local main = format:gsub("path", dir)

--- This class manages elements and plugins. It loads elements and plugins from the elements and plugins directories
--- and then applies the plugins to the elements. It also provides a way to get elements and APIs.
--- @class ElementManager
local ElementManager = {}
ElementManager._elements = {}
ElementManager._plugins = {}
ElementManager._APIs = {}
local elementsDirectory = fs.combine(dir, "elements")
local pluginsDirectory = fs.combine(dir, "plugins")

log.info("Loading elements from "..elementsDirectory)
if fs.exists(elementsDirectory) then
    for _, file in ipairs(fs.list(elementsDirectory)) do
        local name = file:match("(.+).lua")
        if name then
            log.debug("Found element: "..name)
            ElementManager._elements[name] = {
                class = nil,
                plugins = {},
                loaded = false
            }
        end
    end
end

log.info("Loading plugins from "..pluginsDirectory)
if fs.exists(pluginsDirectory) then
    for _, file in ipairs(fs.list(pluginsDirectory)) do
        local name = file:match("(.+).lua")
        if name then
            log.debug("Found plugin: "..name)
            local plugin = require(fs.combine("plugins", name))
            if type(plugin) == "table" then
                for k,v in pairs(plugin) do
                    if(k ~= "API")then
                        if(ElementManager._plugins[k]==nil)then
                            ElementManager._plugins[k] = {}
                        end
                        table.insert(ElementManager._plugins[k], v)
                    else
                        ElementManager._APIs[name] = v
                    end
                end
            end
        end
    end
end

if(minified)then
    if(minified_elementDirectory==nil)then
        error("Unable to find minified_elementDirectory please report this bug to our discord.")
    end
    for name,v in pairs(minified_elementDirectory)do
        ElementManager._elements[name:gsub(".lua", "")] = {
            class = nil,
            plugins = {},
            loaded = false
        }
    end
    if(minified_pluginDirectory==nil)then
        error("Unable to find minified_pluginDirectory please report this bug to our discord.")
    end
    for name,_ in pairs(minified_pluginDirectory)do
        local plugName = name:gsub(".lua", "")
        local plugin = require(fs.combine("plugins", plugName))
        if type(plugin) == "table" then
            for k,v in pairs(plugin) do
                if(k ~= "API")then
                    if(ElementManager._plugins[k]==nil)then
                        ElementManager._plugins[k] = {}
                    end
                    table.insert(ElementManager._plugins[k], v)
                else
                    ElementManager._APIs[plugName] = v
                end
            end
        end
    end
end

--- Loads an element by name. This will load the element and apply any plugins to it.
--- @param name string The name of the element to load
--- @usage ElementManager.loadElement("Button")
function ElementManager.loadElement(name)
    if not ElementManager._elements[name].loaded then
        package.path = main.."rom/?"
        local element = require(fs.combine("elements", name))
        package.path = defaultPath
        ElementManager._elements[name] = {
            class = element,
            plugins = element.plugins,
            loaded = true
        }
        log.debug("Loaded element: "..name)

        if(ElementManager._plugins[name]~=nil)then
            for _, plugin in pairs(ElementManager._plugins[name]) do
                if(plugin.setup)then
                    plugin.setup(element)
                end

                if(plugin.hooks)then
                    for methodName, hooks in pairs(plugin.hooks) do
                        local original = element[methodName]
                        if(type(original)~="function")then
                            error("Element "..name.." does not have a method "..methodName)
                        end
                        if(type(hooks)=="function")then
                            element[methodName] = function(self, ...)
                                local result = original(self, ...)
                                local hookResult = hooks(self, ...)
                                return hookResult == nil and result or hookResult
                            end
                        elseif(type(hooks)=="table")then
                            element[methodName] = function(self, ...)
                                if hooks.pre then hooks.pre(self, ...) end
                                local result = original(self, ...)
                                if hooks.post then hooks.post(self, ...) end
                                return result
                            end
                        end
                    end
                end

                for funcName, func in pairs(plugin) do
                    if funcName ~= "setup" and funcName ~= "hooks" then
                        element[funcName] = func
                    end
                end
            end
        end
    end
end

--- Gets an element by name. If the element is not loaded, it will try to load it first.
--- @param name string The name of the element to get
--- @return table Element The element class
function ElementManager.getElement(name)
    if not ElementManager._elements[name].loaded then
        ElementManager.loadElement(name)
    end
    return ElementManager._elements[name].class
end

--- Gets a list of all elements
--- @return table ElementList A list of all elements
function ElementManager.getElementList()
    return ElementManager._elements
end

--- Gets an Plugin API by name
--- @param name string The name of the API to get
--- @return table API The API
function ElementManager.getAPI(name)
    return ElementManager._APIs[name]
end

return ElementManager end
project["elements/Timer.lua"] = function(...) local elementManager = require("elementManager")
local BaseElement = elementManager.getElement("BaseElement")
---@cofnigDescription The Timer is a non-visual element that can be used to perform actions at specific intervals.

--- The Timer is a non-visual element that can be used to perform actions at specific intervals.
---@class Timer : BaseElement
local Timer = setmetatable({}, BaseElement)
Timer.__index = Timer

---@property interval number 1 The interval in seconds at which the timer will trigger its action.
Timer.defineProperty(Timer, "interval", {default = 1, type = "number"})
---@property action function function The action to be performed when the timer triggers.
Timer.defineProperty(Timer, "action", {default = function() end, type = "function"})
---@property running boolean false Indicates whether the timer is currently running or not.
Timer.defineProperty(Timer, "running", {default = false, type = "boolean"})
---@property amount number -1 The amount of time the timer should run.
Timer.defineProperty(Timer, "amount", {default = -1, type = "number"})

Timer.defineEvent(Timer, "timer")

--- @shortDescription Creates a new Timer instance
--- @return table self The created instance
--- @private
function Timer.new()
    local self = setmetatable({}, Timer):__init()
    self.class = Timer
    return self
end

--- @shortDescription Initializes the Timer instance
--- @param props table The properties to initialize the element with
--- @param basalt table The basalt instance
--- @protected
function Timer:init(props, basalt)
    BaseElement.init(self, props, basalt)
    self.set("type", "Timer")
end

--- Starts the timer with the specified interval.
--- @shortDescription Starts the timer
--- @param self Timer The Timer instance to start
--- @return Timer self The Timer instance
function Timer:start()
    if not self.running then
        self.running = true
        local time = self.get("interval")
        self.timerId = os.startTimer(time)
    end
    return self
end

--- Stops the timer if it is currently running.
--- @shortDescription Stops the timer
--- @param self Timer The Timer instance to stop
--- @return Timer self The Timer instance
function Timer:stop()
    if self.running then
        self.running = false
        os.cancelTimer(self.timerId)
    end
    return self
end

--- @protected
--- @shortDescription Dispatches events to the Timer instance
function Timer:dispatchEvent(event, ...)
    BaseElement.dispatchEvent(self, event, ...)
    if event == "timer" then
        local timerId = select(1, ...)
        if timerId == self.timerId then
            self.action()
            local amount = self.get("amount")
            if amount > 0 then
                self.set("amount", amount - 1)
            end
            if amount ~= 0 then
                self.timerId = os.startTimer(self.get("interval"))
            end
        end
    end
end

return Timer end
project["elements/ScrollBar.lua"] = function(...) local VisualElement = require("elements/VisualElement")
local tHex = require("libraries/colorHex")
---@configDescription A ScrollBar element that can be attached to other elements to control their scroll properties.

---A ScrollBar element that can be attached to other elements to control their scroll properties
---@class ScrollBar : VisualElement
local ScrollBar = setmetatable({}, VisualElement)
ScrollBar.__index = ScrollBar

---@property value number 0 Current scroll value
ScrollBar.defineProperty(ScrollBar, "value", {default = 0, type = "number", canTriggerRender = true})
---@property min number 0 Minimum scroll value
ScrollBar.defineProperty(ScrollBar, "min", {default = 0, type = "number", canTriggerRender = true})
---@property max number 100 Maximum scroll value
ScrollBar.defineProperty(ScrollBar, "max", {default = 100, type = "number", canTriggerRender = true})
---@property step number 1 Step size for scroll operations
ScrollBar.defineProperty(ScrollBar, "step", {default = 10, type = "number"})
---@property dragMultiplier number 1 How fast the ScrollBar moves when dragging
ScrollBar.defineProperty(ScrollBar, "dragMultiplier", {default = 1, type = "number"})
---@property symbol string " " Symbol used for the ScrollBar handle
ScrollBar.defineProperty(ScrollBar, "symbol", {default = " ", type = "string", canTriggerRender = true})
---@property backgroundSymbol string "\127" Symbol used for the ScrollBar background
ScrollBar.defineProperty(ScrollBar, "symbolColor", {default = colors.gray, type = "color", canTriggerRender = true})
---@property symbolBackgroundColor color black Background color of the ScrollBar handle
ScrollBar.defineProperty(ScrollBar, "symbolBackgroundColor", {default = colors.black, type = "color", canTriggerRender = true})
---@property backgroundSymbol string "\127" Symbol used for the ScrollBar background
ScrollBar.defineProperty(ScrollBar, "backgroundSymbol", {default = "\127", type = "string", canTriggerRender = true})
---@property attachedElement table? nil The element this ScrollBar is attached to
ScrollBar.defineProperty(ScrollBar, "attachedElement", {default = nil, type = "table"})
---@property attachedProperty string? nil The property being controlled
ScrollBar.defineProperty(ScrollBar, "attachedProperty", {default = nil, type = "string"})
---@property minValue number|function 0 Minimum value or function that returns it
ScrollBar.defineProperty(ScrollBar, "minValue", {default = 0, type = "number"})
---@property maxValue number|function 100 Maximum value or function that returns it
ScrollBar.defineProperty(ScrollBar, "maxValue", {default = 100, type = "number"})
---@property orientation string vertical Orientation of the ScrollBar ("vertical" or "horizontal")
ScrollBar.defineProperty(ScrollBar, "orientation", {default = "vertical", type = "string", canTriggerRender = true})

---@property handleSize number 2 Size of the ScrollBar handle in characters
ScrollBar.defineProperty(ScrollBar, "handleSize", {default = 2, type = "number", canTriggerRender = true})

ScrollBar.defineEvent(ScrollBar, "mouse_click")
ScrollBar.defineEvent(ScrollBar, "mouse_release")
ScrollBar.defineEvent(ScrollBar, "mouse_drag")
ScrollBar.defineEvent(ScrollBar, "mouse_scroll")

--- Creates a new ScrollBar instance
--- @shortDescription Creates a new ScrollBar instance
--- @return ScrollBar self The newly created ScrollBar instance
--- @private
function ScrollBar.new()
    local self = setmetatable({}, ScrollBar):__init()
    self.class = ScrollBar
    self.set("width", 1)
    self.set("height", 10)
    return self
end

--- @shortDescription Initializes the ScrollBar instance
--- @param props table The properties to initialize the element with
--- @param basalt table The basalt instance
--- @return ScrollBar self The initialized instance
--- @protected
function ScrollBar:init(props, basalt)
    VisualElement.init(self, props, basalt)
    self.set("type", "ScrollBar")
    return self
end

--- Attaches the ScrollBar to an element's property
--- @shortDescription Attaches the ScrollBar to an element's property
--- @param element BaseElement The element to attach to
--- @param config table Configuration {property = "propertyName", min = number|function, max = number|function}
--- @return ScrollBar self The ScrollBar instance
function ScrollBar:attach(element, config)
    self.set("attachedElement", element)
    self.set("attachedProperty", config.property)
    self.set("minValue", config.min or 0)
    self.set("maxValue", config.max or 100)
    element:observe(config.property, function(_, value)
        if value then
            local min = self.get("minValue")
            local max = self.get("maxValue")
            if min == max then return end
            
            self.set("value", math.floor(
                (value - min) / (max - min) * 100 + 0.5
            ))
        end
    end)
    return self
end

--- Updates the attached element's property based on the ScrollBar value
--- @shortDescription Updates the attached element's property based on the ScrollBar value
--- @return ScrollBar self The ScrollBar instance
function ScrollBar:updateAttachedElement()
    local element = self.get("attachedElement")
    if not element then return end

    local value = self.get("value")
    local min = self.get("minValue")
    local max = self.get("maxValue")

    if type(min) == "function" then min = min() end
    if type(max) == "function" then max = max() end

    local mappedValue = min + (value / 100) * (max - min)
    element.set(self.get("attachedProperty"), math.floor(mappedValue + 0.5))
    return self
end

local function getScrollbarSize(self)
    return self.get("orientation") == "vertical" and self.get("height") or self.get("width")
end

local function getRelativeScrollPosition(self, x, y)
    local relX, relY = self:getRelativePosition(x, y)
    return self.get("orientation") == "vertical" and relY or relX
end

--- @shortDescription Handles mouse click events
--- @param button number The mouse button clicked
--- @param x number The x position of the click
--- @param y number The y position of the click
--- @return boolean Whether the event was handled
--- @protected
function ScrollBar:mouse_click(button, x, y)
    if VisualElement.mouse_click(self, button, x, y) then
        local size = getScrollbarSize(self)
        local value = self.get("value")
        local handleSize = self.get("handleSize")

        local handlePos = math.floor((value / 100) * (size - handleSize)) + 1
        local relPos = getRelativeScrollPosition(self, x, y)

        if relPos >= handlePos and relPos < handlePos + handleSize then
            self.dragOffset = relPos - handlePos
        else
            local newValue = ((relPos - 1) / (size - handleSize)) * 100
            self.set("value", math.min(100, math.max(0, newValue)))
            self:updateAttachedElement()
        end
        return true
    end
end

--- @shortDescription Handles mouse drag events
--- @param button number The mouse button being dragged
--- @param x number The x position of the drag
--- @param y number The y position of the drag
--- @return boolean Whether the event was handled
--- @protected
function ScrollBar:mouse_drag(button, x, y)
    if(VisualElement.mouse_drag(self, button, x, y))then
        local size = getScrollbarSize(self)
        local handleSize = self.get("handleSize")
        local dragMultiplier = self.get("dragMultiplier")
        local relPos = getRelativeScrollPosition(self, x, y)

        relPos = math.max(1, math.min(size, relPos))

        local newPos = relPos - (self.dragOffset or 0)
        local newValue = (newPos - 1) / (size - handleSize) * 100 * dragMultiplier

        self.set("value", math.min(100, math.max(0, newValue)))
        self:updateAttachedElement()
        return true
    end
end

--- @shortDescription Handles mouse scroll events
--- @param direction number The scroll direction (1 for up, -1 for down)
--- @param x number The x position of the scroll
--- @param y number The y position of the scroll
--- @return boolean Whether the event was handled
--- @protected
function ScrollBar:mouse_scroll(direction, x, y)
    if not self:isInBounds(x, y) then return false end
    direction = direction > 0 and -1 or 1
    local step = self.get("step")
    local currentValue = self.get("value")
    local newValue = currentValue - direction * step

    self.set("value", math.min(100, math.max(0, newValue)))
    self:updateAttachedElement()
    return true
end

--- @shortDescription Renders the ScrollBar
--- @protected
function ScrollBar:render()
    VisualElement.render(self)

    local size = getScrollbarSize(self)
    local value = self.get("value")
    local handleSize = self.get("handleSize")
    local symbol = self.get("symbol")
    local symbolColor = self.get("symbolColor")
    local symbolBackgroundColor = self.get("symbolBackgroundColor")
    local bgSymbol = self.get("backgroundSymbol")
    local isVertical = self.get("orientation") == "vertical"

    local handlePos = math.floor((value / 100) * (size - handleSize)) + 1

    for i = 1, size do
        if isVertical then
            self:blit(1, i, bgSymbol, tHex[self.get("foreground")], tHex[self.get("background")])
        else
            self:blit(i, 1, bgSymbol, tHex[self.get("foreground")], tHex[self.get("background")])
        end
    end

    for i = handlePos, handlePos + handleSize - 1 do
        if isVertical then
            self:blit(1, i, symbol, tHex[symbolColor], tHex[symbolBackgroundColor])
        else
            self:blit(i, 1, symbol, tHex[symbolColor], tHex[symbolBackgroundColor])
        end
    end
end

return ScrollBar
 end
project["elements/TextBox.lua"] = function(...) ---@diagnostic disable: duplicate-set-field
local VisualElement = require("elements/VisualElement")
local tHex = require("libraries/colorHex")
---@configDescription A multi-line text editor component with cursor support and text manipulation features
---@configDefault false

---A multi-line text editor component with cursor support and text manipulation features
---@class TextBox : VisualElement
local TextBox = setmetatable({}, VisualElement)
TextBox.__index = TextBox

---@property lines table {} Array of text lines
TextBox.defineProperty(TextBox, "lines", {default = {""}, type = "table", canTriggerRender = true})
---@property cursorX number 1 Cursor X position
TextBox.defineProperty(TextBox, "cursorX", {default = 1, type = "number"})
---@property cursorY number 1 Cursor Y position (line number)
TextBox.defineProperty(TextBox, "cursorY", {default = 1, type = "number"})
---@property scrollX number 0 Horizontal scroll offset
TextBox.defineProperty(TextBox, "scrollX", {default = 0, type = "number", canTriggerRender = true})
---@property scrollY number 0 Vertical scroll offset
TextBox.defineProperty(TextBox, "scrollY", {default = 0, type = "number", canTriggerRender = true})
---@property editable boolean true Whether text can be edited
TextBox.defineProperty(TextBox, "editable", {default = true, type = "boolean"})
---@property syntaxPatterns table {} Syntax highlighting patterns
TextBox.defineProperty(TextBox, "syntaxPatterns", {default = {}, type = "table"})
---@property cursorColor number nil Color of the cursor
TextBox.defineProperty(TextBox, "cursorColor", {default = nil, type = "color"})
---@property autoPairEnabled boolean true Whether automatic bracket/quote pairing is enabled
TextBox.defineProperty(TextBox, "autoPairEnabled", {default = true, type = "boolean"})
---@property autoPairCharacters table { ["("]=")", ["["]="]", ["{"]="}", ['"']='"', ['\'']='\'', ['`']='`'} Mapping of opening to closing characters for auto pairing
TextBox.defineProperty(TextBox, "autoPairCharacters", {default = { ["("]=")", ["["]="]", ["{"]="}", ['"']='"', ['\'']='\'', ['`']='`' }, type = "table"})
---@property autoPairSkipClosing boolean true Skip inserting a closing char if the same one is already at cursor
TextBox.defineProperty(TextBox, "autoPairSkipClosing", {default = true, type = "boolean"})
---@property autoPairOverType boolean true When pressing a closing char that matches the next char, move over it instead of inserting
TextBox.defineProperty(TextBox, "autoPairOverType", {default = true, type = "boolean"})
---@property autoPairNewlineIndent boolean true On Enter between matching braces, create blank line and keep closing aligned
TextBox.defineProperty(TextBox, "autoPairNewlineIndent", {default = true, type = "boolean"})
---@property autoCompleteEnabled boolean false Whether autocomplete suggestions are enabled
TextBox.defineProperty(TextBox, "autoCompleteEnabled", {default = false, type = "boolean"})
---@property autoCompleteItems table {} List of suggestions used when no provider is supplied
TextBox.defineProperty(TextBox, "autoCompleteItems", {default = {}, type = "table"})
---@property autoCompleteProvider function nil Optional suggestion provider returning a list for the current prefix
TextBox.defineProperty(TextBox, "autoCompleteProvider", {default = nil, type = "function", allowNil = true})
---@property autoCompleteMinChars number 1 Minimum characters required before showing suggestions
TextBox.defineProperty(TextBox, "autoCompleteMinChars", {default = 1, type = "number"})
---@property autoCompleteMaxItems number 6 Maximum number of visible suggestions
TextBox.defineProperty(TextBox, "autoCompleteMaxItems", {default = 6, type = "number"})
---@property autoCompleteCaseInsensitive boolean true Whether suggestions should match case-insensitively
TextBox.defineProperty(TextBox, "autoCompleteCaseInsensitive", {default = true, type = "boolean"})
---@property autoCompleteTokenPattern string "[%w_]+" Pattern used to extract the current token for suggestions
TextBox.defineProperty(TextBox, "autoCompleteTokenPattern", {default = "[%w_]+", type = "string"})
---@property autoCompleteOffsetX number 0 Horizontal offset applied to the popup frame relative to the TextBox
TextBox.defineProperty(TextBox, "autoCompleteOffsetX", {default = 0, type = "number"})
---@property autoCompleteOffsetY number 1 Vertical offset applied to the popup frame relative to the TextBox bottom edge
TextBox.defineProperty(TextBox, "autoCompleteOffsetY", {default = 1, type = "number"})
---@property autoCompleteZOffset number 1 Z-index offset applied to the popup frame
TextBox.defineProperty(TextBox, "autoCompleteZOffset", {default = 1, type = "number"})
---@property autoCompleteMaxWidth number 0 Maximum width of the autocomplete popup (0 uses the textbox width)
TextBox.defineProperty(TextBox, "autoCompleteMaxWidth", {default = 0, type = "number"})
---@property autoCompleteShowBorder boolean true Whether to render a character border around the popup
TextBox.defineProperty(TextBox, "autoCompleteShowBorder", {default = true, type = "boolean"})
---@property autoCompleteBorderColor color black Color of the popup border when enabled
TextBox.defineProperty(TextBox, "autoCompleteBorderColor", {default = colors.black, type = "color"})
---@property autoCompleteBackground color lightGray Background color of the suggestion popup
TextBox.defineProperty(TextBox, "autoCompleteBackground", {default = colors.lightGray, type = "color"})
---@property autoCompleteForeground color black Foreground color of the suggestion popup
TextBox.defineProperty(TextBox, "autoCompleteForeground", {default = colors.black, type = "color"})
---@property autoCompleteSelectedBackground color gray Background color for the selected suggestion
TextBox.defineProperty(TextBox, "autoCompleteSelectedBackground", {default = colors.gray, type = "color"})
---@property autoCompleteSelectedForeground color white Foreground color for the selected suggestion
TextBox.defineProperty(TextBox, "autoCompleteSelectedForeground", {default = colors.white, type = "color"})
---@property autoCompleteAcceptOnEnter boolean true Whether pressing Enter accepts the current suggestion
TextBox.defineProperty(TextBox, "autoCompleteAcceptOnEnter", {default = true, type = "boolean"})
---@property autoCompleteAcceptOnClick boolean true Whether clicking a suggestion accepts it immediately
TextBox.defineProperty(TextBox, "autoCompleteAcceptOnClick", {default = true, type = "boolean"})
---@property autoCompleteCloseOnEscape boolean true Whether pressing Escape closes the popup
TextBox.defineProperty(TextBox, "autoCompleteCloseOnEscape", {default = true, type = "boolean"})

TextBox.defineEvent(TextBox, "mouse_click")
TextBox.defineEvent(TextBox, "key")
TextBox.defineEvent(TextBox, "char")
TextBox.defineEvent(TextBox, "mouse_scroll")
TextBox.defineEvent(TextBox, "paste")
TextBox.defineEvent(TextBox, "auto_complete_open")
TextBox.defineEvent(TextBox, "auto_complete_close")
TextBox.defineEvent(TextBox, "auto_complete_accept")

local updateAutoCompleteBorder
local layoutAutoCompleteList

local function autoCompleteVisible(self)
    local frame = self._autoCompleteFrame
    return frame and not frame._destroyed and frame.get and frame.get("visible")
end

local function getBorderPadding(self)
    return self.get("autoCompleteShowBorder") and 1 or 0
end

local function updateAutoCompleteStyles(self)
    local frame = self._autoCompleteFrame
    local list = self._autoCompleteList
    if not frame or frame._destroyed then return end
    frame:setBackground(self.get("autoCompleteBackground"))
    frame:setForeground(self.get("autoCompleteForeground"))
    if list and not list._destroyed then
        list:setBackground(self.get("autoCompleteBackground"))
        list:setForeground(self.get("autoCompleteForeground"))
        list:setSelectedBackground(self.get("autoCompleteSelectedBackground"))
        list:setSelectedForeground(self.get("autoCompleteSelectedForeground"))
        list:updateRender()
    end
    layoutAutoCompleteList(self)
    updateAutoCompleteBorder(self)
    frame:updateRender()
end

local function setAutoCompleteSelection(self, index, clampOnly)
    local list = self._autoCompleteList
    if not list or list._destroyed then return end
    local items = list.get("items")
    local count = #items
    if count == 0 then return end
    if index < 1 then index = 1 end
    if index > count then index = count end
    self._autoCompleteIndex = index

    for i, item in ipairs(items) do
        if type(item) == "table" then
            item.selected = (i == index)
        end
    end

    local height = list.get("height") or 0
    local offset = list.get("offset") or 0
    if not clampOnly and height > 0 then
        if index > offset + height then
            list:setOffset(math.max(0, index - height))
        elseif index <= offset then
            list:setOffset(math.max(0, index - 1))
        end
    end
    list:updateRender()
end

local function hideAutoComplete(self, silent)
    if autoCompleteVisible(self) then
        self._autoCompleteFrame:setVisible(false)
        if not silent then
            self:fireEvent("auto_complete_close")
        end
    end
    self._autoCompleteIndex = nil
    self._autoCompleteSuggestions = nil
    self._autoCompleteToken = nil
    self._autoCompleteTokenStart = nil
    self._autoCompletePopupWidth = nil
end

local function applyAutoCompleteSelection(self, item)
    local suggestions = self._autoCompleteSuggestions or {}
    local index = self._autoCompleteIndex or 1
    local entry = item or suggestions[index]
    if not entry then return end
    local insertText = entry.insert or entry.text or ""
    if insertText == "" then return end

    local lines = self.get("lines")
    local cursorY = self.get("cursorY")
    local cursorX = self.get("cursorX")
    local line = lines[cursorY] or ""
    local startIndex = self._autoCompleteTokenStart or cursorX
    if startIndex < 1 then startIndex = 1 end

    local before = line:sub(1, startIndex - 1)
    local after = line:sub(cursorX)
    lines[cursorY] = before .. insertText .. after

    self.set("cursorX", startIndex + #insertText)
    self:updateViewport()
    self:updateRender()
    hideAutoComplete(self, true)
    self:fireEvent("auto_complete_accept", insertText, entry.source or entry)
end

local function ensureAutoCompleteUI(self)
    if not self.get("autoCompleteEnabled") then return nil end
    local frame = self._autoCompleteFrame
    if frame and not frame._destroyed then
        return self._autoCompleteList
    end

    local base = self:getBaseFrame()
    if not base or not base.addFrame then return nil end

    frame = base:addFrame({
        width = self.get("width"),
        height = 1,
        x = 1,
        y = 1,
        visible = false,
        background = self.get("autoCompleteBackground"),
        foreground = self.get("autoCompleteForeground"),
        ignoreOffset = true,
        z = self.get("z") + self.get("autoCompleteZOffset"),
    })
    frame:setIgnoreOffset(true)
    frame:setVisible(false)

    local padding = getBorderPadding(self)
    local list = frame:addList({
        x = padding + 1,
        y = padding + 1,
        width = math.max(1, frame.get("width") - padding * 2),
        height = math.max(1, frame.get("height") - padding * 2),
        selectable = true,
        multiSelection = false,
        background = self.get("autoCompleteBackground"),
        foreground = self.get("autoCompleteForeground"),
    })
    list:setSelectedBackground(self.get("autoCompleteSelectedBackground"))
    list:setSelectedForeground(self.get("autoCompleteSelectedForeground"))
    list:setOffset(0)
    list:onSelect(function(_, index, selectedItem)
        if not autoCompleteVisible(self) then return end
        setAutoCompleteSelection(self, index)
        if self.get("autoCompleteAcceptOnClick") then
            applyAutoCompleteSelection(self, selectedItem)
        end
    end)

    self._autoCompleteFrame = frame
    self._autoCompleteList = list
    updateAutoCompleteStyles(self)
    return list
end

layoutAutoCompleteList = function(self, contentWidth, visibleCount)
    local frame = self._autoCompleteFrame
    local list = self._autoCompleteList
    if not frame or frame._destroyed or not list or list._destroyed then return end

    local border = getBorderPadding(self)
    local width = tonumber(contentWidth) or rawget(self, "_autoCompletePopupWidth") or list.get("width") or frame.get("width")
    local height = tonumber(visibleCount) or (list.get and list.get("height")) or (#(rawget(self, "_autoCompleteSuggestions") or {}))

    width = math.max(1, width or 1)
    height = math.max(1, height or 1)

    local frameWidth = frame.get and frame.get("width") or width
    local frameHeight = frame.get and frame.get("height") or height
    local maxWidth = math.max(1, frameWidth - border * 2)
    local maxHeight = math.max(1, frameHeight - border * 2)
    if width > maxWidth then width = maxWidth end
    if height > maxHeight then height = maxHeight end

    list:setPosition(border + 1, border + 1)
    list:setWidth(math.max(1, width))
    list:setHeight(math.max(1, height))
end

updateAutoCompleteBorder = function(self)
    local frame = self._autoCompleteFrame
    if not frame or frame._destroyed then return end

    local canvas = frame.get and frame.get("canvas")
    if not canvas then return end

    canvas:setType("post")
    if frame._autoCompleteBorderCommand then
        canvas:removeCommand(frame._autoCompleteBorderCommand)
        frame._autoCompleteBorderCommand = nil
    end

    if not self.get("autoCompleteShowBorder") then
        frame:updateRender()
        return
    end

    local borderColor = self.get("autoCompleteBorderColor") or colors.black

    local commandIndex = canvas:addCommand(function(element)
        local width = element.get("width") or 0
        local height = element.get("height") or 0
        if width < 1 or height < 1 then return end

        local bgColor = element.get("background") or colors.black
        local bgHex = tHex[bgColor] or tHex[colors.black]
        local borderHex = tHex[borderColor] or tHex[colors.black]

        element:textFg(1, 1, ("\131"):rep(width), borderColor)
        element:multiBlit(1, height, width, 1, "\143", bgHex, borderHex)
        element:multiBlit(1, 1, 1, height, "\149", borderHex, bgHex)
        element:multiBlit(width, 1, 1, height, "\149", bgHex, borderHex)
        element:blit(1, 1, "\151", borderHex, bgHex)
        element:blit(width, 1, "\148", bgHex, borderHex)
        element:blit(1, height, "\138", bgHex, borderHex)
        element:blit(width, height, "\133", bgHex, borderHex)
    end)

    frame._autoCompleteBorderCommand = commandIndex
    frame:updateRender()
end

local function getTokenInfo(self)
    local lines = self.get("lines")
    local cursorY = self.get("cursorY")
    local cursorX = self.get("cursorX")
    local line = lines[cursorY] or ""
    local uptoCursor = line:sub(1, math.max(cursorX - 1, 0))
    local pattern = self.get("autoCompleteTokenPattern") or "[%w_]+"

    local token = ""
    if pattern ~= "" then
        token = uptoCursor:match("(" .. pattern .. ")$") or ""
    end
    local startIndex = cursorX - #token
    if startIndex < 1 then startIndex = 1 end
    return token, startIndex
end

local function normalizeSuggestion(entry)
    if type(entry) == "string" then
        return {text = entry, insert = entry, source = entry}
    elseif type(entry) == "table" then
        local text = entry.text or entry.label or entry.value or entry.insert or entry[1]
        if not text then return nil end
        local item = {
            text = text,
            insert = entry.insert or entry.value or text,
            source = entry,
        }
        if entry.foreground then item.foreground = entry.foreground end
        if entry.background then item.background = entry.background end
        if entry.selectedForeground then item.selectedForeground = entry.selectedForeground end
        if entry.selectedBackground then item.selectedBackground = entry.selectedBackground end
        if entry.icon then item.icon = entry.icon end
        if entry.info then item.info = entry.info end
        return item
    end
end

local function iterateSuggestions(source, handler)
    if type(source) ~= "table" then return end
    local length = #source
    if length > 0 then
        for index = 1, length do
            handler(source[index])
        end
    else
        for _, value in pairs(source) do
            handler(value)
        end
    end
end

local function gatherSuggestions(self, token)
    local provider = self.get("autoCompleteProvider")
    local source = {}
    if provider then
        local ok, result = pcall(provider, self, token)
        if ok and type(result) == "table" then
            source = result
        end
    else
        source = self.get("autoCompleteItems") or {}
    end

    local suggestions = {}
    local caseInsensitive = self.get("autoCompleteCaseInsensitive")
    local target = caseInsensitive and token:lower() or token
    iterateSuggestions(source, function(entry)
        local normalized = normalizeSuggestion(entry)
        if normalized and normalized.text then
            local compare = caseInsensitive and normalized.text:lower() or normalized.text
            if target == "" or compare:find(target, 1, true) == 1 then
                table.insert(suggestions, normalized)
            end
        end
    end)

    local maxItems = self.get("autoCompleteMaxItems")
    if #suggestions > maxItems then
        while #suggestions > maxItems do
            table.remove(suggestions)
        end
    end
    return suggestions
end

local function measureSuggestionWidth(self, suggestions)
    local maxLen = 0
    for _, entry in ipairs(suggestions) do
        local text = entry
        if type(entry) == "table" then
            text = entry.text or entry.label or entry.value or entry.insert or entry[1]
        end
        if text ~= nil then
            local len = #tostring(text)
            if len > maxLen then
                maxLen = len
            end
        end
    end

    local limit = self.get("autoCompleteMaxWidth")
    local maxWidth = self.get("width")
    if limit and limit > 0 then
        maxWidth = math.min(maxWidth, limit)
    end

    local border = getBorderPadding(self)
    local base = self:getBaseFrame()
    if base and base.get then
        local baseWidth = base.get("width")
        if baseWidth and baseWidth > 0 then
            local available = baseWidth - border * 2
            if available < 1 then available = 1 end
            maxWidth = math.min(maxWidth, available)
        end
    end

    maxLen = math.min(maxLen, maxWidth)

    return math.max(1, maxLen)
end

local function placeAutoCompleteFrame(self, visibleCount, width)
    local frame = self._autoCompleteFrame
    local list = self._autoCompleteList
    if not frame or frame._destroyed then return end
    local border = getBorderPadding(self)
    local contentWidth = math.max(1, width or self.get("width"))
    local contentHeight = math.max(1, visibleCount or 1)

    local base = self:getBaseFrame()
    if not base then return end
    local baseWidth = base.get and base.get("width")
    local baseHeight = base.get and base.get("height")

    if baseWidth and baseWidth > 0 then
        local maxContentWidth = baseWidth - border * 2
        if maxContentWidth < 1 then maxContentWidth = 1 end
        if contentWidth > maxContentWidth then
            contentWidth = maxContentWidth
        end
    end

    if baseHeight and baseHeight > 0 then
        local maxContentHeight = baseHeight - border * 2
        if maxContentHeight < 1 then maxContentHeight = 1 end
        if contentHeight > maxContentHeight then
            contentHeight = maxContentHeight
        end
    end

    local frameWidth = contentWidth + border * 2
    local frameHeight = contentHeight + border * 2
    local originX, originY = self:calculatePosition()
    local scrollX = self.get("scrollX") or 0
    local scrollY = self.get("scrollY") or 0
    local tokenStart = (self._autoCompleteTokenStart or self.get("cursorX"))
    local column = tokenStart - scrollX
    column = math.max(1, math.min(self.get("width"), column))

    local cursorRow = self.get("cursorY") - scrollY
    cursorRow = math.max(1, math.min(self.get("height"), cursorRow))

    local offsetX = self.get("autoCompleteOffsetX")
    local offsetY = self.get("autoCompleteOffsetY")

    local baseX = originX + column - 1 + offsetX
    local x = baseX - border
    if border > 0 then
        x = x + 1
    end
    local listTopBelow = originY + cursorRow + offsetY
    local listBottomAbove = originY + cursorRow - offsetY - 1
    local belowY = listTopBelow - border
    local aboveY = listBottomAbove - contentHeight + 1 - border
    local y = belowY

    if baseWidth and baseWidth > 0 then
        if frameWidth > baseWidth then
            frameWidth = baseWidth
            contentWidth = math.max(1, frameWidth - border * 2)
        end
        if x + frameWidth - 1 > baseWidth then
            x = math.max(1, baseWidth - frameWidth + 1)
        end
        if x < 1 then
            x = 1
        end
    else
        if x < 1 then x = 1 end
    end

    if baseHeight and baseHeight > 0 then
        if y + frameHeight - 1 > baseHeight then
            -- Place above
            y = aboveY
            if border > 0 then
                -- Shift further up so lower border does not overlap the text line
                y = y - border
            end
            if y < 1 then
                y = math.max(1, baseHeight - frameHeight + 1)
            end
        end
        if y < 1 then
            y = 1
        end
    else
        if y < 1 then y = 1 end
        if y == aboveY and border > 0 then
            y = math.max(1, y - border)
        end
    end

    frame:setPosition(x, y)
    frame:setWidth(frameWidth)
    frame:setHeight(frameHeight)
    frame:setZ(self.get("z") + self.get("autoCompleteZOffset"))

    layoutAutoCompleteList(self, contentWidth, contentHeight)

    if list and not list._destroyed then
        list:updateRender()
    end
    frame:updateRender()
end

local function refreshAutoComplete(self)
    if not self.get("autoCompleteEnabled") then
        hideAutoComplete(self, true)
        return
    end
    if not self.get("focused") then
        hideAutoComplete(self, true)
        return
    end

    local token, startIndex = getTokenInfo(self)
    self._autoCompleteToken = token
    self._autoCompleteTokenStart = startIndex

    if #token < self.get("autoCompleteMinChars") then
        hideAutoComplete(self)
        return
    end

    local suggestions = gatherSuggestions(self, token)
    if #suggestions == 0 then
        hideAutoComplete(self)
        return
    end

    local list = ensureAutoCompleteUI(self)
    if not list then return end

    list:setOffset(0)
    list:setItems(suggestions)
    self._autoCompleteSuggestions = suggestions
    setAutoCompleteSelection(self, 1, true)

    local popupWidth = measureSuggestionWidth(self, suggestions)
    self._autoCompletePopupWidth = popupWidth
    placeAutoCompleteFrame(self, #suggestions, popupWidth)
    updateAutoCompleteStyles(self)
    self._autoCompleteFrame:setVisible(true)
    self._autoCompleteList:updateRender()
    self._autoCompleteFrame:updateRender()
    self:fireEvent("auto_complete_open", token, suggestions)
end

local function handleAutoCompleteKey(self, key)
    if not autoCompleteVisible(self) then return false end

    if key == keys.tab or (key == keys.enter and self.get("autoCompleteAcceptOnEnter")) then
        applyAutoCompleteSelection(self)
        return true
    elseif key == keys.up then
        setAutoCompleteSelection(self, (self._autoCompleteIndex or 1) - 1)
        return true
    elseif key == keys.down then
        setAutoCompleteSelection(self, (self._autoCompleteIndex or 1) + 1)
        return true
    elseif key == keys.pageUp then
        local height = (self._autoCompleteList and self._autoCompleteList.get("height")) or 1
        setAutoCompleteSelection(self, (self._autoCompleteIndex or 1) - height)
        return true
    elseif key == keys.pageDown then
        local height = (self._autoCompleteList and self._autoCompleteList.get("height")) or 1
        setAutoCompleteSelection(self, (self._autoCompleteIndex or 1) + height)
        return true
    elseif key == keys.escape and self.get("autoCompleteCloseOnEscape") then
        hideAutoComplete(self)
        return true
    end
    return false
end

local function handleAutoCompleteScroll(self, direction)
    if not autoCompleteVisible(self) then return false end
    local list = self._autoCompleteList
    if not list or list._destroyed then return false end
    local items = list.get("items")
    local height = list.get("height") or 1
    local offset = list.get("offset") or 0
    local count = #items
    if count == 0 then return false end

    local maxOffset = math.max(0, count - height)
    local newOffset = math.max(0, math.min(maxOffset, offset + direction))
    if newOffset ~= offset then
        list:setOffset(newOffset)
    end

    local target = (self._autoCompleteIndex or 1) + direction
    if target >= 1 and target <= count then
        setAutoCompleteSelection(self, target)
    else
        list:updateRender()
    end
    return true
end

--- Creates a new TextBox instance
--- @shortDescription Creates a new TextBox instance
--- @return TextBox self The newly created TextBox instance
--- @private
function TextBox.new()
    local self = setmetatable({}, TextBox):__init()
    self.class = TextBox
    self.set("width", 20)
    self.set("height", 10)
    return self
end

--- @shortDescription Initializes the TextBox instance
--- @param props table The properties to initialize the element with
--- @param basalt table The basalt instance
--- @return TextBox self The initialized instance
--- @protected
function TextBox:init(props, basalt)
    VisualElement.init(self, props, basalt)
    self.set("type", "TextBox")

    local function refreshIfEnabled()
        if self.get("autoCompleteEnabled") and self.get("focused") then
            refreshAutoComplete(self)
        end
    end

    local function restyle()
        updateAutoCompleteStyles(self)
    end

    local function reposition()
        if autoCompleteVisible(self) then
            local suggestions = rawget(self, "_autoCompleteSuggestions") or {}
            placeAutoCompleteFrame(self, math.max(#suggestions, 1), rawget(self, "_autoCompletePopupWidth") or self.get("width"))
        end
    end

    self:observe("autoCompleteEnabled", function(_, value)
        if not value then
            hideAutoComplete(self, true)
        elseif self.get("focused") then
            refreshAutoComplete(self)
        end
    end)

    self:observe("focused", function(_, focused)
        if focused then
            refreshIfEnabled()
        else
            hideAutoComplete(self, true)
        end
    end)

    self:observe("foreground", restyle)
    self:observe("background", restyle)
    self:observe("autoCompleteBackground", restyle)
    self:observe("autoCompleteForeground", restyle)
    self:observe("autoCompleteSelectedBackground", restyle)
    self:observe("autoCompleteSelectedForeground", restyle)
    self:observe("autoCompleteBorderColor", restyle)

    self:observe("autoCompleteZOffset", function()
        if self._autoCompleteFrame and not self._autoCompleteFrame._destroyed then
            self._autoCompleteFrame:setZ(self.get("z") + self.get("autoCompleteZOffset"))
        end
    end)
    self:observe("z", function()
        if self._autoCompleteFrame and not self._autoCompleteFrame._destroyed then
            self._autoCompleteFrame:setZ(self.get("z") + self.get("autoCompleteZOffset"))
        end
    end)

    self:observe("autoCompleteShowBorder", function()
        restyle()
        reposition()
    end)

    for _, prop in ipairs({
        "autoCompleteItems",
        "autoCompleteProvider",
        "autoCompleteMinChars",
        "autoCompleteMaxItems",
        "autoCompleteCaseInsensitive",
        "autoCompleteTokenPattern",
        "autoCompleteOffsetX",
        "autoCompleteOffsetY",
    }) do
        self:observe(prop, refreshIfEnabled)
    end

    self:observe("x", reposition)
    self:observe("y", reposition)
    self:observe("width", function()
        reposition()
        refreshIfEnabled()
    end)
    self:observe("height", reposition)
    self:observe("cursorX", reposition)
    self:observe("cursorY", reposition)
    self:observe("scrollX", reposition)
    self:observe("scrollY", reposition)
    self:observe("autoCompleteOffsetX", reposition)
    self:observe("autoCompleteOffsetY", reposition)
    self:observe("autoCompleteMaxWidth", function()
        if autoCompleteVisible(self) then
            local suggestions = rawget(self, "_autoCompleteSuggestions") or {}
            if #suggestions > 0 then
                local popupWidth = measureSuggestionWidth(self, suggestions)
                self._autoCompletePopupWidth = popupWidth
                placeAutoCompleteFrame(self, math.max(#suggestions, 1), popupWidth)
            end
        end
    end)
    return self
end

--- Adds a new syntax highlighting pattern
--- @shortDescription Adds a new syntax highlighting pattern
--- @param pattern string The regex pattern to match
--- @param color number The color to apply
--- @return TextBox self The TextBox instance
function TextBox:addSyntaxPattern(pattern, color)
    table.insert(self.get("syntaxPatterns"), {pattern = pattern, color = color})
    return self
end

--- Removes a syntax pattern by index (1-based)
--- @param index number The index of the pattern to remove
--- @return TextBox self
function TextBox:removeSyntaxPattern(index)
    local patterns = self.get("syntaxPatterns") or {}
    if type(index) ~= "number" then return self end
    if index >= 1 and index <= #patterns then
        table.remove(patterns, index)
        self.set("syntaxPatterns", patterns)
        self:updateRender()
    end
    return self
end

--- Clears all syntax highlighting patterns
--- @return TextBox self
function TextBox:clearSyntaxPatterns()
    self.set("syntaxPatterns", {})
    self:updateRender()
    return self
end

local function insertChar(self, char)
    local lines = self.get("lines")
    local cursorX = self.get("cursorX")
    local cursorY = self.get("cursorY")
    local currentLine = lines[cursorY]
    lines[cursorY] = currentLine:sub(1, cursorX-1) .. char .. currentLine:sub(cursorX)
    self.set("cursorX", cursorX + 1)
    self:updateViewport()
    self:updateRender()
end

local function insertText(self, text)
    for i = 1, #text do
        insertChar(self, text:sub(i,i))
    end
end

local function newLine(self)
    local lines = self.get("lines")
    local cursorX = self.get("cursorX")
    local cursorY = self.get("cursorY")
    local currentLine = lines[cursorY]

    local restOfLine = currentLine:sub(cursorX)
    lines[cursorY] = currentLine:sub(1, cursorX-1)
    table.insert(lines, cursorY + 1, restOfLine)

    self.set("cursorX", 1)
    self.set("cursorY", cursorY + 1)
    self:updateViewport()
    self:updateRender()
end

local function backspace(self)
    local lines = self.get("lines")
    local cursorX = self.get("cursorX")
    local cursorY = self.get("cursorY")
    local currentLine = lines[cursorY]

    if cursorX > 1 then
        lines[cursorY] = currentLine:sub(1, cursorX-2) .. currentLine:sub(cursorX)
        self.set("cursorX", cursorX - 1)
    elseif cursorY > 1 then
        local previousLine = lines[cursorY-1]
        self.set("cursorX", #previousLine + 1)
        self.set("cursorY", cursorY - 1)
        lines[cursorY-1] = previousLine .. currentLine
        table.remove(lines, cursorY)
    end
    self:updateViewport()
    self:updateRender()
end

--- Updates the viewport to keep the cursor in view
--- @shortDescription Updates the viewport to keep the cursor in view
--- @return TextBox self The TextBox instance
function TextBox:updateViewport()
    local cursorX = self.get("cursorX")
    local cursorY = self.get("cursorY")
    local scrollX = self.get("scrollX")
    local scrollY = self.get("scrollY")
    local width = self.get("width")
    local height = self.get("height")

    -- Horizontal scrolling
    if cursorX - scrollX > width then
        self.set("scrollX", cursorX - width)
    elseif cursorX - scrollX < 1 then
        self.set("scrollX", cursorX - 1)
    end

    -- Vertical scrolling
    if cursorY - scrollY > height then
        self.set("scrollY", cursorY - height)
    elseif cursorY - scrollY < 1 then
        self.set("scrollY", cursorY - 1)
    end
    return self
end

--- @shortDescription Handles character input
--- @param char string The character that was typed
--- @return boolean handled Whether the event was handled
--- @protected
function TextBox:char(char)
    if not self.get("editable") or not self.get("focused") then return false end
    -- Auto-pair logic only triggers for single characters
    local autoPair = self.get("autoPairEnabled")
    if autoPair and #char == 1 then
        local map = self.get("autoPairCharacters") or {}
        local lines = self.get("lines")
        local cursorX = self.get("cursorX")
        local cursorY = self.get("cursorY")
        local line = lines[cursorY] or ""
        local afterChar = line:sub(cursorX, cursorX)

        -- If typed char is an opening pair and we should skip duplicating closing when already there
        local closing = map[char]
        if closing then
            -- If skip closing and same closing already directly after, just insert opening?
            insertChar(self, char)
            if self.get("autoPairSkipClosing") then
                if afterChar ~= closing then
                    insertChar(self, closing)
                    -- Move cursor back inside pair
                    self.set("cursorX", self.get("cursorX") - 1)
                end
            else
                insertChar(self, closing)
                self.set("cursorX", self.get("cursorX") - 1)
            end
            refreshAutoComplete(self)
            return true
        end

        -- If typed char is a closing we might want to overtype
        if self.get("autoPairOverType") then
            for open, close in pairs(map) do
                if char == close and afterChar == close then
                    -- move over instead of inserting
                    self.set("cursorX", cursorX + 1)
                    refreshAutoComplete(self)
                    return true
                end
            end
        end
    end

    insertChar(self, char)
    refreshAutoComplete(self)
    return true
end

--- @shortDescription Handles key events
--- @param key number The key that was pressed
--- @return boolean handled Whether the event was handled
--- @protected
function TextBox:key(key)
    if not self.get("editable") or not self.get("focused") then return false end
    if handleAutoCompleteKey(self, key) then
        return true
    end
    local lines = self.get("lines")
    local cursorX = self.get("cursorX")
    local cursorY = self.get("cursorY")

    if key == keys.enter then
        -- Smart newline between matching braces/brackets if enabled
        if self.get("autoPairEnabled") and self.get("autoPairNewlineIndent") then
            local lines = self.get("lines")
            local cursorX = self.get("cursorX")
            local cursorY = self.get("cursorY")
            local line = lines[cursorY] or ""
            local before = line:sub(1, cursorX - 1)
            local after = line:sub(cursorX)
            local pairMap = self.get("autoPairCharacters") or {}
            local inverse = {}
            for o,c in pairs(pairMap) do inverse[c]=o end
            local prevChar = before:sub(-1)
            local nextChar = after:sub(1,1)
            if prevChar ~= "" and nextChar ~= "" and pairMap[prevChar] == nextChar then
                -- Split line into two with an empty line between, caret positioned on inner line
                lines[cursorY] = before
                table.insert(lines, cursorY + 1, "")
                table.insert(lines, cursorY + 2, after)
                self.set("cursorY", cursorY + 1)
                self.set("cursorX", 1)
                self:updateViewport()
                self:updateRender()
                refreshAutoComplete(self)
                return true
            end
        end
        newLine(self)
    elseif key == keys.backspace then
        backspace(self)
    elseif key == keys.left then
        if cursorX > 1 then
            self.set("cursorX", cursorX - 1)
        elseif cursorY > 1 then
            self.set("cursorY", cursorY - 1)
            self.set("cursorX", #lines[cursorY-1] + 1)
        end
    elseif key == keys.right then
        if cursorX <= #lines[cursorY] then
            self.set("cursorX", cursorX + 1)
        elseif cursorY < #lines then
            self.set("cursorY", cursorY + 1)
            self.set("cursorX", 1)
        end
    elseif key == keys.up and cursorY > 1 then
        self.set("cursorY", cursorY - 1)
        self.set("cursorX", math.min(cursorX, #lines[cursorY-1] + 1))
    elseif key == keys.down and cursorY < #lines then
        self.set("cursorY", cursorY + 1)
        self.set("cursorX", math.min(cursorX, #lines[cursorY+1] + 1))
    end
    self:updateRender()
    self:updateViewport()
    refreshAutoComplete(self)
    return true
end

--- @shortDescription Handles mouse scroll events
--- @param direction number The scroll direction
--- @param x number The x position of the scroll
--- @param y number The y position of the scroll
--- @return boolean handled Whether the event was handled
--- @protected
function TextBox:mouse_scroll(direction, x, y)
    if handleAutoCompleteScroll(self, direction) then
        return true
    end
    if self:isInBounds(x, y) then
        local scrollY = self.get("scrollY")
        local height = self.get("height")
        local lines = self.get("lines")

        local maxScroll = math.max(0, #lines - height + 2)

        local newScroll = math.max(0, math.min(maxScroll, scrollY + direction))

        self.set("scrollY", newScroll)
        self:updateRender()
        return true
    end
    return false
end

--- @shortDescription Handles mouse click events
--- @param button number The button that was clicked
--- @param x number The x position of the click
--- @param y number The y position of the click
--- @return boolean handled Whether the event was handled
--- @protected
function TextBox:mouse_click(button, x, y)
    if VisualElement.mouse_click(self, button, x, y) then
        local relX, relY = self:getRelativePosition(x, y)
        local scrollX = self.get("scrollX")
        local scrollY = self.get("scrollY")

        local targetY = (relY or 0) + (scrollY or 0)
        local lines = self.get("lines") or {}

        -- clamp and validate before indexing to avoid nil errors
        if targetY < 1 then targetY = 1 end
        if targetY <= #lines and lines[targetY] ~= nil then
            self.set("cursorY", targetY)
            local lineLen = #tostring(lines[targetY])
            self.set("cursorX", math.min((relX or 1) + (scrollX or 0), lineLen + 1))
        end
        self:updateRender()
        refreshAutoComplete(self)
        return true
    end
    if autoCompleteVisible(self) then
        local frame = self._autoCompleteFrame
        if not (frame and frame:isInBounds(x, y)) and not self:isInBounds(x, y) then
            hideAutoComplete(self)
        end
    end
    return false
end

--- @shortDescription Handles paste events
--- @protected
function TextBox:paste(text)
    if not self.get("editable") or not self.get("focused") then return false end

    for char in text:gmatch(".") do
        if char == "\n" then
            newLine(self)
        else
            insertChar(self, char)
        end
    end

    refreshAutoComplete(self)
    return true
end

--- Sets the text of the TextBox
--- @shortDescription Sets the text of the TextBox
--- @param text string The text to set
--- @return TextBox self The TextBox instance
function TextBox:setText(text)
    local lines = {}
    if text == "" then
        lines = {""}
    else
        for line in (text.."\n"):gmatch("([^\n]*)\n") do
            table.insert(lines, line)
        end
    end
    self.set("lines", lines)
    hideAutoComplete(self, true)
    return self
end

--- Gets the text of the TextBox
--- @shortDescription Gets the text of the TextBox
--- @return string text The text of the TextBox
function TextBox:getText()
    return table.concat(self.get("lines"), "\n")
end

local function applySyntaxHighlighting(self, line)
    local text = line
    local colors = string.rep(tHex[self.get("foreground")], #text)
    local patterns = self.get("syntaxPatterns")

    for _, syntax in ipairs(patterns) do
        local start = 1
        while true do
            local s, e = text:find(syntax.pattern, start)
            if not s then break end
            local matchLen = e - s + 1
            if matchLen <= 0 then
                -- avoid infinite loops for zero-length matches: color one char and advance
                colors = colors:sub(1, s-1) .. string.rep(tHex[syntax.color], 1) .. colors:sub(s+1)
                start = s + 1
            else
                colors = colors:sub(1, s-1) .. string.rep(tHex[syntax.color], matchLen) .. colors:sub(e+1)
                start = e + 1
            end
        end
    end

    return text, colors
end

--- @shortDescription Renders the TextBox with syntax highlighting
--- @protected
function TextBox:render()
    VisualElement.render(self)

    local lines = self.get("lines")
    local scrollX = self.get("scrollX")
    local scrollY = self.get("scrollY")
    local width = self.get("width")
    local height = self.get("height")
    local fg = tHex[self.get("foreground")]
    local bg = tHex[self.get("background")]

    for y = 1, height do
        local lineNum = y + scrollY
        local line = lines[lineNum] or ""

        local fullText, fullColors = applySyntaxHighlighting(self, line)
        local text = fullText:sub(scrollX + 1, scrollX + width)
        local colors = fullColors:sub(scrollX + 1, scrollX + width)

        local padLen = width - #text
        if padLen > 0 then
            text = text .. string.rep(" ", padLen)
            colors = colors .. string.rep(tHex[self.get("foreground")], padLen)
        end

        self:blit(1, y, text, colors, string.rep(bg, #text))
    end

    if self.get("focused") then
        local relativeX = self.get("cursorX") - scrollX
        local relativeY = self.get("cursorY") - scrollY
        if relativeX >= 1 and relativeX <= width and relativeY >= 1 and relativeY <= height then
            self:setCursor(relativeX, relativeY, true, self.get("cursorColor") or self.get("foreground"))
        end
    end
end

function TextBox:destroy()
    if self._autoCompleteFrame and not self._autoCompleteFrame._destroyed then
        self._autoCompleteFrame:destroy()
    end
    self._autoCompleteFrame = nil
    self._autoCompleteList = nil
    self._autoCompletePopupWidth = nil
    VisualElement.destroy(self)
end

return TextBox
 end
project["elements/Slider.lua"] = function(...) local VisualElement = require("elements/VisualElement")
local tHex = require("libraries/colorHex")

--- This is the slider class. It provides a draggable slider control that can be either horizontal or vertical,
--- with customizable colors and value ranges.
---@class Slider : VisualElement
local Slider = setmetatable({}, VisualElement)
Slider.__index = Slider

---@property step number 1 Current position of the slider handle (1 to width/height)
Slider.defineProperty(Slider, "step", {default = 1, type = "number", canTriggerRender = true})
---@property max number 100 Maximum value for value conversion (maps slider position to this range)
Slider.defineProperty(Slider, "max", {default = 100, type = "number"})
---@property horizontal boolean true Whether the slider is horizontal (false for vertical)
Slider.defineProperty(Slider, "horizontal", {default = true, type = "boolean", canTriggerRender = true, setter=function(self, value)
    if value then
        self.set("backgroundEnabled", false)
    else
        self.set("backgroundEnabled", true)
    end
end})
---@property barColor color gray Color of the slider track
Slider.defineProperty(Slider, "barColor", {default = colors.gray, type = "color", canTriggerRender = true})
---@property sliderColor color blue Color of the slider handle
Slider.defineProperty(Slider, "sliderColor", {default = colors.blue, type = "color", canTriggerRender = true})

---@event onChange {value number} Fired when the slider value changes
Slider.defineEvent(Slider, "mouse_click")
Slider.defineEvent(Slider, "mouse_drag")
Slider.defineEvent(Slider, "mouse_up")
Slider.defineEvent(Slider, "mouse_scroll")

--- Creates a new Slider instance
--- @shortDescription Creates a new Slider instance
--- @return Slider self The newly created Slider instance
--- @private
function Slider.new()
    local self = setmetatable({}, Slider):__init()
    self.class = Slider
    self.set("width", 8)
    self.set("height", 1)
    self.set("backgroundEnabled", false)
    return self
end

--- @shortDescription Initializes the Slider instance
--- @param props table The properties to initialize the element with
--- @param basalt table The basalt instance
--- @return Slider self The initialized instance
--- @protected
function Slider:init(props, basalt)
    VisualElement.init(self, props, basalt)
    self.set("type", "Slider")
end

--- Gets the current value of the slider
--- @shortDescription Gets the current value mapped to the max range
--- @return number value The current value (0 to max)
--- @usage local value = slider:getValue()
function Slider:getValue()
    local step = self.get("step")
    local max = self.get("max")
    local maxSteps = self.get("horizontal") and self.get("width") or self.get("height")
    return math.floor((step - 1) * (max / (maxSteps - 1)))
end

--- @shortDescription Updates slider position on mouse click
--- @param button number The mouse button that was clicked
--- @param x number The x position of the click
--- @param y number The y position of the click
--- @return boolean handled Whether the event was handled
--- @protected
function Slider:mouse_click(button, x, y)
    if self:isInBounds(x, y) then
        local relX, relY = self:getRelativePosition(x, y)
        local pos = self.get("horizontal") and relX or relY
        local maxSteps = self.get("horizontal") and self.get("width") or self.get("height")

        self.set("step", math.min(maxSteps, math.max(1, pos)))
        self:updateRender()
        return true
    end
    return false
end
Slider.mouse_drag = Slider.mouse_click

--- @shortDescription Handles mouse release events
--- @param button number The mouse button that was released
--- @param x number The x position of the release
--- @param y number The y position of the release
--- @return boolean handled Whether the event was handled
--- @protected
function Slider:mouse_scroll(direction, x, y)
    if self:isInBounds(x, y) then
        local step = self.get("step")
        local maxSteps = self.get("horizontal") and self.get("width") or self.get("height")
        self.set("step", math.min(maxSteps, math.max(1, step + direction)))
        self:updateRender()
        return true
    end
    return false
end

--- @shortDescription Renders the slider with track and handle
--- @protected
function Slider:render()
    VisualElement.render(self)
    local width = self.get("width")
    local height = self.get("height")
    local horizontal = self.get("horizontal")
    local step = self.get("step")

    local barChar = horizontal and "\140" or " "
    local text = string.rep(barChar, horizontal and width or height)

    if horizontal then
        self:textFg(1, 1, text, self.get("barColor"))
        self:textBg(step, 1, " ", self.get("sliderColor"))
    else
        local bg = self.get("background")
        for y = 1, height do
            self:textBg(1, y, " ", bg)
        end
        self:textBg(1, step, " ", self.get("sliderColor"))
    end
end

return Slider end
project["elements/List.lua"] = function(...) local VisualElement = require("elements/VisualElement")
---@configDescription A scrollable list of selectable items

--- This is the list class. It provides a scrollable list of selectable items with support for 
--- custom item rendering, separators, and selection handling.
---@class List : VisualElement
local List = setmetatable({}, VisualElement)
List.__index = List

---@property items table {} List of items to display. Items can be tables with properties including selected state
List.defineProperty(List, "items", {default = {}, type = "table", canTriggerRender = true})
---@property selectable boolean true Whether items in the list can be selected
List.defineProperty(List, "selectable", {default = true, type = "boolean"})
---@property multiSelection boolean false Whether multiple items can be selected at once
List.defineProperty(List, "multiSelection", {default = false, type = "boolean"})
---@property offset number 0 Current scroll offset for viewing long lists
List.defineProperty(List, "offset", {default = 0, type = "number", canTriggerRender = true})
---@property selectedBackground color blue Background color for selected items
List.defineProperty(List, "selectedBackground", {default = colors.blue, type = "color"})
---@property selectedForeground color white Text color for selected items
List.defineProperty(List, "selectedForeground", {default = colors.white, type = "color"})

---@event onSelect {index number, item table} Fired when an item is selected
List.defineEvent(List, "mouse_click")
List.defineEvent(List, "mouse_scroll")

--- Creates a new List instance
--- @shortDescription Creates a new List instance
--- @return List self The newly created List instance
--- @private
function List.new()
    local self = setmetatable({}, List):__init()
    self.class = List
    self.set("width", 16)
    self.set("height", 8)
    self.set("z", 5)
    self.set("background", colors.gray)
    return self
end

--- @shortDescription Initializes the List instance
--- @param props table The properties to initialize the element with
--- @param basalt table The basalt instance
--- @return List self The initialized instance
--- @protected
function List:init(props, basalt)
    VisualElement.init(self, props, basalt)
    self.set("type", "List")
    return self
end

--- Adds an item to the list
--- @shortDescription Adds an item to the list
--- @param text string|table The item to add (string or item table)
--- @return List self The List instance
--- @usage list:addItem("New Item")
--- @usage list:addItem({text="Item", callback=function() end})
function List:addItem(text)
    local items = self.get("items")
    table.insert(items, text)
    self:updateRender()
    return self
end

--- Removes an item from the list
--- @shortDescription Removes an item from the list
--- @param index number The index of the item to remove
--- @return List self The List instance
--- @usage list:removeItem(1)
function List:removeItem(index)
    local items = self.get("items")
    table.remove(items, index)
    self:updateRender()
    return self
end

--- Clears all items from the list
--- @shortDescription Clears all items from the list
--- @return List self The List instance
--- @usage list:clear()
function List:clear()
    self.set("items", {})
    self:updateRender()
    return self
end

-- Gets the currently selected items
--- @shortDescription Gets the currently selected items
--- @return table selected List of selected items
--- @usage local selected = list:getSelectedItems()
function List:getSelectedItems()
    local selected = {}
    for i, item in ipairs(self.get("items")) do
        if type(item) == "table" and item.selected then
            local selectedItem = item
            selectedItem.index = i
            table.insert(selected, selectedItem)
        end
    end
    return selected
end

--- Gets first selected item
--- @shortDescription Gets first selected item
--- @return table? selected The first item
function List:getSelectedItem()
    local items = self.get("items")
    for i, item in ipairs(items) do
        if type(item) == "table" and item.selected then
            return item
        end
    end
    return nil
end

--- @shortDescription Handles mouse click events
--- @param button number The mouse button that was clicked
--- @param x number The x-coordinate of the click
--- @param y number The y-coordinate of the click
--- @return boolean Whether the event was handled
--- @protected
function List:mouse_click(button, x, y)
    if self:isInBounds(x, y) and self.get("selectable") then
        local _, index = self:getRelativePosition(x, y)
        local adjustedIndex = index + self.get("offset")
        local items = self.get("items")

        if adjustedIndex <= #items then
            local item = items[adjustedIndex]
            if type(item) == "string" then
                item = {text = item}
                items[adjustedIndex] = item
            end

            if not self.get("multiSelection") then
                for _, otherItem in ipairs(items) do
                    if type(otherItem) == "table" then
                        otherItem.selected = false
                    end
                end
            end

            item.selected = not item.selected

            if item.callback then
                item.callback(self)
            end
            self:fireEvent("mouse_click", button, x, y)
            self:fireEvent("select", adjustedIndex, item)
            self:updateRender()
        end
        return true
    end
    return false
end

--- @shortDescription Handles mouse scroll events
--- @param direction number The direction of the scroll (1 for down, -1 for up)
--- @param x number The x-coordinate of the scroll
--- @param y number The y-coordinate of the scroll
--- @return boolean Whether the event was handled
--- @protected
function List:mouse_scroll(direction, x, y)
    if self:isInBounds(x, y) then
        local offset = self.get("offset")
        local maxOffset = math.max(0, #self.get("items") - self.get("height"))

        offset = math.min(maxOffset, math.max(0, offset + direction))
        self.set("offset", offset)
        self:fireEvent("mouse_scroll", direction, x, y)
        return true
    end
    return false
end

--- Registers a callback for the select event
--- @shortDescription Registers a callback for the select event
--- @param callback function The callback function to register
--- @return List self The List instance
--- @usage list:onSelect(function(index, item) print("Selected item:", index, item) end)
function List:onSelect(callback)
    self:registerCallback("select", callback)
    return self
end

--- Scrolls the list to the bottom
--- @shortDescription Scrolls the list to the bottom
--- @return List self The List instance
function List:scrollToBottom()
    local maxOffset = math.max(0, #self.get("items") - self.get("height"))
    self.set("offset", maxOffset)
    return self
end

--- Scrolls the list to the top
--- @shortDescription Scrolls the list to the top
--- @return List self The List instance
function List:scrollToTop()
    self.set("offset", 0)
    return self
end

--- @shortDescription Renders the list
--- @protected
function List:render()
    VisualElement.render(self)

    local items = self.get("items")
    local height = self.get("height")
    local offset = self.get("offset")
    local width = self.get("width")

    for i = 1, height do
        local itemIndex = i + offset
        local item = items[itemIndex]

        if item then
            if type(item) == "string" then
                item = {text = item}
                items[itemIndex] = item
            end

            if item.separator then
                local separatorChar = (item.text or "-"):sub(1,1)
                local separatorText = string.rep(separatorChar, width)
                local fg = item.foreground or self.get("foreground")
                local bg = item.background or self.get("background")

                self:textBg(1, i, string.rep(" ", width), bg)
                self:textFg(1, i, separatorText:sub(1, width), fg)
            else
                local text = item.text
                local isSelected = item.selected

                local bg = isSelected and
                    (item.selectedBackground or self.get("selectedBackground")) or
                    (item.background or self.get("background"))

                local fg = isSelected and
                    (item.selectedForeground or self.get("selectedForeground")) or
                    (item.foreground or self.get("foreground"))

                self:textBg(1, i, string.rep(" ", width), bg)
                self:textFg(1, i, text:sub(1, width), fg)
            end
        end
    end
end

return List
 end
project["propertySystem.lua"] = function(...) local deepCopy = require("libraries/utils").deepCopy
local expect = require("libraries/expect")
local errorManager = require("errorManager")

--- PropertySystem is a class that allows Elements to have properties that can be observed and updated.
--- It also allows for properties to have custom getters and setters. This is the base system for all Elements.
--- @class PropertySystem
--- @field _properties table A table containing all property configurations
--- @field _values table A table containing all property values
--- @field _observers table A table containing all property observers
--- @field set function A function to set a property value
--- @field get function A function to get a property value
local PropertySystem = {}
PropertySystem.__index = PropertySystem

PropertySystem._properties = {}
local blueprintTemplates = {}

PropertySystem._setterHooks = {}

--- Adds a setter hook to the PropertySystem. Setter hooks are functions that are called before a property is set.
--- @shortDescription Adds a setter hook to the PropertySystem
--- @param hook function The hook function to add
function PropertySystem.addSetterHook(hook)
    table.insert(PropertySystem._setterHooks, hook)
end

local function applyHooks(element, propertyName, value, config)
    for _, hook in ipairs(PropertySystem._setterHooks) do
        local newValue = hook(element, propertyName, value, config)
        if newValue ~= nil then
            value = newValue
        end
    end
    return value
end

--- Defines a property for an element class
--- @shortDescription Defines a property for an element class
--- @param class table The element class to define the property for
--- @param name string The name of the property
--- @param config table The configuration of the property
function PropertySystem.defineProperty(class, name, config)
    if not rawget(class, '_properties') then
        class._properties = {}
    end

    class._properties[name] = {
        type = config.type,
        default = config.default,
        canTriggerRender = config.canTriggerRender,
        getter = config.getter,
        setter = config.setter,
        allowNil = config.allowNil,
    }

    local capitalizedName = name:sub(1,1):upper() .. name:sub(2)

    class["get" .. capitalizedName] = function(self, ...)
        expect(1, self, "element")
        local value = self._values[name]
        if type(value) == "function" and config.type ~= "function" then
            value = value(self)
        end
        return config.getter and config.getter(self, value, ...) or value
    end

    class["set" .. capitalizedName] = function(self, value, ...)
        expect(1, self, "element")
        value = applyHooks(self, name, value, config)

        if type(value) ~= "function" then
            if config.type == "table" then
                if value == nil then
                    if not config.allowNil then
                        expect(2, value, config.type)
                    end
                end
            else
                expect(2, value, config.type)
            end
        end

        if config.setter then
            value = config.setter(self, value, ...)
        end

        self:_updateProperty(name, value)
        return self
    end
end

--- Combines multiple properties into a single getter and setter
--- @shortDescription Combines multiple properties
--- @param class table The element class to combine the properties for
--- @param name string The name of the combined property
--- @vararg string The names of the properties to combine
function PropertySystem.combineProperties(class, name, ...)
    local properties = {...}
    for k,v in pairs(properties)do
        if not class._properties[v] then errorManager.error("Property not found: "..v) end
    end
    local capitalizedName = name:sub(1,1):upper() .. name:sub(2)

    class["get" .. capitalizedName] = function(self)
        expect(1, self, "element")
        local value = {}
        for _,v in pairs(properties)do
            table.insert(value, self.get(v))
        end
        return table.unpack(value)
    end

    class["set" .. capitalizedName] = function(self, ...)
        expect(1, self, "element")
        local values = {...}
        for i,v in pairs(properties)do
            self.set(v, values[i])
        end
        return self
    end
end

--- Creates a blueprint of an element class with all its properties
--- @shortDescription Creates a blueprint of an element class
--- @param elementClass table The element class to create a blueprint from
--- @return table blueprint A table containing all property definitions
function PropertySystem.blueprint(elementClass, properties, basalt, parent)
    if not blueprintTemplates[elementClass] then
        local template = {
            basalt = basalt,
            __isBlueprint = true,
            _values = properties or {},
            _events = {},
            render = function() end,
            dispatchEvent = function() end,
            init = function() end,
        }

        template.loaded = function(self, callback)
            self.loadedCallback = callback
            return template
        end

        template.create = function(self)
            local element = elementClass.new()
            element:init({}, self.basalt)
            for name, value in pairs(self._values) do
                element._values[name] = value
            end
            for name, callbacks in pairs(self._events) do
                for _, callback in ipairs(callbacks) do
                    element[name](element, callback)
                end
            end
            if(parent~=nil)then
                parent:addChild(element)
            end
            element:updateRender()
            self.loadedCallback(element)
            element:postInit()
            return element
        end

        local currentClass = elementClass
        while currentClass do
            if rawget(currentClass, '_properties') then
                for name, config in pairs(currentClass._properties) do
                    if type(config.default) == "table" then
                        template._values[name] = deepCopy(config.default)
                    else
                        template._values[name] = config.default
                    end
                end
            end
            currentClass = getmetatable(currentClass) and rawget(getmetatable(currentClass), '__index')
        end

        blueprintTemplates[elementClass] = template
    end

    local blueprint = {
        _values = {},
        _events = {},
        loadedCallback = function() end,
    }

    blueprint.get = function(name)
        local value = blueprint._values[name]
        local config = elementClass._properties[name]
        if type(value) == "function" and config.type ~= "function" then
            value = value(blueprint)
        end
        return value
    end
    blueprint.set = function(name, value)
        blueprint._values[name] = value
        return blueprint
    end

    setmetatable(blueprint, {
        __index = function(self, k)
            if k:match("^on%u") then
                return function(_, callback)
                    self._events[k] = self._events[k] or {}
                    table.insert(self._events[k], callback)
                    return self
                end
            end
            if k:match("^get%u") then
                local propName = k:sub(4,4):lower() .. k:sub(5)
                return function()
                    return self._values[propName]
                end
            end
            if k:match("^set%u") then
                local propName = k:sub(4,4):lower() .. k:sub(5)
                return function(_, value)
                    self._values[propName] = value
                    return self
                end
            end
            return blueprintTemplates[elementClass][k]
        end
    })

    return blueprint
end

--- Creates an element from a blueprint
--- @shortDescription Creates an element from a blueprint
--- @param elementClass table The element class to create from the blueprint
--- @param blueprint table The blueprint to create the element from
--- @return table element The created element
function PropertySystem.createFromBlueprint(elementClass, blueprint, basalt)
    local element = elementClass.new({}, basalt)
    for name, value in pairs(blueprint._values) do
        if type(value) == "table" then
            element._values[name] = deepCopy(value)
        else
            element._values[name] = value
        end
    end

    return element
end

--- Initializes the PropertySystem IS USED INTERNALLY
--- @shortDescription Initializes the PropertySystem
--- @return table self The PropertySystem
function PropertySystem:__init()
    self._values = {}
    self._observers = {}

    self.set = function(name, value, ...)
        local oldValue = self._values[name]
        local config = self._properties[name]
        if(config~=nil)then
            if(config.setter) then
                value = config.setter(self, value, ...)
            end
            if config.canTriggerRender then
                self:updateRender()
            end
            self._values[name] = applyHooks(self, name, value, config)
            if oldValue ~= value and self._observers[name] then
                for _, callback in ipairs(self._observers[name]) do
                    callback(self, value, oldValue)
                end
            end
        end
    end

    self.get = function(name, ...)
        local value = self._values[name]
        local config = self._properties[name]
        if(config==nil)then errorManager.error("Property not found: "..name) return end
        if type(value) == "function" and config.type ~= "function" then
            value = value(self)
        end
        return config.getter and config.getter(self, value, ...) or value
    end

    local properties = {}
    local currentClass = getmetatable(self).__index

    while currentClass do
        if rawget(currentClass, '_properties') then
            for name, config in pairs(currentClass._properties) do
                if not properties[name] then
                    properties[name] = config
                end
            end
        end
        currentClass = getmetatable(currentClass) and rawget(getmetatable(currentClass), '__index')
    end

    self._properties = properties

    local originalMT = getmetatable(self)
    local originalIndex = originalMT.__index
    setmetatable(self, {
        __index = function(t, k)
            local config = self._properties[k]
            if config then
                local value = self._values[k]
                if type(value) == "function" and config.type ~= "function" then
                    value = value(self)
                end
                return value
            end
            if type(originalIndex) == "function" then
                return originalIndex(t, k)
            else
                return originalIndex[k]
            end
        end,
        __newindex = function(t, k, v)
            local config = self._properties[k]
            if config then
                if config.setter then
                    v = config.setter(self, v)
                end
                v = applyHooks(self, k, v, config)
                self:_updateProperty(k, v)
            else
                rawset(t, k, v)
            end
        end,
        __tostring = function(self)
            return string.format("Object: %s (id: %s)", self._values.type, self.id)
        end
    })

    for name, config in pairs(properties) do
        if self._values[name] == nil then
            if type(config.default) == "table" then
                self._values[name] = deepCopy(config.default)
            else
                self._values[name] = config.default
            end
        end
    end

    return self
end

--- Update call for a property IS USED INTERNALLY
--- @shortDescription Update call for a property
--- @param name string The name of the property
--- @param value any The value of the property
--- @return table self The PropertySystem
function PropertySystem:_updateProperty(name, value)
    local oldValue = self._values[name]
    if type(oldValue) == "function" then
        oldValue = oldValue(self)
    end

    self._values[name] = value
    local newValue = type(value) == "function" and value(self) or value

    if oldValue ~= newValue then
        if self._properties[name].canTriggerRender then
            self:updateRender()
        end
        if self._observers[name] then
            for _, callback in ipairs(self._observers[name]) do
                callback(self, newValue, oldValue)
            end
        end
    end
    return self
end

--- Observers a property
--- @shortDescription Observers a property
--- @param name string The name of the property
--- @param callback function The callback function to call when the property changes
--- @return table self The PropertySystem
function PropertySystem:observe(name, callback)
    self._observers[name] = self._observers[name] or {}
    table.insert(self._observers[name], callback)
    return self
end

--- Removes an observer from a property
--- @shortDescription Removes an observer from a property
--- @param name string The name of the property
--- @param callback function The callback function to remove
--- @return table self The PropertySystem
function PropertySystem:removeObserver(name, callback)
    if self._observers[name] then
        for i, cb in ipairs(self._observers[name]) do
            if cb == callback then
                table.remove(self._observers[name], i)
                if #self._observers[name] == 0 then
                    self._observers[name] = nil
                end
                break
            end
        end
    end
    return self
end

--- Removes all observers from a property
--- @shortDescription Removes all observers from a property
--- @param name? string The name of the property
--- @return table self The PropertySystem
function PropertySystem:removeAllObservers(name)
    if name then
        self._observers[name] = nil
    else
        self._observers = {}
    end
    return self
end

--- Adds a property to the PropertySystem on instance level
--- @shortDescription Adds a property to the PropertySystem on instance level
--- @param name string The name of the property
--- @param config table The configuration of the property
--- @return table self The PropertySystem
function PropertySystem:instanceProperty(name, config)
    PropertySystem.defineProperty(self, name, config)
    self._values[name] = config.default
    return self
end

--- Removes a property from the PropertySystem on instance level
--- @shortDescription Removes a property from the PropertySystem
--- @param name string The name of the property
--- @return table self The PropertySystem
function PropertySystem:removeProperty(name)
    self._values[name] = nil
    self._properties[name] = nil
    self._observers[name] = nil

    local capitalizedName = name:sub(1,1):upper() .. name:sub(2)
    self["get" .. capitalizedName] = nil
    self["set" .. capitalizedName] = nil
    return self
end

--- Gets a property configuration
--- @shortDescription Gets a property configuration
--- @param name string The name of the property
--- @return table config The configuration of the property
function PropertySystem:getPropertyConfig(name)
    return self._properties[name]
end

return PropertySystem end
project["elements/Image.lua"] = function(...) local elementManager = require("elementManager")
local VisualElement = elementManager.getElement("VisualElement")
local tHex = require("libraries/colorHex")
---@configDescription An element that displays an image in bimg format
---@configDefault false

--- This is the Image element class which can be used to display bimg formatted images.
--- Bimg is a universal ComputerCraft image format.
--- See: https://github.com/SkyTheCodeMaster/bimg
---@class Image : VisualElement
local Image = setmetatable({}, VisualElement)
Image.__index = Image

---@property bimg table {} The bimg image data
Image.defineProperty(Image, "bimg", {default = {{}}, type = "table", canTriggerRender = true})
---@property currentFrame number 1 Current animation frame
Image.defineProperty(Image, "currentFrame", {default = 1, type = "number", canTriggerRender = true})
---@property autoResize boolean false Whether to automatically resize the image when content exceeds bounds
Image.defineProperty(Image, "autoResize", {default = false, type = "boolean"})
---@property offsetX number 0 Horizontal offset for viewing larger images
Image.defineProperty(Image, "offsetX", {default = 0, type = "number", canTriggerRender = true})
---@property offsetY number 0 Vertical offset for viewing larger images
Image.defineProperty(Image, "offsetY", {default = 0, type = "number", canTriggerRender = true})

---@combinedProperty offset {offsetX offsetY} Combined property for offsetX and offsetY
Image.combineProperties(Image, "offset", "offsetX", "offsetY")

--- Creates a new Image instance
--- @shortDescription Creates a new Image instance
--- @return Image self The newly created Image instance
--- @private
function Image.new()
    local self = setmetatable({}, Image):__init()
    self.class = Image
    self.set("width", 12)
    self.set("height", 6)
    self.set("background", colors.black)
    self.set("z", 5)
    return self
end

--- @shortDescription Initializes the Image instance
--- @param props table The properties to initialize the element with
--- @param basalt table The basalt instance
--- @return Image self The initialized instance
--- @protected
function Image:init(props, basalt)
    VisualElement.init(self, props, basalt)
    self.set("type", "Image")
    return self
end

--- Resizes the image to the specified width and height
--- @shortDescription Resizes the image to the specified width and height
--- @param width number The new width of the image
--- @param height number The new height of the image
--- @return Image self The Image instance
function Image:resizeImage(width, height)
    local frames = self.get("bimg")

    for frameIndex, frame in ipairs(frames) do
        local newFrame = {}
        for y = 1, height do
            local text = string.rep(" ", width)
            local fg = string.rep("f", width)
            local bg = string.rep("0", width)

            if frame[y] and frame[y][1] then
                local oldText = frame[y][1]
                local oldFg = frame[y][2]
                local oldBg = frame[y][3]

                text = (oldText .. string.rep(" ", width)):sub(1, width)
                fg = (oldFg .. string.rep("f", width)):sub(1, width)
                bg = (oldBg .. string.rep("0", width)):sub(1, width)
            end

            newFrame[y] = {text, fg, bg}
        end
        frames[frameIndex] = newFrame
    end

    self:updateRender()
    return self
end

--- Gets the size of the image
--- @shortDescription Gets the size of the image
--- @return number width The width of the image
--- @return number height The height of the image
function Image:getImageSize()
    local bimg = self.get("bimg")
    if not bimg[1] or not bimg[1][1] then return 0, 0 end
    return #bimg[1][1][1], #bimg[1]
end

--- Gets pixel information at position
--- @shortDescription Gets pixel information at position
--- @param x number X position
--- @param y number Y position
--- @return number? fg Foreground color
--- @return number? bg Background color
--- @return string? char Character at position
function Image:getPixelData(x, y)
    local frame = self.get("bimg")[self.get("currentFrame")]
    if not frame or not frame[y] then return end

    local text = frame[y][1]
    local fg = frame[y][2]
    local bg = frame[y][3]

    if not text or not fg or not bg then return end

    local fgColor = tonumber(fg:sub(x,x), 16)
    local bgColor = tonumber(bg:sub(x,x), 16)
    local char = text:sub(x,x)

    return fgColor, bgColor, char
end

local function ensureFrame(self, y)
    local frame = self.get("bimg")[self.get("currentFrame")]
    if not frame then
        frame = {}
        self.get("bimg")[self.get("currentFrame")] = frame
    end
    if not frame[y] then
        frame[y] = {"", "", ""}
    end
    return frame
end

local function updateFrameSize(self, neededWidth, neededHeight)
    if not self.get("autoResize") then return end

    local frames = self.get("bimg")

    local maxWidth = neededWidth
    local maxHeight = neededHeight

    for _, frame in ipairs(frames) do
        for y, line in pairs(frame) do
            maxWidth = math.max(maxWidth, #line[1])
            maxHeight = math.max(maxHeight, y)
        end
    end

    for _, frame in ipairs(frames) do
        for y = 1, maxHeight do
            if not frame[y] then
                frame[y] = {"", "", ""}
            end

            local line = frame[y]
            while #line[1] < maxWidth do line[1] = line[1] .. " " end
            while #line[2] < maxWidth do line[2] = line[2] .. "f" end
            while #line[3] < maxWidth do line[3] = line[3] .. "0" end
        end
    end
end

--- Sets the text at the specified position
--- @shortDescription Sets the text at the specified position
--- @param x number The x position
--- @param y number The y position
--- @param text string The text to set
--- @return Image self The Image instance
function Image:setText(x, y, text)
    if type(text) ~= "string" or #text < 1 or x < 1 or y < 1 then return self end
    if not self.get("autoResize")then
        local imgWidth, imgHeight = self:getImageSize()
        if y > imgHeight then return self end
    end
    local frame = ensureFrame(self, y)

    if self.get("autoResize") then
        updateFrameSize(self, x + #text - 1, y)
    else
        local maxLen = #frame[y][1]
        if x > maxLen then return self end
        text = text:sub(1, maxLen - x + 1)
    end

    local currentLine = frame[y][1]
    frame[y][1] = currentLine:sub(1, x-1) .. text .. currentLine:sub(x + #text)

    self:updateRender()
    return self
end

--- Gets the text at the specified position
--- @shortDescription Gets the text at the specified position
--- @param x number The x position
--- @param y number The y position
--- @param length number The length of the text to get
--- @return string text The text at the specified position
function Image:getText(x, y, length)
    if not x or not y then return "" end
    local frame = self.get("bimg")[self.get("currentFrame")]
    if not frame or not frame[y] then return "" end

    local text = frame[y][1]
    if not text then return "" end

    if length then
        return text:sub(x, x + length - 1)
    else
        return text:sub(x, x)
    end
end

--- Sets the foreground color at the specified position
--- @shortDescription Sets the foreground color at the specified position
--- @param x number The x position
--- @param y number The y position
--- @param pattern string The foreground color pattern
--- @return Image self The Image instance
function Image:setFg(x, y, pattern)
    if type(pattern) ~= "string" or #pattern < 1 or x < 1 or y < 1 then return self end
    if not self.get("autoResize")then
        local imgWidth, imgHeight = self:getImageSize()
        if y > imgHeight then return self end
    end
    local frame = ensureFrame(self, y)

    if self.get("autoResize") then
        updateFrameSize(self, x + #pattern - 1, y)
    else
        local maxLen = #frame[y][2]
        if x > maxLen then return self end
        pattern = pattern:sub(1, maxLen - x + 1)
    end

    local currentFg = frame[y][2]
    frame[y][2] = currentFg:sub(1, x-1) .. pattern .. currentFg:sub(x + #pattern)

    self:updateRender()
    return self
end

--- Gets the foreground color at the specified position
--- @shortDescription Gets the foreground color at the specified position
--- @param x number The x position
--- @param y number The y position
--- @param length number The length of the foreground color pattern to get
--- @return string fg The foreground color pattern
function Image:getFg(x, y, length)
    if not x or not y then return "" end
    local frame = self.get("bimg")[self.get("currentFrame")]
    if not frame or not frame[y] then return "" end

    local fg = frame[y][2]
    if not fg then return "" end

    if length then
        return fg:sub(x, x + length - 1)
    else
        return fg:sub(x)
    end
end

--- Sets the background color at the specified position
--- @shortDescription Sets the background color at the specified position
--- @param x number The x position
--- @param y number The y position
--- @param pattern string The background color pattern
--- @return Image self The Image instance
function Image:setBg(x, y, pattern)
    if type(pattern) ~= "string" or #pattern < 1 or x < 1 or y < 1 then return self end
    if not self.get("autoResize")then
        local imgWidth, imgHeight = self:getImageSize()
        if y > imgHeight then return self end
    end
    local frame = ensureFrame(self, y)

    if self.get("autoResize") then
        updateFrameSize(self, x + #pattern - 1, y)
    else
        local maxLen = #frame[y][3]
        if x > maxLen then return self end
        pattern = pattern:sub(1, maxLen - x + 1)
    end

    local currentBg = frame[y][3]
    frame[y][3] = currentBg:sub(1, x-1) .. pattern .. currentBg:sub(x + #pattern)

    self:updateRender()
    return self
end

--- Gets the background color at the specified position
--- @shortDescription Gets the background color at the specified position
--- @param x number The x position
--- @param y number The y position
--- @param length number The length of the background color pattern to get
--- @return string bg The background color pattern
function Image:getBg(x, y, length)
    if not x or not y then return "" end
    local frame = self.get("bimg")[self.get("currentFrame")]
    if not frame or not frame[y] then return "" end

    local bg = frame[y][3]
    if not bg then return "" end

    if length then
        return bg:sub(x, x + length - 1)
    else
        return bg:sub(x)
    end
end

--- Sets the pixel at the specified position
--- @shortDescription Sets the pixel at the specified position
--- @param x number The x position
--- @param y number The y position
--- @param char string The character to set
--- @param fg string The foreground color pattern
--- @param bg string The background color pattern
--- @return Image self The Image instance
function Image:setPixel(x, y, char, fg, bg)
    if char then self:setText(x, y, char) end
    if fg then self:setFg(x, y, fg) end
    if bg then self:setBg(x, y, bg) end
    return self
end

--- Advances to the next frame in the animation
--- @shortDescription Advances to the next frame in the animation
--- @return Image self The Image instance
function Image:nextFrame()
    if not self.get("bimg").animation then return self end

    local frames = self.get("bimg")
    local current = self.get("currentFrame")
    local next = current + 1
    if next > #frames then next = 1 end

    self.set("currentFrame", next)
    return self
end

--- Adds a new frame to the image
--- @shortDescription Adds a new frame to the image
--- @return Image self The Image instance
function Image:addFrame()
    local frames = self.get("bimg")
    local width = frames.width or #frames[1][1][1]
    local height = frames.height or #frames[1]
    local frame = {}
    local text = string.rep(" ", width)
    local fg = string.rep("f", width)
    local bg = string.rep("0", width)
    for y = 1, height do
        frame[y] = {text, fg, bg}
    end
    table.insert(frames, frame)
    return self
end

--- Updates the specified frame with the provided data
--- @shortDescription Updates the specified frame with the provided data
--- @param frameIndex number The index of the frame to update
--- @param frame table The new frame data
--- @return Image self The Image instance
function Image:updateFrame(frameIndex, frame)
    local frames = self.get("bimg")
    frames[frameIndex] = frame
    self:updateRender()
    return self
end

--- Gets the specified frame
--- @shortDescription Gets the specified frame
--- @param frameIndex number The index of the frame to get
--- @return table frame The frame data
function Image:getFrame(frameIndex)
    local frames = self.get("bimg")
    return frames[frameIndex or self.get("currentFrame")]
end

--- Gets the metadata of the image
--- @shortDescription Gets the metadata of the image
--- @return table metadata The metadata of the image
function Image:getMetadata()
    local metadata = {}
    local bimg = self.get("bimg")
    for k,v in pairs(bimg)do
        if(type(v)=="string")then
            metadata[k] = v
        end
    end
    return metadata
end

--- Sets the metadata of the image
--- @shortDescription Sets the metadata of the image
--- @param key string The key of the metadata to set
--- @param value string The value of the metadata to set
--- @return Image self The Image instance
function Image:setMetadata(key, value)
    if(type(key)=="table")then
        for k,v in pairs(key)do
            self:setMetadata(k, v)
        end
        return self
    end
    local bimg = self.get("bimg")
    if(type(value)=="string")then
        bimg[key] = value
    end
    return self
end

--- @shortDescription Renders the Image
--- @protected
function Image:render()
    VisualElement.render(self)

    local frame = self.get("bimg")[self.get("currentFrame")]
    if not frame then return end

    local offsetX = self.get("offsetX")
    local offsetY = self.get("offsetY")
    local elementWidth = self.get("width")
    local elementHeight = self.get("height")

    for y = 1, elementHeight do
        local frameY = y + offsetY
        local line = frame[frameY]

        if line then
            local text = line[1]
            local fg = line[2]
            local bg = line[3]

            if text and fg and bg then
                local remainingWidth = elementWidth - math.max(0, offsetX)
                if remainingWidth > 0 then
                    if offsetX < 0 then
                        local startPos = math.abs(offsetX) + 1
                        text = text:sub(startPos)
                        fg = fg:sub(startPos)
                        bg = bg:sub(startPos)
                    end

                    text = text:sub(1, remainingWidth)
                    fg = fg:sub(1, remainingWidth)
                    bg = bg:sub(1, remainingWidth)

                    self:blit(math.max(1, 1 + offsetX), y, text, fg, bg)
                end
            end
        end
    end
end

return Image end
project["elements/DropDown.lua"] = function(...) local VisualElement = require("elements/VisualElement")
local List = require("elements/List")
local tHex = require("libraries/colorHex")

---@configDescription A DropDown menu that shows a list of selectable items
---@configDefault false

--- Item Properties:
--- Property|Type|Description
--- -------|------|-------------
--- text|string|The display text for the item
--- separator|boolean|Makes item a divider line
--- callback|function|Function called when selected
--- foreground|color|Normal text color
--- background|color|Normal background color
--- selectedForeground|color|Text color when selected
--- selectedBackground|color|Background when selected

--- A collapsible selection menu that expands to show multiple options when clicked. Supports single and multi-selection modes, custom item styling, separators, and item callbacks.
--- @usage -- Create a styled dropdown menu
--- @usage local dropdown = main:addDropDown()
--- @usage     :setPosition(5, 5)
--- @usage     :setSize(20, 1)  -- Height expands when opened
--- @usage     :setSelectedText("Select an option...")
--- @usage 
--- @usage -- Add items with different styles and callbacks
--- @usage dropdown:setItems({
--- @usage     {
--- @usage         text = "Category A",
--- @usage         background = colors.blue,
--- @usage         foreground = colors.white
--- @usage     },
--- @usage     { separator = true, text = "-" },  -- Add a separator
--- @usage     {
--- @usage         text = "Option 1",
--- @usage         callback = function(self)
--- @usage             -- Handle selection
--- @usage             basalt.debug("Selected Option 1")
--- @usage         end
--- @usage     },
--- @usage     {
--- @usage         text = "Option 2",
--- @usage         -- Custom colors when selected
--- @usage         selectedBackground = colors.green,
--- @usage         selectedForeground = colors.white
--- @usage     }
--- @usage })
--- @usage
--- @usage -- Listen for selections
--- @usage dropdown:onChange(function(self, value)
--- @usage     basalt.debug("Selected:", value)
--- @usage end)
---@class DropDown : List
local DropDown = setmetatable({}, List)
DropDown.__index = DropDown

---@property isOpen boolean false Controls the expanded/collapsed state
DropDown.defineProperty(DropDown, "isOpen", {default = false, type = "boolean", canTriggerRender = true})
---@property dropdownHeight number 5 Maximum visible items when expanded
DropDown.defineProperty(DropDown, "dropdownHeight", {default = 5, type = "number"})
---@property selectedText string "" Text shown when no selection made
DropDown.defineProperty(DropDown, "selectedText", {default = "", type = "string"})
---@property dropSymbol string "\31" Indicator for dropdown state
DropDown.defineProperty(DropDown, "dropSymbol", {default = "\31", type = "string"})

--- Creates a new DropDown instance
--- @shortDescription Creates a new DropDown instance
--- @return DropDown self The newly created DropDown instance
--- @private
function DropDown.new()
    local self = setmetatable({}, DropDown):__init()
    self.class = DropDown
    self.set("width", 16)
    self.set("height", 1)
    self.set("z", 8)
    return self
end

--- @shortDescription Initializes the DropDown instance
--- @param props table The properties to initialize the element with
--- @param basalt table The basalt instance
--- @return DropDown self The initialized instance
--- @protected
function DropDown:init(props, basalt)
    List.init(self, props, basalt)
    self.set("type", "DropDown")
    return self
end

--- @shortDescription Handles mouse click events
--- @param button number The button that was clicked
--- @param x number The x position of the click
--- @param y number The y position of the click
--- @return boolean handled Whether the event was handled
--- @protected
function DropDown:mouse_click(button, x, y)
    if not VisualElement.mouse_click(self, button, x, y) then return false end

    local relX, relY = self:getRelativePosition(x, y)

    if relY == 1 then
        self.set("isOpen", not self.get("isOpen"))
        if not self.get("isOpen") then
            self.set("height", 1)
        else
            self.set("height", 1 + math.min(self.get("dropdownHeight"), #self.get("items")))
        end
        return true
    elseif self.get("isOpen") and relY > 1 and self.get("selectable") then
        local itemIndex = (relY - 1) + self.get("offset")
        local items = self.get("items")

        if itemIndex <= #items then
            local item = items[itemIndex]
            if type(item) == "string" then
                item = {text = item}
                items[itemIndex] = item
            end

            if not self.get("multiSelection") then
                for _, otherItem in ipairs(items) do
                    if type(otherItem) == "table" then
                        otherItem.selected = false
                    end
                end
            end

            item.selected = not item.selected

            if item.callback then
                item.callback(self)
            end

            self:fireEvent("select", itemIndex, item)
            self.set("isOpen", false)
            self.set("height", 1)
            self:updateRender()
            return true
        end
    end
    return false
end

--- @shortDescription Renders the DropDown
--- @protected
function DropDown:render()
    VisualElement.render(self)

    local text = self.get("selectedText")
    local selectedItems = self:getSelectedItems()
    if #selectedItems > 0 then
        local selectedItem = selectedItems[1]
        text = selectedItem.text or ""
        text = text:sub(1, self.get("width") - 2)
    end

    self:blit(1, 1, text .. string.rep(" ", self.get("width") - #text - 1) .. (self.get("isOpen") and "\31" or "\17"),
        string.rep(tHex[self.get("foreground")], self.get("width")),
        string.rep(tHex[self.get("background")], self.get("width")))

    if self.get("isOpen") then
        local items = self.get("items")
        local height = self.get("height") - 1
        local offset = self.get("offset")
        local width = self.get("width")

        for i = 1, height do
            local itemIndex = i + offset
            local item = items[itemIndex]

            if item then
                if type(item) == "string" then
                    item = {text = item}
                    items[itemIndex] = item
                end

                if item.separator then
                    local separatorChar = (item.text or "-"):sub(1,1)
                    local separatorText = string.rep(separatorChar, width)
                    local fg = item.foreground or self.get("foreground")
                    local bg = item.background or self.get("background")

                    self:textBg(1, i + 1, string.rep(" ", width), bg)
                    self:textFg(1, i + 1, separatorText, fg)
                else
                    local text = item.text
                    local isSelected = item.selected
                    text = text:sub(1, width)

                    local bg = isSelected and 
                        (item.selectedBackground or self.get("selectedBackground")) or
                        (item.background or self.get("background"))

                    local fg = isSelected and 
                        (item.selectedForeground or self.get("selectedForeground")) or
                        (item.foreground or self.get("foreground"))

                    self:textBg(1, i + 1, string.rep(" ", width), bg)
                    self:textFg(1, i + 1, text, fg)
                end
            end
        end
    end
end

return DropDown
 end
project["elements/Label.lua"] = function(...) local elementManager = require("elementManager")
local VisualElement = elementManager.getElement("VisualElement")
local wrapText = require("libraries/utils").wrapText
---@configDescription A simple text display element that automatically resizes its width based on the text content.

--- This is the label class. It provides a simple text display element that automatically
--- resizes its width based on the text content.
---@class Label : VisualElement
local Label = setmetatable({}, VisualElement)
Label.__index = Label

---@property text string Label The text content to display. Can be a string or a function that returns a string
Label.defineProperty(Label, "text", {default = "Label", type = "string", canTriggerRender = true, setter = function(self, value)
    if(type(value)=="function")then value = value() end
    if(self.get("autoSize"))then
        self.set("width", #value)
    else
        self.set("height", #wrapText(value, self.get("width")))
    end
    return value
end})

---@property autoSize boolean true Whether the label should automatically resize its width based on the text content
Label.defineProperty(Label, "autoSize", {default = true, type = "boolean", canTriggerRender = true, setter = function(self, value)
    if(value)then
        self.set("width", #self.get("text"))
    else
        self.set("height", #wrapText(self.get("text"), self.get("width")))
    end
    return value
end})

--- Creates a new Label instance
--- @shortDescription Creates a new Label instance
--- @return Label self The newly created Label instance
--- @private
function Label.new()
    local self = setmetatable({}, Label):__init()
    self.class = Label
    self.set("z", 3)
    self.set("foreground", colors.black)
    self.set("backgroundEnabled", false)
    return self
end

--- @shortDescription Initializes the Label instance
--- @param props table The properties to initialize the element with
--- @param basalt table The basalt instance
--- @return Label self The initialized instance
--- @protected
function Label:init(props, basalt)
    VisualElement.init(self, props, basalt)
    if(self.parent)then
        self.set("background", self.parent.get("background"))
        self.set("foreground", self.parent.get("foreground"))
    end
    self.set("type", "Label")
    return self
end

--- Gets the wrapped lines of the Label
--- @shortDescription Gets the wrapped lines of the Label
--- @return table wrappedText The wrapped lines of the Label
function Label:getWrappedText()
    local text = self.get("text")
    local wrappedText = wrapText(text, self.get("width"))
    return wrappedText
end

--- @shortDescription Renders the Label by drawing its text content
--- @protected
function Label:render()
    VisualElement.render(self)
    local text = self.get("text")
    if(self.get("autoSize"))then
        self:textFg(1, 1, text, self.get("foreground"))
    else
        local wrappedText = wrapText(text, self.get("width"))
        for i, line in ipairs(wrappedText) do
            self:textFg(1, i, line, self.get("foreground"))
        end
    end
end

return Label end
project["elements/CheckBox.lua"] = function(...) local VisualElement = require("elements/VisualElement")
---@configDescription This is a checkbox. It is a visual element that can be checked.

--- A toggleable UI element that can be checked or unchecked. Displays different text based on its state and supports automatic sizing. Commonly used in forms and settings interfaces for boolean options.
--- @usage -- Create a checkbox for a setting
--- @usage local checkbox = parent:addCheckBox()
--- @usage     :setText("Enable Feature")
--- @usage     :setCheckedText("✓")
--- @usage     :onChange("checked", function(self, checked)
--- @usage         -- React to checkbox state changes
--- @usage         if checked then
--- @usage             -- Handle enabled state
--- @usage         else
--- @usage             -- Handle disabled state
--- @usage         end
--- @usage     end)
--- @class CheckBox : VisualElement
local CheckBox = setmetatable({}, VisualElement)
CheckBox.__index = CheckBox

---@property checked boolean false The current state of the checkbox (true=checked, false=unchecked)
CheckBox.defineProperty(CheckBox, "checked", {default = false, type = "boolean", canTriggerRender = true})
---@property text string empty Text shown when the checkbox is unchecked
CheckBox.defineProperty(CheckBox, "text", {default = " ", type = "string", canTriggerRender = true, setter=function(self, value)
    local checkedText = self.get("checkedText")
    local width = math.max(#value, #checkedText)
    if(self.get("autoSize"))then
        self.set("width", width)
    end
    return value
end})
---@property checkedText string x Text shown when the checkbox is checked
CheckBox.defineProperty(CheckBox, "checkedText", {default = "x", type = "string", canTriggerRender = true, setter=function(self, value)
    local text = self.get("text")
    local width = math.max(#value, #text)
    if(self.get("autoSize"))then
        self.set("width", width)
    end
    return value
end})
---@property autoSize boolean true Automatically adjusts width based on text length
CheckBox.defineProperty(CheckBox, "autoSize", {default = true, type = "boolean"})

CheckBox.defineEvent(CheckBox, "mouse_click")
CheckBox.defineEvent(CheckBox, "mouse_up")

--- @shortDescription Creates a new CheckBox instance
--- @return CheckBox self The created instance
--- @protected
function CheckBox.new()
    local self = setmetatable({}, CheckBox):__init()
    self.class = CheckBox
    self.set("backgroundEnabled", false)
    return self
end

--- @shortDescription Initializes the CheckBox instance
--- @param props table The properties to initialize the element with
--- @param basalt table The basalt instance
--- @protected
function CheckBox:init(props, basalt)
    VisualElement.init(self, props, basalt)
    self.set("type", "CheckBox")
end

--- Handles mouse interactions to toggle the checkbox state
--- @shortDescription Toggles checked state on mouse click
--- @param button number The button that was clicked
--- @param x number The x position of the click
--- @param y number The y position of the click
--- @return boolean Clicked Whether the event was handled
--- @protected
function CheckBox:mouse_click(button, x, y)
    if VisualElement.mouse_click(self, button, x, y) then
        self.set("checked", not self.get("checked"))
        return true
    end
    return false
end

--- @shortDescription Renders the CheckBox
--- @protected
function CheckBox:render()
    VisualElement.render(self)

    local checked = self.get("checked")
    local defaultText = self.get("text")
    local checkedText = self.get("checkedText")
    local text = string.sub(checked and checkedText or defaultText, 1, self.get("width"))

    self:textFg(1, 1, text, self.get("foreground"))
end

return CheckBox end
project["elements/VisualElement.lua"] = function(...) ---@diagnostic disable: duplicate-set-field, undefined-field, undefined-doc-name, param-type-mismatch, redundant-return-value
local elementManager = require("elementManager")
local BaseElement = elementManager.getElement("BaseElement")
local tHex = require("libraries/colorHex")
---@configDescription The Visual Element class which is the base class for all visual UI elements

--- This is the visual element class. It serves as the base class for all visual UI elements
--- and provides core functionality for positioning, sizing, colors, and rendering.
---@class VisualElement : BaseElement
local VisualElement = setmetatable({}, BaseElement)
VisualElement.__index = VisualElement

---@property x number 1 The horizontal position relative to parent
VisualElement.defineProperty(VisualElement, "x", {default = 1, type = "number", canTriggerRender = true})
---@property y number 1 The vertical position relative to parent
VisualElement.defineProperty(VisualElement, "y", {default = 1, type = "number", canTriggerRender = true})
---@property z number 1 The z-index for layering elements
VisualElement.defineProperty(VisualElement, "z", {default = 1, type = "number", canTriggerRender = true, setter = function(self, value)
    if self.parent then
        self.parent:sortChildren()
    end
    return value
end})

---@property width number 1 The width of the element
VisualElement.defineProperty(VisualElement, "width", {default = 1, type = "number", canTriggerRender = true})
---@property height number 1 The height of the element
VisualElement.defineProperty(VisualElement, "height", {default = 1, type = "number", canTriggerRender = true})
---@property background color black The background color
VisualElement.defineProperty(VisualElement, "background", {default = colors.black, type = "color", canTriggerRender = true})
---@property foreground color white The text/foreground color
VisualElement.defineProperty(VisualElement, "foreground", {default = colors.white, type = "color", canTriggerRender = true})
---@property clicked boolean false Whether the element is currently clicked
VisualElement.defineProperty(VisualElement, "clicked", {default = false, type = "boolean"})
---@property hover boolean false Whether the mouse is currently hover over the element (Craftos-PC only)
VisualElement.defineProperty(VisualElement, "hover", {default = false, type = "boolean"})
---@property backgroundEnabled boolean true Whether to render the background
VisualElement.defineProperty(VisualElement, "backgroundEnabled", {default = true, type = "boolean", canTriggerRender = true})
---@property borderTop boolean false Draw top border
VisualElement.defineProperty(VisualElement, "borderTop", {default = false, type = "boolean", canTriggerRender = true})
---@property borderBottom boolean false Draw bottom border
VisualElement.defineProperty(VisualElement, "borderBottom", {default = false, type = "boolean", canTriggerRender = true})
---@property borderLeft boolean false Draw left border
VisualElement.defineProperty(VisualElement, "borderLeft", {default = false, type = "boolean", canTriggerRender = true})
---@property borderRight boolean false Draw right border
VisualElement.defineProperty(VisualElement, "borderRight", {default = false, type = "boolean", canTriggerRender = true})
---@property borderColor color white Border color
VisualElement.defineProperty(VisualElement, "borderColor", {default = colors.white, type = "color", canTriggerRender = true})
---@property focused boolean false Whether the element has input focus
VisualElement.defineProperty(VisualElement, "focused", {default = false, type = "boolean", setter = function(self, value, internal)
    local curValue = self.get("focused")
    if value == curValue then return value end

    if value then
        self:focus()
    else
        self:blur()
    end

    if not internal and self.parent then
        if value then
            self.parent:setFocusedChild(self)
        else
            self.parent:setFocusedChild(nil)
        end
    end
    return value
end})

---@property visible boolean true Whether the element is visible
VisualElement.defineProperty(VisualElement, "visible", {default = true, type = "boolean", canTriggerRender = true, setter=function(self, value)
    if(self.parent~=nil)then
        self.parent.set("childrenSorted", false)
        self.parent.set("childrenEventsSorted", false)
    end
    if(value==false)then
        self.set("clicked", false)
    end
    return value
end})

---@property ignoreOffset boolean false Whether to ignore the parent's offset
VisualElement.defineProperty(VisualElement, "ignoreOffset", {default = false, type = "boolean"})

---@combinedProperty position {x number, y number} Combined x, y position
VisualElement.combineProperties(VisualElement, "position", "x", "y")
---@combinedProperty size {width number, height number} Combined width, height
VisualElement.combineProperties(VisualElement, "size", "width", "height")
---@combinedProperty color {foreground number, background number} Combined foreground, background colors
VisualElement.combineProperties(VisualElement, "color", "foreground", "background")

---@event onClick {button string, x number, y number} Fired on mouse click
---@event onMouseUp {button, x, y} Fired on mouse button release
---@event onRelease {button, x, y} Fired when mouse leaves while clicked
---@event onDrag {button, x, y} Fired when mouse moves while clicked
---@event onScroll {direction, x, y} Fired on mouse scroll
---@event onEnter {-} Fired when mouse enters element
---@event onLeave {-} Fired when mouse leaves element
---@event onFocus {-} Fired when element receives focus
---@event onBlur {-} Fired when element loses focus
---@event onKey {key} Fired on key press
---@event onKeyUp {key} Fired on key release
---@event onChar {char} Fired on character input

VisualElement.defineEvent(VisualElement, "focus")
VisualElement.defineEvent(VisualElement, "blur")

VisualElement.registerEventCallback(VisualElement, "Click", "mouse_click", "mouse_up")
VisualElement.registerEventCallback(VisualElement, "ClickUp", "mouse_up", "mouse_click")
VisualElement.registerEventCallback(VisualElement, "Drag", "mouse_drag", "mouse_click", "mouse_up")
VisualElement.registerEventCallback(VisualElement, "Scroll", "mouse_scroll")
VisualElement.registerEventCallback(VisualElement, "Enter", "mouse_enter", "mouse_move")
VisualElement.registerEventCallback(VisualElement, "LeEave", "mouse_leave", "mouse_move")
VisualElement.registerEventCallback(VisualElement, "Focus", "focus", "blur")
VisualElement.registerEventCallback(VisualElement, "Blur", "blur", "focus")
VisualElement.registerEventCallback(VisualElement, "Key", "key", "key_up")
VisualElement.registerEventCallback(VisualElement, "Char", "char")
VisualElement.registerEventCallback(VisualElement, "KeyUp", "key_up", "key")

local max, min = math.max, math.min

--- Creates a new VisualElement instance
--- @shortDescription Creates a new visual element
--- @return VisualElement object The newly created VisualElement instance
--- @private
function VisualElement.new()
    local self = setmetatable({}, VisualElement):__init()
    self.class = VisualElement
    return self
end

--- @shortDescription Initializes a new visual element with properties
--- @param props table The properties to initialize the element with
--- @param basalt table The basalt instance
--- @protected
function VisualElement:init(props, basalt)
    BaseElement.init(self, props, basalt)
    self.set("type", "VisualElement")
    self:observe("x", function()
        if self.parent then
            self.parent.set("childrenSorted", false)
        end
    end)
    self:observe("y", function()
        if self.parent then
            self.parent.set("childrenSorted", false)
        end
    end)
    self:observe("width", function()
        if self.parent then
            self.parent.set("childrenSorted", false)
        end
    end)
    self:observe("height", function()
        if self.parent then
            self.parent.set("childrenSorted", false)
        end
    end)
    self:observe("visible", function()
        if self.parent then
            self.parent.set("childrenSorted", false)
        end
    end)
end

--- @shortDescription Multi-character drawing with colors
--- @param x number The x position to draw
--- @param y number The y position to draw
--- @param width number The width of the area to draw
--- @param height number The height of the area to draw
--- @param text string The text to draw
--- @param fg string The foreground color
--- @param bg string The background color
--- @protected
function VisualElement:multiBlit(x, y, width, height, text, fg, bg)
    local xElement, yElement = self:calculatePosition()
    x = x + xElement - 1
    y = y + yElement - 1
    self.parent:multiBlit(x, y, width, height, text, fg, bg)
end

--- @shortDescription Draws text with foreground color
--- @param x number The x position to draw
--- @param y number The y position to draw
--- @param text string The text char to draw
--- @param fg color The foreground color
--- @protected
function VisualElement:textFg(x, y, text, fg)
    local xElement, yElement = self:calculatePosition()
    x = x + xElement - 1
    y = y + yElement - 1
    self.parent:textFg(x, y, text, fg)
end

--- @shortDescription Draws text with background color
--- @param x number The x position to draw
--- @param y number The y position to draw
--- @param text string The text char to draw
--- @param bg color The background color
--- @protected
function VisualElement:textBg(x, y, text, bg)
    local xElement, yElement = self:calculatePosition()
    x = x + xElement - 1
    y = y + yElement - 1
    self.parent:textBg(x, y, text, bg)
end

function VisualElement:drawText(x, y, text)
    local xElement, yElement = self:calculatePosition()
    x = x + xElement - 1
    y = y + yElement - 1
    self.parent:drawText(x, y, text)
end

function VisualElement:drawFg(x, y, fg)
    local xElement, yElement = self:calculatePosition()
    x = x + xElement - 1
    y = y + yElement - 1
    self.parent:drawFg(x, y, fg)
end

function VisualElement:drawBg(x, y, bg)
    local xElement, yElement = self:calculatePosition()
    x = x + xElement - 1
    y = y + yElement - 1
    self.parent:drawBg(x, y, bg)
end

--- @shortDescription Draws text with both colors
--- @param x number The x position to draw
--- @param y number The y position to draw
--- @param text string The text char to draw
--- @param fg string The foreground color
--- @param bg string The background color
--- @protected
function VisualElement:blit(x, y, text, fg, bg)
    local xElement, yElement = self:calculatePosition()
    x = x + xElement - 1
    y = y + yElement - 1
    self.parent:blit(x, y, text, fg, bg)
end

--- Checks if the specified coordinates are within the bounds of the element
--- @shortDescription Checks if point is within bounds
--- @param x number The x position to check
--- @param y number The y position to check
--- @return boolean isInBounds Whether the coordinates are within the bounds of the element
function VisualElement:isInBounds(x, y)
    local xPos, yPos = self.get("x"), self.get("y")
    local width, height = self.get("width"), self.get("height")
    if(self.get("ignoreOffset"))then
        if(self.parent)then
            x = x - self.parent.get("offsetX")
            y = y - self.parent.get("offsetY")
        end
    end

    return x >= xPos and x <= xPos + width - 1 and
           y >= yPos and y <= yPos + height - 1
end

--- @shortDescription Handles a mouse click event
--- @param button number The button that was clicked
--- @param x number The x position of the click
--- @param y number The y position of the click
--- @return boolean clicked Whether the element was clicked
--- @protected
function VisualElement:mouse_click(button, x, y)
    if self:isInBounds(x, y) then
        self.set("clicked", true)
        self:fireEvent("mouse_click", button, self:getRelativePosition(x, y))
        return true
    end
    return false
end

--- @shortDescription Handles a mouse up event
--- @param button number The button that was released
--- @param x number The x position of the release
--- @param y number The y position of the release
--- @return boolean release Whether the element was released on the element
--- @protected
function VisualElement:mouse_up(button, x, y)
    if self:isInBounds(x, y) then
        self.set("clicked", false)
        self:fireEvent("mouse_up", button, self:getRelativePosition(x, y))
        return true
    end
    return false
end

--- @shortDescription Handles a mouse release event
--- @param button number The button that was released
--- @param x number The x position of the release
--- @param y number The y position of the release
--- @protected
function VisualElement:mouse_release(button, x, y)
    self:fireEvent("mouse_release", button, self:getRelativePosition(x, y))
    self.set("clicked", false)
end

---@shortDescription Handles a mouse move event
---@param _ number unknown
---@param x number The x position of the mouse
---@param y number The y position of the mouse
---@return boolean hover Whether the mouse has moved over the element
--- @protected
function VisualElement:mouse_move(_, x, y)
    if(x==nil)or(y==nil)then return false end
    local hover = self.get("hover")
    if(self:isInBounds(x, y))then
        if(not hover)then
            self.set("hover", true)
            self:fireEvent("mouse_enter", self:getRelativePosition(x, y))
        end
        return true
    else
        if(hover)then
            self.set("hover", false)
            self:fireEvent("mouse_leave", self:getRelativePosition(x, y))
        end
    end
    return false
end

--- @shortDescription Handles a mouse scroll event
--- @param direction number The scroll direction
--- @param x number The x position of the scroll
--- @param y number The y position of the scroll
--- @return boolean scroll Whether the element was scrolled
--- @protected
function VisualElement:mouse_scroll(direction, x, y)
    if(self:isInBounds(x, y))then
        self:fireEvent("mouse_scroll", direction, self:getRelativePosition(x, y))
        return true
    end
    return false
end

--- @shortDescription Handles a mouse drag event
--- @param button number The button that was clicked while dragging
--- @param x number The x position of the drag
--- @param y number The y position of the drag
--- @return boolean drag Whether the element was dragged
--- @protected
function VisualElement:mouse_drag(button, x, y)
    if(self.get("clicked"))then
        self:fireEvent("mouse_drag", button, self:getRelativePosition(x, y))
        return true
    end
    return false
end

--- @shortDescription Handles a focus event
--- @protected
function VisualElement:focus()
    self:fireEvent("focus")
end

--- @shortDescription Handles a blur event
--- @protected
function VisualElement:blur()
    self:fireEvent("blur")
    -- Attempt to clear cursor; signature may expect (x,y,blink,fg,bg)
    pcall(function() self:setCursor(1,1,false, self.get and self.get("foreground")) end)
end

--- Adds or updates a drawable character border around the element using the canvas plugin.
--- The border will automatically adapt to size/background changes because the command
--- reads current properties each render.
-- @param colorOrOptions any Border color or options table
--- @return VisualElement self
function VisualElement:addBorder(colorOrOptions, sideOptions)
    local col = nil
    local spec = nil
    if type(colorOrOptions) == "table" and (colorOrOptions.color or colorOrOptions.top ~= nil or colorOrOptions.left ~= nil) then
        col = colorOrOptions.color
        spec = colorOrOptions
    else
        col = colorOrOptions
        spec = sideOptions
    end
    if spec then
        if spec.top ~= nil then self.set("borderTop", spec.top) end
        if spec.bottom ~= nil then self.set("borderBottom", spec.bottom) end
        if spec.left ~= nil then self.set("borderLeft", spec.left) end
        if spec.right ~= nil then self.set("borderRight", spec.right) end
    else
        -- default: enable all sides
        self.set("borderTop", true)
        self.set("borderBottom", true)
        self.set("borderLeft", true)
        self.set("borderRight", true)
    end
    if col then self.set("borderColor", col) end
    return self
end

--- Removes the previously added border (if any)
--- @return VisualElement self
function VisualElement:removeBorder()
    self.set("borderTop", false)
    self.set("borderBottom", false)
    self.set("borderLeft", false)
    self.set("borderRight", false)
    return self
end

--- @shortDescription Handles a key event
--- @param key number The key that was pressed
--- @protected
function VisualElement:key(key, held)
    if(self.get("focused"))then
        self:fireEvent("key", key, held)
    end
end

--- @shortDescription Handles a key up event
--- @param key number The key that was released
--- @protected
function VisualElement:key_up(key)
    if(self.get("focused"))then
        self:fireEvent("key_up", key)
    end
end

--- @shortDescription Handles a character event
--- @param char string The character that was pressed
--- @protected
function VisualElement:char(char)
    if(self.get("focused"))then
        self:fireEvent("char", char)
    end
end

--- Calculates the position of the element relative to its parent
--- @shortDescription Calculates the position of the element
--- @return number x The x position
--- @return number y The y position
function VisualElement:calculatePosition()
    local x, y = self.get("x"), self.get("y")
    if not self.get("ignoreOffset") then
        if self.parent ~= nil then
            local xO, yO = self.parent.get("offsetX"), self.parent.get("offsetY")
            x = x - xO
            y = y - yO
        end
    end
    return x, y
end

--- Returns the absolute position of the element or the given coordinates.
--- @shortDescription Returns the absolute position of the element
---@param x? number x position
---@param y? number y position
---@return number x The absolute x position
---@return number y The absolute y position
function VisualElement:getAbsolutePosition(x, y)
    local xPos, yPos = self.get("x"), self.get("y")
    if(x ~= nil) then
        xPos = xPos + x - 1
    end
    if(y ~= nil) then
        yPos = yPos + y - 1
    end

    local parent = self.parent
    while parent do
        local px, py = parent.get("x"), parent.get("y")
        xPos = xPos + px - 1
        yPos = yPos + py - 1
        parent = parent.parent
    end

    return xPos, yPos
end

--- Returns the relative position of the element or the given coordinates.
--- @shortDescription Returns the relative position of the element
---@param x? number x position
---@param y? number y position
---@return number x The relative x position
---@return number y The relative y position
function VisualElement:getRelativePosition(x, y)
    if (x == nil) or (y == nil) then
        x, y = self.get("x"), self.get("y")
    end

    local parentX, parentY = 1, 1
    if self.parent then
        parentX, parentY = self.parent:getRelativePosition()
    end

    local elementX, elementY = self.get("x"), self.get("y")
    return x - (elementX - 1) - (parentX - 1),
           y - (elementY - 1) - (parentY - 1)
end

--- @shortDescription Sets the cursor position
--- @param x number The x position of the cursor
--- @param y number The y position of the cursor
--- @param blink boolean Whether the cursor should blink
--- @param color number The color of the cursor
--- @return VisualElement self The VisualElement instance
--- @protected
function VisualElement:setCursor(x, y, blink, color)
    if self.parent then
        local xPos, yPos = self:calculatePosition()
        if(x + xPos - 1<1)or(x + xPos - 1>self.parent.get("width"))or
        (y + yPos - 1<1)or(y + yPos - 1>self.parent.get("height"))then
            return self.parent:setCursor(x + xPos - 1, y + yPos - 1, false)
        end
        return self.parent:setCursor(x + xPos - 1, y + yPos - 1, blink, color)
    end
    return self
end

--- This function is used to prioritize the element by moving it to the top of its parent's children. It removes the element from its parent and adds it back, effectively changing its order.
--- @shortDescription Prioritizes the element by moving it to the top of its parent's children
--- @return VisualElement self The VisualElement instance
function VisualElement:prioritize()
    if(self.parent)then
        local parent = self.parent
        parent:removeChild(self)
        parent:addChild(self)
        self:updateRender()
    end
    return self
end

--- @shortDescription Renders the element
--- @protected
function VisualElement:render()
    if(not self.get("backgroundEnabled"))then return end
    local width, height = self.get("width"), self.get("height")
    local fgHex = tHex[self.get("foreground")]
    local bgHex = tHex[self.get("background")]
    self:multiBlit(1, 1, width, height, " ", fgHex, bgHex)
    if (self.get("borderTop") or self.get("borderBottom") or self.get("borderLeft") or self.get("borderRight")) then
        local bColor = self.get("borderColor") or self.get("foreground")
        local bHex = tHex[bColor] or fgHex
        if self.get("borderTop") then
            self:textFg(1,1,("\131"):rep(width), bColor)
        end
        if self.get("borderBottom") then
            self:multiBlit(1,height,width,1,"\143", bgHex, bHex)
        end
        if self.get("borderLeft") then
            self:multiBlit(1,1,1,height,"\149", bHex, bgHex)
        end
        if self.get("borderRight") then
            self:multiBlit(width,1,1,height,"\149", bgHex, bHex)
        end
        -- Corners
        if self.get("borderTop") and self.get("borderLeft") then self:blit(1,1,"\151", bHex, bgHex) end
        if self.get("borderTop") and self.get("borderRight") then self:blit(width,1,"\148", bgHex, bHex) end
        if self.get("borderBottom") and self.get("borderLeft") then self:blit(1,height,"\138", bgHex, bHex) end
        if self.get("borderBottom") and self.get("borderRight") then self:blit(width,height,"\133", bgHex, bHex) end
    end
end

--- @shortDescription Post-rendering function for the element
--- @protected
function VisualElement:postRender()
end

function VisualElement:destroy()
    self.set("visible", false)
    BaseElement.destroy(self)
end

return VisualElement
 end
project["elements/Program.lua"] = function(...) local elementManager = require("elementManager")
local VisualElement = elementManager.getElement("VisualElement")
local errorManager = require("errorManager")

--- @configDescription A program that runs in a window

--- This is the program class. It provides a program that runs in a window.
---@class Program : VisualElement
local Program = setmetatable({}, VisualElement)
Program.__index = Program

--- @property program table nil The program instance
Program.defineProperty(Program, "program", {default = nil, type = "table"})
--- @property path string "" The path to the program
Program.defineProperty(Program, "path", {default = "", type = "string"})
--- @property running boolean false Whether the program is running
Program.defineProperty(Program, "running", {default = false, type = "boolean"})
--- @property errorCallback function nil The error callback function
Program.defineProperty(Program, "errorCallback", {default = nil, type = "function"})
--- @property doneCallback function nil The done callback function
Program.defineProperty(Program, "doneCallback", {default = nil, type = "function"})

Program.defineEvent(Program, "*")

local BasaltProgram = {}
BasaltProgram.__index = BasaltProgram
local newPackage = dofile("rom/modules/main/cc/require.lua").make

---@private
function BasaltProgram.new(program, env, addEnvironment)
    local self = setmetatable({}, BasaltProgram)
    self.env = env or {}
    self.args = {}
    self.addEnvironment = addEnvironment == nil and true or addEnvironment
    self.program = program
    return self
end

function BasaltProgram:setArgs(...)
    self.args = {...}
end

local function createShellEnv(dir)
    local env = { shell = shell, multishell = multishell }
    env.require, env.package = newPackage(env, dir)
    return env
end

---@private
function BasaltProgram:run(path, width, height)
    self.window = window.create(self.program:getBaseFrame():getTerm(), 1, 1, width, height, false)
    local pPath = shell.resolveProgram(path) or fs.exists(path) and path or nil
    if(pPath~=nil)then
        if(fs.exists(pPath)) then
            local file = fs.open(pPath, "r")
            local content = file.readAll()
            file.close()

            local env = setmetatable(createShellEnv(fs.getDir(path)), { __index = _ENV })
            env.term = self.window
            env.term.current = term.current
            env.term.redirect = term.redirect
            env.term.native = function ()
                return self.window
            end
            if(self.addEnvironment)then
                for k,v in pairs(self.env) do
                    env[k] = v
                end
            else
                env = self.env
            end


            self.coroutine = coroutine.create(function()
                local program = load(content, "@/" .. path, nil, env)
                if program then
                    local result = program(table.unpack(self.args))
                    return result
                end
            end)
            local current = term.current()
            term.redirect(self.window)
            local ok, result = coroutine.resume(self.coroutine)
            term.redirect(current)
            if not ok then
                local doneCallback = self.program.get("doneCallback")
                if doneCallback then
                    doneCallback(self.program, ok, result)
                end
                local errorCallback = self.program.get("errorCallback")
                if errorCallback then
                    local trace = debug.traceback(self.coroutine, result)
                    local _result = errorCallback(self.program, result, trace:gsub(result, ""))
                    if(_result==false)then
                        self.filter = nil
                        return ok, result
                    end
                end
                errorManager.header = "Basalt Program Error ".. path
                errorManager.error(result)
            end
            if coroutine.status(self.coroutine)=="dead" then
                self.program.set("running", false)
                self.program.set("program", nil)
                local doneCallback = self.program.get("doneCallback")
                if doneCallback then
                    doneCallback(self.program, ok, result)
                end
            end
        else
            errorManager.header = "Basalt Program Error ".. path
            errorManager.error("File not found")
        end
    else
        errorManager.header = "Basalt Program Error"
        errorManager.error("Program "..path.." not found")
    end
end

---@private
function BasaltProgram:resize(width, height)
    self.window.reposition(1, 1, width, height)
    self:resume("term_resize", width, height)
end

---@private
function BasaltProgram:resume(event, ...)
    local args = {...}
    if(event:find("mouse_"))then
        args[2], args[3] = self.program:getRelativePosition(args[2], args[3])
    end
    if self.coroutine==nil or coroutine.status(self.coroutine)=="dead" then self.program.set("running", false) return end
    if(self.filter~=nil)then
        if(event~=self.filter)then return end
        self.filter=nil
    end
    local current = term.current()
    term.redirect(self.window)
    local ok, result = coroutine.resume(self.coroutine, event, table.unpack(args))
    term.redirect(current)

    if ok then
        self.filter = result
        if coroutine.status(self.coroutine)=="dead" then
            self.program.set("running", false)
            self.program.set("program", nil)
            local doneCallback = self.program.get("doneCallback")
            if doneCallback then
                doneCallback(self.program, ok, result)
            end
        end
    else
        local doneCallback = self.program.get("doneCallback")
        if doneCallback then
            doneCallback(self.program, ok, result)
        end
        local errorCallback = self.program.get("errorCallback")
        if errorCallback then
            local trace = debug.traceback(self.coroutine, result)
            trace = trace == nil and "" or trace
            result = result or "Unknown error"
            local _result = errorCallback(self.program, result, trace:gsub(result, ""))
            if(_result==false)then
                self.filter = nil
                return ok, result
            end
        end
        errorManager.header = "Basalt Program Error"
        errorManager.error(result)
    end
    return ok, result
end

---@private
function BasaltProgram:stop()
    if self.coroutine==nil or coroutine.status(self.coroutine)=="dead" then self.program.set("running", false) return end
    coroutine.close(self.coroutine)
    self.coroutine = nil
end

--- @shortDescription Creates a new Program instance
--- @return Program object The newly created Program instance
--- @private
function Program.new()
    local self = setmetatable({}, Program):__init()
    self.class = Program
    self.set("z", 5)
    self.set("width", 30)
    self.set("height", 12)
    return self
end

--- @shortDescription Initializes the Program instance
--- @param props table The properties to initialize the element with
--- @param basalt table The basalt instance
--- @return Program self The initialized instance
--- @protected
function Program:init(props, basalt)
    VisualElement.init(self, props, basalt)
    self.set("type", "Program")
        self:observe("width", function(self, width)
        local program = self.get("program")
        if program then
            program:resize(width, self.get("height"))
        end
    end)
    self:observe("height", function(self, height)
        local program = self.get("program")
        if program then
            program:resize(self.get("width"), height)
        end
    end)
    return self
end

--- Executes a program
--- @shortDescription Executes a program
--- @param path string The path to the program
--- @param env? table The environment to run the program in
--- @param addEnvironment? boolean Whether to add the environment to the program's environment (false = overwrite instead of adding)
--- @return Program self The Program instance
function Program:execute(path, env, addEnvironment, ...)
    self.set("path", path)
    self.set("running", true)
    local program = BasaltProgram.new(self, env, addEnvironment)
    self.set("program", program)
    program:setArgs(...)
    program:run(path, self.get("width"), self.get("height"), ...)
    self:updateRender()
    return self
end

--- Stops the program
--- @shortDescription Stops the program
--- @return Program self The Program instance
function Program:stop()
    local program = self.get("program")
    if program then
        program:stop()
        self.set("running", false)
        self.set("program", nil)
    end
    return self
end

--- Sends an event to the program
--- @shortDescription Sends an event to the program
--- @param event string The event to send
--- @param ... any The event arguments
--- @return Program self The Program instance
function Program:sendEvent(event, ...)
    self:dispatchEvent(event, ...)
    return self
end

--- Registers a callback for the program's error event, if the function returns false, the program won't stop
--- @shortDescription Registers a callback for the program's error event
--- @param fn function The callback function to register
--- @return Program self The Program instance
function Program:onError(fn)
    self.set("errorCallback", fn)
    return self
end

--- Registers a callback for the program's done event
--- @shortDescription Registers a callback for the program's done event
--- @param fn function The callback function to register
--- @return Program self The Program instance
function Program:onDone(fn)
    self.set("doneCallback", fn)
    return self
end

--- @shortDescription Handles all incomming events
--- @param event string The event to handle
--- @param ... any The event arguments
--- @return any result The event result
--- @protected
function Program:dispatchEvent(event, ...)
    local program = self.get("program")
    local result = VisualElement.dispatchEvent(self, event, ...)
    if program then
        program:resume(event, ...)
        if(self.get("focused"))then
            local cursorBlink = program.window.getCursorBlink()
            local cursorX, cursorY = program.window.getCursorPos()
            self:setCursor(cursorX, cursorY, cursorBlink, program.window.getTextColor())
        end
        self:updateRender()
    end
    return result
end

--- @shortDescription Gets called when the element gets focused
--- @protected
function Program:focus()
    if(VisualElement.focus(self))then
        local program = self.get("program")
        if program then
            local cursorBlink = program.window.getCursorBlink()
            local cursorX, cursorY = program.window.getCursorPos()
            self:setCursor(cursorX, cursorY, cursorBlink, program.window.getTextColor())
        end
    end
end

--- @shortDescription Renders the program
--- @protected
function Program:render()
    VisualElement.render(self)
    local program = self.get("program")
    if program then
        local _, height = program.window.getSize()
        for y = 1, height do
            local text, fg, bg = program.window.getLine(y)
            if text then
                self:blit(1, y, text, fg, bg)
            end
        end
    end
end

return Program end
project["elements/BarChart.lua"] = function(...) local elementManager = require("elementManager")
local VisualElement = elementManager.getElement("VisualElement")
local BaseGraph = elementManager.getElement("Graph")
local tHex = require("libraries/colorHex")
--- @configDescription A bar chart element based on the graph element.
--- @configDefault false

--- A data visualization element that represents numeric data through vertical bars. Each bar's height corresponds to its value, making it ideal for comparing quantities across categories or showing data changes over time. Supports multiple data series with customizable colors and styles.
--- @usage -- Create a bar chart
--- @usage local chart = main:addBarChart()
--- @usage 
--- @usage -- Add two data series with different colors
--- @usage chart:addSeries("input", " ", colors.green, colors.green, 5)
--- @usage chart:addSeries("output", " ", colors.red, colors.red, 5)
--- @usage 
--- @usage -- Continuously update the chart with random data
--- @usage basalt.schedule(function()
--- @usage     while true do
--- @usage         chart:addPoint("input", math.random(1,100))
--- @usage         chart:addPoint("output", math.random(1,100))
--- @usage         sleep(2)
--- @usage     end
--- @usage end)
--- @class BarChart : Graph
local BarChart = setmetatable({}, BaseGraph)
BarChart.__index = BarChart

--- Creates a new BarChart instance
--- @shortDescription Creates a new BarChart instance
--- @return BarChart self The newly created BarChart instance
--- @private
function BarChart.new()
    local self = setmetatable({}, BarChart):__init()
    self.class = BarChart
    return self
end

--- @shortDescription Initializes the BarChart instance
--- @param props table The properties to initialize the element with
--- @param basalt table The basalt instance
--- @return BarChart self The initialized instance
--- @protected
function BarChart:init(props, basalt)
    BaseGraph.init(self, props, basalt)
    self.set("type", "BarChart")
    return self
end

--- Renders the bar chart by calculating bar positions and heights based on data values
--- @shortDescription Draws bars for each data point in visible series
--- @protected
function BarChart:render()
    VisualElement.render(self)

    local width = self.get("width")
    local height = self.get("height")
    local minVal = self.get("minValue")
    local maxVal = self.get("maxValue")
    local series = self.get("series")

    local activeSeriesCount = 0
    local seriesList = {}
    for _, s in pairs(series) do
        if(s.visible)then
            if #s.data > 0 then
                activeSeriesCount = activeSeriesCount + 1
                table.insert(seriesList, s)
            end
        end
    end

    local barGroupWidth = activeSeriesCount
    local spacing = 1
    local totalGroups = math.min(seriesList[1] and seriesList[1].pointCount or 0, math.floor((width + spacing) / (barGroupWidth + spacing)))

    for groupIndex = 1, totalGroups do
        local groupX = ((groupIndex-1) * (barGroupWidth + spacing)) + 1

        for seriesIndex, s in ipairs(seriesList) do
            local value = s.data[groupIndex]
            if value then
                local x = groupX + (seriesIndex - 1)
                local normalizedValue = (value - minVal) / (maxVal - minVal)
                local y = math.floor(height - (normalizedValue * (height-1)))
                y = math.max(1, math.min(y, height))

                for barY = y, height do
                    self:blit(x, barY, s.symbol, tHex[s.fgColor], tHex[s.bgColor])
                end
            end
        end
    end
end

return BarChart
 end
project["plugins/state.lua"] = function(...) local PropertySystem = require("propertySystem")
local errorManager = require("errorManager")

---@class BaseFrame : Container
local BaseFrame = {}

function BaseFrame.setup(element)
    element.defineProperty(element, "states", {default = {}, type = "table"})
    element.defineProperty(element, "stateObserver", {default = {}, type = "table"})
end

--- Initializes a new state for this element
--- @shortDescription Initializes a new state
--- @param self BaseFrame The element to initialize state for
--- @param name string The name of the state
--- @param default any The default value of the state
--- @param persist? boolean Whether to persist the state to disk
--- @param path? string Custom file path for persistence
--- @return BaseFrame self The element instance
function BaseFrame:initializeState(name, default, persist, path)
    local states = self.get("states")

    if states[name] then
        errorManager.error("State '" .. name .. "' already exists")
        return self
    end

    local file = path or "states/" .. self.get("name") .. ".state"
    local persistedData = {}

    if persist and fs.exists(file) then
        local f = fs.open(file, "r")
        persistedData = textutils.unserialize(f.readAll()) or {}
        f.close()
    end

    states[name] = {
        value = persist and persistedData[name] or default,
        persist = persist,
    }

    return self
end


--- This is the state plugin. It provides a state management system for UI elements with support for
--- persistent states, computed states, and state sharing between elements.
---@class BaseElement
local BaseElement = {}

--- Sets the value of a state
--- @shortDescription Sets a state value
--- @param self BaseElement The element to set state for
--- @param name string The name of the state
--- @param value any The new value for the state
--- @return BaseElement self The element instance
function BaseElement:setState(name, value)
    local main = self:getBaseFrame()
    local states = main.get("states")
    local observers = main.get("stateObserver")
    if not states[name] then
        errorManager.error("State '"..name.."' not initialized")
    end

    if states[name].persist then
        local file = "states/" .. main.get("name") .. ".state"
        local persistedData = {}

        if fs.exists(file) then
            local f = fs.open(file, "r")
            persistedData = textutils.unserialize(f.readAll()) or {}
            f.close()
        end

        persistedData[name] = value

        local dir = fs.getDir(file)
        if not fs.exists(dir) then
            fs.makeDir(dir)
        end

        local f = fs.open(file, "w")
        f.write(textutils.serialize(persistedData))
        f.close()
    end

    states[name].value = value

    -- Trigger observers
    if observers[name] then
        for _, callback in ipairs(observers[name]) do
            callback(name, value)
        end
    end

    -- Recompute all computed states
    for stateName, state in pairs(states) do
        if state.computed then
            state.value = state.computeFn(self)
            if observers[stateName] then
                for _, callback in ipairs(observers[stateName]) do
                    callback(stateName, state.value)
                end
            end
        end
    end

    return self
end

--- Gets the value of a state
--- @shortDescription Gets a state value
--- @param self BaseElement The element to get state from
--- @param name string The name of the state
--- @return any value The current state value
function BaseElement:getState(name)
    local main = self:getBaseFrame()
    local states = main.get("states")

    if not states[name] then
        errorManager.error("State '"..name.."' not initialized")
    end

    if states[name].computed then
        return states[name].computeFn(self)
    end
    return states[name].value
end

--- Registers a callback for state changes
--- @shortDescription Watches for state changes
--- @param self BaseElement The element to watch
--- @param stateName string The state to watch
--- @param callback function Called with (element, newValue, oldValue)
--- @return BaseElement self The element instance
function BaseElement:onStateChange(stateName, callback)
    local main = self:getBaseFrame()
    local state = main.get("states")[stateName]
    if not state then
        errorManager.error("Cannot observe state '" .. stateName .. "': State not initialized")
        return self
    end
    local observers = main.get("stateObserver")
    if not observers[stateName] then
        observers[stateName] = {}
    end
    table.insert(observers[stateName], callback)
    return self
end

--- Removes a state change observer
--- @shortDescription Removes a state change observer
--- @param self BaseElement The element to remove observer from
--- @param stateName string The state to remove observer from
--- @param callback function The callback function to remove
--- @return BaseElement self The element instance
function BaseElement:removeStateChange(stateName, callback)
    local main = self:getBaseFrame()
    local observers = main.get("stateObserver")

    if observers[stateName] then
        for i, observer in ipairs(observers[stateName]) do
            if observer == callback then
                table.remove(observers[stateName], i)
                break
            end
        end
    end
    return self
end

function BaseElement:computed(name, func)
    local main = self:getBaseFrame()
    local states = main.get("states")

    if states[name] then
        errorManager.error("Computed state '" .. name .. "' already exists")
        return self
    end

    states[name] = {
        computeFn = func,
        value = func(self),
        computed = true,
    }

    return self
end

--- Binds a property to a state
--- @param self BaseElement The element to bind
--- @param propertyName string The property to bind
--- @param stateName string The state to bind to (optional, uses propertyName if not provided)
--- @return BaseElement self The element instance
function BaseElement:bind(propertyName, stateName)
    stateName = stateName or propertyName
    local main = self:getBaseFrame()
    local internalCall = false

    if self.get(propertyName) ~= nil then
        self.set(propertyName, main:getState(stateName))
    end

    self:onChange(propertyName, function(self, value)
        if internalCall then return end
        internalCall = true
        self:setState(stateName, value)
        internalCall = false
    end)

    self:onStateChange(stateName, function(name, value)
        if internalCall then return end
        internalCall = true
        if self.get(propertyName) ~= nil then
            self.set(propertyName, value)
        end
        internalCall = false
    end)

    return self
end

return {
    BaseElement = BaseElement,
    BaseFrame = BaseFrame
}
 end
project["plugins/benchmark.lua"] = function(...) local log = require("log")


local activeProfiles = setmetatable({}, {__mode = "k"})

local function createProfile()
    return {
        methods = {},
    }
end

local function wrapMethod(element, methodName)
    local originalMethod = element[methodName]

    if not activeProfiles[element] then
        activeProfiles[element] = createProfile()
    end
    if not activeProfiles[element].methods[methodName] then
        activeProfiles[element].methods[methodName] = {
            calls = 0,
            totalTime = 0,
            minTime = math.huge,
            maxTime = 0,
            lastTime = 0,
            startTime = 0,
            path = {},
            methodName = methodName,
            originalMethod = originalMethod
        }
    end

    element[methodName] = function(self, ...)
        self:startProfile(methodName)
        local result = originalMethod(self, ...)
        self:endProfile(methodName)
        return result
    end
end

---@splitClass

---@class BaseElement
local BaseElement = {}

--- Starts profiling a method
--- @shortDescription Starts timing a method call
--- @param methodName string The name of the method to profile
--- @return BaseElement self The element instance
function BaseElement:startProfile(methodName)
    local profile = activeProfiles[self]
    if not profile then 
        profile = createProfile()
        activeProfiles[self] = profile
    end

    if not profile.methods[methodName] then
        profile.methods[methodName] = {
            calls = 0,
            totalTime = 0,
            minTime = math.huge,
            maxTime = 0,
            lastTime = 0,
            startTime = 0,
            path = {},
            methodName = methodName
        }
    end

    local methodProfile = profile.methods[methodName]
    methodProfile.startTime = os.clock() * 1000
    methodProfile.path = {}

    local current = self
    while current do
        table.insert(methodProfile.path, 1, current.get("name") or current.get("id"))
        current = current.parent
    end
    return self
end

--- Ends profiling a method
--- @shortDescription Ends timing a method call and records statistics
--- @param methodName string The name of the method to stop profiling
--- @return BaseElement self The element instance
function BaseElement:endProfile(methodName)
    local profile = activeProfiles[self]
    if not profile or not profile.methods[methodName] then return self end

    local methodProfile = profile.methods[methodName]
    local endTime = os.clock() * 1000
    local duration = endTime - methodProfile.startTime

    methodProfile.calls = methodProfile.calls + 1
    methodProfile.totalTime = methodProfile.totalTime + duration
    methodProfile.minTime = math.min(methodProfile.minTime, duration)
    methodProfile.maxTime = math.max(methodProfile.maxTime, duration)
    methodProfile.lastTime = duration

    return self
end

--- Enables benchmarking for a method
--- @shortDescription Enables performance measurement for a method
--- @param methodName string The name of the method to benchmark
--- @return BaseElement self The element instance
--- @usage element:benchmark("render")
function BaseElement:benchmark(methodName)
    if not self[methodName] then
        log.error("Method " .. methodName .. " does not exist")
        return self
    end

    activeProfiles[self] = createProfile()
    activeProfiles[self].methodName = methodName
    activeProfiles[self].isRunning = true

    wrapMethod(self, methodName)
    return self
end

--- Logs benchmark statistics for a method
--- @shortDescription Logs benchmark statistics for a method
--- @param methodName string The name of the method to log
--- @return BaseElement self The element instance
function BaseElement:logBenchmark(methodName)
    local profile = activeProfiles[self]
    if not profile or not profile.methods[methodName] then return self end

    local stats = profile.methods[methodName]
    if stats then
        local averageTime = stats.calls > 0 and (stats.totalTime / stats.calls) or 0
        log.info(string.format(
            "Benchmark results for %s.%s: " ..
            "Path: %s " ..
            "Calls: %d " ..
            "Average time: %.2fms " ..
            "Min time: %.2fms " ..
            "Max time: %.2fms " ..
            "Last time: %.2fms " ..
            "Total time: %.2fms",
            table.concat(stats.path, "."),
            stats.methodName,
            table.concat(stats.path, "/"),
            stats.calls,
            averageTime,
            stats.minTime ~= math.huge and stats.minTime or 0,
            stats.maxTime,
            stats.lastTime,
            stats.totalTime
        ))
    end
    return self
end

--- Stops benchmarking for a method
--- @shortDescription Disables performance measurement for a method
--- @param methodName string The name of the method to stop benchmarking
--- @return BaseElement self The element instance
function BaseElement:stopBenchmark(methodName)
    local profile = activeProfiles[self]
    if not profile or not profile.methods[methodName] then return self end

    local stats = profile.methods[methodName]
    if stats and stats.originalMethod then
        self[methodName] = stats.originalMethod
    end

    profile.methods[methodName] = nil
    if not next(profile.methods) then
        activeProfiles[self] = nil
    end
    return self
end

--- Gets benchmark statistics for a method
--- @shortDescription Retrieves benchmark statistics for a method
--- @param methodName string The name of the method to get statistics for
--- @return table? stats The benchmark statistics or nil
function BaseElement:getBenchmarkStats(methodName)
    local profile = activeProfiles[self]
    if not profile or not profile.methods[methodName] then return nil end

    local stats = profile.methods[methodName]
    return {
        averageTime = stats.totalTime / stats.calls,
        totalTime = stats.totalTime,
        calls = stats.calls,
        minTime = stats.minTime,
        maxTime = stats.maxTime,
        lastTime = stats.lastTime
    }
end

---@splitClass

---@class Container : VisualElement
local Container = {}

--- Enables benchmarking for a container and all its children
--- @shortDescription Recursively enables benchmarking
--- @param methodName string The method to benchmark
--- @return Container self The container instance
--- @usage container:benchmarkContainer("render")
function Container:benchmarkContainer(methodName)
    self:benchmark(methodName)

    for _, child in pairs(self.get("children")) do
        child:benchmark(methodName)

        if child:isType("Container") then
            child:benchmarkContainer(methodName)
        end
    end
    return self
end

--- Logs benchmark statistics for a container and all its children
--- @shortDescription Recursively logs benchmark statistics
--- @param methodName string The method to log
--- @return Container self The container instance
function Container:logContainerBenchmarks(methodName, depth)
    depth = depth or 0
    local indent = string.rep("  ", depth)
    local childrenTotalTime = 0
    local childrenStats = {}

    for _, child in pairs(self.get("children")) do
        local profile = activeProfiles[child]
        if profile and profile.methods[methodName] then
            local stats = profile.methods[methodName]
            childrenTotalTime = childrenTotalTime + stats.totalTime
            table.insert(childrenStats, {
                element = child,
                type = child.get("type"),
                calls = stats.calls,
                totalTime = stats.totalTime,
                avgTime = stats.totalTime / stats.calls
            })
        end
    end

    local profile = activeProfiles[self]
    if profile and profile.methods[methodName] then
        local stats = profile.methods[methodName]
        local selfTime = stats.totalTime - childrenTotalTime
        local avgSelfTime = selfTime / stats.calls

        log.info(string.format(
            "%sBenchmark %s (%s): " ..
            "%.2fms/call (Self: %.2fms/call) " ..
            "[Total: %dms, Calls: %d]",
            indent,
            self.get("type"),
            methodName,
            stats.totalTime / stats.calls,
            avgSelfTime,
            stats.totalTime,
            stats.calls
        ))

        if #childrenStats > 0 then
            for _, childStat in ipairs(childrenStats) do
                if childStat.element:isType("Container") then
                    childStat.element:logContainerBenchmarks(methodName, depth + 1)
                else
                    log.info(string.format("%s> %s: %.2fms/call [Total: %dms, Calls: %d]",
                        indent .. " ",
                        childStat.type,
                        childStat.avgTime,
                        childStat.totalTime,
                        childStat.calls
                    ))
                end
            end
        end
    end
    
    return self
end

--- Stops benchmarking for a container and all its children
--- @shortDescription Recursively stops benchmarking
--- @param methodName string The method to stop benchmarking
--- @return Container self The container instance
function Container:stopContainerBenchmark(methodName)
    for _, child in pairs(self.get("children")) do
        if child:isType("Container") then
            child:stopContainerBenchmark(methodName)
        else
            child:stopBenchmark(methodName)
        end
    end

    self:stopBenchmark(methodName)
    return self
end

--- This is the benchmark plugin. It provides performance measurement tools for elements and methods,
--- with support for hierarchical profiling and detailed statistics. The plugin is meant to be used for very big projects
--- where performance is critical. It allows you to measure the time taken by specific methods and log the results.
---@class Benchmark
local API = {}

--- Starts a custom benchmark
--- @shortDescription Starts timing a custom operation
--- @param name string The name of the benchmark
--- @param options? table Optional configuration 
function API.start(name, options)
    options = options or {}
    local profile = createProfile()
    profile.name = name
    profile.startTime = os.clock() * 1000
    profile.custom = true
    profile.calls = 0
    profile.totalTime = 0
    profile.minTime = math.huge
    profile.maxTime = 0
    profile.lastTime = 0
    activeProfiles[name] = profile
end

--- Stops a custom benchmark
--- @shortDescription Stops timing and logs results
--- @param name string The name of the benchmark to stop
function API.stop(name)
    local profile = activeProfiles[name]
    if not profile or not profile.custom then return end

    local endTime = os.clock() * 1000
    local duration = endTime - profile.startTime

    profile.calls = profile.calls + 1
    profile.totalTime = profile.totalTime + duration
    profile.minTime = math.min(profile.minTime, duration)
    profile.maxTime = math.max(profile.maxTime, duration)
    profile.lastTime = duration

    log.info(string.format(
        "Custom Benchmark '%s': " ..
        "Calls: %d " ..
        "Average time: %.2fms " ..
        "Min time: %.2fms " ..
        "Max time: %.2fms " ..
        "Last time: %.2fms " ..
        "Total time: %.2fms",
        name,
        profile.calls,
        profile.totalTime / profile.calls,
        profile.minTime,
        profile.maxTime,
        profile.lastTime,
        profile.totalTime
    ))
end

--- Gets statistics for a benchmark
--- @shortDescription Retrieves benchmark statistics
--- @param name string The name of the benchmark
--- @return table? stats The benchmark statistics or nil
function API.getStats(name)
    local profile = activeProfiles[name]
    if not profile then return nil end

    return {
        averageTime = profile.totalTime / profile.calls,
        totalTime = profile.totalTime,
        calls = profile.calls,
        minTime = profile.minTime,
        maxTime = profile.maxTime,
        lastTime = profile.lastTime
    }
end

--- Clears a specific benchmark
--- @shortDescription Removes a benchmark's data
--- @param name string The name of the benchmark to clear
function API.clear(name)
    activeProfiles[name] = nil
end

--- Clears all custom benchmarks
--- @shortDescription Removes all custom benchmark data
function API.clearAll()
    for k,v in pairs(activeProfiles) do
        if v.custom then
            activeProfiles[k] = nil
        end
    end
end

return {
    BaseElement = BaseElement,
    Container = Container,
    API = API
} end
project["elements/BigFont.lua"] = function(...) -------------------------------------------------------------------------------------
-- Wojbies API 5.0 - Bigfont - functions to write bigger font using drawing sybols --
-------------------------------------------------------------------------------------
--   Copyright (c) 2015-2025 Wojbie (wojbie@wojbie.net)
--   Redistribution and use in source and binary forms, with or without modification, are permitted (subject to the limitations in the disclaimer below) provided that the following conditions are met:
--   1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
--   2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
--   3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
--   4. Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.
--   5. The origin of this software must not be misrepresented; you must not claim that you wrote the original software.
--   NO EXPRESS OR IMPLIED LICENSES TO ANY PARTY'S PATENT RIGHTS ARE GRANTED BY THIS LICENSE. THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. YOU ACKNOWLEDGE THAT THIS SOFTWARE IS NOT DESIGNED, LICENSED OR INTENDED FOR USE IN THE DESIGN, CONSTRUCTION, OPERATION OR MAINTENANCE OF ANY NUCLEAR FACILITY.


-- Basalt - Nyorie: Please don't copy paste this code to your projects, this code is slightly changed (to fit the way basalt draws elements), if you want the original code, checkout this:
-- http://www.computercraft.info/forums2/index.php?/topic/25367-bigfont-api-write-bigger-letters-v10/
---@skip
---@class BigFontText
local tHex = require("libraries/colorHex")

local rawFont = {{"\32\32\32\137\156\148\158\159\148\135\135\144\159\139\32\136\157\32\159\139\32\32\143\32\32\143\32\32\32\32\32\32\32\32\147\148\150\131\148\32\32\32\151\140\148\151\140\147", "\32\32\32\149\132\149\136\156\149\144\32\133\139\159\129\143\159\133\143\159\133\138\32\133\138\32\133\32\32\32\32\32\32\150\150\129\137\156\129\32\32\32\133\131\129\133\131\132", "\32\32\32\130\131\32\130\131\32\32\129\32\32\32\32\130\131\32\130\131\32\32\32\32\143\143\143\32\32\32\32\32\32\130\129\32\130\135\32\32\32\32\131\32\32\131\32\131", "\139\144\32\32\143\148\135\130\144\149\32\149\150\151\149\158\140\129\32\32\32\135\130\144\135\130\144\32\149\32\32\139\32\159\148\32\32\32\32\159\32\144\32\148\32\147\131\132", "\159\135\129\131\143\149\143\138\144\138\32\133\130\149\149\137\155\149\159\143\144\147\130\132\32\149\32\147\130\132\131\159\129\139\151\129\148\32\32\139\131\135\133\32\144\130\151\32", "\32\32\32\32\32\32\130\135\32\130\32\129\32\129\129\131\131\32\130\131\129\140\141\132\32\129\32\32\129\32\32\32\32\32\32\32\131\131\129\32\32\32\32\32\32\32\32\32", "\32\32\32\32\149\32\159\154\133\133\133\144\152\141\132\133\151\129\136\153\32\32\154\32\159\134\129\130\137\144\159\32\144\32\148\32\32\32\32\32\32\32\32\32\32\32\151\129", "\32\32\32\32\133\32\32\32\32\145\145\132\141\140\132\151\129\144\150\146\129\32\32\32\138\144\32\32\159\133\136\131\132\131\151\129\32\144\32\131\131\129\32\144\32\151\129\32", "\32\32\32\32\129\32\32\32\32\130\130\32\32\129\32\129\32\129\130\129\129\32\32\32\32\130\129\130\129\32\32\32\32\32\32\32\32\133\32\32\32\32\32\129\32\129\32\32", "\150\156\148\136\149\32\134\131\148\134\131\148\159\134\149\136\140\129\152\131\32\135\131\149\150\131\148\150\131\148\32\148\32\32\148\32\32\152\129\143\143\144\130\155\32\134\131\148", "\157\129\149\32\149\32\152\131\144\144\131\148\141\140\149\144\32\149\151\131\148\32\150\32\150\131\148\130\156\133\32\144\32\32\144\32\130\155\32\143\143\144\32\152\129\32\134\32", "\130\131\32\131\131\129\131\131\129\130\131\32\32\32\129\130\131\32\130\131\32\32\129\32\130\131\32\130\129\32\32\129\32\32\133\32\32\32\129\32\32\32\130\32\32\32\129\32", "\150\140\150\137\140\148\136\140\132\150\131\132\151\131\148\136\147\129\136\147\129\150\156\145\138\143\149\130\151\32\32\32\149\138\152\129\149\32\32\157\152\149\157\144\149\150\131\148", "\149\143\142\149\32\149\149\32\149\149\32\144\149\32\149\149\32\32\149\32\32\149\32\149\149\32\149\32\149\32\144\32\149\149\130\148\149\32\32\149\32\149\149\130\149\149\32\149", "\130\131\129\129\32\129\131\131\32\130\131\32\131\131\32\131\131\129\129\32\32\130\131\32\129\32\129\130\131\32\130\131\32\129\32\129\131\131\129\129\32\129\129\32\129\130\131\32", "\136\140\132\150\131\148\136\140\132\153\140\129\131\151\129\149\32\149\149\32\149\149\32\149\137\152\129\137\152\129\131\156\133\149\131\32\150\32\32\130\148\32\152\137\144\32\32\32", "\149\32\32\149\159\133\149\32\149\144\32\149\32\149\32\149\32\149\150\151\129\138\155\149\150\130\148\32\149\32\152\129\32\149\32\32\32\150\32\32\149\32\32\32\32\32\32\32", "\129\32\32\130\129\129\129\32\129\130\131\32\32\129\32\130\131\32\32\129\32\129\32\129\129\32\129\32\129\32\131\131\129\130\131\32\32\32\129\130\131\32\32\32\32\140\140\132", "\32\154\32\159\143\32\149\143\32\159\143\32\159\144\149\159\143\32\159\137\145\159\143\144\149\143\32\32\145\32\32\32\145\149\32\144\32\149\32\143\159\32\143\143\32\159\143\32", "\32\32\32\152\140\149\151\32\149\149\32\145\149\130\149\157\140\133\32\149\32\154\143\149\151\32\149\32\149\32\144\32\149\149\153\32\32\149\32\149\133\149\149\32\149\149\32\149", "\32\32\32\130\131\129\131\131\32\130\131\32\130\131\129\130\131\129\32\129\32\140\140\129\129\32\129\32\129\32\137\140\129\130\32\129\32\130\32\129\32\129\129\32\129\130\131\32", "\144\143\32\159\144\144\144\143\32\159\143\144\159\138\32\144\32\144\144\32\144\144\32\144\144\32\144\144\32\144\143\143\144\32\150\129\32\149\32\130\150\32\134\137\134\134\131\148", "\136\143\133\154\141\149\151\32\129\137\140\144\32\149\32\149\32\149\154\159\133\149\148\149\157\153\32\154\143\149\159\134\32\130\148\32\32\149\32\32\151\129\32\32\32\32\134\32", "\133\32\32\32\32\133\129\32\32\131\131\32\32\130\32\130\131\129\32\129\32\130\131\129\129\32\129\140\140\129\131\131\129\32\130\129\32\129\32\130\129\32\32\32\32\32\129\32", "\32\32\32\32\149\32\32\149\32\32\32\32\32\32\32\32\149\32\32\149\32\32\32\32\32\32\32\32\149\32\32\149\32\32\32\32\32\32\32\32\149\32\32\149\32\32\32\32", "\32\32\32\32\32\32\32\32\32\32\32\32\32\149\32\32\149\32\32\149\32\32\149\32\32\149\32\32\149\32\32\149\32\32\149\32\32\32\32\32\32\32\32\32\32\32\32\32", "\32\32\32\32\32\32\32\32\32\32\32\32\32\32\32\32\32\32\32\32\32\32\32\32\32\32\32\32\32\32\32\32\32\32\32\32\32\32\32\32\32\32\32\32\32\32\32\32", "\32\32\32\32\149\32\32\149\32\32\32\32\32\32\32\32\149\32\32\149\32\32\32\32\32\32\32\32\149\32\32\149\32\32\32\32\32\32\32\32\149\32\32\149\32\32\32\32", "\32\32\32\32\32\32\32\32\32\32\32\32\32\149\32\32\149\32\32\149\32\32\149\32\32\149\32\32\149\32\32\149\32\32\149\32\32\32\32\32\32\32\32\32\32\32\32\32", "\32\149\32\32\149\32\32\149\32\32\149\32\32\149\32\32\149\32\32\149\32\32\149\32\32\149\32\32\149\32\32\149\32\32\149\32\32\149\32\32\149\32\32\149\32\32\149\32", "\32\32\32\32\145\32\159\139\32\151\131\132\155\143\132\134\135\145\32\149\32\158\140\129\130\130\32\152\147\155\157\134\32\32\144\144\32\32\32\32\32\32\152\131\155\131\131\129", "\32\32\32\32\149\32\149\32\145\148\131\32\149\32\149\140\157\132\32\148\32\137\155\149\32\32\32\149\154\149\137\142\32\153\153\32\131\131\149\131\131\129\149\135\145\32\32\32", "\32\32\32\32\129\32\130\135\32\131\131\129\134\131\132\32\129\32\32\129\32\131\131\32\32\32\32\130\131\129\32\32\32\32\129\129\32\32\32\32\32\32\130\131\129\32\32\32", "\150\150\32\32\148\32\134\32\32\132\32\32\134\32\32\144\32\144\150\151\149\32\32\32\32\32\32\145\32\32\152\140\144\144\144\32\133\151\129\133\151\129\132\151\129\32\145\32", "\130\129\32\131\151\129\141\32\32\142\32\32\32\32\32\149\32\149\130\149\149\32\143\32\32\32\32\142\132\32\154\143\133\157\153\132\151\150\148\151\158\132\151\150\148\144\130\148", "\32\32\32\140\140\132\32\32\32\32\32\32\32\32\32\151\131\32\32\129\129\32\32\32\32\134\32\32\32\32\32\32\32\129\129\32\129\32\129\129\130\129\129\32\129\130\131\32", "\156\143\32\159\141\129\153\140\132\153\137\32\157\141\32\159\142\32\150\151\129\150\131\132\140\143\144\143\141\145\137\140\148\141\141\144\157\142\32\159\140\32\151\134\32\157\141\32", "\157\140\149\157\140\149\157\140\149\157\140\149\157\140\149\157\140\149\151\151\32\154\143\132\157\140\32\157\140\32\157\140\32\157\140\32\32\149\32\32\149\32\32\149\32\32\149\32", "\129\32\129\129\32\129\129\32\129\129\32\129\129\32\129\129\32\129\129\131\129\32\134\32\131\131\129\131\131\129\131\131\129\131\131\129\130\131\32\130\131\32\130\131\32\130\131\32", "\151\131\148\152\137\145\155\140\144\152\142\145\153\140\132\153\137\32\154\142\144\155\159\132\150\156\148\147\32\144\144\130\145\136\137\32\146\130\144\144\130\145\130\136\32\151\140\132", "\151\32\149\151\155\149\149\32\149\149\32\149\149\32\149\149\32\149\149\32\149\152\137\144\157\129\149\149\32\149\149\32\149\149\32\149\149\32\149\130\150\32\32\157\129\149\32\149", "\131\131\32\129\32\129\130\131\32\130\131\32\130\131\32\130\131\32\130\131\32\32\32\32\130\131\32\130\131\32\130\131\32\130\131\32\130\131\32\32\129\32\130\131\32\133\131\32", "\156\143\32\159\141\129\153\140\132\153\137\32\157\141\32\159\142\32\159\159\144\152\140\144\156\143\32\159\141\129\153\140\132\157\141\32\130\145\32\32\147\32\136\153\32\130\146\32", "\152\140\149\152\140\149\152\140\149\152\140\149\152\140\149\152\140\149\149\157\134\154\143\132\157\140\133\157\140\133\157\140\133\157\140\133\32\149\32\32\149\32\32\149\32\32\149\32", "\130\131\129\130\131\129\130\131\129\130\131\129\130\131\129\130\131\129\130\130\131\32\134\32\130\131\129\130\131\129\130\131\129\130\131\129\32\129\32\32\129\32\32\129\32\32\129\32", "\159\134\144\137\137\32\156\143\32\159\141\129\153\140\132\153\137\32\157\141\32\32\132\32\159\143\32\147\32\144\144\130\145\136\137\32\146\130\144\144\130\145\130\138\32\146\130\144", "\149\32\149\149\32\149\149\32\149\149\32\149\149\32\149\149\32\149\149\32\149\131\147\129\138\134\149\149\32\149\149\32\149\149\32\149\149\32\149\154\143\149\32\157\129\154\143\149", "\130\131\32\129\32\129\130\131\32\130\131\32\130\131\32\130\131\32\130\131\32\32\32\32\130\131\32\130\131\129\130\131\129\130\131\129\130\131\129\140\140\129\130\131\32\140\140\129" }, {"000110000110110000110010101000000010000000100101", "000000110110000000000010101000000010000000100101", "000000000000000000000000000000000000000000000000", "100010110100000010000110110000010100000100000110", "000000110000000010110110000110000000000000110000", "000000000000000000000000000000000000000000000000", "000000110110000010000000100000100000000000000010", "000000000110110100010000000010000000000000000100", "000000000000000000000000000000000000000000000000", "010000000000100110000000000000000000000110010000", "000000000000000000000000000010000000010110000000", "000000000000000000000000000000000000000000000000", "011110110000000100100010110000000100000000000000", "000000000000000000000000000000000000000000000000", "000000000000000000000000000000000000000000000000", "110000110110000000000000000000010100100010000000", "000010000000000000110110000000000100010010000000", "000000000000000000000000000000000000000000000000", "010110010110100110110110010000000100000110110110", "000000000000000000000110000000000110000000000000", "000000000000000000000000000000000000000000000000", "010100010110110000000000000000110000000010000000", "110110000000000000110000110110100000000010000000", "000000000000000000000000000000000000000000000000", "000100011111000100011111000100011111000100011111", "000000000000100100100100011011011011111111111111", "000000000000000000000000000000000000000000000000", "000100011111000100011111000100011111000100011111", "000000000000100100100100011011011011111111111111", "100100100100100100100100100100100100100100100100", "000000110100110110000010000011110000000000011000", "000000000100000000000010000011000110000000001000", "000000000000000000000000000000000000000000000000", "010000100100000000000000000100000000010010110000", "000000000000000000000000000000110110110110110000", "000000000000000000000000000000000000000000000000", "110110110110110110000000110110110110110110110110", "000000000000000000000110000000000000000000000000", "000000000000000000000000000000000000000000000000", "000000000000110110000110010000000000000000010010", "000010000000000000000000000000000000000000000000", "000000000000000000000000000000000000000000000000", "110110110110110110110000110110110110000000000000", "000000000000000000000110000000000000000000000000", "000000000000000000000000000000000000000000000000", "110110110110110110110000110000000000000000010000", "000000000000000000000000100000000000000110000110", "000000000000000000000000000000000000000000000000" }}

local fonts = {}
local firstFont = {}
do
    local char = 0
    local height = #rawFont[1]
    local length = #rawFont[1][1]
    for i = 1, height, 3 do
        for j = 1, length, 3 do
            local thisChar = string.char(char)

            local temp = {}
            temp[1] = rawFont[1][i]:sub(j, j + 2)
            temp[2] = rawFont[1][i + 1]:sub(j, j + 2)
            temp[3] = rawFont[1][i + 2]:sub(j, j + 2)

            local temp2 = {}
            temp2[1] = rawFont[2][i]:sub(j, j + 2)
            temp2[2] = rawFont[2][i + 1]:sub(j, j + 2)
            temp2[3] = rawFont[2][i + 2]:sub(j, j + 2)

            firstFont[thisChar] = {temp, temp2}
            char = char + 1
        end
    end
    fonts[1] = firstFont
end

local function generateFontSize(size,yeld)
    local inverter = {["0"] = "1", ["1"] = "0"}
    if size<= #fonts then return true end
    for f = #fonts+1, size do
        local nextFont = {}
        local lastFont = fonts[f - 1]
        for char = 0, 255 do
            local thisChar = string.char(char)

            local temp = {}
            local temp2 = {}

            local templateChar = lastFont[thisChar][1]
            local templateBack = lastFont[thisChar][2]
            for i = 1, #templateChar do
                local line1, line2, line3, back1, back2, back3 = {}, {}, {}, {}, {}, {}
                for j = 1, #templateChar[1] do
                    local currentChar = firstFont[templateChar[i]:sub(j, j)][1]
                    table.insert(line1, currentChar[1])
                    table.insert(line2, currentChar[2])
                    table.insert(line3, currentChar[3])

                    local currentBack = firstFont[templateChar[i]:sub(j, j)][2]
                    if templateBack[i]:sub(j, j) == "1" then
                        table.insert(back1, (currentBack[1]:gsub("[01]", inverter)))
                        table.insert(back2, (currentBack[2]:gsub("[01]", inverter)))
                        table.insert(back3, (currentBack[3]:gsub("[01]", inverter)))
                    else
                        table.insert(back1, currentBack[1])
                        table.insert(back2, currentBack[2])
                        table.insert(back3, currentBack[3])
                    end
                end
                table.insert(temp, table.concat(line1))
                table.insert(temp, table.concat(line2))
                table.insert(temp, table.concat(line3))
                table.insert(temp2, table.concat(back1))
                table.insert(temp2, table.concat(back2))
                table.insert(temp2, table.concat(back3))
            end

            nextFont[thisChar] = {temp, temp2}
            if yeld then yeld = "Font"..f.."Yeld"..char os.queueEvent(yeld) os.pullEvent(yeld) end
        end
        fonts[f] = nextFont
    end
    return true
end

local function makeText(nSize, sString, nFC, nBC, bBlit)
    if not type(sString) == "string" then error("Not a String",3) end --this should never happend with expects in place.
    local cFC = type(nFC) == "string" and nFC:sub(1, 1) or tHex[nFC] or error("Wrong Front Color",3)
    local cBC = type(nBC) == "string" and nBC:sub(1, 1) or tHex[nBC] or error("Wrong Back Color",3)
    if(fonts[nSize]==nil)then generateFontSize(3,false) end
    local font = fonts[nSize] or error("Wrong font size selected",3)
    if sString == "" then return {{""}, {""}, {""}} end

    local input = {}
    for i in sString:gmatch('.') do table.insert(input, i) end

    local tText = {}
    local height = #font[input[1]][1]


    for nLine = 1, height do
        local outLine = {}
        for i = 1, #input do
            outLine[i] = font[input[i]] and font[input[i]][1][nLine] or ""
        end
        tText[nLine] = table.concat(outLine)
    end

    local tFront = {}
    local tBack = {}
    local tFrontSub = {["0"] = cFC, ["1"] = cBC}
    local tBackSub = {["0"] = cBC, ["1"] = cFC}

    for nLine = 1, height do
        local front = {}
        local back = {}
        for i = 1, #input do
            local template = font[input[i]] and font[input[i]][2][nLine] or ""
            front[i] = template:gsub("[01]", bBlit and {["0"] = nFC:sub(i, i), ["1"] = nBC:sub(i, i)} or tFrontSub)
            back[i] = template:gsub("[01]", bBlit and {["0"] = nBC:sub(i, i), ["1"] = nFC:sub(i, i)} or tBackSub)
        end
        tFront[nLine] = table.concat(front)
        tBack[nLine] = table.concat(back)
    end

    return {tText, tFront, tBack}
end

-- This part has nothing to do with Wojbie's BigFont API:

local elementManager = require("elementManager")
local VisualElement = elementManager.getElement("VisualElement")
---@cofnigDescription The BigFont is a text element that displays large text.
---@configDefault false

--- A specialized text element that renders characters in larger sizes using Wojbie's BigFont API. Supports multiple font sizes and custom colors while maintaining the pixel-art style of ComputerCraft. Ideal for headers, titles, and emphasis text.
--- @usage -- Create a large welcome message
--- @usage local main = basalt.getMainFrame()
--- @usage local title = main:addBigFont()
--- @usage     :setPosition(3, 3)
--- @usage     :setFontSize(2)  -- Makes text twice as large
--- @usage     :setText("Welcome!")
--- @usage     :setForeground(colors.yellow)  -- Make text yellow
--- @usage
--- @usage -- For animated text
--- @usage basalt.schedule(function()
--- @usage     while true do
--- @usage         title:setForeground(colors.yellow)
--- @usage         sleep(0.5)
--- @usage         title:setForeground(colors.orange)
--- @usage         sleep(0.5)
--- @usage     end
--- @usage end)
---@class BigFont : VisualElement
local BigFont = setmetatable({}, VisualElement)
BigFont.__index = BigFont

---@property text string BigFont The text string to display in enlarged format
BigFont.defineProperty(BigFont, "text", {default = "BigFont", type = "string", canTriggerRender = true, setter=function(self, value)
    self.bigfontText = makeText(self.get("fontSize"), value, self.get("foreground"), self.get("background"))
    return value
end})
---@property fontSize number 1 Scale factor for text size (1-3, where 1 is 3x3 pixels per character)
BigFont.defineProperty(BigFont, "fontSize", {default = 1, type = "number", canTriggerRender = true, setter=function(self, value)
    self.bigfontText = makeText(value, self.get("text"), self.get("foreground"), self.get("background"))
    return value
end})

--- @shortDescription Creates a new BigFont instance
--- @return table self The created instance
--- @private
function BigFont.new()
    local self = setmetatable({}, BigFont):__init()
    self.class = BigFont
    self.set("width", 16)
    self.set("height", 3)
    self.set("z", 5)
    return self
end

--- @shortDescription Initializes the BigFont instance
--- @param props table The properties to initialize the element with
--- @param basalt table The basalt instance
--- @protected
function BigFont:init(props, basalt)
    VisualElement.init(self, props, basalt)
    self.set("type", "BigFont")
    self:observe("background", function(self, value)
        self.bigfontText = makeText(self.get("fontSize"), self.get("text"), self.get("foreground"), value)
    end)
    self:observe("foreground", function(self, value)
        self.bigfontText = makeText(self.get("fontSize"), self.get("text"), value, self.get("background"))
    end)
end

--- @shortDescription Renders the BigFont
--- @protected
function BigFont:render()
    VisualElement.render(self)
    if(self.bigfontText)then
        local x, y = self.get("x"), self.get("y")
        for i = 1, #self.bigfontText[1] do
            local text = self.bigfontText[1][i]:sub(1, self.get("width"))
            local fg = self.bigfontText[2][i]:sub(1, self.get("width"))
            local bg = self.bigfontText[3][i]:sub(1, self.get("width"))
            self:blit(x, y + i - 1, text, fg, bg)
        end
    end
end

return BigFont end
project["plugins/debug.lua"] = function(...) local log = require("log")
local tHex = require("libraries/colorHex")

local maxLines = 10
local isVisible = false

local DEBUG_LEVELS = {
    ERROR = 1,
    WARN = 2,
    INFO = 3,
    DEBUG = 4
}

local function createDebugger(element)
    local elementInfo = {
        renderCount = 0,
        eventCount = {},
        lastRender = os.epoch("utc"),
        properties = {},
        children = {}
    }

    return {
        trackProperty = function(name, value)
            elementInfo.properties[name] = value
        end,

        trackRender = function()
            elementInfo.renderCount = elementInfo.renderCount + 1
            elementInfo.lastRender = os.epoch("utc")
        end,

        trackEvent = function(event)
            elementInfo.eventCount[event] = (elementInfo.eventCount[event] or 0) + 1
        end,

        dump = function()
            return {
                type = element.get("type"),
                id = element.get("id"),
                stats = elementInfo
            }
        end
    }
end

--- No Description
--- @class BaseElement
local BaseElement = {}

--- Enables debugging for this element
--- @shortDescription Enables debugging for this element
--- @param self BaseElement The element to debug
--- @param level number The debug level
function BaseElement.debug(self, level)
    self._debugger = createDebugger(self)
    self._debugLevel = level or DEBUG_LEVELS.INFO
    return self
end

--- Dumps debug information for this element
--- @shortDescription Dumps debug information
--- @param self BaseElement The element to dump debug info for
function BaseElement.dumpDebug(self)
    if not self._debugger then return end
    return self._debugger.dump()
end

---@class BaseFrame
local BaseFrame = {}

--- Shows the debug log frame
--- @shortDescription Shows the debug log frame
--- @param self BaseFrame The frame to show debug log in
function BaseFrame.openConsole(self)
    if not self._debugFrame then
        local width = self.get("width")
        local height = self.get("height")
        self._debugFrame = self:addFrame("basaltDebugLog")
            :setWidth(width)
            :setHeight(height)
            :listenEvent("mouse_scroll", true)

        self._debugFrame:addButton("basaltDebugLogClose")
        :setWidth(9)
        :setHeight(1)
        :setX(width - 8)
        :setY(height)
        :setText("Close")
        :onClick(function()
            self:closeConsole()
        end)

        self._debugFrame._scrollOffset = 0
        self._debugFrame._processedLogs = {}

        local function wrapText(text, width)
            local lines = {}
            while #text > 0 do
                local line = text:sub(1, width)
                table.insert(lines, line)
                text = text:sub(width + 1)
            end
            return lines
        end

        local function processLogs()
            local processed = {}
            local width = self._debugFrame.get("width")

            for _, entry in ipairs(log._logs) do
                local lines = wrapText(entry.message, width)
                for _, line in ipairs(lines) do
                    table.insert(processed, {
                        text = line,
                        level = entry.level
                    })
                end
            end
            return processed
        end

        local totalLines = #processLogs() - self.get("height")
        self._scrollOffset = totalLines

        local originalRender = self._debugFrame.render
        self._debugFrame.render = function(frame)
            originalRender(frame)
            frame._processedLogs = processLogs()

            local height = frame.get("height")-2
            local totalLines = #frame._processedLogs
            local maxScroll = math.max(0, totalLines - height)
            frame._scrollOffset = math.min(frame._scrollOffset, maxScroll)

            for i = 1, height-2 do
                local logIndex = i + frame._scrollOffset
                local entry = frame._processedLogs[logIndex]

                if entry then
                    local color = entry.level == log.LEVEL.ERROR and colors.red
                        or entry.level == log.LEVEL.WARN and colors.yellow
                        or entry.level == log.LEVEL.DEBUG and colors.lightGray
                        or colors.white

                    frame:textFg(2, i, entry.text, color)
                end
            end
        end

        local baseDispatchEvent = self._debugFrame.dispatchEvent
        self._debugFrame.dispatchEvent = function(self, event, direction, ...)
            if(event == "mouse_scroll") then
                self._scrollOffset = math.max(0, self._scrollOffset + direction)
                self:updateRender()
                return true
            else
                return baseDispatchEvent(self, event, direction, ...)
            end
        end
    end
    self._debugFrame.set("width", self.get("width"))
    self._debugFrame.set("height", self.get("height"))
    self._debugFrame.set("visible", true)
    return self
end

--- Hides the debug log frame
--- @shortDescription Hides the debug log frame
--- @param self BaseFrame The frame to hide debug log for
function BaseFrame.closeConsole(self)
    if self._debugFrame then
        self._debugFrame.set("visible", false)
    end
    return self
end

--- Toggles the debug log frame
--- @shortDescription Toggles the debug log frame
--- @param self BaseFrame The frame to toggle debug log for
function BaseFrame.toggleConsole(self)
    if self._debugFrame and self._debugFrame:getVisible() then
        self:closeConsole()
    else
        self:openConsole()
    end
    return self
end

---@class Container
local Container = {}

--- Enables debugging for this container and all its children
--- @shortDescription Debug container and children
--- @param self Container The container to debug
--- @param level number The debug level
function Container.debugChildren(self, level)
    self:debug(level)
    for _, child in pairs(self.get("children")) do
        if child.debug then
            child:debug(level)
        end
    end
    return self
end

return {
    BaseElement = BaseElement,
    Container = Container,
    BaseFrame = BaseFrame,
}
 end
project["elements/SideNav.lua"] = function(...) local elementManager = require("elementManager")
local VisualElement = require("elements/VisualElement")
local Container = elementManager.getElement("Container")
local tHex = require("libraries/colorHex")
---@configDescription A SideNav element that provides sidebar navigation with multiple content areas.

--- The SideNav is a container that provides sidebar navigation functionality
---@class SideNav : Container
local SideNav = setmetatable({}, Container)
SideNav.__index = SideNav

---@property activeTab number nil The currently active navigation item ID
SideNav.defineProperty(SideNav, "activeTab", {default = nil, type = "number", allowNil = true, canTriggerRender = true, setter = function(self, value)
    return value
end})
---@property sidebarWidth number 12 Width of the sidebar navigation area
SideNav.defineProperty(SideNav, "sidebarWidth", {default = 12, type = "number", canTriggerRender = true})
---@property tabs table {} List of navigation item definitions
SideNav.defineProperty(SideNav, "tabs", {default = {}, type = "table"})

---@property sidebarBackground color gray Background color for the sidebar area
SideNav.defineProperty(SideNav, "sidebarBackground", {default = colors.gray, type = "color", canTriggerRender = true})
---@property activeTabBackground color white Background color for the active navigation item
SideNav.defineProperty(SideNav, "activeTabBackground", {default = colors.white, type = "color", canTriggerRender = true})
---@property activeTabTextColor color black Foreground color for the active navigation item text
SideNav.defineProperty(SideNav, "activeTabTextColor", {default = colors.black, type = "color", canTriggerRender = true})
---@property sidebarScrollOffset number 0 Current scroll offset for navigation items in scrollable mode
SideNav.defineProperty(SideNav, "sidebarScrollOffset", {default = 0, type = "number", canTriggerRender = true})
---@property sidebarPosition string left Position of the sidebar ("left" or "right")
SideNav.defineProperty(SideNav, "sidebarPosition", {default = "left", type = "string", canTriggerRender = true})

SideNav.defineEvent(SideNav, "mouse_click")
SideNav.defineEvent(SideNav, "mouse_up")
SideNav.defineEvent(SideNav, "mouse_scroll")

--- @shortDescription Creates a new SideNav instance
--- @return SideNav self The created instance
--- @private
function SideNav.new()
    local self = setmetatable({}, SideNav):__init()
    self.class = SideNav
    self.set("width", 30)
    self.set("height", 15)
    self.set("z", 10)
    return self
end

--- @shortDescription Initializes the SideNav instance
--- @param props table The properties to initialize the element with
--- @param basalt table The basalt instance
--- @protected
function SideNav:init(props, basalt)
    Container.init(self, props, basalt)
    self.set("type", "SideNav")
end

--- returns a proxy for adding elements to the navigation item
--- @shortDescription Creates a new navigation item handler proxy
--- @param title string The title of the navigation item
--- @return table tabHandler The navigation item handler proxy for adding elements
function SideNav:newTab(title)
    local tabs = self.get("tabs") or {}
    local tabId = #tabs + 1

    table.insert(tabs, {
        id = tabId,
        title = tostring(title or ("Item " .. tabId))
    })

    self.set("tabs", tabs)

    if not self.get("activeTab") then
        self.set("activeTab", tabId)
    end
    self:updateTabVisibility()

    local sideNav = self
    local proxy = {}
    setmetatable(proxy, {
        __index = function(_, key)
            if type(key) == "string" and key:sub(1,3) == "add" and type(sideNav[key]) == "function" then
                return function(_, ...)
                    local el = sideNav[key](sideNav, ...)
                    if el then
                        el._tabId = tabId
                        sideNav.set("childrenSorted", false)
                        sideNav.set("childrenEventsSorted", false)
                        sideNav:updateRender()
                    end
                    return el
                end
            end
            local v = sideNav[key]
            if type(v) == "function" then
                return function(_, ...)
                    return v(sideNav, ...)
                end
            end
            return v
        end
    })

    return proxy
end
SideNav.addTab = SideNav.newTab

--- @shortDescription Sets an element to belong to a specific navigation item
--- @param element table The element to assign to a navigation item
--- @param tabId number The ID of the navigation item to assign the element to
--- @return SideNav self For method chaining
function SideNav:setTab(element, tabId)
    element._tabId = tabId
    self:updateTabVisibility()
    return self
end

--- @shortDescription Adds an element to the SideNav and assigns it to the active navigation item
--- @param elementType string The type of element to add
--- @param tabId number Optional navigation item ID, defaults to active item
--- @return table element The created element
function SideNav:addElement(elementType, tabId)
    local element = Container.addElement(self, elementType)
    local targetTab = tabId or self.get("activeTab")
    if targetTab then
        element._tabId = targetTab
        self:updateTabVisibility()
    end
    return element
end

--- @shortDescription Overrides Container's addChild to assign new elements to item 1 by default
--- @param child table The child element to add
--- @return Container self For method chaining
--- @protected
function SideNav:addChild(child)
    Container.addChild(self, child)
    if not child._tabId then
        local tabs = self.get("tabs") or {}
        if #tabs > 0 then
            child._tabId = 1
            self:updateTabVisibility()
        end
    end
    return self
end

--- @shortDescription Updates visibility of navigation item containers
--- @private
function SideNav:updateTabVisibility()
    self.set("childrenSorted", false)
    self.set("childrenEventsSorted", false)
end

--- @shortDescription Sets the active navigation item
--- @param tabId number The ID of the navigation item to activate
function SideNav:setActiveTab(tabId)
    local oldTab = self.get("activeTab")
    if oldTab == tabId then return self end
    self.set("activeTab", tabId)
    self:updateTabVisibility()
    self:dispatchEvent("tabChanged", tabId, oldTab)
    return self
end

--- @shortDescription Checks if a child should be visible (overrides Container)
--- @param child table The child element to check
--- @return boolean Whether the child should be visible
--- @protected
function SideNav:isChildVisible(child)
    if not Container.isChildVisible(self, child) then
        return false
    end
    if child._tabId then
        return child._tabId == self.get("activeTab")
    end
    return true
end

--- @shortDescription Gets the content area X offset (right of sidebar)
--- @return number xOffset The X offset for content
--- @protected
function SideNav:getContentXOffset()
    local metrics = self:_getSidebarMetrics()
    return metrics.sidebarWidth
end

function SideNav:_getSidebarMetrics()
    local tabs = self.get("tabs") or {}
    local height = self.get("height") or 1
    local sidebarWidth = self.get("sidebarWidth") or 12
    local scrollOffset = self.get("sidebarScrollOffset") or 0
    local sidebarPos = self.get("sidebarPosition") or "left"

    local positions = {}
    local actualY = 1
    local totalHeight = #tabs

    for i, tab in ipairs(tabs) do
        local itemHeight = 1

        local visualY = actualY - scrollOffset
        local startClip = 0
        local endClip = 0

        if visualY < 1 then
            startClip = 1 - visualY
        end

        if visualY + itemHeight - 1 > height then
            endClip = (visualY + itemHeight - 1) - height
        end

        if visualY + itemHeight > 1 and visualY <= height then
            local displayY = math.max(1, visualY)
            local displayHeight = itemHeight - startClip - endClip

            table.insert(positions, {
                id = tab.id, 
                title = tab.title, 
                y1 = displayY,
                y2 = displayY + displayHeight - 1,
                height = itemHeight,
                displayHeight = displayHeight,
                actualY = actualY,
                startClip = startClip,
                endClip = endClip
            })
        end

        actualY = actualY + itemHeight
    end

    return {
        sidebarWidth = sidebarWidth,
        sidebarPosition = sidebarPos,
        positions = positions,
        totalHeight = totalHeight,
        scrollOffset = scrollOffset,
        maxScroll = math.max(0, totalHeight - height)
    }
end

--- @shortDescription Handles mouse click events for navigation item switching
--- @param button number The button that was clicked
--- @param x number The x position of the click (global)
--- @param y number The y position of the click (global)
--- @return boolean Whether the event was handled
--- @protected
function SideNav:mouse_click(button, x, y)
    if not VisualElement.mouse_click(self, button, x, y) then
        return false
    end

    local baseRelX, baseRelY = VisualElement.getRelativePosition(self, x, y)
    local metrics = self:_getSidebarMetrics()
    local width = self.get("width") or 1

    local inSidebar = false
    if metrics.sidebarPosition == "right" then
        inSidebar = baseRelX > (width - metrics.sidebarWidth)
    else
        inSidebar = baseRelX <= metrics.sidebarWidth
    end

    if inSidebar then
        if #metrics.positions == 0 then return true end
        for _, pos in ipairs(metrics.positions) do
            if baseRelY >= pos.y1 and baseRelY <= pos.y2 then
                self:setActiveTab(pos.id)
                self.set("focusedChild", nil)
                return true
            end
        end
        return true
    end
    return Container.mouse_click(self, button, x, y)
end

function SideNav:getRelativePosition(x, y)
    local metrics = self:_getSidebarMetrics()
    local width = self.get("width") or 1

    if x == nil or y == nil then
        return VisualElement.getRelativePosition(self)
    else
        local rx, ry = VisualElement.getRelativePosition(self, x, y)
        if metrics.sidebarPosition == "right" then
            return rx, ry
        else
            return rx - metrics.sidebarWidth, ry
        end
    end
end

function SideNav:multiBlit(x, y, width, height, text, fg, bg)
    local metrics = self:_getSidebarMetrics()
    if metrics.sidebarPosition == "right" then
        return Container.multiBlit(self, x, y, width, height, text, fg, bg)
    else
        return Container.multiBlit(self, (x or 1) + metrics.sidebarWidth, y, width, height, text, fg, bg)
    end
end

function SideNav:textFg(x, y, text, fg)
    local metrics = self:_getSidebarMetrics()
    if metrics.sidebarPosition == "right" then
        return Container.textFg(self, x, y, text, fg)
    else
        return Container.textFg(self, (x or 1) + metrics.sidebarWidth, y, text, fg)
    end
end

function SideNav:textBg(x, y, text, bg)
    local metrics = self:_getSidebarMetrics()
    if metrics.sidebarPosition == "right" then
        return Container.textBg(self, x, y, text, bg)
    else
        return Container.textBg(self, (x or 1) + metrics.sidebarWidth, y, text, bg)
    end
end

function SideNav:drawText(x, y, text)
    local metrics = self:_getSidebarMetrics()
    if metrics.sidebarPosition == "right" then
        return Container.drawText(self, x, y, text)
    else
        return Container.drawText(self, (x or 1) + metrics.sidebarWidth, y, text)
    end
end

function SideNav:drawFg(x, y, fg)
    local metrics = self:_getSidebarMetrics()
    if metrics.sidebarPosition == "right" then
        return Container.drawFg(self, x, y, fg)
    else
        return Container.drawFg(self, (x or 1) + metrics.sidebarWidth, y, fg)
    end
end

function SideNav:drawBg(x, y, bg)
    local metrics = self:_getSidebarMetrics()
    if metrics.sidebarPosition == "right" then
        return Container.drawBg(self, x, y, bg)
    else
        return Container.drawBg(self, (x or 1) + metrics.sidebarWidth, y, bg)
    end
end

function SideNav:blit(x, y, text, fg, bg)
    local metrics = self:_getSidebarMetrics()
    if metrics.sidebarPosition == "right" then
        return Container.blit(self, x, y, text, fg, bg)
    else
        return Container.blit(self, (x or 1) + metrics.sidebarWidth, y, text, fg, bg)
    end
end

function SideNav:mouse_up(button, x, y)
    if not VisualElement.mouse_up(self, button, x, y) then
        return false
    end
    local baseRelX, baseRelY = VisualElement.getRelativePosition(self, x, y)
    local metrics = self:_getSidebarMetrics()
    local width = self.get("width") or 1

    local inSidebar = false
    if metrics.sidebarPosition == "right" then
        inSidebar = baseRelX > (width - metrics.sidebarWidth)
    else
        inSidebar = baseRelX <= metrics.sidebarWidth
    end

    if inSidebar then
        return true
    end
    return Container.mouse_up(self, button, x, y)
end

function SideNav:mouse_release(button, x, y)
    VisualElement.mouse_release(self, button, x, y)
    local baseRelX, baseRelY = VisualElement.getRelativePosition(self, x, y)
    local metrics = self:_getSidebarMetrics()
    local width = self.get("width") or 1

    local inSidebar = false
    if metrics.sidebarPosition == "right" then
        inSidebar = baseRelX > (width - metrics.sidebarWidth)
    else
        inSidebar = baseRelX <= metrics.sidebarWidth
    end

    if inSidebar then
        return
    end
    return Container.mouse_release(self, button, x, y)
end

function SideNav:mouse_move(_, x, y)
    if VisualElement.mouse_move(self, _, x, y) then
        local baseRelX, baseRelY = VisualElement.getRelativePosition(self, x, y)
        local metrics = self:_getSidebarMetrics()
        local width = self.get("width") or 1

        local inSidebar = false
        if metrics.sidebarPosition == "right" then
            inSidebar = baseRelX > (width - metrics.sidebarWidth)
        else
            inSidebar = baseRelX <= metrics.sidebarWidth
        end

        if inSidebar then
            return true
        end
        local args = {self:getRelativePosition(x, y)}
        local success, child = self:callChildrenEvent(true, "mouse_move", table.unpack(args))
        if success then
            return true
        end
    end
    return false
end

function SideNav:mouse_drag(button, x, y)
    if VisualElement.mouse_drag(self, button, x, y) then
        local baseRelX, baseRelY = VisualElement.getRelativePosition(self, x, y)
        local metrics = self:_getSidebarMetrics()
        local width = self.get("width") or 1

        local inSidebar = false
        if metrics.sidebarPosition == "right" then
            inSidebar = baseRelX > (width - metrics.sidebarWidth)
        else
            inSidebar = baseRelX <= metrics.sidebarWidth
        end

        if inSidebar then
            return true
        end
        return Container.mouse_drag(self, button, x, y)
    end
    return false
end

---Scrolls the sidebar up or down
--- @shortDescription Scrolls the sidebar up or down
--- @param direction number -1 to scroll up, 1 to scroll down
--- @return SideNav self For method chaining
function SideNav:scrollSidebar(direction)
    local metrics = self:_getSidebarMetrics()
    local currentOffset = self.get("sidebarScrollOffset") or 0
    local maxScroll = metrics.maxScroll or 0

    local newOffset = currentOffset + (direction * 2)
    newOffset = math.max(0, math.min(maxScroll, newOffset))

    self.set("sidebarScrollOffset", newOffset)
    return self
end

function SideNav:mouse_scroll(direction, x, y)
    if VisualElement.mouse_scroll(self, direction, x, y) then
        local baseRelX, baseRelY = VisualElement.getRelativePosition(self, x, y)
        local metrics = self:_getSidebarMetrics()
        local width = self.get("width") or 1

        local inSidebar = false
        if metrics.sidebarPosition == "right" then
            inSidebar = baseRelX > (width - metrics.sidebarWidth)
        else
            inSidebar = baseRelX <= metrics.sidebarWidth
        end

        if inSidebar then
            self:scrollSidebar(direction)
            return true
        end

        return Container.mouse_scroll(self, direction, x, y)
    end
    return false
end

--- @shortDescription Sets the cursor position; accounts for sidebar offset when delegating to parent
function SideNav:setCursor(x, y, blink, color)
    local metrics = self:_getSidebarMetrics()
    if self.parent then
        local xPos, yPos = self:calculatePosition()
        local targetX, targetY

        if metrics.sidebarPosition == "right" then
            targetX = x + xPos - 1
            targetY = y + yPos - 1
        else
            targetX = x + xPos - 1 + metrics.sidebarWidth
            targetY = y + yPos - 1
        end

        if(targetX < 1) or (targetX > self.parent.get("width")) or
           (targetY < 1) or (targetY > self.parent.get("height")) then
            return self.parent:setCursor(targetX, targetY, false)
        end
        return self.parent:setCursor(targetX, targetY, blink, color)
    end
    return self
end

--- @shortDescription Renders the SideNav (sidebar + children)
--- @protected
function SideNav:render()
    VisualElement.render(self)
    local height = self.get("height")
    local metrics = self:_getSidebarMetrics()
    local sidebarW = metrics.sidebarWidth or 12

    for y = 1, height do
        VisualElement.multiBlit(self, 1, y, sidebarW, 1, " ", tHex[self.get("foreground")], tHex[self.get("sidebarBackground")])
    end

    local activeTab = self.get("activeTab")

    for _, pos in ipairs(metrics.positions) do
        local bgColor = (pos.id == activeTab) and self.get("activeTabBackground") or self.get("sidebarBackground")
        local fgColor = (pos.id == activeTab) and self.get("activeTabTextColor") or self.get("foreground")

        local itemHeight = pos.displayHeight or (pos.y2 - pos.y1 + 1)
        for dy = 0, itemHeight - 1 do
            VisualElement.multiBlit(self, 1, pos.y1 + dy, sidebarW, 1, " ", tHex[self.get("foreground")], tHex[bgColor])
        end

        local displayTitle = pos.title
        if #displayTitle > sidebarW - 2 then
            displayTitle = displayTitle:sub(1, sidebarW - 2)
        end

        VisualElement.textFg(self, 2, pos.y1, displayTitle, fgColor)
    end

    if not self.get("childrenSorted") then
        self:sortChildren()
    end
    if not self.get("childrenEventsSorted") then
        for eventName in pairs(self._values.childrenEvents or {}) do
            self:sortChildrenEvents(eventName)
        end
    end

    for _, child in ipairs(self.get("visibleChildren") or {}) do
        if child == self then error("CIRCULAR REFERENCE DETECTED!") return end
        child:render()
        child:postRender()
    end
end

--- @protected
function SideNav:sortChildrenEvents(eventName)
    local childrenEvents = self._values.childrenEvents and self._values.childrenEvents[eventName]
    if childrenEvents then
        local visibleChildrenEvents = {}
        for _, child in ipairs(childrenEvents) do
            if self:isChildVisible(child) then
                table.insert(visibleChildrenEvents, child)
            end
        end

        for i = 2, #visibleChildrenEvents do
            local current = visibleChildrenEvents[i]
            local currentZ = current.get("z")
            local j = i - 1
            while j > 0 do
                local compare = visibleChildrenEvents[j].get("z")
                if compare > currentZ then
                    visibleChildrenEvents[j + 1] = visibleChildrenEvents[j]
                    j = j - 1
                else
                    break
                end
            end
            visibleChildrenEvents[j + 1] = current
        end

        self._values.visibleChildrenEvents = self._values.visibleChildrenEvents or {}
        self._values.visibleChildrenEvents[eventName] = visibleChildrenEvents
    end
    self.set("childrenEventsSorted", true)
    return self
end

return SideNav end
project["elements/TabControl.lua"] = function(...) local elementManager = require("elementManager")
local VisualElement = require("elements/VisualElement")
local Container = elementManager.getElement("Container")
local tHex = require("libraries/colorHex")
local log = require("log")
---@configDescription A TabControl element that provides tabbed interface with multiple content areas.

--- The TabControl is a container that provides tabbed interface functionality
---@class TabControl : Container
local TabControl = setmetatable({}, Container)
TabControl.__index = TabControl

---@property activeTab number nil The currently active tab ID
TabControl.defineProperty(TabControl, "activeTab", {default = nil, type = "number", allowNil = true, canTriggerRender = true, setter = function(self, value)
    return value
end})
---@property tabHeight number 1 Height of the tab header area
TabControl.defineProperty(TabControl, "tabHeight", {default = 1, type = "number", canTriggerRender = true})
---@property tabs table {} List of tab definitions
TabControl.defineProperty(TabControl, "tabs", {default = {}, type = "table"})

---@property headerBackground color gray Background color for the tab header area
TabControl.defineProperty(TabControl, "headerBackground", {default = colors.gray, type = "color", canTriggerRender = true})
---@property activeTabBackground color white Background color for the active tab
TabControl.defineProperty(TabControl, "activeTabBackground", {default = colors.white, type = "color", canTriggerRender = true})
---@property activeTabTextColor color black Foreground color for the active tab text
TabControl.defineProperty(TabControl, "activeTabTextColor", {default = colors.black, type = "color", canTriggerRender = true})
---@property scrollableTab boolean false Enables scroll mode for tabs if they exceed width
TabControl.defineProperty(TabControl, "scrollableTab", {default = false, type = "boolean", canTriggerRender = true})
---@property tabScrollOffset number 0 Current scroll offset for tabs in scrollable mode
TabControl.defineProperty(TabControl, "tabScrollOffset", {default = 0, type = "number", canTriggerRender = true})

TabControl.defineEvent(TabControl, "mouse_click")
TabControl.defineEvent(TabControl, "mouse_up")
TabControl.defineEvent(TabControl, "mouse_scroll")

--- @shortDescription Creates a new TabControl instance
--- @return TabControl self The created instance
--- @private
function TabControl.new()
    local self = setmetatable({}, TabControl):__init()
    self.class = TabControl
    self.set("width", 20)
    self.set("height", 10)
    self.set("z", 10)
    return self
end

--- @shortDescription Initializes the TabControl instance
--- @param props table The properties to initialize the element with
--- @param basalt table The basalt instance
--- @protected
function TabControl:init(props, basalt)
    Container.init(self, props, basalt)
    self.set("type", "TabControl")
end

--- returns a proxy for adding elements to the tab
--- @shortDescription Creates a new tab handler proxy
--- @param title string The title of the tab
--- @return table tabHandler The tab handler proxy for adding elements to the new tab
function TabControl:newTab(title)
    local tabs = self.get("tabs") or {}
    local tabId = #tabs + 1

    table.insert(tabs, {
        id = tabId,
        title = tostring(title or ("Tab " .. tabId))
    })

    self.set("tabs", tabs)

    if not self.get("activeTab") then
        self.set("activeTab", tabId)
    end
    self:updateTabVisibility()

    local tabControl = self
    local proxy = {}
    setmetatable(proxy, {
        __index = function(_, key)
            if type(key) == "string" and key:sub(1,3) == "add" and type(tabControl[key]) == "function" then
                return function(_, ...)
                    local el = tabControl[key](tabControl, ...)
                    if el then
                        el._tabId = tabId
                        tabControl.set("childrenSorted", false)
                        tabControl.set("childrenEventsSorted", false)
                        tabControl:updateRender()
                    end
                    return el
                end
            end
            local v = tabControl[key]
            if type(v) == "function" then
                return function(_, ...)
                    return v(tabControl, ...)
                end
            end
            return v
        end
    })

    return proxy
end
TabControl.addTab = TabControl.newTab

--- @shortDescription Sets an element to belong to a specific tab
--- @param element table The element to assign to a tab
--- @param tabId number The ID of the tab to assign the element to
--- @return TabControl self For method chaining
function TabControl:setTab(element, tabId)
    element._tabId = tabId
    self:updateTabVisibility()
    return self
end

--- @shortDescription Adds an element to the TabControl and assigns it to the active tab
--- @param elementType string The type of element to add
--- @param tabId number Optional tab ID, defaults to active tab
--- @return table element The created element
function TabControl:addElement(elementType, tabId)
    local element = Container.addElement(self, elementType)
    local targetTab = tabId or self.get("activeTab")
    if targetTab then
        element._tabId = targetTab
    self:updateTabVisibility()
    end
    return element
end

--- @shortDescription Overrides Container's addChild to assign new elements to tab 1 by default
--- @param child table The child element to add
--- @return Container self For method chaining
--- @protected
function TabControl:addChild(child)
    Container.addChild(self, child)
    if not child._tabId then
        local tabs = self.get("tabs") or {}
        if #tabs > 0 then
            child._tabId = 1
            self:updateTabVisibility()
        end
    end
    return self
end

--- @shortDescription Updates visibility of tab containers
--- @private
function TabControl:updateTabVisibility()
    self.set("childrenSorted", false)
    self.set("childrenEventsSorted", false)
end

--- @shortDescription Sets the active tab
--- @param tabId number The ID of the tab to activate
function TabControl:setActiveTab(tabId)
    local oldTab = self.get("activeTab")
    if oldTab == tabId then return self end
    self.set("activeTab", tabId)
    self:updateTabVisibility()
    self:dispatchEvent("tabChanged", tabId, oldTab)
    return self
end

--- @shortDescription Checks if a child should be visible (overrides Container)
--- @param child table The child element to check
--- @return boolean Whether the child should be visible
--- @protected
function TabControl:isChildVisible(child)
    if not Container.isChildVisible(self, child) then
        return false
    end
    if child._tabId then
        return child._tabId == self.get("activeTab")
    end
    return true
end

--- @shortDescription Gets the content area Y offset (below tab headers)
--- @return number yOffset The Y offset for content
--- @protected
function TabControl:getContentYOffset()
    local metrics = self:_getHeaderMetrics()
    return metrics.headerHeight
end

function TabControl:_getHeaderMetrics()
    local tabs = self.get("tabs") or {}
    local width = self.get("width") or 1
    local minTabH = self.get("tabHeight") or 1
    local scrollable = self.get("scrollableTab")

    local positions = {}

    if scrollable then
        local scrollOffset = self.get("tabScrollOffset") or 0
        local actualX = 1
        local totalWidth = 0

        for i, tab in ipairs(tabs) do
            local tabWidth = #tab.title + 2
            if tabWidth > width then
                tabWidth = width
            end

            local visualX = actualX - scrollOffset
            local startClip = 0
            local endClip = 0

            if visualX < 1 then
                startClip = 1 - visualX
            end

            if visualX + tabWidth - 1 > width then
                endClip = (visualX + tabWidth - 1) - width
            end

            if visualX + tabWidth > 1 and visualX <= width then
                local displayX = math.max(1, visualX)
                local displayWidth = tabWidth - startClip - endClip

                table.insert(positions, {
                    id = tab.id, 
                    title = tab.title, 
                    line = 1, 
                    x1 = displayX,
                    x2 = displayX + displayWidth - 1,
                    width = tabWidth,
                    displayWidth = displayWidth,
                    actualX = actualX,
                    startClip = startClip,
                    endClip = endClip
                })
            end

            actualX = actualX + tabWidth
        end

        totalWidth = actualX - 1

        return {
            headerHeight = 1, 
            lines = 1, 
            positions = positions,
            totalWidth = totalWidth,
            scrollOffset = scrollOffset,
            maxScroll = math.max(0, totalWidth - width)
        }
    else
        local line = 1
        local cursorX = 1

        for i, tab in ipairs(tabs) do
            local tabWidth = #tab.title + 2
            if tabWidth > width then
                tabWidth = width
            end
            if cursorX + tabWidth - 1 > width then
                line = line + 1
                cursorX = 1
            end
            table.insert(positions, {
                id = tab.id, 
                title = tab.title, 
                line = line, 
                x1 = cursorX, 
                x2 = cursorX + tabWidth - 1,
                width = tabWidth
            })
            cursorX = cursorX + tabWidth
        end

        local computedLines = line
        local headerHeight = math.max(minTabH, computedLines)
        return {headerHeight = headerHeight, lines = computedLines, positions = positions}
    end
end


--- @shortDescription Handles mouse click events for tab switching
--- @param button number The button that was clicked
--- @param x number The x position of the click (global)
--- @param y number The y position of the click (global)
--- @return boolean Whether the event was handled
--- @protected
function TabControl:mouse_click(button, x, y)
    if not VisualElement.mouse_click(self, button, x, y) then
        return false
    end

    local baseRelX, baseRelY = VisualElement.getRelativePosition(self, x, y)
    local metrics = self:_getHeaderMetrics()
    if baseRelY <= metrics.headerHeight then
        if #metrics.positions == 0 then return true end
        for _, pos in ipairs(metrics.positions) do
            if pos.line == baseRelY and baseRelX >= pos.x1 and baseRelX <= pos.x2 then
                self:setActiveTab(pos.id)
                self.set("focusedChild", nil)
                return true
            end
        end
        return true
    end
    return Container.mouse_click(self, button, x, y)
end

function TabControl:getRelativePosition(x, y)
    local headerH = self:_getHeaderMetrics().headerHeight
    if x == nil or y == nil then
    return VisualElement.getRelativePosition(self)
    else
        local rx, ry = VisualElement.getRelativePosition(self, x, y)
        return rx, ry - headerH
    end
end

function TabControl:multiBlit(x, y, width, height, text, fg, bg)
    local headerH = self:_getHeaderMetrics().headerHeight
    return Container.multiBlit(self, x, (y or 1) + headerH, width, height, text, fg, bg)
end

function TabControl:textFg(x, y, text, fg)
    local headerH = self:_getHeaderMetrics().headerHeight
    return Container.textFg(self, x, (y or 1) + headerH, text, fg)
end

function TabControl:textBg(x, y, text, bg)
    local headerH = self:_getHeaderMetrics().headerHeight
    return Container.textBg(self, x, (y or 1) + headerH, text, bg)
end

function TabControl:drawText(x, y, text)
    local headerH = self:_getHeaderMetrics().headerHeight
    return Container.drawText(self, x, (y or 1) + headerH, text)
end

function TabControl:drawFg(x, y, fg)
    local headerH = self:_getHeaderMetrics().headerHeight
    return Container.drawFg(self, x, (y or 1) + headerH, fg)
end

function TabControl:drawBg(x, y, bg)
    local headerH = self:_getHeaderMetrics().headerHeight
    return Container.drawBg(self, x, (y or 1) + headerH, bg)
end

function TabControl:blit(x, y, text, fg, bg)
    local headerH = self:_getHeaderMetrics().headerHeight
    return Container.blit(self, x, (y or 1) + headerH, text, fg, bg)
end

function TabControl:mouse_up(button, x, y)
    if not VisualElement.mouse_up(self, button, x, y) then
        return false
    end
    local baseRelX, baseRelY = VisualElement.getRelativePosition(self, x, y)
    local headerH = self:_getHeaderMetrics().headerHeight
    if baseRelY <= headerH then
        return true
    end
    return Container.mouse_up(self, button, x, y)
end

function TabControl:mouse_release(button, x, y)
    VisualElement.mouse_release(self, button, x, y)
    local baseRelX, baseRelY = VisualElement.getRelativePosition(self, x, y)
    local headerH = self:_getHeaderMetrics().headerHeight
    if baseRelY <= headerH then
        return
    end
    return Container.mouse_release(self, button, x, y)
end

function TabControl:mouse_move(_, x, y)
    if VisualElement.mouse_move(self, _, x, y) then
        local baseRelX, baseRelY = VisualElement.getRelativePosition(self, x, y)
    local headerH = self:_getHeaderMetrics().headerHeight
    if baseRelY <= headerH then
            return true
        end
        local args = {self:getRelativePosition(x, y)}
        local success, child = self:callChildrenEvent(true, "mouse_move", table.unpack(args))
        if success then
            return true
        end
    end
    return false
end

function TabControl:mouse_drag(button, x, y)
    if VisualElement.mouse_drag(self, button, x, y) then
        local baseRelX, baseRelY = VisualElement.getRelativePosition(self, x, y)
    local headerH = self:_getHeaderMetrics().headerHeight
    if baseRelY <= headerH then
            return true
        end
        return Container.mouse_drag(self, button, x, y)
    end
    return false
end

---Scrolls the tab header left or right if scrollableTab is enabled
--- @shortDescription Scrolls the tab header left or right if scrollableTab is enabled
--- @param direction number -1 to scroll left, 1 to scroll right
--- @return TabControl self For method chaining
function TabControl:scrollTabs(direction)
    if not self.get("scrollableTab") then return self end

    local metrics = self:_getHeaderMetrics()
    local currentOffset = self.get("tabScrollOffset") or 0
    local maxScroll = metrics.maxScroll or 0

    local newOffset = currentOffset + (direction * 5)
    newOffset = math.max(0, math.min(maxScroll, newOffset))

    self.set("tabScrollOffset", newOffset)
    return self
end

function TabControl:mouse_scroll(direction, x, y)
    if VisualElement.mouse_scroll(self, direction, x, y) then
        local headerH = self:_getHeaderMetrics().headerHeight

        if self.get("scrollableTab") and y == self.get("y") then
            self:scrollTabs(direction)
            return true
        end

        return Container.mouse_scroll(self, direction, x, y)
    end
    return false
end


--- @shortDescription Sets the cursor position; accounts for tab header offset when delegating to parent
function TabControl:setCursor(x, y, blink, color)
    local tabH = self:_getHeaderMetrics().headerHeight
    if self.parent then
        local xPos, yPos = self:calculatePosition()
        local targetX = x + xPos - 1
        local targetY = y + yPos - 1 + tabH

        if(targetX < 1) or (targetX > self.parent.get("width")) or
           (targetY < 1) or (targetY > self.parent.get("height")) then
            return self.parent:setCursor(targetX, targetY, false)
        end
        return self.parent:setCursor(targetX, targetY, blink, color)
    end
    return self
end

--- @shortDescription Renders the TabControl (header + children)
--- @protected
function TabControl:render()
    VisualElement.render(self)
    local width = self.get("width")
    local metrics = self:_getHeaderMetrics()
    local headerH = metrics.headerHeight or 1

    VisualElement.multiBlit(self, 1, 1, width, headerH, " ", tHex[self.get("foreground")], tHex[self.get("headerBackground")])
    local activeTab = self.get("activeTab")

    for _, pos in ipairs(metrics.positions) do
        local bgColor = (pos.id == activeTab) and self.get("activeTabBackground") or self.get("headerBackground")
        local fgColor = (pos.id == activeTab) and self.get("activeTabTextColor") or self.get("foreground")

        VisualElement.multiBlit(self, pos.x1, pos.line, pos.displayWidth or (pos.x2 - pos.x1 + 1), 1, " ", tHex[self.get("foreground")], tHex[bgColor])

        local displayTitle = pos.title
        local textStartInTitle = 1 + (pos.startClip or 0)
        local textLength = #pos.title - (pos.startClip or 0) - (pos.endClip or 0)

        if textLength > 0 then
            displayTitle = pos.title:sub(textStartInTitle, textStartInTitle + textLength - 1)
            local textX = pos.x1
            if (pos.startClip or 0) == 0 then
                textX = textX + 1
            end
            VisualElement.textFg(self, textX, pos.line, displayTitle, fgColor)
        end
    end

    if not self.get("childrenSorted") then
        self:sortChildren()
    end
    if not self.get("childrenEventsSorted") then
        for eventName in pairs(self._values.childrenEvents or {}) do
            self:sortChildrenEvents(eventName)
        end
    end

    for _, child in ipairs(self.get("visibleChildren") or {}) do
        if child == self then error("CIRCULAR REFERENCE DETECTED!") return end
        child:render()
        child:postRender()
    end
end

--- @protected
function TabControl:sortChildrenEvents(eventName)
    local childrenEvents = self._values.childrenEvents and self._values.childrenEvents[eventName]
    if childrenEvents then
        local visibleChildrenEvents = {}
        for _, child in ipairs(childrenEvents) do
            if self:isChildVisible(child) then
                table.insert(visibleChildrenEvents, child)
            end
        end

        for i = 2, #visibleChildrenEvents do
            local current = visibleChildrenEvents[i]
            local currentZ = current.get("z")
            local j = i - 1
            while j > 0 do
                local compare = visibleChildrenEvents[j].get("z")
                if compare > currentZ then
                    visibleChildrenEvents[j + 1] = visibleChildrenEvents[j]
                    j = j - 1
                else
                    break
                end
            end
            visibleChildrenEvents[j + 1] = current
        end

        self._values.visibleChildrenEvents = self._values.visibleChildrenEvents or {}
        self._values.visibleChildrenEvents[eventName] = visibleChildrenEvents
    end
    self.set("childrenEventsSorted", true)
    return self
end

return TabControl end
project["elements/Menu.lua"] = function(...) local VisualElement = require("elements/VisualElement")
local List = require("elements/List")
local tHex = require("libraries/colorHex")
---@configDescription A horizontal menu bar with selectable items.

--- This is the menu class. It provides a horizontal menu bar with selectable items.
--- Menu items are displayed in a single row and can have custom colors and callbacks.
---@class Menu : List
local Menu = setmetatable({}, List)
Menu.__index = Menu

---@property separatorColor color gray The color used for separator items in the menu
Menu.defineProperty(Menu, "separatorColor", {default = colors.gray, type = "color"})

--- Creates a new Menu instance
--- @shortDescription Creates a new Menu instance
--- @return Menu self The newly created Menu instance
--- @private
function Menu.new()
    local self = setmetatable({}, Menu):__init()
    self.class = Menu
    self.set("width", 30)
    self.set("height", 1)
    self.set("background", colors.gray)
    return self
end

--- @shortDescription Initializes the Menu instance
--- @param props table The properties to initialize the element with
--- @param basalt table The basalt instance
--- @return Menu self The initialized instance
--- @protected
function Menu:init(props, basalt)
    List.init(self, props, basalt)
    self.set("type", "Menu")
    return self
end

--- Sets the menu items
--- @shortDescription Sets the menu items and calculates total width
--- @param items table[] List of items with {text, separator, callback, foreground, background} properties
--- @return Menu self The Menu instance
--- @usage menu:setItems({{text="File"}, {separator=true}, {text="Edit"}})
function Menu:setItems(items)
    local listItems = {}
    local totalWidth = 0
    for _, item in ipairs(items) do
        if item.separator then
            table.insert(listItems, {text = item.text or "|", selectable = false})
            totalWidth = totalWidth + 1
        else
            local text = " " .. item.text .. " "
            item.text = text
            table.insert(listItems, item)
            totalWidth = totalWidth + #text
        end
    end
    self.set("width", totalWidth)
    return List.setItems(self, listItems)
end

--- @shortDescription Renders the menu horizontally with proper spacing and colors
--- @protected
function Menu:render()
    VisualElement.render(self)
    local currentX = 1

    for i, item in ipairs(self.get("items")) do
        if type(item) == "string" then
            item = {text = " "..item.." "}
            self.get("items")[i] = item
        end

        local isSelected = item.selected
        local fg = item.selectable == false and self.get("separatorColor") or
            (isSelected and (item.selectedForeground or self.get("selectedForeground")) or
            (item.foreground or self.get("foreground")))

        local bg = isSelected and
            (item.selectedBackground or self.get("selectedBackground")) or
            (item.background or self.get("background"))

        self:blit(currentX, 1, item.text,
            string.rep(tHex[fg], #item.text),
            string.rep(tHex[bg], #item.text))

        currentX = currentX + #item.text
    end
end

--- @shortDescription Handles mouse click events and item selection
--- @param button number The button that was clicked
--- @param x number The x position of the click
--- @param y number The y position of the click
--- @return boolean Whether the event was handled
--- @protected
function Menu:mouse_click(button, x, y)
    if not VisualElement.mouse_click(self, button, x, y) then return false end
    if(self.get("selectable") == false) then return false end
    local relX = select(1, self:getRelativePosition(x, y))
    local currentX = 1

    for i, item in ipairs(self.get("items")) do
        if relX >= currentX and relX < currentX + #item.text then
            if item.selectable ~= false then
                if type(item) == "string" then
                    item = {text = item}
                    self.get("items")[i] = item
                end

                if not self.get("multiSelection") then
                    for _, otherItem in ipairs(self.get("items")) do
                        if type(otherItem) == "table" then
                            otherItem.selected = false
                        end
                    end
                end

                item.selected = not item.selected

                if item.callback then
                    item.callback(self)
                end
                self:fireEvent("select", i, item)
            end
            return true
        end
        currentX = currentX + #item.text
    end
    return false
end

return Menu
 end
project["plugins/reactive.lua"] = function(...) local errorManager = require("errorManager")
local PropertySystem = require("propertySystem")

local protectedNames = {
    colors = true,
    math = true,
    clamp = true,
    round = true
}

local mathEnv = {
    clamp = function(val, min, max)
        return math.min(math.max(val, min), max)
    end,
    round = function(val)
        return math.floor(val + 0.5)
    end,
    floor = math.floor,
    ceil = math.ceil,
    abs = math.abs
}

local function analyzeDependencies(expr)
    return {
        parent = expr:find("parent%."),
        self = expr:find("self%."),
        other = expr:find("[^(parent)][^(self)]%.")
    }
end

local function parseExpression(expr, element, propName)
    local deps = analyzeDependencies(expr)
    
    if deps.parent and not element.parent then
        errorManager.header = "Reactive evaluation error"
        errorManager.error("Expression uses parent but no parent available")
        return function() return nil end
    end
    
    expr = expr:gsub("^{(.+)}$", "%1")

    expr = expr:gsub("([%w_]+)%$([%w_]+)", function(obj, prop)
        if obj == "self" then
            return string.format('__getState("%s")', prop)
        elseif obj == "parent" then
            return string.format('__getParentState("%s")', prop)
        else
            return string.format('__getElementState("%s", "%s")', obj, prop)
        end
    end)

    expr = expr:gsub("([%w_]+)%.([%w_]+)", function(obj, prop)
        if protectedNames[obj] then 
            return obj.."."..prop
        end
        if tonumber(obj) then
            return obj.."."..prop
        end
        return string.format('__getProperty("%s", "%s")', obj, prop)
    end)

    local env = setmetatable({
        colors = colors,
        math = math,
        tostring = tostring,
        tonumber = tonumber,
        __getState = function(prop)
            return element:getState(prop)
        end,
        __getParentState = function(prop)
            return element.parent:getState(prop)
        end,
        __getElementState = function(objName, prop)
            if tonumber(objName) then
                return nil
            end
            local target = element:getBaseFrame():getChild(objName)
            if not target then
                errorManager.header = "Reactive evaluation error"
                errorManager.error("Could not find element: " .. objName)
                return nil
            end
            return target:getState(prop).value
        end,
        __getProperty = function(objName, propName)
            if tonumber(objName) then
                return nil
            end
            if objName == "self" then
                return element.get(propName)
            elseif objName == "parent" then
                return element.parent.get(propName)
            else
                local target = element.parent:getChild(objName)
                if not target then
                    errorManager.header = "Reactive evaluation error"
                    errorManager.error("Could not find element: " .. objName)
                    return nil
                end

                return target.get(propName)
            end
        end
    }, { __index = mathEnv })

    if(element._properties[propName].type == "string")then
        expr = "tostring(" .. expr .. ")"
    elseif(element._properties[propName].type == "number")then
        expr = "tonumber(" .. expr .. ")"
    end

    local func, err = load("return "..expr, "reactive", "t", env)
    if not func then
        errorManager.header = "Reactive evaluation error"
        errorManager.error("Invalid expression: " .. err)
        return function() return nil end
    end

    return func
end

local function validateReferences(expr, element)
    for ref in expr:gmatch("([%w_]+)%.") do
        if not protectedNames[ref] then
            if ref == "self" then
            elseif ref == "parent" then
                if not element.parent then
                    errorManager.header = "Reactive evaluation error"
                    errorManager.error("No parent element available")
                    return false
                end
            else
                if(tonumber(ref) == nil)then
                    local target = element.parent:getChild(ref)
                    if not target then
                        errorManager.header = "Reactive evaluation error"
                        errorManager.error("Referenced element not found: " .. ref)
                        return false
                    end
                end
            end
        end
    end
    return true
end

local functionCache = setmetatable({}, {__mode = "k"})

local observerCache = setmetatable({}, {
    __mode = "k",
    __index = function(t, k)
        t[k] = {}
        return t[k]
    end
})

local function setupObservers(element, expr, propertyName)
    local deps = analyzeDependencies(expr)
    
    if observerCache[element][propertyName] then
        for _, observer in ipairs(observerCache[element][propertyName]) do
            observer.target:removeObserver(observer.property, observer.callback)
        end
    end

    local observers = {}
    for ref, prop in expr:gmatch("([%w_]+)%.([%w_]+)") do
        if not protectedNames[ref] then
            local target
            if ref == "self" and deps.self then
                target = element
            elseif ref == "parent" and deps.parent then
                target = element.parent
            elseif deps.other then
                target = element:getBaseFrame():getChild(ref)
            end

            if target then
                local observer = {
                    target = target,
                    property = prop,
                    callback = function()
                        element:updateRender()
                    end
                }
                target:observe(prop, observer.callback)
                table.insert(observers, observer)
            end
        end
    end

    observerCache[element][propertyName] = observers
end

PropertySystem.addSetterHook(function(element, propertyName, value, config)
    if type(value) == "string" and value:match("^{.+}$") then
        local expr = value:gsub("^{(.+)}$", "%1")
        local deps = analyzeDependencies(expr)
        
        if deps.parent and not element.parent then
            return config.default
        end
        if not validateReferences(expr, element) then
            return config.default
        end

        setupObservers(element, expr, propertyName)

        if not functionCache[element] then
            functionCache[element] = {}
        end
        if not functionCache[element][value] then
            local parsedFunc = parseExpression(value, element, propertyName)
            functionCache[element][value] = parsedFunc
        end

        return function(self)
            if element._destroyed or (deps.parent and not element.parent) then
                return config.default
            end

            local success, result = pcall(functionCache[element][value])
            if not success then
                if result and result:match("attempt to index.-nil value") then
                    return config.default
                end
                errorManager.header = "Reactive evaluation error"
                if type(result) == "string" then
                    errorManager.error("Error evaluating expression: " .. result)
                else
                    errorManager.error("Error evaluating expression")
                end
                return config.default
            end
            return result
        end
    end
end)

--- This module provides reactive functionality for elements, it adds no new functionality for elements. 
--- It is used to evaluate expressions in property values and update the element when the expression changes.
--- @usage local button = main:addButton({text="Exit"})
--- @usage button:setX("{parent.x - 12}")
--- @usage button:setBackground("{self.clicked and colors.red or colors.green}")
--- @usage button:setWidth("{#self.text + 2}")
---@class Reactive
local BaseElement = {}

BaseElement.hooks = {
    destroy = function(self)
        if observerCache[self] then
            for propName, observers in pairs(observerCache[self]) do
                for _, observer in ipairs(observers) do
                    observer.target:removeObserver(observer.property, observer.callback)
                end
            end
            observerCache[self] = nil
            functionCache[self] = nil
        end
    end
}

return {
    BaseElement = BaseElement
}
 end
project["plugins/animation.lua"] = function(...) local registeredAnimations = {}
local easings = {
    linear = function(progress)
        return progress
    end,

    easeInQuad = function(progress)
        return progress * progress
    end,

    easeOutQuad = function(progress)
        return 1 - (1 - progress) * (1 - progress)
    end,

    easeInOutQuad = function(progress)
        if progress < 0.5 then
            return 2 * progress * progress
        end
        return 1 - (-2 * progress + 2)^2 / 2
    end
}

---@splitClass

--- This is the AnimationInstance class. It represents a single animation instance
---@class AnimationInstance
---@field element VisualElement The element being animated
---@field type string The type of animation
---@field args table The animation arguments
---@field duration number The duration in seconds
---@field startTime number The animation start time
---@field isPaused boolean Whether the animation is paused
---@field handlers table The animation handlers
---@field easing string The easing function name
local AnimationInstance = {}
AnimationInstance.__index = AnimationInstance

--- Creates a new AnimationInstance
--- @shortDescription Creates a new animation instance
--- @param element VisualElement The element to animate
--- @param animType string The type of animation
--- @param args table The animation arguments
--- @param duration number Duration in seconds
--- @param easing string The easing function name
--- @return AnimationInstance The new animation instance
function AnimationInstance.new(element, animType, args, duration, easing)
    local self = setmetatable({}, AnimationInstance)
    self.element = element
    self.type = animType
    self.args = args
    self.duration = duration or 1
    self.startTime = 0
    self.isPaused = false
    self.handlers = registeredAnimations[animType]
    self.easing = easing
    return self
end

--- Starts the animation
--- @shortDescription Starts the animation
--- @return AnimationInstance self The animation instance
function AnimationInstance:start()
    self.startTime = os.epoch("local") / 1000
    if self.handlers.start then
        self.handlers.start(self)
    end
    return self
end

--- Updates the animation
--- @shortDescription Updates the animation
--- @param elapsed number The elapsed time in seconds
--- @return boolean Whether the animation is finished
function AnimationInstance:update(elapsed)
    local rawProgress = math.min(1, elapsed / self.duration)
    local progress = easings[self.easing](rawProgress)
    return self.handlers.update(self, progress)
end

--- Gets called when the animation is completed
--- @shortDescription Called when the animation is completed
function AnimationInstance:complete()
    if self.handlers.complete then
        self.handlers.complete(self)
    end
end

--- This is the animation plugin. It provides a animation system for visual elements
--- with support for sequences, easing functions, and multiple animation types.
---@class Animation
local Animation = {}
Animation.__index = Animation

--- Registers a new animation type
--- @shortDescription Registers a custom animation type
--- @param name string The name of the animation
--- @param handlers table Table containing start, update and complete handlers
--- @usage Animation.registerAnimation("fade", {start=function(anim) end, update=function(anim,progress) end})
function Animation.registerAnimation(name, handlers)
    registeredAnimations[name] = handlers

    Animation[name] = function(self, ...)
        local args = {...}
        local easing = "linear"
        if(type(args[#args]) == "string") then
            easing = table.remove(args, #args)
        end
        local duration = table.remove(args, #args)
        return self:addAnimation(name, args, duration, easing)
    end
end

--- Registers a new easing function
--- @shortDescription Adds a custom easing function
--- @param name string The name of the easing function
--- @param func function The easing function (takes progress 0-1, returns modified progress)
function Animation.registerEasing(name, func)
    easings[name] = func
end

--- Creates a new Animation
--- @shortDescription Creates a new animation
--- @param element VisualElement The element to animate
--- @return Animation The new animation
function Animation.new(element)
    local self = {}
    self.element = element
    self.sequences = {{}}
    self.sequenceCallbacks = {}
    self.currentSequence = 1
    self.timer = nil
    setmetatable(self, Animation)
    return self
end

--- Creates a new sequence
--- @shortDescription Creates a new sequence
--- @return Animation self The animation instance
function Animation:sequence()
    table.insert(self.sequences, {})
    self.currentSequence = #self.sequences
    self.sequenceCallbacks[self.currentSequence] = {
        start = nil,
        update = nil,
        complete = nil
    }
    return self
end

--- Registers a callback for the start event
--- @shortDescription Registers a callback for the start event
--- @param callback function The callback function to register
function Animation:onStart(callback)
    if not self.sequenceCallbacks[self.currentSequence] then
        self.sequenceCallbacks[self.currentSequence] = {}
    end
    self.sequenceCallbacks[self.currentSequence].start = callback
    return self
end

--- Registers a callback for the update event
--- @shortDescription Registers a callback for the update event
--- @param callback function The callback function to register
--- @return Animation self The animation instance
function Animation:onUpdate(callback)
    if not self.sequenceCallbacks[self.currentSequence] then
        self.sequenceCallbacks[self.currentSequence] = {}
    end
    self.sequenceCallbacks[self.currentSequence].update = callback
    return self
end

--- Registers a callback for the complete event
--- @shortDescription Registers a callback for the complete event
--- @param callback function The callback function to register
--- @return Animation self The animation instance
function Animation:onComplete(callback)
    if not self.sequenceCallbacks[self.currentSequence] then
        self.sequenceCallbacks[self.currentSequence] = {}
    end
    self.sequenceCallbacks[self.currentSequence].complete = callback
    return self
end

--- Adds a new animation to the sequence
--- @shortDescription Adds a new animation to the sequence
--- @param type string The type of animation
--- @param args table The animation arguments
--- @param duration number The duration in seconds
--- @param easing string The easing function name
function Animation:addAnimation(type, args, duration, easing)
    local anim = AnimationInstance.new(self.element, type, args, duration, easing)
    table.insert(self.sequences[self.currentSequence], anim)
    return self
end

--- Starts the animation
--- @shortDescription Starts the animation
--- @return Animation self The animation instance
function Animation:start()
    self.currentSequence = 1
    self.timer = nil
    if(self.sequenceCallbacks[self.currentSequence])then
        if(self.sequenceCallbacks[self.currentSequence].start) then
            self.sequenceCallbacks[self.currentSequence].start(self.element)
        end
    end
    if #self.sequences[self.currentSequence] > 0 then
        self.timer = os.startTimer(0.05)
        for _, anim in ipairs(self.sequences[self.currentSequence]) do
            anim:start()
        end
    end
    return self
end

--- The event handler for the animation (listens to timer events)
--- @shortDescription The event handler for the animation
--- @param event string The event type
--- @param timerId number The timer ID
function Animation:event(event, timerId)
    if event == "timer" and timerId == self.timer then
        local currentTime = os.epoch("local") / 1000
        local sequenceFinished = true
        local remaining = {}
        local callbacks = self.sequenceCallbacks[self.currentSequence]

        for _, anim in ipairs(self.sequences[self.currentSequence]) do
            local elapsed = currentTime - anim.startTime
            local progress = elapsed / anim.duration
            local finished = anim:update(elapsed)

            if callbacks and callbacks.update then
                callbacks.update(self.element, progress)
            end

            if not finished then
                table.insert(remaining, anim)
                sequenceFinished = false
            else
                anim:complete()
            end
        end

        if sequenceFinished then
            if callbacks and callbacks.complete then
                callbacks.complete(self.element)
            end

            if self.currentSequence < #self.sequences then
                self.currentSequence = self.currentSequence + 1
                remaining = {}

                local nextCallbacks = self.sequenceCallbacks[self.currentSequence]
                if nextCallbacks and nextCallbacks.start then
                    nextCallbacks.start(self.element)
                end

                for _, anim in ipairs(self.sequences[self.currentSequence]) do
                    anim:start()
                    table.insert(remaining, anim)
                end
            end
        end

        if #remaining > 0 then
            self.timer = os.startTimer(0.05)
        end
        return true
    end
end

--- Stops the animation immediately: cancels timers, completes running anim instances and clears the element property
--- @shortDescription Stops the animation
function Animation:stop()
    if self.timer then
        pcall(os.cancelTimer, self.timer)
        self.timer = nil
    end

    for _, seq in ipairs(self.sequences) do
        for _, anim in ipairs(seq) do
            pcall(function()
                if anim and anim.complete then anim:complete() end
            end)
        end
    end

    if self.element and type(self.element.set) == "function" then
        pcall(function() self.element.set("animation", nil) end)
    end
end

Animation.registerAnimation("move", {
    start = function(anim)
        anim.startX = anim.element.get("x")
        anim.startY = anim.element.get("y")
    end,

    update = function(anim, progress)
        local x = anim.startX + (anim.args[1] - anim.startX) * progress
        local y = anim.startY + (anim.args[2] - anim.startY) * progress
        anim.element.set("x", math.floor(x))
        anim.element.set("y", math.floor(y))
        return progress >= 1
    end,

    complete = function(anim)
        anim.element.set("x", anim.args[1])
        anim.element.set("y", anim.args[2])
    end
})

Animation.registerAnimation("resize", {
    start = function(anim)
        anim.startW = anim.element.get("width")
        anim.startH = anim.element.get("height")
    end,

    update = function(anim, progress)
        local w = anim.startW + (anim.args[1] - anim.startW) * progress
        local h = anim.startH + (anim.args[2] - anim.startH) * progress
        anim.element.set("width", math.floor(w))
        anim.element.set("height", math.floor(h))
        return progress >= 1
    end,

    complete = function(anim)
        anim.element.set("width", anim.args[1])
        anim.element.set("height", anim.args[2])
    end
})

Animation.registerAnimation("moveOffset", {
    start = function(anim)
        anim.startX = anim.element.get("offsetX")
        anim.startY = anim.element.get("offsetY")
    end,

    update = function(anim, progress)
        local x = anim.startX + (anim.args[1] - anim.startX) * progress
        local y = anim.startY + (anim.args[2] - anim.startY) * progress
        anim.element.set("offsetX", math.floor(x))
        anim.element.set("offsetY", math.floor(y))
        return progress >= 1
    end,

    complete = function(anim)
        anim.element.set("offsetX", anim.args[1])
        anim.element.set("offsetY", anim.args[2])
    end
})

Animation.registerAnimation("number", {
    start = function(anim)
        anim.startValue = anim.element.get(anim.args[1])
        anim.targetValue = anim.args[2]
    end,

    update = function(anim, progress)
        local value = anim.startValue + (anim.targetValue - anim.startValue) * progress
        anim.element.set(anim.args[1], math.floor(value))
        return progress >= 1
    end,

    complete = function(anim)
        anim.element.set(anim.args[1], anim.targetValue)
    end
})

Animation.registerAnimation("entries", {
    start = function(anim)
        anim.startColor = anim.element.get(anim.args[1])
        anim.colorList = anim.args[2]
    end,

    update = function(anim, progress)
        local list = anim.colorList
        local index = math.floor(#list * progress) + 1
        if index > #list then
            index = #list
        end
        anim.element.set(anim.args[1], list[index])

    end,

    complete = function(anim)
        anim.element.set(anim.args[1], anim.colorList[#anim.colorList])
    end
})

Animation.registerAnimation("morphText", {
    start = function(anim)
        local startText = anim.element.get(anim.args[1])
        local targetText = anim.args[2]
        local maxLength = math.max(#startText, #targetText)
        local startSpace = string.rep(" ", math.floor(maxLength - #startText)/2)
        anim.startText = startSpace .. startText .. startSpace
        anim.targetText = targetText .. string.rep(" ", maxLength - #targetText)
        anim.length = maxLength
    end,

    update = function(anim, progress)
        local currentText = ""

        for i = 1, anim.length do
            local startChar = anim.startText:sub(i,i)
            local targetChar = anim.targetText:sub(i,i)

            if progress < 0.5 then
                currentText = currentText .. (math.random() > progress*2 and startChar or " ")
            else
                currentText = currentText .. (math.random() > (progress-0.5)*2 and " " or targetChar)
            end
        end

        anim.element.set(anim.args[1], currentText)
        return progress >= 1
    end,

    complete = function(anim)
        anim.element.set(anim.args[1], anim.targetText:gsub("%s+$", ""))  -- Entferne trailing spaces
    end
})

Animation.registerAnimation("typewrite", {
    start = function(anim)
        anim.targetText = anim.args[2]
        anim.element.set(anim.args[1], "")
    end,

    update = function(anim, progress)
        local length = math.floor(#anim.targetText * progress)
        anim.element.set(anim.args[1], anim.targetText:sub(1, length))
        return progress >= 1
    end
})

Animation.registerAnimation("fadeText", {
    start = function(anim)
        anim.chars = {}
        for i=1, #anim.args[2] do
            anim.chars[i] = {char = anim.args[2]:sub(i,i), visible = false}
        end
    end,

    update = function(anim, progress)
        local text = ""
        for i, charData in ipairs(anim.chars) do
            if math.random() < progress then
                charData.visible = true
            end
            text = text .. (charData.visible and charData.char or " ")
        end
        anim.element.set(anim.args[1], text)
        return progress >= 1
    end
})

Animation.registerAnimation("scrollText", {
    start = function(anim)
        anim.width = anim.element.get("width")
        anim.startText = anim.element.get(anim.args[1]) or ""
        anim.targetText = anim.args[2] or ""
        anim.startText = tostring(anim.startText)
        anim.targetText = tostring(anim.targetText)
    end,

    update = function(anim, progress)
        local w = anim.width

        if progress < 0.5 then
            local p = progress / 0.5
            local offset = math.floor(w * p)
            local visible = (anim.startText:sub(offset + 1) .. string.rep(" ", w)):sub(1, w)
            anim.element.set(anim.args[1], visible)
        else
            local p = (progress - 0.5) / 0.5
            local leftSpaces = math.floor(w * (1 - p))
            local incoming = string.rep(" ", leftSpaces) .. anim.targetText
            local visible = incoming:sub(1, w)
            anim.element.set(anim.args[1], visible)
        end

        return progress >= 1
    end,

    complete = function(anim)
        local final = (anim.targetText .. string.rep(" ", anim.width))
        anim.element.set(anim.args[1], final)
    end
})

Animation.registerAnimation("marquee", {
    start = function(anim)
        anim.width = anim.element.get("width")
        anim.text = tostring(anim.args[2] or "")
        anim.speed = tonumber(anim.args[3]) or 0.15
        anim.offset = 0
        anim.lastShift = -1
        anim.padded = anim.text .. string.rep(" ", anim.width)
    end,

    update = function(anim, progress)
        local elapsed = os.epoch("local") / 1000 - anim.startTime
        local step = math.max(0.01, anim.speed)
        local shifts = math.floor(elapsed / step)
        if shifts ~= anim.lastShift then
            anim.lastShift = shifts
            local totalLen = #anim.padded
            local idx = (shifts % totalLen) + 1
            local doubled = anim.padded .. anim.padded
            local visible = doubled:sub(idx, idx + anim.width - 1)
            anim.element.set(anim.args[1], visible)
        end
        return false
    end,

    complete = function(anim)
    end
})

--- Adds additional methods for VisualElement when adding animation plugin
--- @class VisualElement
local VisualElement = {hooks={}}

---@private
function VisualElement.hooks.handleEvent(self, event, ...)
    if event == "timer" then
        local animation = self.get("animation")
        if animation then
            animation:event(event, ...)
        end
    end
end

---@private
function VisualElement.setup(element)
    element.defineProperty(element, "animation", {default = nil, type = "table"})
    element.defineEvent(element, "timer")
end

-- Convenience to stop animations from the element
function VisualElement.stopAnimation(self)
    local anim = self.get("animation")
    if anim and type(anim.stop) == "function" then
        anim:stop()
    else
        -- fallback: clear property
        self.set("animation", nil)
    end
    return self
end

--- Creates a new Animation Object
--- @shortDescription Creates a new animation
--- @return Animation animation The new animation
function VisualElement:animate()
    local animation = Animation.new(self)
    self.set("animation", animation)
    return animation
end

return {
    VisualElement = VisualElement
} end
project["render.lua"] = function(...) local colorChars = require("libraries/colorHex")
local log = require("log")

--- This is the render module for Basalt. It tries to mimic the functionality of the `term` API. but with additional 
--- functionality. It also has a buffer system to reduce the number of calls
--- @class Render
--- @field terminal table The terminal object to render to
--- @field width number The width of the render
--- @field height number The height of the render
--- @field buffer table The buffer to render
--- @field xCursor number The x position of the cursor
--- @field yCursor number The y position of the cursor
--- @field blink boolean Whether the cursor should blink
local Render = {}
Render.__index = Render

local sub = string.sub

--- Creates a new Render object
--- @param terminal table The terminal object to render to
--- @return Render
function Render.new(terminal)
    local self = setmetatable({}, Render)
    self.terminal = terminal
    self.width, self.height = terminal.getSize()

    self.buffer = {
        text = {},
        fg = {},
        bg = {},
        dirtyRects = {}
    }

    for y=1, self.height do
        self.buffer.text[y] = string.rep(" ", self.width)
        self.buffer.fg[y] = string.rep("0", self.width)
        self.buffer.bg[y] = string.rep("f", self.width)
    end

    return self
end

--- Adds a dirty rectangle to the buffer
--- @param x number The x position of the rectangle
--- @param y number The y position of the rectangle
--- @param width number The width of the rectangle
--- @param height number The height of the rectangle
--- @return Render
function Render:addDirtyRect(x, y, width, height)
    table.insert(self.buffer.dirtyRects, {
        x = x,
        y = y,
        width = width,
        height = height
    })
    return self
end

--- Blits text to the screen
--- @param x number The x position to blit to
--- @param y number The y position to blit to
--- @param text string The text to blit
--- @param fg string The foreground color of the text
--- @param bg string The background color of the text
--- @return Render
function Render:blit(x, y, text, fg, bg)
    if y < 1 or y > self.height then return self end
    if(#text ~= #fg or #text ~= #bg)then
        error("Text, fg, and bg must be the same length")
    end

    self.buffer.text[y] = sub(self.buffer.text[y]:sub(1,x-1) .. text .. self.buffer.text[y]:sub(x+#text), 1, self.width)
    self.buffer.fg[y] = sub(self.buffer.fg[y]:sub(1,x-1) .. fg .. self.buffer.fg[y]:sub(x+#fg), 1, self.width)
    self.buffer.bg[y] = sub(self.buffer.bg[y]:sub(1,x-1) .. bg .. self.buffer.bg[y]:sub(x+#bg), 1, self.width)
    self:addDirtyRect(x, y, #text, 1)

    return self
end

--- Blits text to the screen with multiple lines
--- @param x number The x position to blit to
--- @param y number The y position to blit to
--- @param width number The width of the text
--- @param height number The height of the text
--- @param text string The text to blit
--- @param fg colors The foreground color of the text
--- @param bg colors The background color of the text
--- @return Render
function Render:multiBlit(x, y, width, height, text, fg, bg)
    if y < 1 or y > self.height then return self end
    if(#text ~= #fg or #text ~= #bg)then
        error("Text, fg, and bg must be the same length")
    end
    text = text:rep(width)
    fg = fg:rep(width)
    bg = bg:rep(width)

    for dy=0, height-1 do
        local cy = y + dy
        if cy >= 1 and cy <= self.height then
            self.buffer.text[cy] = sub(self.buffer.text[cy]:sub(1,x-1) .. text .. self.buffer.text[cy]:sub(x+#text), 1, self.width)
            self.buffer.fg[cy] = sub(self.buffer.fg[cy]:sub(1,x-1) .. fg .. self.buffer.fg[cy]:sub(x+#fg), 1, self.width)
            self.buffer.bg[cy] = sub(self.buffer.bg[cy]:sub(1,x-1) .. bg .. self.buffer.bg[cy]:sub(x+#bg), 1, self.width)
        end
    end

    self:addDirtyRect(x, y, width, height)
    return self
end

--- Blits text to the screen with a foreground color
--- @param x number The x position to blit to
--- @param y number The y position to blit to
--- @param text string The text to blit
--- @param fg colors The foreground color of the text
--- @return Render
function Render:textFg(x, y, text, fg)
    if y < 1 or y > self.height then return self end
    fg = colorChars[fg] or "0"
    fg = fg:rep(#text)
    self.buffer.text[y] = sub(self.buffer.text[y]:sub(1,x-1) .. text .. self.buffer.text[y]:sub(x+#text), 1, self.width)
    self.buffer.fg[y] = sub(self.buffer.fg[y]:sub(1,x-1) .. fg .. self.buffer.fg[y]:sub(x+#fg), 1, self.width)
    self:addDirtyRect(x, y, #text, 1)

    return self
end

--- Blits text to the screen with a background color
--- @param x number The x position to blit to
--- @param y number The y position to blit to
--- @param text string The text to blit
--- @param bg colors The background color of the text
--- @return Render
function Render:textBg(x, y, text, bg)
    if y < 1 or y > self.height then return self end
    bg = colorChars[bg] or "f"

    self.buffer.text[y] = sub(self.buffer.text[y]:sub(1,x-1) .. text .. self.buffer.text[y]:sub(x+#text), 1, self.width)
    self.buffer.bg[y] = sub(self.buffer.bg[y]:sub(1,x-1) .. bg:rep(#text) .. self.buffer.bg[y]:sub(x+#text), 1, self.width)
    self:addDirtyRect(x, y, #text, 1)

    return self
end

--- Renders the text to the screen
--- @param x number The x position to blit to
--- @param y number The y position to blit to
--- @param text string The text to blit
--- @return Render
function Render:text(x, y, text)
    if y < 1 or y > self.height then return self end

    self.buffer.text[y] = sub(self.buffer.text[y]:sub(1,x-1) .. text .. self.buffer.text[y]:sub(x+#text), 1, self.width)
    self:addDirtyRect(x, y, #text, 1)

    return self
end

--- Blits a foreground color to the screen
--- @param x number The x position
--- @param y number The y position
--- @param fg string The foreground color to blit
--- @return Render
function Render:fg(x, y, fg)
    if y < 1 or y > self.height then return self end

    self.buffer.fg[y] = sub(self.buffer.fg[y]:sub(1,x-1) .. fg .. self.buffer.fg[y]:sub(x+#fg), 1, self.width)
    self:addDirtyRect(x, y, #fg, 1)

    return self
end

--- Blits a background color to the screen
--- @param x number The x position
--- @param y number The y position
--- @param bg string The background color to blit
--- @return Render
function Render:bg(x, y, bg)
    if y < 1 or y > self.height then return self end

    self.buffer.bg[y] = sub(self.buffer.bg[y]:sub(1,x-1) .. bg .. self.buffer.bg[y]:sub(x+#bg), 1, self.width)
    self:addDirtyRect(x, y, #bg, 1)

    return self
end

--- Blits text to the screen
--- @param x number The x position to blit to
--- @param y number The y position to blit to
--- @param text string The text to blit
--- @return Render
function Render:text(x, y, text)
    if y < 1 or y > self.height then return self end

    self.buffer.text[y] = sub(self.buffer.text[y]:sub(1,x-1) .. text .. self.buffer.text[y]:sub(x+#text), 1, self.width)
    self:addDirtyRect(x, y, #text, 1)

    return self
end

--- Blits a foreground color to the screen
--- @param x number The x position
--- @param y number The y position
--- @param fg string The foreground color to blit
--- @return Render
function Render:fg(x, y, fg)
    if y < 1 or y > self.height then return self end

    self.buffer.fg[y] = sub(self.buffer.fg[y]:sub(1,x-1) .. fg .. self.buffer.fg[y]:sub(x+#fg), 1, self.width)
    self:addDirtyRect(x, y, #fg, 1)

    return self
end

--- Blits a background color to the screen
--- @param x number The x position
--- @param y number The y position
--- @param bg string The background color to blit
--- @return Render
function Render:bg(x, y, bg)
    if y < 1 or y > self.height then return self end

    self.buffer.bg[y] = sub(self.buffer.bg[y]:sub(1,x-1) .. bg .. self.buffer.bg[y]:sub(x+#bg), 1, self.width)
    self:addDirtyRect(x, y, #bg, 1)

    return self
end

--- Clears the screen
--- @param bg colors The background color to clear the screen with
--- @return Render
function Render:clear(bg)
    local bgChar = colorChars[bg] or "f"
    for y=1, self.height do
        self.buffer.text[y] = string.rep(" ", self.width)
        self.buffer.fg[y] = string.rep("0", self.width)
        self.buffer.bg[y] = string.rep(bgChar, self.width)
        self:addDirtyRect(1, y, self.width, 1)
    end
    return self
end

--- Renders the buffer to the screen
--- @return Render
function Render:render()
    local mergedRects = {}
    for _, rect in ipairs(self.buffer.dirtyRects) do
        local merged = false
        for _, existing in ipairs(mergedRects) do
            if self:rectOverlaps(rect, existing) then
                self:mergeRects(existing, rect)
                merged = true
                break
            end
        end
        if not merged then
            table.insert(mergedRects, rect)
        end
    end

    for _, rect in ipairs(mergedRects) do
        for y = rect.y, rect.y + rect.height - 1 do
            if y >= 1 and y <= self.height then
                self.terminal.setCursorPos(rect.x, y)
                self.terminal.blit(
                    self.buffer.text[y]:sub(rect.x, rect.x + rect.width - 1),
                    self.buffer.fg[y]:sub(rect.x, rect.x + rect.width - 1),
                    self.buffer.bg[y]:sub(rect.x, rect.x + rect.width - 1)
                )
            end
        end
    end

    self.buffer.dirtyRects = {}

    if self.blink then
        self.terminal.setTextColor(self.cursorColor or colors.white)
        self.terminal.setCursorPos(self.xCursor, self.yCursor)
        self.terminal.setCursorBlink(true)
    else
        self.terminal.setCursorBlink(false)
    end

    return self
end

--- Checks if two rectangles overlap
--- @param r1 table The first rectangle
--- @param r2 table The second rectangle
--- @return boolean
function Render:rectOverlaps(r1, r2)
    return not (r1.x + r1.width <= r2.x or
               r2.x + r2.width <= r1.x or
               r1.y + r1.height <= r2.y or
               r2.y + r2.height <= r1.y)
end

--- Merges two rectangles
--- @param target table The target rectangle
--- @param source table The source rectangle
--- @return Render
function Render:mergeRects(target, source)
    local x1 = math.min(target.x, source.x)
    local y1 = math.min(target.y, source.y)
    local x2 = math.max(target.x + target.width, source.x + source.width)
    local y2 = math.max(target.y + target.height, source.y + source.height)
    
    target.x = x1
    target.y = y1
    target.width = x2 - x1
    target.height = y2 - y1
    return self
end

--- Sets the cursor position
--- @param x number The x position of the cursor
--- @param y number The y position of the cursor
--- @param blink boolean Whether the cursor should blink
--- @return Render
function Render:setCursor(x, y, blink, color)
    if color ~= nil then self.terminal.setTextColor(color) end
    self.terminal.setCursorPos(x, y)
    self.terminal.setCursorBlink(blink)
    self.xCursor = x
    self.yCursor = y
    self.blink = blink
    self.cursorColor = color
    return self
end

--- Clears an area of the screen
--- @param x number The x position of the area
--- @param y number The y position of the area
--- @param width number The width of the area
--- @param height number The height of the area
--- @param bg colors The background color to clear the area with
--- @return Render
function Render:clearArea(x, y, width, height, bg)
    local bgChar = colorChars[bg] or "f"
    for dy=0, height-1 do
        local cy = y + dy
        if cy >= 1 and cy <= self.height then
            local text = string.rep(" ", width)
            local color = string.rep(bgChar, width)
            self:blit(x, cy, text, "0", bgChar)
        end
    end
    return self
end

--- Gets the size of the render
--- @return number, number
function Render:getSize()
    return self.width, self.height
end

--- Sets the size of the render
--- @param width number The width of the render
--- @param height number The height of the render
--- @return Render
function Render:setSize(width, height)
    self.width = width
    self.height = height
    for y=1, self.height do
        self.buffer.text[y] = string.rep(" ", self.width)
        self.buffer.fg[y] = string.rep("0", self.width)
        self.buffer.bg[y] = string.rep("f", self.width)
    end
    return self
end

return Render end
project["plugins/canvas.lua"] = function(...) local tHex = require("libraries/colorHex")
local errorManager = require("errorManager")
local Canvas = {}
Canvas.__index = Canvas

local sub, rep = string.sub, string.rep

function Canvas.new(element)
    local self = setmetatable({}, Canvas)
    self.commands = {pre={},post={}}
    self.type = "pre"
    self.element = element
    return self
end

function Canvas:clear()
    self.commands = {pre={},post={}}
    return self
end

function Canvas:getValue(v)
    if type(v) == "function" then
        return v(self.element)
    end
    return v
end

function Canvas:setType(type)
    if type == "pre" or type == "post" then
        self.type = type
    else
        errorManager.error("Invalid type. Use 'pre' or 'post'.")
    end
    return self
end

function Canvas:addCommand(drawFn)
    local index = #self.commands[self.type] + 1
    self.commands[self.type][index] = drawFn
    return index
end

function Canvas:setCommand(index, drawFn)
    self.commands[index] = drawFn
    return self
end

function Canvas:removeCommand(index)
    --self.commands[self.type][index] = nil
    table.remove(self.commands[self.type], index)
    return self
end

function Canvas:text(x, y, text, fg, bg)
    return self:addCommand(function(render)
        local _x, _y = self:getValue(x), self:getValue(y)
        local _text = self:getValue(text)
        local _fg = self:getValue(fg)
        local _bg = self:getValue(bg)
        local __fg = type(_fg) == "number" and tHex[_fg]:rep(#text) or _fg
        local __bg = type(_bg) == "number" and tHex[_bg]:rep(#text) or _bg
        render:drawText(_x, _y, _text)
        if __fg then render:drawFg(_x, _y, __fg) end
        if __bg then render:drawBg(_x, _y, __bg) end
    end)
end

function Canvas:bg(x, y, bg)
    return self:addCommand(function(render)
        render:drawBg(x, y, bg)
    end)
end

function Canvas:fg(x, y, fg)
    return self:addCommand(function(render)
        render:drawFg(x, y, fg)
    end)
end

function Canvas:rect(x, y, width, height, char, fg, bg)
    return self:addCommand(function(render)
        local _x, _y = self:getValue(x), self:getValue(y)
        local _width, _height = self:getValue(width), self:getValue(height)
        local _char = self:getValue(char)
        local _fg = self:getValue(fg)
        local _bg = self:getValue(bg)

        if(type(_fg) == "number") then _fg = tHex[_fg] end
        if(type(_bg) == "number") then _bg = tHex[_bg] end

        local bgLine = _bg and sub(_bg:rep(_width), 1, _width)
        local fgLine = _fg and sub(_fg:rep(_width), 1, _width)
        local textLine = _char and sub(_char:rep(_width), 1, _width)

        for i = 0, _height - 1 do
            if _bg then render:drawBg(_x, _y + i, bgLine) end
            if _fg then render:drawFg(_x, _y + i, fgLine) end
            if _char then render:drawText(_x, _y + i, textLine) end
        end
    end)
end

function Canvas:line(x1, y1, x2, y2, char, fg, bg)
    local function linePoints(x1, y1, x2, y2)
        local points = {}
        local count = 0

        local dx = math.abs(x2 - x1)
        local dy = math.abs(y2 - y1)
        local sx = (x1 < x2) and 1 or -1
        local sy = (y1 < y2) and 1 or -1
        local err = dx - dy

        while true do
            count = count + 1
            points[count] = {x = x1, y = y1}

            if (x1 == x2) and (y1 == y2) then break end

            local err2 = err * 2
            if err2 > -dy then
                err = err - dy
                x1 = x1 + sx
            end
            if err2 < dx then
                err = err + dx
                y1 = y1 + sy
            end
        end

        return points
    end
    local needsRecreate = false
    local points
    if type(x1) == "function" or type(y1) == "function" or type(x2) == "function" or type(y2) == "function" then
        needsRecreate = true
    else
        points = linePoints(self:getValue(x1), self:getValue(y1), self:getValue(x2), self:getValue(y2))
    end

    return self:addCommand(function(render)
        if needsRecreate then
            points = linePoints(self:getValue(x1), self:getValue(y1), self:getValue(x2), self:getValue(y2))
        end
        local _char = self:getValue(char)
        local _fg = self:getValue(fg)
        local _bg = self:getValue(bg)
        local __fg = type(_fg) == "number" and tHex[_fg] or _fg
        local __bg = type(_bg) == "number" and tHex[_bg] or _bg

        for _, point in ipairs(points) do
            local x = math.floor(point.x)
            local y = math.floor(point.y)

            if _char then render:drawText(x, y, _char) end
            if __fg then render:drawFg(x, y, __fg) end
            if __bg then render:drawBg(x, y, __bg) end
        end
    end)
end

function Canvas:ellipse(centerX, centerY, radiusX, radiusY, char, fg, bg)
    local function ellipsePoints(x, y, radiusX, radiusY)
        local points = {}
        local count = 0

        local a2 = radiusX * radiusX
        local b2 = radiusY * radiusY

        local px = 0
        local py = radiusY

        local p = b2 - a2 * radiusY + 0.25 * a2
        local px2 = 0
        local py2 = 2 * a2 * py

        local function addPoint(px, py)
            count = count + 1
            points[count] = {x = x + px, y = y + py}
            count = count + 1
            points[count] = {x = x - px, y = y + py}
            count = count + 1
            points[count] = {x = x + px, y = y - py}
            count = count + 1
            points[count] = {x = x - px, y = y - py}
        end

        addPoint(px, py)

        while px2 < py2 do
            px = px + 1
            px2 = px2 + 2 * b2
            if p < 0 then
                p = p + b2 + px2
            else
                py = py - 1
                py2 = py2 - 2 * a2
                p = p + b2 + px2 - py2
            end
            addPoint(px, py)
        end

        p = b2 * (px + 0.5) * (px + 0.5) + a2 * (py - 1) * (py - 1) - a2 * b2

        while py > 0 do
            py = py - 1
            py2 = py2 - 2 * a2
            if p > 0 then
                p = p + a2 - py2
            else
                px = px + 1
                px2 = px2 + 2 * b2
                p = p + a2 - py2 + px2
            end
            addPoint(px, py)
        end

        return points
    end

    local points = ellipsePoints(centerX, centerY, radiusX, radiusY)
    return self:addCommand(function(render)
        local _char = self:getValue(char)
        local _fg = self:getValue(fg)
        local _bg = self:getValue(bg)
        local __fg = type(_fg) == "number" and tHex[_fg] or _fg
        local __bg = type(_bg) == "number" and tHex[_bg] or _bg

        for y, line in pairs(points) do
            local x = math.floor(line.x)
            local y = math.floor(line.y)

            if _char then render:drawText(x, y, _char) end
            if __fg then render:drawFg(x, y, __fg) end
            if __bg then render:drawBg(x, y, __bg) end
        end
    end)
end

local VisualElement = {hooks={}}

function VisualElement.setup(element)
    element.defineProperty(element, "canvas", {
        default = nil,
        type = "table",
        getter = function(self)
            if not self._values.canvas then
                self._values.canvas = Canvas.new(self)
            end
            return self._values.canvas
        end
    })
end

function VisualElement.hooks.render(self)
    local canvas = self.get("canvas")
    if canvas and #canvas.commands.pre > 0 then
        for _, cmd in pairs(canvas.commands.pre) do
            cmd(self)
        end
    end
end

function VisualElement.hooks.postRender(self)
    local canvas = self.get("canvas")
    if canvas and #canvas.commands.post > 0 then
        for _, cmd in pairs(canvas.commands.post) do
            cmd(self)
        end
    end
end

return {
    VisualElement = VisualElement,
    API = Canvas
} end
project["plugins/xml.lua"] = function(...) local errorManager = require("errorManager")
local log = require("log")
local XMLNode = {
    new = function(tag)
        return {
            tag = tag,
            value = nil,
            attributes = {},
            children = {},

            addChild = function(self, child)
                table.insert(self.children, child)
            end,

            addAttribute = function(self, tag, value)
                self.attributes[tag] = value
            end
        }
    end
}

local parseAttributes = function(node, s)
    local _, _ = string.gsub(s, "(%w+)=([\"'])(.-)%2", function(attribute, _, value)
        node:addAttribute(attribute, "\"" .. value .. "\"")
    end)
    local _, _ = string.gsub(s, "(%w+)={(.-)}", function(attribute, expression)
        node:addAttribute(attribute, expression)
    end)
end

local XMLParser = {
    parseText = function(xmlText)
        local stack = {}
        local top = XMLNode.new()
        table.insert(stack, top)
        local ni, c, label, xarg, empty
        local i, j = 1, 1
        while true do
            ni, j, c, label, xarg, empty = string.find(xmlText, "<(%/?)([%w_:]+)(.-)(%/?)>", i)
            if not ni then break end
            local text = string.sub(xmlText, i, ni - 1);
            if not string.find(text, "^%s*$") then
                local lVal = (top.value or "") .. text
                stack[#stack].value = lVal
            end
            if empty == "/" then
                local lNode = XMLNode.new(label)
                parseAttributes(lNode, xarg)
                top:addChild(lNode)
            elseif c == "" then
                local lNode = XMLNode.new(label)
                parseAttributes(lNode, xarg)
                table.insert(stack, lNode)
                top = lNode
            else
                local toclose = table.remove(stack)

                top = stack[#stack]
                if #stack < 1 then
                    errorManager.error("XMLParser: nothing to close with " .. label)
                end
                if toclose.tag ~= label then
                    errorManager.error("XMLParser: trying to close " .. toclose.tag .. " with " .. label)
                end
                top:addChild(toclose)
            end
            i = j + 1
        end
        if #stack > 1 then
            error("XMLParser: unclosed " .. stack[#stack].tag)
        end
        return top.children
    end
}

local function findExpressions(text)
    local expressions = {}
    local lastIndex = 1

    while true do
        local startPos, endPos, expr = text:find("%${([^}]+)}", lastIndex)
        if not startPos then break end

        table.insert(expressions, {
            start = startPos,
            ending = endPos, 
            expression = expr,
            raw = text:sub(startPos, endPos)
        })

        lastIndex = endPos + 1
    end

    return expressions
end

local function convertValue(value, scope)
    if not value then return value end
    if value:sub(1,1) == "\"" and value:sub(-1) == "\"" then
        value = value:sub(2, -2)
    end

    local expressions = findExpressions(value)

    for _, expr in ipairs(expressions) do
        local expression = expr.expression
        local startPos = expr.start - 1
        local endPos = expr.ending + 1

        if scope[expression] then
            value = value:sub(1, startPos) .. tostring(scope[expression]) .. value:sub(endPos)
        else
            errorManager.error("XMLParser: variable '" .. expression .. "' not found in scope")
        end
    end

    if value:match("^%s*<!%[CDATA%[.*%]%]>%s*$") then
        local cdata = value:match("<!%[CDATA%[(.*)%]%]>")
        local env = _ENV
        for k,v in pairs(scope) do
            env[k] = v
        end
        return load("return " .. cdata, nil, "bt", env)()
    end

    if value == "true" then
        return true
    elseif value == "false" then
        return false
    elseif colors[value] then
        return colors[value]
    elseif tonumber(value) then
        return tonumber(value)
    else
        return value
    end
end

local function createTableFromNode(node, scope)
    local list = {}

    for _, child in pairs(node.children) do
        if child.tag == "item" or child.tag == "entry" then
            local item = {}

            for attrName, attrValue in pairs(child.attributes) do
                item[attrName] = convertValue(attrValue, scope)
            end

            for _, subChild in pairs(child.children) do
                if subChild.value then
                    item[subChild.tag] = convertValue(subChild.value, scope)
                elseif #subChild.children > 0 then
                    item[subChild.tag] = createTableFromNode(subChild)
                end
            end

            table.insert(list, item)
        else
            if child.value then
                list[child.tag] = convertValue(child.value, scope)
            elseif #child.children > 0 then
                list[child.tag] = createTableFromNode(child)
            end
        end
    end

    return list
end

local BaseElement = {}

function BaseElement.setup(element)
    element.defineProperty(element, "customXML", {default = {attributes={},children={}}, type = "table"})
end

--- Generates this element from XML nodes
--- @shortDescription Generates this element from XML nodes
--- @param self BaseElement The element to generate from XML nodes
--- @param node table The XML nodes to generate from
--- @param scope table The scope to use
--- @return BaseElement self The element instance
function BaseElement:fromXML(node, scope)
    if(node.attributes)then
        for k, v in pairs(node.attributes) do
            if(self._properties[k])then
                self.set(k, convertValue(v, scope))
            elseif self[k] then
                if(k:sub(1,2)=="on")then
                    local val = v:gsub("\"", "")
                    if(scope[val])then
                        if(type(scope[val]) ~= "function")then
                            errorManager.error("XMLParser: variable '" .. val .. "' is not a function for element '" .. self:getType() .. "' "..k)
                        end
                        self[k](self, scope[val])
                    else
                        errorManager.error("XMLParser: variable '" .. val .. "' not found in scope")
                    end
                else
                    errorManager.error("XMLParser: property '" .. k .. "' not found in element '" .. self:getType() .. "'")
                end
            else
                local customXML = self.get("customXML")
                customXML.attributes[k] = convertValue(v, scope)
            end
        end
    end

    if(node.children)then
        for _, child in pairs(node.children) do
            if(self._properties[child.tag])then
                if(self._properties[child.tag].type == "table")then
                    self.set(child.tag, createTableFromNode(child, scope))
                else
                    self.set(child.tag, convertValue(child.value, scope))
                end
            else
                local args = {}
                if(child.children)then
                    for _, child in pairs(child.children) do
                        if(child.tag == "param")then
                            table.insert(args, convertValue(child.value, scope))
                        elseif (child.tag == "table")then
                            table.insert(args, createTableFromNode(child, scope))
                        end
                    end
                end

                if(self[child.tag])then
                    if(#args > 0)then
                        self[child.tag](self, table.unpack(args))
                    elseif(child.value)then
                        self[child.tag](self, convertValue(child.value, scope))
                    else
                        self[child.tag](self)
                    end
                else
                    local customXML = self.get("customXML")
                    child.value = convertValue(child.value, scope)
                    customXML.children[child.tag] = child
                end
            end
        end
    end
    return self
end

local Container = {}

--- Loads an XML string and parses it into the element
--- @shortDescription Loads an XML string and parses it into the element
--- @param self Container The element to load the XML into
--- @param content string The XML string to load
--- @param scope table The scope to use
--- @return Container self The element instance
function Container:loadXML(content, scope)
    scope = scope or {}
    local nodes = XMLParser.parseText(content)
    self:fromXML(nodes, scope)
    if(nodes)then
        for _, node in ipairs(nodes) do
            local capitalizedName = node.tag:sub(1,1):upper() .. node.tag:sub(2)
            if self["add"..capitalizedName] then
                local element = self["add"..capitalizedName](self)
                element:fromXML(node, scope)
            end
        end
    end
    return self
end

--- Generates this element from XML nodes
--- @shortDescription Generates this element from XML nodes
--- @param self Container The element to generate from XML nodes
--- @param nodes table The XML nodes to generate from
--- @param scope table The scope to use
--- @return Container self The element instance
function Container:fromXML(nodes, scope)
    BaseElement.fromXML(self, nodes, scope)
    if(nodes.children)then
        for _, node in ipairs(nodes.children) do
            local capitalizedName = node.tag:sub(1,1):upper() .. node.tag:sub(2)
            if self["add"..capitalizedName] then
                local element = self["add"..capitalizedName](self)
                element:fromXML(node, scope)
            end
        end
    end
    return self
end

return {
    API = XMLParser,
    Container = Container,
    BaseElement = BaseElement
} end
project["libraries/expect.lua"] = function(...) local errorManager = require("errorManager")

-- Simple type checking without stack traces
local function expect(position, value, expectedType)
    local valueType = type(value)

    if expectedType == "element" then
        if valueType == "table" and value.get("type") ~= nil then
            return true
        end
    end

    if expectedType == "color" then
        if valueType == "number" then
            return true
        end
        if valueType == "string" and colors[value] then
            return true
        end
    end

    if valueType ~= expectedType then
        errorManager.header = "Basalt Type Error"
        errorManager.error(string.format(
            "Bad argument #%d: expected %s, got %s",
            position,
            expectedType,
            valueType
        ))
    end

    return true
end

return expect end
project["init.lua"] = function(...) local args = {...}
local basaltPath = fs.getDir(args[2])

local defaultPath = package.path
local format = "path;/path/?.lua;/path/?/init.lua;"

local main = format:gsub("path", basaltPath)
package.path = main.."rom/?;"..defaultPath

local function errorHandler(err)
    package.path = main.."rom/?"
    local errorManager = require("errorManager")
    package.path = defaultPath
    errorManager.header = "Basalt Loading Error"
    errorManager.error(err)
end

local ok, result = pcall(require, "main")
package.loaded.log = nil

package.path = defaultPath
if not ok then
    errorHandler(result)
else
    return result
end end
project["libraries/utils.lua"] = function(...) local floor, len = math.floor, string.len

local utils = {}

function utils.getCenteredPosition(text, totalWidth, totalHeight)
    local textLength = len(text)

    local x = floor((totalWidth - textLength+1) / 2 + 0.5)
    local y = floor(totalHeight / 2 + 0.5)

    return x, y
end

function utils.deepCopy(obj)
    if type(obj) ~= "table" then
        return obj
    end

    local copy = {}
    for k, v in pairs(obj) do
        copy[utils.deepCopy(k)] = utils.deepCopy(v)
    end

    return copy
end

function utils.copy(obj)
    local new = {}
    for k,v in pairs(obj)do
        new[k] = v
    end
    return new
end

function utils.reverse(t)
    local reversed = {}
    for i = #t, 1, -1 do
        table.insert(reversed, t[i])
    end
    return reversed
end

function utils.uuid()
    return string.format('%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
    math.random(0, 0xffff), math.random(0, 0xffff), math.random(0, 0xffff),
    math.random(0, 0x0fff) + 0x4000, math.random(0, 0x3fff) + 0x8000,
    math.random(0, 0xffff), math.random(0, 0xffff), math.random(0, 0xffff))
end

function utils.split(str, delimiter)
    local result = {}
    for match in (str..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match)
    end
    return result
end

function utils.removeTags(input)
    return input:gsub("{[^}]+}", "")
end

function utils.wrapText(str, width)
    if str == nil then return {} end
    str = utils.removeTags(str)
    local lines = {}

    local paragraphs = utils.split(str, "\n\n")

    for i, paragraph in ipairs(paragraphs) do
        if #paragraph == 0 then
            table.insert(lines, "")
            if i < #paragraphs then
                table.insert(lines, "")
            end
        else
            local textLines = utils.split(paragraph, "\n")

            for _, line in ipairs(textLines) do
                local words = utils.split(line, " ")
                local currentLine = ""

                for _, word in ipairs(words) do
                    if #currentLine == 0 then
                        currentLine = word
                    elseif #currentLine + #word + 1 <= width then
                        currentLine = currentLine .. " " .. word
                    else
                        table.insert(lines, currentLine)
                        currentLine = word
                    end
                end

                if #currentLine > 0 then
                    table.insert(lines, currentLine)
                end
            end

            if i < #paragraphs then
                table.insert(lines, "")
            end
        end
    end

    return lines
end

return utils end
project["elements/LineChart.lua"] = function(...) local elementManager = require("elementManager")
local VisualElement = elementManager.getElement("VisualElement")
local Graph = elementManager.getElement("Graph")
local tHex = require("libraries/colorHex")
--- @configDescription A line chart element based on the graph element
---@configDefault false

--- The Line Chart element visualizes data series as connected line graphs. It plots points on a coordinate system and connects them with lines.
--- @usage local chart = main:addLineChart()
--- @usage :addSeries("input", " ", colors.green, colors.green, 10)
--- @usage :addSeries("output", " ", colors.red, colors.red, 10)
--- @usage 
--- @usage basalt.schedule(function()
--- @usage     while true do
--- @usage         chart:addPoint("input", math.random(1,100))
--- @usage         chart:addPoint("output", math.random(1,100))
--- @usage         sleep(2)
--- @usage     end
--- @usage end)
--- @class LineChart : Graph
local LineChart = setmetatable({}, Graph)
LineChart.__index = LineChart

--- Creates a new LineChart instance
--- @shortDescription Creates a new LineChart instance
--- @return LineChart self The newly created LineChart instance
--- @private
function LineChart.new()
    local self = setmetatable({}, LineChart):__init()
    self.class = LineChart
    return self
end

--- @shortDescription Initializes the LineChart instance
--- @param props table The properties to initialize the element with
--- @param basalt table The basalt instance
--- @return LineChart self The initialized instance
--- @protected
function LineChart:init(props, basalt)
    Graph.init(self, props, basalt)
    self.set("type", "LineChart")
    return self
end

local function drawLine(self, x1, y1, x2, y2, symbol, bgColor, fgColor)
    local dx = x2 - x1
    local dy = y2 - y1
    local steps = math.max(math.abs(dx), math.abs(dy))

    for i = 0, steps do
        local t = steps == 0 and 0 or i / steps
        local x = math.floor(x1 + dx * t)
        local y = math.floor(y1 + dy * t)
        if x >= 1 and x <= self.get("width") and y >= 1 and y <= self.get("height") then
            self:blit(x, y, symbol, tHex[bgColor], tHex[fgColor])
        end
    end
end

--- @shortDescription Renders the LineChart
--- @protected
function LineChart:render()
    VisualElement.render(self)

    local width = self.get("width")
    local height = self.get("height")
    local minVal = self.get("minValue")
    local maxVal = self.get("maxValue")
    local series = self.get("series")

    for _, s in pairs(series) do
        if(s.visible)then
            local lastX, lastY
            local dataCount = #s.data
            local spacing = (width - 1) / math.max((dataCount - 1), 1)

            for i, value in ipairs(s.data) do
                local x = math.floor(((i-1) * spacing) + 1)
                local normalizedValue = (value - minVal) / (maxVal - minVal)
                local y = math.floor(height - (normalizedValue * (height-1)))
                y = math.max(1, math.min(y, height))

                if lastX then
                    drawLine(self, lastX, lastY, x, y, s.symbol, s.bgColor, s.fgColor)
                end
                lastX, lastY = x, y
            end
        end
    end
end

return LineChart
 end
project["elements/FlexBox.lua"] = function(...) local elementManager = require("elementManager")
local Container = elementManager.getElement("Container")
---@configDescription A flexbox container that arranges its children in a flexible layout.

--- This is the FlexBox class. It is a container that arranges its children in a flexible layout.
--- @usage local flex = main:addFlexbox({background=colors.black, width=30, height=10})
--- @usage flex:addButton():setFlexGrow(1)
--- @usage flex:addButton():setFlexGrow(1)
--- @usage flex:addButton():setFlexGrow(1)
--- The flexbox element adds the following properties to its children:
--- 
--- @usage flex:addButton():setFlexGrow(1) -- The flex-grow property defines the ability for a flex item to grow if necessary.
--- @usage flex:addButton():setFlexShrink(1) -- The flex-shrink property defines the ability for a flex item to shrink if necessary.
--- @usage flex:addButton():setFlexBasis(1) -- The flex-basis property defines the default size of an element before the remaining space is distributed.
---@class FlexBox : Container
local FlexBox = setmetatable({}, Container)
FlexBox.__index = FlexBox

---@property flexDirection string "row" The direction of the flexbox layout "row" or "column"
FlexBox.defineProperty(FlexBox, "flexDirection", {default = "row", type = "string"})
---@property flexSpacing number 1 The spacing between flex items
FlexBox.defineProperty(FlexBox, "flexSpacing", {default = 1, type = "number"})
---@property flexJustifyContent string "flex-start" The alignment of flex items along the main axis
FlexBox.defineProperty(FlexBox, "flexJustifyContent", {
    default = "flex-start",
    type = "string",
    setter = function(self, value)
        if not value:match("^flex%-") then
            value = "flex-" .. value
        end
        return value
    end
})
---@property flexAlignItems string "flex-start" The alignment of flex items along the cross axis
FlexBox.defineProperty(FlexBox, "flexAlignItems", {
    default = "flex-start",
    type = "string",
    setter = function(self, value)
        if not value:match("^flex%-") and value ~= "stretch" then
            value = "flex-" .. value
        end
        return value
    end
})
---@property flexCrossPadding number 0 The padding on both sides of the cross axis
FlexBox.defineProperty(FlexBox, "flexCrossPadding", {default = 0, type = "number"})
---@property flexWrap boolean false Whether to wrap flex items onto multiple lines
---@property flexUpdateLayout boolean false Whether to update the layout of the flexbox
FlexBox.defineProperty(FlexBox, "flexWrap", {default = false, type = "boolean"})
FlexBox.defineProperty(FlexBox, "flexUpdateLayout", {default = false, type = "boolean"})

local lineBreakElement = {
  getHeight = function(self) return 0 end,
  getWidth = function(self) return 0 end,
  getZ = function(self) return 1 end,
  getPosition = function(self) return 0, 0 end,
  getSize = function(self) return 0, 0 end,
  isType = function(self) return false end,
  getType = function(self) return "lineBreak" end,
  getName = function(self) return "lineBreak" end,
  setPosition = function(self) end,
  setParent = function(self) end,
  setSize = function(self) end,
  getFlexGrow = function(self) return 0 end,
  getFlexShrink = function(self) return 0 end,
  getFlexBasis = function(self) return 0 end,
  init = function(self) end,
  getVisible = function(self) return true end,
}

local function sortElements(self, direction, spacing, wrap)
    local sortedElements = {}
    local visibleElements = {}
    local childCount = 0
    
    -- We can't use self.get("visibleChildren") here 
    --because it would exclude elements that are obscured
    for _, elem in pairs(self.get("children")) do
        if elem.get("visible") then
            table.insert(visibleElements, elem)
            if elem ~= lineBreakElement then
                childCount = childCount + 1
            end
        end
    end
    
    
    if childCount == 0 then
        return sortedElements
    end
    
    if not wrap then
        sortedElements[1] = {offset=1}
        
        for _, elem in ipairs(visibleElements) do
            if elem == lineBreakElement then
                local nextIndex = #sortedElements + 1
                if sortedElements[nextIndex] == nil then
                    sortedElements[nextIndex] = {offset=1}
                end
            else
                table.insert(sortedElements[#sortedElements], elem)
            end
        end
    else
        local containerSize = direction == "row" and self.get("width") or self.get("height")
        
        local segments = {{}}
        local currentSegment = 1
        
        for _, elem in ipairs(visibleElements) do
            if elem == lineBreakElement then
                currentSegment = currentSegment + 1
                segments[currentSegment] = {}
            else
                table.insert(segments[currentSegment], elem)
            end
        end
        
        for segmentIndex, segment in ipairs(segments) do
            if #segment == 0 then
                sortedElements[#sortedElements + 1] = {offset=1}
            else
                local rows = {}
                local currentRow = {}
                local currentWidth = 0
                
                for _, elem in ipairs(segment) do
                    local intrinsicSize = 0
                    local currentSize = direction == "row" and elem.get("width") or elem.get("height")
                    
                    local hasIntrinsic = false
                    if direction == "row" then
                        local ok, intrinsicWidth = pcall(function() return elem.get("intrinsicWidth") end)
                        if ok and intrinsicWidth then
                            intrinsicSize = intrinsicWidth
                            hasIntrinsic = true
                        end
                    else
                        local ok, intrinsicHeight = pcall(function() return elem.get("intrinsicHeight") end)
                        if ok and intrinsicHeight then
                            intrinsicSize = intrinsicHeight
                            hasIntrinsic = true
                        end
                    end
                    
                    local elemSize = hasIntrinsic and intrinsicSize or currentSize
                    
                    local spaceNeeded = elemSize
                    
                    if #currentRow > 0 then
                        spaceNeeded = spaceNeeded + spacing
                    end
                    
                    if currentWidth + spaceNeeded <= containerSize or #currentRow == 0 then
                        table.insert(currentRow, elem)
                        currentWidth = currentWidth + spaceNeeded
                    else
                        table.insert(rows, currentRow)
                        currentRow = {elem}
                        currentWidth = elemSize
                    end
                end
                
                if #currentRow > 0 then
                    table.insert(rows, currentRow)
                end
                
                for _, row in ipairs(rows) do
                    sortedElements[#sortedElements + 1] = {offset=1}
                    for _, elem in ipairs(row) do
                        table.insert(sortedElements[#sortedElements], elem)
                    end
                end
            end
        end
    end
    
    local filteredElements = {}
    for i, rowOrColumn in ipairs(sortedElements) do
        if #rowOrColumn > 0 then
            table.insert(filteredElements, rowOrColumn)
        end
    end
    
    return filteredElements
end

local function calculateRow(self, children, spacing, justifyContent)
    -- Make a copy of children that filters out lineBreak elements
    local filteredChildren = {}
    for _, child in ipairs(children) do
        if child ~= lineBreakElement then
            table.insert(filteredChildren, child)
        end
    end
    
    -- Skip processing if no children
    if #filteredChildren == 0 then
        return
    end
    
    local containerWidth = self.get("width")
    local containerHeight = self.get("height")
    local alignItems = self.get("flexAlignItems")
    local crossPadding = self.get("flexCrossPadding")
    local wrap = self.get("flexWrap")
    
    -- Safety check
    if containerWidth <= 0 then return end
    
    -- Calculate available cross axis space (considering padding)
    local availableCrossAxisSpace = containerHeight - (crossPadding * 2)
    if availableCrossAxisSpace < 1 then
        availableCrossAxisSpace = containerHeight
        crossPadding = 0
    end
    
    -- Cache local variables to reduce function calls
    local max = math.max
    local min = math.min
    local floor = math.floor
    local ceil = math.ceil
    
    -- Categorize elements and calculate their minimal widths and flexibilities
    local totalFixedWidth = 0
    local totalFlexGrow = 0
    local minWidths = {}
    local flexGrows = {}
    local flexShrinks = {}
    
    -- First pass: collect fixed widths and flex properties
    for _, child in ipairs(filteredChildren) do
        local grow = child.get("flexGrow") or 0
        local shrink = child.get("flexShrink") or 0
        local width = child.get("width")
        
        -- Track element properties
        flexGrows[child] = grow
        flexShrinks[child] = shrink
        minWidths[child] = width
        
        -- Calculate total flex grow factor
        if grow > 0 then
            totalFlexGrow = totalFlexGrow + grow
        else
            -- If not flex grow, it's a fixed element
            totalFixedWidth = totalFixedWidth + width
        end
    end
    
    -- Calculate total spacing
    local elementsCount = #filteredChildren
    local totalSpacing = (elementsCount > 1) and ((elementsCount - 1) * spacing) or 0
    
    -- Calculate available space for flex items
    local availableSpace = containerWidth - totalFixedWidth - totalSpacing
    
    -- Second pass: distribute available space to flex-grow items
    if availableSpace > 0 and totalFlexGrow > 0 then
        -- Container has extra space - distribute according to flex-grow
        for _, child in ipairs(filteredChildren) do
            local grow = flexGrows[child]
            if grow > 0 then
                -- Calculate flex basis (never less than minWidth)
                local minWidth = minWidths[child]
                local flexWidth = floor((grow / totalFlexGrow) * availableSpace)
                
                -- Set calculated width, ensure it's at least 1
                child.set("width", max(flexWidth, 1))
            end
        end
    elseif availableSpace < 0 then
        -- Container doesn't have enough space - check for shrinkable items
        local totalFlexShrink = 0
        local shrinkableItems = {}
        
        -- Find shrinkable items
        for _, child in ipairs(filteredChildren) do
            local shrink = flexShrinks[child]
            if shrink > 0 then
                totalFlexShrink = totalFlexShrink + shrink
                table.insert(shrinkableItems, child)
            end
        end
        
        -- If we have shrinkable items, shrink them proportionally
        if totalFlexShrink > 0 and #shrinkableItems > 0 then
            local excessWidth = -availableSpace
            
            for _, child in ipairs(shrinkableItems) do
                local width = child.get("width")
                local shrink = flexShrinks[child]
                local proportion = shrink / totalFlexShrink
                local reduction = ceil(excessWidth * proportion)
                
                -- Ensure width doesn't go below 1
                child.set("width", max(1, width - reduction))
            end
        end
        
        -- Recalculate fixed widths after shrinking
        totalFixedWidth = 0
        for _, child in ipairs(filteredChildren) do
            totalFixedWidth = totalFixedWidth + child.get("width")
        end
        
        -- If we still have flex-grow items, ensure they have proportional space
        if totalFlexGrow > 0 then
            local growableItems = {}
            local totalGrowableInitialWidth = 0
            
            -- Find growable items
            for _, child in ipairs(filteredChildren) do
                if flexGrows[child] > 0 then
                    table.insert(growableItems, child)
                    totalGrowableInitialWidth = totalGrowableInitialWidth + child.get("width")
                end
            end
            
            -- Ensure flexGrow items get at least some width, even if space is tight
            if #growableItems > 0 and totalGrowableInitialWidth > 0 then
                -- Minimum guaranteed width for flex items (at least 20% of container)
                local minFlexSpace = max(floor(containerWidth * 0.2), #growableItems)
                
                -- Reserve space for flex items
                local reservedFlexSpace = min(minFlexSpace, containerWidth - totalSpacing)
                
                -- Distribute among flex items
                for _, child in ipairs(growableItems) do
                    local grow = flexGrows[child]
                    local proportion = grow / totalFlexGrow
                    local flexWidth = max(1, floor(reservedFlexSpace * proportion))
                    child.set("width", flexWidth)
                end
            end
        end
    end
    
    -- Step 3: Position elements (never allow overlapping)
    local currentX = 1
    
    -- Place all elements sequentially
    for _, child in ipairs(filteredChildren) do
        -- Apply X coordinate
        child.set("x", currentX)
        
        -- Apply Y coordinate (based on vertical alignment) ONLY if not in wrapped mode
        if not wrap then
            if alignItems == "stretch" then
                -- Vertical stretch to fill container, considering padding
                child.set("height", availableCrossAxisSpace)
                child.set("y", 1 + crossPadding)
            else
                local childHeight = child.get("height")
                local y = 1
                
                if alignItems == "flex-end" then
                    -- Bottom align
                    y = containerHeight - childHeight + 1
                elseif alignItems == "flex-center" or alignItems == "center" then
                    -- Center align
                    y = floor((containerHeight - childHeight) / 2) + 1
                end
                
                -- Ensure Y value is not less than 1
                child.set("y", max(1, y))
            end
        end
        
        -- Final safety check height doesn't exceed container - only for elements with flexShrink
        local bottomEdge = child.get("y") + child.get("height") - 1
        if bottomEdge > containerHeight and (child.get("flexShrink") or 0) > 0 then
            child.set("height", max(1, containerHeight - child.get("y") + 1))
        end
        
        -- Update position for next element - advance by element width + spacing
        currentX = currentX + child.get("width") + spacing
    end
    
    -- Apply justifyContent only if there's remaining space
    local lastChild = filteredChildren[#filteredChildren]
    local usedWidth = 0
    if lastChild then
        usedWidth = lastChild.get("x") + lastChild.get("width") - 1
    end
    
    local remainingSpace = containerWidth - usedWidth
    
    if remainingSpace > 0 then
        if justifyContent == "flex-end" then
            for _, child in ipairs(filteredChildren) do
                child.set("x", child.get("x") + remainingSpace)
            end
        elseif justifyContent == "flex-center" or justifyContent == "center" then
            local offset = floor(remainingSpace / 2)
            for _, child in ipairs(filteredChildren) do
                child.set("x", child.get("x") + offset)
            end
        end
    end
end

local function calculateColumn(self, children, spacing, justifyContent)
    -- Make a copy of children that filters out lineBreak elements
    local filteredChildren = {}
    for _, child in ipairs(children) do
        if child ~= lineBreakElement then
            table.insert(filteredChildren, child)
        end
    end
    
    -- Skip processing if no children
    if #filteredChildren == 0 then
        return
    end
    
    local containerWidth = self.get("width")
    local containerHeight = self.get("height")
    local alignItems = self.get("flexAlignItems")
    local crossPadding = self.get("flexCrossPadding")
    local wrap = self.get("flexWrap")
    
    -- Safety check
    if containerHeight <= 0 then return end
    
    -- Calculate available cross axis space (considering padding)
    local availableCrossAxisSpace = containerWidth - (crossPadding * 2)
    if availableCrossAxisSpace < 1 then
        availableCrossAxisSpace = containerWidth
        crossPadding = 0
    end
    
    -- Cache local variables to reduce function calls
    local max = math.max
    local min = math.min
    local floor = math.floor
    local ceil = math.ceil
    
    -- Categorize elements and calculate their minimal heights and flexibilities
    local totalFixedHeight = 0
    local totalFlexGrow = 0
    local minHeights = {}
    local flexGrows = {}
    local flexShrinks = {}
    
    -- First pass: collect fixed heights and flex properties
    for _, child in ipairs(filteredChildren) do
        local grow = child.get("flexGrow") or 0
        local shrink = child.get("flexShrink") or 0
        local height = child.get("height")
        
        -- Track element properties
        flexGrows[child] = grow
        flexShrinks[child] = shrink
        minHeights[child] = height
        
        -- Calculate total flex grow factor
        if grow > 0 then
            totalFlexGrow = totalFlexGrow + grow
        else
            -- If not flex grow, it's a fixed element
            totalFixedHeight = totalFixedHeight + height
        end
    end
    
    -- Calculate total spacing
    local elementsCount = #filteredChildren
    local totalSpacing = (elementsCount > 1) and ((elementsCount - 1) * spacing) or 0
    
    -- Calculate available space for flex items
    local availableSpace = containerHeight - totalFixedHeight - totalSpacing
    
    -- Second pass: distribute available space to flex-grow items
    if availableSpace > 0 and totalFlexGrow > 0 then
        -- Container has extra space - distribute according to flex-grow
        for _, child in ipairs(filteredChildren) do
            local grow = flexGrows[child]
            if grow > 0 then
                -- Calculate flex basis (never less than minHeight)
                local minHeight = minHeights[child]
                local flexHeight = floor((grow / totalFlexGrow) * availableSpace)
                
                -- Set calculated height, ensure it's at least 1
                child.set("height", max(flexHeight, 1))
            end
        end
    elseif availableSpace < 0 then
        -- Container doesn't have enough space - check for shrinkable items
        local totalFlexShrink = 0
        local shrinkableItems = {}
        
        -- Find shrinkable items
        for _, child in ipairs(filteredChildren) do
            local shrink = flexShrinks[child]
            if shrink > 0 then
                totalFlexShrink = totalFlexShrink + shrink
                table.insert(shrinkableItems, child)
            end
        end
        
        -- If we have shrinkable items, shrink them proportionally
        if totalFlexShrink > 0 and #shrinkableItems > 0 then
            local excessHeight = -availableSpace
            
            for _, child in ipairs(shrinkableItems) do
                local height = child.get("height")
                local shrink = flexShrinks[child]
                local proportion = shrink / totalFlexShrink
                local reduction = ceil(excessHeight * proportion)
                
                -- Ensure height doesn't go below 1
                child.set("height", max(1, height - reduction))
            end
        end
        
        -- Recalculate fixed heights after shrinking
        totalFixedHeight = 0
        for _, child in ipairs(filteredChildren) do
            totalFixedHeight = totalFixedHeight + child.get("height")
        end
        
        -- If we still have flex-grow items, ensure they have proportional space
        if totalFlexGrow > 0 then
            local growableItems = {}
            local totalGrowableInitialHeight = 0
            
            -- Find growable items
            for _, child in ipairs(filteredChildren) do
                if flexGrows[child] > 0 then
                    table.insert(growableItems, child)
                    totalGrowableInitialHeight = totalGrowableInitialHeight + child.get("height")
                end
            end
            
            -- Ensure flexGrow items get at least some height, even if space is tight
            if #growableItems > 0 and totalGrowableInitialHeight > 0 then
                -- Minimum guaranteed height for flex items (at least 20% of container)
                local minFlexSpace = max(floor(containerHeight * 0.2), #growableItems)
                
                -- Reserve space for flex items
                local reservedFlexSpace = min(minFlexSpace, containerHeight - totalSpacing)
                
                -- Distribute among flex items
                for _, child in ipairs(growableItems) do
                    local grow = flexGrows[child]
                    local proportion = grow / totalFlexGrow
                    local flexHeight = max(1, floor(reservedFlexSpace * proportion))
                    child.set("height", flexHeight)
                end
            end
        end
    end
    
    -- Step 3: Position elements (never allow overlapping)
    local currentY = 1
    
    -- Place all elements sequentially
    for _, child in ipairs(filteredChildren) do
        -- Apply Y coordinate
        child.set("y", currentY)
        
        -- Apply X coordinate (based on horizontal alignment)
        if not wrap then 
            if alignItems == "stretch" then
                -- Horizontal stretch to fill container, considering padding
                child.set("width", availableCrossAxisSpace)
                child.set("x", 1 + crossPadding)
            else
                local childWidth = child.get("width")
                local x = 1
                
                if alignItems == "flex-end" then
                    -- Right align
                    x = containerWidth - childWidth + 1
                elseif alignItems == "flex-center" or alignItems == "center" then
                    -- Center align
                    x = floor((containerWidth - childWidth) / 2) + 1
                end
                
                -- Ensure X value is not less than 1
                child.set("x", max(1, x))
            end
        end
        
        -- Final safety check width doesn't exceed container - only for elements with flexShrink
        local rightEdge = child.get("x") + child.get("width") - 1
        if rightEdge > containerWidth and (child.get("flexShrink") or 0) > 0 then
            child.set("width", max(1, containerWidth - child.get("x") + 1))
        end
        
        -- Update position for next element - advance by element height + spacing
        currentY = currentY + child.get("height") + spacing
    end
    
    -- Apply justifyContent only if there's remaining space
    local lastChild = filteredChildren[#filteredChildren]
    local usedHeight = 0
    if lastChild then
        usedHeight = lastChild.get("y") + lastChild.get("height") - 1
    end
    
    local remainingSpace = containerHeight - usedHeight
    
    if remainingSpace > 0 then
        if justifyContent == "flex-end" then
            for _, child in ipairs(filteredChildren) do
                child.set("y", child.get("y") + remainingSpace)
            end
        elseif justifyContent == "flex-center" or justifyContent == "center" then
            local offset = floor(remainingSpace / 2)
            for _, child in ipairs(filteredChildren) do
                child.set("y", child.get("y") + offset)
            end
        end
    end
end

-- Optimize updateLayout function
local function updateLayout(self, direction, spacing, justifyContent, wrap)
    if self.get("width") <= 0 or self.get("height") <= 0 then
        return
    end
    
    direction = (direction == "row" or direction == "column") and direction or "row"
    
    local currentWidth, currentHeight = self.get("width"), self.get("height")
    local sizeChanged = currentWidth ~= self._lastLayoutWidth or currentHeight ~= self._lastLayoutHeight
    
    self._lastLayoutWidth = currentWidth
    self._lastLayoutHeight = currentHeight
    
    if wrap and sizeChanged and (currentWidth > self._lastLayoutWidth or currentHeight > self._lastLayoutHeight) then
        for _, child in pairs(self.get("children")) do
            if child ~= lineBreakElement and child:getVisible() and child.get("flexGrow") and child.get("flexGrow") > 0 then
                if direction == "row" then
                    local ok, value = pcall(function() return child.get("intrinsicWidth") end)
                    if ok and value then
                        child.set("width", value)
                    end
                else
                    local ok, value = pcall(function() return child.get("intrinsicHeight") end)
                    if ok and value then
                        child.set("height", value)
                    end
                end
            end
        end
    end
    
    local elements = sortElements(self, direction, spacing, wrap)
    if #elements == 0 then return end
    
    local layoutFunction = direction == "row" and calculateRow or calculateColumn
    
    if direction == "row" and wrap then
        local currentY = 1
        for i, rowOrColumn in ipairs(elements) do
            if #rowOrColumn > 0 then
                for _, element in ipairs(rowOrColumn) do
                    if element ~= lineBreakElement then
                        element.set("y", currentY)
                    end
                end
                
                layoutFunction(self, rowOrColumn, spacing, justifyContent)
                
                local rowHeight = 0
                for _, element in ipairs(rowOrColumn) do
                    if element ~= lineBreakElement then
                        rowHeight = math.max(rowHeight, element.get("height"))
                    end
                end
                
                if i < #elements then
                    currentY = currentY + rowHeight + spacing
                else
                    currentY = currentY + rowHeight
                end
            end
        end
    elseif direction == "column" and wrap then
        local currentX = 1
        for i, rowOrColumn in ipairs(elements) do
            if #rowOrColumn > 0 then
                for _, element in ipairs(rowOrColumn) do
                    if element ~= lineBreakElement then
                        element.set("x", currentX)
                    end
                end
                
                layoutFunction(self, rowOrColumn, spacing, justifyContent)
                
                local columnWidth = 0
                for _, element in ipairs(rowOrColumn) do
                    if element ~= lineBreakElement then
                        columnWidth = math.max(columnWidth, element.get("width"))
                    end
                end
                
                if i < #elements then
                    currentX = currentX + columnWidth + spacing
                else
                    currentX = currentX + columnWidth
                end
            end
        end
    else
        for _, rowOrColumn in ipairs(elements) do
            layoutFunction(self, rowOrColumn, spacing, justifyContent)
        end
    end
    self:sortChildren()
    self.set("childrenEventsSorted", false)
    self.set("flexUpdateLayout", false)
end

--- @shortDescription Creates a new FlexBox instance
--- @return FlexBox object The newly created FlexBox instance
--- @private
function FlexBox.new()
    local self = setmetatable({}, FlexBox):__init()
    self.class = FlexBox
    self.set("width", 12)
    self.set("height", 6)
    self.set("background", colors.blue)
    self.set("z", 10)
    
    self._lastLayoutWidth = 0
    self._lastLayoutHeight = 0
    
    self:observe("width", function() self.set("flexUpdateLayout", true) end)
    self:observe("height", function() self.set("flexUpdateLayout", true) end)
    self:observe("flexDirection", function() self.set("flexUpdateLayout", true) end)
    self:observe("flexSpacing", function() self.set("flexUpdateLayout", true) end)
    self:observe("flexWrap", function() self.set("flexUpdateLayout", true) end)
    self:observe("flexJustifyContent", function() self.set("flexUpdateLayout", true) end)
    self:observe("flexAlignItems", function() self.set("flexUpdateLayout", true) end)
    self:observe("flexCrossPadding", function() self.set("flexUpdateLayout", true) end)

    return self
end

--- @shortDescription Initializes the FlexBox instance
--- @param props table The properties to initialize the element with
--- @param basalt table The basalt instance
--- @return FlexBox self The initialized instance
--- @protected
function FlexBox:init(props, basalt)
    Container.init(self, props, basalt)
    self.set("type", "FlexBox")
    return self
end

--- Adds a child element to the flexbox
--- @shortDescription Adds a child element to the flexbox
--- @param element Element The child element to add
--- @return FlexBox self The flexbox instance
function FlexBox:addChild(element)
    Container.addChild(self, element)

    if(element~=lineBreakElement)then
        element:instanceProperty("flexGrow", {default = 0, type = "number"})
        element:instanceProperty("flexShrink", {default = 0, type = "number"})
        element:instanceProperty("flexBasis", {default = 0, type = "number"})
        element:instanceProperty("intrinsicWidth", {default = element.get("width"), type = "number"})
        element:instanceProperty("intrinsicHeight", {default = element.get("height"), type = "number"})
        
        element:observe("flexGrow", function() self.set("flexUpdateLayout", true) end)
        element:observe("flexShrink", function() self.set("flexUpdateLayout", true) end)
        
        element:observe("width", function(_, newValue, oldValue) 
            if element.get("flexGrow") == 0 then 
                element.set("intrinsicWidth", newValue) 
            end
            self.set("flexUpdateLayout", true)
        end)
        element:observe("height", function(_, newValue, oldValue) 
            if element.get("flexGrow") == 0 then 
                element.set("intrinsicHeight", newValue) 
            end
            self.set("flexUpdateLayout", true)
        end)
    end

    self.set("flexUpdateLayout", true)
    return self
end

--- @shortDescription Removes a child element from the flexbox
--- @param element Element The child element to remove
--- @return FlexBox self The flexbox instance
--- @protected
function FlexBox:removeChild(element)
  Container.removeChild(self, element)

  if(element~=lineBreakElement)then
    element.setFlexGrow = nil
    element.setFlexShrink = nil
    element.setFlexBasis = nil
    element.getFlexGrow = nil
    element.getFlexShrink = nil
    element.getFlexBasis = nil
    element.set("flexGrow", nil)
    element.set("flexShrink", nil)
    element.set("flexBasis", nil)
  end

  self.set("flexUpdateLayout", true)
  return self
end

--- Adds a new line break to the flexbox
--- @shortDescription Adds a new line break to the flexbox.
---@param self FlexBox The element itself
---@return FlexBox
function FlexBox:addLineBreak()
  self:addChild(lineBreakElement)
  return self
end

--- @shortDescription Renders the flexbox and its children
--- @protected
function FlexBox:render()
  if(self.get("flexUpdateLayout"))then
    updateLayout(self, self.get("flexDirection"), self.get("flexSpacing"), self.get("flexJustifyContent"), self.get("flexWrap"))
  end
  Container.render(self)
end

return FlexBox end
project["elements/Container.lua"] = function(...) local elementManager = require("elementManager")
local errorManager = require("errorManager")
local VisualElement = elementManager.getElement("VisualElement")
local expect = require("libraries/expect")
local split = require("libraries/utils").split
---@configDescription The container class. It is a visual element that can contain other elements. It is the base class for all containers
---@configDefault true

--- A fundamental layout element that manages child UI components. Containers handle element organization, event propagation, 
--- rendering hierarchy, and coordinate space management. They serve as the backbone of Basalt's UI structure by providing:
--- - Child element management and organization
--- - Event bubbling and distribution
--- - Visibility calculations and clipping
--- - Focus management
--- - Coordinate space transformation
---@class Container : VisualElement
local Container = setmetatable({}, VisualElement)
Container.__index = Container

---@property children table {} Collection of all child elements
Container.defineProperty(Container, "children", {default = {}, type = "table"})
---@property childrenSorted boolean true Indicates if children are sorted by z-index
Container.defineProperty(Container, "childrenSorted", {default = true, type = "boolean"})
---@property childrenEventsSorted boolean true Indicates if event handlers are properly sorted
Container.defineProperty(Container, "childrenEventsSorted", {default = true, type = "boolean"})
---@property childrenEvents table {} Registered event handlers for all children
Container.defineProperty(Container, "childrenEvents", {default = {}, type = "table"})
---@property eventListenerCount table {} Number of listeners per event type
Container.defineProperty(Container, "eventListenerCount", {default = {}, type = "table"})
---@property focusedChild table nil Currently focused child element (receives keyboard events)
Container.defineProperty(Container, "focusedChild", {default = nil, type = "table", allowNil=true, setter = function(self, value, internal)
    local oldChild = self._values.focusedChild

    if value == oldChild then return value end

    if oldChild then
        if oldChild:isType("Container") then
            oldChild.set("focusedChild", nil, true)
        end
        oldChild.set("focused", false, true)
    end

    if value and not internal then
        value.set("focused", true, true)
        if self.parent then
            self.parent:setFocusedChild(self)
        end
    end

    return value
end})

---@property visibleChildren table {} Currently visible child elements (calculated based on viewport)
Container.defineProperty(Container, "visibleChildren", {default = {}, type = "table"})
---@property visibleChildrenEvents table {} Event handlers for currently visible children
Container.defineProperty(Container, "visibleChildrenEvents", {default = {}, type = "table"})

---@property offsetX number 0 Horizontal scroll/content offset
Container.defineProperty(Container, "offsetX", {default = 0, type = "number", canTriggerRender = true, setter=function(self, value)
    self.set("childrenSorted", false)
    self.set("childrenEventsSorted", false)
    return value
end})
---@property offsetY number 0 Vertical scroll/content offset
Container.defineProperty(Container, "offsetY", {default = 0, type = "number", canTriggerRender = true, setter=function(self, value)
    self.set("childrenSorted", false)
    self.set("childrenEventsSorted", false)
    return value
end})

---@combinedProperty offset {offsetX number, offsetY number} Combined property for offsetX and offsetY
Container.combineProperties(Container, "offset", "offsetX", "offsetY")

for k, _ in pairs(elementManager:getElementList()) do
    local capitalizedName = k:sub(1,1):upper() .. k:sub(2)
    if capitalizedName ~= "BaseFrame" then
        Container["add"..capitalizedName] = function(self, ...)
            expect(1, self, "table")
            local element = self.basalt.create(k, ...)
            self:addChild(element)
            element:postInit()
            return element
        end
        Container["addDelayed"..capitalizedName] = function(self, prop)
            expect(1, self, "table")
            local element = self.basalt.create(k, prop, true, self)
            return element
        end
    end
end

--- Creates a new Container instance
--- @shortDescription Creates a new Container instance
--- @return Container self The new container instance
--- @private
function Container.new()
    local self = setmetatable({}, Container):__init()
    self.class = Container
    return self
end

--- @shortDescription Initializes the Container instance
--- @param props table The properties to initialize the element with
--- @param basalt table The basalt instance
--- @protected
function Container:init(props, basalt)
    VisualElement.init(self, props, basalt)
    self.set("type", "Container")
    self:observe("width", function()
        self.set("childrenSorted", false)
        self.set("childrenEventsSorted", false)
    end)
    self:observe("height", function()
        self.set("childrenSorted", false)
        self.set("childrenEventsSorted", false)
    end)
end

--- Tests whether a child element is currently visible within the container's viewport
--- @shortDescription Checks if a child element is visible
--- @param child table The child element to check
--- @return boolean isVisible Whether the child is within view bounds
function Container:isChildVisible(child)
    if not child:isType("VisualElement") then return false end
    if(child.get("visible") == false)then return false end
    if(child._destroyed)then return false end
    local containerW, containerH = self.get("width"), self.get("height")
    local offsetX, offsetY = self.get("offsetX"), self.get("offsetY")

    local childX, childY = child.get("x"), child.get("y")
    local childW, childH = child.get("width"), child.get("height")

    local relativeX
    local relativeY
    if(child.get("ignoreOffset"))then
        relativeX = childX
        relativeY = childY
    else
        relativeX = childX - offsetX
        relativeY = childY - offsetY
    end

    return (relativeX + childW > 0) and
           (relativeX <= containerW) and
           (relativeY + childH > 0) and
           (relativeY <= containerH)
end

--- Adds a new element to this container's hierarchy
--- @shortDescription Adds a child element to the container
--- @param child table The element to add as a child
--- @return Container self For method chaining
function Container:addChild(child)
    if child == self then
        error("Cannot add container to itself")
    end
    if(child ~= nil)then
        table.insert(self._values.children, child)
        child.parent = self
        child:postInit()
        self.set("childrenSorted", false)
        self:registerChildrenEvents(child)
    end
    return self
end

local function sortAndFilterChildren(self, children)
    local visibleChildren = {}

    for _, child in ipairs(children) do
        if self:isChildVisible(child) and child.get("visible") and not child._destroyed then
            table.insert(visibleChildren, child)
        end
    end

    for i = 2, #visibleChildren do
        local current = visibleChildren[i]
        local currentZ = current.get("z")
        local j = i - 1
        while j > 0 do
            local compare = visibleChildren[j].get("z")
            if compare > currentZ then
                visibleChildren[j + 1] = visibleChildren[j]
                j = j - 1
            else
                break
            end
        end
        visibleChildren[j + 1] = current
    end

    return visibleChildren
end

--- Removes all child elements and resets the container's state
--- @shortDescription Removes all children and resets container
--- @return Container self For method chaining
function Container:clear()
    self.set("children", {})
    self.set("childrenEvents", {})
    self.set("visibleChildren", {})
    self.set("visibleChildrenEvents", {})
    self.set("childrenSorted", true)
    self.set("childrenEventsSorted", true)
    return self
end

--- Re-sorts children by their z-index and updates visibility
--- @shortDescription Updates child element ordering
--- @return Container self For method chaining
function Container:sortChildren()
    self.set("visibleChildren", sortAndFilterChildren(self, self._values.children))
    self.set("childrenSorted", true)
    return self
end

--- Sorts the children events of the container
--- @shortDescription Sorts the children events of the container
--- @param eventName string The event name to sort
--- @return Container self The container instance
function Container:sortChildrenEvents(eventName)
    if self._values.childrenEvents[eventName] then
        self._values.visibleChildrenEvents[eventName] = sortAndFilterChildren(self, self._values.childrenEvents[eventName])
    end
    self.set("childrenEventsSorted", true)
    return self
end

--- Registers the children events of the container
--- @shortDescription Registers the children events of the container
--- @param child table The child to register events for
--- @return Container self The container instance
function Container:registerChildrenEvents(child)
    if(child._registeredEvents == nil)then return end
    for event in pairs(child._registeredEvents) do
        self:registerChildEvent(child, event)
    end
    return self
end

--- Registers an event handler for a specific child element
--- @shortDescription Sets up event handling for a child
--- @param child table The child element to register events for
--- @param eventName string The name of the event to register
--- @return Container self For method chaining
function Container:registerChildEvent(child, eventName)
    if not self._values.childrenEvents[eventName] then
        self._values.childrenEvents[eventName] = {}
        self._values.eventListenerCount[eventName] = 0

        if self.parent then
            self.parent:registerChildEvent(self, eventName)
        end
    end

    for _, registeredChild in ipairs(self._values.childrenEvents[eventName]) do
        if registeredChild.get("id") == child.get("id") then
            return self
        end
    end

    self.set("childrenEventsSorted", false)
    table.insert(self._values.childrenEvents[eventName], child)
    self._values.eventListenerCount[eventName] = self._values.eventListenerCount[eventName] + 1
    return self
end

--- Unregisters the children events of the container
--- @shortDescription Unregisters the children events of the container
--- @param child table The child to unregister events for
--- @return Container self The container instance
function Container:removeChildrenEvents(child)
    if child ~= nil then
        if(child._registeredEvents == nil)then return self end
        for event in pairs(child._registeredEvents) do
            self:unregisterChildEvent(child, event)
        end
    end
    return self
end

--- Unregisters the children events of the container
--- @shortDescription Unregisters the children events of the container
--- @param child table The child to unregister events for
--- @param eventName string The event name to unregister
--- @return Container self The container instance
function Container:unregisterChildEvent(child, eventName)
    if self._values.childrenEvents[eventName] then
        for i, listener in ipairs(self._values.childrenEvents[eventName]) do
            if listener.get("id") == child.get("id") then
                table.remove(self._values.childrenEvents[eventName], i)
                self._values.eventListenerCount[eventName] = self._values.eventListenerCount[eventName] - 1

                if self._values.eventListenerCount[eventName] <= 0 then
                    self._values.childrenEvents[eventName] = nil
                    self._values.eventListenerCount[eventName] = nil

                    if self.parent then
                        self.parent:unregisterChildEvent(self, eventName)
                    end
                end
                self.set("childrenEventsSorted", false)
                self:updateRender()
                break
            end
        end
    end
    return self
end

--- Removes an element from this container's hierarchy and cleans up its events
--- @shortDescription Removes a child element from the container
--- @param child table The element to remove
--- @return Container self For method chaining
function Container:removeChild(child)
    if child == nil then return self end
    for i,v in ipairs(self._values.children) do
        if v.get("id") == child.get("id") then
            table.remove(self._values.children, i)
            child.parent = nil
            break
        end
    end
    self:removeChildrenEvents(child)
    self:updateRender()
    self.set("childrenSorted", false)
    return self
end

--- Locates a child element using a path-like syntax (e.g. "panel/button1")
--- @shortDescription Finds a child element by its path
--- @param path string Path to the child (e.g. "panel/button1", "header/title")
--- @return Element? child The found element or nil if not found
function Container:getChild(path)
    if type(path) == "string" then
        local parts = split(path, "/")
        for _,v in pairs(self._values.children) do
            if v.get("name") == parts[1] then
                if #parts == 1 then
                    return v
                else
                    if(v:isType("Container"))then
                       return v:find(table.concat(parts, "/", 2))
                    end
                end
            end
        end
    end
    return nil
end

local function convertMousePosition(self, event, ...)
    local args = {...}
    if event and event:find("mouse_") then
        local button, absX, absY = ...
        local xOffset, yOffset = self.get("offsetX"), self.get("offsetY")
        local relX, relY = self:getRelativePosition(absX + xOffset, absY + yOffset)
        args = {button, relX, relY}
    end
    return args
end

--- Calls a event on all children
--- @shortDescription Calls a event on all children
--- @param visibleOnly boolean Whether to only call the event on visible children
--- @param event string The event to call
--- @vararg any The event arguments
--- @return boolean handled Whether the event was handled
--- @return table? child The child that handled the event
function Container:callChildrenEvent(visibleOnly, event, ...)
    local children = visibleOnly and self.get("visibleChildrenEvents") or self.get("childrenEvents")
    if children[event] then
        local events = children[event]
        for i = #events, 1, -1 do
            local child = events[i]
            if(child:dispatchEvent(event, ...))then
                return true, child
            end
        end
    end
    if(children["*"])then
        local events = children["*"]
        for i = #events, 1, -1 do
            local child = events[i]
            if(child:dispatchEvent(event, ...))then
                return true, child
            end
        end
    end
    return false
end

--- @shortDescription Default handler for events
--- @param event string The event to handle
--- @vararg any The event arguments
--- @return boolean handled Whether the event was handled
--- @protected
function Container:handleEvent(event, ...)
    VisualElement.handleEvent(self, event, ...)
    local args = convertMousePosition(self, event, ...)
    return self:callChildrenEvent(false, event, table.unpack(args))
end

--- @shortDescription Handles mouse click events
--- @param button number The button that was clicked
--- @param x number The x position of the click
--- @param y number The y position of the click
--- @return boolean handled Whether the event was handled
--- @protected
function Container:mouse_click(button, x, y)
    if VisualElement.mouse_click(self, button, x, y) then
        local args = convertMousePosition(self, "mouse_click", button, x, y)
        local success, child = self:callChildrenEvent(true, "mouse_click", table.unpack(args))
        if(success)then
            self.set("focusedChild", child)
            return true
        end
        self.set("focusedChild", nil)
        return true
    end
    return false
end

--- @shortDescription Handles mouse up events
--- @param button number The button that was clicked
--- @param x number The x position of the click
--- @param y number The y position of the click
--- @return boolean handled Whether the event was handled
--- @protected
function Container:mouse_up(button, x, y)
    if VisualElement.mouse_up(self, button, x, y) then
        local args = convertMousePosition(self, "mouse_up", button, x, y)
        local success, child = self:callChildrenEvent(true, "mouse_up", table.unpack(args))
        if(success)then
            return true
        end
    end
    return false
end

--- @shortDescription Handles mouse release events
--- @param button number The button that was clicked
--- @param x number The x position of the click
--- @param y number The y position of the click
--- @protected
function Container:mouse_release(button, x, y)
    VisualElement.mouse_release(self, button, x, y)
    local args = convertMousePosition(self, "mouse_release", button, x, y)
    self:callChildrenEvent(false, "mouse_release", table.unpack(args))
end

--- @shortDescription Handles mouse move events
--- @param _ number unknown
--- @param x number The x position of the click
--- @param y number The y position of the click
--- @return boolean handled Whether the event was handled
--- @protected
function Container:mouse_move(_, x, y)
    if VisualElement.mouse_move(self, _, x, y) then
        local args = convertMousePosition(self, "mouse_move", _, x, y)
        local success, child = self:callChildrenEvent(true, "mouse_move", table.unpack(args))
        if(success)then
            return true
        end
    end
    return false
end

--- @shortDescription Handles mouse drag events
--- @param button number The button that was clicked
--- @param x number The x position of the click
--- @param y number The y position of the click
--- @return boolean handled Whether the event was handled
--- @protected
function Container:mouse_drag(button, x, y)
    if VisualElement.mouse_drag(self, button, x, y) then
        local args = convertMousePosition(self, "mouse_drag", button, x, y)
        local success, child = self:callChildrenEvent(true, "mouse_drag", table.unpack(args))
        if(success)then
            return true
        end
    end
    return false
end

--- @shortDescription Handles mouse scroll events
--- @param direction number The direction of the scroll
--- @param x number The x position of the click
--- @param y number The y position of the click
--- @return boolean handled Whether the event was handled
--- @protected
function Container:mouse_scroll(direction, x, y)
    if(VisualElement.mouse_scroll(self, direction, x, y))then
        local args = convertMousePosition(self, "mouse_scroll", direction, x, y)
        local success, child = self:callChildrenEvent(true, "mouse_scroll", table.unpack(args))
        return success
    end
    return false
end

--- @shortDescription Handles key events
--- @param key number The key that was pressed
--- @return boolean handled Whether the event was handled
--- @protected
function Container:key(key)
    if self.get("focusedChild") then
        return self.get("focusedChild"):dispatchEvent("key", key)
    end
    return true
end

--- @shortDescription Handles char events
--- @param char string The character that was pressed
--- @return boolean handled Whether the event was handled
--- @protected
function Container:char(char)
    if self.get("focusedChild") then
        return self.get("focusedChild"):dispatchEvent("char", char)
    end
    return true
end

--- @shortDescription Handles key up events
--- @param key number The key that was released
--- @return boolean handled Whether the event was handled
--- @protected
function Container:key_up(key)
    if self.get("focusedChild") then
        return self.get("focusedChild"):dispatchEvent("key_up", key)
    end
    return true
end

--- @shortDescription Draws multiple lines of text, fg and bg strings
--- @param x number The x position to draw the text
--- @param y number The y position to draw the text
--- @param width number The width of the text
--- @param height number The height of the text
--- @param text string The text to draw
--- @param fg string The foreground color of the text
--- @param bg string The background color of the text
--- @return Container self The container instance
--- @protected
function Container:multiBlit(x, y, width, height, text, fg, bg)
    local w, h = self.get("width"), self.get("height")
    
    width = x < 1 and math.min(width + x - 1, w) or math.min(width, math.max(0, w - x + 1))
    height = y < 1 and math.min(height + y - 1, h) or math.min(height, math.max(0, h - y + 1))

    if width <= 0 or height <= 0 then return self end

    VisualElement.multiBlit(self, math.max(1, x), math.max(1, y), width, height, text, fg, bg)
    return self
end

--- @shortDescription Draws a line of text and fg as color
--- @param x number The x position to draw the text
--- @param y number The y position to draw the text
--- @param text string The text to draw
--- @param fg color The foreground color of the text
--- @return Container self The container instance
--- @protected
function Container:textFg(x, y, text, fg)
    local w, h = self.get("width"), self.get("height")

    if y < 1 or y > h then return self end

    local textStart = x < 1 and (2 - x) or 1
    local textLen = math.min(#text - textStart + 1, w - math.max(1, x) + 1)

    if textLen <= 0 then return self end

    VisualElement.textFg(self, math.max(1, x), math.max(1, y), text:sub(textStart, textStart + textLen - 1), fg)
    return self
end

--- @shortDescription Draws a line of text and bg as color
--- @param x number The x position to draw the text
--- @param y number The y position to draw the text
--- @param text string The text to draw
--- @param bg color The background color of the text
--- @return Container self The container instance
--- @protected
function Container:textBg(x, y, text, bg)
    local w, h = self.get("width"), self.get("height")

    if y < 1 or y > h then return self end

    local textStart = x < 1 and (2 - x) or 1
    local textLen = math.min(#text - textStart + 1, w - math.max(1, x) + 1)

    if textLen <= 0 then return self end

    VisualElement.textBg(self, math.max(1, x), math.max(1, y), text:sub(textStart, textStart + textLen - 1), bg)
    return self
end

function Container:drawText(x, y, text)
    local w, h = self.get("width"), self.get("height")

    if y < 1 or y > h then return self end

    local textStart = x < 1 and (2 - x) or 1
    local textLen = math.min(#text - textStart + 1, w - math.max(1, x) + 1)

    if textLen <= 0 then return self end

    VisualElement.drawText(self, math.max(1, x), math.max(1, y), text:sub(textStart, textStart + textLen - 1))
    return self
end

function Container:drawFg(x, y, fg)
    local w, h = self.get("width"), self.get("height")

    if y < 1 or y > h then return self end

    local textStart = x < 1 and (2 - x) or 1
    local textLen = math.min(#fg - textStart + 1, w - math.max(1, x) + 1)
    if textLen <= 0 then return self end

    VisualElement.drawFg(self, math.max(1, x), math.max(1, y), fg:sub(textStart, textStart + textLen - 1))
    return self
end

function Container:drawBg(x, y, bg)
    local w, h = self.get("width"), self.get("height")

    if y < 1 or y > h then return self end

    local textStart = x < 1 and (2 - x) or 1
    local textLen = math.min(#bg - textStart + 1, w - math.max(1, x) + 1)
    if textLen <= 0 then return self end

    VisualElement.drawBg(self, math.max(1, x), math.max(1, y), bg:sub(textStart, textStart + textLen - 1))
    return self
end

--- @shortDescription Draws a line of text and fg and bg as colors
--- @param x number The x position to draw the text
--- @param y number The y position to draw the text
--- @param text string The text to draw
--- @param fg string The foreground color of the text
--- @param bg string The background color of the text
--- @return Container self The container instance
--- @protected
function Container:blit(x, y, text, fg, bg)
    local w, h = self.get("width"), self.get("height")

    if y < 1 or y > h then return self end

    local textStart = x < 1 and (2 - x) or 1
    local textLen = math.min(#text - textStart + 1, w - math.max(1, x) + 1)
    local fgLen = math.min(#fg - textStart + 1, w - math.max(1, x) + 1)
    local bgLen = math.min(#bg - textStart + 1, w - math.max(1, x) + 1)

    if textLen <= 0 then return self end

    local finalText = text:sub(textStart, textStart + textLen - 1)
    local finalFg = fg:sub(textStart, textStart + fgLen - 1)
    local finalBg = bg:sub(textStart, textStart + bgLen - 1)

    VisualElement.blit(self, math.max(1, x), math.max(1, y), finalText, finalFg, finalBg)
    return self
end

--- @shortDescription Renders the container
--- @protected
function Container:render()
    VisualElement.render(self)
    if not self.get("childrenSorted")then
        self:sortChildren()
    end
    if not self.get("childrenEventsSorted")then
        for event in pairs(self._values.childrenEvents) do
            self:sortChildrenEvents(event)
        end
    end
    for _, child in ipairs(self.get("visibleChildren")) do
        if child == self then
            errorManager.error("CIRCULAR REFERENCE DETECTED!")
            return
        end
        child:render()
        child:postRender()
    end
end


--- @private
function Container:destroy()
    if not self:isType("BaseFrame") then
        for _, child in ipairs(self._values.children) do
            if child.destroy then
                child:destroy()
            end
        end
        self:removeAllObservers()
        VisualElement.destroy(self)
        return self
    else
        errorManager.header = "Basalt Error"
        errorManager.error("Cannot destroy a BaseFrame.")
    end
end

return Container end
project["elements/ComboBox.lua"] = function(...) local VisualElement = require("elements/VisualElement")
local DropDown = require("elements/DropDown")
local tHex = require("libraries/colorHex")

---@configDescription A ComboBox that combines dropdown selection with editable text input
---@configDefault false

--- A hybrid input element that combines a text input field with a dropdown list. Users can either type directly or select from predefined options. 
--- Supports auto-completion, custom styling, and both single and multi-selection modes.
--- @usage -- Create a searchable country selector
--- @usage local combo = main:addComboBox()
--- @usage     :setPosition(5, 5)
--- @usage     :setSize(20, 1)  -- Height will expand when opened
--- @usage     :setItems({
--- @usage         {text = "Germany"},
--- @usage         {text = "France"},
--- @usage         {text = "Spain"},
--- @usage         {text = "Italy"}
--- @usage     })
--- @usage     :setPlaceholder("Select country...")
--- @usage     :setAutoComplete(true)  -- Enable filtering while typing
--- @usage 
--- @usage -- Handle selection changes
--- @usage combo:onChange(function(self, value)
--- @usage     -- value will be the selected country
--- @usage     basalt.debug("Selected:", value)
--- @usage end)
---@class ComboBox : DropDown
local ComboBox = setmetatable({}, DropDown)
ComboBox.__index = ComboBox

---@property editable boolean true Enables direct text input in the field
ComboBox.defineProperty(ComboBox, "editable", {default = true, type = "boolean", canTriggerRender = true})
---@property text string "" The current text value of the input field
ComboBox.defineProperty(ComboBox, "text", {default = "", type = "string", canTriggerRender = true})
---@property cursorPos number 1 Current cursor position in the text input
ComboBox.defineProperty(ComboBox, "cursorPos", {default = 1, type = "number"})
---@property viewOffset number 0 Horizontal scroll position for viewing long text
ComboBox.defineProperty(ComboBox, "viewOffset", {default = 0, type = "number", canTriggerRender = true})
---@property placeholder string "..." Text shown when the input is empty
ComboBox.defineProperty(ComboBox, "placeholder", {default = "...", type = "string"})
---@property placeholderColor color gray Color used for placeholder text
ComboBox.defineProperty(ComboBox, "placeholderColor", {default = colors.gray, type = "color"})
---@property focusedBackground color blue Background color when input is focused
ComboBox.defineProperty(ComboBox, "focusedBackground", {default = colors.blue, type = "color"})
---@property focusedForeground color white Text color when input is focused
ComboBox.defineProperty(ComboBox, "focusedForeground", {default = colors.white, type = "color"})
---@property autoComplete boolean false Enables filtering dropdown items while typing
ComboBox.defineProperty(ComboBox, "autoComplete", {default = false, type = "boolean"})
---@property manuallyOpened boolean false Indicates if dropdown was opened by user action
ComboBox.defineProperty(ComboBox, "manuallyOpened", {default = false, type = "boolean"})

--- Creates a new ComboBox instance
--- @shortDescription Creates a new ComboBox instance
--- @return ComboBox self The newly created ComboBox instance
function ComboBox.new()
    local self = setmetatable({}, ComboBox):__init()
    self.class = ComboBox
    self.set("width", 16)
    self.set("height", 1)
    self.set("z", 8)
    return self
end

--- @shortDescription Initializes the ComboBox instance
--- @param props table The properties to initialize the element with
--- @param basalt table The basalt instance
--- @return ComboBox self The initialized instance
--- @protected
function ComboBox:init(props, basalt)
    DropDown.init(self, props, basalt)
    self.set("type", "ComboBox")

    self.set("cursorPos", 1)
    self.set("viewOffset", 0)

    return self
end

--- Sets the text content of the ComboBox
--- @shortDescription Sets the text content
--- @param text string The text to set
--- @return ComboBox self
function ComboBox:setText(text)
    if text == nil then text = "" end
    self.set("text", tostring(text))
    self.set("cursorPos", #self.get("text") + 1)
    self:updateViewport()
    return self
end

--- Gets the current text content
--- @shortDescription Gets the text content
--- @return string text The current text
function ComboBox:getText()
    return self.get("text")
end

--- Sets whether the ComboBox is editable
--- @shortDescription Sets editable state
--- @param editable boolean Whether the ComboBox should be editable
--- @return ComboBox self
function ComboBox:setEditable(editable)
    self.set("editable", editable)
    return self
end

--- Filters items based on current text for auto-complete
--- @shortDescription Filters items for auto-complete
--- @private
function ComboBox:getFilteredItems()
    local allItems = self.get("items") or {}
    local currentText = self.get("text"):lower()

    if not self.get("autoComplete") or #currentText == 0 then
        return allItems
    end

    local filteredItems = {}
    for _, item in ipairs(allItems) do
        local itemText = ""
        if type(item) == "string" then
            itemText = item:lower()
        elseif type(item) == "table" and item.text then
            itemText = item.text:lower()
        end

        if itemText:find(currentText, 1, true) then
            table.insert(filteredItems, item)
        end
    end

    return filteredItems
end

--- Updates the dropdown with filtered items
--- @shortDescription Updates dropdown with filtered items
--- @private
function ComboBox:updateFilteredDropdown()
    if not self.get("autoComplete") then return end

    local filteredItems = self:getFilteredItems()
    local shouldOpen = #filteredItems > 0 and #self.get("text") > 0

    if shouldOpen then
        self.set("isOpen", true)
        self.set("manuallyOpened", false)
        local dropdownHeight = self.get("dropdownHeight") or 5
        local actualHeight = math.min(dropdownHeight, #filteredItems)
        self.set("height", 1 + actualHeight)
    else
        self.set("isOpen", false)
        self.set("manuallyOpened", false)
        self.set("height", 1)
    end
    self:updateRender()
end

--- @shortDescription Updates the viewport
--- @private
function ComboBox:updateViewport()
    local text = self.get("text")
    local cursorPos = self.get("cursorPos")
    local width = self.get("width")
    local dropSymbol = self.get("dropSymbol")

    local textWidth = width - #dropSymbol
    if textWidth < 1 then textWidth = 1 end

    local viewOffset = self.get("viewOffset")

    if cursorPos - viewOffset > textWidth then
        viewOffset = cursorPos - textWidth
    elseif cursorPos - 1 < viewOffset then
        viewOffset = math.max(0, cursorPos - 1)
    end

    self.set("viewOffset", viewOffset)
end

--- Handles character input when editable
--- @shortDescription Handles character input
--- @param char string The character that was typed
function ComboBox:char(char)
    if not self.get("editable") then return end
    if not self.get("focused") then return end

    local text = self.get("text")
    local cursorPos = self.get("cursorPos")

    local newText = text:sub(1, cursorPos - 1) .. char .. text:sub(cursorPos)
    self.set("text", newText)
    self.set("cursorPos", cursorPos + 1)
    self:updateViewport()

    if self.get("autoComplete") then
        self:updateFilteredDropdown()
    else
        self:updateRender()
    end
end

--- Handles key input when editable
--- @shortDescription Handles key input
--- @param key number The key code that was pressed
--- @param held boolean Whether the key is being held
function ComboBox:key(key, held)
    if not self.get("editable") then return end
    if not self.get("focused") then return end

    local text = self.get("text")
    local cursorPos = self.get("cursorPos")

    if key == keys.left then
        self.set("cursorPos", math.max(1, cursorPos - 1))
        self:updateViewport()
    elseif key == keys.right then
        self.set("cursorPos", math.min(#text + 1, cursorPos + 1))
        self:updateViewport()
    elseif key == keys.backspace then
        if cursorPos > 1 then
            local newText = text:sub(1, cursorPos - 2) .. text:sub(cursorPos)
            self.set("text", newText)
            self.set("cursorPos", cursorPos - 1)
            self:updateViewport()

            if self.get("autoComplete") then
                self:updateFilteredDropdown()
            else
                self:updateRender()
            end
        end
    elseif key == keys.delete then
        if cursorPos <= #text then
            local newText = text:sub(1, cursorPos - 1) .. text:sub(cursorPos + 1)
            self.set("text", newText)
            self:updateViewport()

            if self.get("autoComplete") then
                self:updateFilteredDropdown()
            else
                self:updateRender()
            end
        end
    elseif key == keys.home then
        self.set("cursorPos", 1)
        self:updateViewport()
    elseif key == keys["end"] then
        self.set("cursorPos", #text + 1)
        self:updateViewport()
    elseif key == keys.enter then
        self.set("isOpen", not self.get("isOpen"))
        self:updateRender()
    end
end

--- Handles mouse clicks
--- @shortDescription Handles mouse clicks
--- @param button number The mouse button (1 = left, 2 = right, 3 = middle)
--- @param x number The x coordinate of the click
--- @param y number The y coordinate of the click
--- @return boolean handled Whether the event was handled
--- @protected
function ComboBox:mouse_click(button, x, y)
    if not VisualElement.mouse_click(self, button, x, y) then return false end

    local relX, relY = self:getRelativePosition(x, y)
    local width = self.get("width")
    local dropSymbol = self.get("dropSymbol")

    if relY == 1 then
        if relX >= width - #dropSymbol + 1 and relX <= width then

            local isCurrentlyOpen = self.get("isOpen")
            self.set("isOpen", not isCurrentlyOpen)

            if self.get("isOpen") then
                local allItems = self.get("items") or {}
                local dropdownHeight = self.get("dropdownHeight") or 5
                local actualHeight = math.min(dropdownHeight, #allItems)
                self.set("height", 1 + actualHeight)
                self.set("manuallyOpened", true)
            else
                self.set("height", 1)
                self.set("manuallyOpened", false)
            end
            self:updateRender()
            return true
        end

        if relX <= width - #dropSymbol and self.get("editable") then
            local text = self.get("text")
            local viewOffset = self.get("viewOffset")
            local maxPos = #text + 1
            local targetPos = math.min(maxPos, viewOffset + relX)

            self.set("cursorPos", targetPos)
            self:updateRender()
            return true
        end

        return true
    elseif self.get("isOpen") and relY > 1 and self.get("selectable") then
        local itemIndex = (relY - 1) + self.get("offset")
        local items = self.get("items")

        if itemIndex <= #items then
            local item = items[itemIndex]
            if type(item) == "string" then
                item = {text = item}
                items[itemIndex] = item
            end

            if not self.get("multiSelection") then
                for _, otherItem in ipairs(items) do
                    if type(otherItem) == "table" then
                        otherItem.selected = false
                    end
                end
            end

            item.selected = true

            if item.text then
                self:setText(item.text)
            end
            self.set("isOpen", false)
            self.set("height", 1)
            self:updateRender()

            return true
        end
    end

    return false
end

--- Renders the ComboBox
--- @shortDescription Renders the ComboBox
function ComboBox:render()
    VisualElement.render(self)
    
    local text = self.get("text")
    local width = self.get("width")
    local dropSymbol = self.get("dropSymbol")
    local isFocused = self.get("focused")
    local isOpen = self.get("isOpen")
    local viewOffset = self.get("viewOffset")
    local placeholder = self.get("placeholder")

    local bg = isFocused and self.get("focusedBackground") or self.get("background")
    local fg = isFocused and self.get("focusedForeground") or self.get("foreground")

    local displayText = text
    local textWidth = width - #dropSymbol

    if #text == 0 and not isFocused and #placeholder > 0 then
        displayText = placeholder
        fg = self.get("placeholderColor")
    end

    if #displayText > 0 then
        displayText = displayText:sub(viewOffset + 1, viewOffset + textWidth)
    end

    displayText = displayText .. string.rep(" ", textWidth - #displayText)

    local fullText = displayText .. (isOpen and "\31" or "\17")

    self:blit(1, 1, fullText,
        string.rep(tHex[fg], width),
        string.rep(tHex[bg], width))

    if isFocused and self.get("editable") then
        local cursorPos = self.get("cursorPos")
        local cursorX = cursorPos - viewOffset
        if cursorX >= 1 and cursorX <= textWidth then
            self:setCursor(cursorX, 1, true, self.get("foreground"))
        end
    end

    if isOpen then
        local items
        if self.get("autoComplete") and not self.get("manuallyOpened") then
            items = self:getFilteredItems()
        else
            items = self.get("items")
        end

        local dropdownHeight = math.min(self.get("dropdownHeight"), #items)
        if dropdownHeight > 0 then
            local offset = self.get("offset")

            for i = 1, dropdownHeight do
                local itemIndex = i + offset
                if items[itemIndex] then
                    local item = items[itemIndex]
                    local itemText = item.text or ""
                    local isSelected = item.selected or false

                    local itemBg = isSelected and self.get("selectedBackground") or self.get("background")
                    local itemFg = isSelected and self.get("selectedForeground") or self.get("foreground")

                    if #itemText > width then
                        itemText = itemText:sub(1, width)
                    end

                    itemText = itemText .. string.rep(" ", width - #itemText)
                    self:blit(1, i + 1, itemText,
                        string.rep(tHex[itemFg], width),
                        string.rep(tHex[itemBg], width))
                end
            end
        end
    end
end

--- Called when the ComboBox gains focus
--- @shortDescription Called when gaining focus
function ComboBox:focus()
    DropDown.focus(self)
    -- Additional focus logic for input if needed
end

--- Called when the ComboBox loses focus
--- @shortDescription Called when losing focus
function ComboBox:blur()
    DropDown.blur(self)
    self.set("isOpen", false)
    self.set("height", 1)
    self:updateRender()
end

return ComboBox
 end
project["elements/Switch.lua"] = function(...) local elementManager = require("elementManager")
local VisualElement = elementManager.getElement("VisualElement")
local tHex = require("libraries/colorHex")
---@configDescription The Switch is a standard Switch element with click handling and state management.

--- The Switch is a standard Switch element with click handling and state management.
---@class Switch : VisualElement
local Switch = setmetatable({}, VisualElement)
Switch.__index = Switch

---@property checked boolean Whether switch is checked
Switch.defineProperty(Switch, "checked", {default = false, type = "boolean", canTriggerRender = true})
---@property text string Text to display next to switch
Switch.defineProperty(Switch, "text", {default = "", type = "string", canTriggerRender = true})
---@property autoSize boolean Whether to automatically size the element to fit switch and text
Switch.defineProperty(Switch, "autoSize", {default = false, type = "boolean"})
---@property onBackground number Background color when ON
Switch.defineProperty(Switch, "onBackground", {default = colors.green, type = "number", canTriggerRender = true})
---@property offBackground number Background color when OFF
Switch.defineProperty(Switch, "offBackground", {default = colors.red, type = "number", canTriggerRender = true})

Switch.defineEvent(Switch, "mouse_click")
Switch.defineEvent(Switch, "mouse_up")

--- @shortDescription Creates a new Switch instance
--- @return table self The created instance
--- @private
function Switch.new()
    local self = setmetatable({}, Switch):__init()
    self.class = Switch
    self.set("width", 2)
    self.set("height", 1)
    self.set("z", 5)
    self.set("backgroundEnabled", true)
    return self
end

--- @shortDescription Initializes the Switch instance
--- @param props table The properties to initialize the element with
--- @param basalt table The basalt instance
--- @protected
function Switch:init(props, basalt)
    VisualElement.init(self, props, basalt)
    self.set("type", "Switch")
end

--- @shortDescription Handles mouse click events
--- @param button number The button that was clicked
--- @param x number The x position of the click
--- @param y number The y position of the click
--- @return boolean Whether the event was handled
--- @protected
function Switch:mouse_click(button, x, y)
    if VisualElement.mouse_click(self, button, x, y) then
        self.set("checked", not self.get("checked"))
        return true
    end
    return false
end

--- @shortDescription Renders the Switch
--- @protected
function Switch:render()
    local checked = self.get("checked")
    local text = self.get("text")
    local switchWidth = self.get("width")
    local switchHeight = self.get("height")

    local bgColor = checked and self.get("onBackground") or self.get("offBackground")
    self:multiBlit(1, 1, switchWidth, switchHeight, " ", tHex[self.get("foreground")], tHex[bgColor])

    local sliderSize = math.floor(switchWidth / 2)
    local sliderStart = checked and (switchWidth - sliderSize + 1) or 1
    self:multiBlit(sliderStart, 1, sliderSize, switchHeight, " ", tHex[self.get("foreground")], tHex[self.get("background")])

    if text ~= "" then
        self:textFg(switchWidth + 2, 1, text, self.get("foreground"))
    end
end

return Switch
 end
project["main.lua"] = function(...) local elementManager = require("elementManager")
local errorManager = require("errorManager")
local propertySystem = require("propertySystem")
local expect = require("libraries/expect")

--- This is the UI Manager and the starting point for your project. The following functions allow you to influence the default behavior of Basalt.
---
--- Before you can access Basalt, you need to add the following code on top of your file:
--- @usage local basalt = require("basalt")
--- What this code does is it loads basalt into the project, and you can access it by using the variable defined as "basalt".
--- @class basalt
--- @field traceback boolean Whether to show a traceback on errors
--- @field _events table A table of events and their callbacks
--- @field _schedule function[] A table of scheduled functions
--- @field _eventQueue table A table of unfinished events
--- @field _plugins table A table of plugins
--- @field isRunning boolean Whether the Basalt runtime is active
--- @field LOGGER Log The logger instance
--- @field path string The path to the Basalt library
local basalt = {}
basalt.traceback = true
basalt._events = {}
basalt._schedule = {}
basalt._eventQueue = {}
basalt._plugins = {}
basalt.isRunning = false
basalt.LOGGER = require("log")
if(minified)then
    basalt.path = fs.getDir(shell.getRunningProgram())
else
    basalt.path = fs.getDir(select(2, ...))
end

local main = nil
local focusedFrame = nil
local activeFrames = {}
local _type = type

local lazyElements = {}
local lazyElementCount = 10
local lazyElementsTimer = 0
local isLazyElementsTimerActive = false

local function queueLazyElements()
    if(isLazyElementsTimerActive)then return end
    lazyElementsTimer = os.startTimer(0.2)
    isLazyElementsTimerActive = true
end

local function loadLazyElements(count)
    for _=1,count do
        local blueprint = lazyElements[1]
        if(blueprint)then
            blueprint:create()
        end
        table.remove(lazyElements, 1)
    end
end

local function lazyElementsEventHandler(event, timerId)
    if(event=="timer")then
        if(timerId==lazyElementsTimer)then
            loadLazyElements(lazyElementCount)
            isLazyElementsTimerActive = false
            lazyElementsTimer = 0
            if(#lazyElements>0)then
                queueLazyElements()
            end
            return true
        end
    end
end

--- Creates and returns a new UI element of the specified type.
--- @shortDescription Creates a new UI element
--- @param type string The type of element to create (e.g. "Button", "Label", "BaseFrame")
--- @param properties? string|table Optional name for the element or a table with properties to initialize the element with
--- @return table element The created element instance
--- @usage local button = basalt.create("Button")
function basalt.create(type, properties, lazyLoading, parent)
    if(_type(properties)=="string")then properties = {name=properties} end
    if(properties == nil)then properties = {name = type} end
    local elementClass = elementManager.getElement(type)
    if(lazyLoading)then
        local blueprint = propertySystem.blueprint(elementClass, properties, basalt, parent)
        table.insert(lazyElements, blueprint)
        queueLazyElements()
        return blueprint
    else
        local element = elementClass.new()
        element:init(properties, basalt)
        return element
    end
end

--- Creates and returns a new BaseFrame
--- @shortDescription Creates a new BaseFrame
--- @return BaseFrame BaseFrame The created frame instance
function basalt.createFrame()
    local frame = basalt.create("BaseFrame")
    frame:postInit()
    if(main==nil)then
        main = tostring(term.current())
        basalt.setActiveFrame(frame, true)
    end
    return frame
end

--- Returns the element manager instance
--- @shortDescription Returns the element manager
--- @return table ElementManager The element manager
function basalt.getElementManager()
    return elementManager
end

--- Returns the error manager instance
--- @shortDescription Returns the error manager
--- @return table ErrorManager The error manager
function basalt.getErrorManager()
    return errorManager
end

--- Gets or creates the main frame
--- @shortDescription Gets or creates the main frame
--- @return BaseFrame BaseFrame The main frame instance
function basalt.getMainFrame()
    local _main = tostring(term.current())
    if(activeFrames[_main] == nil)then
        main = _main
        basalt.createFrame()
    end
    return activeFrames[_main]
end

--- Sets the active frame
--- @shortDescription Sets the active frame
--- @param frame BaseFrame The frame to set as active
--- @param setActive? boolean Whether to set the frame as active (default: true)
function basalt.setActiveFrame(frame, setActive)
    local t = frame:getTerm()
    if(setActive==nil)then setActive = true end
    if(t~=nil)then
        activeFrames[tostring(t)] = setActive and frame or nil
        frame:updateRender()
    end
end

--- Returns the active frame
--- @shortDescription Returns the active frame
--- @param t? term The term to get the active frame for (default: current term)
--- @return BaseFrame? BaseFrame The frame to set as active
function basalt.getActiveFrame(t)
    if(t==nil)then t = term.current() end
    return activeFrames[tostring(t)]
end

--- Sets a frame as focused
--- @shortDescription Sets a frame as focused
--- @param frame BaseFrame The frame to set as focused
function basalt.setFocus(frame)
    if(focusedFrame==frame)then return end
    if(focusedFrame~=nil)then
        focusedFrame:dispatchEvent("blur")
    end
    focusedFrame = frame
    if(focusedFrame~=nil)then
        focusedFrame:dispatchEvent("focus")
    end
end

--- Returns the focused frame
--- @shortDescription Returns the focused frame
--- @return BaseFrame? BaseFrame The focused frame
function basalt.getFocus()
    return focusedFrame
end

--- Schedules a function to run in a coroutine
--- @shortDescription Schedules a function to run in a coroutine
--- @function scheduleUpdate
--- @param func function The function to schedule
--- @return thread func The scheduled function
function basalt.schedule(func)
    expect(1, func, "function")

    local co = coroutine.create(func)
    local ok, result = coroutine.resume(co)
    if(ok)then
        table.insert(basalt._schedule, {coroutine=co, filter=result})
    else
        errorManager.header = "Basalt Schedule Error"
        errorManager.error(result)
    end
    return co
end

--- Removes a scheduled update
--- @shortDescription Removes a scheduled update
--- @function removeSchedule
--- @param func thread The scheduled function to remove
--- @return boolean success Whether the scheduled function was removed
function basalt.removeSchedule(func)
    for i, v in ipairs(basalt._schedule) do
        if(v.coroutine==func)then
            table.remove(basalt._schedule, i)
            return true
        end
    end
    return false
end

local mouseEvents = {
    mouse_click = true,
    mouse_up = true,
    mouse_scroll = true,
    mouse_drag = true,
}

local keyEvents = {
    key = true,
    key_up = true,
    char = true,
}

local function updateEvent(event, ...)
    if(event=="terminate")then basalt.stop() return end
    if lazyElementsEventHandler(event, ...) then return end
    local args = {...}

    local function basaltEvent()
        if(mouseEvents[event])then
            if activeFrames[main] then
                activeFrames[main]:dispatchEvent(event, table.unpack(args))
            end
        elseif(keyEvents[event])then
            if(focusedFrame~=nil)then
                focusedFrame:dispatchEvent(event, table.unpack(args))
            end
        else
            for _, frame in pairs(activeFrames) do
                frame:dispatchEvent(event, table.unpack(args))
            end
            --activeFrames[main]:dispatchEvent(event, table.unpack(args)) -- continue here
        end
    end

    -- Main event coroutine system
    for k,v in pairs(basalt._eventQueue) do
        if coroutine.status(v.coroutine) == "suspended" then
            if v.filter == event or v.filter == nil then
                v.filter = nil
                local ok, result = coroutine.resume(v.coroutine, event, ...)
                if not ok then
                    errorManager.header = "Basalt Event Error"
                    errorManager.error(result)
                end
                v.filter = result
            end
        end
        if coroutine.status(v.coroutine) == "dead" then
            table.remove(basalt._eventQueue, k)
        end
    end

    local newEvent = {coroutine=coroutine.create(basaltEvent), filter=event}
    local ok, result = coroutine.resume(newEvent.coroutine, event, ...)
    if(not ok)then
        errorManager.header = "Basalt Event Error"
        errorManager.error(result)
    end
    if(result~=nil)then
        newEvent.filter = result
    end
    table.insert(basalt._eventQueue, newEvent)

    -- Schedule event coroutine system
    for _, func in ipairs(basalt._schedule) do
        if coroutine.status(func.coroutine)=="suspended" then
            if event==func.filter or func.filter==nil then
                func.filter = nil
                local ok, result = coroutine.resume(func.coroutine, event, ...)
                if(not ok)then
                    errorManager.header = "Basalt Schedule Error"
                    errorManager.error(result)
                end
                func.filter = result
            end
        end
        if(coroutine.status(func.coroutine)=="dead")then
            basalt.removeSchedule(func.coroutine)
        end
    end

    if basalt._events[event] then
        for _, callback in ipairs(basalt._events[event]) do
            callback(...)
        end
    end
end

local function renderFrames()
    for _, frame in pairs(activeFrames)do
        frame:render()
        frame:postRender()
    end
end

--- Runs basalt once, can be used to update the UI manually, but you have to feed it the events
--- @shortDescription Runs basalt once
--- @vararg any The event to run with
function basalt.update(...)
    local f = function(...)
        basalt.isRunning = true
        updateEvent(...)
        renderFrames()
    end
    local ok, err = pcall(f, ...)
    if not(ok)then
        errorManager.header = "Basalt Runtime Error"
        errorManager.error(err)
    end
    basalt.isRunning = false
end

--- Stops the Basalt runtime
--- @shortDescription Stops the Basalt runtime
function basalt.stop()
    basalt.isRunning = false
    term.clear()
    term.setCursorPos(1,1)
end

--- Starts the Basalt runtime
--- @shortDescription Starts the Basalt runtime
--- @param isActive? boolean Whether to start active (default: true)
function basalt.run(isActive)
    if(basalt.isRunning)then errorManager.error("Basalt is already running") end
    if(isActive==nil)then 
        basalt.isRunning = true
    else
        basalt.isRunning = isActive
    end
    local function f()
        renderFrames()
        while basalt.isRunning do
            updateEvent(os.pullEventRaw())
            if(basalt.isRunning)then
                renderFrames()
            end
        end
    end
    while basalt.isRunning do
        local ok, err = pcall(f)
        if not(ok)then
            errorManager.header = "Basalt Runtime Error"
            errorManager.error(err)
        end
    end
end

--- Returns an element's class without creating a instance
--- @shortDescription Returns an element class
--- @param name string The name of the element
--- @return table Element The element class
function basalt.getElementClass(name)
    return elementManager.getElement(name)
end

--- Returns a Plugin API
--- @shortDescription Returns a Plugin API
--- @param name string The name of the plugin
--- @return table Plugin The plugin API
function basalt.getAPI(name)
    return elementManager.getAPI(name)
end

--- Registers a callback function for a specific event
--- @shortDescription Registers an event callback
--- @param eventName string The name of the event to listen for (e.g. "mouse_click", "key", "timer")
--- @param callback function The callback function to execute when the event occurs
--- @usage basalt.onEvent("mouse_click", function(button, x, y) basalt.debug("Clicked at", x, y) end)
function basalt.onEvent(eventName, callback)
    expect(1, eventName, "string")
    expect(2, callback, "function")

    if not basalt._events[eventName] then
        basalt._events[eventName] = {}
    end

    table.insert(basalt._events[eventName], callback)
end

--- Removes a callback function for a specific event
--- @shortDescription Removes an event callback
--- @param eventName string The name of the event
--- @param callback function The callback function to remove
--- @return boolean success Whether the callback was found and removed
function basalt.removeEvent(eventName, callback)
    expect(1, eventName, "string")
    expect(2, callback, "function")

    if not basalt._events[eventName] then
        return false
    end

    for i, registeredCallback in ipairs(basalt._events[eventName]) do
        if registeredCallback == callback then
            table.remove(basalt._events[eventName], i)
            return true
        end
    end

    return false
end

--- Triggers a custom event and calls all registered callbacks
--- @shortDescription Triggers a custom event
--- @param eventName string The name of the event to trigger
--- @vararg any Arguments to pass to the event callbacks
--- @usage basalt.triggerEvent("custom_event", "data1", "data2")
function basalt.triggerEvent(eventName, ...)
    expect(1, eventName, "string")
    
    if basalt._events[eventName] then
        for _, callback in ipairs(basalt._events[eventName]) do
            local ok, err = pcall(callback, ...)
            if not ok then
                errorManager.header = "Basalt Event Callback Error"
                errorManager.error("Error in event callback for '" .. eventName .. "': " .. tostring(err))
            end
        end
    end
end

return basalt end
project["elements/Display.lua"] = function(...) local elementManager = require("elementManager")
local VisualElement = elementManager.getElement("VisualElement")
local getCenteredPosition = require("libraries/utils").getCenteredPosition
local deepcopy = require("libraries/utils").deepcopy
local colorHex = require("libraries/colorHex")
---@configDescription The Display is a special element which uses the CC Window API which you can use.
---@configDefault false

--- A specialized element that provides direct access to ComputerCraft's Window API. 
--- It acts as a canvas where you can use standard CC terminal operations, making it ideal for:
--- - Integration with existing CC programs and APIs
--- - Custom drawing operations
--- - Terminal emulation
--- - Complex text manipulation
--- The Display maintains its own terminal buffer and can be manipulated using familiar CC terminal methods.
--- @usage -- Create a display for a custom terminal
--- @usage local display = main:addDisplay()
--- @usage     :setSize(30, 10)
--- @usage     :setPosition(2, 2)
--- @usage
--- @usage -- Get the window object for CC API operations
--- @usage local win = display:getWindow()
--- @usage
--- @usage -- Use standard CC terminal operations
--- @usage win.setTextColor(colors.yellow)
--- @usage win.setBackgroundColor(colors.blue)
--- @usage win.clear()
--- @usage win.setCursorPos(1, 1)
--- @usage win.write("Hello World!")
--- @usage
--- @usage -- Or use the helper method
--- @usage display:write(1, 2, "Direct write", colors.red, colors.black)
--- @usage
--- @usage -- Useful for external APIs
--- @usage local paintutils = require("paintutils")
--- @usage paintutils.drawLine(1, 1, 10, 1, colors.red, win)
---@class Display : VisualElement
local Display = setmetatable({}, VisualElement)
Display.__index = Display

--- @shortDescription Creates a new Display instance
--- @return table self The created instance
--- @private
function Display.new()
    local self = setmetatable({}, Display):__init()
    self.class = Display
    self.set("width", 25)
    self.set("height", 8)
    self.set("z", 5)
    return self
end

--- @shortDescription Initializes the Display instance
--- @param props table The properties to initialize the element with
--- @param basalt table The basalt instance
--- @protected
function Display:init(props, basalt)
    VisualElement.init(self, props, basalt)
    self.set("type", "Display")
    self._window = window.create(basalt.getActiveFrame():getTerm(), 1, 1, self.get("width"), self.get("height"), false)
    local reposition = self._window.reposition
    local blit = self._window.blit
    local write = self._window.write
    self._window.reposition = function(x, y, width, height)
        self.set("x", x)
        self.set("y", y)
        self.set("width", width)
        self.set("height", height)
        reposition(1, 1, width, height)
    end

    self._window.getPosition = function(self)
        return self.get("x"), self.get("y")
    end

    self._window.setVisible = function(visible)
        self.set("visible", visible)
    end

    self._window.isVisible = function(self)
        return self.get("visible")
    end
    self._window.blit = function(x, y, text, fg, bg)
        blit(x, y, text, fg, bg)
        self:updateRender()
    end
    self._window.write = function(x, y, text)
        write(x, y, text)
        self:updateRender()
    end

    self:observe("width", function(self, width)
        local window = self._window
        if window then
            window.reposition(1, 1, width, self.get("height"))
        end
    end)
    self:observe("height", function(self, height)
        local window = self._window
        if window then
            window.reposition(1, 1, self.get("width"), height)
        end
    end)
end

--- Retrieves the underlying ComputerCraft window object
--- @shortDescription Gets the CC window instance
--- @return table window A CC window object with all standard terminal methods
function Display:getWindow()
    return self._window
end

--- Writes text directly to the display with optional colors
--- @shortDescription Writes colored text to the display
--- @param x number X position (1-based)
--- @param y number Y position (1-based)
--- @param text string Text to write
--- @param fg? colors Foreground color (optional)
--- @param bg? colors Background color (optional)
--- @return Display self For method chaining
function Display:write(x, y, text, fg, bg)
    local window = self._window
    if window then
        if fg then
            window.setTextColor(fg)
        end
        if bg then
            window.setBackgroundColor(bg)
        end
        window.setCursorPos(x, y)
        window.write(text)
    end
    self:updateRender()
    return self
end

--- @shortDescription Renders the Display
--- @protected
function Display:render()
    VisualElement.render(self)
    local window = self._window
    local _, height = window.getSize()
    if window then
        for y = 1, height do
            local text, fg, bg = window.getLine(y)
            self:blit(1, y, text, fg, bg)
        end
    end
end

return Display end
project["elements/Table.lua"] = function(...) local VisualElement = require("elements/VisualElement")
local tHex = require("libraries/colorHex")

--- This is the table class. It provides a sortable data grid with customizable columns,
--- row selection, and scrolling capabilities.
--- @usage local people = container:addTable():setWidth(40)
--- @usage people:setColumns({{name="Name",width=12}, {name="Age",width=10}, {name="Country",width=15}})
--- @usage people:setData({{"Alice", 30, "USA"}, {"Bob", 25, "UK"}})
---@class Table : VisualElement
local Table = setmetatable({}, VisualElement)
Table.__index = Table

---@property columns table {} List of column definitions with {name, width} properties
Table.defineProperty(Table, "columns", {default = {}, type = "table", canTriggerRender = true, setter=function(self, value)
    local t = {}
    for i, col in ipairs(value) do
        if type(col) == "string" then
            t[i] = {name = col, width = #col+1}
        elseif type(col) == "table" then
            t[i] = {
                name = col.name or "",
                width = col.width,  -- Can be number, "auto", or percentage like "30%"
                minWidth = col.minWidth or 3,
                maxWidth = col.maxWidth or nil
            }
        end
    end
    return t
end})
---@property data table {} The table data as array of row arrays
Table.defineProperty(Table, "data", {default = {}, type = "table", canTriggerRender = true, setter=function(self, value)
    self.set("scrollOffset", 0)
    self.set("selectedRow", nil)
    self.set("sortColumn", nil)
    self.set("sortDirection", "asc")
    return value
end})
---@property selectedRow number? nil Currently selected row index
Table.defineProperty(Table, "selectedRow", {default = nil, type = "number", canTriggerRender = true})
---@property headerColor color blue Color of the column headers
Table.defineProperty(Table, "headerColor", {default = colors.blue, type = "color"})
---@property selectedColor color lightBlue Background color of selected row
Table.defineProperty(Table, "selectedColor", {default = colors.lightBlue, type = "color"})
---@property gridColor color gray Color of grid lines
Table.defineProperty(Table, "gridColor", {default = colors.gray, type = "color"})
---@property sortColumn number? nil Currently sorted column index
Table.defineProperty(Table, "sortColumn", {default = nil, type = "number", canTriggerRender = true})
---@property sortDirection string "asc" Sort direction ("asc" or "desc")
Table.defineProperty(Table, "sortDirection", {default = "asc", type = "string", canTriggerRender = true})
---@property scrollOffset number 0 Current scroll position
Table.defineProperty(Table, "scrollOffset", {default = 0, type = "number", canTriggerRender = true})
---@property customSortFunction table {} Custom sort functions for columns
Table.defineProperty(Table, "customSortFunction", {default = {}, type = "table"})

Table.defineEvent(Table, "mouse_click")
Table.defineEvent(Table, "mouse_scroll")

--- Creates a new Table instance
--- @shortDescription Creates a new Table instance
--- @return Table self The newly created Table instance
--- @private
function Table.new()
    local self = setmetatable({}, Table):__init()
    self.class = Table
    self.set("width", 30)
    self.set("height", 10)
    self.set("z", 5)
    return self
end

--- @shortDescription Initializes the Table instance
--- @param props table The properties to initialize the element with
--- @param basalt table The basalt instance
--- @return Table self The initialized instance
--- @protected
function Table:init(props, basalt)
    VisualElement.init(self, props, basalt)
    self.set("type", "Table")
    return self
end

--- Adds a new column to the table
--- @shortDescription Adds a new column to the table
--- @param name string The name of the column
--- @param width number The width of the column
--- @return Table self The Table instance
function Table:addColumn(name, width)
    local columns = self.get("columns")
    table.insert(columns, {name = name, width = width})
    self.set("columns", columns)
    return self
end

--- Adds a new row of data to the table
--- @shortDescription Adds a new row of data to the table
--- @param ... any The data for the new row
--- @return Table self The Table instance
function Table:addData(...)
    local data = self.get("data")
    table.insert(data, {...})
    self.set("data", data)
    return self
end

--- Sets a custom sort function for a specific column
--- @shortDescription Sets a custom sort function for a column
--- @param columnIndex number The index of the column
--- @param sortFn function Function that takes (rowA, rowB) and returns comparison result
--- @return Table self The Table instance
function Table:setColumnSortFunction(columnIndex, sortFn)
    local customSorts = self.get("customSortFunction")
    customSorts[columnIndex] = sortFn
    self.set("customSortFunction", customSorts)
    return self
end

--- Adds data with both display and sort values
--- @shortDescription Adds formatted data with raw sort values
--- @param displayData table The formatted data for display
--- @param sortData table The raw data for sorting (optional)
--- @return Table self The Table instance
function Table:setFormattedData(displayData, sortData)
    local enrichedData = {}

    for i, row in ipairs(displayData) do
        local enrichedRow = {}
        for j, cell in ipairs(row) do
            enrichedRow[j] = cell
        end

        if sortData and sortData[i] then
            enrichedRow._sortValues = sortData[i]
        end

        table.insert(enrichedData, enrichedRow)
    end

    self.set("data", enrichedData)
    return self
end

--- Set data with automatic formatting
--- @shortDescription Sets table data with optional column formatters
--- @param rawData table The raw data array
--- @param formatters table Optional formatter functions for columns {[2] = function(value) return value end}
--- @return Table self The Table instance
function Table:setData(rawData, formatters)
    if not formatters then
        self.set("data", rawData)
        return self
    end

    local formattedData = {}
    for i, row in ipairs(rawData) do
        local formattedRow = {}
        for j, cell in ipairs(row) do
            if formatters[j] then
                formattedRow[j] = formatters[j](cell)
            else
                formattedRow[j] = cell
            end
        end
        table.insert(formattedData, formattedRow)
    end

    return self:setFormattedData(formattedData, rawData)
end

--- @shortDescription Calculates column widths for rendering
--- @param columns table The column definitions
--- @param totalWidth number The total available width
--- @return table The columns with calculated visibleWidth
--- @private
function Table:calculateColumnWidths(columns, totalWidth)
    local calculatedColumns = {}
    local remainingWidth = totalWidth
    local autoColumns = {}
    local fixedWidth = 0

    for i, col in ipairs(columns) do
        calculatedColumns[i] = {
            name = col.name,
            width = col.width,
            minWidth = col.minWidth or 3,
            maxWidth = col.maxWidth
        }
        if type(col.width) == "number" then
            calculatedColumns[i].visibleWidth = math.max(col.width, calculatedColumns[i].minWidth)
            if calculatedColumns[i].maxWidth then
                calculatedColumns[i].visibleWidth = math.min(calculatedColumns[i].visibleWidth, calculatedColumns[i].maxWidth)
            end
            remainingWidth = remainingWidth - calculatedColumns[i].visibleWidth
            fixedWidth = fixedWidth + calculatedColumns[i].visibleWidth
        elseif type(col.width) == "string" and col.width:match("%%$") then
            local percent = tonumber(col.width:match("(%d+)%%"))
            if percent then
                calculatedColumns[i].visibleWidth = math.floor(totalWidth * percent / 100)
                calculatedColumns[i].visibleWidth = math.max(calculatedColumns[i].visibleWidth, calculatedColumns[i].minWidth)
                if calculatedColumns[i].maxWidth then
                    calculatedColumns[i].visibleWidth = math.min(calculatedColumns[i].visibleWidth, calculatedColumns[i].maxWidth)
                end
                remainingWidth = remainingWidth - calculatedColumns[i].visibleWidth
                fixedWidth = fixedWidth + calculatedColumns[i].visibleWidth
            else
                table.insert(autoColumns, i)
            end
        else
            table.insert(autoColumns, i)
        end
    end

    if #autoColumns > 0 and remainingWidth > 0 then
        local autoWidth = math.floor(remainingWidth / #autoColumns)
        for _, colIndex in ipairs(autoColumns) do
            calculatedColumns[colIndex].visibleWidth = math.max(autoWidth, calculatedColumns[colIndex].minWidth)
            if calculatedColumns[colIndex].maxWidth then
                calculatedColumns[colIndex].visibleWidth = math.min(calculatedColumns[colIndex].visibleWidth, calculatedColumns[colIndex].maxWidth)
            end
        end
    end

    local totalCalculated = 0
    for i, col in ipairs(calculatedColumns) do
        totalCalculated = totalCalculated + (col.visibleWidth or 0)
    end

    if totalCalculated > totalWidth then
        local scale = totalWidth / totalCalculated
        for i, col in ipairs(calculatedColumns) do
            if col.visibleWidth then
                col.visibleWidth = math.max(1, math.floor(col.visibleWidth * scale))
            end
        end
    end

    return calculatedColumns
end

--- Sorts the table data by column
--- @shortDescription Sorts the table data by the specified column
--- @param columnIndex number The index of the column to sort by
--- @param fn function? Optional custom sorting function
--- @return Table self The Table instance
function Table:sortData(columnIndex, fn)
    local data = self.get("data")
    local direction = self.get("sortDirection")
    local customSorts = self.get("customSortFunction")

    local sortFn = fn or customSorts[columnIndex]

    if sortFn then
        table.sort(data, function(a, b)
            return sortFn(a, b, direction)
        end)
    else
        table.sort(data, function(a, b)
            if not a or not b then return false end

            local valueA, valueB

            if a._sortValues and a._sortValues[columnIndex] then
                valueA = a._sortValues[columnIndex]
            else
                valueA = a[columnIndex]
            end

            if b._sortValues and b._sortValues[columnIndex] then
                valueB = b._sortValues[columnIndex]
            else
                valueB = b[columnIndex]
            end

            if type(valueA) == "number" and type(valueB) == "number" then
                if direction == "asc" then
                    return valueA < valueB
                else
                    return valueA > valueB
                end
            else
                local strA = tostring(valueA or "")
                local strB = tostring(valueB or "")
                if direction == "asc" then
                    return strA < strB
                else
                    return strA > strB
                end
            end
        end)
    end
    return self
end

--- @shortDescription Handles header clicks for sorting and row selection
--- @param button number The button that was clicked
--- @param x number The x position of the click
--- @param y number The y position of the click
--- @return boolean handled Whether the event was handled
--- @protected
function Table:mouse_click(button, x, y)
    if not VisualElement.mouse_click(self, button, x, y) then return false end

    local relX, relY = self:getRelativePosition(x, y)

    if relY == 1 then
        local columns = self.get("columns")
        local width = self.get("width")
        local calculatedColumns = self:calculateColumnWidths(columns, width)

        local currentX = 1
        for i, col in ipairs(calculatedColumns) do
            local colWidth = col.visibleWidth or col.width or 10
            if relX >= currentX and relX < currentX + colWidth then
                if self.get("sortColumn") == i then
                    self.set("sortDirection", self.get("sortDirection") == "asc" and "desc" or "asc")
                else
                    self.set("sortColumn", i)
                    self.set("sortDirection", "asc")
                end
                self:sortData(i)
                break
            end
            currentX = currentX + colWidth
        end
    end

    if relY > 1 then
        local rowIndex = relY - 2 + self.get("scrollOffset")
        if rowIndex >= 0 and rowIndex < #self.get("data") then
            self.set("selectedRow", rowIndex + 1)
        end
    end

    return true
end

--- @shortDescription Handles scrolling through the table data
--- @param direction number The scroll direction (-1 up, 1 down)
--- @param x number The x position of the scroll
--- @param y number The y position of the scroll
--- @return boolean handled Whether the event was handled
--- @protected
function Table:mouse_scroll(direction, x, y)
    if(VisualElement.mouse_scroll(self, direction, x, y))then
        local data = self.get("data")
        local height = self.get("height")
        local visibleRows = height - 2
        local maxScroll = math.max(0, #data - visibleRows - 1)
        local newOffset = math.min(maxScroll, math.max(0, self.get("scrollOffset") + direction))

        self.set("scrollOffset", newOffset)
        return true
    end
    return false
end

--- @shortDescription Renders the table with headers, data and scrollbar
--- @protected
function Table:render()
    VisualElement.render(self)
    local columns = self.get("columns")
    local data = self.get("data")
    local selected = self.get("selectedRow")
    local sortCol = self.get("sortColumn")
    local scrollOffset = self.get("scrollOffset")
    local height = self.get("height")
    local width = self.get("width")

    local calculatedColumns = self:calculateColumnWidths(columns, width)

    local totalWidth = 0
    local lastVisibleColumn = #calculatedColumns
    for i, col in ipairs(calculatedColumns) do
        if totalWidth + col.visibleWidth > width then
            lastVisibleColumn = i - 1
            break
        end
        totalWidth = totalWidth + col.visibleWidth
    end

    local currentX = 1
    for i, col in ipairs(calculatedColumns) do
        if i > lastVisibleColumn then break end
        local text = col.name
        if i == sortCol then
            text = text .. (self.get("sortDirection") == "asc" and "\30" or "\31")
        end
        self:textFg(currentX, 1, text:sub(1, col.visibleWidth), self.get("headerColor"))
        currentX = currentX + col.visibleWidth
    end

    for y = 2, height do
        local rowIndex = y - 2 + scrollOffset
        local rowData = data[rowIndex + 1]

        if rowData and (rowIndex + 1) <= #data then
            currentX = 1
            local bg = (rowIndex + 1) == selected and self.get("selectedColor") or self.get("background")

            for i, col in ipairs(calculatedColumns) do
                if i > lastVisibleColumn then break end
                local cellText = tostring(rowData[i] or "")
                local paddedText = cellText .. string.rep(" ", col.visibleWidth - #cellText)
                if i < lastVisibleColumn then
                    paddedText = string.sub(paddedText, 1, col.visibleWidth - 1) .. " "
                end
                local finalText = string.sub(paddedText, 1, col.visibleWidth)
                local finalForeground = string.rep(tHex[self.get("foreground")], col.visibleWidth)
                local finalBackground = string.rep(tHex[bg], col.visibleWidth)

                self:blit(currentX, y, finalText, finalForeground, finalBackground)
                currentX = currentX + col.visibleWidth
            end
        else
            self:blit(1, y, string.rep(" ", self.get("width")),
                string.rep(tHex[self.get("foreground")], self.get("width")),
                string.rep(tHex[self.get("background")], self.get("width")))
        end
    end
end

return Table end
project["elements/BaseFrame.lua"] = function(...) local elementManager = require("elementManager")
local Container = elementManager.getElement("Container")
local errorManager = require("errorManager")
local Render = require("render")
---@configDescription This is the base frame class. It is the root element of all elements and the only element without a parent.


--- This is the root frame class that serves as the foundation for the UI hierarchy. It manages the rendering context and acts as the top-level container for all other elements. Unlike other elements, it renders directly to a terminal or monitor and does not require a parent element.
---@class BaseFrame : Container
---@field _render Render The render object
---@field _renderUpdate boolean Whether the render object needs to be updated
---@field _peripheralName string The name of a peripheral
local BaseFrame = setmetatable({}, Container)
BaseFrame.__index = BaseFrame

local function isPeripheral(t)
    local ok, result = pcall(function()
        return peripheral.getType(t)
    end)
    if ok then
        return true
    end
    return false
end

---@property term term|peripheral term.current() The terminal or (monitor) peripheral object to render to
BaseFrame.defineProperty(BaseFrame, "term", {default = nil, type = "table", setter = function(self, value)
    self._peripheralName = nil
    if self.basalt.getActiveFrame(self._values.term)==self then
        self.basalt.setActiveFrame(self, false)
    end
    if value == nil or value.setCursorPos == nil then
        return value
    end

    if(isPeripheral(value)) then
        self._peripheralName = peripheral.getName(value)
    end

    self._values.term = value
    if self.basalt.getActiveFrame(value) == nil then
        self.basalt.setActiveFrame(self)
    end

    self._render = Render.new(value)
    self._renderUpdate = true
    local width, height = value.getSize()
    self.set("width", width)
    self.set("height", height)
    return value
end})

--- Creates a new Frame instance
--- @shortDescription Creates a new Frame instance
--- @return BaseFrame object The newly created Frame instance
--- @usage local element = BaseFrame.new()
--- @private
function BaseFrame.new()
    local self = setmetatable({}, BaseFrame):__init()
    self.class = BaseFrame
    return self
end

--- @shortDescription Initializes the Frame instance
--- @param props table The properties to initialize the element with
--- @param basalt table The basalt instance
--- @return table self The initialized instance
--- @protected
function BaseFrame:init(props, basalt)
    Container.init(self, props, basalt)
    self.set("term", term.current())
    self.set("type", "BaseFrame")
    return self
end

--- @shortDescription Renders a multiBlit to the render Object
--- @param x number The x position to render to
--- @param y number The y position to render to
--- @param width number The width of the text
--- @param height number The height of the text
--- @param text string The text to render
--- @param fg string The foreground color
--- @param bg string The background color
--- @protected
function BaseFrame:multiBlit(x, y, width, height, text, fg, bg)
    if(x<1)then width = width + x - 1; x = 1 end
    if(y<1)then height = height + y - 1; y = 1 end
    self._render:multiBlit(x, y, width, height, text, fg, bg)
end

--- @shortDescription Renders a text with a foreground color to the render Object
--- @param x number The x position to render to
--- @param y number The y position to render to
--- @param text string The text to render
--- @param fg colors The foreground color
--- @protected
function BaseFrame:textFg(x, y, text, fg)
    if x < 1 then text = string.sub(text, 1 - x); x = 1 end
    self._render:textFg(x, y, text, fg)
end

--- @shortDescription Renders a text with a background color to the render Object
--- @param x number The x position to render to
--- @param y number The y position to render to
--- @param text string The text to render
--- @param bg colors The background color
--- @protected
function BaseFrame:textBg(x, y, text, bg)
    if x < 1 then text = string.sub(text, 1 - x); x = 1 end
    self._render:textBg(x, y, text, bg)
end

--- @shortDescription Draws plain text to the render Object
--- @param x number The x position to render to
--- @param y number The y position to render to
--- @param text string The text to render
--- @protected
function BaseFrame:drawText(x, y, text)
    if x < 1 then text = string.sub(text, 1 - x); x = 1 end
    self._render:text(x, y, text)
end

--- @shortDescription Draws a foreground color to the render Object
--- @param x number The x position to render to
--- @param y number The y position to render to
--- @param fg colors The foreground color
--- @protected
function BaseFrame:drawFg(x, y, fg)
    if x < 1 then fg = string.sub(fg, 1 - x); x = 1 end
    self._render:fg(x, y, fg)
end

--- @shortDescription Draws a background color to the render Object
--- @param x number The x position to render to
--- @param y number The y position to render to
--- @param bg colors The background color
--- @protected
function BaseFrame:drawBg(x, y, bg)
    if x < 1 then bg = string.sub(bg, 1 - x); x = 1 end
    self._render:bg(x, y, bg)
end

--- @shortDescription Renders a text with a foreground and background color to the render Object
--- @param x number The x position to render to
--- @param y number The y position to render to
--- @param text string The text to render
--- @param fg string The foreground color
--- @param bg string The background color
--- @protected
function BaseFrame:blit(x, y, text, fg, bg)
    if x < 1 then 
        text = string.sub(text, 1 - x)
        fg = string.sub(fg, 1 - x)
        bg = string.sub(bg, 1 - x)
        x = 1 end
    self._render:blit(x, y, text, fg, bg)
end

--- Sets the cursor position
--- @shortDescription Sets the cursor position
--- @param x number The x position to set the cursor to
--- @param y number The y position to set the cursor to
--- @param blink boolean Whether the cursor should blink
function BaseFrame:setCursor(x, y, blink, color)
    local _term = self.get("term")
    self._render:setCursor(x, y, blink, color)
end

--- @shortDescription Handles monitor touch events
--- @param name string The name of the monitor that was touched
--- @param x number The x position of the mouse
--- @param y number The y position of the mouse
--- @protected
function BaseFrame:monitor_touch(name, x, y)
    local _term = self.get("term")
    if _term == nil then return end
        if(isPeripheral(_term))then
        if self._peripheralName == name then
            self:mouse_click(1, x, y)
            self.basalt.schedule(function()
                sleep(0.1)
                self:mouse_up(1, x, y)
            end)
        end
    end
end

--- @shortDescription Handles mouse click events
--- @param button number The button that was clicked
--- @param x number The x position of the mouse
--- @param y number The y position of the mouse
--- @protected
function BaseFrame:mouse_click(button, x, y)
    Container.mouse_click(self, button, x, y)
    self.basalt.setFocus(self)
end

--- @shortDescription Handles mouse up events
--- @param button number The button that was released
--- @param x number The x position of the mouse
--- @param y number The y position of the mouse
--- @protected
function BaseFrame:mouse_up(button, x, y)
    Container.mouse_up(self, button, x, y)
    Container.mouse_release(self, button, x, y)
end

--- @shortDescription Resizes the Frame
--- @protected
function BaseFrame:term_resize()
    local width, height = self.get("term").getSize()
    if(width == self.get("width") and height == self.get("height")) then
        return
    end
    self.set("width", width)
    self.set("height", height)
    self._render:setSize(width, height)
    self._renderUpdate = true
end

--- @shortDescription Handles key events
--- @param key number The key that was pressed
--- @protected
function BaseFrame:key(key)
    self:fireEvent("key", key)
    Container.key(self, key)
end

--- @shortDescription Handles key up events
--- @param key number The key that was released
--- @protected
function BaseFrame:key_up(key)
    self:fireEvent("key_up", key)
    Container.key_up(self, key)
end

--- @shortDescription Handles character events
--- @param char string The character that was pressed
--- @protected
function BaseFrame:char(char)
    self:fireEvent("char", char)
    Container.char(self, char)
end

function BaseFrame:dispatchEvent(event, ...)
    local _term = self.get("term")
    if _term == nil then return end
    if(isPeripheral(_term))then
        if event == "mouse_click" then
            return
        end
    end
    Container.dispatchEvent(self, event, ...)
end

--- @shortDescription Renders the Frame
--- @protected
function BaseFrame:render()
    if(self._renderUpdate) then
        if self._render ~= nil then
            Container.render(self)
            self._render:render()
            self._renderUpdate = false
        end
    end
end

return BaseFrame end
project["elements/BaseElement.lua"] = function(...) local PropertySystem = require("propertySystem")
local uuid = require("libraries/utils").uuid
local errorManager = require("errorManager")
---@configDescription The base class for all UI elements in Basalt.

--- The fundamental base class for all UI elements in Basalt. It implements core functionality like event handling, property management, lifecycle hooks, and the observer pattern. Every UI component inherits from this class to ensure consistent behavior and interface.
--- @class BaseElement : PropertySystem
local BaseElement = setmetatable({}, PropertySystem)
BaseElement.__index = BaseElement

--- @property type string BaseElement A hierarchical identifier of the element's type chain
BaseElement.defineProperty(BaseElement, "type", {default = {"BaseElement"}, type = "string", setter=function(self, value)
    if type(value) == "string" then
        table.insert(self._values.type, 1, value)
        return self._values.type
    end
    return value
end, getter = function(self, _, index)
    if index~= nil and index < 1 then
        return self._values.type
    end
    return self._values.type[index or 1]
end})

--- @property id string BaseElement Auto-generated unique identifier for element lookup
BaseElement.defineProperty(BaseElement, "id", {default = "", type = "string", readonly = true})

--- @property name string BaseElement User-defined name for the element
BaseElement.defineProperty(BaseElement, "name", {default = "", type = "string"})

--- @property eventCallbacks table BaseElement Collection of registered event handler functions
BaseElement.defineProperty(BaseElement, "eventCallbacks", {default = {}, type = "table"})

--- @property enabled boolean BaseElement Controls event processing for this element
BaseElement.defineProperty(BaseElement, "enabled", {default = true, type = "boolean" })

--- Registers a class-level event listener with optional dependency
--- @shortDescription Registers a new event listener for the element (on class level)
--- @param class table The class to register
--- @param eventName string The name of the event to register
--- @param requiredEvent? string The name of the required event (optional)
function BaseElement.defineEvent(class, eventName, requiredEvent)
    if not rawget(class, '_eventConfigs') then
        class._eventConfigs = {}
    end

    class._eventConfigs[eventName] = {
        requires = requiredEvent and requiredEvent or eventName
    }
end

--- Defines a class-level event callback method with automatic event registration
--- @shortDescription Registers a new event callback method with auto-registration
--- @param class table The class to register
--- @param callbackName string The name of the callback to register
--- @param ... string The names of the events to register the callback for
function BaseElement.registerEventCallback(class, callbackName, ...)
    local methodName = callbackName:match("^on") and callbackName or "on"..callbackName
    local events = {...}
    local mainEvent = events[1]

    class[methodName] = function(self, ...)
        for _, sysEvent in ipairs(events) do
            if not self._registeredEvents[sysEvent] then
                self:listenEvent(sysEvent, true)
            end
        end
        self:registerCallback(mainEvent, ...)
        return self
    end
end

--- @shortDescription Creates a new BaseElement instance
--- @return table The newly created BaseElement instance
--- @private
function BaseElement.new()
    local self = setmetatable({}, BaseElement):__init()
    self.class = BaseElement
    return self
end

--- @shortDescription Initializes the BaseElement instance
--- @param props table The properties to initialize the element with
--- @param basalt table The basalt instance
--- @return table self The initialized instance
--- @protected
function BaseElement:init(props, basalt)
    if self._initialized then
        return self
    end
    self._initialized = true
    self._props = props
    self._values.id = uuid()
    self.basalt = basalt
    self._registeredEvents = {}

    local currentClass = getmetatable(self).__index

    local events = {}
    currentClass = self.class

    while currentClass do
        if type(currentClass) == "table" and currentClass._eventConfigs then
            for eventName, config in pairs(currentClass._eventConfigs) do
                if not events[eventName] then
                    events[eventName] = config
                end
            end
        end
        currentClass = getmetatable(currentClass) and getmetatable(currentClass).__index
    end

    for eventName, config in pairs(events) do
        self._registeredEvents[config.requires] = true
    end

    if self._callbacks then
        for eventName, methodName in pairs(self._callbacks) do
            self[methodName] = function(self, ...)
                self:registerCallback(eventName, ...)
                return self
            end
        end
    end 

    return self
end

--- @shortDescription Post initialization
--- @return table self The BaseElement instance
--- @protected
function BaseElement:postInit()
    if self._postInitialized then
        return self
    end
    self._postInitialized = true
    if(self._props)then
        for k,v in pairs(self._props)do
            self.set(k, v)
        end
    end
    self._props = nil
    return self
end

--- Checks if the element matches or inherits from the specified type
--- @shortDescription Tests if element is of or inherits given type
--- @param type string The type to check for
--- @return boolean isType Whether the element is of the specified type
function BaseElement:isType(type)
    for _, t in ipairs(self._values.type) do
        if t == type then
            return true
        end
    end
    return false
end

--- Configures event listening behavior with automatic parent notification
--- @shortDescription Enables/disables event handling for this element
--- @param eventName string The name of the event to listen for
--- @param enable? boolean Whether to enable or disable the event (default: true)
--- @return table self The BaseElement instance
function BaseElement:listenEvent(eventName, enable)
    enable = enable ~= false
    if enable ~= (self._registeredEvents[eventName] or false) then
        if enable then
            self._registeredEvents[eventName] = true
            if self.parent then
                self.parent:registerChildEvent(self, eventName)
            end
        else
            self._registeredEvents[eventName] = nil
            if self.parent then
                self.parent:unregisterChildEvent(self, eventName)
            end
        end
    end
    return self
end

--- Adds an event handler function with automatic event registration
--- @shortDescription Registers a function to handle specific events
--- @param event string The event to register the callback for
--- @param callback function The callback function to register
--- @return table self The BaseElement instance
function BaseElement:registerCallback(event, callback)
    if not self._registeredEvents[event] then
        self:listenEvent(event, true)
    end

    if not self._values.eventCallbacks[event] then
        self._values.eventCallbacks[event] = {}
    end

    table.insert(self._values.eventCallbacks[event], callback)
    return self
end

--- Executes all registered callbacks for the specified event
--- @shortDescription Triggers event callbacks with provided arguments
--- @param event string The event to fire
--- @param ... any Additional arguments to pass to the callbacks
--- @return table self The BaseElement instance
function BaseElement:fireEvent(event, ...)
    if self.get("eventCallbacks")[event] then
        for _, callback in ipairs(self.get("eventCallbacks")[event]) do
            local result = callback(self, ...)
            return result
        end
    end
    return self
end

--- @shortDescription Handles all events
--- @param event string The event to handle
--- @vararg any The arguments for the event
--- @return boolean? handled Whether the event was handled
--- @protected
function BaseElement:dispatchEvent(event, ...)
    if self.get("enabled") == false then
        return false
    end
    if self[event] then
        return self[event](self, ...)
    end
    return self:handleEvent(event, ...)
end

--- @shortDescription The default event handler for all events
--- @param event string The event to handle
--- @vararg any The arguments for the event
--- @return boolean? handled Whether the event was handled
--- @protected
function BaseElement:handleEvent(event, ...)
    return false
end

--- Sets up a property change observer with immediate callback registration
--- @shortDescription Watches property changes with callback notification
--- @param property string The property to observe
--- @param callback function The callback to call when the property changes
--- @return table self The BaseElement instance
function BaseElement:onChange(property, callback)
    self:observe(property, callback)
    return self
end

--- Traverses parent chain to locate the root frame element
--- @shortDescription Retrieves the root frame of this element's tree
--- @return BaseFrame BaseFrame The base frame of the element
function BaseElement:getBaseFrame()
    if self.parent then
        return self.parent:getBaseFrame()
    end
    return self
end

--- Removes the element from UI tree and cleans up resources
--- @shortDescription Removes element and performs cleanup
function BaseElement:destroy()
    if(self.parent) then
        self.parent:removeChild(self)
    end
    self._destroyed = true
    self:removeAllObservers()
    self:setFocused(false)
end

--- Propagates render request up the element tree
--- @shortDescription Requests UI update for this element
--- @return table self The BaseElement instance
function BaseElement:updateRender()
    if(self.parent) then
        self.parent:updateRender()
    else
        self._renderUpdate = true
    end
    return self
end

return BaseElement end
project["libraries/colorHex.lua"] = function(...) local colorHex = {}

for i = 0, 15 do
    colorHex[2^i] = ("%x"):format(i)
    colorHex[("%x"):format(i)] = 2^i
end

return colorHex end
project["elements/Input.lua"] = function(...) local VisualElement = require("elements/VisualElement")
local tHex = require("libraries/colorHex")
---@configDescription A text input field with various features

--- This is the input class. It provides a text input field that can handle user input with various features like
--- cursor movement, text manipulation, placeholder text, and input validation.
---@class Input : VisualElement
local Input = setmetatable({}, VisualElement)
Input.__index = Input

---@property text string - The current text content of the input
Input.defineProperty(Input, "text", {default = "", type = "string", canTriggerRender = true})
---@property cursorPos number 1 The current cursor position in the text
Input.defineProperty(Input, "cursorPos", {default = 1, type = "number"})
---@property viewOffset number 0 The horizontal scroll offset for viewing long text
Input.defineProperty(Input, "viewOffset", {default = 0, type = "number", canTriggerRender = true})
---@property maxLength number? nil Maximum length of input text (optional)
Input.defineProperty(Input, "maxLength", {default = nil, type = "number"})
---@property placeholder string ... Text to display when input is empty
Input.defineProperty(Input, "placeholder", {default = "...", type = "string"})
---@property placeholderColor color gray Color of the placeholder text
Input.defineProperty(Input, "placeholderColor", {default = colors.gray, type = "color"})
---@property focusedBackground color blue Background color when input is focused
Input.defineProperty(Input, "focusedBackground", {default = colors.blue, type = "color"})
---@property focusedForeground color white Foreground color when input is focused
Input.defineProperty(Input, "focusedForeground", {default = colors.white, type = "color"})
---@property pattern string? nil Regular expression pattern for input validation
Input.defineProperty(Input, "pattern", {default = nil, type = "string"})
---@property cursorColor number nil Color of the cursor
Input.defineProperty(Input, "cursorColor", {default = nil, type = "number"})
---@property replaceChar string nil Character to replace the input with (for password fields)
Input.defineProperty(Input, "replaceChar", {default = nil, type = "string", canTriggerRender = true})

Input.defineEvent(Input, "mouse_click")
Input.defineEvent(Input, "key")
Input.defineEvent(Input, "char")
Input.defineEvent(Input, "paste")

--- @shortDescription Creates a new Input instance
--- @return Input object The newly created Input instance
--- @private
function Input.new()
    local self = setmetatable({}, Input):__init()
    self.class = Input
    self.set("width", 8)
    self.set("z", 3)
    return self
end

--- @shortDescription Initializes the Input instance
--- @param props table The properties to initialize the element with
--- @param basalt table The basalt instance
--- @return Input self The initialized instance
--- @protected
function Input:init(props, basalt)
    VisualElement.init(self, props, basalt)
    self.set("type", "Input")
    return self
end

--- Sets the cursor position and color
--- @shortDescription Sets the cursor position and color
--- @param x number The x position of the cursor
--- @param y number The y position of the cursor
--- @param blink boolean Whether the cursor should blink
--- @param color number The color of the cursor
function Input:setCursor(x, y, blink, color)
    x = math.min(self.get("width"), math.max(1, x))
    return VisualElement.setCursor(self, x, y, blink, color)
end

--- @shortDescription Handles char events
--- @param char string The character that was typed
--- @return boolean handled Whether the event was handled
--- @protected
function Input:char(char)
    if not self.get("focused") then return false end
    local text = self.get("text")
    local pos = self.get("cursorPos")
    local maxLength = self.get("maxLength")
    local pattern = self.get("pattern")

    if maxLength and #text >= maxLength then return false end
    if pattern and not char:match(pattern) then return false end

    self.set("text", text:sub(1, pos-1) .. char .. text:sub(pos))
    self.set("cursorPos", pos + 1)
    self:updateViewport()

    local relPos = self.get("cursorPos") - self.get("viewOffset")
    self:setCursor(relPos, 1, true, self.get("cursorColor") or self.get("foreground"))
    VisualElement.char(self, char)
    return true
end

--- @shortDescription Handles key events
--- @param key number The key that was pressed
--- @return boolean handled Whether the event was handled
--- @protected
function Input:key(key, held)
    if not self.get("focused") then return false end
    local pos = self.get("cursorPos")
    local text = self.get("text")
    local viewOffset = self.get("viewOffset")
    local width = self.get("width")

    if key == keys.left then
        if pos > 1 then
            self.set("cursorPos", pos - 1)
            if pos - 1 <= viewOffset then
                self.set("viewOffset", math.max(0, pos - 2))
            end
        end
    elseif key == keys.right then
        if pos <= #text then
            self.set("cursorPos", pos + 1)
            if pos - viewOffset >= width then
                self.set("viewOffset", pos - width + 1)
            end
        end
    elseif key == keys.backspace then
        if pos > 1 then
            self.set("text", text:sub(1, pos-2) .. text:sub(pos))
            self.set("cursorPos", pos - 1)
            self:updateRender()
            self:updateViewport()
        end
    end

    local relativePos = self.get("cursorPos") - self.get("viewOffset")
    self:setCursor(relativePos, 1, true, self.get("cursorColor") or self.get("foreground"))
    VisualElement.key(self, key, held)
    return true
end

--- @shortDescription Handles mouse click events
--- @param button number The button that was clicked
--- @param x number The x position of the click
--- @param y number The y position of the click
--- @return boolean handled Whether the event was handled
--- @protected
function Input:mouse_click(button, x, y)
    if VisualElement.mouse_click(self, button, x, y) then
        local relX, relY = self:getRelativePosition(x, y)
        local text = self.get("text")
        local viewOffset = self.get("viewOffset")

        local maxPos = #text + 1
        local targetPos = math.min(maxPos, viewOffset + relX)

        self.set("cursorPos", targetPos)
        local visualX = targetPos - viewOffset
        self:setCursor(visualX, 1, true, self.get("cursorColor") or self.get("foreground"))

        return true
    end
    return false
end

--- Updates the input's viewport
--- @shortDescription Updates the input's viewport
--- @return Input self The updated instance
function Input:updateViewport()
    local width = self.get("width")
    local cursorPos = self.get("cursorPos")
    local viewOffset = self.get("viewOffset")
    local textLength = #self.get("text")

    if cursorPos - viewOffset >= width then
        self.set("viewOffset", cursorPos - width + 1)
    elseif cursorPos <= viewOffset then
        self.set("viewOffset", cursorPos - 1)
    end

    self.set("viewOffset", math.max(0, math.min(self.get("viewOffset"), textLength - width + 1)))

    return self
end

--- @shortDescription Handles a focus event
--- @protected
function Input:focus()
    VisualElement.focus(self)
    self:setCursor(self.get("cursorPos") - self.get("viewOffset"), 1, true, self.get("cursorColor") or self.get("foreground"))
    self:updateRender()
end

--- @shortDescription Handles a blur event
--- @protected
function Input:blur()
    VisualElement.blur(self)
    self:setCursor(1, 1, false, self.get("cursorColor") or self.get("foreground"))
    self:updateRender()
end

--- @shortDescription Handles paste events
--- @protected
function Input:paste(content)
    if not self.get("focused") then return false end
    local text = self.get("text")
    local pos = self.get("cursorPos")
    local maxLength = self.get("maxLength")
    local pattern = self.get("pattern")
    local newText = text:sub(1, pos - 1) .. content .. text:sub(pos)
    if maxLength and #newText > maxLength then
        newText = newText:sub(1, maxLength)
    end
    if pattern and not newText:match(pattern) then
        return false
    end
    self.set("text", newText)
    self.set("cursorPos", pos + #content)
    self:updateViewport()
end

--- @shortDescription Renders the input element
--- @protected
function Input:render()
    local text = self.get("text")
    local viewOffset = self.get("viewOffset")
    local width = self.get("width")
    local placeholder = self.get("placeholder")
    local focusedBg = self.get("focusedBackground")
    local focusedFg = self.get("focusedForeground")
    local focused = self.get("focused")
    local width, height = self.get("width"), self.get("height")
    local replaceChar = self.get("replaceChar")
    self:multiBlit(1, 1, width, height, " ", tHex[focused and focusedFg or self.get("foreground")], tHex[focused and focusedBg or self.get("background")])

    if #text == 0 and #placeholder ~= 0 and self.get("focused") == false then
        self:textFg(1, 1, placeholder:sub(1, width), self.get("placeholderColor"))
        return
    end

    if(focused) then
        self:setCursor(self.get("cursorPos") - viewOffset, 1, true, self.get("cursorColor") or self.get("foreground"))
    end

    local visibleText = text:sub(viewOffset + 1, viewOffset + width)
    if replaceChar and #replaceChar > 0 then
        visibleText = replaceChar:rep(#visibleText)
    end
    self:textFg(1, 1, visibleText, self.get("foreground"))
end

return Input end
project["errorManager.lua"] = function(...) local LOGGER = require("log")

--- This is Basalt's error handler. All the errors are handled by this module.
--- @class ErrorHandler
--- @field tracebackEnabled boolean If the error handler should print a stack trace
--- @field header string The header of the error message
local errorHandler = {
    tracebackEnabled = true,
    header = "Basalt Error"
}

local function coloredPrint(message, color)
    term.setTextColor(color)
    print(message)
    term.setTextColor(colors.white)
end

--- Handles an error
--- @param errMsg string The error message
--- @usage errorHandler.error("An error occurred")
function errorHandler.error(errMsg)
    if errorHandler.errorHandled then
        error()
    end
    term.setBackgroundColor(colors.black)

    term.clear()
    term.setCursorPos(1, 1)

    coloredPrint(errorHandler.header..":", colors.red)
    print()

    local level = 2
    local topInfo
    while true do
        local info = debug.getinfo(level, "Sl")
        if not info then break end
        topInfo = info
        level = level + 1
    end
    local info = topInfo or debug.getinfo(2, "Sl")
    local fileName = info.source:sub(2)
    local lineNumber = info.currentline
    local errorMessage = errMsg

        if(errorHandler.tracebackEnabled)then
            local stackTrace = debug.traceback()
            if stackTrace then
                --coloredPrint("Stack traceback:", colors.gray)
                for line in stackTrace:gmatch("[^\r\n]+") do
                    local fileNameInTraceback, lineNumberInTraceback = line:match("([^:]+):(%d+):")
                    if fileNameInTraceback and lineNumberInTraceback then
                        term.setTextColor(colors.lightGray)
                        term.write(fileNameInTraceback)
                        term.setTextColor(colors.gray)
                        term.write(":")
                        term.setTextColor(colors.lightBlue)
                        term.write(lineNumberInTraceback)
                        term.setTextColor(colors.gray)
                        line = line:gsub(fileNameInTraceback .. ":" .. lineNumberInTraceback, "")
                    end
                    coloredPrint(line, colors.gray)
                end
                print()
            end
        end

    if fileName and lineNumber then
        term.setTextColor(colors.red)
        term.write("Error in ")
        term.setTextColor(colors.white)
        term.write(fileName)
        term.setTextColor(colors.red)
        term.write(":")
        term.setTextColor(colors.lightBlue)
        term.write(lineNumber)
        term.setTextColor(colors.red)
        term.write(": ")


        if errorMessage then
            errorMessage = string.gsub(errorMessage, "stack traceback:.*", "")
            if errorMessage ~= "" then
                coloredPrint(errorMessage, colors.red)
            else
                coloredPrint("Error message not available", colors.gray)
            end
        else
            coloredPrint("Error message not available", colors.gray)
        end

        local file = fs.open(fileName, "r")
        if file then
            local lineContent = ""
            local currentLineNumber = 1
            repeat
                lineContent = file.readLine()
                if currentLineNumber == tonumber(lineNumber) then
                    coloredPrint("\149Line " .. lineNumber, colors.cyan)
                    coloredPrint(lineContent, colors.lightGray)
                    break
                end
                currentLineNumber = currentLineNumber + 1
            until not lineContent
            file.close()
        end
    end

    term.setBackgroundColor(colors.black)
    LOGGER.error(errMsg)
    errorHandler.errorHandled = true
    error()
end

return errorHandler end
project["elements/ProgressBar.lua"] = function(...) local VisualElement = require("elements/VisualElement")
local tHex = require("libraries/colorHex")

--- This is the progress bar class. It provides a visual representation of progress
--- with optional percentage display and customizable colors.
--- @usage local progressBar = main:addProgressBar()
--- @usage progressBar:setDirection("up") 
--- @usage progressBar:setProgress(50)
---@class ProgressBar : VisualElement
local ProgressBar = setmetatable({}, VisualElement)
ProgressBar.__index = ProgressBar

---@property progress number 0 Current progress value (0-100)
ProgressBar.defineProperty(ProgressBar, "progress", {default = 0, type = "number", canTriggerRender = true})
---@property showPercentage boolean false Whether to show the percentage text in the center
ProgressBar.defineProperty(ProgressBar, "showPercentage", {default = false, type = "boolean"})
---@property progressColor color lime The color used for the filled portion of the progress bar
ProgressBar.defineProperty(ProgressBar, "progressColor", {default = colors.black, type = "color"})
---@property direction string right The direction of the progress bar ("up", "down", "left", "right")
ProgressBar.defineProperty(ProgressBar, "direction", {default = "right", type = "string"})

--- Creates a new ProgressBar instance
--- @shortDescription Creates a new ProgressBar instance
--- @return ProgressBar self The newly created ProgressBar instance
--- @private
function ProgressBar.new()
    local self = setmetatable({}, ProgressBar):__init()
    self.class = ProgressBar
    self.set("width", 25)
    self.set("height", 3)
    return self
end

--- @shortDescription Initializes the ProgressBar instance
--- @param props table The properties to initialize the element with
--- @param basalt table The basalt instance
--- @return ProgressBar self The initialized instance
--- @protected
function ProgressBar:init(props, basalt)
    VisualElement.init(self, props, basalt)
    self.set("type", "ProgressBar")
end

--- @shortDescription Renders the progress bar with filled portion and optional percentage text
--- @protected
function ProgressBar:render()
    VisualElement.render(self)
    local width = self.get("width")
    local height = self.get("height")
    local progress = math.min(100, math.max(0, self.get("progress")))
    local fillWidth = math.floor((width * progress) / 100)
    local fillHeight = math.floor((height * progress) / 100)
    local direction = self.get("direction")
    local progressColor = self.get("progressColor")

    if direction == "right" then
        self:multiBlit(1, 1, fillWidth, height, " ", tHex[self.get("foreground")], tHex[progressColor])
    elseif direction == "left" then
        self:multiBlit(width - fillWidth + 1, 1, fillWidth, height, " ", tHex[self.get("foreground")], tHex[progressColor])
    elseif direction == "up" then
        self:multiBlit(1, height - fillHeight + 1, width, fillHeight, " ", tHex[self.get("foreground")], tHex[progressColor])
    elseif direction == "down" then
        self:multiBlit(1, 1, width, fillHeight, " ", tHex[self.get("foreground")], tHex[progressColor])
    end

    if self.get("showPercentage") then
        local text = tostring(progress).."%"
        local x = math.floor((width - #text) / 2) + 1
        local y = math.floor((height - 1) / 2) + 1
        self:textFg(x, y, text, self.get("foreground"))
    end
end

return ProgressBar end
project["elements/Tree.lua"] = function(...) local VisualElement = require("elements/VisualElement")
local sub = string.sub
local tHex = require("libraries/colorHex")
---@cofnigDescription The tree element provides a hierarchical view of nodes that can be expanded and collapsed, with support for selection and scrolling.


--- This is the tree class. It provides a hierarchical view of nodes that can be expanded and collapsed,
--- with support for selection and scrolling.
---@class Tree : VisualElement
local Tree = setmetatable({}, VisualElement)
Tree.__index = Tree

---@property nodes table {} The tree structure containing node objects with {text, children} properties
Tree.defineProperty(Tree, "nodes", {default = {}, type = "table", canTriggerRender = true, setter = function(self, value)
    if #value > 0 then
        self.get("expandedNodes")[value[1]] = true
    end
    return value
end})
---@property selectedNode table? nil Currently selected node
Tree.defineProperty(Tree, "selectedNode", {default = nil, type = "table", canTriggerRender = true})
---@property expandedNodes table {} Table of nodes that are currently expanded
Tree.defineProperty(Tree, "expandedNodes", {default = {}, type = "table", canTriggerRender = true})
---@property scrollOffset number 0 Current vertical scroll position
Tree.defineProperty(Tree, "scrollOffset", {default = 0, type = "number", canTriggerRender = true})
---@property horizontalOffset number 0 Current horizontal scroll position
Tree.defineProperty(Tree, "horizontalOffset", {default = 0, type = "number", canTriggerRender = true})
---@property selectedForegroundColor color white foreground color of selected node
Tree.defineProperty(Tree, "selectedForegroundColor", {default = colors.white, type = "color"})
---@property selectedBackgroundColor color lightBlue background color of selected node
Tree.defineProperty(Tree, "selectedBackgroundColor", {default = colors.lightBlue, type = "color"})

Tree.defineEvent(Tree, "mouse_click")
Tree.defineEvent(Tree, "mouse_scroll")

--- Creates a new Tree instance
--- @shortDescription Creates a new Tree instance
--- @return Tree self The newly created Tree instance
--- @private
function Tree.new()
    local self = setmetatable({}, Tree):__init()
    self.class = Tree
    self.set("width", 30)
    self.set("height", 10)
    self.set("z", 5)
    return self
end

--- Initializes the Tree instance
--- @shortDescription Initializes the Tree instance
--- @param props table The properties to initialize the element with
--- @param basalt table The basalt instance
--- @return Tree self The initialized instance
--- @protected
function Tree:init(props, basalt)
    VisualElement.init(self, props, basalt)
    self.set("type", "Tree")
    return self
end

--- Expands a node
--- @shortDescription Expands a node to show its children
--- @param node table The node to expand
--- @return Tree self The Tree instance
function Tree:expandNode(node)
    self.get("expandedNodes")[node] = true
    self:updateRender()
    return self
end

--- Collapses a node
--- @shortDescription Collapses a node to hide its children
--- @param node table The node to collapse
--- @return Tree self The Tree instance
function Tree:collapseNode(node)
    self.get("expandedNodes")[node] = nil
    self:updateRender()
    return self
end

--- Toggles a node's expanded state
--- @shortDescription Toggles between expanded and collapsed state
--- @param node table The node to toggle
--- @return Tree self The Tree instance
function Tree:toggleNode(node)
    if self.get("expandedNodes")[node] then
        self:collapseNode(node)
    else
        self:expandNode(node)
    end
    return self
end

local function flattenTree(nodes, expandedNodes, level, result)
    result = result or {}
    level = level or 0

    for _, node in ipairs(nodes) do
        table.insert(result, {node = node, level = level})
        if expandedNodes[node] and node.children then
            flattenTree(node.children, expandedNodes, level + 1, result)
        end
    end
    return result
end

--- Handles mouse click events
--- @shortDescription Handles mouse click events for node selection and expansion
--- @param button number The button that was clicked
--- @param x number The x position of the click
--- @param y number The y position of the click
--- @return boolean handled Whether the event was handled
--- @protected
function Tree:mouse_click(button, x, y)
    if VisualElement.mouse_click(self, button, x, y) then
        local relX, relY = self:getRelativePosition(x, y)
        local flatNodes = flattenTree(self.get("nodes"), self.get("expandedNodes"))
        local visibleIndex = relY + self.get("scrollOffset")

        if flatNodes[visibleIndex] then
            local nodeInfo = flatNodes[visibleIndex]
            local node = nodeInfo.node

            if relX <= nodeInfo.level * 2 + 2 then
                self:toggleNode(node)
            end

            self.set("selectedNode", node)
            self:fireEvent("node_select", node)
        end
        return true
    end
    return false
end

--- Registers a callback for when a node is selected
--- @shortDescription Registers a callback for when a node is selected
--- @param callback function The callback function
--- @return Tree self The Tree instance
function Tree:onSelect(callback)
    self:registerCallback("node_select", callback)
    return self
end

--- @shortDescription Handles mouse scroll events for vertical scrolling
--- @param direction number The scroll direction (1 for up, -1 for down)
--- @param x number The x position of the scroll
--- @param y number The y position of the scroll
--- @return boolean handled Whether the event was handled
--- @protected
function Tree:mouse_scroll(direction, x, y)
    if VisualElement.mouse_scroll(self, direction, x, y) then
        local flatNodes = flattenTree(self.get("nodes"), self.get("expandedNodes"))
        local maxScroll = math.max(0, #flatNodes - self.get("height"))
        local newScroll = math.min(maxScroll, math.max(0, self.get("scrollOffset") + direction))

        self.set("scrollOffset", newScroll)
        return true
    end
    return false
end

--- Gets the size of the tree
--- @shortDescription Gets the size of the tree
--- @return number width The width of the tree
--- @return number height The height of the tree
function Tree:getNodeSize()
    local width, height = 0, 0
    local flatNodes = flattenTree(self.get("nodes"), self.get("expandedNodes"))
    for _, nodeInfo in ipairs(flatNodes) do
        width = math.max(width, nodeInfo.level + #nodeInfo.node.text)
    end
    height = #flatNodes
    return width, height
end

--- @shortDescription Renders the tree with nodes, selection and scrolling
--- @protected
function Tree:render()
    VisualElement.render(self)

    local flatNodes = flattenTree(self.get("nodes"), self.get("expandedNodes"))
    local height = self.get("height")
    local selectedNode = self.get("selectedNode")
    local expandedNodes = self.get("expandedNodes")
    local scrollOffset = self.get("scrollOffset")
    local horizontalOffset = self.get("horizontalOffset")

    for y = 1, height do
        local nodeInfo = flatNodes[y + scrollOffset]
        if nodeInfo then
            local node = nodeInfo.node
            local level = nodeInfo.level
            local indent = string.rep("  ", level)

            local symbol = " "
            if node.children and #node.children > 0 then
                symbol = expandedNodes[node] and "\31" or "\16"
            end

            local isSelected = node == selectedNode
            local _bg = isSelected and self.get("selectedBackgroundColor") or (node.background or node.bg or self.get("background"))
            local _fg = isSelected and self.get("selectedForegroundColor") or (node.foreground or node.fg or self.get("foreground"))

            local fullText = indent .. symbol .. " " .. (node.text or "Node")
            local text = sub(fullText, horizontalOffset + 1, horizontalOffset + self.get("width"))
            local paddedText = text .. string.rep(" ", self.get("width") - #text)

            local bg = tHex[_bg]:rep(#paddedText) or tHex[colors.black]:rep(#paddedText)
            local fg = tHex[_fg]:rep(#paddedText) or tHex[colors.white]:rep(#paddedText)

            self:blit(1, y, paddedText, fg, bg)
        else
            self:blit(1, y, string.rep(" ", self.get("width")), tHex[self.get("foreground")]:rep(self.get("width")), tHex[self.get("background")]:rep(self.get("width")))
        end
    end
end

return Tree end
project["elements/Graph.lua"] = function(...) local elementManager = require("elementManager")
local VisualElement = elementManager.getElement("VisualElement")
local tHex = require("libraries/colorHex")
---@configDescription A point based graph element
---@configDefault false

--- This is the base class for all graph elements. It is a point based graph.
--- @usage local graph = main:addGraph()
--- @usage :addSeries("input", " ", colors.green, colors.green, 10)
--- @usage :addSeries("output", " ", colors.red, colors.red, 10)
--- @usage 
--- @usage basalt.schedule(function()
--- @usage     while true do
--- @usage         graph:addPoint("input", math.random(1,100))
--- @usage         graph:addPoint("output", math.random(1,100))
--- @usage         sleep(2)
--- @usage     end
--- @usage end)
--- @class Graph : VisualElement
local Graph = setmetatable({}, VisualElement)
Graph.__index = Graph

---@property minValue number 0 The minimum value of the graph
Graph.defineProperty(Graph, "minValue", {default = 0, type = "number", canTriggerRender = true})
---@property maxValue number 100 The maximum value of the graph
Graph.defineProperty(Graph, "maxValue", {default = 100, type = "number", canTriggerRender = true})
---@property series table {} The series of the graph
Graph.defineProperty(Graph, "series", {default = {}, type = "table", canTriggerRender = true})

--- Creates a new Graph instance
--- @shortDescription Creates a new Graph instance
--- @return Graph self The newly created Graph instance
--- @private
function Graph.new()
    local self = setmetatable({}, Graph):__init()
    self.class = Graph
    return self
end

--- @shortDescription Initializes the Graph instance
--- @param props table The properties to initialize the element with
--- @param basalt table The basalt instance
--- @return Graph self The initialized instance
--- @protected
function Graph:init(props, basalt)
    VisualElement.init(self, props, basalt)
    self.set("type", "Graph")
    self.set("width", 20)
    self.set("height", 10)
    return self
end

--- @shortDescription Adds a series to the graph
--- @param name string The name of the series
--- @param symbol string The symbol of the series
--- @param bgCol number The background color of the series
--- @param fgCol number The foreground color of the series
--- @param pointCount number The number of points in the series
--- @return Graph self The graph instance
function Graph:addSeries(name, symbol, bgCol, fgCol, pointCount)
    local series = self.get("series")
    table.insert(series, {
        name = name,
        symbol = symbol or " ",
        bgColor = bgCol or colors.white,
        fgColor = fgCol or colors.black,
        pointCount = pointCount or self.get("width"),
        data = {},
        visible = true
    })
    self:updateRender()
    return self
end

--- @shortDescription Removes a series from the graph
--- @param name string The name of the series
--- @return Graph self The graph instance
function Graph:removeSeries(name)
    local series = self.get("series")
    for i, s in ipairs(series) do
        if s.name == name then
            table.remove(series, i)
            break
        end
    end
    self:updateRender()
    return self
end

--- @shortDescription Gets a series from the graph
--- @param name string The name of the series
--- @return table? series The series
function Graph:getSeries(name)
    local series = self.get("series")
    for _, s in ipairs(series) do
        if s.name == name then
            return s
        end
    end
    return nil
end

--- @shortDescription Changes the visibility of a series
--- @param name string The name of the series
--- @param visible boolean Whether the series should be visible
--- @return Graph self The graph instance
function Graph:changeSeriesVisibility(name, visible)
    local series = self.get("series")
    for _, s in ipairs(series) do
        if s.name == name then
            s.visible = visible
            break
        end
    end
    self:updateRender()
    return self
end

--- @shortDescription Adds a point to a series
--- @param name string The name of the series
--- @param value number The value of the point
--- @return Graph self The graph instance
function Graph:addPoint(name, value)
    local series = self.get("series")

    for _, s in ipairs(series) do
        if s.name == name then
            table.insert(s.data, value)
            while #s.data > s.pointCount do
                table.remove(s.data, 1)
            end
            break
        end
    end
    self:updateRender()
    return self
end

--- @shortDescription Focuses a series
--- @param name string The name of the series
--- @return Graph self The graph instance
function Graph:focusSeries(name)
    local series = self.get("series")
    for index, s in ipairs(series) do
        if s.name == name then
            table.remove(series, index)
            table.insert(series, s)
            break
        end
    end
    self:updateRender()
    return self
end

--- @shortDescription Sets the point count of a series
--- @param name string The name of the series
--- @param count number The number of points in the series
--- @return Graph self The graph instance
function Graph:setSeriesPointCount(name, count)
    local series = self.get("series")
    for _, s in ipairs(series) do
        if s.name == name then
            s.pointCount = count
            while #s.data > count do
                table.remove(s.data, 1)
            end
            break
        end
    end
    self:updateRender()
    return self
end

--- Clears all points from a series
--- @shortDescription Clears all points from a series
--- @param name? string The name of the series
--- @return Graph self The graph instance
function Graph:clear(seriesName)
    local series = self.get("series")
    if seriesName then
        for _, s in ipairs(series) do
            if s.name == seriesName then
                s.data = {}
                break
            end
        end
    else
        for _, s in ipairs(series) do
            s.data = {}
        end
    end
    return self
end

--- @shortDescription Renders the graph
--- @protected
function Graph:render()
    VisualElement.render(self)

    local width = self.get("width")
    local height = self.get("height")
    local minVal = self.get("minValue")
    local maxVal = self.get("maxValue")
    local series = self.get("series")

    for _, s in pairs(series) do
        if(s.visible)then
            local dataCount = #s.data
            local spacing = (width - 1) / math.max((dataCount - 1), 1)

            for i, value in ipairs(s.data) do
                local x = math.floor(((i-1) * spacing) + 1)

                local normalizedValue = (value - minVal) / (maxVal - minVal)
                local y = math.floor(height - (normalizedValue * (height-1)))
                y = math.max(1, math.min(y, height))

                self:blit(x, y, s.symbol, tHex[s.bgColor], tHex[s.fgColor])
            end
        end
    end
end

return Graph end
project["elements/Button.lua"] = function(...) local elementManager = require("elementManager")
local VisualElement = elementManager.getElement("VisualElement")
local getCenteredPosition = require("libraries/utils").getCenteredPosition
---@configDescription The Button is a standard button element with click handling and state management.

--- A clickable interface element that triggers actions when pressed. Supports text labels, custom styling, and automatic text centering. Commonly used for user interactions and form submissions.
--- @usage -- Create a simple action button
--- @usage local button = parent:addButton()
--- @usage     :setPosition(5, 5)
--- @usage     :setText("Click me!")
--- @usage     :setBackground(colors.blue)
--- @usage     :setForeground(colors.white)
--- @usage
--- @usage -- Add click handling
--- @usage button:onClick(function(self, button, x, y)
--- @usage     -- Change appearance when clicked
--- @usage     self:setBackground(colors.green)
--- @usage     self:setText("Success!")
--- @usage     
--- @usage     -- Revert after delay
--- @usage     basalt.schedule(function()
--- @usage         sleep(1)
--- @usage         self:setBackground(colors.blue)
--- @usage         self:setText("Click me!")
--- @usage     end)
--- @usage end)
---@class Button : VisualElement
local Button = setmetatable({}, VisualElement)
Button.__index = Button

---@property text string Button Label text displayed centered within the button
Button.defineProperty(Button, "text", {default = "Button", type = "string", canTriggerRender = true})

Button.defineEvent(Button, "mouse_click")
Button.defineEvent(Button, "mouse_up")

--- @shortDescription Creates a new Button instance
--- @return table self The created instance
--- @private
function Button.new()
    local self = setmetatable({}, Button):__init()
    self.class = Button
    self.set("width", 10)
    self.set("height", 3)
    self.set("z", 5)
    return self
end

--- @shortDescription Initializes the Button instance
--- @param props table The properties to initialize the element with
--- @param basalt table The basalt instance
--- @protected
function Button:init(props, basalt)
    VisualElement.init(self, props, basalt)
    self.set("type", "Button")
end

--- @shortDescription Renders the Button
--- @protected
function Button:render()
    VisualElement.render(self)
    local text = self.get("text")
    text = text:sub(1, self.get("width"))
    local xO, yO = getCenteredPosition(text, self.get("width"), self.get("height"))
    self:textFg(xO, yO, text, self.get("foreground"))
end

return Button end
project["elements/Frame.lua"] = function(...) local elementManager = require("elementManager")
local VisualElement = elementManager.getElement("VisualElement")
local Container = elementManager.getElement("Container")
---@configDescription A frame element that serves as a grouping container for other elements.

--- This is the frame class. It serves as a grouping container for other elements.
---@class Frame : Container
local Frame = setmetatable({}, Container)
Frame.__index = Frame

---@property draggable boolean false Whether the frame is draggable
Frame.defineProperty(Frame, "draggable", {default = false, type = "boolean", setter=function(self, value)
    if value then
        self:listenEvent("mouse_click", true)
        self:listenEvent("mouse_up", true)
        self:listenEvent("mouse_drag", true)
    end
    return value
end})
---@property draggingMap table {} The map of dragging positions
Frame.defineProperty(Frame, "draggingMap", {default = {{x=1, y=1, width="width", height=1}}, type = "table"})
---@property scrollable boolean false Whether the frame is scrollable
Frame.defineProperty(Frame, "scrollable", {default = false, type = "boolean", setter=function(self, value)
    if value then
        self:listenEvent("mouse_scroll", true)
    end
    return value
end})

--- Creates a new Frame instance
--- @shortDescription Creates a new Frame instance
--- @return Frame self The newly created Frame instance
--- @private
function Frame.new()
    local self = setmetatable({}, Frame):__init()
    self.class = Frame
    self.set("width", 12)
    self.set("height", 6)
    self.set("background", colors.gray)
    self.set("z", 10)
    return self
end

--- @shortDescription Initializes the Frame instance
--- @param props table The properties to initialize the element with
--- @param basalt table The basalt instance
--- @return Frame self The initialized instance
--- @protected
function Frame:init(props, basalt)
    Container.init(self, props, basalt)
    self.set("type", "Frame")
    return self
end

--- @shortDescription Handles mouse click events
--- @param button number The button that was clicked
--- @param x number The x position of the click
--- @param y number The y position of the click
--- @return boolean handled Whether the event was handled
--- @protected
function Frame:mouse_click(button, x, y)
    if VisualElement.mouse_click(self, button, x, y) then
        if self.get("draggable") then
            local relX, relY = self:getRelativePosition(x, y)
            local draggingMap = self.get("draggingMap")

            for _, map in ipairs(draggingMap) do
                local width = map.width or 1
                local height = map.height or 1

                if type(width) == "string" and width == "width" then
                    width = self.get("width")
                elseif type(width) == "function" then
                    width = width(self)
                end
                if type(height) == "string" and height == "height" then
                    height = self.get("height")
                elseif type(height) == "function" then
                    height = height(self)
                end

                local mapY = map.y or 1
                if relX >= map.x and relX <= map.x + width - 1 and
                relY >= mapY and relY <= mapY + height - 1 then
                    self.dragStartX = x - self.get("x")
                    self.dragStartY = y - self.get("y")
                    self.dragging = true
                    return true
                end
            end
        end
        return Container.mouse_click(self, button, x, y)
    end
    return false
end

--- @shortDescription Handles mouse release events
--- @param button number The button that was released
--- @param x number The x position of the release
--- @param y number The y position of the release
--- @return boolean handled Whether the event was handled
--- @protected
function Frame:mouse_up(button, x, y)
    if self.dragging then
        self.dragging = false
        self.dragStartX = nil
        self.dragStartY = nil
        return true
    end
    return Container.mouse_up(self, button, x, y)
end

--- @shortDescription Handles mouse drag events
--- @param button number The button that was clicked
--- @param x number The x position of the drag position
--- @param y number The y position of the drag position
--- @return boolean handled Whether the event was handled
--- @protected
function Frame:mouse_drag(button, x, y)
    if self.get("clicked") and self.dragging then
        local newX = x - self.dragStartX
        local newY = y - self.dragStartY

        self.set("x", newX)
        self.set("y", newY)
        return true
    end
    if not self.dragging then
        return Container.mouse_drag(self, button, x, y)
    end
    return false
end

--- @shortDescription Calculates the total height of all children elements
--- @return number height The total height needed for all children
--- @protected
function Frame:getChildrenHeight()
    local maxHeight = 0
    local children = self.get("children")

    for _, child in ipairs(children) do
        if child.get("visible") then
            local childY = child.get("y")
            local childHeight = child.get("height")
            local totalHeight = childY + childHeight - 1

            if totalHeight > maxHeight then
                maxHeight = totalHeight
            end
        end
    end

    return maxHeight
end

--- @shortDescription Handles mouse scroll events
--- @param direction number The scroll direction
--- @param x number The x position of the scroll
--- @param y number The y position of the scroll
--- @return boolean handled Whether the event was handled
--- @protected
function Frame:mouse_scroll(direction, x, y)
    if Container.mouse_scroll(self, direction, x, y) then
        return true
    end

    if self.get("scrollable") then
        local relX, relY = self:getRelativePosition(x, y)
        local width = self.get("width")
        local height = self.get("height")

        if relX >= 1 and relX <= width and relY >= 1 and relY <= height then
            local childrenHeight = self:getChildrenHeight()
            local currentOffset = self.get("offsetY")
            local maxScroll = math.max(0, childrenHeight - height)

            local newOffset = currentOffset + direction
            newOffset = math.max(0, math.min(maxScroll, newOffset))

            self.set("offsetY", newOffset)
            return true
        end
    end
    
    return false
end

return Frame end
project["plugins/theme.lua"] = function(...) local errorManager = require("errorManager")
local defaultTheme = {
    default = {
        background = colors.lightGray,
        foreground = colors.black,
    },
    BaseFrame = {
        background = colors.white,
        foreground = colors.black,

        Frame = {
            background = colors.black,
            names = {
                basaltDebugLogClose = {
                    background = colors.blue,
                    foreground = colors.white
                }
            },
        },
        Button = {
            background = "{self.clicked and colors.black or colors.cyan}",
            foreground = "{self.clicked and colors.cyan or colors.black}",
        },

        names = {
            basaltDebugLog = {
                background = colors.red,
                foreground = colors.white
            },
            test = {
                background = "{self.clicked and colors.black or colors.green}",
                foreground = "{self.clicked and colors.green or colors.black}"
            }
        },
    }
}

local themes = {
    default = defaultTheme
}

---@title title

local currentTheme = "default"

--- This is the theme plugin. It provides a theming system that allows for consistent styling across elements
--- with support for inheritance, named styles, and dynamic theme switching.
---@class BaseElement
local BaseElement = {
    hooks = {
        postInit = {
            pre = function(self)
                if self._postInitialized then
                    return self
                end
                self:applyTheme()
            end
        }
    }
}

---@private
function BaseElement.____getElementPath(self, types)
    if types then
        table.insert(types, 1, self._values.type)
    else
        types = {self._values.type}
    end
    local parent = self.parent
    if parent then
        return parent.____getElementPath(parent, types)
    else
        return types
    end
end

local function lookUpTemplate(theme, path)
    local current = theme

    for i = 1, #path do
        local found = false
        local types = path[i]

        for _, elementType in ipairs(types) do
            if current[elementType] then
                current = current[elementType]
                found = true
                break
            end
        end

        if not found then
            return nil
        end
    end

    return current
end

local function getDefaultProperties(theme, elementType)
    local result = {}
    if theme.default then
        for k,v in pairs(theme.default) do
            if type(v) ~= "table" then
                result[k] = v
            end
        end

        if theme.default[elementType] then
            for k,v in pairs(theme.default[elementType]) do
                if type(v) ~= "table" then
                    result[k] = v
                end
            end
        end
    end
    return result
end

local function applyNamedStyles(result, theme, elementType, elementName, themeTable)
    if theme.default and theme.default.names and theme.default.names[elementName] then
        for k,v in pairs(theme.default.names[elementName]) do
            if type(v) ~= "table" then result[k] = v end
        end
    end

    if theme.default and theme.default[elementType] and theme.default[elementType].names 
       and theme.default[elementType].names[elementName] then
        for k,v in pairs(theme.default[elementType].names[elementName]) do
            if type(v) ~= "table" then result[k] = v end
        end
    end

    if themeTable and themeTable.names and themeTable.names[elementName] then
        for k,v in pairs(themeTable.names[elementName]) do
            if type(v) ~= "table" then result[k] = v end
        end
    end
end

local function collectThemeProps(theme, path, elementType, elementName)
    local result = {}
    local themeTable = lookUpTemplate(theme, path)
    if themeTable then
        for k,v in pairs(themeTable) do
            if type(v) ~= "table" then
                result[k] = v
            end
        end
    end

    if next(result) == nil then
        result = getDefaultProperties(theme, elementType)
    end

    applyNamedStyles(result, theme, elementType, elementName, themeTable)

    return result
end

--- Applies the current theme to this element
--- @shortDescription Applies theme styles to the element
--- @param self BaseElement The element to apply theme to
--- @param applyToChildren boolean? Whether to apply theme to child elements (default: true)
--- @return BaseElement self The element instance
function BaseElement:applyTheme(applyToChildren)
    local styles = self:getTheme()
    if(styles ~= nil) then
        for prop, value in pairs(styles) do
            local config = self._properties[prop]
            if(config)then
                if((config.type)=="color")then
                    if(type(value)=="string")then
                        if(colors[value])then
                            value = colors[value]
                        end
                    end
                end
                self.set(prop, value)
            end
        end
    end
    if(applyToChildren~=false)then
        if(self:isType("Container"))then
            local children = self.get("children")
            for _, child in ipairs(children) do
                if(child and child.applyTheme)then
                    child:applyTheme()
                end
            end
        end
    end
    return self
end

--- Gets the theme properties for this element
--- @shortDescription Gets theme properties for the element
--- @param self BaseElement The element to get theme for
--- @return table styles The theme properties
function BaseElement:getTheme()
    local path = self:____getElementPath()
    local elementType = self.get("type")
    local elementName = self.get("name")

    return collectThemeProps(themes[currentTheme], path, elementType, elementName)
end

--- The Theme API provides methods for managing themes globally
---@class ThemeAPI
local ThemeAPI = {}

--- Sets the current theme
--- @shortDescription Sets a new theme
--- @param newTheme table The theme configuration to set
function ThemeAPI.setTheme(newTheme)
    themes.default = newTheme
end

--- Gets the current theme configuration
--- @shortDescription Gets the current theme
--- @return table theme The current theme configuration
function ThemeAPI.getTheme()
    return themes.default
end

--- Loads a theme from a JSON file
--- @shortDescription Loads theme from JSON file
--- @param path string Path to the theme JSON file
function ThemeAPI.loadTheme(path)
    local file = fs.open(path, "r")
    if file then
        local content = file.readAll()
        file.close()
        themes.default = textutils.unserializeJSON(content)
        if not themes.default then
            errorManager.error("Failed to load theme from " .. path)
        end
    else
        errorManager.error("Could not open theme file: " .. path)
    end
end

return {
    BaseElement = BaseElement,
    API = ThemeAPI
}
 end
project["log.lua"] = function(...) --- Logger module for Basalt. Logs messages to the console and optionally to a file.
--- @class Log
--- @field _logs table The complete log history
--- @field _enabled boolean If the logger is enabled
--- @field _logToFile boolean If the logger should log to a file
--- @field _logFile string The file to log to
--- @field LEVEL table The log levels
local Log = {}
Log._logs = {}
Log._enabled = false
Log._logToFile = false
Log._logFile = "basalt.log"

fs.delete(Log._logFile)

Log.LEVEL = {
    DEBUG = 1,
    INFO = 2,
    WARN = 3,
    ERROR = 4
}

local levelMessages = {
    [Log.LEVEL.DEBUG] = "Debug",
    [Log.LEVEL.INFO] = "Info",
    [Log.LEVEL.WARN] = "Warn",
    [Log.LEVEL.ERROR] = "Error"
}

local levelColors = {
    [Log.LEVEL.DEBUG] = colors.lightGray,
    [Log.LEVEL.INFO] = colors.white,
    [Log.LEVEL.WARN] = colors.yellow,
    [Log.LEVEL.ERROR] = colors.red
}

--- Sets if the logger should log to a file.
--- @shortDescription Sets if the logger should log to a file
function Log.setLogToFile(enable)
    Log._logToFile = enable
end

--- Sets if the logger should log
--- @shortDescription Sets if the logger should log
function Log.setEnabled(enable)
    Log._enabled = enable
end

local function writeToFile(message)
    if Log._logToFile then
        local file = io.open(Log._logFile, "a")
        if file then
            file:write(message.."\n")
            file:close()
        end
    end
end

local function log(level, ...)
    if not Log._enabled then return end

    local timeStr = os.date("%H:%M:%S")

    local info = debug.getinfo(3, "Sl")
    local source = info.source:match("@?(.*)")
    local line = info.currentline
    local levelStr = string.format("[%s:%d]", source:match("([^/\\]+)%.lua$"), line)

    local levelMsg = "[" .. levelMessages[level] .. "]"

    local message = ""
    for i, v in ipairs(table.pack(...)) do
        if i > 1 then
            message = message .. " "
        end
        message = message .. tostring(v)
    end

    local fullMessage = string.format("%s %s%s %s", timeStr, levelStr, levelMsg, message)

    writeToFile(fullMessage)
    table.insert(Log._logs, {
        time = timeStr,
        level = level,
        message = message
    })
end

--- Sends a debug message to the logger.
--- @shortDescription Sends a debug message
--- @vararg string The message to log
--- @usage Log.debug("This is a debug message")
function Log.debug(...) log(Log.LEVEL.DEBUG, ...) end

--- Sends an info message to the logger.
--- @shortDescription Sends an info message
--- @vararg string The message to log
--- @usage Log.info("This is an info message")
function Log.info(...) log(Log.LEVEL.INFO, ...) end

--- Sends a warning message to the logger.
--- @shortDescription Sends a warning message
--- @vararg string The message to log
--- @usage Log.warn("This is a warning message")
function Log.warn(...) log(Log.LEVEL.WARN, ...) end

--- Sends an error message to the logger.
--- @shortDescription Sends an error message
--- @vararg string The message to log
--- @usage Log.error("This is an error message")
function Log.error(...) log(Log.LEVEL.ERROR, ...) end

return Log end
return project["main.lua"]()