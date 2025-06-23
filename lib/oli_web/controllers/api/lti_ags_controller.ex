defmodule OliWeb.Api.LtiAgsController do
  use OliWeb, :controller

  alias Oli.Delivery.Attempts.Core
  alias Oli.Delivery.Attempts.Core.ClientEvaluation
  alias Oli.Delivery.Attempts.ActivityLifecycle.Evaluate
  alias Oli.Delivery.Sections.Section

  require Logger

  plug OliWeb.Plugs.LtiAgsTokenValidator

  # GET /lti/lineitems/:activity_attempt_guid?user_id=...
  def get_result(conn, %{"activity_attempt_guid" => activity_attempt_guid, "user_id" => user_id}) do
    with {:ok, activity_attempt} <- get_activity_attempt(activity_attempt_guid) do
      platform_url = Oli.Utils.get_base_url()

      json(conn, [
        %{
          "id" => "#{platform_url}/lineitems/#{activity_attempt_guid}/results/#{user_id}",
          "scoreOf" => "#{platform_url}/lineitems/#{activity_attempt_guid}",
          "userId" => user_id,
          "resultScore" => activity_attempt.score,
          "resultMaximum" => activity_attempt.out_of
        }
        |> maybe_put_comment_from_activity_attempt(activity_attempt)
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

  defp get_activity_attempt(activity_attempt_guid) do
    case Core.get_activity_attempt_by(attempt_guid: activity_attempt_guid) do
      nil ->
        {:error, "Activity attempt not found for guid: #{activity_attempt_guid}"}

      activity_attempt ->
        {:ok, activity_attempt}
    end
  end

  defp maybe_put_comment_from_activity_attempt(result, activity_attempt) do
    # get part attempt guid using activity_attempt_guid. There should be only one part attempt
    case get_single_part_attempt_from_activity_attempt(activity_attempt.attempt_guid) do
      {:ok, part_attempt} ->
        case OliWeb.Common.Utils.extract_from_part_attempt(part_attempt) do
          [] -> result
          feedbacks -> Map.put(result, "comment", feedbacks |> Enum.join("\n"))
        end

      error ->
        error
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
    with {:ok, section_slug} <-
           get_section_slug_from_activity_attempt_guid(activity_attempt_guid),
         datashop_session_id <- Plug.Conn.get_session(conn, :datashop_session_id),
         {:ok, part_attempt} <-
           get_single_part_attempt_from_activity_attempt(activity_attempt_guid),
         {:ok, _activity_attempt_guid, _part_attempt_guid} <-
           reset_unscored_activity(
             section_slug,
             activity_attempt_guid,
             part_attempt,
             datashop_session_id
           ) do
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
          "gradingProgress" => grading_progress
        } = params
      ) do
    with :ok <- validate_grading_progress(grading_progress),
         {:ok, section_slug} <-
           get_section_slug_from_activity_attempt_guid(activity_attempt_guid),
         datashop_session_id <- Plug.Conn.get_session(conn, :datashop_session_id),
         {:ok, activity_attempt_guid, part_attempt_guid} <-
           get_active_attempt_or_reset_unscored(
             section_slug,
             activity_attempt_guid,
             datashop_session_id
           ),
         :ok <-
           apply_score(
             section_slug,
             activity_attempt_guid,
             part_attempt_guid,
             score_given,
             score_maximum,
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

  defp validate_grading_progress(grading_progress) do
    if(String.downcase(grading_progress) == "fullygraded",
      do: :ok,
      else: {:error, "Invalid score payload. \"gradingProgress\" must be \"FullyGraded\""}
    )
  end

  defp get_section_slug_from_activity_attempt_guid(activity_attempt_guid) do
    case Core.get_section_by_activity_attempt_guid(activity_attempt_guid) do
      %Section{slug: section_slug} ->
        {:ok, section_slug}

      _ ->
        {:error, "Section not found for activity attempt guid: #{activity_attempt_guid}"}
    end
  end

  defp get_active_attempt_or_reset_unscored(
         section_slug,
         activity_attempt_guid,
         datashop_session_id
       ) do
    # get part attempt guid using activity_attempt_guid. There should be only one part attempt
    case get_single_part_attempt_from_activity_attempt(activity_attempt_guid) do
      {:ok, part_attempt} ->
        # If the part attempt lifecycle_state is not active then reset the activity
        if part_attempt.lifecycle_state != :active do
          reset_unscored_activity(
            section_slug,
            activity_attempt_guid,
            part_attempt,
            datashop_session_id
          )
        else
          # The part attempt is active, return the existing activity and part attempt guids
          {:ok, activity_attempt_guid, part_attempt.attempt_guid}
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

  defp reset_unscored_activity(
         section_slug,
         activity_attempt_guid,
         part_attempt,
         datashop_session_id
       ) do
    # Only reset the activity automatically if it is on an unscored page
    page_revision = get_page_revision_from_part_attempt(part_attempt)

    if page_revision.graded do
      {:error,
       "Activity attempt has already been submitted and this activity is on a scored page. \
        A new attempt must be started before a score can be applied."}
    else
      # In an unscored page, automatically reset the activity attempt and return the new
      # activity and part attempt guids
      case Oli.Delivery.Attempts.ActivityLifecycle.reset_activity(
             section_slug,
             activity_attempt_guid,
             datashop_session_id
           ) do
        {:ok, {activity_state, _model}} ->
          activity_attempt_guid = activity_state.attemptGuid
          part_attempt_guid = hd(activity_state.parts).attemptGuid

          {:ok, activity_attempt_guid, part_attempt_guid}

        {:error, e} ->
          Logger.error(
            "Failed to reset activity for activity attempt guid #{activity_attempt_guid}: #{inspect(e)}"
          )

          {:error, "Failed to reset activity for activity attempt guid: #{activity_attempt_guid}"}
      end
    end
  end

  defp get_page_revision_from_part_attempt(part_attempt) do
    part_attempt = Core.preload_part_attempt_revisions(part_attempt)

    part_attempt.activity_attempt.resource_attempt.revision
  end

  defp apply_score(
         section_slug,
         activity_attempt_guid,
         part_attempt_guid,
         score_given,
         score_maximum,
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
            out_of: score_maximum
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

  defp maybe_apply_feedback_from_comment(client_evaluation, nil), do: client_evaluation
  defp maybe_apply_feedback_from_comment(client_evaluation, ""), do: client_evaluation

  defp maybe_apply_feedback_from_comment(client_evaluation, comment),
    do: %ClientEvaluation{
      client_evaluation
      | feedback: %{content: feedback_content(comment)}
    }

  defp feedback_content(text) do
    %{type: "p", children: [%{text: text}]}
  end
end
