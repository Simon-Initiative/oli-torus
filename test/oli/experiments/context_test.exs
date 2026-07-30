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
    ExperimentSectionParticipation,
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
      assert definition.project_id == scope.project_id
      assert definition.section_ids == [scope.section_id]
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

      refute Experiments.project_has_experiments?(scope.project_id)

      assert {:ok, [%DecisionPointCandidate{} = candidate]} =
               Experiments.list_available_decision_points(scope)

      assert candidate.alternatives_resource_id == alternatives.resource_id
      assert candidate.option_labels == %{"alt-a" => "A", "alt-b" => "B"}

      assert {:ok, %ExperimentDefinition{} = definition} =
               Experiments.create_experiment(graph_request(scope, alternatives))

      assert Experiments.project_has_experiments?(scope.project_id)

      assert definition.section_ids == []

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

      refute Experiments.project_has_experiments?(scope.project_id)
    end

    test "creates a section-scoped experiment graph" do
      scope = %{valid_scope() | user_id: nil, enrollment_id: nil}
      alternatives = alternatives_revision(scope.project_id)

      assert {:ok, %ExperimentDefinition{} = definition} =
               Experiments.create_experiment(graph_request(scope, alternatives))

      assert definition.section_ids == [scope.section_id]
    end

    test "project authoring lists and reads experiments regardless of selected section count" do
      scope = project_scope()
      delivery_scope = runtime_scope(scope)
      alternatives = alternatives_revision(scope.project_id)

      {:ok, unselected} =
        Experiments.create_experiment(graph_request(scope, alternatives))

      {:ok, selected} =
        Experiments.create_experiment(
          scope
          |> graph_request(alternatives)
          |> Map.put(:section_ids, [delivery_scope.section_id])
        )

      assert {:ok, definitions} = Experiments.list_project_experiments(scope)
      assert Enum.map(definitions, & &1.id) == [selected.id, unselected.id]

      assert {:ok, %ExperimentAuthoringView{definition: %{id: id}}} =
               Experiments.get_experiment_authoring_view(selected.id, scope)

      assert id == selected.id

      assert {:ok, %ExperimentAuthoringView{definition: %{id: unselected_id}}} =
               Experiments.get_experiment_authoring_view(unselected.id, scope)

      assert unselected_id == unselected.id
    end

    test "creates an experiment associated with multiple sections" do
      scope = %{valid_scope() | user_id: nil, enrollment_id: nil}
      project = Repo.get!(Project, scope.project_id)
      institution = Repo.get!(Institution, scope.institution_id)
      other_section = insert(:section, institution: institution, base_project: project)
      publication = Repo.get!(Oli.Publishing.Publications.Publication, scope.publication_id)

      insert(:section_project_publication,
        section: other_section,
        project: project,
        publication: publication
      )

      alternatives = alternatives_revision(scope.project_id)

      request =
        scope
        |> graph_request(alternatives)
        |> Map.put(:section_ids, [scope.section_id, other_section.id])

      assert {:ok, %ExperimentDefinition{} = definition} =
               Experiments.create_experiment(request)

      assert Enum.sort(definition.section_ids) ==
               Enum.sort([scope.section_id, other_section.id])

      assert {:ok, %ExperimentAuthoringView{definition: scoped_definition}} =
               Experiments.get_experiment_authoring_view(
                 definition.id,
                 %{scope | section_id: other_section.id}
               )

      assert Enum.sort(scoped_definition.section_ids) ==
               Enum.sort([scope.section_id, other_section.id])
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

    test "rejects learner preference alternatives as experiment decision points" do
      scope = project_scope()
      alternatives = learner_preference_alternatives_revision(scope.project_id)

      assert {:error, %ExperimentError{type: :invalid_condition, message: message}} =
               Experiments.create_experiment(graph_request(scope, alternatives))

      assert message == "selected alternatives group is not an A/B Testing decision point"
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
        section_id: runtime_scope.section_id,
        enrollment_id: runtime_scope.enrollment_id,
        user_id: runtime_scope.user_id,
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

  describe "section participation eligibility" do
    test "includes active base and current-remix sections exactly once" do
      author = insert(:author)
      institution = insert(:institution)
      project = insert(:project)
      insert(:author_project, author_id: author.id, project_id: project.id)
      publication = insert(:publication, project: project)
      other_project = insert(:project)

      base =
        insert(:section,
          institution: institution,
          base_project: project,
          title: "Base section"
        )

      remix =
        insert(:section,
          institution: institution,
          base_project: other_project,
          title: "Remix section"
        )

      for section <- [base, remix] do
        insert(:section_project_publication,
          section: section,
          project: project,
          publication: publication
        )
      end

      scope = %Scope{
        author_id: author.id,
        institution_id: institution.id,
        project_id: project.id
      }

      assert {:ok, [%{id: base_id}, %{id: remix_id}]} =
               Experiments.list_eligible_sections(scope)

      assert [base_id, remix_id] == [base.id, remix.id]

      request =
        scope
        |> graph_request(alternatives_revision(project.id))
        |> Map.put(:section_ids, [remix.id])

      assert {:ok, %{section_ids: [^remix_id]}} = Experiments.create_experiment(request)
    end

    test "excludes inactive, removed-remix, unrelated, and cross-institution sections" do
      author = insert(:author)
      institution = insert(:institution)
      other_institution = insert(:institution)
      project = insert(:project)
      insert(:author_project, author_id: author.id, project_id: project.id)
      publication = insert(:publication, project: project)
      other_project = insert(:project)

      eligible = insert(:section, institution: institution, base_project: project)

      inactive =
        insert(:section, institution: institution, base_project: project, status: :archived)

      removed_remix = insert(:section, institution: institution, base_project: other_project)
      _unrelated = insert(:section, institution: institution, base_project: other_project)
      cross_institution = insert(:section, institution: other_institution, base_project: project)

      for section <- [eligible, inactive, removed_remix, cross_institution] do
        insert(:section_project_publication,
          section: section,
          project: project,
          publication: publication
        )
      end

      assert {:ok, summaries_before_removal} =
               Experiments.list_eligible_sections(%Scope{
                 author_id: author.id,
                 institution_id: institution.id,
                 project_id: project.id
               })

      assert removed_remix.id in Enum.map(summaries_before_removal, & &1.id)

      Oli.Delivery.Sections.SectionsProjectsPublications
      |> Ecto.Query.where(
        [spp],
        spp.section_id == ^removed_remix.id and spp.project_id == ^project.id
      )
      |> Repo.delete_all()

      assert {:ok, [%{id: eligible_id}]} =
               Experiments.list_eligible_sections(%Scope{
                 author_id: author.id,
                 institution_id: institution.id,
                 project_id: project.id
               })

      assert eligible_id == eligible.id
    end

    test "rejects invalid project scope without leaking section metadata" do
      assert {:error, %ExperimentError{type: :invalid_scope}} =
               Experiments.list_eligible_sections(%Scope{project_id: -1})
    end

    test "rejects an author without accepted project access" do
      author = insert(:author)
      institution = insert(:institution)
      project = insert(:project)

      assert {:error, %ExperimentError{type: :invalid_scope}} =
               Experiments.list_eligible_sections(%Scope{
                 author_id: author.id,
                 institution_id: institution.id,
                 project_id: project.id
               })
    end
  end

  # Implementation proof: AC-001, AC-002, AC-003, AC-007
  describe "section participation APIs" do
    test "reads and atomically replaces independent selected section sets" do
      {scope, author} = authorized_project_scope()
      first_section = runtime_scope(scope)
      second_section = runtime_scope(scope)
      alternatives = alternatives_revision(scope.project_id)

      {:ok, first} = Experiments.create_experiment(graph_request(scope, alternatives))
      {:ok, second} = Experiments.create_experiment(graph_request(scope, alternatives))
      authoring_scope = %{scope | author_id: author.id}

      assert {:ok, %ExperimentSectionParticipation{selected_ids: []}} =
               Experiments.get_section_participation(first.id, authoring_scope)

      assert {:ok, %ExperimentSectionParticipation{selected_ids: selected_ids}} =
               Experiments.update_section_participation(
                 first.id,
                 authoring_scope,
                 [second_section.section_id, first_section.section_id, first_section.section_id]
               )

      assert selected_ids == Enum.sort([first_section.section_id, second_section.section_id])

      assert {:ok, %ExperimentSectionParticipation{selected_ids: []}} =
               Experiments.get_section_participation(second.id, authoring_scope)

      assert {:ok, %ExperimentSectionParticipation{selected_ids: []}} =
               Experiments.update_section_participation(first.id, authoring_scope, [])
    end

    test "shows stale selections and rejects forged IDs without partial mutation" do
      {scope, author} = authorized_project_scope()
      delivery_scope = runtime_scope(scope)
      alternatives = alternatives_revision(scope.project_id)
      authoring_scope = %{scope | author_id: author.id}

      {:ok, definition} =
        Experiments.create_experiment(
          scope
          |> graph_request(alternatives)
          |> Map.put(:section_ids, [delivery_scope.section_id])
        )

      section = Repo.get!(Oli.Delivery.Sections.Section, delivery_scope.section_id)
      section |> Ecto.Changeset.change(status: :archived) |> Repo.update!()

      assert {:ok,
              %ExperimentSectionParticipation{
                selected_ids: [],
                stale_sections: [%{id: stale_id}]
              }} = Experiments.get_section_participation(definition.id, authoring_scope)

      assert stale_id == delivery_scope.section_id

      assert {:error, %ExperimentError{type: :invalid_scope}} =
               Experiments.update_section_participation(
                 definition.id,
                 authoring_scope,
                 [delivery_scope.section_id, -1]
               )

      assert {:ok, %ExperimentSectionParticipation{stale_sections: [%{id: ^stale_id}]}} =
               Experiments.get_section_participation(definition.id, authoring_scope)

      assert {:ok, %ExperimentSectionParticipation{stale_sections: []}} =
               Experiments.update_section_participation(definition.id, authoring_scope, [])
    end

    test "rejects completed and archived experiments" do
      {scope, author} = authorized_project_scope()
      alternatives = alternatives_revision(scope.project_id)
      authoring_scope = %{scope | author_id: author.id}
      {:ok, definition} = Experiments.create_experiment(graph_request(scope, alternatives))

      {:ok, active} = Experiments.activate_experiment(definition.id, lifecycle(scope))
      {:ok, completed} = Experiments.complete_experiment(active.id, lifecycle(scope))

      assert {:error, %ExperimentError{type: :invalid_state}} =
               Experiments.update_section_participation(completed.id, authoring_scope, [])

      {:ok, archived} = Experiments.archive_experiment(completed.id, lifecycle(scope))

      assert {:error, %ExperimentError{type: :invalid_state}} =
               Experiments.update_section_participation(archived.id, authoring_scope, [])
    end

    test "emits privacy-safe update and validation telemetry" do
      attach_participation_telemetry()
      {scope, author} = authorized_project_scope()
      section_scope = runtime_scope(scope)
      alternatives = alternatives_revision(scope.project_id)
      authoring_scope = %{scope | author_id: author.id}
      {:ok, definition} = Experiments.create_experiment(graph_request(scope, alternatives))

      assert {:ok, _} =
               Experiments.update_section_participation(
                 definition.id,
                 authoring_scope,
                 [section_scope.section_id]
               )

      assert_receive {:participation_telemetry, :updated, metadata}
      refute Map.has_key?(metadata, :section_titles)
      refute Map.has_key?(metadata, :user_id)

      assert {:error, _} =
               Experiments.update_section_participation(definition.id, authoring_scope, [-1])

      assert_receive {:participation_telemetry, :validation_failed, failed_metadata}
      assert failed_metadata.requested_count == 1
      refute Map.has_key?(failed_metadata, :section_ids)
    end

    test "serializes concurrent complete-set updates without duplicates" do
      {scope, author} = authorized_project_scope()
      first_section = runtime_scope(scope)
      second_section = runtime_scope(scope)
      alternatives = alternatives_revision(scope.project_id)
      authoring_scope = %{scope | author_id: author.id}
      {:ok, definition} = Experiments.create_experiment(graph_request(scope, alternatives))

      results =
        [[first_section.section_id], [second_section.section_id]]
        |> Enum.map(fn section_ids ->
          Task.async(fn ->
            Experiments.update_section_participation(
              definition.id,
              authoring_scope,
              section_ids
            )
          end)
        end)
        |> Enum.map(&Task.await(&1, 5_000))

      assert Enum.all?(results, &match?({:ok, %ExperimentSectionParticipation{}}, &1))

      assert {:ok, %ExperimentSectionParticipation{selected_ids: [selected_id]}} =
               Experiments.get_section_participation(definition.id, authoring_scope)

      assert selected_id in [first_section.section_id, second_section.section_id]
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

    test "does not distinguish out-of-scope experiment IDs from missing IDs" do
      scope = project_scope()
      other_scope = project_scope()
      alternatives = alternatives_revision(other_scope.project_id)

      assert {:ok, foreign_experiment} =
               Experiments.create_experiment(graph_request(other_scope, alternatives))

      assert {:error, %ExperimentError{type: :not_found, message: foreign_message}} =
               Experiments.activate_experiment(foreign_experiment.id, lifecycle(scope))

      assert {:error, %ExperimentError{type: :not_found, message: missing_message}} =
               Experiments.activate_experiment(-1, lifecycle(scope))

      assert foreign_message == missing_message
    end

    test "allows only one active experiment per stable decision point" do
      scope = project_scope()
      first_section = runtime_scope(scope)
      second_section = runtime_scope(scope)
      alternatives = alternatives_revision(scope.project_id)
      other_alternatives = alternatives_revision(scope.project_id)

      create_experiment = fn decision_point, section_ids ->
        scope
        |> graph_request(decision_point)
        |> Map.put(:section_ids, section_ids)
        |> Experiments.create_experiment()
        |> elem(1)
      end

      first = create_experiment.(alternatives, [first_section.section_id])
      same_point_other_section = create_experiment.(alternatives, [second_section.section_id])
      same_point_no_sections = create_experiment.(alternatives, [])
      different_point = create_experiment.(other_alternatives, [second_section.section_id])

      different_key =
        scope
        |> graph_request(alternatives)
        |> Map.update!(:decision_point, fn decision_point ->
          Map.put(
            decision_point,
            :decision_point_key,
            "secondary:#{alternatives.resource_id}"
          )
        end)
        |> Map.put(:section_ids, [second_section.section_id])
        |> Experiments.create_experiment()
        |> elem(1)

      assert {:ok, %{state: :active}} =
               Experiments.activate_experiment(first.id, lifecycle(scope))

      assert {:error,
              %ExperimentError{
                type: :conflict,
                message: "another active experiment already targets this decision point",
                details: %{
                  alternatives_resource_id: alternatives_resource_id,
                  decision_point_key: decision_point_key
                }
              }} =
               Experiments.activate_experiment(same_point_other_section.id, lifecycle(scope))

      assert alternatives_resource_id == alternatives.resource_id
      assert decision_point_key == "alternatives:#{alternatives.resource_id}"

      assert {:error, %ExperimentError{type: :conflict}} =
               Experiments.activate_experiment(same_point_no_sections.id, lifecycle(scope))

      assert {:ok, %{state: :active}} =
               Experiments.activate_experiment(different_point.id, lifecycle(scope))

      assert {:ok, %{state: :active}} =
               Experiments.activate_experiment(different_key.id, lifecycle(scope))

      assert {:ok, %{state: :paused}} =
               Experiments.pause_experiment(first.id, lifecycle(scope))

      assert {:ok, %{state: :active}} =
               Experiments.activate_experiment(same_point_other_section.id, lifecycle(scope))

      assert {:error, %ExperimentError{type: :conflict}} =
               Experiments.activate_experiment(same_point_no_sections.id, lifecycle(scope))

      assert {:ok, %{state: :completed}} =
               Experiments.complete_experiment(same_point_other_section.id, lifecycle(scope))

      assert {:ok, %{state: :active}} =
               Experiments.activate_experiment(same_point_no_sections.id, lifecycle(scope))

      assert {:ok, %{state: :archived}} =
               Experiments.archive_experiment(same_point_no_sections.id, lifecycle(scope))

      after_archive = create_experiment.(alternatives, [first_section.section_id])

      assert {:ok, %{state: :active}} =
               Experiments.activate_experiment(after_archive.id, lifecycle(scope))
    end

    test "rejects competing activation requests for the same stable decision point" do
      scope = project_scope()
      section = runtime_scope(scope)
      alternatives = alternatives_revision(scope.project_id)

      experiments =
        for _index <- 1..2 do
          request =
            scope
            |> graph_request(alternatives)
            |> Map.put(:section_ids, [section.section_id])

          assert {:ok, experiment} = Experiments.create_experiment(request)
          experiment
        end

      results =
        experiments
        |> Enum.map(fn experiment ->
          Task.async(fn -> Experiments.activate_experiment(experiment.id, lifecycle(scope)) end)
        end)
        |> Enum.map(&Task.await(&1, 5_000))

      assert Enum.count(results, &match?({:ok, %{state: :active}}, &1)) == 1
      assert Enum.count(results, &match?({:error, %ExperimentError{type: :conflict}}, &1)) == 1
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

  defp project_scope do
    institution = insert(:institution)
    project = insert(:project)

    %Scope{
      institution_id: institution.id,
      project_id: project.id
    }
  end

  defp authorized_project_scope do
    scope = project_scope()
    author = insert(:author)
    insert(:author_project, author_id: author.id, project_id: scope.project_id)
    {scope, author}
  end

  defp runtime_scope(%Scope{} = project_scope) do
    project = Repo.get!(Project, project_scope.project_id)
    institution = Repo.get!(Institution, project_scope.institution_id)
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

    revision =
      insert(:revision, %{
        resource: resource,
        resource_type_id: ResourceType.id_for_alternatives(),
        title: "Decision Point",
        content: %{
          "strategy" => "upgrade_decision_point",
          "options" => [
            %{"id" => "alt-a", "name" => "A"},
            %{"id" => "alt-b", "name" => "B"}
          ]
        }
      })

    attach_revision_to_project_publications(project_id, revision)
    revision
  end

  defp learner_preference_alternatives_revision(project_id) do
    resource = insert(:resource)
    insert(:project_resource, project_id: project_id, resource_id: resource.id)

    revision =
      insert(:revision, %{
        resource: resource,
        resource_type_id: ResourceType.id_for_alternatives(),
        title: "Learner Preference",
        content: %{
          "strategy" => "user_section_preference",
          "options" => [
            %{"id" => "alt-a", "name" => "A"},
            %{"id" => "alt-b", "name" => "B"}
          ]
        }
      })

    attach_revision_to_project_publications(project_id, revision)
    revision
  end

  defp attach_revision_to_project_publications(project_id, revision) do
    project = Repo.get!(Project, project_id)

    publications =
      Oli.Publishing.Publications.Publication
      |> Ecto.Query.where([publication], publication.project_id == ^project_id)
      |> Repo.all()

    publications =
      case Enum.any?(publications, &is_nil(&1.published)) do
        true -> publications
        false -> [insert(:publication, project: project, published: nil) | publications]
      end

    Enum.each(publications, fn publication ->
      insert(:published_resource,
        publication: publication,
        resource: revision.resource,
        revision: revision
      )
    end)

    Oli.Delivery.Sections.SectionsProjectsPublications
    |> Ecto.Query.where([mapping], mapping.project_id == ^project_id)
    |> Repo.all()
    |> Enum.uniq_by(& &1.section_id)
    |> Enum.each(fn mapping ->
      section = Repo.get!(Oli.Delivery.Sections.Section, mapping.section_id)

      insert(:section_resource,
        project: project,
        section: section,
        resource_id: revision.resource_id
      )
    end)
  end

  defp graph_request(scope, alternatives, conditions \\ nil) do
    %CreateExperimentRequest{
      scope: scope,
      slug: "ab-test-#{System.unique_integer([:positive])}",
      name: "A/B Test",
      algorithm: :weighted_random,
      decision_point: %{
        alternatives_resource_id: alternatives.resource_id,
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

  defp attach_participation_telemetry do
    parent = self()
    handler_id = "participation-context-test-#{System.unique_integer([:positive])}"

    :telemetry.attach_many(
      handler_id,
      [
        [:oli, :experiments, :participation, :updated],
        [:oli, :experiments, :participation, :validation_failed]
      ],
      fn event, _measurements, metadata, _config ->
        send(parent, {:participation_telemetry, List.last(event), metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)
  end

  defp private_schema?(struct) do
    struct.__struct__
    |> Module.split()
    |> Enum.take(3)
    |> Kernel.==(["Oli", "Experiments", "Schemas"])
  end
end
