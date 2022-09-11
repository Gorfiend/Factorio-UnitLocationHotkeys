local controller = table.deepcopy(data.raw["spidertron-remote"]["spidertron-remote"])

controller.name = "cls-spidertron-remote-oic"
controller.flags = controller.flags or {}
table.insert(controller.flags, "hidden")
table.insert(controller.flags, "only-in-cursor")

data:extend({ controller,
    {
        type = "selection-tool",
        name = "cls-location-selection-tool",
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
            name = 'cls-go-to-location-index-' .. i,
            key_sequence = "ALT + " .. (i % 10),
            action = 'lua',
            enabled_while_spectating = true,
        }
    })
end
