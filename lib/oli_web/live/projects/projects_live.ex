defmodule OliWeb.Projects.ProjectsLive do

  @moduledoc """
  LiveView implementation of projects view.
  """

  use Phoenix.LiveView, layout: {OliWeb.LayoutView, "live.html"}

  alias Oli.Authoring.Course
  alias Oli.Authoring.Course.Project
  alias Oli.Accounts.{Author, SystemRole}
  alias OliWeb.Projects.Table
  alias OliWeb.Projects.Cards

  alias Oli.Repo
  alias Oli.Accounts

  def mount(params, %{"current_author_id" => author_id}, socket) do

    author = Repo.get(Author, author_id)
    projects = Course.get_projects_for_author(author)

    authors = Accounts.project_authors(Enum.map(projects, fn %{id: id} -> id end))
    |> Enum.reduce(%{}, fn [author, project_id], m ->
      case Map.get(m, project_id) do
        nil -> Map.put(m, project_id, [author])
        list -> Map.put(m, project_id, [author | list])
      end
    end)

    {:ok, assign(socket,
      projects: projects,
      authors: authors,
      author: author,
      changeset: Project.changeset(%Project{
        title: params["project_title"] || ""
      }),
      is_admin: SystemRole.role_id().admin == author.system_role_id,
      title: "Projects")
    }
  end

  def render(assigns) do

    case assigns.is_admin do
      true ->
        ~L"""
        <div class="container">
          <div class="row">
            <div class="col-12">
              <%= live_component @socket, Table, projects: @projects, authors: @authors %>
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
  def handle_event("select", %{"slug" => slug}, socket) do
    {:noreply, assign(socket, selected: slug, attachment_summary: @default_attachment_summary)}
  end

end
