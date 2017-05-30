defmodule Elber.Drivers.Driver do
    use GenServer    
    require Logger
    alias Elber.Zones.Zone    

    def start_link(state) do
        log(state, :info, "Starting driver")           
        #Logger.info("[#{state.uuid}] Starting driver")
        GenServer.start_link(__MODULE__, [state], [])
    end

    def state(driver_pid) do
        GenServer.call(driver_pid, {:state})
    end

    def request_ride(driver_pid, rider) do
        GenServer.call(driver_pid, {:request_ride, rider})
    end

    # -----------------------------------
    # PRIVATE
    # -----------------------------------
    defp activate do
        
    end

    # Set current location and add to zones_traveled
    defp set_curr_loc(state, loc) do
        state = Map.merge(state, %{
            curr_loc: loc,
            zones_traveled: List.insert_at(state.zones_traveled, 0, loc)            
        })
    end

    # Set destination location
    defp set_dest_loc(state, route) do
        state = Map.merge(state, %{
            curr_route: route,
            dest_loc: List.last(route)
        })
    end        

    # Using current location, find a route to dest_loc using
    # a Breadth First Search
    defp find_route(state, dest_loc) do
        Elber.Zones.BFS.search(state.curr_loc, dest_loc)        
    end

    # Update route: adds to routes_traveled & current route
    defp update_route(state, route) do # when is_list(route) not empty
        start_loc = List.first(route)
        dest_loc = List.last(route)
        log(state, :info, "Traveling route from #{start_loc} to #{dest_loc}")         
        #Logger.info("[#{state.uuid}] Traveling route from #{start_loc} to #{dest_loc}") 

        state = Map.merge(state, %{
            dest_loc: List.last(route),
            curr_route: route,
            routes_traveled: [route] ++ state.routes_traveled
        })
    end 

    defp begin_trip(state) do
        # HACK: Sometimes pickup & dropoff are the same
        # If so, skip travel
        if state.pickup_loc != state.dropoff_loc do
            # get a route, update our state, then travel there
            state = find_route(state, state.dropoff_loc)
            |> (&update_route(state, &1)).()
            |> (&travel_to_dest(&1)).()
        end
        state
    end

    # NOTE: State must be all set, otherwise it won't work
    # TODO: Remove starting point since it's where we are
    # TODO: Get meter_off working
    defp travel_to_dest(state) do
        # get next location and update remaining route
        [next_loc | remaining_route] = state.curr_route
        |> (&List.delete(&1, state.curr_loc)).()

        # since a zone has a size, it should take N seconds to the next
        log(state, :debug, "Traveling from #{state.curr_loc} to #{next_loc}")         
        :timer.sleep 100

        # remove drive from current_loc and add to next_loc
        Zone.remove_driver(state.curr_loc, [self(), state.uuid]) 
        Zone.add_driver(next_loc, [self(), state.uuid])

        state = Map.merge(state, %{
            curr_route: remaining_route
        })

        # move to next_location
        state = set_curr_loc(state, next_loc)

        #IO.inspect state.zones_traveled

        # until we reach our destination, keep traveling recursively
        if (state.curr_loc != state.dest_loc) do
            state = travel_to_dest(state)    
        else
            state = Map.merge(state, %{
                meter_off: "TODO",
                arrived: True
            })            
            state
        end
        state  
    end    

    defp end_trip(state) do
        log(state, :info, "Drop off [#{state.rider_uuid}]")         
        #Logger.info("[#{state.uuid}] is at location and dropping off [#{state.rider_uuid}] ")
        :timer.sleep 100  

        # write a fare record
        [route_traveled | _] = state.routes_traveled
        
        # RECORD
        #   driver uuid
        #   rider uuid
        #   request_datetime
        #   pickup_datetime
        #   pickup_loc
        #   dropoff_datetime
        #   dest_loc
        #   distance
        record = [
            state.uuid,
            state.rider_uuid,
            state.rider_start_datetime,
            state.rider_request_datetime,
            state.meter_on,
            state.pickup_loc,
            state.meter_off,
            state.dest_loc,
            length(route_traveled) - 1
        ]
        #IO.inspect record
        data = Enum.join(record, ",") |> (&(&1 <> "\r\n")).()
        {:ok, file} = File.open "logs/history.csv", [:append]
        IO.binwrite file, data
        File.close file

        # add record to server history
        #status = Elber.Server.add_history(record)
        :ok
    end

    defp reset(state) do
        log(state, :debug, "RESET ---------------")
        #Logger.info("[#{state.uuid}] RESET ---------------")
        state = Map.merge(state, %{ 
            available: True,
            has_rider: False,
            arrived: False,
            in_vehicle: False,
            request_datetime: nil,
            dest_loc: nil,
            pickup_loc: nil,
            dropoff_loc: nil,
            rider_pid: nil,
            rider_uuid: nil
        })        
    end

    defp punch_off(state) do
        log(state, :info, "---------- OFF THE CLOCK ----------") 

        # remove from curr_loc
        Zone.remove_driver(state.curr_loc, [self(), state.uuid])

        # reset cab state
        #state = reset(state)

        # punch off the clock and stop being available
        state = Map.merge(state, %{
            available: False,
            searching: False
        })      
    end    

    defp log(state, type, msg) do
        predicate = "[d][#{state.uuid}] "
        case type do
            :debug ->
                Logger.debug(predicate <> msg)
            :error ->
                Logger.error(predicate <> msg)
            _ ->
                Logger.info(predicate <> msg)
        end
    end

    defp get_datetime do
        Timex.format!(Timex.local, "{ISO:Extended}")
    end

    # -----------------------------------
    # CALLBACKS
    # -----------------------------------
    def init([state]) do
        Process.send_after(self(), {:deploy}, 5000)
       {:ok, state} 
    end

    def handle_call({:state}, _from, state) do
        {:reply, state, state}
    end

    def handle_call({:request_ride, rider}, _from, state) do
        # if available
        #IO.inspect rider

        # add request to list
        state = Map.merge(state, %{
            rider_requests: List.insert_at(state.rider_requests, 0, rider.uuid)
        })
        
        # is this drivare available?
        if state.available == True do
            state = Map.merge(state, %{
                searching: False,
                available: False,
                has_rider: True,
                rider_pid: rider.pid,
                rider_uuid: rider.uuid,
                rider_start_datetime: rider.start_datetime,
                rider_request_datetime: get_datetime,
                #dest_loc: rider.pickup_loc,
                pickup_loc: rider.pickup_loc,
                dropoff_loc: rider.dropoff_loc
            })

            #IO.inspect state

            # TODO: remove self from zone in [drivers_available]

            # now go pick up the rider
            send(self(), {:pickup})

            {:reply, :ok, state}
        else
            if state.searching == False do
                send(self(), {:search})
            end
            {:reply, :denied, state}
        end
    end

    def handle_info({:deploy}, state) do
        # if not working, start
        if state.available == False do
            log(state, :info, "Deploying...")            
            #Logger.info("[#{state.uuid}] Deploying...")

            # start working
            state = Map.merge(state, %{
                available: True,
                curr_loc: state.start_loc
            })

            # add driver to zone
            Zone.add_driver(state.start_loc, [self(), state.uuid])            
            
            # go find first customer
            Process.send_after(self(), {:search}, 2000, [])
        end
        {:noreply, state}
    end     

    def handle_info({:pickup}, state) do
        if state.has_rider == True && state.available == False do
            log(state, :info, "Driving to pickup [#{state.rider_uuid}]...")             
            #Logger.info("[#{state.uuid}] Driving to pickup [#{state.rider_uuid}]...")

            # Determine if we need to travel across zones
            if state.curr_loc != state.pickup_loc do 
                # get a route, update our state, then travel there                           
                state = find_route(state, state.pickup_loc)
                |> (&update_route(state, &1)).()
                |> (&travel_to_dest(&1)).()
            else
                # NOTE: most times the driver and rider will be in the same zone. To
                #       simulate driving to the pickup location, pause for a few seconds                
                :timer.sleep(3000)
            end

            log(state, :info, "At pickup location [#{state.pickup_loc}] for [#{state.rider_uuid}]")
            #Logger.info("[#{state.uuid}] At pickup location [#{state.pickup_loc}] for [#{state.rider_uuid}]")

            # send arrived notification to rider
            try do        
                status = Elber.Riders.Rider.driver_arrived(state.rider_pid)

                # send begin trip notification to self
                if status == :ok do
                    state = Map.merge(state, %{
                        arrived: True,
                        in_vehicle: True,
                    })
                    send(self(), {:begin_trip})
                else
                    log(state, :error, "ERROR picking up [#{state.rider_uuid}]")                 
                    #Logger.error("[#{state.uuid}] ERROR picking up [#{state.rider_uuid}]")            
                end
            catch
                :exit, _ -> 
                    Logger.error("[#{state.uuid}] ERROR picking up rider [#{state.rider_uuid}]. Resetting")
                    :timer.sleep(1000)
                    state = reset(state)
                    Process.send_after(self(), {:search}, 500)  
            end
        end
        {:noreply, state}
    end

    def handle_info({:begin_trip}, state) do
        log(state, :info, "Begin trip for [#{state.rider_uuid}]")        
        #Logger.info("[#{state.uuid}] Begin trip for [#{state.rider_uuid}]")

        state = Map.merge(state, %{
            meter_on: get_datetime,
        })

        #IO.inspect(state)

        state = begin_trip(state)

        #IO.inspect(state)

        # are we at the dropoff location?
        if state.curr_loc == state.dropoff_loc do
            log(state, :debug, "Reached dropoff for [#{state.rider_uuid}]")
            #Logger.debug("[#{state.uuid}] Reached dropoff for [#{state.rider_uuid}]")
            send(self(), {:end_trip})
        else
            log(state, :error, "ERROR reaching destination for [#{state.rider_uuid}]")            
            #Logger.error("[#{state.uuid}] ERROR reaching destination for [#{state.rider_uuid}]")
        end

        {:noreply, state}
    end

    # TODO: must validate at destination state and ready to end trip
    def handle_info({:end_trip}, state) do
        log(state, :info, "End trip for [#{state.rider_uuid}]")
        
        # trun the meter off
        state = Map.merge(state, %{
            meter_off: get_datetime,
        })

        # drop off
        status = Elber.Riders.Rider.dropoff(state.rider_pid)

        # end trip and write record
        status = end_trip(state)        

        # reset the driver state
        state = reset(state)

        # hang for a couple seconds
        :timer.sleep(5000)        

        # start searching again
        send(self(), {:search})

        {:noreply, state}
    end

    def handle_info({:search}, state) do
        if state.available == True do
            # check shift
            if Enum.count(state.zones_traveled) >= state.shift_length do
                # done working
                punch_off(state)               
            else
                log(state, :info, "Searching for a rider")            

                # set searching state
                state = Map.merge(state, %{
                    searching: True
                })

                # search until a customer request comes in
                # hang in this zone for a bit
                :timer.sleep(1000)

                # Move to a random adjacent zone
                # - get adjacent zones
                # - filter out zone traveled from
                # - get random zone from remaining list
                [dest_loc] = Zone.get_adjacent_zones(state.curr_loc)
                |> (&List.delete(&1, Enum.at(&1, 1))).() # DONT THINK THIS IS WORKING
                |> (&Enum.take_random(&1, 1)).()          

                # get a route, update our state, then travel there
                state = find_route(state, dest_loc)
                |> (&update_route(state, &1)).()
                |> (&travel_to_dest(&1)).()

                # reset cab state
                state = reset(state)

                # continue the search
                send(self(), {:search})
            end
        end
        {:noreply, state}
    end

end