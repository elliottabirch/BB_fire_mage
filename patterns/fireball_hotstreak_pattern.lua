local BasePattern = require("patterns/base_pattern")
local resources = require("resources")
local spellcasting = require("spellcasting")
local spell_data = require("spell_data")

---@class FireballHotstreakPattern : BasePattern
local FireballHotstreakPattern = BasePattern:new("Fireball->HotStreak pattern")

-- Define states
FireballHotstreakPattern.STATES = {
    NONE = "NONE",
    FIRE_BLAST_CAST = "FIRE_BLAST_CAST",
    PYROBLAST_CAST = "PYROBLAST_CAST"
}

-- Set initial state
FireballHotstreakPattern.state = FireballHotstreakPattern.STATES.NONE

---@param player game_object
---@param patterns_active table Table containing active state of other patterns
---@return boolean
function FireballHotstreakPattern:should_start(player, patterns_active)
    self:log("Evaluating conditions:", 3)


    if spellcasting.last_cast ~= spell_data.SPELL.FIREBALL.name then
        self:log("REJECTED: Not currently casting Fireball", 2)
        return false
    end
    local remaining_cast_time = resources:get_remaining_cast_time(player)
    local elapsed_cast_time = resources:get_elapsed_cast_time(player)
    local active_spell_id = player:get_active_spell_id()
    if active_spell_id ~= spell_data.SPELL.FIREBALL.id or remaining_cast_time < 300 or elapsed_cast_time < 500 then
        self:log("REJECTED: Not casting Fireball", 2)
        return false
    end

    -- Check if we have Heating Up
    if not resources:has_heating_up(player) then
        self:log("REJECTED: No heating up", 2)
        return false
    end

    local combustionCD = core.spell_book.get_spell_cooldown(spell_data.SPELL.COMBUSTION.id)
    local fire_blast_charges = resources:get_fire_blast_charges()

    if combustionCD < 15 and fire_blast_charges < 3 then
        self:log("REJECTED: Combustion CD or Fire Blast charges too low", 2)
        return false
    end
    self:log("ACCEPTED: Casting Fireball with Hot Streak active", 1)
    return true
end

function FireballHotstreakPattern:start()
    self.active = true
    self.state = self.STATES.FIRE_BLAST_CAST
    self.start_time = core.time()
    self:log("STARTED - State: " .. self.state, 1)
end

function FireballHotstreakPattern:reset()
    local prev_state = self.state
    self.active = false
    self.state = self.STATES.NONE
    self.start_time = 0
    self:log("RESET (from " .. prev_state .. " state)", 1)
end

---Handles spell cast events to update pattern state
---@param spell_id number The ID of the spell that was cast
function FireballHotstreakPattern:on_spell_cast(spell_id)
    if not self.active then
        return false
    end

    self:log("Processing spell cast: " .. spell_id, 3)

    -- Fire Blast was cast
    if spell_id == spell_data.SPELL.FIRE_BLAST.id then
        self:log("Fire Blast cast detected", 2)
        if self.state == self.STATES.FIRE_BLAST_CAST then
            self.state = self.STATES.PYROBLAST_CAST
            self:log("State advanced to PYROBLAST_CAST after Fire Blast cast", 2)
            return true
        end

        -- Pyroblast was cast
    elseif spell_id == spell_data.SPELL.PYROBLAST.id then
        self:log("Pyroblast cast detected", 2)
        if self.state == self.STATES.PYROBLAST_CAST then
            self:log("COMPLETED: Pyroblast cast detected, pattern complete", 1)
            self:reset()
            return true
        end
    end

    return false
end

---@param player game_object
---@param target game_object
---@return boolean
function FireballHotstreakPattern:execute(player, target)
    if not self.active then
        return false
    end

    self:log("Executing - Current state: " .. self.state, 3)

    -- State: FIRE_BLAST_CAST
    if self.state == self.STATES.FIRE_BLAST_CAST then
        -- Check if Fireball is still being cast
        local cast_end_time = player:get_active_spell_cast_end_time()
        if not resources:has_heating_up(player) then
            self:log("heating up dropped off, resetting", 2)
            self:reset()
        end
        local elapsed_cast_time = resources:get_elapsed_cast_time(player)
        if cast_end_time > 0 and elapsed_cast_time > 500 then
            -- Cast Fire Blast during Fireball cast
            self:log("Attempting to cast Fire Blast during Fireball", 2)
            spellcasting:cast_spell(spell_data.SPELL.FIRE_BLAST, target, false, false)
            -- No state change here - will be handled by on_spell_cast
        else
            self:log("resetting because fb was never cast", 2)
            self:reset()
        end
        return true

        -- State: PYROBLAST_CAST
    elseif self.state == self.STATES.PYROBLAST_CAST then
        -- Wait for GCD after Fireball
        local cast_end_time = player:get_active_spell_cast_end_time()
        if cast_end_time > 0 then
            self:log("Waiting for fireball cast (" .. string.format("%.2f", cast_end_time) .. "s remaining)", 3)
            return true
        end

        -- Cast Pyroblast
        self:log("Attempting to cast Pyroblast with Hot Streak", 2)
        spellcasting:cast_spell(spell_data.SPELL.PYROBLAST, target, false, false)
        -- No state change here - will be handled by on_spell_cast
        return true
    end

    return true
end

return FireballHotstreakPattern
