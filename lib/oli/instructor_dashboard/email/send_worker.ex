defmodule Oli.InstructorDashboard.Email.SendWorker do
  @moduledoc """
  Oban worker that delivers one per-recipient instructor email. Dedup is
  enforced via `unique: [keys: [:draft_id, :user_id], ...]`; telemetry is
  emitted per attempt under `[:oli, :instructor_dashboard, :email, :send, *]`.
  """

  use Oban.Worker,
    queue: :mailer,
    max_attempts: 3,
    unique: [
      keys: [:draft_id, :user_id],
      states: [:available, :scheduled, :retryable],
      period: :infinity
    ]

  alias Oli.Mailer
  alias Oli.Mailer.SendEmailWorker

  @attempted [:oli, :instructor_dashboard, :email, :send, :attempted]
  @succeeded [:oli, :instructor_dashboard, :email, :send, :succeeded]
  @failed [:oli, :instructor_dashboard, :email, :send, :failed]

  @impl Oban.Worker
  def perform(%Oban.Job{args: args, attempt: attempt}) do
    metadata = base_metadata(args, attempt)

    :telemetry.execute(@attempted, %{}, metadata)

    email = SendEmailWorker.deserialize_email(args["email"])

    case Mailer.deliver(email) do
      {:ok, _meta} ->
        :telemetry.execute(@succeeded, %{}, metadata)
        :ok

      {:error, reason} ->
        # Do NOT inspect provider error reasons in telemetry — Swoosh/SES
        # payloads can contain SMTP response strings, headers, or auth
        # fragments. Emit only the coarse error category.
        :telemetry.execute(
          @failed,
          %{},
          Map.put(metadata, :error_category, classify_error(reason))
        )

        {:error, reason}
    end
  end

  # Unexpected exceptions (Mailer.deliver raising) propagate to Oban's job
  # runner, which marks the job as failed and applies the retry policy.
  # Oban emits `[:oban, :job, :exception]` telemetry natively for those
  # cases — no local rescue needed here.

  defp classify_error(:timeout), do: :timeout
  defp classify_error({:timeout, _}), do: :timeout
  defp classify_error(:nxdomain), do: :network
  defp classify_error(:econnrefused), do: :network
  defp classify_error(_), do: :delivery_error

  defp base_metadata(args, attempt) do
    %{
      section_id: args["section_id"],
      draft_id: args["draft_id"],
      user_id: args["user_id"],
      situation_key: args["situation_key"],
      attempt: attempt
    }
  end
end
