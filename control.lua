local mod_gui = require("mod-gui")

local zoom_constants = {
    max = 1.5,
    min = 0.01,
    step = 0.001,
    world_min = 0.3, -- Max zoom-out without going to map view
}

-- Table for each players data
--- @class GlobalData
--- @field players PlayerData[]
global = {}
global.players = {}


--- @class PlayerData
--- @field config ConfigSlot[]
--- @field gui PlayerGuiConfig


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
--- @field slot_index integer
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
        local prefix = ""
        if slot.caption and string.len(slot.caption) > 0 then
            prefix = slot.caption .. "\n"
        end
        table.add {
            type = "sprite-button",
            tooltip = prefix .. "Click to go to this position\nRight-click to edit",
            sprite = slot.sprite,
            number = index,
            tags = {
                cls_action = "go_to_location_button",
                data = slot,
                index = index,
            }
        }
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
local function add_shortcut(player)
    local player_data = global.players[player.index]

    --- @type ConfigSlot
    local config_slot = {}
    -- would really like to get the current player camera zoom/position, but can't...
    config_slot.zoom = zoom_constants.world_min
    config_slot.mode = defines.render_mode.chart_zoomed_in
    config_slot.position = player.position
    config_slot.sprite = "item/radar"
    config_slot.caption = "x=" .. player.position.x .. " y=" .. player.position.y
    table.insert(player_data.config, config_slot)
    rebuild_table(player_data)
end

--- @param player LuaPlayer
--- @param data ConfigSlot
local function go_to_location(player, data)
    local position
    if data.position then
        position = data.position
    elseif data.entity then
        if not data.entity.valid then
            player.print(data.entity.name .. " is no longer valid!")
            return
        end
        position = data.entity.position
    end

    if data.zoom < zoom_constants.world_min then
        player.open_map(data.position, data.zoom)
    else
        player.zoom_to_world(data.position, data.zoom)
    end
end

--- @param player_data PlayerData
local function get_editing_slot(player_data)
    return player_data.config[player_data.gui.edit_window.slot_index]
end

local function refresh_edit_window(player)
    local player_data = global.players[player.index]
    local edit_window_data = player_data.gui.edit_window
    if not edit_window_data then return end

    local slot_data = get_editing_slot(player_data)


    edit_window_data.name_field.text = slot_data.caption

    local _, _, sprite_type, sprite_name = string.find(slot_data.sprite, "(.*)/(.*)")
    if sprite_type == "entity" then
        edit_window_data.entity_button.elem_value = sprite_name
        edit_window_data.recipe_button.elem_value = nil
    elseif sprite_type == "recipe" then
        edit_window_data.entity_button.elem_value = nil
        edit_window_data.recipe_button.elem_value = sprite_name
    end

    edit_window_data.zoom_field.text = tostring(slot_data.zoom)
    edit_window_data.zoom_slider.slider_value = slot_data.zoom

    go_to_location(player, slot_data) -- live preview of zoom level
    rebuild_table(player_data)
end

--- @param player_data PlayerData
local function close_edit_window(player_data)
    if player_data.gui.edit_window then player_data.gui.edit_window.frame.destroy() end
    player_data.gui.edit_window = nil
    player_data.gui.add_shortcut_button.enabled = true
end

--- @param player LuaPlayer
--- @param slot_index integer
local function open_edit_window(player, slot_index)
    local player_data = global.players[player.index]
    close_edit_window(player_data)

    player_data.gui.add_shortcut_button.enabled = false

    player_data.gui.edit_window = {}
    local edit_window_data = player_data.gui.edit_window
    edit_window_data.slot_index = slot_index

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

    refresh_edit_window(player)
end

-- GUI Event handlers
script.on_event(defines.events.on_gui_click, function(e)
    if e.element.name == "cls_add_shortcut_button" then
        -- if e.shift...
        add_shortcut(game.players[e.player_index])
    elseif e.element.tags.cls_action == "go_to_location_button" then
        if e.button == defines.mouse_button_type.left then
            go_to_location(game.players[e.player_index], e.element.tags.data--[[@as ConfigSlot]] )
        else
            open_edit_window(game.players[e.player_index], e.element.tags.index--[[@as number]])
        end
    end
end)

script.on_event(defines.events.on_gui_text_changed, function(e)
    local player_data = global.players[e.player_index]
    if not player_data then return end
    if e.element.name == "cls_edit_window_name_field" then
        get_editing_slot(player_data).caption = e.element.text
        refresh_edit_window(game.players[e.player_index])
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
        refresh_edit_window(game.players[e.player_index])
    end
end)

script.on_event(defines.events.on_gui_value_changed, function(e)
    local player_data = global.players[e.player_index]
    if not player_data then return end
    if e.element.name == "cls_edit_window_zoom_slider" then
        get_editing_slot(player_data).zoom = e.element.slider_value
        refresh_edit_window(game.players[e.player_index])
    end
end)

script.on_event(defines.events.on_gui_elem_changed, function(e)
    local player_data = global.players[e.player_index]
    if not player_data then return end
    if e.element.name == "cls_edit_window_entity_button" then
        get_editing_slot(player_data).sprite = "entity/" .. e.element.elem_value
        refresh_edit_window(game.players[e.player_index])
    elseif e.element.name == "cls_edit_window_recipe_button" then
        get_editing_slot(player_data).sprite = "recipe/" .. e.element.elem_value
        refresh_edit_window(game.players[e.player_index])
    end
end)

script.on_event(defines.events.on_gui_closed, function(event)
    if event.element and event.element.name == "cls_edit_window_frame" then
        close_edit_window(global.players[event.player_index])
    end
end)


-- Other Event handlers

script.on_event(defines.events.on_player_joined_game, function(e)
    game.print("on_player_joined_game")
    init_player(game.players[e.player_index])
end)

script.on_event(defines.events.on_player_removed, function(event)
    global.players[event.player_index] = nil
end)

script.on_init(function()
    game.print("on_init")
    for _, player in pairs(game.players) do
        init_player(player)
    end
end)
