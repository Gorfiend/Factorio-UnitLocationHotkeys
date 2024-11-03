local mod_gui = require("mod-gui")

local constants = require("constants")
local ulh_util = require("ulh_util")

--- @class UlhGui
local ulh_gui = {}


--- @class PlayerGuiConfig
--- @field expanded boolean
--- @field labeled boolean
--- @field frame LuaGuiElement
--- @field add_shortcut_button LuaGuiElement?
--- @field edit_window EditWindowConfig


--- @class EditWindowConfig
--- @field frame LuaGuiElement
--- @field title_label LuaGuiElement
--- @field drop_down_swap LuaGuiElement
--- @field drop_down_insert LuaGuiElement
--- @field name_field LuaGuiElement
--- @field entity_button LuaGuiElement
--- @field recipe_button LuaGuiElement
--- @field signal_button LuaGuiElement
--- @field zoom_check LuaGuiElement
--- @field zoom_slider LuaGuiElement
--- @field zoom_field LuaGuiElement
--- @field zoom_max_button LuaGuiElement


--- @param player LuaPlayer
--- @param player_data PlayerData
function ulh_gui.init_player_gui(player, player_data)
    player_data.gui.expanded = true
    ulh_gui.create_frame(player, player_data)
end

--- @param player LuaPlayer
--- @param player_data PlayerData
function ulh_gui.create_frame(player, player_data)
    player_data.gui.frame = mod_gui.get_frame_flow(player).add {
        type = "frame",
        style = mod_gui.frame_style,
        direction = "vertical",
    }
    ulh_gui.rebuild_table(player, player_data)
end

--- @param player LuaPlayer
--- @param player_data PlayerData
function ulh_gui.rebuild_table(player, player_data)
    local gui_data = player_data.gui
    if not (gui_data.frame and gui_data.frame.valid) then
        -- Something invalidated our frame... recreate it from scratch
        ulh_gui.create_frame(player, player_data)
        return
    end
    gui_data.frame.clear()

    local toolbar = gui_data.frame.add {
        type = "flow",
    }
    local title_icon = toolbar.add {
        type = "sprite",
        tooltip = "Unit/Location Shortcuts",
        sprite = "item/radar",
    }
    title_icon.style.width = 24
    title_icon.style.height = 24
    title_icon.style.stretch_image_to_widget_size = true

    local expanded_button = toolbar.add {
        type = "sprite-button",
        tooltip = "Expand/collapse the shortcut panel",
        style = "frame_action_button",
        name = "ulh_expanded_button",
    }
    if gui_data.expanded then
        expanded_button.sprite = "utility/collapse"
    else
        expanded_button.sprite = "utility/expand"
    end

    if not gui_data.expanded then return end

    local label_button = toolbar.add {
        type = "button",
        caption = "T",
        tooltip = "Show labels under buttons",
        style = "frame_action_button",
        name = "ulh_label_button",
    }
    if gui_data.labeled then
        label_button.style = "ulh_selected_frame_action_button"
    end

    local content = gui_data.frame.add {
        type = "frame",
        style = "slot_button_deep_frame",
    }
    local column_count = player.mod_settings["ulh-setting-number-columns"].value
    if gui_data.labeled and player.mod_settings["ulh-setting-number-columns-labeled"].value > 0 then
        column_count = player.mod_settings["ulh-setting-number-columns-labeled"].value
    end
    ---@cast column_count integer
    local table = content.add {
        type = "table",
        column_count = column_count,
        style = "filter_slot_table",
    }
    -- Is there a way to set a default alignment, instead of setting each index?
    for i = 1, column_count do
        table.style.column_alignments[i] = "center"
    end

    for index, slot in pairs(player_data.config) do
        --- @type string|LocalisedString
        local prefix = ""
        ulh_util.update_slot_entity(slot)
        if slot.caption and slot.caption ~= "" then
            prefix = slot.caption .. "\n"
        elseif slot.entity and slot.entity.valid then
            prefix = { "", slot.entity.entity_label or slot.entity.localised_name, "\n" }
        end
        --- @type string|LocalisedString
        local hotkey = ""
        if (index <= 10) then
            hotkey = { "", "(", { "unit-location-hotkeys-shortcut-tooltip-" .. index }, ")" }
        end
        local style
        local tooltip
        local surface = ulh_util.get_slot_surface(slot)
        if slot.entity and not slot.entity.valid then
            if slot.player and slot.player.valid then
                style = "red_slot_button"
                tooltip = { "", prefix, { "gui.ulh-entity-not-valid" }, "\n", "May need to wait for player to respawn or rejoin", "\n", "Control + Right-click to delete" }
            else
                style = "red_slot_button"
                tooltip = { "", prefix, { "gui.ulh-entity-not-valid" }, "\n", "Control + Right-click to delete" }
            end
        elseif not surface then
            style = "red_slot_button"
            tooltip = { "", prefix, { "gui.ulh-surface-not-valid" }, "\n", "Control + Right-click to delete" }
        else
            style = "slot_button"
            tooltip = { "", prefix, "Click to go to this position/entity ", hotkey, "\n", [[
- Hold Control to pick a remote if the target is a spidertron
- Hold Shift to follow the entity
Right-click to edit
- Hold Control to delete]],
            }
        end
        local button_panel = table.add {
            type = "flow",
            direction = "vertical",
        }
        button_panel.style.vertical_spacing = 0
        button_panel.style.horizontal_align = "center"
        local button = button_panel.add {
            type = "sprite-button",
            tooltip = tooltip,
            style = style,
            number = index,
            tags = {
                ulh_action = "go_to_location_button",
                index = index,
            }
        }
        if helpers.is_valid_sprite_path(slot.sprite) then
            button.sprite = slot.sprite
        end

        local color = nil
        if slot.player and slot.player.valid then
            color = slot.player.color
        elseif slot.entity and slot.entity.valid and slot.entity.color then
            color = slot.entity.color
        end
        if color then
            color.a = 1
            button.caption = "■"
            button.style.font_color = color
            button.style.clicked_font_color = color
            button.style.hovered_font_color = color
            button.style.vertical_align = "top"
            button.style.horizontal_align = "left"
            button.style.top_padding = 0
            button.style.left_padding = 0
        end
        if gui_data.labeled then
            local label = button_panel.add {
                type = "label",
                caption = slot.caption,
            }
            -- Ensure space between labels
            label.style.left_padding = 4
            label.style.right_padding = 4
        end
    end

    gui_data.add_shortcut_button = table.add {
        type = "sprite-button",
        tooltip = { "gui.ulh-add-shortcut-tooltip", },
        sprite = "utility/add",
        style = "tool_button", -- slot_button_in_shallow_frame    slot_button    slot_button_deep_frame
        name = "ulh_add_shortcut_button",
    }
    gui_data.add_shortcut_button.style.margin = 6
    gui_data.add_shortcut_button.enabled = (player_data.edit_slot_index == nil)
end

--- @param player LuaPlayer
--- @param slot_index integer
function ulh_gui.open_edit_window(player, slot_index)
    local player_data = storage.players[player.index]
    ulh_gui.close_edit_window(player, player_data)

    local slot = player_data.config[slot_index]
    if slot.entity and not slot.entity.valid then
        player.print({ "gui.ulh-entity-not-valid" })
        return
    end

    if player_data.gui.add_shortcut_button then
        player_data.gui.add_shortcut_button.enabled = false
    end

    ---@diagnostic disable-next-line:missing-fields
    player_data.gui.edit_window = {}
    ---@class EditWindowConfig
    local edit_window_data = player_data.gui.edit_window
    player_data.edit_slot_index = slot_index

    edit_window_data.frame = player.gui.screen.add {
        type = "frame",
        name = "ulh_edit_window_frame",
        direction = "vertical",
    }
    edit_window_data.frame.location = { 400, 200 }
    player.opened = edit_window_data.frame

    local titlebar = edit_window_data.frame.add {
        type = "flow",
        direction = "horizontal",
    }
    titlebar.drag_target = edit_window_data.frame

    edit_window_data.title_label = titlebar.add {
        type = "label",
        style = "frame_title",
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
        name = "ulh_edit_window_close_button",
        style = "frame_action_button",
        sprite = "utility/close",
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
        caption = "Change index:",
    }
    local index_flow = controls_table.add {
        type = "flow",
    }
    index_flow.style.vertical_align = "center"
    local index_items = {}
    for i = 1, #(player_data.config) do
        index_items[i] = tostring(i)
    end
    index_flow.add {
        type = "label",
        caption = "Swap",
        tooltip = "Swap positions of this slot with the on at the selected index",
    }
    edit_window_data.drop_down_swap = index_flow.add {
        type = "drop-down",
        name = "ulh_edit_window_index_swap",
        items = index_items,
    }
    index_flow.add {
        type = "label",
        caption = "Insert",
        tooltip = "Insert this slot at the selected index, shifting others over",
    }
    edit_window_data.drop_down_insert = index_flow.add {
        type = "drop-down",
        name = "ulh_edit_window_index_insert",
        items = index_items,
    }


    controls_table.add {
        type = "label",
        caption = "Name:",
    }
    edit_window_data.name_field = controls_table.add {
        type = "textfield",
        name = "ulh_edit_window_name_field",
        icon_selector = true,
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
        name = "ulh_edit_window_entity_button",
        elem_type = "entity",
        style = "slot_button_in_shallow_frame",
    }
    icon_flow.add {
        type = "label",
        caption = "Recipe",
    }
    edit_window_data.recipe_button = icon_flow.add {
        type = "choose-elem-button",
        name = "ulh_edit_window_recipe_button",
        elem_type = "recipe",
        style = "slot_button_in_shallow_frame",
    }
    icon_flow.add {
        type = "label",
        caption = "Signal",
    }
    edit_window_data.signal_button = icon_flow.add {
        type = "choose-elem-button",
        name = "ulh_edit_window_signal_button",
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
        name = "ulh_edit_window_location_button",
        caption = "Change..."
    }

    edit_window_data.zoom_check = controls_table.add {
        type = "checkbox",
        name = "ulh_edit_window_zoom_check",
        caption = "Zoom:",
        state = false,
    }
    local zoom_flow = controls_table.add {
        type = "flow",
    }
    zoom_flow.style.vertical_align = "center"
    edit_window_data.zoom_slider = zoom_flow.add {
        type = "slider",
        name = "ulh_edit_window_zoom_slider",
        minimum_value = constants.zoom.min,
        maximum_value = constants.zoom.max,
        value_step = constants.zoom.step,
    }
    edit_window_data.zoom_field = zoom_flow.add {
        type = "textfield",
        name = "ulh_edit_window_zoom_field",
        numeric = true,
        allow_decimal = true,
        allow_negative = false,
    }
    edit_window_data.zoom_field.style.width = 60
    edit_window_data.zoom_max_button = zoom_flow.add {
        type = "button",
        name = "ulh_edit_window_zoom_max_button",
        caption = "Max world zoom",
        tooltip = "Set to the most zoomed out possible without changing to map view",
    }

    ulh_gui.rebuild_table(player, storage.players[player.index])
    ulh_gui.refresh_edit_window(player)
end

--- @param player LuaPlayer
--- @param player_data PlayerData
function ulh_gui.close_edit_window(player, player_data)
    if player_data.gui.edit_window then
        player_data.gui.edit_window.frame.destroy()
        local stack = player.cursor_stack
        if stack and stack.valid_for_read and stack.name == "ulh-location-selection-tool" then
            stack.clear()
        end
    end
    player_data.edit_slot_index = nil
    player_data.gui.edit_window = nil
    if player_data.gui.add_shortcut_button then
        player_data.gui.add_shortcut_button.enabled = true
    end
end

--- @param player LuaPlayer
function ulh_gui.refresh_edit_window(player)
    local player_data = storage.players[player.index]
    local edit_window_data = player_data.gui.edit_window
    if not edit_window_data then return end

    local slot_data = ulh_util.get_editing_slot(player_data)


    edit_window_data.title_label.caption = "Edit entry #" .. player_data.edit_slot_index

    edit_window_data.drop_down_swap.selected_index = player_data.edit_slot_index --[[@as uint]]
    edit_window_data.drop_down_insert.selected_index = player_data.edit_slot_index --[[@as uint]]

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
    elseif sprite_type == "item" or sprite_type == "fluid" or sprite_type == "virtual-signal" or sprite_type == "space-location" or sprite_type == "asteroid-chunk" or sprite_type == "quality" then
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
        edit_window_data.location_label.caption = ulh_util.position_to_string(slot_data.position)
    elseif slot_data.entity and slot_data.entity.valid then
        if slot_data.entity.entity_label then
            edit_window_data.location_label.caption = { "", slot_data.entity.entity_label,
                " (", ulh_util.position_to_string(slot_data.entity.position), ")" }
        else
            edit_window_data.location_label.caption = { "", slot_data.entity.localised_name,
                " (", ulh_util.position_to_string(slot_data.entity.position), ")" }
        end
    else
        edit_window_data.location_label = nil
    end

    edit_window_data.zoom_check.state = slot_data.use_zoom
    edit_window_data.zoom_field.text = tostring(slot_data.zoom)
    edit_window_data.zoom_slider.slider_value = slot_data.zoom
    edit_window_data.zoom_field.enabled = slot_data.use_zoom
    edit_window_data.zoom_slider.enabled = slot_data.use_zoom
    edit_window_data.zoom_max_button.enabled = slot_data.use_zoom
end

return ulh_gui
