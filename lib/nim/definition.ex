defmodule Nim.Definition do
  defstruct id: nil,
            age: 0,
            color: nil,
            left_sensor: %{
              distance: 0,
              found: nil
            },
            right_sensor: %{
              distance: 0,
              found: nil
            },
            front_sensor: %{
              distance: 0,
              found: nil
            },
            sensor_distance: 5,
            compass: %{north: nil, south: :front_sensor, east: :right_sensor, west: :left_sensor},
            energy: 100,
            storage: 0,
            front_of: :south,
            pos: nil,
            eaten: []
end
