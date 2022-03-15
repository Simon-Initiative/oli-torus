defmodule Oli.Delivery.Attempts.PageLifecycle.Hierarchy do
  import Ecto.Query, warn: false

  require Logger

  alias Oli.Repo

  alias Oli.Delivery.Attempts.Core.{
    PartAttempt,
    ActivityAttempt
  }

  import Oli.Delivery.Attempts.Core
  alias Oli.Activities.Realizer.Query.Source
  alias Oli.Resources.Revision
  alias Oli.Activities.Transformers
  alias Oli.Delivery.ActivityProvider.Result
  alias Oli.Delivery.Attempts.PageLifecycle.{VisitContext}

  @doc """
  Creates an attempt hierarchy for a given resource visit context, optimized to
  use a constant number of queries relative to the number of activities and parts.
  Returns {:ok, %ResourceAttempt{}}
  """
  def create(%VisitContext{} = context) do
    {resource_access_id, next_attempt_number} =
      case context.latest_resource_attempt do
        nil ->
          {get_resource_access(
             context.page_revision.resource_id,
             context.section_slug,
             context.user_id
           ).id, 1}

        attempt ->
          {attempt.resource_access_id, attempt.attempt_number + 1}
      end

    %Result{
      errors: errors,
      revisions: activity_revisions,
      transformed_content: transformed_content,
      unscored: unscored
    } =
      context.activity_provider.(
        context.page_revision,
        %Source{
          blacklisted_activity_ids: [],
          section_slug: context.section_slug,
          publication_id: context.publication_id
        },
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
        bulk_create_attempts(resource_attempt, activity_revisions, unscored)
        {:ok, resource_attempt}

      error ->
        error
    end
  end

  # Instead of one insertion query for every part attempt and one insertion query for
  # every activity attempt, this implementation does the same with exactly three queries:
  #
  # 1. Bulk activity attempt creation (regardless of the number of attempts)
  # 2. A query to fetch the newly created IDs and their corresponding resource_ids
  # 3. A final bulk insert query to create the part attempts
  #
  defp bulk_create_attempts(resource_attempt, activity_revisions, unscored) do
    # Use a common timestamp for all insertions
    right_now =
      DateTime.utc_now()
      |> DateTime.truncate(:second)

    # Create the activity attempts, in bulk
    Enum.map(activity_revisions, fn r ->
      scoreable = !MapSet.member?(unscored, r.resource_id)
      create_raw_activity_attempt(r, scoreable)
    end)
    |> optimize_transformed_model()
    |> bulk_create_activity_attempts(right_now, resource_attempt.id)

    query_driven_part_attempt_creation(resource_attempt.id)
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
  defp query_driven_part_attempt_creation(resource_attempt_id) do
    query = """
      INSERT INTO part_attempts(part_id, activity_attempt_id, attempt_guid, inserted_at, updated_at, hints, attempt_number, lifecycle_state, grading_approach)
      SELECT pm.part_id, a.id, gen_random_uuid(), now(), now(), '{}'::varchar[], 1, 'active', (CASE WHEN pm.grading_approach IS NULL THEN
      'automatic'
       ELSE
       pm.grading_approach
       END)
      FROM activity_attempts as a
      LEFT JOIN part_mapping as pm on a.revision_id = pm.revision_id
      WHERE a.resource_attempt_id = $1;
    """

    Repo.query!(query, [resource_attempt_id])
  end

  # If all of the transformed_model attrs are nil, we do not need to include them in
  # the query, as they will be set to nil by default
  defp optimize_transformed_model(raw_attempts) do
    case Enum.all?(raw_attempts, fn a -> is_nil(a.transformed_model) end) do
      true -> Enum.map(raw_attempts, fn a -> Map.delete(a, :transformed_model) end)
      _ -> raw_attempts
    end
  end

  defp create_raw_activity_attempt(
         %Revision{resource_id: resource_id, id: id, content: model},
         scoreable
       ) do
    transformed_model =
      case Transformers.apply_transforms(model) do
        {:ok, t} -> t
        _ -> nil
      end

    %{
      resource_attempt_id: {:placeholder, :resource_attempt_id},
      attempt_guid: UUID.uuid4(),
      attempt_number: {:placeholder, :attempt_number},
      revision_id: id,
      resource_id: resource_id,
      transformed_model: transformed_model,
      scoreable: scoreable,
      lifecycle_state: :active,
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
        preload: [revision: r],
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
