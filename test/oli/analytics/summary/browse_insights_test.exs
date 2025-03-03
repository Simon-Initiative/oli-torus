defmodule Oli.Analytics.Summary.BrowseInsightsTest do
  use Oli.DataCase

  alias Oli.Analytics.Summary.BrowseInsights

  describe "browse insights query, section_id = -1" do
    setup do
      map =
        Seeder.base_project_with_resource2()
        |> Seeder.create_section()
        |> Seeder.add_objective("A", :o1)
        |> Seeder.add_objective("B", :o2)
        |> Seeder.add_objective("C", :o3)
        |> Seeder.add_activity(%{title: "A", content: %{}}, :a1)
        |> Seeder.add_activity(%{title: "B", content: %{}}, :a2)
        |> Seeder.add_activity(%{title: "C", content: %{}}, :a3)
        |> Seeder.add_user(%{}, :user1)
        |> Seeder.add_user(%{}, :user2)

      map = Seeder.publish_project(map)

      a1 = map.a1
      a2 = map.a2
      a3 = map.a3
      o1 = map.o1
      o2 = map.o2
      o3 = map.o3
      page1 = map.page1
      page2 = map.page2

      insert_summaries(map.project.id, [
        [a1.resource.id, a1.revision.resource_type_id, -1, -1, "part1", 1, 2, 0, 1, 1],
        [a1.resource.id, a1.revision.resource_type_id, -1, -1, "part2", 2, 3, 0, 1, 1],
        [a2.resource.id, a2.revision.resource_type_id, -1, -1, "part1", 3, 4, 0, 1, 1],
        [a2.resource.id, a2.revision.resource_type_id, -1, -1, "part2", 4, 5, 0, 1, 1],
        [a3.resource.id, a3.revision.resource_type_id, -1, -1, "part1", 5, 6, 0, 1, 1],
        [a3.resource.id, a3.revision.resource_type_id, -1, -1, "part2", 6, 7, 0, 1, 1],
        [o1.resource.id, o1.revision.resource_type_id, -1, -1, nil, 1, 2, 1, 1, 1],
        [o2.resource.id, o2.revision.resource_type_id, -1, -1, nil, 1, 3, 1, 1, 1],
        [o3.resource.id, o3.revision.resource_type_id, -1, -1, nil, 1, 4, 1, 1, 1],
        [page1.id, 1, -1, -1, nil, 1, 2, 1, 1, 1],
        [page2.id, 1, -1, -1, nil, 1, 2, 1, 1, 1]
      ])

      map
    end

    test "browsing activities, basic query operation, paging", %{
      project: project
    } do
      activity_type_id = Oli.Resources.ResourceType.get_id_by_type("activity")

      results =
        BrowseInsights.browse_insights(
          %Oli.Repo.Paging{limit: 4, offset: 0},
          %Oli.Repo.Sorting{direction: :asc, field: :title},
          %Oli.Analytics.Summary.BrowseInsightsOptions{
            project_id: project.id,
            section_ids: [],
            resource_type_id: activity_type_id
          }
        )

      assert length(results) == 4
      assert Enum.at(results, 0).total_count == 6
      assert Enum.at(results, 0).title == "A"

      results =
        BrowseInsights.browse_insights(
          %Oli.Repo.Paging{limit: 4, offset: 4},
          %Oli.Repo.Sorting{direction: :asc, field: :title},
          %Oli.Analytics.Summary.BrowseInsightsOptions{
            project_id: project.id,
            section_ids: [],
            resource_type_id: activity_type_id
          }
        )

      assert length(results) == 2
      assert Enum.at(results, 0).total_count == 6
    end

    test "sorting", %{
      project: project
    } do
      objective_type_id = Oli.Resources.ResourceType.get_id_by_type("objective")

      results =
        BrowseInsights.browse_insights(
          %Oli.Repo.Paging{limit: 4, offset: 0},
          %Oli.Repo.Sorting{direction: :asc, field: :title},
          %Oli.Analytics.Summary.BrowseInsightsOptions{
            project_id: project.id,
            section_ids: [],
            resource_type_id: objective_type_id
          }
        )

      assert length(results) == 3
      assert Enum.at(results, 0).total_count == 3
      assert Enum.at(results, 0).title == "A"
      assert Enum.at(results, 1).title == "B"
      assert Enum.at(results, 2).title == "C"

      results =
        BrowseInsights.browse_insights(
          %Oli.Repo.Paging{limit: 4, offset: 0},
          %Oli.Repo.Sorting{direction: :desc, field: :title},
          %Oli.Analytics.Summary.BrowseInsightsOptions{
            project_id: project.id,
            section_ids: [],
            resource_type_id: objective_type_id
          }
        )

      assert length(results) == 3
      assert Enum.at(results, 0).total_count == 3
      assert Enum.at(results, 0).title == "C"
      assert Enum.at(results, 1).title == "B"
      assert Enum.at(results, 2).title == "A"

      results =
        BrowseInsights.browse_insights(
          %Oli.Repo.Paging{limit: 4, offset: 0},
          %Oli.Repo.Sorting{direction: :desc, field: :relative_difficulty},
          %Oli.Analytics.Summary.BrowseInsightsOptions{
            project_id: project.id,
            section_ids: [],
            resource_type_id: objective_type_id
          }
        )

      assert length(results) == 3
      assert Enum.at(results, 0).total_count == 3
      assert Enum.at(results, 0).title == "C"
      assert Enum.at(results, 1).title == "B"
      assert Enum.at(results, 2).title == "A"

      results =
        BrowseInsights.browse_insights(
          %Oli.Repo.Paging{limit: 4, offset: 0},
          %Oli.Repo.Sorting{direction: :asc, field: :relative_difficulty},
          %Oli.Analytics.Summary.BrowseInsightsOptions{
            project_id: project.id,
            section_ids: [],
            resource_type_id: objective_type_id
          }
        )

      assert length(results) == 3
      assert Enum.at(results, 0).total_count == 3
      assert Enum.at(results, 0).title == "A"
      assert Enum.at(results, 1).title == "B"
      assert Enum.at(results, 2).title == "C"
    end
  end

  describe "browse insights query, specific section_ids" do
    setup do
      map =
        Seeder.base_project_with_resource2()
        |> Seeder.create_section()
        |> Seeder.add_objective("A", :o1)
        |> Seeder.add_objective("B", :o2)
        |> Seeder.add_objective("C", :o3)
        |> Seeder.add_activity(%{title: "A", content: %{}}, :a1)
        |> Seeder.add_activity(%{title: "B", content: %{}}, :a2)
        |> Seeder.add_activity(%{title: "C", content: %{}}, :a3)
        |> Seeder.add_user(%{}, :user1)
        |> Seeder.add_user(%{}, :user2)

      map = Seeder.publish_project(map)

      a1 = map.a1
      a2 = map.a2
      a3 = map.a3
      o1 = map.o1
      o2 = map.o2
      o3 = map.o3
      page1 = map.page1
      page2 = map.page2

      insert_summaries(map.project.id, [
        [a1.resource.id, a1.revision.resource_type_id, -1, 1, "part1", 1, 2, 0, 1, 1],
        [a1.resource.id, a1.revision.resource_type_id, -1, 1, "part2", 2, 3, 0, 1, 1],
        [a2.resource.id, a2.revision.resource_type_id, -1, 1, "part1", 3, 4, 0, 1, 1],
        [a2.resource.id, a2.revision.resource_type_id, -1, 1, "part2", 4, 5, 0, 1, 1],
        [a3.resource.id, a3.revision.resource_type_id, -1, 1, "part1", 5, 6, 0, 1, 1],
        [a3.resource.id, a3.revision.resource_type_id, -1, 1, "part2", 6, 7, 0, 1, 1],
        [o1.resource.id, o1.revision.resource_type_id, -1, 1, nil, 1, 2, 1, 1, 1],
        [o2.resource.id, o2.revision.resource_type_id, -1, 1, nil, 1, 3, 1, 1, 1],
        [o3.resource.id, o3.revision.resource_type_id, -1, 1, nil, 1, 4, 1, 1, 1],
        [page1.id, 1, -1, 1, nil, 1, 2, 1, 1, 1],
        [page2.id, 1, -1, 1, nil, 1, 2, 1, 1, 1],
        [a1.resource.id, a1.revision.resource_type_id, -1, 2, "part1", 1, 2, 0, 1, 3],
        [a1.resource.id, a1.revision.resource_type_id, -1, 2, "part2", 2, 3, 0, 1, 1],
        [a2.resource.id, a2.revision.resource_type_id, -1, 2, "part1", 3, 4, 0, 1, 1],
        [a2.resource.id, a2.revision.resource_type_id, -1, 2, "part2", 4, 5, 0, 1, 1],
        [a3.resource.id, a3.revision.resource_type_id, -1, 2, "part1", 5, 6, 0, 1, 1],
        [a3.resource.id, a3.revision.resource_type_id, -1, 2, "part2", 6, 7, 0, 1, 1],
        [o1.resource.id, o1.revision.resource_type_id, -1, 2, nil, 1, 2, 1, 1, 1],
        [o2.resource.id, o2.revision.resource_type_id, -1, 2, nil, 1, 3, 1, 1, 1],
        [o3.resource.id, o3.revision.resource_type_id, -1, 2, nil, 1, 4, 1, 1, 1],
        [page1.id, 1, -1, 2, nil, 1, 2, 1, 1, 1],
        [page2.id, 1, -1, 2, nil, 1, 2, 1, 1, 1]
      ])

      map
    end

    test "browsing activities, basic query operation, paging", %{
      project: project
    } do
      activity_type_id = Oli.Resources.ResourceType.get_id_by_type("activity")

      results =
        BrowseInsights.browse_insights(
          %Oli.Repo.Paging{limit: 4, offset: 0},
          %Oli.Repo.Sorting{direction: :asc, field: :title},
          %Oli.Analytics.Summary.BrowseInsightsOptions{
            project_id: project.id,
            section_ids: [1],
            resource_type_id: activity_type_id
          }
        )

      assert length(results) == 4
      assert Enum.at(results, 0).total_count == 6
      assert Enum.at(results, 0).title == "A"
      assert Enum.at(results, 0).first_attempt_correct == 1.0

      results =
        BrowseInsights.browse_insights(
          %Oli.Repo.Paging{limit: 4, offset: 4},
          %Oli.Repo.Sorting{direction: :asc, field: :title},
          %Oli.Analytics.Summary.BrowseInsightsOptions{
            project_id: project.id,
            section_ids: [1],
            resource_type_id: activity_type_id
          }
        )

      assert length(results) == 2
      assert Enum.at(results, 0).total_count == 6

      results =
        BrowseInsights.browse_insights(
          %Oli.Repo.Paging{limit: 4, offset: 0},
          %Oli.Repo.Sorting{direction: :asc, field: :title},
          %Oli.Analytics.Summary.BrowseInsightsOptions{
            project_id: project.id,
            section_ids: [1, 2],
            resource_type_id: activity_type_id
          }
        )

      assert length(results) == 4
      assert Enum.at(results, 0).total_count == 6
      assert Enum.at(results, 0).title == "A"

      # Verify that it has aggregate the results from both sections
      assert Enum.at(results, 0).first_attempt_correct == 0.5
    end
  end

  defp insert_summaries(project_id, entries) do
    augmented_entries =
      Enum.map(entries, fn [
                             resource_id,
                             resource_type_id,
                             _pub_id,
                             section_id,
                             part_id,
                             num_correct,
                             num_attempts,
                             num_hints,
                             num_first_attempts_correct,
                             num_first_attempts
                           ] ->
        %{
          project_id: project_id,
          section_id: section_id,
          user_id: -1,
          resource_id: resource_id,
          resource_type_id: resource_type_id,
          part_id: part_id,
          num_correct: num_correct,
          num_attempts: num_attempts,
          num_hints: num_hints,
          num_first_attempts: num_first_attempts,
          num_first_attempts_correct: num_first_attempts_correct
        }
      end)

    Oli.Repo.insert_all(Oli.Analytics.Summary.ResourceSummary, augmented_entries)
  end
end
