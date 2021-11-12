defmodule OliWeb.LegacySuperactivityController do
  use OliWeb, :controller

  alias XmlBuilder

  alias Oli.Interop.CustomActivities.{
    SuperActivityClient,
    SuperActivitySession,
    AttemptHistory,
    FileRecord,
    FileDirectory
  }

  alias Oli.Delivery.Student.Summary
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Attempts.Core, as: Attempts
  alias Oli.Grading
  alias Oli.Delivery.Attempts.ActivityLifecycle
  alias Oli.Delivery.Attempts.ActivityLifecycle.Evaluate, as: ActivityEvaluation
  alias Oli.Delivery.Attempts.Core.ClientEvaluation
  alias Oli.Delivery.Attempts.Core.StudentInput
  alias Oli.Activities.Model.Feedback
  alias Oli.Delivery.Attempts.ActivityLifecycle
  alias Oli.Repo

  def context(conn, %{"attempt_guid" => attempt_guid} = _params) do
    user = conn.assigns.current_user

    activity_attempt =
      Attempts.get_activity_attempt_by(attempt_guid: attempt_guid)
      |> Repo.preload([:part_attempts, revision: [:scoring_strategy]])

    %{"base" => base, "src" => src} = activity_attempt.transformed_model

    context = %{
      src_url: "https://#{conn.host}/superactivity/#{base}/#{src}",
      activity_type: activity_attempt.revision.activity_type.slug,
      server_url: "https://#{conn.host}/jcourse/superactivity/server",
      user_guid: user.id,
      mode: "delivery"
    }

    json(conn, context)
  end

  def process(
        conn,
        %{"commandName" => command_name, "activityContextGuid" => attempt_guid} = params
      ) do
    user = conn.assigns.current_user

    context = fetch_context(conn.host, user, attempt_guid)

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

  defp fetch_context(host, user, attempt_guid) do
    activity_attempt =
      Attempts.get_activity_attempt_by(attempt_guid: attempt_guid)
      |> Repo.preload([:part_attempts, revision: [:scoring_strategy]])

    %{"base" => base, "src" => src} = activity_attempt.transformed_model

    resource_attempt = Attempts.get_resource_attempt_by(id: activity_attempt.resource_attempt_id)

    resource_access = Attempts.get_resource_access(resource_attempt.resource_access_id)

    section =
      Sections.get_section_preloaded!(resource_access.section_id)
      |> Repo.preload([:institution, :section_project_publications])

    instructors = Grading.fetch_instructors(section.slug)

    enrollment =
      Sections.get_enrollment(section.slug, user.id)
      |> Repo.preload([:context_roles])

    project = Sections.get_project_by_section_resource(section.id, activity_attempt.resource_id)
    path = "media/" <> project.slug
    web_content_url = "https://#{Application.fetch_env!(:oli, :media_url)}/#{path}/"

    host_url = "https://#{host}"

    save_files =
      ActivityLifecycle.get_activity_attempt_save_files(
        activity_attempt.attempt_guid,
        Integer.to_string(user.id),
        activity_attempt.attempt_number
      )

    %{
      server_time_zone: get_timezone(),
      user: user,
      host: host,
      section: section,
      activity_attempt: activity_attempt,
      resource_attempt: resource_attempt,
      resource_access: resource_access,
      save_files: save_files,
      instructors: instructors,
      enrollment: enrollment,
      web_content_url: web_content_url,
      host_url: host_url,
      base: base,
      src: src
    }
  end

  def file_not_found(conn, _params) do
    conn
    |> put_status(404)
    |> text("File Not Found")
  end

  defp process_command(command_name, context, _params) when command_name === "loadClientConfig" do
    xml =
      SuperActivityClient.setup(%{
        context: context
      })
      |> XmlBuilder.document()
      |> XmlBuilder.generate()

    {:ok, xml}
  end

  defp process_command(command_name, context, _params) when command_name === "beginSession" do
    #        IO.inspect(context, limit: :infinity)
    xml =
      SuperActivitySession.setup(%{
        context: context
      })
      |> XmlBuilder.document()
      |> XmlBuilder.generate()

    {:ok, xml}
  end

  defp process_command(command_name, context, _params) when command_name === "loadContentFile" do
    %{"modelXml" => modelXml} = context.activity_attempt.transformed_model
    {:ok, modelXml}
  end

  defp process_command(command_name, context, params) when command_name === "startAttempt" do
    # commandName: startAttempt
    # resourceTypeID: x-cmu-phil-syntaxlab
    # activityMode: delivery
    # authenticationToken: s=c272df717f00000136fc40e39ca2e317&u=rgachuhi&h=8217d014dba6099bf9445eba90b6536e
    # userGuid: rgachuhi
    # activityContextGuid: 58b3ceea7f0000011018b00c8bc72b87
    # activityGuid: 58b3cee97f0000011e90a274d3df8b5f

    case context.activity_attempt.date_evaluated do
      nil ->
        attempt_history(context)
      _ ->
        seed_state_from_previous = Map.get(params, "seedResponsesWithPrevious", false)

        case ActivityLifecycle.reset_activity(
               context.section.slug,
               context.activity_attempt.attempt_guid,
               seed_state_from_previous
             ) do
          {:ok, {attempt_state, _model}} ->
            IO.inspect attempt_state

            attempt_history(fetch_context(context.host, context.user, attempt_state.attemptGuid))

          {:error, _} ->
            {:error, "server error", 500}
        end
    end
  end

  defp process_command(
         command_name,
         context,
         %{"scoreValue" => score_value, "scoreId" => score_type} = _params
       )
       when command_name === "scoreAttempt" do
    # Assumes all custom activities have a single part
    part_attempt = Enum.at(context.activity_attempt.part_attempts, 0)
    # :TODO: oli legacy allows for custom activities to supply arbitrary score types.
    # :TODO: Worse still; an activity can supply multiple score types as part of the grade. How to handle these on Torus?

    case purse_score(score_type, score_value) do
      {:non_numeric, score_value} ->
        custom_scores = Map.merge(context.activity_attempt.custom_scores, %{score_type => score_value})
        Attempts.update_activity_attempt(context.activity_attempt, %{custom_scores: custom_scores})
      {:numeric, score, out_of} -> eval_numeric_score(context, score, out_of, part_attempt)
    end

  end

  defp eval_numeric_score(context, score, out_of, part_attempt) do
    {:ok, feedback} = Feedback.parse(%{"id" => "1", "content" => "some-feedback"})

    client_evaluations = [
      %{
        attempt_guid: part_attempt.attempt_guid,
        client_evaluation: %ClientEvaluation{
          input: %StudentInput{input: "some-input"},
          score: score,
          out_of: out_of,
          feedback: feedback
        }
      }
    ]

    case ActivityEvaluation.apply_client_evaluation(
           context.section.slug,
           context.activity_attempt.attempt_guid,
           client_evaluations
         ) do
      {:ok, _evaluations} ->
        attempt_history(fetch_context(context.host, context.user, context.activity_attempt.attempt_guid))
#        attempt_history(context)
      {:error, _} ->
        {:error, "server error", 500}
    end
  end

  defp purse_score(score_type, score_value) do
    # 'completed','true'
    # 'count','1'
    # 'feedback','.false'
    # 'grade','.99'
    # 'percent','0'
    # 'percentScore','100'
    # 'posttest1Score','0'
    # 'posttest2Score','0'
    # 'pretestScore','0'
    # 'problem1Completed','true'
    # 'problem2Completed','true'
    # 'problem3Completed','true'
    # 'score','2/2'
    # 'status','Submitted'
    # 'visited','true'
    case score_type do
      "completed" -> {:non_numeric, score_value}
      "count" -> {:non_numeric, score_value}
      "feedback" -> {:non_numeric, score_value}
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
      "problem1Completed" -> {:non_numeric, score_value}
      "problem2Completed" -> {:non_numeric, score_value}
      "problem3Completed" -> {:non_numeric, score_value}
      "score" ->
        case String.split(score_value, ",", trim: true) do
          [numerator, denominator] ->
            {score, _} = Float.parse(numerator)
            {out_of, _} = Float.parse(denominator)
            {:numeric, score, out_of}
          _ -> {:non_numeric, score_value}
        end
      "status" -> {:non_numeric, score_value}
      "visited" -> {:non_numeric, score_value}
    end
  end

  defp process_command(command_name, context, _params) when command_name === "endAttempt" do
    attempt_history(context)
  end

  defp process_command(command_name, context, _params) when command_name === "loadUserSyllabus" do
    #    summary = Summary.get_summary(context.section.slug, context.user)
    hierarchy = Oli.Publishing.DeliveryResolver.full_hierarchy(context.section.slug)

    page_nodes =
      hierarchy
      |> Oli.Delivery.Hierarchy.flatten()

    #      |> Enum.filter(fn node ->
    #        node.revision.resource_type_id ==
    #          Oli.Resources.ResourceType.get_id_by_type("page")
    #      end)

    IO.inspect(hierarchy, limit: :infinity)
    {:error, "command not supported", 400}
  end

  defp process_command(
         command_name,
         context,
         %{
           "activityContextGuid" => attempt_guid,
           "byteEncoding" => byte_encoding,
           "fileName" => file_name,
           "fileRecordData" => content,
           "resourceTypeID" => activity_type,
           "mimeType" => mime_type,
           "userGuid" => user_id
         } = params
       )
       when command_name === "writeFileRecord" do
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

    {:ok, save_file} = ActivityLifecycle.save_activity_attempt_state_file(file_info)

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

  defp process_command(
         command_name,
         _context,
         %{
           "activityContextGuid" => attempt_guid
         } = params
       )
       when command_name === "loadFileRecord" do
    file_name = Map.get(params, "fileName")
    attempt_number = Map.get(params, "attemptNumber")
    user_id = Map.get(params, "userGuid")

    save_file =
      ActivityLifecycle.get_activity_attempt_save_file(
        attempt_guid,
        user_id,
        attempt_number,
        file_name
      )

    case save_file do
      nil -> {:error, "file not found", 404}
      _ -> {:ok, URI.decode(save_file.content)}
    end
  end

  defp process_command(command_name, context, _params) when command_name === "deleteFileRecord" do
    # :TODO: no op?
    xml =
      FileDirectory.setup(%{
        context: context
      })
      |> XmlBuilder.document()
      |> XmlBuilder.generate()

    {:ok, xml}
  end

  defp process_command(_command_name, _context, _params) do
    {:error, "command not supported", 400}
  end

  defp attempt_history(context) do
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
end
