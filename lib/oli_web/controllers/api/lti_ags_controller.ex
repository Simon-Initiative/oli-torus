defmodule OliWeb.Api.LtiAgsController do
  use OliWeb, :controller

  alias Oli.Delivery.Attempts.Core.ClientEvaluation

  plug OliWeb.Plugs.LtiAgsTokenValidator

  # GET /lti/lineitems/:section_slug/:resource_id?user_id=...
  def get_result(conn, %{"lineitem_id" => lineitem_id, "user_id" => user_id}) do
    # TODO: Fetch the result for the given lineitem_id and user_id from your DB
    # Example response per AGS spec section 3.3.4.1
    result = %{
      "id" => "https://your.platform/lineitems/#{lineitem_id}/results/#{user_id}",
      "scoreOf" => "https://your.platform/lineitems/#{lineitem_id}",
      "userId" => user_id,
      "resultScore" => 0.95,
      "resultMaximum" => 1,
      "scoringUserId" => "instructor_id",
      "comment" => "Migrated from LTI 1.1 Basic Outcomes"
    }

    json(conn, [result])
  end

  # POST /lti/lineitems/:section_slug/:resource_id
  def post_score(
        conn,
        %{
          "section_slug" => _section_slug,
          "activity_attempt_guid" => _activity_attempt_guid,
          "gradingProgress" => "NotReady",
          "activityProgress" => "Initialized"
        } = _params
      ) do
    # TODO: Delete the score for the user/lineitem
    send_resp(conn, 501, "Not Implemented")
  end

  def post_score(
        conn,
        %{
          "section_slug" => section_slug,
          "activity_attempt_guid" => activity_attempt_guid,
          "userId" => _user_id,
          "scoreGiven" => score_given,
          "scoreMaximum" => score_maximum,
          "gradingProgress" => grading_progress
        } = params
      ) do
    # Validate the grading_progress
    with :ok <-
           if(String.downcase(grading_progress) == "fullygraded",
             do: :ok,
             else: {:error, "gradingProgress must be FullyGraded"}
           ) do
      datashop_session_id = Plug.Conn.get_session(conn, :datashop_session_id)

      # TODO: optionally, get section from activity_attempt_id instead of using a section_slug param
      # Oli.Delivery.Attempts.Core.get_section_by_activity_attempt_guid

      # get attempt_guid using activity_attempt_guid. There should be only one part attempt
      case Oli.Delivery.Attempts.Core.get_latest_part_attempts(activity_attempt_guid) do
        [part_attempt | _] ->
          attempt_guid = part_attempt.attempt_guid

          # Create a single client evaluation that represents the basic outcomes score
          client_evaluations = [
            %{
              attempt_guid: attempt_guid,
              client_evaluation: %ClientEvaluation{
                score: score_given,
                out_of: score_maximum
              }
            }
          ]

          case Oli.Delivery.Attempts.ActivityLifecycle.Evaluate.apply_client_evaluation(
                 section_slug,
                 activity_attempt_guid,
                 client_evaluations,
                 datashop_session_id
               ) do
            {:ok, _evaluations} ->
              # Respond with 204 No Content per spec
              send_resp(conn, 204, "")

            {:error, e} ->
              {_, msg} = Oli.Utils.log_error("Could not process activity evaluations", e)
              send_resp(conn, 500, msg)
          end

        _ ->
          {:error, "Activity attempt not found or no attempts available"}
      end
    else
      {:error, error} ->
        send_resp(conn, 400, "Invalid score payload. #{error}")

      _ ->
        send_resp(conn, 400, "Invalid score payload")
    end
  end
end
