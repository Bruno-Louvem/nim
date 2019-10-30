defmodule Nim.Helpers do
  def wk_dir(:south, {x, y}), do: {x, y + 1}
  def wk_dir(:north, {x, y}), do: {x, y - 1}
  def wk_dir(:west, {x, y}), do: {x - 1, y}
  def wk_dir(:east, {x, y}), do: {x + 1, y}

  def wk_dir(:south, {x, y}, len), do: {x, y + len}
  def wk_dir(:north, {x, y}, len), do: {x, y - len}
  def wk_dir(:west, {x, y}, len), do: {x - len, y}
  def wk_dir(:east, {x, y}, len), do: {x + len, y}

  def get_dir({{x1, _}, {x2, _}}) when x1 < x2, do: :east
  def get_dir({{x1, _}, {x2, _}}) when x1 > x2, do: :west
  def get_dir({{_, y1}, {_, y2}}) when y1 < y2, do: :south
  def get_dir({{_, y1}, {_, y2}}) when y1 > y2, do: :north

  def get_len(:east, {{x1, _}, {x2, _}}), do: x2 - x1
  def get_len(:west, {{x1, _}, {x2, _}}), do: x1 - x2
  def get_len(:south, {{_, y1}, {_, y2}}), do: y2 - y1
  def get_len(:north, {{_, y1}, {_, y2}}), do: y1 - y2

  @spec dir_to_compass(<<_::16, _::_*8>>) :: :east | :north | :south | :west
  def dir_to_compass("up"), do: :north
  def dir_to_compass("down"), do: :south
  def dir_to_compass("right"), do: :east
  def dir_to_compass("left"), do: :west

  def get_all_pos_line(:horizontal, len, start_pos), do: get_all_pos_line(:east, len, start_pos)
  def get_all_pos_line(:vertical, len, start_pos), do: get_all_pos_line(:south, len, start_pos)

  def get_all_pos_line(dir, len, start_pos) do
    0..len
    |> Enum.map_reduce(
      start_pos,
      fn _, last_pos ->
        cur_pos = wk_dir(dir, last_pos)
        {last_pos, cur_pos}
      end
    )
    |> elem(0)
  end

  def check_line(board, tuple_line) do
    {start_post, _} = tuple_line
    dir = get_dir(tuple_line)
    len = get_len(dir, tuple_line)

    get_all_pos_line(dir, len, start_post)
    |> check_l(board, {0, nil, :horizon})
  end

  def check_l([pos | rest_line], board, {counter, last_pos, type}) do
    with true <- inside_board?(pos),
         {false, _, type} <- occupied_tile?(board, pos) do
      check_l(rest_line, board, {counter + 1, pos, type})
    else
      false -> check_l([], board, {counter, last_pos, type})
      {true, _, type} -> check_l([], board, {counter, last_pos, type})
    end
  end

  def check_l([], _, {distance, last_valid_pos, type}) do
    %{last_valid_pos: last_valid_pos, distance: distance - 1, limit_type: type}
  end

  def inside_board?({x, y}) do
    {x0, y0} = {0, 2}
    {x1, y1} = {x0 + 21, y0 + 21}
    x0 < x and x1 > x and (y0 < y and y1 > y)
  end

  def occupied_tile?(board, {x, y} = position) when x > 0 and y > 0 do
    board
    |> Enum.reduce_while({false, nil, :horizon}, fn {x1, y1, type}, acc ->
      if {x1, y1} == position do
        {:halt, {true, {x1, y1}, type}}
      else
        {:cont, acc}
      end
    end)
  end

  def occupied_tile?(_, _), do: {false, nil, :horizon}
end
