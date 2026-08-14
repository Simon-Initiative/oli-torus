defmodule Oli.Experiments.ConfigurationTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Authoring.Course.Project
  alias Oli.Experiments

  alias Oli.Experiments.{
    ActivationValidator,
    CreateExperimentRequest,
    ExperimentError,
    LifecycleRequest,
    Scope
  }

  alias Oli.Repo
  alias Oli.Resources.ResourceType

  test "creates one atomic singular experiment configuration" do
    scope = project_scope()
    group_a = alternatives_revision(scope.project_id, "Group A")
    page_a = page_revision(scope.project_id, "Intervention A", false)

    assert {:ok, definition} =
             Experiments.create_experiment(
               graph_request(scope, [point(group_a, page_a, "placement-a")])
             )

    assert {:ok, view} = Experiments.get_experiment_authoring_view(definition.id, scope)
    assert Enum.map(view.conditions, & &1.condition_code) == ["control", "control-2"]
    assert view.definition.alternatives_resource_id == group_a.resource_id
    assert length(view.interventions) == 1

    [control, variant] = view.conditions

    update = %Oli.Experiments.UpdateExperimentRequest{
      scope: scope,
      conditions: [
        %{
          id: control.id,
          label: "Baseline",
          option_id: "alt-a",
          weight: 1.0,
          active: true,
          position: 0
        },
        %{
          id: variant.id,
          label: "Variant",
          option_id: "alt-b",
          weight: 1.0,
          active: true,
          position: 1
        }
      ],
      alternatives_resource_id: group_a.resource_id,
      interventions: [%{page_resource_id: page_a.resource_id, content_element_id: "placement-a"}]
    }

    assert {:ok, _updated} = Experiments.update_experiment(definition.id, update)
    assert {:ok, updated_view} = Experiments.get_experiment_authoring_view(definition.id, scope)

    assert Enum.map(updated_view.conditions, &{&1.id, &1.condition_code}) ==
             [{control.id, "control"}, {variant.id, "control-2"}]

    assert {:ok, active} =
             Experiments.activate_experiment(definition.id, %LifecycleRequest{scope: scope})

    assert active.state == :active
  end

  test "defaults weighted random to section-and-enrollment scope and saves intervention scope" do
    scope = project_scope()
    group = alternatives_revision(scope.project_id, "Assignment Scope")
    page = page_revision(scope.project_id, "Assignment Scope Page", false)
    request = graph_request(scope, [point(group, page, "assignment-scope")])

    assert {:ok, %{assignment_scope: :section_enrollment} = default_definition} =
             Experiments.create_experiment(request)

    assert {:ok, %{assignment_scope: :intervention} = definition} =
             request
             |> Map.put(:slug, "section-scope-#{System.unique_integer([:positive])}")
             |> Map.put(:assignment_scope, :intervention)
             |> Experiments.create_experiment()

    assert {:ok, %{assignment_scope: :section_enrollment}} =
             Experiments.update_experiment(
               definition.id,
               %Oli.Experiments.UpdateExperimentRequest{
                 scope: scope,
                 assignment_scope: :section_enrollment
               }
             )

    unauthorized_scope = %{scope | author_id: nil}

    assert {:error, %ExperimentError{type: :invalid_scope}} =
             Experiments.update_experiment(
               definition.id,
               %Oli.Experiments.UpdateExperimentRequest{
                 scope: unauthorized_scope,
                 assignment_scope: :intervention
               }
             )

    assert {:ok, %{state: :active}} =
             Experiments.activate_experiment(default_definition.id, %LifecycleRequest{
               scope: scope
             })

    assert {:error, %ExperimentError{type: :invalid_state}} =
             Experiments.update_experiment(
               default_definition.id,
               %Oli.Experiments.UpdateExperimentRequest{
                 scope: scope,
                 assignment_scope: :intervention
               }
             )
  end

  test "rejects invalid and Thompson Sampling section-and-enrollment scopes" do
    scope = project_scope()
    group = alternatives_revision(scope.project_id, "Invalid Assignment Scope")
    page = page_revision(scope.project_id, "Invalid Assignment Scope Page", false)
    request = graph_request(scope, [point(group, page, "invalid-assignment-scope")])

    assert {:error,
            %ExperimentError{
              message: "assignment scope must be intervention or section_enrollment"
            }} =
             Experiments.create_experiment(%{request | assignment_scope: :unknown})

    assert {:error,
            %ExperimentError{
              message: "assignment scope must be intervention or section_enrollment"
            }} =
             Experiments.create_experiment(%{request | assignment_scope: false})

    assert {:error,
            %ExperimentError{
              message:
                "section-and-enrollment scope is available only for weighted random experiments"
            }} =
             Experiments.create_experiment(%{
               request
               | algorithm: :thompson_sampling,
                 assignment_scope: :section_enrollment
             })

    malformed =
      %Oli.Experiments.Schemas.ExperimentDefinition{}
      |> Oli.Experiments.Schemas.ExperimentDefinition.changeset(%{
        project_id: scope.project_id,
        alternatives_resource_id: group.resource_id,
        slug: "activation-scope-#{System.unique_integer([:positive])}",
        name: "Activation scope",
        algorithm: :weighted_random,
        assignment_scope: :section_enrollment
      })
      |> Repo.insert!()
      |> Map.put(:algorithm, :thompson_sampling)

    assert {:error, %ExperimentError{}} = ActivationValidator.validate(malformed)
  end

  test "allows valid scope changes while the experiment remains a draft" do
    scope = project_scope()
    group = alternatives_revision(scope.project_id, "Assigned Scope")
    page = page_revision(scope.project_id, "Assigned Scope Page", false)

    assert {:ok, definition} =
             scope
             |> graph_request([point(group, page, "assigned-scope")])
             |> Map.put(:assignment_scope, :intervention)
             |> Experiments.create_experiment()

    assert {:error,
            %ExperimentError{
              message: "assignment scope must be intervention or section_enrollment"
            }} =
             Experiments.update_experiment(
               definition.id,
               %Oli.Experiments.UpdateExperimentRequest{
                 scope: scope,
                 assignment_scope: false
               }
             )

    assert {:ok, %{assignment_scope: :intervention}} =
             Experiments.update_experiment(
               definition.id,
               %Oli.Experiments.UpdateExperimentRequest{
                 scope: scope,
                 assignment_scope: "intervention"
               }
             )

    assert {:ok, %{assignment_scope: :section_enrollment}} =
             Experiments.update_experiment(
               definition.id,
               %Oli.Experiments.UpdateExperimentRequest{
                 scope: scope,
                 assignment_scope: :section_enrollment
               }
             )
  end

  test "returns structured errors for incomplete mappings and incompatible assessment bindings" do
    scope = project_scope()
    group = alternatives_revision(scope.project_id, "Group")
    intervention_page = page_revision(scope.project_id, "Intervention", false)
    unscored_page = page_revision(scope.project_id, "Assessment", false)

    incomplete =
      point(group, intervention_page, "placement")
      |> put_in([:mappings], [%{condition_ref: "control", option_id: "alt-a"}])

    assert {:error, %ExperimentError{message: message}} =
             Experiments.create_experiment(graph_request(scope, [incomplete]))

    assert message == "condition mappings must use every group alternative exactly once"

    malformed_weight =
      point(group, intervention_page, "placement")
      |> put_in([:mappings, Access.at(0), :weight], "heavy")

    assert {:error, %ExperimentError{message: weight_message}} =
             Experiments.create_experiment(graph_request(scope, [malformed_weight]))

    assert weight_message == "condition weights must be numeric"

    adaptive =
      point(group, intervention_page, "placement")
      |> Map.put(:algorithm, :thompson_sampling)
      |> put_in([:interventions, Access.at(0), :assessment_binding], %{
        assessment_page_resource_id: unscored_page.resource_id,
        reward_threshold: Decimal.new("0.5")
      })

    adaptive_request = %{graph_request(scope, [adaptive]) | algorithm: :thompson_sampling}

    assert {:error, %ExperimentError{message: adaptive_message}} =
             Experiments.create_experiment(adaptive_request)

    assert adaptive_message == "assessment binding must reference a compatible scored page"
  end

  test "accepts an experiment-controlled Alternatives placement inside an ordinary container" do
    scope = project_scope()
    group = alternatives_revision(scope.project_id, "Group")
    page = page_revision(scope.project_id, "Intervention", false)
    decision_point = point(group, page, "nested-placement")

    nested_content = %{
      "model" => [
        %{
          "type" => "content",
          "id" => "container",
          "children" => [
            %{
              "type" => "alternatives",
              "id" => "nested-placement",
              "alternatives_id" => group.resource_id,
              "children" => []
            }
          ]
        }
      ]
    }

    page
    |> Ecto.Changeset.change(content: nested_content)
    |> Repo.update!()

    assert {:ok, _definition} =
             Experiments.create_experiment(graph_request(scope, [decision_point]))
  end

  test "rejects an Alternatives placement nested within another Alternatives placement" do
    scope = project_scope()
    group = alternatives_revision(scope.project_id, "Inner Group")
    outer_group = alternatives_revision(scope.project_id, "Outer Group")
    page = page_revision(scope.project_id, "Intervention", false)
    decision_point = point(group, page, "nested-placement")

    nested_content = %{
      "model" => [
        %{
          "type" => "alternatives",
          "id" => "outer-placement",
          "alternatives_id" => outer_group.resource_id,
          "children" => [
            %{
              "type" => "alternative",
              "id" => "outer-option",
              "value" => "outer",
              "children" => [
                %{
                  "type" => "group",
                  "children" => [
                    %{
                      "type" => "alternatives",
                      "id" => "nested-placement",
                      "alternatives_id" => group.resource_id,
                      "children" => []
                    }
                  ]
                }
              ]
            }
          ]
        }
      ]
    }

    page
    |> Ecto.Changeset.change(content: nested_content)
    |> Repo.update!()

    assert {:error, %ExperimentError{message: message}} =
             Experiments.create_experiment(graph_request(scope, [decision_point]))

    assert message == "Alternatives placements cannot be nested within another Alternatives"
  end

  test "distinguishes a top-level placement for another Alternatives group from nesting" do
    scope = project_scope()
    group = alternatives_revision(scope.project_id, "Experiment Group")
    other_group = alternatives_revision(scope.project_id, "Other Group")
    page = page_revision(scope.project_id, "Intervention", false)
    decision_point = point(group, page, "placement")

    ensure_root_placement!(page, other_group.resource_id, "placement")

    assert {:error, %ExperimentError{message: message}} =
             Experiments.create_experiment(graph_request(scope, [decision_point]))

    assert message ==
             "intervention placement must reference the experiment Alternatives Group"
  end

  test "distinguishes a missing Alternatives placement from nesting" do
    scope = project_scope()
    group = alternatives_revision(scope.project_id, "Experiment Group")
    page = page_revision(scope.project_id, "Intervention", false)
    decision_point = point(group, page, "existing-placement")

    decision_point =
      put_in(
        decision_point,
        [:interventions, Access.at(0), :content_element_id],
        "removed-placement"
      )

    assert {:error, %ExperimentError{message: message}} =
             Experiments.create_experiment(graph_request(scope, [decision_point]))

    assert message == "intervention placement was not found on the selected page"
  end

  test "requires explicit draft reconciliation and preserves non-draft history" do
    scope = project_scope()
    group = alternatives_revision(scope.project_id, "Group")
    page = page_revision(scope.project_id, "Intervention", false)

    assert {:ok, definition} =
             Experiments.create_experiment(
               graph_request(scope, [point(group, page, "placement")])
             )

    assert {:ok, view} = Experiments.get_experiment_authoring_view(definition.id, scope)
    [intervention] = view.interventions

    assert {:ok, dependencies} =
             Experiments.configuration_dependencies(page.resource_id, scope)

    assert [%{experiment_id: experiment_id, intervention_id: intervention_id}] = dependencies
    assert experiment_id == definition.id
    assert intervention_id == intervention.id

    assert {:ok, _deleted} =
             Experiments.remove_intervention(definition.id, intervention.id, scope)

    assert {:ok, view} = Experiments.get_experiment_authoring_view(definition.id, scope)
    assert view.interventions == []

    # Recreate the complete graph, then leave draft. Structural history is frozen.
    update = %Oli.Experiments.UpdateExperimentRequest{
      scope: scope,
      alternatives_resource_id: group.resource_id,
      conditions: [
        %{
          client_ref: "control",
          label: "Control",
          option_id: "alt-a",
          weight: 1.0,
          active: true,
          position: 0
        },
        %{
          client_ref: "variant",
          label: "Control",
          option_id: "alt-b",
          weight: 1.0,
          active: true,
          position: 1
        }
      ],
      interventions: [%{page_resource_id: page.resource_id, content_element_id: "placement"}]
    }

    assert {:ok, _definition} = Experiments.update_experiment(definition.id, update)
    assert {:ok, view} = Experiments.get_experiment_authoring_view(definition.id, scope)
    [intervention] = view.interventions

    assert {:ok, _active} =
             Experiments.activate_experiment(definition.id, %LifecycleRequest{scope: scope})

    assert {:error, %ExperimentError{type: :invalid_state}} =
             Experiments.remove_intervention(definition.id, intervention.id, scope)
  end

  test "denies dependency reads and mutations without project author access" do
    scope = project_scope()
    group = alternatives_revision(scope.project_id, "Group")
    page = page_revision(scope.project_id, "Intervention", false)

    assert {:ok, definition} =
             Experiments.create_experiment(
               graph_request(scope, [point(group, page, "placement")])
             )

    assert {:ok, view} = Experiments.get_experiment_authoring_view(definition.id, scope)
    [intervention] = view.interventions
    unauthorized_scope = %{scope | author_id: nil}

    assert {:error, %ExperimentError{type: :invalid_scope}} =
             Experiments.configuration_dependencies(page.resource_id, unauthorized_scope)

    assert {:error, %ExperimentError{type: :invalid_scope}} =
             Experiments.remove_intervention(
               definition.id,
               intervention.id,
               unauthorized_scope
             )

    assert {:ok, unchanged} = Experiments.get_experiment_authoring_view(definition.id, scope)
    assert Enum.map(unchanged.interventions, & &1.id) == [intervention.id]
  end

  test "allows shared draft bindings but only one active binding" do
    scope = project_scope()
    group = alternatives_revision(scope.project_id, "Reusable Group")
    first_page = page_revision(scope.project_id, "First", false)
    second_page = page_revision(scope.project_id, "Second", false)

    assert {:ok, first} =
             Experiments.create_experiment(
               graph_request(scope, [point(group, first_page, "first")])
             )

    assert {:ok, second} =
             Experiments.create_experiment(
               graph_request(scope, [point(group, second_page, "second")])
             )

    assert {:ok, _active} =
             Experiments.activate_experiment(first.id, %LifecycleRequest{scope: scope})

    assert {:error, %ExperimentError{type: :conflict}} =
             Experiments.activate_experiment(second.id, %LifecycleRequest{scope: scope})

    assert {:ok, _paused} =
             Experiments.pause_experiment(first.id, %LifecycleRequest{scope: scope})

    assert {:ok, _active} =
             Experiments.activate_experiment(second.id, %LifecycleRequest{scope: scope})
  end

  test "persists inclusive Thompson thresholds at both boundaries" do
    scope = project_scope()
    group_a = alternatives_revision(scope.project_id, "Adaptive A")
    page_a = page_revision(scope.project_id, "Placement A", false)
    page_b = page_revision(scope.project_id, "Placement B", false)
    assessment_a = page_revision(scope.project_id, "Assessment A", true)
    assessment_b = page_revision(scope.project_id, "Assessment B", true)

    adaptive_point = fn group, page, assessment, element_id, threshold ->
      point(group, page, element_id)
      |> Map.put(:algorithm, :thompson_sampling)
      |> put_in([:interventions, Access.at(0), :assessment_binding], %{
        assessment_page_resource_id: assessment.resource_id,
        reward_threshold: threshold
      })
    end

    first = adaptive_point.(group_a, page_a, assessment_a, "a", Decimal.new(0))
    second = adaptive_point.(group_a, page_b, assessment_b, "b", Decimal.new(1))
    configuration = %{first | interventions: first.interventions ++ second.interventions}
    request = %{graph_request(scope, [configuration]) | algorithm: :thompson_sampling}

    assert {:ok, definition} = Experiments.create_experiment(request)
    assert definition.assignment_scope == :intervention
    assert {:ok, view} = Experiments.get_experiment_authoring_view(definition.id, scope)

    assert view.assessment_bindings
           |> Enum.map(& &1.reward_threshold)
           |> Enum.map(&Decimal.to_string/1)
           |> Enum.sort() == ["0.00000", "1.00000"]

    assert {:error,
            %ExperimentError{
              message:
                "section-and-enrollment scope is available only for weighted random experiments"
            }} =
             Experiments.update_experiment(
               definition.id,
               %Oli.Experiments.UpdateExperimentRequest{
                 scope: scope,
                 assignment_scope: :section_enrollment
               }
             )

    assert {:ok, %{state: :active}} =
             Experiments.activate_experiment(definition.id, %LifecycleRequest{scope: scope})
  end

  defp graph_request(scope, [configuration]) do
    mappings = Map.new(configuration.mappings, &{&1.condition_ref, &1})

    conditions =
      Enum.map(graph_conditions(), fn condition ->
        mapping = Map.get(mappings, condition.client_ref, %{})

        Map.merge(condition, %{
          option_id: Map.get(mapping, :option_id),
          weight: Map.get(mapping, :weight, 1.0)
        })
      end)

    %CreateExperimentRequest{
      scope: scope,
      slug: "experiment-#{System.unique_integer([:positive])}",
      name: "Experiment",
      algorithm: :weighted_random,
      alternatives_resource_id: configuration.alternatives_resource_id,
      prior_alpha: Map.get(configuration, :prior_alpha, 1.0),
      prior_beta: Map.get(configuration, :prior_beta, 1.0),
      warm_up_assignments: Map.get(configuration, :warm_up_assignments, 0),
      max_condition_share: Map.get(configuration, :max_condition_share, 1.0),
      fixed_control_allocation: Map.get(configuration, :fixed_control_allocation),
      imbalance_threshold: Map.get(configuration, :imbalance_threshold, 1.0),
      reward_source: Map.get(configuration, :reward_source, "assessment_page:normalized_score"),
      conditions: conditions,
      interventions: configuration.interventions
    }
  end

  defp graph_conditions do
    [
      %{client_ref: "control", label: "Control", active: true, position: 0},
      %{client_ref: "variant", label: "Control", active: true, position: 1}
    ]
  end

  defp point(group, page, element_id) do
    ensure_root_placement!(page, group.resource_id, element_id)

    %{
      alternatives_resource_id: group.resource_id,
      decision_point_key: "alternatives:#{group.resource_id}",
      title: group.title,
      algorithm: :weighted_random,
      mappings: [
        %{condition_ref: "control", option_id: "alt-a", weight: 1.0, position: 0},
        %{condition_ref: "variant", option_id: "alt-b", weight: 1.0, position: 1}
      ],
      interventions: [
        %{page_resource_id: page.resource_id, content_element_id: element_id}
      ]
    }
  end

  defp ensure_root_placement!(page, alternatives_resource_id, element_id) do
    content = %{
      "model" => [
        %{
          "type" => "alternatives",
          "id" => element_id,
          "alternatives_id" => alternatives_resource_id,
          "children" => []
        }
      ]
    }

    page
    |> Ecto.Changeset.change(content: content)
    |> Repo.update!()
  end

  defp project_scope do
    institution = insert(:institution)
    project = insert(:project)
    author = insert(:author)
    insert(:author_project, author_id: author.id, project_id: project.id, status: :accepted)
    %Scope{institution_id: institution.id, project_id: project.id, author_id: author.id}
  end

  defp alternatives_revision(project_id, title) do
    revision =
      project_revision(project_id, title, ResourceType.id_for_alternatives(), false, %{
        "strategy" => "experiment_controlled",
        "options" => [%{"id" => "alt-a", "name" => "A"}, %{"id" => "alt-b", "name" => "B"}]
      })

    revision
  end

  defp page_revision(project_id, title, graded) do
    project_revision(project_id, title, ResourceType.id_for_page(), graded, %{"model" => []})
  end

  defp project_revision(project_id, title, type_id, graded, content) do
    resource = insert(:resource)
    insert(:project_resource, project_id: project_id, resource_id: resource.id)

    revision =
      insert(:revision,
        resource: resource,
        resource_type_id: type_id,
        title: title,
        graded: graded,
        content: content
      )

    project = Repo.get!(Project, project_id)
    publication = insert(:publication, project: project, published: nil)
    insert(:published_resource, publication: publication, resource: resource, revision: revision)
    revision
  end
end
