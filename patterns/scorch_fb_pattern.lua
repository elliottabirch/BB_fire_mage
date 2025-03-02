local BasePattern = require("patterns/base_pattern")
local resources = require("resources")
local spellcasting = require("spellcasting")
local spell_data = require("spell_data")

---@class ScorchFireBlastPattern : BasePattern
local ScorchFireBlastPattern = BasePattern:new("Scorch+FB pattern")

-- Define states
ScorchFireBlastPattern.STATES = {
    NONE = "NONE",
    SCORCH_CAST = "SCORCH_CAST",
    FIRE_BLAST_CAST = "FIRE_BLAST_CAST",
    FIRST_PYROBLAST_CAST = "FIRST_PYROBLAST_CAST",
    SECOND_PYROBLAST_CAST = "SECOND_PYROBLAST_CAST"
}

-- Set initial state
ScorchFireBlastPattern.state = ScorchFireBlastPattern.STATES.NONE

---@param player game_object
---@param patterns_active table Table containing active state of other patterns
---@return boolean
function ScorchFireBlastPattern:should_start(player, patterns_active)
    self:log("Evaluating conditions:", 3)

    -- Don't start if other patterns are active
    if patterns_active.pyro_fb or patterns_active.pyro_pf then
        self:log("REJECTED: Another pattern is already active", 2)
        return false
    end
    self:log("Check: No other patterns active ✓", 3)

    -- Check if we just cast Pyroblast
    if spellcasting.last_cast ~= spell_data.SPELL.PYROBLAST.name then
        self:log("REJECTED: Last cast was not Pyroblast (was " .. (spellcasting.last_cast or "nil") .. ")", 2)
        return false
    end
    self:log("Check: Last cast WAS Pyroblast ✓", 3)

    local gcd = core.spell_book.get_global_cooldown()
    if gcd > 0 then
        self:log("REJECTED: Global cooldown is active (GCD: " .. gcd .. ")", 2)
        return false
    end
    self:log("Check: GCD is not active (" .. string.format("%.2f", gcd) .. "s) ✓", 3)

    -- Check if we have no Fire Blast charges
    local fb_charges = resources:get_fire_blast_charges()
    if fb_charges > 0 then
        self:log("REJECTED: Still have Fire Blast charges (" .. fb_charges .. ")", 2)
        return false
    end
    self:log("Check: No Fire Blast charges available ✓", 3)

    -- Check if Combustion is active
    local combustion_remaining = resources:get_combustion_remaining(player)
    if combustion_remaining <= 0 then
        self:log("REJECTED: Combustion not active", 2)
        return false
    end
    self:log("Check: Combustion is active (" .. string.format("%.2f", combustion_remaining / 1000) .. "s remaining) ✓", 3)

    -- Calculate if Fire Blast will be ready by the end of Scorch cast
    local scorch_cast_time = core.spell_book.get_spell_cast_time(spell_data.SPELL.SCORCH.id)

    -- Check if Scorch cast + safety margin will finish before Combustion ends
    local combustion_remaining_sec = combustion_remaining / 1000
    if (scorch_cast_time + 0.1) >= combustion_remaining_sec then
        self:log("REJECTED: Not enough Combustion time left (Combustion: " ..
            string.format("%.2f", combustion_remaining_sec) .. "s, Required: " ..
            string.format("%.2f", scorch_cast_time + 0.1) .. "s)", 2)
        return false
    end

    self:log("ACCEPTED: All conditions met, starting sequence", 1)
    return true
end

function ScorchFireBlastPattern:start()
    self.active = true
    self.state = self.STATES.SCORCH_CAST
    self.start_time = core.time()
    self:log("STARTED - State: " .. self.state, 1)
end

---@param player game_object
---@param target game_object
---@return boolean
function ScorchFireBlastPattern:execute(player, target)
    if not self.active then
        return false
    end

    self:log("Executing - Current state: " .. self.state, 3)

    -- State: SCORCH_CAST
    if self.state == self.STATES.SCORCH_CAST then
        self:log("Attempting to cast Scorch", 2)
        if spellcasting:cast_spell(spell_data.SPELL.SCORCH, target, false, false) then
            self.state = self.STATES.FIRE_BLAST_CAST
            self:log("Scorch cast successful, transitioning to FIRE_BLAST_CAST state", 2)
            return true
        else
            self:log("Scorch cast FAILED, retrying", 2)
        end
        return true

        -- State: FIRE_BLAST_CAST
    elseif self.state == self.STATES.FIRE_BLAST_CAST then
        local cast_end_time = player:get_active_spell_cast_end_time()
        local current_time = core.game_time()
        local remaining_cast_time = (cast_end_time - current_time) / 1000

        if remaining_cast_time > 0.2 and resources:get_fire_blast_charges() > 0 then
            self:log("Attempting to cast Fire Blast during Scorch (Remaining cast: " ..
                string.format("%.2f", remaining_cast_time) .. "s)", 2)

            if spellcasting:cast_spell(spell_data.SPELL.FIRE_BLAST, target, false, false) then
                self.state = self.STATES.FIRST_PYROBLAST_CAST
                self:log("Fire Blast cast successful, transitioning to FIRST_PYROBLAST_CAST state", 2)
                return true
            end
        elseif cast_end_time == 0 then
            self.state = self.STATES.SECOND_PYROBLAST_CAST
            self:log("No Fire Blast charges after Scorch, transitioning to SECOND_PYROBLAST_CAST state", 1)
            return true
        end
        return true

        -- State: FIRST_PYROBLAST_CAST
    elseif self.state == self.STATES.FIRST_PYROBLAST_CAST then
        local has_hot_streak = resources:has_hot_streak(player)
        self:log("Checking for Hot Streak before Pyroblast (Hot Streak: " .. tostring(has_hot_streak) .. ")", 3)

        local cast_end_time = player:get_active_spell_cast_end_time()
        local current_time = core.game_time()
        local remaining_cast_time = (cast_end_time - current_time) / 1000

        if remaining_cast_time <= 0 then
            self:log("Attempting to cast Pyroblast with Hot Streak", 2)
            if spellcasting:cast_spell(spell_data.SPELL.PYROBLAST, target, false, false) then
                self:log("First pyro cast, advancing to SECOND_PYROBLAST_CAST", 1)
                self.state = self.STATES.SECOND_PYROBLAST_CAST
                return true
            end
        else
            self:log("Waiting for scorch cast to end (Current cast: " ..
                string.format("%.2f", remaining_cast_time) .. "s)", 3)
        end
        return true

        -- State: SECOND_PYROBLAST_CAST
    elseif self.state == self.STATES.SECOND_PYROBLAST_CAST then
        local gcd = core.spell_book.get_global_cooldown()
        if gcd <= 0 then
            self:log("Attempting to cast second Pyroblast with Hot Streak", 2)
            if spellcasting:cast_spell(spell_data.SPELL.PYROBLAST, target, false, false) then
                self:log("COMPLETED: Full sequence executed successfully", 1)
                self:reset()
                return true
            end
        else
            self:log("Waiting for GCD to end (GCD: " .. string.format("%.2f", gcd) .. "s)", 3)
        end
        return true
    end

    return true
end

return ScorchFireBlastPattern
