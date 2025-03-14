---@class Targeting
local Targeting = {
    is_ts_overriden = false
}

local target_selector = require("common/modules/target_selector")
---@type unit_helper
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
function Targeting:get_scorch_target()
    local targets_list = target_selector:get_targets()
    local player = core.object_manager.get_local_player()

    -- Check if player exists
    if not player then
        logger:log("No player found for scorch target", 3)
        return nil
    end

    -- Early exit if no targets
    if #targets_list == 0 then
        logger:log("No targets in list for scorch check", 3)
        return nil
    end

    local scorch_cast_time = core.spell_book.get_spell_cast_time(spell_data.SPELL.SCORCH.id)
    local low_health_target = nil

    -- Import required modules
    ---@type combat_forecast
    local combat_forecast = require("common/modules/combat_forecast")

    -- Find the lowest health target below 30% that will live long enough for a Scorch cast
    for _, target in ipairs(targets_list) do
        -- Skip magic immune targets
        if not pvp_helper:is_damage_immune(target, pvp_helper.damage_type_flags.MAGICAL) then
            local target_health_pct = target:get_health() / target:get_max_health()

            -- Check for targets below 30% health with sufficient remaining time
            if target_health_pct < 0.3 then
                local forecast_time = combat_forecast:get_forecast_single(target)
                if forecast_time > scorch_cast_time then
                    -- If we haven't found a target yet, or this one has lower health percentage
                    if not low_health_target or target_health_pct < (low_health_target:get_health() / low_health_target:get_max_health()) then
                        low_health_target = target
                        logger:log("Found potential scorch target with " .. (target_health_pct * 100) .. "% health", 3)
                    end
                end
            end
        end
    end

    if low_health_target then
        return low_health_target
    end

    logger:log("No valid scorch targets found", 3)
    return nil
end

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

    local most_clustered_target = nil
    local most_clustered_count = 0
    local player_target = player:get_target()
    if unit_helper:is_valid_enemy(player_target) then
        return player_target
    end

    -- Process each potential target
    for i, target in ipairs(targets_list) do
        -- Skip magic immune targets
        if not pvp_helper:is_damage_immune(target, pvp_helper.damage_type_flags.MAGICAL) then
            local target_health = target:get_health()

            -- Track highest health target (for combustion phase)
            if target_health > highest_health_value then
                highest_health_target = target
                highest_health_value = target_health
            end

            -- Count nearby enemies for clustering check
            local nearby_count = unit_helper:get_enemy_list_around(target:get_position(), 8, false, true, false, false) -- 8 yards clustering radius

            -- Track most clustered target
            if #nearby_count > most_clustered_count then
                most_clustered_target = target
                most_clustered_count = #nearby_count
            end
        end
    end


    -- Decision logic
    if combustion_is_up and highest_health_target then
        logger:log("Combustion active: selecting highest health target", 2)
        return highest_health_target
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

---@return game_object|nil
function Targeting:get_fireblast_target()
    return self:get_best_target()
end

return Targeting
