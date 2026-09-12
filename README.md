<div align="center">
  <img width="260" alt="Stockpile icon" src="icon.jpg">

  # Stockpile

  **A backend-grade Minecraft storage manager for [CC: Tweaked](https://tweaked.cc/).**

  Index millions of items, search the database with NBT-aware regex filters, move them between named inventory groups, and automate using a dedicated scripting language.

  [![License](https://img.shields.io/badge/license-GPLv3-blue.svg)](LICENSE)
  [![CC: Tweaked](https://img.shields.io/badge/CC%3A%20Tweaked-1.114.2%2B-blueviolet)](https://tweaked.cc/)
  [![Minecraft](https://img.shields.io/badge/Minecraft-1.20%2B-success)](https://www.minecraft.net/)
  [![Lua](https://img.shields.io/badge/Lua-5.2%2B-informational)](https://www.lua.org/)

</div>

---

Stockpile turns a room full of chests into a queryable database. The **server** computer indexes every connected inventory, compresses the index to a few kilobytes on disk, and exposes a Rednet API. The **client** computer runs a full graphical UI built with Basalt to browse, search, move, and automate that storage.

---

## Table of contents

- [Highlights](#highlights)
- [Quick start](#quick-start)
- [The client](#the-client)
- [Automation DSL](#automation-dsl)
- [The server](#the-server)
- [API reference](#api-reference)
- [Architecture](#architecture)
- [Technical deep dive](#technical-deep-dive)
- [Configuration](#configuration)
- [Limitations](#limitations)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [License](#license)

---

## Highlights

| | |
|---|---|
| **Blazingly fast** | Transfer up to **128,000 items per second** by parallelizing every `pushItems` call through a coroutine queue. Average database search time: **under 10 ms**. |
| **Compressed databse** | A 350,000-item index (≈100 double chests) uses **24 KB** of real disk space. |
| **NBT-aware** | Search and filter by any NBT attribute using Lua patterns — enchantments, custom names, potion effects... |
| **Named inventory groups** | Define subsets of chests as `input`, `output`, `storage`, `sorted_iron`, or anything else. Move items between them with one call. |
| **GUI client** | A full tabbed interface built on Basalt2: search results with keyboard navigation, a group editor, a live usage bar, and persistent UI state across reboots. |
| **Automation DSL** | Write declarative trigger→action pairs in a simple scripting language: `period(60) and item_qty(coal, farm, <, 64) → scan_group(input)`. |
---

## Quick start

You need **at least two CC: Tweaked computers** with wireless or wired modems, and any number of inventories (chests, barrels, drawers…) connected to the server via the peripheral network.

### Install the server

On the computer that has access to every chest, in a CraftOS shell:

```bash
wget run https://raw.githubusercontent.com/MintTee/Stockpile/refs/heads/main/installer.lua