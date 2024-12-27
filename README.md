# Stockpile

Stockpile is a backend Minecraft storage system running on the ComputerCraft: Tweaked mod. It provides an easy-to-use API to transfer items between inventory groups and powerful search tools in the storage content database.

## Features

- **Blazingly Fast:** Item transfer speed can reach up to 128k items per second. (yes, per second). Usually order O(1) search time in the database.
- **Flexible and Expandable:** Easily add and remove inventories to be part of your storage and define custom inventory groups to suit your needs.
- **Efficient:** Uses storage space in the most efficient way possible, always trying to stack items together.
- **NBT Support:** Filter searches and item transfers using regex searches in NBT data.
- **Easy-to-Use API:** The API is comprehensive and can be called from any other computer, such as a frontend GUI client, automation programs like SIGILS, etc.

## Limitations

- **Modded Inventory Slot Sizes:** Stockpile doesn't support modded inventories that can hold more than 64 items per slot (like the Drawers mod). Support coming soon?
- **NBT Limitations:** Due to limitations with the way CC: Tweaked interacts with Minecraft NBT data, Stockpile cannot read some NBT data like shulker content, potency or duration of potions, etc.

## Dependencies

- Lua v5.2 or higher
- CC: Tweaked 1.114.2 or higher with CraftOS v1.9 or higher
- Minecraft 1.20 or higher
