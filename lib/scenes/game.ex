defmodule Nim.Scene.Game do
  use Scenic.Scene
  require Logger

  alias Scenic.Graph
  alias Scenic.ViewPort

  import Scenic.Primitives
  import Nim.Scene.Helpers
  # import Scenic.Components

  @graph Graph.build(font: :roboto, font_size: 36)
  @tile_size 40

  @panel_height 40

  @grass_path :code.priv_dir(:nim)
              |> Path.join("/static/grass.png")

  @red_bug_path :code.priv_dir(:nim)
                |> Path.join("/static/red_bug.png")

  @blue_bug_path :code.priv_dir(:nim)
                 |> Path.join("/static/blue_bug.png")

  @green_bug_path :code.priv_dir(:nim)
                  |> Path.join("/static/the_first.png")

  @red_bug_hash @red_bug_path
                |> Scenic.Cache.Support.Hash.file!(:sha)

  @blue_bug_hash @blue_bug_path
                 |> Scenic.Cache.Support.Hash.file!(:sha)

  @green_bug_hash @green_bug_path
                  |> Scenic.Cache.Support.Hash.file!(:sha)

  @grass_hash @grass_path
              |> Scenic.Cache.Support.Hash.file!(:sha)

  @wall_width 20
  @wall_height 20
  @wall_position_y 0
  @wall_position_x 0

  # ============================================================================
  # setup

  # --------------------------------------------------------
  def init(_, opts) do
    viewport = opts[:viewport]

    # calculate the transform that centers the snake in the viewport
    {:ok, %ViewPort.Status{size: {vp_width, vp_height}}} = ViewPort.info(viewport)
    vp_height = vp_height - @panel_height

    # how many tiles can the viewport hold in each dimension?
    vp_tile_width = trunc(vp_width / @tile_size) |> IO.inspect(label: "Tile width")
    vp_tile_height = trunc(vp_height / @tile_size) |> IO.inspect(label: "Tile height")

    panel_tile_qtd = trunc(@panel_height / vp_tile_height) |> IO.inspect(label: "Panel offset")

    {:ok, timer} = :timer.send_interval(100, :frame)

    Scenic.Cache.Static.Texture.load(@red_bug_path, @red_bug_hash)
    Scenic.Cache.Static.Texture.load(@blue_bug_path, @blue_bug_hash)
    Scenic.Cache.Static.Texture.load(@green_bug_path, @green_bug_hash)
    Scenic.Cache.Static.Texture.load(@grass_path, @grass_hash)

    Nim.WorldSupervisor.start_child("TheFirst")

    # Logger.info("Start the world")
    # Logger.info("Initial population: #{inspect(Nim.World.population())}")

    state = %{
      viewport: viewport,
      tile_width: vp_tile_width,
      tile_height: vp_tile_height,
      panel_tile_qtd: panel_tile_qtd,
      frame_count: 1,
      frame_timer: timer
    }

    # Update the graph and push it to be rendered

    graph =
      @graph
      |> setup_wall(panel_tile_qtd)
      |> draw_counter_panel()
      |> draw_nims()

    state = state |> Map.put(:graph, graph)

    {:ok, state, [push: graph]}
  end

  defp draw_counter_panel(graph) do
    panel_text = "Number of nims: #{Nim.World.population() |> Map.keys() |> length()}"

    graph
    |> text("Number of nims:", translate: {@tile_size / 2, @tile_size}, id: :text)
    |> Graph.modify(:_root_, &update_opts(&1, styles: [translate: {@tile_size / 2, @tile_size}]))
    |> Graph.modify(:text, &text(&1, panel_text))
  end

  def setup_wall(graph, panel_tile_qtd) do
    adjusted_y = @wall_position_y + panel_tile_qtd
    wall_height = @wall_height + panel_tile_qtd

    [
      {:horizontal, {@wall_position_x, adjusted_y}, @wall_width, :north},
      {:horizontal, {@wall_position_x, @wall_height}, @wall_width, :south},
      {:vertical, {@wall_position_x, adjusted_y}, wall_height, :west},
      {:vertical, {@wall_position_x + @wall_width - 1, adjusted_y}, wall_height, :east}
    ]
    |> Enum.reduce(graph, fn {orientation, position, len, dir}, graph ->
      wall_id = "wall_#{dir}" |> String.to_atom()
      wall_opts = [fill: :blue] |> Keyword.merge(id: wall_id)

      positions = Nim.Helpers.get_all_pos_line(orientation, len, position)
      Nim.World.add_fence(wall_id, positions)
      graph |> draw_line(orientation, position, len, wall_opts)
    end)
  end

  defp clean_dead_nims(graph) do
    Nim.World.graveyard()
    |> Enum.reduce(graph, fn id, graph ->
      nim_id = id |> String.to_atom()
      graph |> Graph.delete(nim_id)
    end)
  end

  defp clean_eaten_grass(graph, nim_id) do
    nim = Nim.World.get_nim(nim_id)

    nim.eaten
    |> Enum.reduce(graph, fn {x, y}, graph ->
      grass_id = "grass_#{x}_#{y}" |> String.to_atom()
      graph |> Graph.delete(grass_id)
    end)
  end

  defp draw_nims(graph) do
    Nim.World.population()
    |> Enum.reduce(graph, fn {id, nim_attr}, graph ->
      nim_id = id |> String.to_atom()

      upsert_nim(:check, graph, nim_id, nim_attr.pos)
      |> clean_eaten_grass(nim_id)
    end)
  end

  defp upsert_nim(:check, graph, id, pos) do
    list_nim =
      graph
      |> Graph.get(id)

    op = if list_nim |> length() == 0, do: :insert, else: :update
    upsert_nim(op, graph, id, pos)
  end

  defp upsert_nim(:insert, graph, id, {x, y}) do
    graph |> draw_bug(x, y, id: id)
  end

  defp upsert_nim(:update, graph, id, {x, y}) do
    graph |> update_bug(x, y, id: id)
  end

  defp draw_bug(graph, x, y, opts) do
    image_hash = get_color_bug(opts[:id])

    opts =
      opts
      |> Keyword.merge(
        fill: {:image, image_hash},
        rotate: get_nim_rotate(opts[:id]),
        translate: {x * @tile_size, y * @tile_size}
      )
      |> IO.inspect(label: "opts nim")

    graph
    |> rect({@tile_size, @tile_size}, opts)
  end

  defp get_color_bug(:TheFirst), do: @green_bug_hash
  defp get_color_bug(_), do: [@red_bug_hash, @blue_bug_hash] |> Enum.random()

  defp draw_grass(graph) do
    Nim.World.farm()
    |> Enum.reduce(graph, fn {x, y}, graph ->
      grass_id = "grass_#{x}_#{y}" |> String.to_atom()

      opts = [
        id: grass_id,
        fill: {:image, @grass_hash},
        translate: {x * @tile_size, y * @tile_size}
      ]

      graph
      |> rect({@tile_size, @tile_size}, opts)
    end)
  end

  defp get_nim_rotate(nim_id) do
    nim_id |> Atom.to_string() |> Nim.World.get_nim() |> Map.get(:front_of) |> calc_rotate()
  end

  defp calc_rotate(:west), do: 4.71
  defp calc_rotate(:east), do: 1.57
  defp calc_rotate(:north), do: 0
  defp calc_rotate(:south), do: 3.14

  defp update_bug(graph, x, y, opts) do
    opts =
      opts
      |> Keyword.merge(
        translate: {x * @tile_size, y * @tile_size},
        rotate: get_nim_rotate(opts[:id])
      )

    Graph.modify(graph, opts[:id], &update_opts(&1, opts))
  end

  def handle_info(:frame, %{frame_count: frame_count} = state) do
    # state = move_nim(state)
    graph =
      state.graph
      |> draw_counter_panel()
      |> clean_dead_nims()
      |> draw_nims()
      |> draw_grass()

    {:noreply, %{state | frame_count: frame_count + 1, graph: graph}, push: graph}
  end

  def handle_input(_event, _context, state) do
    # Logger.info("Received event: #{inspect(event)}")
    {:noreply, state}
  end
end
