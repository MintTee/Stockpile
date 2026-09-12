<div align="center">
  <img width="250px" alt="icon" src="icon.jpg">  
</div>


# Stockpile

Stockpile is a backend Minecraft storage system using the CC: Tweaked mod. It provides an easy-to-use API to transfer items between inventory groups in a finely controlled way. It includes powerful search tools in the storage content database.

**[Documentation](https://github.com/MintTee/Stockpile/blob/main/Documentation.md)** here.

## Features

- **Blazingly Fast:** Item transfer speed can reach up to 128k items per *second*. Average search time in the database <10 ms.
- **Flexible and Expandable:** Easily add and remove inventories to be part of your storage and define custom inventory groups to suit your needs.
- **Efficient:** Uses storage space in the most efficient way possible, always trying to stack items together.
- **NBT Support:** Filter searches and item transfers using regex searches in NBT data.
- **Easy-to-Use API:** The API is comprehensive and can be called from any other computer, such as a frontend GUI client, automation programs, etc.

## Installation

Inside a Computer Craft computer, type `wget run https://raw.githubusercontent.com/MintTee/Stockpile/refs/heads/main/src/installer.lua`

If you encounter any issue during the installation process, please report it [here](https://github.com/MintTee/Stockpile/issues).

## Limitations

- **Modded Slot Sizes:** Stockpile doesn't support modded inventories that can hold more than 64 items per slot (like the Drawers mod).
- **NBT Limitations:** Due to limitations with the way CC: Tweaked interacts with Minecraft NBT data, Stockpile cannot read some NBT data like shulker content, potency or duration of potions, etc.
- **No support for fluids mechanics** *ComingSoonTM*

## Roadmap

- **Fluid support:** Adding fluid support to Stockpile.
- **GUI Survival Client** An easy to use comprehensive GUI Client to search and query items from Stockpile with search features similar to JEI, REI or EMI.  
- **SIGILS Compat** A simple program to make interfacing Stockpile with [SIGILS](https://github.com/fechan/SIGILS) easy.
- **Auto schematic material list** Feature to automatically pull every item requiered from a schematic material list.

## Dependencies

- Lua v5.2 or higher
- CC: Tweaked 1.114.2 or higher with CraftOS v1.9 or higher
- Minecraft 1.20 or higher