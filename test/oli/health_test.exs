defmodule Oli.HealthTest do
  use ExUnit.Case, async: false

  alias Oli.Health

  setup do
    Health.starting()

    on_exit(fn ->
      Health.starting()
      Health.started()
    end)
  end

  test "uninitialized state fails closed" do
    :persistent_term.erase({Health, :lifecycle})
    refute Health.live?()
    refute Health.ready?()
    assert Health.state() == :starting
  end

  test "startup completion, idempotent drain, and restart reset" do
    assert Health.state() == :starting
    refute Health.live?()
    refute Health.ready?()
    Health.started()
    assert Health.state() == :running
    assert Health.live?()
    assert :ok = Oli.Release.drain()
    assert :ok = Oli.Release.drain()
    assert Health.state() == :draining
    assert Health.live?()
    refute Health.ready?()
    Health.starting()
    assert Health.state() == :starting
    refute Health.live?()
    refute Health.ready?()
  end

  test "completion never overwrites a drain requested during startup" do
    Health.drain()
    refute Health.live?()
    Health.started()
    assert Health.state() == :draining
    assert Health.live?()
    refute Health.ready?()
  end

  test "concurrent completion and drain preserve both flags" do
    for _ <- 1..100 do
      Health.starting()
      tasks = [Task.async(&Health.started/0), Task.async(&Health.drain/0)]
      Enum.each(tasks, &Task.await/1)
      assert Health.state() == :draining
      assert Health.live?()
    end
  end

  test "prep_stop marks draining and preserves application callback state" do
    Health.started()
    assert Oli.Application.prep_stop(:application_state) == :application_state
    assert Health.state() == :draining
    assert Health.live?()
  end
end
