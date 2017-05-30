defmodule Elber.Zones.BFS do

    def zone_map(name, parent \\ nil) do
        %{
            name: name,
            distance: 0,
            parent: nil
        }
    end

    def search(start, goal) do
        if start != goal do
            from = zone_map(start)
            to = zone_map(goal)

            # search out the goal
            {queue, visited, paths} = search_frontier(to, [from], [], %{})

            # build the route
            build_route(paths, goal, [])
        else
            [goal]
        end
    end

    def search_frontier(goal, queue, visitied, paths) do
        # get the current zone, and assign remaining back to the queue          
        [current | queue] = queue

        # get adjacent zones and iterate
        adjacent_zones = Elber.Zones.Zone.get_adjacent_zones(current.name)
        adj = for x <- adjacent_zones do
            # place zone into a map
            n = zone_map(x)

            # if the adjacent zone has NOT been visited
            if !Enum.member?(visitied, n.name) do
                Map.merge(n, %{
                    parent: current.name,
                    distance: current.distance + 1
                })                 
            end
        end

        # add adjacent to end of queue
        queue = queue ++ adj

        # clean off nil: delete only removes first instance, so use uniq first
        queue = Enum.uniq(queue)
        |> (&List.delete(&1, nil)).()

        # add current to the visited list
        visitied = List.insert_at(visitied, -1, current.name) 

        # no need to add longer paths if shortest is already in the list
        if !Map.has_key?(paths, current.name) do
            paths = Map.put(paths, current.name, current)
        end

        # get names still in the queue
        in_queue = Enum.map(queue, fn(x) -> x.name end)
        cond do
            # has the goal been found in queue?
            Enum.member?(in_queue, goal.name) -> 
                # add goal to map
                goal = Map.merge(goal, %{parent: current.name})
                paths = Map.put(paths, goal.name, goal)

            # are there zones remaining to search?
            length(queue) > 0 -> 
                # recursively search through next level
                {queue, visitied, paths} = search_frontier(goal, queue, visitied, paths) 
        end

        {queue, visitied, paths}
    end

    def build_route(nodes, goal, route) do
        node = nodes[goal]
        route = List.insert_at(route, 0, goal)        

        if node.parent != nil do            
            route = build_route(nodes, node.parent, route)
        end

        route
    end

end     