local BasePattern = require("patterns/base_pattern")
local resources = require("resources")
local spellcasting = require("spellcasting")
local spell_data = require("spell_data")

---@class ScorchFireBlastPattern : BasePattern
local ScorchFireBlastPattern = BasePattern:new("Scorch+FB pattern")

-- Define states
ScorchFireBlastPattern.STATES = {
    NONE = "NONE",
    SCORCH = "SCORCH",
    FIRE_BLAST = "FIRE_BLAST",
    HOT_STREAK = "HOT_STREAK",
    PYROBLAST = "PYROBLAST",
    SECOND_PYROBLAST_CAST = "SECOND_PYROBLAST_CAST"
}


ScorchFireBlastPattern.steps           = {
    ScorchFireBlastPattern.STATES.NONE,
    ScorchFireBlastPattern.STATES.SCORCH,
    ScorchFireBlastPattern.STATES.HOT_STREAK,
    ScorchFireBlastPattern.STATES.PYROBLAST,

}

ScorchFireBlastPattern.expected_spells = {
    [ScorchFireBlastPattern.STATES.NONE] = nil,
    [ScorchFireBlastPattern.STATES.SCORCH] = spell_data.SPELL.SCORCH.id,
    [ScorchFireBlastPattern.STATES.HOT_STREAK] = spell_data.CUSTOM_BUFF_DATA.HOT_STREAK.id,
    [ScorchFireBlastPattern.STATES.PYROBLAST] = spell_data.SPELL.PYROBLAST.id,
}

ScorchFireBlastPattern.step_logic      = {
    [ScorchFireBlastPattern.STATES.NONE] = nil,
    [ScorchFireBlastPattern.STATES.SCORCH] = spell_data.SPELL.SCORCH,
    [ScorchFireBlastPattern.STATES.HOT_STREAK] = nil,
    [ScorchFireBlastPattern.STATES.PYROBLAST] = spell_data.SPELL.PYROBLAST,
}

-- Set initial state
ScorchFireBlastPattern.state           = ScorchFireBlastPattern.STATES.NONE

---@param player game_object
---@return boolean
function ScorchFireBlastPattern:should_start(player)
    self:log("Evaluating conditions:", 3)

    -- Check if we just cast Pyroblast
    if spellcasting.last_cast ~= spell_data.SPELL.PYROBLAST.name then
        self:log("REJECTED: Last cast was not Pyroblast (was " .. (spellcasting.last_cast or "nil") .. ")", 2)
        return false
    end

    local combustion_remaining = resources:get_combustion_remaining(player)

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
    self.state = self.STATES.SCORCH
    self.start_time = core.time()
    self.current_step = 2
    self:log("STARTED - State: " .. self.state, 1)
end

function ScorchFireBlastPattern:reset()
    local prev_state = self.state
    self.active = false
    self.state = self.STATES.NONE
    self.start_time = 0
    self.current_step = 1
    self:log("RESET (from " .. prev_state .. " state)", 1)
end

return ScorchFireBlastPattern
