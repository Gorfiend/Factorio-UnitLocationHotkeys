local mod_gui = require("mod-gui")

local constants = require("constants")
local util = require("util")

--- @class ClsGui
local gui = {}


--- @class PlayerGuiConfig
--- @field expanded boolean
--- @field frame LuaGuiElement
--- @field add_shortcut_button LuaGuiElement?
--- @field edit_window EditWindowConfig
--- @field following_frame LuaGuiElement?


--- @class EditWindowConfig
--- @field frame LuaGuiElement
--- @field name_field LuaGuiElement
--- @field entity_button LuaGuiElement
--- @field recipe_button LuaGuiElement
--- @field signal_button LuaGuiElement
--- @field zoom_slider LuaGuiElement
--- @field zoom_field LuaGuiElement


--- @param player LuaPlayer
--- @param player_data PlayerData
function gui.init_player_gui(player, player_data)
    player_data.gui.expanded = true
    player_data.gui.frame = mod_gui.get_frame_flow(player).add {
        type = "frame",
        style = mod_gui.frame_style,
        direction = "vertical",
    }
    gui.rebuild_table(player_data)
end

--- @param player_data PlayerData
function gui.rebuild_table(player_data)
    local gui_data = player_data.gui
    gui_data.frame.clear()

    local toolbar = gui_data.frame.add {
        type = "flow",
    }
    local title_icon = toolbar.add {
        type = "sprite",
        tooltip = "Camera Location Shortcuts",
        sprite = "item/radar",
    }
    title_icon.style.width = 24
    title_icon.style.height = 24
    title_icon.style.stretch_image_to_widget_size = true
    local expanded_button = toolbar.add {
        type = "sprite-button",
        tooltip = "Expand/collapse the shortcut panel",
        style = "frame_action_button",
        name = "cls_expanded_button",
    }
    if gui_data.expanded then
        expanded_button.sprite = "utility/collapse"
    else
        expanded_button.sprite = "utility/expand"
    end

    if not gui_data.expanded then return end

    local content = gui_data.frame.add {
        type = "frame",
        style = "slot_button_deep_frame",
    }
    local table = content.add {
        type = "table",
        column_count = 5,
        style = "filter_slot_table",
    }

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
- Hold Alt to quick edit the target position/entity
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

    gui_data.add_shortcut_button = table.add {
        type = "sprite-button",
        tooltip = "Add a new shortcut\nHold Shift to immediately add your current location",
        sprite = "utility/add",
        style = "tool_button", -- slot_button_in_shallow_frame    slot_button    slot_button_deep_frame
        name = "cls_add_shortcut_button",
    }
    gui_data.add_shortcut_button.style.margin = 6
    gui_data.add_shortcut_button.enabled = (player_data.edit_slot_index == nil)
end

--- @param player LuaPlayer
--- @param slot_index integer
function gui.open_edit_window(player, slot_index)
    local player_data = global.players[player.index]
    gui.close_edit_window(player_data)

    local slot = player_data.config[slot_index]
    if slot.entity and not slot.entity.valid then
        player.print("Associated entity is no longer valid!")
        return
    end

    if player_data.gui.add_shortcut_button then
        player_data.gui.add_shortcut_button.enabled = false
    end

    player_data.gui.edit_window = {}
    local edit_window_data = player_data.gui.edit_window
    player_data.edit_slot_index = slot_index

    edit_window_data.frame = player.gui.screen.add {
        type = "frame",
        name = "cls_edit_window_frame",
        direction = "vertical",
    }
    edit_window_data.frame.location = { 200, 200 }
    player.opened = edit_window_data.frame

    local titlebar = edit_window_data.frame.add {
        type = "flow",
        direction = "horizontal",
    }
    titlebar.drag_target = edit_window_data.frame

    titlebar.add {
        type = "label",
        style = "frame_title",
        caption = "Edit entry #" .. slot_index,
        ignored_by_interaction = true,
    }

    local spacer = titlebar.add {
        type = "empty-widget",
        style = "draggable_space_header",
        ignored_by_interaction = true,
    }
    spacer.style.height = 24
    spacer.style.horizontally_stretchable = true
    spacer.style.right_margin = 4
    titlebar.add {
        type = "sprite-button",
        name = "cls_edit_window_close_button",
        style = "frame_action_button",
        sprite = "utility/close_white",
        hovered_sprite = "utility/close_black",
        clicked_sprite = "utility/close_black",
    }


    local content_frame = edit_window_data.frame.add {
        type = "frame",
        direction = "vertical",
        style = "inside_shallow_frame_with_padding",
    }
    local controls_table = content_frame.add {
        type = "table",
        column_count = 2,
    }
    controls_table.style.column_alignments[1] = "right"
    controls_table.style.column_alignments[2] = "left"
    controls_table.style.horizontal_spacing = 12
    controls_table.style.vertical_spacing = 12


    controls_table.add {
        type = "label",
        caption = "Name:",
    }
    edit_window_data.name_field = controls_table.add {
        type = "textfield",
        name = "cls_edit_window_name_field",
    }
    edit_window_data.name_field.style.width = 300


    controls_table.add {
        type = "label",
        caption = "Icon:",
    }
    local icon_flow = controls_table.add {
        type = "flow",
    }
    icon_flow.style.vertical_align = "center"
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
    icon_flow.add {
        type = "label",
        caption = "Signal",
    }
    edit_window_data.signal_button = icon_flow.add {
        type = "choose-elem-button",
        name = "cls_edit_window_signal_button",
        elem_type = "signal",
        style = "slot_button_in_shallow_frame",
    }

    controls_table.add {
        type = "label",
        caption = "Location:",
    }
    local location_flow = controls_table.add {
        type = "flow",
    }
    location_flow.style.vertical_align = "center"
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
        caption = "Zoom:",
    }
    local zoom_flow = controls_table.add {
        type = "flow",
    }
    zoom_flow.style.vertical_align = "center"
    edit_window_data.zoom_slider = zoom_flow.add {
        type = "slider",
        name = "cls_edit_window_zoom_slider",
        minimum_value = constants.zoom.min,
        maximum_value = constants.zoom.max,
        value_step = constants.zoom.step,
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
        tooltip = "Set to the most zoomed out possible without changing to map view",
    }

    gui.rebuild_table(global.players[player.index])
    gui.refresh_edit_window(player)
end

--- @param player_data PlayerData
function gui.close_edit_window(player_data)
    if player_data.gui.edit_window then player_data.gui.edit_window.frame.destroy() end
    player_data.edit_slot_index = nil
    player_data.gui.edit_window = nil
    if player_data.gui.add_shortcut_button then
        player_data.gui.add_shortcut_button.enabled = true
    end
end

--- @param player LuaPlayer
function gui.refresh_edit_window(player)
    local player_data = global.players[player.index]
    local edit_window_data = player_data.gui.edit_window
    if not edit_window_data then return end

    local slot_data = util.get_editing_slot(player_data)


    edit_window_data.name_field.text = slot_data.caption or ""

    local _, _, sprite_type, sprite_name = string.find(slot_data.sprite, "(.*)/(.*)")
    if sprite_type == "entity" then
        edit_window_data.entity_button.elem_value = sprite_name
        edit_window_data.recipe_button.elem_value = nil
        edit_window_data.signal_button.elem_value = nil
    elseif sprite_type == "recipe" then
        edit_window_data.entity_button.elem_value = nil
        edit_window_data.recipe_button.elem_value = sprite_name
        edit_window_data.signal_button.elem_value = nil
    elseif sprite_type == "item" or sprite_type == "fluid" or sprite_type == "virtual-signal" then
        edit_window_data.entity_button.elem_value = nil
        edit_window_data.recipe_button.elem_value = nil
        if sprite_type == "virtual-signal" then
            sprite_type = "virtual"
        end
        edit_window_data.signal_button.elem_value = { type = sprite_type, name = sprite_name }
    else
        edit_window_data.entity_button.elem_value = nil
        edit_window_data.recipe_button.elem_value = nil
        edit_window_data.signal_button.elem_value = nil
    end

    if slot_data.position then
        edit_window_data.location_label.caption = util.position_to_string(slot_data.position)
    elseif slot_data.entity and slot_data.entity.valid then
        if slot_data.entity.entity_label then
            edit_window_data.location_label.caption = { "", slot_data.entity.entity_label,
                " (", util.position_to_string(slot_data.entity.position), ")" }
        else
            edit_window_data.location_label.caption = { "", slot_data.entity.localised_name,
                " (", util.position_to_string(slot_data.entity.position), ")" }
        end
    else
        edit_window_data.location_label = nil
    end

    edit_window_data.zoom_field.text = tostring(slot_data.zoom)
    edit_window_data.zoom_slider.slider_value = slot_data.zoom
end

--- @param player LuaPlayer
--- @param player_data PlayerData
function gui.update_following(player, player_data)
    if player_data.following_entity then
        if not player_data.gui.following_frame then
            player_data.gui.following_frame = player.gui.screen.add {
                type = "frame",
                name = "cls_follow_window_frame",
            }
        else
            player_data.gui.following_frame.clear()
        end
        player_data.gui.following_frame.style.padding = 4
        local flow = player_data.gui.following_frame.add {
            type = "flow",
            direction = "horizontal",
        }
        flow.style.vertical_align = "center"

        flow.add {
            type = "label",
            caption = { "", "Following: ", player_data.following_entity.localised_name, " ",
                player_data.following_entity.entity_label }
        }
        local button = flow.add {
            type = "sprite-button",
            name = "cls_follow_stop_button",
            tooltip = "Stop following",
            style = "tool_button",
            sprite = "utility/deconstruction_mark",
        }
        button.style.padding = 0

        player.opened = player_data.gui.following_frame

        player_data.gui.following_frame.location = { x = player.display_resolution.width / 3, y = 50 }
    else
        if player_data.gui.following_frame then
            player_data.gui.following_frame.destroy()
            player_data.gui.following_frame = nil
        end
    end
end

return gui
