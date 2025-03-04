local spellcasting = require("spellcasting")
local spell_data = require("spell_data")
local logger = require("logger")

---@class PatternManager
---@field active_pattern BasePattern|nil The currently active pattern
---@field patterns table<string, BasePattern> All available patterns
local PatternManager = {
    active_pattern = nil,
    patterns = {}
}

---@param name string Pattern identifier
---@param pattern BasePattern Pattern instance to register
function PatternManager:register_pattern(name, pattern)
    self.patterns[name] = pattern
    return self
end

---@param player game_object The player object
---@param target game_object The target object
---@return boolean True if a pattern is active and executing
function PatternManager:execute_active_pattern(player, target)
    if not self.active_pattern then
        return false
    end

    local result = self.active_pattern:execute(player, target)
    -- If execution returns false, pattern is finished
    if not result then
        self.active_pattern = nil
    end
    return true
end

---@param player game_object The player object
---@param context table Additional context data for pattern selection
---@return boolean True if a pattern was started
function PatternManager:select_pattern(player, context)
    -- Don't select a new pattern if one is already active
    if self.active_pattern then
        return false
    end

    -- Define pattern priority order based on context
    local pattern_priority = self:get_pattern_priority(context)

    -- Try to start patterns in priority order
    for _, pattern_name in ipairs(pattern_priority) do
        local pattern = self.patterns[pattern_name]
        if pattern and pattern:should_start(player, context) then
            self.active_pattern = pattern
            pattern:start()
            return true
        end
    end

    return false
end

---@param context table Context data to determine pattern priority
---@return table<string> Ordered list of pattern names by priority
function PatternManager:get_pattern_priority(context)
    -- Default priority (can be dynamically adjusted based on context)
    local is_combustion_active = context.combustion_active or false

    if is_combustion_active then
        return {
            "combustion_opener",
            "pyro_fb",
            "pyro_pf",
            "scorch_fb"
        }
    else
        return {
            "combustion_opener",
            "fireball_hotstreak"
        }
    end
end

---@return string Description of the active pattern and its state
function PatternManager:get_active_pattern_info()
    if not self.active_pattern then
        return "None"
    end

    return self.active_pattern.name .. ": " .. self.active_pattern.state
end

---@param spell_id number The ID of the spell that was cast
function PatternManager:handle_spell_cast(spell_id)
    if spell_data.SPELL_BY_ID[spell_id] then
        spellcasting:set_last_cast(spell_data.SPELL_BY_ID[spell_id])
    end

    if not self.active_pattern then
        return
    end

    -- Allow patterns to react to spell casts
    -- This is useful for interrupting patterns when certain spells are manually cast
    if self.active_pattern.on_spell_cast then
        self.active_pattern:on_spell_cast(spell_id)
    end
end

---@param player game_object The player object
function PatternManager:handle_combustion_state_change(player, was_active, is_active)
    -- Reset combustion-specific patterns when combustion ends
    if was_active and not is_active then
        for name, pattern in pairs(self.patterns) do
            if name == "pyro_fb" or name == "pyro_pf" or name == "scorch_fb" then
                if pattern.active then
                    pattern:reset()
                end
            end
        end

        -- Reset combustion flag
        if self.patterns["combustion_opener"] then
            self.patterns["combustion_opener"]:reset_combustion_flag()
        end
    end
end

---@return boolean True if any pattern is active
function PatternManager:is_pattern_active()
    return self.active_pattern ~= nil
end

---@return table<string, boolean> Map of pattern names to their active state
function PatternManager:get_pattern_states()
    local states = {}
    for name, pattern in pairs(self.patterns) do
        states[name] = pattern.active
    end
    return states
end

function PatternManager:reset_pattern()
    logger:log("attempting to reset pattern", 2)
    if self.active_pattern then
        self.active_pattern:log("PATTERN RESET", 2)
        self.active_pattern:reset()
        self.active_pattern = nil
    end
end

-- Initialize and return a new PatternManager
function PatternManager:new()
    local instance = {}
    setmetatable(instance, { __index = self })
    return instance
end

return PatternManager:new()
