# Stockpile

Stockpile is a backend Minecraft storage system using the CC: Tweaked mod. It provides an easy-to-use API to transfer items between inventory groups. It includes powerful search tools in the storage content database.

## Features

- **Blazingly Fast:** Item transfer speed can reach up to 128k items per second. (yes, per second). Average search time in the database <1 ms.
- **Flexible and Expandable:** Easily add and remove inventories to be part of your storage and define custom inventory groups to suit your needs.
- **Efficient:** Uses storage space in the most efficient way possible, always trying to stack items together.
- **NBT Support:** Filter searches and item transfers using regex searches in NBT data.
- **Easy-to-Use API:** The API is comprehensive and can be called from any other computer, such as a frontend GUI client, automation programs like SIGILS, etc.

## Installation

In a Computer Craft computer, basic or advanced, type ```wget run https://raw.githubusercontent.com/MintTee/Stockpile/refs/heads/main/src/installer.lua```

## Tutorial

**[Using the API]**

To execute an API method on the stockpile server, you will need to send a command over Rednet. The command has to be of a string or table type. You will first need to whitelist the client's computer id in the Stockpile server config file.

It's recommended to format the command as a table such as :
- index[1] is the string formatted API method you want to execute.
- index[2] is a unique identifier for the command that you define.

The server's response over rednet will include that UUID, allowing you to asynchronously know which servers's response correspond to what client's command. The UUID will default to 1 if none is provided or if the command is a string and nott a table.

Format :
```rednet.send(stockpile_server_id, {"command", [command_UUID]})```

Examples :
```rednet.send(123, {[[scan(inventories.storage)]], math.random(1, 2^32)})```
```rednet.send(321, [[list_all_inventories()]])```

In order to collect the server's response, just use ```local server_id, response = rednet.recieve()``` to process it further.
The server's response will be a table where index[1] is the response and the index[2] is the command UUID. 

**[Whitelisting client IDs]**

In order for a stockpile server to allow and execute commands sent from other computers, their computer ID have to be whitelisted in the server. It's a simple security feature to somewhat protect your Stockpile system on untrusted online servers.

1) Go to your Stockpile server and abort the running process either by pressing ```Ctrl + T``` on pc or ```Cmd + T``` on Mac.

2) Type ```edit stockpile/config/client_id_whitelist.txt```

3) Add the computer ID you would like to whitelsite to the list. To know a computer's id, type ```id``` in the shell.
Example :
```
{
    [123] = true,
    [40] = true,
    [41] = true,
}
```
5) Save the content of the file and reboot the computer.

**[Logger settings]**

A crude logger function is provided with Stockpile. You can access the servers logs in ```stockpile/logs/logs.txt```. You can set what kind of event will be logged in that file under ```stockpile/config/logger_config.txt``` and change the fields to either ```true``` or ```false``` depending on your debugging needs.

**[Video tutorials]**

*CommingSoonTM*

## API Documentation

```move_item(from_invs, to_invs, [item_filter], [quantity_filter], [nbt_filter])```

Moves all the item contained in a group of inventories to an other. You can filter the item moved and quantities in multiple ways. If no item filter is specified, it will flag every item for transfer. Same thing with the nbt_filter. If no quantity filter is specified, it will try to move the maximum amount of items.

You can combine the three filters for fine control over the moved item parameters.

**Arguments**

1. *from_invs* : table - A list of the source inventories.
2. *to_invs* : table - A list table of the destination inventories.
3. *item_filter* : string - Regex filter for the item ids. If an item id matches this filter, it will be flagged to be move.
4. *quantity_filter* : number - The limit on the amount of items to transfer.
5. *nbt_filter* : string - Regex filter for the item's nbt data. The nbt data is serialized and therefore this filter will look for any matching pattern, independently of the nbt's attribute structure.

**Returns**
1. string - *"Info : move_item : Success"*
2. string - *"Warn : move_item : Destination inventories are probably full, aborting transfer request. Please verify the destinations have empty space"*

**Examples**

```move_item(inventories.input, inventories.storage)```
Transfers all the items from the inventory group "input" to the inventory group "storage".

```move_item(inventories.storage, inventories.output, "arrow")```
Transfers all item matching "arrow" in their id (minecraft:arrow, minecraft:tipped_arrow...) from the inventory group "storage" to the inventory group "output".

```move_item({"minecraft:chest_20", "minecraft:chest_21"}, {"minecraft:barrel_15"}, _, 10, "Sharpness")```
Transfers up to 10 items matching "Sharpness" in their nbt from chest #20 and #21 to barrel #15.

---

```search([item_filter], [nbt_filter])```

Regex search in your storage's database, that is, in all the content of your storage system.

**Arguments**

1. *item_filter* : string - Regex filter for the item ids. If an item id matches this filter, it will be added to the returned result list.
2. *nbt_filter* : string - Regex filter for the item ids. If an item's serialized nbt data matches this filter, it will be added to the returned result list.

**Returns**
1. table - A table containing all the result of your search. Item ids are keys and the total amount held in the storage are their values.

**Examples**

```search(":stone$")```
Will only return the "minecraft:stone" item and not "minecraft:redstone" (because of the regex expression).

```search("tipped", "Heal")```
Will return the item "minecraft:tipped_arrow" of the "Healing" type and not the "Poison" type (because of the added nbt filter).

---

```scan(inventories)```

Scan an inventory group's content in order to update Stockpile's database.

**This method is to be used when the content of an inventory is not solely defined by Stockpile**. If players or hoppers take items in and out of inventories (the case of inputs and outputs inventories), Stockpile needs to rescan those inventories in order to know what's inside them.

*However, if the content of those inventories where not tampered with by external sources, you do not need to rescan them to perform searches or move items to and from them.*


**Arguments**

1. *inventories* : table - A list of the inventories to scan.

**Returns**
1. string - "Info : scan : Done"

**Examples**

```scan(inventories.inputA)```
Scans the content of the inventories which are part of the "inputA" group.

```scan({"minecraft:barrel_4", "minecraft:chest_8"})```
Scans the content of the barrel #4 and chest #8.

---

```usage()```

Returns the usage of the storage over it's maximum capacity.
It calculate fullness by slots, meaning it will return the total amount of slots in the storage system and the amount of currently used slots.

**Returns**
1. table - {["total_slots"] = amount, ["used_slots"] = amount}

---

```get_nbt(item_id)```

Queries the nbt data of the provided item ID. 

**Arguments**

1. *item_id* : string - The item_id (ex : "minecraft:copper_ingot"). In the case of an item having "special" nbt, such as enchantements, custom display name etc, you will need to provide the ```nbt hash``` in the item_id arg.

**Returns**
1. table - The item's nbt data in a table form (attribute value pairs).

**Examples**

```get_nbt("minecraft:copper_ingot")```
Gets the nbt data of the "minecraft:copper_ingot" item.

```get_nbt("minecraft:tipped_arrow-dd185b385cb1a0bf44aa319217d21944")```
Gets the nbt data of the tipped arrow with the corresponding nbt hash, in that case, an Arrow of Regeneration.

---

```list_all_inventories()```

Returns a list of all the connected peripherals of the "inventory" type found in the server's network.
You process that list in order to easily configure units later on.

**Returns**
1. table - List of all connected inventories.

---

```config_unit```

Functions to manipulate what we call "units", which are essentially groups of inventories.

```config_unit.set(invs, unit_name)```
Sets the unit of the specified name to the provided inventory list. If invs = {}, the unit will be removed.
```config_unit.add(invs, unit_name)```
Adds the provided inventory list to the specified unit.
```config_unit.remove(invs, unit_name)```
Removes the provided inventory list from the specified unit.
```config_unit.counts_towards_total(unit_name, counts_towards_total)```
Tells stockpile to count the content of the specified unit towards in the total amount of item in the database.
Use this method to prevent items in ouputs or inputs to be visible by the search() method for example.

**Arguments**

1. *unit_name* : string - The user defined unit name, can be anything apart from "total_count" for name collision reasons. A good first few units to create would be "storage", "input" and "output" for example.

2. *invs* : table - A list of all the inventories you would like to change the states of.

3. *counts_towards_total* : boolean - true = will count towards the total, false = will ignored those inventories when counting the total.

---


## Limitations

- **Modded Slot Sizes:** Stockpile doesn't support modded inventories that can hold more than 64 items per slot (like the Drawers mod). Support coming soon?
- **NBT Limitations:** Due to limitations with the way CC: Tweaked interacts with Minecraft NBT data, Stockpile cannot read some NBT data like shulker content, potency or duration of potions, etc.

## Dependencies

- Lua v5.2 or higher
- CC: Tweaked 1.114.2 or higher with CraftOS v1.9 or higher
- Minecraft 1.20 or higher