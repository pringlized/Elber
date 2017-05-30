defmodule Elber.Zones.Zone do
    @moduledoc """
    Zone Dispatch
    """
    use GenServer
    require Logger
    alias Elber.Zones.Utils

    def start_link(name, zone_struct) do
        zone_name = via_tuple(name)
        GenServer.start_link(__MODULE__, [zone_struct, name], name: zone_name)
    end

    def stop(zone) do
        GenServer.call(via_tuple(zone), :stop)
    end

    def state(zone) do
        GenServer.call(via_tuple(zone), {:state}) 
    end

    def get_coordinates(zone) do
        GenServer.call(via_tuple(zone), {:get_coordinates})         
    end

    def get_adjacent_zones(zone) do
        GenServer.call(via_tuple(zone), {:get_adjacent_zones})
    end

    def is_adjacent_zone?(from, to) do
        GenServer.call(via_tuple(from), {:is_adjacent_zone, to})
    end

    def add_rider(zone, rider) do
        Logger.info("[#{zone}] Adding rider")        
        GenServer.call(via_tuple(zone), {:add_rider, rider}) 
    end

    def remove_rider(zone, rider) do
        Logger.info("[#{zone}] Removing [#{rider}]")        
        GenServer.call(via_tuple(zone), {:remove_rider, rider})         
    end

    def get_rider(zone) do
        #Logger.info("[#{zone}] Getting rider")
        GenServer.call(via_tuple(zone), {:get_rider})
    end

    def add_driver(zone, [pid, uuid]) do
        Logger.debug("[#{zone}] Adding driver [#{uuid}]")
        GenServer.call(via_tuple(zone), {:add_driver, pid}) 
    end

    def get_driver(zone) do
        #Logger.info("[#{zone}] Getting rider")
        GenServer.call(via_tuple(zone), {:get_driver})
    end  

    def get_drivers(zone) do
        GenServer.call(via_tuple(zone), {:get_drivers})
    end  

    def remove_driver(zone, [pid, uuid]) do
        Logger.debug("[#{zone}] Removing [#{inspect(pid)}]")
        GenServer.call(via_tuple(zone), {:remove_driver, pid})         
    end    

    # used to lookup name of process
    defp via_tuple(name) do
        {:via, Registry, {:zone_registry, name}}
    end

    # ------------------------------------
    # CALLBACKS
    # ------------------------------------
    def init([zone_struct, name]) do
        Logger.info("Zone process created: #{name}")
        {:ok, zone_struct}
    end

    def handle_call(:stop, _from, state) do
        {:stop, :normal, :ok, state}
    end

    def handle_call({:state}, _from, state) do
        {:reply, state, state}    
    end

    def handle_call({:add_rider, rider}, _from, state) do
        riders = List.insert_at(state.riders, -1, rider)
        state = Map.merge(state, %{
            riders: riders
        })
        {:reply, :ok, state}
    end

    def handle_call({:add_driver, driver}, _from, state) do
        drivers = List.insert_at(state.drivers, -1, driver)
        state = Map.merge(state, %{
            drivers: drivers
        })
        #IO.inspect state.drivers
        {:reply, :ok, state}
    end    

    def handle_call({:remove_driver, driver}, _from, state) do
        drivers = List.delete(state.drivers, driver)
        state = Map.merge(state, %{
            drivers: drivers
        })
        #IO.inspect state.drivers
        {:reply, :ok, state} 
    end

    def handle_call({:remove_rider, rider}, _from, state) do
        riders = List.delete(state.riders, rider)
        state = Map.merge(state, %{
            riders: riders
        })
        {:reply, :ok, state} 
    end    

    def handle_call({:get_rider}, _from, state) do
        rider = List.first(state.riders)
        {:reply, rider, state}
    end

    def handle_call({:get_driver}, _from, state) do
        #IO.inspect state.drivers
        driver = List.first(state.drivers)
        {:reply, driver, state}
    end

    def handle_call({:get_drivers}, _from, state) do
        {:reply, state.drivers, state}
    end

    def handle_call({:get_coordinates}, _from, state) do
        coordinates = state.coordinates
        {:reply, coordinates, state}
    end

    def handle_call({:get_adjacent_zones}, _from, state) do
        grid = state.grid
        grid_size = state.grid_size
        coordinates = state.coordinates
        check = Utils.calc_adjacent_coords(coordinates)

        # filter out zone coordinates outside the grid edge
        check_filtered = grid -- check
        adjacent_zones = grid -- check_filtered

        # get the zone names
        zones = Enum.map(adjacent_zones, &Utils.get_zone_name(&1, grid_size))
        {:reply, zones, state}
    end

    def handle_call({:is_adjacent_zone, zone}, _from, state) do
        grid = state.grid
        grid_size = state.grid_size     
        coordinates = state.coordinates
        check = Utils.calc_adjacent_coords(coordinates)

        # filter out what to check from global grid
        check_filtered = grid -- check

        # see if where can be accessed
        coordinates = Utils.get_zone_coords(zone, grid_size)
        is_member = Enum.member?(grid -- check_filtered, coordinates)
        {:reply, is_member, state}
    end
end