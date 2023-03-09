defmodule Oli.Delivery.Sections.SchedulingFacadeTest do
  use Oli.DataCase

  import Ecto.Query, warn: false

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.SchedulingFacade
  alias Oli.Publishing

  def create_date_time({:ok, date}, {:ok, time}) do
    {:ok, date_time} = DateTime.new(date, time)
    date_time
  end

  describe "scheduling facade operations" do
    setup do
      Seeder.base_project_with_resource2()
    end

    test "retrieve/1 fetches and update/2 edits", %{
      project: project,
      institution: institution
    } do
      {:ok, initial_pub} = Publishing.publish_project(project, "some changes")

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

      scheduled_resources = SchedulingFacade.retrieve(section)

      by_slug = fn srs, slug ->
        result = Enum.find(srs, fn sr -> sr.slug == slug end)
        refute is_nil(result)
        result
      end

      assert Enum.count(scheduled_resources) == 3

      root = by_slug.(scheduled_resources, "root_container")
      assert root.resource_type_id == Oli.Resources.ResourceType.get_id_by_type("container")
      assert root.title == "Root Container"
      assert root.scheduling_type == :read_by

      page_one = by_slug.(scheduled_resources, "page_one")
      assert page_one.resource_type_id == Oli.Resources.ResourceType.get_id_by_type("page")
      assert page_one.title == "Page one"
      assert page_one.scheduling_type == :read_by

      page_two = by_slug.(scheduled_resources, "page_two")
      assert page_two.resource_type_id == Oli.Resources.ResourceType.get_id_by_type("page")
      assert page_two.title == "Page two"
      assert page_two.scheduling_type == :read_by

      assert {:ok, 2} = SchedulingFacade.update(section, [
        %{id: root.id, scheduling_type: "inclass_activity", start_date: "2023-02-03", end_date: "2023-02-06", manually_scheduled: true},
        %{id: page_one.id, scheduling_type: "inclass_activity", start_date: nil, end_date: "2023-02-06", manually_scheduled: false}
      ], "Etc/UTC")

      scheduled_resources = SchedulingFacade.retrieve(section)

      assert Enum.count(scheduled_resources) == 3

      root = by_slug.(scheduled_resources, "root_container")
      assert root.resource_type_id == Oli.Resources.ResourceType.get_id_by_type("container")
      assert root.title == "Root Container"
      assert root.start_date == ~D[2023-02-03]
      assert root.end_date == ~D[2023-02-06]
      assert root.manually_scheduled == true
      assert root.scheduling_type == :inclass_activity

      page_one = by_slug.(scheduled_resources, "page_one")
      assert page_one.resource_type_id == Oli.Resources.ResourceType.get_id_by_type("page")
      assert page_one.title == "Page one"
      assert is_nil(page_one.start_date)
      assert page_one.end_date == ~D[2023-02-06]
      assert page_one.manually_scheduled == false
      assert page_one.scheduling_type == :inclass_activity

    end

    test "retrieve/1 fetches and update/2 edits correctly when condition present", %{
      project: project,
      institution: institution
    } do
      {:ok, initial_pub} = Publishing.publish_project(project, "some changes")

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

      scheduled_resources = SchedulingFacade.retrieve(section)

      by_slug = fn srs, slug ->
        result = Enum.find(srs, fn sr -> sr.slug == slug end)
        refute is_nil(result)
        result
      end

      assert Enum.count(scheduled_resources) == 3

      root = by_slug.(scheduled_resources, "root_container")
      assert root.resource_type_id == Oli.Resources.ResourceType.get_id_by_type("container")
      assert root.title == "Root Container"
      assert root.scheduling_type == :read_by

      page_one = by_slug.(scheduled_resources, "page_one")
      assert page_one.resource_type_id == Oli.Resources.ResourceType.get_id_by_type("page")
      assert page_one.title == "Page one"
      assert page_one.scheduling_type == :read_by

      page_two = by_slug.(scheduled_resources, "page_two")
      assert page_two.resource_type_id == Oli.Resources.ResourceType.get_id_by_type("page")
      assert page_two.title == "Page two"
      assert page_two.scheduling_type == :read_by

      Oli.Delivery.Gating.create_gating_condition(%{
        type: :schedule,
        graded_resource_policy: :allows_review,
        data: %{start_datetime: nil, end_datetime: DateTime.utc_now(), resource_id: nil, minimum_percentage: nil},
        resource_id: page_two.resource_id,
        section_id: section.id,
        user_id: nil,
        parent_id: nil
      })

      scheduled_resources = SchedulingFacade.retrieve(section)
      assert Enum.count(scheduled_resources) == 3

      root = by_slug.(scheduled_resources, "root_container")
      assert root.resource_type_id == Oli.Resources.ResourceType.get_id_by_type("container")
      assert root.title == "Root Container"
      assert root.scheduling_type == :read_by

      page_one = by_slug.(scheduled_resources, "page_one")
      assert page_one.resource_type_id == Oli.Resources.ResourceType.get_id_by_type("page")
      assert page_one.title == "Page one"
      assert page_one.scheduling_type == :read_by

      page_two = by_slug.(scheduled_resources, "page_two")
      assert page_two.resource_type_id == Oli.Resources.ResourceType.get_id_by_type("page")
      assert page_two.title == "Page two"
      assert page_two.scheduling_type == :due_by

      # Issue an update which results in an insert and an update of gating conditions
      assert {:ok, 3} = SchedulingFacade.update(section, [
        %{id: root.id, scheduling_type: "inclass_activity", start_date: "2023-02-03", end_date: "2023-02-06", manually_scheduled: true},
        %{id: page_one.id, scheduling_type: "due_by", start_date: nil, end_date: "2023-02-06 4:10:09", manually_scheduled: true},
        %{id: page_two.id, scheduling_type: "due_by", start_date: nil, end_date: "2023-02-07 3:10:09", manually_scheduled: true}
      ], "Etc/UTC")

      gates = Oli.Delivery.Gating.list_gating_conditions(section.id)
      assert Enum.count(gates) == 2
      date1 = create_date_time(Date.new(2023, 2, 6), Time.new(4, 10, 9))
      date2 = create_date_time(Date.new(2023, 2, 7), Time.new(3, 10, 9))

      [a, b] = gates
      assert a.data.end_datetime == date1
      assert b.data.end_datetime == date2

      # Issue an update which results in two deletions of gating conditions
      assert {:ok, 3} = SchedulingFacade.update(section, [
        %{id: root.id, scheduling_type: "inclass_activity", start_date: "2023-02-03", end_date: "2023-02-06", manually_scheduled: true},
        %{id: page_one.id, scheduling_type: "read_by", start_date: nil, end_date: "2023-02-06", manually_scheduled: true},
        %{id: page_two.id, scheduling_type: "read_by", start_date: nil, end_date: "2023-02-07", manually_scheduled: true}
      ], "Etc/UTC")

      gates = Oli.Delivery.Gating.list_gating_conditions(section.id)
      assert Enum.count(gates) == 0

    end

  end

end
