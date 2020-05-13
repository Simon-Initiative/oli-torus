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
      results = ByActivity.combined_query(seeds.project)
      {:ok, %{ seeds: seeds, results: results }}
    end

    test "activity with no attempts", %{ results: results, seeds: seeds } do
      # activities should still be queried even with no attempts agains them

      no_attempt_activity = seeds.activity_no_attempts.resource
      activity_results = Enum.find(results, & &1.activity.id == no_attempt_activity.id)
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
      |> Seeder.add_activity(%{title: "Activity with with no incorrect"}, :activity_no_incorrect)
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

      # |> Seeder.add_activity_snapshot(%{
      #   activity_tag: :activity_user2,
      #   objective_tag: :o1,
      #   user_tag: :user2,

      #   attempt_number: 1,
      #   correct: false,
      #   score: 0,
      #   out_of: 1,
      #   hints: 1
      # }, :ss5)
      # |> Seeder.add_activity_snapshot(%{
      #   activity_tag: :activity_user2,
      #   objective_tag: :o1,
      #   user_tag: :user2,

      #   attempt_number: 2,
      #   correct: true,
      #   score: 1,
      #   out_of: 1,
      #   hints: 0
      # }, :ss6)
      # |> Seeder.add_activity_snapshot(%{
      #   activity_tag: :activity_user1_user2,
      #   objective_tag: :o1,
      #   user_tag: :user1,

      #   attempt_number: 1,
      #   correct: false,
      #   score: 0,
      #   out_of: 1,
      #   hints: 0
      # }, :ss7)
      # |> Seeder.add_activity_snapshot(%{
      #   activity_tag: :activity_user1_user2,
      #   objective_tag: :o1,
      #   user_tag: :user1,

      #   attempt_number: 2,
      #   correct: false,
      #   score: 0,
      #   out_of: 1,
      #   hints: 1
      # }, :ss8)
      # |> Seeder.add_activity_snapshot(%{
      #   activity_tag: :activity_user1_user2,
      #   objective_tag: :o1,
      #   user_tag: :user1,

      #   attempt_number: 3,
      #   correct: true,
      #   score: 1,
      #   out_of: 1,
      #   hints: 0
      # }, :ss9)
      # |> Seeder.add_activity_snapshot(%{
      #   activity_tag: :activity_user1_user2,
      #   objective_tag: :o1,
      #   user_tag: :user2,

      #   attempt_number: 1,
      #   correct: true,
      #   score: 1,
      #   out_of: 1,
      #   hints: 1
      # }, :ss10)
      Oli.Publishing.publish_project(seeds.project)
      results = ByActivity.combined_query(seeds.project)

      {:ok, %{ seeds: seeds, results: results }}
    end

    test "no hints requested", %{ results: results, seeds: seeds } do
      # this activity has attempts from two users
      # 3 attempts from user1, 1 attempt from user2 = 4 attempts
      # 0 hints requested
      # 2 incorrect attempts
      # relative difficulty = (0 + 2) / 4 = .5
      IO.inspect(seeds)
      activity_no_hints = seeds.activity_no_hints.resource
      activity_results = Enum.find(results, & &1.activity.id == activity_no_hints.id)
      assert activity_results.relative_difficulty == 0.5

    end

    test "no incorrect answers" do

    end

    test "no attempts" do

    end

    test "one user - hints and incorrect answers" do

    end

    test "multiple users - hints and incorrect answers" do

    end
  end

  # eventually correct = sum(students with any correct response)
  #                     / sum(total students with attempts)
  describe "eventually correct" do
    @tag :skip
    test "no correct responses" do

    end

    @tag :skip
    test "no attempts" do

    end

    @tag :skip
    test "correct responses" do
      # all correct, mix of correct/incorrect
    end
  end

  # first attempt correct = sum(students with attempt 1 correct)
  #                         / sum(total students with attempts)
  describe "first attempt correct" do
    @tag :skip
    test "no correct responses" do

    end

    @tag :skip
    test "no attempts" do

    end

    @tag :skip
    test "correct responses" do
      # test various, make sure only attempt == 1 are counted
    end
  end

end
