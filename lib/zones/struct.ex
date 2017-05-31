defmodule Elber.Zones.Struct do
    @enforce_keys [:zone_id, :coordinates, :grid, :grid_size]
    defstruct [
        :zone_id,
        :coordinates,
        :grid,
        :grid_size,
        drivers_in: [],
        drivers_available: [],
        riders: []
    ]
end