local spellcasting = require("spellcasting")
local spell_data = require("spell_data")
---@class BasePattern
---@field active boolean
---@field state string
---@field start_time number
---@field current_step number The current step in the pattern sequence
---@field steps table
---@field expected_spells table<number, string> Map of step → expected spell ID
---@field start_on_gcd boolean


local BasePattern = {
    active = false,
    state = "NONE",
    start_time = 0,
    start_on_gcd = false
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

---@param player game_object
---@param target game_object
---@return boolean
function BasePattern:execute_default(player, target)
    -- If the pattern defines steps and expected spells
    if self.steps and self.current_step and self.step_logic then
        -- Check if the cast spell matches what we expect for the current step
        local step_name = self.steps[self.current_step]
        local expected_logic = self.step_logic[step_name]

        if step_name == "NONE" then
            self:log("RESETTING: step is NONE")
            return false
        end
        if expected_logic == nil then
            self:log("nil logic for step: " .. step_name, 2)
            return true
        end


        if type(expected_logic) == "table" then
            self:log("---> AUTO-executing current_step " .. self.current_step)
            self:log("---> AUTO-executing state " .. self.state)
            if spellcasting:cast_spell(expected_logic, target, false, false) then
                self:log("successfully casted " .. expected_logic.name)
            else
                self:log("casting " .. expected_logic.name .. "  failed, retrying")
            end
        elseif expected_logic then
            self:log("---> executing current_step " .. self.current_step)
            self:log("---> executing state " .. self.state)
            return expected_logic(player, target)
        else
            self:log("---> no logic for current_step " .. self.current_step)
            self:log("---> no logic for state " .. self.state)
            return false
        end
        return true
    end
    self:log("advance_state is not setup correctly")
    if not self.steps then self:log("NO STEPS SETUP") end
    if not self.current_step then self:log("NO CURRENT STEP SETUP") end
    if not self.step_logic then self:log("NO STEP LOGIC SETUP") end

    return false
end

function BasePattern:advance_state_is_setup()
    -- If the pattern defines steps and expected spells
    if self.steps and self.current_step and self.expected_spells then
        return true
    end
    self:log("advance_state is not setup correctly")
    if not self.steps then self:log("NO STEPS SETUP") end
    if not self.current_step then self:log("NO CURRENT STEP SETUP") end
    if not self.expected_spells then self:log("NO EXPECTED SPELLS SETUP") end

    return false
end

function BasePattern:advance_state(spell_id)
    -- If the pattern defines steps and expected spells
    if self.steps and self.current_step and self.expected_spells then
        -- Check if the cast spell matches what we expect for the current step
        local step_name = self.steps[self.current_step]
        local expected_spell_id = self.expected_spells[step_name]

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
                return false
            end
        end
    end
    return true
end

function BasePattern:complete()
    self.is_completed = true
    if self.reset then
        self:reset()
    end
end

function BasePattern:is_complete()
    return self.is_completed or false
end

return BasePattern
