defmodule Oli.Analytics.Summary.BrowseInsightsTest do
  use Oli.DataCase

  import Ecto.Query

  alias Oli.Activities
  alias Oli.Activities.ActivityRegistration
  alias Oli.Analytics.Summary.BrowseInsights
  alias Oli.Repo

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

  describe "adaptive activity aggregation" do
    setup do
      map =
        Seeder.base_project_with_resource2()
        |> Seeder.create_section()
        |> Seeder.add_activity(%{title: "Regular Activity", content: %{}}, :regular_activity)

      adaptive_activity = create_adaptive_activity(map, "Adaptive Screen")

      %{project: project, regular_activity: regular_activity, section: section} = map

      insert_summaries(project.id, [
        [
          adaptive_activity.resource.id,
          adaptive_activity.revision.resource_type_id,
          -1,
          -1,
          "progress",
          1,
          2,
          1,
          1,
          2
        ],
        [
          adaptive_activity.resource.id,
          adaptive_activity.revision.resource_type_id,
          -1,
          -1,
          "question",
          2,
          4,
          0,
          1,
          2
        ],
        [
          regular_activity.resource.id,
          regular_activity.revision.resource_type_id,
          -1,
          -1,
          "part1",
          1,
          2,
          0,
          1,
          1
        ],
        [
          regular_activity.resource.id,
          regular_activity.revision.resource_type_id,
          -1,
          -1,
          "part2",
          1,
          3,
          0,
          0,
          1
        ],
        [
          adaptive_activity.resource.id,
          adaptive_activity.revision.resource_type_id,
          -1,
          section.id,
          "progress",
          2,
          3,
          0,
          1,
          1
        ],
        [
          adaptive_activity.resource.id,
          adaptive_activity.revision.resource_type_id,
          -1,
          section.id,
          "question",
          1,
          3,
          2,
          0,
          2
        ],
        [
          regular_activity.resource.id,
          regular_activity.revision.resource_type_id,
          -1,
          section.id,
          "part1",
          1,
          1,
          0,
          1,
          1
        ]
      ])

      Map.put(map, :adaptive_activity, adaptive_activity)
    end

    test "aggregates adaptive activity rows for authoring insights", %{
      project: project,
      regular_activity: regular_activity,
      adaptive_activity: adaptive_activity
    } do
      activity_type_id = Oli.Resources.ResourceType.get_id_by_type("activity")

      results =
        BrowseInsights.browse_insights(
          %Oli.Repo.Paging{limit: 10, offset: 0},
          %Oli.Repo.Sorting{direction: :asc, field: :title},
          %Oli.Analytics.Summary.BrowseInsightsOptions{
            project_id: project.id,
            section_ids: [],
            resource_type_id: activity_type_id
          }
        )

      assert length(results) == 3
      assert Enum.all?(results, &(&1.total_count == 3))

      assert [adaptive_row] =
               Enum.filter(results, &(&1.resource_id == adaptive_activity.resource.id))

      assert adaptive_row.title == "Adaptive Screen"
      assert adaptive_row.part_id == nil
      assert adaptive_row.num_attempts == 6
      assert adaptive_row.num_first_attempts == 4
      assert_in_delta adaptive_row.eventually_correct, 0.5, 1.0e-6
      assert_in_delta adaptive_row.first_attempt_correct, 0.5, 1.0e-6

      regular_rows =
        Enum.filter(results, &(&1.resource_id == regular_activity.resource.id))
        |> Enum.sort_by(& &1.part_id)

      assert Enum.map(regular_rows, & &1.part_id) == ["part1", "part2"]
    end

    test "aggregates adaptive activity rows across sections before paging", %{
      project: project,
      adaptive_activity: adaptive_activity,
      section: section
    } do
      activity_type_id = Oli.Resources.ResourceType.get_id_by_type("activity")

      results =
        BrowseInsights.browse_insights(
          %Oli.Repo.Paging{limit: 1, offset: 0},
          %Oli.Repo.Sorting{direction: :asc, field: :title},
          %Oli.Analytics.Summary.BrowseInsightsOptions{
            project_id: project.id,
            section_ids: [section.id],
            resource_type_id: activity_type_id
          }
        )

      assert length(results) == 1
      assert hd(results).total_count == 2

      adaptive_row = hd(results)

      assert adaptive_row.resource_id == adaptive_activity.resource.id
      assert adaptive_row.part_id == nil
      assert adaptive_row.num_attempts == 6
      assert adaptive_row.num_first_attempts == 3
      assert_in_delta adaptive_row.eventually_correct, 0.5, 1.0e-6
      assert_in_delta adaptive_row.first_attempt_correct, 1 / 3, 1.0e-6
    end

    test "caps adaptive aggregation fetch size before in-memory processing", %{
      project: project
    } do
      previous_max_rows = Application.get_env(:oli, :adaptive_insights_aggregation_max_rows)
      Application.put_env(:oli, :adaptive_insights_aggregation_max_rows, 2)

      on_exit(fn ->
        case previous_max_rows do
          nil -> Application.delete_env(:oli, :adaptive_insights_aggregation_max_rows)
          value -> Application.put_env(:oli, :adaptive_insights_aggregation_max_rows, value)
        end
      end)

      activity_type_id = Oli.Resources.ResourceType.get_id_by_type("activity")

      results =
        BrowseInsights.browse_insights(
          %Oli.Repo.Paging{limit: 10, offset: 0},
          %Oli.Repo.Sorting{direction: :asc, field: :title},
          %Oli.Analytics.Summary.BrowseInsightsOptions{
            project_id: project.id,
            section_ids: [],
            resource_type_id: activity_type_id
          }
        )

      assert length(results) == 2
      assert Enum.all?(results, &(&1.total_count == 2))
      assert Enum.all?(results, &(&1.title == "Regular Activity"))
      assert Enum.map(results, & &1.part_id) == ["part1", "part2"]
    end

    test "returns unaggregated rows when adaptive registration is unavailable", %{
      project: project,
      adaptive_activity: adaptive_activity
    } do
      from(ar in ActivityRegistration, where: ar.slug == "oli_adaptive")
      |> Repo.update_all(set: [slug: "oli_adaptive_missing"])

      activity_type_id = Oli.Resources.ResourceType.get_id_by_type("activity")

      results =
        BrowseInsights.browse_insights(
          %Oli.Repo.Paging{limit: 10, offset: 0},
          %Oli.Repo.Sorting{direction: :asc, field: :title},
          %Oli.Analytics.Summary.BrowseInsightsOptions{
            project_id: project.id,
            section_ids: [],
            resource_type_id: activity_type_id
          }
        )

      assert length(results) == 4
      assert Enum.all?(results, &(&1.total_count == 4))

      adaptive_rows =
        Enum.filter(results, &(&1.resource_id == adaptive_activity.resource.id))
        |> Enum.sort_by(& &1.part_id)

      assert Enum.map(adaptive_rows, & &1.part_id) == ["progress", "question"]
    end
  end

  defp create_adaptive_activity(map, title) do
    adaptive_registration = Activities.get_registration_by_slug("oli_adaptive")

    adaptive_activity =
      Seeder.create_activity(
        %{
          title: title,
          activity_type_id: adaptive_registration.id,
          content: %{}
        },
        map.publication,
        map.project,
        map.author
      )

    Seeder.create_page(
      "Adaptive Parent Page",
      map.publication,
      map.project,
      map.author,
      Seeder.create_sample_adaptive_page_content(adaptive_activity.revision.resource_id)
    )

    adaptive_activity
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
