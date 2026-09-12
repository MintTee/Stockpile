-- lib/bitstream.lua
-- Bitstream writer/reader
local bitstream = {}
local log = require("/stockpile_server/src/log")

function bitstream.new_writer()
    local buffer = 0
    local bits_in_buffer = 0
    local octets = {}

    local obj = {}

    function obj:write_bits(value, nbits)

        --Debug code, to remove in production
        if type(value) ~= "number" or not value then
            log.error(debug.traceback("Wrong value format in bin write"))
            log.flush()
        end

        if nbits == 0 then return end
        value = bit.band(value, (bit.blshift(1, nbits) - 1))
        buffer = bit.bor(buffer, bit.blshift(value, bits_in_buffer))
        bits_in_buffer = bits_in_buffer + nbits

        while bits_in_buffer >= 8 do
            local octet = bit.band(buffer, 0xFF)
            table.insert(octets, octet)
            buffer = bit.brshift(buffer, 8)
            bits_in_buffer = bits_in_buffer - 8
        end
    end

    function obj:flush()
        if bits_in_buffer > 0 then
            table.insert(octets, bit.band(buffer, 0xFF))
            buffer = 0
            bits_in_buffer = 0
        end
        local result = string.char(table.unpack(octets))
        octets = {}
        return result
    end

    return obj
end

function bitstream.new_reader(data_string)
    -- convert string to table of octets (numbers 0-255)
    local octets = {}
    for i = 1, #data_string do
        octets[i] = string.byte(data_string, i)
    end

    local buffer = 0
    local bits_in_buffer = 0

    local obj = {}

    function obj:read_bits(nbits)
        while bits_in_buffer < nbits do
            local next_octet = table.remove(octets, 1)
            if not next_octet then
                error("bitstream: unexpected end of data")
            end
            buffer = bit.bor(buffer, bit.blshift(next_octet, bits_in_buffer))
            bits_in_buffer = bits_in_buffer + 8
        end
        local mask = bit.blshift(1, nbits) - 1
        local value = bit.band(buffer, mask)
        buffer = bit.brshift(buffer, nbits)
        bits_in_buffer = bits_in_buffer - nbits
        return value
    end

    function obj:bytes_left()
        return #octets
    end

    return obj
end

return bitstream