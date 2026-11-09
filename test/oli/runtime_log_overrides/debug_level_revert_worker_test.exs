defmodule Oli.RuntimeLogOverrides.DebugLevelRevertWorkerTest do
  use Oli.DataCase, async: false
  use Oban.Testing, repo: Oli.Repo

  import ExUnit.CaptureLog

  alias Oli.RuntimeLogOverrides.DebugLevelRevertWorker

  setup do
    original_level = Logger.level()
    on_exit(fn -> Logger.configure(level: original_level) end)
    :ok
  end

  defp args(overrides \\ %{}) do
    Map.merge(%{"node" => Atom.to_string(node()), "revert_level" => "warning"}, overrides)
  end

  test "reverts the local node from debug to the configured level" do
    Logger.configure(level: :debug)

    log =
      capture_log(fn ->
        assert :ok = perform_job(DebugLevelRevertWorker, args())
      end)

    assert Logger.level() == :warning
    assert log =~ "automatically reverting from debug to warning"
  end

  test "leaves the level unchanged when the node is no longer at debug" do
    Logger.configure(level: :info)

    assert :ok = perform_job(DebugLevelRevertWorker, args())
    assert Logger.level() == :info
  end

  test "is a no-op when the target node is not connected" do
    Logger.configure(level: :debug)

    capture_log(fn ->
      assert :ok = perform_job(DebugLevelRevertWorker, args(%{"node" => "gone@nowhere"}))
    end)

    assert Logger.level() == :debug
  end

  test "discards jobs with an invalid revert level" do
    Logger.configure(level: :debug)

    assert {:discard, _reason} =
             perform_job(DebugLevelRevertWorker, args(%{"revert_level" => "verbose"}))

    assert Logger.level() == :debug
  end
end
