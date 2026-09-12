# Stockpile — API Documentation

This document describes the **Rednet API exposed by the Stockpile server** and the **data model** it operates on. It is written for anyone building a program that talks to Stockpile: GUI clients, automation scripts, integration shims, or your own custom tools.

If you just want to install and use the built-in client, see [README.md](README.md) instead.

---

## Table of contents

- [Overview](#overview)
- [Protocol](#protocol)
  - [Finding the server](#finding-the-server)
  - [Message format](#message-format)
  - [Response format](#response-format)
  - [Async pattern](#async-pattern)
  - [Error handling](#error-handling)
- [API commands](#api-commands)
  - [`move_item`](#move_item)
  - [`search`](#search)
  - [`scan`](#scan)
  - [`usage`](#usage)
  - [`get_nbt`](#get_nbt)
  - [`get_content`](#get_content)
  - [`list_all_inventories`](#list_all_inventories)
- [Data model](#data-model)
  - [`item_index`](#item_index)
  - [`inv_index`](#inv_index)
  - [Inventory groups](#inventory-groups)
- [Cookbook](#cookbook)
- [Appendix](#appendix)

---

## Overview

Stockpile exposes a small, flat API over [Rednet](https://tweaked.cc/module/rednet.html) on the protocol string `"stockpile"`. There are **seven commands**, each taking a fixed-shape argument list and returning a structured response.

The server is a singleton: it broadcasts its computer ID via `rednet.host("stockpile", <id>)`, and any computer on the same Rednet network can look it up with `rednet.lookup("stockpile")`.

Every command is **stateless from the caller's perspective**. You don't authenticate, you don't open a session, you don't handshake. You send a message, you get a response. The server queues commands internally and processes them one at a time.

> **Server whitelist.** The server intentionally does not verify the sender. Any computer on your Rednet network can move items. If you need access control, wrap the server with your own security layer or restrict Rednet physically.

---

## Protocol

### Finding the server

The server calls `rednet.host("stockpile", tostring(os.getComputerID()))` at startup. Clients discover it via:

```lua
rednet.open("back")                -- or whatever side your modem is on
local server_id = rednet.lookup("stockpile")
if not server_id then
    error("No stockpile server on the network")
end
```

`rednet.lookup` returns `nil` if no host is registered under the protocol. It returns the computer ID otherwise.

If you have multiple modems, open all of them — `rednet.lookup` will find the server on any open interface:

```lua
for _, name in ipairs(peripheral.getNames()) do
    if peripheral.hasType(name, "modem") then
        rednet.open(name)
    end
end
```

### Message format

Every command is a **table** with three fields:

```lua
{
    type = "move_item",       -- string: which command to run
    args = { ... },           -- table: command-specific arguments
    uuid = 12345,             -- number: any unique integer you choose
}
```

| Field | Type | Required | Notes |
|---|---|---|---|
| `type` | string | yes | Must be one of the seven command names. |
| `args` | table | yes | Contents depend on `type`. Pass `{}` for argument-less commands. |
| `uuid` | number | yes | Any integer unique to this in-flight request. Used to correlate responses. |

Send it with:

```lua
rednet.send(server_id, message, "stockpile")
```

The server rejects malformed messages silently — if `type` isn't a string, `args` isn't a table, or `uuid` isn't a number, the message is dropped without a response. Make sure your UUIDs are valid integers (`math.random(1, 2^31)` is a fine choice).

### Response format

The server echoes your original message back with a **`result`** field added:

```lua
{
    type   = "move_item",
    args   = { ... },                    -- unchanged
    uuid   = 12345,                      -- unchanged, use this to match
    sender = 42,                         -- server's computer ID
    result = {
        status = "done",                 -- "done" or "fail"
        detail = "Moved 1728 items",     -- human-readable summary
        data   = { ... },                -- optional, command-specific
    },
}
```

| Field | Type | Notes |
|---|---|---|
| `result.status` | string | `"done"` on success, `"fail"` on failure. **Always check this.** |
| `result.detail` | string | Free-form description. Useful for logging; not machine-parseable. |
| `result.data` | table or nil | Command-specific payload. Only some commands return this. |

The response preserves your original `type`, `args`, and `uuid` verbatim, so you can route it to the right handler without keeping a separate correlation table — but in practice you'll still want one, because you can't know which outgoing message a `rednet.send`-receive cycle belongs to without one.

### Async pattern

The idiomatic way to use the API is a **request table + parallel receive loop**:

```lua
local pending = {}  -- uuid -> callback

local function send(cmd_type, args, callback)
    local uuid = math.random(1, 2^31)
    pending[uuid] = { callback = callback, timer = os.startTimer(10) }
    rednet.send(server_id, { type = cmd_type, args = args, uuid = uuid }, "stockpile")
end

local function handle(sender, message, protocol)
    if protocol ~= "stockpile" then return end
    local entry = pending[message.uuid]
    if not entry then return end

    if os.cancelTimer(entry.timer) then pending[message.uuid] = nil end
    if entry.callback then entry.callback(message.result) end
end

local function handle_timeout(timer)
    for uuid, entry in pairs(pending) do
        if entry.timer == timer then
            pending[uuid] = nil
            if entry.callback then entry.callback(nil) end
            return
        end
    end
end

parallel.waitForAny(
    function() while true do handle(rednet.receive("stockpile")) end end,
    function() while true do local _, t = os.pullEvent("timer"); handle_timeout(t) end end,
    function() while true do
        -- your app's event loop
    end end
)
```

The **10-second timeout** is not enforced by the server — it's a convention the built-in client uses. Pick whatever timeout your workload tolerates. Scanning 5,000 slots can take several seconds; moving items is near-instant.

### Error handling

Every command returns a structured result, so you never get a raw Lua error over the wire. But **`status = "fail"` does not mean the same thing for every command**:

- A **validation failure** (bad argument type) returns `status = "fail"` with a `detail` describing what was wrong.
- A **runtime failure** (destination chests full) returns `status = "fail"` with a `detail` describing what was full.
- A **partial failure** (some items moved, some didn't) returns `status = "done"` — the server does not currently report partial success separately.

If you need exact accounting, call `get_content()` after the move and diff against your previous snapshot.

---

## API commands

### `move_item`

**Signature**

```
move_item(from_invs, to_invs, [item_filter], [quantity], [nbt_filter])
```

Move items between two sets of inventories, with optional filtering.

**Arguments**

| # | Name | Type | Required | Description |
|---|---|---|---|---|
| 1 | `from_invs` | table | yes | List of inventory peripheral names to move **from**. |
| 2 | `to_invs` | table | yes | List of inventory peripheral names to move **to**. |
| 3 | `item_filter` | string \| table | no | Lua pattern (or list of patterns) matching item IDs. If nil, all items are eligible. |
| 4 | `quantity` | number | no | Global cap on the number of items moved. Applied across all matched items. If nil, moves everything. |
| 5 | `nbt_filter` | string | no | Lua pattern over the flattened NBT corpus. Only items with at least one matching NBT attribute are moved. |

**Returns**

`result.data` is not populated. Check `result.status` and read `result.detail` for the outcome.

**Examples**

Move everything from `input` to `storage`:

```lua
send("move_item", {
    {"minecraft:chest_5", "minecraft:chest_6"},
    {"minecraft:chest_20", "minecraft:chest_21", "minecraft:chest_22"},
}, function(result)
    print(result.status, result.detail)
end)
```

Move exactly 1,728 iron ingots from `storage` to `sorted_iron`:

```lua
send("move_item", {
    storage_invs,
    sorted_invs,
    "minecraft:iron_ingot",
    1728,
}, callback)
```

Move every sword with Sharpness IV or higher:

```lua
send("move_item", {
    storage_invs,
    weapons_invs,
    "netherite_sword",       -- item filter
    nil,                     -- no qty cap
    "Sharpness",             -- nbt filter
}, callback)
```

Move any of several item types at once (V2 feature — accepts a list):

```lua
send("move_item", {
    from_invs,
    to_invs,
    { "minecraft:iron_ingot", "minecraft:gold_ingot", "minecraft:copper_ingot" },
    nil,
}, callback)
```

**Gotchas**

- The move is **best-effort**: if the destination fills up partway through, the server moves as much as it can and returns `status = "done"` with a detail describing what stopped.
- The `quantity` cap is **global**, not per-item. If you pass `item_filter = {iron, gold}` and `quantity = 100`, the server will move 100 items total, not 100 of each.
- The `nbt_filter` uses the *flattened* NBT corpus — a list of all leaf strings across every attribute. `"Sharpness"` matches; `"enchantments.0.id"` does not.
- `from_invs` and `to_invs` must be **different lists**. Moving into an inventory that's already in `from_invs` is undefined behaviour.

---

### `search`

**Signature**

```
search([item_filter], [nbt_filter])
```

Search the current database for items matching the given filters. Searches the server's in-memory index — no rescan is triggered.

**Arguments**

| # | Name | Type | Required | Description |
|---|---|---|---|---|
| 1 | `item_filter` | string | no | Lua pattern over item IDs. Empty string matches everything. |
| 2 | `nbt_filter` | string | no | Lua pattern over the flattened NBT corpus. |

**Returns**

`result.data` is a table where the **key** is the full item ID (including hash suffix for NBT-distinct items) and the **value** is the total quantity in storage.

```lua
{
    ["minecraft:iron_ingot"] = 12480,
    ["minecraft:gold_ingot"] = 3840,
    ["minecraft:diamond_sword-3a4f..."] = 1,
}
```

Items with zero total are never returned.

**Examples**

Search for anything containing "coal":

```lua
send("search", { "coal" }, function(result)
    for id, qty in pairs(result.data) do
        print(string.format("%-40s %d", id, qty))
    end
end)
```

Search for potions with a specific NBT attribute:

```lua
send("search", { "potion", "Strength" }, callback)
```

**Gotchas**

- The filter is a **Lua pattern**, not a substring search. `"stone"` matches `"redstone"` and `"cobblestone"`. Use `":stone$"` for an exact suffix match.
- The pattern is anchored **nowhere** by default — `string.match(item_name, pattern)` accepts any substring. Use `^` and `$` for full-string matching.
- Special pattern characters (`(`, `)`, `.`, `%`, `+`, `-`, `*`, `?`, `[`, `]`, `^`, `$`) must be escaped with `%`. Yes, this includes the hyphen in `"-"` and the underscore is fine.
- NBT items get a **hash suffix** in their ID (e.g. `minecraft:potion-abc123...`). Two potions of the same type but different effects appear as separate entries.
- This command is **cheap** — it reads an in-memory table. Run it as often as you like.

---

### `scan`

**Signature**

```
scan(inventories)
```

Re-read the contents of the given inventories and update the server's database. This is the command you use when external sources (players, hoppers, command blocks) have modified a chest's contents behind Stockpile's back.

**Arguments**

| # | Name | Type | Required | Description |
|---|---|---|---|---|
| 1 | `inventories` | table | yes | List of inventory peripheral names to rescan. |

**Returns**

`result.data` is not populated. Check `result.status`.

**Examples**

Rescan a single group:

```lua
send("scan", { { "minecraft:chest_5", "minecraft:chest_6" } }, function(result)
    print("Rescan done: " .. result.detail)
end)
```

Rescan everything:

```lua
send("list_all_inventories", {}, function(result)
    send("scan", { result.data }, callback)
end)
```

**Gotchas**

- **Scanning is expensive.** The server fires a `peripheral.call("getItemDetail", slot)` for every slot in every inventory you list. Scanning 100 double chests is 5,400 peripheral calls.
- **You do not need to scan after a `move_item`.** The server updates its index in-place as it moves items.
- **You do not need to scan after a reboot** if the server loaded its database successfully. The index is persisted.
- **You do need to scan** if the chest's contents could have changed without Stockpile knowing: player interaction, hopper input/output, command block shulker-box manipulation, etc.
- A good habit is to scan your `input` and `output` groups on a `period()` trigger — say, every 300 seconds — so the database stays fresh without manual intervention.

---

### `usage`

**Signature**

```
usage()
```

Return storage utilization metrics.

**Arguments**

None. Pass `{}`.

**Returns**

`result.data` contains:

```lua
{
    total_slots = 5400,      -- sum of .size across every inventory in the DB
    used_slots  = 2384,      -- sum of ceil(qty / stack_size) across every item
}
```

**Examples**

```lua
send("usage", {}, function(result)
    local u = result.data
    local pct = math.floor(u.used_slots / u.total_slots * 100)
    print(string.format("%d / %d slots (%d%%)", u.used_slots, u.total_slots, pct))
end)
```

**Gotchas**

- `used_slots` is an **estimate** — it assumes perfect stacking. Real storage will have partially filled slots and singleton leftovers.
- `total_slots` counts only inventories that are currently in the database. If you haven't scanned a chest yet, it doesn't count.
- Non-storage inventories (input/output buffers) **are** included in the total. If you want to exclude them, compute the total yourself from `inv_index` after filtering by group.

---

### `get_nbt`

**Signature**

```
get_nbt(item_id)
```

Return the raw NBT of a specific item, as read by CC: Tweaked.

**Arguments**

| # | Name | Type | Required | Description |
|---|---|---|---|---|
| 1 | `item_id` | string | yes | The **full** item ID, including the hash suffix for NBT-distinct items. |

**Returns**

`result.data` is the CC: Tweaked `getItemDetail` result — a table mirroring the item's NBT structure.

**Examples**

```lua
send("get_nbt", { "minecraft:netherite_sword-3a4f8b1c..." }, function(result)
    -- result.data.enchantments, result.data.display.Name, ...
    print(textutils.serialize(result.data))
end)
```

**Gotchas**

- If the item has been moved or consumed since the last scan, the underlying peripheral call may fail. The server returns `status = "fail"` in that case.
- For items with **no** special NBT (i.e. the default NBT hash), you can query by the bare ID: `send("get_nbt", { "minecraft:iron_ingot" }, cb)`.
- The NBT returned here is **raw**, unlike `search`'s flattened corpus. This is what you want if you need structured access to enchantment levels, custom names, or potion effects.

---

### `get_content`

**Signature**

```
get_content()
```

Return the entire database — the item index and the inventory index.

**Arguments**

None. Pass `{}`.

**Returns**

`result.data` contains two tables:

```lua
{
    item_index = { ... },    -- see "Data model"
    inv_index  = { ... },    -- see "Data model"
}
```

**Examples**

```lua
send("get_content", {}, function(result)
    local items  = result.data.item_index
    local invs   = result.data.inv_index

    local total = 0
    for _, entry in pairs(items) do total = total + entry.total end
    print("Total items in storage: " .. total)
end)
```

**Gotchas**

- **This is a full database dump.** On a large storage system it can be several hundred kilobytes. The Rednet transmission layer handles messages up to the CC: Tweaked modem limit, but a >1 MB payload may be truncated or fail. Test on your hardware.
- The built-in client fetches content **once at startup** and then relies on scan/events to stay in sync. It does *not* poll `get_content` on a timer.
- If you're writing a long-running client, subscribe to your own "content changed" signals rather than calling this repeatedly.

---

### `list_all_inventories`

**Signature**

```
list_all_inventories()
```

Return the names of every peripheral on the server's network that reports an `inventory` type.

**Arguments**

None. Pass `{}`.

**Returns**

`result.data` is a **sorted list** of peripheral names:

```lua
{
    "minecraft:barrel_3",
    "minecraft:chest_0",
    "minecraft:chest_1",
    "minecraft:chest_10",
    "minecraft:chest_11",
    ...
}
```

**Examples**

```lua
send("list_all_inventories", {}, function(result)
    print(#result.data .. " inventories connected")
    for _, name in ipairs(result.data) do print("  " .. name) end
end)
```

**Gotchas**

- Only peripherals whose **type includes `"inventory"`** are listed. Chests, barrels, shulkers, and most modded inventories qualify. Fluid tanks do not (fluids are not yet supported).
- The server sorts the list before returning, so clients can rely on a stable ordering.
- Calling this **does not** scan any inventories. It only enumerates them.

---

## Data model

The server maintains two in-memory indexes and persists both to disk. Understanding their shape is essential for writing anything nontrivial against the API.

### `item_index`

A flat map from **item ID** to a summary record. Every item that exists anywhere in storage has exactly one entry.

```lua
item_index = {
    ["minecraft:iron_ingot"] = {
        displayName    = "Iron Ingot",           -- human-readable name
        stack_size     = 64,                     -- max stack size for this item
        total          = 12480,                  -- total quantity across all inventories
        nbt            = { ... },                -- flattened NBT corpus (list of strings)
        location       = {                       -- where the item lives
            ["minecraft:chest_0"]  = { [5] = 64, [6] = 64, [7] = 32 },
            ["minecraft:chest_1"]  = { [1] = 64 },
        },
        part_filled_slots = {                    -- subset of location where qty < stack_size
            ["minecraft:chest_0"] = { [7] = 32 },
        },
    },
    ["minecraft:diamond_sword-3a4f..."] = {
        displayName = "Diamond Sword",
        stack_size  = 1,
        total       = 1,
        nbt         = { "Sharpness", "Unbreaking", "durability", "damage", ... },
        location    = { ["minecraft:chest_20"] = { [11] = 1 } },
        part_filled_slots = { ["minecraft:chest_20"] = { [11] = 1 } },
    },
}
```

**Field notes**

| Field | Meaning |
|---|---|
| `displayName` | Best-effort readable name. Modded items may render differently. |
| `stack_size` | Max stack size in a single slot. Always 64 or 1 in vanilla. |
| `total` | Sum of all quantities across `location`. Recomputed on every scan. |
| `nbt` | Flat list of every **leaf string** across the item's NBT tree. This is what `search`'s `nbt_filter` matches against. |
| `location` | Nested map: `inv_name → slot_index → qty`. Every stack of this item in storage appears here. |
| `part_filled_slots` | Filtered subset of `location` where `qty < stack_size`. Used by `move_item` to fill partial stacks first. |

**NBT hash suffix.** When an item has non-default NBT (enchantments, custom names, durability damage), CC: Tweaked assigns it a **content hash**. Stockpile appends that hash to the item ID with a `-` separator. Two diamond swords with different enchantment levels are distinct entries with distinct IDs.

### `inv_index`

A map from **inventory name** to that inventory's metadata and slot contents.

```lua
inv_index = {
    ["minecraft:chest_0"] = {
        size  = 27,                             -- number of slots
        slots = {                               -- sparse: only non-empty slots appear
            [1]  = { ["minecraft:cobblestone"] = 64 },
            [2]  = { ["minecraft:cobblestone"] = 64 },
            [3]  = { ["minecraft:iron_ingot"]  = 32 },
            [15] = { ["minecraft:diamond"]     = 5 },
        },
    },
}
```

**Field notes**

| Field | Meaning |
|---|---|
| `size` | Number of slots in this inventory. 27 for a single chest, 54 for a double, 27 for most modded. |
| `slots` | Sparse map: **only occupied slots** appear. `slot_index → { [item_id] = qty }`. |

**Why nested?** A single slot can only ever hold one item type in vanilla Minecraft. The inner table always has exactly one key. The nesting exists so modded slots that hold multiple items can be supported in a future version.

### Inventory groups

Groups are a **client-side** concept. The server has no idea what a group is. When the client calls `move_item(group_a, group_b)`, it expands each group into a flat list of inventory names before sending the message.

The client persists groups to `/stockpile/config/groups.txt`:

```lua
groups = {
    all    = { "minecraft:chest_0", "minecraft:chest_1", ... },
    input  = { "minecraft:chest_5", "minecraft:chest_6" },
    output = { "minecraft:chest_20" },
    sorted_iron = { "minecraft:chest_22", "minecraft:chest_23" },
}
```

The `all` group is auto-maintained: it always contains every inventory the server reports. All other groups are user-defined.

If you're writing your own client, you'll want to replicate this pattern: keep a local table of groups, expand them before calling the API, and save them to disk on modification.

---

## Cookbook

### Fetch the current storage and search it locally

```lua
local function search_local(pattern)
    send("get_content", {}, function(result)
        local hits = {}
        for id, entry in pairs(result.data.item_index) do
            if id:match(pattern) then
                hits[id] = entry.total
            end
        end
        for id, qty in pairs(hits) do
            print(string.format("%-40s %d", id, qty))
        end
    end)
end

search_local(":ingot$")
```

Fetching once and caching is far cheaper than calling `search` repeatedly, if you're doing many queries.

### Wait for a scan to finish before querying

```lua
local function rescan_and_query(invs, pattern)
    send("scan", { invs }, function(scan_result)
        if scan_result.status ~= "done" then
            print("Scan failed: " .. scan_result.detail)
            return
        end
        send("search", { pattern }, function(search_result)
            for id, qty in pairs(search_result.data) do print(id, qty) end
        end)
    end)
end
```

Because the server processes commands one at a time, you don't need to worry about races — but you do need to **chain** your callbacks so the second command fires after the first completes.

### Periodic rescan of input/output buffers

```lua
local input_invs  = { "minecraft:chest_5", "minecraft:chest_6" }
local output_invs = { "minecraft:chest_20" }

basalt.schedule(function()
    while true do
        sleep(300)
        send("scan", { input_invs  }, function() end)
        send("scan", { output_invs }, function() end)
    end
end)
```

Run two scans back-to-back. The server queues them; the second starts once the first finishes.

### Move items, then wait for the DB to be consistent

```lua
local function safe_move(from, to, item, qty, on_done)
    send("move_item", { from, to, item, qty }, function(move_result)
        if move_result.status ~= "done" then
            on_done(false, move_result.detail)
            return
        end
        -- The server has already updated its index, but wait one tick
        -- to make sure the response has propagated.
        sleep(0.1)
        send("get_content", {}, function(content_result)
            on_done(true, content_result.data)
        end)
    end)
end
```

### Discover what's on the network

```lua
send("list_all_inventories", {}, function(result)
    print("Connected inventories:")
    for _, name in ipairs(result.data) do print("  " .. name) end
end)
```

### Total storage efficiency report

```lua
local function report()
    send("usage", {}, function(result)
        local u = result.data
        print(string.format("Storage: %d / %d slots (%.1f%%)",
            u.used_slots,
            u.total_slots,
            u.used_slots / u.total_slots * 100))
    end)
end
```

---

## Appendix

### Error codes

`result.status` is always one of:

- `"done"` — the command completed, possibly with warnings noted in `detail`.
- `"fail"` — the command did not run, or ran and hit a fatal problem.

There are no numeric error codes. Read `detail` for context.

### Command summary table

| Command | Arguments | Returns `data`? |
|---|---|---|
| `move_item` | `from, to, [item], [qty], [nbt]` | no |
| `search` | `[item], [nbt]` | yes — `{ [id] = qty }` |
| `scan` | `invs` | no |
| `usage` | *(none)* | yes — `{ total_slots, used_slots }` |
| `get_nbt` | `item_id` | yes — raw NBT table |
| `get_content` | *(none)* | yes — `{ item_index, inv_index }` |
| `list_all_inventories` | *(none)* | yes — sorted list of names |

### Protocol version

This document describes the API as of the **V2 unified release**. The V1 protocol was string-based (`{"move_item(...)", uuid}`) and is **not compatible**. Clients written against V1 must be updated to the table-based message format described here.

### Data persistence

The server writes two files to disk:

| File | Contents |
|---|---|
| `server/bin/db.bin` | Bit-packed, dictionary-encoded, DEFLATE-compressed index |
| `server/bin/dict.bin` | Compressed string dictionary shared by `db.bin` |

Both are written on a `db_changed` trigger, at most once every 5 seconds. On startup the server reads them back; if they're missing or corrupt, the server starts with an empty index and you'll need to scan everything manually.

Floppy disk support is planned for very large storage systems (>1 MB index). For now, ensure your server has enough free disk space to hold the compressed DB. A rough rule: **~70 KB per million items**.

### Further reading

- [README.md](README.md) — installation, high-level feature tour
- [CONTRIBUTING.md](CONTRIBUTING.md) — how to submit patches
- [`server/src/bin.lua`](server/src/bin.lua) — the bit-packing format specification, in a comment at the top
- [`server/src/contentdb.lua`](server/src/contentdb.lua) — the reference implementation of every command