local BasePattern = require("patterns/base_pattern")
local resources = require("resources")
local spellcasting = require("spellcasting")
local spell_data = require("spell_data")
local targeting = require("targeting")

---@class ScorchPattern : BasePattern
local ScorchPattern = BasePattern:new("Scorch->Pyro pattern")

-- Define states
ScorchPattern.STATES = {
    NONE = "NONE",
    PYROBLAST_CAST = "PYROBLAST_CAST"
}

-- Set initial state
ScorchPattern.state = ScorchPattern.STATES.NONE

---@param player game_object
---@param context table Context data for pattern selection
---@return boolean
function ScorchPattern:should_start(player, context)
    self:log("Evaluating conditions:", 3)


    -- Check if we have Heating Up
    if not resources:has_heating_up(player) then
        self:log("REJECTED: No Heating Up buff", 2)
        return false
    end

    -- Check if we're casting or about to cast Scorch
    local is_casting = player:is_casting_spell()
    local active_spell_id = player:get_active_spell_id()

    if not is_casting or active_spell_id ~= spell_data.SPELL.SCORCH.id then
        self:log("REJECTED: Not casting Scorch", 2)
        return false
    end

    -- Check if target is a valid Scorch target (low health)
    local scorch_target = targeting:get_scorch_target()
    if not scorch_target then
        self:log("REJECTED: No valid Scorch target", 2)
        return false
    end

    self:log("ACCEPTED: Casting Scorch with Heating Up on low health target", 1)
    return true
end

function ScorchPattern:start()
    self.active = true
    self.state = self.STATES.PYROBLAST_CAST
    self.start_time = core.time()
    self:log("STARTED - State: " .. self.state, 1)
end

function ScorchPattern:reset()
    local prev_state = self.state
    self.active = false
    self.state = self.STATES.NONE
    self.start_time = 0
    self:log("RESET (from " .. prev_state .. " state)", 1)
end

---@param spell_id number
---@return boolean
function ScorchPattern:on_spell_cast(spell_id)
    if not self.active then
        return false
    end

    self:log("Processing spell cast: " .. spell_id, 3)


    -- Pyroblast was cast
    if spell_id == spell_data.SPELL.PYROBLAST.id then
        if self.state == self.STATES.PYROBLAST_CAST then
            self:log("Pyroblast cast detected - pattern complete", 1)
            self:reset()
            return true
        else
            self:log("Unexpected Pyroblast cast in " .. self.state .. " state - resetting pattern", 2)
            self:reset()
            return true
        end
    end

    return false
end

---@param player game_object
---@param target game_object
---@return boolean
function ScorchPattern:execute(player, target)
    if not self.active then
        return false
    end

    self:log("Executing - Current state: " .. self.state, 3)

    -- State: SCORCH_CAST
    if self.state == self.STATES.PYROBLAST_CAST then
        -- Check if we have Hot Streak
        if resources:has_hot_streak(player) then
            self:log("Attempting to cast Pyroblast with Hot Streak", 2)
            spellcasting:cast_spell(spell_data.SPELL.PYROBLAST, target, false, false)
        else
            self:log("Waiting for Hot Streak proc before Pyroblast", 3)
        end

        return true
    end

    return true
end

return ScorchPattern
