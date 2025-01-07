# Stockpile API Documentation

[For more informations regarding Stockpile's data management and floppy disks go here](#data-and-floppy-disks)

## How to use the API

To execute an API method on the stockpile server, you will need to send a command over Rednet. The command has to be of a string or table type. You will first need to whitelist the client's computer id in the Stockpile server config file.

It's recommended to format the command as a table such as :
- index[1] is the string formatted API method you want to execute.
- index[2] is a unique identifier for the command.

The server's response over rednet will include that UUID, allowing you to asynchronously know which servers's response correspond to what command. The UUID will default to 1 if none is provided.

Format :

`rednet.send(stockpile_server_id, {"command", [command_UUID]})`

Examples :

`rednet.send(123, {[[scan(inventories.storage)]], math.random(1, 2^32)})`
`rednet.send(321, [[list_all_inventories()]])`

In order to collect the server's response, just use `local server_id, response = rednet.recieve()` to process it further.

The server's response will be a table where index[1] is the actual returned result and the index[2] is the command UUID. 

---

**All API commands:**\
*[arg] = Optional argument.*

[move_item(from_invs, to_invs, [item_filter], [quantity_filter], [nbt_filter])](#move_item)\
[search([item_filter], [nbt_filter])](#search)\
[scan(inventories)](#scan)\
[usage()](#usage)\
[get_nbt(item_id)](#get_nbt)\
[list_all_inventories()](#list_all_inventories)\
[get_content](#get_content)\
[unit()](#unit)

---

## move_item

`move_item(from_invs, to_invs, [item_filter], [quantity_filter], [nbt_filter])`

Moves all the item contained in a group of inventories to an other. You can filter the item moved and quantities in multiple ways. If no item filter is specified, it will flag every item for transfer. Same thing with the nbt_filter. If no quantity filter is specified, it will try to move the maximum amount of items.

You can combine the three filters for fine control over the moved item parameters.

**Arguments**

1. `from_invs` : table - A list of the source inventories.
2. `to_invs` : table - A list table of the destination inventories.
3. `item_filter` : string - Regex filter for the item ids. If an item id matches this filter, it will be flagged to be move.
4. `quantity_filter` : number - The limit on the amount of items to transfer.
5. `nbt_filter` : string - Regex filter for the item's nbt data. The nbt data is serialized and therefore this filter will look for any matching pattern, independently of the nbt's attribute structure.

**Returns**
1. string - `Info : move_item : Success`
2. string - `Warn : move_item : Destination inventories are probably full, aborting transfer request. Please verify the destinations have empty space.`

**Examples**

`move_item(inventories.input, inventories.storage)`
- Transfers all the items from the inventory group(unit) "input" to the inventory unit "storage".

`move_item(inventories.storage, inventories.output, "arrow")`
- Transfers all item matching "arrow" in their id (minecraft:arrow, minecraft:tipped_arrow...) from the inventory unit "storage" to the inventory unit "output".

`move_item({"minecraft:chest_20", "minecraft:chest_21"}, {"minecraft:barrel_15"}, _, 10, "Sharpness")`
- Transfers up to 10 items matching "Sharpness" in their nbt from chest #20 and #21 to barrel #15.

---

## search
`search([item_filter], [nbt_filter])`

1. `item_filter` : string - Regex filter for the item ids. If an item id matches this filter, it will be added to the returned result list.
2. `nbt_filter` : string - Regex filter for the item ids. If an item's serialized nbt data matches this filter, it will be added to the returned result list.

**Returns**
1. table - A table containing all the result of your search. Item ids are keys and the total amount held in the storage are their values.

**Examples**

`search(":stone$")`
- Will only return the "minecraft:stone" item and not "minecraft:redstone" (because of the regex expression).

`search("tipped", "Heal")`
- Will return the item "minecraft:tipped_arrow" of the "Healing" type and not the "Poison" type (because of the added nbt filter).

---

## scan

`scan(inventories)`

Scan an inventory group's content in order to update Stockpile's database.

**This method is to be used when the content of an inventory is not solely defined by Stockpile**. If players or hoppers take items in and out of inventories (the case of inputs and outputs inventories), Stockpile needs to rescan those inventories in order to know what's inside them.

*However, if the content of those inventories where not tampered with by external sources, you do not need to rescan them to perform searches or move items to and from them.*


**Arguments**

1. `inventories` : table - A list of the inventories to scan.

**Returns**
1. string - "Info : scan : Done"

**Examples**

`scan(inventories.inputA)`
- Scans the content of the inventories which are part of the "inputA" group.

`scan({"minecraft:barrel_4", "minecraft:chest_8"})`
- Scans the content of the barrel #4 and chest #8.

---

## usage

`usage()`

Returns the usage of the storage over it's maximum capacity.
It calculate fullness by slots, meaning it will return the total amount of slots in the storage system and the amount of currently used slots.

**Returns**
1. table - {["total_slots"] = amount, ["used_slots"] = amount}

---

## get_nbt

`get_nbt(item_id)`

Queries the nbt data of the provided item ID. 

**Arguments**

1. `item_id` : string - The item_id (ex : "minecraft:copper_ingot"). In the case of an item having "special" nbt, such as enchantements, custom display name etc, you will need to provide the `nbt hash` in the item_id arg.

**Returns**
1. table - The item's nbt data in a table form (attribute value pairs).

**Examples**

`get_nbt("minecraft:copper_ingot")`
- Gets the nbt data of the "minecraft:copper_ingot" item.

`get_nbt("minecraft:tipped_arrow-dd185b385cb1a0bf44aa319217d21944")`
- Gets the nbt data of the tipped arrow with the corresponding nbt hash, in that case, an Arrow of Regeneration.

---

## get_content

`get_content()`

Returns the "content" table, representing all of the current server's storage content. Can be used later on by a client.

**Returns**
1. table - List of all the current storage content.

---

## unit

**Functions to manipulate what we call "units", which are essentially groups of inventories.**

`unit.set(unit_name, invs)`

Sets the unit of the specified name to the provided inventory list. If invs = {}, the unit will be removed.

`unit.add(unit_name, invs)`

Adds the provided inventory list to the specified unit.

`unit.remove(unit_name, invs)`

Removes the provided inventory list from the specified unit.

`unit.get()`

Returns the entire "units" table, itself containing the subtables of each units and their compositon.
Auto updates the inventories peripheral in the server's network to find if new ones were added.

`unit.is_io(unit_name, is_io)`

Tells stockpile to count the content of the specified unit towards in the total amount of item in the database.
Use this method to prevent items in ouputs or inputs to be visible by the search() method for example.

**Arguments**

1. `unit_name` : string - The user defined unit name, can be anything apart from "total_count" for name collision reasons. A good first few units to create would be "storage", "input" and "output" for example.

2. `invs` : table - A list of all the inventories you would like to change the states of.

3. `is_io` : boolean - true = will count towards the total, false = will ignored those inventories when counting the total.

**Returns**
1. string - `Info : unit.subfunction : Done`


## Data and floppy disks

Stockpile optimizes database queries and item transfers by avoiding unnecessary rescans of inventory content. Instead, it internally represents storage data, which can grow large depending on your storage size. To handle chunk loading, unloading, or computer shutdowns, this data is stored persistently as a text file on disk.

CC: Tweaked limits storage to 1 MB on computers and 125 KB on floppy disks. Stockpile uses about 2 KB to represent 1,000 items.

For example:

    A storage system for 500,000 items (~145 full double chests) requires 500k / 125k * 2 = 8 floppy disks.
    A 10 million item storage needs ~160 floppy disks.

Keep in mind those numbers are estimates. Adjust the amount of disks used according to your needs. There is no harm in adding a little extra.
You can count ~1MB of real disk space used on your machine or server per million item handled by Stockpile.

To connect floppy disks, place disk drives in your world and insert floppy disks in them. Use networking cables and wired modems to connect them to the Stockpile computer. Make sure to right-click the modems to connect the drives to the network.
Stockpile should now be able to use the floppy disks as data storage space.