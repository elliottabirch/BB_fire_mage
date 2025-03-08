local BasePattern = require("patterns/base_pattern")
local resources = require("resources")
local spell_data = require("spell_data")
local buff_manager = require("common/modules/buff_manager")

---@class FireballHotstreakPattern : BasePattern
local FireballHotstreakPattern = BasePattern:new("Fireball->HotStreak pattern")

FireballHotstreakPattern.start_on_gcd = true

-- Define states
FireballHotstreakPattern.STATES = {
    NONE = "NONE",
    FIRE_BLAST = "FIRE_BLAST",
    PYROBLAST = "PYROBLAST",
    HOT_STREAK = "HOT_STREAK"
}


FireballHotstreakPattern.steps           = {
    FireballHotstreakPattern.STATES.NONE,
    FireballHotstreakPattern.STATES.FIRE_BLAST,
    FireballHotstreakPattern.STATES.HOT_STREAK,
    FireballHotstreakPattern.STATES.PYROBLAST
}

FireballHotstreakPattern.expected_spells = {
    [FireballHotstreakPattern.STATES.NONE] = nil,
    [FireballHotstreakPattern.STATES.FIRE_BLAST] = spell_data.SPELL.FIRE_BLAST.id,
    [FireballHotstreakPattern.STATES.HOT_STREAK] = spell_data.CUSTOM_BUFF_DATA.HOT_STREAK.id,
    [FireballHotstreakPattern.STATES.PYROBLAST] = spell_data.SPELL.PYROBLAST.id
}

FireballHotstreakPattern.step_logic      = {
    [FireballHotstreakPattern.STATES.NONE] = nil,
    [FireballHotstreakPattern.STATES.FIRE_BLAST] = spell_data.SPELL.FIRE_BLAST,
    [FireballHotstreakPattern.STATES.HOT_STREAK] = nil,
    [FireballHotstreakPattern.STATES.PYROBLAST] = spell_data.SPELL.PYROBLAST
}


-- Set initial state
FireballHotstreakPattern.state = FireballHotstreakPattern.STATES.NONE

---@param player game_object
---@param patterns_active table Table containing active state of other patterns
---@return boolean
function FireballHotstreakPattern:should_start(player, patterns_active)
    self:log("Evaluating conditions:", 3)


    local remaining_cast_time = resources:get_remaining_cast_time(player)
    local elapsed_cast_time = resources:get_elapsed_cast_time(player)
    local active_spell_id = player:get_active_spell_id()
    if active_spell_id ~= spell_data.SPELL.FIREBALL.id then
        self:log("REJECTED: Not casting Fireball", 2)
        return false
    end

    if remaining_cast_time < 300 then
        self:log("REJECTED: too late in cast (" .. remaining_cast_time .. "ms remaining)", 2)
        return false
    end

    if elapsed_cast_time < 500 then
        self:log("REJECTED: too early in cast (" .. elapsed_cast_time .. "ms remaining)", 2)
        return false
    end

    -- Check if we have Heating Up
    local fb_charges = resources:get_fire_blast_charges()
    local fire_blast_ready_in = resources:next_fire_blast_charge_ready_in()

    local cooking_fb_charge = fire_blast_ready_in < (resources:get_remaining_cast_time(player)) - 250 and 1 or
        0
    local has_less_than_cap_FB_charges = fb_charges + cooking_fb_charge <
        core.spell_book.get_spell_charge_max(spell_data.SPELL.FIRE_BLAST.id)
    if not resources:has_heating_up(player) then
        self:log("FAILURE: does not have heating up")
        return false
    end
    if fb_charges + cooking_fb_charge == 0 then
        self:log("FAILURE: no heating up, no fb charges")
        return false
    end
    if has_less_than_cap_FB_charges then
        local combustionCD = core.spell_book.get_spell_cooldown(spell_data.SPELL.COMBUSTION.id)

        if combustionCD < 15 then
            if not buff_manager:get_buff_data(player, spell_data.BUFF.GLORIOUS_INCANDESCENSE).is_active then
                self:log(
                    "FAILURE: skipping because our fb charges are low, and we dont have glorious incandescense")
                return false
            end
        end
    end


    self:log(
        "CONTNUING: we have " .. fb_charges .. " FB charges and heating up")


    self:log("ACCEPTED: Casting Fireball with Hot Streak active", 1)
    return true
end

function FireballHotstreakPattern:start()
    self.active = true
    self.state = self.STATES.FIRE_BLAST
    self.current_step = 2
    self.start_time = core.time()
    self:log("STARTED - State: " .. self.state, 1)
end

function FireballHotstreakPattern:reset()
    local prev_state = self.state
    self.active = false
    self.state = self.STATES.NONE
    self.current_step = 1
    self.start_time = 0
    self:log("RESET (from " .. prev_state .. " state)", 1)
end

return FireballHotstreakPattern
