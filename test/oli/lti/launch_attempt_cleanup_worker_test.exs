defmodule Oli.Lti.LaunchAttemptCleanupWorkerTest do
  use Oli.DataCase
  use Oban.Testing, repo: Oli.Repo

  import Oli.Factory

  alias Oli.Lti.LaunchAttempt
  alias Oli.Lti.LaunchAttemptCleanupWorker
  alias Oli.Repo

  describe "schedule_cleanup/0" do
    test "enqueues the cleanup worker" do
      assert {:ok, _job} = LaunchAttemptCleanupWorker.schedule_cleanup()

      assert_enqueued(worker: LaunchAttemptCleanupWorker, args: %{})
    end
  end

  describe "perform/1" do
    test "cleans up expired launch attempts" do
      expired_attempt =
        insert(:lti_launch_attempt,
          expires_at:
            DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.add(-5, :second)
        )

      assert :ok = LaunchAttemptCleanupWorker.perform(%Oban.Job{args: %{}})
      refute Repo.get(LaunchAttempt, expired_attempt.id)
    end
  end
end
