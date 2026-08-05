defmodule Oli.Delivery.Attempts.ActivityLifecycle.PersistenceTest do
  use Oli.DataCase, async: true

  alias Oli.Delivery.Attempts.ActivityLifecycle.Persistence

  test "bulk_update_activity_attempts/2 returns an empty ID list when there is nothing to update" do
    assert {:ok, []} = Persistence.bulk_update_activity_attempts("", [])
  end
end
