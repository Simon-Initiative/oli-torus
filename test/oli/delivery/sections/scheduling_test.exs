defmodule Oli.Delivery.Sections.SchedulingTest do
  use Oli.DataCase

  import Ecto.Query, warn: false

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Scheduling
  alias Oli.Publishing

  describe "scheduling operations" do
    setup do
      Seeder.base_project_with_resource2()
    end

    test "retrieve/1 fetches and update/2 edits", %{
      project: project,
      institution: institution,
      author: author
    } do
      {:ok, initial_pub} = Publishing.publish_project(project, "some changes", author.id)

      # Create a course section using the initial publication
      {:ok, section} =
        Sections.create_section(%{
          title: "1",
          registration_open: true,
          context_id: UUID.uuid4(),
          institution_id: institution.id,
          base_project_id: project.id,
          publisher_id: project.publisher_id
        })
        |> then(fn {:ok, section} -> section end)
        |> Sections.create_section_resources(initial_pub)

      scheduled_resources = Scheduling.retrieve(section)

      by_slug = fn srs, slug ->
        result = Enum.find(srs, fn sr -> sr.slug == slug end)
        refute is_nil(result)
        result
      end

      assert Enum.count(scheduled_resources) == 3

      root = by_slug.(scheduled_resources, "root_container")
      assert root.resource_type_id == Oli.Resources.ResourceType.id_for_container()
      assert root.title == "Root Container"
      assert root.scheduling_type == :read_by

      page_one = by_slug.(scheduled_resources, "page_one")
      assert page_one.resource_type_id == Oli.Resources.ResourceType.id_for_page()
      assert page_one.title == "Page one"
      refute page_one.graded
      assert page_one.scheduling_type == :read_by

      page_two = by_slug.(scheduled_resources, "page_two")
      assert page_two.resource_type_id == Oli.Resources.ResourceType.id_for_page()
      assert page_two.title == "Page two"
      refute page_two.graded
      assert page_two.scheduling_type == :read_by

      assert {:ok, 2} =
               Scheduling.update(
                 section,
                 [
                   %{
                     id: root.id,
                     scheduling_type: "inclass_activity",
                     start_date: "2023-02-03",
                     end_date: "2023-02-06",
                     manually_scheduled: true,
                     removed_from_schedule: false
                   },
                   %{
                     id: page_one.id,
                     scheduling_type: "inclass_activity",
                     start_date: nil,
                     end_date: "2023-02-06",
                     manually_scheduled: false,
                     removed_from_schedule: false
                   }
                 ],
                 "Etc/UTC"
               )

      scheduled_resources = Scheduling.retrieve(section)

      assert Enum.count(scheduled_resources) == 3
      root = by_slug.(scheduled_resources, "root_container")
      assert root.resource_type_id == Oli.Resources.ResourceType.id_for_container()
      assert root.title == "Root Container"
      assert root.start_date == ~U[2023-02-03 23:59:59Z]
      assert root.end_date == ~U[2023-02-06 23:59:59Z]
      assert root.manually_scheduled == true
      refute root.graded
      assert root.scheduling_type == :inclass_activity

      page_one = by_slug.(scheduled_resources, "page_one")
      assert page_one.resource_type_id == Oli.Resources.ResourceType.id_for_page()
      assert page_one.title == "Page one"
      assert is_nil(page_one.start_date)
      assert page_one.end_date == ~U[2023-02-06 23:59:59Z]
      assert page_one.manually_scheduled == false
      refute page_one.graded
      assert page_one.scheduling_type == :inclass_activity
    end

    test "cannot edit section resources of a different section", %{
      project: project,
      institution: institution,
      author: author
    } do
      {:ok, initial_pub} = Publishing.publish_project(project, "some changes", author.id)

      # Create a course section using the initial publication
      {:ok, section1} =
        Sections.create_section(%{
          title: "1",
          registration_open: true,
          context_id: UUID.uuid4(),
          institution_id: institution.id,
          base_project_id: project.id,
          publisher_id: project.publisher_id
        })
        |> then(fn {:ok, section} -> section end)
        |> Sections.create_section_resources(initial_pub)

      {:ok, section2} =
        Sections.create_section(%{
          title: "1",
          registration_open: true,
          context_id: UUID.uuid4(),
          institution_id: institution.id,
          base_project_id: project.id,
          publisher_id: project.publisher_id
        })
        |> then(fn {:ok, section} -> section end)
        |> Sections.create_section_resources(initial_pub)

      scheduled_resources = Scheduling.retrieve(section1)

      by_slug = fn srs, slug ->
        result = Enum.find(srs, fn sr -> sr.slug == slug end)
        refute is_nil(result)
        result
      end

      root = by_slug.(scheduled_resources, "root_container")

      # Simulate a malicious client-side attempt to bulk edit section resource
      # schedule of srs from not this section
      assert {:ok, 0} =
               Scheduling.update(
                 section2,
                 [
                   %{
                     id: root.id,
                     scheduling_type: "inclass_activity",
                     start_date: "2023-02-03",
                     end_date: "2023-02-06",
                     manually_scheduled: true,
                     removed_from_schedule: false
                   }
                 ],
                 "Etc/UTC"
               )
    end
  end
end
