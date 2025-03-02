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

-- Patterns
local pattern_manager = require("patterns/pattern_manager")
local pyro_fb_pattern = require("patterns/pyro_fb_pattern")
local pyro_pf_pattern = require("patterns/pyro_pf_pattern")
local scorch_fb_pattern = require("patterns/scorch_fb_pattern")
local combustion_opener_pattern = require("patterns/combustion_opener_pattern")
local fireball_hotstreak_pattern = require("patterns/fireball_hotstreak_pattern")

-----------------------------------
-- UTILITY FUNCTIONS
-----------------------------------
---@return boolean
local function isAnyPatternActive()
    return pyro_fb_pattern.active or
        pyro_pf_pattern.active or
        scorch_fb_pattern.active or
        combustion_opener_pattern.active or
        fireball_hotstreak_pattern.active
end

---@return boolean
local function isAnyCombustionPatternActive()
    return pyro_fb_pattern.active or
        pyro_pf_pattern.active or
        scorch_fb_pattern.active
end

---@return string
local function getActivePatternInfo()
    if pyro_fb_pattern.active then
        return "Pyro->FB: " .. pyro_fb_pattern.state
    elseif pyro_pf_pattern.active then
        return "Pyro->PF: " .. pyro_pf_pattern.state
    elseif scorch_fb_pattern.active then
        return "Scorch+FB: " .. scorch_fb_pattern.state
    elseif combustion_opener_pattern.active then
        return "Combustion: " .. combustion_opener_pattern.state
    elseif fireball_hotstreak_pattern.active then
        return "FB-HS: " .. fireball_hotstreak_pattern.state
    else
        return "None"
    end
end




-- Register all patterns
pattern_manager:register_pattern("pyro_fb", pyro_fb_pattern)
pattern_manager:register_pattern("pyro_pf", pyro_pf_pattern)
pattern_manager:register_pattern("scorch_fb", scorch_fb_pattern)
pattern_manager:register_pattern("combustion_opener", combustion_opener_pattern)
pattern_manager:register_pattern("fireball_hotstreak", fireball_hotstreak_pattern)

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
        return
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

    -- Don't cast during another cast
    local cast_end_time = player:get_active_spell_cast_end_time()
    local active_spell_id = player:get_active_spell_id()

    if cast_end_time > core.game_time() and active_spell_id == spell_data.SPELL.SCORCH.id then
        logger:log("Skipping: Player is casting (time remaining: " ..
            ((cast_end_time - core.game_time()) / 1000) .. "s)", 3)
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

    -- Collect pattern active states for should_start checks
    local patterns_active = {
        pyro_fb = pyro_fb_pattern.active,
        pyro_pf = pyro_pf_pattern.active,
        scorch_fb = scorch_fb_pattern.active,
        combustion_opener = combustion_opener_pattern.active,
        fireball_hotstreak = fireball_hotstreak_pattern.active
    }

    -- COMBUSTION ACTIVE ROTATION
    if combustion_time > 0 then
        logger:log("Combustion is active (" .. string.format("%.2f", combustion_time / 1000) .. "s remaining)", 2)

        -- Check if we need to start a pattern
        if not isAnyPatternActive() then
            logger:log("No pattern active, checking for pattern to start", 3)

            -- Try to start patterns in priority order
            if combustion_opener_pattern:should_start(player, patterns_active) then
                combustion_opener_pattern:start()
            elseif pyro_fb_pattern:should_start(player) then
                pyro_fb_pattern:start()
            elseif pyro_pf_pattern:should_start(player, pyro_fb_pattern.active) then
                pyro_pf_pattern:start()
            elseif scorch_fb_pattern:should_start(player, patterns_active) then
                scorch_fb_pattern:start()
            end
        end

        -- Execute patterns if active
        if combustion_opener_pattern.active and combustion_opener_pattern:execute(player, target) then
            return
        end

        if pyro_fb_pattern.active and pyro_fb_pattern:execute(player, target) then
            return
        end

        if pyro_pf_pattern.active and pyro_pf_pattern:execute(player, target) then
            return
        end

        if scorch_fb_pattern.active and scorch_fb_pattern:execute(player, target) then
            return
        end

        local gcd = core.spell_book.get_global_cooldown()
        local is_casting = player:is_casting_spell()

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
        logger:log("Combustion not active, using standard rotation", 3)

        if combustion_opener_pattern.has_activated_this_combustion then
            combustion_opener_pattern:reset_combustion_flag()
        end

        if isAnyCombustionPatternActive() then
            pyro_fb_pattern:reset()
            pyro_pf_pattern:reset()
            scorch_fb_pattern:reset()
        end

        if not isAnyPatternActive() then
            logger:log("No pattern active in non-combustion rota, checking for pattern to start", 3)
            if combustion_opener_pattern:should_start(player, patterns_active) then
                combustion_opener_pattern:start()
            end
            if fireball_hotstreak_pattern:should_start(player, patterns_active) then
                fireball_hotstreak_pattern:start()
            end
        else
            logger:log("Pattern already active in non-combustion rota", 3)
        end

        -- Execute patterns if active
        if combustion_opener_pattern.active and combustion_opener_pattern:execute(player, target) then
            return
        end

        if fireball_hotstreak_pattern.active and fireball_hotstreak_pattern:execute(player, target) then
            return
        end

        if resources:has_hot_streak(player) or resources:has_hyperthermia(player) then
            logger:log("Standard rotation: Hot Streak or Hyperthermia detected, casting Pyroblast", 3)
            spellcasting:cast_spell(spell_data.SPELL.PYROBLAST, target, false, false)
            return
        end

        if not player:is_casting_spell() then
            if not resources:has_heating_up(player) and resources:get_phoenix_flames_charges() == 2 then
                logger:log("Standard rotation: using pf charge", 3)
                spellcasting:cast_spell(spell_data.SPELL.PHOENIX_FLAMES, target, false, false)
            else
                -- Default to Fireball
                logger:log("Standard rotation: Casting Fireball", 3)
                spellcasting:cast_spell(spell_data.SPELL.FIREBALL, target, false, false)
            end
        end
    end
end

-----------------------------------
-- SPELL CAST MONITORING
-----------------------------------
---@param spell_id number
local function on_spell_cast(spell_id)
    local player = core.object_manager.get_local_player()
    if not player then
        return
    end

    -- Check if spell is Pyroblast
    if spell_id == spell_data.SPELL.PYROBLAST.id then
        logger:log("Pyroblast was cast - Resetting all active patterns", 2)

        -- Reset all patterns
        if pyro_fb_pattern.active then
            logger:log("Resetting Pyro->FB pattern due to manual Pyroblast cast", 2)
            pyro_fb_pattern:reset()
        end

        if pyro_pf_pattern.active then
            logger:log("Resetting Pyro->PF pattern due to manual Pyroblast cast", 2)
            pyro_pf_pattern:reset()
        end

        if scorch_fb_pattern.active then
            logger:log("Resetting Scorch+FB pattern due to manual Pyroblast cast", 2)
            scorch_fb_pattern:reset()
        end

        if combustion_opener_pattern.active then
            logger:log("Resetting Combustion Opener pattern due to manual Pyroblast cast", 2)
            combustion_opener_pattern:reset()
        end

        if fireball_hotstreak_pattern.active then
            logger:log("Resetting Fireball->HotStreak pattern due to manual Pyroblast cast", 2)
            fireball_hotstreak_pattern:reset()
        end

        spellcasting:set_last_cast(spell_data.SPELL.PYROBLAST)
    end
end

-----------------------------------
-- ON RENDER CALLBACK
-----------------------------------
local function on_render()
    local player = core.object_manager.get_local_player()
    if player then
        ui_renderer:render(player, getActivePatternInfo())
    end
end

-----------------------------------
-- REGISTER CALLBACKS
-----------------------------------
core.register_on_update_callback(on_update)
core.register_on_render_callback(on_render)
core.register_on_render_menu_callback(ui_renderer.render_menu)
core.register_on_render_control_panel_callback(ui_renderer.render_control_panel)
core.register_on_legit_spell_cast_callback(on_spell_cast)
