defmodule OliWeb.Projects.RequiredSurvey do
  use Phoenix.LiveComponent
  use OliWeb, :verified_routes

  alias Oli.Auditing.Context
  alias Oli.Delivery.Sections
  alias Phoenix.LiveView.JS

  attr :project, :map, required: true
  attr :author, :map, required: false, doc: "the author editing a project's survey"
  attr :enabled, :boolean, required: true
  attr :is_section, :boolean, default: false
  attr :required_survey, :map, default: nil

  attr :revert_count, :integer,
    default: 0,
    doc: "changes after a failed save, so the checkbox renders again from the saved state"

  def render(assigns) do
    ~H"""
    <div class="flex items-center h-full">
      <form phx-change="set-required-survey" phx-target={@myself}>
        <%!-- A new id after a failed save renders the checkbox again from the saved state --%>
        <div
          class="form-check"
          id={"survey_check_wrapper-#{@revert_count}"}
          phx-mounted={@revert_count > 0 && JS.focus(to: "#survey_check")}
        >
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
    if socket.assigns.enabled do
      case Sections.delete_required_survey(socket.assigns.project) do
        {:ok, updated_section} ->
          send(self(), {:flash, :info, "Required survey disabled"})
          send(self(), {:section_updated, updated_section})
          {:noreply, assign(socket, enabled: false, project: updated_section)}

        {:error, _reason} ->
          send(self(), {:flash, :error, "Failed to disable required survey"})
          {:noreply, socket}
      end
    else
      case Sections.create_required_survey(socket.assigns.project) do
        {:ok, updated_section} ->
          send(self(), {:flash, :info, "Required survey enabled"})
          send(self(), {:section_updated, updated_section})
          {:noreply, assign(socket, enabled: true, project: updated_section)}

        {:error, _reason} ->
          send(self(), {:flash, :error, "Failed to enable required survey"})
          {:noreply, socket}
      end
    end
  end

  def handle_event("set-required-survey", params, socket) do
    %{project: project, author: author} = socket.assigns
    context = Context.for_actor(author, source: :ui)

    case Map.get(params, "survey", "") do
      "" ->
        case Oli.Authoring.Audited.delete_project_survey(context, project.id) do
          {:ok, _project} ->
            {:noreply, assign(socket, enabled: false, required_survey: nil)}

          {:error, _reason} ->
            survey_error(socket, "The survey could not be disabled.")
        end

      _ ->
        case Oli.Authoring.Audited.create_project_survey(context, project.id) do
          {:ok, revision} ->
            {:noreply, assign(socket, enabled: true, required_survey: revision)}

          {:error, _reason} ->
            survey_error(socket, "The survey could not be enabled.")
        end
    end
  end

  defp survey_error(socket, message) do
    send(self(), {:flash_message, {:error, message}})
    {:noreply, assign(socket, revert_count: Map.get(socket.assigns, :revert_count, 0) + 1)}
  end
end
