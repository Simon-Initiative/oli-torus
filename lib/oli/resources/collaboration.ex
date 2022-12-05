defmodule Oli.Resources.Collaboration do
  alias Oli.Authoring.Course.Project
  alias Oli.Publishing
  alias Oli.Publishing.{AuthoringResolver, DeliveryResolver, Publication, PublishedResource}
  alias Oli.Publishing.Publications.Publication
  alias Oli.Delivery
  alias Oli.Delivery.{DeliverySetting, Sections}
  alias Oli.Delivery.Sections.{Section, SectionResource, SectionsProjectsPublications}
  alias Oli.Resources
  alias Oli.Resources.{ResourceType, Revision}
  alias Oli.Resources.Collaboration.{CollabSpaceConfig, Post}
  alias Oli.Repo

  import Ecto.Query, warn: false
  import Oli.Utils

  # ------------------------------------------------------------
  # Collaborative Spaces

  @doc """
  Attach a new collaborative space config to the page_slug revision in the project.

  ## Examples

      iex> upsert_collaborative_space(%{status: :active, ...}, %Project{}, "slug", 123)
      {:ok,
        %{
          project: %Project{},
          publication: %Publication{},
          page_resource: %Resource{},
          next_page_revision: %Revision{}
        }
      }

      iex> upsert_collaborative_space(%{status: :active, ...}, %Project{}, "invalid_slug", 123)
      {:error, {:error, {:not_found}}}
  """
  @spec upsert_collaborative_space(map(), %Project{}, String.t(), integer()) ::
          {:ok, map()} | {:error, String.t()}
  def upsert_collaborative_space(attrs, %Project{} = project, page_slug, author_id) do
    Repo.transaction(fn ->
      with %Publication{} = publication <- Publishing.project_working_publication(project.slug),
           {:ok, page_resource} <- Resources.get_resource_from_slug(page_slug) |> trap_nil(),
           {:ok, page_revision} <-
             Publishing.get_published_revision(publication.id, page_resource.id) |> trap_nil(),
           {:ok, next_page_revision} <-
             Resources.create_revision_from_previous(page_revision, %{
               collab_space_config: attrs,
               author_id: author_id
             }),
           {:ok, _} <- Publishing.upsert_published_resource(publication, next_page_revision) do
        %{
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
  Returns a list of all pages that has a collab space config related in a section.

  ## Examples

      iex> list_collaborative_spaces_in_section("slug")
      [%{collab_space_config, revision, ...}, ...]

      iex> list_collaborative_spaces_in_section("invalid")
      []
  """
  @spec list_collaborative_spaces_in_section(String.t()) :: list(%CollabSpaceConfig{})
  def list_collaborative_spaces_in_section(section_slug) do
    page_type_id = ResourceType.get_id_by_type("page")

    Repo.all(
      from(
        section in Section,
        join: section_resource in SectionResource,
        on: section.id == section_resource.section_id,
        join: page_revision in Revision,
        on:
          page_revision.resource_id == section_resource.resource_id and
            page_revision.resource_type_id == ^page_type_id,
        join: section_project_publication in SectionsProjectsPublications,
        on:
          section.id == section_project_publication.section_id and
            section_resource.project_id == section_project_publication.project_id,
        join: published_resource in PublishedResource,
        on:
          published_resource.publication_id == section_project_publication.publication_id and
            published_resource.revision_id == page_revision.id,
        left_join: delivery_setting in DeliverySetting,
        on:
          delivery_setting.section_id == section.id and
            delivery_setting.resource_id == page_revision.resource_id,
        where:
          section.slug == ^section_slug and
            (not is_nil(page_revision.collab_space_config) or
               not is_nil(delivery_setting.collab_space_config)),
        select: %{
          id: fragment("concat(?, '_', ?)", section.id, page_revision.id),
          section: section,
          page: page_revision,
          collab_space_config:
            fragment(
              "case when ? is null then ? else ? end",
              delivery_setting.collab_space_config,
              page_revision.collab_space_config,
              delivery_setting.collab_space_config
            ),
          number_of_posts:
            fragment(
              "select count(*) from posts where section_id = ? and resource_id = ?",
              section.id,
              page_revision.resource_id
            ),
          number_of_posts_pending_approval:
            fragment(
              "select count(*) from posts where section_id = ? and resource_id = ? and status = 'submitted'",
              section.id,
              page_revision.resource_id
            ),
          most_recent_post:
            fragment(
              "select max(inserted_at) from posts where section_id = ? and resource_id = ?",
              section.id,
              page_revision.resource_id
            )
        }
      )
    )
  end

  @doc """
  Returns a list of all pages that has a collab space config related.

  ## Examples

      iex> list_collaborative_spaces()
      [%{collab_space_config, revision, ...}, ...]

      iex> list_collaborative_spaces()
      []
  """
  @spec list_collaborative_spaces() :: list(%CollabSpaceConfig{})
  def list_collaborative_spaces() do
    page_type_id = ResourceType.get_id_by_type("page")

    Repo.all(
      from(
        publication in Publication,
        join: project in Project,
        on: publication.project_id == project.id,
        join: published_resource in PublishedResource,
        on: publication.id == published_resource.publication_id,
        join: page_revision in Revision,
        on: page_revision.id == published_resource.revision_id,
        where:
          page_revision.resource_type_id == ^page_type_id and
            not is_nil(page_revision.collab_space_config) and
            is_nil(publication.published),
        select: %{
          id: fragment("concat(?, '_', ?)", project.id, page_revision.id),
          project: project,
          page: page_revision,
          collab_space_config: page_revision.collab_space_config,
          number_of_posts:
            fragment(
              "select count(*) from posts where resource_id = ?",
              page_revision.resource_id
            ),
          number_of_posts_pending_approval:
            fragment(
              "select count(*) from posts where resource_id = ? and status = 'submitted'",
              page_revision.resource_id
            ),
          most_recent_post:
            fragment(
              "select max(inserted_at) from posts where resource_id = ?",
              page_revision.resource_id
            )
        }
      )
    )
  end

  @doc """
  Returns the collaborative space config for a specific page in a section.
  Prioritize the config present in the "delivery_settings" relation and fallback to
  the config present in the page revision.

  ## Examples

      iex> get_collab_space_config_for_page_in_section("page_slug", "section_slug")
      {:ok, %CollabSpaceConfig{}}
      or
      {:ok, nil}

      iex> get_collab_space_config_for_page_in_section("invalid_slug", "invalid_slug")
      {:error, :not_found}
  """
  @spec get_collab_space_config_for_page_in_section(String.t(), String.t()) ::
          {:ok, %CollabSpaceConfig{}} | {:error, atom()}
  def get_collab_space_config_for_page_in_section(page_slug, section_slug) do
    with %Section{id: section_id} <- Sections.get_section_by(slug: section_slug),
         %Revision{
           resource_id: resource_id,
           collab_space_config: revision_collab_space_config
         } <- DeliveryResolver.from_revision_slug(section_slug, page_slug) do
      {:ok,
       case Delivery.get_delivery_setting_by(%{
              section_id: section_id,
              resource_id: resource_id
            }) do
         nil ->
           revision_collab_space_config

         %DeliverySetting{collab_space_config: ds_collab_space_config} ->
           ds_collab_space_config
       end}
    else
      _ -> {:error, :not_found}
    end
  end

  @doc """
  Returns the collaborative space config for a specific page in a project.

  ## Examples

      iex> get_collab_space_config_for_page_in_project("page_slug", "project_slug")
      {:ok, %CollabSpaceConfig{}}
      or
      {:ok, nil}

      iex> get_collab_space_config_for_page_in_project("invalid_slug", "invalid_slug")
      {:error, :not_found}
  """
  @spec get_collab_space_config_for_page_in_project(String.t(), String.t()) ::
          {:ok, %CollabSpaceConfig{}} | {:error, atom()}
  def get_collab_space_config_for_page_in_project(page_slug, project_slug) do
    case AuthoringResolver.from_revision_slug(project_slug, page_slug) do
      %Revision{
        collab_space_config: collab_space_config
      } ->
        {:ok, collab_space_config}

      _ ->
        {:error, :not_found}
    end
  end

  # ------------------------------------------------------------
  # Posts

  @doc """
  Returns the list of posts that meets the criteria passed in the filter.

  ## Examples

      iex> search_posts(%{status: :archived})
      [%Post{status: :archived}, ...]

      iex> search_posts(%{resource_id: 123})
      []
  """
  def search_posts(filter) do
    Repo.all(
      from(
        post in Post,
        where: ^filter_conditions(filter),
        select_merge: %{
          replies_count: fragment("select count(*) from posts where thread_root_id = ?", post.id)
        },
        order_by: [asc: :inserted_at],
        preload: [:user]
      )
    )
  end

  @doc """
  Creates a post.

  ## Examples

      iex> create_post(%{field: new_value})
      {:ok, %Post{}}

      iex> create_post(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_post(attrs \\ %{}) do
    %Post{}
    |> Post.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a post that meets the criteria passed in the clauses.

  ## Examples

      iex> get_post_by(%{id: 1})
      %Post{}

      iex> get_post_by(%{id: 123})
      nil
  """
  def get_post_by(clauses),
    do: Repo.get_by(Post, clauses)

  @doc """
  Updates a post.

  ## Examples

      iex> update_post(post, %{field: new_value})
      {:ok, %Post{}}

      iex> update_post(post, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_post(%Post{} = post, attrs) do
    post
    |> Post.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking post changes.

  ## Examples

      iex> change_post(post)
      %Ecto.Changeset{data: %Post{}}
  """
  def change_post(%Post{} = post, attrs \\ %{}) do
    Post.changeset(post, attrs)
  end
end
