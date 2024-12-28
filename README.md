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

If you encounter any issues during the installation process, please report it.

## How to use

#### The API

To execute an API method on the stockpile server, you will need to send a command over Rednet. The command has to be of a string or table type. You will first need to whitelist the client's computer id in the Stockpile server config file.

It's recommended to format the command as a table such as :
- index[1] is the string formatted API method you want to execute.
- index[2] is a unique identifier for the command.

The server's response over rednet will include that UUID, allowing you to asynchronously know which servers's response correspond to what command. The UUID will default to 1 if none is provided.

Format :

```rednet.send(stockpile_server_id, {"command", [command_UUID]})```

Examples :

```rednet.send(123, {[[scan(inventories.storage)]], math.random(1, 2^32)})```
```rednet.send(321, [[list_all_inventories()]])```

In order to collect the server's response, just use ```local server_id, response = rednet.recieve()``` to process it further.

The server's response will be a table where index[1] is the actual returned result and the index[2] is the command UUID. 

#### Whitelisting client IDs

In order for a stockpile server to allow and execute commands sent from other computers, their computer ID have to be whitelisted in the server.

It's a simple security feature to somewhat protect your Stockpile system on untrusted online minecraft servers.

You can access the server's whitelisted client ids in ```stockpile/config/client_id_whitelist.txt``` and add or removed entries following this format : {[123] = true, [456] = true,}

#### Logger settings

A crude logger function is provided with Stockpile.

You can access the servers logs in ```stockpile/logs/logs.txt```. You can set what kind of event will be logged in that file under ```stockpile/config/logger_config.txt``` and change the fields to either ```true``` or ```false``` depending on your debugging needs.

#### Video tutorials

*CommingSoonTM*

## Limitations

- **Modded Slot Sizes:** Stockpile doesn't support modded inventories that can hold more than 64 items per slot (like the Drawers mod). Support coming soon?
- **NBT Limitations:** Due to limitations with the way CC: Tweaked interacts with Minecraft NBT data, Stockpile cannot read some NBT data like shulker content, potency or duration of potions, etc.

## Dependencies

- Lua v5.2 or higher
- CC: Tweaked 1.114.2 or higher with CraftOS v1.9 or higher
- Minecraft 1.20 or higher