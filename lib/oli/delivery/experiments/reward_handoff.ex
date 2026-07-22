defmodule Oli.Delivery.Experiments.RewardHandoff do
  @moduledoc """
  Translates evaluated activity attempts into native experiment outcomes and rewards.
  """

  import Ecto.Query, warn: false

  require Logger

  alias Oli.Delivery.Attempts.Core.{ActivityAttempt, ResourceAccess, ResourceAttempt}
  alias Oli.Delivery.Sections.{Section, SectionsProjectsPublications}

  alias Oli.Experiments.{
    RecordOutcomeRequest,
    RecordRewardRequest,
    RewardEligibleAssignment,
    Scope
  }

  alias Oli.Publishing.PublishedResource
  alias Oli.Repo

  @reward_source "activity_attempt:full_credit"

  def record_evaluated_activity(%ActivityAttempt{id: id}), do: record_evaluated_activity(id)

  def record_evaluated_activity(activity_attempt_id) when is_integer(activity_attempt_id) do
    metadata = %{activity_attempt_id: activity_attempt_id}

    safely_record(metadata, fn ->
      activity_attempt_id
      |> load_evaluated_attempt_context()
      |> record_loaded_context(metadata)
    end)
  end

  def record_evaluated_activity(activity_attempt_guid) when is_binary(activity_attempt_guid) do
    metadata = %{activity_attempt_guid: activity_attempt_guid}

    safely_record(metadata, fn ->
      activity_attempt_guid
      |> load_evaluated_attempt_context_by_guid()
      |> record_loaded_context(metadata)
    end)
  end

  def record_evaluated_activity(_activity_attempt), do: {:error, :invalid_activity_attempt}

  defp safely_record(metadata, fun) do
    fun.()
  rescue
    exception ->
      :telemetry.execute(
        [:oli, :experiments, :delivery_reward, :exception],
        %{count: 1},
        Map.merge(safe_log_metadata(metadata), %{kind: :error, reason: exception.__struct__})
      )

      Logger.warning(
        "A/B testing reward handoff failed: #{inspect(Map.merge(safe_log_metadata(metadata), %{error: exception.__struct__}))}"
      )

      {:error, exception}
  end

  defp record_loaded_context(nil, metadata) do
    emit_skipped(:activity_attempt_not_found, metadata)
    :ok
  end

  defp record_loaded_context(%{activity_attempt: %{lifecycle_state: state}}, metadata)
       when state != :evaluated do
    emit_skipped(:activity_attempt_not_evaluated, Map.put(metadata, :lifecycle_state, state))
    :ok
  end

  defp record_loaded_context(%{} = context, metadata) do
    telemetry_metadata = telemetry_metadata(context, metadata)
    start_time = System.monotonic_time()

    :telemetry.execute(
      [:oli, :experiments, :delivery_reward, :start],
      %{system_time: System.system_time()},
      telemetry_metadata
    )

    try do
      result = do_record(context)
      duration = System.monotonic_time() - start_time

      :telemetry.execute(
        [:oli, :experiments, :delivery_reward, :stop],
        %{duration: duration},
        Map.put(telemetry_metadata, :result, result_tag(result))
      )

      result
    rescue
      exception ->
        duration = System.monotonic_time() - start_time

        :telemetry.execute(
          [:oli, :experiments, :delivery_reward, :exception],
          %{duration: duration},
          Map.merge(telemetry_metadata, %{kind: :error, reason: exception.__struct__})
        )

        Logger.warning(
          "A/B testing reward handoff failed: #{inspect(%{activity_attempt_id: context.activity_attempt.id, error: exception.__struct__})}"
        )

        {:error, exception}
    end
  end

  defp do_record(%{scope: scope, activity_attempt: activity_attempt, page_content: page_content}) do
    case Oli.Experiments.reward_eligible_assignments(
           scope,
           activity_attempt.resource_id,
           page_content
         ) do
      {:ok, []} ->
        emit_skipped(:no_reward_eligible_assignment, %{
          activity_attempt_id: activity_attempt.id,
          activity_resource_id: activity_attempt.resource_id,
          section_id: scope.section_id,
          publication_id: scope.publication_id
        })

        :ok

      {:ok, assignments} ->
        assignments
        |> Enum.reduce_while(:ok, fn assignment, :ok ->
          case record_assignment_reward(scope, activity_attempt, assignment) do
            :ok -> {:cont, :ok}
            {:error, error} -> {:halt, {:error, error}}
          end
        end)

      {:error, error} ->
        {:error, error}
    end
  end

  defp record_assignment_reward(
         %Scope{} = scope,
         %ActivityAttempt{} = activity_attempt,
         %RewardEligibleAssignment{} = assignment
       ) do
    outcome_key =
      "outcome:activity_attempt:#{activity_attempt.id}:assignment:#{assignment.assignment_id}"

    with {:ok, outcome} <-
           Oli.Experiments.record_outcome(%RecordOutcomeRequest{
             scope: scope,
             assignment_id: assignment.assignment_id,
             activity_attempt_id: activity_attempt.id,
             resource_attempt_id: activity_attempt.resource_attempt_id,
             activity_resource_id: activity_attempt.resource_id,
             score: activity_attempt.score,
             out_of: activity_attempt.out_of,
             observed_at: activity_attempt.date_evaluated,
             metadata: outcome_metadata(activity_attempt),
             idempotency_key: outcome_key
           }),
         {:ok, _reward} <-
           Oli.Experiments.record_reward(%RecordRewardRequest{
             scope: scope,
             assignment_id: assignment.assignment_id,
             outcome_id: outcome.id,
             reward_value: reward_value(activity_attempt),
             reward_source: @reward_source,
             metadata: reward_metadata(activity_attempt),
             idempotency_key:
               "reward:activity_attempt:#{activity_attempt.id}:assignment:#{assignment.assignment_id}"
           }) do
      :ok
    end
  end

  defp reward_value(%ActivityAttempt{score: score, out_of: out_of})
       when is_number(score) and is_number(out_of) and out_of > 0 and score >= out_of,
       do: 1.0

  defp reward_value(_activity_attempt), do: 0.0

  defp outcome_metadata(%ActivityAttempt{} = activity_attempt) do
    %{
      "attempt_number" => activity_attempt.attempt_number,
      "source" => @reward_source
    }
  end

  defp reward_metadata(%ActivityAttempt{} = activity_attempt) do
    %{
      "attempt_number" => activity_attempt.attempt_number,
      "binary_rule" => "full_credit"
    }
  end

  defp load_evaluated_attempt_context(activity_attempt_id) do
    from(activity_attempt in ActivityAttempt,
      join: resource_attempt in ResourceAttempt,
      on: resource_attempt.id == activity_attempt.resource_attempt_id,
      join: resource_access in ResourceAccess,
      on: resource_access.id == resource_attempt.resource_access_id,
      join: section in Section,
      on: section.id == resource_access.section_id,
      left_join: spp in SectionsProjectsPublications,
      on: spp.section_id == section.id and spp.project_id == section.base_project_id,
      left_join: published_resource in PublishedResource,
      on:
        published_resource.publication_id == spp.publication_id and
          published_resource.resource_id == resource_access.resource_id,
      where: activity_attempt.id == ^activity_attempt_id,
      select: %{
        activity_attempt: activity_attempt,
        page_content: resource_attempt.content,
        scope: %Scope{
          institution_id: section.institution_id,
          project_id: section.base_project_id,
          publication_id: spp.publication_id,
          section_id: section.id,
          user_id: resource_access.user_id,
          enrollment_id:
            fragment(
              "(SELECT e.id FROM enrollments e WHERE e.section_id = ? AND e.user_id = ? LIMIT 1)",
              section.id,
              resource_access.user_id
            )
        },
        published_revision_id: published_resource.revision_id
      },
      limit: 1
    )
    |> Repo.one()
  end

  defp load_evaluated_attempt_context_by_guid(activity_attempt_guid) do
    case Repo.get_by(ActivityAttempt, attempt_guid: activity_attempt_guid) do
      nil -> nil
      %ActivityAttempt{id: id} -> load_evaluated_attempt_context(id)
    end
  end

  defp telemetry_metadata(%{activity_attempt: activity_attempt, scope: scope}, metadata) do
    Map.merge(metadata, %{
      activity_attempt_id: activity_attempt.id,
      activity_resource_id: activity_attempt.resource_id,
      section_id: scope.section_id,
      publication_id: scope.publication_id
    })
  end

  defp result_tag(:ok), do: :ok
  defp result_tag({:error, _error}), do: :error

  defp safe_log_metadata(%{activity_attempt_id: activity_attempt_id})
       when is_integer(activity_attempt_id),
       do: %{activity_attempt_id: activity_attempt_id}

  defp safe_log_metadata(_metadata), do: %{}

  defp emit_skipped(reason, metadata) do
    :telemetry.execute(
      [:oli, :experiments, :delivery_reward, :skipped],
      %{count: 1},
      Map.put(metadata, :reason, reason)
    )
  end
end
