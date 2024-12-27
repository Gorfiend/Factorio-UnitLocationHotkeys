local ulh_util = {}

--- @param player_data PlayerData
--- @return ConfigSlot
function ulh_util.get_editing_slot(player_data)
    return player_data.config[player_data.edit_slot_index]
end

--- @param slot ConfigSlot
--- @return LuaSurface?
function ulh_util.get_slot_surface(slot)
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
function ulh_util.fill_slot_from_selection(slot, player, selection)
    slot.player = nil
    if selection and #(selection.entities) > 0 then
        local entity = selection.entities[1]
        local is_character = entity.prototype.type == 'character'
        slot.surface_index = nil
        slot.entity = entity
        slot.position = nil
        if is_character and entity.player then
            slot.player = entity.player
        end
        local recipe_name = ulh_util.get_entity_recipe(entity)
        if recipe_name then
            slot.sprite = "recipe/" .. recipe_name
        else
            slot.sprite = "entity/" .. entity.name
        end
        if not slot.caption then
            if entity.entity_label then
                slot.caption = entity.entity_label
            elseif is_character and entity.player then
                slot.caption = entity.player.name
            else
                slot.caption = ""
            end
        end
    else
        local position = player.position
        if selection then
            position = selection.area.left_top
        end
        local surface = player.surface
        slot.surface_index = surface.index
        slot.position = position
        slot.entity = nil
        slot.sprite = "item/radar"
        if surface.planet then
            local path = "space-location/" .. surface.planet.name
            if helpers.is_valid_sprite_path(path) then
                slot.sprite = path
            end
        elseif surface.platform then
            local path = "entity/space-platform-hub"
            if helpers.is_valid_sprite_path(path) then
                slot.sprite = path
            end
        end
        if not slot.caption then
            slot.caption = ulh_util.position_to_string(position)
        end
    end
end

--- @param position MapPosition
--- @return string
function ulh_util.position_to_string(position)
    return "x=" .. string.format("%.0f", position.x) .. " y=" .. string.format("%.0f", position.y)
end

--- @param entity LuaEntity
--- @return string?
function ulh_util.get_entity_recipe(entity)
    local recipe
    if entity.prototype.type == "assembling-machine" then
        recipe = entity.get_recipe()
    elseif entity.prototype.type == "furnace" then
        if entity.get_recipe() then
            recipe = entity.get_recipe()
        end
        if entity.previous_recipe then
            recipe = entity.previous_recipe.name
        end
    end
    if recipe then
        if type(recipe) == "string" then
            return recipe
        end
        if recipe.name then
            return recipe.name
        end
    end
end

function ulh_util.update_slot_entity(slot)
    -- Change the slot entity to be the cloned entity, if needed/possible
    if slot.entity and not slot.entity.valid then
        if slot.cloned_entity and slot.cloned_entity.valid then
            slot.entity = slot.cloned_entity
            slot.cloned_entity = nil
        end
    end
end


return ulh_util
