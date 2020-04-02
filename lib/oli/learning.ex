defmodule Oli.Learning do
  @moduledoc """
  The Learning context.
  """

  import Ecto.Query, warn: false
  alias Oli.Repo

  alias Oli.Learning.Objective
  alias Oli.Learning.ObjectiveFamily

  def create_objective_family(attrs \\ %{}) do
    %ObjectiveFamily{}
    |> ObjectiveFamily.changeset(attrs)
    |> Repo.insert()
  end

  def new_objective_family() do
    %ObjectiveFamily{}
      |> ObjectiveFamily.changeset(%{
      })
  end

  @doc """
  Returns the list of objectives.

  ## Examples

      iex> list_objectives()
      [%Objective{}, ...]

  """
  def list_objectives do
    Repo.all(Objective)
  end

  @doc """
  Gets a single objective.

  Raises `Ecto.NoResultsError` if the Objective does not exist.

  ## Examples

      iex> get_objective!(123)
      %Objective{}

      iex> get_objective!(456)
      ** (Ecto.NoResultsError)

  """
  def get_objective!(id), do: Repo.get!(Objective, id)

  @doc """
  Creates a objective.

  ## Examples

      iex> create_objective(%{field: value})
      {:ok, %Objective{}}

      iex> create_objective(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_objective(attrs \\ %{}) do
    %Objective{}
    |> Objective.changeset(attrs)
    |> Repo.insert()
  end

  def new_project_objective(project, family) do
    %Objective{}
      |> Objective.changeset(%{
        project_id: project.id, family_id: family.id
      })
  end

  @doc """
  Updates a objective.

  ## Examples

      iex> update_objective(objective, %{field: new_value})
      {:ok, %Objective{}}

      iex> update_objective(objective, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_objective(%Objective{} = objective, attrs) do
    objective
    |> Objective.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a objective.

  ## Examples

      iex> delete_objective(objective)
      {:ok, %Objective{}}

      iex> delete_objective(objective)
      {:error, %Ecto.Changeset{}}

  """
  def delete_objective(%Objective{} = objective) do
    Repo.delete(objective)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking objective changes.

  ## Examples

      iex> change_objective(objective)
      %Ecto.Changeset{source: %Objective{}}

  """
  def change_objective(%Objective{} = objective) do
    Objective.changeset(objective, %{})
  end

  alias Oli.Learning.ObjectiveRevision

  @doc """
  Returns the list of objective_revisions.

  ## Examples

      iex> list_objective_revisions()
      [%ObjectiveRevision{}, ...]

  """
  def list_objective_revisions do
    Repo.all(ObjectiveRevision)
  end

  @doc """
  Gets a single objective_revision.

  Raises `Ecto.NoResultsError` if the Objective revision does not exist.

  ## Examples

      iex> get_objective_revision!(123)
      %ObjectiveRevision{}

      iex> get_objective_revision!(456)
      ** (Ecto.NoResultsError)

  """
  def get_objective_revision!(id), do: Repo.get!(ObjectiveRevision, id)

  @doc """
  Creates a objective_revision.

  ## Examples

      iex> create_objective_revision(%{field: value})
      {:ok, %ObjectiveRevision{}}

      iex> create_objective_revision(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_objective_revision(attrs \\ %{}) do
    %ObjectiveRevision{}
    |> ObjectiveRevision.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a objective_revision.

  ## Examples

      iex> update_objective_revision(objective_revision, %{field: new_value})
      {:ok, %ObjectiveRevision{}}

      iex> update_objective_revision(objective_revision, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_objective_revision(%ObjectiveRevision{} = objective_revision, attrs) do
    objective_revision
    |> ObjectiveRevision.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a objective_revision.

  ## Examples

      iex> delete_objective_revision(objective_revision)
      {:ok, %ObjectiveRevision{}}

      iex> delete_objective_revision(objective_revision)
      {:error, %Ecto.Changeset{}}

  """
  def delete_objective_revision(%ObjectiveRevision{} = objective_revision) do
    Repo.delete(objective_revision)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking objective_revision changes.

  ## Examples

      iex> change_objective_revision(objective_revision)
      %Ecto.Changeset{source: %ObjectiveRevision{}}

  """
  def change_objective_revision(%ObjectiveRevision{} = objective_revision) do
    ObjectiveRevision.changeset(objective_revision, %{})
  end
end
