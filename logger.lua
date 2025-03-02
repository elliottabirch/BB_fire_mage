---@class Logger
---@field logs table
---@field max_logs number
---@field level number
local Logger = {
    logs = {},
    max_logs = 10,
    level = 2
}

---@param message string The message to log
---@param level? number The log level (1=minimal, 2=normal, 3=verbose)
---@return string The logged message
function Logger:log(message, level)
    level = level or 2

    if level <= self.level then
        table.insert(self.logs, 1, message)
        if #self.logs > self.max_logs then
            table.remove(self.logs, self.max_logs + 1)
        end
        core.log(message)
        core.log_file(message)
    end

    return message
end

---@param new_level number
function Logger:set_level(new_level)
    self.level = new_level
end

return Logger
