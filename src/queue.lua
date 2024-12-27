-- Function Queue Manager // Parallel processing | Used for item transfers and scanning inventories content at much higher speed.
queue = {}
queue.__index = queue

-- Create or return the queue instance
function queue.get_instance()
    if not queue._instance then
        queue._instance = setmetatable({tasks = {}}, queue)
    end
    return queue._instance
end

-- Add a function to the queue
function queue.add(func, ...)
    local self = queue.get_instance()
    local args = {...}
    local wrapped_task = function() func(table.unpack(args)) end
    table.insert(self.tasks, wrapped_task)

    -- Auto-run the queue if more than 100 tasks are present
    if #self.tasks > 100 then
        self:run()
    end
end

-- Run all functions in the queue and then clear the queue
function queue.run()
    logger("Debug", "queue.run", "Asynch run of the function queue")
    local self = queue.get_instance()
    if #self.tasks > 0 then
        parallel.waitForAll(table.unpack(self.tasks))
        self.tasks = {}  -- Clear the queue after running
    end
end

return queue