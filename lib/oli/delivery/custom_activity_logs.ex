defmodule Oli.Delivery.CustomActivityLogs do

  @doc """
  If background async job execution is enabled, queue the creation of activity log records for
  exising activity attempt record guid. If background job execution is disabled, just create
  the activity log record.
  """
  def queue_or_create_activity_log(activity_attempt_guid, action, info) do
    case Application.fetch_env!(:oli, Oban) |> Keyword.get(:queues, []) do
      false ->
        Oli.Delivery.CustomLogs.Worker.perform_now(activity_attempt_guid, action, info)

      _ ->
        %{activity_attempt_guid: activity_attempt_guid, action: action, info: info}
        |> Oli.Delivery.CustomLogs.Worker.new()
        |> Oban.insert()
    end
  end
end
