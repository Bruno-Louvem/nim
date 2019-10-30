defmodule Nim do
  @moduledoc """
  Documentation for Nim.
  """
  alias Nim.Definition

  @maximum_age 100

  @spec born :: Nim.Definition.t()
  def born() do
    %Definition{id: generate_id(), pos: generate_pos()}
  end

  @spec born(any) :: Nim.Definition.t()
  def born(name, pos \\ {1, 1}) do
    %Definition{id: name, pos: pos}
  end

  def eat(nim) do
    Nim.World.eat_grass(nim.pos)

    nim
    |> do_eat(nim.eaten)
    |> increase_energy(10)
    |> add_to_storage()
    |> decide_if_replicate()
  end

  def do_eat(nim, _) do
    %{nim | eaten: [nim.pos | nim.eaten]}
  end

  defp add_to_storage(nim) do
    if nim.energy > 100 do
      storage = nim.storage + (nim.energy - 100)
      # IO.puts("STORAGE: #{storage} - NIM: #{nim.id}")
      %{nim | storage: storage, energy: 100}
    else
      nim
    end
  end

  defp decide_if_replicate(nim) do
    if nim.storage > 100 do
      IO.puts("REPLICATION FROM #{nim.id}!!!!!!")
      replicate(nim.pos)
      {:ok, %{nim | storage: 0}}
    else
      {:ok, nim}
    end
  end

  def death(nim) do
    Nim.WorldSupervisor.terminate_child(nim.id)
  end

  defp generate_id() do
    first = Faker.Name.PtBr.first_name() |> String.capitalize()
    hash = Nanoid.generate(64)
    "#{first}_#{hash}"
  end

  defp decrease_energy(energy, nim) when energy > 0 do
    %{nim | energy: energy - 2}
  end

  defp decrease_energy(_energy, nim) do
    IO.puts("DEATH #{nim.id}!!!!!!")
    IO.puts("REASON: LOW ENERGY")
    death(nim)
  end

  defp increase_energy(nim, energy) do
    %{nim | energy: nim.energy + energy}
  end

  defp increase_age(%Definition{age: age} = nim) when age >= @maximum_age do
    IO.puts("DEATH #{nim.id}!!!!!!")
    IO.puts("REASON: MAX AGE")

    death(nim)
  end

  defp increase_age(%Definition{age: age} = nim) do
    %{nim | age: age + 1}
  end

  defp replicate(pos) do
    generate_id()
    |> Nim.WorldSupervisor.start_child(pos)
  end

  def generate_pos() do
    {10, 10}
  end

  def pulse(%Definition{age: age} = nim) when age < 2, do: increase_age(nim)

  def pulse(nim) do
    with {:ok, nim} <- read_sensors(nim),
         {:ok, nim} <- decide(nim) do
      nim |> increase_age()
    end
  end

  def read_sensors(nim) do
    sensors =
      nim
      |> check_distance_on_board(nim.sensor_distance, nim.pos)
      |> make_sensor_map()

    {:ok, Map.merge(nim, sensors)}
  end

  defp make_sensor_map(distances) do
    distances
    |> Enum.reduce(%{}, fn data, acc ->
      acc |> Map.merge(data)
    end)
  end

  defp check_distance_on_board(nim, distance, position) do
    nim.compass
    |> get_readble_directions()
    |> Enum.map(fn dir ->
      line =
        {Nim.Helpers.wk_dir(dir, position, 1), Nim.Helpers.wk_dir(dir, position, distance + 1)}

      %{
        nim.compass[dir] =>
          Nim.World.objects()
          |> Nim.Helpers.check_line(line)
      }
    end)
  end

  defp get_readble_directions(compass) do
    compass
    |> Map.keys()
    |> Enum.filter(fn x ->
      compass
      |> Map.fetch!(x)
      |> is_nil() == false
    end)
  end

  def decide(nim) do
    distance_by_compass = nim |> value_sensors_by_compass()

    {direction, data} =
      distance_by_compass
      |> Enum.max_by(fn {_, data_dir} ->
        available_compass(nim.sensor_distance, data_dir)
      end)

    nim |> decide_if_turn(direction) |> walk() |> eat?(data)
  end

  def eat?(nim, data) do
    if data.distance == -1 and data.limit_type == :food, do: eat(nim), else: {:ok, nim}
  end

  def available_compass(default_distance, data) do
    case data.limit_type do
      :food ->
        distance = if data.distance <= 0, do: 1, else: data.distance
        ((default_distance + 1 / distance) |> trunc()) + 1

      :horizon ->
        data.distance

      _ ->
        distance = if data.distance <= 0, do: 5, else: data.distance
        ((default_distance / (distance + 1)) |> trunc()) - 1
    end
  end

  defp decide_if_turn(nim, direction) do
    if nim.front_of != direction do
      turn(nim, direction)
    else
      nim
    end
  end

  def walk(nim) do
    {:ok, nim} = read_sensors(nim)

    if validate_sensor(nim, nim.front_of, 1) do
      new_pos = Nim.Helpers.wk_dir(nim.front_of, nim.pos, 1)
      nim.id |> Nim.World.update(new_pos)
      nim = nim.energy |> decrease_energy(nim)
      %{nim | pos: new_pos}
    else
      nim
    end
  end

  def walk(nim, steps) do
    {:ok, nim} = read_sensors(nim)

    if validate_sensor(nim, nim.front_of, steps) do
      new_pos = Nim.Helpers.wk_dir(nim.front_of, nim.pos, steps)
      nim.id |> Nim.World.update(new_pos)
      nim = nim.energy |> decrease_energy(nim)
      %{nim | pos: new_pos}
    else
      nim
    end
  end

  defp value_sensors_by_compass(nim) do
    nim.compass
    |> get_readble_directions()
    |> Enum.map(fn x ->
      value = nim |> Map.fetch!(nim.compass |> Map.fetch!(x))
      {x, value}
    end)
  end

  def turn(nim, direction) do
    %{nim | front_of: direction}
    |> calibrate_compass()

    # |> read_sensors()
  end

  def calibrate_compass(robot) do
    compass =
      case robot.front_of do
        :north -> %{north: :front_sensor, south: nil, east: :right_sensor, west: :left_sensor}
        :south -> %{north: nil, south: :front_sensor, east: :left_sensor, west: :right_sensor}
        :east -> %{north: :left_sensor, south: :right_sensor, east: :front_sensor, west: nil}
        :west -> %{north: :right_sensor, south: :left_sensor, east: nil, west: :front_sensor}
      end

    %{robot | compass: compass}
  end

  defp validate_sensor(nim, direction, distance) do
    sensor_value =
      case direction do
        :bottom -> nim.front_sensor
        :left -> nim.left_sensor
        :right -> nim.right_sensor
        _ -> nim.front_sensor
      end

    sensor_value >= distance
  end

  @spec go_to({any, any}, :bottom | :left | :rigth | :up) :: {any, any}
  def go_to({x, y} = _current_pos, :up), do: {x, y - 1}
  def go_to({x, y} = _current_pos, :bottom), do: {x, y + 1}
  def go_to({x, y} = _current_pos, :left), do: {x - 1, y}
  def go_to({x, y} = _current_pos, :rigth), do: {x + 1, y}
end
