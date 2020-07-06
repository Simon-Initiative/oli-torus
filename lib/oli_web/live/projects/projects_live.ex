defmodule OliWeb.Projects.ProjectsLive do

  @moduledoc """
  LiveView implementation of projects view.
  """

  use Phoenix.LiveView, layout: {OliWeb.LayoutView, "live.html"}

  alias Oli.Authoring.Course
  alias Oli.Accounts.{Author}
  alias OliWeb.Projects.Table
  alias OliWeb.Projects.Cards
  alias OliWeb.Projects.State
  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Repo
  alias Oli.Accounts


  def mount(_, %{"current_author_id" => author_id}, socket) do

    author = Repo.get(Author, author_id)
    projects = Course.get_projects_for_author(author)
    author_projects = Accounts.project_authors(Enum.map(projects, fn %{id: id} -> id end))

    {:ok, assign(socket, State.initialize_state(author, projects, author_projects))}
  end

  def handle_params(params, _, socket) do

    sort_by =
      case params["sort_by"] do
        sort_by when sort_by in ~w(title created author) -> sort_by
        _ -> socket.assigns.sort_by
      end

    sort_order =
      case params["sort_order"] do
        sort_order when sort_order in ~w(asc desc) -> sort_order
        _ -> socket.assigns.sort_order
      end

    {:noreply, assign(socket, State.sort_projects(socket.assigns, sort_by, sort_order))}
  end


  def render(assigns) do

    case assigns.is_admin do
      true ->
        ~L"""
        <div class="container">
          <div class="row">
            <div class="col-12">
              <%= live_component @socket, Table, projects: @projects, authors: @authors, sort_by: @sort_by, sort_order: @sort_order %>
            </div>
          </div>
        </div>
        """
      false ->
        ~L"""
        <div>
          <%= live_component @socket, Cards, projects: @projects, authors: @authors %>
        </div>
        """
    end

  end

  # handle change of selection
  def handle_event("sort", %{"sort_by" => sort_by}, socket) do

    sort_order = case socket.assigns.sort_by do
      ^sort_by -> if socket.assigns.sort_order == "asc" do "desc" else "asc" end
      _ -> socket.assigns.sort_order
    end

    {:noreply, push_patch(socket, to: Routes.live_path(socket, OliWeb.Projects.ProjectsLive, %{sort_by: sort_by, sort_order: sort_order}))}
  end

end
