local BasePattern = require("patterns/base_pattern")
local resources = require("resources")
local config = require("config")
local spellcasting = require("spellcasting")
local spell_data = require("spell_data")

---@class CombustionOpenerPattern : BasePattern
---@field has_activated_this_combustion boolean
local CombustionOpenerPattern = BasePattern:new("combustion_opener")

-- Define states
CombustionOpenerPattern.STATES = {
    NONE = "NONE",
    SCORCH = "SCORCH",                       -- Initial scorch to build heating up
    CONTINGENT_SCORCH = "CONTINGENT_SCORCH", -- Initial scorch to build heating up
    PHOENIX_FLAMES = "PHOENIX_FLAMES",       -- Phoenix flames to convert heating up to hot streak
    FIRE_BLAST = "FIRE_BLAST",               -- Cast fire blast during combustion
    COMBUSTION = "COMBUSTION",               -- Cast combustion
    HOT_STREAK = "HOT_STREAK",               -- Cast first pyroblast
    PYROBLAST = "PYROBLAST",                 -- Cast first pyroblast
    SECOND_HOT_STREAK = "SECOND_HOT_STREAK", -- Cast first pyroblast
}


CombustionOpenerPattern.steps           = {
    CombustionOpenerPattern.STATES.NONE,
    CombustionOpenerPattern.STATES.SCORCH,
    CombustionOpenerPattern.STATES.PHOENIX_FLAMES,
    CombustionOpenerPattern.STATES.SCORCH,
    CombustionOpenerPattern.STATES.FIRE_BLAST,
    CombustionOpenerPattern.STATES.COMBUSTION,
    CombustionOpenerPattern.STATES.HOT_STREAK,
    CombustionOpenerPattern.STATES.PYROBLAST,
    CombustionOpenerPattern.STATES.SECOND_HOT_STREAK,
    CombustionOpenerPattern.STATES.PYROBLAST
}

CombustionOpenerPattern.expected_spells = {
    [CombustionOpenerPattern.STATES.NONE] = nil,
    [CombustionOpenerPattern.STATES.FIRE_BLAST] = spell_data.SPELL.FIRE_BLAST.id,
    [CombustionOpenerPattern.STATES.SCORCH] = spell_data.SPELL.SCORCH.id,
    [CombustionOpenerPattern.STATES.PHOENIX_FLAMES] = spell_data.SPELL.PHOENIX_FLAMES.id,
    [CombustionOpenerPattern.STATES.COMBUSTION] = spell_data.SPELL.COMBUSTION.id,
    [CombustionOpenerPattern.STATES.HOT_STREAK] = spell_data.CUSTOM_BUFF_DATA.HOT_STREAK.id,
    [CombustionOpenerPattern.STATES.PYROBLAST] = spell_data.SPELL.PYROBLAST.id,
    [CombustionOpenerPattern.STATES.SECOND_HOT_STREAK] = spell_data.CUSTOM_BUFF_DATA.HOT_STREAK.id
}

CombustionOpenerPattern.step_logic      = {
    [CombustionOpenerPattern.STATES.NONE] = nil,
    [CombustionOpenerPattern.STATES.PHOENIX_FLAMES] = spell_data.SPELL.PHOENIX_FLAMES,
    [CombustionOpenerPattern.STATES.SCORCH] = spell_data.SPELL.SCORCH,
    [CombustionOpenerPattern.STATES.FIRE_BLAST] = function(player, target)
        return CombustionOpenerPattern.handle_fireblast_cast(CombustionOpenerPattern, player,
            target)
    end,
    [CombustionOpenerPattern.STATES.HOT_STREAK] = function(player, target)
        return CombustionOpenerPattern.handle_hot_streak(CombustionOpenerPattern, player,
            target)
    end,
    [CombustionOpenerPattern.STATES.COMBUSTION] = function(player, target)
        return CombustionOpenerPattern.handle_combustion_cast(CombustionOpenerPattern, player,
            target)
    end,
    [CombustionOpenerPattern.STATES.PYROBLAST] = spell_data.SPELL.PYROBLAST,
    [CombustionOpenerPattern.STATES.SECOND_HOT_STREAK] = nil
}


-- Set initial state and additional properties
CombustionOpenerPattern.state = CombustionOpenerPattern.STATES.NONE
CombustionOpenerPattern.has_activated_this_combustion = false

---@param player game_object
---@param target game_object
function CombustionOpenerPattern:handle_hot_streak(player, target)
    local has_hot_streak = resources:has_hot_streak(player)
    if has_hot_streak then
        self.state = self.STATES.PYROBLAST
        self.current_step = self.current_step + 1
    end
    return true
end

---@param player game_object
---@param target game_object
function CombustionOpenerPattern:handle_combustion_cast(player, target)
    local is_casting = player:is_casting_spell()
    local cast_end_time = player:get_active_spell_cast_end_time()
    local current_time = core.game_time()
    -- Wait for any existing cast or GCD
    if is_casting then
        local remaining_cast_time = (cast_end_time - current_time) / 1000
        if remaining_cast_time < config.combust_precast_time / 1000 then
            -- Time to precast Combustion during current cast
            self:log("Attempting to cast Combustion during cast (remaining: " ..
                string.format("%.2f", remaining_cast_time) .. "s)", 2)
            if spellcasting:cast_spell(spell_data.SPELL.COMBUSTION, target, false, false) then
                self:log("Combustion cast initiated", 2)
                self.has_activated_this_combustion = true
                return true
            end
        else
            self:log("Waiting for cast to reach combustion precast window", 3)
            return true
        end
    else
        self:reset()
    end
    return true
end

---@param player game_object
---@param target game_object
function CombustionOpenerPattern:handle_fireblast_cast(player, target)
    -- Common checks for all states
    local is_casting = player:is_casting_spell()
    local cast_end_time = player:get_active_spell_cast_end_time()
    local current_time = core.game_time()
    local has_hot_streak = resources:has_hot_streak(player)
    if has_hot_streak then
        self:log("Skipping FB because we have hot streak already", 2)
        self.state = self.STATES.COMBUSTION
        self.current_step = 6
        return true
    end

    self:log("Attempting to cast Fire Blast", 2)
    if is_casting then
        local remaining_cast_time = (cast_end_time - current_time) / 1000
        if remaining_cast_time < (config.combust_precast_time + 200) / 1000 then
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
function CombustionOpenerPattern:should_start(player, patterns_active)
    self:log("Evaluating conditions:", 3)
    if not resources:will_use_combustion() then
        self:log("REJECTED: will not use combusiton")
        return false
    end

    if self.has_activated_this_combustion then
        self:log("REJECTED: opener already activated this combustion", 2)
        return false
    end

    -- Check combustion CD condition
    local combustion_cd = core.spell_book.get_spell_cooldown(spell_data.SPELL.COMBUSTION.id)
    self:log("Combustion CD: " .. combustion_cd, 3)
    if combustion_cd > 2 then
        self:log("REJECTED: Combustion CD too high (" .. combustion_cd .. " > 2s)", 2)
        return false
    end

    -- Check if we have 1 charge of Phoenix Flames
    local pf_charges = resources:get_phoenix_flames_charges()
    if pf_charges < 1 then
        self:log("REJECTED: Not enough Phoenix Flames charges (" .. pf_charges .. " < 1)", 2)
        return false
    end

    -- Check if we have at least 2 Fire Blast charges
    local fb_charges = resources:get_fire_blast_charges()
    if fb_charges < 2 then
        self:log("REJECTED: Not enough Fire Blast charges (" .. fb_charges .. " < 2)", 2)
        return false
    end

    -- Successfully passed all checks
    self:log("ACCEPTED: Combustion CD < 2s, " .. pf_charges .. " Phoenix Flames charges, " ..
        fb_charges .. " Fire Blast charges", 1)

    -- Store which state we should start in based on current buffs
    self.start_state = self.STATES.INITIAL_SCORCH -- Default

    -- Check for hot streak or heating up
    local has_hot_streak = resources:has_hot_streak(player)
    local has_heating_up = resources:has_heating_up(player)

    if has_hot_streak then
        self:log("Player has Hot Streak - will start with SCORCH_CAST", 1)
        self.start_state = self.STATES.SCORCH_CAST
        self.current_step = 4
    elseif has_heating_up then
        self:log("Player has Heating Up - will start with PHOENIX_FLAMES", 1)
        self.start_state = self.STATES.PHOENIX_FLAMES
        self.current_step = 3
    else
        self:log("Player has no procs - will start with INITIAL_SCORCH", 1)
        self.start_state = self.STATES.INITIAL_SCORCH
        self.current_step = 2
    end

    return true
end

function CombustionOpenerPattern:start()
    self.active = true
    self.state = self.start_state or self.STATES.SCORCH
    self.current_step = self.current_step or 2
    self.start_time = core.time()
    self.has_activated_this_combustion = false
    self:log("STARTED - State: " .. self.state, 1)
end

function CombustionOpenerPattern:reset()
    local prev_state = self.state
    self.active = false
    self.state = self.STATES.NONE
    self.current_step = 1
    self.start_time = 0
    self.start_state = nil
    self:log("RESET (from " .. prev_state .. " state)", 1)
end

function CombustionOpenerPattern:reset_combustion_flag()
    self.has_activated_this_combustion = false
end

return CombustionOpenerPattern
