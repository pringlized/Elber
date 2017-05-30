defmodule Elber.Drivers.Supervisor do
    use Supervisor

    def start_link do
        Supervisor.start_link(__MODULE__, [], name: :driver_supervisor)
    end  

    # ------------------------------------
    # CALLBACKS
    # ------------------------------------
    def init(_) do

        children = [
            worker(Elber.Drivers.Driver, [], restart: :transient)
        ]

        supervise(children, strategy: :simple_one_for_one)
    end

end