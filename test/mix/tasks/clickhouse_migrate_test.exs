defmodule Mix.Tasks.Clickhouse.MigrateTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Clickhouse.Migrate

  describe "parse_args/1" do
    test "defaults to up when no command is provided" do
      assert {"up", [], []} = Migrate.parse_args([])
    end

    test "parses reset force flag separately from positional args" do
      assert {"reset", ["reset"], [force: true]} = Migrate.parse_args(["reset", "--force"])
    end

    test "preserves create positional arguments" do
      assert {"create", ["create", "add_raw_events"], []} =
               Migrate.parse_args(["create", "add_raw_events"])
    end
  end
end
