defmodule Oli.Experiments.ConfigurationTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Authoring.Course.Project
  alias Oli.Experiments
  alias Oli.Experiments.{CreateExperimentRequest, ExperimentError, LifecycleRequest, Scope}
  alias Oli.Repo
  alias Oli.Resources.ResourceType

  test "creates one atomic graph with shared stable conditions and multiple decision points" do
    scope = project_scope()
    group_a = alternatives_revision(scope.project_id, "Group A")
    group_b = alternatives_revision(scope.project_id, "Group B")
    page_a = page_revision(scope.project_id, "Intervention A", false)
    page_b = page_revision(scope.project_id, "Intervention B", false)

    assert {:ok, definition} =
             Experiments.create_experiment(
               graph_request(scope, [
                 point(group_a, page_a, "placement-a"),
                 point(group_b, page_b, "placement-b")
               ])
             )

    assert {:ok, view} = Experiments.get_experiment_authoring_view(definition.id, scope)
    assert Enum.map(view.conditions, & &1.condition_code) == ["control", "control-2"]
    assert length(view.decision_points) == 2
    assert length(view.mappings) == 4
    assert length(view.interventions) == 2
    assert Enum.uniq(Enum.map(view.mappings, & &1.condition_id)) |> length() == 2

    [control, variant] = view.conditions

    update = %Oli.Experiments.UpdateExperimentRequest{
      scope: scope,
      conditions: [
        %{id: control.id, label: "Baseline", active: true, position: 0},
        %{id: variant.id, label: "Variant", active: true, position: 1}
      ],
      decision_points: [
        persisted_point(group_a, page_a, "placement-a", control.id, variant.id),
        persisted_point(group_b, page_b, "placement-b", control.id, variant.id)
      ]
    }

    assert {:ok, _updated} = Experiments.update_experiment(definition.id, update)
    assert {:ok, updated_view} = Experiments.get_experiment_authoring_view(definition.id, scope)

    assert Enum.map(updated_view.conditions, &{&1.id, &1.condition_code}) ==
             [{control.id, "control"}, {variant.id, "control-2"}]

    assert {:ok, active} =
             Experiments.activate_experiment(definition.id, %LifecycleRequest{scope: scope})

    assert active.state == :active
  end

  test "returns structured errors for incomplete mappings and incompatible assessment bindings" do
    scope = project_scope()
    group = alternatives_revision(scope.project_id, "Group")
    intervention_page = page_revision(scope.project_id, "Intervention", false)
    unscored_page = page_revision(scope.project_id, "Assessment", false)

    incomplete =
      point(group, intervention_page, "placement")
      |> put_in([:mappings], [%{condition_ref: "control", option_id: "alt-a"}])

    assert {:error, %ExperimentError{message: message, details: details}} =
             Experiments.create_experiment(graph_request(scope, [incomplete]))

    assert message == "decision point must map every condition exactly once"
    assert details.decision_point_key == "alternatives:#{group.resource_id}"

    malformed_weight =
      point(group, intervention_page, "placement")
      |> put_in([:mappings, Access.at(0), :weight], "heavy")

    assert {:error, %ExperimentError{message: weight_message}} =
             Experiments.create_experiment(graph_request(scope, [malformed_weight]))

    assert weight_message == "decision point mapping weights must be numeric"

    adaptive =
      point(group, intervention_page, "placement")
      |> Map.put(:algorithm, :thompson_sampling)
      |> put_in([:interventions, Access.at(0), :assessment_binding], %{
        assessment_page_resource_id: unscored_page.resource_id,
        reward_threshold: Decimal.new("0.5")
      })

    assert {:error, %ExperimentError{message: adaptive_message}} =
             Experiments.create_experiment(graph_request(scope, [adaptive]))

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
      conditions: graph_conditions(),
      decision_points: [point(group, page, "placement")]
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

  test "rejects simultaneous current bindings and permits sequential reuse after completion" do
    scope = project_scope()
    group = alternatives_revision(scope.project_id, "Reusable Group")
    first_page = page_revision(scope.project_id, "First", false)
    second_page = page_revision(scope.project_id, "Second", false)

    assert {:ok, first} =
             Experiments.create_experiment(
               graph_request(scope, [point(group, first_page, "first")])
             )

    assert {:error, %ExperimentError{type: :conflict}} =
             Experiments.create_experiment(
               graph_request(scope, [point(group, second_page, "second")])
             )

    assert {:ok, _active} =
             Experiments.activate_experiment(first.id, %LifecycleRequest{scope: scope})

    assert {:ok, _completed} =
             Experiments.complete_experiment(first.id, %LifecycleRequest{scope: scope})

    assert {:ok, second} =
             Experiments.create_experiment(
               graph_request(scope, [point(group, second_page, "second")])
             )

    refute second.id == first.id
  end

  test "persists inclusive Thompson thresholds at both boundaries" do
    scope = project_scope()
    group_a = alternatives_revision(scope.project_id, "Adaptive A")
    group_b = alternatives_revision(scope.project_id, "Adaptive B")
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

    request =
      graph_request(scope, [
        adaptive_point.(group_a, page_a, assessment_a, "a", Decimal.new(0)),
        adaptive_point.(group_b, page_b, assessment_b, "b", Decimal.new(1))
      ])

    assert {:ok, definition} = Experiments.create_experiment(request)
    assert {:ok, view} = Experiments.get_experiment_authoring_view(definition.id, scope)

    assert view.assessment_bindings
           |> Enum.map(& &1.reward_threshold)
           |> Enum.map(&Decimal.to_string/1)
           |> Enum.sort() == ["0.00000", "1.00000"]

    assert {:ok, %{state: :active}} =
             Experiments.activate_experiment(definition.id, %LifecycleRequest{scope: scope})
  end

  defp graph_request(scope, decision_points) do
    %CreateExperimentRequest{
      scope: scope,
      slug: "experiment-#{System.unique_integer([:positive])}",
      name: "Experiment",
      algorithm: :weighted_random,
      conditions: graph_conditions(),
      decision_points: decision_points
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
      policy_config: %{},
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

  defp persisted_point(group, page, element_id, control_id, variant_id) do
    point(group, page, element_id)
    |> Map.put(:mappings, [
      %{condition_id: control_id, option_id: "alt-a", weight: 1.0, position: 0},
      %{condition_id: variant_id, option_id: "alt-b", weight: 1.0, position: 1}
    ])
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
