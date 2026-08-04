defmodule Oli.Delivery.Experiments.RewardHandoffWorkerTest do
  use Oli.DataCase
  use Oban.Testing, repo: Oli.Repo

  alias Oli.Delivery.Experiments.RewardHandoffWorker

  test "enqueues only one job per evaluated activity attempt" do
    assert :ok = RewardHandoffWorker.enqueue(123)
    assert :ok = RewardHandoffWorker.enqueue(123)

    assert [%Oban.Job{}] =
             all_enqueued(worker: RewardHandoffWorker, args: %{"activity_attempt_ids" => [123]})
  end

  test "normalizes a batch and treats missing activity attempts as a completed no-op" do
    assert :ok = RewardHandoffWorker.enqueue([3, 1, 3, "invalid"])

    assert_enqueued(
      worker: RewardHandoffWorker,
      args: %{"activity_attempt_ids" => [1, 3]}
    )

    assert :ok = perform_job(RewardHandoffWorker, %{"activity_attempt_ids" => [-2, -1]})
  end
end
