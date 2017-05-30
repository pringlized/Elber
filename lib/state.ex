defmodule Elber.State do

    def start_link(state \\ %{}) do
        Agent.start_link(fn -> state end, name: __MODULE__)
    end

    def put(key, value) do
        Agent.update(__MODULE__, fn map -> Map.put(map, key, value) end)
    end

    def get(key) do
        Agent.get(__MODULE__, fn map -> Map.get(map, key) end)
    end

    def del(key) do
        Agent.update(__MODULE__, fn map -> Map.delete(map, key) end)
    end

    def keys do
        Agent.get(__MODULE__, fn map -> Map.keys(map) end)
    end

end