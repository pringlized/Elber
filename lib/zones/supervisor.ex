defmodule Elber.Zones.Supervisor do
    use Supervisor

    def start_link do
        Supervisor.start_link(__MODULE__, [], name: :zone_supervisor)
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