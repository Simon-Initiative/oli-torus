defmodule Oli.Lti.LaunchAttemptCleanupWorker do
  @moduledoc """
  Oban worker that deletes expired LTI launch attempts.
  """

  use Oban.Worker, queue: :default, max_attempts: 3, unique: [period: 60, fields: [:worker]]

  alias Oli.Lti.LaunchAttempts

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    {:ok, _count} = LaunchAttempts.cleanup_expired()
    :ok
  end

  @spec schedule_cleanup() :: {:ok, Oban.Job.t()} | {:error, Ecto.Changeset.t()}
  def schedule_cleanup do
    %{}
    |> new()
    |> Oban.insert()
  end
end
