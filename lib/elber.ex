defmodule Elber do
    use Application

    def start(_type, _args) do
        config = %{
            city_server: nil,
            city_supervisor: nil,
            zone_supervisor: nil,
            driver_supervisor: nil,
            rider_supervisor: nil,
            grid_size: {12,12},
            drivers: 300,
            riders: 500
        }

        start_city(config)
    end

    def start_city(config) do
        Elber.Supervisor.start_link(config)
    end

end