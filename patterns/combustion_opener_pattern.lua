local BasePattern = require("patterns/base_pattern")
local resources = require("resources")
local config = require("config")
local spellcasting = require("spellcasting")
local spell_data = require("spell_data")

---@class CombustionOpenerPattern : BasePattern
---@field has_activated_this_combustion boolean
local CombustionOpenerPattern = BasePattern:new("Combustion Opener")

-- Define states
CombustionOpenerPattern.STATES = {
    NONE = "NONE",
    WAITING_FOR_CAST = "WAITING_FOR_CAST",
    COMBUSTION_CAST = "COMBUSTION_CAST",
    FIRE_BLAST_CAST = "FIRE_BLAST_CAST",
    FIRST_PYRO = "FIRST_PYRO",
    SECOND_PYRO = "SECOND_PYRO"
}

-- Set initial state and additional properties
CombustionOpenerPattern.state = CombustionOpenerPattern.STATES.NONE
CombustionOpenerPattern.has_activated_this_combustion = false

---@param player game_object
---@param patterns_active table Table containing active state of other patterns
---@return boolean
function CombustionOpenerPattern:should_start(player, patterns_active)
    self:log("Evaluating conditions:", 3)

    -- Don't start if other patterns are active
    if patterns_active.pyro_fb or patterns_active.pyro_pf or patterns_active.scorch_fb then
        self:log("REJECTED: Another pattern is already active", 2)
        return false
    end

    if self.has_activated_this_combustion then
        self:log("REJECTED: opener already activated this combustion", 2)
        return false
    end

    -- Check if we have enough Fire Blast charges
    local fb_charges = resources:get_fire_blast_charges()
    if fb_charges < 2 then
        self:log("REJECTED: Not enough Fire Blast charges (" .. fb_charges .. ")", 2)
        return false
    end

    -- Check if we have Heating Up or Hot Streak
    local has_heating_up = resources:has_heating_up(player)
    local has_hot_streak = resources:has_hot_streak(player)
    if not (has_heating_up or has_hot_streak) then
        self:log("REJECTED: No Heating Up or Hot Streak proc", 2)
        return false
    end

    local active_spell_id = player:get_active_spell_id()
    local cast_end_time = player:get_active_spell_cast_end_time()
    local current_time = core.game_time()
    local remaining_cast_time = (cast_end_time - current_time)
    local combustion_cd = core.spell_book.get_spell_cooldown(spell_data.SPELL.COMBUSTION.id)

    self:log("Combustion CD: " .. combustion_cd, 3)
    if combustion_cd > 0.5 then
        self:log("REJECTED: combustion on cd", 2)
        return false
    end

    if active_spell_id ~= spell_data.SPELL.FIREBALL.id or remaining_cast_time < config.combust_precast_time then
        self:log("REJECTED: not casting fireball, or cast time is less than 300ms", 2)
        return false
    end

    self:log("ACCEPTED: " .. fb_charges .. " Fire Blast charges and " ..
        (has_hot_streak and "Hot Streak" or "Heating Up") .. " active", 1)
    return true
end

function CombustionOpenerPattern:start()
    self.active = true
    self.state = self.STATES.WAITING_FOR_CAST
    self.start_time = core.time()
    self.has_activated_this_combustion = false
    self:log("STARTED - State: " .. self.state, 1)
end

function CombustionOpenerPattern:reset()
    local prev_state = self.state
    self.active = false
    self.state = self.STATES.NONE
    self.start_time = 0
    self:log("RESET (from " .. prev_state .. " state)", 1)
end

function CombustionOpenerPattern:reset_combustion_flag()
    self.has_activated_this_combustion = false
end

---@param player game_object
---@param target game_object
---@return boolean
function CombustionOpenerPattern:execute(player, target)
    if not self.active then
        return false
    end

    self:log("Executing - Current state: " .. self.state, 3)

    -- State: WAITING_FOR_CAST
    if self.state == self.STATES.WAITING_FOR_CAST then
        local active_spell_id = player:get_active_spell_id()
        local cast_end_time = player:get_active_spell_cast_end_time()
        local current_time = core.game_time()
        local remaining_cast_time = (cast_end_time - current_time)

        if remaining_cast_time < config.combust_precast_time then
            self:log("Fireball cast time < 300ms, casting Combustion", 2)
            self.state = self.STATES.COMBUSTION_CAST
            return true
        else
            self:log("Waiting for Fireball cast to get to correct timing (remaining: " ..
                string.format("%.2f", remaining_cast_time / 1000) .. "s)", 3)
            return true
        end

        -- State: COMBUSTION_CAST
    elseif self.state == self.STATES.COMBUSTION_CAST then
        self:log("Attempting to cast Combustion", 2)
        if spellcasting:cast_spell(spell_data.SPELL.COMBUSTION, target, false, false) then
            self.has_activated_this_combustion = true

            if resources:has_hot_streak(player) then
                self.state = self.STATES.FIRST_PYRO
                self:log("Combustion cast successful, Hot Streak active, skipping Fire Blast", 2)
            else
                self.state = self.STATES.FIRE_BLAST_CAST
                self:log("Combustion cast successful, transitioning to FIRE_BLAST_CAST state", 2)
            end
            return true
        end
        return true

        -- State: FIRE_BLAST_CAST
    elseif self.state == self.STATES.FIRE_BLAST_CAST then
        self:log("Attempting to cast Fire Blast to get Hot Streak", 2)
        if spellcasting:cast_spell(spell_data.SPELL.FIRE_BLAST, target, false, false) then
            self.state = self.STATES.FIRST_PYRO
            self:log("Fire Blast cast successful, transitioning to FIRST_PYRO state", 2)
            return true
        end
        return true

        -- State: FIRST_PYRO
    elseif self.state == self.STATES.FIRST_PYRO then
        self:log("Attempting to cast first Pyroblast", 2)
        if spellcasting:cast_spell(spell_data.SPELL.PYROBLAST, target, false, false) then
            self.state = self.STATES.SECOND_PYRO
            self:log("First Pyroblast cast successful, transitioning to SECOND_PYRO state", 2)
            return true
        end
        return true

        -- State: SECOND_PYRO
    elseif self.state == self.STATES.SECOND_PYRO then
        local gcd = core.spell_book.get_global_cooldown()
        if gcd > 0.1 then
            self:log("Waiting for GCD after first Pyroblast (" ..
                string.format("%.2f", gcd) .. "s remaining)", 3)
            return true
        end

        self:log("Attempting to cast second Pyroblast", 2)
        if spellcasting:cast_spell(spell_data.SPELL.PYROBLAST, target, false, false) then
            self:log("COMPLETED: Both Pyroblasts cast successfully", 1)
            self:reset()
            return true
        end
        return true
    end

    return true
end

return CombustionOpenerPattern
