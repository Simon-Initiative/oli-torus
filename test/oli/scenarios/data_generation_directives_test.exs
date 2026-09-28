defmodule Oli.Scenarios.DataGenerationDirectivesTest do
  use Oli.DataCase

  alias Oli.Scenarios
  alias Oli.Scenarios.DirectiveParser
  alias Oli.Scenarios.Engine

  alias Oli.Scenarios.DirectiveTypes.{
    BulkCreateEnrollUsersDirective,
    SimulateProgressDirective,
    UseDirective
  }

  test "schema and parser accept bounded data generation directives" do
    yaml = """
    - bulk_create_enroll_users:
        section: demo
        prefix: qa
        instructors: 2
        learners: 5
    - simulate_progress:
        section: demo
        users: [qa_learner_1]
        seed: 42
        profile: steady_learner
    """

    assert :ok = Scenarios.validate_yaml(yaml)

    assert [
             %BulkCreateEnrollUsersDirective{
               section: "demo",
               prefix: "qa",
               instructors: 2,
               learners: 5
             },
             %SimulateProgressDirective{
               section: "demo",
               users: ["qa_learner_1"],
               seed: 42,
               profile: "steady_learner",
               cohorts: nil,
               timing: :fast
             }
           ] = DirectiveParser.parse_yaml!(yaml)
  end

  test "schema and parser accept simple count-based cohorts" do
    yaml = """
    - simulate_progress:
        section: demo
        seed: 17
        timing: {mode: paced}
        cohorts:
          - profile: high_proficiency
            count: 2
          - profile: low_engagement
            count: 3
    """

    assert :ok = Scenarios.validate_yaml(yaml)

    assert [
             %SimulateProgressDirective{
               profile: nil,
               timing: :paced,
               cohorts: [
                 %{profile: "high_proficiency", count: 2},
                 %{profile: "low_engagement", count: 3}
               ]
             }
           ] = DirectiveParser.parse_yaml!(yaml)
  end

  test "parser rejects unbounded or empty generation requests" do
    invalid = [
      "- bulk_create_enroll_users: {section: demo, learners: 0}",
      "- bulk_create_enroll_users: {section: demo, learners: 10001}",
      "- bulk_create_enroll_users: {section: demo, prefix: abcdefghijklmnopqrstuvwxyzabcdefghijklmno, learners: 1}",
      "- simulate_progress: {section: demo}",
      "- simulate_progress: {section: demo, profile: unknown}",
      "- simulate_progress: {section: demo, profile: steady_learner, cohorts: [{profile: steady_learner, count: 1}]}",
      "- simulate_progress: {section: demo, profile: steady_learner, users: []}",
      "- simulate_progress: {section: demo, cohorts: []}",
      "- simulate_progress: {section: demo, profile: steady_learner, max_concurrency: 17}",
      "- simulate_progress: {section: demo, profile: steady_learner, overrides: {initial_correctness: [0.8, 0.9]}}"
    ]

    Enum.each(invalid, fn yaml ->
      assert {:error, _} = Scenarios.validate_yaml(yaml)
      assert_raise RuntimeError, fn -> DirectiveParser.parse_yaml!(yaml) end
    end)
  end

  test "schema and parser reject malformed profile and cohort contracts" do
    structurally_invalid = [
      "- simulate_progress: {section: demo, profile: steady_learner, profile_version: 2}",
      "- simulate_progress: {section: demo, profile: steady_learner, overrides: {unknown: 1}}",
      "- simulate_progress: {section: demo, profile: steady_learner, users: [learner, learner]}",
      "- simulate_progress: {section: demo, profile: steady_learner, cohorts: [{profile: low_engagement, count: 1}]}",
      "- simulate_progress: {section: demo, cohorts: [{profile: steady_learner}]}",
      "- simulate_progress: {section: demo, cohorts: [{profile: steady_learner, users: [learner]}]}",
      "- simulate_progress: {section: demo, overrides: {initial_correctness: [0.5, 0.5]}}"
    ]

    Enum.each(structurally_invalid, fn yaml ->
      assert {:error, _reason} = Scenarios.validate_yaml(yaml)
      assert_raise RuntimeError, fn -> DirectiveParser.parse_yaml!(yaml) end
    end)
  end

  test "schema and parser both reject more than 100 explicit learners" do
    users = Enum.map_join(1..101, ", ", &"learner_#{&1}")
    yaml = "- simulate_progress: {section: demo, profile: steady_learner, users: [#{users}]}"

    assert {:error, _reason} = Scenarios.validate_yaml(yaml)
    assert_raise RuntimeError, fn -> DirectiveParser.parse_yaml!(yaml) end
  end

  test "schema and parser agree that one explicit role count may be zero" do
    yaml = "- bulk_create_enroll_users: {section: demo, instructors: 0, learners: 1}"

    assert :ok = Scenarios.validate_yaml(yaml)

    assert [%BulkCreateEnrollUsersDirective{instructors: 0, learners: 1}] =
             DirectiveParser.parse_yaml!(yaml)
  end

  test "schema and parser use the same character bound for multibyte prefixes" do
    accepted =
      "- bulk_create_enroll_users: {section: demo, prefix: '#{String.duplicate("😀", 40)}', learners: 1}"

    rejected =
      "- bulk_create_enroll_users: {section: demo, prefix: '#{String.duplicate("😀", 41)}', learners: 1}"

    assert :ok = Scenarios.validate_yaml(accepted)
    assert [%BulkCreateEnrollUsersDirective{}] = DirectiveParser.parse_yaml!(accepted)
    assert {:error, _} = Scenarios.validate_yaml(rejected)
    assert_raise RuntimeError, fn -> DirectiveParser.parse_yaml!(rejected) end
  end

  test "bulk_create_enroll_users refuses to reuse a colliding synthetic email" do
    assert {:ok, _user} =
             Oli.Accounts.create_guest_user(%{
               guest: false,
               email: "collision_learner_1@example.edu",
               given_name: "Existing",
               family_name: "User",
               sub: "different-subject"
             })

    yaml = """
    - project:
        name: collision_project
        title: Collision Project
        root:
          children:
            - page: Welcome
    - section:
        name: collision_section
        title: Collision Section
        from: collision_project
    - bulk_create_enroll_users:
        section: collision_section
        prefix: collision
        learners: 1
    """

    result = yaml |> DirectiveParser.parse_yaml!() |> Oli.Scenarios.Engine.execute()

    assert [{%BulkCreateEnrollUsersDirective{}, message}] = result.errors
    assert message =~ "identity_collision"
  end

  test "simulate_progress handles a section with no enrolled learners" do
    yaml = """
    - project:
        name: progress_project
        title: Progress Project
        root:
          children:
            - page: Welcome
    - section:
        name: progress_section
        title: Progress Section
        from: progress_project
    - simulate_progress:
        section: progress_section
        profile: steady_learner
        seed: 7
    """

    result = yaml |> DirectiveParser.parse_yaml!() |> Oli.Scenarios.Engine.execute()

    assert result.errors == []

    assert %{learners: 0, processed: 0, course_complete: 0, failed: 0, warnings: []} =
             result.state.scenario_results.simulate_progress
  end

  test "learners with existing section history are skipped and reported" do
    setup =
      """
      - project:
          name: skip_history_project
          title: Skip History Project
          root:
            children:
              - page: Welcome
      - section: {name: skip_history_section, title: Skip History Section, from: skip_history_project}
      - user: {name: learner_1, type: student}
      - user: {name: learner_2, type: student}
      - enroll: {user: learner_1, section: skip_history_section}
      - enroll: {user: learner_2, section: skip_history_section}
      """
      |> DirectiveParser.parse_yaml!()
      |> Engine.execute()

    [directive] =
      DirectiveParser.parse_yaml!("""
      - simulate_progress:
          section: skip_history_section
          users: [learner_1]
          profile: steady_learner
          seed: 7
      """)

    first = Engine.execute([directive], state: setup.state)
    assert first.errors == []

    [both_learners] =
      DirectiveParser.parse_yaml!("""
      - simulate_progress:
          section: skip_history_section
          users: [learner_1, learner_2]
          profile: steady_learner
          seed: 7
      """)

    second = Engine.execute([both_learners], state: first.state)
    assert second.errors == []

    assert %{learners: 2, processed: 1, skipped_existing_history: 1} =
             second.state.scenario_results.simulate_progress
  end

  test "simulate_progress retains its structured result when execution fails" do
    setup =
      """
      - project:
          name: failed_progress_project
          title: Failed Progress Project
          root:
            children:
              - page: Welcome
      - section: {name: failed_progress_section, title: Failed Progress Section, from: failed_progress_project}
      - user: {name: learner, type: student}
      """
      |> DirectiveParser.parse_yaml!()
      |> Engine.execute()

    [directive] =
      DirectiveParser.parse_yaml!("""
      - simulate_progress:
          section: failed_progress_section
          users: [learner]
          profile: steady_learner
      """)

    result = Engine.execute([directive], state: setup.state)

    assert [{^directive, message}] = result.errors
    assert message =~ "users_not_enrolled_as_learners"

    assert %{learners: 0, processed: 0, failed: 0} =
             result.state.scenario_results.simulate_progress
  end

  test "a failing simulate_progress inside use retains its result and restores include context" do
    setup =
      """
      - project:
          name: included_failure_project
          title: Included Failure Project
          root:
            children:
              - page: Welcome
      - section: {name: included_failure_section, title: Included Failure Section, from: included_failure_project}
      - user: {name: learner, type: student}
      """
      |> DirectiveParser.parse_yaml!()
      |> Engine.execute()

    temp_dir =
      Path.join(
        System.tmp_dir!(),
        "simulate-progress-use-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(temp_dir)
    on_exit(fn -> File.rm_rf(temp_dir) end)

    File.write!(Path.join(temp_dir, "child.yaml"), """
    - simulate_progress:
        section: included_failure_section
        users: [learner]
        profile: steady_learner
    """)

    original_stack = ["parent.yaml"]

    state =
      setup.state
      |> Map.put(:current_dir, temp_dir)
      |> Map.put(:include_stack, original_stack)

    directive = %UseDirective{file: "child.yaml"}
    result = Engine.execute([directive], state: state)

    assert [{^directive, message}] = result.errors
    assert message =~ "users_not_enrolled_as_learners"
    assert result.state.current_dir == temp_dir
    assert result.state.include_stack == original_stack

    assert %{learners: 0, processed: 0, failed: 0} =
             result.state.scenario_results.simulate_progress
  end

  test "removed progress controls fail before mutation with migration guidance" do
    for selection <- ["", "profile: steady_learner, "],
        attribute <- ["pct_correct: 0.8", "assessment_attempts: [{pct_correct: 0.8}]"] do
      yaml = "- simulate_progress: {section: demo, #{selection}#{attribute}}"

      assert {:error, _} = Scenarios.validate_yaml(yaml)

      assert_raise RuntimeError,
                   ~r/no longer accepts.*fixed profile.*lower-level learner directives/,
                   fn ->
                     DirectiveParser.parse_yaml!(yaml)
                   end
    end
  end

  test "cohort counts must match the selected learner population" do
    setup =
      """
      - project:
          name: cohort_validation_project
          title: Cohort Validation Project
          root:
            children:
              - page: Welcome
      - section:
          name: cohort_validation_section
          title: Cohort Validation Section
          from: cohort_validation_project
      - user: {name: learner_1, type: student}
      - user: {name: learner_2, type: student}
      - enroll: {user: learner_1, section: cohort_validation_section}
      - enroll: {user: learner_2, section: cohort_validation_section}
      """
      |> DirectiveParser.parse_yaml!()
      |> Engine.execute()

    assert setup.errors == []

    [directive] =
      DirectiveParser.parse_yaml!("""
      - simulate_progress:
          section: cohort_validation_section
          cohorts:
            - {profile: steady_learner, count: 1}
      """)

    result = Engine.execute([directive], state: setup.state)

    assert [{^directive, message}] = result.errors
    assert message =~ "invalid_or_incomplete_cohort_assignment"

    assert %{learners: 0, processed: 0, failed: 0} =
             result.state.scenario_results.simulate_progress
  end

  test "progress response selection chooses the correctness bucket before an answer" do
    responses = [
      %{"rule" => "input like {correct}", "score" => 1},
      %{"rule" => "input like {wrong-1}", "score" => 0},
      %{"rule" => "input like {wrong-2}", "score" => 0},
      %{"rule" => "input like {wrong-3}", "score" => 0}
    ]

    choices =
      for user_id <- 1..1_000 do
        Oli.Scenarios.ProgressSimulation.select_response(responses, 0.8, {42, user_id, 7, "1"})
      end

    assert Enum.count(choices, &(&1 == "correct")) in 750..850

    assert Oli.Scenarios.ProgressSimulation.select_response(responses, 0.8, {42, 1, 7, "1"}) ==
             Oli.Scenarios.ProgressSimulation.select_response(responses, 0.8, {42, 1, 7, "1"})

    refute Enum.map(1..20, fn seed ->
             Oli.Scenarios.ProgressSimulation.select_response(responses, 0.8, {seed, 1, 7, "1"})
           end)
           |> Enum.uniq()
           |> then(&(length(&1) == 1))
  end

  test "the separate Stagehand source path is retired" do
    refute File.exists?("lib/oli/utils/stagehand.ex")
    assert Path.wildcard("lib/oli/utils/stagehand/**/*.ex") == []

    refute Enum.any?(Path.wildcard("lib/**/*.ex"), fn path ->
             path |> File.read!() |> String.contains?("Oli.Utils.Stagehand")
           end)
  end
end
