defmodule Elber.Riders.Supervisor do
    use Supervisor

    def start_link do
        Supervisor.start_link(__MODULE__, [], name: :rider_supervisor)
    end

    def init(_) do
        children = [
            worker(Elber.Riders.Rider, [], restart: :transient)
        ]

        supervise(children, strategy: :simple_one_for_one)
    end

end