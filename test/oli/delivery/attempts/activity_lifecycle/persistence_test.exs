defmodule Oli.Delivery.Attempts.ActivityLifecycle.PersistenceTest do
  use Oli.DataCase, async: true

  alias Oli.Delivery.Attempts.ActivityLifecycle.Persistence
  alias Oli.Delivery.Attempts.Core.PartAttempt
  alias Oli.Delivery.Evaluation.Actions.FeedbackAction

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

  describe "persist_evaluations/4 keeps every part score within its range" do
    defp persisted(score, out_of) do
      part_attempt = Oli.Factory.insert(:part_attempt)

      assert {:ok, _} =
               Persistence.persist_evaluations(
                 {:ok, [{:ok, %FeedbackAction{score: score, out_of: out_of, feedback: %{}}}]},
                 [%{attempt_guid: part_attempt.attempt_guid, input: %{}}],
                 & &1,
                 "session"
               )

      stored = Oli.Repo.get!(PartAttempt, part_attempt.id)
      {stored.score, stored.out_of}
    end

    test "a score below zero is stored as zero" do
      assert persisted(-3, 1) == {0.0, 1.0}
    end

    test "a score above the maximum is stored as the maximum" do
      assert persisted(7, 2) == {2.0, 2.0}
    end

    test "a maximum that is not above zero is stored as one" do
      assert persisted(0.5, 0) == {0.5, 1.0}
    end
  end
end
