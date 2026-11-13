defmodule Oli.Auditing.PartitionMaintenanceWorker do
  @moduledoc """
  Monthly Oban cron job (08:00 UTC on the 1st) that keeps four future half-year partitions of
  `audit_log_events` provisioned. The migration provisions two years ahead, so many runs can
  fail before a partition is actually missing; `Oli.Auditing.Partitions.status/0` reports the
  remaining coverage.
  """

  use Oban.Worker, queue: :default, max_attempts: 3

  alias Oli.Auditing.Partitions

  @future_months 24

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    case Partitions.ensure_through(Date.shift(Date.utc_today(), month: @future_months)) do
      {:ok, _report} -> :ok
      {:error, error} -> {:error, error.code}
    end
  end
end
