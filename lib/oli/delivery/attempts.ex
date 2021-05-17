defmodule Oli.Delivery.Attempts do
  import Ecto.Query, warn: false

  alias Oli.Repo
  alias Oli.Delivery.Sections.{Section, Enrollment}
  alias Oli.Delivery.Sections

  alias Oli.Delivery.Attempts.{
    PartAttempt,
    ResourceAccess,
    ResourceAttempt,
    ActivityAttempt
  }

  alias Oli.Delivery.Snapshots

  alias Oli.Delivery.Evaluation.{EvaluationContext}
  alias Oli.Activities
  alias Oli.Activities.State.ActivityState
  alias Oli.Resources.{Revision}
  alias Oli.Activities.Model
  alias Oli.Activities.Model.Part
  alias Oli.Activities.Transformers
  alias Oli.Delivery.Attempts.{StudentInput, Result, Scoring, ClientEvaluation}
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
  def reset_activity(section_slug, activity_attempt_guid) do
    Repo.transaction(fn ->
      activity_attempt = get_activity_attempt_by(attempt_guid: activity_attempt_guid)

      if activity_attempt == nil do
        Repo.rollback({:not_found})
      else
        # We cannot rely on the attempt number from the supplied activity attempt
        # to determine the total number of attempts - or the next attempt number, since
        # a client could be resetting an attempt that is not the latest attempt (e.g. from multiple
        # browser windows).
        # Instead we will query to determine the count of attempts. This is likely an
        # area where we want locking in place to ensure that we can never get into a state
        # where two attempts are generated with the same number

        attempt_count =
          count_activity_attempts(
            activity_attempt.resource_attempt_id,
            activity_attempt.resource_id
          )

        if activity_attempt.revision.max_attempts > 0 and
             activity_attempt.revision.max_attempts <= attempt_count do
          Repo.rollback({:no_more_attempts})
        else
          activity_attempt = activity_attempt |> Repo.preload([:part_attempts])

          # Resolve the revision to pick up the latest
          revision = DeliveryResolver.from_resource_id(section_slug, activity_attempt.resource_id)

          # parse and transform
          with {:ok, model} <- Model.parse(revision.content),
               {:ok, transformed_model} <- Transformers.apply_transforms(revision.content),
               {:ok, new_activity_attempt} <-
                 create_activity_attempt(%{
                   attempt_guid: UUID.uuid4(),
                   attempt_number: attempt_count + 1,
                   transformed_model: transformed_model,
                   resource_id: activity_attempt.resource_id,
                   revision_id: revision.id,
                   resource_attempt_id: activity_attempt.resource_attempt_id
                 }) do
            # simulate preloading of the revision
            new_activity_attempt = Map.put(new_activity_attempt, :revision, revision)

            new_part_attempts =
              case Enum.reduce_while(activity_attempt.part_attempts, {:ok, []}, fn p,
                                                                                   {:ok, acc} ->
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
    {count} =
      Repo.one(
        from(p in ActivityAttempt,
          where: p.resource_attempt_id == ^resource_attempt_id and p.resource_id == ^resource_id,
          select: {count(p.id)}
        )
      )

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
      with {:ok, activity_attempt} <-
             get_activity_attempt_by(attempt_guid: activity_attempt_guid)
             |> Oli.Utils.trap_nil(:not_found),
           {:ok, part_attempt} <-
             get_part_attempt_by(attempt_guid: part_attempt_guid)
             |> Oli.Utils.trap_nil(:not_found),
           {:ok, model} <- Model.parse(activity_attempt.transformed_model),
           {:ok, part} <-
             Enum.find(model.parts, fn p -> p.id == part_attempt.part_id end)
             |> Oli.Utils.trap_nil(:not_found) do
        shown_hints = part_attempt.hints

        # Activities save empty hints to preserve the "deer in headlights" / "cognitive" / "bottom out"
        # hint ordering. Empty hints are filtered out here.
        all_hints =
          part.hints
          |> Oli.Activities.ParseUtils.remove_empty()

        if length(all_hints) > length(shown_hints) do
          hint = Enum.at(all_hints, length(shown_hints))

          case update_part_attempt(part_attempt, %{hints: part_attempt.hints ++ [hint.id]}) do
            {:ok, _} -> {hint, length(all_hints) > length(shown_hints) + 1}
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
  @spec determine_resource_attempt_state(%Revision{}, String.t(), number(), any) ::
          {:ok, {:in_progress, {%ResourceAttempt{}, map()}}}
          | {:ok, {:revised, {%ResourceAttempt{}, map()}}}
          | {:ok, {:not_started, {%ResourceAccess{}, [%ResourceAttempt{}]}}}
          | {:error, any}
  def determine_resource_attempt_state(
        resource_revision,
        section_slug,
        user_id,
        activity_provider
      ) do
    determine_resource_attempt_state(
      resource_revision,
      section_slug,
      nil,
      user_id,
      activity_provider
    )
  end

  @spec determine_resource_attempt_state(%Revision{}, String.t(), String.t(), number(), any) ::
          {:ok, {:in_progress, {%ResourceAttempt{}, map()}}}
          | {:ok, {:revised, {%ResourceAttempt{}, map()}}}
          | {:ok, {:not_started, {%ResourceAccess{}, [%ResourceAttempt{}]}}}
          | {:ok, {:in_review, {%ResourceAccess{}, [%ResourceAttempt{}]}}}
          | {:error, any}
  def determine_resource_attempt_state(
        resource_revision,
        section_slug,
        attempt_guid,
        user_id,
        activity_provider
      ) do
    # use supplied attempt guid or determine latest resource attempt and then derive the current resource state
    Repo.transaction(fn ->
      resource_attempt =
        case attempt_guid do
          nil -> get_latest_resource_attempt(resource_revision.resource_id, section_slug, user_id)
          _ -> get_resource_attempt_by(attempt_guid: attempt_guid)
        end

      case get_resource_state(
             resource_attempt,
             resource_revision,
             section_slug,
             user_id,
             activity_provider,
             attempt_guid
           ) do
        {:ok, results} -> results
        {:error, error} -> Repo.rollback(error)
      end
    end)
  end

  defp get_resource_state(
         resource_attempt,
         resource_revision,
         section_slug,
         user_id,
         activity_provider,
         attempt_guid
       ) do
    {graded, resource_attempt} = handle_grading_transitions(resource_attempt, resource_revision)

    if graded do
      get_graded_resource_state(
        resource_attempt,
        resource_revision,
        section_slug,
        user_id,
        activity_provider,
        attempt_guid
      )
    else
      get_ungraded_resource_state(
        resource_attempt,
        resource_revision,
        section_slug,
        user_id,
        activity_provider
      )
    end
  end

  # We cannot simply look at the current revision to know if this is a graded page or not, as
  # the author may have toggled that and republished after a student started an attempt.  To determine the graded status
  #  correctly, and to account for graded <-> ungraded transitions properly we must:
  #
  # 1. Use the current revision if no resource attempt is present, or if the current revision is set to "graded"
  # 2. Otherwise return "graded" value of the resource attempt revision.
  #
  # Then
  defp handle_grading_transitions(resource_attempt, resource_revision) do
    if is_nil(resource_attempt) || resource_attempt.revision.graded === resource_revision.graded do
      # There is no latest attempt, or the latest attempt revision's graded status doesn't differ from the current revisions
      {resource_revision.graded, resource_attempt}
    else
      # There revision on the latest attempt and the revision on current are different.

      # 2. If it was graded and is now ungraded:
      #     -Allow an "open" graded latest attempt to resume
      #     -If no open graded attempts, we proceed in a way that allows the student to access this as ungraded

      if resource_attempt.revision.graded == true do
        if is_nil(resource_attempt.date_evaluated) do
          # Returning true here allows their active graded attempt to continue
          {true, resource_attempt}
        else
          # This will allow the beginning of a new ungraded attempt
          {false, resource_attempt}
        end
      else
        # We want to handle:
        #
        # 1. If it was ungraded and now is graded:
        #     -There may be some historical “ungraded” attempts, delete all of them to provide a clean slate for the graded attempts
        #

        if is_nil(resource_attempt.date_evaluated) do
          # There is an open ungraded attempt that we need to finalize to allow the student
          # to start a new one in this graded context
          {:ok, updated_attempt} =
            update_resource_attempt(resource_attempt, %{
              score: 0,
              out_of: 0,
              date_evaluated: DateTime.utc_now()
            })

          {true, updated_attempt}
        else
          # This will allow the beginning of a new ungraded attempt
          {true, resource_attempt}
        end
      end
    end
  end

  defp get_ungraded_resource_state(
         resource_attempt,
         resource_revision,
         section_slug,
         user_id,
         activity_provider
       ) do
    # For ungraded pages we can safely throw away an existing resource attempt and create a new one
    # in the case that the attempt was pinned to an older revision of the resource. This allows newly published
    # changes to the resource to be seen after a user has visited the resource previously
    if is_nil(resource_attempt) or resource_attempt.revision_id != resource_revision.id do
      case create_new_attempt_tree(
             0,
             resource_attempt,
             resource_revision,
             section_slug,
             user_id,
             activity_provider
           ) do
        {:ok, results} -> {:ok, {:in_progress, results}}
        error -> error
      end
    else
      {:ok, {:in_progress, {resource_attempt, get_latest_attempts(resource_attempt.id)}}}
    end
  end

  defp get_graded_resource_state(
         resource_attempt,
         resource_revision,
         section_slug,
         user_id,
         _,
         attempt_guid
       ) do
    mode = if attempt_guid == nil, do: :in_progress, else: :in_review

    if (is_nil(resource_attempt) or !is_nil(resource_attempt.date_evaluated)) and
         mode != :in_review do
      {access, attempts} =
        get_resource_attempt_history(resource_revision.resource_id, section_slug, user_id)

      graded_attempts = Enum.filter(attempts, fn a -> a.revision.graded == true end)

      {:ok, {:not_started, {access, graded_attempts}}}
    else
      # Unlike ungraded pages, for graded pages we do not throw away attempts and create anew in the case
      # where the resource revision has changed.  Instead we return back the existing attempt tree and force
      # the page renderer to resolve this discrepancy by indicating the "revised" state.
      if resource_revision.id !== resource_attempt.revision_id and mode != :in_review do
        {:ok, {:revised, {resource_attempt, get_latest_attempts(resource_attempt.id)}}}
      else
        {:ok, {mode, {resource_attempt, get_latest_attempts(resource_attempt.id)}}}
      end
    end
  end

  @doc """
  Retrieves the resource access record and all (if any) attempts related to it
  in a two element tuple of the form:

  `{%ResourceAccess, [%ResourceAttempt{}]}`

  The empty list `[]` will be present if there are no resource attempts.
  """
  def get_resource_attempt_history(resource_id, section_slug, user_id) do
    access = get_resource_access(resource_id, section_slug, user_id)

    id = access.id

    attempts =
      Repo.all(
        from(ra in ResourceAttempt,
          where: ra.resource_access_id == ^id,
          select: ra,
          preload: [:revision]
        )
      )

    attempt_representation =
      case attempts do
        nil -> []
        records -> records
      end

    {access, attempt_representation}
  end

  @doc """
  Retrieves all graded resource attempts for a given resource access.

  `[%ResourceAccess{}, ...]`
  """
  def get_graded_attempts_from_access(resource_access_id) do
    Repo.all(
      from(a in ResourceAttempt,
        join: r in Revision,
        on: a.revision_id == r.id,
        where: a.resource_access_id == ^resource_access_id and r.graded == true,
        select: a
      )
    )
  end

  @doc """
  Retrieves all graded resource access for a given context

  `[%ResourceAccess{}, ...]`
  """
  def get_graded_resource_access_for_context(section_slug) do
    Repo.all(
      from(a in ResourceAccess,
        join: s in Section,
        on: a.section_id == s.id,
        join: p in PublishedResource,
        on: s.publication_id == p.publication_id,
        join: r in Revision,
        on: p.revision_id == r.id,
        where: s.slug == ^section_slug and s.status != :deleted and r.graded == true,
        select: a
      )
    )
  end

  @doc """
  Retrieves all graded resource access for a given context

  `[%ResourceAccess{}, ...]`
  """
  def get_resource_access_for_page(section_slug, resource_id) do
    Repo.all(
      from(a in ResourceAccess,
        join: s in Section,
        on: a.section_id == s.id,
        join: p in PublishedResource,
        on: s.publication_id == p.publication_id,
        join: r in Revision,
        on: p.revision_id == r.id,
        where:
          s.slug == ^section_slug and s.status != :deleted and r.graded == true and
            r.resource_id == ^resource_id,
        select: a
      )
    )
  end

  @doc """
  Retrieves all resource accesses for a given context and user

  `[%ResourceAccess{}, ...]`
  """
  def get_user_resource_accesses_for_context(section_slug, user_id) do
    Repo.all(
      from(a in ResourceAccess,
        join: s in Section,
        on: a.section_id == s.id,
        join: p in PublishedResource,
        on: s.publication_id == p.publication_id,
        join: r in Revision,
        on: p.revision_id == r.id,
        where: s.slug == ^section_slug and s.status != :deleted and a.user_id == ^user_id,
        distinct: a.id,
        select: a
      )
    )
  end

  defp get_resource_access(resource_id, section_slug, user_id) do
    Repo.one(
      from(a in ResourceAccess,
        join: s in Section,
        on: a.section_id == s.id,
        where:
          a.user_id == ^user_id and s.slug == ^section_slug and s.status != :deleted and
            a.resource_id == ^resource_id,
        select: a
      )
    )
  end

  def get_part_attempts_and_users_for_publication(publication_id) do
    student_role_id = Lti_1p3.Tool.ContextRoles.get_role(:context_learner).id

    Repo.all(
      from(section in Section,
        join: enrollment in Enrollment,
        on: enrollment.section_id == section.id,
        join: user in Oli.Accounts.User,
        on: enrollment.user_id == user.id,
        join: raccess in ResourceAccess,
        on: user.id == raccess.user_id,
        join: rattempt in ResourceAttempt,
        on: raccess.id == rattempt.resource_access_id,
        join: aattempt in ActivityAttempt,
        on: rattempt.id == aattempt.resource_attempt_id,
        join: pattempt in PartAttempt,
        on: aattempt.id == pattempt.activity_attempt_id,
        where: section.publication_id == ^publication_id,

        # only fetch records for users enrolled as students
        left_join: er in "enrollments_context_roles",
        on: enrollment.id == er.enrollment_id,
        left_join: context_role in Lti_1p3.DataProviders.EctoProvider.ContextRole,
        on: er.context_role_id == context_role.id and context_role.id == ^student_role_id,
        select: %{part_attempt: pattempt, user: user}
      )
    )
    # TODO: This should be done in the query, but can't get the syntax right
    |> Enum.map(
      &%{
        user: &1.user,
        part_attempt:
          Repo.preload(&1.part_attempt,
            activity_attempt: [:revision, revision: :activity_type, resource_attempt: :revision]
          )
      }
    )
  end

  def create_new_attempt_tree(
        attempt_count,
        old_resource_attempt,
        resource_revision,
        section_slug,
        user_id,
        activity_provider
      ) do
    {resource_access_id, next_attempt_number} =
      case old_resource_attempt do
        nil ->
          {get_resource_access(resource_revision.resource_id, section_slug, user_id).id,
           attempt_count + 1}

        attempt ->
          {attempt.resource_access_id, attempt.attempt_number + 1}
      end

    activity_revisions = activity_provider.(section_slug, resource_revision)

    case create_resource_attempt(%{
           attempt_guid: UUID.uuid4(),
           resource_access_id: resource_access_id,
           attempt_number: next_attempt_number,
           revision_id: resource_revision.id
         }) do
      {:ok, resource_attempt} ->
        {:ok,
         {resource_attempt,
          Enum.reduce(activity_revisions, %{}, fn revision, m ->
            case create_full_activity_attempt(resource_attempt, revision) do
              {:ok, {activity_attempt, part_attempts}} ->
                Map.put(m, revision.resource_id, {activity_attempt, part_attempts})

              e ->
                Map.put(m, revision.resource_id, e)
            end
          end)}}

      error ->
        error
    end
  end

  defp create_full_activity_attempt(
         resource_attempt,
         %Revision{resource_id: resource_id, id: id, content: model} = revision
       ) do
    with {:ok, parsed_model} <- Model.parse(model),
         {:ok, transformed_model} <- Transformers.apply_transforms(model),
         {:ok, activity_attempt} <-
           create_activity_attempt(%{
             resource_attempt_id: resource_attempt.id,
             attempt_guid: UUID.uuid4(),
             attempt_number: 1,
             revision_id: id,
             resource_id: resource_id,
             transformed_model: transformed_model
           }),
         {:ok, part_attempts} <- create_part_attempts(parsed_model, activity_attempt) do
      # We simulate the effect of preloading the revision by setting it
      # after we create the record. This is needed so that this function matches
      # the contract of get_latest_attempt - namely that the revision association
      # on activity attempt records is preloaded.

      {:ok, {Map.put(activity_attempt, :revision, revision), part_attempts}}
    else
      e -> IO.inspect(e)
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
    results =
      Repo.all(
        from(aa1 in ActivityAttempt,
          join: r in assoc(aa1, :revision),
          left_join: aa2 in ActivityAttempt,
          on:
            aa1.resource_id == aa2.resource_id and aa1.id < aa2.id and
              aa1.resource_attempt_id == aa2.resource_attempt_id,
          join: pa1 in PartAttempt,
          on: aa1.id == pa1.activity_attempt_id,
          left_join: pa2 in PartAttempt,
          on:
            aa1.id == pa2.activity_attempt_id and pa1.part_id == pa2.part_id and pa1.id < pa2.id and
              pa1.activity_attempt_id == pa2.activity_attempt_id,
          where:
            aa1.resource_attempt_id == ^resource_attempt_id and is_nil(aa2.id) and is_nil(pa2.id),
          preload: [revision: r],
          select: {pa1, aa1}
        )
      )

    Enum.reduce(results, %{}, fn {part_attempt, activity_attempt}, m ->
      activity_id = activity_attempt.resource_id
      part_id = part_attempt.part_id

      # ensure we have an entry for this resource
      m =
        case Map.has_key?(m, activity_id) do
          true -> m
          false -> Map.put(m, activity_id, {activity_attempt, %{}})
        end

      activity_entry =
        case Map.get(m, activity_id) do
          {current_attempt, part_map} ->
            {current_attempt, Map.put(part_map, part_id, part_attempt)}
        end

      Map.put(m, activity_id, activity_entry)
    end)
  end

  @doc """
  Retrieves the latest resource attempt for a given resource id,
  context id and user id.  If no attempts exist, returns nil.
  """
  def get_latest_resource_attempt(resource_id, section_slug, user_id) do
    Repo.one(
      from(a in ResourceAccess,
        join: s in Section,
        on: a.section_id == s.id,
        join: ra1 in ResourceAttempt,
        on: a.id == ra1.resource_access_id,
        left_join: ra2 in ResourceAttempt,
        on:
          a.id == ra2.resource_access_id and ra1.id < ra2.id and
            ra1.resource_access_id == ra2.resource_access_id,
        where:
          a.user_id == ^user_id and s.slug == ^section_slug and s.status != :deleted and
            a.resource_id == ^resource_id and
            is_nil(ra2),
        select: ra1
      )
    )
    |> Repo.preload([:revision])
  end

  @doc """
  Create a new resource attempt in an active state for the given page revision slug
  in the specified section and for a specific user.

  On success returns:
  `{:ok, {%{ResourceAttempt}, ActivityAttemptMap}}`

  Possible failure returns are:
  `{:error, {:not_found}}` if the revision slug cannot be resolved
  `{:error, {:active_attempt_present}}` if an active resource attempt is present
  `{:error, {:no_more_attempts}}` if no more attempts are present

  """
  def start_resource_attempt(revision_slug, section_slug, user_id, activity_provider) do
    Repo.transaction(fn ->
      with {:ok, revision} <-
             DeliveryResolver.from_revision_slug(section_slug, revision_slug)
             |> Oli.Utils.trap_nil(:not_found),
           {_, resource_attempts} <-
             get_resource_attempt_history(revision.resource_id, section_slug, user_id) do
        # We want to disregard any attempts that pertained to revisions whose graded status
        # do not match the current graded status. This acommodates the toggling of "graded" status
        # across publications, interwoven with student attempts to work correctly
        resource_attempts =
          Enum.filter(resource_attempts, fn a -> a.revision.graded == revision.graded end)

        case {revision.max_attempts > length(resource_attempts) or revision.max_attempts == 0,
              has_any_active_attempts?(resource_attempts)} do
          {true, false} ->
            case create_new_attempt_tree(
                   length(resource_attempts),
                   nil,
                   revision,
                   section_slug,
                   user_id,
                   activity_provider
                 ) do
              {:ok, results} -> results
              {:error, error} -> Repo.rollback(error)
            end

          {true, true} ->
            Repo.rollback({:active_attempt_present})

          {false, _} ->
            Repo.rollback({:no_more_attempts})
        end
      else
        {:error, error} -> Repo.rollback(error)
      end
    end)
  end

  @doc """
  Lookup resource attempt in an evaluated state for the given page guid

  On success returns:
  `{:ok, :preview_ready}`

  Possible failure returns are
  `{:error, :not_yet_submitted}` if the resource attempt is not yet evaluated

  """
  def review_resource_attempt(resource_attempt_guid) do
    # get the resource attempt record, ensure it's already evaluated
    resource_attempt = get_resource_attempt_by(attempt_guid: resource_attempt_guid)

    if resource_attempt.date_evaluated != nil do
      {:ok, :preview_ready}
    else
      {:error, :not_yet_submitted}
    end
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

      case Enum.reduce_while(part_inputs, :ok, fn %{
                                                    attempt_guid: attempt_guid,
                                                    response: response
                                                  },
                                                  _ ->
             case Repo.update_all(from(p in PartAttempt, where: p.attempt_guid == ^attempt_guid),
                    set: [response: response]
                  ) do
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
    %ActivityAttempt{
      transformed_model: transformed_model,
      attempt_number: attempt_number,
      resource_attempt: resource_attempt
    } =
      get_activity_attempt_by(attempt_guid: activity_attempt_guid)
      |> Repo.preload([:resource_attempt])

    {:ok, %Model{parts: parts}} = Model.parse(transformed_model)

    # We need to tie the attempt_guid from the part_inputs to the attempt_guid
    # from the %PartAttempt, and then the part id from the %PartAttempt to the
    # part id in the parsed model.
    part_map = Enum.reduce(parts, %{}, fn p, m -> Map.put(m, p.id, p) end)
    attempt_map = Enum.reduce(part_attempts, %{}, fn p, m -> Map.put(m, p.attempt_guid, p) end)

    evaluations =
      Enum.map(part_inputs, fn %{attempt_guid: attempt_guid, input: input} ->
        attempt = Map.get(attempt_map, attempt_guid)
        part = Map.get(part_map, attempt.part_id)

        context = %EvaluationContext{
          resource_attempt_number: resource_attempt.attempt_number,
          activity_attempt_number: attempt_number,
          part_attempt_number: attempt.attempt_number,
          input: input.input
        }

        if is_adaptive_eval?(part) do
          # Stub for the future adaptive rule engine evaluation
          perform_adaptive_eval(attempt_guid, context, part)
        else
          perform_standard_eval(attempt_guid, context, part)
        end
      end)

    {:ok, evaluations}
  end

  defp is_adaptive_eval?(%Part{} = part) do
    case Map.get(part, :outcomes) do
      nil -> false
      [] -> false
      _ -> true
    end
  end

  defp perform_standard_eval(
         attempt_guid,
         %EvaluationContext{} = evaluation_context,
         %Part{} = part
       ) do
    case Oli.Delivery.Evaluation.Evaluator.evaluate(part, evaluation_context) do
      {:ok, {feedback, %Result{score: score, out_of: out_of}}} ->
        {:ok,
         %Oli.Delivery.Attempts.FeedbackActionResult{
           type: "FeedbackActionResult",
           attempt_guid: attempt_guid,
           feedback: feedback,
           score: score,
           out_of: out_of
         }}

      {:error, e} ->
        {:error,
         %Oli.Delivery.Attempts.FeedbackActionResult{
           type: "FeedbackActionResult",
           attempt_guid: attempt_guid,
           feedback: %{},
           score: 0,
           out_of: 0,
           error: e
         }}
    end
  end

  defp perform_adaptive_eval(
         attempt_guid,
         %EvaluationContext{} = _,
         %Part{} = _
       ) do
    {:ok,
     %Oli.Delivery.Attempts.StateUpdateActionResult{
       type: "StateUpdateActionResult",
       attempt_guid: attempt_guid,
       update: %{}
     }}
  end

  # Persist the result of a single evaluation for a single part_input submission.
  defp persist_single_evaluation({_, {:error, error}}, _), do: {:halt, {:error, error}}

  defp persist_single_evaluation(
         {_, {:ok, %Oli.Delivery.Attempts.NavigationActionResult{} = action_result}},
         {:ok, results}
       ) do
    {:cont, {:ok, results ++ [action_result]}}
  end

  defp persist_single_evaluation(
         {_, {:ok, %Oli.Delivery.Attempts.StateUpdateActionResult{} = action_result}},
         {:ok, results}
       ) do
    {:cont, {:ok, results ++ [action_result]}}
  end

  defp persist_single_evaluation(
         {%{attempt_guid: attempt_guid, input: input},
          {:ok,
           %Oli.Delivery.Attempts.FeedbackActionResult{
             feedback: feedback,
             score: score,
             out_of: out_of
           } = feedback_action}},
         {:ok, results}
       ) do
    now = DateTime.utc_now()

    case Repo.update_all(
           from(p in PartAttempt,
             where: p.attempt_guid == ^attempt_guid and is_nil(p.date_evaluated)
           ),
           set: [
             response: input,
             date_evaluated: now,
             score: score,
             out_of: out_of,
             feedback: feedback
           ]
         ) do
      nil ->
        {:halt, {:error, :error}}

      {1, _} ->
        {:cont, {:ok, results ++ [feedback_action]}}

      _ ->
        {:halt, {:error, :error}}
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
    already_evaluated =
      Enum.filter(part_attempts, fn p -> p.date_evaluated != nil end)
      |> Enum.map(fn e -> e.attempt_guid end)
      |> MapSet.new()

    part_inputs =
      Enum.filter(part_inputs, fn %{attempt_guid: attempt_guid} ->
        !MapSet.member?(already_evaluated, attempt_guid)
      end)

    # Check to see if this would complete the activity submidssion
    yet_to_be_evaluated =
      Enum.filter(part_attempts, fn p -> p.date_evaluated == nil end)
      |> Enum.map(fn e -> e.attempt_guid end)
      |> MapSet.new()

    to_be_evaluated =
      Enum.map(part_inputs, fn e -> e.attempt_guid end)
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

    evaluations =
      Enum.map(part_inputs, fn %{part_id: part_id, input: input} ->
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

    evaluations =
      Enum.zip(evaluations, part_inputs)
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

  On success returns an `{:ok, results}` tuple where results in an array of maps. Each
  map instance contains the result of one of the evaluations in the form:

  `${score: score, out_of: out_of, feedback: feedback, attempt_guid, attempt_guid}`

  There can be less items in the results list than there are items in the input part_inputs
  as logic here will not evaluate part_input instances whose part attempt has already
  been evaluated.

  On failure returns `{:error, error}`
  """
  @spec submit_part_evaluations(String.t(), String.t(), [map()]) :: {:ok, [map()]} | {:error, any}
  def submit_part_evaluations(section_slug, activity_attempt_guid, part_inputs) do
    Repo.transaction(fn ->
      part_attempts = get_latest_part_attempts(activity_attempt_guid)

      roll_up = fn result ->
        rollup_part_attempt_evaluations(activity_attempt_guid)
        result
      end

      no_roll_up = fn result -> result end

      {roll_up_fn, part_inputs} =
        case filter_already_submitted(part_inputs, part_attempts) do
          {true, part_inputs} -> {roll_up, part_inputs}
          {false, part_inputs} -> {no_roll_up, part_inputs}
        end

      case evaluate_submissions(activity_attempt_guid, part_inputs, part_attempts)
           |> persist_evaluations(part_inputs, roll_up_fn) do
        {:ok, results} -> results
        {:error, error} -> Repo.rollback(error)
        _ -> Repo.rollback("unknown error")
      end
    end)
    |> Snapshots.maybe_create_snapshot(part_inputs, section_slug)
  end

  @doc """
  Processes a set of client evaluations for some number of parts for the given
  activity attempt guid.  If this collection of evaluations completes the activity
  the results of the part evalutions (including ones already having been evaluated)
  will be rolled up to the activity attempt record.

  On success returns an `{:ok, results}` tuple where results in an array of maps. Each
  map instance contains the result of one of the evaluations in the form:

  `${score: score, out_of: out_of, feedback: feedback, attempt_guid, attempt_guid}`

  On failure returns `{:error, error}`
  """
  @spec submit_client_evaluations(String.t(), String.t(), [map()]) ::
          {:ok, [map()]} | {:error, any}
  def submit_client_evaluations(section_slug, activity_attempt_guid, client_evaluations) do
    # verify this activity type allows client evaluation
    activity_attempt = get_activity_attempt_by(attempt_guid: activity_attempt_guid)
    activity_registration_slug = activity_attempt.revision.activity_type.slug

    part_inputs =
      Enum.map(client_evaluations, fn %{
                                        attempt_guid: attempt_guid,
                                        client_evaluation: %ClientEvaluation{input: input}
                                      } ->
        %{attempt_guid: attempt_guid, input: input}
      end)

    case Oli.Activities.get_registration_by_slug(activity_registration_slug) do
      %Activities.ActivityRegistration{allow_client_evaluation: true} ->
        Repo.transaction(fn ->
          part_attempts = get_latest_part_attempts(activity_attempt_guid)

          roll_up = fn result ->
            rollup_part_attempt_evaluations(activity_attempt_guid)
            result
          end

          no_roll_up = fn result -> result end

          {roll_up_fn, client_evaluations} =
            case filter_already_submitted(client_evaluations, part_attempts) do
              {true, client_evaluations} -> {roll_up, client_evaluations}
              {false, client_evaluations} -> {no_roll_up, client_evaluations}
            end

          case client_evaluations
               |> Enum.map(fn %{
                                attempt_guid: attempt_guid,
                                client_evaluation: %ClientEvaluation{
                                  score: score,
                                  out_of: out_of,
                                  feedback: feedback
                                }
                              } ->
                 {:ok,
                  %Oli.Delivery.Attempts.FeedbackActionResult{
                    type: "FeedbackActionResult",
                    attempt_guid: attempt_guid,
                    feedback: feedback,
                    score: score,
                    out_of: out_of
                  }}
               end)
               |> (fn evaluations -> {:ok, evaluations} end).()
               |> persist_evaluations(part_inputs, roll_up_fn) do
            {:ok, results} -> results
            {:error, error} -> Repo.rollback(error)
            _ -> Repo.rollback("unknown error")
          end
        end)
        |> Snapshots.maybe_create_snapshot(part_inputs, section_slug)

      _ ->
        {:error, "Activity type does not allow client evaluation"}
    end
  end

  def submit_graded_page(section_slug, resource_attempt_guid) do
    result =
      Repo.transaction(fn ->
        # get the resource attempt record, ensure it isn't already evaluated
        resource_attempt = get_resource_attempt_by(attempt_guid: resource_attempt_guid)

        if resource_attempt.date_evaluated == nil do
          # Collect all of the part attempt guids for all of the activities that
          # get finalized
          part_attempt_guids =
            Enum.map(resource_attempt.activity_attempts, fn a ->
              # some activities will finalize themselves ahead of a graded page
              # submission.  so we only submit those that are still yet to be finalized.
              if a.date_evaluated == nil do
                submit_graded_page_activity(a.attempt_guid)
              else
                []
              end
            end)
            |> List.flatten()
            |> Enum.map(fn part_attempt -> part_attempt.attempt_guid end)

          case roll_up_activities_to_resource_attempt(resource_attempt_guid) do
            {:ok, _} ->
              case roll_up_resource_attempts_to_access(
                     section_slug,
                     resource_attempt.resource_access_id
                   ) do
                {:ok, results} -> {results, part_attempt_guids}
                {:error, error} -> Repo.rollback(error)
              end

            {:error, error} ->
              Repo.rollback(error)
          end
        else
          Repo.rollback({:already_submitted})
        end
      end)

    case result do
      {:ok, {results, part_attempt_guids}} ->
        Snapshots.queue_or_create_snapshot(part_attempt_guids, section_slug)
        {:ok, results}

      e ->
        e
    end
  end

  defp roll_up_activities_to_resource_attempt(resource_attempt_guid) do
    resource_attempt = get_resource_attempt_by(attempt_guid: resource_attempt_guid)

    if resource_attempt.date_evaluated == nil do
      # Leaving this hardcoded to 'total' seems to make sense, but perhaps in the
      # future we do allow this to be configured
      {score, out_of} =
        Enum.reduce(resource_attempt.activity_attempts, {0, 0}, fn p, {score, out_of} ->
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

  defp roll_up_resource_attempts_to_access(section_slug, resource_access_id) do
    access = Oli.Repo.get(ResourceAccess, resource_access_id)
    graded_attempts = get_graded_attempts_from_access(access.id)

    %{scoring_strategy_id: strategy_id} =
      DeliveryResolver.from_resource_id(section_slug, access.resource_id)

    %Result{score: score, out_of: out_of} = Scoring.calculate_score(strategy_id, graded_attempts)

    update_resource_access(access, %{
      score: score,
      out_of: out_of,
      date_evaluated: DateTime.utc_now()
    })
  end

  defp submit_graded_page_activity(activity_attempt_guid) do
    part_attempts = get_latest_part_attempts(activity_attempt_guid)

    if Enum.all?(part_attempts, fn pa -> pa.response != nil end) do
      roll_up_fn = fn result ->
        rollup_part_attempt_evaluations(activity_attempt_guid)
        result
      end

      # derive the part_attempts from the currently saved state that we expect
      # to find in the part_attempts
      part_inputs =
        Enum.map(part_attempts, fn p ->
          %{
            attempt_guid: p.attempt_guid,
            input: %StudentInput{input: Map.get(p.response, "input")}
          }
        end)

      case evaluate_submissions(activity_attempt_guid, part_inputs, part_attempts)
           |> persist_evaluations(part_inputs, roll_up_fn) do
        {:ok, _} -> part_attempts
        {:error, error} -> Repo.rollback(error)
      end
    else
      Repo.rollback({:not_all_answered})
    end
  end

  @doc """
  Gets a section by activity attempt guid.
  ## Examples
      iex> get_section_by_activity_attempt_guid("123")
      %Section{}
      iex> get_section_by_activity_attempt_guid("111")
      nil
  """
  def get_section_by_activity_attempt_guid(activity_attempt_guid) do
    Repo.one(
      from(activity_attempt in ActivityAttempt,
        join: resource_attempt in ResourceAttempt,
        on: resource_attempt.id == activity_attempt.resource_attempt_id,
        join: resource_access in ResourceAccess,
        on: resource_access.id == resource_attempt.resource_access_id,
        join: section in Section,
        on: section.id == resource_access.section_id,
        where: activity_attempt.attempt_guid == ^activity_attempt_guid,
        select: section
      )
    )
  end

  @doc """
  Gets a collection of activity attempt records that pertain to a collection of activity
  attempt guids. There is no guarantee that the ordering of the results of the activity attempts
  will match the ordering of the input guids.  Any attempt guids that cannot be found are simply omitted
  from the result.
  ## Examples
      iex> get_activity_attempts(["20595ef0-e5f1-474e-880d-f2c20f3a4459", "30b59817-e193-488f-94b1-597420b8670e"])
      [%ActivityAttempt{}, %ActivityAttempt{}]
      iex> get_activity_attempts(["20595ef0-e5f1-474e-880d-f2c20f3a4459", "a-missing-one"])
      [%ActivityAttempt{}]
      iex> get_activity_attempts(["a-missing-one"])
      []
  """
  def get_activity_attempts(activity_attempt_guids) do
    results =
      Repo.all(
        from(activity_attempt in ActivityAttempt,
          where: activity_attempt.attempt_guid in ^activity_attempt_guids,
          preload: [:part_attempts]
        )
      )

    {:ok, results}
  end

  @doc """
  Gets an activity attempt by a clause.
  ## Examples
      iex> get_activity_attempt_by(attempt_guid: "123")
      %ActivityAttempt
      iex> get_activity_attempt_by(attempt_guid: "111")
      nil
  """
  def get_activity_attempt_by(clauses),
    do: Repo.get_by(ActivityAttempt, clauses) |> Repo.preload(revision: [:activity_type])

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
  def get_resource_attempt_by(clauses),
    do: Repo.get_by(ResourceAttempt, clauses) |> Repo.preload([:activity_attempts, :revision])

  def rollup_part_attempt_evaluations(activity_attempt_guid) do
    # find the latest part attempts
    part_attempts = get_latest_part_attempts(activity_attempt_guid)

    # apply the scoring strategy and set the evaluation on the activity
    activity_attempt = get_activity_attempt_by(attempt_guid: activity_attempt_guid)

    %Result{score: score, out_of: out_of} =
      Scoring.calculate_score(activity_attempt.revision.scoring_strategy_id, part_attempts)

    update_activity_attempt(activity_attempt, %{
      score: score,
      out_of: out_of,
      date_evaluated: DateTime.utc_now()
    })
  end

  defp get_latest_part_attempts(activity_attempt_guid) do
    Repo.all(
      from(aa in ActivityAttempt,
        join: pa1 in PartAttempt,
        on: aa.id == pa1.activity_attempt_id,
        left_join: pa2 in PartAttempt,
        on:
          aa.id == pa2.activity_attempt_id and pa1.part_id == pa2.part_id and pa1.id < pa2.id and
            pa1.activity_attempt_id == pa2.activity_attempt_id,
        where: aa.attempt_guid == ^activity_attempt_guid and is_nil(pa2),
        select: pa1
      )
    )
  end

  @doc """
  Creates or updates an access record for a given resource, section context id and user. When
  created the access count is set to 1, otherwise on updates the
  access count is incremented.
  ## Examples
      iex> track_access(resource_id, section_slug, user_id)
      {:ok, %ResourceAccess{}}
      iex> track_access(resource_id, section_slug, user_id)
      {:error, %Ecto.Changeset{}}
  """
  def track_access(resource_id, section_slug, user_id) do
    section = Sections.get_section_by(slug: section_slug)

    Oli.Repo.insert!(
      %ResourceAccess{
        access_count: 1,
        user_id: user_id,
        section_id: section.id,
        resource_id: resource_id
      },
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
  Gets a resource attempt by parameter.
  ## Examples
      iex> get_resource_attempt(attempt_guid: "123")
      %ResourceAttempt{}
      iex> get_resource_attempt(attempt_guid: "notfound")
      nil
  """
  def get_resource_attempt(clauses),
    do: Repo.get_by(ResourceAttempt, clauses)
end
