-----------------------------------
-- MODULE IMPORTS
-----------------------------------
---@type enums
local enums = require("common/enums")
---@type spell_queue
local spell_queue = require("common/modules/spell_queue")
---@type buff_manager
local buff_manager = require("common/modules/buff_manager")
---@type combat_forecast
local combat_forecast = require("common/modules/combat_forecast")
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
---@type PatternManager
local pattern_manager = require("patterns/pattern_manager")
local pyro_fb_pattern = require("patterns/pyro_fb_pattern")
local pyro_pf_pattern = require("patterns/pyro_pf_pattern")
local scorch_fb_pattern = require("patterns/scorch_fb_pattern")
local scorch_fb_double_pyro_pattern = require("patterns/scorch_fb_double_pyro_pattern")
local combustion_opener_pattern = require("patterns/combustion_opener_pattern")
local fireball_hotstreak_pattern = require("patterns/fireball_hotstreak_pattern")
local scorch_pattern = require("patterns/scorch_pattern")
local random_comustion_opener_pattern = require("patterns/random_comustion_opener_pattern")

-----------------------------------
-- PATTERN MANAGER INITIALIZATION
-----------------------------------
-- Register all patterns
pattern_manager:register_pattern("pyro_fb", pyro_fb_pattern)
pattern_manager:register_pattern("pyro_pf", pyro_pf_pattern)
pattern_manager:register_pattern("scorch_fb", scorch_fb_pattern)
pattern_manager:register_pattern("combustion_opener", combustion_opener_pattern)
pattern_manager:register_pattern("fireball_hotstreak", fireball_hotstreak_pattern)
pattern_manager:register_pattern("scorch_pattern", scorch_pattern)
pattern_manager:register_pattern("scorch_fb_double_pyro_pattern", scorch_fb_double_pyro_pattern)
pattern_manager:register_pattern("random_combustion_opener", random_comustion_opener_pattern)

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

    -- Don't cast during another cast (except specific casts we want to modify)
    local cast_end_time = player:get_active_spell_cast_end_time()
    local active_spell_id = player:get_active_spell_id()

    if cast_end_time > core.game_time() and active_spell_id == spell_data.SPELL.PYROBLAST.id then
        logger:log("casting pyroblast, and attempting to stop")
        core.input.move_backward_start()
        core.input.move_backward_stop()

        return
    end

    -- Override target selector settings
    targeting:override_ts_settings(menu_elements.ts_custom_logic_override:get_state())

    -- Get target
    local target = targeting:get_best_target()
    local scorch_target = targeting:get_scorch_target()
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
    local time_since_combustion = core.time() - spell_data.SPELL.COMBUSTION.last_attempt
    local is_random_combustion = time_since_combustion > 12
    -- Prepare context for pattern selection
    local context = {
        combustion_active = combustion_active,
        combustion_time = combustion_time,
        last_cast = spellcasting.last_cast,
        gcd = core.spell_book.get_global_cooldown(),
        is_casting = player:is_casting_spell(),
        active_spell_id = active_spell_id,
        cast_end_time = cast_end_time,
        is_random_combustion = is_random_combustion,
    }

    local gcd = core.spell_book.get_global_cooldown() * 1000
    local cast_remains = player:get_active_spell_cast_end_time() - core.time() * 1000


    local action_remains = math.max(gcd, cast_remains)

    if buff_manager:get_buff_data(player, spell_data.BUFF.GLORIOUS_INCANDESCENSE).is_active and buff_manager:get_buff_data(player, spell_data.BUFF.GLORIOUS_INCANDESCENSE).remaining < 500 then
        logger:log("Glorios Incandescence is up, using fire blast")
        spellcasting:cast_spell(spell_data.SPELL.FIRE_BLAST, target, false, false)
    end



    if is_random_combustion and combustion_active and pattern_manager.active_pattern ~= nil then
        local is_filler_pattern = pattern_manager.active_pattern.name == "fireball_hotstreak" or
            pattern_manager.active_pattern.name == "scorch_pattern"
        if is_filler_pattern then
            pattern_manager:reset_pattern()
        end
    end


    local index_one_name = spellcasting.recent_casts and spellcasting.recent_casts[1] and
        spellcasting.recent_casts[1].name ~= nil and spellcasting.recent_casts[1].name
    local index_three_name = spellcasting.recent_casts and spellcasting.recent_casts[3] and
        spellcasting.recent_casts[3].name ~= nil and
        spellcasting.recent_casts[3].name

    if combustion_time > 3 and not is_random_combustion and index_one_name ~= nil and index_one_name == spell_data.SPELL.FIRE_BLAST.name and index_three_name ~= nil and index_three_name == spell_data.SPELL.FIRE_BLAST.name then
        core.input.use_item(168989)
    end


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




    -- REGULAR ROTATION (NO COMBUSTION)
    logger:log("Standard rotation fallback", 3)
    local combat_too_short = combat_forecast:get_forecast() > 0
    if resources:has_hot_streak(player) or resources:has_hyperthermia(player) then
        if resources:has_hyperthermia(player) and resources:has_heating_up(player) and resources:get_fire_blast_charges() > 0 then
            spellcasting:cast_spell(spell_data.SPELL.FIRE_BLAST, target, false, false)
            return
        end
        logger:log("Standard rotation: Hot Streak or Hyperthermia detected, casting Pyroblast", 3)
        spellcasting:cast_spell(spell_data.SPELL.PYROBLAST, target, false, false)
        return
    end
    -- TODO: implement resource spending at end of fight
    -- if combat_too_short then
    --     logger:log("Standard rotation: combat too short. using resources", 3)
    --     if not resources:has_hot_streak(player) then
    --         logger:log("Standard rotation: combat too short. doesnt have hot streak", 3)
    --         if player:is_casting_spell() or core.spell_book.get_global_cooldown() > 0 and spellcasting.last_cast ~= spell_data.SPELL.PHOENIX_FLAMES.name then
    --             logger:log("Standard rotation: combat too short. getting hot streak with FB", 3)
    --             spellcasting:cast_spell(spell_data.SPELL.FIRE_BLAST, target, false, false)
    --         else
    --             logger:log("Standard rotation: combat too short. getting hot streak with PF", 3)
    --             spellcasting:cast_spell(spell_data.SPELL.PHOENIX_FLAMES, target, false, false)
    --         end
    --     end
    -- end

    if not player:is_casting_spell() then
        -- Check if we have Heating Up
        local pf_charges = resources:get_phoenix_flames_charges()
        local pf_ready_in = resources:next_phoenix_flames_charge_ready_in()

        local cooking_pf_charge = pf_ready_in < 500 and 1 or
            0

        -- Check if we have Heating Up
        local fb_charges = resources:get_fire_blast_charges()
        local fire_blast_ready_in = resources:next_fire_blast_charge_ready_in()

        local cooking_fb_charge = fire_blast_ready_in < 750 and 1 or
            0

        local has_max_pf_charges = ((pf_charges + cooking_pf_charge) >= 2 or buff_manager:get_buff_data(player, spell_data.BUFF.BORN_OF_FLAME).is_active)
        logger:log("---> pf charges" .. pf_charges, 2)
        logger:log("---> cooking pf charges" .. cooking_pf_charge, 2)
        logger:log("---> pf ready in" .. pf_ready_in, 2)
        logger:log("---> fb ready in " .. fire_blast_ready_in, 2)
        logger:log(
            "---> born of flame is active" ..
            tostring(buff_manager:get_buff_data(player, spell_data.BUFF.BORN_OF_FLAME)
                .is_active), 2)
        logger:log("---> has max pf charges " .. tostring(has_max_pf_charges))
        if fb_charges + cooking_fb_charge >= 1 and spellcasting.last_cast == spell_data.SPELL.FIREBALL.name and has_max_pf_charges and not resources:has_heating_up(player) then
            logger:log("Standard rotation: using pf charge", 2)

            spellcasting:cast_spell(spell_data.SPELL.PHOENIX_FLAMES, target, false, false)
        else
            if scorch_target then
                logger:log("Standard rotation: Casting Fireball", 2)
                spellcasting:cast_spell(spell_data.SPELL.SCORCH, scorch_target, false, false)
            else
                if player:is_moving() then
                    logger:log("Standard rotation: moving, so casting scorch", 2)
                    spellcasting:cast_spell(spell_data.SPELL.SCORCH, target, false, false)
                else
                    -- Default to Fireball
                    logger:log("Standard rotation: Casting Fireball", 2)
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
