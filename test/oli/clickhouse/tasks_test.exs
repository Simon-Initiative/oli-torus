defmodule Oli.ClickHouse.TasksTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Oli.ClickHouse.Tasks

  describe "reset/0" do
    test "requires explicit confirmation before proceeding" do
      output =
        capture_io("no\n", fn ->
          assert :cancelled = Tasks.reset()
        end)

      assert output =~ "WARNING! This will completely erase all data from the ClickHouse database."
      assert output =~ "Enter RESET CLICKHOUSE to continue"
      assert output =~ "--force to bypass"
      assert output =~ "ABORTED: Operation was not confirmed by user."
    end
  end
end
