---@class BasePattern
---@field active boolean
---@field state string
---@field start_time number
local BasePattern = {
    active = false,
    state = "NONE",
    start_time = 0
}

local logger = require("logger")

---@param state string
function BasePattern:set_state(state)
    self.state = state
    logger:log(self.name .. " - State set to: " .. state, 2)
end

---@param message string
---@param level? number
function BasePattern:log(message, level)
    logger:log(self.name .. ": " .. message, level or 2)
end

---@return boolean
function BasePattern:is_active()
    return self.active
end

---@return string
function BasePattern:get_state()
    return self.state
end

---@return number
function BasePattern:get_start_time()
    return self.start_time
end

---@param name string
---@return BasePattern
function BasePattern:new(name)
    local instance = {
        active = false,
        state = "NONE",
        start_time = 0,
        name = name
    }
    setmetatable(instance, { __index = self })
    return instance
end

---@virtual
---@param player game_object
---@return boolean
function BasePattern:should_start(player)
    -- To be overridden
    return false
end

---@virtual
function BasePattern:start()
    self.active = true
    self.start_time = core.time()
    self:log("STARTED - State: " .. self.state, 1)
end

---@virtual
function BasePattern:reset()
    local prev_state = self.state
    self.active = false
    self.state = "NONE"
    self.start_time = 0
    self:log("RESET (from " .. prev_state .. " state)", 1)
end

---@virtual
---@param player game_object
---@param target game_object
---@return boolean
function BasePattern:execute(player, target)
    -- To be overridden
    return false
end

return BasePattern
