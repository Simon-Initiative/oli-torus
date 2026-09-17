defmodule Oli.Delivery.GatingTest do
  use Oli.DataCase

  alias Oli.Delivery.Gating
  alias Oli.Delivery.Sections
  alias Oli.Seeder

  describe "atomic gate edits" do
    @describetag :copy_configuration_regression

    setup do
      Seeder.base_project_with_resource4()
      |> Seeder.add_users_to_section(:section_1, [:user_a])
    end

    test "creating a gate also persists its enforcement index", %{
      section_1: section,
      page1: page,
      user_a: user
    } do
      assert {:ok, gate} =
               Gating.create_gating_condition_with_index(%{
                 section_id: section.id,
                 resource_id: page.id,
                 type: :schedule,
                 data: %{start_datetime: ~U[2099-01-01 00:00:00Z]}
               })

      updated = Sections.get_section!(section.id)
      assert updated.resource_gating_index[Integer.to_string(page.id)] == [page.id]
      assert [%{id: id}] = Gating.blocked_by(updated, user, page.id)
      assert id == gate.id
    end

    test "changing a gate target atomically updates the enforcement index", %{
      section_1: section,
      page1: page1,
      page2: page2,
      user_a: user
    } do
      gate =
        gating_condition_fixture(%{
          section_id: section.id,
          resource_id: page1.id,
          data: %{start_datetime: ~U[2099-01-01 00:00:00Z]}
        })

      {:ok, _} = Gating.update_resource_gating_index(section)

      assert {:ok, updated_gate} =
               Gating.update_gating_condition_with_index(gate, %{resource_id: page2.id})

      updated = Sections.get_section!(section.id)

      assert Gating.blocked_by(updated, user, page1.id) == []
      assert [%{id: id}] = Gating.blocked_by(updated, user, page2.id)
      assert id == updated_gate.id
    end

    test "deleting a gate clears its index in the same operation", %{
      section_1: section,
      page1: page
    } do
      gate = gating_condition_fixture(%{section_id: section.id, resource_id: page.id})
      {:ok, _} = Gating.update_resource_gating_index(section)

      assert {:ok, deleted, 1} = Gating.delete_gating_condition_with_index(gate)
      assert deleted.id == gate.id
      assert Sections.get_section!(section.id).resource_gating_index == %{}
      assert Gating.list_gating_conditions(section.id) == []
    end

    test "a failed index write rolls the gate creation back", %{
      section_1: section,
      page1: page
    } do
      # Force a section validation failure after the gate insert succeeds.
      from(s in Oli.Delivery.Sections.Section, where: s.id == ^section.id)
      |> Repo.update_all(set: [requires_payment: true, amount: nil])

      assert {:error, %Ecto.Changeset{}} =
               Gating.create_gating_condition_with_index(%{
                 section_id: section.id,
                 resource_id: page.id,
                 type: :schedule,
                 data: %{}
               })

      assert Gating.list_gating_conditions(section.id) == []
      assert Sections.get_section!(section.id).resource_gating_index == %{}
    end

    test "a failed index write also rolls a gate target change back", %{
      section_1: section,
      page1: page1,
      page2: page2
    } do
      gate = gating_condition_fixture(%{section_id: section.id, resource_id: page1.id})
      {:ok, section} = Gating.update_resource_gating_index(section)

      from(s in Oli.Delivery.Sections.Section, where: s.id == ^section.id)
      |> Repo.update_all(set: [requires_payment: true, amount: nil])

      assert {:error, %Ecto.Changeset{}} =
               Gating.update_gating_condition_with_index(gate, %{resource_id: page2.id})

      assert Gating.get_gating_condition!(gate.id).resource_id == page1.id

      assert Sections.get_section!(section.id).resource_gating_index ==
               section.resource_gating_index
    end

    test "invalid gate changes do not alter the gate or its index", %{
      section_1: section,
      page1: page
    } do
      gate = gating_condition_fixture(%{section_id: section.id, resource_id: page.id})
      {:ok, section} = Gating.update_resource_gating_index(section)

      assert {:error, %Ecto.Changeset{}} =
               Gating.update_gating_condition_with_index(gate, %{type: nil})

      assert Gating.get_gating_condition!(gate.id) == gate

      assert Sections.get_section!(section.id).resource_gating_index ==
               section.resource_gating_index
    end

    test "an atomic gate edit cannot move a gate to another section", %{
      section_1: section,
      section_2: other,
      page1: page
    } do
      gate = gating_condition_fixture(%{section_id: section.id, resource_id: page.id})

      assert {:error, changeset} =
               Gating.update_gating_condition_with_index(gate, %{section_id: other.id})

      assert errors_on(changeset).section_id == ["cannot move a gate to another section"]
      assert Gating.get_gating_condition!(gate.id).section_id == section.id
    end
  end

  describe "gating_conditions" do
    alias Oli.Delivery.Gating.GatingCondition
    alias Oli.Delivery.Gating.GatingConditionData

    setup do
      Seeder.base_project_with_resource4()
      |> Seeder.add_users_to_section(:section_1, [:user_a, :user_b])
    end

    @update_attrs %{type: :schedule, data: %{}}
    @invalid_attrs %{type: nil, data: nil}

    test "duplicate_gates/2 duplicates top-level gates",
         %{
           page1: page1,
           page2: page2,
           section_1: section,
           section_2: section2,
           user_a: user_a
         } do
      gate = gating_condition_fixture(%{section_id: section.id, resource_id: page1.id})

      gating_condition_fixture(%{
        section_id: section.id,
        resource_id: page1.id,
        parent_id: gate.id,
        user_id: user_a.id
      })

      second_gate =
        gating_condition_fixture(%{section_id: section.id, resource_id: page2.id})

      gcs = Gating.list_gating_conditions(section.id)
      assert Enum.count(gcs) == 3

      assert Gating.list_gating_conditions(section2.id) == []

      assert {:ok, 2} = Gating.duplicate_gates(section, section2)

      gcs = Gating.list_gating_conditions(section2.id)
      assert Enum.count(gcs) == 2
      dupe = Enum.find(gcs, &(&1.resource_id == gate.resource_id))
      assert dupe.resource_id == gate.resource_id
      assert dupe.type == gate.type
      assert dupe.graded_resource_policy == gate.graded_resource_policy
      assert dupe.data == gate.data
      assert is_nil(dupe.parent_id)
      assert is_nil(dupe.user_id)

      assert Enum.any?(gcs, &(&1.resource_id == second_gate.resource_id))
    end

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

    test "list_gating_conditions/3 returns all gating_conditions for a given section, user and list of resource_ids",
         %{
           container: %{resource: container_resource},
           page1: page1,
           page2: page2,
           section_1: section,
           user_a: user_a,
           user_b: user_b
         } do
      _gc_1 =
        gating_condition_fixture(%{
          section_id: section.id,
          user_id: user_a.id,
          resource_id: container_resource.id
        })

      _gc_2 =
        gating_condition_fixture(%{section_id: section.id, resource_id: container_resource.id})

      gc_3 =
        gating_condition_fixture(%{
          section_id: section.id,
          user_id: user_a.id,
          resource_id: page1.id
        })

      gc_4 = gating_condition_fixture(%{section_id: section.id, resource_id: page1.id})

      _gc_5 =
        gating_condition_fixture(%{
          section_id: section.id,
          user_id: user_b.id,
          resource_id: page1.id
        })

      _gc_6 = gating_condition_fixture(%{section_id: section.id, resource_id: page2.id})

      gcs = Gating.list_gating_conditions(section.id, user_a.id, [page1.id])

      # ensure all defined gating conditions for section are returned
      assert Enum.count(gcs) == 2
      assert Enum.find(gcs, fn gc -> gc.id == gc_3.id end)
      assert Enum.find(gcs, fn gc -> gc.id == gc_4.id end)
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

      assert {:ok, %GatingCondition{}, 1} = Gating.delete_gating_condition(gating_condition)

      assert_raise Ecto.NoResultsError, fn ->
        Gating.get_gating_condition!(gating_condition.id)
      end
    end

    test "delete_gating_condition/1 deletes the gating_condition and the exception", %{
      page1: page1,
      section_1: section,
      user_a: user
    } do
      gating_condition =
        gating_condition_fixture(%{section_id: section.id, resource_id: page1.id})

      gating_condition_fixture(%{
        section_id: section.id,
        resource_id: page1.id,
        parent_id: gating_condition.id,
        user_id: user.id
      })

      assert {:ok, %GatingCondition{}, 2} = Gating.delete_gating_condition(gating_condition)

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

    test "blocked_by/3 returns empty list if all ancestor gating conditions pass", %{
      unit1_container: %{resource: unit1},
      page1: page1,
      nested_page1: nested_page1,
      nested_page2: nested_page2,
      page2: page2,
      section_1: section,
      user_a: user_a
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
      assert Gating.blocked_by(section, user_a, page1.id) == []

      # check nested resource that has gating condition defined for itself and its container
      assert Gating.blocked_by(section, user_a, nested_page1.id) == []

      # check for a resource that is gated and condition is not satisfied
      refute Gating.blocked_by(section, user_a, nested_page2.id) == []

      # change unit to have ended yesterday, check that nested resource is now gated properly
      Gating.update_gating_condition(unit_gating_condition, %{
        data: %{end_datetime: yesterday()}
      })

      # nested resource should no longer be accessible since unit is gated by a schedule that ended yesterday
      refute Gating.blocked_by(section, user_a, nested_page1.id) == []
    end

    test "blocked_by/3 allows student exception to override an otherwise active gate", %{
      page2: page2,
      section_1: section,
      user_a: user_a,
      user_b: user_b
    } do
      # Create a situation where a resource is gated for all students, but overridden (and bypassed) by
      # a student specific gate
      parent =
        gating_condition_fixture(%{
          section_id: section.id,
          resource_id: page2.id,
          data: %{start_datetime: tomorrow()}
        })

      gating_condition_fixture(%{
        section_id: section.id,
        resource_id: page2.id,
        parent_id: parent.id,
        user_id: user_a.id,
        data: %{start_datetime: yesterday()}
      })

      {:ok, section} = Gating.update_resource_gating_index(section)

      # check resource that has no gating condition defined for user_a, but it blocked for user_b
      assert Gating.blocked_by(section, user_a, page2.id) == []
      refute Gating.blocked_by(section, user_b, page2.id) == []
    end

    test "blocked_by/3 allows always_allow student exception to override an otherwise active gate",
         %{
           page2: page2,
           section_1: section,
           user_a: user_a,
           user_b: user_b
         } do
      # Create a situation where a resource is gated for all students, but overridden by an always_open
      parent =
        gating_condition_fixture(%{
          section_id: section.id,
          resource_id: page2.id,
          data: %{start_datetime: tomorrow()}
        })

      gating_condition_fixture(%{
        section_id: section.id,
        resource_id: page2.id,
        parent_id: parent.id,
        user_id: user_a.id,
        type: :always_open
      })

      {:ok, section} = Gating.update_resource_gating_index(section)

      # check resource that has no gating condition defined for user_a, but it blocked for user_b
      assert Gating.blocked_by(section, user_a, page2.id) == []
      refute Gating.blocked_by(section, user_b, page2.id) == []
    end

    test "blocked_by/3 allows always_open as a gate, but a student exception can be blocked",
         %{
           page2: page2,
           section_1: section,
           user_a: user_a,
           user_b: user_b
         } do
      # Create a situation where a resource is gated by :always_open, which allows all students to access it,
      # but then a student-specific exception exists that makes the resource unavailable to just that student
      parent =
        gating_condition_fixture(%{
          section_id: section.id,
          resource_id: page2.id,
          type: :always_open
        })

      gating_condition_fixture(%{
        section_id: section.id,
        resource_id: page2.id,
        parent_id: parent.id,
        user_id: user_a.id,
        data: %{start_datetime: tomorrow()}
      })

      {:ok, section} = Gating.update_resource_gating_index(section)

      # check resource that has no gating condition defined for user_b, but it blocked for user_a
      refute Gating.blocked_by(section, user_a, page2.id) == []
      assert Gating.blocked_by(section, user_b, page2.id) == []
    end

    test "source_page_resource_map/1 returns MapSet of resource IDs used as source pages",
         %{page1: page1, page2: page2, section_1: section} do
      # Create gating conditions where page1 is used as source for page2
      gating_condition_fixture(%{
        section_id: section.id,
        resource_id: page2.id,
        type: :started,
        data: %{resource_id: page1.id}
      })

      # Create another gating condition where page2 is used as source for page1
      gating_condition_fixture(%{
        section_id: section.id,
        resource_id: page1.id,
        type: :finished,
        data: %{resource_id: page2.id}
      })

      source_page_resource_ids = Gating.source_page_resource_map(section.id)

      # Both page1 and page2 should be in the MapSet
      assert MapSet.member?(source_page_resource_ids, page1.id)
      assert MapSet.member?(source_page_resource_ids, page2.id)
    end

    test "source_page_resource_map/1 returns empty MapSet when no gating conditions exist",
         %{section_1: section} do
      source_page_resource_ids = Gating.source_page_resource_map(section.id)

      # Should be empty when no gating conditions exist
      assert MapSet.size(source_page_resource_ids) == 0
    end
  end
end
