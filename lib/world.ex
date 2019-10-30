defmodule Nim.World do
  use GenServer

  @spec add(any, any) :: :ok
  def add(nim, pid), do: GenServer.cast(__MODULE__, {:add, nim, pid})

  def add_fence(id, position), do: GenServer.cast(__MODULE__, {:add_fence, id, position})

  def eat_grass(grass_pos), do: GenServer.cast(__MODULE__, {:eat_grass, grass_pos})

  def remove(nim_id), do: GenServer.call(__MODULE__, {:remove, nim_id})

  def update(nim_id, pos), do: GenServer.cast(__MODULE__, {:update, nim_id, pos})

  def population(), do: GenServer.call(__MODULE__, :population)

  def farm(), do: GenServer.call(__MODULE__, :farm)

  def graveyard(), do: GenServer.call(__MODULE__, :graveyard)

  def objects(), do: GenServer.call(__MODULE__, :objects)

  def get_nim(id) do
    Module.concat(Nim.NimServer, id)
    |> GenServer.call(:appear)
  end

  def get_pid_nim(id) do
    GenServer.call(__MODULE__, {:pid_nim, id})
  end

  def start_link(state) when is_map(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  @impl true
  def init(state \\ %{}) do
    schedule_pulse()
    {:ok, default_map() |> Map.merge(state)}
  end

  @impl true
  def handle_call({:remove, nim_id}, _from, state) do
    nim = state.population |> Map.get(nim_id)
    population = state.population |> Map.delete(nim_id)
    graveyard = [nim_id | state.graveyard]

    state = delete_object(state, [nim.pos], :nim)

    {:reply, state.population |> Map.get(nim_id),
     %{state | population: population, graveyard: graveyard}}
  end

  @impl true
  def handle_call(:graveyard, _from, state) do
    {:reply, state.graveyard, state}
  end

  @impl true
  def handle_call(:population, _from, state) do
    {:reply, state.population, state}
  end

  @impl true
  def handle_call(:farm, _from, state) do
    {:reply, state.farm, state}
  end

  @impl true
  def handle_call(:objects, _from, state) do
    {:reply, state.objects, state}
  end

  @impl true
  def handle_call({:pid_nim, nim_id}, _from, state) do
    {:reply, state.population |> Map.get(nim_id), state}
  end

  @impl true
  def handle_cast({:add, nim, pid}, state) do
    population = state.population |> Map.put(nim.id, %{pos: nim.pos, pid: pid})

    state = add_object(state, [nim.pos], :nim)

    {:noreply, %{state | population: population}}
  end

  @impl true
  def handle_cast({:update, nim_id, pos}, state) do
    nim = state.population |> Map.get(nim_id)

    state =
      delete_object(state, [nim.pos], :nim)
      |> add_object([pos], :nim)

    nim_attrs = nim |> Map.put(:pos, pos)
    population = state.population |> Map.put(nim_id, nim_attrs)

    {:noreply, %{state | population: population}}
  end

  @impl true
  def handle_cast({:add_fence, id, positions}, state) do
    fences = state.fences |> Map.put(id, positions)
    state = add_object(state, positions, :wall)
    {:noreply, %{state | fences: fences}}
  end

  @impl true
  def handle_cast({:eat_grass, position}, state) do
    farm = state.farm |> List.delete(position)
    state = delete_object(state, [position], :food)
    {:noreply, %{state | farm: farm}}
  end

  defp default_map() do
    %{
      population: %{},
      graveyard: [],
      farm: [],
      fences: %{},
      objects: []
    }
  end

  @impl true
  def handle_info(:pulse, state) do
    schedule_pulse()

    {:noreply, state |> pulse()}
  end

  def schedule_pulse() do
    Process.send_after(self(), :pulse, 500)
  end

  def pulse(world) do
    world
    |> farm()
    |> case do
      :noop -> world
      world -> world
    end
  end

  defp farm(world) do
    with {x, y} <- generate_possible_grass_position(world) do
      position = {x, y}
      farm = [position | world.farm]
      world = %{world | farm: farm}
      world |> add_object([position], :food)
    end
  end

  defp generate_possible_grass_position(world) do
    {
      1..18 |> Enum.random(),
      3..18 |> Enum.random()
    }
    |> check_position(world)
  end

  defp check_position(position, world) do
    world.objects
    |> Enum.any?(fn object ->
      {x, y, _} = object
      {x, y} == position
    end)
    |> case do
      false -> position
      _ -> :noop
    end
  end

  defp delete_object(%{objects: objects} = state, positions, type) do
    objects =
      positions
      |> handle_positions(type)
      |> Enum.reduce(objects, fn position, objects ->
        objects |> List.delete(position)
      end)

    %{state | objects: objects}
  end

  defp add_object(%{objects: objects} = state, positions, type) do
    positions = positions |> handle_positions(type)
    %{state | objects: objects ++ positions}
  end

  defp handle_positions(positions, type) do
    positions
    |> Enum.reduce([], fn p, acc ->
      pos = p |> Tuple.insert_at(2, type)
      [pos | acc]
    end)
  end
end
