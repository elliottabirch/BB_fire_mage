---@class Spellcasting
---@field last_cast string|nil
---@field last_cast_time number
local Spellcasting = {
    last_cast = nil,
    last_cast_time = 0
}

local spell_helper = require("common/utility/spell_helper")
local spell_queue = require("common/modules/spell_queue")
local logger = require("logger")

---@param spell table
function Spellcasting:set_last_cast(spell)
    local current_time = core.time()
    spell.last_cast = current_time
    self.last_cast = spell.name
    self.last_cast_time = current_time
    logger:log("LAST SPELL CAST SET TO: " .. spell.name, 1)
end

---@param spell table
---@param target game_object
---@param skip_facing boolean
---@param skip_range boolean
---@return boolean
function Spellcasting:cast_spell(spell, target, skip_facing, skip_range)
    local current_time = core.time()
    local local_player = core.object_manager.get_local_player()

    -- Check if spell is castable
    local is_spell_castable = spell_helper:is_spell_castable(
        spell.id, local_player, target, skip_facing, skip_range
    )
    if not is_spell_castable then
        logger:log("Cast rejected: " .. spell.name .. " (Not castable)", 2)
        return false
    end

    -- Check rate limiting to prevent spam
    if current_time - spell.last_attempt < spell.cast_delay then
        logger:log("Cast rejected: " .. spell.name .. " (Rate limited)", 3)
        return false
    end

    -- Queue the spell based on whether it's off the GCD or not
    if spell.is_off_gcd then
        spell_queue:queue_spell_target_fast(
            spell.id, target, spell.priority, "Casting " .. spell.name
        )
        spell.last_attempt = current_time
    else
        spell_queue:queue_spell_target(
            spell.id, target, spell.priority, "Casting " .. spell.name
        )
        spell.last_attempt = current_time
    end
    return true
end

return Spellcasting
