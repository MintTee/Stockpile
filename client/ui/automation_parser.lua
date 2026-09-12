-- /stockpile_client/ui/automation_parser.lua
local parser = {}

-- =====================================================================
-- Grammar specs
-- =====================================================================
local SIDES = {
    any = true, left = true, right = true,
    front = true, back = true, top = true, bottom = true,
}

local REDSTONE_OPS = {
    [">"] = true, ["<"] = true, ["="] = true,
    rising = true, falling = true, delta_any = true,
}

local COMPARE_OPS = { [">"] = true, ["<"] = true, ["="] = true }

local CONDITION_SPECS = {
    period = {
        arity = { 1, 1 },
        args  = { { kind = "number" } },
    },
    redstone = {
        arity = { 2, 3 },
        args  = {
            { kind = "ident",       oneOf = SIDES },
            { kind = "op_or_ident", oneOf = REDSTONE_OPS },
            { kind = "number",      optional = true },
        },
    },
    item_qty = {
        arity = { 4, 4 },
        args  = {
            { kind = "string_or_ident" },
            { kind = "ident" },
            { kind = "op", oneOf = COMPARE_OPS },
            { kind = "number" },
        },
    },
}

local COMMAND_SPECS = {
    scan_group = {
        arity = { 1, 1 },
        args  = { { kind = "ident" } },
    },
    move_item = {
        arity = { 4, 4 },
        args  = {
            { kind = "string_or_ident" },
            { kind = "ident" },
            { kind = "ident" },
            { kind = "number" },
        },
    },
}

-- =====================================================================
-- Tokenizer
-- =====================================================================
local function tokenize(text)
    local tokens = {}
    local pos = 1
    while pos <= #text do
        local char = text:sub(pos, pos)
        if char:match("%s") then
            pos = pos + 1
        elseif char == "(" then
            tokens[#tokens + 1] = { type = "lparen", value = "(" }; pos = pos + 1
        elseif char == ")" then
            tokens[#tokens + 1] = { type = "rparen", value = ")" }; pos = pos + 1
        elseif char == "," then
            tokens[#tokens + 1] = { type = "comma", value = "," }; pos = pos + 1
        elseif char == ">" or char == "<" or char == "=" then
            tokens[#tokens + 1] = { type = "op", value = char }; pos = pos + 1
        elseif char == '"' then
            local start = pos + 1
            pos = pos + 1
            while pos <= #text and text:sub(pos, pos) ~= '"' do pos = pos + 1 end
            if pos > #text then error("Unterminated string literal") end
            tokens[#tokens + 1] = { type = "string", value = text:sub(start, pos - 1) }
            pos = pos + 1
        elseif char:match("%d") then
            -- numbers: digits only. Reject 12abc, 0x10, 1e5.
            local start = pos
            while pos <= #text and text:sub(pos, pos):match("%d") do pos = pos + 1 end
            if pos <= #text and text:sub(pos, pos):match("[%a_]") then
                error("Invalid number at position " .. start ..
                      " (digits cannot be followed by letters)")
            end
            tokens[#tokens + 1] = {
                type = "number",
                value = tonumber(text:sub(start, pos - 1)),
            }
        elseif char:match("[%a_]") then
            -- identifiers: start with letter/underscore; can contain
            -- letters, digits, underscore, colon (for minecraft:xxx names).
            local start = pos
            while pos <= #text and text:sub(pos, pos):match("[%w_:]") do pos = pos + 1 end
            tokens[#tokens + 1] = { type = "ident", value = text:sub(start, pos - 1) }
        else
            error("Unexpected character '" .. char .. "' at position " .. pos)
        end
    end
    return tokens
end

-- =====================================================================
-- Argument validation
-- =====================================================================
local function check_arg_kind(arg, spec)
    local t = arg.type
    local k = spec.kind

    if k == "number" then
        if t ~= "number" then return "expected number, got " .. t end
    elseif k == "ident" then
        if t ~= "ident" then return "expected identifier, got " .. t end
    elseif k == "op" then
        if t ~= "op" then return "expected operator, got " .. t end
    elseif k == "string_or_ident" then
        if t ~= "string" and t ~= "ident" then
            return "expected item name (identifier or quoted string), got " .. t
        end
    elseif k == "op_or_ident" then
        if t ~= "op" and t ~= "ident" then
            return "expected operator or keyword, got " .. t
        end
    end

    if spec.oneOf and not spec.oneOf[arg.value] then
        return "unexpected value '" .. tostring(arg.value) .. "'"
    end
    return nil
end

local function validate_call(name, args, spec, kind)
    if not spec then
        return "unknown " .. kind .. " '" .. name .. "'"
    end
    local lo, hi = spec.arity[1], spec.arity[2]
    if #args < lo or #args > hi then
        return string.format("'%s' expects %d..%d argument(s), got %d",
                             name, lo, hi, #args)
    end
    for i, argSpec in ipairs(spec.args) do
        if i <= #args then
            local err = check_arg_kind(args[i], argSpec)
            if err then
                return string.format("'%s' arg %d: %s", name, i, err)
            end
        elseif not argSpec.optional then
            return string.format("'%s' arg %d is required", name, i)
        end
    end
    return nil
end

-- =====================================================================
-- Parser
-- =====================================================================
local function parse_tokens(tokens, specs, kind)
    local pos = 1

    local function peek() return tokens[pos] end
    local function consume(expected)
        local t = tokens[pos]
        if not t then error("Unexpected end of input") end
        if expected and t.type ~= expected then
            error("Expected " .. expected .. ", got " .. t.type ..
                  " ('" .. tostring(t.value) .. "')")
        end
        pos = pos + 1
        return t
    end

    local parse_primary, parse_arg

    parse_arg = function()
        local t = peek()
        if not t then error("Expected argument, got end of input") end
        if t.type == "string" then consume("string"); return { type = "string", value = t.value }
        elseif t.type == "number" then consume("number"); return { type = "number", value = t.value }
        elseif t.type == "op" then consume("op"); return { type = "op", value = t.value }
        elseif t.type == "ident" then consume("ident"); return { type = "ident", value = t.value }
        else error("Unexpected token in argument: " .. t.type .. " ('" .. tostring(t.value) .. "')") end
    end

    local parse_condition = function()
        local name = consume("ident").value:lower()
        consume("lparen")
        local args = {}
        if peek() and peek().type ~= "rparen" then
            args[#args + 1] = parse_arg()
            while peek() and peek().type == "comma" do
                consume("comma")
                args[#args + 1] = parse_arg()
            end
        end
        consume("rparen")

        local err = validate_call(name, args, specs[name], kind)
        if err then error(err) end

        return { type = "condition", name = name, args = args }
    end

    local parse_not, parse_and, parse_xor, parse_or

    parse_primary = function()
        if peek() and peek().type == "lparen" then
            consume("lparen")
            local expr = parse_or()
            consume("rparen")
            return expr
        end
        return parse_condition()
    end

    parse_not = function()
        if peek() and peek().type == "ident" and peek().value:lower() == "not" then
            consume("ident")
            return { type = "not", operand = parse_not() }
        end
        return parse_primary()
    end

    parse_and = function()
        local left = parse_not()
        while peek() and peek().type == "ident" and peek().value:lower() == "and" do
            consume("ident")
            left = { type = "and", left = left, right = parse_not() }
        end
        return left
    end

    parse_xor = function()
        local left = parse_and()
        while peek() and peek().type == "ident" and peek().value:lower() == "xor" do
            consume("ident")
            left = { type = "xor", left = left, right = parse_and() }
        end
        return left
    end

    parse_or = function()
        local left = parse_xor()
        while peek() and peek().type == "ident" and peek().value:lower() == "or" do
            consume("ident")
            left = { type = "or", left = left, right = parse_xor() }
        end
        return left
    end

    local ast = parse_or()
    if pos <= #tokens then
        error("Unexpected token: '" .. tostring(tokens[pos].value) .. "'")
    end
    return ast
end

-- =====================================================================
-- Evaluator
-- =====================================================================
local function eval_node(node, ctx)
    if node.type == "and" then
        return eval_node(node.left, ctx) and eval_node(node.right, ctx)
    elseif node.type == "or" then
        return eval_node(node.left, ctx) or eval_node(node.right, ctx)
    elseif node.type == "xor" then
        return eval_node(node.left, ctx) ~= eval_node(node.right, ctx)
    elseif node.type == "not" then
        return not eval_node(node.operand, ctx)
    elseif node.type == "condition" then
        return ctx.evaluate_condition(node.name, node.args)
    end
    error("Unknown node type: " .. tostring(node.type))
end

-- =====================================================================
-- Public API
-- =====================================================================
-- mode: "condition" (default) or "command"
function parser.parse(text, mode)
    local tokens = tokenize(text)
    if #tokens == 0 then return nil end

    local specs, kind
    if mode == "command" then
        specs, kind = COMMAND_SPECS, "command"
    else
        specs, kind = CONDITION_SPECS, "condition"
    end

    return parse_tokens(tokens, specs, kind)
end

function parser.evaluate(ast, ctx)
    return eval_node(ast, ctx)
end

return parser