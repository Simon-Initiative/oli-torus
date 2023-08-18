defmodule Oli.Resources.Collaboration do
  alias Oli.Authoring.Course.Project
  alias Oli.Publishing
  alias Oli.Publishing.{AuthoringResolver, DeliveryResolver, Publication, PublishedResource}
  alias Oli.Publishing.Publications.Publication
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.{Section, SectionResource, SectionsProjectsPublications}
  alias Oli.Resources
  alias Oli.Resources.{ResourceType, Revision}
  alias Oli.Resources.Collaboration.{CollabSpaceConfig, Post}
  alias Oli.Repo
  alias Oli.Accounts.User

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
  @spec list_collaborative_spaces_in_section(String.t(), limit: Integer.t(), offset: Integer.t()) ::
          {Integer.t(), list(%CollabSpaceConfig{})}
  def list_collaborative_spaces_in_section(section_slug, opts \\ []) do
    page_type_id = ResourceType.get_id_by_type("page")

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
      where:
        section.slug == ^section_slug and
          (not is_nil(page_revision.collab_space_config) or
             not is_nil(section_resource.collab_space_config)),
      select: %{
        id: fragment("concat(?, '_', ?)", section.id, page_revision.id),
        section: section,
        page: page_revision,
        collab_space_config:
          fragment(
            "case when ? is null then ? else ? end",
            section_resource.collab_space_config,
            page_revision.collab_space_config,
            section_resource.collab_space_config
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
          ),
        count: over(count(page_revision.id))
      },
      order_by: section.id
    )
    |> maybe_add_query_limit(opts[:limit])
    |> maybe_add_query_offset(opts[:offset])
    |> Repo.all()
    |> return_results_with_count()
  end

  defp maybe_add_query_limit(query, nil), do: query
  defp maybe_add_query_limit(query, limit), do: limit(query, ^limit)

  defp maybe_add_query_offset(query, nil), do: query
  defp maybe_add_query_offset(query, offset), do: offset(query, ^offset)

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
      case Sections.get_section_resource(section_id, resource_id) do
        %{collab_space_config: nil} -> {:ok, revision_collab_space_config}
        %{collab_space_config: sr_collab_space_config} -> {:ok, sr_collab_space_config}
      end
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
  Returns the list of posts that a user can see.

  ## Examples

      iex> list_posts_for_user_in_page_section(1, 1, 1))
      [%Post{status: :archived}, ...]

      iex> list_posts_for_user_in_page_section(2, 2, 2)
      []
  """
  def list_posts_for_user_in_page_section(section_id, resource_id, user_id, enter_time \\ nil) do
    filter_by_enter_time =
      if is_nil(enter_time) do
        true
      else
        dynamic([p], p.inserted_at >= ^enter_time or p.updated_at >= ^enter_time)
      end

    Repo.all(
      from(
        post in Post,
        where:
          post.section_id == ^section_id and post.resource_id == ^resource_id and
            (post.status in [:approved, :archived] or
               (post.status == :submitted and post.user_id == ^user_id)),
        where: ^filter_by_enter_time,
        select: post,
        order_by: [asc: :inserted_at],
        preload: [:user]
      )
    )
  end

  @doc """
  Returns the list of posts that a instructor can see.

  ## Examples

      iex> list_posts_for_instructor_in_page_section(1, 1)
      [%Post{status: :submitted}, ...]

      iex> list_posts_for_instructor_in_page_section(2, 2)
      []
  """
  def list_posts_for_instructor_in_page_section(section_id, resource_id) do
    Repo.all(
      from(
        post in Post,
        where:
          post.section_id == ^section_id and post.resource_id == ^resource_id and
            post.status != :deleted,
        select: post,
        order_by: [asc: :inserted_at],
        preload: [:user]
      )
    )
  end

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
        }
      )
    )
  end

  @doc """
  Returns the list of posts created by an user in a section.

  ## Examples

      iex> list_last_posts_for_user(1, 1, 5)
      [%Post{status: :archived}, ...]

      iex> list_last_posts_for_user(2, 2, 10)
      []
  """

  def list_lasts_posts_for_user(user_id, section_id, limit) do
    Repo.all(
      from(
        post in Post,
        join: sr in SectionResource,
        on: sr.resource_id == post.resource_id and sr.section_id == post.section_id,
        join: spp in SectionsProjectsPublications,
        on: spp.section_id == post.section_id and spp.project_id == sr.project_id,
        join: pr in PublishedResource,
        on: pr.publication_id == spp.publication_id and pr.resource_id == post.resource_id,
        join: rev in Revision,
        on: rev.id == pr.revision_id,
        join: user in User,
        on: post.user_id == user.id,
        where:
          post.section_id == ^section_id and post.user_id == ^user_id and
            (post.status in [:approved, :archived] or
               (post.status == :submitted and post.user_id == ^user_id)),
        select: %{
          id: post.id,
          content: post.content,
          user_name: user.name,
          title: rev.title,
          slug: rev.slug,
          resource_type_id: rev.resource_type_id,
          updated_at: post.updated_at
        },
        order_by: [desc: :updated_at],
        limit: ^limit
      )
    )
  end

  @doc """
  Returns the list of posts created in all resources of section.

  ## Examples

      iex> list_last_posts_for_section(1, 1, 5)
      [%Post{status: :archived}, ...]

      iex> list_last_posts_for_section(2, 2, 10)
      []
  """

  def list_lasts_posts_for_section(user_id, section_id, limit) do
    Repo.all(
      from(
        post in Post,
        join: sr in SectionResource,
        on: sr.resource_id == post.resource_id and sr.section_id == post.section_id,
        join: spp in SectionsProjectsPublications,
        on: spp.section_id == post.section_id and spp.project_id == sr.project_id,
        join: pr in PublishedResource,
        on: pr.publication_id == spp.publication_id and pr.resource_id == post.resource_id,
        join: rev in Revision,
        on: rev.id == pr.revision_id,
        join: user in User,
        on: post.user_id == user.id,
        where:
          post.section_id == ^section_id and post.user_id != ^user_id and
            post.status in [:approved, :archived],
        select: %{
          id: post.id,
          content: post.content,
          user_name: user.name,
          title: rev.title,
          slug: rev.slug,
          resource_type_id: rev.resource_type_id,
          updated_at: post.updated_at
        },
        order_by: [desc: :updated_at],
        limit: ^limit
      )
    )
  end

  @doc """
  Returns the posts that are pending of approval for a given section.

  ## Examples

      iex> pending_approval_posts("example_section")
      [%Post{status: :archived}, ...]

      iex> pending_approval_posts("example_section")
      []
  """
  def pending_approval_posts(section_slug) do
    do_list_posts_in_section_for_instructor(
      section_slug,
      0,
      nil
    )
    |> where([_s, p], p.status == :submitted)
    |> Repo.all()
  end

  @doc """
  Returns the list of all posts across a section given a certain criteria.

  ## Examples

      iex> list_posts_in_section_for_instructor("example_section", :need_approval, 0, 5)
      [%Post{status: :archived}, ...]

      iex> list_posts_in_section_for_instructor("example_section", :need_response, 0, 5)
      []
  """

  def list_posts_in_section_for_instructor(section_slug, filter, opts \\ [offset: 0, limit: 10])

  def list_posts_in_section_for_instructor(section_slug, :need_approval, opts) do
    do_list_posts_in_section_for_instructor(
      section_slug,
      Keyword.get(opts, :offset, 0),
      Keyword.get(opts, :limit)
    )
    |> where([_s, p], p.status == :submitted)
    |> Repo.all()
    |> return_results_with_count()
  end

  def list_posts_in_section_for_instructor(section_slug, :need_response, opts) do
    do_list_posts_in_section_for_instructor(
      section_slug,
      Keyword.get(opts, :offset, 0),
      Keyword.get(opts, :limit)
    )
    |> join(:left, [_s, p, _spp, _pr, _r, _u], p2 in Post,
      on: p2.parent_post_id == p.id or p2.thread_root_id == p.id
    )
    |> where(
      [_s, p, _spp, _pr, _r, _u, p2],
      is_nil(p2) and is_nil(p.parent_post_id) and is_nil(p.thread_root_id)
    )
    |> Repo.all()
    |> return_results_with_count()
  end

  def list_posts_in_section_for_instructor(section_slug, :all, opts) do
    do_list_posts_in_section_for_instructor(
      section_slug,
      Keyword.get(opts, :offset, 0),
      Keyword.get(opts, :limit)
    )
    |> Repo.all()
    |> return_results_with_count()
  end

  defp return_results_with_count([]), do: {0, []}

  defp return_results_with_count([first_post | _rest] = posts) do
    {first_post.count, Enum.map(posts, &Map.delete(&1, :count))}
  end

  defp do_list_posts_in_section_for_instructor(section_id_or_slug, offset, limit) do
    section_join =
      case is_number(section_id_or_slug) do
        true -> dynamic([s], s.id == ^section_id_or_slug)
        false -> dynamic([s], s.slug == ^section_id_or_slug)
      end

    Section
    |> join(:inner, [s], p in Post, on: p.section_id == s.id)
    |> join(:inner, [s], spp in SectionsProjectsPublications, on: spp.section_id == s.id)
    |> join(:inner, [s, p, spp], pr in PublishedResource,
      on: pr.publication_id == spp.publication_id and pr.resource_id == p.resource_id
    )
    |> join(:inner, [_s, _p, _spp, pr], r in Revision, on: r.id == pr.revision_id)
    |> join(:inner, [_s, p, _spp], u in User, on: p.user_id == u.id)
    |> where(^section_join)
    |> where([_s, p], p.status != :deleted)
    |> select([s, p, spp, pr, r, u], %{
      id: p.id,
      content: p.content,
      user_name: u.name,
      slug: r.slug,
      title: r.title,
      resource_type_id: r.resource_type_id,
      inserted_at: p.inserted_at,
      status: p.status,
      count: over(count(p.id))
    })
    |> limit(^limit)
    |> offset(^offset)
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
  Delete a post or a set of posts.

  ## Examples

      iex> delete_posts(post)
      {number, nil | returned data}` where number is the number of deleted entries
  """
  def delete_posts(%Post{} = post) do
    from(
      p in Post,
      where: ^post.id == p.id or ^post.id == p.parent_post_id or ^post.id == p.thread_root_id
    )
    |> Repo.update_all(set: [status: :deleted])
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
