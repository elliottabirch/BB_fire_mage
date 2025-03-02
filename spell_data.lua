---@type enums
local enums = require("common/enums")

local SPELL = {
    FIREBALL = {
        id = 133,
        name = "Fireball",
        priority = 1,
        last_cast = 0,
        cast_delay = 0.20,
        is_off_gcd = false
    },
    FIRE_BLAST = {
        id = 108853,
        name = "Fire Blast",
        priority = 1,
        last_cast = 0,
        cast_delay = 0.10,
        is_off_gcd = true
    },
    PYROBLAST = {
        id = 11366,
        name = "Pyroblast",
        priority = 1,
        last_cast = 0,
        cast_delay = 0.20,
        is_off_gcd = false
    },
    PHOENIX_FLAMES = {
        id = 257541,
        name = "Phoenix Flames",
        priority = 1,
        last_cast = 0,
        cast_delay = 0.20,
        is_off_gcd = false
    },
    SCORCH = {
        id = 2948,
        name = "Scorch",
        priority = 1,
        last_cast = 0,
        cast_delay = 0.20,
        is_off_gcd = false
    },
    COMBUSTION = {
        id = 190319,
        name = "Combustion",
        priority = 1,
        last_cast = 0,
        cast_delay = 0.10,
        is_off_gcd = true
    }
}

local BUFF = {
    HOT_STREAK = enums.buff_db.HOT_STREAK,
    HEATING_UP = enums.buff_db.HEATING_UP,
    COMBUSTION = enums.buff_db.COMBUSTION,
    HYPERTHERMIA = enums.buff_db.HYPERTHERMIA
}

return {
    SPELL = SPELL,
    BUFF = BUFF
}
