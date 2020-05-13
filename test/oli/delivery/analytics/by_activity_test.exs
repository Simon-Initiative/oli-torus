defmodule Oli.Delivery.Analytics.ByAnalyticsTest do

  use Oli.DataCase

  alias Oli.Delivery.Attempts.Snapshot
  alias Oli.Analytics.ByActivity

  describe "number of attempts" do
    setup do
      seeds = Seeder.base_project_with_resource2()
      |> Seeder.create_section()
      |> Seeder.add_objective("objective one", :o1)
      |> Seeder.add_activity(%{}, :activity_no_attempts)
      |> Seeder.add_activity(%{}, :activity_user2)
      |> Seeder.add_activity(%{}, :activity_user1)
      |> Seeder.add_activity(%{}, :activity_user1_user2)
      |> Seeder.add_user(%{}, :user1)
      |> Seeder.add_user(%{}, :user2)
      |> Seeder.add_activity_snapshot(%{
        activity_tag: :activity_user2,
        objective_tag: :o1,
        user_tag: :user1,

        attempt_number: 1,
        correct: true,
        score: 1,
        out_of: 1,
        hints: 1
      }, :ss1)

      {:ok, seeds}
    end

    test "activity with no attempts", map do
      IO.inspect ByActivity.activity_num_attempts_rel_difficulty(), label: "Activity num attempts"
      # map.make_snapshot(activity)
    end

    @tag :skip
    test "activity with attempts from 1 user" do

    end

    @tag :skip
    test "activity with attempts from multiple users" do

    end

    @tag :skip
    test "multiple activities", map do
      assert true
    end

  end

  # Relative difficulty = (# hints requested + # incorrect answers) / total attempts
  describe "relative difficulty" do
    @tag :skip
    test "no hints requested" do

    end

    @tag :skip
    test "no incorrect answers" do

    end

    @tag :skip
    test "no attempts" do

    end

    @tag :skip
    test "one user - hints and incorrect answers" do

    end

    @tag :skip
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
