defmodule OliWeb.Projects.CustomizationLive do
  use OliWeb, :live_view
  alias Oli.Authoring.Course
  alias Oli.Branding.CustomLabels
  alias OliWeb.Common.CustomLabelsForm

  def mount(
        _params,
        %{
          "project_slug" => project_slug
        },
        socket
      ) do
    project = Course.get_project_by_slug(project_slug)

    labels =
      case project.customizations do
        nil -> Map.from_struct(CustomLabels.default())
        val -> Map.from_struct(val)
      end

    {:ok,
     assign(socket,
       project: project,
       labels: labels
     )}
  end

  @spec render(any) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
      <CustomLabelsForm.render labels={@labels} save="save_labels"/>
    """
  end

  def handle_event("save_labels", params, socket) do
    socket = clear_flash(socket)

    params =
      Map.merge(%{"unit" => "Unit", "module" => "Module", "section" => "Section"}, params, fn _k,
                                                                                              v1,
                                                                                              v2 ->
        if v2 == nil || String.length(String.trim(v2)) == 0 do
          v1
        else
          v2
        end
      end)

    case Course.update_project(socket.assigns.project, %{customizations: params}) do
      {:ok, project} ->
        {:noreply, assign(socket, :project, project)}

      {:error, %Ecto.Changeset{} = _changeset} ->
        socket =
          put_flash(
            socket,
            :error,
            "Project couldn't be updated"
          )

        {:noreply, assign(socket, :project, socket.assigns.project)}
    end
  end
end
