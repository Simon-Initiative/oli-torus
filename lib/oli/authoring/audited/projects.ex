defmodule Oli.Authoring.Audited.Projects do
  @moduledoc false
  # Raw project creation, duplication, and collaborator writes, used only by
  # `Oli.Authoring.Audited`, which owns the transaction and records the events.

  import Ecto.Query, only: [from: 2]
  import Oli.Authoring.Editing.Utils, only: [trap_nil: 1]

  alias Oli.Accounts.Author
  alias Oli.Authoring.{Clone, Collaborators, Course, Locks}
  alias Oli.Authoring.Authors.{AuthorProject, ProjectRole}
  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Sections.Blueprint
  alias Oli.Inventories
  alias Oli.Publishing
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Repo

  @doc """
  Creates the project, its family, the owner collaboration, the root container, and the initial
  working publication. Must run inside a transaction.
  """
  def create(title, %Author{} = author, attrs, learning_model_version, lo_well_formed) do
    with {:ok, family} <- Course.create_family(default_family(title)),
         {:ok, project} <-
           insert_project(
             default_project(title, family, attrs),
             learning_model_version,
             lo_well_formed
           ),
         {:ok, collaborator} <- insert_collaborator(author, project, :accepted),
         {:ok, %{resource: resource, revision: resource_revision}} <-
           Course.initial_resource_setup(author, project),
         {:ok, %{publication: publication, published_resource: published_resource}} <-
           Publishing.initial_publication_setup(project, resource, resource_revision) do
      {:ok,
       %{
         project_family: family,
         project: project,
         author_project: collaborator,
         resource: resource,
         resource_revision: resource_revision,
         publication: publication,
         published_resource: published_resource
       }}
    end
  end

  @doc """
  Copies the project with `project_slug` for `author`, who becomes the owner of the copy.
  Returns `{:ok, {base_project, cloned_project}}`. Must run inside a transaction.
  """
  def duplicate(project_slug, %Author{} = author, opts) do
    title_suffix =
      if opts[:author_in_project_title], do: " <#{author.email}>", else: " Copy"

    with {:ok, base_project} <-
           Course.get_project_by_slug(project_slug) |> Repo.preload(:family) |> trap_nil(),
         {:ok, cloned_family} <-
           Course.create_family(%{
             title: base_project.family.title <> " Copy",
             description: base_project.family.description
           }),
         {:ok, customizations, attributes} <- copy_attributes(base_project),
         {:ok, cloned_project} <-
           %Project{}
           |> Project.changeset(%{
             title: base_project.title <> title_suffix,
             version: "1.0.0",
             family_id: cloned_family.id,
             project_id: base_project.id,
             publisher_id: base_project.publisher_id,
             required_survey_resource_id: base_project.required_survey_resource_id,
             customizations: customizations,
             attributes: attributes,
             analytics_version: :v2
           })
           |> Project.trusted_learning_model_changeset(%{
             learning_model_version: base_project.learning_model_version
           })
           |> Project.trusted_lo_well_formed_changeset(%{
             lo_well_formed: base_project.lo_well_formed
           })
           |> Repo.insert(),
         {:ok, _} <- insert_collaborator(author, cloned_project, :accepted),
         base_root_container <- AuthoringResolver.root_container(base_project.slug),
         {:ok, cloned_publication} <-
           Publishing.create_publication(%{
             project_id: cloned_project.id,
             root_resource_id: base_root_container.resource_id
           }),
         base_publication <- Publishing.project_working_publication(base_project.slug),
         _ <- Locks.release_all(base_publication.id),
         _ <- Clone.clone_all_published_resources(base_publication.id, cloned_publication.id),
         _ <- Clone.clone_all_project_resources(base_project.id, cloned_project.id),
         _ <- Clone.clone_all_media_items(base_project.id, cloned_project.id),
         _ <-
           Clone.clone_all_project_activity_registrations(base_project.id, cloned_project.id),
         Blueprint.get_blueprint_by_base_project(base_project)
         |> Enum.map(fn blueprint -> %{blueprint | base_project_id: cloned_project.id} end)
         |> Clone.clone_blueprints({base_project.id, cloned_publication.id}) do
      {:ok, {base_project, cloned_project}}
    end
  end

  @doc """
  Inserts the collaboration of `author` on `project` with `status`. The first collaborator of a
  project is its owner; everyone else is a contributor.
  """
  def insert_collaborator(%Author{} = author, %Project{} = project, status) do
    case Collaborators.change_collaborator(author.email, project.slug, status) do
      %Ecto.Changeset{} = changeset -> Repo.insert(changeset)
      {:error, message} -> {:error, message}
    end
  end

  @doc "Locks the collaboration of `author_id` on `project_id` and returns it with its role."
  def lock_collaborator(author_id, project_id) do
    from(ap in AuthorProject,
      where: ap.author_id == ^author_id and ap.project_id == ^project_id,
      lock: "FOR UPDATE"
    )
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      author_project -> {:ok, Repo.preload(author_project, :project_role)}
    end
  end

  @doc "Updates the status of a collaboration."
  def update_collaborator_status(%AuthorProject{} = author_project, status) do
    author_project
    |> AuthorProject.changeset(%{status: status})
    |> Repo.update()
  end

  @doc "Deletes a collaboration."
  def delete_collaborator(%AuthorProject{} = author_project), do: Repo.delete(author_project)

  @doc "Returns the role type (`owner` or `contributor`) of a collaboration."
  def role_type(%AuthorProject{project_role: %ProjectRole{type: type}}), do: type

  def role_type(%AuthorProject{} = author_project),
    do: author_project |> Repo.preload(:project_role) |> role_type()

  @doc "Locks the project row and returns it."
  def lock_project(project_id) do
    from(p in Project, where: p.id == ^project_id, lock: "FOR NO KEY UPDATE")
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      project -> {:ok, project}
    end
  end

  @doc "Marks the project deleted."
  def mark_deleted(%Project{} = project) do
    project
    |> Project.changeset(%{status: :deleted})
    |> Repo.update()
  end

  defp insert_project(attrs, learning_model_version, lo_well_formed) do
    %Project{}
    |> Project.changeset(attrs)
    |> Project.trusted_learning_model_changeset(%{learning_model_version: learning_model_version})
    |> maybe_set_lo_well_formed(lo_well_formed)
    |> Repo.insert()
  end

  defp maybe_set_lo_well_formed(changeset, :use_default), do: changeset

  defp maybe_set_lo_well_formed(changeset, lo_well_formed),
    do: Project.trusted_lo_well_formed_changeset(changeset, %{lo_well_formed: lo_well_formed})

  defp default_family(title),
    do: %{title: title, description: "New family from project creation"}

  defp default_project(title, family, attrs) do
    Map.merge(
      %{
        title: title,
        version: "1.0.0",
        family_id: family.id,
        publisher_id: Inventories.default_publisher().id,
        analytics_version: :v2
      },
      attrs
    )
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
    |> Enum.reduce(%{}, fn key, acc -> Map.put(acc, key, from_struct(Map.get(attribute, key))) end)
  end

  defp from_struct(attribute), do: attribute
end
