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

    try do
      case Mailer.deliver(email) do
        {:ok, _meta} ->
          :telemetry.execute(@succeeded, %{}, metadata)
          :ok

        {:error, reason} ->
          :telemetry.execute(
            @failed,
            %{},
            Map.put(metadata, :reason, inspect(reason, limit: 50, printable_limit: 200))
          )

          {:error, reason}
      end
    rescue
      exception ->
        :telemetry.execute(
          @failed,
          %{},
          Map.put(metadata, :reason, inspect(exception, limit: 50, printable_limit: 200))
        )

        reraise(exception, __STACKTRACE__)
    end
  end

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
