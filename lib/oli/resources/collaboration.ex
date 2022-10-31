defmodule Oli.Resources.Collaboration do
  alias Oli.Authoring.Course
  alias Oli.Authoring.Course.Project
  alias Oli.Publishing
  alias Oli.Publishing.Publication
  alias Oli.Resources
  alias Oli.Resources.ResourceType
  alias Oli.Repo

  import Oli.Utils

  # ------------------------------------------------------------
  # Collaborative Spaces

  @doc """
  Creates a new collaborative space (resource + revision) and attach it to the page_slug
  revision in the project.

  ## Examples

      iex> create_collaborative_space(%{status: :active, ...}, %Project{}, "slug", 123)
      {:ok,
        %{
          cs_resource: %Resource{},
          cs_revision: %Revision{},
          cs_published_resource: %PublishedResource{},
          project: %Project{},
          publication: %Publication{},
          page_resource: %Resource{},
          next_page_revision: %Revision{}
        }
      }

      iex> create_collaborative_space(%{status: :active, ...}, %Project{}, "invalid_slug", 123)
      {:error, {:error, {:not_found}}}
  """
  @spec create_collaborative_space(map(), %Project{}, String.t(), integer()) ::
          {:ok, map()} | {:error, String.t()}
  def create_collaborative_space(attrs, %Project{} = project, page_slug, author_id) do
    attrs =
      Map.merge(attrs, %{
        author_id: author_id,
        resource_type_id: ResourceType.get_id_by_type("collabspace")
      })

    Repo.transaction(fn ->
      with {:ok, %{resource: cs_resource, revision: cs_revision}} <-
            Course.create_and_attach_resource(project, attrs),
          %Publication{} = publication <- Publishing.project_working_publication(project.slug),
          {:ok, cs_published_resource} <-
            Publishing.upsert_published_resource(publication, cs_revision),
          {:ok, page_resource} <- Resources.get_resource_from_slug(page_slug) |> trap_nil(),
          {:ok, page_revision} <-
            Publishing.get_published_revision(publication.id, page_resource.id) |> trap_nil(),
          {:ok, next_page_revision} =
            Resources.create_revision_from_previous(page_revision, %{
              collab_space_id: cs_resource.id,
              author_id: author_id
            }),
          {:ok, _} = Publishing.upsert_published_resource(publication, next_page_revision) do
        %{
          cs_resource: cs_resource,
          cs_revision: cs_revision,
          cs_published_resource: cs_published_resource,
          project: project,
          publication: publication,
          page_resource: page_resource,
          next_page_revision: next_page_revision
        }
      else
        error -> Repo.rollback(error)
      end
    end)
  end

  @doc """
  Updates a collaborative space creating a new revision from previous, and upserting the
  published resource in the project.

  ## Examples

      iex> update_collaborative_space(123, %{status: :active, ...}, %Project{}, 123)
      {:ok, %Revision{}}

      iex> update_collaborative_space(789, %{status: :active, ...}, %Project{}, 123)
      {:error, {:error, {:not_found}}}
  """
  @spec update_collaborative_space(integer(), map(), %Project{}, String.t()) ::
          {:ok, map()} | {:error, String.t()}
  def update_collaborative_space(resource_id, attrs, %Project{} = project, author_id) do
    attrs = Map.merge(attrs, %{author_id: author_id})

    Repo.transaction(fn ->
      with %Publication{} = publication <- Publishing.project_working_publication(project.slug),
          {:ok, revision} <-
            Publishing.get_published_revision(publication.id, resource_id) |> trap_nil(),
          {:ok, new_revision} <- Resources.create_revision_from_previous(revision, attrs),
          {:ok, _} <- Publishing.upsert_published_resource(publication, new_revision) do
        new_revision
      else
        error -> Repo.rollback(error)
      end
    end)
  end

  @doc """
  Returns a list of collaborative spaces that belongs to a section.

  ## Examples

      iex> search_collaborative_spaces("slug")
      [%Revision{}, ...]

      iex> search_collaborative_spaces("invalid")
      []
  """
  def search_collaborative_spaces(section_slug) do
    collab_space_type_id = ResourceType.get_id_by_type("collabspace")

    Repo.all(
      from(
        section in Section,
        join: section_resource in SectionResource,
        on: section.id == section_resource.section_id,
        join: cs_revision in Revision,
        on:
          cs_revision.resource_id == section_resource.resource_id and
            cs_revision.resource_type_id == ^collab_space_type_id,
        join: page_revision in Revision,
        on: page_revision.collab_space_id == cs_revision.resource_id,
        where: section.slug == ^section_slug,
        select: %{
          collab_space: cs_revision,
          page: page_revision
        }
      )
    )
  end
end
