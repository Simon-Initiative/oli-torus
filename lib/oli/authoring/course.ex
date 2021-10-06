defmodule Oli.Authoring.Course do
  import Ecto.Query, warn: false
  alias Oli.Repo
  alias Oli.Repo.{Paging, Sorting}
  alias Oli.Publishing
  alias Oli.Authoring.{Collaborators, ProjectSearch}
  alias Oli.Authoring.Course.{Project, Family, ProjectResource}
  alias Oli.Accounts.{SystemRole, Author}
  alias Oli.Authoring.Authors.AuthorProject

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
        include_deleted,
        text_search \\ nil
      ) do
    admin_role_id = SystemRole.role_id().admin

    case author do
      # Admin authors have access to every project
      %{system_role_id: ^admin_role_id} ->
        browse_projects_as_admin(paging, sorting, include_deleted, text_search)

      _ ->
        browse_projects_as_author(author, paging, sorting, include_deleted, text_search)
    end
  end

  defp browse_projects_as_admin(
         %Paging{limit: limit, offset: offset} = paging,
         %Sorting{direction: direction, field: field} = sorting,
         include_deleted,
         text_search \\ nil
       ) do
    filter_by_status =
      if include_deleted do
        true
      else
        dynamic([p], p.status == :active)
      end

    filter_by_text =
      if is_nil(text_search) do
        true
      else
        dynamic([p], like(p.title, ^text_search))
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
        total_count: fragment("count(*) OVER()")
      })

    query =
      case {field, direction} do
        {:name, :asc} -> order_by(query, [_, _, o], asc: o.name)
        {:title, :asc} -> order_by(query, [p, _, _], asc: p.title)
        {:inserted_at, :asc} -> order_by(query, [p, _, _], asc: p.inserted_at)
        {:name, :desc} -> order_by(query, [_, _, o], desc: o.name)
        {:title, :desc} -> order_by(query, [p, _, _], desc: p.title)
        {:inserted_at, :desc} -> order_by(query, [p, _, _], desc: p.inserted_at)
      end

    Repo.all(query)
  end

  defp browse_projects_as_author(
         %Author{id: id},
         %Paging{limit: limit, offset: offset},
         %Sorting{direction: direction, field: field},
         include_deleted,
         text_search \\ nil
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
      if is_nil(text_search) do
        true
      else
        dynamic([_, p, _, _], like(p.title, ^text_search))
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
        total_count: fragment("count(*) OVER()")
      })

    query =
      case {field, direction} do
        {:name, :asc} -> order_by(query, [_, _, _, o], asc: o.name)
        {:title, :asc} -> order_by(query, [_, p, _, _], asc: p.title)
        {:inserted_at, :asc} -> order_by(query, [_, p, _, _], asc: p.inserted_at)
        {:name, :desc} -> order_by(query, [_, _, _, o], desc: o.name)
        {:title, :desc} -> order_by(query, [_, p, _, _], desc: p.title)
        {:inserted_at, :desc} -> order_by(query, [_, p, _, _], desc: p.inserted_at)
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

  def create_project(title, author) do
    Repo.transaction(fn ->
      with {:ok, project_family} <- create_family(default_family(title)),
           {:ok, project} <- create_project(default_project(title, project_family)),
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

  defp default_project(title, family) do
    %{
      title: title,
      version: "1.0.0",
      family_id: family.id
    }
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
end
