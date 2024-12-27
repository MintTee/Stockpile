--Global variables that should be accessible by any modules throughout the program. As of now, only two tables are global :
--content and inventories. Content is a table which represents all the stockpile system content (including inputs, outputs and others)
--Inventories is a table which is used to specify inventory groups to handle item transfer between them.
local data = require("/stockpile/src/data_manager")

content = data.load("/stockpile/database/content.txt")
inventories = data.load("/stockpile/database/inventories.txt")
client_id_whitelist = data.load("/stockpile/config/client_id_whitelist.txt")
logs = data.load("/stockpile/logs/logs.txt") or {}
logger_config = data.load("/stockpile/config/logger_config.txt")