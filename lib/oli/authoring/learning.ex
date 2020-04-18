defmodule Oli.Authoring.Learning do
  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias Oli.Repo

  alias Oli.Authoring.Learning.{Objective, ObjectiveFamily, ObjectiveRevision}
  alias Oli.Publishing
  alias Oli.Publishing.ObjectiveMapping

  # From a list of objective revision slugs, convert to a list of objective ids
  def get_ids_from_objective_slugs(slugs) do
    result = Repo.all from rev in ObjectiveRevision,
      where: rev.slug in ^slugs,
      select: map(rev, [:objective_id])

    Enum.map(result, fn m -> Map.get(m, :objective_id) end)
  end

  def create_objective_family(attrs \\ %{}) do
    %ObjectiveFamily{}
    |> ObjectiveFamily.changeset(attrs)
    |> Repo.insert()
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
  Gets a single objective, based on a revision and project slugs.
  """
  @spec get_objective_from_slug(String.t, String.t) :: any
  def get_objective_from_slug(project_slug, revision_slug) do
    query = from o in Objective,
                 distinct: o.id,
                 join: p in Project, on: o.project_id == p.id,
                 join: v in ObjectiveRevision, on: v.objective_id == o.id,
                 where: p.slug == ^project_slug and v.slug == ^revision_slug,
                 select: o
    Repo.one(query)
  end

  @doc """
  Gets a single objective_revision, based on a revision and project slugs.
  """
  @spec get_objective_revision_from_slug(String.t, String.t) :: any
  def get_objective_revision_from_slug(project_slug, revision_slug) do
    query = from v in ObjectiveRevision,
                 distinct: v.id,
                 join: o in Objective, on: v.objective_id == o.id,
                 join: p in Project, on: o.project_id == p.id,
                 where: p.slug == ^project_slug and v.slug == ^revision_slug,
                 select: v
    Repo.one(query)
  end

  @doc """
  Creates an objective.
  ## Examples
      iex> create_objective(%{field: value})
      {:ok, %Objective{}}
      iex> create_objective(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_objective(attrs \\ %{}) do
    Multi.new
    |> Multi.insert(:objective_family, new_objective_family())
    |> Multi.merge(fn %{objective_family: objective_family} ->
      Multi.new
      |> Multi.insert(:objective, do_create_objective(attrs, objective_family)) end)
    |> Multi.merge(fn %{objective: objective} ->
      Multi.new
      |> Multi.insert(:objective_revision, do_create_objective_revision(attrs, objective)) end)
    |> Multi.merge(fn %{objective_revision: objective_revision} ->
      Multi.new
      |> Multi.run(:objective_parent, fn _repo, _changes ->
        do_add_objective_to_parent(attrs, objective_revision)
      end)
    end)
    |> Multi.merge(fn %{objective: objective, objective_revision: objective_revision} ->
      Multi.new
      |> Multi.insert(:objective_mapping, do_create_objective_mapping(attrs, objective, objective_revision))end)
    |> Repo.transaction
  end

  defp do_add_objective_to_parent(attrs, objective_revision) do
    if Map.has_key?(attrs, "parent_slug") do
      parent_objective_revision = get_objective_revision_from_slug(Map.get(attrs, "project_slug"), Map.get(attrs, "parent_slug"))
      children = parent_objective_revision.children ++ [objective_revision.id]
      update_objective_revision(parent_objective_revision, %{children: children})
    end
    {:ok, :val}
  end

  defp do_create_objective_mapping(attrs, objective, objective_revision) do
    publication = Publishing.get_unpublished_publication(Map.get(attrs, "project_slug"))
    %ObjectiveMapping{}
    |> ObjectiveMapping.changeset(%{
      publication_id: publication.id,
      objective_id: objective.id,
      revision_id: objective_revision.id
    })
  end

  defp do_create_objective(attrs, objective_family) do
    project_id = Map.get(attrs, "project_id");
    %Objective{}
    |> Objective.changeset(%{
      family_id: objective_family.id,
      project_id: project_id
    })
  end

  defp do_create_objective_revision(attrs, objective) do
    title = Map.get(attrs, "title")
    %ObjectiveRevision{}
    |> ObjectiveRevision.changeset(%{
      title: title,
      children: [],
      deleted: false,
      objective_id: objective.id
    })
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
  Returns an `%Ecto.Changeset{}` for tracking objective_revision changes.
  ## Examples
      iex> change_objective_revision(objective_revision)
      %Ecto.Changeset{source: %ObjectiveRevision{}}
  """
  def change_objective_revision(attrs, objective) do
    title = Map.get(attrs, "title")
    %ObjectiveRevision{}
    |> ObjectiveRevision.changeset(%{
      title: title,
      children: [],
      deleted: false,
      objective_id: objective.id
    })
  end

  def change_objective(%Objective{} = objective) do
    Objective.changeset(objective, %{})
  end

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

  defp new_objective_family() do
    %ObjectiveFamily{}
    |> ObjectiveFamily.changeset()
  end
end
