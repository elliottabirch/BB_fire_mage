local plugin = {}

plugin["name"] = "Fire Mage Rotation"
plugin["version"] = "1.0.0"
plugin["author"] = "Claude"
plugin["load"] = true

-- Check if local player exists
local local_player = core.object_manager.get_local_player()
if not local_player then
    plugin["load"] = false
    return plugin
end

-- Check for Mage class
local enums = require("common/enums")
local player_class = local_player:get_class()
local is_valid_class = player_class == enums.class_id.MAGE

if not is_valid_class then
    plugin["load"] = false
    return plugin
end

-- Check for Fire spec (spec ID 2 for Mage)
local player_spec_id = core.spell_book.get_specialization_id()
local is_valid_spec_id = player_spec_id == 2

if not is_valid_spec_id then
    plugin["load"] = false
    return plugin
end

return plugin
