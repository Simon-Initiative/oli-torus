defmodule OliWeb.LiveSessionPlugs.AuthorizeProject do
  use OliWeb, :verified_routes
  import Phoenix.LiveView, only: [redirect: 2, put_flash: 3]

  alias Oli.Authoring.Course.Project
  alias Oli.Accounts
  alias Oli.Accounts.Author

  def on_mount(:default, %{"project_id" => project_id}, _session, socket)
      when not is_nil(project_id) do
    with {:author, %Author{} = author} <- {:author, Map.get(socket.assigns, :current_author)},
         {:project, %Project{} = project} <- {:project, Map.get(socket.assigns, :project)},
         {:access, true} <- {:access, Accounts.can_access?(author, project)},
         {:status, :active} <- {:status, Map.get(project, :status)} do
      {:cont, socket}
    else
      {:author, nil} -> halt("You must be logged in to access that project", socket)
      {:project, nil} -> halt("Project not found", socket)
      {:access, false} -> halt("You don't have access to that project", socket)
      {:status, :deleted} -> halt("That project has been deleted", socket)
    end
  end

  def on_mount(:default, _params, _session, socket) do
    {:cont, socket}
  end

  defp halt(message, socket) do
    {:halt, socket |> put_flash(:error, message) |> redirect(to: ~p"/workspaces/course_author")}
  end
end
