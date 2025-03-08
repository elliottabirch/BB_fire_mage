local BasePattern                    = require("patterns/base_pattern")
local resources                      = require("resources")
local config                         = require("config")
local spellcasting                   = require("spellcasting")
local spell_data                     = require("spell_data")

---@class PyroFireBlastPattern : BasePattern
local PyroFireBlastPattern           = BasePattern:new("Pyro->FB pattern")

PyroFireBlastPattern.start_on_gcd    = true

-- Define states
PyroFireBlastPattern.STATES          = {
    NONE = "NONE",
    FIRE_BLAST = "FIRE_BLAST",
    HOT_STREAK = "HOT_STREAK",
    PYROBLAST = "PYROBLAST"
}

PyroFireBlastPattern.steps           = {
    PyroFireBlastPattern.STATES.NONE,
    PyroFireBlastPattern.STATES.FIRE_BLAST,
    PyroFireBlastPattern.STATES.HOT_STREAK,
    PyroFireBlastPattern.STATES.PYROBLAST
}

PyroFireBlastPattern.expected_spells = {
    [PyroFireBlastPattern.STATES.NONE] = nil,
    [PyroFireBlastPattern.STATES.FIRE_BLAST] = spell_data.SPELL.FIRE_BLAST.id,
    [PyroFireBlastPattern.STATES.HOT_STREAK] = spell_data.CUSTOM_BUFF_DATA.HOT_STREAK.id,
    [PyroFireBlastPattern.STATES.PYROBLAST] = spell_data.SPELL.PYROBLAST.id
}

PyroFireBlastPattern.step_logic      = {
    [PyroFireBlastPattern.STATES.NONE] = nil,
    [PyroFireBlastPattern.STATES.FIRE_BLAST] = spell_data.SPELL.FIRE_BLAST,
    [PyroFireBlastPattern.STATES.HOT_STREAK] = nil,
    [PyroFireBlastPattern.STATES.PYROBLAST] = spell_data.SPELL.PYROBLAST
}

-- Set initial state
PyroFireBlastPattern.state           = PyroFireBlastPattern.STATES.NONE

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

    local fire_blast_charges = resources:get_fire_blast_charges()
    local fire_blast_ready_in = resources:next_fire_blast_charge_ready_in()

    local cooking_fb_charge = fire_blast_ready_in < .75 and 1 or 0
    if resources:get_spellfire_sphere_charges(player) >= 4 and fire_blast_charges + cooking_fb_charge < 2 then
        self:log("REJECTED: holding for spellfire_spheres")
        return false
    end

    if resources:has_burden_of_power(player) and fire_blast_charges + cooking_fb_charge < 2 then
        self:log("REJECTED: burden of power is up")
        return false
    end

    -- Check if we have Fire Blast charge or will have one soon
    if fire_blast_charges > 0 then
        self:log("ACCEPTED: Have Fire Blast charges (" .. fire_blast_charges .. ")", 2)
        return true
    end
    local gcd = core.spell_book.get_global_cooldown()
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
    self.current_step = 2
    self:log("STARTED - State: " .. self.state, 1)
end

return PyroFireBlastPattern
