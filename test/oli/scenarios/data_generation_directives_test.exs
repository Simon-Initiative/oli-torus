defmodule Oli.Scenarios.DataGenerationDirectivesTest do
  use Oli.DataCase

  alias Oli.Scenarios
  alias Oli.Scenarios.DirectiveParser
  alias Oli.Scenarios.DirectiveTypes.{BulkCreateEnrollUsersDirective, SimulateProgressDirective}

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
        pct_correct: 0.75
        assessment_attempts:
          - pct_correct: 0.4
          - pct_correct: 0.7
          - pct_correct: 0.9
        batch_size: 5
        max_concurrency: 2
        timeout_ms: 10000
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
               pct_correct: 0.75,
               assessment_attempts: [
                 %{pct_correct: 0.4},
                 %{pct_correct: 0.7},
                 %{pct_correct: 0.9}
               ],
               batch_size: 5,
               max_concurrency: 2,
               timeout_ms: 10_000
             }
           ] = DirectiveParser.parse_yaml!(yaml)
  end

  test "parser rejects unbounded or empty generation requests" do
    invalid = [
      "- bulk_create_enroll_users: {section: demo, learners: 0}",
      "- bulk_create_enroll_users: {section: demo, learners: 10001}",
      "- bulk_create_enroll_users: {section: demo, prefix: abcdefghijklmnopqrstuvwxyzabcdefghijklmno, learners: 1}",
      "- simulate_progress: {section: demo, pct_correct: 1.1}",
      "- simulate_progress: {section: demo, assessment_attempts: []}",
      "- simulate_progress: {section: demo, assessment_attempts: [{pct_correct: 1.1}]}",
      "- simulate_progress: {section: demo, assessment_attempts: [{pct_correct: 0.5, extra: true}]}",
      "- simulate_progress: {section: demo, max_concurrency: 17}"
    ]

    Enum.each(invalid, fn yaml ->
      assert {:error, _} = Scenarios.validate_yaml(yaml)
      assert_raise RuntimeError, fn -> DirectiveParser.parse_yaml!(yaml) end
    end)
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
               email: "collision_learner_1@scenarios.invalid",
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

  test "simulate_progress handles an explicitly empty learner set without loading per-user state" do
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
        users: []
        seed: 7
    """

    result = yaml |> DirectiveParser.parse_yaml!() |> Oli.Scenarios.Engine.execute()

    assert result.errors == []

    assert result.state.scenario_results.simulate_progress == %{
             learners: 0,
             completed: 0,
             failed: 0,
             warnings: [],
             warnings_truncated: false
           }
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
