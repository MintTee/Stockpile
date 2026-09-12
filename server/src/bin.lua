--[[	Compression module for stockpile, allows for enourmous compression of database using formatted bit packing, dictionnary encoding, dynamic packing size and deflate compressor, compared to using simple textutils.serialize() data saving technique.

Stats : about 350k items (100*54*64) items stored in chest occuping 24Ko of real disk space.
So that's [14,400 items stored per Ko]. Probably even more items/Ko because of increase in dictionnary efficiency for large databases but diminushing results with increased item variety. (tested with max item variety from a random item set)

1 Mil items : 70ko
10 Mil items : 700Ko
100 Mil items : 7Mo -prob less
]]

local log = require("/stockpile_server/src/log")
local bitstream = require("/stockpile_server/lib/bitstream")
local table_utils = require("/stockpile_server/src/table_utils")
local dict = require("/stockpile_server/src/dict")
local string_utils = require("/stockpile_server/src/string_utils")
require("/stockpile_server/var/globals")

--Documents how an entry of item_index is packed into a bit stream, each number corresponding to the space on which is encoded the information
local fmt = {
	bool = 1,
	type = 3,
	smol_int = 6,
	stack = 7,
	dict_string = 12, --dynamic scaling
	nbits_dict_string = 4, -- value of variable bit lenght for encoding dict_string. Embedded in first position of inv_index. 
}

local bin = {}

--processes the display name of the item, if it can be reconstructed, then it's set to nil, meaning we don't have to encode it
local function process_displayname(item, dispn)
    if dispn == string_utils.make_display(item) then
        return nil
    else
        return dispn
    end
end

-- Returns the number of symbols necessary to write a number (in binary). Example : 3 bits for n=7 (111)
local function nbit(n)
    if n == 0 then return 1 end
    return math.floor(math.log(n) / math.log(2)) + 1
end

function bin.encode_db()
	local writer = bitstream.new_writer()

	local function encode_item(item, item_name)

		--item name & stack size
		writer:write_bits(dict.switch(item_name), fmt.dict_string)
		writer:write_bits(item.stack_size, fmt.stack)

		--Writing bool of display name presence (if not present it can be reconstructed)
		if not process_displayname(item_name, item.displayName) then -- do we need the display name ? nil if not
			writer:write_bits(0, fmt.bool) --no display name
		else
			writer:write_bits(1, fmt.bool) --display name is present
			writer:write_bits(dict.switch(item.displayName), fmt.dict_string)
		end

		local n_nbt_fields = table_utils.length(item.nbt)
		writer:write_bits(n_nbt_fields, fmt.smol_int) --how many nbt entry are encoded
		if n_nbt_fields > 0 then
			for _, v in pairs(item.nbt) do
				writer:write_bits(dict.switch(v), fmt.dict_string) --writes each nbt string
			end
		end
	end

	--RLE technique of juste indicating how many empty slots are after 1 slot if any, so you can directly write item_name|qty chaining with beggining state of 1st slot empty or smth in it
	local function rle_indexes(t)

		local keys = {}
		for k in pairs(t) do
			assert(type(k) == "number", "Non-numeric key in rle_indexes")
			keys[#keys+1] = k
		end
		table.sort(keys)
		if #keys == 0 then return {} end

		local res = {}
		local prev = 0
		local i = 1

		while i <= #keys do
			local start = keys[i]
			while i < #keys and keys[i+1] == keys[i] + 1 do i = i + 1 end
			local finish = keys[i]

			if start > prev + 1 then
				res[#res+1] = {exists = false, count = start - prev - 1}
			end
			res[#res+1] = {exists = true, count = finish - start + 1}

			prev = finish
			i = i + 1
		end

		return res
	end

	dict.generate()
	fmt.dict_string = nbit(dict.get_ns_length())
	writer:write_bits(fmt.dict_string, fmt.nbits_dict_string) --embedded bit lenght of dict strings

	local tested_item = {}

	for inv_id, inv in pairs(inv_index) do

		--header
		local dict_inv_id = dict.switch(inv_id)
		writer:write_bits(dict_inv_id, fmt.dict_string)
		writer:write_bits(inv.size, fmt.smol_int)

		if not inv.slots then inv.slots = {} end

		local rle_i = rle_indexes(inv.slots)
		local slot = 1
		local n_rle_chunks = #rle_i

		local state
		if rle_i[1] and rle_i[1].exists == true then state = true else state = false end
		if state == true then writer:write_bits(1, fmt.bool) else writer:write_bits(0, fmt.bool) end

		writer:write_bits(n_rle_chunks, fmt.stack) --how many rle chunks are there to treat ?

		for _, data in ipairs(rle_i) do
			local count = data.count

			writer:write_bits(count, fmt.stack) --how many consecutive slots per chunk (empty or filled)
			if state == true then
				for _=1, count do
					local item, qty = next(inv.slots[slot])

					if not tested_item[item] then -- if it's the first time we encounter this item
						tested_item[item] = true
						encode_item(item_index[item], item) --we encode the item info (disp name and nbt fields)
					else
						writer:write_bits(dict.switch(item), fmt.dict_string)
					end

					writer:write_bits(qty, fmt.stack)
					slot = slot + 1
				end
			else
				slot = slot + count
			end
			state = not state
		end
	end

	--saving to disk
	dict.save()
	local f = io.open("/stockpile_server/bin/db.bin", "wb")
	f:write(writer:flush())
	f:close()
end

function bin.decode_db()
	dict.load()

	inv_index, item_index = {}, {} --init indexes

    local file = io.open("/stockpile_server/bin/db.bin", "rb")
    if not file then return end
    local s = file:read("a")
    file:close()
    local reader = bitstream.new_reader(s)

	fmt.dict_string = reader:read_bits(fmt.nbits_dict_string) --embedded bit lenght of dict strings

	local function decode_item(item_name)
		--item name & stack size
		item_index[item_name] = {}
		item_index[item_name].stack_size = reader:read_bits(fmt.stack)
		item_index[item_name].nbt = {}

		local bool_displayname = reader:read_bits(fmt.bool)
		if bool_displayname == 1 then
			item_index[item_name].displayName = dict.switch(reader:read_bits(fmt.dict_string))
		else
			item_index[item_name].displayName = string_utils.make_display(item_name)
		end

		local n_nbt_fields = reader:read_bits(fmt.smol_int)

		if n_nbt_fields > 0 then
			for _=1, n_nbt_fields do
				local val = dict.switch(reader:read_bits(fmt.dict_string))
				table.insert(item_index[item_name].nbt, val)
			end
		end
	end

	local tested_item = {}
    while reader:bytes_left() ~= 0 do

        --header
		local inv_id = reader:read_bits(fmt.dict_string)
		local inv_name = dict.switch(inv_id)
		local size = reader:read_bits(fmt.smol_int)

		inv_index[inv_name] = {size = size, slots = {}}

		--slots
		local slot_id = 1
		local state
		if reader:read_bits(fmt.bool) == 1 then state = true else state = false end --rle chunk chain starts with empty or occupied slot

		local n_rle_chunks = reader:read_bits(fmt.stack)
		for _ = 1, n_rle_chunks do --itrates every rle chunk

			local rle_n_slot = reader:read_bits(fmt.stack) --how many slots in rle chunk
			if state == true then
				for _=1, rle_n_slot do
					local item = reader:read_bits(fmt.dict_string)
					
					if not tested_item[item] then --first time we see this item
						tested_item[item] = true
						decode_item(dict.switch(item))
					end

					local qty = reader:read_bits(fmt.stack)
					inv_index[inv_name].slots[slot_id] = {[dict.switch(item)] = qty}
					slot_id = slot_id + 1
				end
			else -- empty slots sequence
				slot_id = slot_id + rle_n_slot
			end
			state = not state
		end
    end

	local function reconstruct_item_index()
		for inv_name, inv in pairs(inv_index) do
			for slot_id, slot in pairs(inv.slots) do
				if type(slot) == "table" then
					local item, qty = next(slot)
					local total = item_index[item].total or 0
					item_index[item].total = total + qty
					if not item_index[item].location then item_index[item].location = {} end
					if not item_index[item].location[inv_name] then item_index[item].location[inv_name] = {} end
					if item_index[item].stack_size > qty then --part filled slot
						if not item_index[item].part_filled_slots then item_index[item].part_filled_slots = {} end
						if not item_index[item].part_filled_slots[inv_name] then item_index[item].part_filled_slots[inv_name] = {} end
						item_index[item].part_filled_slots[inv_name][slot_id] = qty
					end
					item_index[item].location[inv_name][slot_id] = qty --filling location
				end
			end
		end
	end
	reconstruct_item_index()
	--Verify results if needed
	--[[local f = io.open("/stockpile_server/debug/inv_index_decoded.txt", "w")
	f:write(textutils.serialize(inv_index))
	f:close()

	f = io.open("/stockpile_server/debug/item_index_decoded.txt", "w")
	f:write(textutils.serialize(item_index))
	f:close()]]
end

return bin