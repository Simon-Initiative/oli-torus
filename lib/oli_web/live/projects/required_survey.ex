defmodule OliWeb.Projects.RequiredSurvey do
  use Phoenix.LiveComponent

  alias Oli.Authoring.Course

  attr :project_id, :integer, required: true
  attr :author_id, :integer, required: true
  attr :enabled, :boolean, required: true

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

  def handle_event("set-required-survey", params, socket) do
    %{project_id: project_id, author_id: author_id} = socket.assigns
    allow_survey = Map.has_key?(params, "survey")

    if (allow_survey) do
      Course.create_project_survey(project_id, author_id)
    else
      Course.delete_project_survey(project_id)
    end

    {:noreply, assign(socket, enabled: allow_survey)}
  end
end
