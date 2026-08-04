defmodule Oli.Delivery.Experiments.RewardHandoffWorkerTest do
  use Oli.DataCase
  use Oban.Testing, repo: Oli.Repo

  alias Oli.Delivery.Experiments.RewardHandoffWorker

  test "enqueues only one job per evaluated activity attempt" do
    assert :ok = RewardHandoffWorker.enqueue(123)
    assert :ok = RewardHandoffWorker.enqueue(123)

    assert [%Oban.Job{}] =
             all_enqueued(worker: RewardHandoffWorker, args: %{"activity_attempt_id" => 123})
  end

  test "treats a missing activity attempt as a completed no-op" do
    assert :ok = perform_job(RewardHandoffWorker, %{"activity_attempt_id" => -1})
  end
end
