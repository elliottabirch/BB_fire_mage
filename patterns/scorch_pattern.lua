local BasePattern = require("patterns/base_pattern")
local resources = require("resources")
local spellcasting = require("spellcasting")
local spell_data = require("spell_data")
local targeting = require("targeting")
local buff_manager = require("common/modules/buff_manager")


---@class ScorchPattern : BasePattern
---@field scorch_end_time number The expected end time of the Scorch cast
local ScorchPattern = BasePattern:new("Scorch->Pyro pattern")

-- Define states
ScorchPattern.STATES = {
    NONE = "NONE",
    FIRE_BLAST = "FIRE_BLAST",
    PYROBLAST_CAST = "PYROBLAST_CAST"
}

-- Set initial state
ScorchPattern.state = ScorchPattern.STATES.NONE
ScorchPattern.scorch_end_time = 0

---@param player game_object
---@param context table Context data for pattern selection
---@return boolean
function ScorchPattern:should_start(player, context)
    self:log("Evaluating conditions:", 3)

    -- Check if we have Heating Up
    local fb_charges = resources:get_fire_blast_charges()
    local has_less_than_cap_FB_charges = fb_charges <
        core.spell_book.get_spell_charge_max(spell_data.SPELL.FIRE_BLAST.id)


    if not resources:has_heating_up(player) then
        if fb_charges == 0 then
            self:log("rejected: no heating up, no fb charges")
            return false
        end
        if has_less_than_cap_FB_charges then
            if buff_manager:get_buff_data(player, spell_data.BUFF.GLORIOUS_INCANDESCENSE).is_active then
                self:log("CONTNUING: we have glorious incandescense")
            else
                self:log(
                    "skipping because we dont have heating up, our fb charges are low, and we dont have glorious incandescense")
                return false
            end
        end
    end

    self:log(
        "CONTNUING: we have " .. fb_charges .. " FB charges and heating up")

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

    self:log("ACCEPTED: Casting Scorch with Heating Up or fb charge on low health target", 1)
    return true
end

function ScorchPattern:start()
    self.active = true
    -- Initial state is SCORCH_CASTING since we're already casting Scorch
    self.state = self.STATES.FIRE_BLAST
    self.start_time = core.time()

    -- Save the expected end time of the Scorch cast
    local player = core.object_manager.get_local_player()
    if player then
        self.scorch_end_time = player:get_active_spell_cast_end_time()
        self:log("STARTED - State: " .. self.state .. ", Scorch end time: " .. self.scorch_end_time, 1)
    else
        self:log("STARTED - State: " .. self.state .. " (couldn't get Scorch end time)", 1)
    end
end

function ScorchPattern:reset()
    local prev_state = self.state
    self.active = false
    self.state = self.STATES.NONE
    self.start_time = 0
    self.scorch_end_time = 0
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
    if spell_id == spell_data.SPELL.FIRE_BLAST.id then
        if self.state == self.STATES.FIRE_BLAST then
            self:log("Fire Blast Detected, advancing to PYROBLAST", 1)
            self.state = self.STATES.PYROBLAST_CAST
            return true
        end
    end
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
    local current_time = core.game_time()

    -- State: FIRE_BLAST
    if self.state == self.STATES.FIRE_BLAST then
        local fb_charges = resources:get_fire_blast_charges()
        if not resources:has_heating_up(player) and (buff_manager:get_buff_data(player, spell_data.BUFF.GLORIOUS_INCANDESCENSE).is_active or fb_charges == core.spell_book.get_spell_charge_max(spell_data.SPELL.FIRE_BLAST.id)) then
            self:log("casting fire blast becauase of heating up or full charges" ..
                tostring(buff_manager:get_buff_data(player, spell_data.BUFF.GLORIOUS_INCANDESCENSE)) ..
                " " .. fb_charges .. core.spell_book.get_spell_charge_max(spell_data.SPELL.FIRE_BLAST.id))

            spellcasting:cast_spell(spell_data.SPELL.FIRE_BLAST, target, false, false)
        end
        -- Check if Scorch cast has finished based on time
        if current_time > self.scorch_end_time then
            self:log("Scorch cast should be finished, transitioning to PYROBLAST_CAST state", 2)
            self.state = self.STATES.PYROBLAST_CAST
        else
            self:log("Waiting for Scorch cast to finish", 3)
        end
        return true

        -- State: PYROBLAST_CAST
    elseif self.state == self.STATES.PYROBLAST_CAST then
        -- Check if too much time has passed since Scorch finished
        if self.scorch_end_time > 0 and current_time > (self.scorch_end_time + 500) then
            self:log("Too much time has passed since Scorch finished, resetting pattern", 2)
            self:reset()
            return false
        end

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
