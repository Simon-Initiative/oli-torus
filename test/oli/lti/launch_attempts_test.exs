defmodule Oli.Lti.LaunchAttemptsTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Lti.LaunchAttempt
  alias Oli.Lti.LaunchAttempts
  alias Oli.Repo

  @telemetry_prefix [:oli, :lti, :launch_attempt]

  describe "create_launch_attempt/1" do
    test "creates a pending launch attempt and emits telemetry" do
      handler_id = attach_handler([@telemetry_prefix ++ [:created]])

      assert {:ok, attempt} =
               LaunchAttempts.create_launch_attempt(%{
                 flow_mode: :legacy_session,
                 transport_method: :session_storage,
                 issuer: "https://platform.example",
                 client_id: "client-1"
               })

      assert attempt.lifecycle_state == :pending_launch
      assert attempt.issuer == "https://platform.example"
      assert attempt.client_id == "client-1"

      assert_receive {:telemetry_event, [:oli, :lti, :launch_attempt, :created], %{count: 1},
                      meta}

      assert meta.attempt_id == attempt.id
      assert meta.transport_method == :session_storage

      detach_handler(handler_id)
    end
  end

  describe "resolve_active_attempt/1" do
    test "resolves an active attempt by state token" do
      attempt = insert(:lti_launch_attempt)

      assert {:ok, resolved} = LaunchAttempts.resolve_active_attempt(attempt.state_token)
      assert resolved.id == attempt.id
    end

    test "marks expired attempts and returns expired" do
      attempt =
        insert(:lti_launch_attempt,
          expires_at:
            DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.add(-5, :second)
        )

      assert {:error, :expired} = LaunchAttempts.resolve_active_attempt(attempt.state_token)

      assert Repo.get!(LaunchAttempt, attempt.id).lifecycle_state == :expired
      assert Repo.get!(LaunchAttempt, attempt.id).failure_classification == :expired_state
    end

    test "treats terminal attempts as consumed" do
      attempt =
        insert(:lti_launch_attempt,
          lifecycle_state: :launch_succeeded,
          consumed_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )

      assert {:error, :consumed} = LaunchAttempts.resolve_active_attempt(attempt.state_token)
    end
  end

  describe "transition_attempt/4" do
    test "updates state atomically and emits telemetry" do
      handler_id = attach_handler([@telemetry_prefix ++ [:transitioned]])
      attempt = insert(:lti_launch_attempt)

      assert {:ok, updated_attempt} =
               LaunchAttempts.transition_attempt(
                 attempt.id,
                 :pending_launch,
                 :launching
               )

      assert updated_attempt.lifecycle_state == :launching
      assert not is_nil(updated_attempt.launched_at)

      assert_receive {:telemetry_event, [:oli, :lti, :launch_attempt, :transitioned], %{count: 1},
                      meta}

      assert meta.attempt_id == attempt.id
      assert meta.from_state == :pending_launch
      assert meta.to_state == :launching

      assert {:error, :transition_conflict} =
               LaunchAttempts.transition_attempt(
                 attempt.id,
                 :pending_launch,
                 :launch_succeeded
               )

      detach_handler(handler_id)
    end
  end

  describe "cleanup_expired/0" do
    test "deletes only cleanup-eligible expired attempts" do
      expired_pending =
        insert(:lti_launch_attempt,
          expires_at:
            DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.add(-5, :second)
        )

      expired_terminal =
        insert(:lti_launch_attempt,
          lifecycle_state: :launch_succeeded,
          consumed_at: DateTime.utc_now() |> DateTime.truncate(:second),
          expires_at:
            DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.add(-5, :second)
        )

      active_future =
        insert(:lti_launch_attempt,
          expires_at:
            DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.add(300, :second)
        )

      assert {:ok, 1} = LaunchAttempts.cleanup_expired()

      refute Repo.get(LaunchAttempt, expired_pending.id)
      assert Repo.get(LaunchAttempt, expired_terminal.id)
      assert Repo.get(LaunchAttempt, active_future.id)
    end
  end

  defp attach_handler(events) do
    handler_id = "launch-attempts-test-#{System.unique_integer([:positive])}"
    parent = self()

    :telemetry.attach_many(
      handler_id,
      events,
      fn event_name, measurements, metadata, _ ->
        send(parent, {:telemetry_event, event_name, measurements, metadata})
      end,
      %{}
    )

    handler_id
  end

  defp detach_handler(handler_id), do: :telemetry.detach(handler_id)
end
