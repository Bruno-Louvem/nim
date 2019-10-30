defmodule Nim.WorldSupervisor do
  use DynamicSupervisor

  def start_link(_arg) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def start_child(name, pos \\ {1, 3}) do
    spec = {Nim.NimServer, name: name, pos: pos}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  def terminate_child(name) do
    %{pid: pid} = Nim.World.get_pid_nim(name)
    Nim.World.remove(name)
    DynamicSupervisor.terminate_child(__MODULE__, pid)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
