defmodule Oli.Experiments.AnalyticsTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Experiments

  alias Oli.Experiments.{
    AnalyticsQuery,
    AssignmentDecision,
    RecordExposureRequest,
    RecordRewardRequest,
    Scope
  }

  alias Oli.Experiments.Schemas.{Condition, ExperimentDefinition, ExperimentSection, Intervention}

  describe "analytics reads" do
    test "returns scoped summary, counts, and policy snapshots" do
      %{scope: scope, revision: revision, definition_id: experiment_id} =
        active_experiment_with_conditions()

      {:ok, %AssignmentDecision{} = assignment} =
        Experiments.assign_condition(assign_request(scope, revision, ["a", "b"]))

      {:ok, _exposure} =
        Experiments.record_exposure(%RecordExposureRequest{
          key: "analytics-exposure",
          scope: scope,
          assignment_id: assignment.assignment_id,
          page_resource_id: revision.resource_id,
          content_element_id: "placement",
          content_revision_id: revision.id
        })

      {:ok, _reward} =
        Experiments.record_reward(%RecordRewardRequest{
          key: "analytics-reward",
          scope: scope,
          assignment_id: assignment.assignment_id,
          reward_value: 1.0,
          reward_source: "analytics"
        })

      query = %AnalyticsQuery{scope: scope, experiment_id: experiment_id}

      assert {:ok, %{experiments: 1, assignments: 1, exposures: 0, rewards: 1}} =
               Experiments.experiment_summary(query)

      assert {:ok, [%{condition_code: condition_code, count: 1}]} =
               Experiments.assignment_counts(query)

      assert condition_code in ["a", "b"]

      assert {:ok, []} = Experiments.exposure_counts(query)
      assert {:ok, [%{count: 1}]} = Experiments.reward_counts(query)

      assert {:ok,
              [
                %{
                  algorithm: :weighted_random,
                  algorithm_version: "weighted_random",
                  assignment_count: 1,
                  reward_success_count: 0
                } = snapshot
              ]} = Experiments.policy_state_snapshot(query)

      assert snapshot.state == %{}
      refute Map.has_key?(snapshot, :policy_config)
    end

    test "rejects out-of-scope analytics queries" do
      %{definition_id: experiment_id} = active_experiment_with_conditions()
      other_scope = valid_scope()

      assert {:error, %{type: :invalid_scope, message: "experiment is outside analytics scope"}} =
               Experiments.experiment_summary(%AnalyticsQuery{
                 scope: other_scope,
                 experiment_id: experiment_id
               })
    end
  end

  defp active_experiment_with_conditions do
    scope = valid_scope()

    revision =
      insert(:revision,
        resource_type_id: Oli.Resources.ResourceType.id_for_alternatives(),
        content: %{
          "strategy" => "upgrade_decision_point",
          "options" => [
            %{"id" => "a", "name" => "A"},
            %{"id" => "b", "name" => "B"}
          ]
        }
      )

    publication = Repo.get!(Oli.Publishing.Publications.Publication, scope.publication_id)
    project = Repo.get!(Oli.Authoring.Course.Project, scope.project_id)
    section = Repo.get!(Oli.Delivery.Sections.Section, scope.section_id)

    insert(:published_resource,
      publication: publication,
      resource: revision.resource,
      revision: revision
    )

    insert(:section_resource,
      project: project,
      section: section,
      resource_id: revision.resource_id
    )

    active =
      %ExperimentDefinition{}
      |> ExperimentDefinition.changeset(%{
        project_id: scope.project_id,
        slug: "analytics-#{System.unique_integer([:positive])}",
        name: "Analytics experiment",
        state: :active,
        algorithm: :weighted_random,
        alternatives_resource_id: revision.resource_id
      })
      |> Repo.insert!()

    %ExperimentSection{}
    |> ExperimentSection.changeset(%{experiment_id: active.id, section_id: scope.section_id})
    |> Repo.insert!()

    for {code, position} <- [{"a", 0}, {"b", 1}] do
      %Condition{}
      |> Condition.changeset(%{
        experiment_id: active.id,
        condition_code: code,
        label: code,
        option_id: code,
        weight: 1.0,
        position: position
      })
      |> Repo.insert!()
    end

    %Intervention{}
    |> Intervention.changeset(%{
      experiment_id: active.id,
      page_resource_id: revision.resource_id,
      content_element_id: "placement"
    })
    |> Repo.insert!()

    %{scope: scope, revision: revision, definition_id: active.id}
  end

  defp assign_request(scope, revision, condition_codes) do
    %Oli.Experiments.AssignConditionRequest{
      scope: scope,
      alternatives_resource_id: revision.resource_id,
      alternatives_revision_id: revision.id,
      page_resource_id: revision.resource_id,
      content_element_id: "placement",
      available_condition_codes: condition_codes
    }
  end

  defp valid_scope do
    institution = insert(:institution)
    project = insert(:project)
    publication = insert(:publication, project: project)
    section = insert(:section, institution: institution, base_project: project)

    insert(:section_project_publication,
      section: section,
      project: project,
      publication: publication
    )

    user = insert(:user)
    author = insert(:author)
    insert(:author_project, author_id: author.id, project_id: project.id, status: :accepted)
    enrollment = insert(:enrollment, section: section, user: user)

    %Scope{
      author_id: author.id,
      institution_id: institution.id,
      project_id: project.id,
      publication_id: publication.id,
      section_id: section.id,
      user_id: user.id,
      enrollment_id: enrollment.id
    }
  end
end
