defmodule Oli.Experiments.RuntimeTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Experiments

  alias Oli.Experiments.{
    AssignmentDecision,
    CreateExperimentRequest,
    ExposureReceipt,
    LifecycleRequest,
    OutcomeReceipt,
    RecordExposureRequest,
    RecordOutcomeRequest,
    RecordRewardRequest,
    RewardReceipt,
    Scope
  }

  alias Oli.Experiments.Schemas.{
    Assignment,
    Condition,
    DecisionPoint,
    DecisionPointCondition,
    ExperimentSection,
    Intervention,
    PolicyState
  }

  alias Oli.Resources.ResourceType
  alias Oli.Resources.Alternatives
  alias Oli.Resources.Alternatives.AlternativesStrategyContext

  describe "assign_condition/1" do
    test "returns no_experiment when no active experiment matches and emits fallback telemetry" do
      attach_telemetry([[:oli, :experiments, :assignment, :fallback]])

      scope = valid_scope()
      revision = alternatives_revision()
      deploy_revision(scope, revision)

      assert {:ok, %AssignmentDecision{status: :no_experiment}} =
               Experiments.assign_condition(assign_request(scope, revision, ["a"]))

      assert_receive {:telemetry, [:oli, :experiments, :assignment, :fallback], %{count: 1},
                      %{reason: :no_experiment}}
    end

    test "creates and reuses sticky assignments by enrollment" do
      attach_telemetry([[:oli, :experiments, :telemetry, :assignment_decided]])

      %{scope: scope, revision: revision} = active_experiment_with_conditions()

      assert {:ok, %AssignmentDecision{status: :assigned, reused?: false} = first} =
               Experiments.assign_condition(assign_request(scope, revision, ["a", "b"]))

      assert first.condition_code in ["a", "b"]
      assert first.assignment_id

      assert {:ok, %AssignmentDecision{status: :assigned, reused?: true} = second} =
               Experiments.assign_condition(assign_request(scope, revision, ["a", "b"]))

      assert second.assignment_id == first.assignment_id
      assert Repo.aggregate(Assignment, :count, :id) == 1

      assert_operational_event(:assignment_decided, "assignment")

      assert_operational_event(:assignment_decided, "assignment")
    end

    test "creates independent sticky assignments for repeated interventions" do
      %{scope: scope, revision: revision, decision_point: decision_point} =
        active_experiment_with_conditions()

      first_page = insert(:resource)
      second_page = insert(:resource)

      first_intervention =
        insert_intervention!(decision_point, first_page.id, "placement-one")

      second_intervention =
        insert_intervention!(decision_point, second_page.id, "placement-two")

      first_request =
        intervention_request(scope, revision, first_intervention, first_page.id, ["a", "b"])

      second_request =
        intervention_request(scope, revision, second_intervention, second_page.id, ["a", "b"])

      assert {:ok, %AssignmentDecision{reused?: false} = first} =
               Experiments.assign_condition(first_request)

      assert {:ok, %AssignmentDecision{reused?: false} = second} =
               Experiments.assign_condition(second_request)

      assert first.assignment_id != second.assignment_id

      assert {:ok, %AssignmentDecision{assignment_id: first_id, reused?: true}} =
               Experiments.assign_condition(first_request)

      assert first_id == first.assignment_id
      assert Repo.aggregate(Assignment, :count, :id) == 2
    end

    test "lazily materializes weighted-random interventions from delivered placements" do
      %{scope: scope, revision: revision, decision_point: decision_point} =
        active_experiment_with_conditions()

      add_condition_mappings!(decision_point)
      page = insert(:resource)

      request = %{
        assign_request(scope, revision, ["a", "b"])
        | page_resource_id: page.id,
          content_element_id: "discovered-placement"
      }

      assert Repo.aggregate(Intervention, :count, :id) == 0

      assert {:ok, %AssignmentDecision{status: :assigned, reused?: false} = first} =
               Experiments.assign_condition(request)

      intervention = Repo.one!(Intervention)
      assert intervention.decision_point_id == decision_point.id
      assert intervention.page_resource_id == page.id
      assert intervention.content_element_id == "discovered-placement"

      assert Repo.get!(Assignment, first.assignment_id).intervention_id == intervention.id

      assert {:ok, %AssignmentDecision{assignment_id: assignment_id, reused?: true}} =
               Experiments.assign_condition(request)

      assert assignment_id == first.assignment_id
      assert Repo.aggregate(Intervention, :count, :id) == 1
    end

    test "batch assignment materializes all missing weighted-random placements" do
      %{scope: scope, revision: revision, decision_point: decision_point} =
        active_experiment_with_conditions()

      add_condition_mappings!(decision_point)
      page = insert(:resource)

      requests =
        for id <- ["first-discovered", "second-discovered"] do
          %{
            assign_request(scope, revision, ["a", "b"])
            | page_resource_id: page.id,
              content_element_id: id
          }
        end

      assert {:ok, decisions} = Experiments.assign_page_conditions(requests)
      assert Map.keys(decisions) |> Enum.sort() == ["first-discovered", "second-discovered"]
      assert Repo.aggregate(Intervention, :count, :id) == 2
      assert Repo.aggregate(Assignment, :count, :id) == 2
    end

    test "lazy page materialization keeps SELECT reads constant for 2 and 10 placements" do
      select_counts =
        for placement_count <- [2, 10] do
          %{scope: scope, revision: revision, decision_point: decision_point} =
            active_experiment_with_conditions()

          add_condition_mappings!(decision_point)
          page = insert(:resource)

          requests =
            for index <- 1..placement_count do
              %{
                assign_request(scope, revision, ["a", "b"])
                | page_resource_id: page.id,
                  content_element_id: "lazy-placement-#{index}"
              }
            end

          count =
            count_select_queries(fn ->
              assert {:ok, decisions} = Experiments.assign_page_conditions(requests)
              assert map_size(decisions) == placement_count
            end)

          assert Repo.aggregate(
                   from(intervention in Intervention,
                     where: intervention.decision_point_id == ^decision_point.id
                   ),
                   :count,
                   :id
                 ) == placement_count

          assert Repo.aggregate(
                   from(assignment in Assignment,
                     where: assignment.decision_point_id == ^decision_point.id
                   ),
                   :count,
                   :id
                 ) == placement_count

          count
        end

      assert [two_placements, ten_placements] = select_counts
      assert two_placements == ten_placements
    end

    test "concurrent batches converge while lazily discovering the same placement" do
      %{scope: scope, revision: revision, decision_point: decision_point} =
        active_experiment_with_conditions()

      add_condition_mappings!(decision_point)
      page = insert(:resource)

      request = %{
        assign_request(scope, revision, ["a", "b"])
        | page_resource_id: page.id,
          content_element_id: "concurrently-discovered"
      }

      results =
        1..2
        |> Enum.map(fn _ ->
          Task.async(fn -> Experiments.assign_page_conditions([request]) end)
        end)
        |> Enum.map(&Task.await(&1, 5_000))

      assert Enum.all?(results, &match?({:ok, %{"concurrently-discovered" => _}}, &1))
      assert Repo.aggregate(Intervention, :count, :id) == 1
      assert Repo.aggregate(Assignment, :count, :id) == 1
    end

    test "invalid placement identities do not materialize interventions" do
      %{scope: scope, revision: revision, decision_point: decision_point} =
        active_experiment_with_conditions()

      add_condition_mappings!(decision_point)

      request = %{
        assign_request(scope, revision, ["a", "b"])
        | page_resource_id: insert(:resource).id,
          content_element_id: String.duplicate("x", 256)
      }

      assert {:ok, %AssignmentDecision{status: :no_experiment}} =
               Experiments.assign_condition(request)

      assert Repo.aggregate(Intervention, :count, :id) == 0
    end

    test "checks active section relevance without entering assignment resolution" do
      %{scope: scope} = active_experiment_with_conditions()

      assert Experiments.relevant_active_experiment?(scope.section_id, scope.project_id)
      refute Experiments.relevant_active_experiment?(scope.section_id, insert(:project).id)
    end

    test "page batch assignment keeps SELECT reads constant for 2 and 10 distinct placements" do
      select_counts =
        for placement_count <- [2, 10] do
          %{scope: scope, revision: revision, decision_point: decision_point} =
            active_experiment_with_conditions()

          add_condition_mappings!(decision_point)
          page = insert(:resource)

          requests =
            for index <- 1..placement_count do
              intervention = insert_intervention!(decision_point, page.id, "placement-#{index}")
              intervention_request(scope, revision, intervention, page.id, ["a", "b"])
            end

          count_select_queries(fn ->
            assert {:ok, decisions} = Experiments.assign_page_conditions(requests)
            assert map_size(decisions) == placement_count
          end)
        end

      assert [two_placements, ten_placements] = select_counts
      assert two_placements == ten_placements
    end

    test "delivery preparation batches distinct placements into placement-keyed decisions" do
      %{scope: scope, revision: revision, decision_point: decision_point} =
        active_experiment_with_conditions()

      add_condition_mappings!(decision_point)
      page = insert(:resource)

      elements =
        for index <- 1..2 do
          id = "placement-#{index}"
          insert_intervention!(decision_point, page.id, id)

          %{
            "type" => "alternatives",
            "id" => id,
            "alternatives_id" => revision.resource_id,
            "children" => [
              %{"type" => "alternative", "value" => "a", "children" => []},
              %{"type" => "alternative", "value" => "b", "children" => []}
            ]
          }
        end

      context = %AlternativesStrategyContext{
        enrollment_id: scope.enrollment_id,
        user: Repo.get!(Oli.Accounts.User, scope.user_id),
        institution_id: scope.institution_id,
        project_id: scope.project_id,
        publication_id: scope.publication_id,
        section_id: scope.section_id,
        mode: :delivery,
        page_resource_id: page.id,
        alternative_groups_by_id: %{
          revision.resource_id => %{
            id: revision.resource_id,
            revision_id: revision.id,
            strategy: "experiment_controlled",
            options: [%{"id" => "a"}, %{"id" => "b"}]
          }
        }
      }

      {decisions, _attributions} =
        Alternatives.prepare_delivery_decisions(context, %{"model" => elements})

      assert Map.keys(decisions) |> Enum.sort() == ["placement-1", "placement-2"]
      assert Repo.aggregate(Assignment, :count, :id) == 2
    end

    test "delivery preparation discovers experiment placements inside ordinary containers" do
      {context, [placement]} = batch_delivery_fixture(1)

      content = %{
        "model" => [
          %{
            "type" => "group",
            "id" => "ordinary-container",
            "children" => [placement]
          }
        ]
      }

      {decisions, _attributions} = Alternatives.prepare_delivery_decisions(context, content)

      assert Map.keys(decisions) == ["placement-1"]
      assert Repo.aggregate(Assignment, :count, :id) == 1
    end

    test "delivery preparation never assigns an experiment nested within Alternatives" do
      {context, [nested_experiment]} = batch_delivery_fixture(1)
      outer_group_id = System.unique_integer([:positive])

      context = %{
        context
        | alternative_groups_by_id:
            Map.put(context.alternative_groups_by_id, outer_group_id, %{
              id: outer_group_id,
              revision_id: System.unique_integer([:positive]),
              strategy: "user_section_preference",
              options: [%{"id" => "outer"}]
            })
      }

      content = %{
        "model" => [
          %{
            "type" => "alternatives",
            "id" => "outer",
            "alternatives_id" => outer_group_id,
            "children" => [
              %{
                "type" => "alternative",
                "value" => "outer",
                "children" => [nested_experiment]
              }
            ]
          }
        ]
      }

      assert {%{}, []} = Alternatives.prepare_delivery_decisions(context, content)
      assert Repo.aggregate(Assignment, :count, :id) == 0
    end

    test "full delivery preparation keeps SELECT reads constant for 2 and 10 placements" do
      select_counts =
        for placement_count <- [2, 10] do
          {context, elements} = batch_delivery_fixture(placement_count)

          count_select_queries(fn ->
            {decisions, _attributions} =
              Alternatives.prepare_delivery_decisions(context, %{"model" => elements})

            assert map_size(decisions) == placement_count
          end)
        end

      assert [two_placements, ten_placements] = select_counts
      assert two_placements == ten_placements
    end

    test "batch rollback emits no assignment evidence for earlier placements" do
      attach_telemetry([[:oli, :experiments, :telemetry, :assignment_decided]])
      {context, _elements} = batch_delivery_fixture(2)
      decision_point = Repo.one!(DecisionPoint)

      revision =
        Repo.one!(
          from revision in Oli.Resources.Revision,
            where: revision.resource_id == ^decision_point.alternatives_resource_id
        )

      interventions = Repo.all(from intervention in Intervention, order_by: intervention.id)

      requests =
        Enum.map(interventions, fn intervention ->
          intervention_request(
            %Scope{
              institution_id: context.institution_id,
              project_id: context.project_id,
              publication_id: context.publication_id,
              section_id: context.section_id,
              user_id: context.user.id,
              enrollment_id: context.enrollment_id
            },
            revision,
            intervention,
            context.page_resource_id,
            if(intervention == List.last(interventions), do: ["invalid"], else: ["a", "b"])
          )
        end)

      assert {:error, %Oli.Experiments.ExperimentError{}} =
               Experiments.assign_page_conditions(requests)

      assert Repo.aggregate(Assignment, :count, :id) == 0
      refute_receive {:telemetry, [:oli, :experiments, :telemetry, :assignment_decided], _, _}
    end

    test "concurrent page batches reload the sticky winner" do
      %{scope: scope, revision: revision, decision_point: decision_point} =
        active_experiment_with_conditions()

      add_condition_mappings!(decision_point)
      page = insert(:resource)
      intervention = insert_intervention!(decision_point, page.id, "placement")
      request = intervention_request(scope, revision, intervention, page.id, ["a", "b"])

      results =
        1..2
        |> Enum.map(fn _ ->
          Task.async(fn -> Experiments.assign_page_conditions([request]) end)
        end)
        |> Enum.map(&Task.await(&1, 5_000))

      assert Enum.all?(results, &match?({:ok, %{"placement" => %AssignmentDecision{}}}, &1))
      assert Repo.aggregate(Assignment, :count, :id) == 1
    end

    test "an active experiment with no selected sections applies nowhere" do
      attach_telemetry([[:oli, :experiments, :assignment, :fallback]])

      %{scope: scope, revision: revision, definition: definition} =
        active_experiment_with_conditions()

      Repo.delete_all(
        from(experiment_section in ExperimentSection,
          where: experiment_section.experiment_id == ^definition.id
        )
      )

      assert {:ok, %AssignmentDecision{status: :no_experiment}} =
               Experiments.assign_condition(assign_request(scope, revision, ["a", "b"]))

      assert Repo.aggregate(Assignment, :count, :id) == 0

      assert_receive {:telemetry, [:oli, :experiments, :assignment, :fallback], %{count: 1},
                      %{reason: :no_experiment}}
    end

    test "a selected section stops participating when inactive" do
      attach_telemetry([[:oli, :experiments, :assignment, :fallback]])

      %{scope: scope, revision: revision} = active_experiment_with_conditions()

      Oli.Delivery.Sections.Section
      |> Repo.get!(scope.section_id)
      |> Ecto.Changeset.change(status: :archived)
      |> Repo.update!()

      assert {:ok, %AssignmentDecision{status: :no_experiment}} =
               Experiments.assign_condition(assign_request(scope, revision, ["a", "b"]))

      assert Repo.aggregate(Assignment, :count, :id) == 0

      assert_receive {:telemetry, [:oli, :experiments, :assignment, :fallback], %{count: 1},
                      %{reason: :no_experiment}}
    end

    test "a selected current-remix section participates" do
      %{scope: scope, revision: revision} = active_experiment_with_conditions()
      other_project = insert(:project)

      Oli.Delivery.Sections.Section
      |> Repo.get!(scope.section_id)
      |> Ecto.Changeset.change(base_project_id: other_project.id)
      |> Repo.update!()

      assert {:ok, %AssignmentDecision{status: :assigned}} =
               Experiments.assign_condition(assign_request(scope, revision, ["a", "b"]))
    end

    test "a selected removed-remix section falls back without creating new assignments" do
      %{scope: scope, revision: revision} = active_experiment_with_conditions()
      other_project = insert(:project)

      Oli.Delivery.Sections.Section
      |> Repo.get!(scope.section_id)
      |> Ecto.Changeset.change(base_project_id: other_project.id)
      |> Repo.update!()

      Oli.Delivery.Sections.SectionsProjectsPublications
      |> where(
        [spp],
        spp.section_id == ^scope.section_id and spp.project_id == ^scope.project_id
      )
      |> Repo.delete_all()

      assert {:ok, %AssignmentDecision{status: :no_experiment}} =
               Experiments.assign_condition(assign_request(scope, revision, ["a", "b"]))

      assert Repo.aggregate(Assignment, :count, :id) == 0
    end

    test "matches an active decision point after compatible alternatives revision changes" do
      %{scope: scope, revision: revision, decision_point: decision_point} =
        active_experiment_with_conditions()

      updated_revision =
        insert(:revision, %{
          resource: revision.resource,
          resource_type_id: revision.resource_type_id,
          title: "Updated Decision Point",
          content: %{
            "strategy" => "upgrade_decision_point",
            "options" => [
              %{"id" => "a", "name" => "a"},
              %{"id" => "b", "name" => "b"}
            ]
          }
        })

      assert updated_revision.resource_id == revision.resource_id
      assert updated_revision.id != revision.id

      Oli.Publishing.PublishedResource
      |> Repo.get_by!(
        publication_id: scope.publication_id,
        resource_id: revision.resource_id
      )
      |> Ecto.Changeset.change(revision_id: updated_revision.id)
      |> Repo.update!()

      assert {:error, %{type: :invalid_condition}} =
               Experiments.assign_condition(assign_request(scope, revision, ["a", "b"]))

      assert {:ok, %AssignmentDecision{status: :assigned} = assignment} =
               Experiments.assign_condition(assign_request(scope, updated_revision, ["a", "b"]))

      assert assignment.decision_point_id == decision_point.id
      assert assignment.condition_code in ["a", "b"]
      assert Repo.aggregate(Assignment, :count, :id) == 1
    end

    test "preserves Thompson Sampling sticky assignment after posterior updates" do
      %{scope: scope, revision: revision} =
        active_experiment_with_conditions(algorithm: :thompson_sampling)

      assert {:ok, %AssignmentDecision{reused?: false} = first} =
               Experiments.assign_condition(assign_request(scope, revision, ["a", "b"]))

      reward_request = %RecordRewardRequest{
        key: "sticky-ts-reward:#{first.assignment_id}",
        scope: scope,
        assignment_id: first.assignment_id,
        reward_value: 1.0,
        reward_source: "test"
      }

      assert {:ok, %RewardReceipt{reused?: false}} = Experiments.record_reward(reward_request)

      assert {:ok, %AssignmentDecision{reused?: true} = second} =
               Experiments.assign_condition(assign_request(scope, revision, ["a", "b"]))

      assert second.assignment_id == first.assignment_id
      assert second.condition_id == first.condition_id
      assert second.condition_code == first.condition_code
    end

    test "emits Thompson Sampling guardrail metadata for first assignments" do
      attach_telemetry([[:oli, :experiments, :assignment, :guardrail]])

      %{scope: scope, revision: revision} =
        active_experiment_with_conditions(
          algorithm: :thompson_sampling,
          warm_up_assignments: 1
        )

      assert {:ok, %AssignmentDecision{status: :assigned}} =
               Experiments.assign_condition(assign_request(scope, revision, ["a", "b"]))

      assert_receive {:telemetry, [:oli, :experiments, :assignment, :guardrail], %{count: 1},
                      %{algorithm: :thompson_sampling, guardrail_action: :warm_up}}
    end

    test "applies fixed-control and traffic-cap guardrails before Thompson Sampling" do
      %{scope: scope, revision: revision, definition: definition, decision_point: decision_point} =
        active_experiment_with_conditions(
          algorithm: :thompson_sampling,
          fixed_control_allocation: 0.5
        )

      assert {:ok, %AssignmentDecision{condition_code: "a"}} =
               Experiments.assign_condition(assign_request(scope, revision, ["a", "b"]))

      %{
        scope: cap_scope,
        revision: cap_revision,
        definition: cap_definition,
        decision_point: cap_dp
      } =
        active_experiment_with_conditions(
          algorithm: :thompson_sampling,
          max_condition_share: 0.5
        )

      condition_a = Repo.get_by!(Condition, experiment_id: cap_definition.id, condition_code: "a")
      insert_assignment!(cap_definition, cap_dp, condition_a, valid_scope())

      assert {:ok, %AssignmentDecision{condition_code: "b"}} =
               Experiments.assign_condition(assign_request(cap_scope, cap_revision, ["a", "b"]))

      assert definition.id
      assert decision_point.id
    end

    test "serializes concurrent guardrail assignments" do
      %{scope: scope, revision: revision, decision_point: decision_point} =
        active_experiment_with_conditions(
          algorithm: :thompson_sampling,
          fixed_control_allocation: 0.5
        )

      add_condition_mappings!(decision_point)
      page = insert(:resource)
      intervention = insert_intervention!(decision_point, page.id, "serialized-placement")
      second_scope = sibling_runtime_scope(scope)

      results =
        [scope, second_scope]
        |> Enum.map(fn assignment_scope ->
          Task.async(fn ->
            request =
              intervention_request(
                assignment_scope,
                revision,
                intervention,
                page.id,
                ["a", "b"]
              )

            Experiments.assign_page_conditions([request])
          end)
        end)
        |> Enum.map(&Task.await(&1, 5_000))

      assert Enum.sort(
               for {:ok, %{"serialized-placement" => decision}} <- results,
                   do: decision.condition_code
             ) == ["a", "b"]
    end

    test "reports imbalance guardrail flag without blocking sticky fallback" do
      attach_telemetry([[:oli, :experiments, :assignment, :guardrail]])

      %{scope: scope, revision: revision, definition: definition, decision_point: decision_point} =
        active_experiment_with_conditions(
          algorithm: :thompson_sampling,
          imbalance_threshold: 0.5
        )

      condition_a = Repo.get_by!(Condition, experiment_id: definition.id, condition_code: "a")
      insert_assignment!(definition, decision_point, condition_a, valid_scope())

      assert {:ok, %AssignmentDecision{condition_code: "a"}} =
               Experiments.assign_condition(assign_request(scope, revision, ["a"]))

      assert_receive {:telemetry, [:oli, :experiments, :assignment, :guardrail], %{count: 1},
                      %{guardrail_action: :none, imbalance_flag?: true}}
    end

    test "paused and malformed Thompson Sampling experiments use controlled fallback errors" do
      %{scope: scope, revision: revision, definition: definition} =
        active_experiment_with_conditions(algorithm: :thompson_sampling)

      assert {:ok, _paused} =
               Experiments.pause_experiment(definition.id, %LifecycleRequest{
                 scope: %{
                   scope
                   | section_id: nil,
                     user_id: nil,
                     enrollment_id: nil
                 }
               })

      assert {:ok, %AssignmentDecision{status: :no_experiment}} =
               Experiments.assign_condition(assign_request(scope, revision, ["a", "b"]))

      %{
        scope: bad_scope,
        revision: bad_revision,
        definition: bad_definition,
        decision_point: bad_decision_point
      } =
        active_experiment_with_conditions(algorithm: :thompson_sampling)

      %PolicyState{}
      |> PolicyState.changeset(%{
        experiment_id: bad_definition.id,
        decision_point_id: bad_decision_point.id,
        algorithm: :thompson_sampling,
        algorithm_version: "thompson_sampling:v2",
        state: %{"a" => %{"successes" => "bad"}},
        reward_success_count: 0,
        reward_failure_count: 0,
        assignment_count: 0
      })
      |> Repo.insert!()

      assert {:error, %{type: :invalid_condition, message: "policy could not assign a condition"}} =
               Experiments.assign_condition(assign_request(bad_scope, bad_revision, ["a", "b"]))
    end

    test "rejects active experiment condition mismatches" do
      %{scope: scope, revision: revision} = active_experiment_with_conditions()

      assert {:error, %{type: :invalid_condition}} =
               Experiments.assign_condition(assign_request(scope, revision, ["missing"]))
    end

    test "fails safely and emits diagnostics when multiple active experiments match" do
      attach_telemetry([[:oli, :experiments, :assignment, :ambiguous_match]])

      %{scope: scope, revision: revision} = active_experiment_with_conditions()

      {:ok, second_definition} =
        Experiments.create_experiment(%CreateExperimentRequest{
          scope: scope,
          slug: "ambiguous-runtime",
          name: "Persisted ambiguous experiment",
          algorithm: :weighted_random
        })

      {:ok, second_active} =
        Experiments.activate_experiment(second_definition.id, %LifecycleRequest{scope: scope})

      project = Repo.get!(Oli.Authoring.Course.Project, scope.project_id)
      institution = Repo.get!(Oli.Institutions.Institution, scope.institution_id)
      publication = Repo.get!(Oli.Publishing.Publications.Publication, scope.publication_id)
      other_section = insert(:section, institution: institution, base_project: project)

      insert(:section_project_publication,
        section: other_section,
        project: project,
        publication: publication
      )

      from(experiment_section in ExperimentSection,
        where: experiment_section.experiment_id == ^second_active.id
      )
      |> Repo.update_all(set: [section_id: other_section.id])

      second_decision_point =
        %DecisionPoint{}
        |> DecisionPoint.changeset(%{
          experiment_id: second_active.id,
          alternatives_resource_id: revision.resource_id,
          decision_point_key: decision_point_key(revision)
        })
        |> Repo.insert!()

      for {code, position} <- [{"a", 0}, {"b", 1}] do
        %Condition{}
        |> Condition.changeset(%{
          experiment_id: second_active.id,
          decision_point_id: second_decision_point.id,
          condition_code: code,
          label: code,
          weight: 1.0,
          position: position
        })
        |> Repo.insert!()
      end

      assert {:ok, %AssignmentDecision{status: :no_experiment}} =
               Experiments.assign_condition(assign_request(scope, revision, ["a", "b"]))

      assert Repo.aggregate(Assignment, :count, :id) == 0

      assert_receive {:telemetry, [:oli, :experiments, :assignment, :ambiguous_match],
                      %{count: 1, sampled_match_count: 2},
                      %{
                        experiment_ids: experiment_ids,
                        truncated?: false,
                        project_id: project_id,
                        section_id: section_id,
                        alternatives_resource_id: alternatives_resource_id,
                        decision_point_key: decision_point_key
                      }}

      assert length(experiment_ids) == 2
      assert project_id == scope.project_id
      assert section_id == scope.section_id
      assert alternatives_resource_id == revision.resource_id
      assert decision_point_key == "alternatives:#{revision.resource_id}"
    end
  end

  # Implementation proof: AC-004, AC-005, AC-006
  describe "runtime evidence commands" do
    test "deselection blocks sticky reuse and all later evidence while retaining history" do
      %{scope: scope, revision: revision, definition: definition} =
        active_experiment_with_conditions(algorithm: :thompson_sampling)

      {:ok, assignment} =
        Experiments.assign_condition(assign_request(scope, revision, ["a", "b"]))

      policy_before = Repo.get_by!(PolicyState, experiment_id: definition.id)

      Repo.delete_all(
        from(experiment_section in ExperimentSection,
          where: experiment_section.experiment_id == ^definition.id
        )
      )

      assert {:ok, %AssignmentDecision{status: :no_experiment}} =
               Experiments.assigned_condition(assign_request(scope, revision, ["a", "b"]))

      assert {:ok, %AssignmentDecision{status: :no_experiment}} =
               Experiments.assign_condition(assign_request(scope, revision, ["a", "b"]))

      assert {:error, %{type: :invalid_scope}} =
               Experiments.record_exposure(%RecordExposureRequest{
                 key: "after-deselection",
                 scope: scope,
                 assignment_id: assignment.assignment_id,
                 content_revision_id: revision.id
               })

      assert {:error, %{type: :invalid_scope}} =
               Experiments.record_outcome(%RecordOutcomeRequest{
                 key: "outcome-after-deselection",
                 scope: scope,
                 assignment_id: assignment.assignment_id,
                 score: 1.0,
                 out_of: 1.0
               })

      assert {:error, %{type: :invalid_scope}} =
               Experiments.record_reward(%RecordRewardRequest{
                 key: "reward-after-deselection",
                 scope: scope,
                 assignment_id: assignment.assignment_id,
                 reward_value: 1.0,
                 reward_source: "test"
               })

      assert Repo.aggregate(Assignment, :count, :id) == 1
      assert Repo.get!(Assignment, assignment.assignment_id).runtime_event_state == %{}

      policy_after = Repo.get!(PolicyState, policy_before.id)
      assert policy_after.reward_success_count == policy_before.reward_success_count
      assert policy_after.state == policy_before.state
    end

    test "rejects exposure evidence for a revision other than the deployed decision point" do
      %{scope: scope, revision: revision} = active_experiment_with_conditions()
      {:ok, assignment} = Experiments.assign_condition(assign_request(scope, revision, ["a"]))
      other_revision = insert(:revision)

      assert {:error, %{type: :invalid_condition}} =
               Experiments.record_exposure(%RecordExposureRequest{
                 key: "mismatched-exposure:#{assignment.assignment_id}",
                 scope: scope,
                 assignment_id: assignment.assignment_id,
                 content_revision_id: other_revision.id
               })
    end

    test "records exposure and outcome without runtime state and reward idempotently" do
      attach_telemetry([
        [:oli, :experiments, :exposure, :recorded],
        [:oli, :experiments, :reward, :recorded],
        [:oli, :experiments, :telemetry, :assignment_decided],
        [:oli, :experiments, :telemetry, :exposure_recorded],
        [:oli, :experiments, :telemetry, :outcome_recorded],
        [:oli, :experiments, :telemetry, :reward_recorded],
        [:oli, :experiments, :xapi, :emit, :skipped_duplicate]
      ])

      %{scope: scope, revision: revision} = active_experiment_with_conditions()
      {:ok, assignment} = Experiments.assign_condition(assign_request(scope, revision, ["a"]))

      exposure_request = %RecordExposureRequest{
        key: "exposure:#{assignment.assignment_id}",
        scope: scope,
        assignment_id: assignment.assignment_id,
        content_revision_id: revision.id
      }

      assert {:ok, %ExposureReceipt{reused?: false} = exposure} =
               Experiments.record_exposure(exposure_request)

      assert exposure.key == exposure_request.key

      assert {:ok, %ExposureReceipt{reused?: false} = reused_exposure} =
               Experiments.record_exposure(exposure_request)

      assert reused_exposure.key == exposure.key

      outcome_request = %RecordOutcomeRequest{
        key: "outcome:#{assignment.assignment_id}",
        scope: scope,
        assignment_id: assignment.assignment_id,
        score: 1.0,
        out_of: 1.0
      }

      assert {:ok, %OutcomeReceipt{reused?: false} = outcome} =
               Experiments.record_outcome(outcome_request)

      assert outcome.key == outcome_request.key

      assert {:ok, %OutcomeReceipt{reused?: false} = reused_outcome} =
               Experiments.record_outcome(outcome_request)

      assert reused_outcome.key == outcome.key

      reward_request = %RecordRewardRequest{
        key: "reward:#{assignment.assignment_id}",
        scope: scope,
        assignment_id: assignment.assignment_id,
        outcome_key: outcome.key,
        reward_value: 1.0,
        reward_source: "test"
      }

      assert {:ok, %RewardReceipt{reused?: false} = reward} =
               Experiments.record_reward(reward_request)

      assert reward.key == reward_request.key

      assert {:ok, %RewardReceipt{reused?: true} = reused_reward} =
               Experiments.record_reward(reward_request)

      assert reused_reward.key == reward.key

      assert_receive {:telemetry, [:oli, :experiments, :exposure, :recorded], %{count: 1}, _}
      assert_receive {:telemetry, [:oli, :experiments, :reward, :recorded], %{count: 1}, _}
      assert_operational_event(:assignment_decided, "assignment")
      assert_operational_event(:exposure_recorded, "exposure")
      assert_operational_event(:outcome_recorded, "outcome")
      assert_operational_event(:reward_recorded, "reward")
      assert_duplicate_skip("reward")
    end

    test "rejects idempotent receipts outside the caller scope" do
      %{scope: scope, revision: revision} = active_experiment_with_conditions()
      {:ok, assignment} = Experiments.assign_condition(assign_request(scope, revision, ["a"]))

      exposure_request = %RecordExposureRequest{
        key: "shared-key",
        scope: scope,
        assignment_id: assignment.assignment_id,
        content_revision_id: revision.id
      }

      assert {:ok, %ExposureReceipt{}} = Experiments.record_exposure(exposure_request)

      other_scope = valid_scope()

      assert {:error, %{type: :invalid_scope}} =
               Experiments.record_exposure(%{exposure_request | scope: other_scope})
    end

    test "experiment telemetry does not perform direct xAPI emission for exposure receipts" do
      %{scope: scope, revision: revision} = active_experiment_with_conditions()
      {:ok, assignment} = Experiments.assign_condition(assign_request(scope, revision, ["a"]))

      exposure_request = %RecordExposureRequest{
        key: "failed-xapi-exposure:#{assignment.assignment_id}",
        scope: scope,
        assignment_id: assignment.assignment_id,
        content_revision_id: revision.id
      }

      assert {:ok, %ExposureReceipt{reused?: false}} =
               Experiments.record_exposure(exposure_request)

      persisted_assignment = Repo.get!(Assignment, assignment.assignment_id)
      refute Map.has_key?(persisted_assignment.runtime_event_state || %{}, "exposures")

      refute_receive {:telemetry, [:oli, :experiments, :xapi, :emit, :exception], _, _}
    end

    test "records Thompson Sampling policy state and audit updates idempotently" do
      attach_telemetry([[:oli, :experiments, :telemetry, :policy_updated]])

      %{scope: scope, revision: revision} =
        active_experiment_with_conditions(algorithm: :thompson_sampling)

      {:ok, assignment} = Experiments.assign_condition(assign_request(scope, revision, ["a"]))

      reward_request = %RecordRewardRequest{
        key: "ts-reward:#{assignment.assignment_id}",
        scope: scope,
        assignment_id: assignment.assignment_id,
        reward_value: 1.0,
        reward_source: "test"
      }

      assert {:ok, %RewardReceipt{reused?: false}} = Experiments.record_reward(reward_request)

      assert {:ok, %RewardReceipt{reused?: true}} = Experiments.record_reward(reward_request)

      policy_state = Repo.get_by!(PolicyState, experiment_id: assignment.experiment_id)
      assert policy_state.algorithm == :thompson_sampling
      assert policy_state.reward_success_count == 1
      assert policy_state.reward_failure_count == 0
      assert policy_state.state[assignment.condition_code]["successes"] == 1
      assert_operational_event(:policy_updated, "policy_update")
    end

    test "records concurrent Thompson Sampling rewards without losing posterior increments" do
      %{scope: scope, revision: revision} =
        active_experiment_with_conditions(algorithm: :thompson_sampling)

      second_scope = sibling_runtime_scope(scope)

      {:ok, first_assignment} =
        Experiments.assign_condition(assign_request(scope, revision, ["a"]))

      {:ok, second_assignment} =
        Experiments.assign_condition(assign_request(second_scope, revision, ["a"]))

      first_request = %RecordRewardRequest{
        key: "concurrent-ts-reward:#{first_assignment.assignment_id}",
        scope: scope,
        assignment_id: first_assignment.assignment_id,
        reward_value: 1.0,
        reward_source: "test"
      }

      second_request = %RecordRewardRequest{
        key: "concurrent-ts-reward:#{second_assignment.assignment_id}",
        scope: second_scope,
        assignment_id: second_assignment.assignment_id,
        reward_value: 1.0,
        reward_source: "test"
      }

      [first_result, second_result] =
        [first_request, second_request]
        |> Enum.map(&Task.async(fn -> Experiments.record_reward(&1) end))
        |> Enum.map(&Task.await(&1, 5_000))

      assert {:ok, %RewardReceipt{reused?: false}} = first_result
      assert {:ok, %RewardReceipt{reused?: false}} = second_result

      policy_state = Repo.get_by!(PolicyState, experiment_id: first_assignment.experiment_id)
      assert policy_state.reward_success_count == 2
      assert policy_state.state["a"]["successes"] == 2
      assert policy_state.state["a"]["posterior_alpha"] == 3.0
    end
  end

  defp active_experiment_with_conditions(opts \\ []) do
    scope = valid_scope()
    revision = alternatives_revision()

    deploy_revision(scope, revision)
    algorithm = Keyword.get(opts, :algorithm, :weighted_random)

    {:ok, definition} =
      Experiments.create_experiment(%CreateExperimentRequest{
        scope: scope,
        slug: "runtime-#{System.unique_integer([:positive])}",
        name: "Runtime experiment",
        algorithm: algorithm
      })

    {:ok, active} =
      Experiments.activate_experiment(definition.id, %LifecycleRequest{scope: scope})

    decision_point =
      %DecisionPoint{}
      |> DecisionPoint.changeset(%{
        experiment_id: active.id,
        alternatives_resource_id: revision.resource_id,
        decision_point_key: decision_point_key(revision),
        algorithm: active.algorithm,
        prior_alpha: Keyword.get(opts, :prior_alpha, 1.0),
        prior_beta: Keyword.get(opts, :prior_beta, 1.0),
        warm_up_assignments: Keyword.get(opts, :warm_up_assignments, 0),
        max_condition_share: Keyword.get(opts, :max_condition_share, 1.0),
        fixed_control_allocation: Keyword.get(opts, :fixed_control_allocation),
        imbalance_threshold: Keyword.get(opts, :imbalance_threshold, 1.0)
      })
      |> Repo.insert!()

    for {code, position} <- [{"a", 0}, {"b", 1}] do
      %Condition{}
      |> Condition.changeset(%{
        experiment_id: active.id,
        decision_point_id: decision_point.id,
        condition_code: code,
        label: code,
        weight: 1.0,
        position: position
      })
      |> Repo.insert!()
    end

    %{scope: scope, revision: revision, definition: active, decision_point: decision_point}
  end

  defp alternatives_revision do
    resource = insert(:resource)

    insert(:revision,
      resource: resource,
      resource_type_id: ResourceType.id_for_alternatives(),
      content: %{
        "strategy" => "upgrade_decision_point",
        "options" => [
          %{"id" => "a", "name" => "A"},
          %{"id" => "b", "name" => "B"}
        ]
      }
    )
  end

  defp assign_request(scope, revision, condition_codes) do
    %Oli.Experiments.AssignConditionRequest{
      scope: scope,
      alternatives_resource_id: revision.resource_id,
      alternatives_revision_id: revision.id,
      decision_point_key: decision_point_key(revision),
      available_condition_codes: condition_codes
    }
  end

  defp insert_intervention!(decision_point, page_resource_id, content_element_id) do
    %Intervention{}
    |> Intervention.changeset(%{
      decision_point_id: decision_point.id,
      page_resource_id: page_resource_id,
      content_element_id: content_element_id
    })
    |> Repo.insert!()
  end

  defp add_condition_mappings!(decision_point) do
    Condition
    |> where([condition], condition.decision_point_id == ^decision_point.id)
    |> order_by([condition], asc: condition.position)
    |> Repo.all()
    |> Enum.each(fn condition ->
      %DecisionPointCondition{}
      |> DecisionPointCondition.changeset(%{
        decision_point_id: decision_point.id,
        condition_id: condition.id,
        option_id: condition.condition_code,
        weight: condition.weight,
        position: condition.position
      })
      |> Repo.insert!()
    end)
  end

  defp batch_delivery_fixture(placement_count) do
    %{scope: scope, revision: revision, decision_point: decision_point} =
      active_experiment_with_conditions()

    add_condition_mappings!(decision_point)
    page = insert(:resource)

    elements =
      for index <- 1..placement_count do
        id = "placement-#{index}"
        insert_intervention!(decision_point, page.id, id)

        %{
          "type" => "alternatives",
          "id" => id,
          "alternatives_id" => revision.resource_id,
          "children" => [
            %{"type" => "alternative", "value" => "a", "children" => []},
            %{"type" => "alternative", "value" => "b", "children" => []}
          ]
        }
      end

    context = %AlternativesStrategyContext{
      enrollment_id: scope.enrollment_id,
      user: Repo.get!(Oli.Accounts.User, scope.user_id),
      institution_id: scope.institution_id,
      project_id: scope.project_id,
      publication_id: scope.publication_id,
      section_id: scope.section_id,
      mode: :delivery,
      page_resource_id: page.id,
      alternative_groups_by_id: %{
        revision.resource_id => %{
          id: revision.resource_id,
          revision_id: revision.id,
          strategy: "experiment_controlled",
          options: [%{"id" => "a"}, %{"id" => "b"}]
        }
      }
    }

    {context, elements}
  end

  defp intervention_request(scope, revision, intervention, page_resource_id, condition_codes) do
    %{
      assign_request(scope, revision, condition_codes)
      | page_resource_id: page_resource_id,
        content_element_id: intervention.content_element_id
    }
  end

  defp count_select_queries(fun) do
    parent = self()
    handler_id = "page-batch-query-count-#{System.unique_integer([:positive])}"

    :telemetry.attach(
      handler_id,
      [:oli, :repo, :query],
      fn _, _, metadata, _ ->
        case metadata.query do
          "SELECT" <> _ -> send(parent, :page_batch_select)
          _ -> :ok
        end
      end,
      %{}
    )

    try do
      fun.()
      count_messages(:page_batch_select, 0)
    after
      :telemetry.detach(handler_id)
    end
  end

  defp count_messages(message, count) do
    receive do
      ^message -> count_messages(message, count + 1)
    after
      0 -> count
    end
  end

  defp decision_point_key(revision), do: "alternatives:#{revision.resource_id}"

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

  defp deploy_revision(scope, revision) do
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
  end

  defp sibling_runtime_scope(%Scope{} = scope) do
    section = Repo.get!(Oli.Delivery.Sections.Section, scope.section_id)
    user = insert(:user)
    enrollment = insert(:enrollment, section: section, user: user)

    %{scope | user_id: user.id, enrollment_id: enrollment.id}
  end

  defp attach_telemetry(events) do
    parent = self()
    handler_id = "experiment-runtime-test-#{System.unique_integer([:positive])}"

    :telemetry.attach_many(
      handler_id,
      events,
      fn event, measurements, metadata, _config ->
        send(parent, {:telemetry, event, measurements, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)
  end

  defp assert_operational_event(event, role) do
    assert_receive {:telemetry, [:oli, :experiments, :telemetry, ^event], %{count: 1},
                    %{"role" => ^role}}
  end

  defp assert_duplicate_skip(event_type) do
    assert_receive {:telemetry, [:oli, :experiments, :xapi, :emit, :skipped_duplicate],
                    %{count: 1}, %{attribution_role: ^event_type, key_hash: hash}}

    assert byte_size(hash) == 64
  end

  defp insert_assignment!(definition, decision_point, condition, scope) do
    %Assignment{}
    |> Assignment.changeset(%{
      experiment_id: definition.id,
      decision_point_id: decision_point.id,
      condition_id: condition.id,
      section_id: scope.section_id,
      enrollment_id: scope.enrollment_id,
      user_id: scope.user_id,
      assigned_by_policy: Atom.to_string(definition.algorithm),
      policy_version: "test",
      assignment_key: "test-assignment-#{System.unique_integer([:positive])}",
      assigned_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Repo.insert!()
  end
end
