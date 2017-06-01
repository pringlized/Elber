defmodule Elber.Drivers.Supervisor do
    use Supervisor

    @name :driver_supervisor

    def start_link do
        Supervisor.start_link(__MODULE__, [], name: @name)
    end  

    def start_driver(state) do
        Supervisor.start_child(@name, [state])        
    end

    # ------------------------------------
    # CALLBACKS
    # ------------------------------------
    def init(_) do

        children = [
            worker(Elber.Drivers.Driver, [], restart: :temporary)
        ]

        supervise(children, strategy: :simple_one_for_one)
    end

end