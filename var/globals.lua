--Global variables that should be accessible by any modules throughout the program. As of now, only two tables are global :
--content and units. Content is a table which represents all the stockpile system content (including inputs, outputs and others)
--Units is a table which is used to specify inventory groups to handle item transfer between them.
local data = require("/stockpile/src/data_manager")

content = data.load_large_file_from_disks("content.txt") or {["item_index"] = {}, ["inv_index"] = {}}
units = data.load("/stockpile/config/units.txt") or {}
logs = data.load("/stockpile/logs/logs.txt") or {}
logger_config = data.load("/stockpile/config/logger_config.txt")