defmodule OliWeb.LiveSessionPlugs.SetProject do
  use OliWeb, :verified_routes

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [redirect: 2, put_flash: 3]

  alias Oli.Authoring.Course
  alias Oli.Authoring.Course.Project

  def on_mount(:default, %{"project_id" => project_id}, _session, socket) do
    project = Course.get_project_by_slug(project_id)

    case project do
      nil ->
        halt("Project not found", socket)

      %Project{required_survey_resource_id: nil} = project ->
        {:cont, assign(socket, project: %{project | required_survey: nil})}

      %Project{required_survey_resource_id: _} = project ->
        required_survey = Course.get_project_survey(project.id)
        {:cont, assign(socket, project: %{project | required_survey: required_survey})}
    end
  end

  def on_mount(:default, _params, _session, socket) do
    {:cont, socket}
  end

  defp halt(message, socket) do
    {:halt, socket |> put_flash(:error, message) |> redirect(to: ~p"/workspaces/course_author")}
  end
end
