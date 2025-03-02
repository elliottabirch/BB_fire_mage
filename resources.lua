---@class Resources
local Resources = {}

local spell_data = require("spell_data")
local SPELL = spell_data.SPELL
local BUFF = spell_data.BUFF

local buff_manager = require("common/modules/buff_manager")

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

---@return number
function Resources:get_phoenix_flames_charges()
    return core.spell_book.get_spell_charge(SPELL.PHOENIX_FLAMES.id)
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

---@param duration number
---@return boolean
function Resources:fire_blast_will_be_ready(duration)
    if self:get_fire_blast_charges() > 0 then
        return true
    end

    local charge_cd = core.spell_book.get_spell_charge_cooldown_duration(SPELL.FIRE_BLAST.id)
    local start_time = core.spell_book.get_spell_charge_cooldown_start_time(SPELL.FIRE_BLAST.id)

    if start_time == 0 then
        return false
    end

    local time_until_charge = (start_time + charge_cd - core.game_time()) / 1000
    return time_until_charge < duration
end

return Resources
