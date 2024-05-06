defmodule Oli.Delivery.Analytics.AnalyticsTest do
  use Oli.DataCase

  alias Oli.Analytics.{ByActivity, ByObjective, ByPage}
  alias Oli.Snapshots.SnapshotSeeder
  alias Oli.Authoring.Clone

  defp to_path(path) do
    Path.expand(__DIR__) <> path
  end

  def seed_snapshots(context) do
    seeds =
      Seeder.base_project_with_resource2()
      |> Seeder.create_section()
      |> Seeder.add_activity(%{title: "Activity with with no attempts"}, :activity_no_attempts)
      |> Seeder.add_objective("not used in any seeds", :obj_not_used)
      |> Seeder.create_section_resources()
      |> SnapshotSeeder.setup_csv(context.path)

    Oli.Publishing.publish_project(seeds.project, "some changes", seeds.author.id)

    {:ok,
     %{
       seeds: seeds,
       activity_query: ByActivity.query_against_project_slug(seeds.project.slug, []),
       objective_query: ByObjective.query_against_project_slug(seeds.project.slug, []),
       page_query:
         ByPage.query_against_project_slug(
           seeds.project.slug,
           []
         ),
       page_with_sections_query:
         ByPage.query_against_project_slug(
           seeds.project.slug,
           [seeds[:section].id]
         ),
       activity_with_sections_query:
         ByPage.query_against_project_slug(
           seeds.project.slug,
           [seeds[:section].id]
         )
     }}
  end

  def duplicate_project(%{seeds: seeds} = seeded) do
    {:ok, duplicated_project} = Clone.clone_project(seeds.project.slug, seeds.author)
    {:ok, %{seeded | seeds: Map.put(seeded.seeds, :duplicated, duplicated_project)}}
  end

  describe "number of attempts" do
    setup do: %{path: to_path("/csv/number_of_attempts.csv")}
    setup :seed_snapshots

    @tag :skip
    test "with no attempts", %{
      activity_query: activity_query,
      page_query: page_query,
      objective_query: objective_query,
      seeds: seeds
    } do
      # activities/pages should still be queried even with no attempts against them
      activity_no_attempts = seeds.activity_no_attempts.revision
      activity_results = Enum.find(activity_query, &(&1.slice.id == activity_no_attempts.id))
      assert activity_results.number_of_attempts == nil
      page_no_attempts = seeds.revision1
      page_results = Enum.find(page_query, &(&1.slice.id == page_no_attempts.id))

      refute page_results[:number_of_attempts]

      objective_no_attempts = seeds.obj_not_used.revision
      obj_results = Enum.find(objective_query, &(&1.slice.id == objective_no_attempts.id))
      assert obj_results.number_of_attempts == nil
    end

    test "with attempts from 1 user", %{activity_query: activity_query, seeds: seeds} do
      # test a couple activities with different users attempting them
      activity_user1 = seeds.activity_user1.revision
      activity1_results = Enum.find(activity_query, &(&1.slice.id == activity_user1.id))

      activity_user2 = seeds.activity_user2.revision
      activity2_results = Enum.find(activity_query, &(&1.slice.id == activity_user2.id))

      assert activity1_results.number_of_attempts == 3
      assert activity2_results.number_of_attempts == 2
    end

    test "with attempts from multiple users", %{activity_query: activity_query, seeds: seeds} do
      # test an activity with multiple users attempting it
      activity_user1_user2 = seeds.activity_user1_user2.revision
      activity_results = Enum.find(activity_query, &(&1.slice.id == activity_user1_user2.id))

      assert activity_results.number_of_attempts == 4
    end

    test "multiple resouces", %{
      activity_query: activity_query,
      page_query: page_query,
      objective_query: objective_query
    } do
      assert length(activity_query) == 4
      assert length(objective_query) == 2
      assert length(page_query) == 4
    end
  end

  # Relative difficulty = (# hints requested + # incorrect answers) / total attempts
  describe "relative difficulty" do
    setup do: %{path: to_path("/csv/relative_difficulty.csv")}
    setup :seed_snapshots

    test "no incorrect answers and no hints", %{activity_query: activity_query, seeds: seeds} do
      # attempts from two users:
      # 1 attempt from user1, 1 attempt from user2 = 2 attempts
      # 0 hints requested
      # 0 incorrect attempts
      # relative difficulty = (0 + 0) / 2 = 0

      activity_no_incorrect_no_hints = seeds.activity_no_incorrect_no_hints.revision

      activity_results =
        Enum.find(activity_query, &(&1.slice.id == activity_no_incorrect_no_hints.id))

      assert activity_results.relative_difficulty == 0
    end

    test "no incorrect answers and some hints", %{activity_query: activity_query, seeds: seeds} do
      # attempts from two users:
      # 1 attempt from user1, 1 attempt from user2 = 2 attempts
      # 4 hints requested
      # 0 incorrect attempts
      # relative difficulty = (0 + 4) / 2 = 2

      activity_no_incorrect = seeds.activity_no_incorrect.revision
      activity_results = Enum.find(activity_query, &(&1.slice.id == activity_no_incorrect.id))

      assert activity_results.relative_difficulty == 2
    end

    test "no attempts", %{activity_query: activity_query, seeds: seeds} do
      # activities should still be queried even with no attempts against them

      no_attempt_activity = seeds.activity_no_attempts.revision
      activity_results = Enum.find(activity_query, &(&1.slice.id == no_attempt_activity.id))
      assert activity_results.number_of_attempts == nil
    end

    test "incorrect answers and no hints", %{activity_query: activity_query, seeds: seeds} do
      # this activity has attempts from two users:
      # 3 attempts from user1, 1 attempt from user2 = 4 attempts
      # 0 hints requested
      # 2 incorrect attempts
      # relative difficulty = (0 + 2) / 4 = .5
      activity_no_hints = seeds.activity_no_hints.revision
      activity_results = Enum.find(activity_query, &(&1.slice.id == activity_no_hints.id))

      assert activity_results.relative_difficulty == 0.5
    end

    test "one user - hints and incorrect answers", %{activity_query: activity_query, seeds: seeds} do
      # this activity has attempts from one user:
      # 2 attempts from user1
      # 3 hints requested
      # 1 incorrect attempt
      # relative difficulty = (1 + 3) / 2 = 2
      activity_one_user_hints_and_incorrect = seeds.activity_one_user_hints_and_incorrect.revision

      activity_results =
        Enum.find(activity_query, &(&1.slice.id == activity_one_user_hints_and_incorrect.id))

      assert activity_results.relative_difficulty == 2
    end

    test "multiple users - hints and incorrect answers", %{
      activity_query: activity_query,
      seeds: seeds
    } do
      # this activity has attempts from two users:
      # 4 attempts (2 from user1, 2 from user2)
      # 6 hints requested
      # 2 incorrect attempts (1 from user1, 1 from user2)
      # relative difficulty = (6 + 2) / 4 = 2

      activity_mult_users_hints_and_incorrect =
        seeds.activity_mult_users_hints_and_incorrect.revision

      activity_results =
        Enum.find(activity_query, &(&1.slice.id == activity_mult_users_hints_and_incorrect.id))

      assert activity_results.relative_difficulty == 2
    end
  end

  # eventually correct = sum(students with any correct response)
  #                     / sum(total students with attempts)
  describe "eventually correct" do
    setup do: %{path: to_path("/csv/eventually_correct.csv")}
    setup :seed_snapshots

    # eventually correct = sum(students with any correct response)
    #                     / sum(total students with attempts)
    test "no correct responses", %{activity_query: activity_query, seeds: seeds} do
      # this activity has attempts from two users:
      # 2 attempts from user1 (both incorrect)
      # 1 attempt from user2 (incorrect)
      # eventually_correct = 0 / 2 = 0
      activity_no_correct = seeds.activity_no_correct.revision
      activity_results = Enum.find(activity_query, &(&1.slice.id == activity_no_correct.id))

      assert activity_results.eventually_correct == 0
    end

    test "no attempts", %{activity_query: activity_query, seeds: seeds} do
      # activities should still be queried even with no attempts against them

      no_attempt_activity = seeds.activity_no_attempts.revision
      activity_results = Enum.find(activity_query, &(&1.slice.id == no_attempt_activity.id))
      assert activity_results.eventually_correct == nil
    end

    test "all users get correct answer eventually", %{
      activity_query: activity_query,
      seeds: seeds
    } do
      # this activity has 6 attempts from 2 users (3 each)
      # 2 correct attempts
      # eventually_correct = 2 / 2 = 1

      activity_mult_users_correct = seeds.activity_mult_users_correct.revision

      activity_results =
        Enum.find(activity_query, &(&1.slice.id == activity_mult_users_correct.id))

      assert activity_results.eventually_correct == 1
    end

    test "not all users get correct answer eventually", %{
      activity_query: activity_query,
      seeds: seeds
    } do
      # this activity has 6 attempts from 2 users (3 each)
      # 1 correct attempts, so other user never gets it right

      activity_mult_users_correct_incorrect = seeds.activity_mult_users_correct_incorrect.revision

      activity_results =
        Enum.find(activity_query, &(&1.slice.id == activity_mult_users_correct_incorrect.id))

      assert activity_results.eventually_correct == 0.5
    end
  end

  # first attempt correct = sum(students with attempt 1 correct)
  #                         / sum(total students with attempts)
  describe "first try correct" do
    setup do: %{path: to_path("/csv/first_try_correct.csv")}
    setup :seed_snapshots

    test "no correct responses", %{activity_query: activity_query, seeds: seeds} do
      # this activity has attempts from two users:
      # 2 attempts from user1 (both incorrect)
      # 1 attempt from user2 (incorrect)
      # first_try_correct = 0 / 2 = 0
      activity_no_correct = seeds.activity_no_correct.revision
      activity_results = Enum.find(activity_query, &(&1.slice.id == activity_no_correct.id))

      assert activity_results.first_try_correct == 0
    end

    test "no attempts", %{activity_query: activity_query, seeds: seeds} do
      # activities should still be queried even with no attempts against them

      no_attempt_activity = seeds.activity_no_attempts.revision
      activity_results = Enum.find(activity_query, &(&1.slice.id == no_attempt_activity.id))
      assert activity_results.first_try_correct == nil
    end

    test "all first correct", %{activity_query: activity_query, seeds: seeds} do
      # this activity has attempts from two users:
      # both are correct on first attempt
      # first_try_correct = 2 / 2 = 1

      activity_all_correct = seeds.activity_all_correct.revision
      activity_results = Enum.find(activity_query, &(&1.slice.id == activity_all_correct.id))
      assert activity_results.first_try_correct == 1
    end

    test "some first correct", %{activity_query: activity_query, seeds: seeds} do
      # this activity has attempts from two users:
      # one is correct on first attempt
      # first_try_correct = 1 / 2 = 0.5

      activity_some_correct = seeds.activity_some_correct.revision
      activity_results = Enum.find(activity_query, &(&1.slice.id == activity_some_correct.id))
      assert activity_results.first_try_correct == 0.5
    end
  end

  describe "duplicating a project with analytics" do
    setup do: %{path: to_path("/csv/first_try_correct.csv")}
    setup :seed_snapshots
    setup :duplicate_project

    test "a duplicated course should not have analytics from a parent course", %{
      activity_query: activity_query,
      objective_query: objective_query,
      page_query: page_query,
      seeds: %{duplicated: duplicated}
    } do
      # Parent course should still have analytics after duplicating project
      assert Enum.count(objective_query) == 2
      assert Enum.count(activity_query) == 4
      assert Enum.count(page_query) == 4

      # Duplicated course should not have analytics

      insights_from_struct = fn struct ->
        [
          struct.eventually_correct,
          struct.first_try_correct,
          struct.number_of_attempts,
          struct.relative_difficulty
        ]
      end

      # 2 objectives with no analytics
      obj_insights = ByObjective.query_against_project_slug(duplicated.slug, [])
      assert Enum.count(obj_insights) == 2

      assert Enum.all?(obj_insights, fn obj ->
               Enum.all?(insights_from_struct.(obj), &is_nil(&1))
             end)

      # 4 activities with no analytics
      activity_insights = ByActivity.query_against_project_slug(duplicated.slug, [])
      assert Enum.count(activity_insights) == 4

      assert Enum.all?(activity_insights, fn obj ->
               Enum.all?(insights_from_struct.(obj), &is_nil(&1))
             end)

      # 3 pages with no analytics
      page_insights = ByPage.query_against_project_slug(duplicated.slug, [])
      assert Enum.count(page_insights) == 1

      assert Enum.all?(page_insights, fn obj ->
               Enum.all?(insights_from_struct.(obj), &is_nil(&1))
             end)
    end
  end
end
