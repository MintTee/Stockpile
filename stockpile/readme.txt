 "Stockpile" is a backend Minecraft storage system running on the Computer Craft:Tweaked mod. It provide a simple, easy to use API
 to input and request items from an arbitrarly big storage system. Any kind of inventory, modded or vanilla, can be used with Stockpile
 as long as it uses the vanilla inventory mechanic (chests, barrels, shulkers...).  It supports modded inventories which have
 more than 54 slots (such as tiered chests for example)

 It can handle the storage of up to 10 million items (or ~2900 double chests) for more than 3000 different item types without
 significant lag or delay in transfers.

 Average transfers time for a full double chest of items ~ 70ms

Features : 

-Multiple user defined storage units, inputs, outputs, and groups. Define machine inputs, multiple user outputs, custom storages etc... 
-Easy to use API to be called from any other program such as the front end gui client, automation programs such as SIGILS, etc...
-Blazingly fast respond time. The program never rescans inventories, making requests extremly fast.
-Expandable. Add storages and just update the peripheral list.
-Huge capacity. Stockpile can handle up to 10 million items with no decrease in responsivity.
-Efficient. Uses the storage space in the most efficient way possible. Always tries to stack items together.
-Mass transfer functions, allows to transfer all of an item type or entire inventories content to other part of the storage.
- Full setup guide and explanations videos on YouTube.
- Parrallelisation of transfers. Handle multiple requests at once in both ways (inputting into a set of invs or outputting)

 The API's methods can be called from anywhere in the computer or be invoked remotly by computers in the same network.

Stockpile cannot read shulkers boxes content nor can it differenciate item nbt data. It only works using item ids (it can't
differentiate types of potions for example). Support for NBT coming soon ?
Stockpile doesn't support modded inventories which
can hold more than 64 items per slots (drawers mod for example. (Support coming soon ?))

Dependencies :
-Lua v5.2 or higher
-Computer Craft:Tweaked vxxx or higher
-Minecraft 1.14 or higher



API methods :

move_item
list(search_string, search method)
scan_content
usage
update_inventories (or config_inv)