local BasePattern = require("patterns/base_pattern")
local resources = require("resources")
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

    -- Check if we just cast Pyroblast
    if spellcasting.last_cast ~= spell_data.SPELL.PYROBLAST.name then
        self:log("REJECTED: Last cast was not Pyroblast (was " .. (spellcasting.last_cast or "nil") .. ")", 2)
        return false
    end
    self:log("Check: Last cast WAS Pyroblast ✓", 3)

    -- Check if GCD is active
    local gcd = core.spell_book.get_global_cooldown()
    if gcd > 0.1 then
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

    self:log("REJECTED: No Phoenix Flames charges and none will be ready soon", 2)
    return false
end

function PyroPhoenixFlamePattern:start()
    self.active = true
    self.state = self.STATES.PF_CAST
    self.start_time = core.time()
    self:log("STARTED - State: " .. self.state, 1)
end

function PyroPhoenixFlamePattern:reset()
    local prev_state = self.state
    self.active = false
    self.state = self.STATES.NONE
    self.start_time = 0
    self:log("RESET (from " .. prev_state .. " state)", 1)
end

---@param spell_id number
---@return boolean
function PyroPhoenixFlamePattern:on_spell_cast(spell_id)
    if not self.active then
        return false
    end

    self:log("Processing spell cast: " .. spell_id, 3)

    -- Phoenix Flames was cast
    if spell_id == spell_data.SPELL.PHOENIX_FLAMES.id then
        if self.state == self.STATES.PF_CAST then
            self:log("Phoenix Flames cast detected - transitioning to PYROBLAST_CAST state", 2)
            self.state = self.STATES.PYROBLAST_CAST
            return true
        end

        -- Pyroblast was cast
    elseif spell_id == spell_data.SPELL.PYROBLAST.id then
        if self.state == self.STATES.PYROBLAST_CAST then
            self:log("Pyroblast cast detected in PYROBLAST_CAST state - pattern complete", 1)
            self:reset()
            return true
        end
    end

    return false
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
        self:log("Attempting to cast Phoenix Flames", 2)
        spellcasting:cast_spell(spell_data.SPELL.PHOENIX_FLAMES, target, false, false)
        -- No state transition here - handled by on_spell_cast
        return true
        -- State: PYROBLAST_CAST
    elseif self.state == self.STATES.PYROBLAST_CAST then
        if gcd == 0 then
            self:log("Attempting to cast Pyroblast with Hot Streak", 2)
            spellcasting:cast_spell(spell_data.SPELL.PYROBLAST, target, false, false)
            -- No state transition here - handled by on_spell_cast
            return true
        else
            if gcd > 0 then
                self:log("Waiting for GCD before Pyroblast cast", 3)
            end
            return true
        end
    end

    return true
end

return PyroPhoenixFlamePattern
