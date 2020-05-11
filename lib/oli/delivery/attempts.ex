defmodule Oli.Delivery.Attempts do

  import Ecto.Query, warn: false
  alias Oli.Repo
  alias Oli.Delivery.Sections.{Section}
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Attempts.{PartAttempt, ResourceAccess, ResourceAttempt, ActivityAttempt}
  alias Oli.Resources.{Revision}
  alias Oli.Activities.Model



  @doc """
  Determine the attempt state of this resource, that has a given set of activities
  and activity revisions present.

  Note that this method will create attempts. If a resource attempt can be started
  without student intervention (aka an ungraded page) attempts for the resource and all
  activities and all parts will be created. Transformations are applied at activity attempt creation time, and stored on the
  the activity.

  If a resource attempt is in progress, returns a tuple of the form:

  `{:in_progress, {%ResourceAttempt{}, ActivityAttemptMap}}`

  Where `%ResourceAttempt{}` is the in progress attempt and ActivityAttemptMap is a map
  of activity ids to tuples of activity attempts to part maps. See `get_latest_attempts`
  for more details on this map structure.

  If the attempt has not started, returns a tuple of the form:

  `{:not_started, {%ResourceAccess{}, [%ResourceAttempt{}]}`
  """
  @spec determine_resource_attempt_state(%Revision{}, String.t, number(), any) :: {:in_progress, {%ResourceAttempt{}, %{}}} | {:not_started, {%ResourceAccess{}, [%ResourceAttempt{}]}}
  def determine_resource_attempt_state(resource_revision, context_id, user_id, activity_provider) do

    # determine latest resource attempt and then derive the current resource state
    get_latest_resource_attempt(resource_revision.resource_id, context_id, user_id)
    |> get_resource_state(resource_revision, context_id, user_id, activity_provider)

  end


  def get_resource_state(resource_attempt, resource_revision, context_id, user_id, activity_provider) do

    case resource_revision.graded do
      true -> get_graded_resource_state(resource_attempt, resource_revision, context_id, user_id, activity_provider)
      false -> get_ungraded_resource_state(resource_attempt, resource_revision, context_id, user_id, activity_provider)
    end

  end

  def get_ungraded_resource_state(resource_attempt, resource_revision, context_id, user_id, activity_provider) do

    if is_nil(resource_attempt) or resource_attempt.revision_id != resource_revision.id do
      {:in_progress, create_new_attempt_tree(resource_attempt, resource_revision, context_id, user_id, activity_provider)}
    else
      {:in_progress, {resource_attempt, get_latest_attempts(resource_attempt.id)}}
    end
  end

  def get_graded_resource_state(resource_attempt, resource_revision, context_id, user_id, activity_provider) do

    if is_nil(resource_attempt) or !is_nil(resource_attempt.date_evalulated) do
      {:not_started, get_resource_attempt_history(resource_revision.resource_id, context_id, user_id)}
    else
      if resource_attempt.revision_id != resource_revision.id do

        # At some point we can optimize this case to allow curernt attempts for
        # activities within this resource attempt whose activity revisions haven't
        # changed to be pull forward to this new resource attempt.  This would allow
        # a use case where - live during an exam - an instructor deletes an activity. Students
        # would need to create a new resource attempt, but their exist work could be pulled
        # forward.
        {:in_progress, create_new_attempt_tree(resource_attempt, resource_revision, context_id, user_id, activity_provider)}
      else

        # Bonus optimizastion at some point: look at each activity attempt, if any are
        # for an activity revision that differs from the
        # the current activity revision - create a new attempt
        # for that activity. This allows a use case where an instructor live publishes
        # during the middle of a student resource attempt a fix for one specific activity.

        {:in_progress, {resource_attempt, get_latest_attempts(resource_attempt.id)}}
      end
    end

  end

  @doc """
  Retrieves the resource access record and all (if any) attempts related to it
  in a two element tuple of the form:

  `{%ResourceAccess, [%ResourceAttempt{}]}`

  The empty list `[]` will be present if there are no resource attempts.
  """
  def get_resource_attempt_history(resource_id, context_id, user_id) do

    access = get_resource_access(resource_id, context_id, user_id)

    id = access.id

    attempts = Repo.all(from ra in ResourceAttempt,
      where: ra.resource_access_id == ^id,
      select: ra)

    attempt_representation = case attempts do
      nil -> []
      records -> records
    end

    {access, attempt_representation}
  end

  def get_resource_access(resource_id, context_id, user_id) do
    Repo.one(from a in ResourceAccess,
      join: s in Section, on: a.section_id == s.id,
      where: a.user_id == ^user_id and s.context_id == ^context_id and a.resource_id == ^resource_id,
      select: a)
  end

  def create_new_attempt_tree(old_resource_attempt, resource_revision, context_id, user_id, activity_provider) do

    {resource_access_id, next_attempt_number} = case old_resource_attempt do
      nil -> {get_resource_access(resource_revision.resource_id, context_id, user_id).id, 1}
      attempt -> {attempt.resource_access_id, attempt.attempt_number + 1}
    end

    activity_revisions = activity_provider.(resource_revision)

    {:ok, resource_attempt} = create_resource_attempt(%{
      attempt_guid: UUID.uuid4(),
      resource_access_id: resource_access_id,
      attempt_number: next_attempt_number,
      revision_id: resource_revision.id
    })

    {resource_attempt, Enum.reduce(activity_revisions, %{}, fn %Revision{resource_id: resource_id, id: id, content: model} = revision, m ->

        {:ok, parsed_model} = Model.parse(model)

        # todo, apply transformations
        transformed_model = model

        {:ok, activity_attempt} = create_activity_attempt(%{
          resource_attempt_id: resource_attempt.id,
          attempt_guid: UUID.uuid4(),
          attempt_number: 1,
          revision_id: id,
          resource_id: resource_id,
          transformed_model: transformed_model
        })

        # We simulate the effect of preloading the revision by setting it
        # after we create the record. This is needed so that this function matches
        # the contract of get_latest_attempt - namely that the revision association
        # on activity attempt records is preloaded.
        activity_attempt = Map.put(activity_attempt, :revision, revision)

        part_attempts = create_part_attempts(parsed_model, activity_attempt)

        Map.put(m, resource_id, {activity_attempt, part_attempts})
    end)}

  end

  defp create_part_attempts(parsed_model, activity_attempt) do
    Enum.reduce(parsed_model.parts, %{}, fn p, m ->
      {:ok, part_attempt} = create_part_attempt(%{
        attempt_guid: UUID.uuid4(),
        activity_attempt_id: activity_attempt.id,
        attempt_number: 1,
        part_id: p.id
      })
      Map.put(m, p.id, part_attempt)
    end)
  end

  @doc """
  Retrieves the state of the latest attempts for a given resource attempt id.

  Return value is a map of activity ids to a two element tuple.  The first
  element is the latest activity attempt and the second is a map of part ids
  to their part attempts. As an example:

  %{
    232 => {%ActivityAttempt{}, %{ "1" => %PartAttempt{}, "2" => %PartAttempt{}}}
    233 => {%ActivityAttempt{}, %{ "1" => %PartAttempt{}, "2" => %PartAttempt{}}}
  }
  """
  def get_latest_attempts(resource_attempt_id) do

    results = Repo.all(from aa1 in ActivityAttempt,
      join: r in assoc(aa1, :revision),
      left_join: aa2 in ActivityAttempt, on: (aa1.resource_id == aa2.resource_id and aa1.id < aa2.id),
      join: pa1 in PartAttempt, on: aa1.id == pa1.activity_attempt_id,
      left_join: pa2 in PartAttempt, on: (aa1.id == pa2.activity_attempt_id and pa1.part_id == pa2.part_id and pa1.id < pa2.id),
      where: aa1.resource_attempt_id == ^resource_attempt_id and is_nil(aa2.id) and is_nil(pa2.id),
      preload: [revision: r],
      select: {pa1, aa1})

    Enum.reduce(results, %{}, fn {part_attempt, activity_attempt}, m ->

      activity_id = activity_attempt.resource_id
      part_id = part_attempt.part_id

      # ensure we have an entry for this resource
      m = case Map.has_key?(m, activity_id) do
        true -> m
        false -> Map.put(m, activity_id, {activity_attempt, %{}})
      end

      activity_entry = case Map.get(m, activity_id) do
        {current_attempt, part_map} -> {current_attempt, Map.put(part_map, part_id, part_attempt)}
      end

      Map.put(m, activity_id, activity_entry)
    end)

  end

  @doc """
  Retrieves the latest resource attempt for a given resource id,
  context id and user id.  If no attempts exist, returns nil.
  """
  def get_latest_resource_attempt(resource_id, context_id, user_id) do

    Repo.one(from a in ResourceAccess,
      join: s in Section, on: a.section_id == s.id,
      join: ra1 in ResourceAttempt, on: a.id == ra1.resource_access_id,
      left_join: ra2 in ResourceAttempt, on: (a.id == ra2.resource_access_id and ra1.id < ra2.id),
      where: a.user_id == ^user_id and s.context_id == ^context_id and a.resource_id == ^resource_id and is_nil(ra2),
      select: ra1)

  end

  def save_student_input(part_inputs) do

    Repo.transaction(fn ->
      length = length(part_inputs)
      case Enum.reduce_while(part_inputs, :ok, fn %{attempt_guid: attempt_guid, response: response}, _ ->

        case Repo.update_all(from(p in PartAttempt, where: p.attempt_guid == ^attempt_guid), set: [response: response]) do
          nil -> {:halt, :error}
          _ -> {:cont, :ok}
        end
      end) do
        :error -> Repo.rollback(:error)
        :ok -> length
      end

    end)

  end


  @doc """
  Creates or updates an access record for a given resource, section context id and user. When
  created the access count is set to 1, otherwise on updates the
  access count is incremented.
  ## Examples
      iex> track_access(resource_id, context_id, user_id)
      {:ok, %ResourceAccess{}}
      iex> track_access(resource_id, context_id, user_id)
      {:error, %Ecto.Changeset{}}
  """
  def track_access(resource_id, context_id, user_id) do

    section = Sections.get_section_by(context_id: context_id)

    Oli.Repo.insert!(
      %ResourceAccess{access_count: 1, user_id: user_id, section_id: section.id, resource_id: resource_id},
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
  Updates an activity attempt.
  ## Examples
      iex> update_activity_attempt(revision, %{field: new_value})
      {:ok, %ActivityAttempt{}}
      iex> update_activity_attempt(revision, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_activity_attempt(activity_attempt, attrs) do
    ActivityAttempt.changeset(activity_attempt, attrs)
    |> Repo.update()
  end

  @doc """
  Creates an activity attempt.
  ## Examples
      iex> create_activity_attempt(%{field: value})
      {:ok, %ActivityAttempt{}}
      iex> create_activity_attempt(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_activity_attempt(attrs \\ %{}) do
    %ActivityAttempt{}
    |> ActivityAttempt.changeset(attrs)
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
