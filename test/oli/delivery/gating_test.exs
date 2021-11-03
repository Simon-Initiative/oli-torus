defmodule Oli.Delivery.GatingTest do
  use Oli.DataCase

  alias Oli.Delivery.Gating
  alias Oli.Seeder

  describe "gating_conditions" do
    alias Oli.Delivery.Gating.GatingCondition

    setup do
      Seeder.base_project_with_resource4()
    end

    @valid_attrs %{type: :start_datetime, data: %{}}
    @update_attrs %{type: :end_datetime, data: %{}}
    @invalid_attrs %{type: nil, data: nil}

    def gating_condition_fixture(attrs \\ %{}) do
      {:ok, gating_condition} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Gating.create_gating_condition()

      gating_condition
    end

    test "list_gating_conditions/0 returns all gating_conditions", %{
      page1: page1,
      section_1: section
    } do
      gating_condition =
        gating_condition_fixture(%{section_id: section.id, resource_id: page1.id})

      assert Gating.list_gating_conditions() == [gating_condition]
    end

    test "list_gating_conditions/1 returns all gating_conditions for a given list of resource_ids",
         %{
           container: %{resource: container_resource},
           page1: page1,
           page2: page2,
           section_1: section
         } do
      gating_condition1 =
        gating_condition_fixture(%{section_id: section.id, resource_id: container_resource.id})

      gating_condition2 =
        gating_condition_fixture(%{section_id: section.id, resource_id: page1.id})

      gating_condition3 =
        gating_condition_fixture(%{section_id: section.id, resource_id: page2.id})

      resource_ids = [container_resource.id, page1.id, page2.id]
      gcs = Gating.list_gating_conditions(resource_ids)

      # ensure all gating conditions are returned
      assert Enum.count(gcs) == 3
      assert Enum.find(gcs, fn gc -> gc.id == gating_condition1.id end)
      assert Enum.find(gcs, fn gc -> gc.id == gating_condition2.id end)
      assert Enum.find(gcs, fn gc -> gc.id == gating_condition3.id end)
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

      assert gating_condition.data == %{}
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

      assert gating_condition.data == %{}
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
  end
end
