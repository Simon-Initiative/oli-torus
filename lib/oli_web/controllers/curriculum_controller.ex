defmodule OliWeb.CurriculumController do
  use OliWeb, :controller
  import OliWeb.ProjectPlugs
  alias Oli.Authoring.Editing.ContainerEditor
  alias Oli.Resources.ScoringStrategy

  plug :fetch_project
  plug :authorize_project

  def index(conn, _params) do
    render(conn, "index.html",
      pages: ContainerEditor.list_all_pages(conn.assigns.project),
      title: "Curriculum")
  end

  def create(conn, %{"type" => type}) do
    %{ project: project, current_author: author } = conn.assigns

    IO.inspect type

    attrs = %{
      objectives: %{ "attached" => []},
      children: [],
      content: %{ "model" => []},
      title: "New Page",
      graded: type == "Scored",
      max_attempts: if type == "Scored" do 5 else 0 end,
      recommended_attempts: if type == "Scored" do 5 else 0 end,
      scoring_strategy_id: ScoringStrategy.get_id_by_type("best"),
      resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page")
    }

    IO.inspect attrs

    case ContainerEditor.add_new(attrs, author, project) do

      {:ok, _resource} ->
        conn
        |> put_flash(:info, "Page created")
        |> redirect(to: Routes.curriculum_path(conn, :index, project))

      {:error, %Ecto.Changeset{} = _changeset} ->
        conn
        |> put_flash(:error, "Could not create page")
        |> redirect(to: Routes.curriculum_path(conn, :index, project))
    end
  end

  def update(conn, %{"sourceSlug" => source, "index" => index}) do
    %{project: project, current_author: author} = conn.assigns

    case ContainerEditor.reorder_child(project, author, source, index) do
      {:ok, _resource} -> json(conn, %{ "success" => "true"})
      {:error, _} -> json(conn, %{ "success" => "false"})
    end
  end

  def delete(conn, %{"id" => page_slug}) do
    %{project: project, current_author: author} = conn.assigns

    case ContainerEditor.remove_child(project, author, page_slug) do
      {:ok, _resource} ->
        conn
        |> put_flash(:info, "Page deleted.")
        |> redirect(to: Routes.curriculum_path(conn, :index, project))

      {:error, _} ->
        conn
        |> put_flash(:error, "Page not deleted.")
        |> redirect(to: Routes.curriculum_path(conn, :index, project))
    end

  end

end
