defmodule Elber.Riders.Supervisor do
    use Supervisor

    @name :rider_supervisor

    def start_link do
        Supervisor.start_link(__MODULE__, [], name: @name)
    end

    def start_rider(state) do
        Supervisor.start_child(@name, [state])        
    end

    # ------------------------------------
    # CALLBACKS
    # ------------------------------------
    def init(_) do

        children = [
            worker(Elber.Riders.Rider, [], restart: :temporary)
        ]

        supervise(children, strategy: :simple_one_for_one)
    end

end