local mod_gui = require("mod-gui")

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



--- @param player_data PlayerData
local function rebuild_table(player_data)
    local table = player_data.gui.table
    table.clear()
    for _, slot in pairs(player_data.config) do
        table.add {
            type = "sprite-button",
            caption = slot.caption .. "\nClick to go to this position\nRight-click to edit",
            sprite = slot.sprite,
            tags = {
                cls_action = "go_to_location_button",
                data = slot,
            }
        }
    end
end

--- @param player LuaPlayer
local function init_gui(player, gui_data)
    gui_data.frame = player.gui.left.add {
        type = "frame"
    }
    gui_data.add_shortcut_button = gui_data.frame.add {
        type = "button",
        caption = "+",
        -- sprite = "utility-sprites/add",
        style = "frame_action_button",
        name = "cls_add_shortcut_button"
    }
    gui_data.table = gui_data.frame.add {
        type = "table",
        column_count = 4
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
    config_slot.zoom = 0.3 -- zoom level it switches to world view when zooming in on the map
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
    if data.position then
        if data.mode == defines.render_mode.chart then
            player.open_map(data.position, data.zoom)
        else
            player.zoom_to_world(data.position, data.zoom)
        end
    elseif data.entity then
        if not data.entity.valid then
            player.print(data.entity.name .. " is no longer valid!")
            return
        end
    end
end

--- @param player LuaPlayer
--- @param data ConfigSlot
local function open_edit_window(player, data)
end

-- GUI Event handlers
script.on_event(defines.events.on_gui_click, function(e)
    if e.element.name == "cls_add_shortcut_button" then
        -- if e.shift...
        add_shortcut(game.players[e.player_index])
    elseif e.element.tags.cls_action == "cls_go_to_location_button" then
        if e.button == defines.mouse_button_type.left then
            go_to_location(game.players[e.player_index], e.element.tags.data--[[@as ConfigSlot]] )
        else
            open_edit_window(game.players[e.player_index], e.element.tags.data--[[@as ConfigSlot]] )
        end
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
