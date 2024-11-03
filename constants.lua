local constants = {}

constants.zoom = {
    max = 3,
    min = 0.01,
    step = 0.001,
    world_min = 0.4, -- Max zoom-out without going to map view
    default = 0.5,
}

return constants