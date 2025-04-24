defmodule Oli.Delivery.Attempts.PageLifecycle.Hierarchy do
  import Ecto.Query, warn: false

  require Logger

  alias Oli.Repo

  alias Oli.Delivery.Attempts.Core.{
    PartAttempt,
    ActivityAttempt,
    ResourceAccess,
    ResourceAttempt
  }

  import Oli.Delivery.Attempts.Core
  alias Oli.Activities.Realizer.Query.Source
  alias Oli.Resources.Revision
  alias Oli.Activities.Transformers
  alias Oli.Delivery.ActivityProvider.{AttemptPrototype, Result}
  alias Oli.Delivery.Attempts.PageLifecycle.{VisitContext}

  @doc """
  Creates an attempt hierarchy for a given resource visit context, optimized to
  use a constant number of queries relative to the number of activities and parts.
  Returns {:ok, %ResourceAttempt{}}
  """
  def create(%VisitContext{datashop_session_id: datashop_session_id} = context) do
    {resource_access_id, next_attempt_number} =
      case context.latest_resource_attempt do
        nil ->
          {get_resource_access(
             context.page_revision.resource_id,
             context.section_slug,
             context.user.id
           ).id, 1}

        attempt ->
          {attempt.resource_access_id, attempt.attempt_number + 1}
      end

    constraining_attempt_prototypes = construct_attempt_prototypes(context)

    audience_filtered_content =
      Oli.Delivery.Audience.filter_for_role(context.audience_role, context.page_revision.content)

    %Result{
      errors: errors,
      prototypes: prototypes,
      transformed_content: transformed_content,
      unscored: unscored
    } =
      context.activity_provider.(
        audience_filtered_content,
        %Source{
          blacklisted_activity_ids: [],
          section_slug: context.section_slug,
          publication_id: context.publication_id
        },
        constraining_attempt_prototypes,
        context.user,
        context.section_slug,
        Oli.Publishing.DeliveryResolver
      )

    case create_resource_attempt(%{
           content: transformed_content,
           errors: errors,
           attempt_guid: UUID.uuid4(),
           resource_access_id: resource_access_id,
           attempt_number: next_attempt_number,
           revision_id: context.page_revision.id
         }) do
      {:ok, resource_attempt} ->
        bulk_create_attempts(
          resource_attempt,
          context.latest_resource_attempt,
          prototypes,
          unscored,
          datashop_session_id
        )

        {:ok, resource_attempt}

      error ->
        error
    end
  end

  defp construct_attempt_prototypes(%VisitContext{latest_resource_attempt: nil}), do: []

  defp construct_attempt_prototypes(%VisitContext{
         page_revision: %Revision{content: %{"advancedDelivery" => true}}
       }),
       do: []

  defp construct_attempt_prototypes(%VisitContext{
         effective_settings: %{retake_mode: retake_mode, batch_scoring: batch_scoring},
         latest_resource_attempt: latest_resource_attempt,
         page_revision: %Revision{graded: graded} = page_revision
       }) do

    migrate_all_fn = fn ->
      get_migratable_activity_attempts(latest_resource_attempt.id)
      |> Enum.map(fn attempt ->
        Oli.Delivery.ActivityProvider.AttemptPrototype.from_attempt(attempt)
      end)
    end

    revisions_changed =
      latest_resource_attempt.revision_id != page_revision.id

    # When the revision of page has changed, there are three cases where
    # we migrate forward the activity attempts from the previous resource attempt:
    #
    # 1. Revisions have changed in a practice page
    # 2. Page revisions have NOT changed, graded page and targeted retake mode is enabled
    # 2. Revisions changed in a score as you go graded page
    case {revisions_changed, graded, retake_mode, batch_scoring} do

      {true, false, _, _} ->
        migrate_all_fn.()

      {false, true, :targeted, _} ->

        get_correct_attempts(latest_resource_attempt.id)
        |> Enum.map(fn attempt ->
          Oli.Delivery.ActivityProvider.AttemptPrototype.from_attempt(attempt)
        end)

      {true, true, _, false} ->
        migrate_all_fn.()

      _ ->
        []

    end

  end

  defp construct_attempt_prototypes(_), do: []

  # Instead of one insertion query for every part attempt and one insertion query for
  # every activity attempt, this implementation does the same with exactly three queries:
  #
  # 1. Bulk activity attempt creation (regardless of the number of attempts)
  # 2. A query to fetch the newly created IDs and their corresponding resource_ids
  # 3. A final bulk insert query to create the part attempts
  #
  defp bulk_create_attempts(
         resource_attempt,
         previous_attempt,
         prototypes,
         unscored,
         datashop_session_id
       ) do
    # Use a common timestamp for all insertions
    right_now =
      DateTime.utc_now()
      |> DateTime.truncate(:second)

    # Perform the in-bulk activity transformation for those prototypes
    # that do not already have a transformed_model present
    require_transformations =
      Enum.filter(prototypes, fn p -> is_nil(p.transformed_model) end)
      |> Enum.map(fn p -> p.revision end)

    transformation_results_map =
      Transformers.apply_transforms(require_transformations)
      |> Enum.zip(require_transformations)
      |> Enum.reduce(%{}, fn {transformation_result, revision}, map ->
        Map.put(map, revision.resource_id, transformation_result)
      end)

    # Normalize the prototypes so that they all have transformed_model updated (if needed)
    # and scoreable attrs set
    prototypes =
      Enum.map(prototypes, fn prototype ->
        unscored = MapSet.member?(unscored, prototype.revision.resource_id)
        scoreable = !unscored && is_nil(prototype.survey_id)

        case Map.get(transformation_results_map, prototype.revision.resource_id) do
          nil ->
            prototype

          {:ok, transformed_model} ->
            prototype
            |> Map.put(:transformed_model, transformed_model)

          {:error, e} ->
            Logger.warning("Could not transform activity model #{Kernel.inspect(e)}")

            prototype
            |> Map.put(:transformed_model, nil)
        end
        |> Map.put(:scoreable, scoreable)
      end)

    Enum.map(prototypes, fn prototype -> create_raw_activity_attempt(prototype) end)
    |> optimize_raw_attempts()
    |> bulk_create_activity_attempts(right_now, resource_attempt.id)

    create_part_attempts(prototypes, previous_attempt, resource_attempt, datashop_session_id)
  end

  defp create_part_attempts(prototypes, previous_attempt, resource_attempt, datashop_session_id) do
    # Handle the case that at least one of the prototypes require inheriting their state from a previous attempt
    if Enum.any?(prototypes, fn p -> p.inherit_state_from_previous end) do
      revision_ids =
        Enum.filter(prototypes, fn p -> p.inherit_state_from_previous end)
        |> Enum.map(fn p -> p.revision.id end)

      # Create the attempts that require inherited state
      create_part_attempts_with_state(
        previous_attempt.id,
        resource_attempt.id,
        revision_ids,
        datashop_session_id
      )

      # Create the rest of the attempts
      query_driven_part_attempt_creation(
        resource_attempt.id,
        datashop_session_id,
        revision_ids
      )
    else
      query_driven_part_attempt_creation(resource_attempt.id, datashop_session_id)
    end
  end

  defp bulk_create_activity_attempts(raw_attempts, now, resource_attempt_id) do
    placeholders = %{
      now: now,
      attempt_number: 1,
      resource_attempt_id: resource_attempt_id
    }

    Repo.insert_all(ActivityAttempt, raw_attempts, placeholders: placeholders)
  end

  # This is the optimal way to bulk create part attempts: passing a query driven 'insert'
  # to the database, instead of passing the raw payload of each record to create.
  defp query_driven_part_attempt_creation(
         resource_attempt_id,
         datashop_session_id,
         excluding_revision_ids \\ nil
       ) do
    exclude_clause =
      case excluding_revision_ids do
        nil ->
          ""

        revision_ids ->
          " and not a.revision_id in (" <>
            (revision_ids
             |> Enum.map(fn id -> "#{id}" end)
             |> Enum.join(",")) <> ")"
      end

    query = """
      INSERT INTO part_attempts(part_id, activity_attempt_id, attempt_guid, datashop_session_id, inserted_at, updated_at, hints, attempt_number, lifecycle_state, grading_approach)
      SELECT pm.part_id, a.id, gen_random_uuid(), $2, now(), now(), '{}'::varchar[], 1, 'active', (CASE WHEN pm.grading_approach IS NULL THEN
      'automatic'
       ELSE
       pm.grading_approach
       END)
      FROM activity_attempts as a
      LEFT JOIN revision_parts as pm on a.revision_id = pm.revision_id
      WHERE a.resource_attempt_id = $1 #{exclude_clause};
    """

    Repo.query!(query, [resource_attempt_id, datashop_session_id])
  end

  defp create_part_attempts_with_state(
         previous_resource_id,
         current_resource_id,
         revision_ids,
         datashop_session_id
       ) do
    # This is unfortunately a multi-step process.
    # 1. Collect the state (aka the response) from the previous attempt for the activities requested,
    #    arranging it into a map keyed by activity attempt revision id to lists of part attempt information
    previous_state_by_revision_id =
      Repo.all(
        from(aa1 in ActivityAttempt,
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
            aa1.resource_attempt_id == ^previous_resource_id and is_nil(aa2.id) and is_nil(pa2.id) and
              aa1.revision_id in ^revision_ids,
          select: %{
            response: pa1.response,
            score: pa1.score,
            out_of: pa1.out_of,
            feedback: pa1.feedback,
            part_id: pa1.part_id,
            revision_id: aa1.revision_id,
            lifecycle_state: pa1.lifecycle_state,
            grading_approach: pa1.grading_approach
          }
        )
      )
      |> Enum.reduce(%{}, fn row, m ->
        Map.put(m, row.revision_id, [row | Map.get(m, row.revision_id, [])])
      end)

    now = DateTime.utc_now()

    # 2. Retrieve the activity attempt ids and revision ids for the same matching collection of
    #    activity revisions from the *current resource attempt*.  These are the activity attempts
    #    that we need to create part attempt records for
    insert_payload =
      Repo.all(
        from(aa1 in ActivityAttempt,
          where:
            aa1.resource_attempt_id == ^current_resource_id and
              aa1.revision_id in ^revision_ids,
          select: %{id: aa1.id, revision_id: aa1.revision_id}
        )
      )
      # 3. Pair together the response from the previous attempt with the activity attempt id
      #    from the current attempt to create bulk insert payloads for these new part attempt records
      |> Enum.reduce([], fn %{id: id, revision_id: revision_id}, all ->
        case Map.get(previous_state_by_revision_id, revision_id) do
          nil ->
            all

          parts ->
            Enum.map(parts, fn %{
                                 response: response,
                                 score: score,
                                 out_of: out_of,
                                 feedback: feedback,
                                 lifecycle_state: lifecycle_state,
                                 part_id: part_id,
                                 grading_approach: grading_approach
                               } ->
              [
                part_id: part_id,
                response: response,
                activity_attempt_id: id,
                attempt_guid: UUID.uuid4(),
                datashop_session_id: datashop_session_id,
                inserted_at: now,
                updated_at: now,
                score: score,
                out_of: out_of,
                feedback: feedback,
                lifecycle_state: Atom.to_string(lifecycle_state),
                date_evaluated:
                  if lifecycle_state == :evaluated do
                    now
                  else
                    nil
                  end,
                date_submitted:
                  if lifecycle_state == :evaluated or lifecycle_state == :submitted do
                    now
                  else
                    nil
                  end,
                hints: [],
                attempt_number: 1,
                grading_approach: Atom.to_string(grading_approach)
              ]
            end) ++ all
        end
      end)

    # 4. Now simply insert these new records
    Repo.insert_all("part_attempts", insert_payload)
  end

  # If all of the transformed_model attrs are nil, we do not need to include them in
  # the query, as they will be set to nil by default.  Similar logic for the group of
  # lifecycle state, score, out_of, date_submitted and date_evaluated - when all
  # entries have lifecycle_state equal to :active.  We also optimize away each of
  # survey_id, group_id, and selection_id
  defp optimize_raw_attempts(raw_attempts) do
    raw_attempts =
      case Enum.all?(raw_attempts, fn a -> is_nil(a.transformed_model) end) do
        true -> Enum.map(raw_attempts, fn a -> Map.delete(a, :transformed_model) end)
        _ -> raw_attempts
      end

    raw_attempts =
      case Enum.all?(raw_attempts, fn a -> a.lifecycle_state == :active end) do
        true ->
          Enum.map(raw_attempts, fn a ->
            Map.delete(a, :lifecycle_state)
            |> Map.delete(:score)
            |> Map.delete(:date_submitted)
            |> Map.delete(:date_evaluated)
          end)

        _ ->
          raw_attempts
      end

    raw_attempts =
      case Enum.all?(raw_attempts, fn a -> is_nil(a.group_id) end) do
        true ->
          Enum.map(raw_attempts, fn a ->
            Map.delete(a, :group_id)
          end)

        _ ->
          raw_attempts
      end

    raw_attempts =
      case Enum.all?(raw_attempts, fn a -> is_nil(a.selection_id) end) do
        true ->
          Enum.map(raw_attempts, fn a ->
            Map.delete(a, :selection_id)
          end)

        _ ->
          raw_attempts
      end

    case Enum.all?(raw_attempts, fn a -> is_nil(a.survey_id) end) do
      true ->
        Enum.map(raw_attempts, fn a ->
          Map.delete(a, :survey_id)
        end)

      _ ->
        raw_attempts
    end
  end

  defp create_raw_activity_attempt(
         %AttemptPrototype{
           revision: %Revision{resource_id: resource_id, id: id},
           scoreable: scoreable,
           transformed_model: transformed_model,
           group_id: group_id,
           survey_id: survey_id,
           selection_id: selection_id,
           score: score,
           out_of: out_of
         } = prototype
       ) do
    %{
      resource_attempt_id: {:placeholder, :resource_attempt_id},
      attempt_guid: UUID.uuid4(),
      attempt_number: {:placeholder, :attempt_number},
      revision_id: id,
      resource_id: resource_id,
      transformed_model: transformed_model,
      scoreable: scoreable,
      lifecycle_state:
        if is_nil(prototype.lifecycle_state) do
          :active
        else
          prototype.lifecycle_state
        end,
      date_submitted: prototype.date_submitted,
      date_evaluated: prototype.date_evaluated,
      score: score,
      out_of: out_of,
      group_id: group_id,
      survey_id: survey_id,
      selection_id: selection_id,
      inserted_at: {:placeholder, :now},
      updated_at: {:placeholder, :now}
    }
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
        preload: [revision: r, part_attempts: pa1],
        select: {pa1, aa1}
      )
    )
    |> results_to_activity_map
  end

  def get_latest_attempts(resource_attempt_id, activity_ids) do
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
          aa1.resource_id in ^activity_ids and
            aa1.resource_attempt_id == ^resource_attempt_id and is_nil(aa2.id) and is_nil(pa2.id),
        preload: [revision: r],
        select: {pa1, aa1}
      )
    )
    |> results_to_activity_map
  end

  def get_migratable_activity_attempts(resource_attempt_id) do
    Repo.all(
      from(aa1 in ActivityAttempt,
        join: ra in ResourceAttempt,
        on: aa1.resource_attempt_id == ra.id,
        join: r in assoc(aa1, :revision),
        left_join: aa2 in ActivityAttempt,
        on:
          aa1.resource_id == aa2.resource_id and aa1.id < aa2.id and
            aa1.resource_attempt_id == aa2.resource_attempt_id,
        left_join: a in ResourceAccess,
        on: a.id == ra.resource_access_id,
        left_join: spp in Oli.Delivery.Sections.SectionsProjectsPublications,
        on: spp.section_id == a.section_id,
        left_join: pr in Oli.Publishing.PublishedResource,
        on: pr.publication_id == spp.publication_id and aa1.revision_id == pr.revision_id,
        where: ra.id == ^resource_attempt_id and is_nil(aa2.id) and pr.revision_id == r.id,
        preload: [revision: r],
        select: aa1
      )
    )
  end

  # Retrieve the activity attempts that were "correct" for a given resource attempt. This
  # assumes that this is a graded page (given that this is being used only for powering
  # targeted retake mode), thus is does nothing to ensure that it is retrieving the "latest"
  # activity attempt for each activity - as there is only ever one per activity per graded
  # resource attempt.
  defp get_correct_attempts(resource_attempt_id) do
    Repo.all(
      from(aa1 in ActivityAttempt,
        join: r in assoc(aa1, :revision),
        where:
          aa1.resource_attempt_id == ^resource_attempt_id and aa1.score == aa1.out_of and
            aa1.score > 0.0,
        preload: [revision: r]
      )
    )
  end

  def full_hierarchy(resource_attempt) do
    get_latest_attempts(resource_attempt.id)
  end

  def thin_hierarchy(resource_attempt) do
    map =
      Oli.Activities.list_activity_registrations()
      |> Enum.reduce(%{}, fn r, m -> Map.put(m, r.id, r) end)

    get_thin_activity_context(resource_attempt.id)
    |> Enum.map(fn {id, guid, type_id} ->
      {id,
       %{
         id: id,
         attemptGuid: guid,
         deliveryElement: Map.get(map, type_id).delivery_element
       }}
    end)
    |> Map.new()
  end

  # Take results in the form of a list of {part attempt, activity attempt} tuples
  # and convert that to a map of activity id to tuple of the activity attempt and
  # a map of part ids to part attempts.
  #
  # For example:
  #
  # %{
  #  232 => {%ActivityAttempt{}, %{ "1" => %PartAttempt{}, "2" => %PartAttempt{}}}
  #  233 => {%ActivityAttempt{}, %{ "1" => %PartAttempt{}, "2" => %PartAttempt{}}}
  # }
  defp results_to_activity_map(results) do
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
end
