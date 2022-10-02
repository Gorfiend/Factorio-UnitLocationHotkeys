data:extend({
    {
        type = "string-setting",
        name = "cls-hotkey-picks-remote",
        setting_type = "runtime-per-user",
        default_value = "always",
        allowed_values = { "always", "cursor-empty", "never" },
        order = "a",
    },
    {
        type = "bool-setting",
        name = "cls-hotkey-starts-follow",
        setting_type = "runtime-per-user",
        default_value = false,
        order = "b",
    },
})
