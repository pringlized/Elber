defmodule Elber.Server do
    use GenServer
    require Logger
    require UUID
    import Supervisor.Spec
    alias Elber.Zones.Zone    

    defmodule State do
        defstruct sup: nil, size: nil, mfa: nil, grid_size: nil
    end    

    def start_link(city_supervisor, config) do     
        GenServer.start_link(__MODULE__, [city_supervisor, config], name: :city_server)
    end

    def state do
        GenServer.call(:city_server, {:state})
    end

    def get_zone_state(zone) do
        GenServer.call(:city_server, {:get_zone_state, zone})
    end

    def add_driver do
        
    end

    def remove_driver do
        
    end

    def add_rider do
        
    end

    def remove_rider do

    end

    # used to lookup name of process
    defp via_tuple(name) do
        {:via, Registry, {:registry, name}}
    end    

    # ------------------------------------
    # PRIVATE
    # ------------------------------------
    defp create_grid({x, y}) do
        # grid list
        for row <- 1..x, col <- 1..y do
            {row, col}
        end
    end

    defp start_zone(zone_supervisor, id, coordinates, grid, grid_size) do
        # build name from map iteration accumulator
        zone_id = :"zone#{id}"
        zone_state = %Elber.Zones.Struct{ 
            :zone_id => zone_id, 
            :coordinates => coordinates,
            :grid => grid,
            :grid_size => grid_size
        }
        opts = [id: zone_id]

        # create the worker data
        Supervisor.start_child(
            zone_supervisor, 
            worker(Elber.Zones.Zone, [zone_id, zone_state], opts)
        )       
    end

    defp start_driver(driver_supervisor) do
        # create uuid
        uuid = "d-" <> UUID.uuid4

        # new driver starting state
        state = %Elber.Drivers.Struct{
            uuid: uuid
        }

        # create the worker
        Supervisor.start_child(driver_supervisor, [state])
    end

    defp start_rider(rider_supervisor, grid_size) do
        # create uuid
        uuid = "r-" <> UUID.uuid4

        state = %Elber.Riders.Struct{
            uuid: uuid,
            pickup_loc: get_random_zone(grid_size),
            dropoff_loc: get_random_zone(grid_size)
        }

        # create the worker
        Supervisor.start_child(rider_supervisor, [state])
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
        #IO.inspect city_supervisor

        # update state with the city supervisor pid
        config = put_in(config, [:city_supervisor], city_supervisor)

        # start the supervisors
        send self(), {:start}

        # start cleaning out zones of dead driver processes
        Process.send_after(self(), {:check_zones}, 10000)        

        {:ok, config}
    end

    # TODO: go through all the zones, get all the drivers and purge ones that aren't alive
    def handle_info({:check_zones}, state) do
        # HACK: hardcoding for 12x12 grid
        # get all zones
        removed = Enum.map(1..144, fn(num) ->
            zone_name = :"zone#{num}"
            drivers = Zone.get_available_drivers(zone_name)
            removed = Enum.each(drivers, fn(driver_pid) ->
                if !Process.alive?(driver_pid) do
                    Logger.info("PURGING DEAD DRIVER #{inspect(driver_pid)} from #{zone_name}")
                    Zone.remove_available_driver(zone_name, [driver_pid, nil])
                end
                nil
            end)
            nil
        end)
        Process.send_after(self(), {:check_zones}, 30000)
        {:noreply, state}
    end

    def handle_call({:state}, _from, state) do
        {:reply, state, state}    
    end    

    def handle_call({:get_zone_state, zone}, _from, state) do
        zone_state = Elber.Zones.Zone.state(zone)
        {:reply, zone_state, state}
    end

    def handle_info({:start}, state) do
        Logger.info("Starting supervisors...")

        # start zone supervisor
        {_, zone_sup} = Supervisor.start_child(state.city_supervisor, supervisor(Elber.Zones.Supervisor, []))
        Logger.info("Zone supervisor started")        
        state = put_in(state, [:zone_supervisor], zone_sup)

        # add zones
        grid = create_grid(state.grid_size)
        zones = Enum.map_reduce(grid, 1, fn(x, acc) -> 
            # create the worker data
            {_, worker} = start_zone(state.zone_supervisor, acc, x, grid, state.grid_size)

            # return data & accumulator
            { worker, acc + 1 }
        end)

        #IO.inspect zones

        # start driver supervisor
        {_, driver_sup} = Supervisor.start_child(state.city_supervisor, supervisor(Elber.Drivers.Supervisor, []))
        Logger.info("Driver supervisor started")        
        state = put_in(state, [:driver_supervisor], driver_sup)
        drivers = Enum.each(1..state.drivers, fn(x) ->
            {_, worker} = start_driver(driver_sup)
            #IO.inspect worker
            worker
        end)
        #IO.inspect drivers
        
        # start rider supervisor
        {_, rider_sup} = Supervisor.start_child(state.city_supervisor, supervisor(Elber.Riders.Supervisor, []))
        Logger.info("Rider supervisor started")        
        state = put_in(state, [:rider_supervisor], rider_sup)    
        riders = Enum.each(1..state.riders, fn(x) ->
            {_, worker} = start_rider(rider_sup, state.grid_size)
            worker
        end)    
        #IO.inspect rider_sup

        #IO.inspect state
        {:noreply, state}
    end
end