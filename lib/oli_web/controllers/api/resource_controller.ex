defmodule OliWeb.Api.ResourceController do
  use OliWeb, :controller

  alias Oli.Authoring.Editing.PageEditor
  alias Oli.Authoring.Course
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Authoring.Editing.ObjectiveEditor
  alias Oli.Resources.ResourceType
  alias Oli.Authoring.Editing.ResourceEditor

  def index(conn, %{"project" => project_slug}) do
    case Course.get_project_by_slug(project_slug) do
      nil ->
        error(conn, 404, "not found")

      project ->
        pages =
          AuthoringResolver.all_pages(project.slug)
          |> Enum.map(fn r ->
            %{
              id: r.resource_id,
              slug: r.slug,
              title: r.title
            }
          end)

        json(conn, %{"type" => "success", "pages" => pages})
    end
  end

  def update(conn, %{"project" => project_slug, "resource" => resource_slug, "update" => update}) do
    author = conn.assigns[:current_author]

    case PageEditor.edit(project_slug, resource_slug, author.email, update) do
      {:ok, revision} ->
        json(conn, %{"type" => "success", "revision_slug" => revision.slug})

      {:error, {:lock_not_acquired, {_user, _updated_at}}} ->
        error(conn, 423, "locked")

      {:error, {:not_found}} ->
        error(conn, 404, "not found")

      {:error, {:not_authorized}} ->
        error(conn, 403, "unauthorized")

      e ->
        {_, msg} = Oli.Utils.log_error("Could not update resource", e)
        error(conn, 500, msg)
    end
  end

  def create_objective(conn, %{"project_id" => project_slug, "title" => title}) do
    project = Course.get_project_by_slug(project_slug)
    author = conn.assigns[:current_author]

    case ObjectiveEditor.add_new(%{title: title}, author, project, nil) do
      {:ok, %{revision: revision}} ->
        conn
        |> json(%{"type" => "success", "revisionSlug" => revision.slug})

      {:error, %Ecto.Changeset{} = c} ->
        {_, msg} = Oli.Utils.log_error("Could not create objective", c)

        conn
        |> send_resp(500, msg)
    end
  end

  def alternatives(conn, %{"project" => project_slug}) do
    project = Course.get_project_by_slug(project_slug)
    author = conn.assigns[:current_author]

    case project do
      nil ->
        error(conn, 404, "not found")

      project ->
        {:ok, alternatives} =
          ResourceEditor.list(
            project.slug,
            author,
            ResourceType.get_id_by_type("alternatives")
          )

        alternatives =
          Enum.map(alternatives, fn a ->
            %{
              id: a.resource_id,
              title: a.title,
              options: a.content["options"]
            }
          end)

        json(conn, %{"type" => "success", "alternatives" => alternatives})
    end
  end

  defp error(conn, code, reason) do
    conn
    |> send_resp(code, reason)
    |> halt()
  end
end
