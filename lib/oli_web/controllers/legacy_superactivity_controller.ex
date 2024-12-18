defmodule OliWeb.LegacySuperactivityController do
  use OliWeb, :controller
  require Logger

  alias XmlBuilder

  alias Oli.Interop.CustomActivities.{
    SuperActivityClient,
    SuperActivitySession,
    AttemptHistory,
    FileRecord,
    FileDirectory
  }

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Attempts.Core, as: Attempts
  alias Oli.Delivery.Attempts.ActivityLifecycle
  alias Oli.Delivery.Attempts.ActivityLifecycle.Evaluate, as: ActivityEvaluation
  alias Oli.Delivery.Attempts.Core.ClientEvaluation
  alias Oli.Delivery.Attempts.Core.StudentInput
  alias Oli.Activities.Model.Feedback
  alias Oli.Delivery.Attempts.ActivityLifecycle
  alias Oli.Repo

  defmodule LegacySuperactivityContext do
    @moduledoc false
    defstruct [
      :server_time_zone,
      :user,
      :host,
      :section,
      :datashop_session_id,
      :activity_attempt,
      :resource_attempt,
      :resource_access,
      :attempt_user_id,
      :save_files,
      :instructors,
      :enrollment,
      :web_content_url,
      :host_url,
      :base,
      :src
    ]
  end

  def context(conn, %{"attempt_guid" => attempt_guid} = _params) do
    user = conn.assigns.current_user

    attempt = Attempts.get_activity_attempt_by(attempt_guid: attempt_guid)

    case attempt do
      nil ->
        error(conn, 404, "Attempt not found")

      _ ->
        activity_attempt =
          Attempts.get_latest_activity_attempt(attempt.resource_attempt_id, attempt.resource_id)
          |> Repo.preload([:part_attempts, revision: [:scoring_strategy]])

        part_ids = Enum.map(activity_attempt.part_attempts, fn x -> x.part_id end)

        %{"base" => base, "src" => src} = activity_attempt.revision.content

        context = %{
          attempt_guid: activity_attempt.attempt_guid,
          src_url: "https://#{conn.host}/superactivity/#{base}/#{src}",
          activity_type: activity_attempt.revision.activity_type.slug,
          server_url: "https://#{conn.host}/jcourse/superactivity/server",
          user_guid: user.id,
          mode: "delivery",
          part_ids: part_ids
        }

        json(conn, context)
    end
  end

  def process(
        conn,
        %{"commandName" => command_name, "activityContextGuid" => attempt_guid} = params
      ) do
    user = conn.assigns.current_user
    datashop_session_id = Plug.Conn.get_session(conn, :datashop_session_id)

    context = fetch_context(conn.host, user, attempt_guid, datashop_session_id)

    xml_response = process_command(command_name, context, params)

    case xml_response do
      {:ok, xml} ->
        conn
        |> put_resp_content_type("text/xml")
        |> send_resp(200, xml)

      {:error, error, code} ->
        conn
        |> put_resp_content_type("text/text")
        |> send_resp(code, error)
    end
  end

  def file_not_found(conn, _params) do
    conn
    |> put_status(404)
    |> text("File Not Found")
  end

  defp fetch_context(host, user, attempt_guid, datashop_session_id) do
    activity_attempt =
      Attempts.get_activity_attempt_by(attempt_guid: attempt_guid)
      |> Repo.preload([:part_attempts, revision: [:scoring_strategy]])

    %{"base" => base, "src" => src} = activity_attempt.revision.content

    resource_attempt = Attempts.get_resource_attempt_by(id: activity_attempt.resource_attempt_id)

    resource_access = Attempts.get_resource_access(resource_attempt.resource_access_id)

    # different than current user when instructor reviews student attempt
    attempt_user_id = resource_access.user_id

    section =
      Sections.get_section_preloaded!(resource_access.section_id)
      |> Repo.preload([:institution, :section_project_publications])

    instructors = Sections.fetch_instructors(section.slug)

    enrollment =
      Sections.get_enrollment(section.slug, user.id)
      |> Repo.preload([:context_roles])

    path = "super_media"
    web_content_url = "https://#{host}/#{path}/"

    host_url = "https://#{host}"

    save_files =
      ActivityLifecycle.get_activity_attempt_save_files(
        activity_attempt.attempt_guid,
        Integer.to_string(attempt_user_id),
        activity_attempt.attempt_number
      )

    %LegacySuperactivityContext{
      server_time_zone: get_timezone(),
      user: user,
      host: host,
      section: section,
      datashop_session_id: datashop_session_id,
      activity_attempt: activity_attempt,
      resource_attempt: resource_attempt,
      resource_access: resource_access,
      attempt_user_id: attempt_user_id,
      save_files: save_files,
      instructors: instructors,
      enrollment: enrollment,
      web_content_url: web_content_url,
      host_url: host_url,
      base: base,
      src: src
    }
  end

  defp process_command("loadClientConfig", %LegacySuperactivityContext{} = context, _params) do
    xml =
      SuperActivityClient.setup(%{
        context: context
      })
      |> XmlBuilder.document()
      |> XmlBuilder.generate()

    {:ok, xml}
  end

  defp process_command("beginSession", %LegacySuperactivityContext{} = context, _params) do
    xml =
      SuperActivitySession.setup(%{
        context: context
      })
      |> XmlBuilder.document()
      |> XmlBuilder.generate()

    {:ok, xml}
  end

  defp process_command("loadContentFile", %LegacySuperactivityContext{} = context, _params) do
    %{"modelXml" => modelXml} = context.activity_attempt.revision.content
    {:ok, modelXml}
  end

  defp process_command("startAttempt", %LegacySuperactivityContext{} = context, params) do
    case context.activity_attempt.date_evaluated do
      nil ->
        attempt_history(context)

      _ ->
        seed_state_from_previous = Map.get(params, "seedResponsesWithPrevious", false)

        case ActivityLifecycle.reset_activity(
               context.section.slug,
               context.activity_attempt.attempt_guid,
               context.datashop_session_id,
               seed_state_from_previous
             ) do
          {:ok, {attempt_state, _model}} ->
            attempt_history(
              fetch_context(
                context.host,
                context.user,
                attempt_state.attemptGuid,
                context.datashop_session_id
              )
            )

          {:error, _} ->
            {:error, "server error", 500}
        end
    end
  end

  defp process_command(
         "scoreAttempt",
         %LegacySuperactivityContext{} = context,
         %{"scoreValue" => score_value, "scoreId" => score_type} = params
       ) do
    part_attempt =
      case Map.get(params, "partId") do
        nil ->
          # Assumes custom has a single part if partId is absent from request parameters
          Enum.at(context.activity_attempt.part_attempts, 0)

        part_id ->
          Enum.filter(context.activity_attempt.part_attempts, fn p -> part_id === p.part_id end)
      end

    # oli legacy allows for custom activities to supply arbitrary score types.
    # Worse still; an activity can supply multiple score types as part of the grade. How to handle these on Torus?
    case purse_score(score_type, score_value) do
      {:non_numeric, score_value} ->
        custom_scores =
          Map.merge(context.activity_attempt.custom_scores, %{score_type => score_value})

        Attempts.update_activity_attempt(context.activity_attempt, %{custom_scores: custom_scores})

      {:numeric, score, out_of} ->
        eval_numeric_score(context, score, out_of, part_attempt)
    end
  end

  defp process_command("endAttempt", %LegacySuperactivityContext{} = context, _params) do
    case finalize_activity_attempt(context) do
      {:ok, _} ->
        attempt_history(
          fetch_context(
            context.host,
            context.user,
            context.activity_attempt.attempt_guid,
            context.datashop_session_id
          )
        )

      {:error, message} ->
        Logger.error("Error when processing help message #{inspect(message)}")
        {:error, "server error", 500}
    end
  end

  defp process_command(command_name, %LegacySuperactivityContext{} = _context, _params)
       when command_name === "loadUserSyllabus" do
    {:error, "command not supported", 400}
  end

  defp process_command(
         "writeFileRecord",
         %LegacySuperactivityContext{} = context,
         %{
           "activityContextGuid" => attempt_guid,
           "byteEncoding" => byte_encoding,
           "fileName" => file_name,
           "fileRecordData" => content,
           "resourceTypeID" => activity_type,
           "mimeType" => mime_type,
           "userGuid" => user_id
         } = params
       ) do
    {:ok, save_file} =
      case context.activity_attempt.date_evaluated do
        nil ->
          file_info = %{
            attempt_guid: attempt_guid,
            user_id: user_id,
            content: content,
            mime_type: mime_type,
            byte_encoding: byte_encoding,
            activity_type: activity_type,
            file_name: file_name
          }

          attempt_number = Map.get(params, "attemptNumber")

          file_info =
            if attempt_number != nil do
              Map.merge(file_info, %{attempt_number: attempt_number})
            else
              file_info
            end

          ActivityLifecycle.save_activity_attempt_state_file(file_info)

        _ ->
          attempt_number = Map.get(params, "attemptNumber")

          save_file =
            ActivityLifecycle.get_activity_attempt_save_file(
              attempt_guid,
              user_id,
              attempt_number,
              file_name
            )

          {:ok, save_file}
      end

    case save_file do
      nil ->
        {:error, "file not found", 404}

      _ ->
        xml =
          FileRecord.setup(%{
            context: context,
            date_created: DateTime.to_unix(save_file.inserted_at),
            file_name: save_file.file_name,
            guid: save_file.file_guid
          })
          |> XmlBuilder.document()
          |> XmlBuilder.generate()

        {:ok, xml}
    end
  end

  defp process_command(
         "loadFileRecord",
         %LegacySuperactivityContext{} = context,
         %{
           "activityContextGuid" => attempt_guid
         } = params
       ) do
    file_name = Map.get(params, "fileName")
    attempt_number = Map.get(params, "attemptNumber")
    # use attempt_user from context to allow for instructor review of student work
    attempt_user_id = context.attempt_user_id

    save_file =
      ActivityLifecycle.get_activity_attempt_save_file(
        attempt_guid,
        Integer.to_string(attempt_user_id),
        attempt_number,
        file_name
      )

    case save_file do
      nil -> {:error, "file not found", 404}
      _ -> {:ok, URI.decode(save_file.content)}
    end
  end

  defp process_command("deleteFileRecord", %LegacySuperactivityContext{} = context, _params) do
    # no op
    xml =
      FileDirectory.setup(%{
        context: context
      })
      |> XmlBuilder.document()
      |> XmlBuilder.generate()

    {:ok, xml}
  end

  defp process_command(_command_name, %LegacySuperactivityContext{} = _context, _params) do
    {:error, "command not supported", 400}
  end

  defp finalize_activity_attempt(%LegacySuperactivityContext{} = context) do
    case context.activity_attempt.date_evaluated do
      nil ->
        part_attempts = Attempts.get_latest_part_attempts(context.activity_attempt.attempt_guid)

        # Ensures all parts are evaluated before rolling up the part scores into activity score
        # Note that by default assign 0 out of 100 is assumed for any part not already evaluated
        client_evaluations =
          Enum.reduce(part_attempts, [], fn p, acc ->
            case p.date_evaluated do
              nil -> acc ++ [create_evaluation(context, 0, 100, p)]
              _ -> acc
            end
          end)

        Repo.transaction(fn ->
          if length(client_evaluations) > 0 do
            ActivityEvaluation.apply_super_activity_evaluation(
              context.section.slug,
              context.activity_attempt.attempt_guid,
              client_evaluations,
              context.datashop_session_id
            )
          end

          rest =
            ActivityEvaluation.rollup_part_attempt_evaluations(
              context.activity_attempt.attempt_guid
            )

          rest
        end)

      _ ->
        {:ok, "activity already finalized"}
    end
  end

  defp create_evaluation(%LegacySuperactivityContext{} = context, score, out_of, part_attempt) do
    {:ok, feedback} = Feedback.parse(%{"id" => "1", "content" => "elsewhere"})

    user_input =
      case Enum.at(context.save_files, 0) do
        nil -> "some-input"
        _ -> Enum.at(context.save_files, 0).content
      end

    %{
      attempt_guid: part_attempt.attempt_guid,
      client_evaluation: %ClientEvaluation{
        input: %StudentInput{
          input: user_input
        },
        score: score,
        out_of: out_of,
        feedback: feedback
      }
    }
  end

  defp eval_numeric_score(%LegacySuperactivityContext{} = context, score, out_of, part_attempt) do
    client_evaluations = [
      create_evaluation(context, score, out_of, part_attempt)
    ]

    case ActivityEvaluation.apply_super_activity_evaluation(
           context.section.slug,
           context.activity_attempt.attempt_guid,
           client_evaluations,
           context.datashop_session_id
         ) do
      {:ok, _evaluations} ->
        attempt_history(
          fetch_context(
            context.host,
            context.user,
            context.activity_attempt.attempt_guid,
            context.datashop_session_id
          )
        )

      {:error, message} ->
        Logger.error("The error when applying client evaluation #{message}")
        {:error, "server error", 500}
    end
  end

  defp purse_score(score_type, score_value) do
    case score_type do
      "completed" ->
        {:non_numeric, score_value}

      "count" ->
        {:non_numeric, score_value}

      "feedback" ->
        {:non_numeric, score_value}

      "grade" ->
        {score, _} = Float.parse(score_value)
        {:numeric, score * 100, 100}

      "percent" ->
        {score, _} = Float.parse(score_value)
        {:numeric, score * 100, 100}

      "percentScore" ->
        {score, _} = Float.parse(score_value)
        {:numeric, score, 100}

      "posttest1Score" ->
        {score, _} = Float.parse(score_value)
        {:numeric, score * 100, 100}

      "posttest2Score" ->
        {score, _} = Float.parse(score_value)
        {:numeric, score * 100, 100}

      "pretestScore" ->
        {score, _} = Float.parse(score_value)
        {:numeric, score * 100, 100}

      "problem1Completed" ->
        {:non_numeric, score_value}

      "problem2Completed" ->
        {:non_numeric, score_value}

      "problem3Completed" ->
        {:non_numeric, score_value}

      "score" ->
        case String.split(score_value, ",", trim: true) do
          [numerator, denominator] ->
            {score, _} = Float.parse(numerator)
            {out_of, _} = Float.parse(denominator)
            {:numeric, score, out_of}

          _ ->
            {:non_numeric, score_value}
        end

      "status" ->
        {:non_numeric, score_value}

      "visited" ->
        {:non_numeric, score_value}
    end
  end

  defp attempt_history(%LegacySuperactivityContext{} = context) do
    xml =
      AttemptHistory.setup(%{
        context: context
      })
      |> XmlBuilder.document()
      |> XmlBuilder.generate()

    {:ok, xml}
  end

  defp get_timezone() do
    {zone, result} = System.cmd("date", ["+%Z"])
    if result == 0, do: String.trim(zone)
  end

  defp error(conn, code, reason) do
    conn
    |> Plug.Conn.send_resp(code, reason)
    |> Plug.Conn.halt()
  end
end
