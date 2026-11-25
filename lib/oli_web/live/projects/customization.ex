defmodule OliWeb.Projects.CustomizationLive do
  use OliWeb, :live_view
  alias Oli.Accounts
  alias Oli.Auditing.Context
  alias Oli.Authoring.Course
  alias Oli.Branding.CustomLabels
  alias OliWeb.Common.CustomLabelsForm

  def mount(
        _params,
        %{
          "project_slug" => project_slug,
          "author_id" => author_id
        },
        socket
      ) do
    project = Course.get_project_by_slug(project_slug)
    author = Accounts.get_author!(author_id)

    labels =
      case project.customizations do
        nil -> CustomLabels.default_map()
        val -> Map.from_struct(val)
      end

    {:ok,
     assign(socket,
       project: project,
       author: author,
       labels: labels
     )}
  end

  @spec render(any) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <CustomLabelsForm.render labels={@labels} save="save_labels" />
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

    %{project: project, author: author} = socket.assigns

    case Oli.Authoring.Audited.update_project_settings(
           Context.for_actor(author, source: :ui),
           project.id,
           %{customizations: params},
           [:customizations]
         ) do
      {:ok, project} ->
        {:noreply, assign(socket, :project, project)}

      {:error, _reason} ->
        {:noreply, flash_error(socket, "Project couldn't be updated")}
    end
  end

  # This view is rendered inside the project overview, which shows its flash messages
  defp flash_error(socket, message) do
    case socket.parent_pid do
      nil ->
        put_flash(socket, :error, message)

      parent ->
        send(parent, {:flash_message, {:error, message}})
        socket
    end
  end
end
