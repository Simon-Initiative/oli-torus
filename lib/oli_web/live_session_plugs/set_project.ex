defmodule OliWeb.LiveSessionPlugs.SetProject do
  import Phoenix.Component, only: [assign: 2]

  def on_mount(:default, %{"project_id" => project_id}, _session, socket) do
    project = Oli.Authoring.Course.get_project_by_slug(project_id)

    project =
      case project.required_survey_resource_id do
        nil ->
          Map.put(project, :required_survey, nil)

        _ ->
          required_survey = Oli.Authoring.Course.get_project_survey(project.id)
          Map.put(project, :required_survey, required_survey)
      end

    socket = assign(socket, project: project)

    {:cont, socket}
  end

  def on_mount(:default, _params, _session, socket) do
    {:cont, socket}
  end
end
