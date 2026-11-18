defmodule Mix.Tasks.Oli.GenerateContentDispatcherTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Oli.GenerateContentDispatcher

  test "check mode detects stale output without writing and regeneration restores it" do
    path = Path.join(System.tmp_dir!(), "dispatcher-#{System.unique_integer([:positive])}.json")
    on_exit(fn -> File.rm!(path) end)
    schema = "priv/schemas/v0-1-0/content-element.schema.json" |> File.read!() |> Jason.decode!()
    stale = put_in(schema, ["$defs", "typed-element", "allOf"], []) |> Jason.encode!()
    File.write!(path, stale)
    assert_raise Mix.Error, ~r/stale/, fn -> GenerateContentDispatcher.run(["--check", path]) end
    assert File.read!(path) == stale
    GenerateContentDispatcher.run([path])
    assert :ok = GenerateContentDispatcher.run(["--check", path])
    bytes = File.read!(path)
    GenerateContentDispatcher.run([path])
    assert File.read!(path) == bytes
  end
end
