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

    -- Don't start if other patterns are active
    if patterns_active.pyro_fb or patterns_active.pyro_pf or patterns_active.scorch_fb or patterns_active.combustion_opener then
        self:log("REJECTED: Another pattern is already active", 2)
        return false
    end

    -- Check if we're currently casting Fireball
    local active_spell_id = player:get_active_spell_id()
    if active_spell_id ~= spell_data.SPELL.FIREBALL.id then
        self:log("REJECTED: Not casting Fireball", 2)
        return false
    end

    -- Check if we have Heating Up
    if not resources:has_heating_up(player) then
        self:log("REJECTED: No heating up", 2)
        return false
    end

    -- Check if we're not in Combustion
    local combustion_remaining = resources:get_combustion_remaining(player)
    if combustion_remaining > 0 then
        self:log("REJECTED: Combustion is active", 2)
        return false
    end

    local combustionCD = core.spell_book.get_spell_cooldown(spell_data.SPELL.COMBUSTION.id)
    local fire_blast_charges = resources:get_fire_blast_charges()

    if combustionCD < 10 and fire_blast_charges < 2 then
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
        local current_time = core.game_time()

        if cast_end_time > 0 then
            -- Cast Fire Blast during Fireball cast
            self:log("Attempting to cast Fire Blast during Fireball", 2)
            if spellcasting:cast_spell(spell_data.SPELL.FIRE_BLAST, target, false, false) then
                self.state = self.STATES.PYROBLAST_CAST
                self:log("Fire Blast cast successful, waiting for Fireball to finish", 2)
                return true
            end
        else
            -- Fireball cast finished, move to next state
            self.state = self.STATES.PYROBLAST_CAST
            self:log("Fireball cast finished, transitioning to PYROBLAST_CAST state", 2)
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
        if spellcasting:cast_spell(spell_data.SPELL.PYROBLAST, target, false, false) then
            self:log("COMPLETED: Pyroblast cast after Fireball", 1)
            self:reset()
            return true
        end
        return true
    end

    return true
end

return FireballHotstreakPattern
