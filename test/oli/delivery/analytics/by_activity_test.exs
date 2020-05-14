defmodule Oli.Delivery.Analytics.ByAnalyticsTest do

  use Oli.DataCase

  alias Oli.Delivery.Attempts.Snapshot
  alias Oli.Analytics.ByActivity

  describe "number of attempts" do
    setup do
      seeds = Seeder.base_project_with_resource2()
      |> Seeder.create_section()
      |> Seeder.add_objective("objective one", :o1)
      |> Seeder.add_activity(%{title: "Activity with no attempts"}, :activity_no_attempts)
      |> Seeder.add_activity(%{title: "Activity with attempts from user 1"}, :activity_user1)
      |> Seeder.add_activity(%{title: "Activity with attempts from user 2"}, :activity_user2)
      |> Seeder.add_activity(%{title: "Activity with attempts from both users"}, :activity_user1_user2)
      |> Seeder.add_user(%{}, :user1)
      |> Seeder.add_user(%{}, :user2)
      |> Seeder.add_activity_snapshot(%{
        activity_tag: :activity_user1,
        objective_tag: :o1,
        user_tag: :user1,

        attempt_number: 1,
        correct: false,
        score: 0,
        out_of: 1,
        hints: 0
      }, :ss1)
      |> Seeder.add_activity_snapshot(%{
        activity_tag: :activity_user1,
        objective_tag: :o1,
        user_tag: :user1,

        attempt_number: 2,
        correct: false,
        score: 0,
        out_of: 1,
        hints: 1
      }, :ss1)
      |> Seeder.add_activity_snapshot(%{
        activity_tag: :activity_user1,
        objective_tag: :o1,
        user_tag: :user1,

        attempt_number: 3,
        correct: true,
        score: 1,
        out_of: 1,
        hints: 0
      }, :ss3)
      |> Seeder.add_activity_snapshot(%{
        activity_tag: :activity_user2,
        objective_tag: :o1,
        user_tag: :user2,

        attempt_number: 1,
        correct: false,
        score: 0,
        out_of: 1,
        hints: 1
      }, :ss4)
      |> Seeder.add_activity_snapshot(%{
        activity_tag: :activity_user2,
        objective_tag: :o1,
        user_tag: :user2,

        attempt_number: 2,
        correct: true,
        score: 1,
        out_of: 1,
        hints: 0
      }, :ss5)
      |> Seeder.add_activity_snapshot(%{
        activity_tag: :activity_user1_user2,
        objective_tag: :o1,
        user_tag: :user1,

        attempt_number: 1,
        correct: false,
        score: 0,
        out_of: 1,
        hints: 0
      }, :ss6)
      |> Seeder.add_activity_snapshot(%{
        activity_tag: :activity_user1_user2,
        objective_tag: :o1,
        user_tag: :user1,

        attempt_number: 2,
        correct: false,
        score: 0,
        out_of: 1,
        hints: 1
      }, :ss7)
      |> Seeder.add_activity_snapshot(%{
        activity_tag: :activity_user1_user2,
        objective_tag: :o1,
        user_tag: :user1,

        attempt_number: 3,
        correct: true,
        score: 1,
        out_of: 1,
        hints: 0
      }, :ss8)
      |> Seeder.add_activity_snapshot(%{
        activity_tag: :activity_user1_user2,
        objective_tag: :o1,
        user_tag: :user2,

        attempt_number: 1,
        correct: true,
        score: 1,
        out_of: 1,
        hints: 1
      }, :ss9)
      Oli.Publishing.publish_project(seeds.project)
      results = ByActivity.query_against_project_id(seeds.project.id)
      {:ok, %{ seeds: seeds, results: results }}
    end

    test "activity with no attempts", %{ results: results, seeds: seeds } do
      # activities should still be queried even with no attempts against them

      activity_no_attempts = seeds.activity_no_attempts.resource
      activity_results = Enum.find(results, & &1.activity.id == activity_no_attempts.id)
      assert activity_results.number_of_attempts == nil
    end

    test "activity with attempts from 1 user", %{ results: results, seeds: seeds } do
      # test a couple activities with different users attempting them
      activity_user1 = seeds.activity_user1.resource
      activity1_results = Enum.find(results, & &1.activity.id == activity_user1.id)

      activity_user2 = seeds.activity_user2.resource
      activity2_results = Enum.find(results, & &1.activity.id == activity_user2.id)

      assert activity1_results.number_of_attempts == 3
      assert activity2_results.number_of_attempts == 2
    end

    test "activity with attempts from multiple users", %{ results: results, seeds: seeds } do
      # test an activity with multiple users attempting it
      activity_user1_user2 = seeds.activity_user1_user2.resource
      activity_results = Enum.find(results, & &1.activity.id == activity_user1_user2.id)

      assert activity_results.number_of_attempts == 4
    end

    test "multiple activities", %{ results: results, seeds: seeds } do
      # query results should have 4 activities
      assert (length results) == 4
    end

  end

  # Relative difficulty = (# hints requested + # incorrect answers) / total attempts
  describe "relative difficulty" do

    setup do
      seeds = Seeder.base_project_with_resource2()
      |> Seeder.create_section()
      |> Seeder.add_objective("objective one", :o1)
      |> Seeder.add_activity(%{title: "Activity with no hints"}, :activity_no_hints)
      |> Seeder.add_activity(%{title: "Activity with with no incorrect and no hints"}, :activity_no_incorrect_no_hints)
      |> Seeder.add_activity(%{title: "Activity with with no incorrect but with hints"}, :activity_no_incorrect)
      |> Seeder.add_activity(%{title: "Activity with with no attempts"}, :activity_no_attempts)
      |> Seeder.add_activity(%{title: "Activity with hints/correct attempts from one user"}, :activity_one_user_hints_and_incorrect)
      |> Seeder.add_activity(%{title: "Activity with hints/correct attempts from both users"}, :activity_mult_users_hints_and_incorrect)
      |> Seeder.add_user(%{}, :user1)
      |> Seeder.add_user(%{}, :user2)
      |> Seeder.add_activity_snapshot(%{
        activity_tag: :activity_no_hints,
        objective_tag: :o1,
        user_tag: :user1,

        attempt_number: 1,
        correct: false,
        score: 0,
        out_of: 1,
        hints: 0
      }, :ss1)
      |> Seeder.add_activity_snapshot(%{
        activity_tag: :activity_no_hints,
        objective_tag: :o1,
        user_tag: :user1,

        attempt_number: 2,
        correct: false,
        score: 0,
        out_of: 1,
        hints: 0
      }, :ss1)
      |> Seeder.add_activity_snapshot(%{
        activity_tag: :activity_no_hints,
        objective_tag: :o1,
        user_tag: :user1,

        attempt_number: 3,
        correct: true,
        score: 1,
        out_of: 1,
        hints: 0
      }, :ss3)
      |> Seeder.add_activity_snapshot(%{
        activity_tag: :activity_no_hints,
        objective_tag: :o1,
        user_tag: :user2,

        attempt_number: 1,
        correct: true,
        score: 1,
        out_of: 1,
        hints: 0
      }, :ss4)

      |> Seeder.add_activity_snapshot(%{
        activity_tag: :activity_no_incorrect_no_hints,
        objective_tag: :o1,
        user_tag: :user1,

        attempt_number: 1,
        correct: true,
        score: 1,
        out_of: 1,
        hints: 0
      }, :ss5)
      |> Seeder.add_activity_snapshot(%{
        activity_tag: :activity_no_incorrect_no_hints,
        objective_tag: :o1,
        user_tag: :user2,

        attempt_number: 1,
        correct: true,
        score: 1,
        out_of: 1,
        hints: 0
      }, :ss6)

      |> Seeder.add_activity_snapshot(%{
        activity_tag: :activity_no_incorrect,
        objective_tag: :o1,
        user_tag: :user1,

        attempt_number: 1,
        correct: true,
        score: 1,
        out_of: 1,
        hints: 1
      }, :ss7)
      |> Seeder.add_activity_snapshot(%{
        activity_tag: :activity_no_incorrect,
        objective_tag: :o1,
        user_tag: :user2,

        attempt_number: 1,
        correct: true,
        score: 1,
        out_of: 1,
        hints: 3
      }, :ss8)

      |> Seeder.add_activity_snapshot(%{
        activity_tag: :activity_one_user_hints_and_incorrect,
        objective_tag: :o1,
        user_tag: :user1,

        attempt_number: 1,
        correct: false,
        score: 0,
        out_of: 1,
        hints: 2
      }, :ss9)
      |> Seeder.add_activity_snapshot(%{
        activity_tag: :activity_one_user_hints_and_incorrect,
        objective_tag: :o1,
        user_tag: :user1,

        attempt_number: 2,
        correct: true,
        score: 1,
        out_of: 1,
        hints: 1
      }, :ss10)

      |> Seeder.add_activity_snapshot(%{
        activity_tag: :activity_mult_users_hints_and_incorrect,
        objective_tag: :o1,
        user_tag: :user1,

        attempt_number: 1,
        correct: false,
        score: 0,
        out_of: 1,
        hints: 2
      }, :ss11)
      |> Seeder.add_activity_snapshot(%{
        activity_tag: :activity_mult_users_hints_and_incorrect,
        objective_tag: :o1,
        user_tag: :user1,

        attempt_number: 2,
        correct: true,
        score: 1,
        out_of: 1,
        hints: 1
      }, :ss12)
      |> Seeder.add_activity_snapshot(%{
        activity_tag: :activity_mult_users_hints_and_incorrect,
        objective_tag: :o1,
        user_tag: :user2,

        attempt_number: 1,
        correct: false,
        score: 0,
        out_of: 1,
        hints: 3
      }, :ss13)
      |> Seeder.add_activity_snapshot(%{
        activity_tag: :activity_mult_users_hints_and_incorrect,
        objective_tag: :o1,
        user_tag: :user2,

        attempt_number: 2,
        correct: true,
        score: 1,
        out_of: 1,
        hints: 0
      }, :ss14)

      Oli.Publishing.publish_project(seeds.project)
      results = ByActivity.query_against_project_id(seeds.project.id)

      {:ok, %{ seeds: seeds, results: results }}
    end

    test "no incorrect answers and no hints", %{ results: results, seeds: seeds } do
      # attempts from two users:
      # 1 attempt from user1, 1 attempt from user2 = 2 attempts
      # 0 hints requested
      # 0 incorrect attempts
      # relative difficulty = (0 + 0) / 2 = 0

      activity_no_incorrect_no_hints = seeds.activity_no_incorrect_no_hints.resource
      activity_results = Enum.find(results, & &1.activity.id == activity_no_incorrect_no_hints.id)

      assert activity_results.relative_difficulty == 0

    end

    test "no incorrect answers and some hints", %{ results: results, seeds: seeds } do
      # attempts from two users:
      # 1 attempt from user1, 1 attempt from user2 = 2 attempts
      # 4 hints requested
      # 0 incorrect attempts
      # relative difficulty = (0 + 4) / 2 = 2

      activity_no_incorrect = seeds.activity_no_incorrect.resource
      activity_results = Enum.find(results, & &1.activity.id == activity_no_incorrect.id)

      assert activity_results.relative_difficulty == 2

    end

    test "no attempts", %{ results: results, seeds: seeds } do
      # activities should still be queried even with no attempts against them

      no_attempt_activity = seeds.activity_no_attempts.resource
      activity_results = Enum.find(results, & &1.activity.id == no_attempt_activity.id)
      assert activity_results.number_of_attempts == nil
    end

    test "incorrect answers and no hints", %{ results: results, seeds: seeds } do
      # this activity has attempts from two users:
      # 3 attempts from user1, 1 attempt from user2 = 4 attempts
      # 0 hints requested
      # 2 incorrect attempts
      # relative difficulty = (0 + 2) / 4 = .5
      activity_no_hints = seeds.activity_no_hints.resource
      activity_results = Enum.find(results, & &1.activity.id == activity_no_hints.id)

      assert activity_results.relative_difficulty == 0.5
    end

    test "one user - hints and incorrect answers", %{ results: results, seeds: seeds } do
      # this activity has attempts from one user:
      # 2 attempts from user1
      # 3 hints requested
      # 1 incorrect attempt
      # relative difficulty = (1 + 3) / 2 = 2
      activity_one_user_hints_and_incorrect = seeds.activity_one_user_hints_and_incorrect.resource
      activity_results = Enum.find(results, & &1.activity.id == activity_one_user_hints_and_incorrect.id)

      assert activity_results.relative_difficulty == 2
    end

    test "multiple users - hints and incorrect answers", %{ results: results, seeds: seeds } do
      # this activity has attempts from two users:
      # 4 attempts (2 from user1, 2 from user2)
      # 6 hints requested
      # 2 incorrect attempts (1 from user1, 1 from user2)
      # relative difficulty = (6 + 2) / 4 = 2

      activity_mult_users_hints_and_incorrect = seeds.activity_mult_users_hints_and_incorrect.resource
      activity_results = Enum.find(results, & &1.activity.id == activity_mult_users_hints_and_incorrect.id)

      assert activity_results.relative_difficulty == 2
    end
  end

  # eventually correct = sum(students with any correct response)
  #                     / sum(total students with attempts)
  describe "eventually correct" do

    setup do
      seeds = Seeder.base_project_with_resource2()
      |> Seeder.create_section()
      |> Seeder.add_objective("objective one", :o1)
      |> Seeder.add_activity(%{title: "Activity with no correct answers"}, :activity_no_correct)
      |> Seeder.add_activity(%{title: "Activity with with no attempts"}, :activity_no_attempts)
      |> Seeder.add_activity(%{title: "Activity with correct attempts from both users"}, :activity_mult_users_correct)
      |> Seeder.add_activity(%{title: "Activity with correct attempts from only one user"}, :activity_mult_users_correct_incorrect)
      |> Seeder.add_user(%{}, :user1)
      |> Seeder.add_user(%{}, :user2)
      |> Seeder.add_activity_snapshot(%{
        activity_tag: :activity_no_correct,
        objective_tag: :o1,
        user_tag: :user1,

        attempt_number: 1,
        correct: false,
        score: 0,
        out_of: 1,
        hints: 0
      }, :ss1)
      |> Seeder.add_activity_snapshot(%{
        activity_tag: :activity_no_correct,
        objective_tag: :o1,
        user_tag: :user1,

        attempt_number: 2,
        correct: false,
        score: 0,
        out_of: 1,
        hints: 0
      }, :ss2)
      |> Seeder.add_activity_snapshot(%{
        activity_tag: :activity_no_correct,
        objective_tag: :o1,
        user_tag: :user2,

        attempt_number: 1,
        correct: false,
        score: 0,
        out_of: 1,
        hints: 0
      }, :ss3)

      |> Seeder.add_activity_snapshot(%{
        activity_tag: :activity_mult_users_correct,
        objective_tag: :o1,
        user_tag: :user1,

        attempt_number: 1,
        correct: false,
        score: 0,
        out_of: 1,
        hints: 0
      }, :ss4)
      |> Seeder.add_activity_snapshot(%{
        activity_tag: :activity_mult_users_correct,
        objective_tag: :o1,
        user_tag: :user1,

        attempt_number: 2,
        correct: false,
        score: 0,
        out_of: 1,
        hints: 0
      }, :ss5)
      |> Seeder.add_activity_snapshot(%{
        activity_tag: :activity_mult_users_correct,
        objective_tag: :o1,
        user_tag: :user1,

        attempt_number: 3,
        correct: true,
        score: 1,
        out_of: 1,
        hints: 0
      }, :ss6)
      |> Seeder.add_activity_snapshot(%{
        activity_tag: :activity_mult_users_correct,
        objective_tag: :o1,
        user_tag: :user2,

        attempt_number: 1,
        correct: false,
        score: 0,
        out_of: 1,
        hints: 0
      }, :ss7)
      |> Seeder.add_activity_snapshot(%{
        activity_tag: :activity_mult_users_correct,
        objective_tag: :o1,
        user_tag: :user2,

        attempt_number: 2,
        correct: false,
        score: 0,
        out_of: 1,
        hints: 0
      }, :ss8)
      |> Seeder.add_activity_snapshot(%{
        activity_tag: :activity_mult_users_correct,
        objective_tag: :o1,
        user_tag: :user2,

        attempt_number: 3,
        correct: true,
        score: 1,
        out_of: 1,
        hints: 0
      }, :ss9)

      |> Seeder.add_activity_snapshot(%{
        activity_tag: :activity_mult_users_correct_incorrect,
        objective_tag: :o1,
        user_tag: :user1,

        attempt_number: 1,
        correct: false,
        score: 0,
        out_of: 1,
        hints: 0
      }, :ss10)
      |> Seeder.add_activity_snapshot(%{
        activity_tag: :activity_mult_users_correct_incorrect,
        objective_tag: :o1,
        user_tag: :user1,

        attempt_number: 2,
        correct: false,
        score: 0,
        out_of: 1,
        hints: 0
      }, :ss11)
      |> Seeder.add_activity_snapshot(%{
        activity_tag: :activity_mult_users_correct_incorrect,
        objective_tag: :o1,
        user_tag: :user1,

        attempt_number: 3,
        correct: false,
        score: 0,
        out_of: 1,
        hints: 0
      }, :ss12)
      |> Seeder.add_activity_snapshot(%{
        activity_tag: :activity_mult_users_correct_incorrect,
        objective_tag: :o1,
        user_tag: :user2,

        attempt_number: 1,
        correct: false,
        score: 0,
        out_of: 1,
        hints: 0
      }, :ss13)
      |> Seeder.add_activity_snapshot(%{
        activity_tag: :activity_mult_users_correct_incorrect,
        objective_tag: :o1,
        user_tag: :user2,

        attempt_number: 2,
        correct: false,
        score: 0,
        out_of: 1,
        hints: 0
      }, :ss14)
      |> Seeder.add_activity_snapshot(%{
        activity_tag: :activity_mult_users_correct_incorrect,
        objective_tag: :o1,
        user_tag: :user2,

        attempt_number: 3,
        correct: true,
        score: 1,
        out_of: 1,
        hints: 0
      }, :ss15)

      Oli.Publishing.publish_project(seeds.project)
      results = IO.inspect ByActivity.query_against_project_id(seeds.project.id)

      {:ok, %{ seeds: seeds, results: results }}
    end

    # eventually correct = sum(students with any correct response)
    #                     / sum(total students with attempts)
    test "no correct responses", %{ results: results, seeds: seeds } do
      # this activity has attempts from two users:
      # 2 attempts from user1 (both incorrect)
      # 1 attempt from user2 (incorrect)
      # eventually_correct = 0 / 2 = 0
      activity_no_correct = seeds.activity_no_correct.resource
      activity_results = Enum.find(results, & &1.activity.id == activity_no_correct.id)

      assert activity_results.eventually_correct == 0
    end

    test "no attempts", %{ results: results, seeds: seeds } do
      # activities should still be queried even with no attempts against them

      no_attempt_activity = seeds.activity_no_attempts.resource
      activity_results = Enum.find(results, & &1.activity.id == no_attempt_activity.id)
      assert activity_results.eventually_correct == nil
    end

    test "all users get correct answer eventually", %{ results: results, seeds: seeds } do
      # this activity has 6 attempts from 2 users (3 each)
      # 2 correct attempts
      # eventually_correct = 2 / 2 = 1

      activity_mult_users_correct = seeds.activity_mult_users_correct.resource
      activity_results = Enum.find(results, & &1.activity.id == activity_mult_users_correct.id)
      assert activity_results.eventually_correct == 1
    end

    test "not all users get correct answer eventually", %{ results: results, seeds: seeds } do
      # this activity has 6 attempts from 2 users (3 each)
      # 1 correct attempts, so other user never gets it right

      activity_mult_users_correct_incorrect = seeds.activity_mult_users_correct_incorrect.resource
      activity_results = Enum.find(results, & &1.activity.id == activity_mult_users_correct_incorrect.id)
      assert activity_results.eventually_correct == 0.5
    end
  end

  # first attempt correct = sum(students with attempt 1 correct)
  #                         / sum(total students with attempts)
  describe "first attempt correct" do

    setup do
      seeds = Seeder.base_project_with_resource2()
      |> Seeder.create_section()
      |> Seeder.add_objective("objective one", :o1)
      |> Seeder.add_activity(%{title: "Activity with no correct answers"}, :activity_no_correct)
      |> Seeder.add_activity(%{title: "Activity with with no attempts"}, :activity_no_attempts)
      |> Seeder.add_activity(%{title: "Activity with first correct attempts from both users"}, :activity_all_correct)
      |> Seeder.add_activity(%{title: "Activity with first correct attempts from only one user"}, :activity_some_correct)
      |> Seeder.add_user(%{}, :user1)
      |> Seeder.add_user(%{}, :user2)
      |> Seeder.add_activity_snapshot(%{
        activity_tag: :activity_no_correct,
        objective_tag: :o1,
        user_tag: :user1,

        attempt_number: 1,
        correct: false,
        score: 0,
        out_of: 1,
        hints: 0
      }, :ss1)
      |> Seeder.add_activity_snapshot(%{
        activity_tag: :activity_no_correct,
        objective_tag: :o1,
        user_tag: :user1,

        attempt_number: 2,
        correct: false,
        score: 0,
        out_of: 1,
        hints: 0
      }, :ss2)
      |> Seeder.add_activity_snapshot(%{
        activity_tag: :activity_no_correct,
        objective_tag: :o1,
        user_tag: :user2,

        attempt_number: 1,
        correct: false,
        score: 0,
        out_of: 1,
        hints: 0
      }, :ss3)

      |> Seeder.add_activity_snapshot(%{
        activity_tag: :activity_all_correct,
        objective_tag: :o1,
        user_tag: :user1,

        attempt_number: 1,
        correct: true,
        score: 1,
        out_of: 1,
        hints: 0
      }, :ss4)
      |> Seeder.add_activity_snapshot(%{
        activity_tag: :activity_all_correct,
        objective_tag: :o1,
        user_tag: :user1,

        attempt_number: 2,
        correct: false,
        score: 0,
        out_of: 1,
        hints: 0
      }, :ss5)
      |> Seeder.add_activity_snapshot(%{
        activity_tag: :activity_all_correct,
        objective_tag: :o1,
        user_tag: :user2,

        attempt_number: 1,
        correct: true,
        score: 1,
        out_of: 1,
        hints: 0
      }, :ss6)
      |> Seeder.add_activity_snapshot(%{
        activity_tag: :activity_all_correct,
        objective_tag: :o1,
        user_tag: :user2,

        attempt_number: 2,
        correct: false,
        score: 0,
        out_of: 1,
        hints: 0
      }, :ss7)

      |> Seeder.add_activity_snapshot(%{
        activity_tag: :activity_some_correct,
        objective_tag: :o1,
        user_tag: :user1,

        attempt_number: 1,
        correct: false,
        score: 0,
        out_of: 1,
        hints: 0
      }, :ss10)
      |> Seeder.add_activity_snapshot(%{
        activity_tag: :activity_some_correct,
        objective_tag: :o1,
        user_tag: :user1,

        attempt_number: 2,
        correct: false,
        score: 0,
        out_of: 1,
        hints: 0
      }, :ss11)
      |> Seeder.add_activity_snapshot(%{
        activity_tag: :activity_some_correct,
        objective_tag: :o1,
        user_tag: :user1,

        attempt_number: 3,
        correct: true,
        score: 1,
        out_of: 1,
        hints: 0
      }, :ss12)
      |> Seeder.add_activity_snapshot(%{
        activity_tag: :activity_some_correct,
        objective_tag: :o1,
        user_tag: :user2,

        attempt_number: 1,
        correct: true,
        score: 1,
        out_of: 1,
        hints: 0
      }, :ss13)
      |> Seeder.add_activity_snapshot(%{
        activity_tag: :activity_some_correct,
        objective_tag: :o1,
        user_tag: :user2,

        attempt_number: 2,
        correct: false,
        score: 0,
        out_of: 1,
        hints: 0
      }, :ss14)
      |> Seeder.add_activity_snapshot(%{
        activity_tag: :activity_some_correct,
        objective_tag: :o1,
        user_tag: :user2,

        attempt_number: 3,
        correct: true,
        score: 1,
        out_of: 1,
        hints: 0
      }, :ss15)

      Oli.Publishing.publish_project(seeds.project)
      results = IO.inspect ByActivity.query_against_project_id(seeds.project.id)

      {:ok, %{ seeds: seeds, results: results }}
    end

    test "no correct responses", %{ results: results, seeds: seeds } do
      # this activity has attempts from two users:
      # 2 attempts from user1 (both incorrect)
      # 1 attempt from user2 (incorrect)
      # first_try_correct = 0 / 2 = 0
      activity_no_correct = seeds.activity_no_correct.resource
      activity_results = Enum.find(results, & &1.activity.id == activity_no_correct.id)

      assert activity_results.first_try_correct == 0
    end

    test "no attempts", %{ results: results, seeds: seeds } do
      # activities should still be queried even with no attempts against them

      no_attempt_activity = seeds.activity_no_attempts.resource
      activity_results = Enum.find(results, & &1.activity.id == no_attempt_activity.id)
      assert activity_results.first_try_correct == nil
    end

    test "all first correct", %{ results: results, seeds: seeds } do
      # this activity has attempts from two users:
      # both are correct on first attempt
      # first_try_correct = 2 / 2 = 1

      activity_all_correct = seeds.activity_all_correct.resource
      activity_results = Enum.find(results, & &1.activity.id == activity_all_correct.id)
      assert activity_results.first_try_correct == 1
    end

    test "some first correct", %{ results: results, seeds: seeds } do
      # this activity has attempts from two users:
      # one is correct on first attempt
      # first_try_correct = 1 / 2 = 0.5

      activity_some_correct = seeds.activity_some_correct.resource
      activity_results = Enum.find(results, & &1.activity.id == activity_some_correct.id)
      assert activity_results.first_try_correct == 0.5
    end
  end

end
