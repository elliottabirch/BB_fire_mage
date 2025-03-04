-----------------------------------
-- MODULE IMPORTS
-----------------------------------
---@type enums
local enums = require("common/enums")
---@type spell_queue
local spell_queue = require("common/modules/spell_queue")
---@type buff_manager
local buff_manager = require("common/modules/buff_manager")
---@type plugin_helper
local plugin_helper = require("common/utility/plugin_helper")
---@type control_panel_helper
local control_panel_helper = require("common/utility/control_panel_helper")

-- Local modules
local config = require("config")
local spell_data = require("spell_data")
local logger = require("logger")
local spellcasting = require("spellcasting")
local resources = require("resources")
local targeting = require("targeting")
local menu_elements = require("ui/menu_elements")
local ui_renderer = require("ui/rendering")
local spell_tracker = require("spell_tracker")

-- Patterns
local pattern_manager = require("patterns/pattern_manager")
local pyro_fb_pattern = require("patterns/pyro_fb_pattern")
local pyro_pf_pattern = require("patterns/pyro_pf_pattern")
local scorch_fb_pattern = require("patterns/scorch_fb_pattern")
local combustion_opener_pattern = require("patterns/combustion_opener_pattern")
local fireball_hotstreak_pattern = require("patterns/fireball_hotstreak_pattern")

-----------------------------------
-- PATTERN MANAGER INITIALIZATION
-----------------------------------
-- Register all patterns
pattern_manager:register_pattern("pyro_fb", pyro_fb_pattern)
pattern_manager:register_pattern("pyro_pf", pyro_pf_pattern)
pattern_manager:register_pattern("scorch_fb", scorch_fb_pattern)
pattern_manager:register_pattern("combustion_opener", combustion_opener_pattern)
pattern_manager:register_pattern("fireball_hotstreak", fireball_hotstreak_pattern)

-- Save the last combustion state for detecting state changes
local last_combustion_state = false
-----------------------------------
-- MAIN EXECUTION
-----------------------------------
local function on_update()
    -- Update logger level
    logger:set_level(menu_elements.log_level:get())

    -- Update control panel
    control_panel_helper:on_update(menu_elements)

    -- Check if player exists
    local player = core.object_manager.get_local_player()
    if not player then
        return
    end

    -- Check if script is enabled
    if not menu_elements.enable_script_check:get_state() or
        not plugin_helper:is_toggle_enabled(menu_elements.enable_toggle) then
        if pattern_manager:is_pattern_active() then
            pattern_manager:reset_pattern()
        end
        return
    end

    -- Check for spell interruptions
    local was_interrupted = spell_tracker:update(player)
    if was_interrupted and pattern_manager:is_pattern_active() then
        logger:log("RESETTING PATTERN: Spell was interrupted, resetting pattern", 2)

        pattern_manager:reset_pattern()
    end

    -- Don't cast during channeling
    local channel_end_time = player:get_active_channel_cast_end_time()
    if channel_end_time > 0.0 then
        logger:log("Skipping: Player is channeling", 3)
        return
    end

    -- Don't cast while mounted
    if player:is_mounted() then
        logger:log("Skipping: Player is mounted", 3)
        return
    end

    -- Don't cast during another cast (except specific casts we want to modify)
    local cast_end_time = player:get_active_spell_cast_end_time()
    local active_spell_id = player:get_active_spell_id()

    if cast_end_time > core.game_time() and active_spell_id == spell_data.SPELL.PYROBLAST.id then
        core.input.jump()
        return
    end

    -- Override target selector settings
    targeting:override_ts_settings(menu_elements.ts_custom_logic_override:get_state())

    -- Get target
    local target = targeting:get_best_target()
    if not target then
        logger:log("Skipping: No valid target found", 3)
        return
    end

    logger:log("Evaluating patterns with target: " .. target:get_name(), 3)
    local combustion_time = resources:get_combustion_remaining(player)
    local combustion_active = combustion_time > 0

    -- Check for combustion state change
    if last_combustion_state ~= combustion_active then
        pattern_manager:handle_combustion_state_change(player, last_combustion_state, combustion_active)
        last_combustion_state = combustion_active
    end

    -- Prepare context for pattern selection
    local context = {
        combustion_active = combustion_active,
        combustion_time = combustion_time,
        last_cast = spellcasting.last_cast,
        gcd = core.spell_book.get_global_cooldown(),
        is_casting = player:is_casting_spell(),
        active_spell_id = active_spell_id,
        cast_end_time = cast_end_time
    }

    -- Pattern management - first check if we have an active pattern
    if pattern_manager:is_pattern_active() then
        -- Execute existing pattern
        if pattern_manager:execute_active_pattern(player, target) then
            return -- Pattern is still executing
        end
        -- If we got here, the pattern has completed
    end

    -- No active pattern, try to select one
    if pattern_manager:select_pattern(player, context) then
        -- A new pattern was selected, start executing it
        if pattern_manager:execute_active_pattern(player, target) then
            return
        end
    end

    -- If we get here, no pattern is active or applicable
    -- Fall back to the default rotation logic

    if combustion_active then
        -- COMBUSTION FALLBACK ROTATION
        logger:log("Combustion fallback rotation", 2)

        local gcd = core.spell_book.get_global_cooldown()
        local is_casting = player:is_casting_spell()
        if not pattern_manager:is_pattern_active() and resources:has_hot_streak(player) and spellcasting:cast_spell(spell_data.SPELL.PYROBLAST, target, false, false) then
            logger:log("Consumed rogue hot streak with pyrroblast")
            return
        end

        if gcd == 0 and not is_casting then
            if not resources:has_hot_streak(player) then
                if spellcasting:cast_spell(spell_data.SPELL.FIRE_BLAST, target, false, false) then
                    logger:log("Fire Blast cast successful")
                    return
                elseif spellcasting:cast_spell(spell_data.SPELL.PHOENIX_FLAMES, target, false, false) then
                    logger:log("Phoenix Flames cast successful")
                    return
                else
                    spellcasting:cast_spell(spell_data.SPELL.SCORCH, target, false, false)
                end
            else
                spellcasting:cast_spell(spell_data.SPELL.PYROBLAST, target, false, false)
            end
        end
    else
        -- REGULAR ROTATION (NO COMBUSTION)
        logger:log("Standard rotation fallback", 3)

        if resources:has_hot_streak(player) or resources:has_hyperthermia(player) then
            if resources:has_hyperthermia(player) and resources:has_heating_up(player) and resources:get_fire_blast_charges() > 0 then
                spellcasting:cast_spell(spell_data.SPELL.FIRE_BLAST, target, false, false)
                return
            end
            logger:log("Standard rotation: Hot Streak or Hyperthermia detected, casting Pyroblast", 3)
            spellcasting:cast_spell(spell_data.SPELL.PYROBLAST, target, false, false)
            return
        end

        if not player:is_casting_spell() then
            if spellcasting.last_cast == spell_data.SPELL.FIREBALL.name and not resources:has_heating_up(player) and resources:get_phoenix_flames_charges() == 2 then
                logger:log("Standard rotation: using pf charge", 3)
                spellcasting:cast_spell(spell_data.SPELL.PHOENIX_FLAMES, target, false, false)
            else
                if player:is_moving() then
                    spellcasting:cast_spell(spell_data.SPELL.scorch, target, false, false)
                else
                    local scorch_target = targeting:get_scorch_target()
                    if scorch_target then
                        logger:log("Standard rotation: Casting Fireball", 3)
                        spellcasting:cast_spell(spell_data.SPELL.SCORCH, target, false, false)
                    end

                    -- Default to Fireball
                    logger:log("Standard rotation: Casting Fireball", 3)
                    spellcasting:cast_spell(spell_data.SPELL.FIREBALL, target, false, false)
                end
            end
        end
    end
end

-----------------------------------
-- SPELL CAST MONITORING
-----------------------------------
---@param spell_id number
local function on_spell_cast(data)
    local player = core.object_manager.get_local_player()
    if not player then
        return
    end

    if type(data) == "number" then
        logger.log(logger, "ACTUAL CAST DETECTED: " .. core.spell_book.get_spell_name(data.spell_id), 2)
        pattern_manager:handle_spell_cast(data)
        return
    end
    if data.caster == player then
        logger.log(logger, "ACTUAL CAST DETECTED: " .. core.spell_book.get_spell_name(data.spell_id), 2)
        pattern_manager:handle_spell_cast(data.spell_id)
    end
end

-----------------------------------
-- ON RENDER CALLBACK
-----------------------------------
local function on_render()
    local player = core.object_manager.get_local_player()
    if player then
        ui_renderer:render(player, pattern_manager:get_active_pattern_info())
    end
end

-----------------------------------
-- REGISTER CALLBACKS
-----------------------------------
core.register_on_update_callback(on_update)
core.register_on_render_callback(on_render)
core.register_on_render_menu_callback(ui_renderer.render_menu)
core.register_on_render_control_panel_callback(ui_renderer.render_control_panel)
core.register_on_spell_cast_callback(on_spell_cast)
