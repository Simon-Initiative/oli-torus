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

  def context(conn, %{"attempt_guid" => attempt_guid} = params) do
    user = conn.assigns.current_user

    activity_attempt =
      Attempts.get_activity_attempt_by(attempt_guid: attempt_guid)
      |> Repo.preload([:part_attempts, revision: [:scoring_strategy]])

    #    IO.inspect(Enum.at(activity_attempt.part_attempts, 0), limit: :infinity)

    context = %{
      src_url:
        "https://#{conn.host}/superactivity/#{activity_attempt.revision.activity_type.slug}/index.html",
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

    context = fetch_context(conn, user, attempt_guid)

    xml_response = process_command(command_name, context, params)

    case xml_response do
      {:ok, xml} ->
        conn
        |> put_resp_content_type("text/xml")
        |> send_resp(200, xml)

      {:error, error} ->
        conn
        |> put_resp_content_type("text/text")
        |> send_resp(500, error)
    end
  end

  defp fetch_context(conn, user, attempt_guid) do
    activity_attempt =
      Attempts.get_activity_attempt_by(attempt_guid: attempt_guid)
      |> Repo.preload([:part_attempts, revision: [:scoring_strategy]])

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
    web_content_url = "https://#{Application.fetch_env!(:oli, :media_url)}/#{path}/webcontent/"

    host_url = "https://#{conn.host}"

    save_file =
      ActivityLifecycle.get_activity_attempt_save_file(activity_attempt.attempt_guid, activity_attempt.attempt_number)

    IO.inspect("Does the save file exist #{inspect(save_file)}")

    %{
      server_time_zone: get_timezone(),
      user: user,
      section: section,
      activity_attempt: activity_attempt,
      resource_attempt: resource_attempt,
      resource_access: resource_access,
      save_file: save_file,
      instructors: instructors,
      enrollment: enrollment,
      web_content_url: web_content_url,
      host_url: host_url
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
          {:ok, {attempt_state, model}} ->
            attempt_history(context)
          {:error, _} ->
            {:error, "server error"}
        end
    end
  end

  defp process_command(
         command_name,
         context,
         %{"scoreValue" => score_value, "scoreId" => score_type} = params
       )
       when command_name === "scoreAttempt" do
    # Assumes all custom activities have a single part
    part_attempt = Enum.at(context.activity_attempt.part_attempts, 0)
    #:TODO: oli legacy allows for custom activities to supply arbitrary score types.
    #Worse still; an activity can supply multiple score types as part of the grade. How to handle these on Torus?
    #'completed','true'
    #'count','1'
    #'feedback','.false'
    #'grade','.99'
    #'percent','0'
    #'percentScore','100'
    #'posttest1Score','0'
    #'posttest2Score','0'
    #'pretestScore','0'
    #'problem1Completed','true'
    #'problem2Completed','true'
    #'problem3Completed','true'
    #'score','2/2'
    #'status','Submitted'
    #'visited','true'
    {score, _} = Float.parse(score_value)

    {:ok, feedback} = Feedback.parse(%{"id" => "1", "content" => "some-feedback"})

    client_evaluations = [
      %{
        attempt_guid: part_attempt.attempt_guid,
        client_evaluation: %ClientEvaluation{
          input: %StudentInput{input: "some-input"},
          score: score,
          out_of: 1,
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
        attempt_history(context)

      {:error, _} ->
        {:error, "server error"}
    end
  end

  defp process_command(command_name, context, _params) when command_name === "endAttempt" do
    attempt_history(context)
  end

  defp process_command(
         command_name,
         context,
         %{
           "activityContextGuid" => attempt_guid,
           "attemptNumber" => attempt_number,
           "byteEncoding" => byte_encoding,
           "fileName" => file_name,
           "fileRecordData" => content,
           "resourceTypeID" => activity_type,
           "mimeType" => mime_type
         } = params
       )
       when command_name === "writeFileRecord" do
    {:ok, save_file} =
      ActivityLifecycle.save_activity_attempt_state_file(%{
        attempt_guid: attempt_guid,
        attempt_number: attempt_number,
        content: content,
        mime_type: mime_type,
        byte_encoding: byte_encoding,
        activity_type: activity_type,
        file_name: file_name
      })

    context = Map.merge(context, %{save_file: save_file})

    xml =
      FileRecord.setup(%{
        context: context
      })
      |> XmlBuilder.document()
      |> XmlBuilder.generate()

    {:ok, xml}
  end

  defp process_command(
         command_name,
         context,
         %{
           "activityContextGuid" => attempt_guid,
           "attemptNumber" => attempt_number,
         } = params
       )
       when command_name === "loadFileRecord" do

    save_file = ActivityLifecycle.get_activity_attempt_save_file(attempt_guid, attempt_number)


    case save_file do
      nil -> {:error, "file not found"}
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

  defp process_command(_command_name, context, _params) do
    {:error, "command not supported"}
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
