defmodule OliWeb.Projects.RequiredSurvey do
  use Phoenix.LiveComponent
  use OliWeb, :verified_routes

  alias Oli.Authoring.Course
  alias Oli.Delivery.Sections

  attr :project, :map, required: true
  attr :author_id, :integer, required: false
  attr :enabled, :boolean, required: true
  attr :is_section, :boolean, default: false
  attr :required_survey, :map, default: nil

  def render(assigns) do
    ~H"""
    <div class="flex items-center h-full">
      <form phx-change="set-required-survey" phx-target={@myself}>
        <div class="form-check">
          <label class="form-check-label">
            <input
              name="survey"
              class="survey_check"
              type="checkbox"
              id="survey_check"
              checked={@enabled}
            />
            <span>
              Require students to take a survey before starting the course
            </span>
          </label>
        </div>
        <%= if (!@is_section and @required_survey) do %>
          <a
            class="torus-button primary mt-3"
            href={
              ~p"/workspaces/course_author/#{@project.slug}/curriculum/#{@required_survey.slug}/edit"
            }
          >
            Edit survey
          </a>
        <% end %>
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

    required_survey =
      if allow_survey do
        Course.create_project_survey(project, author_id)
      else
        Course.delete_project_survey(project)
        nil
      end

    {:noreply, assign(socket, enabled: allow_survey, required_survey: required_survey)}
  end
end
