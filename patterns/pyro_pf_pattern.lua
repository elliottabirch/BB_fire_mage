local BasePattern = require("patterns/base_pattern")
local resources = require("resources")
local config = require("config")
local spellcasting = require("spellcasting")
local spell_data = require("spell_data")

---@class PyroPhoenixFlamePattern : BasePattern
local PyroPhoenixFlamePattern = BasePattern:new("Pyro->PF pattern")

-- Define states
PyroPhoenixFlamePattern.STATES = {
    NONE = "NONE",
    PF_CAST = "PF_CAST",
    PYROBLAST_CAST = "PYROBLAST_CAST"
}

-- Set initial state
PyroPhoenixFlamePattern.state = PyroPhoenixFlamePattern.STATES.NONE

---@param player game_object
---@param pyro_fb_active boolean Whether Pyro-FB pattern is active
---@return boolean
function PyroPhoenixFlamePattern:should_start(player, pyro_fb_active)
    self:log("Evaluating conditions:", 3)

    -- If the Fire Blast pattern is active, don't start this one
    if pyro_fb_active then
        self:log("REJECTED: Fire Blast pattern already active", 2)
        return false
    end
    self:log("Check: No Fire Blast pattern active ✓", 3)

    -- Check if we just cast Pyroblast
    if spellcasting.last_cast ~= spell_data.SPELL.PYROBLAST.name then
        self:log("REJECTED: Last cast was not Pyroblast (was " .. (spellcasting.last_cast or "nil") .. ")", 2)
        return false
    end
    self:log("Check: Last cast WAS Pyroblast ✓", 3)

    -- Check if GCD is active
    local gcd = core.spell_book.get_global_cooldown()
    if gcd > 0 then
        self:log("REJECTED: Global cooldown is active (GCD: " .. gcd .. ")", 2)
        return false
    end
    self:log("Check: GCD is not active (" .. string.format("%.2f", gcd) .. "s) ✓", 3)

    -- Check if we have Phoenix Flames charge
    local pf_charges = resources:get_phoenix_flames_charges()
    if pf_charges > 0 then
        self:log("ACCEPTED: Have Phoenix Flames charges (" .. pf_charges .. ")", 2)
        return true
    end

    -- Check if a charge will be ready by end of GCD
    local pf_ready_time = resources:phoenix_flames_ready_in(gcd)
    if pf_ready_time < gcd then
        self:log(
            "ACCEPTED: Phoenix Flames will be ready in " .. string.format("%.2f", pf_ready_time) .. "s (before GCD ends)",
            2)
        return true
    end

    self:log("REJECTED: No Phoenix Flames charges and none will be ready soon", 2)
    return false
end

function PyroPhoenixFlamePattern:start()
    self.active = true
    self.state = self.STATES.PF_CAST
    self.start_time = core.time()
    self:log("STARTED - State: " .. self.state, 1)
end

---@param player game_object
---@param target game_object
---@return boolean
function PyroPhoenixFlamePattern:execute(player, target)
    if not self.active then
        return false
    end

    local gcd = core.spell_book.get_global_cooldown()
    self:log("Executing - Current state: " .. self.state .. ", GCD: " .. string.format("%.2f", gcd) .. "s", 3)

    -- State: PHOENIX_FLAMES_CAST
    if self.state == self.STATES.PF_CAST then
        local pf_charges = resources:get_phoenix_flames_charges()
        self:log("Checking Phoenix Flames charges: " .. pf_charges, 3)

        if pf_charges > 0 and gcd == 0 then
            self:log("Attempting to cast Phoenix Flames", 2)
            if spellcasting:cast_spell(spell_data.SPELL.PHOENIX_FLAMES, target, false, false) then
                self.state = self.STATES.PYROBLAST_CAST
                self:log("Phoenix Flames cast successful, transitioning to PYROBLAST_CAST state", 2)
                return true
            else
                self:log("Phoenix Flames cast FAILED, retrying", 2)
                return true
            end
        else
            self:log("ABANDONED: No Phoenix Flames charges", 1)
            self:reset()
            return false
        end

        -- State: PYROBLAST_CAST
    elseif self.state == self.STATES.PYROBLAST_CAST then
        local has_hot_streak = resources:has_hot_streak(player)
        self:log("Checking for Hot Streak before Pyroblast (Hot Streak: " .. tostring(has_hot_streak) .. ")", 3)

        if gcd == 0 then
            if spellcasting:cast_spell(spell_data.SPELL.PYROBLAST, target, false, false) then
                self:log("COMPLETED: Full sequence executed successfully", 1)
                self:reset()
                return true
            else
                self:log("Pyroblast cast FAILED, retrying", 2)
                return true
            end
        elseif gcd <= 0 and self.start_time + config.reset_time > core.time() then
            self:log("ABANDONED: No Hot Streak for Pyroblast after Phoenix Flames (GCD ended)", 1)
            self:reset()
            return false
        else
            self:log("Waiting for Hot Streak proc or GCD (Current GCD: " .. string.format("%.2f", gcd) .. "s)", 3)
            return true
        end
    end

    return true
end

return PyroPhoenixFlamePattern
