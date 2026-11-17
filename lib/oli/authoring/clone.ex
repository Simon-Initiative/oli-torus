defmodule Oli.Authoring.Clone do
  import Ecto.Query, warn: false
  alias Oli.Repo
  alias Oli.Authoring.Course.Project
  alias Oli.Authoring.Authors.AuthorProject
  alias Oli.Delivery.Sections.Blueprint

  def clone_blueprints(blueprints, cloned_from_project_publication_ids) do
    Enum.map(blueprints, &Blueprint.duplicate(&1, %{}, cloned_from_project_publication_ids))
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
end
