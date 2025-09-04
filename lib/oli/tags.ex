defmodule Oli.Tags do
  @moduledoc """
  The Tags context provides functions for managing tags and their associations
  with projects, sections, and products.

  Tags provide a way to categorize and organize projects, sections, and products
  for easier browsing and management in the admin interface.

  ## Key Features

  - Create and manage tags
  - Associate tags with projects, sections, and products
  - Search and filter tags
  - Handle both regular sections and products (blueprint sections)

  ## Usage

      # Create a tag
      {:ok, tag} = Oli.Tags.create_tag(%{name: "Biology"})

      # Associate tag with a project
      {:ok, _} = Oli.Tags.associate_tag_with_project(project, tag)

      # Get all tags for a project
      tags = Oli.Tags.get_project_tags(project)

      # Search tags
      tags = Oli.Tags.list_tags(%{search: "bio"})
  """

  import Ecto.Query, warn: false
  alias Oli.Repo

  alias Oli.Tags.Tag
  alias Oli.Tags.ProjectTag
  alias Oli.Tags.SectionTag
  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Sections.Section

  @doc """
  Creates a tag.

  ## Examples

      iex> create_tag(%{name: "Biology"})
      {:ok, %Tag{}}

      iex> create_tag(%{name: ""})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_tag(map()) :: {:ok, Tag.t()} | {:error, Ecto.Changeset.t()}
  def create_tag(attrs \\ %{}) do
    %Tag{}
    |> Tag.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a tag by name.

  ## Examples

      iex> get_tag_by_name("Biology")
      %Tag{}

      iex> get_tag_by_name("nonexistent")
      nil

  """
  @spec get_tag_by_name(String.t()) :: Tag.t() | nil
  def get_tag_by_name(name) when is_binary(name) do
    Repo.get_by(Tag, name: name)
  end

  @doc """
  Lists tags with optional search and pagination.

  ## Options

  - `:search` - Search term to filter tags by name
  - `:limit` - Maximum number of tags to return (default: 50)
  - `:offset` - Number of tags to skip (default: 0)

  ## Examples

      iex> list_tags()
      [%Tag{}, ...]

      iex> list_tags(%{search: "bio"})
      [%Tag{name: "Biology"}, ...]

      iex> list_tags(%{limit: 10, offset: 20})
      [%Tag{}, ...]

  """
  @spec list_tags(map()) :: [Tag.t()]
  def list_tags(opts \\ %{}) do
    search = Map.get(opts, :search, "")
    limit = Map.get(opts, :limit, 50)
    offset = Map.get(opts, :offset, 0)

    Tag
    |> maybe_search_by_name(search)
    |> order_by([t], asc: t.name)
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
  end

  @doc """
  Associates a tag with a project.

  ## Examples

      iex> associate_tag_with_project(project, tag)
      {:ok, %ProjectTag{}}

      iex> associate_tag_with_project(project, nonexistent_tag)
      {:error, :tag_not_found}

  """
  @spec associate_tag_with_project(Project.t() | integer(), Tag.t() | integer()) ::
          {:ok, ProjectTag.t()}
          | {:error, :tag_not_found | :project_not_found | Ecto.Changeset.t()}
  def associate_tag_with_project(project, tag) do
    project_id = get_entity_id(project)
    tag_id = get_entity_id(tag)

    with {:ok, _project} <- get_entity(Project, project_id),
         {:ok, _tag} <- get_entity(Tag, tag_id) do
      %ProjectTag{project_id: project_id, tag_id: tag_id}
      |> Repo.insert(on_conflict: :nothing)
      |> case do
        {:ok, result} -> {:ok, result}
        {:error, %Ecto.Changeset{}} -> {:error, :already_exists}
      end
    end
  end

  @doc """
  Associates a tag with a section (works for both regular sections and products).

  ## Examples

      iex> associate_tag_with_section(section, tag)
      {:ok, %SectionTag{}}

      iex> associate_tag_with_section(product, tag)
      {:ok, %SectionTag{}}

  """
  @spec associate_tag_with_section(Section.t() | integer(), Tag.t() | integer()) ::
          {:ok, SectionTag.t()}
          | {:error, :tag_not_found | :section_not_found | Ecto.Changeset.t()}
  def associate_tag_with_section(section, tag) do
    section_id = get_entity_id(section)
    tag_id = get_entity_id(tag)

    with {:ok, _section} <- get_entity(Section, section_id),
         {:ok, _tag} <- get_entity(Tag, tag_id) do
      %SectionTag{section_id: section_id, tag_id: tag_id}
      |> Repo.insert(on_conflict: :nothing)
      |> case do
        {:ok, result} -> {:ok, result}
        {:error, %Ecto.Changeset{}} -> {:error, :already_exists}
      end
    end
  end

  @doc """
  Removes a tag from a project.

  ## Options

  - `:remove_if_unused` - If true, also deletes the tag from the database if it becomes unused (default: false)

  ## Returns

  - `{:ok, %ProjectTag{}, :removed_from_entity}` - Tag association removed, tag still exists in database
  - `{:ok, %Tag{}, :completely_removed}` - Tag association removed and tag deleted from database
  - `{:error, :not_found}` - No association found between project and tag

  ## Examples

      iex> remove_tag_from_project(project, tag)
      {:ok, %ProjectTag{}, :removed_from_entity}

      iex> remove_tag_from_project(project, tag, remove_if_unused: true)
      {:ok, %Tag{}, :completely_removed}

      iex> remove_tag_from_project(project, nonexistent_tag)
      {:error, :not_found}

  """
  @spec remove_tag_from_project(Project.t() | integer(), Tag.t() | integer(), keyword()) ::
          {:ok, ProjectTag.t(), :removed_from_entity}
          | {:ok, Tag.t(), :completely_removed}
          | {:error, :not_found}
  def remove_tag_from_project(project, tag, opts \\ []) do
    project_id = get_entity_id(project)
    tag_id = get_entity_id(tag)
    remove_if_unused = Keyword.get(opts, :remove_if_unused, false)

    case Repo.get_by(ProjectTag, project_id: project_id, tag_id: tag_id) do
      nil ->
        {:error, :not_found}

      project_tag ->
        if remove_if_unused do
          # Count total usage of this tag across projects and sections
          project_count_query =
            from(pt in ProjectTag, where: pt.tag_id == ^tag_id, select: count())

          section_count_query =
            from(st in SectionTag, where: st.tag_id == ^tag_id, select: count())

          project_count = Repo.one(project_count_query) || 0
          section_count = Repo.one(section_count_query) || 0
          total_usage = project_count + section_count

          if total_usage <= 1 do
            # This is the last usage, delete the tag itself (cascade will remove associations)
            case Repo.get(Tag, tag_id) do
              nil ->
                case Repo.delete(project_tag) do
                  {:ok, deleted_project_tag} -> {:ok, deleted_project_tag, :removed_from_entity}
                  {:error, changeset} -> {:error, changeset}
                end

              tag ->
                case Repo.delete(tag) do
                  {:ok, deleted_tag} -> {:ok, deleted_tag, :completely_removed}
                  {:error, changeset} -> {:error, changeset}
                end
            end
          else
            # Tag is still used elsewhere, just remove the association
            case Repo.delete(project_tag) do
              {:ok, deleted_project_tag} -> {:ok, deleted_project_tag, :removed_from_entity}
              {:error, changeset} -> {:error, changeset}
            end
          end
        else
          # Standard behavior: just remove the association
          case Repo.delete(project_tag) do
            {:ok, deleted_project_tag} -> {:ok, deleted_project_tag, :removed_from_entity}
            {:error, changeset} -> {:error, changeset}
          end
        end
    end
  end

  @doc """
  Removes a tag from a section (works for both regular sections and products).

  ## Options

  - `:remove_if_unused` - If true, also deletes the tag from the database if it becomes unused (default: false)

  ## Returns

  - `{:ok, %SectionTag{}, :removed_from_entity}` - Tag association removed, tag still exists in database
  - `{:ok, %Tag{}, :completely_removed}` - Tag association removed and tag deleted from database
  - `{:error, :not_found}` - No association found between section and tag

  ## Examples

      iex> remove_tag_from_section(section, tag)
      {:ok, %SectionTag{}, :removed_from_entity}

      iex> remove_tag_from_section(product, tag, remove_if_unused: true)
      {:ok, %Tag{}, :completely_removed}

      iex> remove_tag_from_section(section, nonexistent_tag)
      {:error, :not_found}

  """
  @spec remove_tag_from_section(Section.t() | integer(), Tag.t() | integer(), keyword()) ::
          {:ok, SectionTag.t(), :removed_from_entity}
          | {:ok, Tag.t(), :completely_removed}
          | {:error, :not_found}
  def remove_tag_from_section(section, tag, opts \\ []) do
    section_id = get_entity_id(section)
    tag_id = get_entity_id(tag)
    remove_if_unused = Keyword.get(opts, :remove_if_unused, false)

    case Repo.get_by(SectionTag, section_id: section_id, tag_id: tag_id) do
      nil ->
        {:error, :not_found}

      section_tag ->
        if remove_if_unused do
          # Count total usage of this tag across projects and sections
          project_count_query =
            from(pt in ProjectTag, where: pt.tag_id == ^tag_id, select: count())

          section_count_query =
            from(st in SectionTag, where: st.tag_id == ^tag_id, select: count())

          project_count = Repo.one(project_count_query) || 0
          section_count = Repo.one(section_count_query) || 0
          total_usage = project_count + section_count

          if total_usage <= 1 do
            # This is the last usage, delete the tag itself (cascade will remove associations)
            case Repo.get(Tag, tag_id) do
              nil ->
                case Repo.delete(section_tag) do
                  {:ok, deleted_section_tag} -> {:ok, deleted_section_tag, :removed_from_entity}
                  {:error, changeset} -> {:error, changeset}
                end

              tag ->
                case Repo.delete(tag) do
                  {:ok, deleted_tag} -> {:ok, deleted_tag, :completely_removed}
                  {:error, changeset} -> {:error, changeset}
                end
            end
          else
            # Tag is still used elsewhere, just remove the association
            case Repo.delete(section_tag) do
              {:ok, deleted_section_tag} -> {:ok, deleted_section_tag, :removed_from_entity}
              {:error, changeset} -> {:error, changeset}
            end
          end
        else
          # Standard behavior: just remove the association
          case Repo.delete(section_tag) do
            {:ok, deleted_section_tag} -> {:ok, deleted_section_tag, :removed_from_entity}
            {:error, changeset} -> {:error, changeset}
          end
        end
    end
  end

  @doc """
  Gets all tags associated with a project.

  ## Examples

      iex> get_project_tags(project)
      [%Tag{}, ...]

  """
  @spec get_project_tags(Project.t() | integer()) :: [Tag.t()]
  def get_project_tags(project) do
    project_id = get_entity_id(project)

    Tag
    |> join(:inner, [t], pt in ProjectTag, on: t.id == pt.tag_id)
    |> where([t, pt], pt.project_id == ^project_id)
    |> order_by([t], asc: t.name)
    |> Repo.all()
  end

  @doc """
  Gets all tags associated with a section (works for both regular sections and products).

  ## Examples

      iex> get_section_tags(section)
      [%Tag{}, ...]

      iex> get_section_tags(product)
      [%Tag{}, ...]

  """
  @spec get_section_tags(Section.t() | integer()) :: [Tag.t()]
  def get_section_tags(section) do
    section_id = get_entity_id(section)

    Tag
    |> join(:inner, [t], st in SectionTag, on: t.id == st.tag_id)
    |> where([t, st], st.section_id == ^section_id)
    |> order_by([t], asc: t.name)
    |> Repo.all()
  end

  @doc """
  Gets or creates a tag by name. If the tag doesn't exist, it creates it.

  ## Examples

      iex> get_or_create_tag("Biology")
      {:ok, %Tag{}}

      iex> get_or_create_tag("New Tag")
      {:ok, %Tag{}}

  """
  @spec get_or_create_tag(String.t()) :: {:ok, Tag.t()}
  def get_or_create_tag(name) when is_binary(name) do
    case get_tag_by_name(name) do
      nil -> create_tag(%{name: name})
      tag -> {:ok, tag}
    end
  end

  @doc """
  Gets tags that match a search term, useful for autocomplete functionality.

  ## Examples

      iex> search_tags("bio")
      [%Tag{name: "Biology"}, %Tag{name: "Biochemistry"}, ...]

  """
  @spec search_tags(String.t(), integer()) :: [Tag.t()]
  def search_tags(search_term, limit \\ 10) when is_binary(search_term) do
    Tag
    |> where([t], ilike(t.name, ^"%#{search_term}%"))
    |> order_by([t], asc: t.name)
    |> limit(^limit)
    |> Repo.all()
  end

  # Private helper functions

  defp maybe_search_by_name(query, ""), do: query

  defp maybe_search_by_name(query, search) when is_binary(search) do
    where(query, [t], ilike(t.name, ^"%#{search}%"))
  end

  defp get_entity_id(%{id: id}), do: id
  defp get_entity_id(id) when is_integer(id), do: id

  defp get_entity(schema, id) do
    case Repo.get(schema, id) do
      nil -> {:error, :not_found}
      entity -> {:ok, entity}
    end
  end
end
