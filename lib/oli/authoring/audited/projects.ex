defmodule Oli.Authoring.Audited.Projects do
  @moduledoc false
  # Project lifecycle commands of `Oli.Authoring.Audited`, which validates their arguments, and
  # the project writes they run.

  import Ecto.Query, only: [from: 2]
  import Oli.Authoring.Audited.Support, only: [record: 2]
  import Oli.Authoring.Editing.Utils, only: [trap_nil: 1]

  alias Oli.Accounts.Author
  alias Oli.Authoring.Audited.Collaborators
  alias Oli.Authoring.{Clone, Course, Locks}
  alias Oli.Authoring.Authors.AuthorProject
  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Sections.Blueprint
  alias Oli.Inventories
  alias Oli.Publishing
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Repo

  ## Commands

  def create_project(context, title, author, attrs, opts) do
    learning_model_version = Keyword.get(opts, :learning_model_version, :lkt_aoa)
    lo_well_formed = Keyword.get(opts, :lo_well_formed, :use_default)

    record_creation(context, :project_created, fn ->
      create(title, author, attrs, learning_model_version, lo_well_formed)
    end)
  end

  def import_project(context, title, author, learning_model_version, attrs) do
    lo_well_formed = Map.get(attrs, :lo_well_formed)
    attrs = Map.delete(attrs, :lo_well_formed)

    record_creation(context, :project_imported, fn ->
      create(title, author, attrs, learning_model_version, lo_well_formed)
    end)
  end

  def duplicate_project(context, project_slug, author, opts) do
    Repo.transaction(fn ->
      with {:ok, {base_project, project}} <- duplicate(project_slug, author, opts),
           :ok <-
             record(context, project_event(:project_duplicated, project, author, base_project)) do
        project
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  def delete_project(context, project_id) do
    Repo.transaction(fn ->
      with {:ok, project} <- lock_project(project_id),
           {:ok, deleted} <- delete_once(context, project) do
        deleted
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp delete_once(_context, %Project{status: :deleted} = project), do: {:ok, project}

  defp delete_once(context, project) do
    with {:ok, deleted} <- mark_deleted(project),
         :ok <- record(context, project_event(:project_deleted, deleted, nil, nil)) do
      {:ok, deleted}
    end
  end

  # Function-style transactions (the creation steps use them) compose as savepoints of an
  # enclosing transaction, so the archive ingest can call `import_project/5` inside its own.
  defp record_creation(context, event_type, build) do
    Repo.transaction(fn ->
      with {:ok, %{project: project, author_project: owner} = created} <- build.(),
           :ok <- record(context, project_event(event_type, project, owner, nil)) do
        created
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp project_event(event_type, %Project{} = project, owner, source) do
    key =
      case event_type do
        :project_created -> "created"
        :project_imported -> "imported"
        :project_duplicated -> "duplicated"
        :project_deleted -> "deleted"
      end

    %{
      event_type: event_type,
      entity: {:project, project.id, project},
      scope: %{project_id: project.id},
      event_key: "project:#{project.id}:#{key}",
      details: %{project_title: project.title}
    }
    |> put_owner(owner)
    |> put_source(source)
  end

  defp put_owner(proposal, nil), do: proposal
  defp put_owner(proposal, %Author{id: id}), do: Map.put(proposal, :affected, {:author, id})

  defp put_owner(proposal, %AuthorProject{author_id: id}),
    do: Map.put(proposal, :affected, {:author, id})

  defp put_source(proposal, nil), do: proposal

  defp put_source(proposal, %Project{} = source) do
    proposal
    |> Map.put(:refs, [%{role: :source, type: :project, id: source.id, label: source.title}])
    |> Map.update!(:details, &Map.put(&1, :source_project_id, source.id))
  end

  ## Writes

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
         {:ok, collaborator} <- Collaborators.insert_collaborator(author, project, :accepted),
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
         {:ok, _} <- Collaborators.insert_collaborator(author, cloned_project, :accepted),
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
