defmodule Oli.LearningModel.LktAoa.ApplicationTest do
  use Oli.DataCase

  alias Oli.LearningModel

  alias Oli.LearningModel.{
    AttemptApplication,
    LearningState,
    PriorActivityPartEvidence
  }

  alias Oli.LearningModel.LktAoa.BatchResult
  alias Oli.LearningModel.LktAoaFixtures

  describe "public dispatch" do
    test "nil batches do not write operational rows" do
      section = Oli.Factory.insert(:section, learning_model_version: :lkt_aoa)

      assert {:ok, %BatchResult{status: :noop}} =
               LearningModel.apply_evaluated_attempts(section, nil)

      assert Repo.aggregate(AttemptApplication, :count) == 0
      assert Repo.aggregate(PriorActivityPartEvidence, :count) == 0
      assert Repo.aggregate(LearningState, :count) == 0
    end

    test "naive sections skip without fetching LKT state or writing operational rows" do
      %{section: section, group: group} =
        LktAoaFixtures.lkt_fixture(%{section_attrs: [learning_model_version: :naive]})

      assert {:ok,
              %BatchResult{
                status: :skipped,
                input_attempt_count: 1,
                claimed_attempt_count: 0,
                contribution_count: 0
              }} = LearningModel.apply_evaluated_attempts(section, group)

      assert Repo.aggregate(AttemptApplication, :count) == 0
      assert Repo.aggregate(PriorActivityPartEvidence, :count) == 0
      assert Repo.aggregate(LearningState, :count) == 0
    end
  end

  describe "LKT-AOA application" do
    test "applies one evaluated part to one objective atomically" do
      %{section: section, group: group, user: user, objectives: [objective]} =
        LktAoaFixtures.lkt_fixture(%{
          objectives: [%{beta_lo: 0.25}],
          part_attempts: [
            %{part_id: "part-1", objective_indexes: [0], beta_part: -0.25, score: 1.0}
          ]
        })

      assert {:ok,
              %BatchResult{
                status: :applied,
                input_attempt_count: 1,
                claimed_attempt_count: 1,
                contribution_count: 1,
                affected_state_count: 1,
                new_evidence_count: 1
              }} = LearningModel.apply_evaluated_attempts(section, group)

      assert Repo.aggregate(AttemptApplication, :count) == 1
      assert Repo.aggregate(PriorActivityPartEvidence, :count) == 1

      state =
        Repo.get_by!(LearningState,
          section_id: section.id,
          user_id: user.id,
          learning_objective_id: objective.id
        )

      assert state.attempt_count == 1
      assert_in_delta state.aoa, 0.5, 1.0e-12
      assert_in_delta state.success_score, 1.0, 1.0e-12
      assert_in_delta state.failure_score, 0.0, 1.0e-12
      assert_in_delta state.recency_logit, :math.log(2.0), 1.0e-12
      assert state.unique_activity_part_count == 1
      assert_in_delta state.confidence, 1.0 - :math.exp(-1 / 3.0), 1.0e-12
    end

    test "resolves objectives from the attempted remixed project's publication" do
      %{section: section, group: group, objectives: [objective]} =
        LktAoaFixtures.lkt_fixture()

      source_mapping =
        Repo.get_by!(Oli.Publishing.PublishedResource,
          publication_id: group.context.publication_id,
          resource_id: objective.id
        )

      remix_project = Oli.Factory.insert(:project)
      remix_publication = Oli.Factory.insert(:publication, project: remix_project)

      Oli.Factory.insert(:section_project_publication,
        section: section,
        project: remix_project,
        publication: remix_publication
      )

      Oli.Factory.insert(:published_resource,
        publication: remix_publication,
        resource: objective,
        revision: Repo.get!(Oli.Resources.Revision, source_mapping.revision_id)
      )

      group = %{
        group
        | context: %{
            group.context
            | project_id: remix_project.id,
              publication_id: remix_publication.id
          }
      }

      assert {:ok, %BatchResult{status: :applied, contribution_count: 1}} =
               LearningModel.apply_evaluated_attempts(section, group)
    end

    test "multi-objective and multi-part batches write one final row per affected state" do
      %{section: section, group: group, user: user, objectives: objectives} =
        LktAoaFixtures.lkt_fixture(%{
          objectives: [%{}, %{}],
          part_attempts: [
            %{part_id: "part-1", objective_indexes: [0, 1], score: 1.0},
            %{part_id: "part-2", objective_indexes: [0], score: 0.0}
          ]
        })

      assert {:ok,
              %BatchResult{
                status: :applied,
                claimed_attempt_count: 2,
                contribution_count: 3,
                affected_state_count: 2,
                new_evidence_count: 2
              }} = LearningModel.apply_evaluated_attempts(section, group)

      [objective_a, objective_b] = objectives

      state_a =
        Repo.get_by!(LearningState,
          section_id: section.id,
          user_id: user.id,
          learning_objective_id: objective_a.id
        )

      state_b =
        Repo.get_by!(LearningState,
          section_id: section.id,
          user_id: user.id,
          learning_objective_id: objective_b.id
        )

      assert state_a.attempt_count == 2
      assert state_a.unique_activity_part_count == 2
      assert state_b.attempt_count == 1
      assert state_b.unique_activity_part_count == 1
      assert Repo.aggregate(LearningState, :count) == 2
    end

    test "repeated attempts update proficiency but do not increase confidence breadth" do
      %{section: section, group: first_group, user: user, objectives: [objective]} =
        LktAoaFixtures.lkt_fixture(%{
          part_attempts: [
            %{part_id: "part-1", objective_indexes: [0], score: 1.0}
          ]
        })

      assert {:ok, %BatchResult{status: :applied}} =
               LearningModel.apply_evaluated_attempts(section, first_group)

      second_group =
        LktAoaFixtures.add_attempt(first_group,
          part_id: "part-1",
          score: 0.0,
          date_evaluated: DateTime.add(~U[2026-08-24 12:00:00Z], 60, :second)
        )

      assert {:ok,
              %BatchResult{
                status: :applied,
                claimed_attempt_count: 1,
                contribution_count: 1,
                new_evidence_count: 0
              }} = LearningModel.apply_evaluated_attempts(section, second_group)

      state =
        Repo.get_by!(LearningState,
          section_id: section.id,
          user_id: user.id,
          learning_objective_id: objective.id
        )

      assert state.attempt_count == 2
      assert state.unique_activity_part_count == 1
      assert Repo.aggregate(PriorActivityPartEvidence, :count) == 1
    end

    test "duplicate guid retry is a no-op for claims, evidence, and state" do
      %{section: section, group: group, user: user, objectives: [objective]} =
        LktAoaFixtures.lkt_fixture()

      assert {:ok, %BatchResult{status: :applied}} =
               LearningModel.apply_evaluated_attempts(section, group)

      before_state =
        Repo.get_by!(LearningState,
          section_id: section.id,
          user_id: user.id,
          learning_objective_id: objective.id
        )

      assert {:ok,
              %BatchResult{
                status: :noop,
                input_attempt_count: 1,
                claimed_attempt_count: 0,
                contribution_count: 0
              }} = LearningModel.apply_evaluated_attempts(section, group)

      after_state =
        Repo.get_by!(LearningState,
          section_id: section.id,
          user_id: user.id,
          learning_objective_id: objective.id
        )

      assert after_state.attempt_count == before_state.attempt_count
      assert after_state.unique_activity_part_count == before_state.unique_activity_part_count
      assert Repo.aggregate(AttemptApplication, :count) == 1
      assert Repo.aggregate(PriorActivityPartEvidence, :count) == 1
    end

    test "duplicate copies of the same guid in one input batch contribute once" do
      %{section: section, group: group, user: user, objectives: [objective]} =
        LktAoaFixtures.lkt_fixture()

      duplicated_group = %{group | part_attempts: group.part_attempts ++ group.part_attempts}

      assert {:ok,
              %BatchResult{
                status: :applied,
                input_attempt_count: 2,
                claimed_attempt_count: 1,
                contribution_count: 1
              }} = LearningModel.apply_evaluated_attempts(section, duplicated_group)

      state =
        Repo.get_by!(LearningState,
          section_id: section.id,
          user_id: user.id,
          learning_objective_id: objective.id
        )

      assert state.attempt_count == 1
      assert state.unique_activity_part_count == 1
      assert Repo.aggregate(AttemptApplication, :count) == 1
      assert Repo.aggregate(PriorActivityPartEvidence, :count) == 1
    end

    test "non-evaluated and null-date part attempts fail before claims" do
      %{section: section, group: group} =
        LktAoaFixtures.lkt_fixture(%{part_attempts: [%{lifecycle_state: :submitted}]})

      assert LearningModel.apply_evaluated_attempts(section, group) ==
               {:error, {:part_attempt_not_evaluated, hd(group.part_attempts).attempt_guid}}

      assert Repo.aggregate(AttemptApplication, :count) == 0

      %{section: section, group: group} =
        LktAoaFixtures.lkt_fixture(%{part_attempts: [%{date_evaluated: nil}]})

      assert LearningModel.apply_evaluated_attempts(section, group) ==
               {:error, {:missing_date_evaluated, hd(group.part_attempts).attempt_guid}}

      assert Repo.aggregate(AttemptApplication, :count) == 0
    end

    test "missing published objective revisions are skipped after claiming the attempt" do
      %{section: section, group: group} =
        LktAoaFixtures.lkt_fixture(%{publish_objectives?: false})

      assert {:ok,
              %BatchResult{
                status: :applied,
                claimed_attempt_count: 1,
                contribution_count: 0,
                affected_state_count: 0,
                new_evidence_count: 0
              }} = LearningModel.apply_evaluated_attempts(section, group)

      assert Repo.aggregate(AttemptApplication, :count) == 1
      assert Repo.aggregate(PriorActivityPartEvidence, :count) == 0
      assert Repo.aggregate(LearningState, :count) == 0
    end

    test "missing and deleted objective revisions do not block valid objectives" do
      %{section: section, group: group, objectives: [valid, missing, deleted], user: user} =
        LktAoaFixtures.lkt_fixture(%{
          objectives: [%{}, %{}, %{}],
          part_attempts: [%{objective_indexes: [0, 1, 2]}]
        })

      missing_mapping =
        Repo.get_by!(Oli.Publishing.PublishedResource,
          publication_id: group.context.publication_id,
          resource_id: missing.id
        )

      Repo.delete!(missing_mapping)

      deleted_mapping =
        Repo.get_by!(Oli.Publishing.PublishedResource,
          publication_id: group.context.publication_id,
          resource_id: deleted.id
        )

      deleted_mapping.revision_id
      |> then(&Repo.get!(Oli.Resources.Revision, &1))
      |> Ecto.Changeset.change(deleted: true)
      |> Repo.update!()

      assert {:ok,
              %BatchResult{
                status: :applied,
                claimed_attempt_count: 1,
                contribution_count: 1,
                affected_state_count: 1
              }} = LearningModel.apply_evaluated_attempts(section, group)

      assert Repo.get_by!(LearningState,
               section_id: section.id,
               user_id: user.id,
               learning_objective_id: valid.id
             )

      refute Repo.get_by(LearningState,
               section_id: section.id,
               user_id: user.id,
               learning_objective_id: missing.id
             )

      refute Repo.get_by(LearningState,
               section_id: section.id,
               user_id: user.id,
               learning_objective_id: deleted.id
             )
    end

    test "database failure after evidence insertion rolls back claims, evidence, and state" do
      %{section: section, group: group} = LktAoaFixtures.lkt_fixture()

      Ecto.Adapters.SQL.query!(
        Repo,
        """
        ALTER TABLE learning_states
        ADD CONSTRAINT learning_states_phase3_forced_final_write_failure
        CHECK (attempt_count = 0)
        NOT VALID
        """,
        []
      )

      assert {:error, {:state_write_failed, %Postgrex.Error{}}} =
               LearningModel.apply_evaluated_attempts(section, group)

      assert Repo.aggregate(AttemptApplication, :count) == 0
      assert Repo.aggregate(PriorActivityPartEvidence, :count) == 0
      assert Repo.aggregate(LearningState, :count) == 0
    end

    test "uses the same operational query categories for single and bulk batches" do
      %{section: single_section, group: single_group} = LktAoaFixtures.lkt_fixture()

      single_count =
        operational_query_count(fn ->
          assert {:ok, %BatchResult{status: :applied}} =
                   LearningModel.apply_evaluated_attempts(single_section, single_group)
        end)

      %{section: bulk_section, group: bulk_group} =
        LktAoaFixtures.lkt_fixture(%{
          objectives: [%{}, %{}, %{}],
          part_attempts: [
            %{part_id: "part-1", objective_indexes: [0, 1]},
            %{part_id: "part-2", objective_indexes: [1, 2]},
            %{part_id: "part-3", objective_indexes: [0, 2]}
          ]
        })

      bulk_count =
        operational_query_count(fn ->
          assert {:ok, %BatchResult{status: :applied}} =
                   LearningModel.apply_evaluated_attempts(bulk_section, bulk_group)
        end)

      assert single_count == bulk_count
      assert single_count == 6
    end
  end

  defp operational_query_count(fun) do
    handler_id = "lkt-aoa-application-query-count-#{System.unique_integer([:positive])}"
    parent = self()

    :ok =
      :telemetry.attach(
        handler_id,
        [:oli, :repo, :query],
        fn _event, _measurements, metadata, _config ->
          query = metadata.query || ""

          if operational_query?(query) do
            send(parent, :operational_repo_query)
          end
        end,
        nil
      )

    try do
      fun.()
    after
      :telemetry.detach(handler_id)
    end

    collect_operational_queries(0)
  end

  defp collect_operational_queries(count) do
    receive do
      :operational_repo_query -> collect_operational_queries(count + 1)
    after
      0 -> count
    end
  end

  defp operational_query?(query) do
    Enum.any?(
      [
        "learning_model_attempt_applications",
        "published_resources",
        "learning_states",
        "prior_activity_part_evidence"
      ],
      &String.contains?(query, &1)
    )
  end
end
