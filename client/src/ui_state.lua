-- /stockpile_client/src/ui_state.lua
local data = require("src.data")

local ui_state = {}

local STATE_FILE = "/stockpile_client/config/ui_state.json"

-- Last loaded state, kept so `reapply_selections` can re-apply after
-- asynchronous content refreshes without touching text boxes.
local last_state = nil

-- =====================================================================
-- Helpers
-- =====================================================================
-- Basalt stores `element.get` / `element.set` as per-instance closures
-- that already capture `self`. Correct calls:
--     element.get(prop)
--     element.set(prop, value)
-- NOT element:get(prop) / element:set(prop, value).

local function safe_get(element, prop)
    local ok, val = pcall(function() return element.get(prop) end)
    if ok then return val end
    return nil
end

local function safe_set(element, prop, value)
    return pcall(function() element.set(prop, value) end)
end

--- Count how many earlier siblings share the same type as `element`.
--- An element counts as "unnamed" when its name is empty OR equals its
--- type — Basalt's basalt.create() sets name = type when no properties
--- are passed, so every auto-created Frame/Button/Label looks named.
local function sibling_index(element, siblings)
    local elem_type = safe_get(element, "type") or "unknown"
    local idx = 0
    for _, sibling in ipairs(siblings) do
        local sib_name = safe_get(sibling, "name") or ""
        local sib_type = safe_get(sibling, "type") or "unknown"
        local is_unnamed = (sib_name == "" or sib_name == sib_type)
        if is_unnamed and sib_type == elem_type then
            idx = idx + 1
        end
        if sibling == element then return idx end
    end
    return idx
end

--- Generate a stable key for an element.
--- - If the element has a truly explicit `name` (different from its
---   type), use it.
--- - Otherwise fall back to type + 1-based index among same-type
---   auto-named siblings.
local function make_key(parent_key, element, siblings)
    local name      = safe_get(element, "name") or ""
    local elem_type = safe_get(element, "type") or "unknown"

    if name ~= "" and name ~= elem_type then
        return parent_key .. "/" .. name
    end

    local idx = sibling_index(element, siblings)
    return parent_key .. "/" .. elem_type .. "#" .. tostring(idx)
end

--- If the element is a BetterList wrapper, return the inner Basalt List.
local function get_list_inner(element)
    if type(element.getList) == "function" then
        local ok, inner = pcall(element.getList, element)
        if ok and inner then return inner end
    end
    return element
end

-- =====================================================================
-- Capture
-- =====================================================================

local function capture_element(element, parent_key, out, siblings)
    if not element or element._destroyed then return end
    siblings = siblings or {}

    local key = make_key(parent_key, element, siblings)

    out[key .. "/visible"] = safe_get(element, "visible")

    if element:isType("TextBox") then
        local ok, text = pcall(element.getText, element)
        if ok and text ~= nil then
            out[key .. "/text"] = text
        end
    end

    if element:isType("Input") then
        out[key .. "/text"]       = safe_get(element, "text") or ""
        out[key .. "/cursorPos"]  = safe_get(element, "cursorPos")
        out[key .. "/viewOffset"] = safe_get(element, "viewOffset")
    end

    if element:isType("ComboBox") then
        out[key .. "/text"]      = safe_get(element, "text") or ""
        out[key .. "/cursorPos"] = safe_get(element, "cursorPos")
    end

    if element:isType("DropDown") and not element:isType("ComboBox") then
        local ok, sel = pcall(element.getSelectedItem, element)
        if ok and sel and sel.text then
            out[key .. "/selectedText"] = sel.text
        end
    end

    if element:isType("Switch") or element:isType("CheckBox") then
        out[key .. "/checked"] = safe_get(element, "checked")
    end

    if element:isType("Table") then
        out[key .. "/selectedRow"]   = safe_get(element, "selectedRow")
        out[key .. "/sortColumn"]    = safe_get(element, "sortColumn")
        out[key .. "/sortDirection"] = safe_get(element, "sortDirection")
        out[key .. "/scrollOffset"]  = safe_get(element, "scrollOffset")
    end

    if element:isType("Tree") then
        out[key .. "/scrollOffset"]     = safe_get(element, "scrollOffset")
        out[key .. "/horizontalOffset"] = safe_get(element, "horizontalOffset")
        local expanded = safe_get(element, "expandedNodes") or {}
        local expanded_keys = {}
        for node in pairs(expanded) do
            if type(node) == "table" and node.text then
                expanded_keys[#expanded_keys + 1] = node.text
            end
        end
        out[key .. "/expandedNodes"] = expanded_keys
    end

    if element:isType("List") and not element:isType("DropDown") then
        local list = get_list_inner(element)
        local items = safe_get(list, "items") or {}
        local selected_keys = {}
        for _, item in ipairs(items) do
            if type(item) == "table" and item.selected then
                selected_keys[#selected_keys + 1] = item.id or item.text
            end
        end
        out[key .. "/selectedKeys"] = selected_keys
        out[key .. "/offset"]       = safe_get(list, "offset")
    end

    if element:isType("Frame") then
        out[key .. "/offsetX"] = safe_get(element, "offsetX")
        out[key .. "/offsetY"] = safe_get(element, "offsetY")
    end

    if element:isType("Slider") then
        out[key .. "/step"] = safe_get(element, "step")
    end

    if element:isType("ProgressBar") then
        out[key .. "/progress"] = safe_get(element, "progress")
    end

    if element:isType("TabControl") then
        out[key .. "/activeTab"] = safe_get(element, "activeTab")
    end

    if element:isType("Container") then
        local children = safe_get(element, "children") or {}
        for _, child in ipairs(children) do
            capture_element(child, key, out, children)
        end
    end
end

function ui_state.capture(root)
    local out = {}
    capture_element(root, "", out, {})
    return out
end

-- =====================================================================
-- Restore
-- =====================================================================

local function restore_element(element, parent_key, state, siblings, selection_only)
    if not element or element._destroyed then return end
    siblings = siblings or {}

    local key = make_key(parent_key, element, siblings)
    local function get_state(suffix) return state[key .. "/" .. suffix] end

    -- =================================================================
    -- Non-selection state — only touched in the first (full) pass.
    -- =================================================================
    if not selection_only then
        local visible = get_state("visible")
        if visible ~= nil then safe_set(element, "visible", visible) end

        if element:isType("TextBox") then
            local text = get_state("text")
            if text then pcall(element.setText, element, text) end
        end

        if element:isType("Input") then
            local text = get_state("text")
            if text then
                safe_set(element, "text", text)
                safe_set(element, "cursorPos", get_state("cursorPos") or (#text + 1))
                safe_set(element, "viewOffset", get_state("viewOffset") or 0)
                pcall(element.updateViewport, element)
            end
        end

        if element:isType("ComboBox") then
            local text = get_state("text")
            if text then pcall(element.setText, element, text) end
        end

        if element:isType("Switch") or element:isType("CheckBox") then
            local checked = get_state("checked")
            if checked ~= nil then safe_set(element, "checked", checked) end
        end

        if element:isType("Slider") then
            local v = get_state("step"); if v ~= nil then safe_set(element, "step", v) end
        end
        if element:isType("ProgressBar") then
            local v = get_state("progress"); if v ~= nil then safe_set(element, "progress", v) end
        end

        if element:isType("TabControl") then
            local v = get_state("activeTab")
            if v ~= nil then pcall(element.setActiveTab, element, v) end
        end
    end

    -- =================================================================
    -- Selection state — applied in BOTH passes.
    --
    -- In the full pass (pass 1), DropDowns ALSO fire their `select`
    -- event so dependent lists (search results, inventory list, qty
    -- visibility, target-group dropdown) get repopulated from the
    -- restored group/mode. In the selection-only pass (pass 2), we
    -- just re-mark item.selected without firing events — this lets
    -- list selections be reapplied after lists have been rebuilt.
    -- =================================================================

    if element:isType("DropDown") and not element:isType("ComboBox") then
        local sel_text = get_state("selectedText")
        if sel_text then
            local items = safe_get(element, "items") or {}
            local selected_index, selected_item
            for i, item in ipairs(items) do
                if type(item) == "table" then
                    item.selected = (item.text == sel_text)
                    if item.selected then
                        selected_index, selected_item = i, item
                    end
                end
            end
            if not selection_only and selected_index then
                -- Fire the same event a real user click would, so all
                -- onSelect listeners run and rebuild their dependencies.
                pcall(function()
                    element:fireEvent("select", selected_index, selected_item)
                end)
            end
        end
    end

    if element:isType("List") and not element:isType("DropDown") then
        local list = get_list_inner(element)
        local selected_keys = get_state("selectedKeys") or {}
        local items = safe_get(list, "items") or {}
        for _, item in ipairs(items) do
            if type(item) == "table" then
                local ik = item.id or item.text
                item.selected = false
                for _, k in ipairs(selected_keys) do
                    if ik == k then item.selected = true; break end
                end
            end
        end
        local offset = get_state("offset")
        if offset ~= nil then safe_set(list, "offset", offset) end
    end

    if element:isType("Table") then
        local v = get_state("selectedRow");   if v ~= nil then safe_set(element, "selectedRow", v) end
        v = get_state("sortColumn");          if v ~= nil then safe_set(element, "sortColumn", v) end
        v = get_state("sortDirection");       if v ~= nil then safe_set(element, "sortDirection", v) end
        v = get_state("scrollOffset");        if v ~= nil then safe_set(element, "scrollOffset", v) end
    end

    if element:isType("Tree") then
        local v = get_state("scrollOffset");     if v ~= nil then safe_set(element, "scrollOffset", v) end
        v = get_state("horizontalOffset");       if v ~= nil then safe_set(element, "horizontalOffset", v) end
        local expanded_keys = get_state("expandedNodes") or {}
        local function mark_expanded(nodes)
            for _, node in ipairs(nodes) do
                if type(node) == "table" then
                    for _, k in ipairs(expanded_keys) do
                        if node.text == k then pcall(element.expandNode, element, node) end
                    end
                    if node.children then mark_expanded(node.children) end
                end
            end
        end
        mark_expanded(safe_get(element, "nodes") or {})
    end

    if element:isType("Frame") then
        local v = get_state("offsetX"); if v ~= nil then safe_set(element, "offsetX", v) end
        v = get_state("offsetY");        if v ~= nil then safe_set(element, "offsetY", v) end
    end

    if element:isType("Container") then
        local children = safe_get(element, "children") or {}
        for _, child in ipairs(children) do
            restore_element(child, key, state, children, selection_only)
        end
    end
end

function ui_state.restore(root, state)
    if not state or next(state) == nil then return end
    restore_element(root, "", state, {}, false)
end

--- Re-apply only selection state. Safe to call repeatedly; never
--- touches text boxes so it won't clobber user input typed since
--- the last load.
function ui_state.reapply_selections(root)
    if not last_state then return end
    restore_element(root, "", last_state, {}, true)
end

-- =====================================================================
-- Disk I/O
-- =====================================================================

function ui_state.save(root)
    last_state = ui_state.capture(root)
    data.save(STATE_FILE, textutils.serialise(last_state))
end

function ui_state.load(root)
    if not fs.exists(STATE_FILE) then return false end
    local s = data.load(STATE_FILE)
    if not s or s == "" then return false end
    local state = textutils.unserialize(s)
    if type(state) ~= "table" then return false end
    last_state = state

    -- Pass 1: restore text / visibility / dropdowns. Dropdown restores
    --         fire their `select` callbacks so dependent lists get
    --         populated from the restored group / mode.
    restore_element(root, "", state, {}, false)

    -- Pass 2: re-apply list item selections now that the lists exist.
    restore_element(root, "", state, {}, true)

    return true
end

return ui_state