defmodule MosaicTest do
  use ExUnit.Case
  doctest Mosaic

  test "greets the world" do
    assert Mosaic.hello() == :world
  end
end
