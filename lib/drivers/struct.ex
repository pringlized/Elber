defmodule Elber.Drivers.Struct do
    @enforce_keys[:uuid]
    defstruct [
        # driver id used by the system
        :uuid,
        # driver pid
        pid: nil,
        # on the clock?
        available: False,  
        # currently search for fare
        searching: False,         
        # length of shift in zones traveled
        shift_length: 100,
        # start_loc:
        start_loc: :zone1,
        # ride pid
        rider_pid: nil,
        # rider id used by the system (in leiu of pid)
        rider_uuid: nil,
        # requests sent out to riders
        rider_requests: [],
        # time of accepted request
        request_datetime: nil,          
        # located a rider to send a pickup request
        has_rider: False,
        # rider is in the driver
        in_vehicle: False,
        # moving or stopped
        is_driving: False,        
        # at destination?
        arrived: False,
        # ride history
        ride_history: [],
        # time of the pickup
        meter_on: nil,
        # date time of the dropoff
        meter_off: nil,         
        # where the driver is currently driving through
        curr_route: nil,        
        # where at currently
        curr_loc: nil,     
        # where to pickup up the rider
        pickup_loc: nil,
        # where to dropoff the rider
        dropoff_loc: nil,         
        # current destination
        dest_loc: nil,
        # Plots entire shift including search.
        zones_traveled: [],        
        # save the routes, so we can plot the driving
        routes_traveled: []       
    ]
end