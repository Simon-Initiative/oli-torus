defmodule Oli.RuntimeLogOverrides.DebugRevertConfigTest do
  use ExUnit.Case, async: true

  alias Oli.RuntimeLogOverrides.DebugRevertConfig

  describe "from_env!/1" do
    test "defaults to 30 minutes and warning" do
      assert DebugRevertConfig.from_env!(%{}) == [timeout_minutes: 30, revert_level: :warning]
    end

    test "parses configured values, ignoring case and surrounding whitespace" do
      env = %{
        "DEBUG_LOG_LEVEL_TIMEOUT_MINUTES" => " 15 ",
        "DEBUG_LOG_LEVEL_REVERT_LEVEL" => "ERROR"
      }

      assert DebugRevertConfig.from_env!(env) == [timeout_minutes: 15, revert_level: :error]
    end

    test "rejects non-positive or non-numeric timeouts" do
      for value <- ["0", "-5", "ten", "1.5"] do
        assert_raise ArgumentError, ~r/DEBUG_LOG_LEVEL_TIMEOUT_MINUTES/, fn ->
          DebugRevertConfig.from_env!(%{"DEBUG_LOG_LEVEL_TIMEOUT_MINUTES" => value})
        end
      end
    end

    test "rejects unknown levels and debug as revert level" do
      for value <- ["verbose", "debug"] do
        assert_raise ArgumentError, ~r/DEBUG_LOG_LEVEL_REVERT_LEVEL/, fn ->
          DebugRevertConfig.from_env!(%{"DEBUG_LOG_LEVEL_REVERT_LEVEL" => value})
        end
      end
    end
  end
end
