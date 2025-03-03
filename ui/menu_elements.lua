---@class MenuElements
local MenuElements = {}

function MenuElements:init()
    self.main_tree = core.menu.tree_node()
    self.keybinds_tree_node = core.menu.tree_node()
    self.enable_script_check = core.menu.checkbox(false, "enable_script_check")
    self.enable_toggle = core.menu.keybind(999, false, "toggle_script_check")
    self.draw_plugin_state = core.menu.checkbox(true, "draw_plugin_state")
    self.ts_custom_logic_override = core.menu.checkbox(true, "override_ts_logic")
    self.debug_info = core.menu.checkbox(true, "debug_info")
    self.log_level = core.menu.slider_int(1, 3, 2, "log_level")             -- 1=minimal, 2=normal, 3=verbose
    self.toggle_cooldowns = core.menu.keybind(88, true, "toggle_cooldowns") -- Default key: X

    self.smart_combustion = core.menu.checkbox(true, "smart_combustion")

    return self
end

return MenuElements:init()
