defmodule Elber.Riders.Struct do
    @enforce_keys [:uuid, :pickup_loc, :dropoff_loc]
    defstruct [
        :uuid,
        :pickup_loc,
        :dropoff_loc,
        is_requesting: False,
        requests_denied: [],
        in_vehicle: False,
        arrived: False,
        driver_pid: nil,
        driver_uuid: nil,
        start_datetime: nil,
        request_datetime: nil,
        pickup_datetime: nil,
        dropoff_datetime: nil
    ]
end