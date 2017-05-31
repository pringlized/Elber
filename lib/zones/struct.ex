defmodule Elber.Zones.Struct do
    @enforce_keys [:zone_id, :coordinates, :grid, :grid_size]
    defstruct [
        :zone_id,
        :coordinates,
        :grid,
        :grid_size,
        driver_history: [],
        drivers_in: [],
        drivers_available: [],
        riders: []
    ]
end