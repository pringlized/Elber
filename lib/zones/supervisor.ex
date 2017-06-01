defmodule Elber.Zones.Supervisor do
    use Supervisor

    @name :zone_supervisor

    def start_link do
        Supervisor.start_link(__MODULE__, [], name: @name)
    end

    def start_zone(state) do
        Supervisor.start_child(@name, [state])        
    end    

    # ------------------------------------
    # CALLBACKS
    # ------------------------------------
    def init(_) do
        opts = [
            strategy: :one_for_one
        ]

        supervise([], opts)
    end

end