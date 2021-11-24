defmodule Oli.Delivery.GatingTest do
  use Oli.DataCase

  alias Oli.Delivery.Gating
  alias Oli.Seeder

  describe "gating_conditions" do
    alias Oli.Delivery.Gating.GatingCondition
    alias Oli.Delivery.Gating.GatingConditionData

    setup do
      Seeder.base_project_with_resource4()
    end

    @update_attrs %{type: :schedule, data: %{}}
    @invalid_attrs %{type: nil, data: nil}

    test "list_gating_conditions/1 returns all gating_conditions for a given section",
         %{
           container: %{resource: container_resource},
           page1: page1,
           page2: page2,
           section_1: section,
           section_2: section2
         } do
      gating_condition1 =
        gating_condition_fixture(%{section_id: section.id, resource_id: container_resource.id})

      gating_condition2 =
        gating_condition_fixture(%{section_id: section.id, resource_id: page1.id})

      gating_condition3 =
        gating_condition_fixture(%{section_id: section.id, resource_id: page2.id})

      another_section_gating_condition =
        gating_condition_fixture(%{section_id: section2.id, resource_id: page2.id})

      gcs = Gating.list_gating_conditions(section.id)

      # ensure all defined gating conditions for section are returned
      assert Enum.count(gcs) == 3
      assert Enum.find(gcs, fn gc -> gc.id == gating_condition1.id end)
      assert Enum.find(gcs, fn gc -> gc.id == gating_condition2.id end)
      assert Enum.find(gcs, fn gc -> gc.id == gating_condition3.id end)

      # ensure all defined gating conditions for another section are not
      assert !Enum.find(gcs, fn gc -> gc.id == another_section_gating_condition.id end)
    end

    test "list_gating_conditions/2 returns all gating_conditions for a given section and list of resource_ids",
         %{
           container: %{resource: container_resource},
           page1: page1,
           page2: page2,
           section_1: section,
           section_2: section2
         } do
      gating_condition1 =
        gating_condition_fixture(%{section_id: section.id, resource_id: container_resource.id})

      gating_condition2 =
        gating_condition_fixture(%{section_id: section.id, resource_id: page1.id})

      gating_condition3 =
        gating_condition_fixture(%{section_id: section.id, resource_id: page2.id})

      another_section_gating_condition =
        gating_condition_fixture(%{section_id: section2.id, resource_id: page2.id})

      gcs = Gating.list_gating_conditions(section.id)

      # ensure all defined gating conditions for section are returned
      assert Enum.count(gcs) == 3
      assert Enum.find(gcs, fn gc -> gc.id == gating_condition1.id end)
      assert Enum.find(gcs, fn gc -> gc.id == gating_condition2.id end)
      assert Enum.find(gcs, fn gc -> gc.id == gating_condition3.id end)

      # ensure all defined gating conditions for another section are not
      assert !Enum.find(gcs, fn gc -> gc.id == another_section_gating_condition.id end)
    end

    test "get_gating_condition!/1 returns the gating_condition with given id", %{
      page1: page1,
      section_1: section
    } do
      gating_condition =
        gating_condition_fixture(%{section_id: section.id, resource_id: page1.id})

      assert Gating.get_gating_condition!(gating_condition.id) == gating_condition
    end

    test "create_gating_condition/1 with valid data creates a gating_condition", %{
      page1: page1,
      section_1: section
    } do
      gating_condition =
        gating_condition_fixture(%{section_id: section.id, resource_id: page1.id})

      assert gating_condition.data == %GatingConditionData{}
    end

    test "create_gating_condition/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Gating.create_gating_condition(@invalid_attrs)
    end

    test "update_gating_condition/2 with valid data updates the gating_condition", %{
      page1: page1,
      section_1: section
    } do
      gating_condition =
        gating_condition_fixture(%{section_id: section.id, resource_id: page1.id})

      assert {:ok, %GatingCondition{} = gating_condition} =
               Gating.update_gating_condition(gating_condition, @update_attrs)

      assert gating_condition.data == %GatingConditionData{}
    end

    test "update_gating_condition/2 with invalid data returns error changeset", %{
      page1: page1,
      section_1: section
    } do
      gating_condition =
        gating_condition_fixture(%{section_id: section.id, resource_id: page1.id})

      assert {:error, %Ecto.Changeset{}} =
               Gating.update_gating_condition(gating_condition, @invalid_attrs)

      assert gating_condition == Gating.get_gating_condition!(gating_condition.id)
    end

    test "delete_gating_condition/1 deletes the gating_condition", %{
      page1: page1,
      section_1: section
    } do
      gating_condition =
        gating_condition_fixture(%{section_id: section.id, resource_id: page1.id})

      assert {:ok, %GatingCondition{}} = Gating.delete_gating_condition(gating_condition)

      assert_raise Ecto.NoResultsError, fn ->
        Gating.get_gating_condition!(gating_condition.id)
      end
    end

    test "change_gating_condition/1 returns a gating_condition changeset", %{
      page1: page1,
      section_1: section
    } do
      gating_condition =
        gating_condition_fixture(%{section_id: section.id, resource_id: page1.id})

      assert %Ecto.Changeset{} = Gating.change_gating_condition(gating_condition)
    end

    test "generate_resource_gating_index/1 returns a gating index map", %{
      unit1_container: %{resource: unit1},
      nested_page1: nested_page1,
      nested_page2: nested_page2,
      page1: page1,
      page2: page2,
      section_1: section,
      section_2: section2
    } do
      page2_gating_condition =
        gating_condition_fixture(%{section_id: section.id, resource_id: page2.id})

      unit_gating_condition =
        gating_condition_fixture(%{section_id: section.id, resource_id: unit1.id})

      nested_page1_gating_condition =
        gating_condition_fixture(%{section_id: section.id, resource_id: nested_page1.id})

      another_section_gating_condition =
        gating_condition_fixture(%{section_id: section2.id, resource_id: page1.id})

      index = Gating.generate_resource_gating_index(section)

      # ensure all defined gating conditions for section are in the index
      assert Enum.count(index) == 4

      assert index[Integer.to_string(page2.id)] == [
               page2_gating_condition.resource_id
             ]

      assert index[Integer.to_string(unit1.id)] == [
               unit_gating_condition.resource_id
             ]

      assert index[Integer.to_string(nested_page1.id)] == [
               nested_page1_gating_condition.resource_id,
               unit_gating_condition.resource_id
             ]

      assert index[Integer.to_string(nested_page2.id)] == [
               unit_gating_condition.resource_id
             ]

      # ensure a gating condition for a resource only in another section does not
      # appear in this index
      assert index[another_section_gating_condition.resource_id] == nil
    end

    test "resource_open/2 returns true if all ancestor gating conditions pass", %{
      unit1_container: %{resource: unit1},
      page1: page1,
      nested_page1: nested_page1,
      nested_page2: nested_page2,
      page2: page2,
      section_1: section
    } do
      _page2_gating_condition =
        gating_condition_fixture(%{section_id: section.id, resource_id: page2.id})

      unit_gating_condition =
        gating_condition_fixture(%{
          section_id: section.id,
          resource_id: unit1.id,
          data: %{start_datetime: yesterday(), end_datetime: tomorrow()}
        })

      _nested_page1_gating_condition =
        gating_condition_fixture(%{section_id: section.id, resource_id: nested_page1.id})

      _nested_page2_gating_condition =
        gating_condition_fixture(%{
          section_id: section.id,
          resource_id: nested_page2.id,
          data: %{end_datetime: yesterday()}
        })

      {:ok, section} = Gating.update_resource_gating_index(section)

      # check resource that has no gating condition defined
      assert Gating.resource_open(section, page1.id) == true

      # check nested resource that has gating condition defined for itself and its container
      assert Gating.resource_open(section, nested_page1.id) == true

      # check for a resource that is gated and condition is not satisfied
      assert Gating.resource_open(section, nested_page2.id) == false

      # change unit to have ended yesterday, check that nested resource is now gated properly
      Gating.update_gating_condition(unit_gating_condition, %{
        data: %{end_datetime: yesterday()}
      })

      # nested resource should no longer be accessible since unit is gated by a schedule that ended yesterday
      assert Gating.resource_open(section, nested_page1.id) == false
    end
  end
end
