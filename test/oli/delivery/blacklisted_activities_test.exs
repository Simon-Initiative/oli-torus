defmodule Oli.Delivery.BlacklistedActivitiesTest do
  @moduledoc """
  Comprehensive unit tests for the BlacklistedActivities context module.

  This module tests all public functions in Oli.Delivery.BlacklistedActivities
  which manages blacklisting of activities within course sections.

  Activity IDs and Selection IDs are weak references (not foreign keys),
  so simple test values like numbers and strings can be used.
  """

  use Oli.DataCase

  import Oli.Factory

  alias Oli.Delivery.BlacklistedActivities
  alias Oli.Delivery.BlacklistedActivity

  describe "get_blacklisted_activity_ids/2" do
    @doc """
    Tests retrieving blacklisted activity IDs for a specific section and selection.
    Should return only the activity IDs (not full records) for the given combination.
    """
    test "returns activity IDs for a specific section and selection" do
      # Create multiple sections to ensure proper filtering
      section1 = insert(:section)
      section2 = insert(:section)

      # Add blacklisted activities for section1 with selection "A"
      {:ok, _} = BlacklistedActivities.add_to_blacklist(section1.id, "A", 1)
      {:ok, _} = BlacklistedActivities.add_to_blacklist(section1.id, "A", 2)
      {:ok, _} = BlacklistedActivities.add_to_blacklist(section1.id, "A", 3)

      # Add blacklisted activities for section1 with different selection "B"
      {:ok, _} = BlacklistedActivities.add_to_blacklist(section1.id, "B", 4)
      {:ok, _} = BlacklistedActivities.add_to_blacklist(section1.id, "B", 5)

      # Add blacklisted activities for section2 with selection "A"
      {:ok, _} = BlacklistedActivities.add_to_blacklist(section2.id, "A", 6)
      {:ok, _} = BlacklistedActivities.add_to_blacklist(section2.id, "A", 7)

      # Test retrieval for section1, selection "A"
      activity_ids = BlacklistedActivities.get_blacklisted_activity_ids(section1.id, "A")
      assert length(activity_ids) == 3
      assert Enum.sort(activity_ids) == [1, 2, 3]

      # Test retrieval for section1, selection "B"
      activity_ids = BlacklistedActivities.get_blacklisted_activity_ids(section1.id, "B")
      assert length(activity_ids) == 2
      assert Enum.sort(activity_ids) == [4, 5]

      # Test retrieval for section2, selection "A"
      activity_ids = BlacklistedActivities.get_blacklisted_activity_ids(section2.id, "A")
      assert length(activity_ids) == 2
      assert Enum.sort(activity_ids) == [6, 7]

      # Test empty result for non-existent combination
      activity_ids = BlacklistedActivities.get_blacklisted_activity_ids(section2.id, "B")
      assert activity_ids == []
    end
  end

  describe "get_blacklisted_activities/1" do
    @doc """
    Tests retrieving all blacklisted activities for an entire section.
    Should return full BlacklistedActivity records for all selections in the section.
    """
    test "returns all blacklisted activities for a section across all selections" do
      section1 = insert(:section)
      section2 = insert(:section)

      # Add blacklisted activities for section1 with various selections
      {:ok, _} = BlacklistedActivities.add_to_blacklist(section1.id, "A", 1)
      {:ok, _} = BlacklistedActivities.add_to_blacklist(section1.id, "A", 2)
      {:ok, _} = BlacklistedActivities.add_to_blacklist(section1.id, "B", 3)
      {:ok, _} = BlacklistedActivities.add_to_blacklist(section1.id, "C", 4)

      # Add blacklisted activities for section2
      {:ok, _} = BlacklistedActivities.add_to_blacklist(section2.id, "A", 5)

      # Test retrieval for section1
      activities = BlacklistedActivities.get_blacklisted_activities(section1.id)
      assert length(activities) == 4

      # Verify all activities belong to section1
      assert Enum.all?(activities, fn a -> a.section_id == section1.id end)

      # Verify we have the expected activity IDs
      activity_ids = Enum.map(activities, & &1.activity_id) |> Enum.sort()
      assert activity_ids == [1, 2, 3, 4]

      # Test retrieval for section2
      activities = BlacklistedActivities.get_blacklisted_activities(section2.id)
      assert length(activities) == 1
      assert hd(activities).activity_id == 5

      # Test empty result for section with no blacklisted activities
      section3 = insert(:section)
      activities = BlacklistedActivities.get_blacklisted_activities(section3.id)
      assert activities == []
    end
  end

  describe "is_blacklisted?/3" do
    @doc """
    Tests checking if a specific activity is blacklisted for a section and selection.
    Should return true if blacklisted, false otherwise.
    """
    test "correctly identifies blacklisted and non-blacklisted activities" do
      section1 = insert(:section)
      section2 = insert(:section)

      # Add some blacklisted activities
      {:ok, _} = BlacklistedActivities.add_to_blacklist(section1.id, "A", 1)
      {:ok, _} = BlacklistedActivities.add_to_blacklist(section1.id, "B", 2)
      {:ok, _} = BlacklistedActivities.add_to_blacklist(section2.id, "A", 1)

      # Test positive cases
      assert BlacklistedActivities.is_blacklisted?(section1.id, "A", 1) == true
      assert BlacklistedActivities.is_blacklisted?(section1.id, "B", 2) == true
      assert BlacklistedActivities.is_blacklisted?(section2.id, "A", 1) == true

      # Test negative cases - different activity
      assert BlacklistedActivities.is_blacklisted?(section1.id, "A", 2) == false
      assert BlacklistedActivities.is_blacklisted?(section1.id, "B", 1) == false

      # Test negative cases - different selection
      assert BlacklistedActivities.is_blacklisted?(section1.id, "C", 1) == false

      # Test negative cases - different section
      assert BlacklistedActivities.is_blacklisted?(section2.id, "B", 2) == false

      # Test negative cases - non-existent combinations
      section3 = insert(:section)
      assert BlacklistedActivities.is_blacklisted?(section3.id, "A", 1) == false
    end
  end

  describe "toggle_blacklist/3" do
    @doc """
    Tests toggling the blacklist status of an activity.
    Should add to blacklist if not present, remove if present.
    """
    test "toggles activity blacklist status correctly" do
      section = insert(:section)

      # Initially, activity should not be blacklisted
      assert BlacklistedActivities.is_blacklisted?(section.id, "A", 1) == false

      # First toggle should add to blacklist
      assert {:ok, :added} = BlacklistedActivities.toggle_blacklist(section.id, "A", 1)
      assert BlacklistedActivities.is_blacklisted?(section.id, "A", 1) == true

      # Second toggle should remove from blacklist
      assert {:ok, :removed} = BlacklistedActivities.toggle_blacklist(section.id, "A", 1)
      assert BlacklistedActivities.is_blacklisted?(section.id, "A", 1) == false

      # Third toggle should add again
      assert {:ok, :added} = BlacklistedActivities.toggle_blacklist(section.id, "A", 1)
      assert BlacklistedActivities.is_blacklisted?(section.id, "A", 1) == true
    end

    test "toggles independently for different sections and selections" do
      section1 = insert(:section)
      section2 = insert(:section)

      # Toggle for section1, selection A, activity 1
      assert {:ok, :added} = BlacklistedActivities.toggle_blacklist(section1.id, "A", 1)

      # Verify only this specific combination is blacklisted
      assert BlacklistedActivities.is_blacklisted?(section1.id, "A", 1) == true
      assert BlacklistedActivities.is_blacklisted?(section1.id, "B", 1) == false
      assert BlacklistedActivities.is_blacklisted?(section2.id, "A", 1) == false

      # Toggle for section2, selection A, activity 1 (same activity, different section)
      assert {:ok, :added} = BlacklistedActivities.toggle_blacklist(section2.id, "A", 1)

      # Both should now be blacklisted independently
      assert BlacklistedActivities.is_blacklisted?(section1.id, "A", 1) == true
      assert BlacklistedActivities.is_blacklisted?(section2.id, "A", 1) == true

      # Toggle off for section1 shouldn't affect section2
      assert {:ok, :removed} = BlacklistedActivities.toggle_blacklist(section1.id, "A", 1)
      assert BlacklistedActivities.is_blacklisted?(section1.id, "A", 1) == false
      assert BlacklistedActivities.is_blacklisted?(section2.id, "A", 1) == true
    end
  end

  describe "add_to_blacklist/3" do
    @doc """
    Tests adding an activity to the blacklist.
    Should handle duplicate additions gracefully (idempotent).
    """
    test "adds activity to blacklist successfully" do
      section = insert(:section)

      # Add activity to blacklist
      assert {:ok, %BlacklistedActivity{} = activity} =
               BlacklistedActivities.add_to_blacklist(section.id, "A", 1)

      assert activity.section_id == section.id
      assert activity.selection_id == "A"
      assert activity.activity_id == 1

      # Verify it's actually blacklisted
      assert BlacklistedActivities.is_blacklisted?(section.id, "A", 1) == true
    end

    test "handles duplicate additions gracefully (idempotent)" do
      section = insert(:section)

      # Add activity to blacklist
      assert {:ok, _} = BlacklistedActivities.add_to_blacklist(section.id, "A", 1)

      # Adding same activity again should not error (on_conflict: :nothing)
      assert {:ok, _} = BlacklistedActivities.add_to_blacklist(section.id, "A", 1)

      # Should still only have one entry
      activities = BlacklistedActivities.list_blacklisted_activities(section.id, "A")
      assert length(activities) == 1
    end

    test "adds multiple different activities independently" do
      section = insert(:section)

      # Add multiple different activities
      assert {:ok, _} = BlacklistedActivities.add_to_blacklist(section.id, "A", 1)
      assert {:ok, _} = BlacklistedActivities.add_to_blacklist(section.id, "A", 2)
      assert {:ok, _} = BlacklistedActivities.add_to_blacklist(section.id, "B", 1)
      assert {:ok, _} = BlacklistedActivities.add_to_blacklist(section.id, "B", 3)

      # Verify all are blacklisted
      assert BlacklistedActivities.is_blacklisted?(section.id, "A", 1) == true
      assert BlacklistedActivities.is_blacklisted?(section.id, "A", 2) == true
      assert BlacklistedActivities.is_blacklisted?(section.id, "B", 1) == true
      assert BlacklistedActivities.is_blacklisted?(section.id, "B", 3) == true

      # Verify counts
      assert length(BlacklistedActivities.get_blacklisted_activity_ids(section.id, "A")) == 2
      assert length(BlacklistedActivities.get_blacklisted_activity_ids(section.id, "B")) == 2
    end
  end

  describe "remove_from_blacklist/3" do
    @doc """
    Tests removing an activity from the blacklist.
    Should handle removal of non-existent entries gracefully.
    """
    test "removes activity from blacklist successfully" do
      section = insert(:section)

      # Add activity to blacklist
      {:ok, _} = BlacklistedActivities.add_to_blacklist(section.id, "A", 1)
      assert BlacklistedActivities.is_blacklisted?(section.id, "A", 1) == true

      # Remove from blacklist
      {count, _} = BlacklistedActivities.remove_from_blacklist(section.id, "A", 1)
      assert count == 1

      # Verify it's no longer blacklisted
      assert BlacklistedActivities.is_blacklisted?(section.id, "A", 1) == false
    end

    test "handles removal of non-existent entries gracefully" do
      section = insert(:section)

      # Try to remove non-existent entry
      {count, _} = BlacklistedActivities.remove_from_blacklist(section.id, "A", 1)
      assert count == 0

      # Should not error and activity should still not be blacklisted
      assert BlacklistedActivities.is_blacklisted?(section.id, "A", 1) == false
    end

    test "removes only specific activity without affecting others" do
      section = insert(:section)

      # Add multiple activities
      {:ok, _} = BlacklistedActivities.add_to_blacklist(section.id, "A", 1)
      {:ok, _} = BlacklistedActivities.add_to_blacklist(section.id, "A", 2)
      {:ok, _} = BlacklistedActivities.add_to_blacklist(section.id, "B", 1)

      # Remove only one specific activity
      BlacklistedActivities.remove_from_blacklist(section.id, "A", 1)

      # Verify only that one was removed
      assert BlacklistedActivities.is_blacklisted?(section.id, "A", 1) == false
      assert BlacklistedActivities.is_blacklisted?(section.id, "A", 2) == true
      assert BlacklistedActivities.is_blacklisted?(section.id, "B", 1) == true
    end
  end

  describe "list_blacklisted_activities/2" do
    @doc """
    Tests retrieving full blacklisted activity records for a section and selection.
    Should return complete BlacklistedActivity structs with all fields.
    """
    test "returns full activity records for section and selection" do
      section = insert(:section)

      # Add blacklisted activities
      {:ok, _} = BlacklistedActivities.add_to_blacklist(section.id, "A", 1)
      {:ok, _} = BlacklistedActivities.add_to_blacklist(section.id, "A", 2)
      {:ok, _} = BlacklistedActivities.add_to_blacklist(section.id, "B", 3)

      # Get activities for selection "A"
      activities = BlacklistedActivities.list_blacklisted_activities(section.id, "A")
      assert length(activities) == 2

      # Verify full records are returned
      Enum.each(activities, fn activity ->
        assert %BlacklistedActivity{} = activity
        assert activity.section_id == section.id
        assert activity.selection_id == "A"
        assert activity.activity_id in [1, 2]
        assert activity.inserted_at != nil
        assert activity.updated_at != nil
      end)

      # Get activities for selection "B"
      activities = BlacklistedActivities.list_blacklisted_activities(section.id, "B")
      assert length(activities) == 1
      assert hd(activities).activity_id == 3

      # Empty result for non-existent selection
      activities = BlacklistedActivities.list_blacklisted_activities(section.id, "C")
      assert activities == []
    end

    test "returns empty list for section with no blacklisted activities" do
      section = insert(:section)

      activities = BlacklistedActivities.list_blacklisted_activities(section.id, "A")
      assert activities == []
    end
  end

  describe "bulk_update_blacklist/3" do
    @doc """
    Tests bulk updating blacklisted activities for a section.
    Should replace all existing blacklisted activities with the provided list.
    This function uses a transaction to ensure atomicity.
    """
    test "replaces all blacklisted activities for a section" do
      section = insert(:section)

      # Add initial blacklisted activities
      {:ok, _} = BlacklistedActivities.add_to_blacklist(section.id, "A", 1)
      {:ok, _} = BlacklistedActivities.add_to_blacklist(section.id, "A", 2)
      {:ok, _} = BlacklistedActivities.add_to_blacklist(section.id, "B", 3)

      # Verify initial state
      assert length(BlacklistedActivities.get_blacklisted_activities(section.id)) == 3

      # Bulk update with new list (note: this replaces ALL activities for the section)
      {:ok, _} = BlacklistedActivities.bulk_update_blacklist(section.id, "C", [4, 5, 6])

      # Verify all old activities are removed and new ones are added
      activities = BlacklistedActivities.get_blacklisted_activities(section.id)
      assert length(activities) == 3

      activity_ids = Enum.map(activities, & &1.activity_id) |> Enum.sort()
      assert activity_ids == [4, 5, 6]

      # All should have the new selection_id
      assert Enum.all?(activities, fn a -> a.selection_id == "C" end)

      # Old activities should not be blacklisted
      assert BlacklistedActivities.is_blacklisted?(section.id, "A", 1) == false
      assert BlacklistedActivities.is_blacklisted?(section.id, "A", 2) == false
      assert BlacklistedActivities.is_blacklisted?(section.id, "B", 3) == false
    end

    test "handles empty list by removing all blacklisted activities" do
      section = insert(:section)

      # Add initial blacklisted activities
      {:ok, _} = BlacklistedActivities.add_to_blacklist(section.id, "A", 1)
      {:ok, _} = BlacklistedActivities.add_to_blacklist(section.id, "A", 2)

      # Bulk update with empty list
      {:ok, _} = BlacklistedActivities.bulk_update_blacklist(section.id, "A", [])

      # Verify all activities are removed
      activities = BlacklistedActivities.get_blacklisted_activities(section.id)
      assert activities == []
    end

    test "bulk update is atomic - transaction rollback on error" do
      section1 = insert(:section)
      section2 = insert(:section)

      # Add activities to section1
      {:ok, _} = BlacklistedActivities.add_to_blacklist(section1.id, "A", 1)
      {:ok, _} = BlacklistedActivities.add_to_blacklist(section1.id, "A", 2)

      # Add activities to section2 (should not be affected)
      {:ok, _} = BlacklistedActivities.add_to_blacklist(section2.id, "B", 3)

      # Perform bulk update for section1
      {:ok, _} = BlacklistedActivities.bulk_update_blacklist(section1.id, "C", [10, 11])

      # Verify section1 was updated
      activities1 = BlacklistedActivities.get_blacklisted_activities(section1.id)
      assert length(activities1) == 2
      assert Enum.map(activities1, & &1.activity_id) |> Enum.sort() == [10, 11]

      # Verify section2 was not affected
      activities2 = BlacklistedActivities.get_blacklisted_activities(section2.id)
      assert length(activities2) == 1
      assert hd(activities2).activity_id == 3
    end

    test "preserves timestamps correctly in bulk update" do
      section = insert(:section)

      # Perform bulk update
      {:ok, _} = BlacklistedActivities.bulk_update_blacklist(section.id, "A", [1, 2])

      # Get the activities and check timestamps
      activities = BlacklistedActivities.get_blacklisted_activities(section.id)

      Enum.each(activities, fn activity ->
        assert activity.inserted_at != nil
        assert activity.updated_at != nil
        # Timestamps should be very recent (within last second)
        assert DateTime.diff(DateTime.utc_now(), activity.inserted_at) < 1
      end)
    end
  end

  describe "edge cases and comprehensive scenarios" do
    @doc """
    Tests various edge cases and complex scenarios to ensure robustness.
    """
    test "handles large numbers of activities efficiently" do
      section = insert(:section)
      activity_ids = Enum.to_list(1..100)

      # Bulk add many activities
      {:ok, _} = BlacklistedActivities.bulk_update_blacklist(section.id, "A", activity_ids)

      # Verify all were added
      retrieved_ids = BlacklistedActivities.get_blacklisted_activity_ids(section.id, "A")
      assert length(retrieved_ids) == 100
      assert Enum.sort(retrieved_ids) == activity_ids
    end

    test "handles various selection_id formats" do
      section = insert(:section)

      # Test with different selection_id formats
      test_cases = [
        {"simple", 1},
        {"with-dash", 2},
        {"with_underscore", 3},
        {"123numeric", 4},
        {"UPPERCASE", 5},
        {"mixed-Case_123", 6}
      ]

      Enum.each(test_cases, fn {selection_id, activity_id} ->
        {:ok, _} = BlacklistedActivities.add_to_blacklist(section.id, selection_id, activity_id)
        assert BlacklistedActivities.is_blacklisted?(section.id, selection_id, activity_id)
      end)

      # Verify total count
      assert length(BlacklistedActivities.get_blacklisted_activities(section.id)) == 6
    end

    test "multiple sections can have same activity blacklisted independently" do
      sections = insert_list(3, :section)

      # Each section blacklists the same activity IDs but with different selections
      Enum.with_index(sections, fn section, index ->
        selection_id = "Selection_#{index}"
        {:ok, _} = BlacklistedActivities.add_to_blacklist(section.id, selection_id, 1)
        {:ok, _} = BlacklistedActivities.add_to_blacklist(section.id, selection_id, 2)
      end)

      # Verify each section has its own independent blacklist
      Enum.with_index(sections, fn section, index ->
        selection_id = "Selection_#{index}"
        activities = BlacklistedActivities.list_blacklisted_activities(section.id, selection_id)
        assert length(activities) == 2
        assert Enum.all?(activities, fn a -> a.selection_id == selection_id end)
      end)
    end
  end
end
