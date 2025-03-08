local BasePattern = require("patterns/base_pattern")
local resources = require("resources")
local spellcasting = require("spellcasting")
local spell_data = require("spell_data")

---@class ScorchFireblastDoublePyro : BasePattern
local ScorchFireblastDoublePyro = BasePattern:new("Scorch+FB+DoublePyro pattern")

-- Define states
ScorchFireblastDoublePyro.STATES = {
    NONE = "NONE",
    SCORCH = "SCORCH",
    FIRE_BLAST = "FIRE_BLAST",
    HOT_STREAK = "HOT_STREAK",
    PYROBLAST = "PYROBLAST",
}


ScorchFireblastDoublePyro.steps           = {
    ScorchFireblastDoublePyro.STATES.NONE,
    ScorchFireblastDoublePyro.STATES.SCORCH,
    ScorchFireblastDoublePyro.STATES.FIRE_BLAST,
    ScorchFireblastDoublePyro.STATES.HOT_STREAK,
    ScorchFireblastDoublePyro.STATES.PYROBLAST,
    ScorchFireblastDoublePyro.STATES.HOT_STREAK,
    ScorchFireblastDoublePyro.STATES.PYROBLAST,

}

ScorchFireblastDoublePyro.expected_spells = {
    [ScorchFireblastDoublePyro.STATES.NONE] = nil,
    [ScorchFireblastDoublePyro.STATES.SCORCH] = spell_data.SPELL.SCORCH.id,
    [ScorchFireblastDoublePyro.STATES.FIRE_BLAST] = spell_data.SPELL.FIRE_BLAST.id,
    [ScorchFireblastDoublePyro.STATES.HOT_STREAK] = spell_data.CUSTOM_BUFF_DATA.HOT_STREAK.id,
    [ScorchFireblastDoublePyro.STATES.PYROBLAST] = spell_data.SPELL.PYROBLAST.id,
}

ScorchFireblastDoublePyro.step_logic      = {
    [ScorchFireblastDoublePyro.STATES.NONE] = nil,
    [ScorchFireblastDoublePyro.STATES.SCORCH] = spell_data.SPELL.SCORCH,
    [ScorchFireblastDoublePyro.STATES.FIRE_BLAST] = spell_data.SPELL.FIRE_BLAST,
    [ScorchFireblastDoublePyro.STATES.HOT_STREAK] = nil,
    [ScorchFireblastDoublePyro.STATES.PYROBLAST] = spell_data.SPELL.PYROBLAST,
}

-- Set initial state
ScorchFireblastDoublePyro.state           = ScorchFireblastDoublePyro.STATES.NONE

---@param player game_object
---@return boolean
function ScorchFireblastDoublePyro:should_start(player)
    self:log("Evaluating conditions:", 3)

    -- Check if we just cast Pyroblast
    if spellcasting.last_cast ~= spell_data.SPELL.PYROBLAST.name then
        self:log("REJECTED: Last cast was not Pyroblast (was " .. (spellcasting.last_cast or "nil") .. ")", 2)
        return false
    end
    self:log("Check: Last cast WAS Pyroblast ✓", 3)

    local combustion_remaining = resources:get_combustion_remaining(player)

    -- Calculate if Fire Blast will be ready by the end of Scorch cast
    local scorch_cast_time = core.spell_book.get_spell_cast_time(spell_data.SPELL.SCORCH.id)

    local fire_blast_charges = resources:get_fire_blast_charges()
    local fire_blast_ready_in = resources:next_fire_blast_charge_ready_in()

    local cooking_fb_charge = fire_blast_ready_in < scorch_cast_time - .2 and 1 or 0
    -- Check if Scorch cast + safety margin will finish before Combustion ends

    if cooking_fb_charge + fire_blast_charges == 0 then
        self:log("REJECTED: no fireblast charges")
        return false
    end

    local combustion_remaining_sec = combustion_remaining / 1000
    if (scorch_cast_time + 0.2) >= combustion_remaining_sec then
        self:log("REJECTED: Not enough Combustion time left (Combustion: " ..
            string.format("%.2f", combustion_remaining_sec) .. "s, Required: " ..
            string.format("%.2f", scorch_cast_time + 0.1) .. "s)", 2)
        return false
    end

    self:log("ACCEPTED: All conditions met, starting sequence", 1)
    return true
end

function ScorchFireblastDoublePyro:start()
    self.active = true
    self.state = self.STATES.SCORCH
    self.start_time = core.time()
    self.current_step = 2
    self:log("STARTED - State: " .. self.state, 1)
end

function ScorchFireblastDoublePyro:reset()
    local prev_state = self.state
    self.active = false
    self.state = self.STATES.NONE
    self.start_time = 0
    self.current_step = 1
    self:log("RESET (from " .. prev_state .. " state)", 1)
end

return ScorchFireblastDoublePyro
