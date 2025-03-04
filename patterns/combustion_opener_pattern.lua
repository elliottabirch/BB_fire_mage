local BasePattern = require("patterns/base_pattern")
local resources = require("resources")
local config = require("config")
local spellcasting = require("spellcasting")
local spell_data = require("spell_data")
local plugin_helper = require("common/utility/plugin_helper")
local menu_elements = require("ui/menu_elements")
local combat_forecast = require("common/modules/combat_forecast")

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
    if not plugin_helper:is_toggle_enabled(menu_elements.toggle_cooldowns) then
        self:log("REJECTED: Cooldowns are disabled via keybind", 2)
        return false
    end

    -- The rest of the method remains the same...
    if menu_elements.smart_combustion:get_state() then
        ---@type combat_forecast

        local combat_length = combat_forecast:get_forecast()
        if combat_length < 30 then
            self:log(
                "REJECTED: Smart Combustion enabled but fight is not predicted to be long enough: " ..
                combat_length .. " seconds", 2)
            return false
        else
            self:log("Smart Combustion: Fight is predicted to be long enough: " .. combat_length .. " seconds", 3)
        end
    end

    -- Don't start if other patterns are active
    if patterns_active.pyro_fb or patterns_active.pyro_pf or patterns_active.scorch_fb then
        self:log("REJECTED: Another pattern is already active", 2)
        return false
    end

    -- Remaining checks continue as before...
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
    if combustion_cd > ((remaining_cast_time - 500) / 1000) then
        self:log("REJECTED: combustion on cd", 2)
        return false
    end

    local elapsed_cast = resources:get_elapsed_cast_time(player)

    if elapsed_cast < 500 then
        self:log("REJECTED: cast time too short", 2)
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
            self:log("Fireball cast time < 300ms, attempting to cast Combustion", 2)
            spellcasting:cast_spell(spell_data.SPELL.COMBUSTION, target, false, false)
            -- No state change here - will be handled by on_spell_cast
            return true
        else
            self:log("Waiting for Fireball cast to get to correct timing (remaining: " ..
                string.format("%.2f", remaining_cast_time / 1000) .. "s)", 3)
            return true
        end

        -- State: FIRE_BLAST_CAST
    elseif self.state == self.STATES.FIRE_BLAST_CAST then
        self:log("Attempting to cast Fire Blast", 2)
        spellcasting:cast_spell(spell_data.SPELL.FIRE_BLAST, target, false, false)
        -- No state change here - will be handled by on_spell_cast
        return true

        -- State: FIRST_PYRO
    elseif self.state == self.STATES.FIRST_PYRO then
        self:log("Attempting to cast first Pyroblast", 2)
        spellcasting:cast_spell(spell_data.SPELL.PYROBLAST, target, false, false)
        -- No state change here - will be handled by on_spell_cast
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
        spellcasting:cast_spell(spell_data.SPELL.PYROBLAST, target, false, false)
        -- No state change here - will be handled by on_spell_cast
        return true
    end

    return true
end

---Handles spell cast events to update pattern state
---@param spell_id number The ID of the spell that was cast
function CombustionOpenerPattern:on_spell_cast(spell_id)
    if not self.active then
        return false
    end

    self:log("Processing spell cast: " .. spell_id, 3)

    -- Track state transitions based on spell casts
    if spell_id == spell_data.SPELL.COMBUSTION.id then
        self:log("Combustion cast detected", 2)
        if self.state == self.STATES.WAITING_FOR_CAST then
            self.has_activated_this_combustion = true
            self.state = self.STATES.FIRE_BLAST_CAST
            self:log("State advanced to FIRE_BLAST_CAST after Combustion cast", 2)
            return true
        end
    elseif spell_id == spell_data.SPELL.FIRE_BLAST.id then
        self:log("Fire Blast cast detected", 2)
        if self.state == self.STATES.FIRE_BLAST_CAST then
            self.state = self.STATES.FIRST_PYRO
            self:log("State advanced to FIRST_PYRO after Fire Blast cast", 2)
            return true
        end
    elseif spell_id == spell_data.SPELL.PYROBLAST.id then
        self:log("Pyroblast cast detected", 2)
        if self.state == self.STATES.FIRST_PYRO then
            self.state = self.STATES.SECOND_PYRO
            self:log("State advanced to SECOND_PYRO after first Pyroblast cast", 2)
            return true
        elseif self.state == self.STATES.SECOND_PYRO then
            self:log("COMPLETED: Second Pyroblast cast detected, pattern complete", 1)
            self:reset()
            return true
        elseif self.state == self.STATES.WAITING_FOR_CAST or
            self.state == self.STATES.COMBUSTION_CAST or
            self.state == self.STATES.FIRE_BLAST_CAST then
            self:log("Unexpected Pyroblast cast, resetting pattern", 2)
            self:reset()
            return true
        end
    end

    return false
end

return CombustionOpenerPattern
