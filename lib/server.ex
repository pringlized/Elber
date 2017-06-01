defmodule Elber.Server do
    use GenServer
    require Logger
    require UUID
    import Supervisor.Spec
    alias Elber.Zones.Zone
    alias Elber.Drivers.Driver
    alias Elber.Riders.Rider
    alias Elber.Zones.Struct, as: ZoneStruct
    alias Elber.Drivers.Struct, as: DriverStruct
    alias Elber.Riders.Struct, as: RiderStruct
    alias Elber.Zones.Supervisor, as: ZoneSupervisor
    alias Elber.Drivers.Supervisor, as: DriverSupervisor
    alias Elber.Riders.Supervisor, as: RiderSupervisor

    @name :city_server

    defmodule State do
        defstruct sup: nil, size: nil, mfa: nil, grid_size: nil
    end    

    def start_link(city_supervisor, config) do     
        GenServer.start_link(__MODULE__, [city_supervisor, config], name: @name)
    end

    def state do
        GenServer.call(@name, {:state})
    end

    def update_state_cache(entity_state) do
        GenServer.call(@name, {:update_state_cache, entity_state})
    end

    def get_state_cache do
        GenServer.call(@name, {:get_state_cache})
    end    

    # used to lookup name of process
    defp via_tuple(name) do
        {:via, Registry, {:registry, name}}
    end    

    # ------------------------------------
    # PRIVATE
    # ------------------------------------
    # create coordinate zones for a city grid
    defp create_grid({x, y}) do
        # grid list
        for row <- 1..x, col <- 1..y do
            {row, col}
        end
    end

    defp create_cache(table) do
        :ets.new(table, [:set, :protected, :named_table])
    end

    defp update_cache(table, pid, state) do
        :ets.insert(table, {pid, state})
    end

    defp get_cache(table, pid) do
        :ets.lookup(table, pid)
    end

    defp delete_cache(table, pid) do
        :ets.delete(table, pid)
    end

    # NOTE: Should eventually be moved to a ZoneServer
    defp start_zones(state, zone_supervisor) do
        grid = create_grid(state.grid_size)
        Enum.map_reduce(grid, 1, fn(x, acc) -> 
            # create the worker data
            {_, worker} = start_zone(zone_supervisor, acc, x, grid, state.grid_size)

            # return data & accumulator
            { worker, acc + 1 }
        end)        
    end

    # NOTE: Should eventually be moved to a ZoneServer
    defp start_zone(zone_supervisor, id, coordinates, grid, grid_size) do
        # build name from map iteration accumulator
        zone_id = :"zone#{id}"
        zone_state = %ZoneStruct{ 
            :zone_id => zone_id, 
            :coordinates => coordinates,
            :grid => grid,
            :grid_size => grid_size
        }
        opts = [id: zone_id]

        # create the worker data
        Supervisor.start_child(
            zone_supervisor, 
            worker(Zone, [zone_id, zone_state], opts)
        )       
    end

    # NOTE: Should eventually be moved to a DriverServer
    defp start_drivers(state, driver_supervisor) do
        Enum.map(1..state.drivers, fn(x) ->
            pid = start_driver(driver_supervisor)

            if is_pid(pid) do
               # start monitor
               ref = Process.monitor(pid)
               {pid, ref} 
            else
                nil
            end
        end)        
    end

    # NOTE: Should eventually be moved to a DriverServer
    defp start_driver(driver_supervisor, state \\ nil) do
        # create uuid
        uuid = "d-" <> UUID.uuid4

        # new driver starting state
        if state == nil do
            state = %DriverStruct{
                uuid: uuid
            }
        end

        # create the worker
        {status, pid} = DriverSupervisor.start_driver(state)

        if status == :ok do
            _ = update_cache(:statecache, pid, state)
            pid
        else
            nil
        end
    end

    # NOTE: Should eventually be moved to a RiderServer
    defp start_riders(state, rider_supervisor) do
        Enum.map(1..state.riders, fn(x) ->
            # start the process
            pid = start_rider(rider_supervisor, state.grid_size)

            # make sure a valid pid was returned
            if is_pid(pid) do
                pid
            else
                nil
            end
        end)        
    end

    # NOTE: Should eventually be moved to a RiderServer
    defp start_rider(rider_supervisor, grid_size) do
        # create uuid
        uuid = "r-" <> UUID.uuid4

        state = %RiderStruct{
            uuid: uuid,
            pickup_loc: get_random_zone(grid_size),
            dropoff_loc: get_random_zone(grid_size)
        }

        # create the worker
        {status, pid} = RiderSupervisor.start_rider(state)

        if status == :ok do
            pid
        else
            nil
        end
    end

    def get_random_zone({x, y}) do
        grid_size = x * y
        num = :rand.uniform(grid_size) |> Integer.to_string
        :"zone#{num}"
    end    

    # ------------------------------------
    # CALLBACKS
    # ------------------------------------
    def init([city_supervisor, config]) do
        Logger.info("Server init...")

        # update state with the city supervisor pid
        config = put_in(config, [:city_supervisor], city_supervisor)

        # start the supervisors
        send self(), {:start}     

        {:ok, config}
    end

    def handle_call({:state}, _from, state) do
        {:reply, state, state}    
    end

    # updates the cache for calling process
    def handle_call({:update_state_cache, entity_state}, {_from, ref}, state) do
        _ = update_cache(:statecache, _from, entity_state)
        {:reply, :ok, state}
    end

    # get the cache for the calling process
    def handle_call({:get_state_cache}, {_from, ref}, state) do
        entity_state = get_cache(:statecache, _from)
        {:reply, entity_state, state}
    end    

    def handle_info({:start}, state) do
        Logger.info("Starting supervisors...")

        # initialize state cache
        cache = create_cache(:statecache)

        # Start the supervisors
        Logger.info("Starting Zone Supervisor")         
        {_, zone_sup} = Supervisor.start_child(state.city_supervisor, supervisor(ZoneSupervisor, []))
        Logger.info("Starting Driver Supervisor...")
        {_, driver_sup} = Supervisor.start_child(state.city_supervisor, supervisor(DriverSupervisor, []))
        Logger.info("Starting Rider Supervisor")
        {_, rider_sup} = Supervisor.start_child(state.city_supervisor, supervisor(RiderSupervisor, []))

        # Init zones
        zones = start_zones(state, zone_sup)

        # Start the drivers
        Logger.info("Seeding grid with drivers...")
        drivers = start_drivers(state, driver_sup)

        # Start the riders
        Logger.info("Seeding grid with riders..")
        riders = start_riders(state, rider_sup)

        # Update state with supervisor pid
        state = Map.merge(state, %{
            zone_supervisor: zone_sup,
            driver_supervisor: driver_sup,
            rider_supervisor: rider_sup
        })                   

        {:noreply, state}
    end

    # TEST EXIT
    def handle_info({:EXIT, worker_sup, _reason}, state) do 
        Logger.info("Driver [#{inspect(worker_sup)}] EXIT: [#{inspect(_reason)}]")        
        IO.inspect _reason
        IO.inspect worker_sup
        {:noreply, state}
    end

    # DRVIER CRASH
    def handle_info({:DOWN, ref, :process, pid, {_reason, process_state}}, state) do 
        Logger.error("Drvier [#{inspect(pid)}] has crashed: [#{inspect(_reason)}][#{inspect(process_state)}]")

        # attempt to get prior state
        cache = get_cache(:statecache, pid)

        # does the cache exist?
        if Enum.count(cache) == 0 do
            Logger.error("NOT monitoring drvier [#{inspect(pid)}]")
        else
            [{driver_pid, past_state}] = cache       

            # purge old pid from zone
            Zone.remove_available_driver(past_state.curr_loc, pid)

            # Demonitor dead pid, and remove cache
            true = Process.demonitor(ref)
            true = delete_cache(:statecache, driver_pid)

            # Reset available so the driver can be redeployed
            past_state = Map.merge(past_state, %{available: False})

            # spawn new driver
            new_driver = start_driver(state.driver_supervisor, past_state)

            # make sure a valid pid was returned            
            if new_driver != nil do
                Logger.info("Started new driver [#{inspect(new_driver)}]")
                
                # Start montitoring new drive
                ref = Process.monitor(new_driver)
                
                Logger.info("Monitoring new driver [#{inspect(new_driver)}] - [#{inspect(ref)}]")                
            else
                Logger.error("FAILED to start new driver after crash of [#{inspect(pid)}]")
            end   
        end
        {:noreply, state} 
    end
    
    # TEST
    def handle_info({:DOWN, ref, :process, pid, _reason}, state) do 
        Logger.error("Driver [#{inspect(pid)}] DOWN: [#{inspect(_reason)}]")
        IO.inspect pid
        IO.inspect _reason          
        {:noreply, state}        
    end    
end