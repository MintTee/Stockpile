local string_utils = {}

function string_utils.truncate(str, max_len)
    if #str <= max_len then
        return str
    end
    return string.format("...%s", string.sub(str, -(max_len - 3)))
end

function string_utils.formatMetricPrefix(num)
    local sign = ""
    if num < 0 then
        sign = "-"
        num = math.abs(num)
    end

    local prefixes = {
        {value = 1000000000, symbol = "G"},
        {value = 1000000, symbol = "M"},
        {value = 1000, symbol = "k"}
    }

    for _, prefix in ipairs(prefixes) do
        if num >= prefix.value then
            local formatted = num / prefix.value
            formatted = math.floor(formatted * 10 + 0.5) / 10
            return string.format("%s%.1f%s", sign, formatted, prefix.symbol)
        end
    end

    return sign .. tostring(math.floor(num + 0.5))
end

return string_utils