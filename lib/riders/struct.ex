defmodule Elber.Riders.Struct do
    @enforce_keys [:uuid, :pickup_loc, :dropoff_loc]
    defstruct [
        :uuid,
        :pickup_loc,
        :dropoff_loc,
        is_requesting: False,
        in_vehicle: False,
        arrived: False,
        driver_pid: nil,
        driver_uuid: nil,
        request_datetime: nil,
        pickup_datetime: nil,
        dropoff_datetime: nil
    ]
end