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
    BUILDER = "BUILDER",
    PHOENIX_FLAMES_CAST = "PHOENIX_FLAMES_CAST",
    SCORCH_OR_FIREBALL = "SCORCH_OR_FIREBALL",
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

    if menu_elements.smart_combustion:get_state() then
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

    if self.has_activated_this_combustion then
        self:log("REJECTED: opener already activated this combustion", 2)
        return false
    end
    local is_casting = player:is_casting_spell()
    if is_casting then
        self:log("Waiting for current cast to finish before starting", 3)
        return false
    end
    local gcd = core.spell_book.get_global_cooldown()
    if gcd > 0 then
        self:log("Waiting for GCD before starting (" .. string.format("%.2f", gcd) .. "s)", 3)
        return false
    end

    -- Check combustion CD condition
    local combustion_cd = core.spell_book.get_spell_cooldown(spell_data.SPELL.COMBUSTION.id)
    self:log("Combustion CD: " .. combustion_cd, 3)
    if combustion_cd > 2 then
        self:log("REJECTED: Combustion CD too high (" .. combustion_cd .. " > 2s)", 2)
        return false
    end

    -- Check if we have 1 charge of Phoenix Flames
    local pf_charges = resources:get_phoenix_flames_charges()
    if pf_charges < 1 then
        self:log("REJECTED: Not enough Phoenix Flames charges (" .. pf_charges .. " < 1)", 2)
        return false
    end

    -- Check if we have at least 2 Fire Blast charges
    local fb_charges = resources:get_fire_blast_charges()
    if fb_charges < 2 then
        self:log("REJECTED: Not enough Fire Blast charges (" .. fb_charges .. " < 2)", 2)
        return false
    end

    -- Successfully passed all checks
    self:log("ACCEPTED: Combustion CD < 2s, " .. pf_charges .. " Phoenix Flames charges, " ..
        fb_charges .. " Fire Blast charges", 1)
    return true
end

function CombustionOpenerPattern:start()
    self.active = true
    -- If player is moving, skip the builder phase
    local player = core.object_manager.get_local_player()
    if player and player:is_moving() then
        self.state = self.STATES.PHOENIX_FLAMES_CAST
        self:log("STARTED (player moving) - State: " .. self.state, 1)
    else
        self.state = self.STATES.BUILDER
        self:log("STARTED (player stationary) - State: " .. self.state, 1)
    end
    self.start_time = core.time()
    self.has_activated_this_combustion = false
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

    -- Common checks for all states
    local is_casting = player:is_casting_spell()
    local cast_end_time = player:get_active_spell_cast_end_time()
    local current_time = core.game_time()
    local gcd = core.spell_book.get_global_cooldown()
    local has_hot_streak = resources:has_hot_streak(player)
    local has_heating_up = resources:has_heating_up(player)
    local is_moving = player:is_moving()

    -- State: BUILDER (cast Fireball if not moving)
    if self.state == self.STATES.BUILDER then
        if is_moving then
            self:log("Player is moving, skipping to Phoenix Flames", 2)
            self.state = self.STATES.PHOENIX_FLAMES_CAST
            return true
        end

        if is_casting then
            self:log("Already casting, waiting for cast to finish", 3)
            return true
        end

        self:log("Attempting to cast Fireball as builder", 2)
        if spellcasting:cast_spell(spell_data.SPELL.FIREBALL, target, false, false) then
            self:log("Fireball cast initiated", 2)
        else
            self:log("Failed to cast Fireball, will retry", 2)
        end
        return true

        -- State: PHOENIX_FLAMES_CAST
    elseif self.state == self.STATES.PHOENIX_FLAMES_CAST then
        -- Wait for any existing cast to finish
        if is_casting then
            self:log("Waiting for current cast to finish before Phoenix Flames", 3)
            return true
        end

        if gcd ~= 0 then
            self:log("Waiting for GCD before Phoenix Flames (" .. string.format("%.2f", gcd) .. "s)", 3)
            return true
        end

        self:log("Attempting to cast Phoenix Flames", 2)
        if spellcasting:cast_spell(spell_data.SPELL.PHOENIX_FLAMES, target, false, false) then
            self:log("Phoenix Flames cast initiated", 2)
        else
            self:log("Failed to cast Phoenix Flames, will retry", 2)
        end
        return true

        -- State: SCORCH_OR_FIREBALL
    elseif self.state == self.STATES.SCORCH_OR_FIREBALL then
        -- Wait for any existing cast or GCD
        if is_casting then
            self:log("Waiting for current cast to finish before Scorch/Fireball", 3)
            return true
        end

        if gcd > 0.1 then
            self:log("Waiting for GCD before Scorch/Fireball (" .. string.format("%.2f", gcd) .. "s)", 3)
            return true
        end

        if is_moving then
            self:log("Player is moving, casting Scorch", 2)
            if spellcasting:cast_spell(spell_data.SPELL.SCORCH, target, false, false) then
                self:log("Scorch cast initiated", 2)
            else
                self:log("Failed to cast Scorch, will retry", 2)
            end
        else
            self:log("Player is stationary, casting Fireball", 2)
            if spellcasting:cast_spell(spell_data.SPELL.FIREBALL, target, false, false) then
                self:log("Fireball cast initiated", 2)
            else
                self:log("Failed to cast Fireball, will retry", 2)
            end
        end
        return true

        -- State: COMBUSTION_CAST
    elseif self.state == self.STATES.COMBUSTION_CAST then
        -- Check if combustion is on CD
        local combustion_cd = core.spell_book.get_spell_cooldown(spell_data.SPELL.COMBUSTION.id)
        if combustion_cd > 0 then
            self:log("Waiting for Combustion cooldown (" .. string.format("%.2f", combustion_cd) .. "s)", 3)
            return true
        end
        -- Wait for any existing cast or GCD
        if is_casting then
            local remaining_cast_time = (cast_end_time - current_time) / 1000
            if remaining_cast_time < config.combust_precast_time / 1000 then
                -- Time to precast Combustion during current cast
                self:log("Attempting to cast Combustion during cast (remaining: " ..
                    string.format("%.2f", remaining_cast_time) .. "s)", 2)
                if spellcasting:cast_spell(spell_data.SPELL.COMBUSTION, target, false, false) then
                    self:log("Combustion cast initiated", 2)
                    self.has_activated_this_combustion = true
                    return true
                end
            else
                self:log("Waiting for cast to reach combustion precast window", 3)
                return true
            end
        else
            self:reset()
            self:log("combustion failed to go off before end of cast")
        end

        -- State: FIRE_BLAST_CAST
    elseif self.state == self.STATES.FIRE_BLAST_CAST then
        -- Check if we have a Fire Blast charge
        local fb_charges = resources:get_fire_blast_charges()
        if fb_charges < 1 then
            self:log("No Fire Blast charges available, waiting", 3)
            return true
        end

        if has_hot_streak then
            self:log("skipping FB to because we have hot streak already", 2)
            self.state = self.STATES.FIRST_PYRO
            return true
        end


        self:log("Attempting to cast Fire Blast", 2)
        if is_casting then
            local remaining_cast_time = (cast_end_time - current_time) / 1000
            if remaining_cast_time < config.combust_precast_time / 1000 then
                if spellcasting:cast_spell(spell_data.SPELL.FIRE_BLAST, target, false, false) then
                    self:log("Fire Blast cast initiated", 2)
                else
                    self:log("Failed to cast Fire Blast, will retry", 2)
                end
            end
        else
            self:reset()
            self:log("resetting because fire blast was not cast in time", 2)
        end
        return true

        -- State: FIRST_PYRO
    elseif self.state == self.STATES.FIRST_PYRO then
        -- Wait for Hot Streak proc if needed
        if not has_hot_streak then
            self:log("Waiting for Hot Streak proc before first Pyroblast", 3)
            return true
        end

        self:log("Attempting to cast first Pyroblast with Hot Streak", 2)
        if spellcasting:cast_spell(spell_data.SPELL.PYROBLAST, target, false, false) then
            self:log("First Pyroblast cast initiated", 2)
        else
            self:log("Failed to cast first Pyroblast, will retry", 2)
        end
        return true

        -- State: SECOND_PYRO
    elseif self.state == self.STATES.SECOND_PYRO then
        -- Wait for GCD
        if gcd > 0.1 then
            self:log("Waiting for GCD before second Pyroblast (" .. string.format("%.2f", gcd) .. "s)", 3)
            return true
        end

        self:log("Attempting to cast second Pyroblast with Hot Streak", 2)
        if spellcasting:cast_spell(spell_data.SPELL.PYROBLAST, target, false, false) then
            self:log("Second Pyroblast cast initiated", 2)
        else
            self:log("Failed to cast second Pyroblast, will retry", 2)
        end
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
    if spell_id == spell_data.SPELL.FIREBALL.id then
        self:log("Fireball cast detected", 2)
        if self.state == self.STATES.BUILDER then
            self.state = self.STATES.PHOENIX_FLAMES_CAST
            self:log("State advanced to PHOENIX_FLAMES_CAST after Fireball cast", 2)
            return true
        elseif self.state == self.STATES.SCORCH_OR_FIREBALL then
            self.state = self.STATES.COMBUSTION_CAST
            self:log("State advanced to COMBUSTION_CAST after Fireball cast", 2)
            return true
        end
    elseif spell_id == spell_data.SPELL.PHOENIX_FLAMES.id then
        self:log("Phoenix Flames cast detected", 2)
        if self.state == self.STATES.PHOENIX_FLAMES_CAST then
            self.state = self.STATES.SCORCH_OR_FIREBALL
            self:log("State advanced to SCORCH_OR_FIREBALL after Phoenix Flames cast", 2)
            return true
        end
    elseif spell_id == spell_data.SPELL.SCORCH.id then
        self:log("Scorch cast detected", 2)
        if self.state == self.STATES.SCORCH_OR_FIREBALL then
            self.state = self.STATES.COMBUSTION_CAST
            self:log("State advanced to COMBUSTION_CAST after Scorch cast", 2)
            return true
        end
    elseif spell_id == spell_data.SPELL.COMBUSTION.id then
        self:log("Combustion cast detected", 2)
        if self.state == self.STATES.COMBUSTION_CAST or self.state == self.STATES.SCORCH_OR_FIREBALL then
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
        end
    end

    return false
end

return CombustionOpenerPattern
