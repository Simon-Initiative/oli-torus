defmodule Oli.Lti.KeysetFetchCoordinatorTest do
  use ExUnit.Case, async: false

  alias Oli.Lti.KeysetFetchCoordinator

  @test_url "https://example.com/jwks"

  describe "run/3" do
    test "AC-001 AC-002 AC-006 coalesces concurrent callers for the same url" do
      parent = self()

      tasks =
        Enum.map(1..2, fn _ ->
          Task.async(fn ->
            KeysetFetchCoordinator.run(@test_url, fn ->
              send(parent, :fetch_executed)
              Process.sleep(50)
              {:ok, :fetched}
            end)
          end)
        end)

      assert_receive :fetch_executed
      refute_receive :fetch_executed, 100
      assert Enum.map(tasks, &Task.await(&1, 1_000)) == [{:ok, :fetched}, {:ok, :fetched}]
    end

    test "returns a bounded timeout error when the owner fetch exceeds the timeout" do
      assert {:error, :single_flight_timeout} =
               KeysetFetchCoordinator.run(
                 @test_url,
                 fn ->
                   Process.sleep(50)
                   {:ok, :fetched}
                 end,
                 10
               )
    end

    test "returns owner down for waiters when the fetch owner exits" do
      parent = self()

      owner =
        spawn(fn ->
          KeysetFetchCoordinator.run(@test_url, fn ->
            send(parent, :owner_started)
            Process.sleep(5_000)
            {:ok, :fetched}
          end)
        end)

      assert_receive :owner_started

      waiter =
        Task.async(fn ->
          KeysetFetchCoordinator.run(@test_url, fn ->
            {:ok, :unexpected_second_fetch}
          end)
        end)

      Process.sleep(50)
      Process.exit(owner, :kill)

      assert {:error, :single_flight_owner_down} = Task.await(waiter, 1_000)
    end
  end
end
