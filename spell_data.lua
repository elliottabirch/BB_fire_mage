---@type enums
local enums = require("common/enums")

local SPELL = {
    FIREBALL = {
        id = 133,
        name = "Fireball",
        priority = 1,
        last_cast = 0,
        last_attempt = 0,
        cast_delay = 0.10,
        is_off_gcd = false
    },
    FIRE_BLAST = {
        id = 108853,
        name = "Fire Blast",
        priority = 1,
        last_cast = 0,
        last_attempt = 0,
        cast_delay = 0.30,
        is_off_gcd = true
    },
    PYROBLAST = {
        id = 11366,
        name = "Pyroblast",
        priority = 1,
        last_cast = 0,
        last_attempt = 0,
        cast_delay = 0.10,
        is_off_gcd = false
    },
    PHOENIX_FLAMES = {
        id = 257541,
        name = "Phoenix Flames",
        priority = 1,
        last_cast = 0,
        last_attempt = 0,
        cast_delay = 0.10,
        is_off_gcd = false
    },
    SCORCH = {
        id = 2948,
        name = "Scorch",
        priority = 1,
        last_cast = 0,
        last_attempt = 0,
        cast_delay = 0.10,
        is_off_gcd = false
    },
    COMBUSTION = {
        id = 190319,
        name = "Combustion",
        priority = 1,
        last_cast = 0,
        last_attempt = 0,
        cast_delay = 0.10,
        is_off_gcd = true
    },


}

local CUSTOM_BUFF_DATA = {
    HOT_STREAK = {
        id = 48108,
        name = "Hot Streak!",
        last_cast = 0,
        last_attempt = 0,
    }
}

local BUFF = {
    HOT_STREAK = enums.buff_db.HOT_STREAK,
    HEATING_UP = enums.buff_db.HEATING_UP,
    COMBUSTION = enums.buff_db.COMBUSTION,
    HYPERTHERMIA = enums.buff_db.HYPERTHERMIA,
    GLORIOUS_INCANDESCENSE = enums.buff_db.GLORIOUS_INCANDESCENSE,
    BORN_OF_FLAME = { 1219307 }
}

-- Create a map of spell IDs to spell objects
local SPELL_BY_ID = {}
for key, spell in pairs(SPELL) do
    SPELL_BY_ID[spell.id] = spell
end

local BUFF_BY_ID = {}
for key, buff in pairs(CUSTOM_BUFF_DATA) do
    BUFF_BY_ID[buff.id] = buff
end

return {
    SPELL = SPELL,
    BUFF = BUFF,
    SPELL_BY_ID = SPELL_BY_ID,
    CUSTOM_BUFF_DATA = CUSTOM_BUFF_DATA,
    BUFF_BY_ID = BUFF_BY_ID
}
