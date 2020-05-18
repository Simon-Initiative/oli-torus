defmodule Oli.Delivery.Analytics.AnalyticsTest do

  use Oli.DataCase

  alias Oli.Analytics.ByActivity
  alias Oli.Snapshots.SnapshotSeeder

  defp to_path(path) do
    Path.expand(__DIR__) <> path
  end

  def seed_snapshots(context) do
    seeds = Seeder.base_project_with_resource2()
    |> Seeder.create_section()
    |> Seeder.add_activity(%{title: "Activity with with no attempts"}, :activity_no_attempts)
    |> SnapshotSeeder.setup_csv(context.path)

    Oli.Publishing.publish_project(seeds.project)
    {:ok, %{ seeds: seeds, results: ByActivity.query_against_project_id(seeds.project.id) }}
  end

  describe "number of attempts" do
    setup do: %{ path: to_path("/csv/number_of_attempts.csv") }
    setup :seed_snapshots

    test "activity with no attempts", %{ results: results, seeds: seeds } do
      # activities should still be queried even with no attempts against them
      activity_no_attempts = seeds.activity_no_attempts.revision
      activity_results = Enum.find(results, & &1.slice.id == activity_no_attempts.id)
      assert activity_results.number_of_attempts == nil
    end

    test "activity with attempts from 1 user", %{ results: results, seeds: seeds } do
      # test a couple activities with different users attempting them
      activity_user1 = seeds.activity_user1.revision
      activity1_results = Enum.find(results, & &1.slice.id == activity_user1.id)

      activity_user2 = seeds.activity_user2.revision
      activity2_results = Enum.find(results, & &1.slice.id == activity_user2.id)

      assert activity1_results.number_of_attempts == 3
      assert activity2_results.number_of_attempts == 2
    end

    test "activity with attempts from multiple users", %{ results: results, seeds: seeds } do
      # test an activity with multiple users attempting it
      activity_user1_user2 = seeds.activity_user1_user2.revision
      activity_results = Enum.find(results, & &1.slice.id == activity_user1_user2.id)

      assert activity_results.number_of_attempts == 4
    end

    test "multiple activities", %{ results: results, seeds: _seeds } do
      # query results should have 4 activities
      assert (length results) == 4
    end

  end

  # Relative difficulty = (# hints requested + # incorrect answers) / total attempts
  describe "relative difficulty" do
    setup do: %{ path: to_path("/csv/relative_difficulty.csv") }
    setup :seed_snapshots

    test "no incorrect answers and no hints", %{ results: results, seeds: seeds } do
      # attempts from two users:
      # 1 attempt from user1, 1 attempt from user2 = 2 attempts
      # 0 hints requested
      # 0 incorrect attempts
      # relative difficulty = (0 + 0) / 2 = 0

      activity_no_incorrect_no_hints = seeds.activity_no_incorrect_no_hints.revision
      activity_results = Enum.find(results, & &1.slice.id == activity_no_incorrect_no_hints.id)

      assert activity_results.relative_difficulty == 0

    end

    test "no incorrect answers and some hints", %{ results: results, seeds: seeds } do
      # attempts from two users:
      # 1 attempt from user1, 1 attempt from user2 = 2 attempts
      # 4 hints requested
      # 0 incorrect attempts
      # relative difficulty = (0 + 4) / 2 = 2

      activity_no_incorrect = seeds.activity_no_incorrect.revision
      activity_results = Enum.find(results, & &1.slice.id == activity_no_incorrect.id)

      assert activity_results.relative_difficulty == 2

    end

    test "no attempts", %{ results: results, seeds: seeds } do
      # activities should still be queried even with no attempts against them

      no_attempt_activity = seeds.activity_no_attempts.revision
      activity_results = Enum.find(results, & &1.slice.id == no_attempt_activity.id)
      assert activity_results.number_of_attempts == nil
    end

    test "incorrect answers and no hints", %{ results: results, seeds: seeds } do
      # this activity has attempts from two users:
      # 3 attempts from user1, 1 attempt from user2 = 4 attempts
      # 0 hints requested
      # 2 incorrect attempts
      # relative difficulty = (0 + 2) / 4 = .5
      activity_no_hints = seeds.activity_no_hints.revision
      activity_results = Enum.find(results, & &1.slice.id == activity_no_hints.id)

      assert activity_results.relative_difficulty == 0.5
    end

    test "one user - hints and incorrect answers", %{ results: results, seeds: seeds } do
      # this activity has attempts from one user:
      # 2 attempts from user1
      # 3 hints requested
      # 1 incorrect attempt
      # relative difficulty = (1 + 3) / 2 = 2
      activity_one_user_hints_and_incorrect = seeds.activity_one_user_hints_and_incorrect.revision
      activity_results = Enum.find(results, & &1.slice.id == activity_one_user_hints_and_incorrect.id)

      assert activity_results.relative_difficulty == 2
    end

    test "multiple users - hints and incorrect answers", %{ results: results, seeds: seeds } do
      # this activity has attempts from two users:
      # 4 attempts (2 from user1, 2 from user2)
      # 6 hints requested
      # 2 incorrect attempts (1 from user1, 1 from user2)
      # relative difficulty = (6 + 2) / 4 = 2

      activity_mult_users_hints_and_incorrect = seeds.activity_mult_users_hints_and_incorrect.revision
      activity_results = Enum.find(results, & &1.slice.id == activity_mult_users_hints_and_incorrect.id)

      assert activity_results.relative_difficulty == 2
    end
  end

  # eventually correct = sum(students with any correct response)
  #                     / sum(total students with attempts)
  describe "eventually correct" do
    setup do: %{ path: to_path("/csv/eventually_correct.csv") }
    setup :seed_snapshots

    # eventually correct = sum(students with any correct response)
    #                     / sum(total students with attempts)
    test "no correct responses", %{ results: results, seeds: seeds } do
      # this activity has attempts from two users:
      # 2 attempts from user1 (both incorrect)
      # 1 attempt from user2 (incorrect)
      # eventually_correct = 0 / 2 = 0
      activity_no_correct = seeds.activity_no_correct.revision
      activity_results = Enum.find(results, & &1.slice.id == activity_no_correct.id)

      assert activity_results.eventually_correct == 0
    end

    test "no attempts", %{ results: results, seeds: seeds } do
      # activities should still be queried even with no attempts against them

      no_attempt_activity = seeds.activity_no_attempts.revision
      activity_results = Enum.find(results, & &1.slice.id == no_attempt_activity.id)
      assert activity_results.eventually_correct == nil
    end

    test "all users get correct answer eventually", %{ results: results, seeds: seeds } do
      # this activity has 6 attempts from 2 users (3 each)
      # 2 correct attempts
      # eventually_correct = 2 / 2 = 1

      activity_mult_users_correct = seeds.activity_mult_users_correct.revision
      activity_results = Enum.find(results, & &1.slice.id == activity_mult_users_correct.id)
      assert activity_results.eventually_correct == 1
    end

    test "not all users get correct answer eventually", %{ results: results, seeds: seeds } do
      # this activity has 6 attempts from 2 users (3 each)
      # 1 correct attempts, so other user never gets it right

      activity_mult_users_correct_incorrect = seeds.activity_mult_users_correct_incorrect.revision
      activity_results = Enum.find(results, & &1.slice.id == activity_mult_users_correct_incorrect.id)
      assert activity_results.eventually_correct == 0.5
    end
  end

  # first attempt correct = sum(students with attempt 1 correct)
  #                         / sum(total students with attempts)
  describe "first try correct" do
    setup do: %{ path: to_path("/csv/first_try_correct.csv") }
    setup :seed_snapshots

    test "no correct responses", %{ results: results, seeds: seeds } do
      # this activity has attempts from two users:
      # 2 attempts from user1 (both incorrect)
      # 1 attempt from user2 (incorrect)
      # first_try_correct = 0 / 2 = 0
      activity_no_correct = seeds.activity_no_correct.revision
      activity_results = Enum.find(results, & &1.slice.id == activity_no_correct.id)

      assert activity_results.first_try_correct == 0
    end

    test "no attempts", %{ results: results, seeds: seeds } do
      # activities should still be queried even with no attempts against them

      no_attempt_activity = seeds.activity_no_attempts.revision
      activity_results = Enum.find(results, & &1.slice.id == no_attempt_activity.id)
      assert activity_results.first_try_correct == nil
    end

    test "all first correct", %{ results: results, seeds: seeds } do
      # this activity has attempts from two users:
      # both are correct on first attempt
      # first_try_correct = 2 / 2 = 1

      activity_all_correct = seeds.activity_all_correct.revision
      activity_results = Enum.find(results, & &1.slice.id == activity_all_correct.id)
      assert activity_results.first_try_correct == 1
    end

    test "some first correct", %{ results: results, seeds: seeds } do
      # this activity has attempts from two users:
      # one is correct on first attempt
      # first_try_correct = 1 / 2 = 0.5

      activity_some_correct = seeds.activity_some_correct.revision
      activity_results = Enum.find(results, & &1.slice.id == activity_some_correct.id)
      assert activity_results.first_try_correct == 0.5
    end
  end
end
