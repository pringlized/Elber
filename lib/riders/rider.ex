defmodule Elber.Riders.Rider do
    use GenServer
    require Logger
    alias Elber.Zones.Zone
    
    def start_link(state) do
        Logger.info("[#{state.uuid}] Starting rider")        
        GenServer.start(__MODULE__, [state], [])
    end

    def state(rider_pid) do
        GenServer.call(rider_pid, {:state})
    end

    def driver_arrived(rider_pid) do
        GenServer.call(rider_pid, {:driver_arrived})
    end

    def dropoff(rider_pid) do
        GenServer.call(rider_pid, {:dropoff})
    end

    # -----------------------------------
    # PRIVATE
    # -----------------------------------  
    defp send_ride_request(state, driver) do
        Logger.info("[#{state.uuid}] Found driver [#{inspect(driver)}] in [#{state.pickup_loc}]")

        # send drvier.request_ride
        data = %{
            pid: self(),
            uuid: state.uuid,
            pickup_loc: state.pickup_loc,
            dropoff_loc: state.dropoff_loc
        }
        status = Elber.Drivers.Driver.request_ride(driver, data)
        
        #IO.inspect status

        # update status and now wait for arrival
        if status == :ok do
            Logger.info("[#{state.uuid}] Request accepted from [#{inspect(driver)}]")                
            state = Map.merge(state, %{
                is_requesting: False,
                driver_pid: driver,
                request_datetime: "NOW"
            })
        else
            # pause for a moment
            Logger.info("[#{state.uuid}] Request DENIED from [#{inspect(driver)}]")                 
            :timer.sleep(1000)
            send(self(), {:locate_driver})
        end
        state     
    end

    # -----------------------------------
    # CALLBACKS
    # -----------------------------------
    def init([state]) do
        Process.send_after(self(), {:locate_driver}, 5000)        
        {:ok, state}
    end

    def handle_call({:state}, _from, state) do       
        {:reply, state, state}
    end

    # TODO:???
    def handle_call({:driver_arrived}, _from, state) do
        Logger.debug("[#{state.uuid}] Driver [#{inspect(state.driver_pid)}] has arrived")

        # TODO: match the sender with the expected driver (state.driver_pid)

        # TODO: mark down time arrived & in_vehichle
        state = Map.merge(state, %{
            in_vehicle: True,
            pickup_datetime: "NOW"
        })

        # off we go
        {:reply, :ok, state}
    end

    def handle_call({:dropoff}, _from, state) do
        Logger.debug("[#{state.uuid}] Dropoff at [#{state.dropoff_loc}]")

        state = Map.merge(state, %{
            dropoff_datetime: "NOW",
            arrived: True,
            in_vehicle: False
        })

        IO.inspect state

        {:reply, state, state}
    end

    def handle_info({:locate_driver}, state) do
        # Get a driver from zone if any available
        Logger.debug("[#{state.uuid}] Looking in [#{state.pickup_loc}] for a driver")
        driver = Zone.get_driver(state.pickup_loc)

        # look in zone for a driver
        if driver != nil do
            send_ride_request(state, driver)
        else
            Logger.info("[#{state.uuid}] No driver found in [#{state.pickup_loc}]. Expanding search..")

            # not found in current zone. search adjacent zones to get first available driver
            driver = Zone.get_adjacent_zones(state.pickup_loc)
            |> (&Enum.map(&1, fn(zone) -> Zone.get_driver(zone) end)).()
            |> (&Enum.filter(&1, fn(driver) -> driver != nil end)).()
            |> List.first
            
            #IO.inspect driver

            if driver != nil do
                IO.puts("FOUND!!!")               
                send_ride_request(state, driver)
            else
                #IO.puts("NOT FOUND")
                # else expand search to adjacent zones
                :timer.sleep(3000)
                send(self(), {:locate_driver})                 
            end
        end
        {:noreply, state}
    end


end