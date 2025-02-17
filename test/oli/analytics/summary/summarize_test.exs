defmodule Oli.Analytics.Summary.SummarizeTest do
  use Oli.DataCase

  alias Oli.Analytics.Summary

  def add_resource_part_response([resource_id, part_id, response]) do
    Summary.create_resource_part_response(%{
      resource_id: resource_id,
      part_id: part_id,
      response: response,
      label: response
    })
  end

  def add_response_summary([
        section_id,
        page_id,
        activity_id,
        part_id,
        count,
        resource_part_response_id
      ]) do
    Summary.create_response_summary(%{
      project_id: -1,
      publication_id: -1,
      section_id: section_id,
      page_id: page_id,
      activity_id: activity_id,
      part_id: part_id,
      resource_part_response_id: resource_part_response_id,
      count: count
    })
  end

  describe "v2 metrics calculations" do
    setup do
      map =
        Seeder.base_project_with_resource2()
        |> Seeder.create_section()
        |> Seeder.add_activity(%{title: "one", content: %{}}, :a1)
        |> Seeder.add_activity(%{title: "two", content: %{}}, :a2)
        |> Seeder.add_user(%{}, :user1)
        |> Seeder.add_user(%{}, :user2)

      Seeder.ensure_published(map.publication.id)

      Seeder.create_section_resources(map)
    end

    test "summarizing multipart activities", %{
      user1: user1,
      user2: user2,
      section: section,
      a1: a1,
      a2: a2,
      page1: page1
    } do
      activity_type_id = Oli.Resources.ResourceType.id_for_activity()

      id1 = a1.resource.id
      id2 = a2.resource.id

      # Create two responses for each activity
      [{:ok, r1}, {:ok, r2}, {:ok, r3}, {:ok, r4}] =
        [
          [id1, "1", "apple"],
          [id1, "1", "banana"],
          [id2, "1", "apple"],
          [id2, "1", "banana"]
        ]
        |> Enum.map(fn v -> add_resource_part_response(v) end)

      [
        [section.id, page1.id, id1, "1", 3, r1.id],
        [section.id, page1.id, id1, "1", 3, r2.id],
        [section.id, page1.id, id2, "1", 3, r3.id],
        [section.id, page1.id, id2, "1", 3, r4.id]
      ]
      |> Enum.each(fn v -> add_response_summary(v) end)

      [
        [-1, -1, section.id, user1.id, id1, "1", activity_type_id, 1, 2, 1, 1, 0],
        [-1, -1, section.id, user2.id, id1, "1", activity_type_id, 1, 3, 1, 1, 0],
        [-1, -1, section.id, user1.id, id2, "1", activity_type_id, 2, 4, 1, 1, 0],
        [-1, -1, section.id, user2.id, id2, "1", activity_type_id, 3, 5, 1, 1, 0]
      ]
      |> Enum.each(fn v -> add_resource_summary(v) end)

      items = Summary.summarize_activities_for_page(section.id, page1.id, nil)

      # Since we are querying through response summary to JOIN to the resource summary,
      # let's assert that we did this correctly to ensure that we are getting the true
      # count of resource summaries (and not multiplying by count by the number of responses
      # trough an incorrect join)
      assert Enum.count(items) == 4

      # verify the "only_for_activity_ids" optional constraint works
      items = Summary.summarize_activities_for_page(section.id, page1.id, [id1])
      assert Enum.count(items) == 2

      items = Summary.summarize_activities_for_page(section.id, page1.id, [id1 + id2])
      assert Enum.count(items) == 0
    end
  end
end
