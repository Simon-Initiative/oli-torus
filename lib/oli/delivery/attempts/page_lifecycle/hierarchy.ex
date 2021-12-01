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
  alias Oli.Activities.Model
  alias Oli.Activities.Transformers
  alias Oli.Delivery.ActivityProvider.Result
  alias Oli.Delivery.Attempts.PageLifecycle.{VisitContext, AttemptState}

  @doc """
  Creates an attempt hierarchy for a given resource visit context.

  Returns {:ok, %AttemptState{}}
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
        attempt_hierarchy =
          Enum.reduce(activity_revisions, %{}, fn revision, m ->
            case create_full_activity_attempt(
                   resource_attempt,
                   revision,
                   !MapSet.member?(unscored, revision.resource_id)
                 ) do
              {:ok, {activity_attempt, part_attempts}} ->
                Map.put(m, revision.resource_id, {activity_attempt, part_attempts})

              e ->
                Map.put(m, revision.resource_id, e)
            end
          end)

        {:ok,
         %AttemptState{
           resource_attempt: resource_attempt,
           attempt_hierarchy: attempt_hierarchy
         }}

      error ->
        error
    end
  end

  defp create_full_activity_attempt(
         resource_attempt,
         %Revision{resource_id: resource_id, id: id, content: model} = revision,
         scoreable
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
             transformed_model: transformed_model,
             scoreable: scoreable
           }),
         {:ok, part_attempts} <- create_part_attempts(parsed_model, activity_attempt) do
      # We simulate the effect of preloading the revision by setting it
      # after we create the record. This is needed so that this function matches
      # the contract of get_latest_attempt - namely that the revision association
      # on activity attempt records is preloaded.

      {:ok, {Map.put(activity_attempt, :revision, revision), part_attempts}}
    else
      e -> Logger.error("failed to create full activity attempt: #{inspect(e)}")
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

  @doc """
  Retrieves the state of the latest attempts for a given resource attempt id and
  a given list of activity ids.

  Return value is a map of activity ids to a two element tuple.  The first
  element is the latest activity attempt and the second is a map of part ids
  to their part attempts. As an example:

  %{
    232 => {%ActivityAttempt{}, %{ "1" => %PartAttempt{}, "2" => %PartAttempt{}}}
    233 => {%ActivityAttempt{}, %{ "1" => %PartAttempt{}, "2" => %PartAttempt{}}}
  }
  """
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
            aa1.resource_attempt_id == ^resource_attempt_id and is_nil(aa2.id) and
            is_nil(pa2.id),
        preload: [revision: r],
        select: {pa1, aa1}
      )
    )
    |> results_to_activity_map
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
