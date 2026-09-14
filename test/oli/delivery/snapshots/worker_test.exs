defmodule Oli.Delivery.Snapshots.WorkerTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Analytics.Common.Pipeline

  alias Oli.Analytics.Summary.{
    ResourcePartResponse,
    ResourceSummary,
    ResponseSummary,
    StudentResponse
  }

  alias Oli.Delivery.Snapshots.Worker
  alias Oli.LearningModel.{AttemptApplication, LearningState, PriorActivityPartEvidence}
  alias Oli.LearningModel.LktAoaFixtures

  describe "perform_now/3" do
    test "returns :ok when part attempts are in :submitted state (not :evaluated)" do
      # Create the full hierarchy needed for the join query
      section = insert(:section)
      user = insert(:user)
      resource = insert(:resource)
      revision = insert(:revision, resource: resource)

      # Create resource access
      resource_access =
        insert(:resource_access, %{
          section: section,
          user: user,
          resource: resource
        })

      # Create resource attempt
      resource_attempt =
        insert(:resource_attempt, %{
          resource_access: resource_access,
          lifecycle_state: :evaluated
        })

      # Create activity attempt  
      activity_attempt =
        insert(:activity_attempt, %{
          resource_attempt: resource_attempt,
          revision: revision,
          lifecycle_state: :evaluated
        })

      # Create part attempt in :submitted state (not :evaluated)
      part_attempt =
        insert(:part_attempt, %{
          activity_attempt: activity_attempt,
          attempt_guid: "test-guid-123",
          # This is the key - not :evaluated
          lifecycle_state: :submitted
        })

      # Call perform_now with the part attempt GUID and section slug
      result = Worker.perform_now([part_attempt.attempt_guid], section.slug)

      # Should return :ok because no evaluated part attempts were found
      assert result == :ok
    end

    test "returns :ok when part attempt guids list is empty" do
      section = insert(:section)

      result = Worker.perform_now([], section.slug)

      assert result == :ok
    end

    test "returns :ok when no part attempts match the guids" do
      section = insert(:section)

      # Call with non-existent GUIDs
      result = Worker.perform_now(["non-existent-guid"], section.slug)

      # Should return :ok because no evaluated part attempts were found
      assert result == :ok
    end

    test "naive sections preserve summary writes without creating LKT operational rows" do
      %{section: section, group: group} =
        LktAoaFixtures.lkt_fixture(%{section_attrs: [learning_model_version: :naive]})

      events =
        capture_lkt_aoa_events(fn ->
          assert Worker.perform_now(attempt_guids(group), section.slug) == :ok
        end)

      assert events == []
      assert Repo.aggregate(AttemptApplication, :count) == 0
      assert Repo.aggregate(PriorActivityPartEvidence, :count) == 0
      assert Repo.aggregate(LearningState, :count) == 0
      assert_summary_rows_created()
    end

    test "lkt_aoa sections apply learning state before preserving summary writes" do
      %{section: section, group: group, objectives: [objective], user: user} =
        LktAoaFixtures.lkt_fixture()

      assert Worker.perform_now(attempt_guids(group), section.slug) == :ok

      assert Repo.aggregate(AttemptApplication, :count) == 1
      assert Repo.aggregate(PriorActivityPartEvidence, :count) == 1
      assert_summary_rows_created()

      state =
        Repo.get_by!(LearningState,
          section_id: section.id,
          user_id: user.id,
          learning_objective_id: objective.id
        )

      assert state.attempt_count == 1
      assert state.unique_activity_part_count == 1
    end

    test "lkt_aoa bulk input supports multiple parts and multi-objective mappings" do
      %{section: section, group: group} =
        LktAoaFixtures.lkt_fixture(%{
          objectives: [%{}, %{}],
          part_attempts: [
            %{part_id: "part-1", objective_indexes: [0, 1], response: %{"input" => "A"}},
            %{part_id: "part-2", objective_indexes: [0], response: %{"input" => "B"}}
          ]
        })

      assert Worker.perform_now(attempt_guids(group), section.slug) == :ok

      assert Repo.aggregate(AttemptApplication, :count) == 2
      assert Repo.aggregate(PriorActivityPartEvidence, :count) == 2
      assert Repo.aggregate(LearningState, :count) == 2
      assert Repo.aggregate(ResourcePartResponse, :count) == 2
      assert Repo.aggregate(StudentResponse, :count) == 2
    end

    test "missing LKT objective mappings do not prevent legacy summary writes" do
      %{section: section, group: group} =
        LktAoaFixtures.lkt_fixture(%{publish_objectives?: false})

      assert Worker.perform_now(attempt_guids(group), section.slug) == :ok

      assert Repo.aggregate(AttemptApplication, :count) == 1
      assert Repo.aggregate(PriorActivityPartEvidence, :count) == 0
      assert Repo.aggregate(LearningState, :count) == 0
      assert_summary_rows_created()
    end

    test "LKT validation failures do not return learner answer data to Oban" do
      %{section: section, group: group} =
        LktAoaFixtures.lkt_fixture(%{
          part_attempts: [
            %{response: %{"input" => "sensitive learner answer"}}
          ]
        })

      group.part_attempts
      |> hd()
      |> Ecto.Changeset.change(score: nil)
      |> Repo.update!()

      result = Worker.perform_now(attempt_guids(group), section.slug)

      assert result == {:error, :invalid_part_attempt}
      refute inspect(result) =~ "sensitive learner answer"
    end

    test "retry after downstream summary failure does not apply LKT state twice" do
      %{section: section, group: group, user: user, objectives: [objective]} =
        LktAoaFixtures.lkt_fixture()

      Ecto.Adapters.SQL.query!(
        Repo,
        """
        ALTER TABLE resource_summary
        ADD CONSTRAINT resource_summary_phase4_forced_failure
        CHECK (num_attempts = 0)
        NOT VALID
        """,
        []
      )

      assert {:error, %Pipeline{errors: [_ | _]}} =
               Worker.perform_now(attempt_guids(group), section.slug)

      state =
        Repo.get_by!(LearningState,
          section_id: section.id,
          user_id: user.id,
          learning_objective_id: objective.id
        )

      assert state.attempt_count == 1
      assert Repo.aggregate(AttemptApplication, :count) == 1
      assert Repo.aggregate(ResourceSummary, :count) == 0

      Ecto.Adapters.SQL.query!(
        Repo,
        "ALTER TABLE resource_summary DROP CONSTRAINT resource_summary_phase4_forced_failure",
        []
      )

      assert Worker.perform_now(attempt_guids(group), section.slug) == :ok

      state =
        Repo.get_by!(LearningState,
          section_id: section.id,
          user_id: user.id,
          learning_objective_id: objective.id
        )

      assert state.attempt_count == 1
      assert Repo.aggregate(AttemptApplication, :count) == 1
      assert_summary_rows_created()
    end
  end

  defp attempt_guids(group), do: Enum.map(group.part_attempts, & &1.attempt_guid)

  defp capture_lkt_aoa_events(fun) do
    test_pid = self()
    handler_id = "snapshot-worker-lkt-aoa-test-#{System.unique_integer([:positive])}"

    :ok =
      :telemetry.attach_many(
        handler_id,
        [
          [:oli, :learning_model, :lkt_aoa, :batch, :start],
          [:oli, :learning_model, :lkt_aoa, :batch, :stop],
          [:oli, :learning_model, :lkt_aoa, :batch, :exception]
        ],
        fn event, measurements, metadata, _config ->
          send(test_pid, {:lkt_aoa_event, {event, measurements, metadata}})
        end,
        nil
      )

    try do
      fun.()
    after
      :telemetry.detach(handler_id)
    end

    collect_lkt_aoa_events([])
  end

  defp collect_lkt_aoa_events(events) do
    receive do
      {:lkt_aoa_event, event} -> collect_lkt_aoa_events([event | events])
    after
      0 -> Enum.reverse(events)
    end
  end

  defp assert_summary_rows_created do
    assert Repo.aggregate(ResourceSummary, :count) > 0
    assert Repo.aggregate(ResponseSummary, :count) > 0
    assert Repo.aggregate(ResourcePartResponse, :count) > 0
    assert Repo.aggregate(StudentResponse, :count) > 0
  end
end
