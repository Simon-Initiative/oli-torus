defmodule OliWeb.LiveSessionPlugs.AuthorizeProject do
  use OliWeb, :verified_routes
  import Phoenix.LiveView, only: [redirect: 2, put_flash: 3]

  alias Oli.Accounts
  alias Oli.Accounts.Author

  def on_mount(:default, _params, _session, socket) do
    project = Map.get(socket.assigns, :project)
    current_author = Map.get(socket.assigns, :current_author)

    case current_author do
      nil ->
        {:halt,
         socket
         |> put_flash(:error, "You must be logged in to access that project")
         |> redirect(to: ~p"/workspaces/course_author")}

      %Author{} ->
        case {Accounts.can_access?(current_author, project), project.status} do
          {true, :active} ->
            {:cont, socket}

          {false, _} ->
            {:halt,
             socket
             |> put_flash(:error, "You don't have access to that project")
             |> redirect(to: ~p"/workspaces/course_author")}

          {_, :deleted} ->
            {:halt,
             socket
             |> put_flash(:error, "That project is not active")
             |> redirect(to: ~p"/workspaces/course_author")}
        end
    end
  end
end
