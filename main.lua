-- Fire Mage Script - Enhanced with Comprehensive Pattern-Based Logic
-- Focuses on optimal Fire Blast usage and pattern-based spell casting during Combustion

-----------------------------------
-- MODULE IMPORTS
-----------------------------------
---@type enums
local enums = require("common/enums")
---@type pvp_helper
local pvp_helper = require("common/utility/pvp_helper")
---@type spell_queue
local spell_queue = require("common/modules/spell_queue")
---@type unit_helper
local unit_helper = require("common/utility/unit_helper")
---@type spell_helper
local spell_helper = require("common/utility/spell_helper")
---@type buff_manager
local buff_manager = require("common/modules/buff_manager")
---@type plugin_helper
local plugin_helper = require("common/utility/plugin_helper")
---@type target_selector
local target_selector = require("common/modules/target_selector")
---@type key_helper
local key_helper = require("common/utility/key_helper")
---@type control_panel_helper
local control_panel_helper = require("common/utility/control_panel_helper")

local reset_time = .75
local combust_precast_time = 500
-----------------------------------
-- SPELL DATA DEFINITIONS
-----------------------------------
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

-----------------------------------
-- BUFF DATA DEFINITIONS
-----------------------------------
local BUFF = {
    HOT_STREAK = enums.buff_db.HOT_STREAK,
    HEATING_UP = enums.buff_db.HEATING_UP,
    COMBUSTION = enums.buff_db.COMBUSTION,
    HYPERTHERMIA = enums.buff_db.HYPERTHERMIA
}

-----------------------------------
-- UI ELEMENTS
-----------------------------------
local menu_elements = {
    main_tree = core.menu.tree_node(),
    keybinds_tree_node = core.menu.tree_node(),
    enable_script_check = core.menu.checkbox(false, "enable_script_check"),
    enable_toggle = core.menu.keybind(999, false, "toggle_script_check"),
    draw_plugin_state = core.menu.checkbox(true, "draw_plugin_state"),
    ts_custom_logic_override = core.menu.checkbox(true, "override_ts_logic"),
    debug_info = core.menu.checkbox(true, "debug_info"),
    log_level = core.menu.slider_int(1, 3, 2, "log_level") -- 1=minimal, 2=normal, 3=verbose
}

-----------------------------------
-- LOGGING SYSTEM
-----------------------------------
local logger = {
    logs = {},
    max_logs = 10,
    level = 2 -- Default: normal logging
}

function logger.log(message, level)
    level = level or 2 -- Default level: normal

    if level <= logger.level then
        table.insert(logger.logs, 1, message)
        if #logger.logs > logger.max_logs then
            table.remove(logger.logs, logger.max_logs + 1)
        end
        core.log(message)

        core.log_file(message)
    end

    return message
end

function logger.update_level()
    logger.level = menu_elements.log_level:get()
end

-----------------------------------
-- SPELL CASTING SYSTEM
-----------------------------------
local spellcasting = {
    last_cast = nil,
    last_cast_time = 0
}

local function setLastCast(spell)
    local current_time = core.time()
    spell.last_cast = current_time
    spellcasting.last_cast = spell.name
    spellcasting.last_cast_time = current_time
    logger.log("CAST SUCCESS: " .. spell.name, 1)
end

function spellcasting.cast_spell(spell, target, skip_facing, skip_range)
    local current_time = core.time()
    -- Check if spell is castable
    local is_spell_castable = spell_helper:is_spell_castable(spell.id, core.object_manager.get_local_player(),
        target, skip_facing, skip_range)
    if not is_spell_castable then
        logger.log("Cast rejected: " .. spell.name .. " (Not castable)", 2)
        return false
    end
    -- Check rate limiting to prevent spam
    if current_time - spell.last_cast < spell.cast_delay then
        logger.log("Cast rejected: " .. spell.name .. " (Rate limited)", 3)
        return false
    end



    -- Queue the spell based on whether it's off the GCD or not
    if spell.is_off_gcd then
        spell_queue:queue_spell_target_fast(spell.id, target, spell.priority,
            "Casting " .. spell.name)
    else
        spell_queue:queue_spell_target(spell.id, target, spell.priority,
            "Casting " .. spell.name)
    end

    setLastCast(spell)
    return true
end

-----------------------------------
-- RESOURCE TRACKING
-----------------------------------
local resources = {}

function resources.get_fire_blast_charges()
    return core.spell_book.get_spell_charge(SPELL.FIRE_BLAST.id)
end

function resources.fire_blast_ready_in(seconds)
    local charge_cd = core.spell_book.get_spell_charge_cooldown_duration(SPELL.FIRE_BLAST.id)
    local start_time = core.spell_book.get_spell_charge_cooldown_start_time(SPELL.FIRE_BLAST.id)

    if start_time == 0 or resources.get_fire_blast_charges() > 0 then
        return 0
    end

    local remaining = math.max(0, (start_time + charge_cd - core.game_time()) / 1000)
    logger.log("Remaining time for Fire Blast to be ready: " .. remaining)

    return remaining <= seconds and remaining or 999
end

function resources.has_hot_streak(player)
    local hot_streak_data = buff_manager:get_buff_data(player, BUFF.HOT_STREAK)
    return hot_streak_data.is_active
end

function resources.has_heating_up(player)
    local heating_up_data = buff_manager:get_buff_data(player, BUFF.HEATING_UP)
    return heating_up_data.is_active
end

function resources.has_hyperthermia(player)
    local heating_up_data = buff_manager:get_buff_data(player, BUFF.HYPERTHERMIA)
    return heating_up_data.is_active
end

function resources.get_phoenix_flames_charges()
    return core.spell_book.get_spell_charge(SPELL.PHOENIX_FLAMES.id)
end

function resources.phoenix_flames_ready_in(seconds)
    local charge_cd = core.spell_book.get_spell_charge_cooldown_duration(SPELL.PHOENIX_FLAMES.id)
    local start_time = core.spell_book.get_spell_charge_cooldown_start_time(SPELL.PHOENIX_FLAMES.id)

    if start_time == 0 or resources.get_phoenix_flames_charges() > 0 then
        return 0
    end

    local remaining = math.max(0, (start_time + charge_cd - core.game_time()) / 1000)
    return remaining <= seconds and remaining or 999
end

function resources.get_combustion_remaining(player)
    local combustion_data = buff_manager:get_buff_data(player, BUFF.COMBUSTION)
    return combustion_data.is_active and combustion_data.remaining or 0
end

function resources.fire_blast_will_be_ready(duration)
    if resources.get_fire_blast_charges() > 0 then
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

-----------------------------------
-- PYROBLAST-FIREBLAST PATTERN
-----------------------------------
local pyro_fb_pattern = {
    active = false,
    state = "NONE", -- NONE, WAITING_FOR_GCD, FIRE_BLAST_CAST, PYROBLAST_CAST
    start_time = 0
}

function pyro_fb_pattern.should_start(player)
    logger.log("Evaluating Pyro->FB pattern conditions:", 3)

    -- Check if we just cast Pyroblast
    if spellcasting.last_cast ~= SPELL.PYROBLAST.name then
        logger.log(
            "Pyro->FB pattern REJECTED: Last cast was not Pyroblast (was " .. (spellcasting.last_cast or "nil") .. ")", 2)
        return false
    end
    logger.log("Pyro->FB pattern check: Last cast WAS Pyroblast ✓", 3)

    -- Check if GCD is active
    local gcd = core.spell_book.get_global_cooldown()
    if gcd <= 0 then
        logger.log("Pyro->FB pattern REJECTED: Global cooldown not active (GCD: " .. gcd .. ")", 2)
        return false
    end
    logger.log("Pyro->FB pattern check: GCD is active (" .. string.format("%.2f", gcd) .. "s) ✓", 3)

    -- Check if we have Fire Blast charge or will have one soon
    if resources.get_fire_blast_charges() > 0 then
        logger.log("Pyro->FB pattern ACCEPTED: Have Fire Blast charges (" .. resources.get_fire_blast_charges() .. ")", 2)
        return true
    end

    -- Check if a charge will be ready by end of GCD
    local fb_ready_time = resources.fire_blast_ready_in(gcd - 0.5)
    if fb_ready_time < gcd then
        logger.log(
            "Pyro->FB pattern ACCEPTED: Fire Blast will be ready in " ..
            string.format("%.2f", fb_ready_time) .. "s (before GCD ends)", 2)
        return true
    end

    logger.log("Pyro->FB pattern REJECTED: No Fire Blast charges and none will be ready soon", 2)
    return false
end

function pyro_fb_pattern.start()
    pyro_fb_pattern.active = true
    pyro_fb_pattern.state = "WAITING_FOR_GCD"
    pyro_fb_pattern.start_time = core.time()
    logger.log("Pyro->FB pattern STARTED - State: WAITING_FOR_GCD", 1)
end

function pyro_fb_pattern.reset()
    local prev_state = pyro_fb_pattern.state
    pyro_fb_pattern.active = false
    pyro_fb_pattern.state = "NONE"
    pyro_fb_pattern.start_time = 0
    logger.log("Pyro->FB pattern RESET (from " .. prev_state .. " state)", 1)
end

function pyro_fb_pattern.execute(player, target)
    if not pyro_fb_pattern.active then
        return false
    end
    local hasHotStreak = resources.has_hot_streak(player)
    -- Check for GCD
    local gcd = core.spell_book.get_global_cooldown()
    logger.log(
        "Pyro->FB pattern executing - Current state: " ..
        pyro_fb_pattern.state .. ", GCD: " .. string.format("%.2f", gcd) .. "s", 3)

    -- State: WAITING_FOR_GCD
    if pyro_fb_pattern.state == "WAITING_FOR_GCD" then
        -- Wait until GCD is almost over
        local fb_charges = resources.get_fire_blast_charges()
        if gcd > 0 and fb_charges > 0 then
            logger.log("Pyro->FB pattern - GCD started, preparing Fire Blast (Fire Blast charges: " .. fb_charges .. ")",
                2)
            pyro_fb_pattern.state = "FIRE_BLAST_CAST"
        elseif gcd <= 0 then
            logger.log("Pyro->FB pattern - GCD EXPIRED but no Fire Blast charges, aborting pattern", 2)
            pyro_fb_pattern.reset()
            return false
        else
            logger.log(
                "Pyro->FB pattern - Waiting for GCD (" ..
                string.format("%.2f", gcd) .. "s remaining, FB charges: " .. fb_charges .. ")", 3)
        end
        return true

        -- State: FIRE_BLAST_CAST
    elseif pyro_fb_pattern.state == "FIRE_BLAST_CAST" then
        -- Cast Fire Blast
        logger.log("Pyro->FB pattern - Attempting to cast Fire Blast", 2)
        if not hasHotStreak and spellcasting.cast_spell(SPELL.FIRE_BLAST, target, false, false) then
            pyro_fb_pattern.state = "PYROBLAST_CAST"
            logger.log("Pyro->FB pattern - Fire Blast cast successful, transitioning to PYROBLAST_CAST state", 2)
            return true
        else
            logger.log("Pyro->FB pattern - Fire Blast cast FAILED, retrying", 2)
            return true
        end

        -- State: PYROBLAST_CAST
    elseif pyro_fb_pattern.state == "PYROBLAST_CAST" then
        -- Cast Pyroblast if Hot Streak is active

        if gcd == 0 then
            logger.log("Pyro->FB pattern - Attempting to cast Pyroblast with Hot Streak", 2)
            if spellcasting.cast_spell(SPELL.PYROBLAST, target, false, false) then
                logger.log("Pyro->FB pattern COMPLETED: Full sequence executed successfully", 1)
                pyro_fb_pattern.reset()
                return true
            else
                logger.log("Pyro->FB pattern - Pyroblast cast FAILED, retrying", 2)
                return true
            end
        elseif gcd <= 0 and pyro_fb_pattern.start_time + reset_time > core.time() then
            -- We should have Hot Streak by now, if not something went wrong
            logger.log("start time plus 1 " .. pyro_fb_pattern.start_time + 1)
            logger.log("core time " .. core.time())
            logger.log("Pyro->FB pattern ABANDONED: No Hot Streak for Pyroblast (GCD ended)", 1)
            pyro_fb_pattern.reset()
            return false
        else
            logger.log(
                "Pyro->FB pattern - Waiting for Hot Streak proc or GCD (Current GCD: " ..
                string.format("%.2f", gcd) .. "s)",
                3)
            return true
        end
    end

    return true
end

-----------------------------------
-- PHOENIX FLAMES PATTERN
-----------------------------------
local pyro_pf_pattern = {
    active = false,
    state = "NONE", -- NONE, WAITING_FOR_GCD, PF_CAST, PYROBLAST_CAST
    start_time = 0
}

function pyro_pf_pattern.should_start(player)
    logger.log("Evaluating Pyro->PF pattern conditions:", 3)

    -- If the Fire Blast pattern is active, don't start this one
    if pyro_fb_pattern.active then
        logger.log("Pyro->PF pattern REJECTED: Fire Blast pattern already active", 2)
        return false
    end
    logger.log("Pyro->PF pattern check: No Fire Blast pattern active ✓", 3)

    -- Check if we just cast Pyroblast
    if spellcasting.last_cast ~= SPELL.PYROBLAST.name then
        logger.log(
            "Pyro->PF pattern REJECTED: Last cast was not Pyroblast (was " .. (spellcasting.last_cast or "nil") .. ")", 2)
        return false
    end
    logger.log("Pyro->PF pattern check: Last cast WAS Pyroblast ✓", 3)

    -- Check if GCD is active
    local gcd = core.spell_book.get_global_cooldown()
    if gcd > 0 then
        logger.log("Pyro->PF pattern REJECTED: Global cooldown is active (GCD: " .. gcd .. ")", 2)
        return false
    end
    logger.log("Pyro->PF pattern check: GCD is not active (" .. string.format("%.2f", gcd) .. "s) ✓", 3)

    -- Check if we have Phoenix Flames charge
    local pf_charges = resources.get_phoenix_flames_charges()
    if pf_charges > 0 then
        logger.log("Pyro->PF pattern ACCEPTED: Have Phoenix Flames charges (" .. pf_charges .. ")", 2)
        return true
    end

    -- Check if a charge will be ready by end of GCD
    local pf_ready_time = resources.phoenix_flames_ready_in(gcd)
    if pf_ready_time < gcd then
        logger.log(
            "Pyro->PF pattern ACCEPTED: Phoenix Flames will be ready in " ..
            string.format("%.2f", pf_ready_time) .. "s (before GCD ends)", 2)
        return true
    end

    logger.log("Pyro->PF pattern REJECTED: No Phoenix Flames charges and none will be ready soon", 2)
    return false
end

function pyro_pf_pattern.start()
    pyro_pf_pattern.active = true
    pyro_pf_pattern.state = "PF_CAST"
    pyro_pf_pattern.start_time = core.time()
    logger.log("Pyro->PF pattern STARTED - State: WAITING_FOR_GCD", 1)
end

function pyro_pf_pattern.reset()
    local prev_state = pyro_pf_pattern.state
    pyro_pf_pattern.active = false
    pyro_pf_pattern.state = "NONE"
    pyro_pf_pattern.start_time = 0
    logger.log("Pyro->PF pattern RESET (from " .. prev_state .. " state)", 1)
end

function pyro_pf_pattern.execute(player, target)
    if not pyro_pf_pattern.active then
        return false
    end

    -- Check for GCD
    local gcd = core.spell_book.get_global_cooldown()
    logger.log(
        "Pyro->PF pattern executing - Current state: " ..
        pyro_pf_pattern.state .. ", GCD: " .. string.format("%.2f", gcd) .. "s", 3)

    -- State: WAITING_FOR_GCD


    -- State: PHOENIX_FLAMES_CAST
    if pyro_pf_pattern.state == "PF_CAST" then
        -- Cast Phoenix Flames
        local pf_charges = resources.get_phoenix_flames_charges()
        logger.log("Pyro->PF pattern - Checking Phoenix Flames charges: " .. pf_charges, 3)

        if pf_charges > 0 and gcd == 0 then
            logger.log("Pyro->PF pattern - Attempting to cast Phoenix Flames", 2)
            if spellcasting.cast_spell(SPELL.PHOENIX_FLAMES, target, false, false) then
                pyro_pf_pattern.state = "PYROBLAST_CAST"
                logger.log("Pyro->PF pattern - Phoenix Flames cast successful, transitioning to PYROBLAST_CAST state", 2)
                return true
            else
                logger.log("Pyro->PF pattern - Phoenix Flames cast FAILED, retrying", 2)
                return true
            end
        else
            -- No charges, abandon pattern
            logger.log("Pyro->PF pattern ABANDONED: No Phoenix Flames charges", 1)
            pyro_pf_pattern.reset()
            return false
        end

        -- State: PYROBLAST_CAST
    elseif pyro_pf_pattern.state == "PYROBLAST_CAST" then
        -- Cast Pyroblast if Hot Streak is active
        local has_hot_streak = resources.has_hot_streak(player)
        logger.log(
            "Pyro->PF pattern - Checking for Hot Streak before Pyroblast (Hot Streak: " ..
            tostring(has_hot_streak) .. ")", 3)
        if gcd == 0 then
            if spellcasting.cast_spell(SPELL.PYROBLAST, target, false, false) then
                logger.log("Pyro->PF pattern COMPLETED: Full sequence executed successfully", 1)
                pyro_pf_pattern.reset()
                return true
            else
                logger.log("Pyro->PF pattern - Pyroblast cast FAILED, retrying", 2)
                return true
            end
        end
    elseif gcd <= 0 and pyro_pf_pattern.start_time + reset_time > core.time() then
        -- We should have Hot Streak by now, if not something went wrong
        logger.log("start time plus 1 " .. pyro_fb_pattern.start_time + 1)
        logger.log("core time " .. core.time())
        logger.log("Pyro->PF pattern ABANDONED: No Hot Streak for Pyroblast after Phoenix Flames (GCD ended)", 1)
        pyro_pf_pattern.reset()
        return false
    else
        logger.log(
            "Pyro->PF pattern - Waiting for Hot Streak proc or GCD (Current GCD: " ..
            string.format("%.2f", gcd) .. "s)",
            3)
        return true
    end
end

-----------------------------------
-- SCORCH-FIREBLAST PATTERN
-----------------------------------
local scorch_fb_pattern = {
    active = false,
    state = "NONE", -- NONE, SCORCH_CAST, FIRE_BLAST_CAST, PYROBLAST_CAST
    start_time = 0
}

function scorch_fb_pattern.should_start(player)
    logger.log("Evaluating Scorch+FB pattern conditions:", 3)

    -- Don't start if other patterns are active
    if pyro_fb_pattern.active or pyro_pf_pattern.active then
        logger.log("Scorch+FB pattern REJECTED: Another pattern is already active", 2)
        return false
    end
    logger.log("Scorch+FB pattern check: No other patterns active ✓", 3)

    -- Check if we just cast Pyroblast
    if spellcasting.last_cast ~= SPELL.PYROBLAST.name then
        logger.log(
            "Scorch+FB pattern REJECTED: Last cast was not Pyroblast (was " .. (spellcasting.last_cast or "nil") .. ")",
            2)
        return false
    end
    logger.log("Scorch+FB pattern check: Last cast WAS Pyroblast ✓", 3)

    local gcd = core.spell_book.get_global_cooldown()
    if gcd > 0 then
        logger.log("scorch -> fb pattern REJECTED: Global cooldown is active (GCD: " .. gcd .. ")", 2)
        return false
    end
    logger.log("scorch -> fb pattern check: GCD is not active (" .. string.format("%.2f", gcd) .. "s) ✓", 3)

    -- Check if we have no Fire Blast charges
    local fb_charges = resources.get_fire_blast_charges()
    if fb_charges > 0 then
        logger.log("Scorch+FB pattern REJECTED: Still have Fire Blast charges (" .. fb_charges .. ")", 2)
        return false
    end
    logger.log("Scorch+FB pattern check: No Fire Blast charges available ✓", 3)

    -- Check if Combustion is active
    local combustion_remaining = resources.get_combustion_remaining(player)
    if combustion_remaining <= 0 then
        logger.log("Scorch+FB pattern REJECTED: Combustion not active", 2)
        return false
    end
    logger.log(
        "Scorch+FB pattern check: Combustion is active (" ..
        string.format("%.2f", combustion_remaining / 1000) .. "s remaining) ✓", 3)

    -- Calculate if Fire Blast will be ready by the end of Scorch cast
    local scorch_cast_time = core.spell_book.get_spell_cast_time(SPELL.SCORCH.id)

    -- Check if Scorch cast + safety margin will finish before Combustion ends
    local combustion_remaining_sec = combustion_remaining / 1000
    if (scorch_cast_time + 0.1) >= combustion_remaining_sec then
        logger.log(
            "Scorch+FB pattern REJECTED: Not enough Combustion time left (Combustion: " ..
            string.format("%.2f", combustion_remaining_sec) ..
            "s, Required: " .. string.format("%.2f", scorch_cast_time + 0.1) .. "s)", 2)
        return false
    end

    logger.log("Scorch+FB pattern ACCEPTED: All conditions met, starting sequence", 1)
    return true
end

function scorch_fb_pattern.start()
    scorch_fb_pattern.active = true
    scorch_fb_pattern.state = "SCORCH_CAST"
    scorch_fb_pattern.start_time = core.time()
    logger.log("Scorch+FB pattern STARTED - State: SCORCH_CAST", 1)
end

function scorch_fb_pattern.reset()
    local prev_state = scorch_fb_pattern.state
    scorch_fb_pattern.active = false
    scorch_fb_pattern.state = "NONE"
    scorch_fb_pattern.start_time = 0
    logger.log("Scorch+FB pattern RESET (from " .. prev_state .. " state)", 1)
end

function scorch_fb_pattern.execute(player, target)
    if not scorch_fb_pattern.active then
        return false
    end

    logger.log("Scorch+FB pattern executing - Current state: " .. scorch_fb_pattern.state, 3)

    -- State: SCORCH_CAST
    if scorch_fb_pattern.state == "SCORCH_CAST" then
        -- Cast Scorch
        logger.log("Scorch+FB pattern - Attempting to cast Scorch", 2)
        if spellcasting.cast_spell(SPELL.SCORCH, target, false, false) then
            scorch_fb_pattern.state = "FIRE_BLAST_CAST"
            logger.log("Scorch+FB pattern - Scorch cast successful, transitioning to FIRE_BLAST_CAST state", 2)
            return true
        else
            logger.log("Scorch+FB pattern - Scorch cast FAILED, retrying", 2)
        end
        return true

        -- State: FIRE_BLAST_CAST
    elseif scorch_fb_pattern.state == "FIRE_BLAST_CAST" then
        -- Wait for the right moment to cast Fire Blast
        local cast_end_time = player:get_active_spell_cast_end_time()
        local current_time = core.game_time()
        local remaining_cast_time = (cast_end_time - current_time) / 1000
        -- Cast Fire Blast near the end of Scorch cast
        if remaining_cast_time > 200 and resources.get_fire_blast_charges() > 0 then
            local scorch_cast_time = core.spell_book.get_spell_cast_time(SPELL.SCORCH.id)
            logger.log(
                "Scorch+FB pattern - Attempting to cast Fire Blast during Scorch (Remaining cast: " ..
                string.format("%.2f", remaining_cast_time) .. "s)", 2)
            if spellcasting.cast_spell(SPELL.FIRE_BLAST, target, false, false) then
                scorch_fb_pattern.state = "FIRST_PYROBLAST_CAST"
                logger.log("Scorch+FB pattern - Fire Blast cast successful, transitioning to PYROBLAST_CAST state", 2)
                return true
            end
        elseif cast_end_time == 0 then
            -- Scorch cast finished without casting Fire Blast - check if we got Hot Streak anyway
            scorch_fb_pattern.state = "SECOND_PYROBLAST_CAST"
            logger.log("Scorch+FB pattern: No Fire Blast charges after Scorch, transitioning to PYROBLAST_CAST state",
                1)
            return true
        end
        return true

        -- State: PYROBLAST_CAST
    elseif scorch_fb_pattern.state == "FIRST_PYROBLAST_CAST" then
        -- Cast Pyroblast if Hot Streak is active
        local has_hot_streak = resources.has_hot_streak(player)
        logger.log(
            "Scorch+FB pattern - Checking for Hot Streak before Pyroblast (Hot Streak: " ..
            tostring(has_hot_streak) .. ")",
            3)
        local cast_end_time = player:get_active_spell_cast_end_time()
        local current_time = core.game_time()
        local remaining_cast_time = (cast_end_time - current_time) / 1000
        if remaining_cast_time <= 0 then
            logger.log("Scorch+FB pattern - Attempting to cast Pyroblast with Hot Streak", 2)
            if spellcasting.cast_spell(SPELL.PYROBLAST, target, false, false) then
                logger.log("Scorch+FB pattern: first pyro cast, advanceing to SECOND_PYROBLAST_CAST", 1)
                scorch_fb_pattern.state = "SECOND_PYROBLAST_CAST"
                return true
            end
        else
            logger.log(
                "Scorch+FB pattern - Waiting for scorch cast to end (Current cast: " ..
                string.format("%.2f", remaining_cast_time) .. "s)", 3)
        end
        return true
    elseif scorch_fb_pattern.state == "SECOND_PYROBLAST_CAST" then
        local gcd = core.spell_book.get_global_cooldown()
        if gcd <= 0 then
            logger.log("Scorch+FB pattern - Attempting to cast second Pyroblast with Hot Streak", 2)
            if spellcasting.cast_spell(SPELL.PYROBLAST, target, false, false) then
                logger.log("Scorch+FB pattern COMPLETED: Full sequence executed successfully", 1)
                scorch_fb_pattern.reset()
                return true
            end
        else
            logger.log(
                "Scorch+FB pattern - Waiting for GCD to end (GCD: " ..
                string.format("%.2f", gcd) .. "s)", 3)
        end
        return true
    end

    return true
end

-----------------------------------
-- COMBUSTION OPENER PATTERN
-----------------------------------
local combustion_opener_pattern = {
    active = false,
    state = "NONE", -- NONE, WAITING_FOR_CAST, COMBUSTION_CAST, FIRE_BLAST_CAST, FIRST_PYRO, SECOND_PYRO
    start_time = 0,
    has_activated_this_combustion = false
}

function combustion_opener_pattern.should_start(player)
    logger.log("Evaluating Combustion Opener pattern conditions:", 3)



    -- Don't start if other patterns are active
    if pyro_fb_pattern.active or pyro_pf_pattern.active or scorch_fb_pattern.active then
        logger.log("Combustion Opener REJECTED: Another pattern is already active", 2)
        return false
    end

    if combustion_opener_pattern.has_activated_this_combustion then
        logger.log("Combustion Opener REJECTED: opener already activated this combustion", 2)
        return false
    end

    -- Check if we have enough Fire Blast charges
    local fb_charges = resources.get_fire_blast_charges()
    if fb_charges < 2 then
        logger.log("Combustion Opener REJECTED: Not enough Fire Blast charges (" .. fb_charges .. ")", 2)
        return false
    end

    -- Check if we have Heating Up or Hot Streak
    local has_heating_up = resources.has_heating_up(player)
    local has_hot_streak = resources.has_hot_streak(player)

    if not (has_heating_up or has_hot_streak) then
        logger.log("Combustion Opener REJECTED: No Heating Up or Hot Streak proc", 2)
        return false
    end

    local active_spell_id = player:get_active_spell_id()
    local cast_end_time = player:get_active_spell_cast_end_time()
    local current_time = core.game_time()
    local remaining_cast_time = (cast_end_time - current_time)
    local combustion_cd = core.spell_book.get_spell_cooldown(SPELL.COMBUSTION.id)
    logger.log("Combustion CD: " .. combustion_cd, 3)


    if combustion_cd > .5 then
        logger.log("Combustion Opener REJECTED: combustion on cd", 2)

        return false
    end

    if active_spell_id ~= SPELL.FIREBALL.id or remaining_cast_time < combust_precast_time then
        logger.log("Combustion Opener REJECTED: not casting fireball, or cast time is less than 300ms", 2)
        return false
    end

    logger.log("Combustion Opener ACCEPTED: " .. fb_charges .. " Fire Blast charges and " ..
        (has_hot_streak and "Hot Streak" or "Heating Up") .. " active", 1)
    return true
end

function combustion_opener_pattern.start()
    combustion_opener_pattern.active = true
    combustion_opener_pattern.state = "WAITING_FOR_CAST"
    combustion_opener_pattern.start_time = core.time()
    combustion_opener_pattern.has_activated_this_combustion = false
    logger.log("Combustion Opener STARTED - State: WAITING_FOR_CAST", 1)
end

function combustion_opener_pattern.reset()
    local prev_state = combustion_opener_pattern.state
    combustion_opener_pattern.active = false
    combustion_opener_pattern.state = "NONE"
    combustion_opener_pattern.start_time = 0
    logger.log("Combustion Opener RESET (from " .. prev_state .. " state)", 1)
end

function combustion_opener_pattern.execute(player, target)
    if not combustion_opener_pattern.active then
        return false
    end

    logger.log("Combustion Opener executing - Current state: " .. combustion_opener_pattern.state, 3)

    -- State: WAITING_FOR_CAST
    if combustion_opener_pattern.state == "WAITING_FOR_CAST" then
        -- Check if we're casting Fireball
        local active_spell_id = player:get_active_spell_id()
        local cast_end_time = player:get_active_spell_cast_end_time()
        local current_time = core.game_time()
        local remaining_cast_time = (cast_end_time - current_time)

        if remaining_cast_time < combust_precast_time then
            -- If Fireball cast time is <300ms, cast Combustion
            logger.log("Combustion Opener - Fireball cast time < 300ms, casting Combustion", 2)
            combustion_opener_pattern.state = "COMBUSTION_CAST"
            return true
        else
            logger.log("Combustion Opener - Waiting for Fireball cast to get to correct timing (remaining: " ..
                string.format("%.2f", remaining_cast_time / 1000) .. "s)", 3)
            return true
        end


        -- State: COMBUSTION_CAST
    elseif combustion_opener_pattern.state == "COMBUSTION_CAST" then
        logger.log("Combustion Opener - Attempting to cast Combustion", 2)
        if spellcasting.cast_spell(SPELL.COMBUSTION, target, false, false) then
            combustion_opener_pattern.has_activated_this_combustion = true

            -- Check if we have Hot Streak
            if resources.has_hot_streak(player) then
                combustion_opener_pattern.state = "FIRST_PYRO"
                logger.log("Combustion Opener - Combustion cast successful, Hot Streak active, skipping Fire Blast", 2)
            else
                combustion_opener_pattern.state = "FIRE_BLAST_CAST"
                logger.log("Combustion Opener - Combustion cast successful, transitioning to FIRE_BLAST_CAST state", 2)
            end
            return true
        end
        return true

        -- State: FIRE_BLAST_CAST
    elseif combustion_opener_pattern.state == "FIRE_BLAST_CAST" then
        logger.log("Combustion Opener - Attempting to cast Fire Blast to get Hot Streak", 2)
        if spellcasting.cast_spell(SPELL.FIRE_BLAST, target, false, false) then
            combustion_opener_pattern.state = "FIRST_PYRO"
            logger.log("Combustion Opener - Fire Blast cast successful, transitioning to FIRST_PYRO state", 2)
            return true
        end
        return true

        -- State: FIRST_PYRO
    elseif combustion_opener_pattern.state == "FIRST_PYRO" then
        logger.log("Combustion Opener - Attempting to cast first Pyroblast", 2)
        if spellcasting.cast_spell(SPELL.PYROBLAST, target, false, false) then
            combustion_opener_pattern.state = "SECOND_PYRO"
            logger.log("Combustion Opener - First Pyroblast cast successful, transitioning to SECOND_PYRO state", 2)
            return true
        end
        return true

        -- State: SECOND_PYRO
    elseif combustion_opener_pattern.state == "SECOND_PYRO" then
        -- Also wait for GCD if needed
        local gcd = core.spell_book.get_global_cooldown()
        if gcd > 0.1 then
            logger.log("Combustion Opener - Waiting for GCD after first Pyroblast (" ..
                string.format("%.2f", gcd) .. "s remaining)", 3)
            return true
        end

        -- Cast second Pyroblast
        logger.log("Combustion Opener - Attempting to cast second Pyroblast", 2)
        if spellcasting.cast_spell(SPELL.PYROBLAST, target, false, false) then
            logger.log("Combustion Opener COMPLETED: Both Pyroblasts cast successfully", 1)
            combustion_opener_pattern.reset()
            return true
        end
        return true
    end

    return true
end

-----------------------------------
-- FIREBALL-HOTSTREAK PATTERN
-----------------------------------
local fireball_hotstreak_pattern = {
    active = false,
    state = "NONE", -- NONE, FIRE_BLAST_CAST, PYROBLAST_CAST
    start_time = 0
}

function fireball_hotstreak_pattern.should_start(player)
    logger.log("Evaluating Fireball->HotStreak pattern conditions:", 3)

    -- Don't start if other patterns are active
    if pyro_fb_pattern.active or pyro_pf_pattern.active or scorch_fb_pattern.active or combustion_opener_pattern.active then
        logger.log("Fireball->HotStreak pattern REJECTED: Another pattern is already active", 2)
        return false
    end

    -- Check if we're currently casting Fireball
    local active_spell_id = player:get_active_spell_id()
    if active_spell_id ~= SPELL.FIREBALL.id then
        logger.log("Fireball->HotStreak pattern REJECTED: Not casting Fireball", 2)
        return false
    end

    -- Check if we have Hot Streak
    if not resources.has_heating_up(player) then
        logger.log("Fireball->HotStreak pattern REJECTED: No heating up", 2)
        return false
    end
    -- Check if we're not in Combustion
    local combustion_remaining = resources.get_combustion_remaining(player)
    if combustion_remaining > 0 then
        logger.log("Fireball->HotStreak pattern REJECTED: Combustion is active", 2)
        return false
    end

    local combustionCD = core.spell_book.get_spell_cooldown(SPELL.COMBUSTION.id)
    local fire_blast_charges = resources.get_fire_blast_charges()

    if combustionCD < 10 and fire_blast_charges < 2 then
        logger.log("Fireball->HotStreak pattern REJECTED: Combustion CD or Fire Blast charges too low", 2)
        return false
    end
    logger.log("Fireball->HotStreak pattern ACCEPTED: Casting Fireball with Hot Streak active", 1)
    return true
end

function fireball_hotstreak_pattern.start()
    fireball_hotstreak_pattern.active = true
    fireball_hotstreak_pattern.state = "FIRE_BLAST_CAST"
    fireball_hotstreak_pattern.start_time = core.time()
    logger.log("Fireball->HotStreak pattern STARTED - State: FIRE_BLAST_CAST", 1)
end

function fireball_hotstreak_pattern.reset()
    local prev_state = fireball_hotstreak_pattern.state
    fireball_hotstreak_pattern.active = false
    fireball_hotstreak_pattern.state = "NONE"
    fireball_hotstreak_pattern.start_time = 0
    logger.log("Fireball->HotStreak pattern RESET (from " .. prev_state .. " state)", 1)
end

function fireball_hotstreak_pattern.execute(player, target)
    if not fireball_hotstreak_pattern.active then
        return false
    end

    logger.log("Fireball->HotStreak pattern executing - Current state: " .. fireball_hotstreak_pattern.state, 3)

    -- State: FIRE_BLAST_CAST
    if fireball_hotstreak_pattern.state == "FIRE_BLAST_CAST" then
        -- Check if Fireball is still being cast
        local cast_end_time = player:get_active_spell_cast_end_time()
        local current_time = core.game_time()

        if cast_end_time > 0 then
            -- Cast Fire Blast during Fireball cast
            logger.log("Fireball->HotStreak pattern - Attempting to cast Fire Blast during Fireball", 2)
            if spellcasting.cast_spell(SPELL.FIRE_BLAST, target, false, false) then
                fireball_hotstreak_pattern.state = "PYROBLAST_CAST"
                logger.log("Fireball->HotStreak pattern - Fire Blast cast successful, waiting for Fireball to finish", 2)
                return true
            end
        else
            -- Fireball cast finished, move to next state
            fireball_hotstreak_pattern.state = "PYROBLAST_CAST"
            logger.log("Fireball->HotStreak pattern - Fireball cast finished, transitioning to PYROBLAST_CAST state", 2)
        end
        return true

        -- State: PYROBLAST_CAST
    elseif fireball_hotstreak_pattern.state == "PYROBLAST_CAST" then
        -- Wait for GCD after Fireball
        local cast_end_time = player:get_active_spell_cast_end_time()
        if cast_end_time > 0 then
            logger.log("Fireball->HotStreak pattern - Waiting for fireball cast (" ..
                string.format("%.2f", cast_end_time) .. "s remaining)", 3)
            return true
        end

        -- Cast Pyroblast
        logger.log("Fireball->HotStreak pattern - Attempting to cast Pyroblast with Hot Streak", 2)
        if spellcasting.cast_spell(SPELL.PYROBLAST, target, false, false) then
            logger.log("Fireball->HotStreak pattern COMPLETED: Pyroblast cast after Fireball", 1)
            fireball_hotstreak_pattern.reset()
            return true
        end
        return true
    end

    return true
end

-----------------------------------
-- TARGET SELECTION
-----------------------------------
local targeting = {}

-- Override target selector settings
local is_ts_overriden = false
function targeting.override_ts_settings()
    if is_ts_overriden then
        return
    end

    local is_override_allowed = menu_elements.ts_custom_logic_override:get_state()
    if not is_override_allowed then
        logger.log("Target selector override skipped: Override not enabled in menu", 3)
        return
    end

    logger.log("Target selector settings overriding...", 2)
    target_selector.menu_elements.settings.max_range_damage:set(40)
    target_selector.menu_elements.damage.weight_multiple_hits:set(true)
    target_selector.menu_elements.damage.slider_weight_multiple_hits:set(4)
    target_selector.menu_elements.damage.slider_weight_multiple_hits_radius:set(8)

    is_ts_overriden = true
    logger.log("Target selector settings successfully overridden", 2)
end

-- Get best target
function targeting.get_best_target()
    local targets_list = target_selector:get_targets()

    for i, target in ipairs(targets_list) do
        if unit_helper:is_in_combat(target) and not pvp_helper:is_damage_immune(target, pvp_helper.damage_type_flags.MAGICAL) then
            logger.log("Target selected: #" .. i .. " from target selector list", 3)
            return target
        end
    end

    logger.log("No valid targets found", 3)
    return nil
end

-----------------------------------
-- UI RENDERING
-----------------------------------
local ui = {}

-- Render menu UI
function ui.render_menu()
    menu_elements.main_tree:render("Fire Mage Enhanced", function()
        menu_elements.enable_script_check:render("Enable Script")

        if not menu_elements.enable_script_check:get_state() then
            return
        end

        menu_elements.keybinds_tree_node:render("Keybinds", function()
            menu_elements.enable_toggle:render("Enable Script Toggle")
        end)

        menu_elements.ts_custom_logic_override:render("Enable TS Custom Settings Override",
            "Allows the script to automatically adjust target selection settings")
        menu_elements.debug_info:render("Show Debug Info", "Display real-time information about script decisions")
        menu_elements.draw_plugin_state:render("Draw Plugin State", "Shows enabled/disabled status on screen")
        menu_elements.log_level:render("Log Detail Level", "1=Minimal, 2=Normal, 3=Verbose")
    end)
end

-- Render control panel
function ui.render_control_panel()
    local control_panel_elements = {}

    control_panel_helper:insert_toggle(control_panel_elements, {
        name = "[Fire Mage] Enable (" .. key_helper:get_key_name(menu_elements.enable_toggle:get_key_code()) .. ")",
        keybind = menu_elements.enable_toggle
    })

    return control_panel_elements
end

-- Render on-screen UI
function ui.render()
    local player = core.object_manager.get_local_player()
    if not player then
        return
    end

    if not menu_elements.enable_script_check:get_state() then
        return
    end

    if not plugin_helper:is_toggle_enabled(menu_elements.enable_toggle) then
        if menu_elements.draw_plugin_state:get_state() then
            plugin_helper:draw_text_character_center("DISABLED")
        end
        return
    end

    -- Show debug info if enabled
    if menu_elements.debug_info:get_state() then
        -- Build status text
        local combustion_active = buff_manager:get_buff_data(player, BUFF.COMBUSTION).is_active
        local hot_streak_active = resources.has_hot_streak(player)
        local heating_up_active = resources.has_heating_up(player)

        local active_pattern = "None"
        if pyro_fb_pattern.active then
            active_pattern = "Pyro->FB: " .. pyro_fb_pattern.state
        elseif pyro_pf_pattern.active then
            active_pattern = "Pyro->PF: " .. pyro_pf_pattern.state
        elseif scorch_fb_pattern.active then
            active_pattern = "Scorch+FB: " .. scorch_fb_pattern.state
        end

        local text = "Last Cast: " .. (spellcasting.last_cast or "None") ..
            "\nPattern: " .. active_pattern ..
            "\nFire Blast: " .. resources.get_fire_blast_charges() ..
            ", PF: " .. resources.get_phoenix_flames_charges() ..
            "\nCombustion: " .. (combustion_active and "Active" or "Inactive") ..
            "\nHot Streak: " .. (hot_streak_active and "Active" or "Inactive") ..
            "\nHeating Up: " .. (heating_up_active and "Active" or "Inactive")

        -- Add recent logs
        if #logger.logs > 0 then
            text = text .. "\n\nRecent Actions:"
            for i = 1, math.min(5, #logger.logs) do
                text = text .. "\n- " .. logger.logs[i]
            end
        end

        plugin_helper:draw_text_character_center(text, nil, 100)
    end
end

-----------------------------------
-- MAIN EXECUTION
-----------------------------------
local function isAnyPatternActive()
    return pyro_fb_pattern.active or pyro_pf_pattern.active or scorch_fb_pattern.active or
        combustion_opener_pattern.active or fireball_hotstreak_pattern.active
end

local function isAnyCombustionPatternActive()
    return pyro_fb_pattern.active or pyro_pf_pattern.active or scorch_fb_pattern.active
end

local function on_update()
    -- Update logger level

    logger.update_level()

    -- Update control panel
    control_panel_helper:on_update(menu_elements)

    -- Check if player exists
    local player = core.object_manager.get_local_player()
    if not player then
        return
    end

    -- Check if script is enabled
    if not menu_elements.enable_script_check:get_state() or not plugin_helper:is_toggle_enabled(menu_elements.enable_toggle) then
        return
    end

    -- Don't cast during channeling
    local channel_end_time = player:get_active_channel_cast_end_time()
    if channel_end_time > 0.0 then
        logger.log("Skipping: Player is channeling", 3)
        return
    end

    -- Don't cast while mounted
    if player:is_mounted() then
        logger.log("Skipping: Player is mounted", 3)
        return
    end

    -- Don't cast during another cast
    local cast_end_time = player:get_active_spell_cast_end_time()
    local active_spell_id = player:get_active_spell_id()

    if cast_end_time > core.game_time() and active_spell_id == SPELL.SCORCH.id then
        logger.log(
            "Skipping: Player is casting (time remaining: " .. ((cast_end_time - core.game_time()) / 1000) .. "s)",
            3)
        return
    end

    -- Override target selector settings
    targeting.override_ts_settings()

    -- Get target
    local target = targeting.get_best_target()
    if not target then
        logger.log("Skipping: No valid target found", 3)
        return
    end

    logger.log("Evaluating patterns with target: " .. target:get_name(), 3)
    local combustion_time = resources.get_combustion_remaining(player)

    if combustion_time > 0 then
        logger.log("Combustion is active (" .. string.format("%.2f", combustion_time / 1000) .. "s remaining)", 2)

        -- Check if we need to start the pattern
        if not isAnyPatternActive() then
            logger.log("No pattern active, checking for pattern to start", 3)

            -- Check for combustion opener pattern first
            if combustion_opener_pattern.should_start(player) then
                combustion_opener_pattern.start()
            elseif pyro_fb_pattern.should_start(player) then
                pyro_fb_pattern.start()
            elseif pyro_pf_pattern.should_start(player) then
                pyro_pf_pattern.start()
            elseif scorch_fb_pattern.should_start(player) then
                scorch_fb_pattern.start()
            end
        end

        -- Execute patterns if active
        if combustion_opener_pattern.active and combustion_opener_pattern.execute(player, target) then
            return
        end

        if pyro_fb_pattern.active and pyro_fb_pattern.execute(player, target) then
            return
        end

        if pyro_pf_pattern.active and pyro_pf_pattern.execute(player, target) then
            return
        end

        if scorch_fb_pattern.active and scorch_fb_pattern.execute(player, target) then
            return
        end
        local gcd = core.spell_book.get_global_cooldown()
        local is_casting = player.is_casting_spell(player)

        if gcd == 0 and not is_casting then
            if not resources.has_hot_streak(player) then
                if spellcasting.cast_spell(SPELL.FIRE_BLAST, target, false, false) then
                    logger.log("Fire Blast cast successful")
                    return
                elseif spellcasting.cast_spell(SPELL.PHOENIX_FLAMES, target, false, false) then
                    logger.log("Phoenix Flames cast successful")
                    return
                else
                    spellcasting.cast_spell(SPELL.SCORCH, target, false, false)
                end
            else
                spellcasting.cast_spell(SPELL.PYROBLAST, target, false, false)
            end
        end
    else
        logger.log("Combustion not active, using standard rotation", 3)
        -- Check for Hot Streak
        if combustion_opener_pattern.has_activated_this_combustion then
            combustion_opener_pattern.has_activated_this_combustion = false
        end
        if isAnyCombustionPatternActive() then
            pyro_fb_pattern.reset()
            pyro_pf_pattern.reset()
            scorch_fb_pattern.reset()
        end
        if not isAnyPatternActive() then
            logger.log("No pattern active in non-combustion rota, checking for pattern to start", 3)
            if combustion_opener_pattern.should_start(player) then
                combustion_opener_pattern.start()
            end
            if fireball_hotstreak_pattern.should_start(player) then
                fireball_hotstreak_pattern.start()
            end
        else
            logger.log("Pattern already active in non-combustion rota", 3)
        end


        -- Execute patterns if active
        if combustion_opener_pattern.active and combustion_opener_pattern.execute(player, target) then
            return
        end
        if fireball_hotstreak_pattern.active and fireball_hotstreak_pattern.execute(player, target) then
            return
        end

        if resources.has_hot_streak(player) or resources.has_hyperthermia(player) then
            logger.log("Standard rotation: Hot Streak or Hyperthermia detected, casting Pyroblast", 3)
            spellcasting.cast_spell(SPELL.PYROBLAST, target, false, false)
            return
        end

        if not player.is_casting_spell(player) then
            if not resources.has_heating_up(player) and resources.get_phoenix_flames_charges() == 2 then
                logger.log("Standard rotation: using pf charge", 3)
                spellcasting.cast_spell(SPELL.PHOENIX_FLAMES, target, false, false)
            else
                -- Default to Fireball
                logger.log("Standard rotation: Casting Fireball", 3)
                spellcasting.cast_spell(SPELL.FIREBALL, target, false, false)
            end
        end
    end
end
-----------------------------------
-- SPELL CAST MONITORING
-----------------------------------
local function on_spell_cast(spellId)
    local player = core.object_manager.get_local_player()
    if not player then
        return
    end

    -- Check if spell is Pyroblast
    if spellId == SPELL.PYROBLAST.id then
        logger.log("Pyroblast was cast - Resetting all active patterns", 2)

        -- Reset all patterns
        if pyro_fb_pattern.active then
            logger.log("Resetting Pyro->FB pattern due to manual Pyroblast cast", 2)
            pyro_fb_pattern.reset()
        end

        if pyro_pf_pattern.active then
            logger.log("Resetting Pyro->PF pattern due to manual Pyroblast cast", 2)
            pyro_pf_pattern.reset()
        end

        if scorch_fb_pattern.active then
            logger.log("Resetting Scorch+FB pattern due to manual Pyroblast cast", 2)
            scorch_fb_pattern.reset()
        end

        if combustion_opener_pattern.active then
            logger.log("Resetting Combustion Opener pattern due to manual Pyroblast cast", 2)
            combustion_opener_pattern.reset()
        end

        if fireball_hotstreak_pattern.active then
            logger.log("Resetting Combustion Opener pattern due to manual Pyroblast cast", 2)
            fireball_hotstreak_pattern.reset()
        end
        setLastCast(SPELL.PYROBLAST)
    end
end

-----------------------------------
-- REGISTER CALLBACKS
-----------------------------------
core.register_on_update_callback(on_update)
core.register_on_render_callback(ui.render)
core.register_on_render_menu_callback(ui.render_menu)
core.register_on_render_control_panel_callback(ui.render_control_panel)
core.register_on_legit_spell_cast_callback(on_spell_cast)
