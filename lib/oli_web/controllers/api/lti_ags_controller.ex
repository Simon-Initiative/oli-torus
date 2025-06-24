defmodule OliWeb.Api.LtiAgsController do
  use OliWeb, :controller

  alias Oli.Delivery.Sections.Section
  alias Oli.Accounts.User
  alias Oli.Delivery.Attempts.Core
  alias Oli.Delivery.Attempts.Core.{ClientEvaluation, ActivityAttempt}
  alias Oli.Delivery.Attempts.ActivityLifecycle.Evaluate

  require Logger

  plug OliWeb.Plugs.LtiAgsTokenValidator

  # GET /lti/lineitems/:activity_attempt_guid?user_id=...
  def get_result(conn, %{
        "page_attempt_guid" => page_attempt_guid,
        "activity_resource_id" => activity_resource_id,
        "user_id" => user_sub
      }) do
    with {:ok, user_id} <- get_user_id_from_sub(user_sub),
         %ActivityAttempt{
           score: score,
           out_of: out_of,
           date_submitted: date_submitted,
           part_attempts: [part_attempt | _]
         } <-
           Core.get_latest_activity_attempt_from_page_attempt(
             page_attempt_guid,
             activity_resource_id,
             user_id
           ) do
      platform_url = Oli.Utils.get_base_url()

      json(conn, [
        %{
          "id" =>
            "#{platform_url}/lineitems/#{page_attempt_guid}/#{activity_resource_id}/results/#{user_sub}",
          "scoreOf" => "#{platform_url}/lineitems/#{page_attempt_guid}/#{activity_resource_id}",
          "userId" => user_sub,
          "resultScore" => score,
          "resultMaximum" => out_of,
          "timestamp" => convert_to_iso8601(date_submitted)
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

  defp convert_to_iso8601(nil), do: nil

  defp convert_to_iso8601(datetime) do
    case DateTime.from_iso8601(datetime) do
      {:ok, dt, _offset} -> DateTime.to_iso8601(dt)
      {:error, _reason} -> nil
    end
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
          "page_attempt_guid" => page_attempt_guid,
          "activity_resource_id" => activity_resource_id,
          "userId" => user_sub,
          "activityProgress" => "Initialized",
          "gradingProgress" => "NotReady"
        } = _params
      ) do
    with datashop_session_id <- Plug.Conn.get_session(conn, :datashop_session_id),
         {:ok, user_id} <- get_user_id_from_sub(user_sub),
         latest_activity_attempt <-
           Core.get_latest_activity_attempt_from_page_attempt(
             page_attempt_guid,
             activity_resource_id,
             user_id
           ),
         {:ok, section_slug} <-
           get_section_slug_from_activity_attempt_guid(latest_activity_attempt.attempt_guid),
         {:ok, _new_activity_attempt_guid} <-
           reset_activity(section_slug, latest_activity_attempt.attempt_guid, datashop_session_id) do
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
          "page_attempt_guid" => page_attempt_guid,
          "activity_resource_id" => activity_resource_id,
          "userId" => user_sub,
          "scoreGiven" => score_given,
          "scoreMaximum" => score_maximum,
          "timestamp" => timestamp,
          "activityProgress" => "Completed",
          "gradingProgress" => "FullyGraded"
        } = params
      ) do
    with datashop_session_id <- Plug.Conn.get_session(conn, :datashop_session_id),
         {:ok, user_id} <- get_user_id_from_sub(user_sub),
         latest_activity_attempt <-
           Core.get_latest_activity_attempt_from_page_attempt(
             page_attempt_guid,
             activity_resource_id,
             user_id
           ),
         {:ok, activity_attempt} <-
           maybe_reset_activity_attempt(latest_activity_attempt, datashop_session_id),
         {:ok, timestamp} <- validate_attempt_timestamp(activity_attempt, timestamp),
         {:ok, section_slug} <-
           get_section_slug_from_activity_attempt_guid(activity_attempt.attempt_guid),
         {:ok, part_attempt} <-
           get_single_part_attempt_from_activity_attempt(activity_attempt),
         :ok <-
           apply_score(
             section_slug,
             activity_attempt.attempt_guid,
             part_attempt.attempt_guid,
             score_given,
             score_maximum,
             timestamp,
             params["comment"],
             datashop_session_id
           ) do
      # Respond with 204 No Content per spec
      send_resp(conn, 204, "")
    else
      {:error, error} ->
        Logger.error("Error processing score. #{error}")

        send_resp(conn, 400, "Error processing score. #{error}")
    end
  end

  def post_score(conn, _params) do
    # If the request does not match any of the expected patterns, return an error
    send_resp(
      conn,
      400,
      "Invalid request. Please check your parameters. \
    The request must include 'userId', 'gradingProgress', and 'activityProgress' or 'scoreGiven'."
    )
  end

  defp get_user_id_from_sub(user_sub) do
    case Oli.Accounts.get_user_by(sub: user_sub) do
      %User{id: user_id} -> {:ok, user_id}
      _ -> {:error, "Invalid user: #{user_sub}"}
    end
  end

  defp maybe_reset_activity_attempt(
         %ActivityAttempt{lifecycle_state: :active} = activity_attempt,
         _datashop_session_id
       ),
       do: {:ok, activity_attempt}

  defp maybe_reset_activity_attempt(
         %ActivityAttempt{attempt_guid: attempt_guid},
         datashop_session_id
       ) do
    # No active attempt found, create a new one
    with {:ok, section_slug} <-
           get_section_slug_from_activity_attempt_guid(attempt_guid),
         {:ok, new_activity_attempt_guid} <-
           reset_activity(section_slug, attempt_guid, datashop_session_id),
         new_activity_attempt <-
           Core.get_activity_attempt_by(attempt_guid: new_activity_attempt_guid) do
      {:ok, new_activity_attempt}
    else
      {:error, error} ->
        Logger.error("Error creating new activity attempt: #{error}")
        {:error, "Failed to create new activity attempt."}
    end
  end

  defp maybe_reset_activity_attempt(nil, _datashop_session_id),
    do: {:error, "No existing activity attempt found."}

  defp get_single_part_attempt_from_activity_attempt(%ActivityAttempt{
         part_attempts: [part_attempt | _]
       }),
       do: {:ok, part_attempt}

  defp get_single_part_attempt_from_activity_attempt(%ActivityAttempt{attempt_guid: attempt_guid}),
    do: {:error, "Activity part attempt not found for activity attempt guid: #{attempt_guid}"}

  defp get_section_slug_from_activity_attempt_guid(activity_attempt_guid) do
    case Core.get_section_by_activity_attempt_guid(activity_attempt_guid) do
      %Section{slug: section_slug} ->
        {:ok, section_slug}

      _ ->
        {:error, "Section not found for activity attempt guid: #{activity_attempt_guid}"}
    end
  end

  defp validate_attempt_timestamp(attempt, timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, timestamp_datetime, _offset} ->
        # The spec prescribes that the timestamp comparison should support sub-second precision, but our
        # part attempt database schema only stores the date at second precision.
        # Therefore, we must round the timestamp to the nearest second to ensure a proper comparison.
        timestamp_datetime = DateTime.truncate(timestamp_datetime, :second)

        # Ensure the new timestamp is later than the current date_submitted
        if is_nil(attempt.date_submitted) ||
             DateTime.compare(attempt.date_submitted, timestamp_datetime) == :lt do
          {:ok, timestamp_datetime}
        else
          {:error, "Timestamp must be later than the current date_submitted."}
        end

      {:error, _reason} ->
        {:error, "Invalid timestamp format. Expected ISO 8601 format."}
    end
  end

  defp reset_activity(
         section_slug,
         activity_attempt_guid,
         datashop_session_id
       ) do
    # reset the activity attempt and return the new activity and part attempt guids
    case Oli.Delivery.Attempts.ActivityLifecycle.reset_activity(
           section_slug,
           activity_attempt_guid,
           datashop_session_id
         ) do
      {:ok, {activity_state, _model}} ->
        {:ok, activity_state.attemptGuid}

      {:error, e} ->
        Logger.error(
          "Failed to reset activity for activity attempt guid #{activity_attempt_guid}: #{inspect(e)}"
        )

        {:error, "Failed to reset activity for activity attempt guid: #{activity_attempt_guid}"}
    end
  end

  defp apply_score(
         section_slug,
         activity_attempt_guid,
         part_attempt_guid,
         score_given,
         score_maximum,
         timestamp,
         comment,
         datashop_session_id
       ) do
    # Create a single client evaluation that represents the posted LTI score
    client_evaluations = [
      %{
        attempt_guid: part_attempt_guid,
        client_evaluation:
          %ClientEvaluation{
            score: score_given,
            out_of: score_maximum,
            timestamp: timestamp
          }
          |> maybe_apply_feedback_from_comment(comment)
      }
    ]

    case Evaluate.apply_client_evaluation(
           section_slug,
           activity_attempt_guid,
           client_evaluations,
           datashop_session_id
         ) do
      {:ok, _evaluations} ->
        :ok

      {:error, e} ->
        Logger.error("Failed to process activity evaluations. #{inspect(e)}")

        {:error, "Failed to process activity evaluations"}
    end
  end

  defp maybe_apply_feedback_from_comment(attrs, nil), do: attrs
  defp maybe_apply_feedback_from_comment(attrs, ""), do: attrs

  defp maybe_apply_feedback_from_comment(attrs, comment),
    do:
      Map.put(
        attrs,
        :feedback,
        %{content: feedback_content(comment)}
      )

  defp feedback_content(text) do
    %{type: "p", children: [%{text: text}]}
  end
end
