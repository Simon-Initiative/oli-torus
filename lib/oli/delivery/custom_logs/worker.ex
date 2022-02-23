defmodule Oli.Delivery.CustomLogs.Worker do
  use Oban.Worker, queue: :custom_activity_logs, max_attempts: 3

  import Ecto.Query, warn: false
  alias Oli.Repo
  alias Oli.Resources.Revision

  alias Oli.Delivery.Attempts.Core.{
    ResourceAccess,
    ResourceAttempt,
    ActivityAttempt
    }

  import Oli.Delivery.CustomLogs.Utils

  @moduledoc """
  An Oban worker driven activity log creator.

  If the job fails, it will be retried up to a total of the configured maximum attempts.
  """

  @impl Oban.Worker
  def perform(
        %Oban.Job{
          args: %{
            "activity_attempt_guid" => activity_attempt_guid,
            "action" => action,
            "info" => info
          }
        }
      ) do
    perform_now(activity_attempt_guid, action, info)
  end

  @doc """
  Allows immediate execution of the activity log creation logic. Used to bypass queueing during testing scenarios.
  """
  def perform_now(activity_attempt_guid, action, info) do
    # Fetch all the necessary context information to be able to create activity log
    result =
      from(
        aa in ActivityAttempt,
        join: ra in ResourceAttempt,
        on: aa.resource_attempt_id == ra.id,
        join: a in ResourceAccess,
        on: ra.resource_access_id == a.id,
        join: r1 in Revision,
        on: ra.revision_id == r1.id,
        join: r2 in Revision,
        on: aa.revision_id == r2.id,
        where: aa.attempt_guid == ^activity_attempt_guid,
        select: {aa, ra, a, r1, r2}
      )
      |> Repo.one()

    # Return the value of the result of the transaction as the Oban worker return value. The
    # transaction call will return  either {:ok, _} or {:error, _}. In the case of the {:ok, _} Oban
    # marks the job as completed.  In the case of an error, it scheduled it for a retry.

    Repo.transaction(
      fn ->
        to_attrs(result, action, info)
        |> create_activity_log()
      end
    )
  end

  def to_attrs(
        {
          activity_attempt,
          _resource_attempt,
          resource_access,
          _resource_revision,
          activity_revision
        },
        action,
        info
      ) do
    activity_revision = Repo.preload(activity_revision, :activity_type)
    now =
      DateTime.utc_now()
      |> DateTime.truncate(:second)

    %{
      resource_id: resource_access.resource_id,
      section_id: resource_access.section_id,
      user_id: resource_access.user_id,
      activity_attempt_id: activity_attempt.id,
      revision_id: activity_attempt.revision_id,
      attempt_number: activity_attempt.attempt_number,
      activity_type: activity_revision.activity_type.slug,
      action: action,
      info: info,
      inserted_at: now,
      updated_at: now
    }
  end
end
