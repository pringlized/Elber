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

    def add_available_driver(zone) do
        GenServer.call(via_tuple(zone), {:add_available_driver, zone}) 
    end

    def get_available_driver(zone) do
        #Logger.info("[#{zone}] Getting rider")
        GenServer.call(via_tuple(zone), {:get_available_driver})
    end  

    def get_available_drivers(zone) do
        GenServer.call(via_tuple(zone), {:get_available_drivers})
    end  

    def remove_available_driver(zone) do
        GenServer.call(via_tuple(zone), {:remove_available_driver, zone})         
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

    def handle_call({:add_available_driver, zone}, {_from, reference}, state) do
        # if the driver pid is NOT already in the list
        if !_from in state.drivers_available do
            Logger.debug("[#{zone}] Adding available driver [#{inspect(_from)}]")            
            drivers = List.insert_at(state.drivers_available, -1, _from)
            state = Map.merge(state, %{
                drivers_available: drivers
            })
        end
        #IO.inspect state.drivers_available
        {:reply, :ok, state}
    end    

    def handle_call({:remove_available_driver, zone}, {_from, reference}, state) do
        Logger.debug("[#{zone}] Removing available driver [#{inspect(_from)}]")
        drivers = List.delete(state.drivers_available, _from)
        state = Map.merge(state, %{
            drivers_available: drivers
        })
        #IO.inspect state.drivers_available
        {:reply, :ok, state} 
    end

    def handle_call({:get_available_driver}, _from, state) do
        #IO.inspect state.drivers_available
        driver = List.first(state.drivers_available)
        {:reply, driver, state}
    end

    def handle_call({:get_available_drivers}, _from, state) do
        {:reply, state.drivers_available, state}
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