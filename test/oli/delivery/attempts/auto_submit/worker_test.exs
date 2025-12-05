defmodule Oli.Delivery.Attempts.AutoSubmit.WorkerTest do
  use Oli.DataCase
  use Oban.Testing, repo: Oli.Repo

  alias Oli.Delivery.Attempts.AutoSubmit.Worker
  alias Oli.Delivery.Attempts.Core.ResourceAttempt
  alias Oli.Delivery.Settings.Combined

  describe "maybe_schedule_auto_submit/4" do
    test "schedules a job when there is a due_by deadline" do
      attempt = %ResourceAttempt{
        attempt_guid: "attempt-guid",
        inserted_at: DateTime.utc_now()
      }

      settings = %Combined{
        scheduling_type: :due_by,
        end_date: DateTime.add(DateTime.utc_now(), 3600, :second),
        time_limit: 0,
        grace_period: 0,
        late_submit: :disallow
      }

      assert {:ok, job_id} =
               Worker.maybe_schedule_auto_submit(settings, "section-slug", attempt, "datashop")

      assert job_id

      assert_enqueued(
        worker: Worker,
        args: %{
          "attempt_guid" => attempt.attempt_guid,
          "section_slug" => "section-slug",
          "datashop_session_id" => "datashop"
        }
      )
    end

    test "does not schedule when there is no due date and no time limit" do
      attempt = %ResourceAttempt{
        attempt_guid: "attempt-guid",
        inserted_at: DateTime.utc_now()
      }

      settings = %Combined{
        scheduling_type: :read_by,
        end_date: nil,
        time_limit: 0,
        late_submit: :disallow
      }

      assert {:ok, :not_scheduled} =
               Worker.maybe_schedule_auto_submit(settings, "section-slug", attempt, "datashop")

      refute_enqueued(worker: Worker, args: %{"attempt_guid" => attempt.attempt_guid})
    end

    test "does not schedule for suggested dates even when late policy disallows start" do
      attempt = %ResourceAttempt{
        attempt_guid: "attempt-guid",
        inserted_at: DateTime.utc_now()
      }

      settings = %Combined{
        scheduling_type: :read_by,
        end_date: DateTime.add(DateTime.utc_now(), 3600, :second),
        time_limit: 0,
        late_start: :disallow,
        late_submit: :disallow
      }

      assert {:ok, :not_scheduled} =
               Worker.maybe_schedule_auto_submit(settings, "section-slug", attempt, "datashop")

      refute_enqueued(worker: Worker, args: %{"attempt_guid" => attempt.attempt_guid})
    end

    test "does not schedule when the deadline is already in the past" do
      attempt = %ResourceAttempt{
        attempt_guid: "attempt-guid",
        inserted_at: DateTime.utc_now()
      }

      settings = %Combined{
        scheduling_type: :due_by,
        end_date: DateTime.add(DateTime.utc_now(), -3600, :second),
        time_limit: 0,
        grace_period: 0,
        late_submit: :disallow
      }

      assert {:ok, :not_scheduled} =
               Worker.maybe_schedule_auto_submit(settings, "section-slug", attempt, "datashop")

      refute_enqueued(worker: Worker, args: %{"attempt_guid" => attempt.attempt_guid})
    end
  end
end
