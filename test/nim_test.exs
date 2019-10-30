defmodule NimTest do
  use ExUnit.Case
  doctest Nim

  test "greets the world" do
    assert Nim.hello() == :world
  end
end
