---@class Targeting
local Targeting = {
    is_ts_overriden = false
}

local target_selector = require("common/modules/target_selector")
local unit_helper = require("common/utility/unit_helper")
local pvp_helper = require("common/utility/pvp_helper")
local logger = require("logger")
local resources = require("resources")
local spell_data = require("spell_data")

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
---@return game_object|nil
function Targeting:get_best_target()
    local targets_list = target_selector:get_targets()
    local player = core.object_manager.get_local_player()

    -- Check if player exists
    if not player then
        logger:log("No player found", 3)
        return nil
    end

    -- Early exit if no targets
    if #targets_list == 0 then
        logger:log("No targets in list", 3)
        return nil
    end

    -- Get combustion status
    local combustion_is_up = resources:get_combustion_remaining(player) > 0

    -- Variables for target selection
    local highest_health_target = nil
    local highest_health_value = 0

    local low_health_target = nil
    local scorch_cast_time = core.spell_book.get_spell_cast_time(spell_data.SPELL.SCORCH.id)

    local most_clustered_target = nil
    local most_clustered_count = 0

    -- Import required modules
    ---@type combat_forecast
    local combat_forecast = require("common/modules/combat_forecast")

    -- Process each potential target
    for i, target in ipairs(targets_list) do
        -- Skip magic immune targets
        if not pvp_helper:is_damage_immune(target, pvp_helper.damage_type_flags.MAGICAL) then
            local target_health = target:get_health()
            local target_max_health = target:get_max_health()
            local target_health_pct = target_health / target_max_health

            -- Track highest health target (for combustion phase)
            if target_health > highest_health_value then
                highest_health_target = target
                highest_health_value = target_health
            end

            -- Check for low health targets with sufficient remaining time
            if target_health_pct < 0.3 then
                local forecast_time = combat_forecast:get_forecast_single(target)
                if forecast_time > scorch_cast_time and (not low_health_target or target_health_pct < (low_health_target:get_health() / low_health_target:get_max_health())) then
                    low_health_target = target
                end
            end

            -- Count nearby enemies for clustering check
            local nearby_count = self:count_nearby_enemies(target, targets_list, 8) -- 8 yards clustering radius

            -- Track most clustered target
            if nearby_count > most_clustered_count then
                most_clustered_target = target
                most_clustered_count = nearby_count
            end
        end
    end

    -- Decision logic
    if combustion_is_up and highest_health_target then
        logger:log("Combustion active: selecting highest health target", 2)
        return highest_health_target
    elseif low_health_target then
        logger:log("Low health target found with sufficient time to kill", 2)
        return low_health_target
    elseif most_clustered_count > 1 and most_clustered_target then
        logger:log("Selected target with " .. most_clustered_count .. " nearby enemies", 2)
        return most_clustered_target
    elseif highest_health_target then
        -- Fallback to highest health if no better option found
        logger:log("Fallback to highest health target", 3)
        return highest_health_target
    end

    logger:log("No valid targets found", 3)
    return nil
end

-- Helper method to count nearby enemies
---@param target game_object The central target
---@param targets_list table<game_object> List of all potential targets
---@param radius number Detection radius in yards
---@return number Count of enemies within radius
function Targeting:count_nearby_enemies(target, targets_list, radius)
    local count = 0
    local target_pos = target:get_position()

    for _, other in ipairs(targets_list) do
        if other ~= target and not pvp_helper:is_damage_immune(other, pvp_helper.damage_type_flags.MAGICAL) then
            local other_pos = other:get_position()
            local squared_dist = target_pos:squared_dist_to(other_pos)
            local squared_radius = radius * radius

            if squared_dist <= squared_radius then
                count = count + 1
            end
        end
    end

    return count
end

return Targeting
