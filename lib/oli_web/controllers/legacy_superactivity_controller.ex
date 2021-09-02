defmodule OliWeb.LegacySuperactivityController do
  use OliWeb, :controller

  alias XmlBuilder
  alias Oli.Interop.CustomActivities.{SuperActivityClient, SuperActivitySession}
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Attempts.Core, as: Attempts
  alias Oli.Grading
  alias Oli.Repo

  def process(conn,  %{"commandName" => command_name, "attempt_guid" => attempt_guid} = params) do
    user = conn.assigns.current_user

    context = fetch_context(user, attempt_guid)

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

  defp fetch_context(user, attempt_guid) do
    activity_attempt = Attempts.get_activity_attempt_by(attempt_guid: attempt_guid)
                       |> Repo.preload([revision: [:scoring_strategy]])

    resource_attempt = Attempts.get_resource_attempt_by(id: activity_attempt.resource_attempt_id)

    resource_access = Attempts.get_resource_access(resource_attempt.resource_access_id)

    section = Sections.get_section_preloaded!(resource_access.section_id)
              |> Repo.preload([:institution, :section_project_publications])

    instructors = Grading.fetch_instructors(section.slug)

    enrollment = Sections.get_enrollment(section.slug, user.id)
                 |> Repo.preload([:context_roles])

    %{
      server_time_zone: get_timezone(),
      user: user,
      section: section,
      activity_attempt: activity_attempt,
      resource_attempt: resource_attempt,
      resource_access: resource_access,
      instructors: instructors,
      enrollment: enrollment
    }

  end

  defp process_command(command_name, context, _params) when command_name === "loadClientConfig" do
    xml = SuperActivityClient.setup(%{
      context: context
    }) |> XmlBuilder.document |> XmlBuilder.generate
    {:ok, xml}
  end

  defp process_command(command_name, context, _params) when command_name === "beginSession" do
#    IO.inspect(context, limit: :infinity)
    xml = SuperActivitySession.setup(%{
      context: context
    }) |> XmlBuilder.document |> XmlBuilder.generate
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
