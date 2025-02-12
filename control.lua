local constants = require("constants")
local ulh_util = require("ulh_util")
local ulh_gui = require("ulh_gui")

-- Table for each players data
--- @class GlobalData
--- @field players PlayerData[]
storage = {}
storage.players = {}


--- @class PlayerData
--- @field config ConfigSlot[]
--- @field gui PlayerGuiConfig
--- @field edit_slot_index integer? the config index being edited, or nil if no edit


--- @class ConfigSlot
-- where to focus
--- @field surface_index uint? If it's a position, what surface
--- @field position MapPosition?
--- @field entity LuaEntity?
--- @field cloned_entity LuaEntity? To follow the entity in some situations (like warptorio warps)
--- @field player LuaPlayer?
-- what zoom level to go to
--- @field use_zoom boolean
--- @field zoom double
-- what the button for it looks like
--- @field sprite string?
--- @field caption string?



--- @param player LuaPlayer
local function init_player(player)
    --- @type PlayerData
    local player_data = {
        ---@diagnostic disable-next-line:missing-fields
        gui = {},
        config = {},
    }
    storage.players[player.index] = player_data
    ulh_gui.init_player_gui(player, player_data)
end

--- @param player LuaPlayer
--- @param selection EventData.on_player_selected_area|EventData.on_player_alt_selected_area?
--- @param entity LuaEntity?
--- @param index int?
local function add_shortcut(player, selection, entity, index)
    local player_data = storage.players[player.index]

    local config_slot = ulh_util.create_new_slot()

    if selection then
        ulh_util.fill_slot_from_selection(config_slot, selection)
    elseif entity then
        ulh_util.fill_slot_from_entity(config_slot, entity)
    elseif player.position then
        ulh_util.fill_slot_from_position(config_slot, player.position, player.surface)
    else
        return
    end
    if index then
        local limited_index = math.min(index, #player_data.config + 1) -- TODO allow non-sequential shortcuts
        if player.mod_settings["ulh-create-slot-hotkey-mode"].value == "insert" then
            table.insert(player_data.config, limited_index, config_slot)
        elseif player.mod_settings["ulh-create-slot-hotkey-mode"].value == "replace" then
            player_data.config[limited_index] = config_slot
        else -- player.mod_settings["ulh-create-slot-hotkey-mode"].value == "move-to-end" then
            local old_shortcut = player_data.config[limited_index]
            player_data.config[limited_index] = config_slot
            if old_shortcut then
                table.insert(player_data.config, old_shortcut)
            end
        end
    else
        table.insert(player_data.config, config_slot)
    end
    ulh_gui.rebuild_table(player, player_data)
end

--- @param player LuaPlayer
--- @param entity LuaEntity
--- @param pick_remote boolean
--- @param remote_drive boolean
local function do_pick_remote(player, entity, pick_remote, remote_drive)
    if pick_remote and entity.type == "spider-vehicle" then
        if not player.cursor_stack then return end
        if not player.cursor_stack.valid then return end
        if player.cursor_stack.set_stack { name = "spidertron-remote", count = 1 } then
            player.spidertron_remote_selection = { entity }
        end
    elseif remote_drive and (entity.type == "car" or entity.type == "locomotive" or entity.type == "spider-vehicle") then
        -- There's a allow_remote_driving field that would be nice to check here instead, but I don't see it on the entity or prototype...
        -- Ensure the player is in remote view so we don't accidentally teleport them
        if player.controller_type ~= defines.controllers.remote then return end
        -- Don't eject any player that's currently driving it
        if entity.get_driver() ~= nil then return end
        -- If it's a train, only start driving if it's in manual mode
        if entity.train and not entity.train.manual_mode then return end
        -- Start driving remotely (this does nothing if it can't be driven remotely and player controller type is remote)
        entity.set_driver(player)
    end
end

--- @param player LuaPlayer
--- @param slot ConfigSlot
--- @param follow boolean
--- @param pick_remote boolean
--- @param remote_drive boolean
local function go_to_location(player, slot, follow, pick_remote, remote_drive)
    if not player or not slot then return end
    ulh_util.update_slot_entity(slot)
    if slot.entity and not slot.entity.valid then
        player.print({ "gui.ulh-entity-not-valid" })
        return
    end

    --- @type MapPosition
    local position
    if slot.position then
        position = slot.position
    elseif slot.entity then
        position = slot.entity.position
    end
    if position == nil then return end -- shouldn't happen...
    local surface = ulh_util.get_slot_surface(slot)

    player.set_controller({
        type = defines.controllers.remote,
        position = position,
        surface = surface,
    })

    if follow and slot.entity then
        player.centered_on = slot.entity
    end

    -- TODO no way to not change the zoom level? Should update to remove that option
    if slot.use_zoom and slot.zoom then
        player.zoom = slot.zoom
    end
    if slot.entity then
        do_pick_remote(player, slot.entity, pick_remote, remote_drive)
    end
end

--- @param player LuaPlayer
local function on_config_update(player)
    ulh_gui.refresh_edit_window(player)
    local player_data = storage.players[player.index]
    ulh_gui.rebuild_table(player, player_data)

    if player_data.edit_slot_index then
        local slot = ulh_util.get_editing_slot(player_data)
        if slot then
            go_to_location(player, slot, false, false, false) -- live preview of zoom level
        end
    end
end

--- @param updated_player LuaPlayer
local function update_player_references(updated_player)
    for player_index, player_data in pairs(storage.players) do
        for _, slot in pairs(player_data.config) do
            if slot.player == updated_player then
                slot.entity = updated_player.character
                local player = game.get_player(player_index)
                if not player then return end
                ulh_gui.rebuild_table(player, player_data)
            end
        end
    end
end

--- @param player LuaPlayer
--- @param player_data PlayerData
--- @param index integer
local function delete_config_index(player, player_data, index)
    if player_data.edit_slot_index == index then
        ulh_gui.close_edit_window(player, player_data)
    end
    table.remove(player_data.config, index)
    ulh_gui.rebuild_table(player, player_data)
end

-- GUI Event handlers

script.on_event(defines.events.on_gui_click, function(e)
    local player = game.get_player(e.player_index)
    if not player then return end
    if e.element.name == "ulh_expanded_button" then
        local player_data = storage.players[e.player_index]
        player_data.gui.expanded = not player_data.gui.expanded
        ulh_gui.rebuild_table(player, player_data)
    elseif e.element.name == "ulh_label_button" then
        local player_data = storage.players[e.player_index]
        player_data.gui.labeled = not player_data.gui.labeled
        ulh_gui.rebuild_table(player, player_data)
    elseif e.element.name == "ulh_pin_button" then
        local player_data = storage.players[e.player_index]
        player_data.gui.floating = not player_data.gui.floating
        ulh_gui.rebuild_table(player, player_data)
    elseif e.element.name == "ulh_add_shortcut_button" then
        if e.shift then
            add_shortcut(player, nil, player.character)
        else
            local player_data = storage.players[e.player_index]
            if not player.cursor_stack then return end
            ulh_gui.close_edit_window(player, player_data)
            if player.clear_cursor() then
                player.cursor_stack.set_stack { name = "ulh-location-selection-tool", count = 1 }
            end
        end
    elseif e.element.name == "ulh_edit_window_close_button" then
        local player_data = storage.players[e.player_index]
        ulh_gui.close_edit_window(player, player_data)
    elseif e.element.name == "ulh_edit_window_location_button" then
        if not player.cursor_stack then return end
        if player.clear_cursor() then
            player.cursor_stack.set_stack { name = "ulh-location-selection-tool", count = 1 }
        end
    elseif e.element.name == "ulh_edit_window_zoom_max_button" then
        local player_data = storage.players[e.player_index]
        if not player_data.edit_slot_index then return end
        ulh_util.get_editing_slot(player_data).zoom = constants.zoom.world_min
        on_config_update(player)
    elseif e.element.tags.ulh_action == "go_to_location_button" then
        --- @type number
        local config_index = e.element.tags.index --[[@as number]]
        local player_data = storage.players[e.player_index]
        ulh_gui.rebuild_table(player, player_data)
        if e.button == defines.mouse_button_type.left then
            ulh_gui.close_edit_window(player, player_data)
            go_to_location(player, player_data.config[config_index], e.shift, e.control, e.alt)
        elseif e.button == defines.mouse_button_type.right then
            if e.control then
                delete_config_index(player, player_data, config_index)
            else
                go_to_location(player, player_data.config[config_index], false, false, false)
                ulh_gui.open_edit_window(player, config_index)
            end
        end
    end
end)

script.on_event(defines.events.on_gui_checked_state_changed, function(e)
    local player = game.get_player(e.player_index)
    if not player then return end
    local player_data = storage.players[e.player_index]
    if not player_data then return end
    if e.element.name == "ulh_edit_window_zoom_check" then
        ulh_util.get_editing_slot(player_data).use_zoom = e.element.state
        on_config_update(player)
    end
end)

script.on_event(defines.events.on_gui_text_changed, function(e)
    local player = game.get_player(e.player_index)
    if not player then return end
    local player_data = storage.players[e.player_index]
    if not player_data then return end
    if e.element.name == "ulh_edit_window_name_field" then
        ulh_util.get_editing_slot(player_data).caption = e.element.text
        on_config_update(player)
    end
end)

script.on_event(defines.events.on_gui_confirmed, function(e)
    local player = game.get_player(e.player_index)
    if not player then return end
    local player_data = storage.players[e.player_index]
    if not player_data then return end
    if e.element.name == "ulh_edit_window_zoom_field" then
        local zoom = tonumber(e.element.text)
        if not zoom then return end
        zoom = math.min(math.max(zoom, constants.zoom.min), constants.zoom.max)
        ulh_util.get_editing_slot(player_data).zoom = zoom
        on_config_update(player)
    end
end)

script.on_event(defines.events.on_gui_value_changed, function(e)
    local player = game.get_player(e.player_index)
    if not player then return end
    local player_data = storage.players[e.player_index]
    if not player_data then return end
    if e.element.name == "ulh_edit_window_zoom_slider" then
        ulh_util.get_editing_slot(player_data).zoom = e.element.slider_value
        on_config_update(player)
    end
end)

script.on_event(defines.events.on_gui_elem_changed, function(e)
    local player = game.get_player(e.player_index)
    if not player then return end
    local player_data = storage.players[e.player_index]
    if not player_data then return end
    if e.element.name == "ulh_edit_window_entity_button" then
        if e.element.elem_value then
            ulh_util.get_editing_slot(player_data).sprite = "entity/" .. e.element.elem_value
            on_config_update(player)
        end
    elseif e.element.name == "ulh_edit_window_recipe_button" then
        if e.element.elem_value then
            ulh_util.get_editing_slot(player_data).sprite = "recipe/" .. e.element.elem_value
            on_config_update(player)
        end
    elseif e.element.name == "ulh_edit_window_signal_button" then
        local elem = e.element.elem_value
        if elem then
            local sprite
            if not elem.type then
                sprite = "item/" .. elem.name
            elseif elem.type == "virtual" then
                sprite = "virtual-signal/" .. elem.name
            else
                sprite = elem.type .. "/" .. elem.name
            end
            ulh_util.get_editing_slot(player_data).sprite = sprite
            on_config_update(player)
        end
    end
end)

script.on_event(defines.events.on_gui_selection_state_changed, function(e)
    local player = game.get_player(e.player_index)
    if not player then return end
    local player_data = storage.players[e.player_index]
    if not player_data then return end
    local edit_index = player_data.edit_slot_index
    if not edit_index then return end
    local index = e.element.selected_index
    if e.element.name == "ulh_edit_window_index_swap" then
        player_data.config[index], player_data.config[edit_index] = player_data.config[edit_index], player_data.config[index]
        player_data.edit_slot_index = index
        on_config_update(player)
    elseif e.element.name == "ulh_edit_window_index_insert" then
        local slot = table.remove(player_data.config, edit_index)
        table.insert(player_data.config, index, slot)
        player_data.edit_slot_index = index
        on_config_update(player)
    end
end)

script.on_event(defines.events.on_gui_closed, function(e)
    local player = game.get_player(e.player_index)
    if not player then return end
    if e.element and e.element.name == "ulh_edit_window_frame" then
        ulh_gui.close_edit_window(player, storage.players[e.player_index])
    end
end)

--- @param e EventData.on_player_selected_area|EventData.on_player_alt_selected_area
local function on_selection(e)
    if e.item ~= "ulh-location-selection-tool" then return end
    local player = game.get_player(e.player_index)
    if not player then return end
    local player_index = e.player_index
    local player_data = storage.players[player_index]
    if player_data.edit_slot_index then
        -- editing
        local slot = ulh_util.get_editing_slot(player_data)

        ulh_util.create_slot_from_selection(slot, player, e)
        on_config_update(player)
    else
        -- create new
        add_shortcut(player, e)
    end
end

script.on_event(defines.events.on_player_selected_area, function(e)
    on_selection(e)
end)

script.on_event(defines.events.on_player_alt_selected_area, function(e)
    on_selection(e)
end)

script.on_event(defines.events.on_player_changed_surface, function(e)
    local player = game.get_player(e.player_index)
    if not player then return end
    local player_data = storage.players[e.player_index]
    ulh_gui.rebuild_table(player, player_data)
end)

--- @param e EventData.CustomInputEvent
local function on_keyboard_shortcut(e)
    local _, _, capture = string.find(e.input_name, "ulh%-go%-to%-location%-index%-(.+)")
    local index = tonumber(capture) --- @cast index integer
    local player = game.get_player(e.player_index)
    local player_data = storage.players[e.player_index]
    if player and player_data and player_data.config[index] then
        local settings = player.mod_settings
        local follow = settings["ulh-hotkey-starts-follow"].value --[[@as boolean]]
        local pick_remote = settings["ulh-hotkey-picks-remote"].value --[[@as boolean]]
        local remote_drive = settings["ulh-hotkey-remote-drives"].value --[[@as boolean]]
        go_to_location(player, player_data.config[index], follow, pick_remote, remote_drive)
        ulh_gui.rebuild_table(player, player_data)
    end
end

for i = 1, 10 do
    script.on_event("ulh-go-to-location-index-" .. i, on_keyboard_shortcut)
end

--- @param e EventData.CustomInputEvent
local function on_keyboard_shortcut_create_slot(e)
    local _, _, capture = string.find(e.input_name, "ulh%-create%-shortcut%-index%-(.+)")
    local index = tonumber(capture) --- @cast index integer
    local player = game.get_player(e.player_index)
    local player_data = storage.players[e.player_index]
    if player and player_data then
        add_shortcut(player, nil, player.selected, index)
    end
end

for i = 1, 10 do
    script.on_event("ulh-create-shortcut-index-" .. i, on_keyboard_shortcut_create_slot)
end


-- Other Event handlers

script.on_event(defines.events.on_entity_cloned, function(e)
    -- This is likely bad performance when theres a lot of slots/entities being cloned
    -- Maybe can make a map of entities that are being followed the first time this is called?
    for _, player_data in pairs(storage.players) do
        for _, slot in pairs(player_data.config) do
            if slot.entity == e.source or slot.cloned_entity == e.source then
                slot.cloned_entity = e.destination
            end
        end
    end
end)

script.on_event(defines.events.on_player_created, function(e)
    local player = game.get_player(e.player_index)
    if not player then return end
    init_player(player)
end)

script.on_event(defines.events.on_player_removed, function(e)
    storage.players[e.player_index] = nil
end)

script.on_event(defines.events.on_player_joined_game, function(e)
    local player = game.get_player(e.player_index)
    if not player then return end
    update_player_references(player)
end)

script.on_event(defines.events.on_player_respawned, function(e)
    local player = game.get_player(e.player_index)
    if not player then return end
    update_player_references(player)
end)

script.on_event(defines.events.on_runtime_mod_setting_changed, function(e)
    if e.setting == "ulh-setting-number-columns" or e.setting == "ulh-setting-number-columns-labeled" then
        local player = game.get_player(e.player_index)
        if not player then return end
        local player_data = storage.players[e.player_index]
        ulh_gui.rebuild_table(player, player_data)
    end
end)

script.on_init(function()
    for _, player in pairs(game.players) do
        init_player(player)
    end
end)

script.on_configuration_changed(function(e)
    -- Apply any gui changes
    if e.mod_changes["UnitLocationHotkeys"] ~= nil then
        for player_index, player_data in pairs(storage.players) do
            local player = game.get_player(player_index)
            if player then
                if player_data.gui.floating == nil then
                    player_data.gui.floating = false
                end
                ulh_gui.rebuild_table(player, player_data)
            end
        end
    end
end)
