defmodule Oli.Course do
  @moduledoc """
  The Course context.
  """

  import Ecto.Query, warn: false
  alias Oli.Repo

  alias Oli.Course.Project

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

  @doc """
  Creates a project.

  ## Examples

      iex> create_project(%{field: value})
      {:ok, %Project{}}

      iex> create_project(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_project(attrs \\ %{}) do
    %Project{}
    |> Project.changeset(attrs)
    # will have title from form
    # add required attrs ->
      # id?
      # slug
      # version
      # family
      # author
    |> Repo.insert()
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
