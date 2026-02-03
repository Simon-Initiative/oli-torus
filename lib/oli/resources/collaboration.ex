defmodule Oli.Resources.Collaboration do
  alias Oli.Authoring.Course.Project
  alias Oli.Publishing
  alias Oli.Publishing.{AuthoringResolver, DeliveryResolver, Publication, PublishedResource}
  alias Oli.Publishing.Publications.Publication
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.{Section, SectionResource, SectionsProjectsPublications}
  alias Oli.Resources
  alias Oli.Resources.{ResourceType, Revision}
  alias Oli.Resources.Collaboration.{CollabSpaceConfig, Post, UserReadPost, UserReactionPost}
  alias Oli.Repo
  alias Oli.Accounts.User

  import Ecto.Query, warn: false
  import Oli.Utils
  require Logger

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
    page_type_id = ResourceType.id_for_page()

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
            "select count(*) from posts where section_id = ? and resource_id = ? and status != 'deleted'",
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
            "select max(inserted_at) from posts where section_id = ? and resource_id = ? and status != 'deleted'",
            section.id,
            page_revision.resource_id
          ),
        count: over(count(page_revision.id))
      },
      order_by: [section.id, page_revision.id]
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
    page_type_id = ResourceType.id_for_page()

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
  Returns the collab space config at the course level, the one "attached"
  at the curriculum level.
  """
  def get_course_collab_space_config(root_section_resource_id) do
    Repo.one(
      from(sr in SectionResource,
        where: sr.id == ^root_section_resource_id,
        select: sr.collab_space_config
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

  defp project_working_publication(project_slug) do
    from(p in Publication,
      join: c in Project,
      on: p.project_id == c.id,
      where: is_nil(p.published) and c.slug == ^project_slug,
      select: p.id
    )
  end

  @doc """
  Counts the number of pages with collab space enabled and the number of total pages for a given project,
  for the current working publication.
  Returns a tuple like {pages_with_collab_space_enabled_count, total_pages_count}

  ## Examples

      iex> count_collab_spaces_enabled_in_pages_for_project("project_slug")
      {1, 18}
  """
  def count_collab_spaces_enabled_in_pages_for_project(project_slug) do
    page_id = Oli.Resources.ResourceType.id_for_page()

    from(m in PublishedResource,
      join: rev in Revision,
      on: rev.id == m.revision_id,
      where:
        m.publication_id in subquery(project_working_publication(project_slug)) and
          rev.resource_type_id == ^page_id and rev.deleted == false,
      select: {
        count(
          fragment(
            "CASE WHEN ?->> ? = ? THEN 1 ELSE NULL END",
            rev.collab_space_config,
            ^"status",
            ^"enabled"
          )
        ),
        count(rev)
      }
    )
    |> Repo.one()
  end

  @doc """
  Counts the number of pages with collab space enabled and the number of total pages for a given section,
  for the current working publication.
  Returns a tuple like {pages_with_collab_space_enabled_count, total_pages_count}

  ## Examples

      iex> count_collab_spaces_enabled_in_pages_for_section("section_slug")
      {1, 18}
  """
  def count_collab_spaces_enabled_in_pages_for_section(section_slug) do
    page_id = Oli.Resources.ResourceType.id_for_page()

    from([sr: sr, rev: rev] in DeliveryResolver.section_resource_revisions(section_slug),
      where: rev.resource_type_id == ^page_id and rev.deleted == false,
      select: {
        count(
          fragment(
            "CASE WHEN ?->> ? = ? THEN 1 ELSE NULL END",
            sr.collab_space_config,
            ^"status",
            ^"enabled"
          )
        ),
        count(rev)
      }
    )
    |> Repo.one()
  end

  @doc """
  Disables all page collaborative spaces for a given project,
  for the current working publication.
  """

  def disable_all_page_collab_spaces_for_project(project_slug) do
    page_id = Oli.Resources.ResourceType.id_for_page()

    from(rev in Revision,
      join: m in PublishedResource,
      on: m.revision_id == rev.id,
      where:
        m.publication_id in subquery(project_working_publication(project_slug)) and
          rev.resource_type_id == ^page_id and rev.deleted == false,
      select: rev
    )
    |> Repo.update_all(set: [collab_space_config: %CollabSpaceConfig{}])
  end

  @doc """
  Enables all page collaborative spaces for a given project,
  for the current working publication, bulk applying the collab space config provided.
  """

  def enable_all_page_collab_spaces_for_project(project_slug, collab_space_config) do
    page_id = Oli.Resources.ResourceType.id_for_page()

    from(rev in Revision,
      join: m in PublishedResource,
      on: m.revision_id == rev.id,
      where:
        m.publication_id in subquery(project_working_publication(project_slug)) and
          rev.resource_type_id == ^page_id and rev.deleted == false,
      select: rev
    )
    |> Repo.update_all(set: [collab_space_config: collab_space_config])
  end

  @doc """
  Disables all page collaborative spaces for a given section.
  """

  def disable_all_page_collab_spaces_for_section(section_slug) do
    page_id = Oli.Resources.ResourceType.id_for_page()

    from([sr: sr, rev: rev] in DeliveryResolver.section_resource_revisions(section_slug),
      where: rev.resource_type_id == ^page_id and rev.deleted == false,
      select: sr
    )
    |> Repo.update_all(set: [collab_space_config: %CollabSpaceConfig{}])
  end

  @doc """
  Enables all page collaborative spaces for a given section, bulk applying the collab space config provided.
  """

  def enable_all_page_collab_spaces_for_section(section_slug, collab_space_config) do
    page_id = Oli.Resources.ResourceType.id_for_page()

    from([sr: sr, rev: rev] in DeliveryResolver.section_resource_revisions(section_slug),
      where: rev.resource_type_id == ^page_id and rev.deleted == false,
      select: sr
    )
    |> Repo.update_all(set: [collab_space_config: collab_space_config])
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
  Counts posts and replies for a user in a specific section and resource using DB-side aggregation.

  Returns `{posts_count, replies_count}` where:
  - `posts_count` is the number of top-level posts (where parent_post_id is nil)
  - `replies_count` is the number of reply posts (where parent_post_id is not nil)

  ## Examples

      iex> count_posts_and_replies_for_user(1, 1, 1)
      {5, 3}
  """
  @spec count_posts_and_replies_for_user(
          section_id :: integer(),
          resource_id :: integer(),
          user_id :: integer()
        ) :: {integer(), integer()}
  def count_posts_and_replies_for_user(section_id, resource_id, user_id) do
    base_query =
      from(
        post in Post,
        where:
          post.section_id == ^section_id and post.resource_id == ^resource_id and
            post.user_id == ^user_id and
            (post.status in [:approved, :archived] or
               post.status == :submitted)
      )

    posts_count =
      base_query
      |> where([p], is_nil(p.parent_post_id))
      |> Repo.aggregate(:count, :id)

    replies_count =
      base_query
      |> where([p], not is_nil(p.parent_post_id))
      |> Repo.aggregate(:count, :id)

    {posts_count, replies_count}
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

  # Define a subquery for root thread post replies count
  defp replies_subquery() do
    from(p in Post,
      group_by: p.thread_root_id,
      select: %{
        thread_root_id: p.thread_root_id,
        count: count(p.id),
        last_reply: max(p.updated_at)
      }
    )
  end

  # Define a subquery for root thread post read replies count
  # (replies by the user are counted as read)
  defp read_replies_subquery(user_id) do
    from(
      p in Post,
      left_join: urp in UserReadPost,
      on: urp.post_id == p.id,
      where:
        not is_nil(p.thread_root_id) and
          (p.user_id == ^user_id or (urp.user_id == ^user_id and not is_nil(urp.post_id))),
      group_by: p.thread_root_id,
      select: %{
        thread_root_id: p.thread_root_id,
        # Counting both user's posts and read posts
        count: count(p.id)
      }
    )
  end

  defp unread_replies_subquery(user_id) do
    from(
      post in Post,
      left_join: thread_root in Post,
      on: thread_root.id == post.thread_root_id,
      left_join: urp in UserReadPost,
      on: urp.post_id == post.id and urp.user_id == ^user_id,
      where:
        post.user_id != ^user_id and thread_root.user_id == ^user_id and
          is_nil(urp.post_id),
      group_by: post.thread_root_id,
      select: %{
        thread_root_id: post.thread_root_id,
        count: count(post.id)
      }
    )
  end

  @doc """
  Returns a map of root post ids that map to their unread reply counts for posts created by a given user.
  """
  def get_unread_reply_counts_for_root_discussions(user_id, root_curriculum_resource_id) do
    from(
      post in Post,
      left_join: parent_post in Post,
      on: parent_post.id == post.thread_root_id,
      left_join: urp in UserReadPost,
      on: urp.post_id == post.id and urp.user_id == ^user_id,
      where:
        post.resource_id == ^root_curriculum_resource_id and
          post.visibility == :public and
          post.status in [:approved, :archived] and
          parent_post.status in [:approved, :archived] and
          post.user_id != ^user_id and parent_post.user_id == ^user_id and
          is_nil(urp.post_id),
      group_by: parent_post.id,
      select: %{
        post_id: parent_post.id,
        unread_replies_count: count(post.id)
      }
    )
    |> Repo.all()
    |> Enum.reduce(%{}, fn %{post_id: post_id, unread_replies_count: unread_replies_count}, acc ->
      Map.put(acc, post_id, unread_replies_count)
    end)
  end

  @doc """
  Returns the total count of unread replies for posts created by a given user.
  """
  def get_total_count_of_unread_replies_for_root_discussions(user_id, root_curriculum_resource_id) do
    from(
      post in Post,
      join: parent_post in Post,
      on: parent_post.id == post.thread_root_id,
      left_join: urp in UserReadPost,
      on: urp.post_id == post.id and urp.user_id == ^user_id,
      where:
        post.resource_id == ^root_curriculum_resource_id and
          post.visibility == :public and
          post.status in [:approved, :archived] and
          parent_post.status in [:approved, :archived] and
          post.user_id != ^user_id and parent_post.user_id == ^user_id and
          is_nil(urp.post_id),
      select: count(post.id)
    )
    |> Repo.all()
    |> hd()
  end

  @doc """
  Returns the list of root posts for a section.
  """
  def list_root_posts_for_section(
        user_id,
        section_id,
        root_curriculum_resource_id,
        limit,
        offset,
        sort_by,
        sort_order
      ) do
    order_clause =
      case {sort_by, sort_order} do
        {"popularity", :desc} ->
          {:desc_nulls_last,
           dynamic(
             [_post, _sr, _spp, _pr, _rev, _user, replies, _read_replies, _reactions],
             replies.count
           )}

        {"popularity", :asc} ->
          {:asc_nulls_first,
           dynamic(
             [_post, _sr, _spp, _pr, _rev, _user, replies, _read_replies, _reactions],
             replies.count
           )}

        {"date", sort_order} ->
          {sort_order,
           dynamic(
             [post, _sr, _spp, _pr, _rev, _user, _replies, _read_replies, _reactions],
             post.updated_at
           )}

        {"unread", sort_order} ->
          [
            {sort_order,
             dynamic(
               [post, _sr, _spp, _pr, _rev, _user, _replies, unread_replies, _urp, _reactions],
               coalesce(unread_replies.count, 0)
             )},
            {sort_order,
             dynamic(
               [post, _sr, _spp, _pr, _rev, _user, _replies, _read_replies, _reactions],
               post.id
             )}
          ]
      end

    results =
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
        left_join: replies in subquery(replies_subquery()),
        on: replies.thread_root_id == post.id,
        left_join: unread_replies in subquery(unread_replies_subquery(user_id)),
        on: unread_replies.thread_root_id == post.id,
        left_join: urp in UserReadPost,
        on: urp.post_id == post.id and urp.user_id == ^user_id,
        left_join: reactions in assoc(post, :reactions),
        where:
          post.section_id == ^section_id and post.visibility == :public and
            (post.status in [:approved, :archived, :deleted] or
               (post.status == :submitted and post.user_id == ^user_id)) and
            post.resource_id == ^root_curriculum_resource_id and
            is_nil(post.parent_post_id) and is_nil(post.thread_root_id),
        order_by: ^order_clause,
        limit: ^limit,
        offset: ^offset,
        preload: [
          user: user,
          reactions: reactions
        ],
        select: %{
          post: %{
            post
            | replies_count: coalesce(replies.count, 0),
              unread_replies_count: coalesce(unread_replies.count, 0)
          },
          total_count: over(count(post.id))
        }
      )
      |> Repo.all()

    total_count =
      case results do
        [] -> 0
        _ -> hd(results).total_count
      end

    # Determine if more records exist beyond the current page
    more_posts_exist? = total_count > offset + limit

    posts =
      results
      |> Enum.map(fn %{post: post} -> post end)
      |> summarize_reactions(user_id)

    {posts, more_posts_exist?}
  end

  @doc """
  Returns the list of all the user's private notes for a section.
  """
  def list_all_user_notes_for_section(
        user_id,
        section_id,
        limit,
        offset,
        sort_by,
        sort_order
      ) do
    order_clause =
      case {sort_by, sort_order} do
        {"date", sort_order} ->
          {sort_order,
           dynamic(
             [post, _sr, _spp, _pr, _rev, _user, _replies, _read_replies],
             post.updated_at
           )}
      end

    results =
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
          post.section_id == ^section_id and post.visibility == :private and
            post.user_id == ^user_id,
        order_by: ^order_clause,
        limit: ^limit,
        offset: ^offset,
        preload: [
          user: user
        ],
        select: %{
          post: %{
            post
            | resource_slug: rev.slug
          },
          total_count: over(count(post.id))
        }
      )
      |> Repo.all()

    total_count =
      case results do
        [] -> 0
        _ -> hd(results).total_count
      end

    # Determine if more records exist beyond the current page
    more_posts_exist? = total_count > offset + limit

    posts =
      results
      |> Enum.map(fn %{post: post} -> post end)

    {posts, more_posts_exist?}
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
            post.visibility == :public and
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
          (post.section_id == ^section_id and post.user_id != ^user_id and
             post.visibility == :public and
             post.status in [:approved, :archived]) or
            (post.status == :submitted and post.user_id != ^user_id),
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
    |> where([_s, p], p.status != :deleted and p.visibility == :public)
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
  Soft deletes a single post with the given id, authorized for the actor.

  Only the post owner or a section instructor/admin may delete.
  """
  def soft_delete_post(post_id, actor) do
    actor = maybe_preload_actor(actor)

    case get_post_by(%{id: post_id}) |> Repo.preload(:section) do
      %Post{} = post ->
        if authorized_to_delete?(post, actor) do
          from(p in Post, where: p.id == ^post_id)
          |> Repo.update_all(set: [status: :deleted])
        else
          section_slug = post.section && post.section.slug

          Logger.warning(
            "Unauthorized delete attempt for post #{post_id} by #{actor && actor.id} in section #{section_slug}"
          )

          {:error, :unauthorized}
        end

      nil ->
        {:error, :not_found}
    end
  end

  @doc deprecated: "Use soft_delete_post/2 with an actor for authorization"
  def soft_delete_post(post_id), do: soft_delete_post(post_id, nil)

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

  @doc """
  Marks the given posts as read for the given user, excluding posts that where posted by the user.
  In case the user has already read the posts, it updates the :updated_at field.
  The third optional argument is a boolean that indicates if the operation should be performed in an async way.
  """

  def mark_posts_as_read(posts, user_id, async \\ false)

  def mark_posts_as_read(posts, user_id, false) do
    Enum.reduce(posts, [], fn post, acc ->
      if post.user_id != user_id, do: [post.id | acc], else: acc
    end)
    |> read_posts(user_id)
  end

  def mark_posts_as_read(posts, user_id, true) do
    Task.Supervisor.start_child(Oli.TaskSupervisor, fn ->
      Enum.reduce(posts, [], fn post, acc ->
        if post.user_id != user_id, do: [post.id | acc], else: acc
      end)
      |> read_posts(user_id)
    end)
  end

  defp read_posts(post_ids, user_id) do
    now = DateTime.utc_now(:second)

    Enum.map(post_ids, fn post_id ->
      %{post_id: post_id, user_id: user_id, inserted_at: now, updated_at: now}
    end)
    |> then(fn posts ->
      Repo.insert_all(UserReadPost, posts,
        on_conflict: {:replace, [:updated_at]},
        conflict_target: [:post_id, :user_id]
      )
    end)
  end

  defp authorized_to_delete?(%Post{user_id: user_id}, %{id: actor_id}) when user_id == actor_id,
    do: true

  defp authorized_to_delete?(%Post{section: %{slug: slug}}, actor) do
    Sections.is_instructor?(actor, slug) || Sections.is_admin?(actor, slug)
  end

  defp authorized_to_delete?(_, _), do: false

  defp maybe_preload_actor(nil), do: nil
  defp maybe_preload_actor(%User{} = actor), do: Repo.preload(actor, [:platform_roles])

  @doc """
  Returns the list of posts that a user can see for a particular point content block id.

  ## Examples

      iex> list_posts_for_user_in_point_block(1, 1, 1, :private, "1"))
      [%Post{status: :archived}, ...]

      iex> list_posts_for_user_in_point_block(2, 2, 2, :private, "2")
      []
  """
  def list_posts_for_user_in_point_block(
        section_id,
        resource_id,
        user_id,
        visibility,
        point_block_id \\ nil
      ) do
    filter_by_point_block_id =
      case point_block_id do
        nil ->
          true

        :page ->
          dynamic([p], is_nil(p.annotated_block_id))

        point_block_id ->
          dynamic([p], p.annotated_block_id == ^point_block_id)
      end

    filter_by_visibility =
      case visibility do
        :private ->
          dynamic([p], p.visibility == ^visibility and p.user_id == ^user_id)

        _ ->
          dynamic([p], p.visibility == ^visibility)
      end

    Repo.all(
      from(
        post in Post,
        left_join: replies in subquery(replies_subquery()),
        on: replies.thread_root_id == post.id,
        left_join: read_replies in subquery(read_replies_subquery(user_id)),
        on: read_replies.thread_root_id == post.id,
        left_join: reactions in assoc(post, :reactions),
        left_join: user in assoc(post, :user),
        where:
          post.section_id == ^section_id and post.resource_id == ^resource_id and
            is_nil(post.parent_post_id) and is_nil(post.thread_root_id) and
            (post.status in [:approved, :archived, :deleted] or
               (post.status == :submitted and post.user_id == ^user_id)),
        where: ^filter_by_point_block_id,
        where: ^filter_by_visibility,
        order_by: [desc: :inserted_at],
        preload: [user: user, reactions: reactions],
        select: %{
          post
          | replies_count: coalesce(replies.count, 0)
        }
      )
    )
    |> summarize_reactions(user_id)
  end

  @doc """
  Returns the list of posts that a user can see which match a given search term.

  ## Examples

      iex> search_posts_for_user_in_point_block(1, 1, 1, :private, "1", "search term"))
      [%Post{status: :archived}, ...]

      iex> search_posts_for_user_in_point_block(2, 2, 2, :private, "2", "search term")
      []
  """
  def search_posts_for_user_in_point_block(
        section_id,
        resource_id,
        user_id,
        visibility,
        point_block_id,
        search_term
      ) do
    filter_by_resource_id =
      case resource_id do
        nil ->
          true

        _ ->
          dynamic([p], p.resource_id == ^resource_id)
      end

    filter_by_point_block_id =
      case point_block_id do
        nil ->
          true

        :page ->
          dynamic([p], is_nil(p.annotated_block_id))

        point_block_id ->
          dynamic([p], p.annotated_block_id == ^point_block_id)
      end

    filter_by_visibility =
      case visibility do
        :private ->
          dynamic([p], p.visibility == ^visibility and p.user_id == ^user_id)

        _ ->
          dynamic([p], p.visibility == ^visibility)
      end

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
        left_join: replies in subquery(replies_subquery()),
        on: replies.thread_root_id == post.id,
        left_join: read_replies in subquery(read_replies_subquery(user_id)),
        on: read_replies.thread_root_id == post.id,
        left_join: parent_post in assoc(post, :parent_post),
        left_join: reactions in assoc(post, :reactions),
        left_join: user in assoc(post, :user),
        where:
          post.section_id == ^section_id and
            (post.status in [:approved, :archived, :deleted] or
               (post.status == :submitted and post.user_id == ^user_id)),
        where: ^filter_by_resource_id,
        where: ^filter_by_point_block_id,
        where: ^filter_by_visibility,
        where:
          fragment(
            "to_tsvector('english', ?) @@ websearch_to_tsquery('english', ?)",
            post.content,
            ^search_term
          ),
        where: post.visibility == ^visibility,
        order_by: [desc: :inserted_at],
        preload: [
          user: user,
          reactions: reactions,
          parent_post: parent_post
        ],
        select: %{
          post
          | replies_count: coalesce(replies.count, 0),
            resource_slug: rev.slug,
            headline:
              fragment(
                """
                ts_headline(
                  'english',
                  ?,
                  websearch_to_tsquery(?),
                  'StartSel=<em>,StopSel=</em>,MinWords=25,MaxWords=75'
                )
                """,
                post.content,
                ^search_term
              )
        }
      )
    )
    |> summarize_reactions(user_id)
    |> group_by_parent_post()
  end

  defp group_by_parent_post(posts) do
    by_parent_id = Enum.group_by(posts, &Map.get(&1, :parent_post_id))

    # we want to preserve the order of the posts returned by the query
    # so we need to reduce over the list of posts and place each post in the correct
    # parent post's replies list
    {results, _} =
      posts
      |> Enum.reduce({[], by_parent_id}, fn post, {acc, by_parent_id} ->
        parent_post_id = post.parent_post_id

        case parent_post_id do
          nil ->
            # this is a top-level post
            {[post | acc], by_parent_id}

          _ ->
            # this is a reply post, so place parent post with it's replies we already groups
            # in the list if it's not there yet
            case by_parent_id[parent_post_id] do
              nil ->
                # parent post is already in the list, so skip it
                {acc, by_parent_id}

              replies ->
                # parent post is not in the list yet, so add it and drop it from the by_parent_id map
                # to track which parent posts we already processed
                {[Map.put(post.parent_post, :replies, replies) | acc],
                 Map.delete(by_parent_id, parent_post_id)}
            end
        end
      end)

    results
    |> Enum.reverse()
  end

  defp summarize_reactions(posts, current_user_id) do
    Enum.map(posts, fn post ->
      %{
        post
        | reaction_summaries:
            Enum.reduce(post.reactions, %{}, fn r, acc ->
              reacted_by_current_user = r.user_id == current_user_id

              Map.update(
                acc,
                r.reaction,
                %{count: 1, reacted: reacted_by_current_user},
                fn %{
                     count: count,
                     reacted: reacted
                   } ->
                  %{count: count + 1, reacted: reacted_by_current_user || reacted}
                end
              )
            end)
      }
    end)
  end

  @doc """
  Returns the count of posts that a user can see for each annotated block id. For top-level
  resource posts, the annotated block id is nil.
  """
  def list_post_counts_for_user_in_section(section_id, resource_id, user_id, visibility) do
    filter_by_visibility =
      case visibility do
        :private ->
          dynamic([p], p.visibility == ^visibility and p.user_id == ^user_id)

        _ ->
          dynamic([p], p.visibility == ^visibility)
      end

    from(
      post in Post,
      where:
        post.section_id == ^section_id and post.resource_id == ^resource_id and
          is_nil(post.parent_post_id) and is_nil(post.thread_root_id) and
          (post.status in [:approved, :archived, :deleted] or
             (post.status == :submitted and post.user_id == ^user_id)),
      where: ^filter_by_visibility,
      group_by: post.annotated_block_id,
      select: {post.annotated_block_id, count(post.id)}
    )
    |> Repo.all()
    |> Enum.into(%{})
  end

  @doc """
  Returns the list of replies for a post.

  ## Examples

      iex> list_replies_for_post(1, 1)
      [%Post{status: :approved}, ...]

      iex> list_replies_for_post(2, 2)
      []
  """
  def list_replies_for_post(user_id, post_id) do
    Repo.all(
      from(
        post in Post,
        join: user in User,
        on: post.user_id == user.id,
        left_join: urp in UserReadPost,
        on: urp.post_id == post.id and urp.user_id == ^user_id,
        left_join: reactions in assoc(post, :reactions),
        where:
          post.parent_post_id == ^post_id and
            (post.status in [:approved, :archived, :deleted] or
               (post.status == :submitted and post.user_id == ^user_id)),
        order_by: [asc: :updated_at],
        preload: [user: user, reactions: reactions],
        select: post
      )
    )
    |> summarize_reactions(user_id)
  end

  @doc """
  Toggles a reaction to a post by a user. Returns a tuple with a resulting reaction count offset.

  ## Examples

      iex> toggle_reaction(1, 1, "like")
      {:ok, 1}

      iex> toggle_reaction(1, 1, "like")
      {:ok, -1}
  """
  def toggle_reaction(post_id, user_id, reaction) do
    case get_reaction(post_id, user_id, reaction) do
      nil ->
        case create_reaction(post_id, user_id, reaction) do
          {:ok, _} ->
            {:ok, 1}

          error ->
            error
        end

      reaction ->
        case delete_reaction(reaction) do
          {:ok, _} ->
            {:ok, -1}

          error ->
            error
        end
    end
  end

  @doc """
  Returns the reaction to a post by a user.

  ## Examples

      iex> get_reaction(1, 1, "like")
      %UserReactionPost{}
  """
  def get_reaction(post_id, user_id, reaction) do
    Repo.get_by(UserReactionPost, post_id: post_id, user_id: user_id, reaction: reaction)
  end

  @doc """
  Creates a reaction.

  ## Examples

      iex> create_reaction(1, 1, "like")
      {:ok, %UserReactionPost{}}
  """
  def create_reaction(post_id, user_id, reaction) do
    %UserReactionPost{post_id: post_id, user_id: user_id, reaction: reaction}
    |> Repo.insert()
  end

  @doc """
  Deletes a reaction.

  ## Examples

      iex> delete_reaction(reaction)
      {:ok, 1}
  """
  def delete_reaction(%UserReactionPost{} = reaction) do
    Repo.delete(reaction)
  end

  @doc """
  Marks the given course discussions and replies as read for the given user.

  ## Examples

      iex> mark_course_discussions_and_replies_read(1, 1)
      {:ok, 1}
  """
  def mark_course_discussions_and_replies_read(user_id, root_curriculum_resource_id) do
    now = DateTime.utc_now(:second)

    from(
      p in Post,
      left_join: urp in UserReadPost,
      on: urp.post_id == p.id and urp.user_id == ^user_id,
      where:
        is_nil(urp.id) and
          p.resource_id == ^root_curriculum_resource_id and p.user_id != ^user_id,
      select: p.id
    )
    |> Repo.all()
    |> Enum.map(fn post_id ->
      %{
        post_id: post_id,
        user_id: user_id,
        inserted_at: now,
        updated_at: now
      }
    end)
    |> then(fn posts ->
      Repo.insert_all(UserReadPost, posts,
        on_conflict: {:replace, [:updated_at]},
        conflict_target: [:post_id, :user_id]
      )
    end)
  end
end
