defmodule Oli.Scenarios.ProgressSimulationScenarioTest do
  use Oli.DataCase

  alias Oli.Scenarios
  alias Oli.Scenarios.LearnerSession
  alias Oli.Scenarios.RuntimeOpts

  alias Oli.Activities.ActivityRegistration
  alias Oli.Delivery.Attempts.Core.{ActivityAttempt, PartAttempt, ResourceAccess, ResourceAttempt}
  alias Oli.Delivery.Metrics
  alias Oli.Resources.Revision

  @scenario_path "test/oli/scenarios/data/progress_simulation.scenario.yaml"
  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkin(Oli.Repo)
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Oli.Repo, isolation: :serializable)
    Ecto.Adapters.SQL.Sandbox.mode(Oli.Repo, {:shared, self()})
    :ok
  end

  test "simulates learner progress across practice and graded native activities" do
    assert :ok = Scenarios.validate_file(@scenario_path)

    runtime_opts = RuntimeOpts.build()
    author = Keyword.fetch!(runtime_opts, :author)
    previous_config = Application.get_env(:oli, :preview_qa_tools)

    Application.put_env(:oli, :preview_qa_tools, default_admin_email: author.email)

    on_exit(fn -> Application.put_env(:oli, :preview_qa_tools, previous_config) end)

    result = Scenarios.execute_file(@scenario_path, runtime_opts)

    assert result.errors == []

    assert result.state.scenario_results.bulk_create_enroll_users == %{
             created: 41,
             enrolled: 41,
             reused: 0
           }

    assert %{
             learners: 40,
             processed: 40,
             failed: 0,
             skipped_existing_history: 0,
             hints_requested: hints_requested,
             timing_mode: :fast,
             profiles: profiles,
             warnings_truncated: false
           } = result.state.scenario_results.simulate_progress

    assert hints_requested > 0

    assert profiles["high_proficiency"].learners == 10
    assert profiles["steady_learner"].learners == 15
    assert profiles["persistent_learner"].learners == 10
    assert profiles["low_engagement"].learners == 5

    learners =
      result.state.users
      |> Enum.filter(fn {reference, _user} ->
        String.starts_with?(reference, "simulated_learner_")
      end)

    assert length(learners) == 40

    Enum.each(learners, fn {reference, learner} ->
      refute learner.given_name == "Learner"

      index = String.replace_prefix(reference, "simulated_learner_", "")

      refute learner.family_name == index
      assert learner.email == "simulated_learner_#{index}@example.edu"
      assert learner.name == "#{learner.given_name} #{learner.family_name}"
    end)

    assert Enum.reject(result.verifications, & &1.passed) == []

    native_slugs =
      from(activity_attempt in ActivityAttempt,
        join: revision in Revision,
        on: revision.id == activity_attempt.revision_id,
        join: registration in ActivityRegistration,
        on: registration.id == revision.activity_type_id,
        where: activity_attempt.lifecycle_state == :evaluated,
        select: registration.slug,
        distinct: true
      )
      |> Repo.all()
      |> Enum.sort()

    assert native_slugs == Enum.sort(Oli.Scenarios.ProgressSimulation.supported_activity_types())

    assert Repo.exists?(
             from(activity_attempt in ActivityAttempt,
               where:
                 activity_attempt.lifecycle_state == :evaluated and
                   activity_attempt.attempt_number > 1
             )
           )

    assert Repo.exists?(
             from(part_attempt in PartAttempt,
               where: part_attempt.attempt_number > 1
             )
           )

    assert Repo.aggregate(ActivityAttempt, :max, :attempt_number) <= 4

    part_attempt_counts =
      Repo.all(
        from(part_attempt in PartAttempt,
          join: activity_attempt in ActivityAttempt,
          on: activity_attempt.id == part_attempt.activity_attempt_id,
          join: resource_attempt in ResourceAttempt,
          on: resource_attempt.id == activity_attempt.resource_attempt_id,
          join: resource_access in ResourceAccess,
          on: resource_access.id == resource_attempt.resource_access_id,
          join: revision in Revision,
          on: revision.id == activity_attempt.revision_id,
          group_by: [
            resource_access.user_id,
            activity_attempt.resource_attempt_id,
            activity_attempt.resource_id,
            part_attempt.part_id,
            revision.title
          ],
          select: {
            count(part_attempt.id),
            resource_access.user_id,
            activity_attempt.resource_attempt_id,
            activity_attempt.resource_id,
            part_attempt.part_id,
            revision.title,
            max(part_attempt.attempt_number),
            max(activity_attempt.attempt_number)
          }
        )
      )

    assert Enum.all?(part_attempt_counts, fn {count, _, _, _, _, _, _, _} -> count <= 4 end),
           inspect(
             Enum.filter(part_attempt_counts, fn {count, _, _, _, _, _, _, _} -> count > 4 end)
           )

    assert Repo.exists?(
             from(activity_attempt in ActivityAttempt,
               join: resource_attempt in ResourceAttempt,
               on: resource_attempt.id == activity_attempt.resource_attempt_id,
               join: page_revision in Revision,
               on: page_revision.id == resource_attempt.revision_id,
               where: not page_revision.graded,
               group_by: [activity_attempt.resource_id, activity_attempt.resource_attempt_id],
               having:
                 min(activity_attempt.attempt_number) == 1 and
                   max(activity_attempt.attempt_number) > 1
             )
           )

    evaluated_multi_input_titles =
      Repo.all(
        from(activity_attempt in ActivityAttempt,
          join: activity_revision in Revision,
          on: activity_revision.id == activity_attempt.revision_id,
          join: registration in ActivityRegistration,
          on: registration.id == activity_revision.activity_type_id,
          join: part_attempt in PartAttempt,
          on: part_attempt.activity_attempt_id == activity_attempt.id,
          where:
            registration.slug == "oli_multi_input" and part_attempt.lifecycle_state == :evaluated,
          select: activity_revision.title,
          distinct: true
        )
      )
      |> MapSet.new()

    assert evaluated_multi_input_titles ==
             MapSet.new(["Multi Input Question", "Multi Input Per Part Question"])

    assert Enum.all?(Repo.all(ResourceAccess), fn access ->
             is_number(access.progress) and access.progress >= 0.0 and access.progress <= 1.0
           end)

    section = result.state.sections["progress_simulation_section"]

    learner_ids =
      result.state.users
      |> Map.values()
      |> Enum.filter(&match?(%Oli.Accounts.User{sub: "scenario:simulated_learner_" <> _}, &1))
      |> Enum.map(& &1.id)

    course_progress = Metrics.progress_for(section.id, learner_ids)

    assert map_size(course_progress) == length(learner_ids)
    assert Enum.all?(course_progress, fn {_user_id, progress} -> progress > 0.0 end)

    completed_pages = Metrics.raw_completed_pages_for(section.id, learner_ids, nil)

    assert Enum.any?(learner_ids, fn user_id -> Map.get(completed_pages, user_id, 0) > 0 end)

    assessment_history_by_learner =
      Repo.all(
        from(resource_attempt in ResourceAttempt,
          join: resource_access in ResourceAccess,
          on: resource_access.id == resource_attempt.resource_access_id,
          join: revision in Revision,
          on: revision.id == resource_attempt.revision_id,
          where: revision.graded,
          order_by: [asc: resource_access.user_id, asc: resource_attempt.attempt_number],
          select: {
            resource_access.user_id,
            resource_attempt.attempt_number,
            resource_attempt.score,
            resource_attempt.out_of
          }
        )
      )
      |> Enum.group_by(fn {user_id, _attempt_number, _score, _out_of} -> user_id end)

    assert map_size(assessment_history_by_learner) >= 30

    assert Enum.any?(assessment_history_by_learner, fn {_user_id, attempts} ->
             length(attempts) > 1
           end)

    assert Enum.any?(assessment_history_by_learner, fn {_user_id, attempts} ->
             case attempts do
               [_single] ->
                 false

               [_ | _] ->
                 {_user_id, _number, first_score, first_out_of} = List.first(attempts)
                 {_user_id, _number, last_score, last_out_of} = List.last(attempts)

                 first_out_of > 0 and last_out_of > 0 and
                   last_score / last_out_of > first_score / first_out_of
             end
           end)
  end

  test "reuses one deterministic DataShop session ID for each learner simulation" do
    result = Scenarios.execute_file(@scenario_path, RuntimeOpts.build())
    assert result.errors == []

    section = result.state.sections["progress_simulation_section"]

    users_by_id =
      result.state.users
      |> Map.values()
      |> Enum.filter(&match?(%Oli.Accounts.User{}, &1))
      |> Map.new(&{&1.id, &1})

    sessions_by_learner =
      Repo.all(
        from(part_attempt in PartAttempt,
          join: activity_attempt in ActivityAttempt,
          on: activity_attempt.id == part_attempt.activity_attempt_id,
          join: resource_attempt in ResourceAttempt,
          on: resource_attempt.id == activity_attempt.resource_attempt_id,
          join: resource_access in ResourceAccess,
          on: resource_access.id == resource_attempt.resource_access_id,
          where: resource_access.section_id == ^section.id,
          select: {resource_access.user_id, part_attempt.datashop_session_id}
        )
      )
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))

    assert map_size(sessions_by_learner) > 0

    Enum.each(sessions_by_learner, fn {user_id, session_ids} ->
      user = Map.fetch!(users_by_id, user_id)
      identity = user.sub || user.email || "user:#{user.id}"

      assert Enum.uniq(session_ids) ==
               [LearnerSession.deterministic_id(42, identity, section.slug)]
    end)
  end
end
