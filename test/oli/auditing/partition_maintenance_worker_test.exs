defmodule Oli.Auditing.PartitionMaintenanceWorkerTest do
  use Oli.DataCase, async: false
  use Oban.Testing, repo: Oli.Repo

  alias Oli.Auditing.{PartitionMaintenanceWorker, Partitions}

  test "keeps four future half-years provisioned" do
    assert :ok = perform_job(PartitionMaintenanceWorker, %{})
    assert {:ok, %{future_intervals: future}} = Partitions.status()
    assert future >= 4
  end

  test "is scheduled monthly at 08:00 UTC in both Oban configurations" do
    for path <- ["config/config.exs", "config/runtime.exs"] do
      assert File.read!(path) =~
               ~s({"0 8 1 * *", Oli.Auditing.PartitionMaintenanceWorker, queue: :default}),
             "#{path} does not schedule the partition maintenance worker"
    end
  end
end
