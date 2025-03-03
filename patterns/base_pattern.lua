---@class BasePattern
---@field active boolean
---@field state string
---@field start_time number
---@field current_step number The current step in the pattern sequence
---@field expected_spells table<number, string> Map of step → expected spell ID

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
    -- Existing reset code
    local prev_state = self.state
    self.active = false
    self.state = "NONE"
    self.start_time = 0
    self.current_step = 1 -- Reset current step
    self.is_completed = false
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

function BasePattern:advance_state(spell_id)
    -- If the pattern defines steps and expected spells
    if self.steps and self.current_step and self.expected_spells then
        -- Check if the cast spell matches what we expect for the current step
        local expected_spell_id = self.expected_spells[self.current_step]

        if expected_spell_id == spell_id then
            self.current_step = self.current_step + 1
            local next_state = self.steps[self.current_step]

            if next_state then
                self:log("Advancing state to " .. next_state, 2)
                self.state = next_state
            else
                -- If there's no next step, we're done
                self:log("Pattern complete - all steps executed", 1)
                self:complete()
            end
            return true
        else
            self:log("Unexpected spell cast: got " .. spell_id ..
                " but expected " .. (expected_spell_id or "none"), 2)
        end
    end

    return false
end

function BasePattern:complete()
    self.is_completed = true
end

function BasePattern:is_complete()
    return self.is_completed or false
end

return BasePattern
