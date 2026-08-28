defmodule Oli.Authoring.ObjectiveCoverageTest do
  use Oli.DataCase

  import Ecto.Query
  import Oli.Factory

  # Requirements traceability:
  # AC-001 -> "loads rows from the project's current working publication"
  # AC-002 -> working-publication load, project isolation, deleted revision,
  #            and compact projection tests
  # AC-003 -> "builds normalized resource, hierarchy, and curriculum indexes"
  # AC-004 -> "derives hierarchical coverage, page-first details, and search projections"
  # AC-005 -> assessment-bucket and page-first detail assertions in the same test
  # AC-006 -> search assertions in the same test
  # AC-007 -> embedded/banked activity and input-preservation assertions
  # AC-008 -> malformed data, cycle, isolation, deleted revision, and stable output tests
  # AC-009 -> compact projection, telemetry, formatting, compilation, and focused test checks

  alias Oli.Authoring.ObjectiveCoverage
  alias Oli.Publishing.PublishedResource
  alias Oli.Publishing.Publications.Publication
  alias Oli.Repo
  alias Oli.Resources.Revision
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

      input_rows = rows
      model = ObjectiveCoverage.build(input_rows)

      assert input_rows == rows

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

      assert Enum.map(formative_details, & &1.page.resource_id) == [100]
      assert Enum.map(hd(formative_details).activities, & &1.resource_id) == [200]
      assert Enum.map(summative_details, & &1.page.resource_id) == [101]
      assert Enum.map(hd(summative_details).activities, & &1.resource_id) == [200, 201]

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
      nested_container_id = 50

      rows = [
        row(ResourceType.id_for_objective(), objective_id, children: [child_id]),
        row(ResourceType.id_for_objective(), child_id, children: nil),
        row(ResourceType.id_for_page(), page_id,
          children: [],
          activity_refs: [activity_id, activity_id]
        ),
        row(ResourceType.id_for_activity(), activity_id, scope: :embedded),
        row(ResourceType.id_for_container(), container_id, children: [nested_container_id]),
        row(ResourceType.id_for_container(), nested_container_id, children: [page_id])
      ]

      model =
        ObjectiveCoverage.build(rows, %{
          project_id: 1,
          publication_id: 2,
          root_resource_id: container_id
        })

      assert model.project_id == 1
      assert model.publication_id == 2
      assert model.root_resource_id == container_id
      assert model.objectives_by_id[objective_id].children == [child_id]
      assert model.children_by_parent == %{objective_id => [child_id], child_id => []}
      assert model.parents_by_child == %{child_id => [objective_id]}
      assert model.pages_by_id[page_id].activity_refs == [activity_id]
      assert model.activities_by_id[activity_id].scope == :embedded
      assert model.curriculum_by_id[container_id].children == [nested_container_id]

      assert model.curriculum_children_by_parent == %{
               container_id => [nested_container_id],
               nested_container_id => [page_id],
               page_id => []
             }

      assert model.curriculum_parents_by_child == %{
               nested_container_id => [container_id],
               page_id => [nested_container_id]
             }

      assert model.curriculum_descendants_by_id[container_id] == [page_id, nested_container_id]

      assert model.curriculum_paths_by_id[page_id] == [
               [container_id, nested_container_id, page_id]
             ]

      assert ObjectiveCoverage.curriculum_pages(model, [container_id]) == [page_id]
    end

    test "reuses shared objective descendant scopes" do
      rows = [
        row(ResourceType.id_for_objective(), 1, children: [3]),
        row(ResourceType.id_for_objective(), 2, children: [3]),
        row(ResourceType.id_for_objective(), 3, []),
        row(ResourceType.id_for_page(), 30, objectives: %{"attached" => [3]})
      ]

      model = ObjectiveCoverage.build(rows)

      assert model.objective_scope_by_id == %{1 => [1, 3], 2 => [2, 3], 3 => [3]}
      assert ObjectiveCoverage.coverage(model, 1).page_count == 1
      assert ObjectiveCoverage.coverage(model, 2).page_count == 1
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
          row(ResourceType.id_for_objective(), 1, children: [2, 3]),
          row(ResourceType.id_for_objective(), 2, children: [1]),
          row(ResourceType.id_for_objective(), 3, []),
          row(ResourceType.id_for_container(), 40, children: [41]),
          row(ResourceType.id_for_container(), 41, children: [40])
        ])

      assert ObjectiveCoverage.coverage(cycle, 1).sub_objective_count == 2
      assert ObjectiveCoverage.search(cycle, "resource") != []
      assert cycle.objective_scope_by_id[1] == [1, 2, 3]
      assert cycle.objective_scope_by_id[2] == [1, 2, 3]
      assert cycle.curriculum_descendants_by_id[40] == [41]
      assert cycle.curriculum_paths_by_id[40] == [[41, 40]]
    end
  end

  describe "projection_query/1" do
    test "loads rows from the project's current working publication" do
      %{project: project} = Seeder.base_project_with_resource2()

      assert {:ok, model} = ObjectiveCoverage.load(project.slug)
      assert model.project_id == project.id
      assert is_integer(model.publication_id)
      assert is_integer(model.root_resource_id)
      assert model.rows_by_type != %{}
    end

    test "isolates loaded rows to the requested project" do
      %{project: requested_project} = Seeder.base_project_with_resource2()
      %{project: other_project} = Seeder.base_project_with_resource2()

      assert {:ok, model} = ObjectiveCoverage.load(requested_project.slug)

      rows = model.rows_by_type |> Map.values() |> List.flatten()

      assert rows != []
      assert Enum.all?(rows, &(&1.project_id == requested_project.id))
      refute Enum.any?(rows, &(&1.project_id == other_project.id))
    end

    test "excludes deleted revisions from the loaded projection" do
      %{project: project} = Seeder.base_project_with_resource2()
      {:ok, model} = ObjectiveCoverage.load(project.slug)
      row = model.rows_by_type |> Map.values() |> List.flatten() |> hd()

      Repo.update_all(
        from(revision in Revision, where: revision.id == ^row.revision_id),
        set: [deleted: true]
      )

      assert {:ok, updated_model} = ObjectiveCoverage.load(project.slug)

      refute updated_model.rows_by_type
             |> Map.values()
             |> List.flatten()
             |> Enum.any?(&(&1.resource_id == row.resource_id))
    end

    test "returns a tagged error for an unknown project" do
      assert {:error, :project_not_found} = ObjectiveCoverage.load("missing-project")
    end

    test "returns a tagged error when the project has no working publication" do
      %{project: project} = Seeder.base_project_with_resource2()

      Repo.update_all(
        from(publication in Publication,
          where: publication.project_id == ^project.id and is_nil(publication.published)
        ),
        set: [published: DateTime.utc_now()]
      )

      assert {:error, :working_publication_not_found} = ObjectiveCoverage.load(project.slug)
    end

    test "returns a tagged error when the project has multiple working publications" do
      %{project: project} = Seeder.base_project_with_resource2()

      publication =
        Repo.one!(
          from(publication in Publication,
            where: publication.project_id == ^project.id and is_nil(publication.published)
          )
        )

      insert(:publication,
        project: project,
        root_resource_id: publication.root_resource_id,
        published: nil
      )

      assert {:error, :multiple_working_publications} = ObjectiveCoverage.load(project.slug)
    end

    test "returns an empty model with context for an empty working publication" do
      %{project: project} = Seeder.base_project_with_resource2()
      {:ok, model} = ObjectiveCoverage.load(project.slug)

      Repo.delete_all(
        from(mapping in PublishedResource, where: mapping.publication_id == ^model.publication_id)
      )

      assert {:ok, empty_model} = ObjectiveCoverage.load(project.slug)
      assert empty_model.project_id == project.id
      assert empty_model.publication_id == model.publication_id
      assert empty_model.root_resource_id == model.root_resource_id
      assert empty_model.rows_by_type == %{}
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
