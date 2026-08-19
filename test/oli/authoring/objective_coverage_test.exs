defmodule Oli.Authoring.ObjectiveCoverageTest do
  use Oli.DataCase

  # Requirements proof: AC-001, AC-002, AC-003, AC-004, AC-005, AC-006,
  # AC-007, AC-008, and AC-009 are exercised by this focused suite, with query
  # shape, pure projections, safety, and operational checks kept at the
  # application-module boundary.

  alias Oli.Authoring.ObjectiveCoverage
  alias Oli.Resources.ResourceType

  describe "build/2" do
    test "derives hierarchical coverage, page-first details, and search projections" do
      rows = [
        row(ResourceType.id_for_objective(), 1,
          title: "Parent Objective",
          children: [2],
          objectives: %{}
        ),
        row(ResourceType.id_for_objective(), 2,
          title: "Child Objective",
          objectives: %{}
        ),
        row(ResourceType.id_for_page(), 100,
          title: "Practice Page",
          objectives: %{"attached" => [1]},
          graded: false,
          activity_refs: [200, 200]
        ),
        row(ResourceType.id_for_page(), 101,
          title: "Assessment Page",
          objectives: %{"attached" => [2]},
          graded: true,
          activity_refs: [200, 201, 202]
        ),
        row(ResourceType.id_for_activity(), 200,
          title: "Practice Activity",
          objectives: %{"part" => [2]},
          scope: :embedded
        ),
        row(ResourceType.id_for_activity(), 201,
          title: "Assessment Activity",
          objectives: %{"part" => [1, 2]},
          scope: :embedded
        ),
        row(ResourceType.id_for_activity(), 202,
          title: "Banked Activity",
          objectives: %{"part" => [2]},
          scope: :banked
        )
      ]

      model = ObjectiveCoverage.build(rows)

      assert ObjectiveCoverage.coverage(model, 1) == %{
               page_count: 2,
               formative_activity_count: 1,
               summative_activity_count: 2,
               sub_objective_count: 1
             }

      assert ObjectiveCoverage.coverage(model, 2) == %{
               page_count: 1,
               formative_activity_count: 1,
               summative_activity_count: 2,
               sub_objective_count: 0
             }

      formative_details = ObjectiveCoverage.details(model, 1, :formative)
      summative_details = ObjectiveCoverage.details(model, 1, "summative")

      assert Enum.map(formative_details, & &1.page.resource_id) == [100, 101]
      assert Enum.map(hd(formative_details).activities, & &1.resource_id) == [200]
      assert Enum.map(summative_details, & &1.page.resource_id) == [100, 101]
      assert Enum.map(List.last(summative_details).activities, & &1.resource_id) == [200, 201]

      search_results = ObjectiveCoverage.search(model, "assessment")
      assert Enum.map(search_results, & &1.objective_id) == [2, 1]

      assert Enum.all?(search_results, fn result ->
               Enum.any?(result.matches, &(&1.type == :activity and &1.resource_id == 201))
             end)

      refute Enum.any?(List.last(summative_details).activities, &(&1.resource_id == 202))

      assert Enum.map(ObjectiveCoverage.curriculum_pages(model, [999]), & &1) == []
    end

    test "builds normalized resource, hierarchy, and curriculum indexes" do
      objective_id = 10
      child_id = 11
      page_id = 20
      activity_id = 30
      container_id = 40

      rows = [
        row(ResourceType.id_for_objective(), objective_id, children: [child_id]),
        row(ResourceType.id_for_objective(), child_id, children: nil),
        row(ResourceType.id_for_page(), page_id,
          children: [page_id + 1],
          activity_refs: [activity_id, activity_id]
        ),
        row(ResourceType.id_for_activity(), activity_id, scope: :embedded),
        row(ResourceType.id_for_container(), container_id, children: [page_id])
      ]

      model = ObjectiveCoverage.build(rows, %{project_id: 1, publication_id: 2})

      assert model.project_id == 1
      assert model.publication_id == 2
      assert model.objectives_by_id[objective_id].children == [child_id]
      assert model.children_by_parent == %{objective_id => [child_id], child_id => []}
      assert model.parents_by_child == %{child_id => [objective_id]}
      assert model.pages_by_id[page_id].activity_refs == [activity_id]
      assert model.activities_by_id[activity_id].scope == :embedded
      assert model.curriculum_by_id[container_id].children == [page_id]
    end

    test "normalizes malformed optional values and produces stable output" do
      rows = [
        row(ResourceType.id_for_objective(), 2, children: [3, 2, "invalid"]),
        row(ResourceType.id_for_objective(), 1, children: [2]),
        row(ResourceType.id_for_page(), 9, children: "invalid", activity_refs: nil)
      ]

      first = ObjectiveCoverage.build(rows)
      second = ObjectiveCoverage.build(Enum.reverse(rows))

      assert first.children_by_parent == %{1 => [2], 2 => [2, 3]}
      assert first.pages_by_id[9].children == []
      assert first.pages_by_id[9].activity_refs == []
      assert first == second

      cycle =
        ObjectiveCoverage.build([
          row(ResourceType.id_for_objective(), 1, children: [2]),
          row(ResourceType.id_for_objective(), 2, children: [1])
        ])

      assert ObjectiveCoverage.coverage(cycle, 1).sub_objective_count == 1
      assert ObjectiveCoverage.search(cycle, "resource") != []
    end
  end

  describe "projection_query/1" do
    test "loads rows from the project's current working publication" do
      %{project: project} = Seeder.base_project_with_resource2()

      assert {:ok, model} = ObjectiveCoverage.load(project.slug)
      assert model.project_id == project.id
      assert is_integer(model.publication_id)
      assert model.rows_by_type != %{}
    end

    test "projects only compact working-publication fields" do
      {:ok, query} = ObjectiveCoverage.projection_query("project-slug")
      query_string = inspect(query)

      assert query_string =~ "published"
      assert query_string =~ "resource_type_id"
      refute query_string =~ "content"
    end

    test "emits bounded load telemetry" do
      handler_id = {__MODULE__, self(), System.unique_integer([:positive])}

      :telemetry.attach(
        handler_id,
        [:oli, :authoring, :objective_coverage, :load, :stop],
        fn event, measurements, metadata, pid ->
          send(pid, {:objective_coverage_telemetry, event, measurements, metadata})
        end,
        self()
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      %{project: project} = Seeder.base_project_with_resource2()
      assert {:ok, _model} = ObjectiveCoverage.load(project.slug)

      assert_receive {:objective_coverage_telemetry, event, %{count: 1, duration_ms: duration_ms},
                      metadata}

      assert event == [:oli, :authoring, :objective_coverage, :load, :stop]
      assert is_integer(duration_ms)
      assert metadata.project_id == project.id
      assert metadata.project_slug == project.slug
      refute inspect(metadata) =~ "content"
    end
  end

  defp row(resource_type_id, resource_id, attrs) do
    %{
      project_id: 1,
      publication_id: 2,
      revision_id: resource_id + 100,
      resource_id: resource_id,
      resource_type_id: resource_type_id,
      slug: "resource-#{resource_id}",
      title: Keyword.get(attrs, :title, "Resource #{resource_id}"),
      deleted: false,
      objectives: Keyword.get(attrs, :objectives, %{"attached" => [1]}),
      children: Keyword.get(attrs, :children, []),
      graded: Keyword.get(attrs, :graded, false),
      activity_refs: Keyword.get(attrs, :activity_refs, []),
      scope: Keyword.get(attrs, :scope, :embedded),
      activity_type_id: nil
    }
  end
end
