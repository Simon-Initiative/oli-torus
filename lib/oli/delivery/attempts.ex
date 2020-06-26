defmodule Oli.Delivery.Attempts do

  import Ecto.Query, warn: false
  alias Oli.Repo
  alias Oli.Delivery.Sections.{Section}
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Attempts.{PartAttempt, ResourceAccess, ResourceAttempt, ActivityAttempt, Snapshot}
  alias Oli.Delivery.Evaluation.{EvaluationContext}
  alias Oli.Activities.State.ActivityState
  alias Oli.Resources.{Revision}
  alias Oli.Activities.Model
  alias Oli.Activities.Model.Feedback
  alias Oli.Activities.Transformers
  alias Oli.Delivery.Attempts.{StudentInput, Result, Scoring}
  alias Oli.Publishing.{PublishedResource, DeliveryResolver}
  alias Oli.Delivery.Page.ModelPruner


  @doc """
  Resets a current activity attempt, creating a new activity attempt and
  new part attempts.

  The return value is of the form:

  `{:ok, %ActivityState, model}` where model is potentially a new model of the activity

  If all attempts have been exhausted:

  `{:error, {:no_more_attempts}}`

  If the activity attempt cannot be found:

  `{:error, {:not_found}}`
  """
  def reset_activity(context_id, activity_attempt_guid) do

    Repo.transaction(fn ->

      activity_attempt = get_activity_attempt_by(attempt_guid: activity_attempt_guid)

      if (activity_attempt == nil) do
        Repo.rollback({:not_found})
      else

        # We cannot rely on the attempt number from the supplied activity attempt
        # to determine the total number of attempts - or the next attempt number, since
        # a client could be resetting an attempt that is not the latest attempt (e.g. from multiple
        # browser windows).
        # Instead we will query to determine the count of attempts. This is likely an
        # area where we want locking in place to ensure that we can never get into a state
        # where two attempts are generated with the same number

        attempt_count = count_activity_attempts(activity_attempt.resource_attempt_id, activity_attempt.resource_id)

        if activity_attempt.revision.max_attempts > 0 and activity_attempt.revision.max_attempts <= attempt_count do
          Repo.rollback({:no_more_attempts})
        else
          activity_attempt = activity_attempt |> Repo.preload([:part_attempts])

          # Resolve the revision to pick up the latest
          revision = DeliveryResolver.from_resource_id(context_id, activity_attempt.resource_id)

          # parse and transform
          with {:ok, model} <- Model.parse(revision.content),
            {:ok, transformed_model} <- Transformers.apply_transforms(revision.content),
            {:ok, new_activity_attempt} <- create_activity_attempt(%{
              attempt_guid: UUID.uuid4(),
              attempt_number: attempt_count + 1,
              transformed_model: transformed_model,
              resource_id: activity_attempt.resource_id,
              revision_id: revision.id,
              resource_attempt_id: activity_attempt.resource_attempt_id
            })
          do
            # simulate preloading of the revision
            new_activity_attempt = Map.put(new_activity_attempt, :revision, revision)

            new_part_attempts = case Enum.reduce_while(activity_attempt.part_attempts, {:ok, []}, fn (p, {:ok, acc}) ->

              case create_part_attempt(%{
                attempt_guid: UUID.uuid4(),
                attempt_number: 1,
                part_id: p.part_id,
                activity_attempt_id: new_activity_attempt.id
              }) do
                {:ok, part_attempt} -> {:cont, {:ok, acc ++ [part_attempt]}}
                {:error, changeset} -> {:halt, {:error, changeset}}
              end

            end) do
              {:ok, new_part_attempts} -> new_part_attempts
              {:error, error} -> Repo.rollback(error)
            end

            {ActivityState.from_attempt(new_activity_attempt, new_part_attempts, model),
              ModelPruner.prune(transformed_model)}

          else
            {:error, error} -> Repo.rollback(error)
          end
        end
      end

    end)

  end

  defp count_activity_attempts(resource_attempt_id, resource_id) do
    {count} = Repo.one(from(p in ActivityAttempt,
      where: p.resource_attempt_id == ^resource_attempt_id and p.resource_id == ^resource_id,
      select: {count(p.id)}))

    count
  end


  @doc """
  Retrieve a hint for an attempt.

  Return value is `{:ok, %Hint{}, boolean}` where the boolean is an indication as
  to whether there are more hints.

  If there is not a hint available to fulfill this request, this function returns:
  `{:error, {:no_more_hints}}`

  If the part attempt can not be found this function returns:
  `{:error, {:not_found}}`

  If the attept record cannot be updated to track the new hint request, returns:
  `{:error, %Changeset{}}`
  """
  def request_hint(activity_attempt_guid, part_attempt_guid) do

    # get both the activity and part attempt records
    Repo.transaction(fn ->

      with {:ok, activity_attempt} <- get_activity_attempt_by(attempt_guid: activity_attempt_guid) |> Oli.Utils.trap_nil(:not_found),
        {:ok, part_attempt} <- get_part_attempt_by(attempt_guid: part_attempt_guid) |> Oli.Utils.trap_nil(:not_found),
        {:ok, model} <- Model.parse(activity_attempt.transformed_model),
        {:ok, part} <- Enum.find(model.parts, fn p -> p.id == part_attempt.part_id end) |> Oli.Utils.trap_nil(:not_found)
      do
        shown_hints = length(part_attempt.hints)
        all_hints = length(part.hints)

        if all_hints > shown_hints do

          hint = Enum.at(part.hints, shown_hints)
          case update_part_attempt(part_attempt, %{hints: part_attempt.hints ++ [hint.id]}) do
            {:ok, _} -> {hint, all_hints > shown_hints + 1}
            {:error, error} -> Repo.rollback(error)
          end

        else
          Repo.rollback({:no_more_hints})
        end
      else
        {:error, error} -> Repo.rollback(error)
      end

    end)

  end

  @doc """
  Determine the attempt state of this resource, that has a given set of activities
  and activity revisions present.

  Note that this method will create attempts. If a resource attempt can be started
  without student intervention (aka an ungraded page) attempts for the resource and all
  activities and all parts will be created. Transformations are applied at activity attempt creation time, and stored on the
  the activity.

  If a resource attempt is in progress, returns a tuple of the form:

  `{:ok, {:in_progress, {%ResourceAttempt{}, ActivityAttemptMap}}}`

  Where `%ResourceAttempt{}` is the in progress attempt and ActivityAttemptMap is a map
  of activity ids to tuples of activity attempts to part maps. See `get_latest_attempts`
  for more details on this map structure.

  If a resource attempt is in progress and the revision of the resource pertaining to that attempt
  has changed compared to the supplied resource_revision, returns a tuple of the form:

  `{:ok, {:revised, {%ResourceAttempt{}, ActivityAttemptMap}}}`

  If the attempt has not started, returns a tuple of the form:

  `{:ok, {:not_started, {%ResourceAccess{}, [%ResourceAttempt{}]}}`
  """
  @spec determine_resource_attempt_state(%Revision{}, String.t, number(), any) :: {:ok, {:in_progress, {%ResourceAttempt{}, map() }}} | {:ok, {:revised, {%ResourceAttempt{}, map() }}} | {:ok, {:not_started, {%ResourceAccess{}, [%ResourceAttempt{}]}}} | {:error, any}
  def determine_resource_attempt_state(resource_revision, context_id, user_id, activity_provider) do

    # determine latest resource attempt and then derive the current resource state
    Repo.transaction(fn ->

      case get_latest_resource_attempt(resource_revision.resource_id, context_id, user_id)
      |> get_resource_state(resource_revision, context_id, user_id, activity_provider) do

        {:ok, results} -> results
        {:error, error} -> Repo.rollback(error)
      end

    end)

  end


  defp get_resource_state(resource_attempt, resource_revision, context_id, user_id, activity_provider) do

    case resource_revision.graded do
      true -> get_graded_resource_state(resource_attempt, resource_revision, context_id, user_id, activity_provider)
      false -> get_ungraded_resource_state(resource_attempt, resource_revision, context_id, user_id, activity_provider)
    end

  end

  defp get_ungraded_resource_state(resource_attempt, resource_revision, context_id, user_id, activity_provider) do

    # For ungraded pages we can safely throw away an existing resource attempt and create a new one
    # in the case that the attempt was pinned to an older revision of the resource. This allows newly published
    # changes to the resource to be seen after a user has visited the resource previously
    if is_nil(resource_attempt) or resource_attempt.revision_id != resource_revision.id do

      case create_new_attempt_tree(resource_attempt, resource_revision, context_id, user_id, activity_provider) do
        {:ok, results} -> {:ok, {:in_progress, results}}
        error -> error
      end

    else
      {:ok, {:in_progress, {resource_attempt, get_latest_attempts(resource_attempt.id)}}}
    end
  end

  defp get_graded_resource_state(resource_attempt, resource_revision, context_id, user_id, _) do

    if is_nil(resource_attempt) or !is_nil(resource_attempt.date_evaluated) do
      {:ok, {:not_started, get_resource_attempt_history(resource_revision.resource_id, context_id, user_id)}}
    else

      # Unlike ungraded pages, for graded pages we do not throw away attempts and create anew in the case
      # where the resource revision has changed.  Instead we return back the existing attempt tree and force
      # the page renderer to resolve this discrepancy by indicating the "revised" state.
      if resource_revision.id !== resource_attempt.revision_id do
        {:ok, {:revised, {resource_attempt, get_latest_attempts(resource_attempt.id)}}}
      else
        {:ok, {:in_progress, {resource_attempt, get_latest_attempts(resource_attempt.id)}}}
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

  @doc """
  Retrieves all graded resource access for a given context

  `[%ResourceAccess{}, ...]`
  """
  def get_graded_resource_access_for_context(context_id) do
    Repo.all(from a in ResourceAccess,
      join: s in Section, on: a.section_id == s.id,
      join: p in PublishedResource, on: s.publication_id == p.publication_id,
      join: r in Revision, on: p.revision_id == r.id,
      where: s.context_id == ^context_id and r.graded == true,
      select: a)
  end

  @doc """
  Retrieves all resource accesses for a given context and user

  `[%ResourceAccess{}, ...]`
  """
  def get_user_resource_accesses_for_context(context_id, user_id) do
    Repo.all(from a in ResourceAccess,
      join: s in Section, on: a.section_id == s.id,
      join: p in PublishedResource, on: s.publication_id == p.publication_id,
      join: r in Revision, on: p.revision_id == r.id,
      where: s.context_id == ^context_id and a.user_id == ^user_id,
      select: a)
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

    activity_revisions = activity_provider.(context_id, resource_revision)

    case create_resource_attempt(%{
      attempt_guid: UUID.uuid4(),
      resource_access_id: resource_access_id,
      attempt_number: next_attempt_number,
      revision_id: resource_revision.id
    }) do
      {:ok, resource_attempt} ->
        {:ok, {resource_attempt, Enum.reduce(activity_revisions, %{}, fn revision, m ->

          case create_full_activity_attempt(resource_attempt, revision) do
            {:ok, {activity_attempt, part_attempts}} -> Map.put(m, revision.resource_id, {activity_attempt, part_attempts})
            e -> Map.put(m, revision.resource_id, e)
          end

        end)}}
      error -> error
    end

  end

  defp create_full_activity_attempt(resource_attempt, %Revision{resource_id: resource_id, id: id, content: model} = revision) do

    with {:ok, parsed_model} <- Model.parse(model),
      {:ok, transformed_model} <- Transformers.apply_transforms(model),
      {:ok, activity_attempt} <- create_activity_attempt(%{
        resource_attempt_id: resource_attempt.id,
        attempt_guid: UUID.uuid4(),
        attempt_number: 1,
        revision_id: id,
        resource_id: resource_id,
        transformed_model: transformed_model
      }),
      {:ok, part_attempts} <- create_part_attempts(parsed_model, activity_attempt)
    do
      # We simulate the effect of preloading the revision by setting it
      # after we create the record. This is needed so that this function matches
      # the contract of get_latest_attempt - namely that the revision association
      # on activity attempt records is preloaded.

      {:ok, {Map.put(activity_attempt, :revision, revision), part_attempts}}
    end

  end

  defp create_part_attempts(parsed_model, activity_attempt) do
    Enum.reduce_while(parsed_model.parts, {:ok, %{}}, fn p, {:ok, m} ->
      case create_part_attempt(%{
        attempt_guid: UUID.uuid4(),
        activity_attempt_id: activity_attempt.id,
        attempt_number: 1,
        part_id: p.id
      }) do
        {:ok, part_attempt} -> {:cont, {:ok, Map.put(m, p.id, part_attempt)}}
        e -> {:halt, e}
      end

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
  Create a new resource attempt in an active state for the given page revision slug
  in the specified context_id and for a specific user.

  On success returns:
  `{:ok, {%{ResourceAttempt}, ActivityAttemptMap}}`

  Possible failure returns are:
  `{:error, {:not_found}}` if the revision slug cannot be resolved
  `{:error, {:active_attempt_present}}` if an active resource attempt is present
  `{:error, {:no_more_attempts}}` if no more attempts are present

  """
  def start_resource_attempt(revision_slug, context_id, user_id, activity_provider) do

    Repo.transaction(fn ->

      with {:ok, revision} <- DeliveryResolver.from_revision_slug(context_id, revision_slug) |> Oli.Utils.trap_nil(:not_found),
        {_, resource_attempts} <- get_resource_attempt_history(revision.resource_id, context_id, user_id)
      do
        case {revision.max_attempts > length(resource_attempts) or revision.max_attempts == 0,
          has_any_active_attempts?(resource_attempts)} do

          {true, false} -> case create_new_attempt_tree(nil, revision, context_id, user_id, activity_provider) do
            {:ok, results} -> results
            {:error, error} -> Repo.rollback(error)
          end
          {true, true} -> Repo.rollback({:active_attempt_present})
          {false, _} -> Repo.rollback({:no_more_attempts})
        end
      else
        {:error, error} -> Repo.rollback(error)
      end

    end)

  end

  defp has_any_active_attempts?(resource_attempts) do
    Enum.any?(resource_attempts, fn r -> r.date_evaluated == nil end)
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

    %ActivityAttempt{transformed_model: transformed_model, attempt_number: attempt_number, resource_attempt: resource_attempt}
      = get_activity_attempt_by(attempt_guid: activity_attempt_guid) |> Repo.preload([:resource_attempt])

    {:ok, %Model{parts: parts}} = Model.parse(transformed_model)

    # We need to tie the attempt_guid from the part_inputs to the attempt_guid
    # from the %PartAttempt, and then the part id from the %PartAttempt to the
    # part id in the parsed model.
    part_map = Enum.reduce(parts, %{}, fn p, m -> Map.put(m, p.id, p) end)
    attempt_map = Enum.reduce(part_attempts, %{}, fn p, m -> Map.put(m, p.attempt_guid, p) end)

    evaluations = Enum.map(part_inputs, fn %{attempt_guid: attempt_guid, input: input} ->

      attempt = Map.get(attempt_map, attempt_guid)
      part = Map.get(part_map, attempt.part_id)

      context = %EvaluationContext{
        resource_attempt_number: resource_attempt.attempt_number,
        activity_attempt_number: attempt_number,
        part_attempt_number: attempt.attempt_number,
        input: input.input
      }

      Oli.Delivery.Evaluation.Evaluator.evaluate(part, context)
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

    case Enum.reduce_while(evaluated_inputs, {:ok, []}, &persist_single_evaluation/2) do
      {:ok, results} -> roll_up_fn.({:ok, results})
      error -> error
    end

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
  Processes a test mode evaulation.
  """
  @spec perform_test_evaluation(map(), [map()]) :: {:ok, [map()]} | {:error, any}
  def perform_test_evaluation(model, part_inputs) do

    {:ok, %Model{parts: parts}} = Model.parse(model)

    # We need to tie the attempt_guid from the part_inputs to the attempt_guid
    # from the %PartAttempt, and then the part id from the %PartAttempt to the
    # part id in the parsed model.
    part_map = Enum.reduce(parts, %{}, fn p, m -> Map.put(m, p.id, p) end)

    evaluations = Enum.map(part_inputs, fn %{part_id: part_id, input: input} ->

      part = Map.get(part_map, part_id)

      # we should eventually support test evals that can pass to the server the
      # full context, but for now we hardcode all of the context except the input
      context = %EvaluationContext{
        resource_attempt_number: 1,
        activity_attempt_number: 1,
        part_attempt_number: 1,
        input: input.input
      }

      Oli.Delivery.Evaluation.Evaluator.evaluate(part, context)

    end)
    |> Enum.map(fn e ->
      case e do
        {:ok, {feedback, result}} -> %{feedback: feedback, result: result}
        {:error, _} -> %{error: "error in evaluation"}
      end
    end)

    evaluations = Enum.zip(evaluations, part_inputs)
    |> Enum.map(fn {e, %{part_id: part_id}} -> Map.put(e, :part_id, part_id) end)

    {:ok, evaluations}
  end

  @doc """
  Performs activity model transformation for test mode.
  """
  def perform_test_transformation(model) do
    Transformers.apply_transforms(model)
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
  @spec submit_part_evaluations(atom(), String.t, String.t, [map()]) :: {:ok, [map()]} | {:error, any}
  def submit_part_evaluations(role, context_id, activity_attempt_guid, part_inputs) do

    Repo.transaction(fn ->

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
      |> persist_evaluations(part_inputs, roll_up_fn)
      |> generate_snapshots(role, context_id, part_inputs) do

        {:ok, results} -> results
        {:error, error} -> Repo.rollback(error)
      end

    end)

  end

  def submit_graded_page(role, context_id, resource_attempt_guid) do

    Repo.transaction(fn ->

      # get the resource attempt record, ensure it isn't already evaluated
      resource_attempt = get_resource_attempt_by(attempt_guid: resource_attempt_guid)

      if resource_attempt.date_evaluated == nil do

        Enum.each(resource_attempt.activity_attempts, fn a ->
          submit_graded_page_activity(role, context_id, a.attempt_guid)
        end)

        case roll_up_activities_to_resource_attempt(resource_attempt_guid) do
          {:ok, _} -> case roll_up_resource_attempts_to_access(context_id, resource_attempt.resource_access_id) do
            {:ok, results} -> results
            {:error, error} -> Repo.rollback(error)
          end
          {:error, error} -> Repo.rollback(error)
        end

      else
        Repo.rollback({:already_submitted})
      end

    end)

  end

  defp roll_up_activities_to_resource_attempt(resource_attempt_guid) do

    resource_attempt = get_resource_attempt_by(attempt_guid: resource_attempt_guid)

    if resource_attempt.date_evaluated == nil do

      # Leaving this hardcoded to 'total' seems to make sense, but perhaps in the
      # future we do allow this to be configured
      {score, out_of} = Enum.reduce(resource_attempt.activity_attempts, {0, 0}, fn p, {score, out_of} ->
        {score + p.score, out_of + p.out_of}
      end)

      update_resource_attempt(resource_attempt, %{
        score: score,
        out_of: out_of,
        date_evaluated: DateTime.utc_now()
      })

    else
      {:error, {:already_submitted}}
    end

  end

  defp roll_up_resource_attempts_to_access(context_id, resource_access_id) do

    access = Oli.Repo.get(ResourceAccess, resource_access_id) |> Repo.preload([:resource_attempts])
    %{scoring_strategy_id: strategy_id} = DeliveryResolver.from_resource_id(context_id, access.resource_id)

    %Result{score: score, out_of: out_of} =
      Scoring.calculate_score(strategy_id, access.resource_attempts)

    update_resource_access(access, %{
      score: score,
      out_of: out_of,
      date_evaluated: DateTime.utc_now()
    })

  end

  defp submit_graded_page_activity(role, context_id, activity_attempt_guid) do

    Repo.transaction(fn ->

      part_attempts = get_latest_part_attempts(activity_attempt_guid)

      roll_up_fn = fn result ->
        rollup_part_attempt_evaluations(activity_attempt_guid)
        result
      end

      # derive the part_attempts from the currently saved state that we expect
      # to find in the part_attempts
      part_inputs = Enum.map(part_attempts, fn p -> %{attempt_guid: p.attempt_guid, input: %StudentInput{input: Map.get(p.response, "input")}} end)

      case evaluate_submissions(activity_attempt_guid, part_inputs, part_attempts)
      |> persist_evaluations(part_inputs, roll_up_fn)
      |> generate_snapshots(role, context_id, part_inputs) do

        {:ok, results} -> results
        {:error, error} -> Repo.rollback(error)
      end

    end)

  end


  def generate_snapshots({:ok, _} = previous_in_pipline, :student, context_id, part_inputs) do

    part_attempt_guids = Enum.map(part_inputs, fn %{attempt_guid: attempt_guid} -> attempt_guid end)

    results = Repo.all(from pa in PartAttempt,
      join: aa in ActivityAttempt, on: pa.activity_attempt_id == aa.id,
      join: ra in ResourceAttempt, on: aa.resource_attempt_id == ra.id,
      join: a in ResourceAccess, on: ra.resource_access_id == a.id,
      join: r1 in Revision, on: ra.revision_id == r1.id,
      join: r2 in Revision, on: aa.revision_id == r2.id,
      where: pa.attempt_guid in ^part_attempt_guids,
      select: {pa, aa, ra, a, r1, r2})

    # determine all referenced objective ids by the parts that we find
    objective_ids = Enum.reduce(results, MapSet.new([]),
      fn {pa, _, _, _, _, r}, m ->
        Enum.reduce(Map.get(r.objectives, pa.part_id, []), m, fn id, n -> MapSet.put(n, id) end)
      end)
      |> MapSet.to_list()

    objective_revisions_by_id = DeliveryResolver.from_resource_id(context_id, objective_ids)
    |> Enum.reduce(%{}, fn e, m -> Map.put(m, e.resource_id, e.id) end)

    # Now for each part attempt that we evaluated:
    Enum.each(results, fn {part_attempt, _, _, _, _, activity_revision} = result ->

      # Look at the attached objectives for that part for that revision
      attached_objectives = Map.get(activity_revision.objectives, part_attempt.part_id, [])

      case attached_objectives do
        # If there are no attached objectives, create one record recoring nils for the objectives
        [] -> create_individual_snapshot(result, nil, nil)

        # Otherwise create one record for each objective
        objective_ids -> Enum.each(objective_ids, fn id -> create_individual_snapshot(result, id, Map.get(objective_revisions_by_id, id)) end)
      end
    end)

    previous_in_pipline
  end

  def generate_snapshots(previous, _, _, _), do: previous

  defp create_individual_snapshot({part_attempt, activity_attempt, resource_attempt, resource_access, resource_revision, activity_revision}, objective_id, revision_id) do

    {:ok, _} = create_snapshot(%{
      resource_id: resource_access.resource_id,
      user_id: resource_access.user_id,
      section_id: resource_access.section_id,
      resource_attempt_number: resource_attempt.attempt_number,
      graded: resource_revision.graded,
      activity_id: activity_attempt.resource_id,
      revision_id: activity_attempt.revision_id,
      activity_type_id: activity_revision.activity_type_id,
      attempt_number: activity_attempt.attempt_number,
      part_id: part_attempt.part_id,
      correct: part_attempt.score == part_attempt.out_of,
      score: part_attempt.score,
      out_of: part_attempt.out_of,
      hints: length(part_attempt.hints),
      part_attempt_number: part_attempt.attempt_number,
      part_attempt_id: part_attempt.id,
      objective_id: objective_id,
      objective_revision_id: revision_id
    })
  end

  @doc """
  Gets an activity attempt by a clause.
  ## Examples
      iex> get_activity_attempt_by(attempt_guid: "123")
      %ActivityAttempt
      iex> get_activity_attempt_by(attempt_guid: "111")
      nil
  """
  def get_activity_attempt_by(clauses), do: Repo.get_by(ActivityAttempt, clauses) |> Repo.preload([:revision])

  @doc """
  Gets a part attempt by a clause.
  ## Examples
      iex> get_part_attempt_by(attempt_guid: "123")
      %PartAttempt{}
      iex> get_part_attempt_by(attempt_guid: "111")
      nil
  """
  def get_part_attempt_by(clauses), do: Repo.get_by(PartAttempt, clauses)

  @doc """
  Gets a resource attempt by a clause.
  ## Examples
      iex> get_resource_attempt_by(attempt_guid: "123")
      %ResourceAttempt{}
      iex> get_resource_attempt_by(attempt_guid: "111")
      nil
  """
  def get_resource_attempt_by(clauses), do: Repo.get_by(ResourceAttempt, clauses) |> Repo.preload([:activity_attempts])

  def rollup_part_attempt_evaluations(activity_attempt_guid) do

    # find the latest part attempts
    part_attempts = get_latest_part_attempts(activity_attempt_guid)

    # apply the scoring strategy and set the evaluation on the activity
    activity_attempt = get_activity_attempt_by(attempt_guid: activity_attempt_guid)

    %Result{score: score, out_of: out_of}
      = Scoring.calculate_score(activity_attempt.revision.scoring_strategy_id, part_attempts)

    update_activity_attempt(activity_attempt, %{
      score: score,
      out_of: out_of,
      date_evaluated: DateTime.utc_now()
    })

  end

  defp get_latest_part_attempts(activity_attempt_guid) do
    Repo.all(from aa in ActivityAttempt,
      join: pa1 in PartAttempt, on: aa.id == pa1.activity_attempt_id,
      left_join: pa2 in PartAttempt, on: (aa.id == pa2.activity_attempt_id and pa1.part_id == pa2.part_id and pa1.id < pa2.id),
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
  Updates an resource access.
  ## Examples
      iex> update_resource_access(revision, %{field: new_value})
      {:ok, %ResourceAccess{}}
      iex> update_resource_access(revision, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_resource_access(activity_attempt, attrs) do
    ResourceAccess.changeset(activity_attempt, attrs)
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

    @doc """
  Creates a part attempt snapshot.
  ## Examples
      iex> create_snapshot(%{field: value})
      {:ok, %Snapshot{}}
      iex> create_snapshot(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_snapshot(attrs \\ %{}) do
    %Snapshot{}
    |> Snapshot.changeset(attrs)
    |> Repo.insert()
  end
end
