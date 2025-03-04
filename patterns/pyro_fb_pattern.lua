local BasePattern = require("patterns/base_pattern")
local resources = require("resources")
local config = require("config")
local spellcasting = require("spellcasting")
local spell_data = require("spell_data")

---@class PyroFireBlastPattern : BasePattern
local PyroFireBlastPattern = BasePattern:new("Pyro->FB pattern")

-- Define states
PyroFireBlastPattern.STATES = {
    NONE = "NONE",
    WAITING_FOR_GCD = "WAITING_FOR_GCD",
    FIRE_BLAST_CAST = "FIRE_BLAST_CAST",
    PYROBLAST_CAST = "PYROBLAST_CAST"
}

-- Set initial state
PyroFireBlastPattern.state = PyroFireBlastPattern.STATES.NONE

---@param player game_object
---@return boolean
function PyroFireBlastPattern:should_start(player)
    self:log("Evaluating conditions:", 3)

    -- Check if we just cast Pyroblast
    if spellcasting.last_cast ~= spell_data.SPELL.PYROBLAST.name then
        self:log("REJECTED: Last cast was not Pyroblast (was " .. (spellcasting.last_cast or "nil") .. ")", 2)
        return false
    end
    self:log("Check: Last cast WAS Pyroblast ✓", 3)

    -- Check if GCD is active
    local gcd = core.spell_book.get_global_cooldown()
    if gcd <= 0 then
        self:log("REJECTED: Global cooldown not active (GCD: " .. gcd .. ")", 2)
        return false
    end
    self:log("Check: GCD is active (" .. string.format("%.2f", gcd) .. "s) ✓", 3)

    -- Check if we have Fire Blast charge or will have one soon
    if resources:get_fire_blast_charges() > 0 then
        self:log("ACCEPTED: Have Fire Blast charges (" .. resources:get_fire_blast_charges() .. ")", 2)
        return true
    end

    -- Check if a charge will be ready by end of GCD
    local fb_ready_time = resources:fire_blast_ready_in(gcd - 0.5)
    if fb_ready_time < gcd then
        self:log(
            "ACCEPTED: Fire Blast will be ready in " .. string.format("%.2f", fb_ready_time) .. "s (before GCD ends)", 2)
        return true
    end

    self:log("REJECTED: No Fire Blast charges and none will be ready soon", 2)
    return false
end

function PyroFireBlastPattern:start()
    self.active = true
    self.state = self.STATES.WAITING_FOR_GCD
    self.start_time = core.time()
    self:log("STARTED - State: " .. self.state, 1)
end

---@param player game_object
---@param target game_object
---@return boolean
function PyroFireBlastPattern:execute(player, target)
    if not self.active then
        return false
    end

    local gcd = core.spell_book.get_global_cooldown()
    local hasHotStreak = resources:has_hot_streak(player)

    self:log("Executing - Current state: " .. self.state .. ", GCD: " .. string.format("%.2f", gcd) .. "s", 3)

    -- State: WAITING_FOR_GCD
    if self.state == self.STATES.WAITING_FOR_GCD then
        local fb_charges = resources:get_fire_blast_charges()

        -- Check if we should transition to the next state
        if gcd > 0 and fb_charges > 0 then
            self:log("GCD active, Fire Blast charges available. Ready for Fire Blast cast.", 2)
            self.state = self.STATES.FIRE_BLAST_CAST
        elseif gcd <= 0 then
            self:log("GCD EXPIRED but no Fire Blast charges, aborting pattern", 2)
            self:reset()
            return false
        else
            self:log(
                "Waiting for GCD (" .. string.format("%.2f", gcd) .. "s remaining, FB charges: " .. fb_charges .. ")", 3)
        end
        return true

        -- State: FIRE_BLAST_CAST
    elseif self.state == self.STATES.FIRE_BLAST_CAST and spellcasting.last_cast == spell_data.SPELL.PYROBLAST.name then
        -- Only attempt to cast if we don't already have Hot Streak
        -- Try to cast Fire Blast but don't change state based on result
        -- State change will happen in on_spell_cast when Fire Blast is detected
        if spellcasting:cast_spell(spell_data.SPELL.FIRE_BLAST, target, false, false) then
            self:log("Fire Blast cast request sent", 2)
        else
            self:log("Fire Blast cast request failed", 2)
        end

        return true

        -- State: PYROBLAST_CAST
    elseif self.state == self.STATES.PYROBLAST_CAST and spellcasting.last_cast == spell_data.SPELL.FIRE_BLAST.name then
        if gcd == 0 then
            -- If Hot Streak is active, cast Pyroblast
            -- But don't change state - that will happen in on_spell_cast
            self:log("Attempting to cast Pyroblast at end of gcd", 2)
            if spellcasting:cast_spell(spell_data.SPELL.PYROBLAST, target, false, false) then
                self:log("Pyroblast cast request sent", 2)
            else
                self:log("Pyroblast cast request failed", 2)
            end
        elseif gcd <= 0 and self.start_time + config.reset_time > core.time() then
            -- Timeout check
            self:log("ABANDONED: No Hot Streak for Pyroblast within timeout period", 1)
            self:reset()
            return false
        else
            self:log("Waiting for GCD (Current GCD: " .. string.format("%.2f", gcd) .. "s)", 3)
        end
        return true
    end

    return true
end

---@return table|boolean
function PyroFireBlastPattern:on_spell_cast(spell_id)
    if not self.active then
        self:log("pyro-fb not active, so skipping on_spell_cast", 3)
        return false
    end

    -- Handle Fire Blast cast
    if spell_id == spell_data.SPELL.FIRE_BLAST.id and self.state == self.STATES.FIRE_BLAST_CAST then
        self:log("Detected Fire Blast cast, transitioning to PYROBLAST_CAST state", 2)
        self.state = self.STATES.PYROBLAST_CAST
        return true
    end

    -- Handle Pyroblast cast
    if spell_id == spell_data.SPELL.PYROBLAST.id and self.state == self.STATES.PYROBLAST_CAST then
        self:log("Detected Pyroblast cast, pattern complete", 1)
        self:reset()
        return true
    end

    -- If Pyroblast is cast at any point, reset the pattern
    if spell_id == spell_data.SPELL.PYROBLAST.id then
        self:log("Pyroblast cast detected outside of expected state, resetting pattern", 2)
        self:reset()
        return true
    end

    return false
end

return PyroFireBlastPattern
