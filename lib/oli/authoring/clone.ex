defmodule Oli.Authoring.Clone do
  import Ecto.Query, warn: false
  import Oli.Authoring.Editing.Utils
  alias Oli.Authoring.Editing.Blueprint
  alias Oli.Publishing
  alias Oli.Publishing.{AuthoringResolver}
  alias Oli.Authoring.{Collaborators, Locks}
  alias Oli.Repo
  alias Oli.Authoring.Course
  alias Oli.Authoring.Course.Project
  alias Oli.Authoring.Authors.AuthorProject
  alias Oli.Delivery.Sections.Blueprint

  def clone_blueprints(blueprints, cloned_from_project_publication_ids) do
    Enum.map(blueprints, &Blueprint.duplicate(&1, %{}, cloned_from_project_publication_ids))
  end

  def clone_project(project_slug, author, opts \\ []) do
    new_project_title_suffix =
      if opts[:author_in_project_title], do: " <#{author.email}>", else: " Copy"

    Repo.transaction(fn ->
      with {:ok, base_project} <-
             Course.get_project_by_slug(project_slug) |> Repo.preload(:family) |> trap_nil(),
           {:ok, cloned_family} <-
             Course.create_family(%{
               title: base_project.family.title <> " Copy",
               description: base_project.family.description
             }),
           {:ok, customizations, attributes} <- copy_attributes(base_project),
           {:ok, cloned_project} <-
             Course.create_project(%{
               title: base_project.title <> new_project_title_suffix,
               version: "1.0.0",
               family_id: cloned_family.id,
               project_id: base_project.id,
               publisher_id: base_project.publisher_id,
               customizations: customizations,
               attributes: attributes,
               analytics_version: :v2
             }),
           {:ok, _} <- Collaborators.add_collaborator(author, cloned_project),
           base_root_container <- AuthoringResolver.root_container(base_project.slug),
           {:ok, cloned_publication} <-
             Publishing.create_publication(%{
               project_id: cloned_project.id,
               root_resource_id: base_root_container.resource_id
             }),
           base_publication <- Publishing.project_working_publication(base_project.slug),
           _ <- Locks.release_all(base_publication.id),
           _ <- clone_all_published_resources(base_publication.id, cloned_publication.id),
           _ <- clone_all_project_resources(base_project.id, cloned_project.id),
           _ <- clone_all_media_items(base_project.id, cloned_project.id),
           _ <- clone_all_project_activity_registrations(base_project.id, cloned_project.id),
           Blueprint.get_blueprint_by_base_project(base_project)
           |> Enum.map(fn blueprint -> %{blueprint | base_project_id: cloned_project.id} end)
           |> clone_blueprints({base_project.id, cloned_publication.id}) do
        cloned_project
      else
        {:error, error} -> Repo.rollback(error)
      end
    end)
  end

  def clone_all_project_resources(base_project_id, cloned_project_id) do
    query = """
      INSERT INTO projects_resources(project_id, resource_id, inserted_at, updated_at)
      SELECT $1, resource_id, now(), now()
      FROM projects_resources as p
      WHERE p.project_id = $2;
    """

    Repo.query!(query, [cloned_project_id, base_project_id])
  end

  def clone_all_published_resources(base_publication_id, cloned_publication_id) do
    query = """
      INSERT INTO published_resources(publication_id, revision_id, resource_id, inserted_at, updated_at)
      SELECT $1, revision_id, resource_id, now(), now()
      FROM published_resources as p
      WHERE p.publication_id = $2;
    """

    Repo.query!(query, [cloned_publication_id, base_publication_id])
  end

  def clone_all_media_items(base_project_id, cloned_project_id) do
    query = """
      INSERT INTO media_items(project_id, url, file_name, mime_type, file_size, md5_hash, deleted, inserted_at, updated_at)
      SELECT $1, url, file_name, mime_type, file_size, md5_hash, deleted, now(), now()
      FROM media_items as p
      WHERE p.project_id = $2;
    """

    Repo.query!(query, [cloned_project_id, base_project_id])
  end

  def clone_all_project_activity_registrations(base_project_id, cloned_project_id) do
    query = """
      INSERT INTO activity_registration_projects(activity_registration_id, project_id, inserted_at, updated_at)
      SELECT activity_registration_id, $1, now(), now()
      FROM activity_registration_projects as p
      WHERE p.project_id = $2;
    """

    Repo.query!(query, [cloned_project_id, base_project_id])
  end

  @doc """
  Returns the existing clones from a parent project that an author might have.
  """
  def existing_clones(project_slug, author) do
    from(
      project in Project,
      join: p in Project,
      on: project.id == p.project_id,
      join: ap in AuthorProject,
      on:
        p.id ==
          ap.project_id and ap.author_id == ^author.id,
      where: project.slug == ^project_slug and p.status == :active,
      select: p
    )
    |> Repo.all()
  end

  @doc """
  Returns true if the given author already is a collaborator on a project that was cloned from the
  project specified by the given project slug.
  """
  def already_has_clone?(project_slug, author) do
    project_slug
    |> existing_clones(author)
    |> Enum.count() > 0
  end

  defp copy_attributes(base_project) do
    customizations =
      case base_project.customizations do
        nil -> nil
        labels -> Map.from_struct(labels)
      end

    attributes =
      case base_project.attributes do
        nil -> nil
        base_attributes -> from_struct(base_attributes)
      end

    {:ok, customizations, attributes}
  end

  defp from_struct(attribute) when is_map(attribute) do
    Map.from_struct(attribute)
    |> Map.keys()
    |> Enum.reduce(%{}, fn key, acc ->
      Map.put(acc, key, from_struct(Map.get(attribute, key)))
    end)
  end

  defp from_struct(attribute), do: attribute
end
