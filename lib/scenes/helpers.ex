defmodule Nim.Scene.Helpers do
  import Scenic.Primitives
  alias Scenic.Graph

  @tile_size 40

  def draw_tile(graph, x, y, opts) do
    tile_opts = Keyword.merge([fill: :white, translate: {x * @tile_size, y * @tile_size}], opts)
    graph |> rrect({@tile_size, @tile_size, 5}, tile_opts)
  end

  @spec update_tile(Scenic.Graph.t(), number, number, keyword) :: Scenic.Graph.t()
  def update_tile(graph, x, y, opts) do
    tile_opts = Keyword.merge([fill: :white, translate: {x * @tile_size, y * @tile_size}], opts)
    graph |> Graph.modify(opts[:id], &rrect(&1, {@tile_size, @tile_size, 5}, tile_opts))
  end

  @spec draw_tile_line(any, :horizontal | :vertical, {any, any}, integer, any) :: any
  def draw_tile_line(graph, :horizontal, {x, y}, len, opts) do
    x..(len - 1)
    |> Enum.reduce(graph, fn xi, graph ->
      opts = opts |> Keyword.merge(id: "#{opts[:id]}_#{xi}" |> String.to_atom())
      graph |> draw_tile(xi, y, opts)
    end)
  end

  def draw_tile_line(graph, :vertical, {x, y}, len, opts) do
    y..(len - 1)
    |> Enum.reduce(graph, fn yi, graph ->
      opts = opts |> Keyword.merge(id: "#{opts[:id]}_#{yi}" |> String.to_atom())
      graph |> draw_tile(x, yi, opts)
    end)
  end

  def draw_line(graph, :horizontal, {x, y}, len, opts) do
    opts =
      opts
      |> Keyword.merge(
        id: "#{opts[:id]}" |> String.to_atom(),
        translate: {x * @tile_size, y * @tile_size}
      )

    graph |> rect({@tile_size * len, @tile_size}, opts)
  end

  def draw_line(graph, :vertical, {x, y}, len, opts) do
    opts =
      opts
      |> Keyword.merge(
        id: "#{opts[:id]}" |> String.to_atom(),
        translate: {x * @tile_size, y * @tile_size}
      )

    graph |> rect({@tile_size, @tile_size * len}, opts)
  end
end
