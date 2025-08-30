defmodule Oli.Delivery.Snapshots.WorkerTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Delivery.Snapshots.Worker

  describe "perform_now/3" do
    test "returns :ok when part attempts are in :submitted state (not :evaluated)" do
      # Create the full hierarchy needed for the join query
      section = insert(:section)
      user = insert(:user)
      resource = insert(:resource)
      revision = insert(:revision, resource: resource)
      
      # Create resource access
      resource_access = insert(:resource_access, %{
        section: section,
        user: user,
        resource: resource
      })

      # Create resource attempt
      resource_attempt = insert(:resource_attempt, %{
        resource_access: resource_access,
        lifecycle_state: :evaluated
      })

      # Create activity attempt  
      activity_attempt = insert(:activity_attempt, %{
        resource_attempt: resource_attempt,
        revision: revision,
        lifecycle_state: :evaluated
      })

      # Create part attempt in :submitted state (not :evaluated)
      part_attempt = insert(:part_attempt, %{
        activity_attempt: activity_attempt,
        attempt_guid: "test-guid-123",
        lifecycle_state: :submitted  # This is the key - not :evaluated
      })

      # Call perform_now with the part attempt GUID and section slug
      result = Worker.perform_now([part_attempt.attempt_guid], section.slug)

      # Should return :ok because no evaluated part attempts were found
      assert result == :ok
    end

    test "returns :ok when part attempt guids list is empty" do
      section = insert(:section)
      
      result = Worker.perform_now([], section.slug)
      
      assert result == :ok
    end

    test "returns :ok when no part attempts match the guids" do
      section = insert(:section)
      
      # Call with non-existent GUIDs
      result = Worker.perform_now(["non-existent-guid"], section.slug)
      
      # Should return :ok because no evaluated part attempts were found
      assert result == :ok
    end
  end
end