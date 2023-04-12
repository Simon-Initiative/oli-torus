defmodule Oli.Authoring.Course do
  import Ecto.Query, warn: false

  alias Oli.Accounts.{SystemRole, Author}
  alias Oli.Authoring.Authors.AuthorProject
  alias Oli.Authoring.{Collaborators, ProjectSearch}
  alias Oli.Authoring.Course.{Project, Family, ProjectResource, ProjectAttributes}
  alias Oli.Groups.CommunityVisibility
  alias Oli.Inventories
  alias Oli.Publishing
  alias Oli.Publishing.Publications.Publication
  alias Oli.Publishing.PublishedResource
  alias Oli.Repo
  alias Oli.Repo.{Paging, Sorting}
  alias Oli.Resources.{ResourceType, Revision, ScoringStrategy}

  def create_project_resource(attrs) do
    %ProjectResource{}
    |> ProjectResource.changeset(attrs)
    |> Repo.insert()
  end

  def list_project_resources(project_id) do
    Repo.all(
      from pr in ProjectResource,
        where: pr.project_id == ^project_id,
        select: pr
    )
  end

  def change_project_resource(%ProjectResource{} = project_resource, attrs \\ %{}) do
    ProjectResource.changeset(project_resource, attrs)
  end

  def list_projects do
    Repo.all(Project)
  end

  @doc """
  Lists all projects that contain a particular resource.
  """
  def list_projects_containing_resource(resource_id) do
    Repo.all(
      from pr in ProjectResource,
        join: p in Project,
        on: p.id == pr.project_id,
        where: pr.resource_id == ^resource_id,
        select: p
    )
  end

  @doc """
  Get all the projects that are not associated within a community.

  ## Examples

      iex> list_projects_not_in_community(1)
      {:ok, [%Project{}, ,...]}

      iex> list_projects_not_in_community(123)
      {:ok, []}
  """
  def list_projects_not_in_community(community_id) do
    from(
      project in Project,
      left_join: community_visibility in CommunityVisibility,
      on:
        project.id ==
          community_visibility.project_id and community_visibility.community_id == ^community_id,
      where: is_nil(community_visibility.id) and project.status == :active,
      select: project
    )
    |> Repo.all()
  end

  def get_projects_for_author(author) do
    admin_role_id = SystemRole.role_id().admin

    case author do
      # Admin authors have access to every project
      %{system_role_id: ^admin_role_id} -> Repo.all(Project)
      _ -> Repo.preload(author, [:projects]).projects
    end
  end

  def browse_projects(
        %Author{} = author,
        %Paging{} = paging,
        %Sorting{} = sorting,
        opts \\ []
      ) do
    admin_role_id = SystemRole.role_id().admin
    include_deleted = Keyword.get(opts, :include_deleted, false)
    admin_show_all = Keyword.get(opts, :admin_show_all, true)
    text_search = Keyword.get(opts, :text_search, "")

    case author do
      # Admin authors have access to every project
      %{system_role_id: ^admin_role_id} when admin_show_all ->
        browse_projects_as_admin(paging, sorting, include_deleted, text_search)

      _ ->
        browse_projects_as_author(author, paging, sorting, include_deleted, text_search)
    end
  end

  defp browse_projects_as_admin(
         %Paging{limit: limit, offset: offset},
         %Sorting{direction: direction, field: field},
         include_deleted,
         text_search
       ) do
    filter_by_status =
      if include_deleted do
        true
      else
        dynamic([p], p.status == :active)
      end

    filter_by_text =
      if text_search == "" do
        true
      else
        dynamic([p], ilike(p.title, ^"%#{text_search}%"))
      end

    owner_id = Oli.Authoring.Authors.ProjectRole.role_id().owner

    query =
      Project
      |> join(:left, [p], o in AuthorProject,
        on: p.id == o.project_id and o.project_role_id == ^owner_id
      )
      |> join(:left, [p, a], o in Oli.Accounts.Author, on: o.id == a.author_id)
      |> where(^filter_by_status)
      |> where(^filter_by_text)
      |> limit(^limit)
      |> offset(^offset)
      |> select([p, _, a], %{
        id: p.id,
        slug: p.slug,
        title: p.title,
        inserted_at: p.inserted_at,
        status: p.status,
        owner_id: a.id,
        name: a.name,
        email: a.email,
        total_count: fragment("count(*) OVER()")
      })

    query =
      case field do
        :name -> order_by(query, [_, _, o], {^direction, o.name})
        _ -> order_by(query, [p, _], {^direction, field(p, ^field)})
      end

    Repo.all(query)
  end

  defp browse_projects_as_author(
         %Author{id: id},
         %Paging{limit: limit, offset: offset},
         %Sorting{direction: direction, field: field},
         include_deleted,
         text_search
       ) do
    owner_id = Oli.Authoring.Authors.ProjectRole.role_id().owner

    filter_by_collaborator = dynamic([a, _, _, _], a.author_id == ^id)

    filter_by_status =
      if include_deleted do
        true
      else
        dynamic([_, p, _, _], p.status == :active)
      end

    filter_by_text =
      if text_search == "" do
        true
      else
        dynamic([_, p, _, _], ilike(p.title, ^"%#{text_search}%"))
      end

    query =
      AuthorProject
      |> join(:left, [c], p in Project, on: c.project_id == p.id)
      |> join(:left, [c, p], o in AuthorProject,
        on: p.id == o.project_id and o.project_role_id == ^owner_id
      )
      |> join(:left, [c, p, o], a in Oli.Accounts.Author, on: o.author_id == a.id)
      |> where(^filter_by_collaborator)
      |> where(^filter_by_status)
      |> where(^filter_by_text)
      |> limit(^limit)
      |> offset(^offset)
      |> select([_, p, _, a], %{
        id: p.id,
        slug: p.slug,
        title: p.title,
        inserted_at: p.inserted_at,
        status: p.status,
        owner_id: a.id,
        name: a.name,
        email: a.email,
        total_count: fragment("count(*) OVER()")
      })

    query =
      case field do
        :name -> order_by(query, [_, _, o], {^direction, o.name})
        _ -> order_by(query, [_, p, _], {^direction, field(p, ^field)})
      end

    Repo.all(query)
  end

  @spec search_published_projects(binary) :: any
  @doc """
  Returns the list of published projects where the title, description and slug are similar to the query string
  ## Examples
      iex> search_published_projects()
      [%Project{}, ...]
  """
  def search_published_projects(search_term) do
    ProjectSearch.search(search_term)
  end

  def get_project!(id), do: Repo.get!(Project, id)
  def get_project_by_slug(nil), do: nil
  def get_project_by_slug(slug) when is_binary(slug), do: Repo.get_by(Project, slug: slug)

  def get_project_attributes(nil), do: %ProjectAttributes{}

  def get_project_attributes(project_slug) when is_binary(project_slug) do
    project = get_project_by_slug(project_slug)

    case project do
      nil -> %ProjectAttributes{}
      %Project{:attributes => nil} -> %ProjectAttributes{}
      %Project{:attributes => attributes} -> attributes
    end
  end

  def create_and_attach_resource(project, attrs) do
    with {:ok, %{resource: resource, revision: revision}} <-
           Oli.Resources.create_resource_and_revision(attrs),
         {:ok, project_resource} = attach_to_project(resource, project) do
      {:ok, %{resource: resource, revision: revision, project_resource: project_resource}}
    else
      error -> error
    end
  end

  def attach_to_project(%{resource: resource}, project) do
    attach_to_project(resource, project)
  end

  def attach_to_project(resource, project) do
    create_project_resource(%{project_id: project.id, resource_id: resource.id})
  end

  def initial_resource_setup(author, project) do
    attrs = %{
      title: "Curriculum",
      author_id: author.id,
      resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container")
    }

    create_and_attach_resource(project, attrs)
  end

  def create_project(attrs) do
    %Project{}
    |> Project.changeset(attrs)
    |> Repo.insert()
  end

  def create_project(title, author, additional_attrs \\ %{}) do
    Repo.transaction(fn ->
      with {:ok, project_family} <- create_family(default_family(title)),
           {:ok, project} <-
             create_project(default_project(title, project_family, additional_attrs)),
           {:ok, collaborator} <- Collaborators.add_collaborator(author, project),
           {:ok, %{resource: resource, revision: resource_revision}} <-
             initial_resource_setup(author, project),
           {:ok, %{publication: publication, published_resource: published_resource}} <-
             Publishing.initial_publication_setup(project, resource, resource_revision) do
        %{
          project_family: project_family,
          project: project,
          author_project: collaborator,
          resource: resource,
          resource_revision: resource_revision,
          publication: publication,
          published_resource: published_resource
        }
      else
        {:error, error} -> Repo.rollback(error)
      end
    end)
  end

  defp default_project(title, family, additional_attrs) do
    default_publisher = Inventories.default_publisher()

    Map.merge(
      %{
        title: title,
        version: "1.0.0",
        family_id: family.id,
        publisher_id: default_publisher.id
      },
      additional_attrs
    )
  end

  def update_project(%Project{} = project, attrs) do
    project
    |> Project.changeset(attrs)
    |> Repo.update()
  end

  def get_family!(id), do: Repo.get!(Family, id)

  def update_family(%Family{} = family, attrs) do
    family
    |> Family.changeset(attrs)
    |> Repo.update()
  end

  def create_family(attrs \\ %{}) do
    %Family{}
    |> Family.changeset(attrs)
    |> Repo.insert()
  end

  defp default_family(title) do
    %{
      title: title,
      description: "New family from project creation"
    }
  end

  defp project_has_survey?(project_id) do
    Project
    |> where([p], p.id == ^project_id and not is_nil(p.required_survey_resource_id))
    |> select([p], p.required_survey_resource_id)
    |> Repo.one()
    |> Kernel.!=(nil)
  end

  defp get_project_survey(project_id) do
    PublishedResource
    |> join(:inner, [pr], rev in Revision, on: pr.revision_id == rev.id)
    |> join(:inner, [_, _, proj], proj in Project, on: proj.id == ^project_id)
    |> where(
      [pr, rev, proj],
      pr.publication_id in subquery(
        Publication
        |> where([p], is_nil(p.published) and p.project_id == ^project_id)
        |> select([p], p.id)
      ) and pr.resource_id == proj.required_survey_resource_id
    )
    |> select([_, rev], rev)
    |> Repo.one()
  end

  defp update_project_required_survey_resource_id(project_id, resource_id) do
    Project
    |> where([p], p.id == ^project_id)
    |> Repo.one()
    |> Project.changeset(%{required_survey_resource_id: resource_id})
    |> Repo.update()
  end

  def create_project_survey(project, author_id) do
    case project_has_survey?(project.id) do
      false -> do_create_project_survey(project, author_id)
      _ -> {:error, "The project already has a survey"}
    end
  end

  defp do_create_project_survey(project, author_id) do
    {:ok, %{revision: revision}} =
      create_and_attach_resource(project, %{
        title: "Course Survey",
        author_id: author_id,
        max_attempts: 1,
        scoring_strategy_id: ScoringStrategy.get_id_by_type("most_recent"),
        resource_type_id: ResourceType.get_id_by_type("page")
      })

    update_project_required_survey_resource_id(project.id, revision.resource_id)

    Oli.Publishing.ChangeTracker.track_revision(project.slug, revision)
  end

  def delete_project_survey(project) do
    case project_has_survey?(project.id) do
      false -> {:error, "The project doesn't have a survey"}
      _ -> do_delete_project_survey(project)
    end
  end

  defp do_delete_project_survey(project) do
    case get_project_survey(project.id) do
      revision ->
        update_project_required_survey_resource_id(project.id, nil)
        Oli.Publishing.ChangeTracker.track_revision(project.slug, revision, %{deleted: true})
    end
  end
end
