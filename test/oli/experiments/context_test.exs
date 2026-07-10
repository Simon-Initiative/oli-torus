defmodule Oli.Experiments.ContextTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Experiments

  alias Oli.Experiments.{
    DecisionPointCandidate,
    CreateExperimentRequest,
    ExperimentDefinition,
    ExperimentAuthoringView,
    ExperimentError,
    LifecycleRequest,
    Scope,
    UpdateExperimentRequest
  }

  alias Oli.Experiments.Schemas.{Assignment, Condition, DecisionPoint, PolicyState}
  alias Oli.Authoring.Course.Project
  alias Oli.Institutions.Institution
  alias Oli.Repo
  alias Oli.Resources.ResourceType

  describe "create_experiment/1" do
    test "creates an experiment through the public context boundary" do
      scope = valid_scope()

      assert {:ok, %ExperimentDefinition{} = definition} =
               Experiments.create_experiment(%CreateExperimentRequest{
                 scope: scope,
                 slug: "ab-test",
                 name: "A/B Test",
                 description: "An A/B test",
                 algorithm: :weighted_random,
                 policy_config: %{"salt" => "stable"}
               })

      assert definition.id
      assert definition.uuid
      assert definition.institution_id == scope.institution_id
      assert definition.project_id == scope.project_id
      assert definition.publication_id == scope.publication_id
      assert definition.section_id == scope.section_id
      assert definition.state == :draft
      refute private_schema?(definition)
    end

    test "rejects invalid cross-project publication scope" do
      scope = valid_scope()
      other_publication = insert(:publication)

      assert {:error, %ExperimentError{type: :invalid_scope, message: message}} =
               Experiments.create_experiment(%CreateExperimentRequest{
                 scope: %{scope | publication_id: other_publication.id},
                 slug: "ab-test",
                 name: "A/B Test",
                 algorithm: :weighted_random
               })

      assert message == "publication does not belong to project"
    end

    test "rejects invalid cross-section and cross-enrollment scope" do
      scope = valid_scope()
      other_section = insert(:section)

      assert {:error, %ExperimentError{type: :invalid_scope, message: message}} =
               Experiments.create_experiment(%CreateExperimentRequest{
                 scope: %{scope | section_id: other_section.id},
                 slug: "ab-test",
                 name: "A/B Test",
                 algorithm: :weighted_random
               })

      assert message in [
               "section does not belong to institution",
               "section does not belong to project"
             ]

      other_enrollment = insert(:enrollment)

      assert {:error, %ExperimentError{type: :invalid_scope, message: message}} =
               Experiments.create_experiment(%CreateExperimentRequest{
                 scope: %{scope | enrollment_id: other_enrollment.id},
                 slug: "ab-test",
                 name: "A/B Test",
                 algorithm: :weighted_random
               })

      assert message in [
               "enrollment does not belong to section",
               "enrollment does not belong to user"
             ]
    end

    test "normalizes persistence validation errors to public error structs" do
      scope = valid_scope()

      assert {:error, %ExperimentError{type: :persistence_error, details: %{errors: errors}}} =
               Experiments.create_experiment(%CreateExperimentRequest{
                 scope: scope,
                 slug: "",
                 name: "",
                 algorithm: :weighted_random
               })

      assert %{
               slug: ["can't be blank"],
               name: ["can't be blank"]
             } =
               errors
    end

    test "rejects malformed Thompson Sampling policy config without raising" do
      scope = valid_scope()

      for {policy_config, expected_message} <- [
            {%{"priors" => "bad"}, "Thompson Sampling priors config must be a map"},
            {%{"guardrails" => "bad"}, "Thompson Sampling guardrails config must be a map"},
            {%{"priors" => %{"default" => "bad"}},
             "Thompson Sampling default config must be a map"},
            {%{"priors" => %{"conditions" => %{"a" => "bad"}}},
             "Thompson Sampling per-condition prior config must be a map"}
          ] do
        assert {:error, %ExperimentError{type: :invalid_condition, message: ^expected_message}} =
                 Experiments.create_experiment(%CreateExperimentRequest{
                   scope: scope,
                   slug: "bad-ts-#{System.unique_integer([:positive])}",
                   name: "Bad Thompson Sampling",
                   algorithm: :thompson_sampling,
                   policy_config: policy_config
                 })
      end
    end
  end

  describe "authoring graph APIs" do
    test "creates, lists, reads, activates, and archives a weighted random experiment graph" do
      scope = project_scope()
      alternatives = alternatives_revision(scope.project_id)

      assert {:ok, [%DecisionPointCandidate{} = candidate]} =
               Experiments.list_available_decision_points(scope)

      assert candidate.alternatives_resource_id == alternatives.resource_id

      assert {:ok, %ExperimentDefinition{} = definition} =
               Experiments.create_experiment(graph_request(scope, alternatives))

      assert definition.publication_id == nil
      assert definition.section_id == nil

      assert {:ok, [%ExperimentDefinition{id: experiment_id}]} =
               Experiments.list_project_experiments(scope)

      assert experiment_id == definition.id

      assert {:ok, %ExperimentAuthoringView{} = view} =
               Experiments.get_experiment_authoring_view(definition.id, scope)

      assert view.definition.id == definition.id
      assert [%{decision_point_key: decision_point_key}] = view.decision_points
      assert decision_point_key == "alternatives:#{alternatives.resource_id}"
      assert Enum.map(view.conditions, & &1.condition_code) == ["alt-a", "alt-b"]
      assert view.assignment_counts == %{}

      assert {:ok, %ExperimentDefinition{state: :active}} =
               Experiments.activate_experiment(definition.id, lifecycle(scope))

      assert {:ok, %ExperimentDefinition{state: :archived}} =
               Experiments.archive_experiment(definition.id, lifecycle(scope))
    end

    test "rejects section-scoped graph authoring" do
      scope = valid_scope()
      alternatives = alternatives_revision(scope.project_id)

      assert {:error, %ExperimentError{type: :invalid_scope, message: message}} =
               Experiments.create_experiment(graph_request(scope, alternatives))

      assert message == "authoring experiments must be project-scoped"
    end

    test "rejects invalid weighted random conditions" do
      scope = project_scope()
      alternatives = alternatives_revision(scope.project_id)

      request =
        graph_request(scope, alternatives, [
          %{condition_code: "alt-a", option_id: "alt-a", label: "A", weight: 0.0, active: true},
          %{condition_code: "alt-b", option_id: "alt-b", label: "B", weight: 0.0, active: true}
        ])

      assert {:error, %ExperimentError{type: :invalid_condition, message: message}} =
               Experiments.create_experiment(request)

      assert message == "active condition weights must have a positive total"
    end

    test "creates and activates a Thompson Sampling experiment with normalized adaptive config" do
      scope = project_scope()
      alternatives = alternatives_revision(scope.project_id)
      request = %{graph_request(scope, alternatives) | algorithm: :thompson_sampling}

      assert {:ok, %ExperimentDefinition{} = definition} = Experiments.create_experiment(request)

      assert definition.algorithm == :thompson_sampling
      assert definition.policy_config["reward_source"] == "activity_attempt:full_credit"
      assert definition.policy_config["priors"]["default"] == %{"alpha" => 1.0, "beta" => 1.0}
      assert definition.policy_config["guardrails"]["manual_pause_enabled"]

      policy_state = Repo.get_by!(PolicyState, experiment_id: definition.id)
      assert policy_state.algorithm == :thompson_sampling
      assert policy_state.algorithm_version == "thompson_sampling:v2"
      assert policy_state.prior_config == definition.policy_config["priors"]
      assert policy_state.state["alt-a"]["posterior_alpha"] == 1.0
      assert policy_state.state["alt-b"]["posterior_beta"] == 1.0

      assert {:ok, %ExperimentDefinition{state: :active}} =
               Experiments.activate_experiment(definition.id, lifecycle(scope))
    end

    test "rejects invalid Thompson Sampling priors and guardrails" do
      scope = project_scope()
      alternatives = alternatives_revision(scope.project_id)

      invalid_prior =
        %{graph_request(scope, alternatives) | algorithm: :thompson_sampling}
        |> Map.put(:policy_config, %{"priors" => %{"default" => %{"alpha" => 0.0, "beta" => 1.0}}})

      assert {:error, %ExperimentError{type: :invalid_condition, message: message}} =
               Experiments.create_experiment(invalid_prior)

      assert message == "Thompson Sampling prior alpha must be between 0.0001 and 1000"

      invalid_guardrail =
        %{graph_request(scope, alternatives) | algorithm: :thompson_sampling}
        |> Map.put(:policy_config, %{"guardrails" => %{"max_condition_share" => 2.0}})

      assert {:error, %ExperimentError{type: :invalid_condition, message: message}} =
               Experiments.create_experiment(invalid_guardrail)

      assert message ==
               "Thompson Sampling max condition share must be greater than 0 and at most 1"
    end

    test "blocks assigned condition deletion and deactivation" do
      scope = project_scope()
      alternatives = alternatives_revision(scope.project_id)
      {:ok, definition} = Experiments.create_experiment(graph_request(scope, alternatives))
      {:ok, _active} = Experiments.activate_experiment(definition.id, lifecycle(scope))
      condition = Repo.get_by!(Condition, experiment_id: definition.id, condition_code: "alt-a")
      decision_point = Repo.get_by!(DecisionPoint, experiment_id: definition.id)
      runtime_scope = runtime_scope(scope)

      %Assignment{}
      |> Assignment.changeset(%{
        experiment_id: definition.id,
        decision_point_id: decision_point.id,
        condition_id: condition.id,
        institution_id: runtime_scope.institution_id,
        section_id: runtime_scope.section_id,
        enrollment_id: runtime_scope.enrollment_id,
        user_id: runtime_scope.user_id,
        publication_id: runtime_scope.publication_id,
        assigned_by_policy: "weighted_random",
        policy_version: "weighted_random",
        assignment_key: "assigned-#{System.unique_integer([:positive])}",
        assigned_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })
      |> Repo.insert!()

      {:ok, paused} = Experiments.pause_experiment(definition.id, lifecycle(scope))

      update = %UpdateExperimentRequest{
        scope: scope,
        name: paused.name,
        decision_point: %{
          alternatives_resource_id: alternatives.resource_id,
          alternatives_revision_id: alternatives.id,
          decision_point_key: "alternatives:#{alternatives.resource_id}",
          title: alternatives.title
        },
        conditions: [
          %{condition_code: "alt-a", option_id: "alt-a", label: "A", weight: 1.0, active: false},
          %{condition_code: "alt-b", option_id: "alt-b", label: "B", weight: 1.0, active: true}
        ]
      }

      assert {:error, %ExperimentError{type: :invalid_condition, message: message}} =
               Experiments.update_experiment(definition.id, update)

      assert message =~ "learner assignments already exist"
    end
  end

  describe "update_experiment/2" do
    test "updates draft experiment fields and returns a public domain struct" do
      scope = valid_scope()
      definition = create_definition!(scope)

      assert {:ok, %ExperimentDefinition{} = updated} =
               Experiments.update_experiment(
                 definition.id,
                 %UpdateExperimentRequest{
                   scope: scope,
                   name: "Updated name",
                   description: "Updated description",
                   policy_config: %{"salt" => "new"}
                 }
               )

      assert updated.name == "Updated name"
      assert updated.description == "Updated description"
      assert updated.policy_config == %{"salt" => "new"}
      refute private_schema?(updated)
    end

    test "rejects updates outside the experiment scope" do
      scope = valid_scope()
      definition = create_definition!(scope)
      other_project = insert(:project)

      assert {:error, %ExperimentError{type: :invalid_scope, message: message}} =
               Experiments.update_experiment(
                 definition.id,
                 %UpdateExperimentRequest{
                   scope: %{scope | project_id: other_project.id},
                   name: "Bad"
                 }
               )

      assert message in [
               "publication does not belong to project",
               "section does not belong to project"
             ]
    end

    test "rejects updates once the experiment is active" do
      scope = valid_scope()
      definition = create_definition!(scope)
      assert {:ok, _active} = Experiments.activate_experiment(definition.id, lifecycle(scope))

      assert {:error, %ExperimentError{type: :invalid_state}} =
               Experiments.update_experiment(
                 definition.id,
                 %UpdateExperimentRequest{scope: scope, name: "Too late"}
               )
    end
  end

  describe "lifecycle commands" do
    test "supports allowed lifecycle transitions with timestamps" do
      scope = valid_scope()
      definition = create_definition!(scope)

      assert {:ok, %ExperimentDefinition{state: :active, started_at: started_at} = active} =
               Experiments.activate_experiment(definition.id, lifecycle(scope))

      assert started_at

      assert {:ok, %ExperimentDefinition{state: :paused}} =
               Experiments.pause_experiment(active.id, lifecycle(scope))

      assert {:ok, %ExperimentDefinition{state: :active}} =
               Experiments.activate_experiment(active.id, lifecycle(scope))

      assert {:ok, %ExperimentDefinition{state: :completed, ended_at: ended_at} = completed} =
               Experiments.complete_experiment(active.id, lifecycle(scope))

      assert ended_at

      assert {:ok, %ExperimentDefinition{state: :archived}} =
               Experiments.archive_experiment(completed.id, lifecycle(scope))
    end

    test "rejects invalid lifecycle transitions" do
      scope = valid_scope()
      definition = create_definition!(scope)

      assert {:error, %ExperimentError{type: :invalid_state, message: message}} =
               Experiments.pause_experiment(definition.id, lifecycle(scope))

      assert message == "experiment cannot transition from draft to paused"
    end
  end

  describe "public response shapes" do
    test "public API functions do not return private Ecto schemas" do
      scope = valid_scope()
      definition = create_definition!(scope)

      {:ok, updated} =
        Experiments.update_experiment(
          definition.id,
          %UpdateExperimentRequest{scope: scope, name: "Public response"}
        )

      {:ok, active} = Experiments.activate_experiment(definition.id, lifecycle(scope))

      refute private_schema?(definition)
      refute private_schema?(updated)
      refute private_schema?(active)
    end
  end

  defp valid_scope do
    institution = insert(:institution)
    project = insert(:project)
    publication = insert(:publication, project: project)
    section = insert(:section, institution: institution, base_project: project)
    user = insert(:user)
    enrollment = insert(:enrollment, section: section, user: user)

    %Scope{
      institution_id: institution.id,
      project_id: project.id,
      publication_id: publication.id,
      section_id: section.id,
      user_id: user.id,
      enrollment_id: enrollment.id
    }
  end

  defp project_scope do
    institution = insert(:institution)
    project = insert(:project)

    %Scope{
      institution_id: institution.id,
      project_id: project.id
    }
  end

  defp runtime_scope(%Scope{} = project_scope) do
    project = Repo.get!(Project, project_scope.project_id)
    institution = Repo.get!(Institution, project_scope.institution_id)
    publication = insert(:publication, project: project)
    section = insert(:section, institution: institution, base_project: project)
    user = insert(:user)
    enrollment = insert(:enrollment, section: section, user: user)

    %Scope{
      institution_id: project_scope.institution_id,
      project_id: project_scope.project_id,
      publication_id: publication.id,
      section_id: section.id,
      user_id: user.id,
      enrollment_id: enrollment.id
    }
  end

  defp alternatives_revision(project_id) do
    resource = insert(:resource)
    insert(:project_resource, project_id: project_id, resource_id: resource.id)

    insert(:revision, %{
      resource: resource,
      resource_type_id: ResourceType.id_for_alternatives(),
      title: "Decision Point",
      content: %{
        "options" => [
          %{"id" => "alt-a", "name" => "A"},
          %{"id" => "alt-b", "name" => "B"}
        ]
      }
    })
  end

  defp graph_request(scope, alternatives, conditions \\ nil) do
    %CreateExperimentRequest{
      scope: scope,
      slug: "ab-test-#{System.unique_integer([:positive])}",
      name: "A/B Test",
      algorithm: :weighted_random,
      decision_point: %{
        alternatives_resource_id: alternatives.resource_id,
        alternatives_revision_id: alternatives.id,
        decision_point_key: "alternatives:#{alternatives.resource_id}",
        title: alternatives.title
      },
      conditions:
        conditions ||
          [
            %{condition_code: "alt-a", option_id: "alt-a", label: "A", weight: 1.0, active: true},
            %{condition_code: "alt-b", option_id: "alt-b", label: "B", weight: 1.0, active: true}
          ]
    }
  end

  defp create_definition!(scope) do
    assert {:ok, definition} =
             Experiments.create_experiment(%CreateExperimentRequest{
               scope: scope,
               slug: "ab-test-#{System.unique_integer([:positive])}",
               name: "A/B Test",
               algorithm: :weighted_random
             })

    definition
  end

  defp lifecycle(scope), do: %LifecycleRequest{scope: scope}

  defp private_schema?(struct) do
    struct.__struct__
    |> Module.split()
    |> Enum.take(3)
    |> Kernel.==(["Oli", "Experiments", "Schemas"])
  end
end
