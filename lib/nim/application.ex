defmodule Nim.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    main_viewport_config = Application.get_env(:nim, :viewport)

    children = [
      {Nim.World, %{}},
      supervisor(Scenic, viewports: [main_viewport_config]),
      %{id: Nim.WorldSupervisor, start: {Nim.WorldSupervisor, :start_link, [[]]}}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Nim.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
