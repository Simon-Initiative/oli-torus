defmodule Oli.Course do
  @moduledoc """
  The Course context.
  """

  import Ecto.Query, warn: false
  alias Oli.Repo
  alias Oli.Course.Utils

  alias Oli.Course.Project
  alias Ecto.Multi
  alias Oli.Publishing
  alias Oli.Resources
  alias Oli.Accounts

  @doc """
  Returns the list of projects.

  ## Examples

      iex> list_projects()
      [%Project{}, ...]

  """
  def list_projects do
    Repo.all(Project)
  end

  @doc """
  Gets a single project.

  Raises `Ecto.NoResultsError` if the Project does not exist.

  ## Examples

      iex> get_project!(123)
      %Project{}

      iex> get_project!(456)
      ** (Ecto.NoResultsError)

  """
  def get_project!(id), do: Repo.get!(Project, id)
  def get_project_by_slug(slug) do
    if is_nil(slug) do
      nil
    else
      Repo.get_by(Project, slug: slug)
    end
  end

  @doc """
  Creates a project tied to an author.
  create_project(title : string, author : Author)
  """
  def create_project(title, author) do
    # Here's how this works:
    # Multi chains database operations and performs a single transaction at the end.
    # If one operation fails, the changes are "rolled back" (no transaction is performed).
    # `insert` takes a changeset in order to create a new row, and `merge` takes a lambda
    # that allows you to access the changesets created in previous Multi calls
    Multi.new
      |> Multi.insert(:family, default_family(title))
      |> Multi.merge(fn %{family: family} ->
        Multi.new
        |> Multi.insert(:project, default_project(title, family)) end)
      |> Multi.merge(fn %{project: project} ->
        Multi.new
        |> Multi.update(:author, Accounts.author_to_project(author, project))
        |> Multi.insert(:resource, Resources.new_project_resource(project)) end)
      |> Multi.merge(fn %{author: author, project: project, resource: resource} ->
        Multi.new
        |> Multi.insert(:resource_revision, Resources.new_project_resource_revision(author, project, resource))
        |> Multi.insert(:publication, Publishing.new_project_publication(resource, project)) end)
      |> Repo.transaction
  end

  defp default_project(title, family) do
    %Project{}
      |> Project.changeset(%{
        title: title,
        slug: Utils.generate_slug("projects", title),
        version: "1.0.0",
        family_id: family.id
      })
  end

  @doc """
  Updates a project.

  ## Examples

      iex> update_project(project, %{field: new_value})
      {:ok, %Project{}}

      iex> update_project(project, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_project(%Project{} = project, attrs) do
    project
    |> Project.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a project.

  ## Examples

      iex> delete_project(project)
      {:ok, %Project{}}

      iex> delete_project(project)
      {:error, %Ecto.Changeset{}}

  """
  def delete_project(%Project{} = project) do
    Repo.delete(project)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking project changes.

  ## Examples

      iex> change_project(project)
      %Ecto.Changeset{source: %Project{}}

  """
  def change_project(%Project{} = project) do
    Project.changeset(project, %{})
  end

  alias Oli.Course.Family

  @doc """
  Returns the list of families.

  ## Examples

      iex> list_families()
      [%Family{}, ...]

  """
  def list_families do
    Repo.all(Family)
  end

  @doc """
  Gets a single family.

  Raises `Ecto.NoResultsError` if the Family does not exist.

  ## Examples

      iex> get_family!(123)
      %Family{}

      iex> get_family!(456)
      ** (Ecto.NoResultsError)

  """
  def get_family!(id), do: Repo.get!(Family, id)

  @doc """
  Creates a family.

  ## Examples

      iex> create_family(%{field: value})
      {:ok, %Family{}}

      iex> create_family(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_family(attrs \\ %{}) do
    %Family{}
    |> Family.changeset(attrs)
    |> Repo.insert()
  end

  def default_family(title) do
    %Family{}
      |> Family.changeset(%{
        title: title,
        slug: Utils.generate_slug("families", title),
        description: "New family from project creation"
      })
  end

  @doc """
  Updates a family.

  ## Examples

      iex> update_family(family, %{field: new_value})
      {:ok, %Family{}}

      iex> update_family(family, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_family(%Family{} = family, attrs) do
    family
    |> Family.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a family.

  ## Examples

      iex> delete_family(family)
      {:ok, %Family{}}

      iex> delete_family(family)
      {:error, %Ecto.Changeset{}}

  """
  def delete_family(%Family{} = family) do
    Repo.delete(family)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking family changes.

  ## Examples

      iex> change_family(family)
      %Ecto.Changeset{source: %Family{}}

  """
  def change_family(%Family{} = family) do
    Family.changeset(family, %{})
  end
end
