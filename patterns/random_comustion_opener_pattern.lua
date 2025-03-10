local BasePattern                   = require("patterns/base_pattern")
local resources                     = require("resources")
local config                        = require("config")
local spellcasting                  = require("spellcasting")
local spell_data                    = require("spell_data")

---@class RandomCombustionOpener : BasePattern
---@field has_activated_this_combustion boolean
local RandomCombustionOpener        = BasePattern:new("random_combustion_opener")
RandomCombustionOpener.start_on_gcd = true

-- Define states
RandomCombustionOpener.STATES       = {
    NONE = "NONE",
    SCORCH = "SCORCH",                       -- Initial scorch to build heating up
    PHOENIX_FLAMES = "PHOENIX_FLAMES",       -- Phoenix flames to convert heating up to hot streak
    FIRE_BLAST = "FIRE_BLAST",               -- Cast fire blast during combustion
    HOT_STREAK = "HOT_STREAK",               -- Cast first pyroblast
    PYROBLAST = "PYROBLAST",                 -- Cast first pyroblast
    CHECK_CASTING = "CHECK_CASTING",         -- Cast first pyroblast
    SECOND_HOT_STREAK = "SECOND_HOT_STREAK", -- Cast first pyroblast
}


RandomCombustionOpener.steps           = {
    RandomCombustionOpener.STATES.NONE,
    RandomCombustionOpener.STATES.CHECK_CASTING,
    RandomCombustionOpener.STATES.PHOENIX_FLAMES,
    RandomCombustionOpener.STATES.SCORCH,
    RandomCombustionOpener.STATES.FIRE_BLAST,
    RandomCombustionOpener.STATES.HOT_STREAK,
    RandomCombustionOpener.STATES.PYROBLAST,
    RandomCombustionOpener.STATES.SECOND_HOT_STREAK,
    RandomCombustionOpener.STATES.PYROBLAST,
}

RandomCombustionOpener.expected_spells = {
    [RandomCombustionOpener.STATES.NONE] = nil,
    [RandomCombustionOpener.STATES.FIRE_BLAST] = spell_data.SPELL.FIRE_BLAST.id,
    [RandomCombustionOpener.STATES.SCORCH] = spell_data.SPELL.SCORCH.id,
    [RandomCombustionOpener.STATES.PHOENIX_FLAMES] = spell_data.SPELL.PHOENIX_FLAMES.id,
    [RandomCombustionOpener.STATES.HOT_STREAK] = spell_data.CUSTOM_BUFF_DATA.HOT_STREAK.id,
    [RandomCombustionOpener.STATES.PYROBLAST] = spell_data.SPELL.PYROBLAST.id,
    [RandomCombustionOpener.STATES.CHECK_CASTING] = nil,
    [RandomCombustionOpener.STATES.SECOND_HOT_STREAK] = spell_data.CUSTOM_BUFF_DATA.HOT_STREAK.id
}

RandomCombustionOpener.step_logic      = {
    [RandomCombustionOpener.STATES.NONE] = nil,
    [RandomCombustionOpener.STATES.CHECK_CASTING] = function(player, target)
        return RandomCombustionOpener.handle_check_casting(RandomCombustionOpener, player,
            target)
    end,
    [RandomCombustionOpener.STATES.PHOENIX_FLAMES] = spell_data.SPELL.PHOENIX_FLAMES,
    [RandomCombustionOpener.STATES.SCORCH] = spell_data.SPELL.SCORCH,
    [RandomCombustionOpener.STATES.FIRE_BLAST] = function(player, target)
        return RandomCombustionOpener.handle_fireblast_cast(RandomCombustionOpener, player,
            target)
    end,
    [RandomCombustionOpener.STATES.HOT_STREAK] = function(player, target)
        return RandomCombustionOpener.handle_hot_streak(RandomCombustionOpener, player,
            target)
    end,
    [RandomCombustionOpener.STATES.PYROBLAST] = spell_data.SPELL.PYROBLAST,
    [RandomCombustionOpener.STATES.SECOND_HOT_STREAK] = nil
}


-- Set initial state and additional properties
RandomCombustionOpener.state = RandomCombustionOpener.STATES.NONE
RandomCombustionOpener.has_activated_this_combustion = false

---@param player game_object
---@param target game_object
function RandomCombustionOpener:handle_check_casting(player, target)
    local player = core.object_manager.get_local_player()
    local is_casting = player:is_casting_spell()
    local active_spell_id = player:get_active_spell_id()
    local crits = 0
    self.has_activated_this_combustion = true
    self:log("---> is casting " .. tostring(is_casting))
    self:log("---> active spell id " .. active_spell_id)

    if is_casting and active_spell_id == spell_data.SPELL.FIREBALL.id then
        self:log("interrupting spell cast because of random combustion", 3)
        core.input.move_up_start()

        core.input.move_up_stop()
        return true
    end

    if is_casting and active_spell_id == spell_data.SPELL.SCORCH.id then
        crits = crits + 1
        self:log("adding crit because casting scorch. current crit value: " .. crits)
    end



    if resources:has_heating_up(player) then
        crits = crits + 1
        self:log("adding crit because of heating up. current crit value: " .. crits)
    end

    if resources:has_hot_streak(player) then
        crits = 4
        self:log("has hot streak, skipping all builders. current crit value: " .. crits)
    end

    self.current_step = crits + 3
    self.state = self.steps[self.current_step]
    self:log("PASSED: starting with " ..
        crits .. " crits, on step " .. self.current_step .. " with state: " .. self.state)

    return true
end

---@param player game_object
---@param target game_object
function RandomCombustionOpener:handle_hot_streak(player, target)
    local has_hot_streak = resources:has_hot_streak(player)
    if has_hot_streak then
        self.state = self.STATES.PYROBLAST
        self.current_step = self.current_step + 1
    end
    return true
end

---@param player game_object
---@param target game_object
function RandomCombustionOpener:handle_fireblast_cast(player, target)
    -- Common checks for all states
    local is_casting = player:is_casting_spell()
    local cast_end_time = player:get_active_spell_cast_end_time()
    local current_time = core.game_time()
    local has_hot_streak = resources:has_hot_streak(player)
    if has_hot_streak then
        self:log("Skipping FB because we have hot streak already", 2)
        self.current_step = self.current_step + 1
        self.state = self.steps[self.current_step]
        return true
    end

    self:log("Attempting to cast Fire Blast", 2)
    if is_casting then
        local remaining_cast_time = (cast_end_time - current_time) / 1000
        if remaining_cast_time < 300 / 1000 then
            if spellcasting:cast_spell(spell_data.SPELL.FIRE_BLAST, target, false, false) then
                self:log("Fire Blast cast initiated", 2)
            else
                self:log("Failed to cast Fire Blast, will retry", 2)
            end
        end
    else
        if spellcasting:cast_spell(spell_data.SPELL.FIRE_BLAST, target, false, false) then
            self:log("Fire Blast cast initiated", 2)
        else
            self:log("Failed to cast Fire Blast, will retry", 2)
        end
    end
    return true
end

---@param player game_object
---@param patterns_active table Table containing active state of other patterns
---@return boolean
function RandomCombustionOpener:should_start(player, patterns_active)
    self:log("Evaluating conditions:", 3)


    if self.has_activated_this_combustion then
        self:log("REJECTED: random opener already activated this combustion", 2)
        return false
    end
    return true
end

function RandomCombustionOpener:start()
    self.active = true
    self.current_step = 2
    self.state = self.steps[self.current_step]
    self.start_time = core.time()
    self.has_activated_this_combustion = false
    self:log("STARTED - State: " .. self.state, 1)
end

function RandomCombustionOpener:reset()
    local prev_state = self.state
    self.active = false
    self.state = self.STATES.NONE
    self.current_step = 1
    self.start_time = 0
    self.start_state = nil
    self:log("RESET (from " .. prev_state .. " state)", 1)
end

function RandomCombustionOpener:reset_combustion_flag()
    self.has_activated_this_combustion = false
end

return RandomCombustionOpener
