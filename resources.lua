---@class Resources
local Resources = {}

local spell_data = require("spell_data")
local logger = require("logger")
local SPELL = spell_data.SPELL
local BUFF = spell_data.BUFF

local buff_manager = require("common/modules/buff_manager")
local menu_elements = require("ui/menu_elements")
local plugin_helper = require("common/utility/plugin_helper")
local combat_forecast = require("common/modules/combat_forecast")

---@return number
function Resources:get_fire_blast_charges()
    return core.spell_book.get_spell_charge(SPELL.FIRE_BLAST.id)
end

---@param seconds number
---@return number
function Resources:fire_blast_ready_in(seconds)
    local charge_cd = core.spell_book.get_spell_charge_cooldown_duration(SPELL.FIRE_BLAST.id)
    local start_time = core.spell_book.get_spell_charge_cooldown_start_time(SPELL.FIRE_BLAST.id)

    if start_time == 0 or self:get_fire_blast_charges() > 0 then
        return 0
    end

    local remaining = math.max(0, (start_time + charge_cd - core.game_time()) / 1000)
    return remaining <= seconds and remaining or 999
end

---@param player game_object
---@return boolean
function Resources:has_hot_streak(player)
    local hot_streak_data = buff_manager:get_buff_data(player, BUFF.HOT_STREAK)
    return hot_streak_data.is_active
end

---@param player game_object
---@return boolean
function Resources:has_heating_up(player)
    local heating_up_data = buff_manager:get_buff_data(player, BUFF.HEATING_UP)
    return heating_up_data.is_active
end

---@param player game_object
---@return boolean
function Resources:has_hyperthermia(player)
    local heating_up_data = buff_manager:get_buff_data(player, BUFF.HYPERTHERMIA)
    return heating_up_data.is_active
end

---@param player game_object
---@return boolean
function Resources:has_burden_of_power(player)
    local heating_up_data = buff_manager:get_buff_data(player, { 451049 })
    return heating_up_data.is_active
end

---@param player game_object
---@return boolean
function Resources:get_spellfire_sphere_charges(player)
    local spellfire_sphere_data = buff_manager:get_buff_data(player, { 449400 })
    return spellfire_sphere_data.stacks
end

---@return number
function Resources:get_phoenix_flames_charges()
    return core.spell_book.get_spell_charge(SPELL.PHOENIX_FLAMES.id)
end

---@return number
function Resources:next_phoenix_flames_charge_ready_in()
    if self:get_phoenix_flames_charges() == 2 then
        return 0
    end

    local charge_cd = core.spell_book.get_spell_charge_cooldown_duration(SPELL.PHOENIX_FLAMES.id)
    local start_time = core.spell_book.get_spell_charge_cooldown_start_time(SPELL.PHOENIX_FLAMES.id)

    if start_time == 0 then
        return 0
    end

    return (start_time + charge_cd - core.game_time())
end

---@param seconds number
---@return number
function Resources:phoenix_flames_ready_in(seconds)
    local charge_cd = core.spell_book.get_spell_charge_cooldown_duration(SPELL.PHOENIX_FLAMES.id)
    local start_time = core.spell_book.get_spell_charge_cooldown_start_time(SPELL.PHOENIX_FLAMES.id)

    if start_time == 0 or self:get_phoenix_flames_charges() > 0 then
        return 0
    end

    local remaining = math.max(0, (start_time + charge_cd - core.game_time()) / 1000)
    return remaining <= seconds and remaining or 999
end

---@param player game_object
---@return number
function Resources:get_combustion_remaining(player)
    local combustion_data = buff_manager:get_buff_data(player, BUFF.COMBUSTION)
    return combustion_data.is_active and combustion_data.remaining or 0
end

---@return number
function Resources:next_fire_blast_charge_ready_in()
    if self:get_fire_blast_charges() == 3 then
        return 0
    end

    local charge_cd = core.spell_book.get_spell_charge_cooldown_duration(SPELL.FIRE_BLAST.id)
    local start_time = core.spell_book.get_spell_charge_cooldown_start_time(SPELL.FIRE_BLAST.id)

    if start_time == 0 then
        return 0
    end

    return (start_time + charge_cd - core.game_time())
end

---@param player game_object
---@return number
function Resources:get_remaining_cast_time(player)
    local cast_end_time = player:get_active_spell_cast_end_time()
    local current_time = core.game_time()
    return (cast_end_time - current_time)
end

---@param player game_object
---@return number
function Resources:get_elapsed_cast_time(player)
    local cast_start_time = player:get_active_spell_cast_start_time()
    local current_time = core.game_time()
    return (current_time - cast_start_time)
end

function Resources:will_use_combustion()
    if not plugin_helper:is_toggle_enabled(menu_elements.toggle_cooldowns) then
        logger:log("REJECTED: Cooldowns are disabled via keybind", 2)
        return false
    end

    if menu_elements.smart_combustion:get_state() then
        local combat_length = combat_forecast:get_forecast()
        if combat_length < 30 then
            logger:log(
                "REJECTED: Smart Combustion enabled but fight is not predicted to be long enough: " ..
                combat_length .. " seconds", 2)
            return false
        else
            logger:log("Smart Combustion: Fight is predicted to be long enough: " .. combat_length .. " seconds", 3)
        end
    end
    return true
end

return Resources
