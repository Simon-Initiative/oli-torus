defmodule Oli.Delivery.Attempts do

  import Ecto.Query, warn: false
  alias Oli.Repo
  alias Oli.Delivery.Sections.{Section}
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Attempts.{PartAttempt, ResourceAccess, ResourceAttempt, ActivityAttempt}
  alias Oli.Activities.State.ActivityState
  alias Oli.Resources.{Revision}
  alias Oli.Activities.Model
  alias Oli.Activities.Model.Feedback
  alias Oli.Activities.Transformers
  alias Oli.Delivery.Attempts.Result
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Delivery.Page.ModelPruner


  def reset_activity(context_id, activity_attempt_guid) do

    activity_attempt = get_activity_attempt_by(attempt_guid: activity_attempt_guid)

    if (activity_attempt == nil) do
      {:error, :not_found}
    else
      activity_attempt = activity_attempt |> Repo.preload([:part_attempts])

      # Resolve the revision to pick up the latest
      revision = DeliveryResolver.from_resource_id(context_id, activity_attempt.resource_id)

      # parse and transform
      {:ok, model} = Model.parse(revision.content)
      {:ok, transformed_model} = Transformers.apply_transforms(revision.content)

      {:ok, new_activity_attempt} = create_activity_attempt(%{
        attempt_guid: UUID.uuid4(),
        attempt_number: activity_attempt.attempt_number + 1,
        transformed_model: transformed_model,
        resource_id: activity_attempt.resource_id,
        revision_id: revision.id,
        resource_attempt_id: activity_attempt.resource_attempt_id
      })

      new_part_attempts = Enum.map(activity_attempt.part_attempts, fn p ->
        {:ok, part_attempt} = create_part_attempt(%{
          attempt_guid: UUID.uuid4(),
          attempt_number: 1,
          part_id: p.part_id,
          activity_attempt_id: new_activity_attempt.id
        })
        part_attempt
      end)

      {:ok, ActivityState.from_attempt(new_activity_attempt, new_part_attempts, model),
        ModelPruner.prune(transformed_model)}
    end

  end

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


  defp get_resource_state(resource_attempt, resource_revision, context_id, user_id, activity_provider) do

    case resource_revision.graded do
      true -> get_graded_resource_state(resource_attempt, resource_revision, context_id, user_id, activity_provider)
      false -> get_ungraded_resource_state(resource_attempt, resource_revision, context_id, user_id, activity_provider)
    end

  end

  defp get_ungraded_resource_state(resource_attempt, resource_revision, context_id, user_id, activity_provider) do

    if is_nil(resource_attempt) or resource_attempt.revision_id != resource_revision.id do
      {:in_progress, create_new_attempt_tree(resource_attempt, resource_revision, context_id, user_id, activity_provider)}
    else
      {:in_progress, {resource_attempt, get_latest_attempts(resource_attempt.id)}}
    end
  end

  defp get_graded_resource_state(resource_attempt, resource_revision, context_id, user_id, activity_provider) do

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

  defp get_resource_access(resource_id, context_id, user_id) do
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

        # Todo, handle and propagate upwards failures in parsing and transformation
        {:ok, parsed_model} = Model.parse(model)
        {:ok, transformed_model} = Transformers.apply_transforms(model)

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

  @doc """
  Processes a list of part inputs and saves the response to the corresponding
  part attempt record.

  On success returns a tuple of the form `{:ok, count}`
  """
  def save_student_input(part_inputs) do

    Repo.transaction(fn ->
      count = length(part_inputs)
      case Enum.reduce_while(part_inputs, :ok, fn %{attempt_guid: attempt_guid, response: response}, _ ->

        case Repo.update_all(from(p in PartAttempt, where: p.attempt_guid == ^attempt_guid), set: [response: response]) do
          nil -> {:halt, :error}
          _ -> {:cont, :ok}
        end
      end) do
        :error -> Repo.rollback(:error)
        :ok -> {:ok, count}
      end

    end)

  end

  # Evaluate a list of part_input submissions for a matching list of part_attempt records
  defp evaluate_submissions(_, [], _), do: {:error, "nothing to process"}
  defp evaluate_submissions(activity_attempt_guid, part_inputs, part_attempts) do

    %ActivityAttempt{transformed_model: transformed_model} = get_activity_attempt_by(attempt_guid: activity_attempt_guid)
    {:ok, %Model{parts: parts}} = Model.parse(transformed_model)

    # We need to tie the attempt_guid from the part_inputs to the attempt_guid
    # from the %PartAttempt, and then the part id from the %PartAttempt to the
    # part id in the parsed model.
    part_map = Enum.reduce(parts, %{}, fn p, m -> Map.put(m, p.id, p) end)
    attempt_map = Enum.reduce(part_attempts, %{}, fn p, m -> Map.put(m, p.attempt_guid, p) end)

    evaluations = Enum.map(part_inputs, fn %{attempt_guid: attempt_guid, input: input} ->

      attempt = Map.get(attempt_map, attempt_guid)
      part = Map.get(part_map, attempt.part_id)

      Oli.Delivery.Evaluation.Evaluator.evaluate(part, input)
    end)

    {:ok, evaluations}
  end

  # Persist the result of a single evaluation for a single part_input submission.
  defp persist_single_evaluation({_, {:error, error}}, _), do: {:halt, {:error, error}}
  defp persist_single_evaluation({%{attempt_guid: attempt_guid, input: input},
    {:ok,  {%Feedback{} = feedback, %Result{out_of: out_of, score: score}}}}, {:ok, results}) do

    now = DateTime.utc_now()

    case Repo.update_all(from(p in PartAttempt, where: p.attempt_guid == ^attempt_guid and is_nil(p.date_evaluated)),
      set: [response: input, date_evaluated: now, score: score, out_of: out_of, feedback: feedback]) do
      nil -> {:halt, :error}
      {1, _} -> {:cont, {:ok, results ++ [%{attempt_guid: attempt_guid, feedback: feedback, score: score, out_of: out_of}]}}
      _ -> {:halt, :error}
    end

  end

  # Given a list of evaluations that match a list of part_input submissions,
  # persist the results of each evaluation to the corresponding part_attempt record
  # On success, continue persistence by calling a roll_up function that will may or
  # not roll up the results of the these part_attempts to the activity attempt
  #
  # The return value here is {:ok, [%{}]}, where the maps in the array are the
  # evaluation result that will be sent back to the client
  defp persist_evaluations({:error, error}, _, _), do: {:error, error}
  defp persist_evaluations({:ok, evaluations}, part_inputs, roll_up_fn) do

    evaluated_inputs = Enum.zip(part_inputs, evaluations)

    Repo.transaction(fn ->
      case Enum.reduce_while(evaluated_inputs, {:ok, []}, &persist_single_evaluation/2) do
        {:error, error} -> Repo.rollback(error)
        {:ok, results} -> roll_up_fn.({:ok, results})
      end
    end)
  end

  # Filters out part_inputs whose attempts are already submitted.  This step
  # simply lowers the burden on an activity client for having to manage this - as
  # they now can instead just choose to always submit all parts.  Also
  # returns a boolean indicated whether this filtered collection of submissions
  # will complete the activity attempt.
  defp filter_already_submitted(part_inputs, part_attempts) do

    # filter the part_inputs that have already been evaluated
    already_evaluated = Enum.filter(part_attempts, fn p -> p.date_evaluated != nil end)
    |> Enum.map(fn e -> e.attempt_guid end)
    |> MapSet.new()

    part_inputs = Enum.filter(part_inputs, fn %{attempt_guid: attempt_guid} -> !MapSet.member?(already_evaluated, attempt_guid) end)

    # Check to see if this would complete the activity submidssion
    yet_to_be_evaluated = Enum.filter(part_attempts, fn p -> p.date_evaluated == nil end)
    |> Enum.map(fn e -> e.attempt_guid end)
    |> MapSet.new()

    to_be_evaluated = Enum.map(part_inputs, fn e -> e.attempt_guid end)
    |> MapSet.new()

    {MapSet.equal?(yet_to_be_evaluated, to_be_evaluated), part_inputs}
  end

  @doc """
  Processes a student submission for some number of parts for the given
  activity attempt guid.  If this collection of part attempts completes the activity
  the results of the part evalutions (including ones already having been evaluated)
  will be rolled up to the activity attempt record.

  On success returns an `{:ok, results}` tuple where results in an array of maps.  Each
  map instance contains the result of one of the evaluations in the form:

  `${score: score, out_of: out_of, feedback: feedback, attempt_guid, attempt_guid}`

  There can be less items in the results list than there are items in the input part_inputs
  as logic here will not evaluate part_input instances whose part attempt has already
  been evaluated.

  On failure returns `{:error, error}`
  """
  @spec submit_part_evaluations(String.t, [map()]) :: {:ok, [map()]} | {:error, any}
  def submit_part_evaluations(activity_attempt_guid, part_inputs) do

    part_attempts = get_latest_part_attempts(activity_attempt_guid)

    roll_up = fn result ->
      rollup_part_attempt_evaluations(activity_attempt_guid)
      result
    end

    no_roll_up = fn result -> result end

    {roll_up_fn, part_inputs} = case filter_already_submitted(part_inputs, part_attempts) do
      {true, part_inputs} -> {roll_up, part_inputs}
      {false, part_inputs} -> {no_roll_up, part_inputs}
    end

    case evaluate_submissions(activity_attempt_guid, part_inputs, part_attempts)
    |> persist_evaluations(part_inputs, roll_up_fn) do

      {:ok, results} -> results
      error -> error
    end

  end

  @doc """
  Gets an activity attempt by a clause.
  ## Examples
      iex> get_activity_attempt_by(attempt_guid: "123")
      {:ok, %Section{}}
      iex> get_activity_attempt_by(attempt_guid: "111")
      { :error, changeset }
  """
  def get_activity_attempt_by(clauses), do: Repo.get_by(ActivityAttempt, clauses) |> Repo.preload([:revision])

  def rollup_part_attempt_evaluations(activity_attempt_guid) do

    # find the latest part attempts
    part_attempts = get_latest_part_attempts(activity_attempt_guid)

    # apply the scoring strategy and set the evaluation on the activity
    activity_attempt = get_activity_attempt_by(attempt_guid: activity_attempt_guid)

    # TODO: implement other scoring strategies. But for right now total makes sense
    {score, out_of} = Enum.reduce(part_attempts, {0, 0}, fn p, {score, out_of} ->
      {score + p.score, out_of + p.out_of}
    end)

    update_activity_attempt(activity_attempt, %{
      score: score,
      out_of: out_of,
      date_evaluated: DateTime.utc_now()
    })

  end

  defp get_latest_part_attempts(activity_attempt_guid) do
    Repo.all(from pa1 in PartAttempt,
      left_join: pa2 in PartAttempt, on: (pa1.part_id == pa2.part_id and pa1.id < pa2.id),
      join: aa in ActivityAttempt, on: aa.id == pa1.activity_attempt_id,
      where: aa.attempt_guid == ^activity_attempt_guid and is_nil(pa2),
      select: pa1)
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
