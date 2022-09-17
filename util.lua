local util = {}

--- @param e any
--- @param func fun()
function util.checked_call(e, func)
    local success, result = pcall(func)
    if not success then
        local error_message = "Unhandled error in Camera Location Shortcuts! Please report this to the author: " .. result
        if e.player_index then
            local player = game.players[e.player_index]
            if player then
                player.print(error_message)
                return
            end
        end
        game.print(error_message)
    end
end

--- @param player_data PlayerData
--- @return ConfigSlot
function util.get_editing_slot(player_data)
    return player_data.config[player_data.edit_slot_index]
end

--- @param slot ConfigSlot
--- @return LuaSurface?
function util.get_slot_surface(slot)
    if slot.entity then
        if slot.entity.valid then
            return slot.entity.surface
        else
            return nil
        end
    else
        return game.get_surface(slot.surface_index)
    end
end

--- @param slot ConfigSlot
--- @param player LuaPlayer
--- @param selection EventData.on_player_selected_area|EventData.on_player_alt_selected_area?
function util.fill_slot_from_selection(slot, player, selection)
    if selection and #(selection.entities) > 0 then
        local entity = selection.entities[1]
        slot.surface_index = nil
        slot.entity = entity
        slot.position = nil
        local recipe = util.get_entity_recipe(entity)
        if recipe then
            slot.sprite = "recipe/" .. recipe.name
        else
            slot.sprite = "entity/" .. entity.name
        end
        if not slot.caption then
            if entity.entity_label then
                slot.caption = entity.entity_label
            else
                slot.caption = ""
            end
        end
    else
        local position = player.position
        if selection then
            position = selection.area.left_top
        end
        slot.surface_index = player.surface.index
        slot.position = position
        slot.entity = nil
        slot.sprite = "item/radar"
        if not slot.caption then
            slot.caption = util.position_to_string(position)
        end
    end
end

--- @param position MapPosition
--- @return string
function util.position_to_string(position)
    return "x=" .. position.x .. " y=" .. position.y
end

--- @param entity LuaEntity
--- @return LuaRecipe?
function util.get_entity_recipe(entity)
    if entity.prototype.type == "assembling-machine" then
        return entity.get_recipe()
    elseif entity.prototype.type == "furnace" then
        return entity.get_recipe() or entity.previous_recipe
    end
end

return util
