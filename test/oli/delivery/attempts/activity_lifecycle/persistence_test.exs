defmodule Oli.Delivery.Attempts.ActivityLifecycle.PersistenceTest do
  use Oli.DataCase, async: true

  alias Oli.Delivery.Attempts.ActivityLifecycle.Persistence

  test "bulk_update_activity_attempts/2 returns an empty ID list when there is nothing to update" do
    assert {:ok, []} = Persistence.bulk_update_activity_attempts("", [])
  end

  test "bulk_update_activity_attempts/2 preserves the database result contract" do
    activity_attempt = Oli.Factory.insert(:activity_attempt)
    now = DateTime.utc_now()

    assert {:ok, %Postgrex.Result{num_rows: 1}} =
             Persistence.bulk_update_activity_attempts(
               "($1, $2::double precision, $3::double precision, $4, $5::timestamp, $6::timestamp)",
               [activity_attempt.attempt_guid, 1.0, 1.0, "evaluated", now, now]
             )
  end
end
