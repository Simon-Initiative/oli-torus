defmodule Oli.Delivery.Attempts.ActivityLifecycle do
  import Ecto.Query, warn: false

  alias Oli.Repo

  alias Oli.Delivery.Attempts.Core.{
    PartAttempt,
    ResourceAccess,
    ResourceAttempt,
    ActivityAttempt,
    Result
  }

  alias Oli.Delivery.Evaluation.{EvaluationContext}
  alias Oli.Activities
  alias Oli.Activities.State.ActivityState
  alias Oli.Resources.{Revision}
  alias Oli.Activities.Model
  alias Oli.Activities.Model.Part
  alias Oli.Activities.Transformers
  alias Oli.Delivery.Attempts.Activity.{StudentInput, Result, ClientEvaluation}

  alias Oli.Publishing.DeliveryResolver
  alias Oli.Delivery.Page.ModelPruner

  import Oli.Delivery.Attempts.Core

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

  @doc """
  Performs activity model transformation for test mode.
  """
  def perform_test_transformation(model) do
    Transformers.apply_transforms(model)
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
end
