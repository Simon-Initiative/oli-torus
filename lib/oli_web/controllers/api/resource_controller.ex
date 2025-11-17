defmodule OliWeb.Api.ResourceController do
  use OliWeb, :controller

  alias Oli.Authoring.Course
  alias Oli.Authoring.Editing.ObjectiveEditor
  alias Oli.Authoring.Editing.PageEditor
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Resources
  alias Oli.Resources.Numbering

  def index(conn, %{"project" => project_slug}) do
    case Course.get_project_by_slug(project_slug) do
      nil ->
        error(conn, 404, "not found")

      project ->
        pages = AuthoringResolver.all_pages(project.slug)

        # Note: We need to compute numbering separately because:
        # 1. `all_pages` returns a flat list of page revisions without hierarchy context or ordering
        # 2. In authoring context, numbering is computed JIT (Just In Time) rather than stored,
        #    because the course hierarchy can change frequently during active development
        numberings =
          Numbering.number_full_tree(
            AuthoringResolver,
            project.slug,
            project.customizations
          )

        pages =
          Enum.map(pages, fn r ->
            numbering = Map.get(numberings, r.id)

            %{
              id: r.resource_id,
              slug: r.slug,
              title: r.title,
              numbering_index: numbering && numbering.index
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
    case Resources.alternatives_groups(
           project_slug,
           Oli.Publishing.AuthoringResolver
         ) do
      {:ok, alternatives} ->
        json(conn, %{"type" => "success", "alternatives" => alternatives})

      _ ->
        error(conn, 404, "failed to resolve alternatives groups")
    end
  end

  @spec activities_with_report(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def activities_with_report(conn, %{"project" => project_slug}) do
    author = conn.assigns[:current_author]

    with {:ok, project} <- Oli.Authoring.Course.get_project_by_slug(project_slug) |> trap_nil(),
         {:ok} <- Oli.Authoring.Editing.Utils.authorize_user(author, project) do
      activities = Resources.get_report_activities(project.id)

      publication_id = Oli.Publishing.get_unpublished_publication_id!(project.id)

      parent_pages = Oli.Publishing.determine_parent_pages(publication_id)

      activities =
        Enum.map(activities, fn a ->
          %{
            id: a.id,
            title: a.title,
            type: a.type,
            page:
              case Map.get(parent_pages, a.id) do
                nil ->
                  nil

                %{title: title, slug: slug} ->
                  %{
                    title: title,
                    url: Routes.resource_path(OliWeb.Endpoint, :edit, project_slug, slug)
                  }
              end
          }
        end)

      json(conn, %{"type" => "success", "activities" => activities})
    else
      _ -> error(conn, 404, "failed to resolve alternatives groups")
    end
  end

  defp error(conn, code, reason) do
    conn
    |> send_resp(code, reason)
    |> halt()
  end

  defp trap_nil(result) do
    case result do
      nil -> {:error, {:not_found}}
      _ -> {:ok, result}
    end
  end
end
