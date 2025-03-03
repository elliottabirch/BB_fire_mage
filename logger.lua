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

function Logger:log_table(tbl, indent, max_depth)
    if type(tbl) ~= "table" then
        core.log("Not a table: " .. tostring(tbl))
        return
    end

    indent = indent or ""
    max_depth = max_depth or 3

    if max_depth < 0 then
        core.log(indent .. "... (max depth reached)")
        return
    end

    for k, v in pairs(tbl) do
        local key_str = tostring(k)

        if type(v) == "table" then
            core.log(indent .. key_str .. " = {")
            self.log_table(v, indent .. "    ", max_depth - 1)
            core.log(indent .. "}")
        else
            local val_str = tostring(v)
            core.log(indent .. key_str .. " = " .. val_str)
        end
    end

    -- If the table is empty
    if next(tbl) == nil then
        core.log(indent .. "(empty table)")
    end
end

---@param new_level number
function Logger:set_level(new_level)
    self.level = new_level
end

return Logger
