---@class Targeting
local Targeting = {
    is_ts_overriden = false
}

local target_selector = require("common/modules/target_selector")
local unit_helper = require("common/utility/unit_helper")
local pvp_helper = require("common/utility/pvp_helper")
local logger = require("logger")

---@param ts_override_enabled boolean
function Targeting:override_ts_settings(ts_override_enabled)
    if self.is_ts_overriden then
        return
    end

    if not ts_override_enabled then
        logger:log("Target selector override skipped: Override not enabled in menu", 3)
        return
    end

    logger:log("Target selector settings overriding...", 2)
    target_selector.menu_elements.settings.max_range_damage:set(40)
    target_selector.menu_elements.damage.weight_multiple_hits:set(true)
    target_selector.menu_elements.damage.slider_weight_multiple_hits:set(4)
    target_selector.menu_elements.damage.slider_weight_multiple_hits_radius:set(8)

    self.is_ts_overriden = true
    logger:log("Target selector settings successfully overridden", 2)
end

---@return game_object|nil
function Targeting:get_best_target()
    local targets_list = target_selector:get_targets()

    for i, target in ipairs(targets_list) do
        if unit_helper:is_in_combat(target) and
            not pvp_helper:is_damage_immune(target, pvp_helper.damage_type_flags.MAGICAL) then
            logger:log("Target selected: #" .. i .. " from target selector list", 3)
            return target
        end
    end

    logger:log("No valid targets found", 3)
    return nil
end

return Targeting
