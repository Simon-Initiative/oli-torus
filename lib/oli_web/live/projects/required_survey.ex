defmodule OliWeb.Projects.RequiredSurvey do
  use Phoenix.LiveComponent

  alias Oli.Authoring.Course
  alias Oli.Delivery.Sections

  attr :project, :map, required: true
  attr :author_id, :integer, required: false
  attr :enabled, :boolean, required: true
  attr :is_section, :boolean, default: false

  def render(assigns) do
    ~H"""
    <div class="flex items-center h-full">
      <form phx-change="set-required-survey" phx-target={@myself}>
        <div class="form-check">
          <label class="form-check-label">
            <input name="survey" class="survey_check" type="checkbox" id="survey_check" checked={@enabled}>
            <span>
              Allow students to take a survey before starting the course
            </span>
          </label>
        </div>
      </form>
    </div>
    """
  end

  def handle_event("set-required-survey", _params, %{assigns: %{is_section: true}} = socket) do
    socket =
      if socket.assigns.enabled do
        Sections.delete_required_survey(socket.assigns.project)
        assign(socket, enabled: false)
      else
        Sections.create_required_survey(socket.assigns.project)
        assign(socket, enabled: true)
      end

    {:noreply, socket}
  end

  def handle_event("set-required-survey", params, socket) do
    %{project: project, author_id: author_id} = socket.assigns
    allow_survey = Map.has_key?(params, "survey") and String.length(params["survey"]) > 0

    if allow_survey do
      Course.create_project_survey(project, author_id)
    else
      Course.delete_project_survey(project)
    end

    {:noreply, assign(socket, enabled: allow_survey)}
  end
end
