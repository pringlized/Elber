defmodule Elber.Supervisor do
    use Supervisor

    def start_link(config) do
        IO.inspect config
        Supervisor.start_link(__MODULE__, config, name: __MODULE__)
    end

    # ------------------------------------
    # PRIVATE
    # ------------------------------------
    defp via_tuple(name) do
        {:via, Registry, {:registry, name}}
    end        

    # ------------------------------------
    # CALLBACKS
    # ------------------------------------
    def init(config) do
        children = [
            supervisor(Registry, [:unique, :zone_registry], [id: :zone_registry]),
            worker(Elber.Server, [self(), config], name: :city_server)
        ]

        opts = [strategy: :one_for_all,
                max_restart: 1,
                max_time: 3600
               ]

        supervise(children, opts)
    end  

end