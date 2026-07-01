defmodule Oli.Delivery.InstructorCustomizations.TargetResolverTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Delivery.InstructorCustomizations.TargetResolver
  alias Oli.Delivery.Sections
  alias Oli.Resources.ResourceType

  setup do
    author = insert(:author)
    project = insert(:project, authors: [author])

    candidates = Enum.map(1..3, &activity_revision("Candidate #{&1}"))
    embedded_activity = embedded_activity_revision("Embedded activity")

    page_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_page(),
        title: "Basic page",
        content: %{
          "model" => [
            %{"type" => "activity-reference", "activity_id" => embedded_activity.resource_id},
            selection("selection-1", 2)
          ]
        }
      )

    root_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_container(),
        title: "Root",
        children: [page_revision.resource_id],
        content: %{}
      )

    revisions = [root_revision, page_revision, embedded_activity | candidates]

    Enum.each(revisions, fn revision ->
      insert(:project_resource, project_id: project.id, resource_id: revision.resource_id)
    end)

    publication =
      insert(:publication, project: project, root_resource_id: root_revision.resource_id)

    Enum.each(revisions, fn revision ->
      insert(:published_resource,
        publication: publication,
        resource: revision.resource,
        revision: revision,
        author: author
      )
    end)

    section = insert(:section, base_project: project)
    {:ok, section} = Sections.create_section_resources(section, publication)

    {:ok,
     %{
       section: section,
       page_revision: page_revision,
       selection: selection("selection-1", 2),
       candidates: candidates,
       embedded_activity: embedded_activity
     }}
  end

  describe "candidates_match?/4" do
    test "returns the matching subset as a set", context do
      [first, second | _rest] = context.candidates

      assert {:ok, matching_ids} =
               TargetResolver.candidates_match?(
                 context.section,
                 context.page_revision,
                 context.selection,
                 [first.resource_id, second.resource_id]
               )

      assert matching_ids == MapSet.new([first.resource_id, second.resource_id])
    end

    test "excludes ids that do not currently match the selection", context do
      [first | _rest] = context.candidates

      assert {:ok, matching_ids} =
               TargetResolver.candidates_match?(
                 context.section,
                 context.page_revision,
                 context.selection,
                 [first.resource_id, context.embedded_activity.resource_id]
               )

      assert matching_ids == MapSet.new([first.resource_id])
    end

    test "dedupes and ignores non-integer input ids", context do
      [first | _rest] = context.candidates

      assert {:ok, matching_ids} =
               TargetResolver.candidates_match?(
                 context.section,
                 context.page_revision,
                 context.selection,
                 [first.resource_id, first.resource_id, "bad", nil]
               )

      assert matching_ids == MapSet.new([first.resource_id])
    end

    test "returns an empty set for an empty input list", context do
      assert {:ok, matching_ids} =
               TargetResolver.candidates_match?(
                 context.section,
                 context.page_revision,
                 context.selection,
                 []
               )

      assert matching_ids == MapSet.new()
    end
  end

  defp activity_revision(title) do
    insert(:revision,
      resource_type_id: ResourceType.id_for_activity(),
      activity_type_id: Oli.Activities.get_registration_by_slug("oli_multiple_choice").id,
      title: title,
      scope: "banked",
      content: %{"model" => %{"stem" => title}}
    )
  end

  defp embedded_activity_revision(title) do
    insert(:revision,
      resource_type_id: ResourceType.id_for_activity(),
      activity_type_id: Oli.Activities.get_registration_by_slug("oli_multiple_choice").id,
      title: title,
      scope: "embedded",
      content: %{"model" => %{"stem" => title}}
    )
  end

  defp selection(id, count) do
    %{"type" => "selection", "id" => id, "logic" => %{"conditions" => nil}, "count" => count}
  end
end
