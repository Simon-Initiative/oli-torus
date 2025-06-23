defmodule OliWeb.Api.LtiAgsController do
  use OliWeb, :controller

  alias Oli.Delivery.Attempts.Core

  require Logger

  plug OliWeb.Plugs.LtiAgsTokenValidator

  # GET /lti/lineitems/:activity_attempt_guid?user_id=...
  def get_result(conn, %{"activity_attempt_guid" => activity_attempt_guid, "user_id" => user_id}) do
    with {:ok, part_attempt} <-
           get_single_part_attempt_from_activity_attempt(activity_attempt_guid) do
      platform_url = Oli.Utils.get_base_url()

      json(conn, [
        %{
          "id" => "#{platform_url}/lineitems/#{activity_attempt_guid}/results/#{user_id}",
          "scoreOf" => "#{platform_url}/lineitems/#{activity_attempt_guid}",
          "userId" => user_id,
          "resultScore" => part_attempt.score,
          "resultMaximum" => part_attempt.out_of,
          "timestamp" => part_attempt.date_submitted
        }
        |> maybe_put_comment_from_part_attempt(part_attempt)
      ])
    else
      {:error, error} ->
        Logger.error("Error fetching result. #{error}")

        send_resp(conn, 400, "Error fetching result. #{error}")
    end
  end

  def get_result(conn, _params) do
    # If no user_id is provided, return an error
    send_resp(conn, 400, "Invalid request. 'user_id' parameter is required.")
  end

  defp maybe_put_comment_from_part_attempt(result, part_attempt) do
    case OliWeb.Common.Utils.extract_from_part_attempt(part_attempt) do
      [] -> result
      feedbacks -> Map.put(result, "comment", feedbacks |> Enum.join("\n"))
    end
  end

  # POST /lti/lineitems/:activity_attempt_guid
  def post_score(
        conn,
        %{
          "activity_attempt_guid" => activity_attempt_guid,
          "gradingProgress" => "NotReady",
          "activityProgress" => "Initialized"
        } = _params
      ) do
    with {:ok, _part_attempt} <-
           reset_active_attempt_score(activity_attempt_guid) do
      # Respond with 204 No Content per spec
      send_resp(conn, 204, "")
    else
      {:error, error} ->
        Logger.error("Error resetting score. #{error}")

        send_resp(conn, 400, "Error resetting score. #{error}")
    end
  end

  def post_score(
        conn,
        %{
          "activity_attempt_guid" => activity_attempt_guid,
          "userId" => _user_id,
          "scoreGiven" => score_given,
          "scoreMaximum" => score_maximum,
          "gradingProgress" => grading_progress,
          "timestamp" => timestamp
        } = params
      ) do
    with :ok <- validate_grading_progress(grading_progress),
         {:ok, _part_attempt} <-
           update_active_attempt_score(
             activity_attempt_guid,
             score_given,
             score_maximum,
             timestamp,
             params["comment"]
           ) do
      # Respond with 204 No Content per spec
      send_resp(conn, 204, "")
    else
      {:error, error} ->
        Logger.error("Error processing score. #{error}")

        send_resp(conn, 400, "Error processing score. #{error}")
    end
  end

  defp validate_grading_progress(grading_progress) do
    if(String.downcase(grading_progress) == "fullygraded",
      do: :ok,
      else: {:error, "Invalid score payload. \"gradingProgress\" must be \"FullyGraded\""}
    )
  end

  defp update_active_attempt_score(
         activity_attempt_guid,
         score_given,
         score_maximum,
         timestamp,
         comment
       ) do
    with {:ok, part_attempt} <-
           get_single_part_attempt_from_activity_attempt(activity_attempt_guid),
         :ok <- require_active_part_attempt(part_attempt),
         {:ok, date_submitted} <- validate_timestamp(part_attempt, timestamp) do
      # Update the activity attempt with the new score and timestamp
      Core.update_part_attempt(
        part_attempt,
        %{
          score: score_given,
          out_of: score_maximum,
          date_submitted: date_submitted
        }
        |> maybe_apply_feedback_from_comment(comment)
      )
    else
      error -> error
    end
  end

  defp require_active_part_attempt(part_attempt) do
    if part_attempt.lifecycle_state != :active do
      {:error, "Activity attempt is not active. Cannot update score."}
    else
      :ok
    end
  end

  defp validate_timestamp(part_attempt, timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, new_datetime, _offset} ->
        # The spec prescribes that the timestamp comparison should support sub-second precision, but our
        # part attempt database schema only stores the date at second precision.
        # Therefore, we must round the timestamp to the nearest second to ensure a proper comparison.
        new_datetime = DateTime.truncate(new_datetime, :second)

        # Ensure the new timestamp is later than the current date_submitted
        if is_nil(part_attempt.date_submitted) ||
             DateTime.compare(part_attempt.date_submitted, new_datetime) == :lt do
          {:ok, new_datetime}
        else
          {:error, "Timestamp must be later than the current date_submitted."}
        end

      {:error, _reason} ->
        {:error, "Invalid timestamp format. Expected ISO 8601 format."}
    end
  end

  defp reset_active_attempt_score(activity_attempt_guid) do
    # get part attempt guid using activity_attempt_guid. There should be only one part attempt
    case get_single_part_attempt_from_activity_attempt(activity_attempt_guid) do
      {:ok, part_attempt} ->
        # If the part attempt lifecycle_state is not active then reset the activity
        if part_attempt.lifecycle_state != :active do
          {:error, "Activity attempt is not active. Cannot reset score."}
        else
          # The part attempt is active, update the part attempt with the new attributes
          Core.update_part_attempt(part_attempt, %{
            score: nil,
            out_of: nil,
            date_submitted: nil,
            feedback: nil
          })
        end

      error ->
        error
    end
  end

  defp get_single_part_attempt_from_activity_attempt(activity_attempt_guid) do
    # get single part attempt using activity_attempt_guid. There should be only one part attempt
    case Core.get_latest_part_attempts(activity_attempt_guid) do
      [part_attempt | _] ->
        {:ok, part_attempt}

      _ ->
        {:error,
         "Activity part attempt not found for activity attempt guid: #{activity_attempt_guid}"}
    end
  end

  defp maybe_apply_feedback_from_comment(attrs, nil), do: attrs
  defp maybe_apply_feedback_from_comment(attrs, ""), do: attrs

  defp maybe_apply_feedback_from_comment(attrs, comment),
    do: %{
      attrs
      | feedback: %{content: feedback_content(comment)}
    }

  defp feedback_content(text) do
    %{type: "p", children: [%{text: text}]}
  end
end
