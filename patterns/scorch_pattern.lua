local BasePattern = require("patterns/base_pattern")
local resources = require("resources")
local spellcasting = require("spellcasting")
local spell_data = require("spell_data")
local targeting = require("targeting")
local buff_manager = require("common/modules/buff_manager")


---@class ScorchPattern : BasePattern
---@field scorch_end_time number The expected end time of the Scorch cast
local ScorchPattern = BasePattern:new("scorch_pattern")

ScorchPattern.start_on_gcd = true

-- Define states
ScorchPattern.STATES = {
    NONE = "NONE",
    FIRE_BLAST = "FIRE_BLAST",
    HOT_STREAK = "HOT_STREAK",
    PYROBLAST_CAST = "PYROBLAST_CAST"
}

ScorchPattern.steps = {
    ScorchPattern.STATES.NONE,
    ScorchPattern.STATES.FIRE_BLAST,
    ScorchPattern.STATES.HOT_STREAK,
    ScorchPattern.STATES.PYROBLAST_CAST
}

ScorchPattern.expected_spells = {
    [ScorchPattern.STATES.NONE] = nil,
    [ScorchPattern.STATES.FIRE_BLAST] = spell_data.SPELL.FIRE_BLAST.id,
    [ScorchPattern.STATES.HOT_STREAK] = spell_data.CUSTOM_BUFF_DATA.HOT_STREAK.id,
    [ScorchPattern.STATES.PYROBLAST_CAST] = spell_data.SPELL.PYROBLAST.id
}

ScorchPattern.step_logic = {
    [ScorchPattern.STATES.NONE] = nil,
    [ScorchPattern.STATES.FIRE_BLAST] = function(player, target)
        return ScorchPattern.handle_fire_blast(ScorchPattern, player,
            target)
    end,
    [ScorchPattern.STATES.HOT_STREAK] = nil,
    [ScorchPattern.STATES.PYROBLAST_CAST] = spell_data.SPELL.PYROBLAST
}


function ScorchPattern:handle_fire_blast(player, target)
    if resources:get_elapsed_cast_time(player) < .25 then
        self:log("waiting till all spells hit to decide to cast fire blast or not")
        return true
    end
    self:log("casting fire blast becauase of heating up or full charges" ..
        tostring(buff_manager:get_buff_data(player, spell_data.BUFF.GLORIOUS_INCANDESCENSE).is_active) ..
        " " .. core.spell_book.get_spell_charge_max(spell_data.SPELL.FIRE_BLAST.id))

    spellcasting:cast_spell(spell_data.SPELL.FIRE_BLAST, target, false, false)

    return true
end

function ScorchPattern:handle_pyroblast(player, target)
    self:log("Attempting to cast Pyroblast with Hot Streak", 2)
    spellcasting:cast_spell(spell_data.SPELL.PYROBLAST, target, false, false)
    return true
end

-- Set initial state
ScorchPattern.state = ScorchPattern.STATES.NONE
ScorchPattern.scorch_end_time = 0


function ScorchPattern:execute()
    self:log("Executing Scorch Pattern", 1)
end

---@param player game_object
---@param context table Context data for pattern selection
---@return boolean
function ScorchPattern:should_start(player, context)
    local STARTING_STATE = self.STATES.HOT_STREAK
    local STARTING_STEP = 3
    self:log("Evaluating conditions:", 3)
    local active_spell_id = player:get_active_spell_id()

    if active_spell_id ~= spell_data.SPELL.SCORCH.id then
        self:log("REJECTED: Not casting Scorch", 2)
        return false
    end

    local fb_charges = resources:get_fire_blast_charges()
    local fire_blast_ready_in = resources:next_fire_blast_charge_ready_in()

    local cooking_fb_charge = fire_blast_ready_in < (resources:get_remaining_cast_time(player)) - 250 and 1 or
        0
    local has_less_than_cap_FB_charges = fb_charges + cooking_fb_charge <
        core.spell_book.get_spell_charge_max(spell_data.SPELL.FIRE_BLAST.id)

    -- Check if we have Heating Up
    if not resources:has_heating_up(player) then
        if fb_charges + cooking_fb_charge == 0 then
            self:log("rejected: no heating up, no fb charges")
            return false
        end
        if has_less_than_cap_FB_charges then
            if buff_manager:get_buff_data(player, spell_data.BUFF.GLORIOUS_INCANDESCENSE).is_active then
                STARTING_STATE = self.STATES.FIRE_BLAST
                STARTING_STEP = 2
                self:log("CONTNUING: we have glorious incandescense")
            else
                self:log(
                    "skipping because we dont have heating up, our fb charges are low, and we dont have glorious incandescense")
                return false
            end
        else
            STARTING_STATE = self.STATES.FIRE_BLAST
            STARTING_STEP = 2
            self:log("CONTNUING: have max fireblast stacks")
        end
    end

    self:log(
        "CONTNUING: we have " .. fb_charges .. " FB charges and heating up")

    -- Check if target is a valid Scorch target (low health)
    local scorch_target = targeting:get_scorch_target()
    if not scorch_target then
        self:log("REJECTED: No valid Scorch target", 2)
        return false
    end

    self:log("ACCEPTED: Casting Scorch with Heating Up or fb charge on low health target", 1)
    self.state = STARTING_STATE
    self.current_step = STARTING_STEP
    return true
end

function ScorchPattern:start()
    self:log("Starting Scorch Pattern with on state: " .. self.state, 2)
    self.active = true
end

return ScorchPattern
