defmodule OliWeb.ProjectPlugs do

  alias Oli.Authoring.Course
  alias Oli.Accounts
  alias OliWeb.Router.Helpers, as: Routes

  def fetch_project(conn, _) do
    case Course.get_project_by_slug(conn.params["project_id"]) do
      nil ->
        conn
        |> Phoenix.Controller.put_flash(:info, "That project does not exist")
        |> Phoenix.Controller.redirect(to: Routes.live_path(OliWeb.Endpoint, OliWeb.Projects.ProjectsLive))
        |> Plug.Conn.halt()
      project -> conn
        |> Plug.Conn.assign(:project, project)
    end
  end

  def authorize_project(conn, _) do
    if Accounts.can_access?(conn.assigns[:current_author], conn.assigns[:project]) do
      conn
    else
      conn
       |> Phoenix.Controller.put_flash(:info, "You don't have access to that project")
       |> Phoenix.Controller.redirect(to: Routes.live_path(OliWeb.Endpoint, OliWeb.Projects.ProjectsLive))
       |> Plug.Conn.halt()
    end
  end

  def ensure_context_id_matches(conn, _) do

    lti_params = Plug.Conn.get_session(conn, :lti_params)
    context_id = lti_params["context_id"]

    # Verify that the context_id found as a parameter in the route
    # matches the one found in the LTI launch from the session
    case conn.params do
      %{"context_id" => ^context_id} -> conn
      _ -> conn
        |> Phoenix.Controller.put_view(OliWeb.DeliveryView)
        |> Phoenix.Controller.render("signin_required.html")
        |> Plug.Conn.halt()
    end
  end

end
