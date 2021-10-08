defmodule WatcherTest do
  use ExUnit.Case
  doctest Watcher

  test "greets the world" do
    assert Watcher.hello() == :world
  end
end
