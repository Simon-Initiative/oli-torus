defmodule Oli.Dashboard.Cache.MissCoalescerTest do
  use ExUnit.Case, async: true

  alias Oli.Dashboard.Cache.MissCoalescer

  test "claims one producer and one waiter for identical key and shares producer result" do
    coalescer = start_supervised!({MissCoalescer, []})
    cache_key = {:dashboard_oracle, :progress, 1, :container, 10, 1, 1}

    assert {:producer, _producer_claim} = MissCoalescer.claim(coalescer, cache_key)

    parent = self()

    waiter_task =
      Task.async(fn ->
        assert {:waiter, waiter_ref} = MissCoalescer.claim(coalescer, cache_key)
        send(parent, {:waiter_claimed, waiter_ref})
        MissCoalescer.await(waiter_ref, 100)
      end)

    assert_receive {:waiter_claimed, _waiter_ref}

    :ok = MissCoalescer.publish(coalescer, cache_key, {:ok, %{value: 42}})

    assert {:ok, %{value: 42}} = Task.await(waiter_task, 200)
  end

  test "notifies waiters when producer goes down before publish" do
    coalescer = start_supervised!({MissCoalescer, []})
    parent = self()
    cache_key = {:dashboard_oracle, :objectives, 1, :container, 10, 1, 1}

    producer_pid =
      spawn(fn ->
        claim = MissCoalescer.claim(coalescer, cache_key)
        send(parent, {:producer_claim, claim})
        Process.sleep(:infinity)
      end)

    assert_receive {:producer_claim, {:producer, _claim_ref}}
    assert {:waiter, waiter_ref} = MissCoalescer.claim(coalescer, cache_key)

    Process.exit(producer_pid, :kill)

    assert {:error, {:coalescer_producer_down, :killed}} = MissCoalescer.await(waiter_ref, 100)
  end
end
