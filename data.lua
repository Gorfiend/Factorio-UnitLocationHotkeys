local controller = table.deepcopy(data.raw["spidertron-remote"]["spidertron-remote"])

controller.name = "ulh-spidertron-remote-oic"
controller.flags = controller.flags or {}
table.insert(controller.flags, "hidden")
table.insert(controller.flags, "only-in-cursor")

data:extend({ controller,
    {
        type = "selection-tool",
        name = "ulh-location-selection-tool",
        icon = "__core__/graphics/clone-icon.png",
        icon_size = 32,
        flags = { "hidden", "not-stackable", "only-in-cursor" },
        stack_size = 1,

        selection_cursor_box_type = "entity",
        selection_color = { r = 0, g = 1, b = 0 },
        selection_mode = { "any-entity", "friend" },
        entity_type_filters = { "spider-leg" },
        entity_filter_mode = "blacklist",

        alt_selection_cursor_box_type = "entity",
        alt_selection_color = { r = 0, g = 0, b = 1 },
        alt_selection_mode = { "any-entity", "friend" },
        alt_entity_type_filters = { "car", "spider-vehicle",
            "locomotive", "cargo-wagon", "fluid-wagon", "artillery-wagon" },
        alt_entity_filter_mode = "whitelist",
    }
})

for i = 1, 10 do
    data:extend({
        {
            type = 'custom-input',
            name = 'ulh-go-to-location-index-' .. i,
            key_sequence = "ALT + " .. (i % 10),
            action = 'lua',
            enabled_while_spectating = true,
        }
    })
end


data:extend({ controller,
    {
        type = "custom-input",
        name = "ulh-follow-move-up",
        key_sequence = "",
        linked_game_control = "move-up",
        action = "lua",
    },
    {
        type = "custom-input",
        name = "ulh-follow-move-down",
        key_sequence = "",
        linked_game_control = "move-down",
        action = "lua",
    },
    {
        type = "custom-input",
        name = "ulh-follow-move-left",
        key_sequence = "",
        linked_game_control = "move-left",
        action = "lua",
    },
    {
        type = "custom-input",
        name = "ulh-follow-move-right",
        key_sequence = "",
        linked_game_control = "move-right",
        action = "lua",
    },
})

-- Taken from flib
data.raw["gui-style"].default.ulh_selected_frame_action_button = {
    type = "button_style",
    parent = "frame_action_button",
    default_font_color = _ENV.button_hovered_font_color,
    default_graphical_set = {
        base = { position = { 225, 17 }, corner_size = 8 },
        shadow = { position = { 440, 24 }, corner_size = 8, draw_type = "outer" },
    },
    hovered_font_color = _ENV.button_hovered_font_color,
    hovered_graphical_set = {
        base = { position = { 369, 17 }, corner_size = 8 },
        shadow = { position = { 440, 24 }, corner_size = 8, draw_type = "outer" },
    },
    clicked_font_color = _ENV.button_hovered_font_color,
    clicked_graphical_set = {
        base = { position = { 352, 17 }, corner_size = 8 },
        shadow = { position = { 440, 24 }, corner_size = 8, draw_type = "outer" },
    },
}
