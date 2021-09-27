defmodule OliWeb.LegacySuperactivityController do
  use OliWeb, :controller

  alias XmlBuilder
  alias Oli.Interop.CustomActivities.{SuperActivityClient, SuperActivitySession, AttemptHistory}
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Attempts.Core, as: Attempts
  alias Oli.Grading
  alias Oli.Repo

  def context(conn, %{"attempt_guid" => attempt_guid} = params) do

    IO.inspect params
#    IO.inspect(conn, limit: :infinity)

    user = conn.assigns.current_user
    host_url = "https://#{conn.host}"

    activity_attempt = Attempts.get_activity_attempt_by(attempt_guid: attempt_guid)
                       |> Repo.preload([revision: [:scoring_strategy]])

    context = %{
      src_url: "#{host_url}/superactivity/#{activity_attempt.revision.activity_type.slug}/index.html",
      activity_type: activity_attempt.revision.activity_type.slug,
      server_url: "#{host_url}/jcourse/superactivity/server",
      user_guid: user.id,
      mode: "delivery"
    }

    json(conn, context)
  end

  def process(conn, %{"commandName" => command_name, "activityContextGuid" => attempt_guid} = params) do
    user = conn.assigns.current_user

    #    IO.inspect(conn, limit: :infinity)

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
    activity_attempt = Attempts.get_activity_attempt_by(attempt_guid: attempt_guid)
                       |> Repo.preload([revision: [:scoring_strategy]])

    resource_attempt = Attempts.get_resource_attempt_by(id: activity_attempt.resource_attempt_id)

    resource_access = Attempts.get_resource_access(resource_attempt.resource_access_id)

    section = Sections.get_section_preloaded!(resource_access.section_id)
              |> Repo.preload([:institution, :section_project_publications])

    instructors = Grading.fetch_instructors(section.slug)

    enrollment = Sections.get_enrollment(section.slug, user.id)
                 |> Repo.preload([:context_roles])

    project = Sections.get_project_by_section_resource(section.id, activity_attempt.resource_id)
    path = "media/" <> project.slug
    web_content_url = "https://#{Application.fetch_env!(:oli, :media_url)}/#{path}/webcontent/"

    host_url = "https://#{conn.host}"

    %{
      server_time_zone: get_timezone(),
      user: user,
      section: section,
      activity_attempt: activity_attempt,
      resource_attempt: resource_attempt,
      resource_access: resource_access,
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
    xml = SuperActivityClient.setup(
            %{
              context: context
            }
          )
          |> XmlBuilder.document
          |> XmlBuilder.generate
    {:ok, xml}
  end

  defp process_command(command_name, context, _params) when command_name === "beginSession" do

    #    IO.inspect(context, limit: :infinity)
    xml = SuperActivitySession.setup(
            %{
              context: context
            }
          )
          |> XmlBuilder.document
          |> XmlBuilder.generate
    {:ok, xml}
  end

  defp process_command(command_name, context, _params) when command_name === "loadContentFile" do
    %{"modelXml" => modelXml} = context.activity_attempt.transformed_model
    {:ok, modelXml}
  end

  defp process_command(command_name, context, _params) when command_name === "startAttempt" do
    xml = AttemptHistory.setup(
            %{
              context: context
            }
          )
          |> XmlBuilder.document
          |> XmlBuilder.generate
    {:ok, xml}
  end

  defp process_command(command_name, context, _params) when command_name === "scoreAttempt" do
    xml = AttemptHistory.setup(
            %{
              context: context
            }
          )
          |> XmlBuilder.document
          |> XmlBuilder.generate
    {:ok, xml}
  end

  defp process_command(command_name, context, _params) when command_name === "endAttempt" do
    xml = SuperActivityClient.setup(
            %{
              context: context
            }
          )
          |> XmlBuilder.document
          |> XmlBuilder.generate
    {:ok, xml}
  end

  defp process_command(command_name, context, _params) when command_name === "writeFileRecord" do
    xml = SuperActivityClient.setup(
            %{
              context: context
            }
          )
          |> XmlBuilder.document
          |> XmlBuilder.generate
    {:ok, xml}
  end

  defp process_command(command_name, context, _params) when command_name === "loadFileRecord" do
    xml = SuperActivityClient.setup(
            %{
              context: context
            }
          )
          |> XmlBuilder.document
          |> XmlBuilder.generate
    {:ok, xml}
  end

  defp process_command(command_name, context, _params) when command_name === "deleteFileRecord" do
    xml = SuperActivityClient.setup(
            %{
              context: context
            }
          )
          |> XmlBuilder.document
          |> XmlBuilder.generate
    {:ok, xml}
  end

  defp process_command(_command_name, context, _params) do
    {:error, "command not supported"}
  end

  defp get_timezone() do
    {zone, result} = System.cmd("date", ["+%Z"])
    if result == 0, do: String.trim(zone)
  end

end
