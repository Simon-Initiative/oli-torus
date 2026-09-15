defmodule Oli.Scenarios.OliTorusGettingStartedCourseScenarioTest do
  use Oli.DataCase

  alias Oli.Activities.ActivityRegistration
  alias Oli.Authoring.Editing.ContainerEditor
  alias Oli.Delivery.Attempts.Core.{ActivityAttempt, ResourceAccess, ResourceAttempt}
  alias Oli.Delivery.Metrics
  alias Oli.Delivery.Sections.Enrollment
  alias Oli.Publishing
  alias Oli.Resources.Revision
  alias Oli.Scenarios
  alias Oli.Seeding.BundledScenarios
  alias OliWeb.Curriculum.Rollup

  @scenario_id "oli_torus_getting_started_course"
  @project_name "oli_torus_getting_started_course"
  @section_name "oli_torus_getting_started_section"
  @activity_titles [
    "The Torus Authoring Workspace",
    "Build a Course Structure",
    "Choose Aligned Authoring Practices",
    "Name the Snapshot Action",
    "Connect Authoring and Delivery"
  ]

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkin(Oli.Repo)
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Oli.Repo, isolation: :serializable)
    Ecto.Adapters.SQL.Sandbox.mode(Oli.Repo, {:shared, self()})
    :ok
  end

  test "bundles and executes the complete getting-started course workflow" do
    assert {:ok, metadata, scenario_path} = BundledScenarios.fetch(@scenario_id)
    assert metadata["version"] == "1"
    assert :ok = Scenarios.validate_file(scenario_path)

    bootstrap =
      Scenarios.execute_yaml(
        """
        - user:
            name: "preview_admin"
            type: "author"
            email: "preview_admin@scenarios.invalid"
            given_name: "Preview"
            family_name: "Administrator"
            system_role: "system_admin"
        """,
        ownership: true
      )

    assert bootstrap.errors == []
    author = bootstrap.state.users["preview_admin"]
    previous_config = Application.get_env(:oli, :preview_qa_tools)

    Application.put_env(:oli, :preview_qa_tools, default_admin_email: author.email)
    on_exit(fn -> Application.put_env(:oli, :preview_qa_tools, previous_config) end)

    result = Scenarios.execute_file(scenario_path, author: author, ownership: true)

    assert result.errors == []
    assert length(result.verifications) == 11
    assert Enum.reject(result.verifications, & &1.passed) == []

    project = result.state.projects[@project_name]
    section = result.state.sections[@section_name]

    assert project.project.title == "Getting Started with OLI Torus"
    assert section.title == "Getting Started with OLI Torus"
    assert Publishing.get_latest_published_publication_by_slug(project.project.slug)

    assert result.state.scenario_results.bulk_create_enroll_users == %{
             created: 13,
             enrolled: 13,
             reused: 0
           }

    assert %{
             learners: 12,
             processed: 12,
             failed: 0,
             skipped_existing_history: 0,
             timing_mode: :fast,
             pages_visited: pages_visited,
             practice_submissions: practice_submissions,
             assessment_submissions: assessment_submissions,
             hints_requested: hints_requested,
             warnings: [],
             profiles: profiles
           } = result.state.scenario_results.simulate_progress

    assert pages_visited > 0
    assert practice_submissions > 0
    assert assessment_submissions > 0
    assert hints_requested > 0
    assert profiles["high_proficiency"].learners == 3
    assert profiles["steady_learner"].learners == 4
    assert profiles["persistent_learner"].learners == 3
    assert profiles["low_engagement"].learners == 2

    assert Repo.aggregate(
             from(enrollment in Enrollment, where: enrollment.section_id == ^section.id),
             :count
           ) == 13

    assert_course_pages(project)
    assert_authoring_curriculum_loadable(project)
    assert_activity_support(result, section)
    assert_progress_and_grades(result, section)
    assert_realistic_learner_names(result)
  end

  defp assert_course_pages(project) do
    page_expectations = %{
      "Welcome to OLI Torus" => {false, "Three objects to know"},
      "Organize Your Course" => {false, "Containers"},
      "Design Activities for Learning" => {false, "observable learning objective"},
      "Publish and Deliver Your Course" => {false, "stable snapshot"},
      "Getting Started Assessment" => {true, "same Torus evaluators"}
    }

    Enum.each(page_expectations, fn {title, {graded, expected_text}} ->
      revision = Map.fetch!(project.rev_by_title, title)

      page_text =
        revision.content["model"]
        |> Jason.encode!()
        |> String.replace("\\n", " ")
        |> String.replace(~r/\s+/, " ")

      assert revision.graded == graded
      assert page_text =~ expected_text
    end)
  end

  defp assert_authoring_curriculum_loadable(project) do
    children =
      ContainerEditor.list_all_container_children(project.root.revision, project.project)

    assert {:ok, %Rollup{}} = Rollup.new(children, project.project.slug)
  end

  defp assert_activity_support(result, section) do
    Enum.each(@activity_titles, fn title ->
      activity = Map.fetch!(result.state.activities, {@project_name, title})
      parts = get_in(activity.content, ["authoring", "parts"])

      assert is_list(parts) and parts != []

      Enum.each(parts, fn part ->
        assert length(part["hints"]) == 3
        assert part["responses"] != []

        Enum.each(part["responses"], fn response ->
          assert get_in(response, ["feedback", "content"]) != []
        end)
      end)
    end)

    evaluated_slugs =
      from(activity_attempt in ActivityAttempt,
        join: resource_attempt in ResourceAttempt,
        on: resource_attempt.id == activity_attempt.resource_attempt_id,
        join: resource_access in ResourceAccess,
        on: resource_access.id == resource_attempt.resource_access_id,
        join: revision in Revision,
        on: revision.id == activity_attempt.revision_id,
        join: registration in ActivityRegistration,
        on: registration.id == revision.activity_type_id,
        where:
          resource_access.section_id == ^section.id and
            activity_attempt.lifecycle_state == :evaluated,
        select: registration.slug,
        distinct: true
      )
      |> Repo.all()
      |> Enum.sort()

    assert evaluated_slugs ==
             Enum.sort(Oli.Scenarios.ProgressSimulation.supported_activity_types())

    assert Repo.exists?(
             from(resource_attempt in ResourceAttempt,
               join: resource_access in ResourceAccess,
               on: resource_access.id == resource_attempt.resource_access_id,
               join: revision in Revision,
               on: revision.id == resource_attempt.revision_id,
               where:
                 resource_access.section_id == ^section.id and revision.graded and
                   resource_attempt.attempt_number > 1
             )
           )
  end

  defp assert_progress_and_grades(result, section) do
    learner_ids =
      result.state.users
      |> Enum.filter(fn {reference, _user} ->
        String.starts_with?(reference, "simulated_learner_")
      end)
      |> Enum.map(fn {_reference, user} -> user.id end)

    assert length(learner_ids) == 12

    course_progress = Metrics.progress_for(section.id, learner_ids)

    assert map_size(course_progress) == 12
    assert Enum.all?(course_progress, fn {_user_id, progress} -> progress > 0.0 end)

    graded_accesses =
      Repo.all(
        from(resource_access in ResourceAccess,
          join: revision in Revision,
          on: revision.resource_id == resource_access.resource_id,
          where:
            resource_access.section_id == ^section.id and revision.graded and
              not is_nil(resource_access.score) and resource_access.out_of > 0.0,
          select: {resource_access.score, resource_access.out_of},
          distinct: true
        )
      )

    assert graded_accesses != []

    assert Enum.all?(graded_accesses, fn {score, out_of} ->
             score >= 0.0 and score <= out_of
           end)
  end

  defp assert_realistic_learner_names(result) do
    learners =
      Enum.filter(result.state.users, fn {reference, _user} ->
        String.starts_with?(reference, "simulated_learner_")
      end)

    assert length(learners) == 12

    Enum.each(learners, fn {reference, learner} ->
      index = String.replace_prefix(reference, "simulated_learner_", "")

      refute learner.given_name == "Learner"
      refute learner.family_name == index
      assert learner.name == "#{learner.given_name} #{learner.family_name}"
      assert learner.email == "simulated_learner_#{index}@example.edu"
    end)
  end
end
