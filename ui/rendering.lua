---@class UiRenderer
local UiRenderer = {}

local menu_elements = require("ui/menu_elements")
local key_helper = require("common/utility/key_helper")
local plugin_helper = require("common/utility/plugin_helper")
local control_panel_helper = require("common/utility/control_panel_helper")
local resources = require("resources")
local logger = require("logger")
local buff_manager = require("common/modules/buff_manager")
local spell_data = require("spell_data")
local spellcasting = require("spellcasting")

-- Render menu UI
function UiRenderer:render_menu()
    menu_elements.main_tree:render("Fire Mage Enhanced COPY", function()
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
function UiRenderer:render_control_panel()
    local control_panel_elements = {}

    control_panel_helper:insert_toggle(control_panel_elements, {
        name = "[Fire Mage] Enable (" .. key_helper:get_key_name(menu_elements.enable_toggle:get_key_code()) .. ")",
        keybind = menu_elements.enable_toggle
    })

    return control_panel_elements
end

-- Render on-screen UI
---@param player game_object
---@param active_pattern_info string
function UiRenderer:render(player, active_pattern_info)
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
        local combustion_active = buff_manager:get_buff_data(player, spell_data.BUFF.COMBUSTION).is_active
        local hot_streak_active = resources:has_hot_streak(player)
        local heating_up_active = resources:has_heating_up(player)

        local text = "Last Cast: " .. (spellcasting.last_cast or "None") ..
            "\nPattern: " .. active_pattern_info ..
            "\nFire Blast: " .. resources:get_fire_blast_charges() ..
            ", PF: " .. resources:get_phoenix_flames_charges() ..
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

return UiRenderer
