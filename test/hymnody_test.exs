defmodule HymnodyTest do
  use ExUnit.Case
  doctest Hymnody

  test "greets the world" do
    assert Hymnody.hello() == :world
  end
end
