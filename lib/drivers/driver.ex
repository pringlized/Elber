defmodule Elber.Drivers.Driver do
    use GenServer    
    require Logger
    alias Elber.Zones.Zone  
    alias Elber.Server, as: CityServer  

    def start_link(state) do
        log(state, :info, "Starting driver process")           
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

        # TODO: There eventually needs to be a coefficient as add a time delay
        log(state, :debug, "Traveling from #{state.curr_loc} to #{next_loc}")

        # update driver location for availability and gps from current_loc to next_loc
        update_gps(state.curr_loc, next_loc)        
        if state.available == True do
            update_availability(state.curr_loc, next_loc)
        end

        # Update current route with remaining way points
        state = Map.merge(state, %{curr_route: remaining_route})

        # move to next_location
        state = set_curr_loc(state, next_loc)

        # until we reach our destination, keep traveling recursively
        if (state.curr_loc != state.dest_loc) do
            state = travel_to_dest(state)    
        else
            state = Map.merge(state, %{
                meter_off: "NOW",
                arrived: True
            })            
            state
        end
        state  
    end    

    defp end_trip(state) do
        log(state, :info, "Drop off [#{state.rider_uuid}]")

        # TODO
        # Server.write_history(state)

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

        # write fare record to a file
        data = Enum.join(record, ",") |> (&(&1 <> "\r\n")).()
        {:ok, file} = File.open "logs/history.csv", [:append]
        IO.binwrite file, data
        File.close file

        # Add record to driver's history
        state = Map.merge(state, %{
            ride_history: List.insert_at(state.ride_history, 0, record)
        })

        # Reset the drvier state
        state = reset(state)
    end

    # Reset the cab back to an available state
    defp reset(state) do
        log(state, :debug, "RESET ---------------")

        state = Map.merge(state, %{ 
            available: True,
            has_rider: False,
            arrived: False,
            in_vehicle: False,
            rider_request_datetime: nil,
            rider_start_datetime: nil,
            dest_loc: nil,
            pickup_loc: nil,
            dropoff_loc: nil,
            meter_on: nil,
            meter_off: nil,
            rider_pid: nil,
            rider_uuid: nil
        }) 

        # Update the state cache
        status = CityServer.update_state_cache(state)

        # Return new state
        state                  
    end

    # End the driver's shift
    defp punch_off(state) do
        log(state, :info, "---------- OFF THE CLOCK ----------") 

        # remove from curr_loc
        update_availability(state.curr_loc)
        update_gps(state.curr_loc)

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

    # Notify the Zones of the driver's availability
    defp update_availability(at_loc, to_loc \\ nil) do
        if at_loc != nil do
            remove_status = Zone.remove_available_driver(at_loc)
        end

        if to_loc != nil do
            add_status = Zone.add_available_driver(to_loc)
        end
    end

    # Notify the Zones of the current driver's location
    defp update_gps(at_loc, to_loc \\ nil) do
        if at_loc != nil do
            remove_status = Zone.remove_driver_in(at_loc)
        end

        if to_loc != nil do
            add_status = Zone.add_driver_in(to_loc)
        end
    end

    # -----------------------------------
    # CALLBACKS
    # -----------------------------------
    def init([state]) do
        Process.send_after(self(), {:deploy}, 1000)
       {:ok, state} 
    end

    def handle_info({:deploy}, state) do
        # if not working, start
        if state.available == False do
            log(state, :info, "Deploying...")

            # start working
            state = Map.merge(state, %{available: True})

            # add driver to zone
            update_availability(nil, state.curr_loc)
            update_gps(nil, state.curr_loc) 

            # update the state cache
            status = CityServer.update_state_cache(state)    
            
            # go find first customer
            Process.send_after(self(), {:search}, 5000, [])
        end
        {:noreply, state}
    end     

    def handle_call({:state}, _from, state) do
        {:reply, state, state}
    end

    def handle_call({:request_ride, rider}, _from, state) do
        # add request to list
        state = Map.merge(state, %{
            rider_requests: List.insert_at(state.rider_requests, 0, rider.uuid)
        })
        
        # is this driver available?
        if state.available == True do
            state = Map.merge(state, %{
                searching: False,
                available: False,
                has_rider: True,
                rider_pid: rider.pid,
                rider_uuid: rider.uuid,
                rider_start_datetime: rider.start_datetime,
                rider_request_datetime: get_datetime,
                pickup_loc: rider.pickup_loc,
                dropoff_loc: rider.dropoff_loc
            })

            # remove self from availability to riders
            update_availability(state.curr_loc)

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

    def handle_info({:pickup}, state) do
        if state.has_rider == True && state.available == False do
            log(state, :info, "Driving to pickup [#{state.rider_uuid}]...")             

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

            # send arrived notification to rider
            try do
                # Notify the rider that the driver has arrived
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

        # Turn the meter on
        state = Map.merge(state, %{meter_on: get_datetime})

        # get it rollin'
        state = begin_trip(state)

        # are we at the dropoff location?
        if state.curr_loc == state.dropoff_loc do
            log(state, :debug, "Reached dropoff for [#{state.rider_uuid}]")
            send(self(), {:end_trip})
        else
            log(state, :error, "ERROR reaching destination for [#{state.rider_uuid}]")
        end
        {:noreply, state}
    end

    # TODO: must validate at destination state and ready to end trip
    def handle_info({:end_trip}, state) do
        log(state, :info, "End trip for [#{state.rider_uuid}]")
        
        # trun the meter off
        state = Map.merge(state, %{meter_off: get_datetime})

        # Notify rider they are being dropped off
        _ = Elber.Riders.Rider.dropoff(state.rider_pid)

        # End trip: write record and reset driver status
        state = end_trip(state)

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

                # make sure driver is available to riders
                update_availability(nil, state.curr_loc)

                # set searching state
                state = Map.merge(state, %{searching: True})

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

                # hang in this zone for a bit
                :timer.sleep(2000)                           

                # continue the search
                send(self(), {:search})
            end
        end
        {:noreply, state}
    end

end