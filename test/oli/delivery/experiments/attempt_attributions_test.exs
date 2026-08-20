defmodule Oli.Delivery.Experiments.AttemptAttributionsTest do
  use Oli.DataCase

  import Oli.Factory
  import ExUnit.CaptureLog
  import Ecto.Query, warn: false

  alias Oli.Analytics.Summary.AttemptGroup
  alias Oli.Analytics.XAPI.Events.Context
  alias Oli.Delivery.Experiments.AttemptAttributions
  alias Oli.Experiments.Schemas.Assignment
  alias Oli.Experiments.Schemas.{Condition, ExperimentDefinition, ExperimentSection, Intervention}
  alias Oli.Repo
  alias Oli.Resources.ResourceType

  test "returns empty attributions when the attempt has no experiment assignments" do
    section = insert(:section)
    activity_attempt = %{id: 1, attempt_guid: "activity-attempt-guid"}
    part_attempt = %{id: 1, attempt_guid: "part-attempt-guid", activity_attempt: activity_attempt}

    attempt_group = %AttemptGroup{
      context: %Context{
        host_name: "http://example.edu",
        user_id: insert(:user).id,
        section_id: section.id,
        project_id: insert(:project).id,
        publication_id: insert(:publication).id
      },
      part_attempts: [part_attempt],
      activity_attempts: [activity_attempt],
      resource_attempt: %{}
    }

    assert AttemptAttributions.for_attempt_group(attempt_group) == empty_attributions()
  end

  for assignment_scope <- [:intervention, :section_enrollment] do
    test "attributes weighted-random attempts for #{assignment_scope} scope" do
      %{attempt_group: attempt_group, assignment: assignment, intervention: intervention} =
        setup_attempt_context(unquote(assignment_scope))

      assert %{
               part_attempts: %{"part-attempt-guid" => [part_attribution]},
               activity_attempts: %{"activity-attempt-guid" => [activity_attribution]},
               page_attempt: [page_attribution]
             } = AttemptAttributions.for_attempt_group(attempt_group)

      assert part_attribution["role"] == "outcome"
      assert part_attribution["assignment_id"] == assignment.id
      assert part_attribution["assignment_scope"] == Atom.to_string(unquote(assignment_scope))
      assert part_attribution["intervention_id"] == intervention.id

      assert part_attribution["intervention_key"] ==
               "#{attempt_group.resource_attempt.resource_id}:placement-a"

      assert part_attribution["activity_attempt_id"] == 801
      assert part_attribution["resource_attempt_id"] == 901
      assert part_attribution["activity_resource_id"] == 8001
      assert part_attribution["score"] == 1.0
      assert part_attribution["out_of"] == 2.0
      refute Map.has_key?(part_attribution, "user_id")

      assert activity_attribution["role"] == "rollup"
      assert page_attribution["role"] == "rollup"

      refute Enum.any?(
               [part_attribution, activity_attribution, page_attribution],
               fn attribution ->
                 attribution["attribution_type"] == "reward"
               end
             )
    end
  end

  test "returns no attribution for an activity outside the selected branch" do
    %{attempt_group: attempt_group} = setup_attempt_context(:intervention)

    attempt_group =
      put_in(
        attempt_group.resource_attempt.content,
        selected_content(999_999, attempt_group.resource_attempt.content)
      )

    assert AttemptAttributions.for_attempt_group(attempt_group) == empty_attributions()
  end

  test "fails safe for historical attempts without persisted realized content" do
    %{attempt_group: attempt_group} = setup_attempt_context(:intervention)

    attempt_group = put_in(attempt_group.resource_attempt.content, nil)
    assert AttemptAttributions.for_attempt_group(attempt_group) == empty_attributions()
  end

  test "does not query assignments when realized content has no Alternatives placement" do
    %{attempt_group: attempt_group} = setup_attempt_context(:intervention)
    attempt_group = put_in(attempt_group.resource_attempt.content, %{"model" => []})
    parent = self()
    handler_id = "attempt-attribution-query-#{System.unique_integer([:positive])}"

    :telemetry.attach(
      handler_id,
      [:oli, :repo, :query],
      fn _, _, metadata, _ -> send(parent, {:query_source, metadata.source}) end,
      %{}
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    assert AttemptAttributions.for_attempt_group(attempt_group) == empty_attributions()
    refute_receive {:query_source, "experiment_assignments"}
  end

  test "preserves Thompson outcome and accepted reward evidence" do
    %{attempt_group: attempt_group, assignment: assignment} =
      setup_attempt_context(:intervention, :thompson_sampling)

    assert %{
             part_attempts: %{
               "part-attempt-guid" => [
                 %{"attribution_type" => "outcome"} = outcome,
                 %{"attribution_type" => "reward"} = reward
               ]
             }
           } = AttemptAttributions.for_attempt_group(attempt_group)

    assert outcome["assignment_id"] == assignment.id
    assert outcome["key"] == "outcome:activity_attempt:801:assignment:#{assignment.id}"
    assert reward["assignment_id"] == assignment.id
    assert reward["key"] == "reward:activity_attempt:801:assignment:#{assignment.id}"
    assert reward["outcome_key"] == outcome["key"]
    assert reward["reward_source"] == "activity_attempt:full_credit"
    assert reward["reward_value"] == 1.0
  end

  test "safe enrichment failure returns no attribution without learner data in the log" do
    %{attempt_group: attempt_group} = setup_attempt_context(:intervention)

    malformed_attempt = put_in(attempt_group.resource_attempt.resource_id, nil)

    log =
      capture_log(fn ->
        assert AttemptAttributions.for_attempt_group(malformed_attempt) == empty_attributions()
      end)

    assert log =~ "Attempt experiment attribution enrichment failed"
    refute log =~ "user_id="
  end

  test "does not reuse an intervention-scoped assignment at another placement" do
    %{attempt_group: attempt_group, experiment: experiment} =
      setup_attempt_context(:intervention)

    %Intervention{}
    |> Intervention.changeset(%{
      experiment_id: experiment.id,
      page_resource_id: attempt_group.resource_attempt.resource_id,
      content_element_id: "placement-b"
    })
    |> Repo.insert!()

    content =
      put_in(attempt_group.resource_attempt.content, ["model", Access.at(0), "id"], "placement-b")

    attempt_group = put_in(attempt_group.resource_attempt.content, content)
    assert AttemptAttributions.for_attempt_group(attempt_group) == empty_attributions()
  end

  test "fails safe for an unsupported persisted assignment policy" do
    %{attempt_group: attempt_group, assignment: assignment} =
      setup_attempt_context(:intervention)

    from(persisted in Assignment, where: persisted.id == ^assignment.id)
    |> Repo.update_all(set: [assigned_by_policy: "legacy_unknown"])

    assert AttemptAttributions.for_attempt_group(attempt_group) == empty_attributions()
  end

  defp setup_attempt_context(assignment_scope, algorithm \\ :weighted_random) do
    institution = insert(:institution)
    project = insert(:project)
    publication = insert(:publication, project: project)
    section = insert(:section, institution: institution, base_project: project)
    user = insert(:user)
    enrollment = insert(:enrollment, section: section, user: user)

    alternatives_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_alternatives(),
        content: %{
          "strategy" => "experiment_controlled",
          "options" => [%{"id" => "option-a", "name" => "Condition A"}]
        }
      )

    page_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_page(),
        content: selected_content(8001, alternatives_revision.resource_id)
      )

    experiment =
      %ExperimentDefinition{}
      |> ExperimentDefinition.changeset(%{
        project_id: project.id,
        slug: "attempt-#{System.unique_integer([:positive])}",
        name: "Attempt experiment",
        state: :active,
        algorithm: algorithm,
        assignment_scope: assignment_scope,
        alternatives_resource_id: alternatives_revision.resource_id
      })
      |> Repo.insert!()

    %ExperimentSection{}
    |> ExperimentSection.changeset(%{experiment_id: experiment.id, section_id: section.id})
    |> Repo.insert!()

    condition =
      %Condition{}
      |> Condition.changeset(%{
        experiment_id: experiment.id,
        condition_code: "condition-a",
        label: "Condition A",
        option_id: "option-a",
        weight: 1.0,
        active: true,
        position: 0
      })
      |> Repo.insert!()

    intervention =
      %Intervention{}
      |> Intervention.changeset(%{
        experiment_id: experiment.id,
        page_resource_id: page_revision.resource_id,
        content_element_id: "placement-a"
      })
      |> Repo.insert!()

    runtime_event_state =
      case algorithm do
        :thompson_sampling ->
          reward_key = "reward:activity_attempt:801:assignment:pending"
          %{"rewards" => %{reward_key => %{}}}

        :weighted_random ->
          %{}
      end

    assignment =
      %Assignment{}
      |> Assignment.changeset(%{
        experiment_id: experiment.id,
        condition_id: condition.id,
        intervention_id: if(assignment_scope == :intervention, do: intervention.id),
        section_id: section.id,
        enrollment_id: enrollment.id,
        user_id: user.id,
        assigned_by_policy: Atom.to_string(algorithm),
        policy_version:
          if(algorithm == :thompson_sampling,
            do: "thompson_sampling:v2",
            else: "weighted_random"
          ),
        assignment_scope: assignment_scope,
        assignment_key: "attempt:#{assignment_scope}:#{experiment.id}:#{enrollment.id}",
        assigned_at: ~U[2026-08-19 11:59:00Z],
        runtime_event_state: runtime_event_state
      })
      |> Repo.insert!()

    assignment = maybe_add_thompson_reward(assignment, algorithm)

    activity_attempt = %{
      id: 801,
      attempt_guid: "activity-attempt-guid",
      attempt_number: 1,
      resource_attempt_id: 901,
      resource_id: 8001,
      score: 1.0,
      out_of: 2.0,
      date_evaluated: ~U[2026-08-19 12:00:00Z]
    }

    part_attempt = %{
      id: 701,
      attempt_guid: "part-attempt-guid",
      activity_attempt: activity_attempt
    }

    attempt_group = %AttemptGroup{
      context: %Context{
        host_name: "http://example.edu",
        user_id: user.id,
        section_id: section.id,
        project_id: project.id,
        publication_id: publication.id
      },
      part_attempts: [part_attempt],
      activity_attempts: [activity_attempt],
      resource_attempt: %{
        id: 901,
        resource_id: page_revision.resource_id,
        content: page_revision.content
      }
    }

    %{
      attempt_group: attempt_group,
      assignment: assignment,
      intervention: intervention,
      experiment: experiment
    }
  end

  defp selected_content(activity_resource_id, alternatives_resource_id)
       when is_integer(alternatives_resource_id) do
    %{
      "model" => [
        %{
          "type" => "alternatives",
          "id" => "placement-a",
          "alternatives_id" => alternatives_resource_id,
          "children" => [
            %{
              "type" => "alternative",
              "value" => "option-a",
              "children" => [
                %{"type" => "activity-reference", "activity_id" => activity_resource_id}
              ]
            }
          ]
        }
      ]
    }
  end

  defp selected_content(activity_resource_id, %{"model" => [placement | _]}) do
    selected_content(activity_resource_id, placement["alternatives_id"])
  end

  defp empty_attributions,
    do: %{part_attempts: %{}, activity_attempts: %{}, page_attempt: []}

  defp maybe_add_thompson_reward(assignment, :weighted_random), do: assignment

  defp maybe_add_thompson_reward(assignment, :thompson_sampling) do
    outcome_key = "outcome:activity_attempt:801:assignment:#{assignment.id}"
    reward_key = "reward:activity_attempt:801:assignment:#{assignment.id}"

    runtime_event_state = %{
      "rewards" => %{
        reward_key => %{
          "key" => reward_key,
          "outcome_key" => outcome_key,
          "reward_value" => 1.0,
          "reward_source" => "activity_attempt:full_credit",
          "recorded_at" => "2026-08-19T12:00:01Z"
        }
      }
    }

    assignment
    |> Assignment.changeset(%{runtime_event_state: runtime_event_state})
    |> Repo.update!()
  end
end
