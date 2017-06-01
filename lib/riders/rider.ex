defmodule Elber.Riders.Rider do
    use GenServer
    require Logger
    alias Elber.Zones.Zone
    
    def start_link(state) do
        log(state, :info, "Starting rider process")              
        GenServer.start(__MODULE__, [state], [])
    end

    def state(rider_pid) do
        GenServer.call(rider_pid, {:state})
    end

    def driver_arrived(rider_pid) do
        GenServer.call(rider_pid, {:driver_arrived})
    end

    def dropoff(rider_pid) do
        GenServer.cast(rider_pid, {:dropoff})
    end

    # -----------------------------------
    # PRIVATE
    # -----------------------------------  
    defp send_ride_request(state, driver) do
        log(state, :info, "Found driver [#{inspect(driver)}] in [#{state.pickup_loc}]")

        # send drvier.request_ride
        data = %{
            pid: self(),
            uuid: state.uuid,
            start_datetime: state.start_datetime,
            pickup_loc: state.pickup_loc,
            dropoff_loc: state.dropoff_loc
        }
        try do
            status = Elber.Drivers.Driver.request_ride(driver, data)

            # update status and now wait for arrival
            if status == :ok do
                log(state, :info, "Request accepted from [#{inspect(driver)}]")               
                state = Map.merge(state, %{
                    is_requesting: False,
                    driver_pid: driver,
                    request_datetime: "NOW"
                })
            else
                # pause for a moment
                log(state, :info, "Request DENIED from [#{inspect(driver)}]")

                # add driver to denied_requests list
                if !driver in state.requests_denied do
                    state = Map.merge(state, %{
                        requests_denied: state.requests_denied ++ [driver]
                    })
                end

                :timer.sleep(1000)
                send(self(), {:locate_driver})
            end       
        catch
            :exit, _ -> 
                log(state, :error, "ERROR requesting ride from [#{inspect(driver)}]. Locating another driver") 
                :timer.sleep(1000)
                send(self(), {:locate_driver})
        end            
        state   
    end

    defp log(state, type, msg) do
        predicate = "[r][#{state.uuid}] "
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
        state = Map.merge(state, %{start_datetime: get_datetime})
        send(self(), {:locate_driver})       
        {:ok, state}
    end

    def handle_call({:state}, _from, state) do       
        {:reply, state, state}
    end

    # TODO:???
    def handle_call({:driver_arrived}, _from, state) do
        log(state, :info, "Driver [#{inspect(state.driver_pid)}] has arrived")

        # TODO: match the sender with the expected driver (state.driver_pid)

        # TODO: mark down time arrived & in_vehichle
        state = Map.merge(state, %{
            in_vehicle: True,
            pickup_datetime: "NOW"
        })       

        # off we go
        {:reply, :ok, state}
    end

    def handle_cast({:dropoff}, state) do
        log(state, :info, "Dropoff at [#{state.dropoff_loc}]")         
        #Logger.debug("[#{state.uuid}] Dropoff at [#{state.dropoff_loc}]")

        state = Map.merge(state, %{
            dropoff_datetime: "NOW",
            arrived: True,
            in_vehicle: False
        })

        # the job is done
        Process.exit(self(), :normal)

        {:noreply, state}
    end

    def handle_info({:locate_driver}, state) do
        log(state, :info, "Looking in [#{state.pickup_loc}] for a driver")         
        
        # Get a driver from zone if any available
        driver = Zone.get_available_driver(state.pickup_loc)

        # look in zone for a driver that hasn't already been denied
        if driver != nil && !driver in state.requests_denied do           
            state = send_ride_request(state, driver) 
        else
            log(state, :info, "No driver found in [#{state.pickup_loc}]. Expanding search..")

            # not found in current zone. search adjacent zones to get first available driver
            driver = Zone.get_adjacent_zones(state.pickup_loc)
            |> (&Enum.map(&1, fn(zone) -> Zone.get_available_driver(zone) end)).()
            |> (&Enum.filter(&1, fn(driver) -> driver != nil end)).()
            |> List.first

            # did we find a driver in adjacent zone?
            if driver != nil do                        
                state = send_ride_request(state, driver)                      
            else
                # try again until a driver is within range
                :timer.sleep(3000)
                send(self(), {:locate_driver})                 
            end
        end
        {:noreply, state}
    end

end