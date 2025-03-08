local BasePattern                       = require("patterns/base_pattern")
local resources                         = require("resources")
local spellcasting                      = require("spellcasting")
local spell_data                        = require("spell_data")

---@class PyroPhoenixFlamePattern : BasePattern
local PyroPhoenixFlamePattern           = BasePattern:new("Pyro->PF pattern")

-- Define states
PyroPhoenixFlamePattern.STATES          = {
    NONE = "NONE",
    PHOENIX_FLAMES = "PHOENIX_FLAMES",
    HOT_STREAK = "HOT_STREAK",
    PYROBLAST = "PYROBLAST"
}

PyroPhoenixFlamePattern.steps           = {
    PyroPhoenixFlamePattern.STATES.NONE,
    PyroPhoenixFlamePattern.STATES.PHOENIX_FLAMES,
    PyroPhoenixFlamePattern.STATES.HOT_STREAK,
    PyroPhoenixFlamePattern.STATES.PYROBLAST,
}

PyroPhoenixFlamePattern.expected_spells = {
    [PyroPhoenixFlamePattern.STATES.NONE] = nil,
    [PyroPhoenixFlamePattern.STATES.PHOENIX_FLAMES] = spell_data.SPELL.PHOENIX_FLAMES.id,
    [PyroPhoenixFlamePattern.STATES.HOT_STREAK] = spell_data.CUSTOM_BUFF_DATA.HOT_STREAK.id,
    [PyroPhoenixFlamePattern.STATES.PYROBLAST] = spell_data.SPELL.PYROBLAST.id
}

PyroPhoenixFlamePattern.step_logic      = {
    [PyroPhoenixFlamePattern.STATES.NONE] = nil,
    [PyroPhoenixFlamePattern.STATES.PHOENIX_FLAMES] = spell_data.SPELL.PHOENIX_FLAMES,
    [PyroPhoenixFlamePattern.STATES.HOT_STREAK] = nil,
    [PyroPhoenixFlamePattern.STATES.PYROBLAST] = spell_data.SPELL.PYROBLAST
}


-- Set initial state
PyroPhoenixFlamePattern.state = PyroPhoenixFlamePattern.STATES.NONE

---@param player game_object
---@return boolean
function PyroPhoenixFlamePattern:should_start()
    self:log("Evaluating conditions:", 3)

    -- Check if we just cast Pyroblast
    if spellcasting.last_cast ~= spell_data.SPELL.PYROBLAST.name then
        self:log("REJECTED: Last cast was not Pyroblast (was " .. (spellcasting.last_cast or "nil") .. ")", 2)
        return false
    end
    self:log("CONTINUED: Last cast WAS Pyroblast", 3)

    -- Check if we have Phoenix Flames charge
    local pf_charges = resources:get_phoenix_flames_charges()
    local pf_ready_in = resources:next_phoenix_flames_charge_ready_in()
    local gcd = core.spell_book.get_global_cooldown()

    local cooking_pf_charge = pf_ready_in < gcd - .1 and 1 or 0
    if pf_charges + cooking_pf_charge > 0 then
        self:log(
        "ACCEPTED: Have Phoenix Flames charges (" ..
        pf_charges .. ")  and (" .. cooking_pf_charge .. " ) will be up before gcd ends", 2)
        return true
    end

    self:log("REJECTED: No Phoenix Flames charges and none will be ready soon", 2)
    return false
end

function PyroPhoenixFlamePattern:start()
    self.active = true
    self.state = self.STATES.PF_CAST
    self.start_time = core.time()
    self.current_step = 2
    self:log("STARTED - State: " .. self.state, 1)
end

function PyroPhoenixFlamePattern:reset()
    local prev_state = self.state
    self.active = false
    self.state = self.STATES.NONE
    self.start_time = 0
    self.current_step = 1
    self:log("RESET (from " .. prev_state .. " state)", 1)
end

return PyroPhoenixFlamePattern
