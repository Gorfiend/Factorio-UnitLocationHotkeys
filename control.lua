local mod_gui = require("mod-gui")

local zoom_constants = {
    max = 1.5,
    min = 0.01,
    step = 0.001,
    world_min = 0.3, -- Max zoom-out without going to map view
    default = 0.5,
}

-- Table for each players data
--- @class GlobalData
--- @field players PlayerData[]
global = {}
global.players = {}


--- @class PlayerData
--- @field config ConfigSlot[]
--- @field gui PlayerGuiConfig
--- @field edit_slot_index integer? the config index being edited, or nil if no edit


--- @class ConfigSlot
-- where to focus
--- @field position MapPosition?
--- @field entity LuaEntity?
-- TODO surface?
-- what zoom level to go to
--- @field zoom double
--- @field mode defines.render_mode
-- what the button for it looks like
--- @field sprite string?
--- @field caption string?

--- @class PlayerGuiConfig
--- @field table LuaGuiElement
--- @field add_shortcut_button LuaGuiElement
--- @field edit_window EditWindowConfig

--- @class EditWindowConfig
--- @field frame LuaGuiElement
--- @field name_field LuaGuiElement
--- @field entity_button LuaGuiElement
--- @field recipe_button LuaGuiElement
--- @field zoom_slider LuaGuiElement
--- @field zoom_field LuaGuiElement



--- @param player_data PlayerData
local function rebuild_table(player_data)
    local table = player_data.gui.table
    table.clear()

    for index, slot in pairs(player_data.config) do
        --- @type string|LocalisedString
        local prefix = ""
        if slot.caption and slot.caption ~= "" then
            prefix = slot.caption
        elseif slot.entity and slot.entity.valid then
            prefix = slot.entity.entity_label or slot.entity.localised_name
        end
        --- @type string|LocalisedString
        local hotkey = ""
        if (index <= 10) then
            hotkey = { "", "(", { "camera-location-shortcuts-shortcut-tooltip-" .. index }, ")" }
        end
        local button = table.add {
            type = "sprite-button",
            tooltip = { "", prefix, "\n", "Click to go to this position/entity ", hotkey, "\n",
                [[
- Hold Control to pick a remote if the target is a spidertron
Right-click to edit
- Hold Alt to only edit the target position/entity
- Hold Shift and Control to delete]],
            },
            sprite = slot.sprite,
            number = index,
            tags = {
                cls_action = "go_to_location_button",
                index = index,
            }
        }

        if slot.entity and slot.entity.valid then
            local c = slot.entity.color
            if c then
                c.a = 1
                button.caption = "■"
                button.style.font_color = c
                button.style.clicked_font_color = c
                button.style.hovered_font_color = c
                button.style.vertical_align = "top"
                button.style.horizontal_align = "left"
                button.style.top_padding = 0
                button.style.left_padding = 0
            end
        end
    end
end

--- @param player LuaPlayer
local function init_gui(player, gui_data)
    gui_data.frame = mod_gui.get_frame_flow(player).add {
        type = "frame",
        style = mod_gui.frame_style,
    }
    gui_data.add_shortcut_button = gui_data.frame.add {
        type = "button",
        caption = "+",
        -- sprite = "utility-sprites/add",
        style = "frame_action_button",
        name = "cls_add_shortcut_button",
    }
    gui_data.table = gui_data.frame.add {
        type = "table",
        column_count = 4,
    }
end

--- @param player LuaPlayer
local function init_player(player)
    --- @type PlayerData
    local player_data = {}
    global.players[player.index] = player_data
    player_data.gui = {}
    player_data.config = {}
    init_gui(player, player_data.gui)
end

--- @param player LuaPlayer
--- @param selection EventData.on_player_selected_area|EventData.on_player_alt_selected_area?
local function add_shortcut(player, selection)
    local player_data = global.players[player.index]


    --- @type ConfigSlot
    local config_slot = {}
    -- would really like to get the current player camera zoom/position, but can't...
    config_slot.zoom = zoom_constants.default
    config_slot.mode = defines.render_mode.chart_zoomed_in


    -- TODO pull this logic out and share it with the selection direct edit
    if selection and #(selection.entities) > 0 then
        local entity = selection.entities[1]
        config_slot.entity = entity
        config_slot.sprite = "entity/" .. entity.name
        config_slot.caption = ""
    else
        local position = player.position
        if selection then
            position = selection.area.left_top
        end
        config_slot.position = position
        config_slot.sprite = "item/radar"
        config_slot.caption = "x=" .. position.x .. " y=" .. position.y
    end


    table.insert(player_data.config, config_slot)
    rebuild_table(player_data)
end

--- @param player LuaPlayer
--- @param entity LuaEntity
local function do_pick_remote(player, entity)
    if entity.type ~= "spider-vehicle" then return end
    if not player.cursor_stack then return end
    if player.cursor_stack.connected_entity == entity then return end
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
        player.cursor_stack.set_stack { name = "cls-spidertron-remote-oic", count = 1 }
        player.cursor_stack.connected_entity = entity
    end
end

--- @param player LuaPlayer
--- @param data ConfigSlot
--- @param pick_remote boolean?
local function go_to_location(player, data, pick_remote)
    pick_remote = pick_remote or false
    --- @type MapPosition
    local position
    if data.position then
        position = data.position
    elseif data.entity then
        if not data.entity.valid then
            player.print("Associated entity is no longer valid!")
            return
        end
        position = data.entity.position
        if pick_remote then
            do_pick_remote(player, data.entity)
        end
    end
    if position == nil then return end -- shouldn't happen...

    if data.zoom < zoom_constants.world_min then
        player.open_map(position, data.zoom)
    else
        player.zoom_to_world(position, data.zoom)
    end
end

--- @param player LuaPlayer
--- @param index integer
--- @param pick_remote boolean?
local function go_to_location_index(player, index, pick_remote)
    go_to_location(player, global.players[player.index].config[index], pick_remote)
end

--- @param player_data PlayerData
--- @return ConfigSlot
local function get_editing_slot(player_data)
    return player_data.config[player_data.edit_slot_index]
end

--- @param position MapPosition
--- @return string
local function position_to_string(position)
    return "x=" .. position.x .. " y=" .. position.y
end

--- @param player LuaPlayer
local function refresh_edit_window(player)
    local player_data = global.players[player.index]
    local edit_window_data = player_data.gui.edit_window
    if not edit_window_data then return end

    local slot_data = get_editing_slot(player_data)


    edit_window_data.name_field.text = slot_data.caption or ""

    local _, _, sprite_type, sprite_name = string.find(slot_data.sprite, "(.*)/(.*)")
    if sprite_type == "entity" then
        edit_window_data.entity_button.elem_value = sprite_name
        edit_window_data.recipe_button.elem_value = nil
    elseif sprite_type == "recipe" then
        edit_window_data.entity_button.elem_value = nil
        edit_window_data.recipe_button.elem_value = sprite_name
    else
        edit_window_data.entity_button.elem_value = nil
        edit_window_data.recipe_button.elem_value = nil
    end

    if slot_data.position then
        edit_window_data.location_label.caption = position_to_string(slot_data.position)
    elseif slot_data.entity and slot_data.entity.valid then
        if slot_data.entity.entity_label then
            edit_window_data.location_label.caption = { "", slot_data.entity.entity_label,
                " (", position_to_string(slot_data.entity.position), ")" }
        else
            edit_window_data.location_label.caption = { "", slot_data.entity.localised_name,
                " (", position_to_string(slot_data.entity.position), ")" }
        end
    else
        edit_window_data.location_label = nil
    end

    edit_window_data.zoom_field.text = tostring(slot_data.zoom)
    edit_window_data.zoom_slider.slider_value = slot_data.zoom

    go_to_location(player, slot_data) -- live preview of zoom level
end

--- @param player LuaPlayer
local function on_config_update(player)
    refresh_edit_window(player)
    rebuild_table(global.players[player.index])
end

--- @param player_data PlayerData
local function close_edit_window(player_data)
    if player_data.gui.edit_window then player_data.gui.edit_window.frame.destroy() end
    player_data.edit_slot_index = nil
    player_data.gui.edit_window = nil
    player_data.gui.add_shortcut_button.enabled = true
end

--- @param player_data PlayerData
--- @param index integer
local function delete_config_index(player_data, index)
    if player_data.edit_slot_index == index then
        close_edit_window(player_data)
    end
    table.remove(player_data.config, index)
    rebuild_table(player_data)
end

--- @param player LuaPlayer
--- @param slot_index integer
local function open_edit_window(player, slot_index)
    local player_data = global.players[player.index]
    close_edit_window(player_data)

    local slot = player_data.config[slot_index]
    if slot.entity and not slot.entity.valid then
        player.print("Associated entity is no longer valid!")
        return
    end

    player_data.gui.add_shortcut_button.enabled = false

    player_data.gui.edit_window = {}
    local edit_window_data = player_data.gui.edit_window
    player_data.edit_slot_index = slot_index

    edit_window_data.frame = player.gui.screen.add {
        type = "frame",
        name = "cls_edit_window_frame",
        caption = "Edit entry",
    }
    edit_window_data.frame.location = { 200, 200 }

    player.opened = edit_window_data.frame


    local content_frame = edit_window_data.frame.add {
        type = "frame",
        direction = "vertical",
        style = "inside_shallow_frame_with_padding",
    }
    local controls_table = content_frame.add {
        type = "table",
        column_count = 2,
    }


    controls_table.add {
        type = "label",
        caption = "Name",
    }
    edit_window_data.name_field = controls_table.add {
        type = "textfield",
        name = "cls_edit_window_name_field",
    }
    edit_window_data.name_field.style.natural_width = 300


    controls_table.add {
        type = "label",
        caption = "Icon",
    }
    local icon_flow = controls_table.add {
        type = "flow",
    }
    icon_flow.add {
        type = "label",
        caption = "Entity",
    }
    edit_window_data.entity_button = icon_flow.add {
        type = "choose-elem-button",
        name = "cls_edit_window_entity_button",
        elem_type = "entity",
        style = "slot_button_in_shallow_frame",
    }
    icon_flow.add {
        type = "label",
        caption = "Recipe",
    }
    edit_window_data.recipe_button = icon_flow.add {
        type = "choose-elem-button",
        name = "cls_edit_window_recipe_button",
        elem_type = "recipe",
        style = "slot_button_in_shallow_frame",
    }

    controls_table.add {
        type = "label",
        caption = "Location",
    }
    local location_flow = controls_table.add {
        type = "flow",
    }
    edit_window_data.location_label = location_flow.add {
        type = "label",
    }
    edit_window_data.location_button = location_flow.add {
        type = "button",
        name = "cls_edit_window_location_button",
        caption = "Change..."
    }

    controls_table.add {
        type = "label",
        caption = "Zoom",
    }
    local zoom_flow = controls_table.add {
        type = "flow",
    }
    edit_window_data.zoom_slider = zoom_flow.add {
        type = "slider",
        name = "cls_edit_window_zoom_slider",
        minimum_value = zoom_constants.min,
        maximum_value = zoom_constants.max,
        value_step = zoom_constants.step,
    }
    edit_window_data.zoom_field = zoom_flow.add {
        type = "textfield",
        name = "cls_edit_window_zoom_field",
        numeric = true,
        allow_decimal = true,
        allow_negative = false,
    }
    edit_window_data.zoom_field.style.width = 60
    edit_window_data.zoom_max_button = zoom_flow.add {
        type = "button",
        name = "cls_edit_window_zoom_max_button",
        caption = "Max world zoom",
        tooltip = "The most zoomed out possible without changing to map view",
    }

    refresh_edit_window(player)
end

-- GUI Event handlers

script.on_event(defines.events.on_gui_click, function(e)
    if e.element.name == "cls_add_shortcut_button" then
        if e.shift then
            add_shortcut(game.players[e.player_index])
        else
            local player = game.players[e.player_index]
            local player_data = global.players[e.player_index]
            if not player.cursor_stack then return end
            close_edit_window(player_data)
            if player.clear_cursor() then
                player.cursor_stack.set_stack { name = "cls-location-selection-tool", count = 1 }
            end
        end
    elseif e.element.name == "cls_edit_window_location_button" then
        local player = game.players[e.player_index]
        if not player.cursor_stack then return end
        if player.clear_cursor() then
            player.cursor_stack.set_stack { name = "cls-location-selection-tool", count = 1 }
        end
    elseif e.element.name == "cls_edit_window_zoom_max_button" then
        local player = game.players[e.player_index]
        local player_data = global.players[e.player_index]
        if not player_data.edit_slot_index then return end
        get_editing_slot(player_data).zoom = zoom_constants.world_min
        on_config_update(player)
    elseif e.element.tags.cls_action == "go_to_location_button" then
        --- @type number
        local config_index = e.element.tags.index --[[@as number]]
        if e.button == defines.mouse_button_type.left then
            go_to_location_index(game.players[e.player_index], config_index, e.control)
        elseif e.button == defines.mouse_button_type.right then
            if e.alt then
                local player = game.players[e.player_index]
                local player_data = global.players[e.player_index]
                close_edit_window(player_data)
                player_data.edit_slot_index = config_index
                if player.clear_cursor() then
                    player.cursor_stack.set_stack { name = "cls-location-selection-tool", count = 1 }
                end
            elseif e.shift and e.control then
                local player_data = global.players[e.player_index]
                delete_config_index(player_data, config_index)
            else
                open_edit_window(game.players[e.player_index], config_index)
            end
        end
    end
end)

script.on_event(defines.events.on_gui_text_changed, function(e)
    local player_data = global.players[e.player_index]
    if not player_data then return end
    if e.element.name == "cls_edit_window_name_field" then
        get_editing_slot(player_data).caption = e.element.text
        on_config_update(game.players[e.player_index])
    end
end)

script.on_event(defines.events.on_gui_confirmed, function(e)
    local player_data = global.players[e.player_index]
    if not player_data then return end
    if e.element.name == "cls_edit_window_zoom_field" then
        local zoom = tonumber(e.element.text)
        if not zoom then return end
        zoom = math.min(math.max(zoom, zoom_constants.min), zoom_constants.max)
        get_editing_slot(player_data).zoom = zoom
        on_config_update(game.players[e.player_index])
    end
end)

script.on_event(defines.events.on_gui_value_changed, function(e)
    local player_data = global.players[e.player_index]
    if not player_data then return end
    if e.element.name == "cls_edit_window_zoom_slider" then
        get_editing_slot(player_data).zoom = e.element.slider_value
        on_config_update(game.players[e.player_index])
    end
end)

script.on_event(defines.events.on_gui_elem_changed, function(e)
    local player_data = global.players[e.player_index]
    if not player_data then return end
    if e.element.name == "cls_edit_window_entity_button" then
        if e.element.elem_value then
            get_editing_slot(player_data).sprite = "entity/" .. e.element.elem_value
            on_config_update(game.players[e.player_index])
        end
    elseif e.element.name == "cls_edit_window_recipe_button" then
        if e.element.elem_value then
            get_editing_slot(player_data).sprite = "recipe/" .. e.element.elem_value
            on_config_update(game.players[e.player_index])
        end
    end
end)

script.on_event(defines.events.on_gui_closed, function(e)
    if e.element and e.element.name == "cls_edit_window_frame" then
        close_edit_window(global.players[e.player_index])
    end
end)

--- @param e EventData.on_player_selected_area|EventData.on_player_alt_selected_area
local function on_selection(e)
    local player_index = e.player_index
    if e.item ~= "cls-location-selection-tool" or not player_index then return end
    local player = game.players[player_index]
    local player_data = global.players[player_index]
    if player_data.edit_slot_index then
        -- editing
        local slot = get_editing_slot(player_data)

        if #(e.entities) > 0 then
            --- @type LuaEntity
            local entity = e.entities[1]
            slot.position = nil
            slot.entity = entity
            slot.sprite = "entity/" .. entity.name
        else
            local position = e.area.left_top
            slot.entity = nil
            slot.position = position
            slot.sprite = "item/radar"
        end
        on_config_update(player)
    else
        -- create new
        add_shortcut(game.players[player_index], e)
    end
end

script.on_event(defines.events.on_player_selected_area, function(e)
    on_selection(e)
end)

script.on_event(defines.events.on_player_alt_selected_area, function(e)
    on_selection(e)
end)

--- @param e CustomInputEvent
local function on_keyboard_shortcut(e)
    local _, _, capture = string.find(e.input_name, "cls%-go%-to%-location%-index%-(.+)")
    local index = tonumber(capture)
    local player = game.players[e.player_index]
    local player_data = global.players[e.player_index]
    if player_data and player_data.config[index] then
        -- TODO make a user pref for whether to grab a remote?
        go_to_location(player, player_data.config[index], true)
    end
end

for i = 1, 10 do
    script.on_event("cls-go-to-location-index-" .. i, on_keyboard_shortcut)
end


-- Other Event handlers

script.on_event(defines.events.on_player_joined_game, function(e)
    game.print("on_player_joined_game")
    init_player(game.players[e.player_index])
end)

script.on_event(defines.events.on_player_removed, function(event)
    global.players[event.player_index] = nil
end)

script.on_init(function()
    for _, player in pairs(game.players) do
        init_player(player)
    end
end)
