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
    is_admin = Accounts.is_admin?(author)

    projects =
      Course.get_projects_for_author(author)
      |> Enum.filter(fn p -> is_admin || p.status === :active end)

    author_projects = Accounts.project_authors(Enum.map(projects, fn %{id: id} -> id end))

    {:ok,
     assign(
       socket,
       Map.merge(State.initialize_state(author, projects, author_projects), %{is_admin: is_admin})
     )}
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

    display_mode =
      case params["display_mode"] do
        display_mode when display_mode in ~w(cards table) -> display_mode
        _ -> socket.assigns.display_mode
      end

    changes =
      Keyword.merge(State.sort_projects(socket.assigns, sort_by, sort_order),
        display_mode: display_mode
      )

    {:noreply, assign(socket, changes)}
  end

  def render(assigns) do
    ~L"""
    <div class="projects-title-row my-4">
      <div class="container">
        <div class="row">
          <div class="col-12">

            <div class="d-flex justify-content-between align-items-baseline">
              <div class="flex-grow-1"></div>
              <div class="btn-group btn-group-toggle" data-toggle="buttons">
                <label phx-click="display_mode" phx-value-display_mode="cards" class="btn btn-sm btn-light <%= if @display_mode == "cards" do "active" else "" end %> %>">
                  <input type="radio" name="options" id="option1"
                    <%= if @display_mode == "cards" do "checked" else "" end %>
                  > <span><i class="las la-grip-horizontal"></i> Card</span>
                </label>
                <label phx-click="display_mode" phx-value-display_mode="table" class="btn btn-sm btn-light <%= if @display_mode == "table" do "active" else "" end %>">
                  <input type="radio" name="options" id="option2"
                    <%= if @display_mode == "table" do "checked" else "" end %>
                  > <span><i class="las la-th-list"></i> Table</span>
                </label>
              </div>

            </div>
          </div>

        </div>
      </div>
    </div>
    <%= case @display_mode do %>
      <% "cards" -> %>
        <%= live_component Cards, projects: @projects, authors: @authors %>
      <% "table" -> %>
        <div class="container">
          <div class="row">
            <div class="col-12">
              <%= live_component Table, projects: @projects, authors: @authors, sort_by: @sort_by, sort_order: @sort_order, is_admin: @is_admin %>
            </div>
          </div>
        </div>
    <% end %>
    """
  end

  def handle_event("display_mode", %{"display_mode" => display_mode}, socket) do
    sort_by = socket.assigns.sort_by
    sort_order = socket.assigns.sort_order

    cond do
      display_mode == socket.assigns.display_mode ->
        {:noreply, socket}

      true ->
        {:noreply,
         push_patch(socket,
           to:
             Routes.live_path(socket, OliWeb.Projects.ProjectsLive, %{
               sort_by: sort_by,
               sort_order: sort_order,
               display_mode: display_mode
             })
         )}
    end
  end

  # handle change of selection
  def handle_event("sort", %{"sort_by" => sort_by}, socket) do
    sort_order =
      case socket.assigns.sort_by do
        ^sort_by ->
          if socket.assigns.sort_order == "asc" do
            "desc"
          else
            "asc"
          end

        _ ->
          socket.assigns.sort_order
      end

    display_mode = socket.assigns.display_mode

    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(socket, OliWeb.Projects.ProjectsLive, %{
           sort_by: sort_by,
           sort_order: sort_order,
           display_mode: display_mode
         })
     )}
  end
end
