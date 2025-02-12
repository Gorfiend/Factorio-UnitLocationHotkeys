data:extend({
    {
        type = "selection-tool",
        name = "ulh-location-selection-tool",
        icon = "__core__/graphics/clone-icon.png",
        icon_size = 32,
        flags = { "not-stackable", "only-in-cursor" },
        hidden = true,
        stack_size = 1,

        select = {
            cursor_box_type = "entity",
            border_color = { r = 0, g = 1, b = 0 },
            mode = { "any-entity", "friend" },
            entity_type_filters = { "spider-leg" },
            entity_filter_mode = "blacklist",
        },

        alt_select = {
            cursor_box_type = "entity",
            border_color = { r = 0, g = 0, b = 1 },
            mode = { "any-entity", "friend" },
            entity_type_filters = { "car", "spider-vehicle",
                "locomotive", "cargo-wagon", "fluid-wagon", "artillery-wagon" },
            entity_filter_mode = "whitelist",
        },

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
            order = string.format('a%02d', i),
        }
    })
end

for i = 1, 10 do
    data:extend({
        {
            type = 'custom-input',
            name = 'ulh-create-shortcut-index-' .. i,
            key_sequence = "CONTROL + ALT + " .. (i % 10),
            action = 'lua',
            enabled_while_spectating = true,
            order = string.format('b%02d', i),
        }
    })
end


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
