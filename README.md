<img src="assets/logo.png" align="right" />

## Elber
Elixir based ride-sharing simulator inspired by a few of those companies we know.

### Concept
I wanted to learn Elixir so decided to do a little pet project.  Decided to write a simple ride sharing simulator engine to create fare records for analyzing. This is a first project in Elixir.  Have to say, I'm loving the language.

Upon starting the app, it will create a square city grid of 12x12 (144 zones) with 500 riders, and 300 drivers.  

**NOTE:**

* This is still a proof of concept.  It's really rough and there is no units tests yet.
* Time is not an accurate factor at this moment
* Drivers and riders are not replenished at the moment
* Driver processes that crash do not respawn
* Rider processes that crash do not respawn

#### Riders
Riders will initialize themselves with a random pickup location and a random dropoff location. As if they are using an app to pick a driver, they will query the zone they want to be picked up in for a driver, and if none is found they will look in adjacent zones.  This will continue until a driver is within range extending currently only to the adjacent zones.

Once a driver is found, a request is sent.  If the request is accepted, they will wait to be picked up.  If they request is denied, they will continue to watch for a driver within range.

#### Drivers
All drivers currently start in Zone1 and will "cruise around" until a rider sends them a request for a ride.  Drivers will move through randomly chosen adjacent zones wandering the grid until they get that beloved request.

After accepting a request, they will notify the rider and proceed to drive to that zone and pick them up.  Using a Breadth First Search, the driver will determine a path from the pickup location to the dropoff location. Upon arrival, the driver will create a record of the fare, write it to a history CSV file, kick out the rider, reset itself, and start wandering around again.

Currently each driver will transit 100 zones before punching off the clock.

----
## Improvements/Additions
- Driver state management.  If driver process dies, it will respawn from last known state state
- Running on a realistic and accurate time framework
- Design driver management and replenishment to ebb and flow with customer demand
- Set rider thresholds to manage the number the customer demand
- City status report
  - Total drivers available
  - Total drivers in transit to pickup
  - Total drivers in transit to destination
  - Total riders searching
  - Total riders waiting to be picked up
  - Total riders in transit
  - etc
- Phoenix webapp to visualize the city environment
