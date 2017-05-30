defmodule Elber.Zones.Utils do
    @moduledoc """
    Zone Utilities
    """
    
    def calc_adjacent_coords({x, y}) do
        [
            {x-1, y},   # north
            {x-1, y+1}, # northeast
            {x, y+1},   # east
            {x+1, y+1}, # southeast
            {x+1, y},   # south
            {x+1, y-1}, # southwest
            {x, y-1},   # west
            {x-1, y-1}, # northwest   
        ]
    end

    def get_zone_name(coordinates, grid_size) do
        x = elem(coordinates, 0)
        y = elem(coordinates, 1)
        w = elem(grid_size, 0)
        zone_number = (x - 1) * w + y
        :"zone#{zone_number}"
    end

    def get_zone_coords(zone, grid_size) do
        # extract the number off the atom name for the zone
        num = Regex.replace(~r/zone/, Atom.to_string(zone), "") 
              |> String.to_integer
        
        # get the width of the grid
        width = elem(grid_size, 0)

        # calculate the x position
        x = Float.ceil(num / width) 
            |> round

        # calculate the y position
        y = if (rem(num, width) == 0), do: width, else: rem(num, width)

        {x, y}
    end
end