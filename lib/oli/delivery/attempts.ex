defmodule Oli.Delivery.Attempts do

  import Ecto.Query, warn: false
  alias Oli.Repo
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Attempts.{PartAttempt, ResourceAccess, ResourceAttempt}

  @doc """
  Retrieves the state of active attempts of a collection of activity ids in a given
  context_id for a given user_id.  Returns them as a two-level map of activity ids to
  part state map.

  """
  def get_latest_part_attempts(activity_ids, context_id, user_id) do

    results = Repo.all(from a in ResourceAccess,
      join: s in Section, on: a.section_id == s.id,
      join: ra1 in ResourceAttempt, on: a.id == ra1.resource_access_id,
      left_join: ra2 in ResourceAttempt, on: (a.id == ra2.resource_access_id and ra1.id < ra2.id),
      join: pa1 in PartAttempt, on: ra1.id == pa1.resource_attempt_id,
      left_join: pa2 in PartAttempt, on: (ra1.id == pa2.resource_attempt_id and pa1.part_id == pa2.part_id and pa1.id < pa2.id),
      where: a.resource_id in ^activity_ids and s.context_id == ^context_id and a.user_id == ^user_id and is_nil(ra2.id) and is_nil(pa2.id),
      select: {pa1, a})

    Enum.reduce(results, %{}, fn {attempt, a}, m ->

      resource_id = a.resource_id
      part_id = attempt.part_id

      m = case Map.has_key?(m, resource_id) do
        true -> m
        false -> Map.put(m, resource_id, %{})
      end

      activity_entry = Map.get(m, resource_id)
      activity_entry = Map.put(activity_entry, part_id, attempt)

      Map.put(m, resource_id, activity_entry)
    end)

  end

  @doc """
  Creates or updates an access record for a given resource, section and user. When
  created the access count is set to 1, otherwise on updates the
  access count is incremented.
  ## Examples
      iex> track_access(resource_id, section_id, user_id, parent_id)
      {:ok, %ResourceAccess{}}
      iex> track_access(resource_id, section_id, user_id, parent_id)
      {:error, %Ecto.Changeset{}}
  """
  def track_access(resource_id, section_id, user_id, parent_id \\ nil) do
    Oli.Repo.insert!(
      %ResourceAccess{access_count: 1, user_id: user_id, section_id: section_id, resource_id: resource_id, parent_id: parent_id},
      on_conflict: [inc: [access_count: 1]],
      conflict_target: [:resource_id, :user_id, :section_id]
    )
  end

  @doc """
  Creates a part attempt.
  ## Examples
      iex> create_part_attempt(%{field: value})
      {:ok, %PartAttempt{}}
      iex> create_part_attempt(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_part_attempt(attrs \\ %{}) do
    %PartAttempt{}
    |> PartAttempt.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a part attempt.
  ## Examples
      iex> update_part_attempt(part_attempt, %{field: new_value})
      {:ok, %PartAttempt{}}
      iex> update_part_attempt(part_attempt, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_part_attempt(part_attempt, attrs) do
    PartAttempt.changeset(part_attempt, attrs)
    |> Repo.update()
  end

  @doc """
  Creates a resource attempt.
  ## Examples
      iex> create_resource_attempt(%{field: value})
      {:ok, %ResourceAttempt{}}
      iex> create_resource_attempt(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_resource_attempt(attrs \\ %{}) do
    %ResourceAttempt{}
    |> ResourceAttempt.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a resource attempt.
  ## Examples
      iex> update_resource_attempt(revision, %{field: new_value})
      {:ok, %ResourceAttempt{}}
      iex> update_resource_attempt(revision, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_resource_attempt(resource_attempt, attrs) do
    ResourceAttempt.changeset(resource_attempt, attrs)
    |> Repo.update()
  end
end
