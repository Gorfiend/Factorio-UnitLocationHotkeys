local constants = require("constants")
local util = require("util")
local gui = require("gui")

-- Table for each players data
--- @class GlobalData
--- @field players PlayerData[]
--- @field listeners_added boolean
global = {}
global.players = {}
global.listeners_added = false

local events = {}


--- @class PlayerData
--- @field config ConfigSlot[]
--- @field gui PlayerGuiConfig
--- @field edit_slot_index integer? the config index being edited, or nil if no edit
--- @field following_entity LuaEntity? the entity currently being followed
--- @field following_tick uint? the tick entity following started (needed to make breaking out by closing map work right)


--- @class ConfigSlot
-- where to focus
--- @field surface_index uint? If it's a position, what surface
--- @field position MapPosition?
--- @field entity LuaEntity?
--- @field cloned_entity LuaEntity?
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
    local player_data = {}
    global.players[player.index] = player_data
    player_data.gui = {}
    player_data.config = {}
    gui.init_player_gui(player, player_data)
end

--- @param player LuaPlayer
--- @param selection EventData.on_player_selected_area|EventData.on_player_alt_selected_area?
local function add_shortcut(player, selection)
    local player_data = global.players[player.index]

    --- @type ConfigSlot
    local config_slot = {}
    config_slot.use_zoom = false
    -- would really like to get the current player camera zoom/position, but can't...
    config_slot.zoom = constants.zoom.default

    util.fill_slot_from_selection(config_slot, player, selection)

    table.insert(player_data.config, config_slot)
    gui.rebuild_table(player, player_data)
end

--- @param player LuaPlayer
--- @param entity LuaEntity
--- @param pick_remote string
local function do_pick_remote(player, entity, pick_remote)
    if pick_remote == "never" then return end
    if entity.type ~= "spider-vehicle" then return end
    if not player.cursor_stack then return end
    if player.cursor_stack.connected_entity == entity then return end
    if pick_remote == "cursor-empty" and player.cursor_stack.valid_for_read then return end
    if not player.clear_cursor() then return end

    local inv = player.get_main_inventory()
    -- Try to get a connected remote from the inventory
    if inv and inv.get_item_count("spidertron-remote") then
        for i = 1, #inv do
            local stack = inv[i]
            if stack.connected_entity == entity then
                player.cursor_stack.swap_stack(stack)
                player.hand_location = { inventory = inv.index, slot = i --[[@as uint]] }
                return
            end
        end
    end
    -- otherwise create one
    -- TODO add a map option for requiring you to have a remote in your inventory
    if player.is_cursor_empty() then
        player.cursor_stack.set_stack { name = "ulh-spidertron-remote-oic", count = 1 }
        player.cursor_stack.connected_entity = entity
    end
end

--- @param player LuaPlayer
--- @param player_data PlayerData
local function player_stop_follow(player, player_data)
    player_data.following_entity = nil
    gui.update_following(player, player_data)
    events.update_follow_listeners()
end

--- @param player LuaPlayer
--- @param position MapPosition
--- @param zoom double?
local function go_to_location_position(player, position, zoom)
    if (zoom) then
        if zoom < constants.zoom.world_min then
            player.open_map(position, zoom)
        else
            player.zoom_to_world(position, zoom)
        end
    else
        if player.render_mode == defines.render_mode.chart then
            player.open_map(position)
        else -- chart zoomed in or normal
            player.zoom_to_world(position)
        end
    end
end

--- @param player LuaPlayer
--- @param slot ConfigSlot
--- @param pick_remote string?
local function go_to_location(player, slot, pick_remote)
    if not player or not slot then return end
    pick_remote = pick_remote or "never"
    --- @type MapPosition
    local position
    if slot.position then
        position = slot.position
    elseif slot.entity then
        util.update_slot_entity(slot)
        if not slot.entity.valid then
            player.print({ "gui.ulh-entity-not-valid" })
            return
        end
        position = slot.entity.position
        do_pick_remote(player, slot.entity, pick_remote)
    end
    if position == nil then return end -- shouldn't happen...
    local surface = util.get_slot_surface(slot)
    if surface then
        if not surface.valid then
            player.print({ "gui.ulh-surface-not-valid" })
            return
        elseif player.surface ~= surface then
            if remote.interfaces["space-exploration"] then
                -- Space Exploration support - use remove view to (attempt to) go to another surface
                if not remote.call("space-exploration", "remote_view_is_unlocked", {player=player}) then
                    player.print("Must unlock remote view to go to locations on other surfaces")
                    return
                end
                local zone = remote.call("space-exploration", "get_zone_from_surface_index", {
                    surface_index = surface.index,
                })
                if zone == nil then
                    player.print("Can't go to this surface (spaceship?) - Unable to find surface")
                    return
                end
                -- This opens the location in nav view, and not in the map - which prevents follow from working
                -- Probably need to delay this stuff a tick so it happens after to make it work the same
                remote.call("space-exploration", "remote_view_start", {
                    player = player,
                    zone_name = zone.name,
                    position = position,
                    -- location_name = slot.caption,
                    freeze_history = true,
                })
            else
                player.print({ "gui.ulh-cant-go-to-other-surface", surface.name })
                return
            end
        end
    end

    go_to_location_position(player, position, slot.use_zoom and slot.zoom or nil)
end

--- @param player LuaPlayer
--- @param index integer
--- @param pick_remote string?
local function go_to_location_index(player, index, pick_remote)
    go_to_location(player, global.players[player.index].config[index], pick_remote)
end

--- @param player LuaPlayer
local function on_config_update(player)
    gui.refresh_edit_window(player)
    local player_data = global.players[player.index]
    gui.rebuild_table(player, player_data)

    if player_data.edit_slot_index then
        local slot = util.get_editing_slot(player_data)
        if slot then
            go_to_location(player, slot) -- live preview of zoom level
        end
    end
end

--- @param updated_player LuaPlayer
local function update_player_references(updated_player)
    for player_index, player_data in pairs(global.players) do
        for _, slot in pairs(player_data.config) do
            if slot.player == updated_player then
                slot.entity = updated_player.character
                local player = game.get_player(player_index)
                if not player then return end
                gui.rebuild_table(player, player_data)
            end
        end
    end
end

--- @param player LuaPlayer
--- @param player_data PlayerData
--- @param index integer
local function delete_config_index(player, player_data, index)
    if player_data.edit_slot_index == index then
        gui.close_edit_window(player, player_data)
    end
    table.remove(player_data.config, index)
    gui.rebuild_table(player, player_data)
end

--- @param player LuaPlayer
--- @param player_data PlayerData
--- @param index integer
local function player_start_follow(player, player_data, index)
    player_data.following_entity = nil -- Stop any previous follow

    local entity = player_data.config[index].entity
    if entity and entity.valid then
        if player.surface ~= entity.surface then
            return
        end
        player_data.following_entity = entity
        player_data.following_tick = game.tick
    end
    gui.update_following(player, player_data)
    events.update_follow_listeners()
end

local function on_tick_follow()
    for _, player in pairs(game.connected_players) do
        local player_data = global.players[player.index]
        if player_data.following_entity then
            if player_data.following_entity.valid then
                if player_data.following_tick < game.tick then
                    -- Player left map mode, so stop following
                    if player.render_mode == defines.render_mode.game then
                        player_stop_follow(player, player_data)
                    else
                        go_to_location_position(player, player_data.following_entity.position, nil)
                    end
                end
            else
                player_stop_follow(player, player_data)
            end
        end
    end
end

-- GUI Event handlers

script.on_event(defines.events.on_gui_click, function(e)
    local player = game.get_player(e.player_index)
    if not player then return end
    if e.element.name == "ulh_expanded_button" then
        local player_data = global.players[e.player_index]
        player_data.gui.expanded = not player_data.gui.expanded
        gui.rebuild_table(player, player_data)
    elseif e.element.name == "ulh_label_button" then
        local player_data = global.players[e.player_index]
        player_data.gui.labeled = not player_data.gui.labeled
        gui.rebuild_table(player, player_data)
    elseif e.element.name == "ulh_add_shortcut_button" then
        if e.shift then
            add_shortcut(player)
        else
            local player_data = global.players[e.player_index]
            if not player.cursor_stack then return end
            gui.close_edit_window(player, player_data)
            if player.clear_cursor() then
                player.cursor_stack.set_stack { name = "ulh-location-selection-tool", count = 1 }
            end
        end
    elseif e.element.name == "ulh_edit_window_close_button" then
        local player_data = global.players[e.player_index]
        gui.close_edit_window(player, player_data)
    elseif e.element.name == "ulh_edit_window_location_button" then
        if not player.cursor_stack then return end
        if player.clear_cursor() then
            player.cursor_stack.set_stack { name = "ulh-location-selection-tool", count = 1 }
        end
    elseif e.element.name == "ulh_edit_window_zoom_max_button" then
        local player_data = global.players[e.player_index]
        if not player_data.edit_slot_index then return end
        util.get_editing_slot(player_data).zoom = constants.zoom.world_min
        on_config_update(player)
    elseif e.element and e.element.name == "ulh_follow_stop_button" then
        player_stop_follow(player, global.players[e.player_index])
    elseif e.element.tags.ulh_action == "go_to_location_button" then
        --- @type number
        local config_index = e.element.tags.index --[[@as number]]
        local player_data = global.players[e.player_index]
        gui.rebuild_table(player, player_data)
        if e.button == defines.mouse_button_type.left then
            gui.close_edit_window(player, player_data)
            go_to_location_index(player, config_index, e.control and "always" or "never")
            if e.shift then
                player_start_follow(player, player_data, config_index)
            else
                player_stop_follow(player, player_data)
            end
        elseif e.button == defines.mouse_button_type.right then
            if e.control then
                delete_config_index(player, player_data, config_index)
            else
                player_stop_follow(player, player_data)
                gui.open_edit_window(player, config_index)
                go_to_location_index(player, config_index)
            end
        end
    end
end)

script.on_event(defines.events.on_gui_checked_state_changed, function(e)
    local player = game.get_player(e.player_index)
    if not player then return end
    local player_data = global.players[e.player_index]
    if not player_data then return end
    if e.element.name == "ulh_edit_window_zoom_check" then
        util.get_editing_slot(player_data).use_zoom = e.element.state
        on_config_update(player)
    end
end)

script.on_event(defines.events.on_gui_text_changed, function(e)
    local player = game.get_player(e.player_index)
    if not player then return end
    local player_data = global.players[e.player_index]
    if not player_data then return end
    if e.element.name == "ulh_edit_window_name_field" then
        util.get_editing_slot(player_data).caption = e.element.text
        on_config_update(player)
    end
end)

script.on_event(defines.events.on_gui_confirmed, function(e)
    local player = game.get_player(e.player_index)
    if not player then return end
    local player_data = global.players[e.player_index]
    if not player_data then return end
    if e.element.name == "ulh_edit_window_zoom_field" then
        local zoom = tonumber(e.element.text)
        if not zoom then return end
        zoom = math.min(math.max(zoom, constants.zoom.min), constants.zoom.max)
        util.get_editing_slot(player_data).zoom = zoom
        on_config_update(player)
    end
end)

script.on_event(defines.events.on_gui_value_changed, function(e)
    local player = game.get_player(e.player_index)
    if not player then return end
    local player_data = global.players[e.player_index]
    if not player_data then return end
    if e.element.name == "ulh_edit_window_zoom_slider" then
        util.get_editing_slot(player_data).zoom = e.element.slider_value
        on_config_update(player)
    end
end)

script.on_event(defines.events.on_gui_elem_changed, function(e)
    local player = game.get_player(e.player_index)
    if not player then return end
    local player_data = global.players[e.player_index]
    if not player_data then return end
    if e.element.name == "ulh_edit_window_entity_button" then
        if e.element.elem_value then
            util.get_editing_slot(player_data).sprite = "entity/" .. e.element.elem_value
            on_config_update(player)
        end
    elseif e.element.name == "ulh_edit_window_recipe_button" then
        if e.element.elem_value then
            util.get_editing_slot(player_data).sprite = "recipe/" .. e.element.elem_value
            on_config_update(player)
        end
    elseif e.element.name == "ulh_edit_window_signal_button" then
        local elem = e.element.elem_value
        if elem then
            local sprite
            if elem.type == "virtual" then
                sprite = "virtual-signal/" .. elem.name
            else
                sprite = elem.type .. "/" .. elem.name
            end
            util.get_editing_slot(player_data).sprite = sprite
            on_config_update(player)
        end
    end
end)

script.on_event(defines.events.on_gui_selection_state_changed, function(e)
    local player = game.get_player(e.player_index)
    if not player then return end
    local player_data = global.players[e.player_index]
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
        gui.close_edit_window(player, global.players[e.player_index])
    elseif e.element and e.element.name == "ulh_follow_window_frame" then
        player_stop_follow(player, global.players[e.player_index])
    end
end)

--- @param e EventData.on_player_selected_area|EventData.on_player_alt_selected_area
local function on_selection(e)
    if e.item ~= "ulh-location-selection-tool" then return end
    local player = game.get_player(e.player_index)
    if not player then return end
    local player_index = e.player_index
    local player_data = global.players[player_index]
    if player_data.edit_slot_index then
        -- editing
        local slot = util.get_editing_slot(player_data)

        util.fill_slot_from_selection(slot, player, e)
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
    local player_data = global.players[e.player_index]
    gui.rebuild_table(player, player_data)
end)

--- @param e CustomInputEvent
local function on_keyboard_shortcut(e)
    local _, _, capture = string.find(e.input_name, "ulh%-go%-to%-location%-index%-(.+)")
    local index = tonumber(capture) --- @cast index integer
    local player = game.get_player(e.player_index)
    local player_data = global.players[e.player_index]
    if player and player_data and player_data.config[index] then
        player_stop_follow(player, player_data)
        go_to_location(player, player_data.config[index], player.mod_settings["ulh-hotkey-picks-remote"].value --[[@as string]])
        if player.mod_settings["ulh-hotkey-starts-follow"].value then
            player_start_follow(player, player_data, index)
        end
        gui.rebuild_table(player, player_data)
    end
end

for i = 1, 10 do
    script.on_event("ulh-go-to-location-index-" .. i, on_keyboard_shortcut)
end

local function on_input_move(e)
    local player = game.get_player(e.player_index)
    if not player then return end
    local player_data = global.players[e.player_index]
    if player_data.following_entity then
        player_stop_follow(player, player_data)
    end
end


function events.register_follow_listeners()
    script.on_event("ulh-follow-move-up", on_input_move)
    script.on_event("ulh-follow-move-down", on_input_move)
    script.on_event("ulh-follow-move-left", on_input_move)
    script.on_event("ulh-follow-move-right", on_input_move)

    script.on_event(defines.events.on_tick, on_tick_follow)
end

function events.unregister_follow_listeners()
    script.on_event("ulh-follow-move-up", nil)
    script.on_event("ulh-follow-move-down", nil)
    script.on_event("ulh-follow-move-left", nil)
    script.on_event("ulh-follow-move-right", nil)

    script.on_event(defines.events.on_tick, nil)
end

function events.update_follow_listeners()
    local need_added = false
    for index, player_data in pairs(global.players) do
        if player_data.following_entity then
            local player = game.get_player(index)
            if player and player.connected then
                need_added = true
                break
            end
        end
    end
    if global.listeners_added ~= need_added then
        global.listeners_added = need_added
        if need_added then
            events.register_follow_listeners()
        else
            events.unregister_follow_listeners()
        end
    end
end


-- Other Event handlers

script.on_event(defines.events.on_entity_cloned, function(e)
    -- This is likely bad performance when theres a lot of slots/entities being cloned
    -- Maybe can make a map of entities that are being followed the first time this is called?
    for _, player_data in pairs(global.players) do
        for _, slot in pairs(player_data.config) do
            if slot.entity == e.source then
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
    global.players[e.player_index] = nil
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
        local player_data = global.players[e.player_index]
        gui.rebuild_table(player, player_data)
    end
end)

script.on_init(function()
    for _, player in pairs(game.players) do
        init_player(player)
    end
end)

script.on_load(function ()
    if global.listeners_added then
        events.register_follow_listeners()
    end
end)

script.on_configuration_changed(function(e)
    -- Update everyone's table to use the new tooltip
    if e.mod_changes["UnitLocationHotkeys"] ~= nil then
        for player_index, player_data in pairs(global.players) do
            local player = game.get_player(player_index)
            if player then
                gui.rebuild_table(player, player_data)
            end
        end
    end
end)
