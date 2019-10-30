defmodule Nim.NimServer do
  use GenServer
  require Logger

  def handle_call(:appear, _from, state) do
    {:reply, state, state}
  end

  def handle_info(:pulse, state) do
    # IO.puts "Nim #{state.id} is alive"
    schedule_pulse()

    {:noreply, state |> Nim.pulse() |> IO.inspect()}
  end

  def schedule_pulse() do
    Process.send_after(self(), :pulse, 600)
  end

  def start_link(attrs) do
    [name: name, pos: pos] = attrs
    Logger.info("Nim server starting with name #{name}")
    module_name = __MODULE__ |> Module.concat(name)
    GenServer.start_link(__MODULE__, [name: name, pos: pos], name: module_name)
  end

  def init(attrs) do
    [name: name, pos: pos] = attrs
    schedule_pulse()
    nim = Nim.born(name, pos)
    Nim.World.add(nim, self())
    {:ok, nim}
  end
end
