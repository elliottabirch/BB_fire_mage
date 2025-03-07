---@class SpellTracker
---@field current_cast table Information about the current spell being cast
---@field logger Logger Reference to the logger module

local SpellTracker = {
    current_cast = {
        spell_id = nil,
        start_time = 0,
        expected_end_time = 0
    }
}

local logger = require("logger")

local SPELL_INTERRUPT_FLEXIBILITY = 150

---@param player game_object The player object
---@return boolean True if a cast was interrupted
function SpellTracker:update(player)
    if not player then
        return false
    end

    -- Get current spell casting information
    local active_spell_id = player:get_active_spell_id()
    local cast_start_time = player:get_active_spell_cast_start_time()
    local cast_end_time = player:get_active_spell_cast_end_time()
    -- If we're not casting anything, reset tracking
    if active_spell_id == 0 then
        if self.current_cast.spell_id and core.game_time() < self.current_cast.expected_end_time - SPELL_INTERRUPT_FLEXIBILITY then
            -- A cast was in progress but now isn't, and it ended before it should have
            logger:log("Spell interrupted: " .. tostring(self.current_cast.spell_id), 2)
            self:reset()
            return true
        end
        self:reset()
        return false
    end

    -- Check if we're casting a new spell
    if active_spell_id ~= self.current_cast.spell_id or cast_start_time ~= self.current_cast.start_time then
        -- Check if previous cast was interrupted
        if self.current_cast.spell_id and core.game_time() < self.current_cast.expected_end_time - SPELL_INTERRUPT_FLEXIBILITY then
            -- Cast was interrupted
            logger:log("SPELL INTERRUPTED: " .. tostring(self.current_cast.spell_id) ..
                ", new spell: " .. tostring(active_spell_id), 2)

            -- Reset current cast info before returning
            local was_interrupted = true
            self:reset()

            -- Update with new cast
            self.current_cast.spell_id = active_spell_id
            self.current_cast.start_time = cast_start_time
            self.current_cast.expected_end_time = cast_end_time

            return was_interrupted
        end

        -- Update current cast info for new cast
        self.current_cast.spell_id = active_spell_id
        self.current_cast.start_time = cast_start_time
        self.current_cast.expected_end_time = cast_end_time
    end

    return false
end

---Reset the current cast tracking information
function SpellTracker:reset()
    self.current_cast.spell_id = nil
    self.current_cast.start_time = 0
    self.current_cast.expected_end_time = 0
end

---Get the ID of the spell currently being cast
---@return number|nil The spell ID or nil if not casting
function SpellTracker:get_current_spell_id()
    return self.current_cast.spell_id
end

---Check if a specific spell is being cast
---@param spell_id number The spell ID to check
---@return boolean True if the specified spell is being cast
function SpellTracker:is_casting_spell(spell_id)
    return self.current_cast.spell_id == spell_id
end

return SpellTracker
